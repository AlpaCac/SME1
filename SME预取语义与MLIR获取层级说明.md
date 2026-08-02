# SME 软件预取所需语义与 MLIR 获取层级说明

本文档总结 SME/SVE 软件预取方案中需要使用的语义信息，并说明这些语义可以在 MLIR 的哪些层级获取。

1. **算子与数据对象语义**：回答“预取对象是什么、为什么会被访问”。
2. **分块、时间与复用语义**：回答“什么时候访问、访问几次、提前多远合适”。
3. **访问模式与合法性语义**：回答“地址如何变化、哪些地址可以安全预取”。
4. **缓存与目标硬件语义**：回答“预取到哪一级、用什么 hint、会不会污染 cache”。
5. **运行反馈语义**：回答“静态策略是否有效、是否需要调参或关闭”。

## 1. 语义总览

| 语义类别 | 主要内容 | 作用 | 主要获取层级 |
|---|---|---|---|
| 算子与数据对象语义 | GEMM、A/B/C、alpha/beta、post-op、ZA 初值/写回对象 | 判断预取对象、C 是否读预取、ZA/C 写回策略 | Linalg/Tensor/ArmSME |
| 分块、时间与复用语义 | blkm/blkn/blkk、K step、K-step body 中的 MOPA/MLA、复用次数、packed buffer 生命周期 | 决定预取距离、L1/L2 分层、KEEP/STRM 和对象优先级 | SCF/Affine/ArmSME |
| 访问模式与合法性语义 | 连续、strided、gather、tile slice、writeback、predicate、tail、对象边界 | 选择预取形式并删除不安全预取 | Vector/ArmSVE/ArmSME/SCF |
| 缓存与目标硬件语义 | cache line、L1/L2 容量与相联度、latency、prfm/pst、write allocate | 决定 target、policy、发射频率和污染控制 | Target config/LLVM/Machine |
| 运行反馈语义 | L1/L2 miss、带宽、stall、TLB miss、cache pollution proxy | 调整距离、层级、KEEP/STRM 或关闭负收益预取 | Runtime/PMU |

## 2. 算子与数据对象语义

### 2.1 含义

算子与数据对象语义说明当前计算是什么，以及哪些数据对象会被 SME/SVE 消费或写回。

这一类语义的核心问题是：

```text
当前是不是 GEMM/Matmul？
A/B/C 分别是什么角色？
是否需要读旧 C？
ZA 是清零、恢复，还是由旧 C 初始化？
C 写回后是否还会被使用？
```

### 2.2 需要的信息与逐项解释

```text
op kind: GEMM / matmul / batch matmul / linalg.generic
A/B/C 对象身份
M/N/K 维度
layout: row-major / column-major
transpose A/B
alpha / beta
是否有 bias、activation、scale 等 post-op
ZA tile 是否清零
ZA tile 是否从 backing memory restore
ZA tile 是否读旧 C 初始化
ZA tile store 的目标 C tile
C 写回后是否 soon reused
```

- `op kind`：表示当前算子类型。若是 GEMM/matmul，可直接套用 A/B/C tile 复用模型；若是 `linalg.generic`，需要进一步分析 indexing map 和 iterator type，判断它是否等价于矩阵乘、归约或逐元素计算。
- `A/B/C 对象身份`：区分输入矩阵 A、输入矩阵 B 和输出矩阵 C。A/B 通常是 SME MOPA 的主要读预取对象，C 则涉及旧值读取、ZA 初始化和结果写回。
- `M/N/K 维度`：决定矩阵规模、循环边界、K step 数量和 tile 数量。K 维影响 A/B 操作数的消费时间，M/N 维影响 A/B panel 的复用范围。
- `layout`：说明矩阵在内存中按行主序还是列主序存放。它决定访问是连续、跨步还是需要 packing 转换，也决定预取地址如何计算。
- `transpose A/B`：说明 A 或 B 是否转置参与计算。转置会改变 K 维和 M/N 维在内存中的步长关系，影响 A/B 哪一方连续、哪一方跨步。
- `alpha / beta`：`alpha` 影响是否需要对乘积结果做缩放；`beta` 决定是否需要读取旧 C。若 `beta != 0`，C tile 在写回前需要读旧值，应考虑 C 读预取。
- `post-op`：表示 GEMM 后是否融合 bias、activation、scale 等后处理。若 C 写回后马上被后处理读取或修改，C 更适合 `KEEP`；若结果只写一次且短期不复用，则可考虑 `STRM` 或 non-temporal store。
- `ZA tile 是否清零`：若 ZA 在计算前直接清零，说明不需要从内存读取初始累加状态，因此不需要 ZA restore 或旧 C 读预取。
- `ZA tile 是否从 backing memory restore`：若 ZA 状态需要从 backing memory 恢复，则需要按未来 tile/tile slice 对 backing memory 做读预取。
- `ZA tile 是否读旧 C 初始化`：若 `beta != 0` 或需要累加到旧 C，ZA 初值来自 C tile，应对旧 C tile 考虑读预取。
- `ZA tile store 的目标 C tile`：说明 ZA 结果最终写到哪个 C tile。它决定 C 写回地址序列，以及是否需要写预取或 non-temporal store。
- `C 写回后是否 soon reused`：若 C 很快被后续算子读取或参与 post-op，写回数据应倾向保留在 cache 中。

