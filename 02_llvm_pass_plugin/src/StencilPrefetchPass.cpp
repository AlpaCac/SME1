#include "StencilAnalysis.h"
#include "StencilPrefetchDecision.h"

#include "llvm/Analysis/AssumptionCache.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

#include <cstdlib>

using namespace llvm;

namespace {

struct LoopSummary {
  unsigned Total = 0;
  unsigned Innermost = 0;
  unsigned ComputableTripCounts = 0;
};

bool hasAArch64Prefetch(const Function &F) {
  for (const BasicBlock &BB : F) {
    for (const Instruction &I : BB) {
      const auto *Call = dyn_cast<CallBase>(&I);
      const Function *Callee = Call ? Call->getCalledFunction() : nullptr;
      if (Callee && Callee->getName() == "llvm.aarch64.prefetch")
        return true;
    }
  }
  return false;
}

template <typename T>
bool applyUnsignedEnvironmentOverride(const char *Name, T &Value) {
  const char *Raw = std::getenv(Name);
  if (!Raw)
    return false;

  T Parsed = 0;
  if (StringRef(Raw).getAsInteger(10, Parsed)) {
    errs() << "StencilPrefetchProfile: invalid " << Name << "=" << Raw
           << "\n";
    return false;
  }
  Value = Parsed;
  return true;
}

sme1::TargetPrefetchProfile getActiveProfile() {
  const char *RequestedProfile = std::getenv("SME_PREFETCH_PROFILE");
  sme1::TargetPrefetchProfile Profile;
  if (!RequestedProfile || StringRef(RequestedProfile) == "generic-sme") {
    Profile = sme1::getDefaultPrefetchProfile();
  } else if (StringRef(RequestedProfile) == "apple-m5") {
    Profile = sme1::getAppleM5PrefetchProfile();
  } else {
    errs() << "StencilPrefetchProfile: unknown SME_PREFETCH_PROFILE="
           << RequestedProfile << ", using generic-sme\n";
    Profile = sme1::getDefaultPrefetchProfile();
  }
  bool Overridden = false;
  Overridden |= applyUnsignedEnvironmentOverride(
      "SME_PREFETCH_MAX_STREAMS", Profile.MaxPrefetchStreams);
  Overridden |= applyUnsignedEnvironmentOverride(
      "SME_PREFETCH_MAX_INSTRUCTIONS",
      Profile.MaxPrefetchInstructionsPerIteration);
  Overridden |= applyUnsignedEnvironmentOverride(
      "SME_PREFETCH_MAX_BYTES", Profile.MaxPrefetchBytesPerIteration);
  Overridden |= applyUnsignedEnvironmentOverride(
      "SME_PREFETCH_L1_CAPACITY_BYTES", Profile.L1CapacityBytes);
  Overridden |= applyUnsignedEnvironmentOverride(
      "SME_PREFETCH_L2_CAPACITY_BYTES", Profile.L2CapacityBytes);
  Overridden |= applyUnsignedEnvironmentOverride(
      "SME_PREFETCH_USEFUL_CYCLES_2D", Profile.UsefulCycles2D);
  Overridden |= applyUnsignedEnvironmentOverride(
      "SME_PREFETCH_USEFUL_CYCLES_3D", Profile.UsefulCycles3D);

  unsigned Toggle = Profile.EnableCurrentL1;
  if (applyUnsignedEnvironmentOverride("SME_PREFETCH_ENABLE_CURRENT_L1",
                                       Toggle)) {
    Profile.EnableCurrentL1 = Toggle != 0;
    Overridden = true;
  }
  Toggle = Profile.EnableRowL1;
  if (applyUnsignedEnvironmentOverride("SME_PREFETCH_ENABLE_ROW_L1", Toggle)) {
    Profile.EnableRowL1 = Toggle != 0;
    Overridden = true;
  }
  Toggle = Profile.EnablePlaneL1;
  if (applyUnsignedEnvironmentOverride("SME_PREFETCH_ENABLE_PLANE_L1",
                                       Toggle)) {
    Profile.EnablePlaneL1 = Toggle != 0;
    Overridden = true;
  }
  Toggle = Profile.EnablePlaneL2;
  if (applyUnsignedEnvironmentOverride("SME_PREFETCH_ENABLE_PLANE_L2",
                                       Toggle)) {
    Profile.EnablePlaneL2 = Toggle != 0;
    Overridden = true;
  }
  if (Overridden)
    Profile.Name = "environment-override";
  return Profile;
}

void summarizeLoop(const Loop &L, ScalarEvolution &SE, LoopSummary &Summary) {
  ++Summary.Total;
  if (L.isInnermost())
    ++Summary.Innermost;
  if (!isa<SCEVCouldNotCompute>(SE.getBackedgeTakenCount(&L)))
    ++Summary.ComputableTripCounts;

  for (const Loop *SubLoop : L.getSubLoops())
    summarizeLoop(*SubLoop, SE, Summary);
}

class StencilPrefetchPass
    : public PassInfoMixin<StencilPrefetchPass> {
public:
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
    // Step 1 supplies a kernel-only module, so names need not encode which
    // functions are eligible for analysis. This also supports C++ sources
    // whose stencil kernels do not share a single prefix.
    if (F.isDeclaration())
      return PreservedAnalyses::all();
    if (hasAArch64Prefetch(F)) {
      errs() << "StencilPrefetchPass: function=" << F.getName()
             << " status=AlreadyPrefetched\n";
      return PreservedAnalyses::all();
    }

    LoopInfo &LI = FAM.getResult<LoopAnalysis>(F);
    ScalarEvolution &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);
    DominatorTree &DT = FAM.getResult<DominatorTreeAnalysis>(F);
    TargetTransformInfo &TTI = FAM.getResult<TargetIRAnalysis>(F);
    AssumptionCache &AC = FAM.getResult<AssumptionAnalysis>(F);

