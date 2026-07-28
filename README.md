# SME Stencil 软件预取

本仓库研究如何在不改写原始 SME/SVE ACLE C kernel 的前提下，通过 Clang/LLVM 编译流程为 stencil 计算插入 AArch64 数据读预取。

当前只包含两个单时间步、常系数 stencil：

1. 2D 5-point（2D5P）
2. 3D 7-point（3D7P）

## 当前文件

| 文件 | 说明 |
|---|---|
| `stencil_sme_kernels.c` | 使用 `arm_sme.h` 和 `arm_sve.h` 实现的 2D5P、3D7P kernel |
| `项目代码运行顺序.md` | 从生成 LLVM IR、构建 pass、插入预取到 Apple M5 验证的完整命令顺序 |
| `断网AArch64服务器迁移指南.md` | 准备离线工具链、迁移源码、适配 AArch64 Linux、重新生成产物并验证性能 |
| `毕昇Clang19_LLVM环境安装指南.md` | 在联网 AArch64 服务器上配置毕昇 5.1.0.2 配套或独立 LLVM 19.1.7 开发环境 |
| `stencil预取优化实施方案.md` | 计算模型、预取类别、决策算法和 Clang/LLVM pass 实施步骤 |
| `software_prefetch_sme_analysis.md` | SME stencil 软件读预取的背景与原理分析 |
| `01_llvm_ir_analysis/` | 步骤 1：生成 LLVM IR 并自动验证循环、地址和向量访存结构 |
| `02_llvm_pass_plugin/` | 步骤 2-4：插件、stencil 识别、预取插入和端到端编译检查 |
| `05_runtime_validation/` | 步骤 5：Apple M5 上的 SME 数值正确性与后续性能验证 |

## 执行流程

所有命令均从仓库根目录 `SME1` 执行。最小完整流程为：

```bash
# 1. 从 C kernel 生成 LLVM IR 并检查其可分析性
./01_llvm_ir_analysis/generate_and_check.sh

# 2. 构建 LLVM pass，完成 stencil 识别、预取插入和汇编检查
./02_llvm_pass_plugin/build_and_test.sh

# 3. 在 Apple M5 上运行命名 Profile 的数值正确性测试
SME_RUNTIME_PROFILE=apple-m5 FORCE_SME_RUN=1 \
  ./05_runtime_validation/build_and_run.sh

# 4. 运行当前主要的单进程配对性能测试
SME_RUNTIME_PROFILE=apple-m5 FORCE_SME_RUN=1 \
  ./05_runtime_validation/run_paired_benchmark.sh
```

代码依赖顺序为：

```text
stencil_sme_kernels.c
→ 01_llvm_ir_analysis/output/stencil_sme_kernels.ll
→ StencilPrefetchPass
→ 02_llvm_pass_plugin/output/stencil_sme_kernels.apple-m5.s
→ 05_runtime_validation 正确性与性能驱动
→ output 中的验证报告
```

距离扫描、类别消融、PMU 和多线程测试属于步骤 5 的扩展验证，不是生成
预取汇编的必经步骤。完整命令、输入输出和验收条件见
`项目代码运行顺序.md`。

## Kernel

`stencil_sme_kernels.c` 提供：

```c
void stencil_2d5p_sme_f32(...);
void stencil_3d7p_sme_f32(...);
```

两个函数均：

1. 使用 `__arm_locally_streaming` 进入 SME streaming mode。
2. 以 `x` 为最内层连续维。
3. 使用 SVE 谓词处理尾部。
4. 只计算内部点，边界由调用者负责。
5. 输入和输出使用不同数组。

语法检查示例：

```bash
clang -target arm64-apple-macos15 \
  -march=armv9.2-a+sme+sve2 \
  -fsyntax-only stencil_sme_kernels.c
```

生成 LLVM IR：

```bash
clang -target arm64-apple-macos15 \
  -march=armv9.2-a+sme+sve2 \
  -O1 -S -emit-llvm stencil_sme_kernels.c \
  -o stencil_sme_kernels.ll
```

运行步骤 1 的完整生成与检查：

```bash
./01_llvm_ir_analysis/generate_and_check.sh
```

检查结果写入 `01_llvm_ir_analysis/output/analysis_report.md`。

## 预取实现主线

```text
原始 SME/SVE ACLE C
-> Clang CodeGen
-> LLVM IR
   - 循环与归纳变量
   - getelementptr
   - llvm.masked.load
   - SVE/SME intrinsic
-> StencilPrefetchPass
   - 识别 2D5P/3D7P 物理流
   - 决定距离、L1/L2/L3 和 KEEP/STRM
   - 插入 llvm.aarch64.prefetch
-> AArch64 后端
-> SME/SVE 计算指令 + PRFM
```

分析与插入在同一个 LLVM pass 中完成，不使用 JSON 传递决策，也不依赖高层 MLIR 或自定义预取 op。

## 预取范围

方案只讨论数据读预取，候选包括：

1. 连续 `x` 维前向预取。
2. north/south 跨行预取。
3. 3D front/back 跨平面预取。
4. next-row、next-plane 或 next-tile 预热。

2D5P 通常合并为 3 条主要 cache-line 流，3D7P 通常合并为 5 条。两者共享 LLVM 分析框架，但分别进行距离、层级、KEEP/STRM 和流准入决策。

完整设计与实现顺序见 `stencil预取优化实施方案.md`。

## 实施状态

1. 步骤 1：Clang LLVM IR 生成与可分析性检查，已完成。
2. 步骤 2：LLVM new-pass-manager 插件，已完成。
3. 步骤 3：识别 2D5P/3D7P 循环和物理流，已完成。
4. 步骤 4：预取决策、插入、AArch64 lowering、原始 C 直编和幂等检查，已完成。
5. 步骤 5：Apple M5 数值正确性和跨尺寸距离扫描已完成。命名的
   `apple-m5` Profile 对 2D 不插入预取，对 3D 只插入两条 distance-1
   plane-L1 STRM；配对结果为 2D `1.004x`、3D `1.028x`。自定义
   Instruments 模板的三轮 PMU 对比也已完成：PL2 access/load miss
   分别约增至 `12.25x/50.85x`，L1D 事件波动较大。独立网格的
   1/2/4/8 线程配对结果分别为 `1.043x/1.107x/1.114x/1.095x`。

Apple M5 支持 SME/SME2，但不支持普通 SVE。运行时验证把 SME kernel 与
普通 arm64 测试驱动分开编译，kernel 使用 `+nosve+sme`；不能把
`+sve2` 全局应用到可执行程序。上面的 `+sme+sve2` 命令仅用于 LLVM 18
前端的 IR/汇编验证。

Apple M5 编译时显式选择：

```bash
SME_PREFETCH_PROFILE=apple-m5 clang \
  -fpass-plugin=./StencilPrefetchPass.dylib ...
```
