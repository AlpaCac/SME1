# 01 Custom Lifter

这个目录对应方案的第一步：把当前仓库中的受限 `C kernel` 提升成适合研究的高层 `MLIR`。

## 目标

当前提升器不是通用的 `C -> MLIR` 前端，而是一个面向研究的自定义提升器，专门处理本仓库这类带结构化标注的 GEMM kernel。

现在第一步已经从早期“正则匹配示例文件”的方式，调整为“Clang AST + 结构化标注”的方案：

- `Clang AST` 用来识别 C 函数、参数、循环、数组访问和归约形态
- 源码中的结构化标注继续用来说明研究语义、分块参数和 lowering 目标
- Python 脚本不再直接依赖固定函数签名文本，而是消费 Clang 导出的 JSON AST

- 输入：`gemm_mlir_kernel.c`
- 输出：`linalg` 高层语义版 `MLIR`

按照当前总体方案，第一步只负责生成统一的高层入口 IR，不再同时生成 `affine` 文件。后续如果需要做访存分析或向量化，可以从同一个 `linalg` 主线继续转换：

- `linalg -> affine/scf`：用于分析 reuse distance、stride、working set 和预取距离
- `linalg -> vector`：用于继续做 `vector -> arm_sme` lowering 和预取注入

## 目录结构

- [lift_gemm.py](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/lift_gemm.py)：基于 Clang AST 的自定义提升器脚本
- [Clang_AST提升器方案.md](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/Clang_AST提升器方案.md)：说明为什么采用 Clang AST，以及后续如何增强普适性
- [output/gemm_fp32_linalg.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_linalg.mlir)：`linalg + scf` 版本

## 当前版本做了什么

当前版本会读取 `gemm_mlir_kernel.c` 中的结构化标注：

- `@kernel`
- `@semantic`
- `@layout`
- `@blocking`
- `@lift-target`

同时会调用 Clang 生成 JSON AST，用 AST 校验当前 C kernel 是否满足受限 GEMM 子集。

然后完成下面几件事：

1. 通过 Clang AST 找到目标 C 函数。
2. 校验函数返回类型、参数数量、参数类型、循环数量、数组访问和归约赋值。
3. 解析 `mc / nc / kc / mr / nr` 分块参数。
4. 生成一个作为后续主线入口的高层 `linalg` MLIR 文件。
5. 在 `linalg` 文件中恢复：
   - 外层 tile 循环
   - 内层微块循环
   - `linalg.matmul` 高层矩阵乘语义
   - 可继续转换到 `affine/scf` 的分块结构
   - 可继续转换到 `vector` / `arm_sme` 的算子结构

## 为什么这里使用 Clang AST，而不是直接的 Clang/LLVM IR

如果直接走：

```text
C/C++ -> Clang -> LLVM IR -> mlir-translate --import-llvm
```

通常只能得到低层 `LLVM dialect MLIR`，很难保留我们研究真正需要的内容：

- GEMM 的高层算子语义
- 分块结构
- 归约维与空间维的角色
- 后续可供预取分析使用的结构化信息

所以这里采用的是另一条路线：

```text
C kernel
-> Clang AST
-> 受限 KernelIR / 模式识别
-> 高层 linalg / affine MLIR
```

`Clang AST` 的作用不是把 C 直接降到 LLVM IR，而是给自定义提升器提供结构化输入。这样比纯文本匹配更稳，也更容易扩展到变量名变化、格式变化或多个相近 kernel 的情况。

## 如何运行

在仓库根目录执行：

```bash
python3 01_custom_lifter/lift_gemm.py gemm_mlir_kernel.c
```

默认会在 [output](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output) 目录下生成：

- `gemm_fp32_linalg.mlir`

如果你想指定别的输出目录，也可以这样运行：

```bash
python3 01_custom_lifter/lift_gemm.py \
  gemm_mlir_kernel.c \
  --output-dir /tmp/gemm_mlir_outputs
```

如果源码文件中有多个函数，可以显式指定要提升的函数：

```bash
python3 01_custom_lifter/lift_gemm.py \
  gemm_mlir_kernel.c \
  --function gemm_fp32_mlir_kernel
```

如果需要使用特定 Clang，也可以指定：

```bash
python3 01_custom_lifter/lift_gemm.py \
  gemm_mlir_kernel.c \
  --clang /path/to/clang
```

## 如何验证输出

你已经把 MLIR 工具放在：

```text
external/llvm-project/build/bin
```

可以用下面的命令做语法检查：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  01_custom_lifter/output/gemm_fp32_linalg.mlir
```

## 输出文件中的注释

生成出的 `.mlir` 文件顶部和关键代码段都带有详细中文注释，目的是让它不仅是“工具输入”，也能直接作为研究材料阅读：

- 文件顶部会说明文件定位、阅读顺序和研究用途
- 外层循环处会说明如何对应 `mc / nc / kc`
- 内层循环处会说明如何对应 `mr / nr`
- 重点标出 `linalg.matmul` 如何承载 `C = A * B` 语义

## 当前输出的定位

当前生成物是“最适合继续自定义提升研究”的版本，不是最终最优 IR。它的定位是：

- 尽可能接近论文中的分块 GEMM 结构
- 尽可能保留高层矩阵语义
- 作为后续 `affine/scf` 分析分支和 `vector/arm_sme` lowering 分支的共同入口

## 下一步建议

完成第一步后，可以继续做三件事：

1. 从 `linalg` 主线转换到 `affine/scf`，实现高层访存与重用分析。
2. 从 `linalg` 主线转换到 `vector`，继续做 `vector -> arm_sme` 降级研究。
3. 设计预取语义表示，并注入到你真正想研究的那一层 IR 中。
