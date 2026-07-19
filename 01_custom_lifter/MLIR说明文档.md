# 01 MLIR 说明文档

这份文档的目标是回答三个问题：

1. 什么是 `MLIR`
2. `MLIR` 一般提供哪些能力，为什么适合本课题
3. 结合第一步生成的 `MLIR` 文件，说明它包含哪些部分、每类语句是什么意思

---

## 1. 什么是 MLIR

`MLIR` 的全称是 `Multi-Level Intermediate Representation`，中文一般可以理解为“多层中间表示”。

它是 LLVM 体系中的一个编译基础设施，但它和传统只有一种中间表示的编译框架不一样。  
`MLIR` 的核心思想是：

- 不只保留一种低层 IR
- 而是允许在不同抽象层次上表示程序
- 并在这些层次之间逐步 lowering

例如，一个矩阵乘程序可以在不同阶段被表示成：

```text
高层算子语义
-> 结构化循环
-> 向量操作
-> 目标相关指令语义
-> LLVM IR
```

这正好适合本课题，因为我们研究的重点不是“把 C 直接变成最低层代码”，而是：

- 先保留高层矩阵语义
- 再在高层做分析和预取决策
- 最后再逐层降低到 `arm_sme / llvm`

---

## 2. 为什么 MLIR 适合本课题

对于“面向 ARM SME 的高层 IR 驱动预取优化”这个方向，`MLIR` 的价值主要有四点。

### 2.1 可以保留高层语义

传统流程：

```text
C/C++ -> Clang -> LLVM IR
```

到了 LLVM IR，很多东西已经变成：

- 指针
- `load/store`
- 标量算术
- 分支跳转

这时很难再清楚地区分：

- 哪些循环是空间维
- 哪些循环是归约维
- 哪些访问属于矩阵块
- 哪些位置适合做预取

而 `MLIR` 可以在高层直接表示：

- `linalg.matmul`
- `affine.for`
- `scf.for`
- `memref.subview`
- `vector` 运算

因此更适合做高层分析。

### 2.2 可以同时支持多层 IR

本课题不是只关心一层 IR，而是关心一条链：

```text
linalg / affine
-> vector
-> arm_sme
-> llvm
```

`MLIR` 正适合表达这种“逐层下降”的过程。

### 2.3 可以扩展

`MLIR` 允许：

- 定义新的 dialect
- 定义新的 op
- 编写自定义 pass

这对预取研究很重要，因为很多预取语义一开始不是现成标准 op，需要先作为研究表示插进去，再逐步桥接到标准或目标相关表示。

### 2.4 工具链清晰

`MLIR` 自带比较系统的工具支持，例如：

- `mlir-opt`
  - 用于执行 pass、做 lowering、检查 IR
- `mlir-translate`
  - 用于和 LLVM IR 等外部表示互转
- 各种 dialect conversion pass
  - 用于 `affine -> scf`
  - `memref -> llvm`
  - `vector -> llvm`
  - `vector -> arm_sme`

这使得研究过程可以拆成多个明确阶段，而不是全部混在一起。

---

## 3. MLIR 中常见的“相关支持”

这里把和当前仓库最相关的支持简单整理一下。

### 3.1 Dialect

`MLIR` 里最重要的概念之一是 `dialect`。  
可以把它理解成“某一类 IR 语义的语法包”。

本仓库第一步和后续步骤中常见的 dialect 有：

- `func`
  - 表示函数
- `arith`
  - 表示常量、加减乘除、比较等基础算术
- `memref`
  - 表示带形状的内存对象
- `scf`
  - 表示结构化控制流，例如 `scf.for`
- `affine`
  - 表示仿射循环、仿射索引、仿射映射
- `linalg`
  - 表示线性代数高层算子，例如 `linalg.matmul`
- `vector`
  - 表示向量级操作
- `llvm`
  - 表示接近 LLVM IR 的低层操作

### 3.2 Pass

`pass` 可以理解为“对 IR 做一次系统变换或分析的过程”。

例如：

