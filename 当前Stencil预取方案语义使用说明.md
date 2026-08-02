# 当前 Stencil 预取方案使用的语义说明

## 1. 总览

| 语义类别             | 主要内容                                                     | 作用                                             | 主要获取层级               |
| -------------------- | ------------------------------------------------------------ | ------------------------------------------------ | -------------------------- |
| 算子与数据对象语义   | GEMM、A/B/C、alpha/beta、post-op、ZA 初值/写回对象           | 判断预取对象、C 是否读预取、ZA/C 写回策略        | Linalg/Tensor/ArmSME       |
| 分块、时间与复用语义 | blkm/blkn/blkk、K step、K-step body 中的 MOPA/MLA、复用次数、packed buffer 生命周期 | 决定预取距离、L1/L2 分层、KEEP/STRM 和对象优先级 | SCF/Affine/ArmSME          |
| 访问模式与合法性语义 | 连续、strided、gather、tile slice、writeback、predicate、tail、对象边界 | 选择预取形式并删除不安全预取                     | Vector/ArmSVE/ArmSME/SCF   |
| 缓存与目标硬件语义   | cache line、L1/L2 容量与相联度、latency、prfm/pst、write allocate | 决定 target、policy、发射频率和污染控制          | Target config/LLVM/Machine |
| 运行反馈语义         | L1/L2 miss、带宽、stall、TLB miss、cache pollution proxy     | 调整距离、层级、KEEP/STRM 或关闭负收益预取       | Runtime/PMU                |

## 2. 算子与数据对象语义

### 2.1 已使用的语义

Pass 不依赖函数名确定算子，而是先检查最内层循环中的 masked load 数量和唯一masked store，再结合地址拓扑验证算子。由此使用了以下高层语义的低层近似：

| 高层语义 | LLVM IR 中的实现方式 |
|---|---|
| 算子类型 | masked load 数量加物理流拓扑 |
| 输入对象 | masked load 的指针及其 SCEV/GEP 地址（用于根据数组下标计算内存地址） |
| 输出对象 | 唯一 masked store，仅用于结构验证 |
| 连续维邻域 | 同一物理流内具有常量地址差的多个 load |
| 跨行邻域 | 相对中心流具有 row-stride 地址差的流 |
| 跨平面邻域 | 相对中心流具有 plane-stride 地址差的流 |

### 2.2 使用限制

LLVM IR 没有显式保留 `x/y/z`、数组 shape、Stencil 半径和邻居名称。当前方案需要
从地址差重新推断这些信息。3D 中若 `H * W` 被前端折叠为不透明 SSA 值，则使用
已知点数、精确物理流数、中心流验证和地址表达式复杂度执行拓扑回退。

因此，这部分语义属于“恢复得到的领域语义”，不如高层 Stencil dialect 或源码
metadata 直接、稳定。

## 3. 分块、时间与复用语义

### 3.1 如何用循环时间计算预取距离

这部分要解决的问题是：**数据从目标 cache 层级到达处理器需要若干周期，那么软件
预取应该比真正的 load 提前多少次循环迭代发出？**

当前方案把最内层 `x` 向量循环的一次执行称为“一次向量迭代”。例如：

```text
当前迭代读取 input[..., x]
下一迭代读取 input[..., x + VL]
再下一迭代读取 input[..., x + 2 * VL]
```

其中 `VL` 是运行时的 SVE/SME 向量长度对应的元素步长。预取距离 `D = 4` 表示：

```text
计算 x 位置时，预取 x + 4 * VL 位置的数据
```

#### 第一步：确认一次迭代如何前进

Pass 使用 LLVM 分析恢复以下信息：

| LLVM 信息 | 在本方案中的直观含义 |
|---|---|
| `LoopInfo` | 找到真正执行向量 load/store 的最内层循环 |
| PHI 归纳变量 | 当前的 `x` 位置 |
| SCEV AddRec | 证明 `x` 每轮都按固定规律增长 |
| `vscale` 相关步长 | 证明每轮增长量来自可伸缩向量长度，而不是普通标量步长 |
| `whilelo/whilelt` | 给出当前 `x` 和循环上界，并处理最后不足一个向量的尾部 |

这些检查通过后，Pass 才能把未来地址可靠地写成：

```text
future_x = current_x + D * vector_step
```

这里的 `vector_step` 直接取自 LLVM IR，因此地址会随机器运行时的 VL 变化。

