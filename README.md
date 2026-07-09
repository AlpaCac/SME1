# 方案整理

## 1. 实验目标

本实验的总体目标是：

从国防科大论文的 C 矩阵计算程序出发，构建一条“高层 MLIR 语义分析 + 预取策略生成 + LLVM lowering + LX2 验证”的完整实验流程，用于探索面向 ARM SME 的高层 IR 驱动预取优化方法，从而实现比baseline更优的性能效果。

具体可分为两个子目标：

### 1.1 高层表示目标（蒋涛）

研究 SME 相关矩阵计算在高层 MLIR 中的合适表示形式，包括：

- `linalg` 层的整体算子语义
- `scf` / `affine` 层的循环与 tile 结构
- `vector` 层的向量计算形式
- `arm_sme` 层的目标架构计算形式

据此建立Cost Module，进行预取决策

### 1.2 优化落地目标（杨宏飞）

研究如何基于高层 MLIR 中保留的访存与计算语义：

- 生成适合 SME 场景的预取策略，（考虑CPU、SVE、SME并行时的数据调度）
- 将预取指令插入到MLIR中
- 将预取语义跨层 lowering 到 LLVM IR
- 验证 LX2 硬件上的功能正确性和性能收益

## 2. 总体技术路线

```
C kernel
-> 高层 MLIR（linalg / scf / affine）（通过自定义的提升器将c语言转化成高层MLIR）
-> 高层语义分析

-> 预取语义注入
-> vector 化
-> ArmSME lowering
-> LLVM IR / Target-specific intrinsics
-> 实机验证
```

## 3.**输入程序**

输入程序选取为规则分块的 GEMM kernel，参考国防科大论文的实现方案，体现 `mc / nc / kc / mr / nr` 分块结构，避免显式 SME intrinsic、汇编、复杂指针技巧和运行时机制。这样做的目的是让自定义前端更方便把输入程序转换到高层 MLIR。

第一步的目标是跑通实验流程，所以对输入程序进行了简化：仅包含单个 kernel 函数、规则的 `for` 循环、固定格式的语义标注注释、只保留 `C=A*B`、

## 4.各层 MLIR语义信息

### 5.1 `linalg` 层

这一层负责表达最核心的矩阵乘算子语义。

当前 C kernel 的核心数学语义：

```text
C = A * B
```

### 5.2 `scf` / `affine` 层

这一层负责表达循环结构、tile 结构和访存关系。

当前 C 程序中的：

- `i / j / k` 外层块循环
- `ii / jj / kk` 内层微块与归约循环

### 5.3 `vector` 层

这一层负责表达向量化后的计算形式。

连接高层算子语义与 SME 目标形式

### 5.4 `arm_sme` 层

这一层负责表达最终面向 SME 的目标计算形式。

### 5.5 `llvm` 层

- 验证目标 intrinsic 是否保真传递
- 观察最终目标代码生成结果

## 5.实验内容

### 5.1 高层语义分析（蒋涛）

高层语义分析应主要在 `linalg` 和 `affine/scf` 层开展。

### 5.2 预取语义表示与 IR 注入

对于affine层的mlir，根据语义分析的结果，表达以下预取相关语义：

- 读 / 写预取
- 预取距离
- 目标缓存层级
- `KEEP / STRM`

将预取语义作为单独的中间表示来设计，自定义预取 op实现，通过**自定义 MLIR pass**或者**Transform Dialect 脚本**实现注入

预取决策要考虑CPU、SVE、SME并行的情况。SME一般是计算完整的分块，SVE一般用于计算矩阵边界、CPU负责其他计算。

### 5.3 Vector / ArmSME / LLVM 降级

预取注入后的 MLIR 需要继续完成 lowering，最终降级到llvm层，并且需要保留上层注入的预取语义，需要编写Pass实现

```
linalg/scf/affine
-> vector
-> arm_sme
-> llvm
```

### 5.4实验验证

功能性验证：

1. 毕昇是否接受生成的 LLVM IR
2. 目标预取 intrinsic 是否被识别
3. 预取语义是否保留
4. 最终汇编中是否出现目标预取指令

性能验证：

实验一：利用毕昇编译器编译三个版本并在 LX2 上运行，配合 ARM PMU 计数器（如 `perf stat -e r0004` 等硬件事件）抓取 L2D 缺失率：

1. **Baseline 1 (No Prefetch)**：原始代码，纯靠硬件自动预取。
2. **Baseline 2 (BiSheng Native Prefetch)**：开启毕昇编译器自研的软件预取优化。
3. **Proposed (MLIR Polyhedral Model + BiSheng)**：关闭毕昇自带预取，由你的多面体模型控制发射

实验二：不规则控制流下的带宽与吞吐表现（FlagGEMM）

在不同的 Flag 稀疏度（0.1 到 0.9）下，对比性能（GFLOPS）