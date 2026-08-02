# 当前 Stencil 预取方案使用的语义说明

本文对照 [SME预取语义与MLIR获取层级说明.md](SME预取语义与MLIR获取层级说明.md)，
说明当前 Stencil 软件预取方案实际使用了哪些语义、这些语义从哪里获得，以及哪些
语义仍然缺失。

需要先明确两点：

1. 语义文档主要以 GEMM、MLIR 和 SME ZA 计算为例，而本项目当前只优化 Stencil。
   因此本文按五类语义框架做对应，不使用其中 GEMM 专属的 A/B/C、K-step 等概念。
2. 当前实现不经过 MLIR，而是在 Clang 生成的 LLVM IR 上运行
   `StencilPrefetchPass`。语义来源是 LLVM 分析、IR 结构、目标 Profile 和运行实验。

## 1. 总览

| 语义类别 | 当前使用程度 | 当前方案中的对应信息 |
|---|---|---|
| 算子与数据对象语义 | 部分使用，主要靠推断 | Stencil 类型、逻辑 load 数、current/row/plane 物理流 |
| 分块、时间与复用语义 | 部分使用，部分为近似值 | 最内层循环、向量迭代、trip count、复用次数和复用距离 |
| 访问模式与合法性语义 | 核心使用 | GEP/SCEV 地址、连续流、谓词、尾部归纳变量、未来地址边界 |
| 缓存与目标硬件语义 | 核心使用，但来自静态 Profile | cache line、L1/L2 容量和延迟、VL、指令与带宽预算、KEEP/STRM |
| 运行反馈语义 | 已用于人工筛选，未自动回写 | 正确性、耗时、加速比、距离扫描、流类别消融、多线程测试 |

当前方案的语义流为：

```text
LLVM IR 中的循环、谓词、load/store 和 GEP
-> 识别 Stencil 类型和物理流
-> 结合 SCEV、trip count 与目标 Profile 生成候选
-> 计算距离、L1/L2、KEEP/STRM
-> 执行容量、流数、指令数和带宽预算检查
-> 插入 llvm.aarch64.prefetch
-> AArch64 后端生成 PRFM
-> 通过正确性和性能实验人工调整 Profile
```

## 2. 算子与数据对象语义

### 2.1 已使用的语义

当前实现通过 `StencilKind` 表示以下算子：

```text
1D3P
2D5P、2D9P
3D7P、3D13P、3D25P、3D27P
```

Pass 不依赖函数名确定算子，而是先检查最内层循环中的 masked load 数量和唯一
masked store，再结合地址拓扑验证算子。由此使用了以下高层语义的低层近似：

| 高层语义 | LLVM IR 中的实现方式 |
|---|---|
| 算子类型 | masked load 数量加物理流拓扑 |
| 输入对象 | masked load 的指针及其 SCEV/GEP 地址 |
| 输出对象 | 唯一 masked store，仅用于结构验证 |
| 连续维邻域 | 同一物理流内具有常量地址差的多个 load |
| 跨行邻域 | 相对中心流具有 row-stride 地址差的流 |
| 跨平面邻域 | 相对中心流具有 plane-stride 地址差的流 |

`StreamInfo::Loads` 保存同一物理流对应的逻辑 load。例如 `x-1`、`x`、`x+1`
虽然是多个逻辑访问，但会合并为一条 `current-row` 物理流，避免重复预取同一连续
数据前沿。

### 2.2 使用限制

LLVM IR 没有显式保留 `x/y/z`、数组 shape、Stencil 半径和邻居名称。当前方案需要
从地址差重新推断这些信息。3D 中若 `H * W` 被前端折叠为不透明 SSA 值，则使用
已知点数、精确物理流数、中心流验证和地址表达式复杂度执行拓扑回退。

因此，这部分语义属于“恢复得到的领域语义”，不如高层 Stencil dialect 或源码
metadata 直接、稳定。

## 3. 分块、时间与复用语义

### 3.1 已使用的时间语义

当前 Pass 只分析最内层 SVE/SME 向量循环，并使用：

- `LoopInfo` 查找最内层循环；
- 尾部谓词对应的 PHI 作为归纳变量；
- SCEV AddRec 验证归纳变量按固定规律变化；
- `vscale` 相关表达式识别可伸缩向量步长；
- SCEV 常量 trip count，或从 `whilelo/whilelt` 的起止值估算迭代次数；
- Profile 中的 `UsefulCycles2D/UsefulCycles3D` 估算每次向量迭代的有效周期。

