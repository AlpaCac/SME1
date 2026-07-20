# 03 Vector 预取注入说明

这份文档说明第三步生成的 vector 层 MLIR 中，各部分结构是什么，以及预取是如何根据第二步分析结果插入的。

## 1. 为什么第三步改在 vector 层插入

当前总体方案是：

```text
C kernel
-> linalg 主线
-> affine-normalized 分析层生成预取决策
-> vector 层插入预取
-> arm_sme / llvm lowering
```

第二步已经负责在 affine-normalized 层分析访存和复用，第三步的任务是把这些决策落到后续真正参与 lowering 的 vector 主线上。因此第三步不再生成 `research.prefetch`，而是插入 MLIR 标准 `memref.prefetch`。

## 2. 什么是 MLIR vector 层

`vector` 层是 MLIR 中用于表达向量计算的中高层 IR。它位于 `linalg / affine / scf` 这类结构化高层 IR 和 `llvm / target intrinsic` 这类低层 IR 之间。

可以把它理解为：

```text
linalg.matmul
-> vector.transfer_read / vector.outerproduct / vector.transfer_write
-> arm_sme / arm_sve / llvm
```

在 `linalg` 层，矩阵乘还是一个整体算子；在 `affine` 层，重点是循环、下标和访存规律；到了 `vector` 层，计算已经开始显式体现“每次处理一组元素”的向量化语义。

## 3. vector 层的主要特征

### 3.1 显式表示向量数据

`vector` 层会出现这样的类型：

```mlir
vector<[16]xf32>
vector<[16]x[16]xf32>
```

它们表示一次操作处理多个 `f32` 元素，而不是只处理一个标量。

其中：

- `vector<[16]xf32>`
  - 表示一个一维可扩展向量
  - 当前常用于表示 A 或 B 的一段输入向量
- `vector<[16]x[16]xf32>`
  - 表示二维向量 tile
  - 当前常用于表示 C 的 16x16 累加块

这里的方括号 `[16]` 表示 scalable vector 维度，后续更容易和 SVE/SME 这类可扩展向量机制衔接。

### 3.2 显式表示向量访存

在标量 affine 层中，访存通常是：

```mlir
affine.load
affine.store
```

而在 vector 层中，访存变成：

```mlir
vector.transfer_read
vector.transfer_write
```

这说明编译器已经不再只看单个元素，而是看“一段向量数据如何从内存搬到向量寄存器，以及如何写回内存”。

这对预取研究很重要，因为软件预取通常应该发生在真实向量读之前，而不是等到所有语义都降到低层 LLVM 后再靠后端猜测。

### 3.3 显式表示向量计算

当前 GEMM 的核心计算在 vector 层表现为：

```mlir
vector.outerproduct
```

它表示用两个一维向量生成二维累加结果，正好对应矩阵乘微内核中的外积计算模式。

这比标量形式：

```text
C[i, j] += A[i, k] * B[k, j]
```

更接近 SME/SVE 硬件实际执行的向量或 tile 计算形式。

### 3.4 保留高层结构，同时接近目标 lowering

`vector` 层不是最终机器指令，但它已经比 `linalg.matmul` 更接近硬件：

- 它仍然保留结构化循环和 memref 信息
- 它已经显式表示向量读写和向量计算
- 它可以继续 lowering 到 `arm_sme`、`arm_sve` 或 `llvm`
- 它适合承接第二步分析结果并插入标准预取

因此第三步选择 vector 层作为预取注入点，是为了兼顾两点：

- 仍然有足够高层的信息，能知道哪些读流来自矩阵计算结构
- 已经足够接近后续 lowering，插入的 `memref.prefetch` 更容易保留到 LLVM

## 4. vector 层中的关键结构

第三步的 vector 输出中主要关注这些 op：

```mlir
vector.transfer_read
vector.outerproduct
vector.transfer_write
```

其中：

- `vector.transfer_read`
  - 从 memref 中读取一段向量
  - 当前 A/B 的读流表现为 rank-1 vector
- `vector.outerproduct`
  - 表达向量外积
  - 对应矩阵乘微内核的核心计算
- `vector.transfer_write`
  - 把向量计算结果写回 C tile

## 5. 预取插入形式

当前 pass 在 A/B 的 rank-1 `vector.transfer_read` 前插入：

```mlir
memref.prefetch %subview[%c0], read, locality<3>, data : memref<?xf32, ...>
vector.transfer_read %subview[%c0], ...
```

这表示：

- `read`
  - 预取读数据
- `locality<3>`
  - 给较强局部性提示，当前对应第二步 `KEEP`
- `data`
  - 预取数据缓存，而不是指令缓存

## 6. 如何使用第二步分析结果

第三步 pass 会读取：

```text
02_prefetch_cost_model/output/prefetch_analysis.json
```

当前使用的字段包括：

- `tensor`
- `enable`
- `priority`
- `target_cache`
- `locality`
- `distance`

其中 `enable` 决定是否插入预取；`locality` 用来映射 `memref.prefetch` 的 locality hint；其他字段写入函数属性，用于说明当前 vector 预取来自哪一组 cost model 决策。

## 7. 当前限制

当前实现采用通用 IR 结构匹配，不依赖函数名或 SSA 名，但仍有研究原型限制：

- 只处理 rank-1 `vector.transfer_read`
- 默认 rank-1 read 按出现顺序交替对应 A/B
- 暂时不对 rank-2 C tile 读插入预取
- JSON 解析是轻量字段解析，不是完整 JSON 库

后续更稳的做法是追踪 `vector.transfer_read` 的 base memref 来源，沿 `memref.subview` 回溯到函数参数，从而精确判断当前读流来自 A、B 还是 C。
