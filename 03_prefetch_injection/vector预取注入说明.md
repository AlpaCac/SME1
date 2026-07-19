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

## 2. vector 层中的关键结构

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

## 3. 预取插入形式

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

## 4. 如何使用第二步分析结果

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

## 5. 当前限制

当前实现采用通用 IR 结构匹配，不依赖函数名或 SSA 名，但仍有研究原型限制：

- 只处理 rank-1 `vector.transfer_read`
- 默认 rank-1 read 按出现顺序交替对应 A/B
- 暂时不对 rank-2 C tile 读插入预取
- JSON 解析是轻量字段解析，不是完整 JSON 库

后续更稳的做法是追踪 `vector.transfer_read` 的 base memref 来源，沿 `memref.subview` 回溯到函数参数，从而精确判断当前读流来自 A、B 还是 C。
