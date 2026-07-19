# 01 Clang AST 提升器方案

这份文档说明第一步为什么从早期的 Python 文本匹配方案，调整为基于 `Clang AST` 的提升器方案。

---

## 1. 原有 Python 文本方案的问题

早期 `lift_gemm.py` 的主要目标是快速跑通整体研究链路，因此做法比较直接：

- 用正则确认固定函数签名
- 从注释中读取 `@kernel` / `@blocking` 等标注
- 用模板生成研究用的高层 `linalg` MLIR

这种方式适合原型验证，但普适性不足。

主要问题是：

- 如果函数名变化，正则可能失效
- 如果参数换行或格式变化，识别可能失效
- 如果循环变量名变化，后续扩展会困难
- 如果文件里有多个 kernel，缺少结构化选择能力
- 如果要判断是否真的存在 `for` 循环、数组访问、归约乘加，文本匹配不够可靠

因此它更像“示例文件专用提升器”，不是一个可扩展的受限 C kernel 提升器。

---

## 2. 为什么采用 Clang AST

`Clang AST` 是 Clang 对 C/C++ 源码解析后的抽象语法树。  
它比源代码文本更结构化。

例如，在 AST 中可以直接看到：

- `FunctionDecl`
  - 函数定义
- `ParmVarDecl`
  - 函数参数
- `ForStmt`
  - `for` 循环
- `IfStmt`
  - 条件分支
- `ArraySubscriptExpr`
  - 数组访问
- `BinaryOperator`
  - 二元表达式
- `CompoundAssignOperator`
  - `+=` 这类归约更新

这比正则更适合作为提升器输入。

采用 Clang AST 后，第一步的目标变成：

```text
C kernel
-> Clang AST JSON
-> 受限 GEMM 结构识别
-> 高层 linalg MLIR
```

这里的关键点是：

- Clang 负责可靠解析 C
- Python 负责消费结构化 AST
- 自定义提升器负责把受限 GEMM 语义恢复成 MLIR

---

## 3. 当前实现方式

当前 [lift_gemm.py](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/lift_gemm.py) 会调用：

```bash
clang -Xclang -ast-dump=json -fsyntax-only gemm_mlir_kernel.c
```

得到 JSON AST。

然后脚本会做这些事情：

1. 在 AST 中查找目标 `FunctionDecl`
2. 提取函数名、返回类型、参数列表
3. 统计函数体中的 `ForStmt`
4. 统计 `ArraySubscriptExpr`
5. 统计 `CompoundAssignOperator`
6. 校验它是否满足当前受限 GEMM 子集
7. 结合源码注释中的 `@blocking` 等研究标注生成 MLIR

也就是说，当前方案仍然保留结构化注释，但它们的定位变了。

`Clang AST` 负责回答：

- 源码结构是什么
- 有没有函数
- 参数是什么
- 有没有循环
- 有没有数组访问
- 有没有归约形态

源码标注负责回答：

- 这个 kernel 的研究语义是什么
- 分块参数是多少
- lowering 目标是什么
- layout 如何解释

二者配合，比单纯文本匹配更稳。

---

## 4. 当前仍然不是任意 C 到 MLIR

需要明确的是：

当前 Clang AST 方案并不是“任意 C 自动提升成高层 MLIR”。

当前支持的是受限 GEMM kernel 子集。

当前要求大致包括：

- 单个目标 kernel 函数，或通过 `--function` 指定目标函数
- 返回类型是 `void`
- 参数形式接近：

```c
int M, int N, int K,
const float *A, int lda,
const float *B, int ldb,
float *C, int ldc
```

- 函数体中存在多层 `for` 循环
- 存在数组访问
- 存在 `+=` 形式的归约更新
- 注释中仍然提供 `@semantic C = A * B`
- 注释中仍然提供 `@blocking mc=... nc=... kc=... mr=... nr=...`

这样设计是有意的。

因为本课题需要的是：