- 把 `affine` 降到更低层
- 把 `memref` 转换为 `llvm`
- 把 `vector` 转为目标相关表示
- 做规范化和公共子表达式消除

在本课题里，pass 的作用就是把同一个程序从高层逐步转换到低层。

### 3.3 Lowering

`lowering` 是编译中非常关键的一个词，意思是：

- 从较高抽象层
- 转到较低抽象层

例如：

```text
linalg.matmul
-> loop / vector
-> arm_sme
-> llvm
```

### 3.4 属性、类型、符号

一份 `MLIR` 不只是“操作列表”，还包含很多辅助信息：

- `attribute`
  - 给函数或操作补充语义说明
- `type`
  - 指明值的类型，例如 `f32`、`index`、`memref<?x?xf32>`
- `symbol`
  - 例如函数名、映射名

这些信息对分析和 lowering 都很重要。

---

## 4. 第一步为什么要生成两份 MLIR

第一步输出了两份文件：

- [output/gemm_fp32_linalg.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_linalg.mlir)
- [output/gemm_fp32_affine.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_affine.mlir)

这样做不是重复，而是服务于两个不同研究目标。

### 4.1 linalg 版本

`linalg` 版本尽量保留：

- 高层矩阵乘语义
- 分块结构
- 子块切分关系

它适合继续研究：

- `vector` 化
- `arm_sme` lowering
- 高层算子如何逐步下降

### 4.2 affine 版本

`affine` 版本故意保留：

- 规则循环
- 显式索引
- 标量 `load/store`
- 标量归约

它适合继续研究：

- stride
- reuse distance
- working set
- 预取距离
- 预取注入点

---

## 5. 一份 MLIR 文件通常由哪些部分组成

以第一步生成的文件为例，一份 `MLIR` 通常包含下面几类内容。

### 5.1 文件头注释

例如：

```mlir
// 自动生成文件：gemm_fp32_linalg.mlir
// 来源：gemm_mlir_kernel.c
// 目标：保留 GEMM 的高层算子语义
```

这部分不是 IR 语义本身，而是给人读的说明。

### 5.2 顶层符号定义

例如：

```mlir
#tile_outer = affine_map<(d0, d1) -> (128, d0 - d1)>
```

这里定义了一个名字叫 `#tile_outer` 的仿射映射，后面可以复用。

### 5.3 module

例如：

```mlir
module {
  ...
}
```

`module` 是顶层容器，可以把它理解成“这一份 IR 文件的整体作用域”。

### 5.4 func.func

例如：

```mlir
func.func @gemm_fp32_linalg(...)
```

这表示定义了一个函数。

### 5.5 SSA 值

例如：

```mlir
%m = memref.dim %a, %c0 : memref<?x?xf32>
```

这里的 `%m`、`%a`、`%c0` 都是 SSA 值。  
SSA 可以简单理解成：每个名字只赋值一次，后续只被引用。

### 5.6 操作

例如：

- `arith.constant`
- `memref.dim`
- `scf.for`
- `affine.for`
- `memref.subview`
- `affine.load`
- `affine.store`
- `linalg.matmul`

这些就是 IR 的主体。

### 5.7 类型

例如：

- `index`
- `f32`
- `memref<?x?xf32>`

类型告诉编译器“这个值是什么”。

---

## 6. 以 linalg 版本为例说明各部分含义

下面结合 [gemm_fp32_linalg.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_linalg.mlir) 来看。

### 6.1 affine_map 定义

```mlir
#tile_outer = affine_map<(d0, d1) -> (128, d0 - d1)>
#tile_inner_m = affine_map<(d0, d1) -> (16, d0 - d1)>
#tile_inner_n = affine_map<(d0, d1) -> (16, d0 - d1)>
```

含义：

- 这是三个仿射映射定义
- 用来表达“块大小”和“边界剩余大小”的关系

例如 `#tile_outer` 的意思可以理解为：

- 对于某一维总长度 `d0`
- 和当前块起点 `d1`
- 当前块真实大小取 `128` 和 `d0 - d1` 中较小者

