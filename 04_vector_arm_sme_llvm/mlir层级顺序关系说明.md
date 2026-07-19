# 04 MLIR 层级顺序关系说明

这份文档说明第四步中涉及的 MLIR 层级顺序，以及当前 `output/` 目录中三个主线文件分别对应哪一层。

需要先明确一点：MLIR 不是只有一条固定的“高层 -> 低层”直线。一个 IR 文件中可以同时出现多个 dialect，例如 `func`、`arith`、`memref`、`scf`、`vector` 可以共存在同一阶段。所谓“层级顺序”，更多是指研究和 lowering 时的主要抽象层次逐步降低。

---

## 1. 第四步主线

当前第四步只保留下面这一条主线：

```text
input/gemm_step4_compute_mainline.mlir
-> output/01_vector_prefetch.mlir
-> output/02_arm_sme_prefetch.mlir
-> output/03_llvm_prefetch.mlir
-> LLVM IR .ll
```

其中：

- `input/gemm_step4_compute_mainline.mlir` 是高层 `linalg.matmul` 输入和 transform dialect 调度描述。
- `output/01_vector_prefetch.mlir` 是 vector 化后插入 `memref.prefetch` 的结果。
- `output/02_arm_sme_prefetch.mlir` 是继续降到 Arm SME 相关表示后的结果。
- `output/03_llvm_prefetch.mlir` 是最终 LLVM dialect 结果，可以导出为 LLVM IR。

旧的 `01_affine_prefetch_std.mlir` 和早期证据版 `03_llvm_prefetch.mlir` 已删除，因为它们只是验证 `research.prefetch -> affine.prefetch -> llvm.intr.prefetch` 的支线产物，并不参与当前最终主线。

---

## 2. 各层的定位

### 2.1 高层 MLIR 输入

第 04 步当前输入是：

- [input/gemm_step4_compute_mainline.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/input/gemm_step4_compute_mainline.mlir)

它包含两部分：

- `linalg.matmul`：表达矩阵乘的整体计算语义
- transform dialect：描述如何对 `linalg.matmul` 进行 tiling、vectorization 和 bufferization

这一层适合回答：

```text
矩阵计算是什么？
希望如何把矩阵计算推进到 vector 形式？
```

### 2.2 Vector + MemRef Prefetch 层

对应文件：

- [output/01_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/01_vector_prefetch.mlir)

这一层已经出现向量计算结构，例如：

- `vector.transfer_read`
- `vector.transfer_write`
- `vector.outerproduct`
- `vector.mask`

第 04 步自定义 pass `step4-inject-vector-memref-prefetch` 会在 rank-1 `vector.transfer_read` 前插入：

```mlir
memref.prefetch ..., read, locality<3>, data
```

因此这个文件是观察“SME 计算主线中如何带上预取语义”的关键起点。

### 2.3 Arm SME 层

对应文件：

- [output/02_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/02_arm_sme_prefetch.mlir)

这一层由 `01_vector_prefetch.mlir` 继续执行 `-test-lower-to-arm-sme` 得到。

在这一层可以看到：

- `llvm.arm_locally_streaming`
- `llvm.arm_new_za`
- `arm_sme` / `arm_sve` 相关 op 或 intrinsic
- 仍然可能存在 `memref`、`scf`、`arith` 等混合 dialect

这说明计算已经进入 Arm SME 相关表示，但还没有完全收口到 LLVM dialect。

### 2.4 LLVM Dialect 层

对应文件：

- [output/03_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir)

这一层是第 04 步当前最终输出。

它包含：

- `llvm.func`
- `llvm.br`
- `llvm.cond_br`
- `llvm.getelementptr`
- `llvm.load` / `llvm.store`
- `llvm.intr.prefetch`
- `arm_sme.intr.*`
- `arm_sve.intr.*`

其中预取已经表现为：

```mlir
"llvm.intr.prefetch"(...)
```

这个文件已经可以继续通过：

```bash
mlir-translate --mlir-to-llvmir
```

导出为 LLVM IR `.ll`。

---

## 3. 当前输出文件对应关系

| 文件 | 所在层级 | 作用 |
| --- | --- | --- |
| `output/01_vector_prefetch.mlir` | vector / memref | 证明 vector 计算主线中已经插入 `memref.prefetch` |
| `output/02_arm_sme_prefetch.mlir` | Arm SME 相关层 | 证明带预取的 vector 主线可以继续进入 Arm SME 表示 |
| `output/03_llvm_prefetch.mlir` | LLVM dialect | 证明最终主线中保留了 `llvm.intr.prefetch`，并可导出 LLVM IR |

---

## 4. 为什么仍会看到多个 dialect 共存

在 MLIR lowering 中，常见情况是：

- 一部分 op 已经降到低层
- 另一部分 op 仍停留在较高层
- 多个 dialect 在同一个文件中共存
- lowering pipeline 会分多轮逐步消除高层 op

例如在 `01_vector_prefetch.mlir` 中，主要研究对象是 `vector` 计算和 `memref.prefetch`，但文件中仍然可以存在：

- `func.func`
- `arith.constant`
- `memref.subview`
- `scf.for`

这并不矛盾。它说明当前文件处于“以 vector 为主要计算表达，但还没有完全降到 LLVM dialect”的阶段。

---

## 5. 与前三步的关系

前三步用于研究：

```text
C kernel
-> 高层 MLIR
-> 数据流 / 预取分析
-> 预取决策
```

第 04 步当前聚焦：

```text
vector 计算形态中的预取插入
-> Arm SME lowering
-> LLVM dialect lowering
```

因此第 04 步不再保存 `research.prefetch -> affine.prefetch` 的支线输出。那些内容仍然可以作为方案背景理解，但当前正式产物只看 `01 -> 02 -> 03`。

---

## 6. 阅读建议

建议按下面顺序阅读：

1. 先看 [README.md](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/README.md)，理解第 04 步单主线。
2. 再看 [output/01_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/01_vector_prefetch.mlir)，观察 `vector.transfer_read` 前的 `memref.prefetch`。
3. 接着看 [output/02_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/02_arm_sme_prefetch.mlir)，观察 Arm SME 相关表示。
4. 最后看 [output/03_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir)，确认 `llvm.intr.prefetch` 已保留到 LLVM dialect。

---

## 7. 一句话总结

第 04 步现在只保留一条主线：从 `linalg.matmul` 出发，进入 vector，在 vector 读前插入预取，再降到 Arm SME 和 LLVM dialect，最终形成可导出 LLVM IR 的 `03_llvm_prefetch.mlir`。
