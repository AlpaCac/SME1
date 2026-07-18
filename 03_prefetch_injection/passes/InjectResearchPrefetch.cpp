//===- InjectResearchPrefetch.cpp ----------------------------------------===//
//
// 这是第三步“预取注入”的研究版 MLIR pass。
//
// 它面向第一步生成的受限 affine GEMM 形态：
//   i / j / ko / ii / jj / kk 分块循环
//   kk 归约循环内部包含 A/B/C 的 affine.load / affine.store
//
// pass 做的事情不是直接生成机器预取指令，而是在 affine 层插入
// generic op：research.prefetch。这个 op 用来保留“对谁预取、预取到哪一级、
// 优先级如何、预取距离是什么”等高层研究语义，后续再由 lowering pass 继续处理。
//
//===----------------------------------------------------------------------===//

// affine dialect 提供 affine.for / affine.load 等结构化循环和访存 op。
#include "mlir/Dialect/Affine/IR/AffineOps.h"
// func dialect 提供 func.func，本 pass 以函数作为处理单位。
#include "mlir/Dialect/Func/IR/FuncOps.h"
// scf dialect 提供 scf.if，这里用于识别边界保护区域。
#include "mlir/Dialect/SCF/IR/SCF.h"
// OpBuilder 用于在 IR 中创建新的 operation。
#include "mlir/IR/Builders.h"
// BuiltinAttributes 提供 StringAttr 等基础属性类型。
#include "mlir/IR/BuiltinAttributes.h"
// Operation 是 MLIR IR 中所有 op 的公共基类。
#include "mlir/IR/Operation.h"
// Pass.h 提供 PassWrapper、OperationPass、PassRegistration 等 pass 基础设施。
#include "mlir/Pass/Pass.h"
// PassPlugin.h 提供 mlir-opt --load-pass-plugin 所需的插件入口类型。
#include "mlir/Tools/Plugins/PassPlugin.h"
// STLExtras 提供 llvm::reverse 等 LLVM 常用辅助工具。
#include "llvm/ADT/STLExtras.h"
// llvm-config.h 提供 LLVM_VERSION_STRING，用于插件版本信息。
#include "llvm/Config/llvm-config.h"
// Compiler.h 提供 LLVM_ATTRIBUTE_WEAK，用于导出弱符号插件入口。
#include "llvm/Support/Compiler.h"

// std::optional 用来表达“可能存在常量上界，也可能不存在”。
#include <optional>

// 简化命名空间书写，例如直接写 func::FuncOp、affine::AffineForOp。
using namespace mlir;

