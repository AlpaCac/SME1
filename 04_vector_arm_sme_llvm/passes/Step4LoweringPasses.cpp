//===- Step4LoweringPasses.cpp -------------------------------------------===//
//
// 第四步 MLIR pass 插件。
//
// 这个文件把第四步主线中的研究改写逻辑实现为真正的 MLIR pass：
//   1. step4-inject-vector-memref-prefetch
//      在 vector.transfer_read 之前插入 memref.prefetch，让预取进入 vector 主线。
//   2. step4-repair-llvm-index-bridges
//      把末端 i64 -> index -> i32 桥接残留规整为 llvm.trunc。
//
// 这些 pass 只负责“研究语义改写”。真正的 affine/vector/arm_sme/llvm lowering
// 仍然由 mlir-opt 的官方 pass pipeline 调度。
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/Vector/IR/VectorOps.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Operation.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Tools/Plugins/PassPlugin.h"
#include "llvm/Config/llvm-config.h"
#include "llvm/Support/Compiler.h"

using namespace mlir;

namespace {

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
  PassRegistration<InjectVectorMemrefPrefetchPass>();
  PassRegistration<RepairLLVMIndexBridgesPass>();
}

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "SMEStep4LoweringPasses",
          LLVM_VERSION_STRING, []() { registerStep4Passes(); }};
}
