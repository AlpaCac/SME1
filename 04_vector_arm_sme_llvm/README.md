# 04 Vector / Arm SME / LLVM 降级

本目录实现总体方案的第四步：从第三步已经带有预取语义的高层 MLIR 出发，使用 MLIR pass 和官方 lowering pipeline，将计算与预取逐步降到 `vector / arm_sme / llvm` 层。

这一版已经不再使用 Python 脚本文本改写。目录中的自定义逻辑被重构为 C++ MLIR pass 插件，官方已有的降级工作仍交给 `mlir-opt` pipeline 完成。

## 1. 第四步目标

第四步对应总体方案中的这一段：

```text
带预取语义的高层 MLIR
-> 标准 MLIR 预取表示
-> vector 层计算主线
-> Arm SME 相关表示
-> LLVM dialect
-> LLVM IR
```

目标不是重新实现 MLIR 的全部 lowering，而是在关键位置补充研究所需的语义桥接：

- 把第三步的 `research.prefetch` 转成 MLIR 标准 `affine.prefetch`
- 在 vector 主线中的 `vector.transfer_read` 前插入 `memref.prefetch`
- 修复末端少量 `i64 -> index -> i32` 桥接残留，使结果可以导出为 LLVM IR

## 2. 目录结构

- [CMakeLists.txt](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/CMakeLists.txt)：构建第 04 步 MLIR pass 插件
- [passes/Step4LoweringPasses.cpp](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/passes/Step4LoweringPasses.cpp)：第 04 步自定义 pass 实现
- [input/gemm_step4_compute_mainline.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/input/gemm_step4_compute_mainline.mlir)：用于生成 vector/Arm SME 计算主线的高层输入
- [output/01_affine_prefetch_std.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/01_affine_prefetch_std.mlir)：`research.prefetch -> affine.prefetch`
- [output/03_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir)：预取语义降到 `llvm.intr.prefetch`
- [output/07_unified_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/07_unified_vector_prefetch.mlir)：vector 计算主线中插入标准预取
- [output/08_unified_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/08_unified_arm_sme_prefetch.mlir)：继续降到 Arm SME 相关表示
- [output/09_unified_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir)：可导出 LLVM IR 的最终 MLIR 结果

## 3. 自定义 pass

当前插件注册三个 pass：

```text
step4-convert-research-prefetch-to-affine
step4-inject-vector-memref-prefetch
step4-repair-llvm-index-bridges
```

### 3.1 `step4-convert-research-prefetch-to-affine`

输入是第三步生成的：

```text
03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir
```

这个 pass 读取 `research.prefetch` 的操作数和属性，将其转换为标准 `affine.prefetch`。

当前支持的输入限制：

- `research.prefetch` 必须来自第三步已注册的 `research` dialect
- 预取对象当前支持 `target = "A"` 或 `target = "B"`
- 当前只支持读预取，即 `kind = "read"`
- 当前要求每条 `research.prefetch` 携带 4 个 index 操作数
- `A` 的下标语义固定解释为 `A[i + ii, ko + kk]`
- `B` 的下标语义固定解释为 `B[ko + kk, j + jj]`

### 3.2 `step4-inject-vector-memref-prefetch`

输入是 vector 化后的计算主线。

这个 pass 在 rank-1 `vector.transfer_read` 前插入：

```mlir
memref.prefetch ..., read, locality<3>, data
```

当前支持的输入限制：

- 输入中需要已经存在 `vector.transfer_read`
- 读源需要是 rank-1 `memref`
- 当前只对 rank-1 vector read 插入预取
- rank-2 tile 读写暂时不插入预取，避免把 C tile 初始化或回写误判为 A/B 流式读
- 当前预取 hint 固定为 `read, locality<3>, data`

### 3.3 `step4-repair-llvm-index-bridges`

输入是已经接近 LLVM dialect 的 MLIR。

这个 pass 查找官方 lowering 后可能残留的：

```text
i64 -> index -> i32
```

并将其规整为：

```mlir
llvm.trunc %x : i64 to i32
```

它不改变矩阵计算语义，只是让最终 `mlir-translate --mlir-to-llvmir` 可以接受当前输出。

