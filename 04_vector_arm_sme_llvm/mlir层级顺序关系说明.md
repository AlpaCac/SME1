# 04 MLIR 层级顺序关系说明

这份文档说明第四步中涉及的 MLIR 各个层级之间的顺序关系，以及当前仓库中的输出文件分别对应哪一层。

需要先明确一点：MLIR 不是只有一条固定的“高层 -> 低层”直线。一个 IR 文件中可以同时出现多个 dialect，例如 `func`、`arith`、`memref`、`scf`、`vector` 可以共存在同一阶段。所谓“层级顺序”，更多是指研究和 lowering 时的主要抽象层次逐步降低。

---

## 1. 总体顺序

当前方案关注的是面向 Arm SME 的矩阵计算和预取优化，因此可以把整体顺序理解为：

```text
C kernel
-> 高层 MLIR
-> linalg / affine
-> research.prefetch
-> affine.prefetch / memref.prefetch
-> vector
-> arm_sme
-> llvm dialect
-> LLVM IR .ll
-> AArch64 / SME 汇编
```

其中第四步主要覆盖的是：

```text
带预取语义的高层 MLIR
-> vector
-> arm_sme
-> llvm dialect
-> LLVM IR
```

---

## 2. 各层的定位

### 2.1 C kernel

C kernel 是输入程序层。

它描述的是用户想要计算什么，例如：

```c
C = A * B
```

但 C 代码本身不显式表达 MLIR 中的高层结构，例如 `linalg.matmul`、`affine.for`、`vector.transfer_read` 或 `arm_sme` op。因此第一步需要把 C kernel 提升到 MLIR。

### 2.2 高层 MLIR

高层 MLIR 用来保留计算语义、循环结构和访存关系。

当前项目中，高层 MLIR 主要有两类表示：

- `linalg` 层：更接近“整体张量/矩阵计算语义”
- `affine` 层：更接近“可分析的循环、下标和访存结构”

`linalg` 适合表达“这是矩阵乘”；`affine` 适合研究循环分块、访存模式、reuse distance 和预取距离。

### 2.3 research.prefetch

`research.prefetch` 是项目自定义的研究层预取语义。

它的位置仍然偏高层，目的是保存第二步 cost module 的决策，例如：

- 预取对象是 `A` 还是 `B`
- 是读预取还是写预取
- 优先级是 `high` 还是 `medium`
- 目标缓存层级是 `L1`
- 高层预取距离如何描述

当前第三步已经通过插件注册了 `research.prefetch`，但文本上仍采用 MLIR generic assembly 形式打印：

```mlir
"research.prefetch"(...)
```

### 2.4 affine.prefetch / memref.prefetch

`affine.prefetch` 和 `memref.prefetch` 是更接近 MLIR 标准预取表示的层级。

它们相比 `research.prefetch` 更靠近具体内存访问，但能表达的信息更少。

例如：

```mlir
memref.prefetch %subview[%c0], read, locality<3>, data : memref<?xf32>
```

这一层通常已经不再完整保留 `priority = "high"` 或自然语言 `distance` 这样的研究字段。

### 2.5 vector

`vector` 层开始表达向量化计算。

在这一层，矩阵计算不再只是标量循环中的 `load/mulf/addf/store`，而会出现：

- `vector.transfer_read`
- `vector.transfer_write`
- `vector.outerproduct`
- `vector.create_mask`

这一层是从“循环和标量访存”走向“向量计算”的关键过渡层。

当前第四步中的对应文件是：

- [output/07_unified_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/07_unified_vector_prefetch.mlir)

### 2.6 arm_sme

`arm_sme` 层是面向 Arm Scalable Matrix Extension 的目标相关 MLIR 层。

这一层开始出现与 SME 相关的语义，例如：

- ZA tile 相关属性
- streaming mode 相关属性
- 面向 SME 的向量/矩阵 lowering 结果

在当前输出中，可以看到函数上出现：

```mlir
attributes {llvm.arm_locally_streaming, llvm.arm_new_za}
```

也可以看到和 SME tile 分配相关的属性：

```mlir
{arm_sme.in_memory_tile_id = ...}
```

当前第四步中的对应文件是：

- [output/08_unified_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/08_unified_arm_sme_prefetch.mlir)

### 2.7 LLVM dialect

LLVM dialect 是 MLIR 中接近 LLVM IR 的层级。

这一层仍然是 MLIR 文件，但操作已经接近 LLVM IR，例如：

