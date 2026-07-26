#include "StencilAnalysis.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallPtrSet.h"
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

struct OffsetStream {
  const SCEV *Offset = nullptr;
  unsigned StreamIndex = 0;
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
  if (!GEP || GEP->getNumIndices() != 1)
    return nullptr;
  if (GEP->idx_begin()->get() != Induction)
    return nullptr;
  return GEP->getPointerOperand();
}

bool containsMinusOne(const SCEV *S) {
  auto *Mul = dyn_cast<SCEVMulExpr>(S);
  if (!Mul)
    return false;
  for (const SCEV *Operand : Mul->operands()) {
    auto *Constant = dyn_cast<SCEVConstant>(Operand);
    if (Constant && Constant->getAPInt().isAllOnes())
      return true;
  }
  return false;
}

bool areOpposite(const SCEV *A, const SCEV *B, ScalarEvolution &SE) {
  return A == SE.getNegativeSCEV(B) || B == SE.getNegativeSCEV(A);
}

bool isPlaneMagnitude(const SCEV *Magnitude) {
  auto *Mul = dyn_cast<SCEVMulExpr>(Magnitude);
  if (!Mul)
    return false;

  unsigned NonConstantOperands = 0;
  for (const SCEV *Operand : Mul->operands()) {
    if (!isa<SCEVConstant>(Operand))
      ++NonConstantOperands;
  }
  return NonConstantOperands >= 2;
}

