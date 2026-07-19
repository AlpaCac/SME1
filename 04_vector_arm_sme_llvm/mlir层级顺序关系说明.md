# 04 MLIR 层级顺序关系说明

这份文档说明第四步涉及的 MLIR 层级顺序，以及当前 `output/` 目录中两个主线文件分别对应哪一层。

需要先明确一点：MLIR 不是只有一条固定的“高层 -> 低层”直线。一个 IR 文件中可以同时出现多个 dialect，例如 `func`、`arith`、`memref`、`scf`、`vector` 可以共存在同一阶段。所谓“层级顺序”，更多是指研究和 lowering 时的主要抽象层次逐步降低。

## 1. 当前主线

当前第四步主线是：

```text
03_prefetch_injection/output/02_vector_prefetch.mlir
-> 04_vector_arm_sme_llvm/output/01_arm_sme_prefetch.mlir
-> 04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir
-> LLVM IR .ll
```

其中：

- `03_prefetch_injection/output/02_vector_prefetch.mlir` 是第三步产物，已经包含 vector 计算和 `memref.prefetch`。
- `output/01_arm_sme_prefetch.mlir` 是继续降到 Arm SME 相关表示后的结果。
- `output/02_llvm_prefetch.mlir` 是最终 LLVM dialect 结果，可以导出为 LLVM IR。

第 04 步不再使用单独的 `input/gemm_step4_compute_mainline.mlir`，也不再生成 `01_vector_prefetch.mlir`。vector 层预取注入已经由第 03 步负责完成。

## 2. Vector + MemRef Prefetch 层

对应文件：

- [../03_prefetch_injection/output/02_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/02_vector_prefetch.mlir)

这一层是第 04 步输入。它包含：

- `vector.transfer_read`
- `vector.transfer_write`
- `vector.outerproduct`
- `vector.mask`
- `memref.prefetch`

这一层适合观察：

```text
矩阵乘是否已经变成 vector 外积结构？
第三步是否已经把预取插入到 A/B 的 vector 读前？
```

## 3. Arm SME 层

对应文件：

- [output/01_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/01_arm_sme_prefetch.mlir)

这一层由第三步输出继续执行：

```bash
mlir-opt 03_prefetch_injection/output/02_vector_prefetch.mlir -test-lower-to-arm-sme
```

在这一层可以看到：

- `llvm.arm_locally_streaming`
- `llvm.arm_new_za`
- `arm_sme` / `arm_sve` 相关 op 或 intrinsic
- `memref.prefetch`
- `memref`、`arith`、`cf` 等混合 dialect

这说明 vector 计算已经开始进入 Arm SME 相关表示，同时预取语义还没有丢失。

## 4. LLVM Dialect 层

对应文件：

- [output/02_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir)

这一层是第 04 步最终输出。

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

## 5. 为什么仍会看到多个 dialect 共存

在 MLIR lowering 中，常见情况是：

- 一部分 op 已经降到低层
- 另一部分 op 仍停留在较高层
- 多个 dialect 在同一个文件中共存
- lowering pipeline 会分多轮逐步消除高层 op

例如在 `01_arm_sme_prefetch.mlir` 中，主要研究对象是 Arm SME 相关表示，但文件中仍然可以存在：

- `memref.prefetch`
- `arith.constant`
- `memref.subview`
- `cf.br`

这并不矛盾。它说明当前文件处于“计算已经进入 Arm SME 表示，但尚未完全收口到 LLVM dialect”的阶段。

## 6. 与前三步的关系

前三步完成：

```text
C kernel
-> linalg 层 MLIR
-> affine-normalized 预取分析
-> vector 层预取注入
```

第四步从第三步结果继续：

```text
vector + memref.prefetch
-> Arm SME lowering
-> LLVM dialect lowering
-> LLVM IR 导出
```

因此第四步的任务不是重新生成 vector，也不是重新做预取决策，而是验证第三步形成的预取主线能否继续降低并保留。

## 7. 阅读建议

建议按下面顺序阅读：

1. 先看 [../03_prefetch_injection/output/02_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/02_vector_prefetch.mlir)，确认输入已经有 `vector.outerproduct` 和 `memref.prefetch`。
2. 再看 [output/01_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/01_arm_sme_prefetch.mlir)，观察 Arm SME 相关表示和仍然保留的 `memref.prefetch`。
3. 最后看 [output/02_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir)，确认 `llvm.intr.prefetch` 已保留到 LLVM dialect。

## 8. 一句话总结

第 04 步现在只做一件事：接住第三步已经插入预取的 vector 层 MLIR，继续把同一条主线降到 Arm SME 和 LLVM dialect，验证预取语义没有在跨层 lowering 中丢失。
