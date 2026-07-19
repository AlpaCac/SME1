# 02 Prefetch Cost Model

这个目录对应方案的第二步：在 `linalg` 层分析整体数据流性质，在 `affine` 层分析预取相关特征，并构建一个研究版 `cost module` 给出预取决策。

## 目标

这一阶段不直接修改 MLIR，而是先把“为什么预取、对谁预取、预取到哪一层、优先级如何排”说明白。

当前实现拆成三部分：

1. `linalg` 层分析  
   关注整体算子语义、输入输出角色、归约维、空间维、块级工作集和复用关系。

2. `affine` 层分析  
   关注规则循环、访存模式、读写流、边界块条件、以及真正和预取决策相关的局部性信息。

3. `cost module`  
   把上面两层的结果汇总成一个结构化决策，给出：
   - 是否预取
   - 读 / 写预取
   - 预取优先级
   - 目标缓存层级
   - 建议的预取距离
   - `KEEP / STRM` 风格建议

## 目录结构

- [analyze_prefetch.py](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/analyze_prefetch.py)：第二步分析脚本
- [output/prefetch_analysis.json](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/output/prefetch_analysis.json)：结构化结果
- [output/prefetch_analysis.md](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/output/prefetch_analysis.md)：可直接阅读的结果文档

## 当前分析方法

### 1. Linalg 层

脚本会读取第一步生成的：

- [gemm_fp32_linalg.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_linalg.mlir)

重点识别：

- 是否存在 `linalg.matmul`
- 是否存在 `linalg.fill`
- `subview` 与 `scf.for` 的组织关系
- 块级输入输出角色
- 宏块 / 微块工作集大小
- `A / B / C` 的复用方式

### 2. Affine 层

脚本会读取：

- [gemm_fp32_affine.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_affine.mlir)

重点分析：

- `affine.for`
- `affine.load`
- `affine.store`
- 边界块条件保护
- A/B/C 的访问连续性与复用特征

### 3. Cost Module

当前 `cost module` 是研究版启发式模型，不是最终硬件精确模型。它使用下面这些直观规则：

- 优先预取“连续读 + 跨迭代复用”的对象
- 优先考虑输入流 `A/B`
- 暂时不优先考虑 `C` 的软件预取
- 优先把预取目标放在 `L1`

在当前 GEMM 结构下，默认决策是：

- `B`：高优先级读预取
- `A`：中优先级读预取
- `C`：暂不主动预取

## 如何运行

在仓库根目录执行：

```bash
python3 02_prefetch_cost_model/analyze_prefetch.py
```

默认输入：

- `01_custom_lifter/output/gemm_fp32_linalg.mlir`
- `01_custom_lifter/output/gemm_fp32_affine.mlir`

默认输出到：

- [02_prefetch_cost_model/output](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/output)

## 当前输出的意义

这一步的产出不是最终“插入了预取指令的 MLIR”，而是下一步注入预取语义的依据。

也就是说，它回答的是：

- 为什么优先预取 `B`
- 为什么 `A` 次之
- 为什么 `C` 暂时不预取
- 后面应该把预取 op 注入到 `affine` 层的什么位置

## 下一步建议

完成这一阶段后，可以继续做三件事：

1. 把 `cost module` 的结果映射成自定义预取 op。
2. 在 `affine` 层实现真正的预取语义注入。
3. 继续研究这些预取语义如何跨层传递到 `vector / arm_sme / llvm`。
