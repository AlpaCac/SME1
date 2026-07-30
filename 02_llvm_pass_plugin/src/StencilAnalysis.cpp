#include "StencilAnalysis.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"

#include <optional>
#include <string>

using namespace llvm;

namespace sme1 {
namespace {

struct LoadAccess {
  CallBase *Load = nullptr;
  Value *Pointer = nullptr;
  const SCEV *Address = nullptr;
};

bool hasNamePrefix(const CallBase &Call, StringRef Prefix) {
  const Function *Callee = Call.getCalledFunction();
  return Callee && Callee->getName().starts_with(Prefix);
}

void collectInnermostLoops(Loop &L, SmallVectorImpl<Loop *> &Loops) {
  if (L.isInnermost()) {
    Loops.push_back(&L);
    return;
  }
  for (Loop *SubLoop : L.getSubLoops())
    collectInnermostLoops(*SubLoop, Loops);
}

bool isPlaneOffset(const SCEV *S) {
  if (auto *Mul = dyn_cast<SCEVMulExpr>(S)) {
    unsigned NonConstantOperands = 0;
    for (const SCEV *Operand : Mul->operands())
      NonConstantOperands += !isa<SCEVConstant>(Operand);
    return NonConstantOperands >= 2;
  }
  if (auto *Add = dyn_cast<SCEVAddExpr>(S))
    return llvm::any_of(Add->operands(), isPlaneOffset);
  if (auto *Cast = dyn_cast<SCEVCastExpr>(S))
    return isPlaneOffset(Cast->getOperand());
  return false;
}

const SCEVConstant *constantAddressDifference(const SCEV *Left,
                                              const SCEV *Right,
                                              ScalarEvolution &SE) {
  return dyn_cast<SCEVConstant>(SE.getMinusSCEV(Left, Right));
}

bool areOppositeOffsets(const SCEV *Left, const SCEV *Right,
                        ScalarEvolution &SE) {
  auto *Sum = dyn_cast<SCEVConstant>(SE.getAddExpr(Left, Right));
  return Sum && Sum->getAPInt().isZero();
}

unsigned countOppositeStreamPairs(unsigned Candidate,
                                  ArrayRef<StreamInfo> Streams,
                                  ScalarEvolution &SE) {
  SmallVector<const SCEV *, 16> Offsets;
  for (unsigned I = 0; I < Streams.size(); ++I) {
    if (I == Candidate)
      continue;
    Offsets.push_back(
        SE.getMinusSCEV(Streams[I].Address, Streams[Candidate].Address));
  }

  unsigned Pairs = 0;
  for (unsigned I = 0; I < Offsets.size(); ++I)
    for (unsigned J = I + 1; J < Offsets.size(); ++J)
      Pairs += areOppositeOffsets(Offsets[I], Offsets[J], SE);
  return Pairs;
}

std::optional<StencilKind> kindForLoadCount(unsigned Count) {
  switch (Count) {
  case 3:
    return StencilKind::Stencil1D3P;
  case 5:
    return StencilKind::Stencil2D5P;
  case 7:
    return StencilKind::Stencil3D7P;
  case 9:
    return StencilKind::Stencil2D9P;
  case 13:
    return StencilKind::Stencil3D13P;
  case 25:
    return StencilKind::Stencil3D25P;
  case 27:
    return StencilKind::Stencil3D27P;
  default:
    return std::nullopt;
  }
}

bool is2D(StencilKind Kind) {
  return Kind == StencilKind::Stencil2D5P ||
         Kind == StencilKind::Stencil2D9P;
}

bool is3D(StencilKind Kind) { return !is2D(Kind) && Kind != StencilKind::Stencil1D3P; }

bool isScalableVectorStepImpl(Value *Step, SmallPtrSetImpl<Value *> &Seen) {
  if (!Seen.insert(Step).second)
    return false;

  if (auto *Call = dyn_cast<CallBase>(Step)) {
    return hasNamePrefix(*Call, "llvm.aarch64.sme.cntsw") ||
           hasNamePrefix(*Call, "llvm.aarch64.sme.cntsd") ||
           hasNamePrefix(*Call, "llvm.aarch64.sve.cntw") ||
           hasNamePrefix(*Call, "llvm.aarch64.sve.cntd") ||
           hasNamePrefix(*Call, "llvm.aarch64.sve.cntp") ||
           hasNamePrefix(*Call, "llvm.aarch64.sve.inc") ||
           hasNamePrefix(*Call, "llvm.aarch64.sve.addvl") ||
           hasNamePrefix(*Call, "llvm.vscale.");
  }

  auto *Inst = dyn_cast<Instruction>(Step);
  if (!Inst)
    return false;
  for (Value *Operand : Inst->operands())
    if (isScalableVectorStepImpl(Operand, Seen))
      return true;
  return false;
}

bool isScalableVectorStep(Value *Step) {
  SmallPtrSet<Value *, 8> Seen;
  return isScalableVectorStepImpl(Step, Seen);
}

bool isScalableVectorStep(const SCEV *Step) {
  // LLVM 19 can model vscale as a dedicated SCEV rather than an IR call.
  // Use its stable printed spelling to keep this pass compatible with both
  // representations without depending on a version-specific SCEV subclass.
  std::string Text;
  raw_string_ostream OS(Text);
  Step->print(OS);
  return OS.str().find("vscale") != std::string::npos;
}

Value *findInductionStep(PHINode *Induction, Loop &L) {
  for (User *User : Induction->users()) {
    auto *Add = dyn_cast<BinaryOperator>(User);
    if (!Add || Add->getOpcode() != Instruction::Add || !L.contains(Add))
      continue;
    if (Add->getOperand(0) == Induction)
      return Add->getOperand(1);
    if (Add->getOperand(1) == Induction)
      return Add->getOperand(0);
  }
  return nullptr;
}

PHINode *findTailInduction(Value *TailIndex) {
  // BiSheng may sign- or zero-extend an i32 loop induction before whilelt.
  while (auto *Cast = dyn_cast<CastInst>(TailIndex))
    TailIndex = Cast->getOperand(0);
  return dyn_cast<PHINode>(TailIndex);
}

std::optional<StencilInfo> reject(Function &F, Loop &L, StringRef Reason) {
  errs() << "StencilAnalysisReject: function=" << F.getName()
         << " loop=" << L.getHeader()->getName() << " reason=" << Reason
         << "\n";
  return std::nullopt;
}

std::optional<StencilInfo>
analyzeInnerLoop(Function &F, Loop &L, ScalarEvolution &SE,
                 DominatorTree &DT) {
  (void)DT;
  SmallVector<CallBase *, 32> MaskedLoads;
  SmallVector<CallBase *, 2> MaskedStores;
  bool HasUnsafeCall = false;
  bool HasOrdinaryStore = false;
  for (BasicBlock *BB : L.blocks()) {
    for (Instruction &I : *BB) {
      HasOrdinaryStore |= isa<StoreInst>(I);
      auto *Call = dyn_cast<CallBase>(&I);
      if (!Call)
        continue;
      const Function *Callee = Call->getCalledFunction();
      if (!Callee || !Callee->getName().starts_with("llvm."))
        HasUnsafeCall = true;
      else if (hasNamePrefix(*Call, "llvm.masked.load."))
        MaskedLoads.push_back(Call);
      else if (hasNamePrefix(*Call, "llvm.masked.store."))
        MaskedStores.push_back(Call);
    }
  }

  std::optional<StencilKind> Kind = kindForLoadCount(MaskedLoads.size());
  if (HasUnsafeCall || HasOrdinaryStore || !Kind || MaskedStores.size() != 1)
    return reject(F, L, "memory-or-load-pattern");

  Value *Predicate = MaskedLoads.front()->getArgOperand(2);
  for (CallBase *Load : MaskedLoads)
    if (Load->arg_size() < 3 || Load->getArgOperand(2) != Predicate)
      return reject(F, L, "masked-load-predicate");
  if (MaskedStores.front()->arg_size() < 4 ||
      MaskedStores.front()->getArgOperand(3) != Predicate)
    return reject(F, L, "masked-store-predicate");

  auto *TailPredicate = dyn_cast<CallBase>(Predicate);
  if (!TailPredicate ||
      (!hasNamePrefix(*TailPredicate, "llvm.aarch64.sve.whilelo.") &&
       !hasNamePrefix(*TailPredicate, "llvm.aarch64.sve.whilelt.")) ||
      TailPredicate->arg_size() < 2)
    return reject(F, L, "tail-predicate");
  auto *Induction = findTailInduction(TailPredicate->getArgOperand(0));
  if (!Induction || !L.contains(Induction))
    return reject(F, L, "tail-induction");
  auto *AddRec = dyn_cast<SCEVAddRecExpr>(SE.getSCEV(Induction));
  if (!AddRec || AddRec->getLoop() != &L || !AddRec->isAffine())
    return reject(F, L, "induction-scev");
  const SCEV *StepSCEV = AddRec->getStepRecurrence(SE);
  auto *StepUnknown = dyn_cast<SCEVUnknown>(StepSCEV);
  Value *VectorStep = StepUnknown ? StepUnknown->getValue() : nullptr;
  if (!VectorStep)
    VectorStep = findInductionStep(Induction, L);
  if (!VectorStep ||
      (!isScalableVectorStep(VectorStep) && !isScalableVectorStep(StepSCEV))) {
    errs() << "StencilAnalysisStep: function=" << F.getName()
           << " loop=" << L.getHeader()->getName() << " scev="
           << *StepSCEV;
    if (VectorStep)
      errs() << " value=" << *VectorStep;
    errs() << "\n";
    return reject(F, L, "scalable-vector-step");
  }

  auto *LoadVectorType = dyn_cast<VectorType>(MaskedLoads.front()->getType());
  if (!LoadVectorType)
    return reject(F, L, "masked-load-vector-type");
  unsigned ElementBytes =
      LoadVectorType->getElementType()->getScalarSizeInBits() / 8;
  if (ElementBytes == 0)
    return reject(F, L, "element-size");

  SmallVector<LoadAccess, 32> Accesses;
  for (CallBase *Load : MaskedLoads) {
    Value *Pointer = Load->getArgOperand(0);
    const SCEV *Address = SE.getSCEV(Pointer);
    if (isa<SCEVCouldNotCompute>(Address))
      return reject(F, L, "load-address-scev");
    Accesses.push_back({Load, Pointer, Address});
  }

  // Group loads into physical contiguous-row streams. LLVM may spell x-1,
  // x, and x+1 with unrelated GEP SSA values; a constant SCEV difference is
  // the representation-independent proof that they stay on the same row.
  SmallVector<unsigned, 32> Parent(Accesses.size());
  for (unsigned I = 0; I < Parent.size(); ++I)
    Parent[I] = I;
  auto FindRoot = [&](unsigned I) {
    while (Parent[I] != I) {
      Parent[I] = Parent[Parent[I]];
      I = Parent[I];
    }
    return I;
  };
  for (unsigned I = 0; I < Accesses.size(); ++I) {
    for (unsigned J = I + 1; J < Accesses.size(); ++J) {
      if (!constantAddressDifference(Accesses[I].Address,
                                     Accesses[J].Address, SE))
        continue;
      unsigned LeftRoot = FindRoot(I);
      unsigned RightRoot = FindRoot(J);
      if (LeftRoot != RightRoot)
        Parent[RightRoot] = LeftRoot;
    }
  }

  DenseMap<unsigned, SmallVector<unsigned, 9>> Groups;
  for (unsigned I = 0; I < Accesses.size(); ++I)
    Groups[FindRoot(I)].push_back(I);

  SmallVector<StreamInfo, 27> Streams;
  for (auto &Entry : Groups) {
    ArrayRef<unsigned> Members = Entry.second;
    unsigned Representative = Members.front();
    unsigned BestImbalance = Members.size() + 1;

    // Prefer an interior x-neighbor as the stream anchor. This avoids using
    // x-1 or x+1 when the center address is available, while remaining valid
    // for longer-radius 13P/25P rows.
    for (unsigned Candidate : Members) {
      unsigned NegativeCount = 0;
      unsigned PositiveCount = 0;
      for (unsigned Other : Members) {
        const SCEVConstant *Difference = constantAddressDifference(
            Accesses[Other].Address, Accesses[Candidate].Address, SE);
        if (!Difference)
          continue;
        NegativeCount += Difference->getAPInt().isNegative();
        PositiveCount += !Difference->getAPInt().isNegative() &&
                         !Difference->getAPInt().isZero();
      }
      unsigned Imbalance = NegativeCount > PositiveCount
                               ? NegativeCount - PositiveCount
                               : PositiveCount - NegativeCount;
      if (NegativeCount && PositiveCount && Imbalance < BestImbalance) {
        Representative = Candidate;
        BestImbalance = Imbalance;
      }
    }

    StreamInfo Stream;
    Stream.Base = Accesses[Representative].Pointer;
    Stream.RepresentativePointer = Accesses[Representative].Pointer;
    Stream.Address = Accesses[Representative].Address;
    for (unsigned Index : Members)
      Stream.Loads.push_back(Accesses[Index].Load);
    Streams.push_back(std::move(Stream));
  }

  unsigned CenterIndex = Streams.size();
  unsigned BestOppositePairs = 0;
  for (unsigned I = 0; I < Streams.size(); ++I) {
    if (Streams[I].Loads.size() < 3)
      continue;
    unsigned OppositePairs = countOppositeStreamPairs(I, Streams, SE);
    if (CenterIndex == Streams.size() || OppositePairs > BestOppositePairs) {
      CenterIndex = I;
      BestOppositePairs = OppositePairs;
    }
  }
  if (CenterIndex == Streams.size())
    return reject(F, L, "center-stream");

  // The representative selected above must have neighbors on both x sides.
  bool HasCenter = false;
  bool HasLeft = false;
  bool HasRight = false;
  for (CallBase *Load : Streams[CenterIndex].Loads) {
    const SCEV *Address = SE.getSCEV(Load->getArgOperand(0));
    const SCEVConstant *Difference = constantAddressDifference(
        Address, Streams[CenterIndex].Address, SE);
    if (!Difference)
      continue;
    HasCenter |= Difference->getAPInt().isZero();
    HasLeft |= Difference->getAPInt().isNegative();
    HasRight |= !Difference->getAPInt().isNegative() &&
                !Difference->getAPInt().isZero();
  }
  if (!HasCenter || !HasLeft || !HasRight)
    return reject(F, L, "center-neighbor-offsets");
  Streams[CenterIndex].Kind = StreamKind::CurrentRow;

  unsigned RowNeighbors = 0;
  unsigned PlaneNeighbors = 0;
  for (unsigned I = 0; I < Streams.size(); ++I) {
    if (I == CenterIndex)
      continue;
    const SCEV *Offset =
        SE.getMinusSCEV(Streams[I].Address, Streams[CenterIndex].Address);
    if (isa<SCEVCouldNotCompute>(Offset))
      return reject(F, L, "stream-offset-scev");
    if (isPlaneOffset(Offset)) {
      Streams[I].Kind = StreamKind::PlaneNeighbor;
      ++PlaneNeighbors;
    } else {
      Streams[I].Kind = StreamKind::RowNeighbor;
      ++RowNeighbors;
    }
  }

  if ((*Kind == StencilKind::Stencil1D3P && Streams.size() != 1) ||
      (is2D(*Kind) && (RowNeighbors < 2 || PlaneNeighbors != 0)) ||
      (is3D(*Kind) && (RowNeighbors < 2 || PlaneNeighbors < 2)))
    return reject(F, L, "stream-topology");

  StencilInfo Result;
  Result.Kind = *Kind;
  Result.InnerLoop = &L;
  Result.Induction = Induction;
  Result.Predicate = Predicate;
  Result.VectorStep = VectorStep;
  Result.LogicalLoadCount = MaskedLoads.size();
  Result.ElementBytes = ElementBytes;
  Result.Streams = std::move(Streams);
  return Result;
}

} // namespace

SmallVector<StencilInfo, 8>
analyzeStencilFunction(Function &F, LoopInfo &LI, ScalarEvolution &SE,
                       DominatorTree &DT) {
  SmallVector<Loop *, 8> InnermostLoops;
  for (Loop *L : LI)
    collectInnermostLoops(*L, InnermostLoops);
  SmallVector<StencilInfo, 8> Results;
  for (Loop *L : InnermostLoops)
    if (std::optional<StencilInfo> Info = analyzeInnerLoop(F, *L, SE, DT))
      Results.push_back(std::move(*Info));
  return Results;
}

const char *toString(StencilKind Kind) {
  switch (Kind) {
  case StencilKind::Stencil1D3P: return "1D3P";
  case StencilKind::Stencil2D5P: return "2D5P";
  case StencilKind::Stencil2D9P: return "2D9P";
  case StencilKind::Stencil3D7P: return "3D7P";
  case StencilKind::Stencil3D13P: return "3D13P";
  case StencilKind::Stencil3D25P: return "3D25P";
  case StencilKind::Stencil3D27P: return "3D27P";
  }
  return "unknown";
}

const char *toString(StreamKind Kind) {
  switch (Kind) {
  case StreamKind::CurrentRow: return "current-row";
  case StreamKind::RowNeighbor: return "row-neighbor";
  case StreamKind::PlaneNeighbor: return "plane-neighbor";
  }
  return "unknown";
}

} // namespace sme1
