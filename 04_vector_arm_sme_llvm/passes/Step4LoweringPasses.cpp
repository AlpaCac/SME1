//===- Step4LoweringPasses.cpp -------------------------------------------===//
//
// 第四步 MLIR pass 插件。
//
// 这个文件把第四步主线中的末端修复逻辑实现为真正的 MLIR pass：
//   1. step4-repair-llvm-index-bridges
//      把末端 i64 -> index -> i32 桥接残留规整为 llvm.trunc。
//
// 第三步已经完成 vector 层预取注入，第四步不再重复插入预取，只负责从
// 第三步输出的 vector+memref.prefetch 主线继续降到 arm_sme / llvm。
// 真正的 vector/arm_sme/llvm lowering 仍然由 mlir-opt 的官方 pass pipeline 调度。
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Arith/IR/Arith.h"
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
  PassRegistration<RepairLLVMIndexBridgesPass>();
}

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "SMEStep4LoweringPasses",
          LLVM_VERSION_STRING, []() { registerStep4Passes(); }};
}
