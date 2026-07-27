# 步骤 2-4：LLVM 插件、Stencil 识别与预取决策

本目录落实 `stencil预取优化实施方案.md` 第三部分的步骤 2 至步骤 4。步骤 2 建立可构建、可加载的 function pass；步骤 3 识别 2D5P/3D7P 循环和物理流；步骤 4 使用目标 Profile 生成确定性预取决策，构造安全未来地址并插入 AArch64 读预取 intrinsic。

## 文件

| 文件 | 说明 |
|---|---|
| `步骤2至4实现说明.md` | 按源码说明插件建立、stencil 识别、预取决策与安全插入流程 |
| `CMakeLists.txt` | 使用 LLVM 官方 `add_llvm_pass_plugin` 构建插件 |
| `src/StencilPrefetchPass.cpp` | function pass、显式 pipeline 和 Clang extension-point 注册 |
| `include/StencilAnalysis.h` | `StencilInfo`、`StreamInfo` 和识别接口 |
| `src/StencilAnalysis.cpp` | 最内层循环、masked load、GEP 和 SCEV stride 识别 |
| `include/StencilPrefetchDecision.h` | 目标 Profile、决策结果、层级和 KEEP/STRM 数据结构 |
| `src/StencilPrefetchDecision.cpp` | 距离、容量、复用、预算准入和安全地址插入 |
| `build_and_test.sh` | 构建插件，并通过 Clang `-fpass-plugin` 加载测试 |
| `output/plugin_test_report.md` | 自动生成的步骤 2 验收报告 |
| `output/stencil_recognition_report.md` | 自动生成的步骤 3 正例/负例验收报告 |
| `output/stencil_prefetch_decision_report.md` | 自动生成的步骤 4 决策与地址安全验收报告 |
| `output/pass_run.log` | 插件处理两个 stencil 函数时的诊断输出 |
| `output/negative_run.log` | 非 stencil 负例的 pass 输出 |
| `output/malformed_run.log` | 保留 load 数但破坏 row stride 配对的负例输出 |
| `output/stencil_sme_kernels.after.ll` | 插件插入预取后的 LLVM IR |
| `output/stencil_sme_kernels.s` | 步骤 4 IR 经 AArch64 后端生成的汇编 |
| `output/stencil_sme_kernels.direct.s` | 原始 C 直接加载插件生成的汇编 |
| `output/stencil_sme_kernels.baseline.s` | 原始 C 不加载插件的汇编基线 |
| `output/direct_compile.log` | 原始 C 直接编译时的决策诊断 |
| `output/idempotency_run.log` | 对已插入 IR 再次运行 pass 的诊断 |
| `tests/non_stencil.ll` | 名称以 `stencil_` 开头但不应被识别的负例 |
| `tests/include/arm_sme.h` | LLVM 18 正式 SME 头文件名的测试转接 |

## Pass 边界

`StencilPrefetchPass` 当前执行：

1. 只处理名称以 `stencil_` 开头的非声明函数。
2. 已存在 AArch64 预取时报告 `AlreadyPrefetched` 并保持 IR 不变。
3. 获取 LoopInfo、ScalarEvolution、DominatorTree、TargetIR 和 AssumptionCache。
4. 验证共同 `whilelo` 谓词、5/7 个 masked load、masked store 和 `cntsw` 步长。
5. 合并 left/center/right，并用 SCEV 相反数分类 row/plane 流。
6. 按 `generic-sme` Profile 计算距离、层级、KEEP/STRM 和预算准入。
7. 默认关闭 current-row，2D 预取 row 流，3D 预取 row 与 plane 流。
8. 用 `future_x = x + distance * cntsw()` 构造非 `inbounds` GEP。
9. 按距离合并条件保护，仅在 `future_x < interior_end` 时插入预取。
10. 修改 IR 后返回 `PreservedAnalyses::none()`。

函数名前缀只用于限制 pass 处理范围，不参与 2D/3D 判断。真正的 stencil 类型由循环、谓词、load 数量、GEP 基址和 stride 关系共同决定。

## 步骤 3 识别结果

```text
2D5P:
  logical loads = 5
  current-row = center + left + right
  north-row = north
  south-row = south
  physical streams = 3

3D7P:
  logical loads = 7
  current-row = center + left + right
  north-row = north
  south-row = south
  front-plane = front
  back-plane = back
  physical streams = 5
```

以下情况会被拒绝：

1. masked load 数不是 5 或 7。
2. load/store 不共享同一个 `whilelo` 谓词。
3. 最内层归纳变量不按 `cntsw` 递增。
4. left/center/right 不能证明为 `0/±sizeof(float)`。
5. row/plane stride 不能通过 SCEV 相反数配对。
6. 循环包含外部调用或普通 store。

## 步骤 4 默认决策

`generic-sme` Profile 使用 64-byte cache line、64-byte assumed streaming
VL、64 KiB L1、1 MiB L2、4 KiB 代表行和 128 KiB 代表 plane/tile。
默认决策为：

```text
2D5P:
  north/south row: distance 4, L1 + KEEP

3D7P:
  north/south row: distance 4, L1 + KEEP
  front/back plane near: distance 4, L1 + STRM
  front/back plane far: distance 10, L2 + KEEP
```