距离模型实际使用：

```text
raw_distance = ceil(target_latency / useful_cycles_per_vector_iteration)
```

随后用 trip count 限制过短循环，并按 cache line 对距离取整。最终距离以“提前多少
次向量迭代”表示，而不是固定字节数，因此可以适应运行时可伸缩向量长度。

### 3.2 已使用的复用语义

当前复用模型使用两个近似量：

```text
reuse_count = 同一物理流合并后的逻辑 load 数
reuse_distance = Profile 中的代表性 row 或 plane 大小
```

若 `reuse_count > 1`，且代表性复用距离不超过目标 cache 的有效容量，则选择
`KEEP`；否则选择 `STRM`。plane 流预取到 L1 时强制使用 `STRM`，避免大平面污染
L1。

### 3.3 尚未使用的时间与复用语义

当前实现没有分析外层 `y/z` 循环的完整执行顺序，也没有显式的 tile、分块、时间
步融合或跨多个输出点的精确生命周期。因此以下语义尚未实现：

- 精确的 row/plane 跨外层迭代复用次数；
- tile 大小、tile 生命周期和下一 tile 切换时间；
- 时间阻塞或多个 time step 之间的复用；
- 由实际指令调度得到的每迭代周期；
- 动态问题规模对应的精确工作集，而不是 Profile 代表值。

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

### 4.3 合法性缺口

当前边界证明只验证未来 `x` 没有超过谓词上界，并默认代表指针所属 row/plane 本身
合法。它没有获得完整 allocation 大小，也没有证明预取地址不会跨 allocation 或
页面。因此当前方案只接受已验证的规则连续 Stencil 拓扑，并安全跳过不能证明的
循环。

当前也不支持通用 gather、运行时不规则索引、任意固定 stride、ZA tile slice 和
写预取。

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

### 5.2 尚未使用的硬件语义

当前 Profile 没有使用或没有精确建模：

- cache associativity、set 映射和 LLC；
- 精确的目标 CPU prefetch hint 成本和硬件预取器行为；
- TLB 容量、页大小和 page crossing；
- 寄存器压力、地址计算成本和后端调度窗口；
- 实际内存带宽占用，当前只有静态每迭代字节预算；
- write allocate、store prefetch 和 non-temporal store。

`TargetIRAnalysis` 当前虽已获取，但没有实际参与决策；目标能力主要由手工 Profile
表达。

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

## 7. 明确未使用的语义

由于当前对象是 Stencil 而不是 GEMM，以下语义不属于当前方案：

- GEMM 的 A/B/C 对象角色、M/N/K、transpose、alpha/beta 和 post-op；
- `blkm/blkn/blkk`、`mr/nr`、pack_A/pack_B 和 panel 生命周期；
- GEMM K-step、outer product、MOPA 数量和 `cycles_per_k_step`；
- ZA tile zero/load/store、ZA restore 和 C writeback；
- Linalg/Tensor、SCF/Affine、Vector、ArmSVE、ArmSME 方言中的语义传递；
- MLIR 自定义预取 op 或 MLIR metadata。

当前方案调用 SME/SVE intrinsic 的计算结果所对应的 LLVM IR，但预取分析本身并不
理解 MOPA 或 ZA 的数学含义。它关注的是 SME/SVE 计算循环产生的 masked load、
谓词、向量步长和内存地址流。

## 8. 结论

当前方案已经使用了生成正确读预取所需的最低语义集合：

```text
Stencil 类型和物理流
+ 最内层循环与向量消费时间
+ SVE 谓词和尾部边界
+ GEP/SCEV 地址关系
+ cache/延迟/容量 Profile
+ 近似复用和预取预算
```

这些语义足以让当前实现支持的七种 Stencil 形状从 LLVM IR 生成受保护的
`llvm.aarch64.prefetch` 和最终 `PRFM`。主要不足不是缺少 MLIR 本身，而是高层
shape、外层循环复用、对象边界和真实硬件反馈只被近似或尚未获得。若继续提高决策
精度，优先级应是：补充源码或早期 IR metadata、分析外层循环与动态规模、接入 PMU
反馈；不需要同时再插入一套高层预取。