std::optional<StencilInfo>
analyzeInnerLoop(Function &F, Loop &L, ScalarEvolution &SE,
                 DominatorTree &DT) {
  SmallVector<CallBase *, 8> MaskedLoads;
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
      if (!Callee || !Callee->getName().starts_with("llvm.")) {
        HasUnsafeCall = true;
      } else if (hasNamePrefix(*Call, "llvm.masked.load.")) {
        MaskedLoads.push_back(Call);
      } else if (hasNamePrefix(*Call, "llvm.masked.store.")) {
        MaskedStores.push_back(Call);
      }
    }
  }

  if (HasUnsafeCall || HasOrdinaryStore ||
      (MaskedLoads.size() != 5 && MaskedLoads.size() != 7) ||
      MaskedStores.size() != 1)
    return std::nullopt;

  Value *Predicate = MaskedLoads.front()->getArgOperand(2);
  for (CallBase *Load : MaskedLoads) {
    if (Load->arg_size() < 3 || Load->getArgOperand(2) != Predicate)
      return std::nullopt;
  }
  if (MaskedStores.front()->arg_size() < 4 ||
      MaskedStores.front()->getArgOperand(3) != Predicate)
    return std::nullopt;

  auto *WhileLo = dyn_cast<CallBase>(Predicate);
  if (!WhileLo || !hasNamePrefix(*WhileLo, "llvm.aarch64.sve.whilelo.") ||
      WhileLo->arg_size() < 2)
    return std::nullopt;
  for (CallBase *Load : MaskedLoads) {
    if (!DT.dominates(WhileLo, Load))
      return std::nullopt;
  }
  if (!DT.dominates(WhileLo, MaskedStores.front()))
    return std::nullopt;

  auto *Induction = dyn_cast<PHINode>(WhileLo->getArgOperand(0));
  if (!Induction || !L.contains(Induction))
    return std::nullopt;

  auto *AddRec = dyn_cast<SCEVAddRecExpr>(SE.getSCEV(Induction));
  if (!AddRec || AddRec->getLoop() != &L || !AddRec->isAffine())
    return std::nullopt;

  const SCEV *Step = AddRec->getStepRecurrence(SE);
  auto *StepUnknown = dyn_cast<SCEVUnknown>(Step);
  auto *StepCall =
      StepUnknown ? dyn_cast<CallBase>(StepUnknown->getValue()) : nullptr;
  if (!StepCall ||
      !hasNamePrefix(*StepCall, "llvm.aarch64.sme.cntsw"))
    return std::nullopt;

  const DataLayout &DL = F.getParent()->getDataLayout();
  SmallVector<LoadAccess, 8> Accesses;
  DenseMap<Value *, SmallVector<unsigned, 3>> ConstantGroups;

  for (CallBase *Load : MaskedLoads) {
    Value *Pointer = Load->getArgOperand(0);
    int64_t Offset = 0;
    Value *ConstantBase =
        GetPointerBaseWithConstantOffset(Pointer, Offset, DL);
    unsigned Index = Accesses.size();
    Accesses.push_back({Load, Pointer, ConstantBase, Offset});
    ConstantGroups[ConstantBase].push_back(Index);
  }

  Value *CenterAddress = nullptr;
  auto *LoadVectorType =
      dyn_cast<VectorType>(MaskedLoads.front()->getType());
  if (!LoadVectorType)
    return std::nullopt;
  unsigned ElementBytes =
      LoadVectorType->getElementType()->getScalarSizeInBits() / 8;
  if (ElementBytes == 0)
    return std::nullopt;

  for (auto &Entry : ConstantGroups) {
    bool HasZero = false;
    bool HasLeft = false;
    bool HasRight = false;
    for (unsigned AccessIndex : Entry.second) {
      int64_t Offset = Accesses[AccessIndex].ConstantOffset;
      HasZero |= Offset == 0;
      HasLeft |= Offset == -static_cast<int64_t>(ElementBytes);
      HasRight |= Offset == static_cast<int64_t>(ElementBytes);
    }
    if (Entry.second.size() == 3 && HasZero && HasLeft && HasRight) {
      CenterAddress = Entry.first;
      break;
    }
  }
  if (!CenterAddress)
    return std::nullopt;

  Value *CenterStreamBase =
      stripSingleIndexGEP(CenterAddress, Induction);
  if (!CenterStreamBase)
    return std::nullopt;

  DenseMap<Value *, unsigned> StreamByBase;
  SmallVector<StreamInfo, 5> Streams;
  for (LoadAccess &Access : Accesses) {
    Value *StreamBase =
        stripSingleIndexGEP(Access.ConstantBase, Induction);
    if (!StreamBase)
      return std::nullopt;

    auto Existing = StreamByBase.find(StreamBase);
    if (Existing != StreamByBase.end()) {
      Streams[Existing->second].Loads.push_back(Access.Load);
      continue;
    }

    StreamInfo Stream;
    Stream.Kind = StreamKind::CurrentRow;
    Stream.Base = StreamBase;
    Stream.RepresentativePointer = Access.Pointer;
    Stream.Address = SE.getSCEV(Access.Pointer);
    Stream.Loads.push_back(Access.Load);
    StreamByBase[StreamBase] = Streams.size();
    Streams.push_back(std::move(Stream));
  }

  auto CenterIt = StreamByBase.find(CenterStreamBase);
  if (CenterIt == StreamByBase.end() ||
      Streams[CenterIt->second].Loads.size() != 3)
    return std::nullopt;
  Streams[CenterIt->second].Kind = StreamKind::CurrentRow;

  SmallVector<OffsetStream, 4> NeighborStreams;
  for (unsigned I = 0; I < Streams.size(); ++I) {
    if (I == CenterIt->second)
      continue;

    auto *GEP = dyn_cast<GetElementPtrInst>(Streams[I].Base);
    if (!GEP || GEP->getNumIndices() != 1 ||
        GEP->getPointerOperand() != CenterStreamBase)
      return std::nullopt;

    Value *Index = GEP->idx_begin()->get();
    NeighborStreams.push_back({SE.getSCEV(Index), I});
  }

  if (NeighborStreams.size() != 2 && NeighborStreams.size() != 4)
    return std::nullopt;

  SmallPtrSet<const SCEV *, 4> Classified;
  unsigned RowPairs = 0;
  unsigned PlanePairs = 0;

  for (unsigned I = 0; I < NeighborStreams.size(); ++I) {
    if (Classified.contains(NeighborStreams[I].Offset))
      continue;

    unsigned PairIndex = NeighborStreams.size();
    for (unsigned J = I + 1; J < NeighborStreams.size(); ++J) {
      if (!Classified.contains(NeighborStreams[J].Offset) &&
          areOpposite(NeighborStreams[I].Offset,
                      NeighborStreams[J].Offset, SE)) {
        PairIndex = J;
        break;
      }
    }
    if (PairIndex == NeighborStreams.size())
      return std::nullopt;

    OffsetStream &A = NeighborStreams[I];
    OffsetStream &B = NeighborStreams[PairIndex];
    bool ANegative = containsMinusOne(A.Offset);
    bool BNegative = containsMinusOne(B.Offset);
    if (ANegative == BNegative)
      return std::nullopt;

    OffsetStream &Negative = ANegative ? A : B;
    OffsetStream &Positive = ANegative ? B : A;
    bool Plane = isPlaneMagnitude(Positive.Offset);

    Streams[Negative.StreamIndex].Kind =
        Plane ? StreamKind::FrontPlane : StreamKind::NorthRow;
    Streams[Positive.StreamIndex].Kind =
        Plane ? StreamKind::BackPlane : StreamKind::SouthRow;
    if (Plane)
      ++PlanePairs;
    else
      ++RowPairs;
    Classified.insert(A.Offset);
    Classified.insert(B.Offset);
  }

  StencilInfo Result;
  Result.InnerLoop = &L;
  Result.Induction = Induction;
  Result.Predicate = Predicate;
  Result.VectorStep = StepCall;
  Result.LogicalLoadCount = MaskedLoads.size();
  Result.Streams = std::move(Streams);

  if (MaskedLoads.size() == 5 && Result.Streams.size() == 3 &&
      RowPairs == 1 && PlanePairs == 0) {
    Result.Kind = StencilKind::Stencil2D5P;
    return Result;
  }
  if (MaskedLoads.size() == 7 && Result.Streams.size() == 5 &&
      RowPairs == 1 && PlanePairs == 1) {
    Result.Kind = StencilKind::Stencil3D7P;
    return Result;
  }
  return std::nullopt;
}

} // namespace

SmallVector<StencilInfo, 2>
analyzeStencilFunction(Function &F, LoopInfo &LI, ScalarEvolution &SE,
                       DominatorTree &DT) {
  SmallVector<Loop *, 4> InnermostLoops;
  for (Loop *L : LI)
    collectInnermostLoops(*L, InnermostLoops);

  SmallVector<StencilInfo, 2> Results;
  for (Loop *L : InnermostLoops) {
    if (std::optional<StencilInfo> Info =
            analyzeInnerLoop(F, *L, SE, DT))
      Results.push_back(std::move(*Info));
  }
  return Results;
}

const char *toString(StencilKind Kind) {
  switch (Kind) {
  case StencilKind::Stencil2D5P:
    return "2D5P";
  case StencilKind::Stencil3D7P:
    return "3D7P";
  }
  return "unknown";
}

const char *toString(StreamKind Kind) {
  switch (Kind) {
  case StreamKind::CurrentRow:
    return "current-row";
  case StreamKind::NorthRow:
    return "north-row";
  case StreamKind::SouthRow:
    return "south-row";
  case StreamKind::FrontPlane:
    return "front-plane";
  case StreamKind::BackPlane:
    return "back-plane";
  }
  return "unknown";
}

} // namespace sme1