- `llvm.func`
- `llvm.call`
- `llvm.load`
- `llvm.store`
- `llvm.br`
- `llvm.cond_br`
- `llvm.intr.prefetch`

它的作用是作为 MLIR 到 LLVM IR `.ll` 的最后桥梁。

当前第四步中的对应文件是：

- [output/09_unified_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir)

### 2.8 LLVM IR .ll

LLVM IR `.ll` 已经不再是 MLIR，而是 LLVM 的文本 IR。

从 MLIR 的 LLVM dialect 到 `.ll`，通常使用：

```bash
mlir-translate --mlir-to-llvmir
```

在这一层，预取通常会表现为 LLVM intrinsic：

```llvm
call void @llvm.prefetch(...)
```

### 2.9 AArch64 / SME 汇编

汇编层是最终后端输出。

如果预取最终保留下来，在 AArch64 上可能出现：

```asm
prfm ...
```

如果 SME 计算 lowering 成功，最终还可能出现 SME 相关指令。具体指令形式取决于 LLVM 后端、目标 CPU、编译参数和当前 lowering 是否已经完整。

---

## 3. 第四步当前文件对应关系

当前第四步不是保存所有中间文件，而是只保存关键证据文件。

| 文件 | 所在层级 | 说明 |
| --- | --- | --- |
| `output/01_affine_prefetch_std.mlir` | affine / 标准预取层 | 把第三步的 `research.prefetch` 桥接为 `affine.prefetch` |
| `output/03_llvm_prefetch.mlir` | LLVM dialect 预取层 | 证明预取语义可以降到 `llvm.intr.prefetch` |
| `output/07_unified_vector_prefetch.mlir` | vector 层 | 统一主线中，计算已经进入 vector，预取以 `memref.prefetch` 形式保留 |
| `output/08_unified_arm_sme_prefetch.mlir` | arm_sme 相关层 | 计算继续降到 Arm SME 相关表示，预取仍保留 |
| `output/09_unified_llvm_prefetch.mlir` | LLVM dialect 层 | 统一主线已经接近可导出 LLVM IR 的形式 |

---

## 4. 为什么不是简单的单线顺序

容易误解的一点是：

```text
affine -> vector -> arm_sme -> llvm
```

看起来像每一层都会完全替换上一层。实际并不总是这样。

在 MLIR lowering 中，常见情况是：

- 一部分 op 已经降到低层
- 另一部分 op 仍停留在较高层
- 多个 dialect 在同一个文件中共存
- lowering pipeline 会分多轮逐步消除高层 op

例如在 vector 层文件中，仍然可以看到：

- `func.func`
- `arith.constant`
- `memref.subview`
- `scf.for`
- `vector.transfer_read`
- `memref.prefetch`

这并不矛盾。它说明当前文件处于“以 vector 为主要计算表达，但还没有完全降到 LLVM dialect”的阶段。

---

## 5. 当前方案中的两类语义下沉

第四步实际同时处理两类语义：

```text
计算语义下沉：
linalg / affine
-> vector
-> arm_sme
-> llvm dialect

预取语义下沉：
research.prefetch
-> affine.prefetch / memref.prefetch
-> llvm.intr.prefetch
-> LLVM IR @llvm.prefetch
-> AArch64 prfm
```

这两类语义的 lowering 节奏并不完全一致。

当前第四步的研究重点，就是让它们在统一主线中重新汇合：

```text
vector / arm_sme 计算主线
+ 预取语义
-> 统一 LLVM dialect 输出
```

---

## 6. 阅读第四步输出的建议顺序

建议按下面顺序阅读：

1. 先看 [README.md](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/README.md)，理解第四步统一主线。
2. 再看 [prefetch参数映射说明.md](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/prefetch参数映射说明.md)，理解预取参数如何逐层压缩。
3. 然后看 `output/07_unified_vector_prefetch.mlir`，观察 `vector` 计算和 `memref.prefetch` 如何共存。
4. 接着看 `output/08_unified_arm_sme_prefetch.mlir`，观察 Arm SME 相关属性和结构。
5. 最后看 `output/09_unified_llvm_prefetch.mlir`，确认统一主线已经接近 LLVM IR。

---

## 7. 一句话总结

第四步的 MLIR 层级关系不是“所有 dialect 一次性从高层消失”，而是“计算语义和预取语义在多个 dialect 中逐步降低抽象层级，最终在 LLVM dialect / LLVM IR 附近汇合”。
