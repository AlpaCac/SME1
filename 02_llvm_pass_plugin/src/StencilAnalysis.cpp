#include "StencilAnalysis.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Operator.h"
#include "llvm/Support/raw_ostream.h"

#include <optional>
#include <string>

using namespace llvm;

namespace sme1 {
namespace {

struct SymbolicTerm {
  Value *Operand = nullptr;
  int64_t Coefficient = 0;
};

struct SymbolicAddress {
  Value *Base = nullptr;
  int64_t ConstantOffsetBytes = 0;
  SmallVector<SymbolicTerm, 8> Terms;
};

struct LoadAccess {
  CallBase *Load = nullptr;
  Value *Pointer = nullptr;
  const SCEV *Address = nullptr;
  std::optional<SymbolicAddress> Symbolic;
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

void collectAdditiveTerms(Value *V, int64_t Coefficient,
                          int64_t &Constant,
                          SmallVectorImpl<SymbolicTerm> &Terms) {
  if (auto *Cast = dyn_cast<CastInst>(V)) {
    if (Cast->getOpcode() == Instruction::SExt ||
        Cast->getOpcode() == Instruction::ZExt) {
      collectAdditiveTerms(Cast->getOperand(0), Coefficient, Constant, Terms);
      return;
    }
  }

  if (auto *ConstantIntValue = dyn_cast<ConstantInt>(V)) {
    Constant += Coefficient * ConstantIntValue->getSExtValue();
    return;
  }

  if (auto *Binary = dyn_cast<BinaryOperator>(V)) {
    if (Binary->getOpcode() == Instruction::Add ||
        Binary->getOpcode() == Instruction::Sub) {
      collectAdditiveTerms(Binary->getOperand(0), Coefficient, Constant,
                           Terms);
      collectAdditiveTerms(
          Binary->getOperand(1),
          Binary->getOpcode() == Instruction::Sub ? -Coefficient
                                                   : Coefficient,
          Constant, Terms);
      return;
    }
    if (Binary->getOpcode() == Instruction::Mul) {
      for (unsigned ConstantOperand = 0; ConstantOperand < 2;
           ++ConstantOperand) {
        auto *Factor = dyn_cast<ConstantInt>(
            Binary->getOperand(ConstantOperand));
        if (!Factor)
          continue;
        collectAdditiveTerms(Binary->getOperand(1 - ConstantOperand),
                             Coefficient * Factor->getSExtValue(), Constant,
                             Terms);
        return;
      }
    }
  }

  Terms.push_back({V, Coefficient});
}

std::optional<SymbolicAddress>
getSymbolicAddress(Value *Pointer, const DataLayout &DL) {
  int64_t PointerConstantBytes = 0;
  Value *DynamicPointer =
      GetPointerBaseWithConstantOffset(Pointer, PointerConstantBytes, DL);
  auto *GEP = dyn_cast<GEPOperator>(DynamicPointer->stripPointerCasts());
  if (!GEP || GEP->getNumIndices() != 1)
    return std::nullopt;

  SymbolicAddress Result;
  Result.Base = GEP->getPointerOperand()->stripPointerCasts();
  int64_t IndexConstant = 0;
  collectAdditiveTerms(GEP->idx_begin()->get(), 1, IndexConstant,
                       Result.Terms);
  llvm::sort(Result.Terms, [](const SymbolicTerm &Left,
                              const SymbolicTerm &Right) {
    return Left.Operand < Right.Operand;
  });

  SmallVector<SymbolicTerm, 8> Combined;
  for (const SymbolicTerm &Term : Result.Terms) {
    if (!Combined.empty() && Combined.back().Operand == Term.Operand)
      Combined.back().Coefficient += Term.Coefficient;
    else
      Combined.push_back(Term);
  }
  llvm::erase_if(Combined,
                 [](const SymbolicTerm &Term) {
                   return Term.Coefficient == 0;
                 });
  Result.Terms = std::move(Combined);

  TypeSize ElementSize = DL.getTypeAllocSize(GEP->getSourceElementType());
  if (ElementSize.isScalable())
    return std::nullopt;
  Result.ConstantOffsetBytes =
      PointerConstantBytes +
      IndexConstant * static_cast<int64_t>(ElementSize.getFixedValue());
  return Result;
}

bool haveSameSymbolicTerms(const SymbolicAddress &Left,
                           const SymbolicAddress &Right) {
  if (Left.Base != Right.Base || Left.Terms.size() != Right.Terms.size())
    return false;
  for (unsigned I = 0; I < Left.Terms.size(); ++I)
    if (Left.Terms[I].Operand != Right.Terms[I].Operand ||
        Left.Terms[I].Coefficient != Right.Terms[I].Coefficient)
      return false;
  return true;
}

std::optional<int64_t> constantAddressDifference(const LoadAccess &Left,
                                                 const LoadAccess &Right,
                                                 ScalarEvolution &SE) {
  if (auto *Difference = dyn_cast<SCEVConstant>(
          SE.getMinusSCEV(Left.Address, Right.Address)))
    return Difference->getAPInt().getSExtValue();
  if (Left.Symbolic && Right.Symbolic &&
      haveSameSymbolicTerms(*Left.Symbolic, *Right.Symbolic))
    return Left.Symbolic->ConstantOffsetBytes -
           Right.Symbolic->ConstantOffsetBytes;
  return std::nullopt;
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

int64_t coefficientFor(Value *Operand, const SymbolicAddress &Address) {
  for (const SymbolicTerm &Term : Address.Terms)
    if (Term.Operand == Operand)
      return Term.Coefficient;
  return 0;
}

bool areSymmetricAddresses(const SymbolicAddress &Left,
                           const SymbolicAddress &Right,
                           const SymbolicAddress &Center) {
  if (Left.Base != Center.Base || Right.Base != Center.Base ||
      Left.ConstantOffsetBytes + Right.ConstantOffsetBytes !=
          2 * Center.ConstantOffsetBytes)
    return false;

  SmallPtrSet<Value *, 16> Operands;
  for (const SymbolicTerm &Term : Left.Terms)
    Operands.insert(Term.Operand);
  for (const SymbolicTerm &Term : Right.Terms)
    Operands.insert(Term.Operand);
  for (const SymbolicTerm &Term : Center.Terms)
    Operands.insert(Term.Operand);
  for (Value *Operand : Operands)
    if (coefficientFor(Operand, Left) + coefficientFor(Operand, Right) !=
        2 * coefficientFor(Operand, Center))
      return false;
  return true;
}

bool symbolicDifferenceHasPlaneTerm(const SymbolicAddress &Address,
                                    const SymbolicAddress &Center,
                                    ScalarEvolution &SE) {
  if (Address.Base != Center.Base)
    return false;
  for (const SymbolicTerm &Term : Address.Terms) {
    if (Term.Coefficient == coefficientFor(Term.Operand, Center))
      continue;
    if (isPlaneOffset(SE.getSCEV(Term.Operand)))
      return true;
  }
  return false;
}

bool areOppositeOffsets(const SCEV *Left, const SCEV *Right,
                        ScalarEvolution &SE) {
  auto *Sum = dyn_cast<SCEVConstant>(SE.getAddExpr(Left, Right));
  return Sum && Sum->getAPInt().isZero();
}

unsigned countOppositeStreamPairs(unsigned Candidate,
                                  ArrayRef<StreamInfo> Streams,
                                  ArrayRef<std::optional<SymbolicAddress>>
                                      SymbolicAddresses,
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
    for (unsigned J = I + 1; J < Offsets.size(); ++J) {
      bool Opposite = areOppositeOffsets(Offsets[I], Offsets[J], SE);
      if (!Opposite && SymbolicAddresses[Candidate]) {
        unsigned LeftIndex = I >= Candidate ? I + 1 : I;
        unsigned RightIndex = J >= Candidate ? J + 1 : J;
        if (SymbolicAddresses[LeftIndex] && SymbolicAddresses[RightIndex])
          Opposite = areSymmetricAddresses(
              *SymbolicAddresses[LeftIndex], *SymbolicAddresses[RightIndex],
              *SymbolicAddresses[Candidate]);
      }
      Pairs += Opposite;
    }
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

std::optional<unsigned> expected3DRowNeighbors(StencilKind Kind) {
  switch (Kind) {
  case StencilKind::Stencil3D7P:
  case StencilKind::Stencil3D27P:
    return 2;
  case StencilKind::Stencil3D13P:
    return 4;
  case StencilKind::Stencil3D25P:
    return 8;
  default:
    return std::nullopt;
  }
}

std::optional<unsigned> expected3DStreamCount(StencilKind Kind) {
  switch (Kind) {
  case StencilKind::Stencil3D7P:
    return 5;
  case StencilKind::Stencil3D13P:
  case StencilKind::Stencil3D27P:
    return 9;
  case StencilKind::Stencil3D25P:
    return 17;
  default:
    return std::nullopt;
  }
}

unsigned valueExpressionComplexityImpl(Value *V,
                                       SmallPtrSetImpl<Value *> &Seen) {
  if (!Seen.insert(V).second)
    return 0;
  auto *Inst = dyn_cast<Instruction>(V);
  if (!Inst)
    return 0;
  unsigned Complexity = 1;
  for (Value *Operand : Inst->operands())
    Complexity += valueExpressionComplexityImpl(Operand, Seen);
  return Complexity;
}

unsigned valueExpressionComplexity(Value *V) {
  SmallPtrSet<Value *, 16> Seen;
  return valueExpressionComplexityImpl(V, Seen);
}

unsigned streamOffsetComplexity(
    unsigned StreamIndex, unsigned CenterIndex,
    ArrayRef<std::optional<SymbolicAddress>> SymbolicAddresses,
    ScalarEvolution &SE, ArrayRef<StreamInfo> Streams) {
  if (SymbolicAddresses[StreamIndex] && SymbolicAddresses[CenterIndex]) {
    const SymbolicAddress &Address = *SymbolicAddresses[StreamIndex];
    const SymbolicAddress &Center = *SymbolicAddresses[CenterIndex];
    if (Address.Base == Center.Base) {
      SmallPtrSet<Value *, 16> Operands;
      for (const SymbolicTerm &Term : Address.Terms)
        Operands.insert(Term.Operand);
      for (const SymbolicTerm &Term : Center.Terms)
        Operands.insert(Term.Operand);
      unsigned Complexity = 0;
      for (Value *Operand : Operands) {
        if (coefficientFor(Operand, Address) ==
            coefficientFor(Operand, Center))
          continue;
        Complexity += 1 + valueExpressionComplexity(Operand);
      }
      return Complexity;
    }
  }

  const SCEV *Offset = SE.getMinusSCEV(
      Streams[StreamIndex].Address, Streams[CenterIndex].Address);
  std::string Text;
  raw_string_ostream OS(Text);
  Offset->print(OS);
  return OS.str().size();
}

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

void findTailInductionImpl(Value *V, Loop &L, SmallPtrSetImpl<Value *> &Seen,
                           PHINode *&Found, bool &Ambiguous) {
  if (Ambiguous || !Seen.insert(V).second)
    return;
  if (auto *Phi = dyn_cast<PHINode>(V)) {
    if (Phi->getParent() != L.getHeader())
      return;
    if (Found && Found != Phi)
      Ambiguous = true;
    else
      Found = Phi;
    return;
  }

  auto *Inst = dyn_cast<Instruction>(V);
  if (!Inst || !L.contains(Inst) || isa<CallBase>(Inst))
    return;
  for (Value *Operand : Inst->operands())
    findTailInductionImpl(Operand, L, Seen, Found, Ambiguous);
}

PHINode *findTailInduction(Value *TailIndex, Loop &L) {
  // BiSheng can fold a constant offset or scaling expression into whilelt's
  // start value. Follow that expression and require one unambiguous header
  // PHI instead of accepting only cast(PHI).
  SmallPtrSet<Value *, 16> Seen;
  PHINode *Found = nullptr;
  bool Ambiguous = false;
  findTailInductionImpl(TailIndex, L, Seen, Found, Ambiguous);
  return Ambiguous ? nullptr : Found;
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
  auto *Induction = findTailInduction(TailPredicate->getArgOperand(0), L);
  if (!Induction || !L.contains(Induction)) {
    errs() << "StencilAnalysisTail: function=" << F.getName()
           << " start=" << *TailPredicate->getArgOperand(0) << "\n";
    return reject(F, L, "tail-induction");
  }
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

  const DataLayout &DL = F.getParent()->getDataLayout();
  SmallVector<LoadAccess, 32> Accesses;
  for (CallBase *Load : MaskedLoads) {
    Value *Pointer = Load->getArgOperand(0);
    const SCEV *Address = SE.getSCEV(Pointer);
    if (isa<SCEVCouldNotCompute>(Address))
      return reject(F, L, "load-address-scev");
    Accesses.push_back({Load, Pointer, Address,
                        getSymbolicAddress(Pointer, DL)});
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
      if (!constantAddressDifference(Accesses[I], Accesses[J], SE))
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
  SmallVector<std::optional<SymbolicAddress>, 27> StreamSymbolicAddresses;
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
        std::optional<int64_t> Difference = constantAddressDifference(
            Accesses[Other], Accesses[Candidate], SE);
        if (!Difference)
          continue;
        NegativeCount += *Difference < 0;
        PositiveCount += *Difference > 0;
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
    StreamSymbolicAddresses.push_back(Accesses[Representative].Symbolic);
  }

  unsigned CenterIndex = Streams.size();
  unsigned BestOppositePairs = 0;
  for (unsigned I = 0; I < Streams.size(); ++I) {
    if (Streams[I].Loads.size() < 3)
      continue;
    unsigned OppositePairs = countOppositeStreamPairs(
        I, Streams, StreamSymbolicAddresses, SE);
    if (CenterIndex == Streams.size() || OppositePairs > BestOppositePairs) {
      CenterIndex = I;
      BestOppositePairs = OppositePairs;
    }
  }
  if (CenterIndex == Streams.size()) {
    errs() << "StencilAnalysisStreams: function=" << F.getName()
           << " groups=";
    for (unsigned I = 0; I < Streams.size(); ++I) {
      if (I)
        errs() << ",";
      errs() << Streams[I].Loads.size() << ":"
             << (StreamSymbolicAddresses[I] ? "symbolic" : "scev-only");
    }
    errs() << "\n";
    return reject(F, L, "center-stream");
  }

  // The representative selected above must have neighbors on both x sides.
  bool HasCenter = false;
  bool HasLeft = false;
  bool HasRight = false;
  const LoadAccess *CenterAccess = nullptr;
  for (const LoadAccess &Access : Accesses)
    if (Access.Pointer == Streams[CenterIndex].RepresentativePointer) {
      CenterAccess = &Access;
      break;
    }
  if (!CenterAccess)
    return reject(F, L, "center-address");
  for (CallBase *Load : Streams[CenterIndex].Loads) {
    const LoadAccess *Access = nullptr;
    for (const LoadAccess &Candidate : Accesses)
      if (Candidate.Load == Load) {
        Access = &Candidate;
        break;
      }
    if (!Access)
      continue;
    std::optional<int64_t> Difference =
        constantAddressDifference(*Access, *CenterAccess, SE);
    if (!Difference)
      continue;
    HasCenter |= *Difference == 0;
    HasLeft |= *Difference < 0;
    HasRight |= *Difference > 0;
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
    bool IsPlane = isPlaneOffset(Offset);
    if (!IsPlane && StreamSymbolicAddresses[I] &&
        StreamSymbolicAddresses[CenterIndex])
      IsPlane = symbolicDifferenceHasPlaneTerm(
          *StreamSymbolicAddresses[I],
          *StreamSymbolicAddresses[CenterIndex], SE);
    if (IsPlane) {
      Streams[I].Kind = StreamKind::PlaneNeighbor;
      ++PlaneNeighbors;
    } else {
      Streams[I].Kind = StreamKind::RowNeighbor;
      ++RowNeighbors;
    }
  }

  // Some frontends materialize height*width in an opaque SSA value, so the
  // plane term no longer appears as a SCEV multiplication. For the supported
  // symmetric 3D star/box topologies, rank offset expressions by structural
  // complexity: row stride is the simpler term, while plane stride depends on
  // the row stride and height. Require the exact stream count and all expected
  // opposite pairs before applying this fallback.
  std::optional<unsigned> ExpectedRows = expected3DRowNeighbors(*Kind);
  std::optional<unsigned> ExpectedStreams = expected3DStreamCount(*Kind);
  if (is3D(*Kind) && (RowNeighbors < 2 || PlaneNeighbors < 2) &&
      ExpectedRows && ExpectedStreams &&
      Streams.size() == *ExpectedStreams &&
      BestOppositePairs >= (*ExpectedStreams - 1) / 2) {
    SmallVector<std::pair<unsigned, unsigned>, 16> RankedStreams;
    for (unsigned I = 0; I < Streams.size(); ++I) {
      if (I == CenterIndex)
        continue;
      RankedStreams.push_back(
          {I, streamOffsetComplexity(I, CenterIndex,
                                     StreamSymbolicAddresses, SE, Streams)});
    }
    llvm::stable_sort(
        RankedStreams, [](const auto &Left, const auto &Right) {
          return Left.second < Right.second;
        });

    RowNeighbors = 0;
    PlaneNeighbors = 0;
    for (unsigned Rank = 0; Rank < RankedStreams.size(); ++Rank) {
      StreamInfo &Stream = Streams[RankedStreams[Rank].first];
      if (Rank < *ExpectedRows) {
        Stream.Kind = StreamKind::RowNeighbor;
        ++RowNeighbors;
      } else {
        Stream.Kind = StreamKind::PlaneNeighbor;
        ++PlaneNeighbors;
      }
    }
    errs() << "StencilAnalysisTopologyFallback: function=" << F.getName()
           << " kind=" << toString(*Kind)
           << " row-neighbors=" << RowNeighbors
           << " plane-neighbors=" << PlaneNeighbors << "\n";
  }

  if ((*Kind == StencilKind::Stencil1D3P && Streams.size() != 1) ||
      (is2D(*Kind) && (RowNeighbors < 2 || PlaneNeighbors != 0)) ||
      (is3D(*Kind) && (RowNeighbors < 2 || PlaneNeighbors < 2))) {
    errs() << "StencilAnalysisTopology: function=" << F.getName()
           << " kind=" << toString(*Kind)
           << " streams=" << Streams.size()
           << " opposite-pairs=" << BestOppositePairs
           << " row-neighbors=" << RowNeighbors
           << " plane-neighbors=" << PlaneNeighbors << "\n";
    return reject(F, L, "stream-topology");
  }

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
