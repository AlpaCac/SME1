# 面向 ARM SME 的高层 MLIR 预取优化研究方案

## 1. 研究背景

ARM SME 为矩阵计算提供了专用的向量/Tile 计算能力，但从高层程序语义到 SME 指令之间仍然存在明显鸿沟。

一方面，C/C++ 源程序中的矩阵计算语义在经过传统编译链后，往往很快退化为低层 LLVM IR，难以保留：

- 矩阵乘的整体结构
- 归约维与空间维信息
- 分块与局部重用关系
- 与缓存、带宽、预取相关的高层访存语义

另一方面，现有后端的预取优化多基于启发式规则，较少直接利用高层 IR 中可见的计算与访存结构。因此，若希望研究 SME 场景下更可控的预取策略，需要在高层 MLIR 中显式保留和利用这些语义，再逐层向下传递到 ArmSME 与 LLVM 后端。

## 2. 研究目标

本课题的总体目标是：

从受限 C 矩阵计算程序出发，构建一条“高层 MLIR 语义分析 + 预取策略生成 + ArmSME/LLVM lowering + 毕昇/LX2 验证”的完整研究链路，用于探索面向 ARM SME 的高层 IR 驱动预取优化方法。

具体可分为两个子目标：

### 2.1 高层表示目标

研究 SME 相关矩阵计算在高层 MLIR 中的合适表示形式，包括：

- `linalg` 层的整体算子语义
- `scf` / `affine` 层的循环与 tile 结构
- `vector` 层的向量计算形式
- `arm_sme` 层的目标架构计算形式

### 2.2 优化落地目标

研究如何基于高层 MLIR 中保留的访存与计算语义：

- 分析数据流重用与工作集特征
- 生成适合 SME 场景的预取策略
- 将预取语义跨层 lowering 到 LLVM IR
- 验证毕昇编译器与 LX2 硬件上的功能正确性和性能收益

## 3. 总体技术路线

本研究采用如下主线：

```text
受限 C kernel
-> 自定义提升器
-> 高层 MLIR（linalg / scf / affine）
-> 高层语义分析
-> 预取语义注入
-> vector 化
-> ArmSME lowering
-> LLVM IR / Target-specific intrinsics
-> 毕昇编译
-> LX2 实机验证
```

其中，当前仓库中的 [gemm_mlir_kernel.c](/Users/alpaca/Documents/SME/SME1/gemm_mlir_kernel.c) 作为受限输入程序，主要承担“规则语义输入”的角色，而不是直接由 `clang` 生成高层 ArmSME MLIR。

## 4. 输入程序与受限 C 子集

### 4.1 输入程序定位

输入程序选取为规则分块的 GEMM kernel，其特点是：

- 只保留 `C = A * B` 语义
- 显式保留 `mc / nc / kc / mr / nr` 分块结构
- 使用规则循环和规则矩阵访存
- 避免显式 SME intrinsic、汇编、复杂指针技巧和运行时机制

这样做的目的是让输入程序更接近“可解析的 DSL”，便于自定义前端把它提升到高层 MLIR。

### 4.2 受限 C 子集假设

为降低前端实现复杂度，建议当前阶段仅支持以下子集：

- 单个 kernel 函数
- 规则 `for` 循环
- 明确的数组线性化访问
- 标量乘加归约
- 固定格式的语义标注注释

暂不支持：

- 不规则控制流
- 指针别名复杂情况
- 显式向量类型
- `arm_sme.h` / `arm_sve.h` intrinsic
- OpenMP / 线程并行

## 5. 各层 MLIR 的角色划分

### 5.1 `linalg` 层

这一层负责表达最核心的矩阵乘算子语义。

当前 C kernel 的核心数学语义：

```text
C = A * B
```

最自然的高层表示是：

- `linalg.matmul`

这一层保留的是“算子级”信息，而不是具体每一条标量运算。

### 5.2 `scf` / `affine` 层

这一层负责表达循环结构、tile 结构和访存关系。

当前 C 程序中的：

- `i / j / k` 外层块循环
- `ii / jj / kk` 内层微块与归约循环

很适合映射成：