#### 第二步：把 cache 延迟换算成迭代数

Profile 提供两个模型输入：

| 输入 | 含义 |
|---|---|
| `target_latency` | 从目标层级取回数据预计需要的周期数，例如 L1 预取延迟为 32 cycle |
| `useful_cycles_per_iteration` | 当前 Stencil 完成一次向量迭代预计消耗的周期数 |

假设一次迭代可提供 8 cycle 的计算时间，而数据需要提前 32 cycle 请求，则需要提前
四次迭代：

```text
raw_distance
  = ceil(target_latency / useful_cycles_per_iteration)
  = ceil(32 / 8)
  = 4 次向量迭代
```

当前默认 Profile 对 2D 使用 8 cycle/iteration，对 3D 使用
10 cycle/iteration。例如 3D 的 L2 延迟按 96 cycle 估算时：

```text
raw_distance = ceil(96 / 10) = 10 次向量迭代
```

这里的 8、10、32 和 96 都是 Profile 参数，不是 LLVM IR 能直接证明的硬件事实，
后续需要通过服务器性能实验校正。

#### 第三步：避免距离不适合当前循环

得到 `raw_distance` 后还要做三项修正：

1. **短循环过滤**：先用 SCEV 获取 trip count，也就是最内层循环总共执行多少次
   向量迭代。若循环长度不超过 `2 * raw_distance`，预取还没有足够时间发挥作用，
   当前方案关闭该候选；若无法静态得到 trip count，则使用 Profile 的最大距离约束。
2. **距离上下限**：L1 距离至少为 1，L2 距离至少为 2；最大距离不能超过 Profile
   的限制，已知 trip count 时还不能超过循环长度的一半。
3. **cache-line 修正**：根据 cache line 大小和 Profile 假定的 VL，把距离取整为
   “覆盖一条 cache line 所需迭代数”的整数倍，使提前量按 cache-line 粒度表达。
   当前实现没有降低预取发射频率，因此这一步不等同于完整的 cache-line 去重。

最终保存的是“提前 `D` 次向量迭代”，而不是“提前固定多少字节”。插入时再用真实
`vector_step` 构造 `x + D * vector_step`，因此最终预取地址仍能适应可伸缩向量
长度。需要注意，距离是否真正足够隐藏延迟仍取决于 Profile 中的周期估计和目标
机器的实际执行情况。

### 3.2 已使用的复用语义

当前复用模型使用两个近似量：

```text
reuse_count = 同一物理流合并后的逻辑 load 数
reuse_distance = Profile 中的代表性 row 或 plane 大小
```

若 `reuse_count > 1`，且代表性复用距离不超过目标 cache 的有效容量，则选择
`KEEP`；否则选择 `STRM`。plane 流预取到 L1 时强制使用 `STRM`，避免大平面污染
L1。

## 4. 访问模式与合法性语义

这是当前方案使用最完整的一类语义。

### 4.1 访问模式

Pass 要求候选循环具有相同 SVE 谓词控制的 masked load 和 masked store，并通过
SCEV 与 GEP 分析地址。已识别的访问类别包括：

| 当前类别 | 含义 |
|---|---|
| `current-row` | 沿最内层 `x` 方向连续推进的当前行 |
| `row-neighbor` | 与中心流相差一个或多个 row stride |
| `plane-neighbor` | 与中心流相差一个或多个 plane stride |

同一行中具有常量地址差的逻辑 load 被做物理流去重。中心流还必须同时证明存在
负、零、正的 `x` 邻域偏移，从而避免仅凭 load 数量猜测。

### 4.2 谓词与尾部合法性

当前实现要求：

1. 所有 masked load 和 masked store 使用同一谓词；
2. 谓词来自 AArch64 SVE `whilelo` 或 `whilelt`；
3. 能从谓词起始值回溯到循环归纳变量；
4. 归纳步长是可伸缩向量步长；
5. 插入时计算 `future_x = x + distance * vector_step`；
6. 仅在 `future_x < upper_bound` 时执行预取。

这样使用了主循环范围、尾循环范围、predicate 和未来地址合法性语义。插入位置还
通过 `DominatorTree` 检查代表地址是否支配预取锚点，避免在地址操作数尚不可用时
插入。

## 5. 缓存与目标硬件语义

### 5.1 已使用的 Profile 参数

`TargetPrefetchProfile` 当前提供：

