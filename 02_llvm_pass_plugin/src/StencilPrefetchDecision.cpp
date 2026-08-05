#include "StencilPrefetchDecision.h"

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/IntrinsicsAArch64.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/raw_ostream.h"

#include <algorithm>
#include <cstdint>
#include <limits>

using namespace llvm;

namespace sme1 {
namespace {

struct Candidate {
  PrefetchDecision Decision;
  unsigned Priority = 0;
};

bool hasNamePrefix(const CallBase &Call, StringRef Prefix) {
  const Function *Callee = Call.getCalledFunction();
  return Callee && Callee->getName().starts_with(Prefix);
}

unsigned divideCeil(unsigned Numerator, unsigned Denominator) {
  return (Numerator + Denominator - 1) / Denominator;
}

uint64_t divideCeil(uint64_t Numerator, uint64_t Denominator) {
  return (Numerator + Denominator - 1) / Denominator;
}

bool isRowStream(StreamKind Kind) {
  return Kind == StreamKind::RowNeighbor;
}

bool isPlaneStream(StreamKind Kind) {
  return Kind == StreamKind::PlaneNeighbor;
}

bool is1D(StencilKind Kind) { return Kind == StencilKind::Stencil1D3P; }

bool is2D(StencilKind Kind) {
  return Kind == StencilKind::Stencil2D5P ||
         Kind == StencilKind::Stencil2D9P;
}

bool is3D(StencilKind Kind) { return !is1D(Kind) && !is2D(Kind); }

unsigned distanceOverride(const TargetPrefetchProfile &Profile,
                          StreamKind Stream, CacheLevel Level) {
  if (Stream == StreamKind::CurrentRow)
    return Profile.CurrentL1Distance;
  if (Stream == StreamKind::RowNeighbor)
    return Profile.RowL1Distance;
  return Level == CacheLevel::L1 ? Profile.PlaneL1Distance
                                 : Profile.PlaneL2Distance;
}

unsigned policyOverride(const TargetPrefetchProfile &Profile,
                        StreamKind Stream, CacheLevel Level) {
  if (Stream == StreamKind::CurrentRow)
    return Profile.CurrentL1Policy;
  if (Stream == StreamKind::RowNeighbor)
    return Profile.RowL1Policy;
  return Level == CacheLevel::L1 ? Profile.PlaneL1Policy
                                 : Profile.PlaneL2Policy;
}

unsigned candidatePriority(StencilKind Stencil, StreamKind Stream,
                           CacheLevel Level) {
  if (is1D(Stencil))
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
  return is3D(Kind) ? Profile.UsefulCycles3D : Profile.UsefulCycles2D;
}

unsigned estimatedTripCount(const StencilInfo &Stencil, ScalarEvolution &SE,
                            const TargetPrefetchProfile &Profile) {
  unsigned TripCount = SE.getSmallConstantTripCount(Stencil.InnerLoop);
  if (TripCount != 0)
    return TripCount;

  auto *WhileLo = dyn_cast<CallBase>(Stencil.Predicate);
  auto *Induction = dyn_cast<PHINode>(Stencil.Induction);
  BasicBlock *Preheader = Stencil.InnerLoop->getLoopPreheader();
  if (!WhileLo || WhileLo->arg_size() < 2 || !Induction || !Preheader)
    return 0;

  auto *Upper = dyn_cast<ConstantInt>(WhileLo->getArgOperand(1));
  auto *Start =
      dyn_cast<ConstantInt>(Induction->getIncomingValueForBlock(Preheader));
  if (!Upper || !Start || Upper->getValue().ule(Start->getValue()))
    return 0;

  uint64_t ElementsPerVector =
      std::max<uint64_t>(1, Profile.AssumedStreamingVLBytes /
                                 std::max(1U, Stencil.ElementBytes));
  uint64_t Span = Upper->getZExtValue() - Start->getZExtValue();
  uint64_t Estimated = divideCeil(Span, ElementsPerVector);
  return static_cast<unsigned>(
      std::min<uint64_t>(Estimated, std::numeric_limits<unsigned>::max()));
}

PrefetchDecision makeDecision(const StencilInfo &Stencil,
                              const StreamInfo &Stream, CacheLevel Level,
                              ScalarEvolution &SE,
                              const TargetPrefetchProfile &Profile) {
  PrefetchDecision Decision;
  Decision.Stream = &Stream;
  Decision.Level = Level;

  unsigned Cycles = std::max(1U, usefulCycles(Profile, Stencil.Kind));
  unsigned RawDistance = distanceOverride(Profile, Stream.Kind, Level);
  if (RawDistance == 0)
    RawDistance = divideCeil(latencyFor(Profile, Level), Cycles);
  unsigned TripCount = estimatedTripCount(Stencil, SE, Profile);
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
  // Physical-stream deduplication groups loads that consume the same advancing
  // address stream. Multiple grouped loads are direct reuse evidence available
  // in LLVM IR; a row or plane byte size is neither required nor guessed.
  Decision.ReuseCount = std::max<unsigned>(1, Stream.Loads.size());
  Decision.Policy = Decision.ReuseCount > 1 ? LocalityPolicy::Keep
                                             : LocalityPolicy::Stream;
  if (isPlaneStream(Stream.Kind) && Level == CacheLevel::L1)
    Decision.Policy = LocalityPolicy::Stream;
  unsigned PolicyOverride = policyOverride(Profile, Stream.Kind, Level);
  if (PolicyOverride == 1)
    Decision.Policy = LocalityPolicy::Keep;
  else if (PolicyOverride == 2)
    Decision.Policy = LocalityPolicy::Stream;

  Decision.HiddenCycles =
      std::min(latencyFor(Profile, Level), Distance * Cycles);
  unsigned ReuseMultiplier =
      100 + 25 * (std::min(Decision.ReuseCount, 4U) - 1);
  Decision.BenefitScore =
      static_cast<uint64_t>(Decision.HiddenCycles) * ReuseMultiplier / 100;

  uint64_t Capacity = std::max<uint64_t>(1, effectiveCapacity(Profile, Level));
  uint64_t PressurePercent = divideCeil(Decision.LiveBytes * 100, Capacity);
  uint64_t LinesPerVector =
      divideCeil(Profile.AssumedStreamingVLBytes, Profile.CacheLineBytes);
  uint64_t CandidateBytes = LinesPerVector * Profile.CacheLineBytes;
  uint64_t BandwidthPercent = divideCeil(
      CandidateBytes * 100,
      std::max<uint64_t>(1, Profile.MaxPrefetchBytesPerIteration));
  Decision.CostScore = Profile.PrefetchIssueCost +
      divideCeil(PressurePercent * Profile.CachePressureWeight, uint64_t{100}) +
      divideCeil(BandwidthPercent * Profile.BandwidthWeight, uint64_t{100});
  if (TripCount == 0)
    Decision.CostScore += Profile.UnknownTripCountPenalty;

  Decision.ProfitScore = static_cast<int64_t>(Decision.BenefitScore) -
                         static_cast<int64_t>(Decision.CostScore);
  Decision.ConfidencePercent = TripCount == 0 ? 70 : 100;
  if (Level == CacheLevel::L2)
    Decision.ConfidencePercent =
        Decision.ConfidencePercent > 10 ? Decision.ConfidencePercent - 10 : 0;
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

const TargetPrefetchProfile &getAppleM5PrefetchProfile() {
  static const TargetPrefetchProfile Profile = [] {
    TargetPrefetchProfile Result;
    Result.Name = "apple-m5";
    Result.UsefulCycles3D = 32;
    return Result;
  }();
  return Profile;
}

SmallVector<PrefetchDecision, 32>
decidePrefetches(const StencilInfo &Stencil, ScalarEvolution &SE,
                 const TargetPrefetchProfile &Profile) {
  SmallVector<Candidate, 32> Candidates;
  for (const StreamInfo &Stream : Stencil.Streams) {
    auto AddCandidate = [&](CacheLevel Level) {
      Candidate C;
      C.Decision = makeDecision(Stencil, Stream, Level, SE, Profile);
      C.Priority = candidatePriority(Stencil.Kind, Stream.Kind, Level);
      Candidates.push_back(C);
    };

    if ((Stream.Kind == StreamKind::CurrentRow && is1D(Stencil.Kind)) ||
        isRowStream(Stream.Kind) || isPlaneStream(Stream.Kind))
      AddCandidate(CacheLevel::L1);
    if (is3D(Stencil.Kind) && isPlaneStream(Stream.Kind))
      AddCandidate(CacheLevel::L2);
  }

  llvm::stable_sort(Candidates, [](const Candidate &A, const Candidate &B) {
    if (A.Decision.ProfitScore != B.Decision.ProfitScore)
      return A.Decision.ProfitScore > B.Decision.ProfitScore;
    if (A.Decision.ConfidencePercent != B.Decision.ConfidencePercent)
      return A.Decision.ConfidencePercent > B.Decision.ConfidencePercent;
    if (A.Priority != B.Priority)
      return A.Priority < B.Priority;
    if (A.Decision.Level != B.Decision.Level)
      return A.Decision.Level < B.Decision.Level;
    return A.Decision.Stream->Kind < B.Decision.Stream->Kind;
  });

  uint64_t FrontierBytes =
      std::max(Profile.CacheLineBytes, Profile.AssumedStreamingVLBytes);
  uint64_t L1Used =
      Stencil.Streams.size() * FrontierBytes;
  uint64_t L2Used = 0;
  uint64_t InstructionCount = 0;
  uint64_t PrefetchBytes = 0;
  uint64_t LinesPerVector =
      divideCeil(Profile.AssumedStreamingVLBytes, Profile.CacheLineBytes);
  SmallPtrSet<const StreamInfo *, 8> AdmittedStreams;

  SmallVector<PrefetchDecision, 32> Results;
  for (Candidate &Candidate : Candidates) {
    PrefetchDecision &Decision = Candidate.Decision;
    if (Decision.Reason == DecisionReason::ShortTripCount) {
      Results.push_back(Decision);
      continue;
    }
    if (Decision.ConfidencePercent < Profile.MinConfidencePercent) {
      Decision.Reason = DecisionReason::LowConfidence;
      Results.push_back(Decision);
      continue;
    }
    if (Decision.ProfitScore < Profile.MinProfitScore) {
      Decision.Reason = DecisionReason::Unprofitable;
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
  auto *TailPredicate = dyn_cast<CallBase>(Stencil.Predicate);
  if (!FirstLoad || !TailPredicate || TailPredicate->arg_size() < 2)
    return false;

  (void)LI;
  Module *M = FirstLoad->getModule();
  Function *Prefetch =
      Intrinsic::getDeclaration(M, Intrinsic::aarch64_prefetch);
  Type *IndexType = Stencil.Induction->getType();
  auto *LoadVectorType = dyn_cast<VectorType>(FirstLoad->getType());
  if (!LoadVectorType)
    return false;
  Type *ElementType = LoadVectorType->getElementType();
  DenseMap<unsigned, std::pair<Value *, Value *>> GuardsByDistance;
  bool Changed = false;

  for (const PrefetchDecision &Decision : Decisions) {
    if (!Decision.Enable || Decision.Stream->Loads.empty())
      continue;

    // Address calculations for different rows/planes are not guaranteed to
    // dominate the first masked load in the loop. Anchor each prefetch at the
    // first load of its own stream so all operands are available.
    CallBase *AnchorLoad = Decision.Stream->Loads.front();
    for (CallBase *Load : Decision.Stream->Loads) {
      if (Load->getArgOperand(0) ==
          Decision.Stream->RepresentativePointer) {
        AnchorLoad = Load;
        break;
      }
    }
    if (auto *PointerInst =
            dyn_cast<Instruction>(Decision.Stream->RepresentativePointer)) {
      if (!DT.dominates(PointerInst, AnchorLoad)) {
        errs() << "StencilPrefetchInsertReject: function="
               << AnchorLoad->getFunction()->getName()
               << " stream=" << toString(Decision.Stream->Kind)
               << " reason=address-does-not-dominate-anchor\n";
        continue;
      }
    }

    Value *ScaledStep = nullptr;
    Value *InBounds = nullptr;
    auto ExistingGuard = GuardsByDistance.find(Decision.DistanceIterations);
    if (ExistingGuard != GuardsByDistance.end() &&
        DT.dominates(cast<Instruction>(ExistingGuard->second.second),
                     AnchorLoad)) {
      ScaledStep = ExistingGuard->second.first;
      InBounds = ExistingGuard->second.second;
    } else {
      auto IsAvailableAt = [&](Value *V, Instruction *At) {
        auto *Definition = dyn_cast<Instruction>(V);
        return !Definition || DT.dominates(Definition, At);
      };
      Instruction *GuardAnchor = AnchorLoad;
      if (IsAvailableAt(Stencil.VectorStep, FirstLoad) &&
          IsAvailableAt(TailPredicate->getArgOperand(0), FirstLoad) &&
          IsAvailableAt(TailPredicate->getArgOperand(1), FirstLoad))
        GuardAnchor = FirstLoad;

      IRBuilder<> GuardBuilder(GuardAnchor);
      ScaledStep = GuardBuilder.CreateMul(
          Stencil.VectorStep,
          ConstantInt::get(IndexType, Decision.DistanceIterations),
          "prefetch.step");
      bool IsSignedTail =
          hasNamePrefix(*TailPredicate, "llvm.aarch64.sve.whilelt.");
      Type *TailIndexType = TailPredicate->getArgOperand(0)->getType();
      Value *CompareStep = ScaledStep;
      if (CompareStep->getType() != TailIndexType)
        CompareStep = GuardBuilder.CreateZExtOrTrunc(
            CompareStep, TailIndexType, "prefetch.compare.step");
      Value *CompareX = GuardBuilder.CreateAdd(
          TailPredicate->getArgOperand(0), CompareStep, "prefetch.compare.x");
      InBounds = IsSignedTail
                     ? GuardBuilder.CreateICmpSLT(
                           CompareX, TailPredicate->getArgOperand(1),
                           "prefetch.in.range")
                     : GuardBuilder.CreateICmpULT(
                           CompareX, TailPredicate->getArgOperand(1),
                           "prefetch.in.range");
      GuardsByDistance[Decision.DistanceIterations] =
          std::make_pair(ScaledStep, InBounds);
    }

    IRBuilder<> PrefetchBuilder(AnchorLoad);

    Value *FutureAddress = PrefetchBuilder.CreateGEP(
        ElementType, Decision.Stream->RepresentativePointer, ScaledStep,
        "prefetch.addr");
    Value *Address = PrefetchBuilder.CreateSelect(
        InBounds, FutureAddress, Decision.Stream->RepresentativePointer,
        "prefetch.safe.addr");
    PrefetchBuilder.CreateCall(
        Prefetch,
        {Address, PrefetchBuilder.getInt32(0),
         PrefetchBuilder.getInt32(static_cast<unsigned>(Decision.Level)),
         PrefetchBuilder.getInt32(
             Decision.Policy == LocalityPolicy::Stream ? 1 : 0),
         PrefetchBuilder.getInt32(1)});
    errs() << "StencilPrefetchInsert: function="
           << AnchorLoad->getFunction()->getName()
           << " stream=" << toString(Decision.Stream->Kind)
           << " distance=" << Decision.DistanceIterations
           << " level=" << toString(Decision.Level)
           << " policy=" << toString(Decision.Policy)
           << " guard=branchless-select\n";
    Changed = true;
  }
  return Changed;
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
  case DecisionReason::LowConfidence:
    return "LowConfidence";
  case DecisionReason::Unprofitable:
    return "Unprofitable";
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