它后面会和 `affine.min` 配合使用，处理边界块。

### 6.2 module

```mlir
module {
  ...
}
```

含义：

- 表示当前文件中的最外层模块
- 函数、符号、属性通常都放在 `module` 里

### 6.3 函数定义

```mlir
func.func @gemm_fp32_linalg(%a: memref<?x?xf32>, %b: memref<?x?xf32>, %c: memref<?x?xf32>) attributes {
  c_kernel = "gemm_fp32",
  semantic = "C = A * B",
  layout = "A row-major, B row-major, C row-major",
  lift_target = "linalg.matmul -> scf/affine -> vector -> arm_sme",
  mlir_level = "linalg+scf"
} {
```

这段可以拆开看。

`func.func`

- 表示定义一个函数

`@gemm_fp32_linalg`

- 函数名

`%a: memref<?x?xf32>, %b: memref<?x?xf32>, %c: memref<?x?xf32>`

- 三个输入参数
- 都是二维 `f32` 矩阵
- `?x?` 表示两个维度都是动态大小
- `memref` 表示这是内存中的矩阵对象，不只是抽象张量

`attributes`

- 这是给函数附加的说明信息
- 对编译器和研究者都很有帮助

例如：

- `semantic = "C = A * B"`
  - 明确说明函数语义
- `layout = "A row-major, B row-major, C row-major"`
  - 明确内存布局
- `mlir_level = "linalg+scf"`
  - 说明当前文件的抽象层次

### 6.4 常量定义

```mlir
%c0 = arith.constant 0 : index
%c1 = arith.constant 1 : index
%cst_0 = arith.constant 0.0 : f32
%mc0 = arith.constant 128 : index
%nc0 = arith.constant 128 : index
%kc0 = arith.constant 128 : index
%mr0 = arith.constant 16 : index
%nr0 = arith.constant 16 : index
```

含义：

- 用 `arith.constant` 定义常量
- `index` 类型通常用于循环边界、维度、下标
- `f32` 类型用于浮点数值

这里这些常量分别表示：

- `0` 和 `1`
- 浮点零值
- 外层块大小 `mc / nc / kc = 128`
- 微块大小 `mr / nr = 16`

### 6.5 读取矩阵维度

```mlir
%m = memref.dim %a, %c0 : memref<?x?xf32>
%k = memref.dim %a, %c1 : memref<?x?xf32>
%n = memref.dim %b, %c1 : memref<?x?xf32>
```

含义：

- `memref.dim` 用于读取某个 `memref` 的某一维长度

第一句表示：

- 取矩阵 `A` 的第 `0` 维长度
- 也就是 `m`

第二句表示：

- 取矩阵 `A` 的第 `1` 维长度
- 也就是 `k`

第三句表示：

- 取矩阵 `B` 的第 `1` 维长度
- 也就是 `n`

### 6.6 外层循环

```mlir
scf.for %i = %c0 to %m step %mc0 {
  %mc = affine.min #tile_outer(%m, %i)
```

含义：

`scf.for`

- 这是结构化 `for` 循环
- 可以理解成 MLIR 里的高层循环表示

`%i = %c0 to %m step %mc0`

- 表示 `i` 从 `0` 开始
- 到 `m` 结束
- 步长是 `mc0 = 128`

`%mc = affine.min #tile_outer(%m, %i)`

- 计算当前这个块的真实大小
- 如果是完整块，就是 `128`
- 如果是边界块，就是剩余大小 `m - i`

后面的 `j` 和 `ko` 两层循环也是同样逻辑，分别对应：

- 列块 `nc`
- 归约块 `kc`

### 6.7 subview

```mlir
%a_tile = memref.subview %a[%i, %ko] [%mc, %kc] [%c1, %c1]
```

含义：

- `memref.subview` 表示从原始矩阵中切出一个子视图

这句可以理解成：

- 从矩阵 `A`
- 以 `(%i, %ko)` 为左上角
- 切出大小为 `(%mc, %kc)` 的子矩阵
- 两个维度步长都是 `1`