### 2.3 可获取层级

主要获取层级：

```text
Linalg/Tensor 层
ArmSME 层
LLVM/Machine 层
```

典型来源：

```mlir
linalg.matmul
linalg.batch_matmul
linalg.generic
tensor.extract_slice
tensor.insert_slice
arm_sme.tile_zero
arm_sme.tile_load
arm_sme.tile_store
```

示例标注：

```mlir
linalg.matmul ins(%A, %B : tensor<...>, tensor<...>)
              outs(%C : tensor<...>)
  {prefetch.semantic = "sme_gemm",
   prefetch.roles = ["A", "B", "C"],
   prefetch.beta_nonzero = true}
```

## 3. 分块、时间与复用语义

### 3.1 含义

分块、时间与复用语义说明数据如何被 tile 化、何时被消费、会被消费几次。

核心问题是：

```text
A/B/C 被分成多大的 tile？
未来第几个 K step 会消费 A/B？
A/B panel 是否跨多个 output tile 复用？
一个 packed buffer 生命周期有多长？
当前是不是 edge case？
```

### 3.2 需要的信息与逐项解释

```text
blkm, blkn, blkk
mr, nr 或 mr1, mr2, nr
loop order: jc / pc / ic / k
panel/tile 生命周期
pack_A / pack_B 是否启用
K step
outer-product step
每个 microkernel K-step body 的 MOPA 指令数
cycles_per_k_step
是否 edge case
reuse_count_A / reuse_count_B / reuse_count_C
reuse_distance_A / reuse_distance_B
是否跨多个 output tile 复用
```

- `blkm, blkn, blkk`：MacroKernel 的 M/N/K 方向分块大小。它们决定 A/B/C 工作集大小、L2 是否能容纳 panel，以及 L2 预取应以多大的 panel/tile 为单位发射。
- `mr, nr 或 mr1, mr2, nr`：MicroKernel 的寄存器块大小。KirbyMM 中 `mr1` 对应 SME MOPA 部分，`mr2` 对应 SVE MLA 补充部分，`nr` 对应 N 方向展开；这些参数决定每个 K step 消费多少 A/B 数据。
- `loop order`：说明 `jc/pc/ic/k` 等循环的嵌套顺序。loop order 决定 A/B panel 哪一方复用更强，也决定 L2 预取应该放在哪一层循环。
- `panel/tile 生命周期`：表示一个 panel/tile 从生成、被消费到失效的范围。生命周期越长、复用越多，越适合 `KEEP`；生命周期很短且只顺序消费，可能更适合 `STRM`。
- `pack_A / pack_B 是否启用`：说明是否将原始矩阵重排到 packed buffer。启用 packing 后，后续 microkernel 访问通常更连续，预取可从复杂跨步/gather 转为普通连续流。
- `K step`：GEMM 沿 K 维推进的基本消费单位。SME MOPA 每个 K step 会消费对应的 A/B 向量，因此 L1 预取距离应优先用 K step 表示。
- `outer-product step`：一次外积计算的语义单位，通常对应 A/B 向量装入后执行 MOPA 并累加到 ZA。它比字节距离更贴近 SME 的真实消费节奏。
- `每个 microkernel K-step body 的 MOPA 指令数`：表示 microkernel 在一个 K 维推进位置或展开后的 K-step body 中，为更新当前 ZA tile block 需要执行多少条 MOPA。若只更新一个 ZA tile，可能是一条 MOPA；若更新 `2 x 2` ZA tile block，则可能是一组 MOPA。它用于估算 `cycles_per_k_step`，而不是表示数学意义上的 K 维一步一定包含多条 MOPA。
- `cycles_per_k_step`：每个 K step 的周期数，是把内存延迟换算成预取距离的关键量。可由模型估算，也可由 microbenchmark/PMU 校正。
- `是否 edge case`：表示当前 tile 是否为小矩阵或边界块。edge case 常常 cache-resident 且更受调度影响，预取应更保守。
- `reuse_count_A / reuse_count_B / reuse_count_C`：表示 A/B/C 数据在被加载或预取后会被多少个计算块使用。复用次数越高，越适合 `KEEP`，预取优先级也越高。
- `reuse_distance_A / reuse_distance_B`：表示 A/B 两次使用之间相隔的循环迭代、K step 或 tile 数。距离短适合 L1，距离长但仍会复用则适合 L2。
- `是否跨多个 output tile 复用`：说明某个 A/B panel 是否服务多个 C output tile。跨 tile 复用意味着预取收益更高，也意味着 cache pollution 风险更需要控制。

