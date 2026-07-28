#include "StencilAnalysis.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"

#include <optional>

using namespace llvm;

namespace sme1 {
namespace {

struct LoadAccess {
  CallBase *Load = nullptr;
  Value *Pointer = nullptr;
  Value *ConstantBase = nullptr;
  int64_t ConstantOffset = 0;
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

Value *stripSingleIndexGEP(Value *Pointer, Value *Induction) {
  auto *GEP = dyn_cast<GetElementPtrInst>(Pointer);
  if (!GEP || GEP->getNumIndices() != 1 ||
      GEP->idx_begin()->get() != Induction)
    return nullptr;
  return GEP->getPointerOperand();
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
    return std::nullopt;

  Value *Predicate = MaskedLoads.front()->getArgOperand(2);
  for (CallBase *Load : MaskedLoads)
    if (Load->arg_size() < 3 || Load->getArgOperand(2) != Predicate)
      return std::nullopt;
  if (MaskedStores.front()->arg_size() < 4 ||
      MaskedStores.front()->getArgOperand(3) != Predicate)
    return std::nullopt;

  auto *WhileLo = dyn_cast<CallBase>(Predicate);
  if (!WhileLo || !hasNamePrefix(*WhileLo, "llvm.aarch64.sve.whilelo.") ||
      WhileLo->arg_size() < 2)
    return std::nullopt;
  auto *Induction = dyn_cast<PHINode>(WhileLo->getArgOperand(0));
  if (!Induction || !L.contains(Induction))
    return std::nullopt;
  auto *AddRec = dyn_cast<SCEVAddRecExpr>(SE.getSCEV(Induction));
  if (!AddRec || AddRec->getLoop() != &L || !AddRec->isAffine())
    return std::nullopt;
  auto *StepUnknown = dyn_cast<SCEVUnknown>(AddRec->getStepRecurrence(SE));
  auto *StepCall = StepUnknown ? dyn_cast<CallBase>(StepUnknown->getValue())
                               : nullptr;
  if (!StepCall ||
      (!hasNamePrefix(*StepCall, "llvm.aarch64.sme.cntsw") &&
       !hasNamePrefix(*StepCall, "llvm.aarch64.sme.cntsd")))
    return std::nullopt;

  auto *LoadVectorType = dyn_cast<VectorType>(MaskedLoads.front()->getType());
  if (!LoadVectorType)
    return std::nullopt;
  unsigned ElementBytes =
      LoadVectorType->getElementType()->getScalarSizeInBits() / 8;
  if (ElementBytes == 0)
    return std::nullopt;

  const DataLayout &DL = F.getParent()->getDataLayout();
  SmallVector<LoadAccess, 32> Accesses;
  DenseMap<Value *, SmallVector<unsigned, 9>> Groups;
  for (CallBase *Load : MaskedLoads) {
    Value *Pointer = Load->getArgOperand(0);
    int64_t Offset = 0;
    Value *ConstantBase = GetPointerBaseWithConstantOffset(Pointer, Offset, DL);
    if (!ConstantBase)
      return std::nullopt;
    Groups[ConstantBase].push_back(Accesses.size());
    Accesses.push_back({Load, Pointer, ConstantBase, Offset});
  }

  DenseMap<Value *, unsigned> StreamByBase;
  SmallVector<StreamInfo, 27> Streams;
  for (auto &Entry : Groups) {
    Value *StreamBase = stripSingleIndexGEP(Entry.first, Induction);
    if (!StreamBase)
      return std::nullopt;
    StreamInfo Stream;
    Stream.Base = StreamBase;
    Stream.RepresentativePointer = Accesses[Entry.second.front()].Pointer;
    Stream.Address = SE.getSCEV(Stream.RepresentativePointer);
    for (unsigned Index : Entry.second)
      Stream.Loads.push_back(Accesses[Index].Load);
    StreamByBase[StreamBase] = Streams.size();
    Streams.push_back(std::move(Stream));
  }

  unsigned CenterIndex = Streams.size();
  for (unsigned I = 0; I < Streams.size(); ++I) {
    bool IsCommonBase = true;
    for (unsigned J = 0; J < Streams.size(); ++J) {
      if (I == J)
        continue;
      auto *GEP = dyn_cast<GetElementPtrInst>(Streams[J].Base);
      if (!GEP || GEP->getNumIndices() != 1 ||
          GEP->getPointerOperand() != Streams[I].Base) {
        IsCommonBase = false;
        break;
      }
    }
    if (IsCommonBase) {
      CenterIndex = I;
      break;
    }
  }
  if (CenterIndex == Streams.size())
    return std::nullopt;

  // The center stream must contain the x-direction center/left/right loads.
  bool HasCenter = false;
  bool HasLeft = false;
  bool HasRight = false;
  for (const LoadAccess &Access : Accesses) {
    Value *Base = stripSingleIndexGEP(Access.ConstantBase, Induction);
    if (Base != Streams[CenterIndex].Base)
      continue;
    HasCenter |= Access.ConstantOffset == 0;
    HasLeft |= Access.ConstantOffset < 0;
    HasRight |= Access.ConstantOffset > 0;
  }
  if (!HasCenter || !HasLeft || !HasRight)
    return std::nullopt;
  Streams[CenterIndex].Kind = StreamKind::CurrentRow;

  unsigned RowNeighbors = 0;
  unsigned PlaneNeighbors = 0;
  for (unsigned I = 0; I < Streams.size(); ++I) {
    if (I == CenterIndex)
      continue;
    auto *GEP = dyn_cast<GetElementPtrInst>(Streams[I].Base);
    const SCEV *Offset = SE.getSCEV(GEP->idx_begin()->get());
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
    return std::nullopt;

  StencilInfo Result;
  Result.Kind = *Kind;
  Result.InnerLoop = &L;
  Result.Induction = Induction;
  Result.Predicate = Predicate;
  Result.VectorStep = StepCall;
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
