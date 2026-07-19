# 04 Vector / Arm SME / LLVM 降级

本目录实现总体方案的第四步：从稳定的高层 MLIR 计算主线出发，使用 MLIR pass 和官方 lowering pipeline，将矩阵计算与预取语义逐步降到 `vector / arm_sme / llvm` 层。

当前第 04 步只保留一条主线，不再保存 `research.prefetch -> affine.prefetch -> llvm.intr.prefetch` 的证据支线。

## 1. 第四步目标

第四步对应总体方案中的这一段：

```text
高层 MLIR 计算主线
-> vector 层插入预取
-> Arm SME 相关表示
-> LLVM dialect
-> LLVM IR
```

目标不是重新实现 MLIR 的全部 lowering，而是在官方 lowering pipeline 的关键位置补充研究所需的语义改写：

- 在 vector 主线中的 `vector.transfer_read` 前插入 `memref.prefetch`
- 继续通过官方 pipeline 降到 Arm SME 和 LLVM dialect
- 修复末端少量 `i64 -> index -> i32` 桥接残留，使结果可以导出为 LLVM IR

## 2. 第四步具体做了什么

第 04 步现在做三件事，全部围绕同一条主线展开。

第一件事是生成 vector 计算主线。输入文件 [input/gemm_step4_compute_mainline.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/input/gemm_step4_compute_mainline.mlir) 中用 `linalg.matmul` 表达矩阵乘语义，再用 transform dialect 描述 tiling、vectorization、bufferization 和 vector lowering。执行 `-transform-interpreter` 后，MLIR 会把高层矩阵乘变成包含 `vector.transfer_read`、`vector.outerproduct`、`vector.transfer_write` 的 vector 计算结构。

第二件事是在 vector 层插入预取。第 04 步自定义 pass `step4-inject-vector-memref-prefetch` 会扫描 vector 化后的函数，找到 A/B 这类 rank-1 `vector.transfer_read`，并在它们之前插入标准 `memref.prefetch`。这样预取不是停留在独立证据支线里，而是进入了真正要继续降到 Arm SME 的计算主线。

第三件事是继续降低抽象层级。插入预取后的 vector IR 先通过 `-test-lower-to-arm-sme` 进入 Arm SME 相关表示，再通过 `-test-lower-to-llvm`、`-convert-vector-to-llvm=enable-arm-sve` 等官方 pass 进入 LLVM dialect。最后自定义 pass `step4-repair-llvm-index-bridges` 清理少量官方 lowering 末端留下的类型桥接残留，使最终文件能被 `mlir-translate --mlir-to-llvmir` 接受。

最终形成的主线是：

```text
input/gemm_step4_compute_mainline.mlir
-> output/01_vector_prefetch.mlir
-> output/02_arm_sme_prefetch.mlir
-> output/03_llvm_prefetch.mlir
-> LLVM IR .ll
```

## 3. 它是怎么做到的

第 04 步采用“自定义 MLIR pass + 官方 lowering pass”的组合方式。

自定义 pass 只处理项目研究中必须插入或修复的部分：

- `step4-inject-vector-memref-prefetch`
  - 输入：已经 vector 化的 `func.func`
  - 做法：遍历 `vector.transfer_read`
  - 判断：只处理 source 是 rank-1 memref 且结果是 rank-1 vector 的读取
  - 输出：在读之前插入 `memref.prefetch ..., read, locality<3>, data`

- `step4-repair-llvm-index-bridges`
  - 输入：接近 LLVM dialect 的 `module`
  - 做法：查找 `i64 -> index -> i32` 这种 lowering 后残留桥接
  - 输出：把它改写为等价的 `llvm.trunc %x : i64 to i32`

官方 MLIR pass 负责已有的通用 lowering：

- `-transform-interpreter` 执行 transform dialect 中描述的 tiling/vectorization 调度
- `-test-lower-to-arm-sme` 把 vector 计算进一步降到 Arm SME 相关表示
- `-test-lower-to-llvm` 把主线继续推向 LLVM dialect
- `-convert-vector-to-llvm=enable-arm-sve` 处理剩余 vector/SVE 相关转换
- `-reconcile-unrealized-casts` 清理可自动消除的转换桥接

这样划分的好处是：第 04 步不重复造 MLIR 已经有的 lowering 轮子，只在“预取插入”和“末端可导出性修复”两个研究点上写 pass。

## 4. 三个输出文件分别代表什么

当前只保留三个主线输出。

### 4.1 `01_vector_prefetch.mlir`

这个文件是 vector 层结果。

它说明：

- 矩阵乘已经从 `linalg.matmul` 变成 vector 计算结构
- A/B 的向量读前已经出现 `memref.prefetch`
- 预取语义已经进入真正的计算主线

重点看：

```mlir
memref.prefetch ...
vector.transfer_read ...
vector.outerproduct ...
```

### 4.2 `02_arm_sme_prefetch.mlir`

