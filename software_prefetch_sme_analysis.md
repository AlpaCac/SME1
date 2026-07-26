# 使用软件预取优化 SME Stencil 的类型与落地方案

生成时间：2026-07-26

## 1. 结论

本文只分析运行在 Arm SME 上的 stencil 算子。

本文只考虑数据读预取。按照 stencil 数据流和预取时机，真正值得评估的预取可归纳为 4 类：

1. 邻域输入的近距离 `L1` 读预取
2. 下一行、下一平面或下一空间 tile 的远距离 `L2` 读预取
3. 时间分块下下一批外部输入的读预取
4. 变系数 stencil 的系数场读预取

优先级应为：

1. 先做邻域输入的 `L1` 读预取
2. 再做跨行、跨平面和跨 tile 的 `L2` 读预取
3. 根据 temporal blocking 和系数场的实际 miss 决定是否增加专项预取

最重要的原则不是给每条 load 前都插一条预取，而是识别将被 SME 消费的独立 cache-line 数据流，并为不同维度、不同邻域偏移设置合适的提前量。

## 2. 分析范围与当前项目状态

本文覆盖：

1. 1D、2D 和 3D 规则 stencil
2. 低阶和高阶 stencil
3. 常系数和变系数 stencil
4. 空间分块和时间分块
5. 单核和多核下的软件预取策略
6. `MLIR -> Arm SME -> LLVM -> AArch64 PRFM` 的实现路径

当前 `SME1` 仓库已经具备可复用的预取后半段基础设施：

```text
affine-normalized 层分析
-> vector 层插入 memref.prefetch
-> Arm SME / LLVM lowering
-> llvm.intr.prefetch
-> AArch64 prfm
```

目前仓库还没有完整的 stencil kernel、stencil 语义分析或 stencil 预取注入产物。因此本文描述的是后续以 stencil 为主线时应实现的方案，而不是现有完成状态。

## 3. 参考依据

### 3.1 项目内可复用材料

本文参考当前仓库已有的预取分析和跨层 lowering 设计：

1. `02_prefetch_cost_model/output/prefetch_analysis.md`
2. `03_prefetch_injection/vector预取注入说明.md`
3. `04_vector_arm_sme_llvm/prefetch参数映射说明.md`
4. `README.md`

这些材料的主要复用价值是：

1. 在高层循环 IR 中形成结构化预取决策
2. 在 vector/memref 层插入标准 `memref.prefetch`
3. 将预取语义保留到 `llvm.intr.prefetch`
4. 最终验证汇编中的 AArch64 `prfm`

不应直接复用基于固定操作数身份或 rank-1 load 出现顺序的流分类方法。stencil 必须根据索引映射、维度和邻域偏移识别数据流。

### 3.2 论文与官方资料

Google Scholar 检索中，与本文最直接相关的是：

1. *SMEStencil: Optimizing High-Order Stencils on ARM Multicore Using SME Unit*。检索摘要明确指出，软件预取被用于弥补 Arm 多核系统硬件预取能力的不足。
2. SME、软件预取和高阶 stencil 相关工作共同提示高计算吞吐会把瓶颈推向数据供给，且预取效果强烈依赖距离、布局、缓存容量和并行配置。

编译器层参考：

1. MLIR `memref.prefetch`
2. LLVM `llvm.prefetch`

## 4. 为什么 SME Stencil 需要软件预取

### 4.1 SME 提高计算吞吐后，数据供给更容易成为瓶颈

stencil 的单点运算通常规则，但每个输出点需要多个邻域输入。SME 提高向量或 tile 计算吞吐后，如果邻域行和平面不能及时到达缓存，计算单元会更频繁地等待 load。

### 4.2 硬件预取更容易识别连续流，难以理解完整邻域

对于 row-major 布局，最内层连续维通常容易被硬件预取器识别。但硬件不一定能够稳定理解：