// 匿名命名空间让本文件中的 pass 类型和辅助函数只在当前编译单元可见，
// 避免和其他插件或 MLIR pass 发生符号冲突。
namespace {

// InjectResearchPrefetchPass 是真正的 pass 实现。
//
// PassWrapper 提供 MLIR pass 所需的通用样板逻辑。
// OperationPass<func::FuncOp> 表示这个 pass 的运行单位是 func.func，
// 因此它需要通过 builtin.module(func.func(...)) 这种 pipeline 嵌套方式运行。
struct InjectResearchPrefetchPass
    : public PassWrapper<InjectResearchPrefetchPass,
                         OperationPass<func::FuncOp>> {
  // 为这个 pass 类型生成 MLIR 内部使用的 TypeID。
  // 新版 MLIR 要求 pass 类型具备稳定的类型标识。
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(InjectResearchPrefetchPass)

  // getArgument 决定命令行中使用的 pass 名称。
  // 运行时写作：inject-research-prefetch。
  StringRef getArgument() const final { return "inject-research-prefetch"; }

  // getDescription 决定 mlir-opt --help 中显示的说明文字。
  StringRef getDescription() const final {
    return "Insert research.prefetch ops into the restricted affine GEMM form";
  }

  // 声明本 pass 会依赖哪些 dialect。
  // mlir-opt 加载 pass 后，会确保这些 dialect 可以被 context 使用。
  void getDependentDialects(DialectRegistry &registry) const final {
    registry.insert<affine::AffineDialect, func::FuncDialect,
                    scf::SCFDialect>();
  }

  // runOnOperation 是 pass 的主入口。
  // 因为这是 OperationPass<func::FuncOp>，所以 getOperation() 得到的是当前函数。
  void runOnOperation() final {
    // 取出当前正在处理的 func.func。
    func::FuncOp func = getOperation();

    // 当前研究版默认函数参数至少是 A、B、C 三个 memref。
    // 后续 insertPrefetchOps 会用 argument 0 表示 A，argument 1 表示 B。
    if (func.getNumArguments() < 3) {
      // 如果参数不足，说明输入不符合当前第三步的约定，直接报错并终止 pass。
      func.emitError("expected at least three memref arguments: A, B, C");
      signalPassFailure();
      return;
    }

    // 当前实现只在第一个匹配到的 kk 归约循环中注入预取。
    // injected 用来避免在同一个函数中重复插入。
    bool injected = false;

    // 遍历函数内部所有 affine.for。
    // MLIR walk 会递归访问当前函数下的嵌套 operation。
    func.walk([&](affine::AffineForOp forOp) {
      // 如果已经注入过，或者当前 affine.for 不是候选 kk 归约循环，就跳过。
      if (injected || !isReductionCandidate(forOp))
        return;

      // 在候选 kk 循环体内找到第一个 scf.if。
      // 这个 scf.if 在当前输入中对应 %in_k_bound 边界保护。
      scf::IfOp guard = findFirstIfInLoopBody(forOp);

      // 如果没有 guard，或者 guard 内已经有 research.prefetch，
      // 就不再重复插入，保持 pass 幂等性。
      if (!guard || alreadyHasResearchPrefetch(guard))
        return;

      // 收集当前 kk 循环及其外层 affine.for 的 induction variables。
      // 对当前 GEMM 结构，期望得到 i, j, ko, ii, jj, kk。
      SmallVector<Value> ivs = collectAncestorInductionVars(forOp);

      // 如果收集不到 6 层循环变量，说明输入循环结构不符合当前研究版约定。
      if (ivs.size() < 6)
        return;

      // 在 guard 的 then block 开头插入 A/B 两条 research.prefetch。
      insertPrefetchOps(func, guard, ivs);

      // 标记已插入，后续 walk 即使继续遇到 affine.for 也不会再处理。
      injected = true;
    });

    // 如果整个函数遍历结束后仍然没有注入，说明没有找到受限 GEMM kk 注入点。
    if (!injected) {
      func.emitError("failed to locate the restricted GEMM kk injection point");
      signalPassFailure();
      return;
    }

    // 创建一个 builder，只用于构造属性。
    OpBuilder builder(func.getContext());

    // 在函数上写入标记，方便后续 pass 或人工检查知道第三步已经完成。
    func->setAttr("prefetch_injected", builder.getStringAttr("true"));
  }

private:
  // 在某个 affine.for 的循环体中查找第一个直接出现的 scf.if。
  //
  // 当前输入中，kk 循环体结构大致是：
  //   affine.for %kk = 0 to 128 {
  //     %in_k_bound = arith.cmpi ...
  //     scf.if %in_k_bound {
  //       ...
  //     }
  //   }
  //
  // 因此这里不需要递归找深层 if，只检查循环体的直接子 operation。
  static scf::IfOp findFirstIfInLoopBody(affine::AffineForOp forOp) {
    // affine.for 的 region 里只有一个 block，front() 取出这个循环体 block。
    Block &body = forOp.getRegion().front();

    // 遍历循环体中的 operation，但排除 terminator。
    // affine.for 的 block 末尾会有隐式/显式 terminator，不能把它当作普通语句处理。
    for (Operation &op : body.without_terminator()) {
      // 如果当前 operation 是 scf.if，就返回它。
      if (auto ifOp = dyn_cast<scf::IfOp>(&op))
        return ifOp;
    }

    // 没找到则返回空 op handle。
    return nullptr;
  }

  // 判断一个 affine.for 是否像当前 GEMM 中的 kk 归约循环。
  //
  // 这不是完整的语义证明，而是研究版结构启发式匹配：
  //   1. kk 循环步长是 1
  //   2. kk 循环上界是较大的常量
  //   3. 循环体内有边界保护 scf.if
  //   4. scf.if 内部有嵌套循环和 affine.load
  static bool isReductionCandidate(affine::AffineForOp forOp) {
    // 当前 kk 归约循环是 affine.for %kk = 0 to 128，默认 step 为 1。
    // 初始化 C 的 i_inner / j_inner 循环虽然也可能有 step 1，
    // 但后续还会用 affine.load 等条件继续区分。
    if (forOp.getStepAsInt() != 1)
      return false;

    // 尝试读取 affine.for 的常量上界。
    // 如果上界是动态表达式，这里会得到空值，当前研究版先不处理。
    std::optional<int64_t> upper = forOp.getConstantUpperBound();

    // 当前示例 kk 上界是 128。这里用 >=64 作为粗略过滤，
    // 目的是排除 16x16 微块内部的小循环。
    if (!upper || *upper < 64)
      return false;

    // 找到循环体里的第一个 scf.if，期望它是 kk 的边界保护。
    scf::IfOp guard = findFirstIfInLoopBody(forOp);

    // 如果没有 if，或者 then region 为空，就不是当前受支持形态。
    if (!guard || guard.getThenRegion().empty())
      return false;

    // 下面两个布尔值用于确认 guard 内部像真实乘加区域：
    // 有嵌套 affine.for，并且有 affine.load。
    bool hasNestedAffineLoop = false;
    bool hasAffineLoad = false;

    // 递归遍历 scf.if 的 then region。
    // 如果里面有 affine.for，说明有内层 i_inner/j_inner 计算。
    // 如果里面有 affine.load，说明这里确实发生了 A/B/C 访存。
    guard.getThenRegion().walk([&](Operation *op) {
      hasNestedAffineLoop |= isa<affine::AffineForOp>(op);
      hasAffineLoad |= isa<affine::AffineLoadOp>(op);
    });

    // 只有同时满足两个条件，才认为这是可插入预取的 kk 归约循环。
    return hasNestedAffineLoop && hasAffineLoad;
  }

  // 检查 guard 内是否已经存在 research.prefetch。
  //
  // 这样做可以让 pass 具备基本幂等性：
  // 同一个文件如果重复运行 pass，不会在同一位置无限插入重复预取。
  static bool alreadyHasResearchPrefetch(scf::IfOp guard) {
    bool found = false;

    // research.prefetch 当前还是未注册 generic op，
    // 所以不能用具体 C++ op 类型 dyn_cast，只能按 operation name 字符串判断。
    guard.getThenRegion().walk([&](Operation *op) {
      found |= op->getName().getStringRef() == "research.prefetch";
    });

    return found;
  }

  // 收集当前 affine.for 及其所有外层 affine.for 的 induction variable。
  //
  // 从 kk 循环向父节点走时，收集顺序是：
  //   kk, jj, ii, ko, j, i
  //
  // 后面需要反转为外到内顺序：
  //   i, j, ko, ii, jj, kk
  static SmallVector<Value> collectAncestorInductionVars(affine::AffineForOp op) {
    // 先按从内到外的顺序临时保存。
    SmallVector<Value> reversed;

    // current 从当前 kk affine.for 开始，一直沿 parent op 向外走。
    for (Operation *current = op.getOperation(); current;
         current = current->getParentOp()) {
      // 只有 affine.for 才有 induction variable，其他 op 例如 scf.if、func.func 跳过。
      if (auto forOp = dyn_cast<affine::AffineForOp>(current))
        reversed.push_back(forOp.getInductionVar());
    }

    // ordered 保存从外到内的顺序，便于后续按 i/j/ko/ii/jj/kk 解释。
    SmallVector<Value> ordered;

    // llvm::reverse 只提供反向遍历视图，这里逐个 push 到新的 SmallVector。
    for (Value iv : llvm::reverse(reversed))
      ordered.push_back(iv);

    return ordered;
  }

  // 构造一条 research.prefetch generic op。
  //
  // 由于当前还没有定义正式 research dialect，
  // 这里使用 OperationState 手动创建名字为 "research.prefetch" 的 generic op。
  static void createResearchPrefetch(OpBuilder &builder, Location loc,
                                     StringRef target, Value memref,
                                     ValueRange indices, StringRef priority,
                                     StringRef distance) {
    // OperationState 是 MLIR 创建未知/generic operation 的底层描述对象。
    // loc 表示源码/IR 位置信息，"research.prefetch" 是 op 名称。
    OperationState state(loc, "research.prefetch");

    // research.prefetch 的 operands 约定为：
    //   第一个 operand 是要预取的 memref
    //   后续 operands 是描述预取位置的 index 值
    SmallVector<Value> operands;

    // 先放入 memref，例如 A 或 B。
    operands.push_back(memref);

    // 再追加索引，例如 B 使用 ko, j, jj, kk。
    operands.append(indices.begin(), indices.end());

    // 把 operands 写入 OperationState。
    state.addOperands(operands);

    // target 表示预取对象的逻辑名字，例如 "A" 或 "B"。
    state.addAttribute("target", builder.getStringAttr(target));

    // kind 表示预取类型。当前只研究读预取，因此固定为 read。
    state.addAttribute("kind", builder.getStringAttr("read"));

    // priority 表示第二步 cost module 决策出的预取优先级。
    state.addAttribute("priority", builder.getStringAttr(priority));

    // cache 表示希望预取到的缓存层级。当前研究版固定为 L1。
    state.addAttribute("cache", builder.getStringAttr("L1"));

    // locality 表示局部性提示。KEEP 表示希望保留较强局部性。
    state.addAttribute("locality", builder.getStringAttr("KEEP"));

    // distance 保留高层预取距离描述，后续 lowering 时再决定如何映射成整数距离。
    state.addAttribute("distance", builder.getStringAttr(distance));

    // 通过 builder 在当前插入点真正创建 operation。
    builder.create(state);
  }

  // 在找到的 kk guard 中插入 A/B 两条预取。
  //
  // ivs 必须按外到内顺序组织：
  //   i, j, ko, ii, jj, kk
  static void insertPrefetchOps(func::FuncOp func, scf::IfOp guard,
                                ArrayRef<Value> ivs) {
    // 外层 M 维块起点，对应 C/A 的行方向外层块。
    Value i = ivs[0];

    // 外层 N 维块起点，对应 C/B 的列方向外层块。
    Value j = ivs[1];

    // 外层 K 维块起点，对应 A/B 的归约维外层块。
    Value ko = ivs[2];

    // M 维微块起点，对应 A/C 的行方向微块。
    Value ii = ivs[3];

    // N 维微块起点，对应 B/C 的列方向微块。
    Value jj = ivs[4];

    // K 维归约循环变量，对应当前 kk 推进位置。
    Value kk = ivs[5];

    // guard 的 then region 是边界条件成立时真正执行乘加的位置。
    Block &thenBlock = guard.getThenRegion().front();

    // builder 插入点放在 then block 的开头，
    // 这样 research.prefetch 会位于真实 affine.load 之前。
    OpBuilder builder(&thenBlock, thenBlock.begin());

    // 使用 guard 的 location，让插入的 op 和边界保护位置关联。
    Location loc = guard.getLoc();

    // B 的访问语义来自 B[ko + kk, j + jj + j_inner]。
    // 这里先保留块级坐标 ko / j / jj / kk，j_inner 留给后续 lowering 或分析解释。
    SmallVector<Value> bIndices{ko, j, jj, kk};

    // A 的访问语义来自 A[i + ii + i_inner, ko + kk]。
    // 这里先保留块级坐标 i / ii / ko / kk。
    SmallVector<Value> aIndices{i, ii, ko, kk};

    // 当前 cost module 认为 B 的连续访问和复用更适合高优先级预取。
    // func.getArgument(1) 按约定是 B。
    createResearchPrefetch(builder, loc, "B", func.getArgument(1), bIndices,
                           "high",
                           "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界");

    // A 也需要预取，但当前优先级低于 B。
    // func.getArgument(0) 按约定是 A。
    createResearchPrefetch(builder, loc, "A", func.getArgument(0), aIndices,
                           "medium", "按未来 1 到 2 个 kk-cache-line");
  }
};

// 把 pass 注册到 MLIR PassRegistry。
// 插件被 mlir-opt 加载后，会调用下面的 mlirGetPassPluginInfo，
// 进而执行这个注册函数，使 --inject-research-prefetch 可见。
void registerInjectResearchPrefetchPass() {
  PassRegistration<InjectResearchPrefetchPass>();
}

} // namespace

// 这是 MLIR pass 插件的动态库入口。
//
// mlir-opt --load-pass-plugin=... 会在动态库中查找这个符号。
// 返回值告诉 mlir-opt：
//   插件 API 版本是什么
//   插件名字是什么
//   插件对应的 LLVM 版本是什么
//   加载插件时应该调用哪个函数注册 pass
extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo mlirGetPassPluginInfo() {
  return {MLIR_PLUGIN_API_VERSION, "SMEPrefetchInjectionPass",
          LLVM_VERSION_STRING, []() { registerInjectResearchPrefetchPass(); }};
}