### 3.3 对预取决策的作用

这一类语义用于：

1. 推导 L1 K-step 预取距离：

```text
D_A_L1 ~= L1_miss_hidden_latency / cycles_per_k_step
D_B_L1 ~= L1_miss_hidden_latency / cycles_per_k_step
```

2. 推导 L2 panel/tile 预取距离：

```text
D_panel ~= L2_or_memory_latency / cycles_per_panel
```

3. 判断 `KEEP/STRM`：

```text
high reuse      -> KEEP
one-pass stream -> STRM
```

4. 判断 edge case 是否关闭或降低预取激进度。

### 3.4 可获取层级

主要获取层级：

```text
SCF/Affine 层
ArmSME/ArmSVE 层
MicroKernel 模板或手写 kernel 描述
Runtime/PMU 校正
```

典型来源：

```mlir
scf.for
affine.for
affine.apply
memref.subview
memref.alloc for packed buffers
arm_sme.mopa
arm_sme.tile_load
arm_sme.tile_store
vector.contract lowered to SME
```

## 4. 访问模式与合法性语义

### 4.1 含义

访问模式与合法性语义说明地址如何变化，以及哪些未来地址可以安全预取。

核心问题是：

```text
访问是连续、跨步、gather，还是 tile slice？
未来地址是否在对象边界内？
tail/predicate 下哪些 lane 有效？
是否可能跨 allocation 或 page？
```

### 4.2 需要的信息与逐项解释

```text
CONTIG: 连续访问
STRIDED: 固定步长访问
GATHER: 索引/离散访问
TILE_SLICE: tile 切片访问
WRITEBACK: 写回访问
主循环范围
尾循环范围
predicate mask
对象边界
memref shape/stride
是否可能跨 allocation 或 page
```

- `CONTIG`：连续访问，地址按元素大小顺序递增。最适合普通地址预取，并应按 cache line 去重，避免相邻 vector iteration 重复预取同一行。
- `STRIDED`：固定步长访问，地址按固定 stride 递增。可静态计算未来地址，但需要判断 stride 是否导致 cache line 利用率低或冲突 miss。
- `GATHER`：索引或离散访问。未来数据地址依赖未来索引值，因此通常需要先预取索引流，再在索引可用后执行 gather data 预取。
- `TILE_SLICE`：按 ZA tile 的行/列片段访问。一个 tile slice 往往跨多条 cache line，需要展开成多个 cache line 级预取并去重。
- `WRITEBACK`：写回访问，典型是 ZA tile store 到 C。是否写预取取决于 write allocate、C 是否 soon reused 和目标平台是否支持有效 store prefetch。
- `主循环范围`：表示没有尾部、不越界、尺寸规整的循环区间。该范围内未来地址通常可证明合法，适合积极插入预取。
- `尾循环范围`：表示处理剩余元素或边界 tile 的循环区间。这里可能存在部分 lane 无效，预取必须保守。
- `predicate mask`：表示 SVE/SME 操作中哪些 lane 有效。只有被 predicate 证明有效的地址才适合预取，尤其是 gather 或 tail 访问。
- `对象边界`：表示 A/B/C 或 packed buffer 的合法地址范围。预取不应越过可证明的对象边界。
- `memref shape/stride`：说明 memref 的维度和步长，可用于证明某个未来地址是否仍在对象范围内，并计算实际物理访问跨度。
- `是否可能跨 allocation 或 page`：若未来地址可能跨越 allocation/page 且无法证明安全，应删除预取或限制在主循环中。

