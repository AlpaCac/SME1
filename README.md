# 方案整理

## 1. 研究目标

本实验的总体目标是：

针对 现有预取优化主要依赖后端启发式、高层计算语义在传统编译链中快速丢失、预取语义在跨层 lowering 时容易丢失的问题，

采用“C kernel + 自定义提升器 + 高层 MLIR 语义分析 + 预取语义注入 + LLVM lowering + LX2 验证”的方法，

实现一套面向 GEMM 的高层 IR 驱动预取优化链路，

并期望在 LX2 实机上获得优于无预取 baseline 的性能结果。

## 2.研究问题

### 2.1 现有预取优化主要依赖后端启发式，缺少高层语义支撑

现有预取优化通常出现在 LLVM 或目标后端，主要依赖：

- 局部访存模式
- 静态启发式规则
- 硬件自动预取器的假设

这种方式缺少计算语义的支撑， 对于 SME 场景下的大规模分块矩阵计算，单纯依赖后端启发式未必能得到最优效果。

### 2.2 高层计算语义在传统编译链中快速丢失

对于面向 ARM SME 的矩阵计算程序，若直接采用传统的：

```text
C/C++ -> Clang -> LLVM IR
```

编译流程，则源程序中的很多高层信息会很快退化为低层指针、load/store 和标量算术，很多计算语义难以继续保留，这使得后续很难在编译中端阶段针对 SME 场景进行结构化优化。

### 2.3 预取语义在跨层 lowering 时容易丢失

即使在高层 IR 中做出了合理的预取决策，仍然存在一个关键难点：如何将预取语义从 `linalg / affine / scf / vector`一直保留到 `arm_sme` / LLVM IR，并最终映射成编译器能够识别的目标预取形式。

## 3.研究方案

### 3.1 总体技术路线

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

### 3.2 高层语义分析（蒋涛）

高层语义分析应主要在 `linalg` 和 `affine/scf` 层开展。

### 3.3 预取语义表示与 IR 注入

对于affine层的mlir，根据语义分析的结果，表达以下预取相关语义：

- 读 / 写预取
- 预取距离
- 目标缓存层级
- `KEEP / STRM`

将预取语义作为单独的中间表示来设计，自定义预取 op实现，通过**自定义 MLIR pass**或者**Transform Dialect 脚本**实现注入

预取决策要考虑CPU、SVE、SME并行的情况。SME一般是计算完整的分块，SVE一般用于计算矩阵边界、CPU负责其他计算。

### 3.4 Vector / ArmSME / LLVM 降级

预取注入后的 MLIR 需要继续完成 lowering，最终降级到llvm层，并且需要保留上层注入的预取语义，需要编写Pass实现

```
linalg/scf/affine
-> vector
-> arm_sme
-> llvm
```

## 4. 实验验证

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