- 面向矩阵 kernel 的高层提升器
- 而不是通用 C 前端

如果一开始追求任意 C，工作量会迅速膨胀，而且很难保证高层语义恢复质量。

---

## 5. 当前命令形式

默认使用系统 `clang`：

```bash
python3 01_custom_lifter/lift_gemm.py gemm_mlir_kernel.c
```

如果需要指定函数：

```bash
python3 01_custom_lifter/lift_gemm.py \
  gemm_mlir_kernel.c \
  --function gemm_fp32_mlir_kernel
```

如果需要指定 Clang 路径：

```bash
python3 01_custom_lifter/lift_gemm.py \
  gemm_mlir_kernel.c \
  --clang /path/to/clang
```

如果需要给 Clang 传额外参数：

```bash
python3 01_custom_lifter/lift_gemm.py \
  gemm_mlir_kernel.c \
  --clang-arg -I/path/to/include
```

---

## 6. 更普适的下一步：引入 KernelIR

当前版本已经使用 Clang AST 做结构校验，但生成 MLIR 时仍然有较多模板化内容。

下一步更合理的演进是引入一个中间结构，例如：

```text
KernelIR {
  function_name
  arguments
  problem_sizes
  tile_loops
  micro_loops
  reduction_loop
  array_accesses
  accumulator
  semantic_pattern
}
```

这样整个提升器就可以拆成三层：

```text
Clang AST
-> KernelIR
-> MLIR emitter
```

这样做的好处是：

- AST 解析和 MLIR 生成解耦
- 后续支持不同变量名更容易
- 后续支持不同 tile 参数更容易
- 后续支持其他矩阵 kernel 更容易
- 出错时可以输出 KernelIR 方便调试

---

## 7. 推荐的长期目录结构

如果第一步继续增强，建议逐步拆成：

```text
01_custom_lifter/
  lift_gemm.py
  clang_ast.py
  kernel_ir.py
  match_gemm.py
  emit_linalg.py
  emit_affine.py
```

各文件职责可以是：

- `clang_ast.py`
  - 调用 Clang，读取 JSON AST，提供遍历工具
- `kernel_ir.py`
  - 定义中间结构
- `match_gemm.py`
  - 从 AST 中识别 GEMM 模式
- `emit_linalg.py`
  - 从 KernelIR 生成 linalg MLIR
- `emit_affine.py`
  - 从 KernelIR 生成 affine MLIR
- `lift_gemm.py`
  - 只负责命令行入口和串联流程

当前还没有拆这么细，是为了保持第一步简单可读。

---

## 8. 和直接使用 Clang/LLVM IR 的区别

这里使用 Clang AST，不等于走传统：

```text
C -> LLVM IR -> MLIR
```

两者区别很大。

传统路线会得到较低层的 LLVM IR：

```text
C
-> Clang LLVM IR
-> LLVM dialect MLIR
```

这时很多高层语义已经变成：

- 指针
- load/store
- 标量算术
- 分支

而当前路线是：

```text
C
-> Clang AST
-> 自定义语义恢复
-> linalg / affine MLIR
```

Clang AST 在这里不是 lowering 终点，而是自定义提升器的结构化输入。

这正好服务于本课题目标：

- 保留 GEMM 高层语义
- 保留分块结构
- 保留后续预取分析需要的循环和访存结构

---

## 9. 当前方案的意义

这次调整后的第一步，比原始文本方案更稳健：

- 不再只看固定源码字符串
- 能从 Clang AST 中确认函数和结构
- 对格式变化更不敏感
- 为后续支持更多 C kernel 留出了路径

但它仍然保持了研究边界：

- 只支持受限 GEMM 子集
- 不试图做任意 C 语义恢复
- 重点服务于高层 MLIR 和预取研究

一句话概括：

第一步现在不是“用 Python 正则把示例文件改写成 MLIR”，而是“用 Clang AST 解析受限 C kernel，再由自定义提升器恢复高层 MLIR”。