### 4.3 对预取决策的作用

这一类语义用于：

1. 选择普通地址预取、gather 预取、tile-slice 预取或写预取。
2. 对 cache line 去重，避免重复预取。
3. 对 tail 和 predicate 区域做安全性过滤。
4. 删除无法证明对象边界安全的预取。

### 4.4 可获取层级

主要获取层级：

```text
SCF/Affine 层
Vector 层
ArmSVE 层
ArmSME 层
MemRef/Tensor type 信息
```

典型来源：

```mlir
vector.load
vector.transfer_read
vector.gather
vector.mask
arm_sme.tile_load
arm_sme.tile_store
memref.subview
affine.apply
```

## 5. 缓存与目标硬件语义

### 5.1 含义

缓存与目标硬件语义说明目标平台的 cache 层级、预取 hint 能力和写策略。

核心问题是：

```text
预取到 L1 还是 L2？
使用 KEEP 还是 STRM？
是否支持 store prefetch？
是否存在 write allocate 开销？
预取是否会污染 packed A/B？
```

### 5.2 需要的信息与逐项解释

```text
cache line size
L1/L2/LLC size
L1/L2 associativity
L1/L2 latency
memory latency
当前 tile 工作集大小
packed A/B 是否应驻留 cache
是否 write allocate
是否支持 store prefetch
是否适合 non-temporal store
ARM prfm/pst hint 支持
寄存器压力和调度窗口
```

- `cache line size`：决定预取粒度和去重粒度。多个元素或 vector load 可能落在同一 cache line 上，只需预取一次。
- `L1/L2/LLC size`：决定某个 tile/panel 能否驻留在对应 cache 层级。工作集超过 L1 时，L1 预取可能造成污染，应改为 L2 或降低激进度。
- `L1/L2 associativity`：影响 cache set 冲突风险。即使容量足够，低 associativity 也可能导致 packed A/B 被 C 或其他流挤出。
- `L1/L2 latency`：用于估算从各级 cache 命中的访问成本，也用于选择预取目标层级。
- `memory latency`：表示从内存取数的长延迟，是计算预取距离的基础。
- `当前 tile 工作集大小`：包括 A/B/C tile、packed buffer 和临时数据。它决定是否应该启用 L2 预热、是否抑制低复用预取。
- `packed A/B 是否应驻留 cache`：若 packed A/B 后续高复用，应保护其 cache residency，避免 C 写回预取或低优先级预取造成污染。
- `是否 write allocate`：若写 miss 会先把 cache line 读入再写，写回大矩阵可能产生额外流量；此时可以评估写预取或 non-temporal store。
- `是否支持 store prefetch`：不同 ARM 微架构对 store prefetch hint 的支持和效果不同，应作为目标相关能力，而不是默认启用。
- `是否适合 non-temporal store`：若 C 只写一次且短期不再读，non-temporal store 可能比写预取更合适，因为它减少 cache 污染。
- `ARM prfm/pst hint 支持`：决定抽象预取最终能 lower 成哪类指令，例如 `pldl1keep`、`pldl2keep`、`pldl1strm`、`pstl1keep`。
- `寄存器压力和调度窗口`：预取需要地址计算，可能增加寄存器压力；在 SME/SVE overlap 的窗口中插入预取还可能破坏调度。

### 5.3 对预取决策的作用

这一类语义用于：

1. 选择 L1、L2 或 streaming 预取。
2. 选择 `KEEP`、`STRM`、store prefetch 或 non-temporal store。
3. 控制 issue period，避免预取指令过密。
4. 抑制会污染 packed A/B 的低优先级预取。
5. lower 到具体 ARM hint。

