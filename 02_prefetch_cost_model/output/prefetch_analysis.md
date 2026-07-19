# 第二步分析结果

这份报告由 `step2-prefetch-cost-model` MLIR pass 生成。输入是第一步的 `linalg` 主线，分析层是经过 linalg lowering 得到的 `scf + affine indexing` 循环形态。

## 1. IR 结构摘要

- `linalg.matmul` 数量：`0`
- `linalg.fill` 数量：`0`
- `scf.for` 数量：`10`
- `memref.subview` 数量：`4`
- `memref.load` 数量：`3`
- `memref.store` 数量：`2`

## 2. 分块和工作集

- 宏块：`mc=128, nc=128, kc=128`
- 微块：`mr=16, nr=16`
- 宏块工作集：`196608 bytes`
- 微块工作集：`17408 bytes`

## 3. 预取决策

- `B`：开启读预取，优先级 high，目标 L1，策略 KEEP。原因是 B 在 N 方向连续访问，并在 M 微块方向复用。
- `A`：开启读预取，优先级 medium，目标 L1，策略 KEEP。原因是 A 沿 K 方向连续访问，并在 N 微块方向复用。
- `C`：当前不开启主动软件预取。原因是 C 是短生命周期累加块，更适合先观察实际硬件行为后再决定。

## 4. 对第三步的输出接口

第三步应读取 `prefetch_analysis.json` 中的 `decisions`，并在 vector 主线中对 A/B 的读流插入预取语义。本步骤不直接修改计算语义，只给出分析结果和决策。