- `scf.for`
- `affine.for`

这一层是分析：

- 迭代空间
- 访存表达式
- 数据重用距离
- 工作集大小

的主要载体。

### 5.3 `vector` 层

这一层负责表达向量化后的计算形式。

通常路径不是直接从 C 保留显式 SIMD 类型，而是：

- `linalg.matmul`
- 经过 tiling / vectorize
- 再形成 `vector.contract` / `vector.outerproduct`

这一层是连接高层算子语义与 SME 目标形式的重要桥梁。

### 5.4 `arm_sme` 层

这一层负责表达最终面向 SME 的目标计算形式。

本地 LLVM/MLIR 中已有官方路径：

```text
linalg.matmul -> vector -> arm_sme
```

可参考：

- [ArmSME.md](/Users/alpaca/Documents/SME/external/llvm-project/mlir/docs/Dialects/ArmSME.md)
- [matmul.mlir](/Users/alpaca/Documents/SME/external/llvm-project/mlir/test/Integration/Dialect/Linalg/CPU/ArmSME/matmul.mlir)

这一层的重点是研究：

- `vector.outerproduct`
- `arm_sme.outerproduct`
- `arm_sme.fmopa`

之间的对应关系。

### 5.5 `llvm` 层

LLVM IR 和 LLVM dialect MLIR 主要用于：

- 与毕昇编译链衔接
- 验证目标 intrinsic 是否保真传递
- 观察最终目标代码生成结果

但不应作为高层语义研究主线。

## 6. 当前研究中的两条产物线

建议同时保留两条产物线：

### 6.1 高层研究线

```text
gemm_mlir_kernel.c
-> 自定义提升
-> linalg / scf / affine / vector / arm_sme
```

作用：

- 研究 SME 相关矩阵计算在高层 MLIR 中的形式
- 研究预取策略在高层 IR 中的生成与传递

### 6.2 低层对照线

```text
clang
-> LLVM IR
-> mlir-translate --import-llvm
```

作用：

- 观察同一份 C 在低层 LLVM dialect 中的形态
- 与高层研究线进行对照

## 7. 高层语义分析模块

高层语义分析应主要在 `linalg` 和 `affine/scf` 层开展。

### 7.1 在 `linalg` 层分析的数据流性质

目标是回答以下问题：

- 当前数据是小而热，还是大而冷
- 数据是否会被短期重复使用
- 是否适合保留在缓存中
- 是否更适合流式访问
- 哪些数据流可能污染 L2 / LLC

可生成的粗粒度策略包括：

- `KEEP`
- `STRM`
- 不预取

### 7.2 在 `affine/scf` 层分析的循环与访存信息

重点分析：

- 迭代空间
- 访存函数
- stride
- reuse distance
- working set
- 是否跨 cache line
- 是否适合硬件自动预取
- 预取距离 `D`

可采用近似模型：

```text
D = ceil(Memory_Latency_Cycles / SME_Compute_Cycles_Per_Block)
```

该层分析结果用于后续预取策略生成。

## 8. 预取语义表示与 IR 注入

### 8.1 目标

在高层 MLIR 中表达以下预取相关语义：

- 读 / 写预取
- 预取距离
- 目标缓存层级
- `KEEP / STRM`
- 条件掩码
- gather / unit-stride / tile 访问模式

### 8.2 建议做法

建议将预取语义作为单独的中间表示来设计，而不要直接依赖最终 LLVM intrinsic。

实现上可考虑两种方式：

1. 自定义预取 op
- 例如 `sme.prefetch`
- 语义集中，便于跨层传递

2. 现有 op + attribute
- 轻量，但可维护性较差

从研究清晰度来看，更推荐先定义一个专门的预取 op 或至少统一的属性规范。

### 8.3 注入方式

这一阶段可以通过两类机制实现：

- 自定义 MLIR pass
- Transform Dialect 脚本

建议先实现 pass，再考虑更通用的 transform 机制。  
原因是 pass 更适合快速验证端到端链路。

## 9. Vector / ArmSME / LLVM 降级路径

预取注入后的 MLIR 需要继续完成 lowering。