### 5.4 可获取层级

主要获取层级：

```text
Target configuration
LLVM/Machine 层
Runtime/PMU
```

典型来源：

```text
目标 CPU 配置表
LLVM target lowering
ARM subtarget feature
perf/PMU profile
```

## 6. 运行反馈语义

### 6.1 含义

运行反馈语义用于校正静态模型。静态语义可以生成初始预取策略，但预取收益高度依赖目标微架构、数据规模和实际 cache 状态，因此需要 PMU 或 autotuning 反馈。

### 6.2 需要的信息与逐项解释

```text
L1D miss rate
L2 miss rate
LLC miss rate
memory bandwidth utilization
backend memory stall
TLB miss
prefetch 指令数量
cache pollution proxy
```

- `L1D miss rate`：反映 L1 数据命中情况。若 L1 miss 高且 backend memory stall 明显，可增加 L1 K-step 预取或调整距离。
- `L2 miss rate`：反映 L2 是否有效承接 L1 miss。若 L2 miss 高，可增强 L2 panel 预热；若 L2 命中高但 L1 miss 高，可加强 L1 接力预取。
- `LLC miss rate`：反映是否频繁访问内存。LLC miss 高说明更需要远距离预热，但也要注意带宽压力。
- `memory bandwidth utilization`：带宽利用率接近上限时，继续增加预取可能抢占 demand load，需降低激进度或转向更精准的预取。
- `backend memory stall`：表示流水线因内存等待停顿的程度。若该指标高，预取更可能有收益。
- `TLB miss`：预取无法解决地址翻译瓶颈，TLB miss 高时应考虑大页、packing 或降低离散访问预取。
- `prefetch 指令数量`：反映预取本身的指令开销。数量过高可能影响 issue/rename/前端带宽。
- `cache pollution proxy`：可用 L1/L2 miss 增加、替换事件或性能下降间接衡量。若预取导致污染，应改用 STRM、降低层级或关闭低优先级预取。

### 6.3 对预取决策的作用

运行反馈用于：

1. 调整 `D_A_L1`、`D_B_L1`。
2. 调整 L2 panel 预取距离。
3. 判断 KEEP/STRM。
4. 关闭 edge case 中负收益预取。
5. 判断 C write prefetch 是否有效。

### 6.4 可获取层级

主要获取层级：

```text
Runtime
PMU/perf
Autotuner/profile-guided optimization
```

## 7. 按 MLIR 层级组织的语义获取表

| MLIR 层级 | 可获取语义 | 用于哪些预取决策 |
|---|---|---|
| Linalg/Tensor | GEMM、A/B/C、M/N/K、layout、alpha/beta、post-op | 对象识别、C 读预取、C 写回策略 |
| SCF/Affine | loop order、blkm/blkn/blkk、tile/panel 生命周期、主循环/尾循环、复用关系 | L2 panel 预取、复用分析、安全性判断 |
| Vector | vector load/gather/reduction、VL、predicate、tail | SVE 连续预取、gather 两阶段预取、tail-safe 判断 |
| ArmSVE | SVE load/gather/prefetch、predicate、vector iteration | SVE 低层地址预取、KEEP/STRM hint |
| ArmSME | MOPA、K step、ZA tile load/store、tile slice | L1 K-step 预取、ZA restore、ZA writeback |
| LLVM/Machine | ARM `prfm/pst` hint、寄存器压力、调度、目标 CPU 特性 | lower 到具体指令、删除不合适预取 |
| Runtime/PMU | miss、bandwidth、stall、TLB、cache pollution | profile-guided 调参或关闭预取 |





## 8. 实际中如何获取这些语义

### 8.1 在 Linalg/Tensor 层获取算子与数据对象语义

这一层 IR 仍然保留较强的算法语义，适合识别“这是一个什么计算”。

可获取内容：

```text
op kind
A/B/C 对象身份
M/N/K
layout
transpose
alpha/beta
post-op
```

实际获取方式：

1. 直接匹配 `linalg.matmul`、`linalg.batch_matmul`。  
   这类 op 已经显式区分输入和输出，可直接标注 A/B/C。

2. 对 `linalg.generic` 分析 indexing maps 和 iterator types。  
   如果存在两个 parallel 维和一个 reduction 维，并且访问模式符合：