1. 前后行或前后平面的多个并行流
2. 高阶半径 `r > 1` 的远邻流
3. 空间 tile 切换后的地址跳转
4. ping-pong buffer 的时间步切换
5. 每个邻域流的复用窗口
6. 多核划分后的局部子域边界

### 4.3 高阶和 3D stencil 会快速增加并发数据流

2D 五点 stencil 的流数量有限；3D、高阶或变系数 stencil 会同时访问更多行、平面和系数数组。并发流过多时，硬件预取器的 stream 跟踪能力、缓存容量和内存带宽都可能成为限制。

### 4.4 软件预取可以利用高层 stencil 语义

编译器在高层 IR 中可以知道：

1. stencil 维数
2. 半径和邻域偏移
3. 数据布局和 leading dimension
4. 空间 tile 和时间 tile
5. 内部区与边界区
6. 下一次 SME 向量迭代将访问的地址

这些信息比 LLVM 后端只观察低层地址流更适合决定是否预取、预取哪条流以及提前多少。

## 5. Stencil 工程上可用的 4 类读预取

### 5.1 邻域输入的近距离 `L1` 读预取

以 2D/3D、半径为 `r` 的规则 stencil 为例，输入流包括：

1. 中心点及最内层连续维的左右邻居
2. 前后行邻居
3. 3D stencil 的前后平面邻居
4. 高阶 stencil 中距离为 `2..r` 的远邻行和平面

软件预取应针对下一次或下几次向量迭代将触及的新 cache line。中心点和左右邻居经常落在相同或相邻 cache line 上，不应机械地为每个 load 分别发出预取。

建议：

1. 默认候选为 `read + L1 + KEEP`
2. 优先处理跨行、跨平面和高阶远邻流
3. 对最内层连续流先验证硬件预取是否已经充分
4. 按 cache line 对预取请求去重
5. 限制每次迭代发出的预取指令数量

### 5.2 下一行、下一平面或下一空间 tile 的 `L2` 读预取

3D stencil 的平面跨度大，下一平面数据可能无法在短距离内直接进入 L1。可采用两级策略：

```text
下一行/平面/tile 先进入 L2
接近使用时再由 L1 预取接力
```

可选注入点：

1. 当前行计算到指定位置时，预取下一行的工作集前沿
2. 当前平面计算期间，预取下一平面的工作集前沿
3. 当前空间 tile 尾部，预取下一个 tile 的内部区

不建议在循环入口一次性预取整个平面。应维护随计算推进的 prefetch frontier，控制缓存占用、预取提前量和指令密度。

### 5.3 时间分块下下一批外部输入的读预取

temporal blocking 中，下一时间步的数据可能来自：

1. 当前 tile 内刚生成、仍驻留缓存的数据
2. 下一空间 tile 的旧时间层数据
3. ping-pong buffer 中尚未进入缓存的数据

第一类数据通常不需要预取，因为生产者写入已经使其驻留缓存。第二、三类才可能受益。

必须避免：

1. 预取尚未被前一时间步产生的数据
2. 过早预取导致当前时间层数据被逐出
3. 忽略 ping-pong buffer 切换而计算错误地址
4. 在容量不足时盲目增加时间 tile 深度

### 5.4 变系数 stencil 的系数场读预取

常系数权重通常可常量折叠或驻留寄存器，不值得预取。若每个网格点或每条边需要读取独立系数，系数数组会形成额外内存流。

建议：

1. 常系数模式关闭
2. 小型共享系数表关闭
3. 逐点或逐边系数场按独立读流分析
4. 沿与输出点相同的空间前沿预取
5. 系数场较多时，只启用 miss 贡献显著的流

## 6. 预取距离模型

stencil 不能只使用固定字节距离。建议先以“提前多少次向量迭代”建模：

```text
distance_iterations
  = ceil(memory_latency_cycles / useful_cycles_per_vector_iteration)
```

再换算为字节距离：

```text
distance_bytes
  = distance_iterations
  * elements_per_vector_iteration
  * bytes_per_element
```

最终对齐到 cache line，并结合流的维度偏移形成地址：