建议的主要路径是：

```text
linalg/scf/affine
-> vector
-> arm_sme
-> llvm
```

### 9.1 `vector` 层关键变换

参考本地样例，关键步骤通常包括：

- tile
- vectorize
- bufferize
- `vector.contract -> vector.outerproduct`

### 9.2 `arm_sme` 层关键目标

希望最终观察到的目标形式包括：

- `arm_sme.outerproduct`
- `arm_sme.fmopa`

### 9.3 LLVM IR 层关键问题

需要重点关注：

- 预取语义是否保真传递
- 是否需要 target-specific intrinsic
- `KEEP / STRM` 是否还能表示
- predicate / gather 信息是否丢失

## 10. 毕昇编译与 LX2 实机验证

### 10.1 功能性验证

需要验证：

1. 毕昇是否接受生成的 LLVM IR
2. 目标预取 intrinsic 是否被识别
3. predicate / gather / policy 语义是否保留
4. 最终汇编中是否出现目标预取指令

### 10.2 性能验证

建议至少比较三个版本：

1. Baseline 1: No Prefetch
2. Baseline 2: BiSheng Native Prefetch
3. Proposed: MLIR-guided Prefetch

建议采集指标：

- 运行时间
- GFLOPS
- L2 miss rate
- memory bandwidth
- stall cycles

### 10.3 扩展实验

在主链路跑通后，再研究：

- Skinny GEMM
- 不规则矩阵形态
- FlagGEMM
- 稀疏度变化对预取收益的影响

## 11. 当前最需要手工实现的部分

这几部分是当前课题的核心手工工作：

### 11.1 `C -> 高层 MLIR` 提升器

这是整个方案里最关键的入口。

需要手工决定：

- 用 Clang AST
- 或 `clang -Xclang -ast-dump=json`
- 或更小型的语法匹配器

需要手工实现：

- 哪类循环识别为 tile
- 哪类乘加识别为 matmul
- 何时产生 `linalg.matmul`
- 何时保留 `scf/affine`

### 11.2 预取语义表示

需要自己设计：

- 预取 op / attribute 形式
- 跨层传递规则
- lowering 到 LLVM 的映射规则

### 11.3 降级策略配置

虽然 LLVM/MLIR 有现成 pass，但仍需自己决定：

- tile size
- vectorize 策略
- bufferize 时机
- 进入 `arm_sme` 的时机

## 12. 最小可落地版本（V1）

建议首先只做一个可验证的最小版本。

### 12.1 V1 范围

- 只做 FP32 GEMM
- 只做 dense matmul
- 只做规则 unit-stride 读预取
- 暂不做 gather prefetch
- 暂不做复杂 predicate prefetch
- 暂不做 FlagGEMM
- 暂不做 `KEEP / STRM` 全搜索

### 12.2 V1 实施步骤

1. 以 [gemm_mlir_kernel.c](/Users/alpaca/Documents/SME/SME1/gemm_mlir_kernel.c) 为受限输入
2. 先手工写一个对应的 `linalg.matmul` 版 MLIR 文件
3. 对照本地样例验证 `linalg -> vector -> arm_sme` 路径
4. 实现最小版 `C -> 高层 MLIR` 提升器
5. 在 `affine/scf/vector` 某层插入简单预取语义
6. 降到 LLVM 并接毕昇
7. 在 LX2 上验证功能与性能

## 13. 预期产出

本课题预期形成以下产出：

1. 一套受限 C kernel 输入规范
2. 一套 `C -> 高层 MLIR` 提升规则
3. 一套高层语义驱动的预取分析方法
4. 一套预取语义在 MLIR 中的表示与 lowering 方法
5. 面向 ARM SME 的端到端实验链路
6. 在毕昇 + LX2 环境上的功能与性能验证结果

## 14. 当前建议的下一步

从研发顺序上，最建议立刻做的两件事是：

1. 手工编写一个与当前 C kernel 对应的 `linalg.matmul` 版 `.mlir`
2. 明确“预取语义在 MLIR 中如何表示”的最小设计

只有这两步明确下来，后续的自动提升与 lowering 才能稳定推进。
