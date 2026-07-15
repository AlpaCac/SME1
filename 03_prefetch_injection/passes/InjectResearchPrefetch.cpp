//===- InjectResearchPrefetch.cpp ----------------------------------------===//
//
// A research pass for the SME prefetch pipeline.  It recognizes the restricted
// affine GEMM shape produced by step 01 and inserts generic research.prefetch
// operations before the A/B read streams in the kk reduction loop.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/Operation.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Tools/Plugins/PassPlugin.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/Config/llvm-config.h"
#include "llvm/Support/Compiler.h"

#include <optional>

using namespace mlir;

namespace {

struct InjectResearchPrefetchPass
    : public PassWrapper<InjectResearchPrefetchPass,
                         OperationPass<func::FuncOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(InjectResearchPrefetchPass)

  StringRef getArgument() const final { return "inject-research-prefetch"; }

  StringRef getDescription() const final {
    return "Insert research.prefetch ops into the restricted affine GEMM form";
  }

  void getDependentDialects(DialectRegistry &registry) const final {
    registry.insert<affine::AffineDialect, func::FuncDialect,
                    scf::SCFDialect>();
  }

  void runOnOperation() final {
    func::FuncOp func = getOperation();
    if (func.getNumArguments() < 3) {
      func.emitError("expected at least three memref arguments: A, B, C");
      signalPassFailure();
      return;
    }

    bool injected = false;
    func.walk([&](affine::AffineForOp forOp) {
      if (injected || !isReductionCandidate(forOp))
        return;

      scf::IfOp guard = findFirstIfInLoopBody(forOp);
      if (!guard || alreadyHasResearchPrefetch(guard))
        return;

      SmallVector<Value> ivs = collectAncestorInductionVars(forOp);
      if (ivs.size() < 6)
        return;

      insertPrefetchOps(func, guard, ivs);
      injected = true;
    });

    if (!injected) {
      func.emitError("failed to locate the restricted GEMM kk injection point");
      signalPassFailure();
      return;
    }

    OpBuilder builder(func.getContext());
    func->setAttr("prefetch_injected", builder.getStringAttr("true"));
  }

private:
  static scf::IfOp findFirstIfInLoopBody(affine::AffineForOp forOp) {
    Block &body = forOp.getRegion().front();
    for (Operation &op : body.without_terminator()) {
      if (auto ifOp = dyn_cast<scf::IfOp>(&op))
        return ifOp;
    }
    return nullptr;
  }

  static bool isReductionCandidate(affine::AffineForOp forOp) {
    if (forOp.getStepAsInt() != 1)
      return false;
    std::optional<int64_t> upper = forOp.getConstantUpperBound();
    if (!upper || *upper < 64)
      return false;
    scf::IfOp guard = findFirstIfInLoopBody(forOp);
    if (!guard || guard.getThenRegion().empty())
      return false;

    bool hasNestedAffineLoop = false;
    bool hasAffineLoad = false;
    guard.getThenRegion().walk([&](Operation *op) {
      hasNestedAffineLoop |= isa<affine::AffineForOp>(op);
      hasAffineLoad |= isa<affine::AffineLoadOp>(op);
    });
    return hasNestedAffineLoop && hasAffineLoad;
  }

  static bool alreadyHasResearchPrefetch(scf::IfOp guard) {
    bool found = false;
    guard.getThenRegion().walk([&](Operation *op) {
      found |= op->getName().getStringRef() == "research.prefetch";
    });
    return found;
  }

  static SmallVector<Value> collectAncestorInductionVars(affine::AffineForOp op) {
    SmallVector<Value> reversed;
    for (Operation *current = op.getOperation(); current;
         current = current->getParentOp()) {
      if (auto forOp = dyn_cast<affine::AffineForOp>(current))
        reversed.push_back(forOp.getInductionVar());
    }
    SmallVector<Value> ordered;
    for (Value iv : llvm::reverse(reversed))
      ordered.push_back(iv);
    return ordered;
  }

  static void createResearchPrefetch(OpBuilder &builder, Location loc,
                                     StringRef target, Value memref,
                                     ValueRange indices, StringRef priority,
                                     StringRef distance) {
    OperationState state(loc, "research.prefetch");
    SmallVector<Value> operands;
    operands.push_back(memref);
    operands.append(indices.begin(), indices.end());
    state.addOperands(operands);
    state.addAttribute("target", builder.getStringAttr(target));
    state.addAttribute("kind", builder.getStringAttr("read"));
    state.addAttribute("priority", builder.getStringAttr(priority));
    state.addAttribute("cache", builder.getStringAttr("L1"));
    state.addAttribute("locality", builder.getStringAttr("KEEP"));
    state.addAttribute("distance", builder.getStringAttr(distance));
    builder.create(state);
  }

  static void insertPrefetchOps(func::FuncOp func, scf::IfOp guard,
                                ArrayRef<Value> ivs) {
    Value i = ivs[0];
    Value j = ivs[1];
    Value ko = ivs[2];
    Value ii = ivs[3];
    Value jj = ivs[4];
    Value kk = ivs[5];

    Block &thenBlock = guard.getThenRegion().front();
    OpBuilder builder(&thenBlock, thenBlock.begin());
    Location loc = guard.getLoc();
    SmallVector<Value> bIndices{ko, j, jj, kk};
    SmallVector<Value> aIndices{i, ii, ko, kk};

    createResearchPrefetch(builder, loc, "B", func.getArgument(1), bIndices,
                           "high",
                           "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界");
    createResearchPrefetch(builder, loc, "A", func.getArgument(0), aIndices,
                           "medium", "按未来 1 到 2 个 kk-cache-line");
  }
};

void registerInjectResearchPrefetchPass() {
  PassRegistration<InjectResearchPrefetchPass>();
}

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "SMEPrefetchInjectionPass",
          LLVM_VERSION_STRING, []() { registerInjectResearchPrefetchPass(); }};
}