```text
A(m, k), B(k, n), C(m, n)
```

   则可识别为 GEMM-like 计算。

3. 从 tensor/memref type、indexing map 和 op 属性中获取 shape/layout。  
   若 layout 已经 lower 到 memref stride，则后续也可在 MemRef/SCF 层补充。

4. 从算子属性或周边 pattern 获取 `alpha/beta/post-op`。  
   如果 IR 中没有显式 `alpha/beta`，可通过是否读取旧 C、是否先 load C 再累加来推断。

建议在这一层生成高层标注：

```mlir
{prefetch.semantic = "sme_gemm",
 prefetch.roles = ["A", "B", "C"],
 prefetch.beta_nonzero = true}
```

这些标注不直接生成预取，而是向后续 pass 传递对象身份。

### 8.2 在 Tiling、Bufferization 和 Packing 后获取分块语义

分块语义通常不是原始 Linalg op 自带的，而是在 tiling、bufferization、packing pass 之后变得明确。

可获取内容：

```text
blkm, blkn, blkk
mr/nr 或 mr1/mr2/nr
pack_A / pack_B 是否启用
packed buffer 作用域
tile/panel 生命周期
```

实际获取方式：

1. 从 tiling pass 的 tile size 属性或生成的循环步长获取 `blkm/blkn/blkk`。  
   如果 tiling 使用 transform dialect，可直接从 transform 参数记录。

2. 从 `memref.subview` 获取 tile 的起点、形状和步长。  
   例如 A panel、B panel、C tile 通常会表现为不同的 subview。

3. 从 `memref.alloc` / `memref.alloca` 和 copy/pack loop 获取 packed buffer。  
   packed buffer 的作用域可由 alloc 所在 block、dealloc 位置和使用点推导。

4. 从 microkernel lowering 配置或 kernel 模板获取 `mr/nr`。  
   对 hand-written SME microkernel，可通过外部配置表传入；对自动生成 kernel，可从 vector/matrix tile shape 推导。

这一层建议生成 panel/tile 级语义对象，例如：

```text
PackedPanel(A, shape = blkm x blkk, lifetime = current pc/ic)
PackedPanel(B, shape = blkk x blkn, lifetime = current pc/jc)
OutputTile(C, shape = blkm x blkn)
```

### 8.3 在 SCF/Affine 层获取 loop order、复用和合法性

SCF/Affine 层显式暴露循环结构，适合分析“未来什么时候会访问”和“这个地址是否安全”。

可获取内容：

```text
loop order
reuse_count
reuse_distance
主循环范围
尾循环范围
对象边界
```

实际获取方式：

1. 遍历 `scf.for` / `affine.for` 嵌套结构，记录循环变量和步长。  
   例如 `jc -> pc -> ic -> k` 可以判断 B panel 是否被多个 `ic` tile 复用。

2. 对每个 memref/subview 使用 def-use 分析。  
   如果同一个 B packed buffer 在多个 `ic` 迭代中被 microkernel 使用，则 `reuse_count_B` 较高。

3. 使用 affine expression 计算未来地址。  
   对 affine load/store，可根据 loop iv 和 stride 计算 `k + D`、`pc + D_panel` 对应地址。

4. 根据循环上下界判断主循环和尾循环。  
   如果循环上界是整除 tile size 的主循环区域，可积极预取；如果是 remainder/tail loop，则需要 predicate 或边界证明。

5. 用 memref shape/stride 判断对象边界。  
   对无法证明在边界内的候选预取，应延迟到更低层检查或直接删除。

这一层适合生成 L2 panel/tile 预取候选：

```text
CandidatePrefetch(B_panel, unit = PANEL, target = L2)
CandidatePrefetch(A_panel, unit = PANEL, target = L2)
CandidatePrefetch(C_tile, condition = beta != 0)
```

### 8.4 在 Vector/ArmSVE 层获取访问模式语义

Vector/ArmSVE 层适合判断地址流是连续、跨步还是 gather。

可获取内容：

```text
CONTIG / STRIDED / GATHER
vector length
predicate mask
tail-safe
```

实际获取方式：

1. 匹配 `vector.load`、`vector.transfer_read`。  
   如果 indexing map 对应连续 memref 访问，则标记为 `CONTIG`。

