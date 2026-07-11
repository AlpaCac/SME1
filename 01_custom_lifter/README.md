# 01 Custom Lifter

这个目录对应方案的第一步：把当前仓库中的受限 `C kernel` 提升成适合研究的高层 `MLIR`。

## 目标

当前提升器不是通用的 `C -> MLIR` 前端，而是一个面向研究的自定义提升器，专门处理本仓库这类带结构化标注的 GEMM kernel。

- 输入：`gemm_mlir_kernel.c`
- 输出一：`linalg` 研究版 `MLIR`
- 输出二：`affine` 分析版 `MLIR`

这样拆成两个文件，是为了把两条研究线分开：

- `linalg` 版：保留高层矩阵乘算子语义，适合继续做 `vector -> arm_sme` lowering
- `affine` 版：保留规则循环和标量访存，适合做 reuse distance、stride、working set 和预取分析

## 目录结构

- [lift_gemm.py](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/lift_gemm.py)：自定义提升器脚本
- [output/gemm_fp32_linalg.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_linalg.mlir)：`linalg + scf` 版本
- [output/gemm_fp32_affine.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_affine.mlir)：`affine` 版本

## 当前版本做了什么

当前版本会读取 `gemm_mlir_kernel.c` 中的结构化标注：

- `@kernel`
- `@semantic`
- `@layout`
- `@blocking`
- `@lift-target`

然后完成下面几件事：

1. 校验输入是否符合当前受限 GEMM kernel 约束。
2. 解析 `mc / nc / kc / mr / nr` 分块参数。
3. 一次生成两个高层 `MLIR` 文件。
4. 在 `linalg` 文件中恢复：
   - 外层 tile 循环
   - 内层微块循环
   - `linalg.matmul` 高层矩阵乘语义
5. 在 `affine` 文件中恢复：
   - 规则分块循环
   - 标量 `load/store`
   - 显式乘加归约结构

## 为什么这里不用直接的 Clang/MLIR 工具链

如果直接走：

```text
C/C++ -> Clang -> LLVM IR -> mlir-translate --import-llvm
```

通常只能得到低层 `LLVM dialect MLIR`，很难保留我们研究真正需要的内容：

- GEMM 的高层算子语义
- 分块结构
- 归约维与空间维的角色
- 后续可供预取分析使用的结构化信息

这个自定义提升器的意义，就是把“受限 C kernel”直接恢复成高层 `linalg` 和 `affine` 两类研究入口。

## 如何运行

在仓库根目录执行：

```bash
python3 01_custom_lifter/lift_gemm.py gemm_mlir_kernel.c
```

默认会在 [output](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output) 目录下生成：

- `gemm_fp32_linalg.mlir`
- `gemm_fp32_affine.mlir`

如果你想指定别的输出目录，也可以这样运行：

```bash
python3 01_custom_lifter/lift_gemm.py \
  gemm_mlir_kernel.c \
  --output-dir /tmp/gemm_mlir_outputs
```

## 如何验证输出

你已经把 MLIR 工具放在：

```text
external/llvm-project/build/bin
```

可以分别用下面的命令做语法检查：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  01_custom_lifter/output/gemm_fp32_linalg.mlir

/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  01_custom_lifter/output/gemm_fp32_affine.mlir
```

## 输出文件中的注释

生成出的两个 `.mlir` 文件顶部和关键代码段都带有详细中文注释，目的是让它们不仅是“工具输入”，也能直接作为研究材料阅读：

- 文件顶部会说明文件定位、阅读顺序和研究用途
- 外层循环处会说明如何对应 `mc / nc / kc`
- 内层循环处会说明如何对应 `mr / nr`
- `linalg` 版会重点标出 `linalg.matmul`
- `affine` 版会重点标出标量访存和显式归约

## 当前输出的定位

当前生成物是“最适合继续自定义提升研究”的版本，不是最终最优 IR。它的定位是：

- 尽可能接近论文中的分块 GEMM 结构
- 尽可能保留高层矩阵语义
- 同时分离出更适合分析的 `affine` 版本

## 下一步建议

完成第一步后，可以继续做三件事：

1. 在 `affine` 版上实现高层访存与重用分析。
2. 在 `linalg` 版上继续做 `vector -> arm_sme` 降级研究。
3. 设计预取语义表示，并注入到你真正想研究的那一层 IR 中。
