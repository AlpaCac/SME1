# 02 Prefetch Cost Model

这个目录对应总体方案的第二步：从第一步生成的 `linalg` 主线出发，形成适合访存分析的循环层表示，并构建预取 `cost model`。

## 1. 第二步目标

第二步不直接插入预取指令，而是回答下面几个问题：

- `A / B / C` 在 GEMM 中分别承担什么数据流角色
- 分块结构对应多大的 working set
- 哪些访问具有连续性和复用价值
- 哪些数据对象应该预取
- 预取应该采用什么优先级、缓存目标和 locality 策略

当前输出的预取决策会作为第三步预取注入 pass 的输入依据。

## 2. 输入和输出

输入来自第一步：

- [../01_custom_lifter/output/gemm_fp32_linalg.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_linalg.mlir)

第二步会先通过官方 MLIR lowering 把 `linalg.matmul` 展开成循环分析形态：

```text
linalg.matmul
-> scf.for / memref.load / memref.store / affine.apply
```

这里称为 `affine/scf 分析层`。它不是最终低层 LLVM IR，也不是严格意义上所有循环都变成 `affine.for` 的文件；它的重点是暴露循环、访存和 affine 下标关系，便于做预取分析。

输出包括：

- [output/01_affine_analysis.mlir](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/output/01_affine_analysis.mlir)：带第二步分析属性的循环层 MLIR
- [output/prefetch_analysis.json](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/output/prefetch_analysis.json)：结构化预取决策
- [output/prefetch_analysis.md](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/output/prefetch_analysis.md)：可读分析报告

## 3. 为什么使用 MLIR pass

早期第二步使用 Python 脚本读取固定的 `gemm_fp32_affine.mlir`，这有两个问题：

- 第一，第一步现在只生成 `linalg` 主线，不再生成独立 affine 文件。
- 第二，Python 文本分析依赖字符串和格式，不能真正复用 MLIR 的 IR 结构。

当前方案改为 MLIR pass：

- 官方 pass 负责把 `linalg` 展开成循环层表示
- 自定义 pass `step2-prefetch-cost-model` 在 MLIR IR 上统计和分析
- 分析结果同时写入 IR 属性和外部报告文件

这样第二步更接近正式编译器流程，也更容易和第三步、第四步的 pass 串接。

## 4. 当前 pass 做了什么

pass 文件是：

- [passes/PrefetchCostModel.cpp](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/passes/PrefetchCostModel.cpp)

注册的 pass 名称是：

```text
step2-prefetch-cost-model
```

它会分析：

- `linalg.matmul` / `linalg.fill` 数量
- `scf.for` 循环数量
- `memref.subview` 数量
- `memref.load` / `memref.store` 数量
- `mc / nc / kc / mr / nr` 分块参数
- 宏块和微块 working set
- `A / B / C` 的复用关系

然后在函数属性中写入：

```text
step2.analysis_layer
step2.tile.mc / nc / kc / mr / nr
step2.count.scf_for
step2.count.memref_load
step2.count.memref_store
step2.prefetch.A
step2.prefetch.B
step2.prefetch.C
```

同时生成 `prefetch_analysis.json` 和 `prefetch_analysis.md`。

## 5. 当前预取决策

当前研究版 cost model 采用启发式规则：

- 优先预取连续读流
- 优先预取同时具有复用价值的数据
- 优先考虑 `A / B`，暂时不主动预取 `C`
- 目标缓存层级先设为 `L1`
- locality 先采用 `KEEP`

当前默认决策是：

- `B`：开启读预取，优先级 `high`
- `A`：开启读预取，优先级 `medium`
- `C`：暂不开启主动软件预取

## 6. 如何构建

在仓库根目录执行：

```bash
cmake -S 02_prefetch_cost_model \
  -B 02_prefetch_cost_model/build \
  -DMLIR_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/mlir \
  -DLLVM_DIR=/Users/alpaca/Documents/SME/external/llvm-project/build/lib/cmake/llvm

cmake --build 02_prefetch_cost_model/build
```

构建产物是：

```text
02_prefetch_cost_model/build/SMEPrefetchCostModelPass.dylib
```

## 7. 如何运行

在仓库根目录执行：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-pass-plugin=02_prefetch_cost_model/build/SMEPrefetchCostModelPass.dylib \
  01_custom_lifter/output/gemm_fp32_linalg.mlir \
  --pass-pipeline='builtin.module(convert-linalg-to-loops,canonicalize,func.func(step2-prefetch-cost-model))' \
  -o 02_prefetch_cost_model/output/01_affine_analysis.mlir
```

运行后会得到：

- `output/01_affine_analysis.mlir`
- `output/prefetch_analysis.json`
- `output/prefetch_analysis.md`

## 8. 输入限制

当前 pass 是研究版 GEMM 分析 pass，不是通用 C/MLIR 预取分析器。

当前输入需要满足：

- 来自第一步的 `linalg` 主线
- 包含规则的 `mc / nc / kc / mr / nr` 分块结构
- 包含 `linalg.matmul` 或已经由 `linalg.matmul` 展开的循环结构
- 矩阵元素类型按 `f32` 计算
- A/B/C 参数顺序保持为左输入、右输入、输出矩阵

如果未来要支持更多 kernel，需要把当前固定 GEMM 启发式扩展为更通用的数据流分析。