2. 分析 memref stride 和 vector transfer permutation。  
   若存在固定 stride，则标记为 `STRIDED`，并记录 stride 字节数。

3. 匹配 `vector.gather` 或 ArmSVE gather load。  
   对 gather，生成两阶段语义：

```text
先预取 index stream
再根据 index vector 生成 gather data prefetch
```

4. 读取 mask/predicate。  
   若 predicate 能证明某些 lane 无效，则这些 lane 的地址不能生成预取。

5. 在 vector lowering 后获取真实 VL。  
   对 scalable vector，VL 可能是运行时相关，需要用 vector iteration 而不是固定元素数表示距离。

### 8.5 在 ArmSME 层获取 K-step 和 ZA 语义

ArmSME 层最接近 SME 的真实计算语义，适合获取 K-step body、MOPA、ZA tile load/store。

可获取内容：

```text
K step / outer-product step
microkernel K-step body 中的 MOPA 指令数
cycles_per_k_step 的模型输入
ZA tile zero/load/store
tile slice 布局
```

实际获取方式：

1. 匹配 `arm_sme.mopa` 或等价 outer-product op。  
   MOPA 的 A/B operand 即为 L1 K-step 预取的主要对象。

2. 根据 microkernel 内层循环识别 K-step body。  
   一个 K-step body 可能包含一条 MOPA，也可能包含更新多个 ZA tile 的 MOPA 指令组。

3. 统计 K-step body 中的 load、MOPA、MLA 和 tile 操作。  
   这些信息用于估算：

```text
cycles_per_k_step
CMR
prefetch issue_period
```

4. 匹配 ZA 初始化方式。  
   `tile_zero` 表示不需要旧 C/ZA restore 读预取；`tile_load` 或旧 C load 表示可能需要 C/ZA 读预取。

5. 匹配 ZA store。  
   根据 store 的 tile slice 布局生成 C writeback 候选，并交给硬件层判断是否使用 store prefetch 或 non-temporal store。

### 8.6 在 LLVM/Machine 层获取目标硬件语义

LLVM/Machine 层负责把抽象预取决策转成目标指令，并检查低层成本。

可获取内容：

```text
cache line size
L1/L2 target hint
prfm/pst 支持情况
寄存器压力
调度窗口
目标 CPU 特性
```

实际获取方式：

1. 从 target/subtarget 配置读取硬件参数。  
   包括 cache line size、可用 prefetch hint、是否支持 store prefetch 等。

2. 将抽象 target/policy 映射为 ARM hint：

```text
L1 + KEEP -> pldl1keep
L2 + KEEP -> pldl2keep
L1 + STRM -> pldl1strm
store prefetch -> pstl1keep/pstl1strm
```

3. 检查地址计算成本。  
   如果为了预取需要额外复杂地址计算，可能抵消收益，应降低优先级或删除。

4. 检查寄存器压力和调度。  
   如果预取地址占用额外寄存器，或插入点破坏 SME/SVE overlap，应推迟、合并或删除预取。

5. 做 cache line 去重和发射频率控制。  
   同一 cache line 的重复预取应合并，预取指令不应过密。

### 8.7 在 Runtime/PMU 层获取反馈语义

静态获取的语义只能给出初始策略，最终需要运行反馈校正。

可获取内容：

```text
L1D miss rate
L2 miss rate
LLC miss rate
memory bandwidth utilization
backend memory stall
TLB miss
cache pollution proxy
```

实际获取方式：

1. 使用 `perf` 或平台 PMU 采集 cache/memory 事件。
2. 对不同矩阵规模、不同 tile size、不同预取距离运行 microbenchmark。
3. 比较无预取、固定距离预取、语义驱动预取三类版本。
4. 将最优的 `D_A_L1`、`D_B_L1`、`D_panel`、`KEEP/STRM` 写回 profile。
5. 对 edge case 或负收益场景生成关闭规则。

反馈调参示例：

```text
if L1D miss high and backend memory stall high:
    increase or enable L1 K-step prefetch

if memory bandwidth near saturation:
    reduce prefetch aggressiveness

if L1 miss increases after prefetch:
    suspect cache pollution, lower target to L2 or use STRM

if edge case performance drops:
    disable microkernel-inner prefetch for edge case
```