```text
prefetch_address
  = base
  + neighbor_offset
  + distance_bytes_along_inner_dimension
```

模型至少需要考虑：

1. 向量长度或 SME tile 形状
2. 每次向量迭代的有效计算周期
3. cache line 大小
4. L1/L2 延迟
5. stencil 半径和邻域数量
6. 行跨度和平面跨度
7. 空间/时间 tile
8. 单核或多核内存带宽
9. 同时启用的预取流数量

距离过短会导致预取过晚；距离过长会导致缓存污染、提前逐出或浪费带宽。不同邻域流应允许使用不同距离。

## 7. 在当前编译链中的落地方式

### 7.1 新增 stencil 高层入口

输入 kernel 应显式保留：

1. 维数
2. 半径
3. 邻域偏移
4. 数据布局
5. 边界条件
6. 空间 tile
7. 时间 tile
8. 常系数或变系数模式

可采用 `linalg.generic`、结构化 stencil 表达或带属性的 `scf/affine` 循环作为分析入口。关键要求是不能在 cost model 运行前丢失邻域语义。

### 7.2 在 affine-normalized 层识别访存流

对每个 load 回溯 base memref 和 affine index map，识别：

1. 中心流
2. 最内层左右邻居
3. 行邻居
4. 平面邻居
5. 系数流
随后按以下条件合并请求：

1. 相同底层 buffer
2. 相同或等价邻域偏移
3. 落在相同 cache line
4. 使用时间窗口相近

### 7.3 输出通用的结构化决策

建议每条决策至少包含：

```text
kernel = stencil
stream = center | row-neighbor | plane-neighbor | coefficient
rw = read
level = L1 | L2
policy = KEEP | STRM
distance = 整数或符号表达式
insertion_scope = vector | row | plane | tile | timestep
dimension = 1D | 2D | 3D
radius = 整数
neighbor_offset = 索引向量
guard = 边界合法性条件
```

### 7.4 在 vector 层插入近距离预取

在真实 `vector.transfer_read` 或等价向量 load 前若干迭代插入 `memref.prefetch`。

注入器需要：

1. 从向量 load 追踪到原始 stencil 流
2. 根据向量迭代变量计算未来地址
3. 对 cache line 去重
4. 限制单次迭代的预取数量
5. 为尾部和边界生成合法 guard

### 7.5 在外层循环插入远距离预取

行、平面和 tile 级 `L2` 预取不能只观察单个向量 load。注入器需要访问外层循环上下文，在以下位置生成预取：

1. 行循环内部的下一行前沿
2. 平面循环内部的下一平面前沿
3. 空间 tile 循环内部的下一 tile 前沿
4. 时间 tile 切换点的下一批外部输入

### 7.6 保留到 LLVM 和 AArch64

预取主线应保持：

```text
memref.prefetch
-> llvm.intr.prefetch
-> AArch64 prfm
```

同时保留 metadata 或函数属性，以便回答：

1. 预取对应哪个 stencil 流
2. 目标是 L1 还是 L2
3. 使用 KEEP 还是 STRM
4. 距离由哪个循环维度和公式计算
5. 对应哪个邻域偏移

## 8. 边界、尾部和正确性

stencil 预取地址必须位于合法对象内。即使目标 CPU 将 `PRFM` 视为非故障 hint，MLIR/C 语义也不应构造越界地址。

建议把 kernel 拆为：

1. 无分支的内部主循环
2. 单独处理的边界区
3. 单独处理的向量尾部

策略：

1. 内部区稳定插入预取
2. 边界区默认不插入，除非能够廉价证明合法
3. 向量尾部使用 guard，或在已分配 padding 内预取
4. 周期边界使用映射后的真实地址
5. halo 区必须区分已分配 halo 与逻辑越界
6. 多核子域边界不能预取到未映射或不属于当前对象的区域

## 9. 多核注意事项

多核 stencil 中，单核有效的激进预取不一定能扩展。需要额外考虑：

