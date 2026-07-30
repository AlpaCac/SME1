#ifndef SME1_STENCIL_PREFETCH_DECISION_H
#define SME1_STENCIL_PREFETCH_DECISION_H

#include "StencilAnalysis.h"

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/SmallVector.h"

#include <cstdint>

namespace llvm {
class DominatorTree;
class LoopInfo;
class ScalarEvolution;
} // namespace llvm

namespace sme1 {

enum class CacheLevel {
  L1,
  L2,
  L3,
};

enum class LocalityPolicy {
  Keep,
  Stream,
};

enum class DecisionReason {
  Admitted,
  ShortTripCount,
  CapacityReject,
  StreamBudgetReject,
  InstructionBudgetReject,
  BandwidthReject,
};

struct TargetPrefetchProfile {
  const char *Name = "generic-sme";
  uint64_t CacheLineBytes = 64;
  uint64_t L1CapacityBytes = 64 * 1024;
  uint64_t L2CapacityBytes = 1024 * 1024;
  unsigned L1PrefetchLatencyCycles = 32;
  unsigned L2PrefetchLatencyCycles = 96;
  unsigned MemoryLatencyCycles = 240;
  unsigned MaxPrefetchStreams = 5;
  unsigned MaxPrefetchInstructionsPerIteration = 8;
  uint64_t MaxPrefetchBytesPerIteration = 512;
  unsigned L1CapacityPercent = 60;
  unsigned L2CapacityPercent = 60;
  uint64_t AssumedStreamingVLBytes = 64;
  uint64_t ExpectedRowBytes = 4096;
  uint64_t ExpectedPlaneOrTileBytes = 128 * 1024;
  unsigned UsefulCycles2D = 8;
  unsigned UsefulCycles3D = 10;
  unsigned MaxDistance = 32;
  bool EnableCurrentL1 = true;
  bool EnableRowL1 = true;
  bool EnablePlaneL1 = true;
  bool EnablePlaneL2 = true;
};

struct PrefetchDecision {
  const StreamInfo *Stream = nullptr;
  bool Enable = false;
  unsigned DistanceIterations = 0;
  CacheLevel Level = CacheLevel::L1;
  LocalityPolicy Policy = LocalityPolicy::Stream;
  DecisionReason Reason = DecisionReason::Admitted;
  uint64_t LiveBytes = 0;
  unsigned ReuseCount = 0;
  uint64_t ReuseDistanceBytes = 0;
};

const TargetPrefetchProfile &getDefaultPrefetchProfile();
const TargetPrefetchProfile &getAppleM5PrefetchProfile();

llvm::SmallVector<PrefetchDecision, 32>
decidePrefetches(const StencilInfo &Stencil, llvm::ScalarEvolution &SE,
                 const TargetPrefetchProfile &Profile);

bool insertPrefetches(const StencilInfo &Stencil,
                      llvm::ArrayRef<PrefetchDecision> Decisions,
                      llvm::DominatorTree &DT, llvm::LoopInfo &LI);

const char *toString(CacheLevel Level);
const char *toString(LocalityPolicy Policy);
const char *toString(DecisionReason Reason);

} // namespace sme1

#endif
