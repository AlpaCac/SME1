# MLIR 各层级的 Stencil 预取语义与硬件信息

本文按照 MLIR 从高层到低层的 lowering 顺序，分别说明：

1. 当前层级能够获得哪些 Stencil 语义；
2. 根据这些语义能够生成或改进哪类软件读预取；
3. 做出最终决策还需要哪些目标硬件信息。

本文只讨论 Stencil 读预取。四类预取记为：

| 类别 | 含义 |
|---|---|
| A | 连续维前向预取，即预取未来 `x` 位置 |
| B | 跨行邻域预取，即预取未来 row stream |
| C | 跨平面邻域预取，即预取未来 plane stream |
| D | 下一空间块预取，即预取下一行段、平面块或 tile |

需要区分“生成候选”和“发出指令”。高层适合判断预取什么，低层适合根据最终地址、
VL 和谓词决定准确何时发出，并物化为 `PRFM`。不是每一层都应该独立插入一条
预取，否则 lowering、向量化和循环展开可能产生重复预取。

文中列出的硬件信息并不会因为 IR lowering 到某一层就自动出现。它们通常来自三处：
编译期 target/subtarget 配置，运行时可查询的 VL、问题规模和线程数，以及通过
microbenchmark 或 PMU 测得的延迟、带宽和 stall。MLIR 各层只是使用这些信息，
不能仅靠 IR 自身推导出真实硬件参数。

## 1. 层级总览

| 层级 | 最有价值的语义 | 主要支持的预取 | 主要硬件输入 |
|---|---|---|---|
| Linalg/Tensor | 算子、输入输出、shape、indexing map | 识别 A/B/C/D 候选对象 | 粗粒度 cache 容量 |
| Tiling/Bufferization/MemRef | tile、subview、buffer、物理 stride、生命周期 | C 的 L2 预热、D 下一块预取 | cache 容量、相联度、共享关系、cache line |
| SCF/Affine | 循环顺序、边界、归纳变量、精确 affine 地址和复用 | B/C/D 的位置、距离单位和合法性 | cache/内存延迟、每迭代周期、TLB/page |
| Vector | 向量形状、连续/跨步/gather、mask、scalable VL | A 以及 B/C 的向量化物化准备 | VL、cache line、向量访存成本 |
| ArmSVE | `vscale` 步长、SVE 谓词、尾部和目标相关 load | A/B/C 的最终地址与尾部保护 | SVE VL、PRFM hint 行为、硬件预取器 |
| ArmSME | streaming mode、ZA 生命周期、MOPA/SME 计算窗口 | 修正距离和插入位置，避免干扰 SME 计算 | streaming VL、SME 吞吐、调度与寄存器压力 |
| LLVM/Machine | 最终 GEP、控制流、目标 intrinsic、指令调度 | 最终合法性检查并生成 `PRFM` | 完整目标 Profile 和调度模型 |
| Runtime/PMU | miss、stall、带宽、TLB、实际加速比 | 调参、消融或关闭负收益预取 | PMU 事件定义与稳定测试环境 |

## 2. Linalg/Tensor 层

### 2.1 能够获取的语义

对于由 `linalg.generic` 或自定义 Stencil op 表达的计算，这一层可以获得：

- 输入 tensor、输出 tensor 及其读写角色；
- 1D、2D、3D shape 和动态维度；
- indexing map 中的 `x/y/z` 与邻域偏移；
- Stencil 维度、点数、半径和 star/box 形状；
- tensor layout，以及同一输入元素被多个输出点使用的逻辑复用；
- 算子融合前后的输入输出关系。

普通 `linalg.generic` 不一定直接标记“这是 Stencil”，但可以从 indexing map 中识别
类似以下访问：

```text
input(y, x)
input(y, x - 1)
input(y, x + 1)
input(y - 1, x)
input(y + 1, x)
```

### 2.2 能够做的预取工作

这一层适合：

- 确定哪些输入需要读预取，并排除只写输出；
- 把逻辑访问归类为 current、row、plane 或 next-block 候选；
- 直接得到邻域半径，避免在 LLVM IR 中按 load 数量猜测算子；
- 估算逻辑复用次数，为 `KEEP/STRM` 提供初始倾向；
- 为 B、C、D 类生成高层候选或 metadata。

这一层不适合固定最终预取距离。此时尚不知道 tiling、循环顺序、向量化步长和最终
谓词，过早插入可能在后续变换中被复制或改变相对位置。