`%b_tile` 和 `%c_tile` 同理。

这一步很重要，因为它把“大矩阵运算”明确分成了“当前块运算”。

### 6.8 内层微块循环

```mlir
scf.for %ii = %c0 to %mc step %mr0 {
  %mr = affine.min #tile_inner_m(%mc, %ii)

  scf.for %jj = %c0 to %nc step %nr0 {
    %nr = affine.min #tile_inner_n(%nc, %jj)
```

含义：

- 这两层循环对应微块 `mr / nr`
- 它们在当前大块内部继续切小块

这里保留这些循环的意义是：

- 让后续 `vector` 化更自然
- 也更贴近论文里的块结构

### 6.9 更小一级的 subview

```mlir
%a_block = memref.subview %a_tile[%ii, %c0] [%mr, %kc] [%c1, %c1]
%b_block = memref.subview %b_tile[%c0, %jj] [%kc, %nr] [%c1, %c1]
%c_block = memref.subview %c_tile[%ii, %jj] [%mr, %nr] [%c1, %c1]
```

含义：

- 从 tile 再切出 block
- 这些 block 就是一次 `linalg.matmul` 操作的直接输入输出

### 6.10 linalg.fill

```mlir
linalg.fill ins(%cst_0 : f32)
            outs(%c_block : memref<?x?xf32, strided<[?, ?], offset: ?>>)
```

含义：

- 用 `0.0` 填充 `c_block`
- 对应研究版 `C = A * B` 语义中的“输出块先清零”

`ins(...)`

- 表示输入操作数

`outs(...)`

- 表示输出操作数

### 6.11 linalg.matmul

```mlir
linalg.matmul
  ins(%a_block, %b_block : memref<?x?xf32, strided<[?, ?], offset: ?>>,
                           memref<?x?xf32, strided<[?, ?], offset: ?>>)
  outs(%c_block : memref<?x?xf32, strided<[?, ?], offset: ?>>)
```

这是第一步中最关键的一组语句。

它的含义是：

- 把 `a_block` 和 `b_block` 做矩阵乘
- 结果累加到 `c_block`

这一步的意义在于：

- 原始 C 代码里是很多层标量循环和乘加
- 在这里被恢复成一个明确的高层矩阵乘算子

这正是 `MLIR` 高层表示最有价值的地方之一。

### 6.12 return

```mlir
return
```

含义：

- 函数结束
- 因为这里是通过输出参数 `%c` 原地写回结果，所以不需要显式返回矩阵值

---

## 7. 以 affine 版本为例说明各部分含义

下面结合 [gemm_fp32_affine.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_affine.mlir) 来看。

和 `linalg` 版相比，这份文件最大的不同是：

- 不再把核心计算压缩成 `linalg.matmul`
- 而是显式保留所有循环、索引和标量访问

这更适合分析预取。

### 7.1 affine_map

```mlir
#tile_outer = affine_map<(d0, d1) -> (128, d0 - d1)>
#row_index = affine_map<(d0, d1, d2) -> (d0 + d1 + d2)>
#col_index = affine_map<(d0, d1, d2) -> (d0 + d1 + d2)>
```

含义：

- `#tile_outer` 还是用于边界块大小
- `#row_index` 和 `#col_index` 用于统一表达行列索引计算

例如：

```mlir
%c_row = affine.apply #row_index(%i, %ii, %i_inner)
```

意思就是：

- `c_row = i + ii + i_inner`

### 7.2 affine.for

```mlir
affine.for %i = 0 to %m step 128 {
```

含义：

- 这是仿射循环
- 它比普通结构化循环更强调循环边界和下标表达式的仿射性质

对分析来说，这很有用，因为：

- 编译器更容易理解访存规律
- 研究者也更容易做 stride、复用距离等分析

### 7.3 arith.cmpi + scf.if

```mlir
%ii_in_bound = arith.cmpi ult, %ii, %mc : index
scf.if %ii_in_bound {
```

含义：

- 先比较 `%ii < %mc` 是否成立
- 再根据这个布尔值决定是否进入分支

