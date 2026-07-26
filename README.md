# SME Stencil 软件预取

本仓库研究如何在不改写原始 SME/SVE ACLE C kernel 的前提下，通过 Clang/LLVM 编译流程为 stencil 计算插入 AArch64 数据读预取。

当前只包含两个单时间步、常系数 stencil：

1. 2D 5-point（2D5P）
2. 3D 7-point（3D7P）

## 当前文件

| 文件 | 说明 |
|---|---|
| `stencil_sme_kernels.c` | 使用 `arm_sme.h` 和 `arm_sve.h` 实现的 2D5P、3D7P kernel |
| `stencil预取优化实施方案.md` | 计算模型、预取类别、决策算法和 Clang/LLVM pass 实施步骤 |
| `software_prefetch_sme_analysis.md` | SME stencil 软件读预取的背景与原理分析 |
| `01_llvm_ir_analysis/` | 步骤 1：生成 LLVM IR 并自动验证循环、地址和向量访存结构 |
| `02_llvm_pass_plugin/` | 步骤 2-3：LLVM 插件，以及 2D5P/3D7P 循环和物理流识别 |

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
4. 步骤 4：预取决策与安全地址构造，尚未实现。
