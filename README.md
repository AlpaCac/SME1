# SME1

这个仓库当前包含一个适合编译成 MLIR 的 C 语言矩阵计算 kernel：

- [gemm_mlir_kernel.c](/Users/alpaca/Documents/SME/SME1/gemm_mlir_kernel.c)

它参考了论文 [202512 国防科大 Demystifying ARM SME to Optimize  General Matrix Multiplications](/Users/alpaca/Documents/SME/论文/202512%20国防科大%20Demystifying%20ARM%20SME%20to%20Optimize%20%20General%20Matrix%20Multiplications.pdf) 的整体 GEMM 组织方式：

- 外积式 GEMM
- `mc / nc / kc` 分块
- `mr / nr` 子块更新

但实现上现在刻意保持为“单函数 + 规则分块循环 + 规则矩阵访存”，并去掉了显式向量类型、SME intrinsic、汇编和复杂打包逻辑。这样更适合作为“自定义 C -> 高层 MLIR 提升器”的输入。

函数入口：

```c
void gemm_fp32_mlir_kernel(int m,
                           int n,
                           int k,
                           const float *restrict a,
                           int lda,
                           const float *restrict b,
                           int ldb,
                           float *restrict c,
                           int ldc);
```

约定：

- `A` 为 row-major `m x k`
- `B` 为 row-major `k x n`
- `C` 为 row-major `m x n`
- 计算语义为 `C = A * B`
- 函数内部使用局部 `Cr` 子块缓冲区
- 代码顶部有 `@kernel / @semantic / @blocking / @lift-target` 标注，便于后续自定义解析

这个版本更适合后续做：

- 从受限 C 子集提升到 `linalg` / `scf` / `affine`
- 再从高层 MLIR 继续 lowering 到 `vector` / `arm_sme`

## 当前代码如何对应 MLIR 各层

这份 C 代码本身不是为了直接让 `clang` 产出高层 `ArmSME` MLIR，
而是作为“高层语义输入”来使用。它最适合映射到下面几层：

### 1. `linalg` 层

最核心的数学语义是：

```text
C = A * B
```

因此最理想的高层表示是一个 `linalg.matmul`。

这一步里，当前 C 代码中的：

- `A(a_row, a_col)`
- `B(b_row, b_col)`
- `Cr[i_inner][j_inner] += ...`

可以整体识别为一个局部 matmul 子块，而不是逐条保留成标量加法。

### 2. `scf` / `affine` 层

当前代码里的规则分块循环：

- `i` 对应 `mc`
- `j` 对应 `nc`
- `k` 对应 `kc`
- `ii` 对应 `mr`
- `jj` 对应 `nr`
- `kk` 对应归约维

非常适合直接映射成：

- `scf.for`
- 或 `affine.for`

如果你想研究循环结构、tile 结构、归约维与空间维，这一层最重要。

### 3. `vector` 层

在高层 MLIR 中，通常不会直接从 C 里保留显式 SIMD 类型，
而是先从 `linalg.matmul` 或 `scf/affine` 的乘加归约结构出发，再做：

- tile
- vectorize
- contraction lowering

之后才得到：

- `vector.transfer_read`
- `vector.transfer_write`
- `vector.contract`
- `vector.outerproduct`

### 4. `arm_sme` 层

你本地 LLVM/MLIR 的官方路径是：

```text
linalg.matmul -> vector -> arm_sme
```

本地参考材料：

- [ArmSME.md](/Users/alpaca/Documents/SME/external/llvm-project/mlir/docs/Dialects/ArmSME.md)
- [matmul.mlir](/Users/alpaca/Documents/SME/external/llvm-project/mlir/test/Integration/Dialect/Linalg/CPU/ArmSME/matmul.mlir)

也就是说，`arm_sme.outerproduct`、`arm_sme.fmopa` 这些形式，
不是直接从 C 语法产生的，而是从更高层的 `linalg` / `vector` lowering 下来的。

### 5. `llvm` 层

如果你直接走：

```bash
clang -O1 -S -emit-llvm gemm_mlir_kernel.c -o gemm_mlir_kernel.ll
mlir-translate --import-llvm gemm_mlir_kernel.ll -o gemm_mlir_kernel.mlir
```