### 2.3 需要的硬件信息

识别候选基本不需要硬件信息。若要做初步筛选，只需要：

- L1/L2/LLC 的大致容量；
- cache line 大小；
- 目标是否支持有效的软件读预取。

这些信息只能用于判断整个 row、plane 或 tensor 工作集是否明显过大，不能用于决定
最终迭代距离和 `PRFM` hint。

## 3. Tiling、Bufferization 与 MemRef 层

### 3.1 能够获取的语义

完成 tiling 和 bufferization 后，可以看到：

- tile 的起点、大小和遍历顺序；
- `memref.subview` 对应的当前块与下一块；
- tensor 到实际 buffer 的映射；
- memref shape、stride、layout 和动态尺寸；
- allocation、alias、临时 buffer 及其生命周期；
- 边界 tile 与完整 tile 的区别；
- 一个 row/plane/tile 占用的实际字节数。

### 3.2 能够做的预取工作

这一层最适合处理块级预取：

- 为 C 类计算真实 plane bytes，判断先预热到 L2 还是临近时再预取到 L1；
- 为 D 类确定下一 tile 的首地址、大小和切换时机；
- 根据 tile 工作集抑制会超过 cache 容量的候选；
- 利用 subview 边界生成不会跨 allocation 的块级保护条件；
- 在 buffer 发生 packing 或 layout 变化后更新预取对象和 stride。

此时仍建议保留抽象候选，而不是直接固定成目标 intrinsic，因为后续循环变换和
向量化还会改变一次迭代消费的数据量。

### 3.3 需要的硬件信息

- L1/L2/LLC 容量及可供预取使用的比例；
- cache associativity 和可能的 set 冲突；
- cache line 大小；
- cache 是否由多个核心共享；
- L1、L2 和内存延迟；
- 页大小、TLB 容量和跨页代价。

其中容量决定 tile 是否适合驻留，延迟决定下一块应提前多少个外层循环阶段开始
预热，相联度和共享关系用于估计 cache pollution。

## 4. SCF/Affine 层

### 4.1 能够获取的语义

这一层显式表示循环，能够获得：

- `x/y/z` 循环的嵌套顺序；
- 循环上下界、步长、trip count 和归纳变量；
- 主循环、尾循环和边界条件；
- affine load/store 的地址表达式；
- row stride、plane stride 和下一块地址；
- 某条流隔多少次循环再次使用；
- 预取候选应放在内层还是外层循环。

相比 Linalg 层，这里更清楚“什么时候消费”；相比 LLVM IR，这里仍保留维度和
结构化循环语义。

### 4.2 能够做的预取工作

SCF/Affine 是 B、C、D 类最重要的决策层：

- B 类：确定上下行或更远半径行，并生成 row 级候选；
- C 类：确定前后平面、plane stride 和 `z` 方向复用；
- D 类：在外层循环中确定下一块预热位置；
- 用 trip count 关闭过短循环的预取；
- 用循环边界证明未来 row/plane/tile 地址合法；
- 把距离先表示为 vector iteration、row、plane 或 tile 等语义单位。

如果只停留在这一层，A 类的最终距离仍不准确，因为尚未看到 SVE 可伸缩向量化后的
真实步长。

### 4.3 需要的硬件信息

- L1/L2/内存需要隐藏的延迟；
- 每次内层迭代或每个 tile 的预计周期；
- cache 容量、cache line 和相联度；
- 硬件预取器能否识别连续流和固定 stride；
- 内存带宽上限和允许并行的预取流数量；
- 页大小与 TLB reach。

由此可以计算：

```text
预取距离 = ceil(需要隐藏的延迟 / 每个语义迭代的周期)
```

该结果仍是初始距离，向量化后应再次校正。

## 5. Vector 层

### 5.1 能够获取的语义

Vector 层可以看到：

- vector shape、元素类型和一次向量访问的字节数；
- fixed vector 或 scalable vector；
- 连续、固定 stride、gather 和 transfer 访问；
- mask、尾部 lane 和 permutation；
- 多个逻辑 load 是否落在同一物理向量流；
- 向量化、展开后每次循环实际消费的数据量。

### 5.2 能够做的预取工作

这一层最适合完善 A 类，并把 B/C 类高层候选转换为向量循环中的候选：

