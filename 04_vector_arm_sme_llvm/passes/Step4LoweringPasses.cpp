//===- Step4LoweringPasses.cpp -------------------------------------------===//
//
// 第四步 MLIR pass 插件。
//
// 这个文件把早期 Python 脚本中的 IR 文本改写逻辑迁移为真正的 MLIR pass：
//   1. step4-convert-research-prefetch-to-affine
//      把第三步已经注册的 research.prefetch 桥接为标准 affine.prefetch。
//   2. step4-inject-vector-memref-prefetch
//      在 vector.transfer_read 之前插入 memref.prefetch，让预取进入 vector 主线。
//   3. step4-repair-llvm-index-bridges
//      把末端 i64 -> index -> i32 桥接残留规整为 llvm.trunc。
//
// 这些 pass 只负责“研究语义改写”。真正的 affine/vector/arm_sme/llvm lowering
// 仍然由 mlir-opt 的官方 pass pipeline 调度。
//
// 注意：research dialect 的注册职责属于第三步插件。第四步作为 pass 插件
// 读取第三步已经可解析的 IR，不重复注册同名 dialect，避免同一个插件既作为
// dialect plugin 又作为 pass plugin 加载时产生边界混乱。
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/Vector/IR/VectorOps.h"
#include "mlir/IR/AffineExpr.h"
#include "mlir/IR/AffineMap.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Tools/Plugins/PassPlugin.h"
#include "llvm/Config/llvm-config.h"
#include "llvm/Support/Compiler.h"

using namespace mlir;

namespace {

static bool isResearchPrefetch(Operation *op) {
  return op->getName().getStringRef() == "research.prefetch";
}

static unsigned localityToHint(Operation *op) {
  StringAttr locality = op->getAttrOfType<StringAttr>("locality");
  if (locality && locality.getValue().equals_insensitive("KEEP"))
    return 3;
  return 0;
}

//===----------------------------------------------------------------------===//
// research.prefetch -> affine.prefetch
//===----------------------------------------------------------------------===//

struct ConvertResearchPrefetchToAffinePass
    : public PassWrapper<ConvertResearchPrefetchToAffinePass,
                         OperationPass<func::FuncOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(
      ConvertResearchPrefetchToAffinePass)

  StringRef getArgument() const final {
    return "step4-convert-research-prefetch-to-affine";
  }

  StringRef getDescription() const final {
    return "Bridge registered research.prefetch ops to affine.prefetch ops";
  }

  void getDependentDialects(DialectRegistry &registry) const final {
    registry.insert<affine::AffineDialect, func::FuncDialect>();
  }

  void runOnOperation() final {
    func::FuncOp func = getOperation();
    SmallVector<Operation *> prefetchOps;
    func.walk([&](Operation *op) {
      if (isResearchPrefetch(op))
        prefetchOps.push_back(op);
    });

    for (Operation *op : prefetchOps) {
      if (failed(rewriteOnePrefetch(op))) {
        signalPassFailure();
        return;
      }
    }

    if (!prefetchOps.empty()) {
      OpBuilder builder(func.getContext());
      func->setAttr("step4_prefetch_bridge",
                    builder.getStringAttr("research_to_affine"));
    }
  }

private:
  static LogicalResult rewriteOnePrefetch(Operation *op) {
    StringAttr target = op->getAttrOfType<StringAttr>("target");
    if (!target)
      return op->emitOpError("expected target attribute");

    Value memref = op->getOperand(0);
    SmallVector<Value> indices(op->getOperands().drop_front());
    if (indices.size() != 4)
      return op->emitOpError("expected four research indices");

    MLIRContext *ctx = op->getContext();
    AffineExpr d0, d1, d2, d3;
    bindDims(ctx, d0, d1, d2, d3);

    AffineMap map;
    if (target.getValue() == "B") {
      // B 的 research operands 是 ko, j, jj, kk。
      // 标准 affine.prefetch 下标为 B[ko + kk, j + jj]。
      map = AffineMap::get(4, 0, {d0 + d3, d1 + d2}, ctx);
    } else if (target.getValue() == "A") {
      // A 的 research operands 是 i, ii, ko, kk。
      // 标准 affine.prefetch 下标为 A[i + ii, ko + kk]。
      map = AffineMap::get(4, 0, {d0 + d1, d2 + d3}, ctx);
    } else {
      return op->emitOpError("only A/B research.prefetch are supported");
    }

    OpBuilder builder(op);
    affine::AffinePrefetchOp::create(builder, op->getLoc(), memref, map,
                                     indices, /*isWrite=*/false,
                                     localityToHint(op),
                                     /*isDataCache=*/true);
    op->erase();
    return success();
  }
};