    LoopSummary Summary;
    for (const Loop *L : LI)
      summarizeLoop(*L, SE, Summary);

    (void)TTI;
    (void)AC;
    errs() << "StencilPrefetchPass: function=" << F.getName()
           << " loops=" << Summary.Total
           << " innermost-loops=" << Summary.Innermost
           << " computable-trip-counts=" << Summary.ComputableTripCounts
           << " dom-tree-root=" << (DT.getRootNode() != nullptr ? "yes" : "no")
           << " analyses=LoopInfo,ScalarEvolution,DominatorTree,"
              "TargetIR,AssumptionCache\n";

    SmallVector<sme1::StencilInfo, 8> Stencils =
        sme1::analyzeStencilFunction(F, LI, SE, DT);
    bool Changed = false;
    const sme1::TargetPrefetchProfile Profile = getActiveProfile();
    for (const sme1::StencilInfo &Stencil : Stencils) {
      errs() << "StencilAnalysis: function=" << F.getName()
             << " kind=" << sme1::toString(Stencil.Kind)
             << " logical-loads=" << Stencil.LogicalLoadCount
             << " physical-streams=" << Stencil.Streams.size()
             << " vector-step=";
      if (const auto *StepCall = dyn_cast<CallBase>(Stencil.VectorStep)) {
        const Function *StepCallee = StepCall->getCalledFunction();
        errs() << (StepCallee ? StepCallee->getName() : "indirect-call");
      } else {
        // LLVM 19 can materialize the scalable step as arithmetic on vscale.
        errs() << *Stencil.VectorStep;
      }
      errs() << " element-bytes=" << Stencil.ElementBytes << " streams=";
      for (unsigned I = 0; I < Stencil.Streams.size(); ++I) {
        if (I != 0)
          errs() << ",";
        const sme1::StreamInfo &Stream = Stencil.Streams[I];
        errs() << sme1::toString(Stream.Kind) << ":"
               << Stream.Loads.size();
      }
      errs() << "\n";

      errs() << "StencilDecisionProfile: function=" << F.getName()
             << " profile=" << Profile.Name
             << " cache-line=" << Profile.CacheLineBytes
             << " assumed-vl=" << Profile.AssumedStreamingVLBytes
             << " row-bytes=" << Profile.ExpectedRowBytes
             << " plane-or-tile-bytes="
             << Profile.ExpectedPlaneOrTileBytes
             << " max-streams=" << Profile.MaxPrefetchStreams
             << " current-l1=" << (Profile.EnableCurrentL1 ? "on" : "off")
             << " row-l1=" << (Profile.EnableRowL1 ? "on" : "off")
             << " plane-l1=" << (Profile.EnablePlaneL1 ? "on" : "off")
             << " plane-l2=" << (Profile.EnablePlaneL2 ? "on" : "off")
             << "\n";

      SmallVector<sme1::PrefetchDecision, 32> Decisions =
          sme1::decidePrefetches(Stencil, SE, Profile);
      for (const sme1::PrefetchDecision &Decision : Decisions) {
        errs() << "StencilDecision: function=" << F.getName()
               << " kind=" << sme1::toString(Stencil.Kind)
               << " stream=" << sme1::toString(Decision.Stream->Kind)
               << " enable=" << (Decision.Enable ? "yes" : "no")
               << " distance=" << Decision.DistanceIterations
               << " level=" << sme1::toString(Decision.Level)
               << " policy=" << sme1::toString(Decision.Policy)
               << " live-bytes=" << Decision.LiveBytes
               << " reuse-count=" << Decision.ReuseCount
               << " reuse-distance=" << Decision.ReuseDistanceBytes
               << " reason=" << sme1::toString(Decision.Reason) << "\n";
      }

      Changed |= sme1::insertPrefetches(Stencil, Decisions, DT, LI);
    }

    return Changed ? PreservedAnalyses::none()
                   : PreservedAnalyses::all();
  }
};

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {
      LLVM_PLUGIN_API_VERSION,
      "StencilPrefetchPass",
      LLVM_VERSION_STRING,
      [](PassBuilder &PB) {
        PB.registerPipelineParsingCallback(
            [](StringRef Name, FunctionPassManager &FPM,
               ArrayRef<PassBuilder::PipelineElement>) {
              if (Name != "stencil-prefetch")
                return false;
              FPM.addPass(StencilPrefetchPass());
              return true;
            });

        PB.registerOptimizerEarlyEPCallback(
            [](ModulePassManager &MPM, OptimizationLevel) {
              FunctionPassManager FPM;
              FPM.addPass(StencilPrefetchPass());
              MPM.addPass(
                  createModuleToFunctionPassAdaptor(std::move(FPM)));
            });
      }};
}
