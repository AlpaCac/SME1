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

using namespace llvm;

namespace {

struct LoopSummary {
  unsigned Total = 0;
  unsigned Innermost = 0;
  unsigned ComputableTripCounts = 0;
};

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
    if (F.isDeclaration() || !F.getName().starts_with("stencil_"))
      return PreservedAnalyses::all();

    LoopInfo &LI = FAM.getResult<LoopAnalysis>(F);
    ScalarEvolution &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);
    DominatorTree &DT = FAM.getResult<DominatorTreeAnalysis>(F);
    TargetTransformInfo &TTI = FAM.getResult<TargetIRAnalysis>(F);
    AssumptionCache &AC = FAM.getResult<AssumptionAnalysis>(F);

    LoopSummary Summary;
    for (const Loop *L : LI)
      summarizeLoop(*L, SE, Summary);

    // Step 2 only establishes the pass boundary and required analyses.
    // Stencil recognition and IR mutation start in later steps.
    (void)TTI;
    (void)AC;
    errs() << "StencilPrefetchPass: function=" << F.getName()
           << " loops=" << Summary.Total
           << " innermost-loops=" << Summary.Innermost
           << " computable-trip-counts=" << Summary.ComputableTripCounts
           << " dom-tree-root=" << (DT.getRootNode() != nullptr ? "yes" : "no")
           << " analyses=LoopInfo,ScalarEvolution,DominatorTree,"
              "TargetIR,AssumptionCache\n";

    return PreservedAnalyses::all();
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
