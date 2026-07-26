# 步骤 2-4：LLVM 插件、Stencil 识别与预取决策

本目录落实 `stencil预取优化实施方案.md` 第三部分的步骤 2 至步骤 4。步骤 2 建立可构建、可加载的 function pass；步骤 3 识别 2D5P/3D7P 循环和物理流；步骤 4 使用目标 Profile 生成确定性预取决策，构造安全未来地址并插入 AArch64 读预取 intrinsic。

## 文件

| 文件 | 说明 |
|---|---|
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
| `tests/non_stencil.ll` | 名称以 `stencil_` 开头但不应被识别的负例 |

## Pass 边界

`StencilPrefetchPass` 当前执行：

1. 只处理名称以 `stencil_` 开头的非声明函数。
2. 获取 `LoopAnalysis`。
3. 获取 `ScalarEvolutionAnalysis`。
4. 获取 `DominatorTreeAnalysis`。
5. 获取 `TargetIRAnalysis`。
6. 获取 `AssumptionAnalysis`。
7. 在最内层循环中验证共同 `whilelo` 谓词、5/7 个 masked load 和 masked store。
8. 验证 `x` PHI 按 `cntsw` 递增。
9. 合并 left/center/right，并用相反 SCEV stride 分类 row/plane 流。
10. 输出 2D5P/3D7P 与 3/5 条物理流。
11. 按 `generic-sme` Profile 计算距离、层级、KEEP/STRM 和预算准入。
12. 默认关闭 current-row，2D 预取 row 流，3D 预取 row 与 plane 流。
13. 用 `future_x = x + distance * cntsw()` 构造非 `inbounds` GEP。
14. 按距离合并条件保护，仅在 `future_x < interior_end` 时插入预取。
15. 修改 IR 后返回 `PreservedAnalyses::none()`。

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
