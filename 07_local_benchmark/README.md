# 07 Local Benchmark

这个目录对应“暂时先在本机实验并进行对比”的阶段性工作。

## 目标

在当前 Apple Silicon 本机上，先做一组可复现的局部对比实验，用来回答两个问题：

1. 在本机环境里，预取语义是否对当前流水线有可观测影响。
2. 统一 SME 主线与较高层 / C baseline 相比，大致处在什么量级。

## 当前实验边界

当前脚本只选择 `K <= 128` 的 case。

原因是：

- [gemm_mlir_kernel.c](/Users/alpaca/Documents/SME/SME1/gemm_mlir_kernel.c) 目前保留的是“研究版、便于提升”的块结构写法。
- 这份 C 代码及其 affine 路线在每个 `kc` 块开始时会重置当前输出微块，因此当 `K > 128` 时，体现出来的是“最后一个 `kc` 块写回”的语义。
- `unified` 主线来自 `linalg.matmul`，保持的是完整 `C = A * B` 语义。
- 因此，如果直接拿 `K > 128` 的 case 对比，结论会混入语义差异，不适合作为本地性能观察结果。

换句话说，第 7 步现在的定位是：

- 先在“语义一致”的小范围内，观察预取和 lowering 路线是否有可测差异。
- 不把这里的结果误写成最终的 SME 目标性能结论。

## 对比对象

- `c_baseline`
  - 直接用 [gemm_mlir_kernel.c](/Users/alpaca/Documents/SME/SME1/gemm_mlir_kernel.c) 编译出的 C baseline
- `affine_no_prefetch`
  - 从 [03_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir) 现场翻译成 LLVM IR 后，再去掉 `llvm.prefetch` 调用得到
- `affine_prefetch`
  - 由 [03_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir) 现场翻译得到
- `unified_no_prefetch`
  - 从 [09_unified_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir) 现场翻译成 LLVM IR 后，再去掉 `llvm.prefetch` 调用得到
- `unified_prefetch`
  - 由 [09_unified_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir) 现场翻译得到

## 如何运行

```bash
python3 07_local_benchmark/build_and_benchmark.py
```

## 输出

- [output/benchmark_results.json](/Users/alpaca/Documents/SME/SME1/07_local_benchmark/output/benchmark_results.json)
- [output/benchmark_report.md](/Users/alpaca/Documents/SME/SME1/07_local_benchmark/output/benchmark_report.md)

## 当前应如何解读

- `affine_prefetch` 对比 `affine_no_prefetch`：用于观察 affine 预取注入在本机上的局部影响。
- `unified_prefetch` 对比 `unified_no_prefetch`：用于观察统一主线上预取保留后的局部影响。
- `unified_*` 对比 `c_baseline`：只能看数量级差异，不能直接视为最终优化优劣。
- 真正面向方案目标的性能结论，仍然需要回到 README 中定义的目标环境完成。