current-row 默认关闭，避免与硬件连续流预取重复。候选依次通过 cache
容量、独立流数量、每迭代指令数和预取字节预算；诊断输出包含每条流的
输入、决策和拒绝原因。

为步骤 5 的可复现实验提供以下环境变量覆盖；未设置时仍使用
`generic-sme`，设置后诊断中的 Profile 名称变为 `environment-override`：

| 变量 | 作用 |
|---|---|
| `SME_PREFETCH_MAX_STREAMS` | 独立预取流预算 |
| `SME_PREFETCH_MAX_INSTRUCTIONS` | 每次最内层迭代的预取指令预算 |
| `SME_PREFETCH_MAX_BYTES` | 每次最内层迭代的预取字节预算 |
| `SME_PREFETCH_L1_CAPACITY_BYTES` | L1 容量模型输入 |
| `SME_PREFETCH_L2_CAPACITY_BYTES` | L2 容量模型输入 |
| `SME_PREFETCH_USEFUL_CYCLES_2D` | 2D 距离模型的单次迭代有效周期 |
| `SME_PREFETCH_USEFUL_CYCLES_3D` | 3D 距离模型的单次迭代有效周期 |
| `SME_PREFETCH_ENABLE_ROW_L1` | 是否生成跨行 L1 候选 |
| `SME_PREFETCH_ENABLE_PLANE_L1` | 是否生成跨平面 L1 候选 |
| `SME_PREFETCH_ENABLE_PLANE_L2` | 是否生成跨平面 L2 候选 |

布尔开关以 `0` 表示关闭、非零表示开启。这些覆盖用于离线消融和回归，
最终稳定参数仍应固化为目标 CPU Profile。自动测试以
`SME_PREFETCH_MAX_STREAMS=0` 验证 8 个候选全部被
`StreamBudgetReject` 拒绝，且 IR 中不产生预取 call。
`build_and_test.sh` 会先清理调用者环境中的覆盖，保证默认回归可复现；
内置拒绝用例只对单个 Clang 进程设置零预算。
自动回归分别覆盖 `StreamBudgetReject`、`CapacityReject`、
`InstructionBudgetReject`、`BandwidthReject` 和 `ShortTripCount`。
由于 `cntsw` 是运行时值，短循环测试在上界为常量时使用 Profile 的
assumed streaming VL 估算向量迭代数，而不要求 SCEV 推导动态 VL。

Apple M5 的稳定候选已固化为命名 Profile：

```bash
SME_PREFETCH_PROFILE=apple-m5 clang \
  -fpass-plugin=./StencilPrefetchPass.dylib ...
```

该 Profile 关闭 2D/3D row-L1 和 3D plane-L2，只保留两条 3D
plane-L1 STRM，距离为 1。`generic-sme` 仍是默认值，避免 LLVM 18
无法准确识别 M5 时把 M5 参数静默用于其他 SME CPU。

步骤 4 的自动测试还会把 intrinsic 降为 AArch64 汇编，从原始 C 直接
加载插件编译，并对已插入 IR 再运行一次 pass。当前验收结果为 8 条
`PRFM/PRFUM`，语义分布与默认决策一致，二次运行不会增加 call。

## 两种注册方式

显式 pipeline：

```bash
opt -load-pass-plugin ./StencilPrefetchPass.dylib \
  -passes='function(stencil-prefetch)' \
  input.ll -S -o output.ll
```

Clang 自动注入：

```bash
clang -O1 \
  -fpass-plugin=./StencilPrefetchPass.dylib \
  -S -emit-llvm input.c -o output.ll
```

插件在 optimizer-early extension point 自动加入 Clang 优化管线。两个注册入口使用同一个 `StencilPrefetchPass` 实现。

## 构建与测试

当前共享工作区中的 LLVM 18 开发环境可直接运行：

```bash
./02_llvm_pass_plugin/build_and_test.sh
```

也可以覆盖工具：

```bash
LLVM_CONFIG=/path/to/llvm-config \
CMAKE=/path/to/cmake \
NINJA=/path/to/ninja \
PLUGIN_CXX=/path/to/host/clang++ \
LLVM_CLANG=/path/to/llvm-compatible/clang \
./02_llvm_pass_plugin/build_and_test.sh
```

`LLVM_CONFIG` 决定插件使用的 LLVM 头文件和 ABI，`LLVM_CLANG` 是加载插件的同版本 Clang。`PLUGIN_CXX` 只负责编译插件源码；当前默认使用 Apple Clang，以兼容本机新版 macOS SDK 头文件。

### LLVM 18 测试兼容处理

步骤 1 的 IR 快照由 Apple Clang 21 生成，而当前可用开发包为 LLVM 18。LLVM 18 不认识新版文本 IR 中的：

1. 参数属性 `captures(none)`
2. `getelementptr inbounds nuw` 中的 GEP `nuw`

测试脚本在 `build/` 中生成临时兼容 IR，只移除这两个文本属性，不改变循环、GEP 地址、masked load 或 SVE/SME intrinsic。正式环境应优先使用同一 LLVM 版本生成 IR、构建插件和加载插件。

LLVM 18 的 SME ACLE 资源头仍使用
`arm_sme_draft_spec_subject_to_change.h`。为了测试原始 C 直接编译，
`tests/include/arm_sme.h` 只做文件名转接，不实现 builtin，也不修改
kernel。升级到自带正式 `arm_sme.h` 的工具链后可删除该测试转接。