//===----------------------------------------------------------------------===//
// vector.transfer_read 前插入 memref.prefetch
//===----------------------------------------------------------------------===//

struct InjectVectorMemrefPrefetchPass
    : public PassWrapper<InjectVectorMemrefPrefetchPass,
                         OperationPass<func::FuncOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(InjectVectorMemrefPrefetchPass)

  StringRef getArgument() const final {
    return "step4-inject-vector-memref-prefetch";
  }

  StringRef getDescription() const final {
    return "Insert memref.prefetch before vector.transfer_read in step-4 vector IR";
  }

  void getDependentDialects(DialectRegistry &registry) const final {
    registry.insert<func::FuncDialect, memref::MemRefDialect,
                    vector::VectorDialect>();
  }

  void runOnOperation() final {
    func::FuncOp func = getOperation();
    SmallVector<vector::TransferReadOp> reads;
    func.walk([&](vector::TransferReadOp read) {
      if (shouldPrefetch(read))
        reads.push_back(read);
    });

    for (vector::TransferReadOp read : reads)
      insertPrefetch(read);

    if (!reads.empty()) {
      OpBuilder builder(func.getContext());
      func->setAttr("step4_vector_prefetch",
                    builder.getStringAttr("memref_prefetch"));
    }
  }

private:
  static bool shouldPrefetch(vector::TransferReadOp read) {
    auto sourceType = dyn_cast<MemRefType>(read.getBase().getType());
    if (!sourceType || sourceType.getRank() != 1)
      return false;

    // 当前 step4 vector 主线中，A/B 的读流是 rank-1 scalable vector。
    // C 的 tile 读通常是 rank-2 vector，不在这里插入预取。
    if (read.getVectorType().getRank() != 1)
      return false;

    Operation *previous = read->getPrevNode();
    return !previous || !isa<memref::PrefetchOp>(previous);
  }

  static void insertPrefetch(vector::TransferReadOp read) {
    OpBuilder builder(read);
    memref::PrefetchOp::create(builder, read.getLoc(), read.getBase(),
                               read.getIndices(), /*isWrite=*/false,
                               /*localityHint=*/3,
                               /*isDataCache=*/true);
  }
};

//===----------------------------------------------------------------------===//
// i64 -> index -> i32 桥接清理
//===----------------------------------------------------------------------===//

struct RepairLLVMIndexBridgesPass
    : public PassWrapper<RepairLLVMIndexBridgesPass, OperationPass<ModuleOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(RepairLLVMIndexBridgesPass)

  StringRef getArgument() const final {
    return "step4-repair-llvm-index-bridges";
  }

  StringRef getDescription() const final {
    return "Replace i64 -> index -> i32 bridge leftovers with llvm.trunc";
  }

  void getDependentDialects(DialectRegistry &registry) const final {
    registry.insert<arith::ArithDialect>();
  }

  void runOnOperation() final {
    ModuleOp module = getOperation();
    SmallVector<arith::IndexCastOp> casts;
    module.walk([&](arith::IndexCastOp castOp) {
      if (canRepair(castOp))
        casts.push_back(castOp);
    });

    for (arith::IndexCastOp castOp : casts)
      repair(castOp);
  }

private:
  static bool canRepair(arith::IndexCastOp castOp) {
    if (!castOp.getType().isInteger(32))
      return false;

    auto bridge =
        castOp.getIn().getDefiningOp<UnrealizedConversionCastOp>();
    if (!bridge || bridge.getInputs().size() != 1 ||
        bridge.getOutputs().size() != 1)
      return false;

    return bridge.getInputs()[0].getType().isInteger(64) &&
           bridge.getOutputs()[0].getType().isIndex();
  }

  static void repair(arith::IndexCastOp castOp) {
    auto bridge =
        castOp.getIn().getDefiningOp<UnrealizedConversionCastOp>();
    OpBuilder builder(castOp);
    OperationState state(castOp.getLoc(), "llvm.trunc");
    state.addOperands(bridge.getInputs()[0]);
    state.addTypes(builder.getI32Type());
    Operation *trunc = builder.create(state);
    castOp.replaceAllUsesWith(trunc->getResult(0));
    castOp.erase();
    if (bridge->use_empty())
      bridge.erase();
  }
};

void registerStep4Passes() {
  PassRegistration<ConvertResearchPrefetchToAffinePass>();
  PassRegistration<InjectVectorMemrefPrefetchPass>();
  PassRegistration<RepairLLVMIndexBridgesPass>();
}

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "SMEStep4LoweringPasses",
          LLVM_VERSION_STRING, []() { registerStep4Passes(); }};
}