- 用向量步长生成 `x + D * VL`；
- 区分连续流、固定 stride 和 gather，选择不同策略；
- 按 cache line 合并同一物理流的逻辑访问；
- 根据 mask 删除无效 lane 对应的危险候选；
- 重新计算每次迭代的预取字节数和指令预算；
- 更新高层传下来的距离，使其匹配向量化后的迭代单位。

对于 scalable vector，候选距离应保留为向量迭代数，不应过早转换成固定字节距离。

### 5.3 需要的硬件信息

- SVE/SME 支持的 VL 范围以及运行时 streaming VL；
- cache line 大小；
- 连续 load、gather load 和地址生成的吞吐/延迟；
- 每周期可发射的 load、prefetch 和地址计算数量；
- 硬件预取器覆盖连续流的能力；
- 允许的软件预取指令密度。

## 6. ArmSVE 层

### 6.1 能够获取的语义

ArmSVE 层已经接近目标指令，可以获得：

- `vscale`、`svcnt*` 对应的可伸缩步长；
- `whilelo/whilelt` 等真实谓词；
- masked contiguous、strided 或 gather load；
- 最终尾部循环结构；
- SVE 目标相关地址计算形式；
- 高层候选经过向量化后的实际执行频率。

### 6.2 能够做的预取工作

- 最终确定 A 类是否需要软件预取，避免与硬件连续流预取器重复；
- 为 A/B/C 类构造基于实际 SVE 步长的未来地址；
- 用最终谓词或循环上界生成 tail-safe guard；
- 把候选距离从抽象向量迭代转换成目标相关地址增量；
- 设置 L1/L2 与 KEEP/STRM 候选属性；
- 删除向量化后成本过高或发射过密的候选。

### 6.3 需要的硬件信息

- 当前普通 SVE VL 和 SME streaming VL；
- 不同 `PRFM` hint 在目标 CPU 上的实际行为；
- 硬件预取器的流数量、stride 能力和触发距离；
- SVE load、predicate 和地址生成吞吐；
- cache line、cache 延迟和内存延迟；
- 预取跨页是否安全且是否有效。

## 7. ArmSME 层

### 7.1 能够获取的语义

ArmSME 层能够看到：

- 进入和退出 streaming mode 的区域；
- streaming VL 相关的向量和谓词操作；
- ZA tile 的初始化、使用、保存和恢复；
- MOPA 或其它 SME 计算与输入 load 之间的相对位置；
- 一次向量迭代包含多少 SME 计算；
- ZA 与普通向量寄存器的 live range。

当前 Stencil 预取只读取输入数组，不预取 ZA，但这些信息可以更准确地估算两次
输入 load 之间有多少计算时间。

### 7.2 能够做的预取工作

- 用 SME 计算量修正 `cycles_per_vector_iteration`；
- 判断预取能否与 MOPA/ZA 计算重叠；
- 避免把预取地址计算放在 ZA 状态切换或高寄存器压力位置；
- 区分普通 SVE 区域和 streaming mode 中的向量步长；
- 对 A/B/C 类候选调整最终距离和插入位置。

### 7.3 需要的硬件信息

- streaming VL；
- SME/MOPA 的吞吐和延迟；
- SME load 与 MOPA 能否并行发射；
- ZA 使用对寄存器、调度和前端带宽的影响；
- 目标 CPU 的 SME pipeline 和 load/store 单元数量。

这些参数通常不能只从通用 LLVM cost model 准确获得，需要目标调度模型、厂商资料
或 microbenchmark 校正。

## 8. LLVM Dialect、LLVM IR 与 Machine 层

### 8.1 能够获取的语义

Lowering 到这一层后，高层 Stencil 语义大多已经消失，但可以看到：

- 最终 CFG、循环、PHI 和支配关系；
- 扁平化后的 GEP、指针和 load/store；
- SCEV 地址变化和部分 trip count；
- 最终 SVE/SME intrinsic、谓词和向量步长；
- target triple、CPU feature 和数据布局；
- Machine 层的真实指令、寄存器分配和调度位置。

### 8.2 能够做的预取工作

这一层适合完成最终物化：

- 检查候选地址是否支配插入位置；
- 用最终 GEP 构造未来地址；
- 添加尾部边界 guard；
- 执行流数、指令数、在途字节和带宽预算；
- 将自定义候选 lower 为 `llvm.aarch64.prefetch`；
- 把层级和策略映射为 `PLDL1KEEP`、`PLDL1STRM`、`PLDL2KEEP`、
  `PLDL2STRM` 等 `PRFM` hint；
