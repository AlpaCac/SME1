# 04 Arm SME / LLVM 降级

本目录实现总体方案的第四步：在第三步已经得到的 vector 层预取 MLIR 基础上，继续降到 Arm SME 相关表示和 LLVM dialect。

第四步不再重新执行 `linalg -> vector`，也不再重新插入预取。第三步已经完成：

```text
01_custom_lifter/output/gemm_fp32_linalg.mlir
-> 03_prefetch_injection/output/01_vector.mlir
-> 03_prefetch_injection/output/02_vector_prefetch.mlir
```

因此第四步的起点固定为：

```text
03_prefetch_injection/output/02_vector_prefetch.mlir
```

这能保证总体方案是一条连续主线，而不是第 04 步重新构造另一份计算 IR。

## 1. 第四步目标

第四步对应总体方案中的这一段：

```text
带预取语义的 vector 层 MLIR
-> Arm SME 相关表示
-> LLVM dialect
-> LLVM IR
```

目标是验证两个问题：

- 第三步插入的 `memref.prefetch` 能否随计算主线继续降低。
- vector 层矩阵计算能否进入 Arm SME / LLVM 表示，并最终导出为 LLVM IR。

## 2. 输入和输出

输入：

- [../03_prefetch_injection/output/02_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/02_vector_prefetch.mlir)

输出：

- [output/01_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/01_arm_sme_prefetch.mlir)
- [output/02_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir)

两份输出是一条连续 lowering 主线：

```text
03_prefetch_injection/output/02_vector_prefetch.mlir
-> 04_vector_arm_sme_llvm/output/01_arm_sme_prefetch.mlir
-> 04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir
-> LLVM IR .ll
```

## 3. 第四步具体做了什么

第一步，使用 MLIR 官方测试 lowering pipeline 将第三步的 vector 主线降到 Arm SME 相关表示：

```text
vector.transfer_read / vector.outerproduct / vector.transfer_write
memref.prefetch
-> arm_sme / arm_sve 相关 op 或 intrinsic
仍保留 memref.prefetch
```

第二步，在同一条主线上继续降到 LLVM dialect：

```text
arm_sme / arm_sve 混合 MLIR
memref.prefetch
-> llvm.func / llvm.br / llvm.getelementptr / llvm.intr.prefetch
```

第三步，运行第 04 步自定义 repair pass，清理末端少量 `i64 -> index -> i32` 桥接残留，使最终 MLIR 可以被 `mlir-translate --mlir-to-llvmir` 导出。

## 4. 为什么第四步不再插入预取

按照当前总体方案，职责划分是：

- 第三步：从 linalg 主线生成 vector 层，并根据第二步 cost model 决策插入 `memref.prefetch`。
- 第四步：消费第三步结果，验证预取语义能否继续降到 Arm SME / LLVM。

如果第 04 步再次插入预取，会造成两个问题：

- 主线不连续，看起来像第 04 步重新生成了一条新的 vector 计算路线。
- 很难判断最终 `llvm.intr.prefetch` 到底来自第三步决策，还是来自第四步重复注入。

因此当前第 04 步只保留 lowering 和末端修复，不再注册 vector 预取注入 pass。

## 5. 自定义 pass

当前插件只注册一个 pass：

```text
step4-repair-llvm-index-bridges
```

它的作用是把官方 lowering 后可能残留的：

```text
i64 -> index -> i32
```

规整为：

```mlir
llvm.trunc %x : i64 to i32
```

这个 pass 不改变矩阵计算语义，也不改变预取决策，只是让当前实验产物能够稳定导出 LLVM IR。

## 6. 构建插件

在仓库根目录执行：

```bash
cmake -S 04_vector_arm_sme_llvm \
  -B 04_vector_arm_sme_llvm/build \
  -DMLIR_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/mlir \
  -DLLVM_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/llvm

cmake --build 04_vector_arm_sme_llvm/build
```

构建产物是：

```text
04_vector_arm_sme_llvm/build/SMEStep4LoweringPasses.dylib
```

确认 pass 已注册：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-pass-plugin=04_vector_arm_sme_llvm/build/SMEStep4LoweringPasses.dylib \
  --help-list-hidden | rg "step4-"
```

应能看到：

```text
--step4-repair-llvm-index-bridges
```

## 7. 重新生成输出

生成 Arm SME 相关层：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  03_prefetch_injection/output/02_vector_prefetch.mlir \
  -test-lower-to-arm-sme \
  -o 04_vector_arm_sme_llvm/output/01_arm_sme_prefetch.mlir
```

继续降到 LLVM dialect：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  03_prefetch_injection/output/02_vector_prefetch.mlir \
  -test-lower-to-arm-sme -test-lower-to-llvm \
  -o /private/tmp/step4_llvm_prefetch_pre_legalize.mlir

/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  /private/tmp/step4_llvm_prefetch_pre_legalize.mlir \
  -convert-vector-to-llvm=enable-arm-sve -reconcile-unrealized-casts \
  -o /private/tmp/step4_llvm_prefetch_legalized.mlir

/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-pass-plugin=04_vector_arm_sme_llvm/build/SMEStep4LoweringPasses.dylib \
  --pass-pipeline='builtin.module(step4-repair-llvm-index-bridges)' \
  /private/tmp/step4_llvm_prefetch_legalized.mlir \
  -o 04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir
```

## 8. 验证 LLVM IR 导出

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-translate \
  --mlir-to-llvmir \
  04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir \
  -o /private/tmp/step4_llvm_prefetch.ll
```

当前该命令可以成功执行，说明第 04 步最终产物已经收口到可导出的 LLVM dialect 形式。

## 9. 当前注意事项

- `-test-lower-to-arm-sme` 会输出 SME tile allocation 相关 warning，提示性能可能下降；这是当前测试 lowering 的性能提示，不是本步骤失败。
- 第 04 步不分析 cost model，也不重新插入预取；它只验证第三步预取主线的跨层保留。
- 最终输出中应能看到 `llvm.intr.prefetch`，说明第三步的 `memref.prefetch` 已经降低到 LLVM 预取 intrinsic。
