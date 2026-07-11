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

本方案的总体技术路线分为六个阶段。每个阶段都需要明确：

- 起始条件：这一阶段开始时手里已经有什么
- 采用的技术：这一阶段准备用什么方法解决问题
- 形成的产出：这一阶段结束后要得到什么中间结果
- 与研究目标的对应关系：这一阶段解决了目标中的哪一部分问题

整体主线如下：

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

#### 阶段一：构造受限 C kernel 输入

起始条件：

- 已有国防科大论文中的 GEMM 思路
- 已明确当前研究先以规则 dense GEMM 为入口

采用的技术：

- 将原始实现收缩为受限 C 子集
- 只保留规则分块循环、规则矩阵访存和固定语义标注
- 去掉显式 SME intrinsic、汇编、复杂运行时与线程机制

形成的产出：

- 一个适合自动分析和提升的 C kernel
- 明确的语义标注，如 `@kernel / @semantic / @blocking / @lift-target`

与研究目标的对应关系：

- 对应“高层计算语义在传统编译链中快速丢失”的问题
- 为后续“自定义提升器恢复高层语义”提供稳定输入

#### 阶段二：自定义提升器将 C kernel 转换为高层 MLIR

起始条件：

- 已有受限 C kernel
- 已限定输入语言范围，例如单 kernel、规则 `for` 循环、规则数组访问

采用的技术：

- 使用自定义提升器识别循环结构和矩阵乘模式
- 将 C 程序提升到 `linalg / scf / affine` 层
- 显式恢复：
  - 矩阵乘语义
  - 归约维与空间维
  - tile 结构

形成的产出：

- 高层 MLIR
- 可供后续分析的：
  - `linalg.matmul`
  - `scf.for`
  - `affine.for`
  - 明确的访存与归约结构

与研究目标的对应关系：

- 对应“高层表示目标”
- 解决“高层语义在传统编译链中快速丢失”的问题
- 为后续 Cost Module 和预取决策提供输入

#### 阶段三：高层语义分析与 Cost Module

起始条件：

- 已得到高层 MLIR
- 已在 `linalg` 和 `affine/scf` 层保留算子、循环、tile 和访存结构

采用的技术：

- 在 `linalg` 层分析整体数据流性质
- 在 `affine/scf` 层分析：
  - stride
  - reuse distance
  - working set
  - cache line / 跨行 / 跨块特征
- 构建 Cost Module，给出预取决策

形成的产出：

- 一份结构化的预取决策结果，包括：
  - 是否预取
  - 读 / 写预取
  - 预取距离
  - 目标缓存层级
  - `KEEP / STRM`

与研究目标的对应关系：

- 对应“高层表示目标”中的语义理解部分
- 也是“优化落地目标”里预取策略生成的起点
- 直接回应“现有预取优化主要依赖后端启发式”的问题

#### 阶段四：预取语义表示与 IR 注入

起始条件：

- 已有高层 MLIR
- 已有 Cost Module 输出的预取决策结果

采用的技术：

- 设计统一的预取中间表示
- 通过自定义 MLIR pass 或 Transform Dialect 脚本完成注入
- 在 IR 中显式表达：
  - 读 / 写预取
  - 距离
  - 缓存层级
  - `KEEP / STRM`

形成的产出：

- 带预取语义的高层 MLIR
- 可继续 lowering 的中间 IR

与研究目标的对应关系：

- 对应“优化落地目标”中的预取语义注入部分
- 直接应对“预取语义在跨层 lowering 时容易丢失”的问题

#### 阶段五：从高层 MLIR 降级到 Vector / ArmSME / LLVM

起始条件：

- 已得到带预取语义的高层 MLIR

采用的技术：

- 使用 `linalg/scf/affine -> vector -> arm_sme -> llvm` 的 lowering 路径
- 对需要保留的预取语义编写自定义 pass 或 conversion 逻辑
- 结合本地已有 ArmSME 相关 pass 与 lowering 流程

形成的产出：

- 带目标相关预取形式的 LLVM IR
- 或带 target-specific intrinsic 的 IR
- 可交给毕昇编译器处理的后端输入

与研究目标的对应关系：

- 对应“优化落地目标”中的跨层 lowering 部分
- 解决“预取语义从高层 IR 到 LLVM IR 的传递问题”

#### 阶段六：毕昇编译与 LX2 实机验证

起始条件：

- 已得到可被后端接受的 LLVM IR
- 已生成包含预取语义的目标输入

采用的技术：

- 使用毕昇编译器完成后端编译
- 在 LX2 实机上运行
- 使用 PMU / `perf` 等工具进行功能与性能测量

形成的产出：

- 功能性验证结果：
  - LLVM IR 是否被接受
  - 预取 intrinsic 是否被识别
  - 最终汇编中是否出现目标预取指令
- 性能验证结果：
  - 与 `No Prefetch` baseline 的对比
  - 与 `BiSheng Native Prefetch` 的对比
  - 在 GEMM / FlagGEMM 下的 GFLOPS、L2 miss 等数据

与研究目标的对应关系：

- 对应总体目标中的“实现比 baseline 更优的性能效果”
- 是整个方案最终闭环的验证阶段

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