- 在 Machine 层检查地址计算、寄存器压力和调度冲突。

当前项目直接从这一层开始，因此需要通过 load 数、GEP、SCEV 和物理流拓扑重新
恢复 B/C 类语义。规则 Stencil 可以识别，但高层 shape、tile 和完整对象边界难以
恢复。

### 8.3 需要的硬件信息

- target triple、CPU 和 SME/SVE feature；
- cache line、L1/L2 容量、相联度和延迟；
- 内存延迟与可用带宽；
- `PRFM` hint 支持及微架构解释；
- 硬件预取器行为；
- 指令吞吐、地址生成单元和 load/store 队列容量；
- 寄存器压力与 Machine scheduler 模型；
- 页大小和 TLB 参数。

## 9. Runtime/PMU 反馈层

Runtime/PMU 不是 MLIR dialect，但静态模型无法单独确定预取是否有收益，因此必须
作为最后一层反馈。

### 9.1 能够获取的信息

- baseline/prefetch 的正确性和耗时；
- L1D、L2、LLC miss；
- backend memory stall；
- 内存带宽利用率；
- TLB miss；
- 预取指令数量和 cache pollution proxy；
- 不同尺寸、线程数和 streaming VL 下的稳定性。

### 9.2 能够做的预取工作

- 调整 A/B/C/D 各类预取的开关；
- 扫描并回写距离；
- 调整 L1/L2 和 KEEP/STRM；
- 调整最大流数、指令预算和字节预算；
- 对短循环、小问题、带宽饱和或负收益场景关闭预取；
- 为不同 CPU、VL、问题规模或线程数建立独立 Profile。

### 9.3 需要的硬件信息

- 平台 PMU 事件的准确含义；
- CPU 固定、频率控制和线程绑核方式；
- cache/NUMA 拓扑；
- 可重复的内存分配和页策略；
- 测量噪声、温度和系统负载控制方法。

## 10. 建议的跨层语义传递方式

标准 `memref.prefetch` 不能完整表达本项目需要的 cache 层级和 KEEP/STRM 策略，
因此建议使用自定义候选 op 或等价 metadata：

```text
stencil.prefetch_candidate {
  class = A | B | C | D,
  stream = current | row | plane | next_tile,
  source = input_memref,
  logical_offset = [...],
  distance_unit = vector_iteration | row | plane | tile,
  distance = ...,
  target = undecided | L1 | L2,
  policy = undecided | KEEP | STRM,
  bounds = ...
}
```

各层对同一候选逐步补充信息：

```text
Linalg/Tensor
  确定算子、输入对象和逻辑邻域
        ↓
Tiling/MemRef
  补充 tile、物理 stride、buffer 和对象边界
        ↓
SCF/Affine
  确定循环位置、复用、语义距离和 guard
        ↓
Vector/ArmSVE/ArmSME
  补充 VL、谓词、真实消费速率和向量地址
        ↓
LLVM/Machine
  结合硬件 Profile 做预算检查并生成 PRFM
        ↓
Runtime/PMU
  验证并回写距离、层级、策略和开关
```

同一候选只在最后物化一次。高层候选在 lowering 后若无法证明边界、地址或收益，
应安全删除，而不是强制生成预取。

## 11. 与当前项目的关系

当前项目输入是 SME/SVE ACLE C++，直接生成 LLVM IR，没有经过上述高层 MLIR。
因此当前 Pass 实际承担了以下工作：

```text
从 LLVM IR 恢复 Stencil 和物理流
+ 使用静态硬件 Profile 决策
+ 构造安全未来地址
+ 插入 llvm.aarch64.prefetch
```

如果未来引入 MLIR，最值得前移的是 B、C、D 类的候选识别，而不是立即删除当前
LLVM Pass：

- A 类继续在 Vector/ArmSVE 或 LLVM IR 层判断；
- B 类在 SCF/Affine 识别 row 语义，低层物化；
- C 类在 SCF/Affine 识别 plane 与 L2 预热，低层完成 L1 接力；
- D 类在 Tiling/SCF 层识别下一块，低层完成目标相关 lowering；
- 当前 LLVM Pass 演化为所有候选统一的最终合法性、预算和指令生成层。

因此推荐架构不是“只在某一个 MLIR 层插入预取”，而是：

```text
高层保留和生成语义
+ 中层确定循环位置与复用
+ 低层结合硬件信息物化
+ Runtime/PMU 校正
```
