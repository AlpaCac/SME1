# 07 Local Benchmark

## 说明

- 当前本地对比只选择 `K <= 128` 的 case，用来保证 `c_baseline` / `affine` / `unified` 三组语义一致。
- 若直接使用 `K > 128`，当前研究版 `gemm_mlir_kernel.c` 及其 affine 路线会体现为“按 kc 分块覆盖写回”的语义，而 unified 主线保留的是完整 `linalg.matmul` 语义，因此不能直接拿来做性能结论。

## 配置

### M=128 N=128 K=128 iterations=10

- `c_baseline`: avg_ms=0.122400, gflops=34.267, checksum=-118.180355981
- `affine_no_prefetch`: avg_ms=3.450300, gflops=1.216, checksum=-118.181921616
- `affine_prefetch`: avg_ms=0.930100, gflops=4.510, checksum=-118.181921616
- `unified_no_prefetch`: avg_ms=31.957200, gflops=0.131, checksum=-118.180355981
- `unified_prefetch`: avg_ms=31.423000, gflops=0.133, checksum=-118.180355981
- `affine_prefetch / affine_no_prefetch` speedup=3.7096
- `unified_prefetch / unified_no_prefetch` speedup=1.0170
- `unified_prefetch / c_baseline` speedup=0.0039

### M=256 N=256 K=128 iterations=3

- `c_baseline`: avg_ms=0.483667, gflops=34.688, checksum=50.013477668
- `affine_no_prefetch`: avg_ms=3.901000, gflops=4.301, checksum=50.007252619
- `affine_prefetch`: avg_ms=3.931667, gflops=4.267, checksum=50.007252619
- `unified_no_prefetch`: avg_ms=116.645667, gflops=0.144, checksum=50.013477668
- `unified_prefetch`: avg_ms=112.761333, gflops=0.149, checksum=50.013477668
- `affine_prefetch / affine_no_prefetch` speedup=0.9922
- `unified_prefetch / unified_no_prefetch` speedup=1.0344
- `unified_prefetch / c_baseline` speedup=0.0043
