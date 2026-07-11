# Custom Lifter

这个目录实现方案的第一步：把当前仓库中的受限 `C kernel` 提升成适合研究的高层 `MLIR`。

## 目标

当前提升器不是通用的 `C -> MLIR` 前端，而是一个面向研究的自定义提升器，专门处理本仓库这类带结构化标注的 GEMM kernel：

- 输入：`gemm_mlir_kernel.c`
- 输出：高层 `MLIR`
- 输出层次：`scf + memref + linalg`

这样做的目的不是直接还原所有 C 细节，而是尽可能保留：

- `mc / nc / kc` 外层分块
- `mr / nr` 微块结构
- `C = A * B` 的矩阵乘语义
- 后续进入 `vector -> arm_sme -> llvm` 的研究入口

## 目录结构

- [lift_gemm.py](/Users/alpaca/Documents/SME/SME1/custom_lifter/lift_gemm.py)：自定义提升器脚本
- [output/gemm_fp32_lifted.mlir](/Users/alpaca/Documents/SME/SME1/custom_lifter/output/gemm_fp32_lifted.mlir)：生成出的高层 MLIR 样例

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
3. 生成高层 `MLIR` 骨架。
4. 在 `MLIR` 中显式恢复：
   - 外层 tile 循环
   - 内层微块循环
   - `linalg.matmul` 高层矩阵乘语义

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

这个自定义提升器的意义，就是把“受限 C kernel”直接恢复成高层 `linalg/scf` 形式，作为后续预取优化研究的起点。

## 如何运行

在仓库根目录执行：

```bash
python3 custom_lifter/lift_gemm.py \
  gemm_mlir_kernel.c \
  -o custom_lifter/output/gemm_fp32_lifted.mlir
```

## 如何验证输出

你已经把 MLIR 工具放在：

```text
external/llvm-project/build/bin
```

可以用下面的命令做语法检查：

```bash
/Users/alpaca/Documents/SME/external/llvm-project/build/bin/mlir-opt \
  custom_lifter/output/gemm_fp32_lifted.mlir
```

## 当前输出的定位

当前生成物是“最适合继续自定义提升研究”的版本，不是最终最优 IR。它的定位是：

- 尽可能接近论文中的分块 GEMM 结构
- 尽可能保留高层矩阵语义
- 尽量避免一开始就掉到低层 `load/store`

## 下一步建议

完成第一步后，可以继续做三件事：

1. 把 `scf` 循环进一步规范化为更适合分析的形式。
2. 在 `linalg/scf/affine` 层做高层访存与重用分析。
3. 设计预取语义表示，并把预取信息注入高层 `MLIR`。