这个文件是 Arm SME 相关层结果。

它说明：

- 带预取的 vector 主线可以继续进入 Arm SME lowering
- 函数上已经出现 streaming / ZA 相关属性
- 文件中会出现 `arm_sme` / `arm_sve` 相关结构

这一层仍可能混合存在 `memref`、`arith`、`scf`、`unrealized_conversion_cast` 等 op，因为它还不是最终 LLVM dialect 收口结果。

### 4.3 `03_llvm_prefetch.mlir`

这个文件是第 04 步最终结果。

它说明：

- 函数已经降到 `llvm.func`
- 预取已经变成 `llvm.intr.prefetch`
- SME/SVE 相关操作也已经表现为 LLVM dialect 中的 intrinsic 形式
- 文件可以继续导出为 LLVM IR `.ll`

重点看：

```mlir
"llvm.intr.prefetch"(...)
```

当前最终输出中可以看到 `llvm.intr.prefetch`，说明预取没有在 vector / Arm SME / LLVM lowering 过程中丢失。

## 5. 为什么删掉 01/03 证据支线

早期第 04 步曾经保留过一条支线：

```text
research.prefetch
-> affine.prefetch
-> llvm.intr.prefetch
```

这条支线用于证明“第三步的研究预取语义可以桥接到 MLIR 标准预取并继续下降”。但它没有参与最终 `09` 的生成，后来我们已经确认最终主线本身也能保留 `llvm.intr.prefetch`。因此继续保留这条支线会让流程看起来像有两条路线，反而不利于研究方案表达。

现在第 04 步只保留真正参与后续编译运行的主线：

```text
01_vector_prefetch
-> 02_arm_sme_prefetch
-> 03_llvm_prefetch
```

## 6. 目录结构

- [CMakeLists.txt](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/CMakeLists.txt)：构建第 04 步 MLIR pass 插件
- [passes/Step4LoweringPasses.cpp](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/passes/Step4LoweringPasses.cpp)：第 04 步自定义 pass 实现
- [input/gemm_step4_compute_mainline.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/input/gemm_step4_compute_mainline.mlir)：用于生成 vector/Arm SME 计算主线的高层输入
- [output/01_vector_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/01_vector_prefetch.mlir)：vector 计算主线中插入标准预取后的结果
- [output/02_arm_sme_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/02_arm_sme_prefetch.mlir)：继续降到 Arm SME 相关表示后的结果
- [output/03_llvm_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir)：可导出 LLVM IR 的最终 MLIR 结果

## 7. 自定义 pass

当前插件只注册两个主线 pass：

```text
step4-inject-vector-memref-prefetch
step4-repair-llvm-index-bridges
```

### 7.1 `step4-inject-vector-memref-prefetch`

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

### 7.2 `step4-repair-llvm-index-bridges`

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

## 8. 构建插件

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
  --help-list-hidden | rg "step4-"
```

## 9. 重新生成输出

先生成 vector 计算主线：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  04_vector_arm_sme_llvm/input/gemm_step4_compute_mainline.mlir \
  -transform-interpreter -test-transform-dialect-erase-schedule \
  -o /private/tmp/step4_compute_vector.mlir
```

然后插入 vector 层预取：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  --load-pass-plugin=04_vector_arm_sme_llvm/build/SMEStep4LoweringPasses.dylib \
  --pass-pipeline='builtin.module(func.func(step4-inject-vector-memref-prefetch))' \
  /private/tmp/step4_compute_vector.mlir \
  -o 04_vector_arm_sme_llvm/output/01_vector_prefetch.mlir
```

继续降到 Arm SME：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  04_vector_arm_sme_llvm/output/01_vector_prefetch.mlir \
  -test-lower-to-arm-sme \
  -o 04_vector_arm_sme_llvm/output/02_arm_sme_prefetch.mlir
```

继续降到 LLVM dialect，并执行末端修复：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  04_vector_arm_sme_llvm/output/01_vector_prefetch.mlir \
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
  -o 04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir
```

## 10. 验证 LLVM IR 导出

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-translate \
  --mlir-to-llvmir \
  04_vector_arm_sme_llvm/output/03_llvm_prefetch.mlir \
  -o /private/tmp/step4_llvm_prefetch.ll
```

当前该命令可以成功执行，说明第 04 步最终产物已经收口到可导出的 LLVM dialect 形式。

## 11. 当前注意事项

- `-test-lower-to-arm-sme` 会输出 SME tile allocation 相关 warning，提示性能可能下降；这是当前测试 lowering 的性能提示，不是本步骤失败。
- 第 04 步当前不再直接消费第三步的 `research.prefetch` 文件，而是从稳定的 `linalg.matmul` 计算主线开始观察 vector/Arm SME/LLVM 层级中的预取形态。
- 当前正式输出只有 `01_vector_prefetch.mlir -> 02_arm_sme_prefetch.mlir -> 03_llvm_prefetch.mlir` 这一条主线。