这样做的原因是：

- 外层 `affine.for %ii = 0 to 128 step 16` 是固定范围
- 但边界块时真实大小 `%mc` 可能小于 `128`
- 所以要用条件判断裁掉越界部分

### 7.4 affine.apply

```mlir
%c_row_offset = affine.apply #row_index(%ii, %c0, %i_inner)
```

含义：

- 使用前面定义的仿射映射计算下标

如果代入 `#row_index(d0, d1, d2) = d0 + d1 + d2`，  
这句就是：

```text
c_row_offset = ii + 0 + i_inner
```

### 7.5 affine.store

```mlir
affine.store %f0, %c[%c_row, %c_col] : memref<?x?xf32>
```

含义：

- 把 `%f0` 也就是 `0.0`
- 写到矩阵 `C` 的 `(%c_row, %c_col)` 位置

这对应“清零输出微块”的动作。

### 7.6 affine.load

```mlir
%a_val = affine.load %a[%a_row, %a_col] : memref<?x?xf32>
```

含义：

- 从 `A[a_row, a_col]` 位置读一个标量
- 结果记到 `%a_val`

`%b_val`、`%c_old` 也是同样逻辑。

### 7.7 标量乘加

```mlir
%prod = arith.mulf %a_val, %b_val : f32
%sum = arith.addf %c_old, %prod : f32
affine.store %sum, %c[%c_row, %c_col] : memref<?x?xf32>
```

含义：

- `%prod`
  - 计算 `a_val * b_val`
- `%sum`
  - 计算 `c_old + prod`
- `affine.store`
  - 把结果写回 `C`

这三句合起来就是最基本的 GEMM 标量更新：

```text
C[c_row, c_col] = C[c_row, c_col] + A[a_row, a_col] * B[b_row, b_col]
```

### 7.8 为什么这里不直接用 linalg.matmul

因为这一份文件的任务不是“保留最高层算子语义”，而是：

- 暴露具体访存路径
- 暴露具体下标关系
- 暴露具体归约循环

只有这样，后续才方便研究：

- 哪些访问是顺序流
- 哪些访问会跨 cache line
- 哪些访问存在复用
- 预取距离应该怎么选

---

## 8. 第一份 MLIR 中最值得重点关注的内容

如果你刚开始读第一步生成物，建议按这个顺序看。

### 8.1 先看函数签名

重点理解：

- 输入是什么
- 使用了什么类型
- 当前文件属于哪一层 IR

### 8.2 再看常量和维度恢复

重点理解：

- `index` 类型在做什么
- `memref.dim` 如何恢复问题规模

### 8.3 再看循环结构

重点理解：

- 外层块循环
- 内层微块循环
- 边界块怎么处理

### 8.4 最后看核心计算

对于 `linalg` 版：

- 重点看 `linalg.fill`
- 重点看 `linalg.matmul`

对于 `affine` 版：

- 重点看 `affine.load`
- 重点看 `arith.mulf`
- 重点看 `arith.addf`
- 重点看 `affine.store`

---

## 9. 和后续步骤的关系

第一步输出的这两份 MLIR，不是最终结果，而是整个方案的起点。

它们分别服务于后续两个方向：

- `gemm_fp32_linalg.mlir`
  - 更适合继续做 `vector -> arm_sme -> llvm`
- `gemm_fp32_affine.mlir`
  - 更适合继续做访存分析和预取注入

因此，第一步的真正意义不是“把 C 改写成另一种语法”，而是：

- 把原始 C kernel 中隐藏的结构信息重新显式化
- 把后续研究需要的语义保留下来
- 为后面的高层分析与 lowering 铺路

---

## 10. 一句话总结

如果只用一句话概括第一步生成的 MLIR，可以这样理解：

`linalg` 版是在说“这是一系列分块后的矩阵乘”；  
`affine` 版是在说“这是一系列规则循环、显式访存和标量归约”。

这两种表示都来自同一个 C kernel，但它们分别服务于后续不同的研究目标。