## 4. 构建插件

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

可以用下面命令确认 pass 已注册：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-pass-plugin=04_vector_arm_sme_llvm/build/SMEStep4LoweringPasses.dylib \
  --help-list-hidden | rg "step4-|SMEStep4"
```

## 5. 重新生成输出

第 04 步输入中的 `research.prefetch` 由第 03 步插件注册。因此转换第一段时需要同时加载：

- 第 03 步 dialect 插件：负责解析 `research.prefetch`
- 第 04 步 pass 插件：负责执行 lowering 改写

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-dialect-plugin=03_prefetch_injection/build/SMEPrefetchInjectionPass.dylib \
  --load-pass-plugin=04_vector_arm_sme_llvm/build/SMEStep4LoweringPasses.dylib \
  --pass-pipeline='builtin.module(func.func(step4-convert-research-prefetch-to-affine))' \
  03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir \
  -o 04_vector_arm_sme_llvm/output/01_affine_prefetch_std.mlir
```

继续把标准预取降到 LLVM dialect：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  04_vector_arm_sme_llvm/output/01_affine_prefetch_std.mlir \
  -lower-affine -canonicalize -cse \
  -o /private/tmp/step4_02_memref_prefetch.mlir

/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  /private/tmp/step4_02_memref_prefetch.mlir \
  -convert-scf-to-cf -expand-strided-metadata -finalize-memref-to-llvm \
  -convert-arith-to-llvm -convert-func-to-llvm -convert-cf-to-llvm \
  -reconcile-unrealized-casts \
  -o 04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir
```

生成 vector 计算主线并插入预取：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  04_vector_arm_sme_llvm/input/gemm_step4_compute_mainline.mlir \
  -transform-interpreter -test-transform-dialect-erase-schedule \
  -o /private/tmp/step4_04_compute_vector.mlir

/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-pass-plugin=04_vector_arm_sme_llvm/build/SMEStep4LoweringPasses.dylib \
  --pass-pipeline='builtin.module(func.func(step4-inject-vector-memref-prefetch))' \
  /private/tmp/step4_04_compute_vector.mlir \
  -o 04_vector_arm_sme_llvm/output/07_unified_vector_prefetch.mlir
```

继续降到 Arm SME 和 LLVM dialect：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  04_vector_arm_sme_llvm/output/07_unified_vector_prefetch.mlir \
  -test-lower-to-arm-sme \
  -o 04_vector_arm_sme_llvm/output/08_unified_arm_sme_prefetch.mlir

/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  04_vector_arm_sme_llvm/output/07_unified_vector_prefetch.mlir \
  -test-lower-to-arm-sme -test-lower-to-llvm \
  -o /private/tmp/step4_09_unified_llvm_prefetch_pre_legalize.mlir

/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  /private/tmp/step4_09_unified_llvm_prefetch_pre_legalize.mlir \
  -convert-vector-to-llvm=enable-arm-sve -reconcile-unrealized-casts \
  -o /private/tmp/step4_09_unified_llvm_prefetch_legalized.mlir

/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-pass-plugin=04_vector_arm_sme_llvm/build/SMEStep4LoweringPasses.dylib \
  --pass-pipeline='builtin.module(step4-repair-llvm-index-bridges)' \
  /private/tmp/step4_09_unified_llvm_prefetch_legalized.mlir \
  -o 04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir
```

## 6. 验证 LLVM IR 导出

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-translate \
  --mlir-to-llvmir \
  04_vector_arm_sme_llvm/output/09_unified_llvm_prefetch.mlir \
  -o /private/tmp/step4_09.ll
```

当前该命令可以成功执行，说明第 04 步最终产物已经收口到可导出的 LLVM dialect 形式。

## 7. 当前注意事项

- `-test-lower-to-arm-sme` 会输出 SME tile allocation 相关 warning，提示性能可能下降；这是当前测试 lowering 的性能提示，不是本步骤失败。
- 第 04 步不重复注册 `research` dialect。解析第三步输出时，需要加载第 03 步插件。
- 现在仍保留 `output/03_llvm_prefetch.mlir` 作为预取语义下沉证据；统一主线最终以 `output/07 -> output/08 -> output/09` 为主。