```text
cache line 大小
L1/L2 容量和可使用比例
L1/L2/内存预取延迟
假定的 streaming VL
代表性 row 和 plane/tile 大小
2D/3D 每次向量迭代的有效周期
最大预取距离
最大预取流数
每迭代最大预取指令数
每迭代最大预取字节数
current/row/plane-L1/plane-L2 开关
```

这些参数参与以下决策：

- 用延迟和有效周期计算预取距离；
- 用 cache line 和 VL 计算预取粒度、指令数及字节数；
- 用 L1/L2 有效容量检查在途预取数据；
- 用 row/plane 代表尺寸估算复用距离；
- 按流数、指令数和字节数限制预取压力；
- 对 row、plane near 和 plane far 候选设置优先级；
- 选择 L1 或 L2 以及 `KEEP/STRM`。

启用的决策被编码为 `llvm.aarch64.prefetch`，后端映射为类似
`PLDL1KEEP`、`PLDL1STRM`、`PLDL2KEEP` 或 `PLDL2STRM` 的 `PRFM` 读预取。

## 6. 运行反馈语义

当前运行验证已经使用：

- baseline 与 prefetch 数值正确性比较；
- 每个算子和规模的耗时、中位数及加速比；
- row、plane-L1、plane-L2 流类别消融；
- 2D row-L1 和 3D plane-L1 的距离扫描；
- 跨问题规模复测；
- 多线程带宽压力测试。

这些实验可以判断静态策略是否负收益，并用于人工选择距离、层级、策略和启用流。
但是运行结果不会被 Pass 自动读取，也不会自动修改决策。当前所谓“Profile 回写”
是根据报告手工更新 `TargetPrefetchProfile` 或环境变量后重新生成 IR。

语义文档中列出的 L1/L2/LLC miss、backend stall、TLB miss、实际内存带宽和 cache
pollution proxy 尚未接入自动流程；PMU 仍是后续归因手段。



## 8. 四类预取适合在哪一层发出

### 8.1 判断标准：决策层和指令发出层应分开

“在哪一层发出”实际包含两个不同问题：

1. **在哪一层发现并决定预取候选**：需要知道预取哪个对象、属于哪条流、何时会被
   使用以及是否复用。
2. **在哪一层物化最终预取**：需要知道向量化后的真实步长、谓词、最终地址、目标
   hint 和接近汇编的插入位置。

高层 MLIR 更擅长第一个问题，LLVM IR 更擅长第二个问题。只要最终生成的 `PRFM`
动态执行次数、地址、提前时间、cache 层级和 KEEP/STRM 完全相同，从高层还是
LLVM IR 发起不会产生硬件效果差异。高层可能带来的收益是**提高决策准确性**，而
不是产生一种更强的预取指令。

四类预取的推荐层级如下：

| 预取类别 | 最适合发现和决策的层级 | 最适合物化的层级 | 高层相对当前 LLVM IR 的潜在优势 |
|---|---|---|---|
| A. 连续维前向预取 | Vector/ArmSVE | 向量化后的 ArmSVE 或 LLVM IR | 很小；低层更清楚 VL、谓词和最终地址，且硬件预取器常已覆盖 |
| B. 跨行邻域预取 | SCF/Affine 加 Vector/ArmSVE | Vector/ArmSVE lowering 后或 LLVM IR | 中等；高层能直接获得行宽、行边界和邻域偏移，减少拓扑推断错误 |
| C. 跨平面邻域预取 | SCF/Affine | L2 候选可在外层保留，L1 接力在 Vector/LLVM IR 物化 | 较大；高层能明确获得 `H * W`、平面生命周期和 `z` 方向复用 |
| D. 下一空间块预取 | SCF/Affine | 保留为自定义 op，完成布局和向量化后再 lower | 最大；块边界、下一 tile 和切换时间在当前最内层 LLVM Pass 中基本不可见 |



### 8.2 A 类：连续维前向预取

A 类地址随最内层 `x` 迭代连续增长。高层 Linalg/SCF 可以知道访问连续，但通常还
不知道最终使用固定向量还是可伸缩向量、一次迭代推进多少元素、尾部谓词是什么，
也不知道后端是否展开循环。

因此 A 类不适合过早物化。Vector/ArmSVE 或当前 LLVM IR 层能看到真实 `vscale`
步长、masked load 和 `whilelo/whilelt`，更容易做到 cache-line 去重和尾部保护。
此外，连续流最可能由硬件预取器覆盖；高层插入并不能解决重复预取问题，反而可能
在向量化或展开后产生过多预取。