1. 多核共同消耗内存带宽
2. 每个核心的预取流数量
3. 共享 L2/L3 的容量和争用
4. NUMA 或 cluster 拓扑
5. halo 交换与计算重叠
6. false sharing

调优顺序应是：

1. 先确定单核正确距离范围
2. 再在多核下重新扫描距离和并发流数量
3. 当带宽饱和后，减少无收益预取
4. 分别验证强扩展和弱扩展

## 10. 实施路线

### 阶段 1：建立 stencil baseline

1. 增加至少一个 2D 低阶 stencil
2. 增加至少一个 3D 高阶 stencil
3. 生成无软件预取的 SME baseline
4. 验证数值正确性和汇编中的 SME 指令

### 阶段 2：实现流识别与 `L1` 预取

1. 在高层 IR 保留 stencil metadata
2. 在 affine/vector 层恢复邻域流
3. 实现内部区近距离预取
4. 实现 cache-line 去重和指令数量限制
5. 扫描各邻域流的距离

### 阶段 3：实现 `L2` prefetch frontier

1. 增加下一行预取
2. 增加下一平面预取
3. 增加下一空间 tile 预取
4. 与 `L1` 近距离预取组合

### 阶段 4：扩展复杂 stencil

1. 支持 temporal blocking
2. 支持变系数场
3. 支持多核子域和 halo

## 11. 实验设计

至少选择以下 kernel：

1. 2D 低阶 stencil
2. 2D 高阶 stencil
3. 3D 低阶 stencil
4. 3D 高阶 stencil
5. 一个变系数 stencil

每个 kernel 测试：

1. `baseline`：无软件预取
2. `inner-dimension-L1`
3. `row-neighbor-L1`
4. `plane-neighbor-L1`，仅 3D
5. `neighbor-L1 + next-row-L2`
6. `neighbor-L1 + next-plane-L2`，仅 3D
7. `neighbor-L1/L2 + next-tile`
8. `neighbor-L1/L2 + coefficient`，仅变系数

每组扫描多个距离和预取流数量，并覆盖：

1. 不同网格尺寸
2. 不同半径
3. 不同空间 tile
4. 不同时间 tile
5. 不同线程数
6. 内部区与完整边界版本

重点指标：

1. GStencil/s 或 cell updates/s
2. 总周期数
3. L1D miss
4. L2D miss
5. LLC miss
6. TLB miss
7. memory bandwidth
8. 指令数
9. 预取相关 PMU 事件
10. 多核扩展效率

所有性能结果必须同时通过数值正确性验证。

## 12. 推荐默认策略

第一版 stencil 预取实现建议采用：

```text
内部区：
  跨行/跨平面邻域 -> L1 + KEEP
  下一行/下一平面 -> L2 + KEEP
  最内层连续流 -> 默认关闭，确认硬件预取不足后再打开

边界区：
  默认关闭软件预取

变系数：
  默认关闭，确认系数流 miss 显著后再打开
```

最终建议：

1. 优先把邻域流识别做准
2. 先减少 cache miss，再控制预取指令开销
3. 使用 `L2 warming + L1 near-use` 两级策略
4. 不为同一 cache line 重复预取
5. 不把单核最优参数直接用于多核
6. 任何额外读流都必须由 PMU 证据驱动

## 13. 参考链接

1. [Google Scholar: ARM SME software prefetch stencil](https://scholar.google.com/scholar?q=%22ARM+SME%22+software+prefetch+stencil)
2. [Google Scholar: SME high-order stencil prefetch](https://scholar.google.com/scholar?q=SME+high-order+stencil+prefetch)
3. [SMEStencil: Optimizing High-Order Stencils on ARM Multicore Using SME Unit](https://ieeexplore.ieee.org/abstract/document/11328920/)
4. [MLIR `memref.prefetch` 文档](https://mlir.llvm.org/docs/Dialects/MemRef/)
5. [LLVM `llvm.prefetch` 文档](https://www.llvm.org/docs/LangRef.html)