得到的通常是低层 LLVM dialect MLIR，不是你想研究的高层 `linalg` / `vector` / `arm_sme` 结构。

所以这条路径可以保留用于“低层对照”，但不应该作为高层研究主线。

## 推荐的转换路线

建议把这份代码放进下面这条研究链路：

```text
受限 C kernel
-> 自定义提升器
-> 高层 MLIR（linalg / scf / affine）
-> vector 化
-> ArmSME lowering
-> LLVM
```

对应到当前项目，可以理解成：

1. 这份 `gemm_mlir_kernel.c` 提供规则循环和矩阵乘语义。
2. 你自己的工具识别注释和循环结构，把它变成高层 MLIR。
3. 再复用 LLVM/MLIR 现有的 `vector` / `ArmSME` pass 往下走。

## 哪些步骤可以自动做

这些步骤比较适合自动化：

- 解析文件头注释中的 `@kernel / @semantic / @blocking / @lift-target`
- 识别 `i/j/k` 外层分块循环
- 识别 `ii/jj/kk` 内层微块和归约循环
- 识别 `Cr[i][j] += A(...) * B(...)` 的乘加归约模式
- 生成 `scf.for` 或 `affine.for`
- 在合适的时候把局部模式提升成 `linalg.matmul`

## 哪些步骤需要手工编写

目前这几部分通常需要你手工写，不能指望 `clang` 直接帮你完成：

### 1. `C -> 高层 MLIR` 提升器

这是最关键的一步。

你需要自己决定：

- 用 Clang AST 解析
- 还是用 `clang -Xclang -ast-dump=json`
- 还是自己做一个更小的语法匹配器

然后手工实现：

- 哪种循环结构识别为 tile
- 哪种乘加模式识别为 matmul
- 什么时候生成 `linalg.matmul`
- 什么时候保留为 `scf/affine`

### 2. `linalg` 到 `vector` 的变换策略

虽然 LLVM/MLIR 有现成 pass，但 tile size、vectorize 策略、是否先 bufferize，
这些都需要你手工选择。

本地样例 [matmul.mlir](/Users/alpaca/Documents/SME/external/llvm-project/mlir/test/Integration/Dialect/Linalg/CPU/ArmSME/matmul.mlir)
就展示了一种参考流程：

- tile
- vectorize
- bufferize
- `vector.contract -> vector.outerproduct`

### 3. `vector` 到 `arm_sme` 的实验配置

这一层虽然有官方 pass，但你仍然需要自己决定：

- 研究的 tile size
- 想观察的向量形态
- 何时进入 `arm_sme`
- 是否继续降到 LLVM

## 实际研究时建议保留的两条产物线

建议同时维护两条产物：

### A. 高层研究线

```text
gemm_mlir_kernel.c
-> 自定义提升
-> linalg/scf/affine/vector/arm_sme
```

这是主线，用来研究 SME 在高层 MLIR 中的形式。

### B. 低层对照线

```text
clang
-> LLVM IR
-> mlir-translate --import-llvm
```

这是对照线，用来看同一份 C 在低层 LLVM dialect 里会变成什么样。

## 最小可执行建议

如果你现在就要开始做，建议按下面顺序推进：

1. 把这份 C 当作“受限输入语言”。
2. 先手工写一个对应的 `linalg.matmul` 版 `.mlir` 文件。
3. 对照本地样例 [matmul.mlir](/Users/alpaca/Documents/SME/external/llvm-project/mlir/test/Integration/Dialect/Linalg/CPU/ArmSME/matmul.mlir) 验证从 `linalg` 到 `arm_sme` 的 pass 流程。
4. 再回过头实现自动的 `C -> 高层 MLIR` 提升器。

它当前采用的核心循环结构是：

```text
for i in mc blocks
  for j in nc blocks
    for k in kc blocks
      for ii in mr blocks
        for jj in nr blocks
          initialize Cr from zero
          update Cr by reduction over kk
          write Cr back to C
```

一个最小编译示例：

```bash
clang -O1 -S -emit-llvm gemm_mlir_kernel.c -o gemm_mlir_kernel.ll
```