结论：**A 类维持当前低层决策和插入更合适，高层通常不会带来更好效果。**高层最多
提供“该连续流是否值得软件预取”的标注。

### 8.3 B 类：跨行邻域预取

B 类需要理解 `input[y +/- r][x]` 中的行宽、半径和行边界。在 SCF/Affine 层，
循环 `x/y`、memref shape/stride 和 affine 下标仍然明确，可以直接确认 north、
south 及更远半径行，不必从复杂 GEP 和 SCEV 中恢复。

不过最终提前距离仍依赖向量化后的 VL 和每次向量迭代成本，安全插入也需要最终
predicate。因此更好的实现不是在 SCF/Affine 中直接固定一个低层地址，而是生成
row-stream 预取候选或自定义 op，经过向量化后在 ArmSVE/LLVM IR 层物化。

结论：**B 类在高层做流识别和复用决策可能优于当前方案，但最终发出仍适合放在
低层。**当前 LLVM IR 实现已经能稳定恢复规则行流时，高层方案未必产生明显性能
差异；它主要提高识别覆盖率和参数准确性。

### 8.4 C 类：跨平面邻域预取

C 类依赖 `input[z +/- r][y][x]` 的平面跨度 `H * W`。当前 LLVM IR 中 `H * W`
可能成为不透明 SSA 值，因此需要按物理流数量和表达式复杂度做拓扑回退。高层
SCF/Affine 能保留 `z/y/x`、shape、plane stride 和外层循环顺序，也更容易计算一个
平面在 L1/L2 中的生命周期。

C 类还包含两个时间尺度：

- 远距离 plane warming 主要面向 L2，候选位置与外层 `z/y` 进度有关；
- 临近消费时的 L1 接力与最内层向量迭代、VL 和谓词有关。

因此可在高层决定未来平面及 L2 预热时机，再在 Vector/LLVM IR 层决定 L1 距离和
最终 `PRFM`。这比把两种预取都仅作为最内层流处理更有机会减少过早预取和 cache
污染。

结论：**C 类最值得引入高层语义，预取决策质量可能明显优于纯 LLVM IR 推断；但
性能提升仍需由最终距离、层级和服务器 PMU 验证。**

### 8.5 D 类：下一空间块预取

D 类的关键语义是当前 tile/行段/平面何时结束、下一块从哪里开始、下一块工作集
多大，以及切换前还有多少计算时间。这些信息在 tiling 后的 SCF/Affine 层最清楚，
但在当前只看最内层向量循环的 LLVM Pass 中基本已经丢失。

如果只在 LLVM IR 中寻找下一块，必须重新识别外层循环和经过优化的边界控制流，
成本高且容易把尾块或不同 allocation 误认为规则下一块。因此 D 类应在 Tiling 或
SCF/Affine 层生成块级候选，并携带 tile 标识、未来块索引、边界和 cache 目标，之后
再 lower 为低层预取。

结论：**D 类由高层生成候选明显优于当前 LLVM IR 方案，也是实现该类预取的推荐
路径。**

### 8.6 为什么不建议直接在高层固定发出

直接在 Linalg/SCF 层插入普通预取并不保证更快，主要风险包括：

- tiling、循环交换、融合、展开后，原插入点与真实消费点的距离发生变化；
- 向量化后一个高层迭代对应的元素数改变，固定距离可能过早或过晚；
- 展开或复制循环体可能复制预取，增加指令和带宽压力；
- 高层不知道最终 SVE 谓词和可伸缩 VL，尾部保护可能过于保守或不正确；
- 高层缺少最终目标的 cache hint、地址计算成本和后端调度信息；
- 标准 `memref.prefetch` 无法完整表达本项目需要的层级和 KEEP/STRM 策略。

推荐使用自定义语义载体，而不是高层立即固定成硬件预取。例如：

```text
stencil.prefetch_candidate {
  stream = row | plane | next_tile,
  logical_offset = ...,
  unit = vector_iteration | row | plane | tile,
  target = L1 | L2,
  policy = KEEP | STRM,
  bounds = ...
}
```

该 op 或等价 metadata 在高层记录不会被 LLVM IR 可靠恢复的信息；经过 tiling、
bufferization 和向量化后，再把有效候选 lower 到 `llvm.aarch64.prefetch`。此时用
最终 VL、谓词、GEP 和 Profile 重新计算距离并做预算检查。

