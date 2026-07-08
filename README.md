# SME1

这个仓库当前包含一个适合编译成 MLIR 的 C 语言矩阵计算 kernel：

- [gemm_mlir_kernel.c](/Users/alpaca/Documents/SME/SME1/gemm_mlir_kernel.c)

它参考了论文 [202512 国防科大 Demystifying ARM SME to Optimize  General Matrix Multiplications](/Users/alpaca/Documents/SME/论文/202512%20国防科大%20Demystifying%20ARM%20SME%20to%20Optimize%20%20General%20Matrix%20Multiplications.pdf) 的几个核心思路：

- 外积式 GEMM
- 分块 blocking
- 同时打包 A 和 B
- 16x64 微核形状

但实现上刻意保持为“纯 C + 规则循环”，没有使用 SME intrinsic、汇编或复杂运行时，这样更容易进入 Clang/MLIR 前端并保留较清晰的循环与访存结构。

函数入口：

```c
void gemm_fp32_mlir_kernel(int m,
                           int n,
                           int k,
                           float alpha,
                           const float *restrict a,
                           int lda,
                           const float *restrict b,
                           int ldb,
                           float beta,
                           float *restrict c,
                           int ldc,
                           float *restrict packed_a,
                           float *restrict packed_b);
```

约定：

- `A` 为 row-major `m x k`
- `B` 为 row-major `k x n`
- `C` 为 row-major `m x n`
- `packed_a` 至少分配 `128 * 128` 个 `float`
- `packed_b` 至少分配 `128 * 128` 个 `float`

这个版本更适合后续做：

- `clang -> LLVM IR`
- `mlir-translate --import-llvm`
- 继续观察 `scf` / `affine` / `memref` / `llvm` 层级上的结构

一个最小编译示例：

```bash
clang -O1 -S -emit-llvm gemm_mlir_kernel.c -o gemm_mlir_kernel.ll
```
