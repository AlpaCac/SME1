#include "StencilPrefetchDecision.h"

#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Analysis/DomTreeUpdater.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsAArch64.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"

#include <algorithm>
#include <cstdint>

using namespace llvm;

namespace sme1 {
namespace {

struct Candidate {
  PrefetchDecision Decision;
  unsigned Priority = 0;
};

unsigned divideCeil(unsigned Numerator, unsigned Denominator) {
  return (Numerator + Denominator - 1) / Denominator;
}

uint64_t divideCeil(uint64_t Numerator, uint64_t Denominator) {
  return (Numerator + Denominator - 1) / Denominator;
}

bool isRowStream(StreamKind Kind) {
  return Kind == StreamKind::NorthRow || Kind == StreamKind::SouthRow;
}

bool isPlaneStream(StreamKind Kind) {
  return Kind == StreamKind::FrontPlane || Kind == StreamKind::BackPlane;
}

unsigned candidatePriority(StencilKind Stencil, StreamKind Stream,
                           CacheLevel Level) {
  if (Stencil == StencilKind::Stencil2D5P)
    return 0;
  if (isPlaneStream(Stream) && Level == CacheLevel::L1)
    return 0;
  if (isRowStream(Stream))
    return 1;
  return 2;
}

uint64_t effectiveCapacity(const TargetPrefetchProfile &Profile,
                           CacheLevel Level) {
  if (Level == CacheLevel::L1)
    return Profile.L1CapacityBytes * Profile.L1CapacityPercent / 100;
  if (Level == CacheLevel::L2)
    return Profile.L2CapacityBytes * Profile.L2CapacityPercent / 100;
  return 0;
}

unsigned latencyFor(const TargetPrefetchProfile &Profile, CacheLevel Level) {
  if (Level == CacheLevel::L1)
    return Profile.L1PrefetchLatencyCycles;
  if (Level == CacheLevel::L2)
    return Profile.L2PrefetchLatencyCycles;
  return Profile.MemoryLatencyCycles;
}

unsigned usefulCycles(const TargetPrefetchProfile &Profile,
                      StencilKind Kind) {
  return Kind == StencilKind::Stencil2D5P ? Profile.UsefulCycles2D
                                          : Profile.UsefulCycles3D;
}

PrefetchDecision makeDecision(const StencilInfo &Stencil,
                              const StreamInfo &Stream, CacheLevel Level,
                              ScalarEvolution &SE,
                              const TargetPrefetchProfile &Profile) {
  PrefetchDecision Decision;
  Decision.Stream = &Stream;
  Decision.Level = Level;

  unsigned Cycles = std::max(1U, usefulCycles(Profile, Stencil.Kind));
  unsigned RawDistance = divideCeil(latencyFor(Profile, Level), Cycles);
  unsigned TripCount = SE.getSmallConstantTripCount(Stencil.InnerLoop);
  if (TripCount != 0 && TripCount <= 2 * RawDistance) {
    Decision.Reason = DecisionReason::ShortTripCount;
    return Decision;
  }

  unsigned MaxDistance =
      TripCount == 0 ? Profile.MaxDistance : std::max(1U, TripCount / 2);
  unsigned MinDistance = Level == CacheLevel::L1 ? 1 : 2;
  unsigned Distance =
      std::clamp(RawDistance, MinDistance, MaxDistance);
  uint64_t LineIterations =
      divideCeil(Profile.CacheLineBytes, Profile.AssumedStreamingVLBytes);
  Distance = static_cast<unsigned>(
      divideCeil(static_cast<uint64_t>(Distance), LineIterations) *
      LineIterations);

  Decision.DistanceIterations = Distance;
  Decision.LiveBytes = Distance * Profile.AssumedStreamingVLBytes;
  Decision.ReuseCount = 3;
  if (isRowStream(Stream.Kind)) {
    uint64_t RowMultiplier =
        Stencil.Kind == StencilKind::Stencil2D5P ? 3 : 5;
    Decision.ReuseDistanceBytes =
        RowMultiplier * Profile.ExpectedRowBytes;
  } else {
    Decision.ReuseDistanceBytes = Profile.ExpectedPlaneOrTileBytes;
  }

  bool ReuseFits =
      Decision.ReuseCount > 1 &&
      Decision.ReuseDistanceBytes <= effectiveCapacity(Profile, Level);
  Decision.Policy = ReuseFits ? LocalityPolicy::Keep
                              : LocalityPolicy::Stream;
  if (isPlaneStream(Stream.Kind) && Level == CacheLevel::L1)
    Decision.Policy = LocalityPolicy::Stream;
  return Decision;
}

CallBase *findFirstLoad(const StencilInfo &Stencil) {
  CallBase *First = nullptr;
  for (const StreamInfo &Stream : Stencil.Streams) {
    for (CallBase *Load : Stream.Loads) {
      if (!First ||
          (Load->getParent() == First->getParent() && Load->comesBefore(First)))
        First = Load;
    }
  }
  return First;
}

} // namespace

const TargetPrefetchProfile &getDefaultPrefetchProfile() {
  static const TargetPrefetchProfile Profile;
  return Profile;
}

SmallVector<PrefetchDecision, 8>
decidePrefetches(const StencilInfo &Stencil, ScalarEvolution &SE,
                 const TargetPrefetchProfile &Profile) {
  SmallVector<Candidate, 8> Candidates;
  for (const StreamInfo &Stream : Stencil.Streams) {
    if (Stream.Kind == StreamKind::CurrentRow)
      continue;

    auto AddCandidate = [&](CacheLevel Level) {
      Candidate C;
      C.Decision = makeDecision(Stencil, Stream, Level, SE, Profile);
      C.Priority = candidatePriority(Stencil.Kind, Stream.Kind, Level);
      Candidates.push_back(C);
    };

    AddCandidate(CacheLevel::L1);
    if (Stencil.Kind == StencilKind::Stencil3D7P &&
        isPlaneStream(Stream.Kind))
      AddCandidate(CacheLevel::L2);
  }

  llvm::stable_sort(Candidates, [](const Candidate &A, const Candidate &B) {
    if (A.Priority != B.Priority)
      return A.Priority < B.Priority;
    if (A.Decision.Level != B.Decision.Level)
      return A.Decision.Level < B.Decision.Level;
    return A.Decision.Stream->Kind < B.Decision.Stream->Kind;
  });

  uint64_t FrontierBytes =
      std::max(Profile.CacheLineBytes, Profile.AssumedStreamingVLBytes);
  uint64_t L1Used =
      (Stencil.Kind == StencilKind::Stencil2D5P ? 3 : 5) * FrontierBytes;
  uint64_t L2Used =
      Stencil.Kind == StencilKind::Stencil3D7P
          ? 3 * Profile.ExpectedPlaneOrTileBytes
          : 0;
  uint64_t InstructionCount = 0;
  uint64_t PrefetchBytes = 0;
  uint64_t LinesPerVector =
      divideCeil(Profile.AssumedStreamingVLBytes, Profile.CacheLineBytes);
  SmallPtrSet<const StreamInfo *, 8> AdmittedStreams;

  SmallVector<PrefetchDecision, 8> Results;
  for (Candidate &Candidate : Candidates) {
    PrefetchDecision &Decision = Candidate.Decision;
    if (Decision.Reason == DecisionReason::ShortTripCount) {
      Results.push_back(Decision);
      continue;
    }

    uint64_t &LevelUsed =
        Decision.Level == CacheLevel::L1 ? L1Used : L2Used;
    if (LevelUsed + Decision.LiveBytes >
        effectiveCapacity(Profile, Decision.Level)) {
      Decision.Reason = DecisionReason::CapacityReject;
      Results.push_back(Decision);
      continue;
    }

    bool NewStream = !AdmittedStreams.contains(Decision.Stream);
    if (NewStream &&
        AdmittedStreams.size() + 1 > Profile.MaxPrefetchStreams) {
      Decision.Reason = DecisionReason::StreamBudgetReject;
      Results.push_back(Decision);
      continue;
    }
    if (InstructionCount + LinesPerVector >
        Profile.MaxPrefetchInstructionsPerIteration) {
      Decision.Reason = DecisionReason::InstructionBudgetReject;
      Results.push_back(Decision);
      continue;
    }
    uint64_t CandidateBytes = LinesPerVector * Profile.CacheLineBytes;
    if (PrefetchBytes + CandidateBytes >
        Profile.MaxPrefetchBytesPerIteration) {
      Decision.Reason = DecisionReason::BandwidthReject;
      Results.push_back(Decision);
      continue;
    }

    Decision.Enable = true;
    Decision.Reason = DecisionReason::Admitted;
    LevelUsed += Decision.LiveBytes;
    InstructionCount += LinesPerVector;
    PrefetchBytes += CandidateBytes;
    AdmittedStreams.insert(Decision.Stream);
    Results.push_back(Decision);
  }
  return Results;
}

bool insertPrefetches(const StencilInfo &Stencil,
                      ArrayRef<PrefetchDecision> Decisions,
                      DominatorTree &DT, LoopInfo &LI) {
  CallBase *FirstLoad = findFirstLoad(Stencil);
  auto *WhileLo = dyn_cast<CallBase>(Stencil.Predicate);
  if (!FirstLoad || !WhileLo || WhileLo->arg_size() < 2)
    return false;

  SmallVector<unsigned, 4> Distances;
  for (const PrefetchDecision &Decision : Decisions) {
    if (!Decision.Enable)
      continue;
    if (auto *BaseInst = dyn_cast<Instruction>(Decision.Stream->Base)) {
      if (!DT.dominates(BaseInst, FirstLoad))
        return false;
    }
    if (!llvm::is_contained(Distances, Decision.DistanceIterations))
      Distances.push_back(Decision.DistanceIterations);
  }
  llvm::sort(Distances);
  if (Distances.empty())
    return false;

  DomTreeUpdater DTU(DT, DomTreeUpdater::UpdateStrategy::Eager);
  Module *M = FirstLoad->getModule();
  Function *Prefetch =
      Intrinsic::getDeclaration(M, Intrinsic::aarch64_prefetch);
  Type *IndexType = Stencil.Induction->getType();
  Type *FloatType = Type::getFloatTy(M->getContext());

  for (unsigned Distance : Distances) {
    IRBuilder<> HeadBuilder(FirstLoad);
    Value *ScaledStep = HeadBuilder.CreateMul(
        Stencil.VectorStep, ConstantInt::get(IndexType, Distance),
        "prefetch.step");
    Value *FutureX = HeadBuilder.CreateAdd(
        Stencil.Induction, ScaledStep, "prefetch.future.x");
    Value *InBounds = HeadBuilder.CreateICmpULT(
        FutureX, WhileLo->getArgOperand(1), "prefetch.in.range");

    Instruction *ThenTerm = SplitBlockAndInsertIfThen(
        InBounds, FirstLoad, false, nullptr, &DTU, &LI);
    IRBuilder<> PrefetchBuilder(ThenTerm);

    for (const PrefetchDecision &Decision : Decisions) {
      if (!Decision.Enable || Decision.DistanceIterations != Distance)
        continue;

      Value *Address = PrefetchBuilder.CreateGEP(
          FloatType, Decision.Stream->Base, FutureX, "prefetch.addr");
      PrefetchBuilder.CreateCall(
          Prefetch,
          {Address, PrefetchBuilder.getInt32(0),
           PrefetchBuilder.getInt32(
               static_cast<unsigned>(Decision.Level)),
           PrefetchBuilder.getInt32(
               Decision.Policy == LocalityPolicy::Stream ? 1 : 0),
           PrefetchBuilder.getInt32(1)});
    }
  }
  DTU.flush();
  return true;
}

const char *toString(CacheLevel Level) {
  switch (Level) {
  case CacheLevel::L1:
    return "L1";
  case CacheLevel::L2:
    return "L2";
  case CacheLevel::L3:
    return "L3";
  }
  return "unknown";
}

const char *toString(LocalityPolicy Policy) {
  return Policy == LocalityPolicy::Keep ? "KEEP" : "STRM";
}

const char *toString(DecisionReason Reason) {
  switch (Reason) {
  case DecisionReason::Admitted:
    return "Admitted";
  case DecisionReason::ShortTripCount:
    return "ShortTripCount";
  case DecisionReason::CapacityReject:
    return "CapacityReject";
  case DecisionReason::StreamBudgetReject:
    return "StreamBudgetReject";
  case DecisionReason::InstructionBudgetReject:
    return "InstructionBudgetReject";
  case DecisionReason::BandwidthReject:
    return "BandwidthReject";
  }
  return "unknown";
}

} // namespace sme1
