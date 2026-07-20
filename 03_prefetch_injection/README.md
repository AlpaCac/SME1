# 03 Prefetch Injection

这个目录对应总体方案的第三步：从第一步生成的 `linalg` 主线出发，先降到 `vector` 层，再根据第二步 `cost model` 的分析结果插入预取。

## 1. 第三步目标

第三步不再在 affine 层插入 `research.prefetch`。当前主线是：

```text
01_custom_lifter/output/gemm_fp32_linalg.mlir
-> transform dialect vectorization
-> 03_prefetch_injection/output/01_vector.mlir
-> step3-inject-vector-prefetch
-> 03_prefetch_injection/output/02_vector_prefetch.mlir
```

这样做的原因是：第二步已经在 affine-normalized 层完成预取分析和决策，第三步真正需要服务的是后续 `vector -> arm_sme -> llvm` 主线。因此预取应进入 vector 主线，而不是停留在一条独立的 affine 证据支线。

## 2. 输入和输出

输入：

- [../01_custom_lifter/output/gemm_fp32_linalg.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_linalg.mlir)：第一步生成的高层 linalg 主线
- [../02_prefetch_cost_model/output/prefetch_analysis.json](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/output/prefetch_analysis.json)：第二步生成的结构化预取决策
- [input/linalg_to_vector_transform.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/input/linalg_to_vector_transform.mlir)：用于 linalg 到 vector 的 transform dialect 调度

输出：

- [output/01_vector.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/01_vector.mlir)：从 linalg 主线 vectorize 后的结果
- [output/02_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/02_vector_prefetch.mlir)：插入标准 `memref.prefetch` 后的 vector 层结果

## 3. 当前 pass 做了什么

pass 文件是：

- [passes/InjectVectorPrefetch.cpp](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/passes/InjectVectorPrefetch.cpp)

注册的 pass 名称是：

```text
step3-inject-vector-prefetch
```

它会执行：

- 读取 `02_prefetch_cost_model/output/prefetch_analysis.json`
- 解析 A/B/C 的 `enable`、`priority`、`target_cache`、`locality`、`distance`
- 遍历 `vector.transfer_read`
- 只对 rank-1 vector read 插入读预取
- 跳过 rank-2 vector read，避免误预取 C 的累加 tile
- 在函数属性中记录第三步注入结果

当前插入的标准 MLIR 形式是：

```mlir
memref.prefetch %subview[%c0], read, locality<3>, data : memref<?xf32, ...>
vector.transfer_read %subview[%c0], ...
```

## 4. 如何构建

在仓库根目录执行：

```bash
cmake -S 03_prefetch_injection \
  -B 03_prefetch_injection/build \
  -DMLIR_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/mlir \
  -DLLVM_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/llvm

cmake --build 03_prefetch_injection/build
```

构建产物是：

```text
03_prefetch_injection/build/SMEPrefetchInjectionPass.dylib
```

## 5. 如何运行

第一步，使用 transform dialect 把第一步 linalg 主线降到 vector 层：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  01_custom_lifter/output/gemm_fp32_linalg.mlir \
  --pass-pipeline='builtin.module(transform-preload-library{transform-library-paths=03_prefetch_injection/input/linalg_to_vector_transform.mlir},transform-interpreter)' \
  -o 03_prefetch_injection/output/01_vector.mlir
```

第二步，根据第二步 cost model 决策插入预取：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-pass-plugin=03_prefetch_injection/build/SMEPrefetchInjectionPass.dylib \
  03_prefetch_injection/output/01_vector.mlir \
  --pass-pipeline='builtin.module(func.func(step3-inject-vector-prefetch))' \
  -o 03_prefetch_injection/output/02_vector_prefetch.mlir
```

第三步，验证输出：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  03_prefetch_injection/output/02_vector_prefetch.mlir
```

## 6. 输入限制

当前实现不是任意程序的通用预取注入器，但它不依赖函数名、SSA 名或固定文本格式。

当前需要满足：

- 输入已经是 vector 层，至少包含 `vector.transfer_read`
- A/B 读流在 vector 化后表现为 rank-1 `vector.transfer_read`
- C 累加 tile 通常表现为 rank-2 `vector.transfer_read`，当前默认不预取
- 第二步 JSON 中需要包含 A/B/C 的 `decisions`

后续可以继续增强为更精确的数据流匹配，例如通过追踪 `memref.subview` 的来源来区分 A/B/C，而不是采用当前的 rank-1 read 顺序启发式。
