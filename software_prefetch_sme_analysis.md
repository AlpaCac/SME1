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

本文只讨论 stencil。当前仓库的具体实现对象是：

1. 单时间步 2D 5-point stencil
2. 单时间步 3D 7-point stencil
3. `float32`、row-major、常系数
4. SME streaming mode 与 SVE 谓词向量 load/store
5. 数据读预取，不讨论写预取和指令预取

高阶、变系数、空间分块和时间分块只作为后续可扩展方向，不属于当前 kernel 的已实现范围。

当前主线为：

```text
stencil_sme_kernels.c
-> Clang CodeGen
-> LLVM IR
   - 循环、归纳变量和 GEP
   - llvm.masked.load
   - AArch64 SVE/SME intrinsic
-> StencilPrefetchPass
   - 识别 stencil 物理流
   - 边分析边决定距离、缓存层级和 KEEP/STRM
   - 插入 llvm.aarch64.prefetch
-> AArch64 后端
-> SME/SVE 计算指令 + PRFM
```

当前仓库已经包含 SME/SVE C kernel、预取原理分析和 LLVM pass 实施方案；`StencilPrefetchPass` 本身仍是后续开发目标。

## 3. 参考依据

### 3.1 项目内材料

项目内只保留 stencil 相关材料：

1. `stencil_sme_kernels.c`：2D5P/3D7P ACLE kernel
2. `stencil预取优化实施方案.md`：可执行的预取决策和 LLVM pass 步骤
3. `software_prefetch_sme_analysis.md`：预取类别、原理和扩展方向

实现时应以 `stencil预取优化实施方案.md` 为准。分析与插入在同一个 LLVM pass 中完成，不通过 JSON 或其他外部文件传递决策。

### 3.2 论文与编译器依据

Google Scholar 检索中，与本文最直接相关的是：

1. *SMEStencil: Optimizing High-Order Stencils on ARM Multicore Using SME Unit*。检索摘要指出，软件预取可用于缓解 Arm 多核系统中 stencil 的数据供给问题。
2. SME、软件预取和高阶 stencil 相关工作共同表明，预取效果强烈依赖距离、布局、缓存容量、向量长度和并行配置。
3. LLVM AArch64 `llvm.aarch64.prefetch` intrinsic 可以表达数据读预取、L1/L2/L3 目标以及 KEEP/STRM 策略，并由后端映射为 `PRFM` 提示。


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

## 7. 在当前 Clang/LLVM 编译链中的落地方式

### 7.1 从原始 ACLE C 生成可分析的 LLVM IR

不要求把 C kernel 改写成结构化子集。Clang 正常编译 `stencil_sme_kernels.c`，LLVM IR 中保留：

1. 最内层 `x` 循环和归纳变量
2. 行跨度 `W`、平面跨度 `H * W` 对应的 GEP/SCEV 地址
3. SVE 谓词 load 对应的 `llvm.masked.load`
4. `svcntsw()` 对应的可伸缩向量步长
5. SME locally-streaming 函数属性

pass 应依赖 `LoopInfo`、ScalarEvolution 和 DominatorTree 识别结构，不能依赖 SSA 名称或固定基本块编号。

### 7.2 识别并合并 stencil 物理流

2D5P 的 5 个逻辑 load 合并为 3 条主要 cache-line 流：

1. current row，合并 left/center/right
2. north row
3. south row

3D7P 在此基础上增加 front/back plane，共 5 条主要流。地址差必须由 SCEV 证明为 `0`、`±1`、`±W` 和 3D 的 `±H*W`；无法证明时跳过，不能仅按 load 数量猜测。

### 7.3 在同一个 pass 中做出决策

每条流使用局部 `StreamInfo` 和 `PrefetchDecision`，依次确定：

```text
enable
distance_iterations
cache_level = L1 | L2 | L3
policy = KEEP | STRM
```

输入包括目标 cache profile、预计延迟、SME VL、循环 trip count、行/平面工作集、复用距离、最大流数量和预取带宽预算。pass 生成候选后按 2D/3D 不同优先级准入，随后立即插入，不序列化分析结果。

完整公式、动态 `W/H`、多 cache-line 向量和预算降级算法见 `stencil预取优化实施方案.md` 的步骤 4。

### 7.4 构造安全的未来地址

未来位置为：

```text
future_x = x + distance_iterations * svcntsw()
```

不能盲目复制当前 `inbounds GEP` 后越过对象边界。优先把内层循环拆成可无条件预取的 main loop 和尾部；暂不做 loop versioning 时，使用合法范围 guard。

同一未来 SME 向量跨多个 cache line 时，根据目标 VL profile 为每个 line 构造地址。left/center/right 已经合流，不能重复发出预取。

### 7.5 插入 AArch64 intrinsic

pass 直接插入：

```llvm
call void @llvm.aarch64.prefetch(
  ptr %future_address,
  i32 0,
  i32 target,
  i32 stream,
  i32 1)
```

参数映射：

1. `isWrite = 0`：数据读预取
2. `target = 0/1/2`：L1/L2/L3
3. `isStream = 0/1`：KEEP/STRM
4. `isData = 1`：数据而非指令

AArch64 后端通常生成 `PRFM PLDL1KEEP`、`PLDL1STRM`、`PLDL2KEEP` 等形式，不需要自定义中间 op 或额外 lowering。

### 7.6 扩展到外层空间预热

next-row、next-plane 和 next-tile 不能只观察单个内层 load。后续实现需要访问外层循环，在当前空间块接近结束时维护预取 frontier。

第一版只实现 B 类跨行和 3D C 类近距离跨平面预取；外层 D 类预热必须在近距离方案经 PMU 证明有效后再加入。


## 8. 边界、尾部和正确性

stencil 预取地址必须位于合法对象内。即使目标 CPU 将 `PRFM` 视为非故障 hint，C/LLVM IR 语义也不应构造越界或 poison 地址。

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
4. [LLVM New Pass Manager 文档](https://llvm.org/docs/NewPassManager.html)
5. [LLVM AArch64 intrinsic 定义](https://github.com/llvm/llvm-project/blob/main/llvm/include/llvm/IR/IntrinsicsAArch64.td)
