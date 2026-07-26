# SME Stencil 读预取优化实施方案

本文面向 `SME1` 项目中的两个单时间步、常系数 stencil：

1. 2D 5-point（2D5P）
2. 3D 7-point（3D7P）

本文只讨论数据读预取。整体目标是在不改写原始 SME/SVE ACLE C kernel 的前提下，由 Clang 正常生成 LLVM IR，再由同一个 LLVM pass 从循环、GEP 和 masked load 中识别 stencil 内存流，决定预取距离、缓存层级和 `KEEP/STRM` 策略，插入 `llvm.aarch64.prefetch`，最终由 AArch64 后端生成 `PRFM`。

## 第一部分：2D5P 与 3D7P 如何计算

### 1.1 共同约定

两个算子都使用 `float32`、row-major 布局，并采用两个输入参数控制权重：

1. `center_weight`：中心点权重
2. `axis_weight`：所有轴向邻居的统一权重

输入和输出使用不同数组，不能原地覆盖。原因是当前输出点仍可能依赖相邻位置尚未使用的旧输入值。

kernel 只计算内部点，边界值由调用者负责：

1. 2D 的合法内部范围为 `1 <= y < H - 1`、`1 <= x < W - 1`
2. 3D 的合法内部范围为 `1 <= z < D - 1`、`1 <= y < H - 1`、`1 <= x < W - 1`

当前实现位于：

```text
SME1/stencil_sme_kernels.c
```

两个函数使用 `__arm_locally_streaming` 进入 SME streaming mode，以 `x` 为最内层连续维，通过谓词处理不能整除 streaming vector length 的尾部。

### 1.2 2D 5-point stencil

2D5P 为每个内部输出点读取中心、左、右、上、下共 5 个输入点：

```text
              input[y-1, x]
                    |
input[y, x-1] - input[y, x] - input[y, x+1]
                    |
              input[y+1, x]
```

计算公式为：

```text
output[y, x]
  = center_weight * input[y, x]
  + axis_weight * (
      input[y, x - 1]
    + input[y, x + 1]
    + input[y - 1, x]
    + input[y + 1, x])
```

row-major 线性地址为：

```text
index(y, x) = y * W + x
```

因此 5 个输入地址相对于中心点的偏移为：

```text
center :  0
left   : -1
right  : +1
north  : -W
south  : +W
```

虽然每个输出点有 5 次逻辑读取，但从沿 `x` 推进的 cache-line 流看，通常只有 3 条主要流：

1. `row(y - 1)`：north 行
2. `row(y)`：left、center、right 共享当前行
3. `row(y + 1)`：south 行

left、center、right 的地址只相差一个元素，绝大多数时候落在相同或相邻 cache line。预取时应把它们合并为一条当前行流，不能为三次 load 重复发出三条预取。

### 1.3 3D 7-point stencil

3D7P 在 2D 十字邻域基础上增加前、后两个平面邻居：

```text
当前平面 z：

              input[z, y-1, x]
                     |
input[z,y,x-1] - input[z,y,x] - input[z,y,x+1]
                     |
              input[z, y+1, x]

相邻平面：

input[z-1, y, x]
input[z+1, y, x]
```

计算公式为：

```text
output[z, y, x]
  = center_weight * input[z, y, x]
  + axis_weight * (
      input[z, y, x - 1]
    + input[z, y, x + 1]
    + input[z, y - 1, x]
    + input[z, y + 1, x]
    + input[z - 1, y, x]
    + input[z + 1, y, x])
```

row-major 线性地址为：

```text
index(z, y, x) = z * H * W + y * W + x
plane_stride = H * W
```

7 个输入地址相对于中心点的偏移为：

```text
center :  0
left   : -1
right  : +1
north  : -W
south  : +W
front  : -H*W
back   : +H*W
```

从 cache-line 流看，3D7P 通常形成 5 条主要流：

1. 当前平面的 `row(y - 1)`
2. 当前平面的 `row(y)`，合并 left、center、right
3. 当前平面的 `row(y + 1)`
4. 前一平面的 `row(y)`
5. 后一平面的 `row(y)`

3D7P 比 2D5P 多出的核心问题不是多两次加法，而是多两条跨平面长跨度内存流。平面跨度 `H * W` 较大时，更容易出现 cache miss、TLB miss 和多核带宽压力。

### 1.4 两个算子的共同点与区别

| 项目 | 2D5P | 3D7P |
|---|---:|---:|
| 逻辑输入点数 | 5 | 7 |
| 主要 cache-line 流 | 3 | 5 |
| 最内层连续维 | `x` | `x` |
| 行跨度 | `W` | `W` |
| 平面跨度 | 无 | `H * W` |
| 主要预取对象 | 当前行、上下行 | 当前行、上下行、前后平面 |
| 主要风险 | 预取开销超过收益 | cache/TLB/带宽压力 |

两个算子应共享同一套 LLVM pass 分析框架，但必须分别生成预取决策。尤其不能把 2D 的最优预取距离和流数量直接用于 3D。

## 第二部分：读预取方案与作用原理

### 2.1 为什么预取能够起作用

正常 load 发生 cache miss 时，处理器必须等待数据从更低层缓存或内存返回。SME 提高计算吞吐后，每次向量迭代的计算时间缩短，等待数据的比例会进一步增大。

读预取提前发起未来地址的数据请求，但不立即消费返回值：

```text
当前迭代 i：
  发出未来迭代 i + d 的预取
  计算当前迭代 i

未来迭代 i + d：
  执行真实 load
  期望数据已经进入目标缓存
```

只要预取提前量覆盖了数据访问延迟，真实 load 就可能由长延迟 miss 变成短延迟 cache hit。预取本身不减少逻辑 load 数量，它通过让内存传输与当前计算重叠来隐藏延迟。

预取可能无效或产生负收益：

1. 距离过短：数据尚未返回，预取过晚
2. 距离过长：数据在使用前被逐出
3. 流数量过多：消耗带宽和 miss queue
4. 重复预取：同一 cache line 被多次请求
5. 工作集过大：预取污染当前真正需要的数据
6. 硬件已经处理连续流：软件预取只增加指令开销

因此优化目标不是“插入最多预取”，而是用最少的预取覆盖最关键的未来 cache line。

### 2.2 四类读预取

针对当前 2D5P 和 3D7P，可将读预取分成 4 类。

| 类别 | 2D5P | 3D7P | 主要目标 |
|---|---|---|---|
| A. 连续维前向预取 | 可选 | 可选 | 预取未来 `x` 位置 |
| B. 跨行邻域预取 | 需要 | 需要 | 预取 north/south 行 |
| C. 跨平面邻域预取 | 不适用 | 需要 | 预取 front/back 平面 |
| D. 下一空间块预取 | 可选增强 | 推荐增强 | 消除 row/plane/tile 切换冷启动 |

### 2.3 A 类：连续维前向预取

沿 `x` 方向，当前行访问连续增长。对未来位置 `x + d` 发出预取：

```text
2D:
  input[y, x + d]

3D:
  input[z, y, x + d]
```

由于 left、center、right 属于同一行流，只需要对未来当前行的 cache line 预取一次。

这类流最容易被硬件预取器识别，因此软件预取优先级最低。它的主要用途是：

1. 验证 SME streaming mode 下硬件预取是否足够
2. 在短行、频繁 tile 切换或硬件跟踪失败时补充
3. 作为其他邻域流距离模型的基准

如果开启后性能无改善或指令数增加明显，应关闭。

### 2.4 B 类：跨行邻域预取

2D5P 和 3D7P 都需要 north/south 行。沿 `x` 推进时，对未来位置预取：

```text
2D:
  input[y - 1, x + d_row]
  input[y + 1, x + d_row]

3D:
  input[z, y - 1, x + d_row]
  input[z, y + 1, x + d_row]
```

这类预取的作用是让上下行数据在真实向量 load 前进入缓存。当前行通常具有较好的连续访问和复用，而上下行是额外的并发流，因此 B 类一般比 A 类更值得优先尝试。

但不是每次向量迭代都必须发两条预取。实现时应：

1. 把未来地址对齐到 cache line
2. 只在跨入新 cache line 时发出预取
3. 允许 north/south 使用相同距离但独立开关
4. 在 cache 容量不足时优先保留下一次最早使用的流

### 2.5 C 类：跨平面邻域预取

C 类只适用于 3D7P。对未来位置预取：

```text
input[z - 1, y, x + d_plane]
input[z + 1, y, x + d_plane]
```

front/back 与中心相差一个完整平面。地址跨度本身不会增加一次内存请求的传输延迟，但会带来三个问题：

1. 硬件需要同时跟踪更多独立流
2. 大平面更容易超过缓存容量
3. 跨平面访问更容易增加 TLB 压力

因此 C 类是 3D7P 最需要独立调优的预取。建议采用两级思路：

```text
较远位置：先把 plane 数据预热到较低层缓存
接近使用：再把未来 cache line 拉近到 L1
```

不应在进入一个平面时一次性预取整个下一平面。正确做法是维护随 `x/y` 计算前沿推进的 plane prefetch frontier，只预取即将使用的少量 cache line。

### 2.6 D 类：下一空间块预取

即使稳定的内层流已经被覆盖，切换到下一行、下一平面或下一 tile 时，硬件预取器仍可能需要重新识别地址模式。D 类预取用于减少这种冷启动：

```text
2D:
  当前行接近结束时，预取下一计算行的首批内部数据

3D:
  当前平面计算期间，预取下一平面的工作集前沿
  当前 tile 接近结束时，预取下一 tile 的首批内部数据
```

D 类通常距离较远，不适合直接占用大量 L1 空间。它应与 B/C 类近距离预取形成接力，而不是替代它们。

### 2.7 预取距离模型

预取距离首先用“提前多少次向量迭代”表示：

```text
d_iterations
  = ceil(memory_latency_cycles / useful_cycles_per_vector_iteration)
```

公式中：

- `d_iterations`：预取应领先真实 load 的向量循环迭代次数，单位为“次向量迭代”。
- `memory_latency_cycles`：数据从预期来源层级到达目标 cache 的估计延迟，单位为 cycle；选择 L1、L2 或 L3 时应使用对应的延迟估计。
- `useful_cycles_per_vector_iteration`：不包含当前 cache miss 等待时间时，一次 SME/SVE 向量迭代可用于掩盖内存延迟的有效计算周期。
- `ceil`：向上取整，保证静态提前时间不少于估计的数据返回时间。

再换算为 `x` 方向元素距离：

```text
d_elements
  = d_iterations * streaming_vector_length_in_f32
```

公式中：

- `d_elements`：预取地址相对当前 `x` 的前移元素数，单位为 `float` 元素。
- `streaming_vector_length_in_f32`：一次 streaming SVE 向量可处理的 `float` 元素数，对应运行时 `svcntsw()`。
- 该换算不假定固定硬件向量长度；pass 保存 `d_iterations`，构造地址时通过可伸缩向量步长表达 `d_elements`。

未来地址为：

```text
2D:
  address(y + dy, x + d_elements)

3D:
  address(z + dz, y + dy, x + d_elements)
```

公式中：

- `address(...)`：对应物理输入流在未来迭代将访问的元素地址，最终需要转换为可供预取 intrinsic 使用的指针。
- `x/y/z`：当前向量迭代的空间坐标；`x` 是最内层连续维，`y` 是行维，`z` 是平面维。
- `dy`：行方向邻域偏移；`0/-1/+1` 分别表示当前行、north 行和 south 行。
- `dz`：平面方向邻域偏移；`0/-1/+1` 分别表示当前平面、front 平面和 back 平面。
- `(dz, dy)` 决定当前预取属于当前行、跨行还是跨平面流；2D 模型中没有 `dz`。
- 地址必须仍处于可安全预取的内部区域；靠近边界或循环尾部时需要通过 trip count、谓词或安全地址策略限制。

距离模型至少要考虑：

1. streaming vector length
2. 每次向量迭代的计算周期
3. cache line 大小
4. 目标缓存延迟
5. 行跨度和平面跨度
6. 同时启用的流数量
7. 网格和 tile 大小
8. 单核或多核可用带宽

建议为四类预取分别保存距离，不能只使用一个全局常量：

```text
d_inner
d_row
d_plane
d_tile
```

#### 2.7.1 距离模型的约束条件

距离公式只给出覆盖目标层延迟所需的原始提前量，最终距离必须同时满足：

```text
memory_latency_cycles > 0
useful_cycles_per_vector_iteration > 0

min_distance(level)
  <= d_iterations(stream, level)
  <= max_distance(stream)

inner_trip_count
  > 2 * d_iterations(stream, level)
```

约束含义如下：

1. **输入有效**：目标层延迟和每次迭代有效周期必须由目标机 profile 或静态估算提供；缺少可信输入时不生成候选。
2. **循环足够长**：距离不能超过内层循环可利用的稳定区间。若 trip count 不大于两倍距离，则关闭该流。
3. **未来地址合法**：预取地址必须位于可安全构造的内部区域；无法证明时增加 guard、缩短有效区间或关闭候选。
4. **通过资源检查**：候选还必须满足后续 cache 容量、流数量和带宽预算，否则降级或删除。

### 2.8 目标 cache 层级选择模型

预取距离回答“什么时候发出”，cache 层级回答“先把数据放到哪里”。两者必须联合决策。

选择层级时需要估算预取数据在真实使用前的存活时间和占用：

```text
lead_cycles(stream)
  = d_iterations(stream) * useful_cycles_per_vector_iteration

prefetch_live_bytes(stream)
  = d_iterations(stream)
  * bytes_per_vector_iteration

total_live_bytes(level)
  = sum(prefetch_live_bytes(stream), stream targets level)
```

公式中：

- `stream`：去重后的物理 cache-line 流，例如 current-row、north-row、south-row、front-plane 或 back-plane，而不是每一条逻辑 load。
- `level`：候选预取的目标 cache 层级，如 L1、L2 或 L3。
- `lead_cycles(stream)`：该流从发出预取到真实 load 之间预计经过的周期数。
- `d_iterations(stream)`：为该流和目标层级选择的预取提前迭代数；不同流可以不同。
- `useful_cycles_per_vector_iteration`：一次向量迭代能够与预取传输重叠的有效计算周期。
- `prefetch_live_bytes(stream)`：该流在预取领先窗口内需要占用目标 cache 的近似字节数。
- `bytes_per_vector_iteration`：该物理流每次向量迭代新覆盖的数据字节数；应按 cache-line 去重，不能把 left/center/right 重复累加。
- `total_live_bytes(level)`：所有指向同一 cache 层级的候选流在途占用之和。
- `sum(..., stream targets level)`：只累加最终候选层级等于 `level` 的流；改变层级或删除流后必须重新计算。

`prefetch_live_bytes` 是某条流从发出预取到真实使用之间的大致在途覆盖范围。实际选择还要加上当前 stencil 的活跃行、活跃平面和 tile 工作集。

层级选择规则：

1. **选择 L1**：数据将在较少的向量迭代后立即使用，并且所有 L1 预取流的 `total_live_bytes + active_working_set` 不超过可用 L1 预算。
2. **选择 L2**：数据距离使用仍较远，或下一行、下一平面、下一 tile 的数据过早放入 L1 会污染当前工作集。
3. **选择 L3**：只用于非常远的空间块预热，并且目标平台确实具有可控的共享末级缓存。第一版不默认使用 L3。

建议使用有效容量而不是标称容量：

```text
L1_budget = alpha1 * L1_capacity
L2_budget = alpha2 * L2_capacity
```

公式中：

- `L1_capacity/L2_capacity`：目标核心上相应 cache 的标称容量。
- `alpha1/alpha2`：可分配给当前 stencil 预取和活跃工作集的容量折扣系数。
- `L1_budget/L2_budget`：层级决策实际使用的有效容量上限，而不是硬件标称容量。
- `alpha1/alpha2` 可先取 `0.5~0.7`，为真实 load、store、栈和其他线程争用保留空间。

按预取类别的初始层级：

| 类别 | 初始层级 | 原因 |
|---|---|---|
| A 连续维 | L1 | 若启用，通常很快使用 |
| B 跨行邻域 | L1 | north/south 的未来 cache line 接近使用 |
| C 跨平面近距离 | L1 | front/back 的当前前沿即将使用 |
| C 跨平面远距离 warming | L2 | 避免过早占用 L1 |
| D 下一行/平面/tile | L2 | 切换前的远距离预热 |

同一条 plane 流可以使用两级接力：

```text
较远处插入 L2 预取
-> 接近真实 load 时插入 L1 预取
-> 执行真实 load
```

这意味着一条 `StreamInfo` 不一定只插入一次预取；启用两级策略时，可以在较远位置插入一次 L2 `llvm.aarch64.prefetch`，并在接近真实 load 时再插入一次 L1 `llvm.aarch64.prefetch`。

#### 2.8.1 Cache 层级模型的约束条件

层级选择不是在 L1/L2/L3 中任意取值。一个层级候选只有满足以下容量条件才能接受：

```text
required_bytes(level)
  = active_working_set(level)
  + sum(prefetch_live_bytes(stream), stream targets level)

required_bytes(level) <= budget(level)
```

此外还必须满足：

1. **满足时间窗口**：接近使用的流优先进入 L1，较远 warming 优先进入 L2；不能通过缩短距离牺牲延迟覆盖。
2. **满足有效容量**：活跃工作集和所有已准入预取流必须共同计入 `required_bytes`，改变候选集合后重新计算。
3. **尺寸信息可用**：静态尺寸未知时使用 workload profile；两者都缺失时，关闭依赖完整行或平面驻留的候选。
4. **两级接力分别成立**：同时使用 L2 warming 和 L1 near prefetch 时，两个层级必须分别通过时间和容量检查。

### 2.9 KEEP/STRM 策略选择模型

`KEEP/STRM` 回答“数据进入目标 cache 后是否值得尽量保留”。选择依据不是地址是否连续，而是复用次数和复用距离。

建议为每条流估算：

```text
reuse_count(stream)
reuse_distance_bytes(stream)
```

其中：

- `reuse_count(stream)`：同一 cache line 在离开当前复用窗口前预计被 stencil 再次读取的次数；值越大，保留该 line 的潜在收益越高。
- `reuse_distance_bytes(stream)`：从本次使用到下一次使用之间预计访问的不同数据总量，单位为 byte；它近似表示该 line 在复用前承受的 cache 容量压力。
- `stream`：已经合并和去重的物理输入流。left、center、right 对同一 current-row line 的访问应共同参与复用估算，不能作为三条独立流计算。
- 这两个量是静态分析与目标 profile 的估计值；动态 `W/H` 或 tile 尺寸未知时应标记为未知，而不能默认其能够驻留 cache。

选择规则：

1. **选择 KEEP**：cache line 会再次使用，且 `reuse_distance_bytes` 小于目标 cache 的有效容量预算。
2. **选择 STRM**：cache line 在当前阶段近似只使用一次，或再次使用前要跨越的工作集明显大于目标 cache 容量。

2D5P 中，一条输入行会随 `y` 推进依次扮演 south、current、north，因此存在跨输出行复用：

```text
row(y + 1) 作为 south
-> 下一轮作为 current
-> 再下一轮作为 north
```

如果几条活跃行能留在目标 cache 中，B 类 row stream 优先使用 `KEEP`。当行非常长、多核争用严重、复用距离超过 cache 预算时，再比较 `STRM`。

3D7P 中，front/back 平面也会随 `z` 推进轮换，但完整平面的复用距离可能远大于 L1：

1. plane 近距离进入 L1、只服务当前计算前沿时，可优先比较 `STRM`
2. plane/tile 能在 L2 内复用时，远距离 warming 使用 `KEEP`
3. 完整平面大于 L2 有效容量时，L2 `STRM` 可能比 `KEEP` 更少污染

因此不能使用一个全局 policy。至少分别配置：

```text
policy_inner
policy_row
policy_plane_near
policy_plane_far
policy_tile
```

#### 2.9.1 KEEP/STRM 模型的约束条件

策略必须在目标 cache 层级确定后按流计算：

```text
reuse_fits(stream, level)
  = reuse_count(stream) > 1
  && reuse_distance_bytes(stream) <= budget(level)

policy(stream, level)
  = KEEP, if reuse_fits(stream, level)
  = STRM, otherwise
```

该判定受以下条件约束：

1. **复用可判断**：只有能够识别复用次数和复用距离时才选择 `KEEP`；信息未知时使用 `STRM`，并关闭依赖长期驻留的 warming。
2. **复用能够驻留**：`reuse_distance_bytes` 必须小于已选层级的有效容量；同一流在 L1 和 L2 可能得到不同 policy。
3. **按物理流决策**：left、center、right 合并后只能产生一个 KEEP/STRM 决策。
4. **仍受资源限制**：`STRM` 不减少指令数和内存流量，候选仍需通过流数量与带宽预算。

### 2.10 距离、层级和策略的联合决策

每条流的完整决策为：

```text
PrefetchDecision {
  enable
  distance_iterations
  cache_level
  policy
}
```

推荐决策顺序：

1. 根据预计延迟计算候选 `distance_iterations`
2. 根据使用时间窗口和活跃工作集选择 `cache_level`
3. 根据复用次数和复用距离选择 `policy`
4. 重新计算该组合产生的 cache 占用和总预取流数量
5. 如果超出 cache 或带宽预算，缩短距离、降到更低层 cache，或关闭低优先级流

联合约束可写为：

```text
total_live_bytes(L1) + active_L1_working_set <= L1_budget
total_live_bytes(L2) + active_L2_working_set <= L2_budget
enabled_prefetch_streams <= stream_budget
estimated_prefetch_bandwidth <= bandwidth_budget
```

第一版不需要追求完全准确的硬件模型。可以用静态启发式生成候选组合，再通过 PMU 实验筛选；但 pass 内必须显式保留三维决策，不能只保存距离。

### 2.11 2D 与 3D 的推荐初始策略

2D5P：

```text
A 连续维：默认关闭；若开启，使用 L1 + KEEP
B 跨行：默认开启，north/south 使用近距离 L1 + KEEP
C 跨平面：不适用
D 下一块：next-row 使用远距离 L2 + KEEP
```

3D7P：

```text
A 连续维：默认关闭；若开启，使用 L1 + KEEP
B 跨行：使用近距离 L1 + KEEP
C 跨平面近距离：先测试 L1 + STRM
C 跨平面远距离：平面/tile 可复用时使用 L2 + KEEP，
                  平面明显超过 L2 预算时比较 L2 + STRM
D 下一块：next-plane/next-tile 默认使用 L2，
           KEEP/STRM 由 tile 是否能在 L2 内复用决定
```

以上是初始候选，不是固定结论。最终选择必须分别对 2D 和 3D 扫描距离、层级与 policy。

## 第三部分：在 Clang/LLVM 编译流程中实现预取

本部分按照实际开发顺序实现。输入是原始 SME/SVE ACLE C kernel，不要求手工结构化 C，不要求高层 MLIR，也不生成 JSON。流识别、策略选择和指令插入在同一个 LLVM function pass 中完成。

整体流程：

```text
stencil_sme_kernels.c
-> Clang 语义分析与 CodeGen
-> LLVM IR
   - 自然循环和归纳变量
   - getelementptr 地址计算
   - llvm.masked.load
   - AArch64 SVE/SME intrinsic
-> StencilPrefetchPass
   - 识别 2D5P/3D7P 内存流
   - 计算距离、缓存层级和 KEEP/STRM
   - 就地插入 llvm.aarch64.prefetch
-> LLVM AArch64 后端
-> SME/SVE 计算指令 + PRFM 读预取
```

各层职责如下：

| 层级 | 本方案中的职责 |
|---|---|
| C/ACLE 源码 | 表达原始 2D5P、3D7P 和 SME/SVE 向量计算，不承载预取决策 |
| Clang AST/CodeGen | 完成 C 语义检查并生成 LLVM IR；第一版不修改 Clang AST |
| LLVM IR pass | 识别 stencil 访问、选择策略并插入目标预取 intrinsic，是本方案的核心 |
| AArch64 后端 | 把 intrinsic 选择成带层级和策略提示的 `PRFM` |
| 汇编/机器码 | 执行最终 SME/SVE 计算和软件读预取 |

### 步骤 1：确认 Clang 生成的 LLVM IR 可分析

先保留 kernel 的 LLVM IR：

```bash
clang -target arm64-apple-macos15 -march=armv9.2-a+sme+sve2 \
  -O1 -S -emit-llvm stencil_sme_kernels.c \
  -o stencil_sme_kernels.ll
```

当前 C kernel 经过 Clang 后仍保留实现预取所需的信息：

1. `__arm_locally_streaming` 形成 `aarch64_pstate_sm_body` 函数属性。
2. `svcntsw()` 形成 `llvm.aarch64.sme.cntsw`，可用于表示每次向量迭代的元素步长。
3. `x` 循环形成基本块、`phi` 归纳变量和回边。
4. 输入地址形成 `getelementptr`，行跨度 `W` 和平面跨度 `H * W` 仍在地址表达式中。
5. 谓词 SVE load 形成 `llvm.masked.load`；2D5P 有 5 个逻辑 load，3D7P 有 7 个逻辑 load。
6. SVE 加法、乘法和 store 仍以 AArch64 intrinsic 或等价向量 IR 表达。

因此无需先把 C 变成 affine/vector MLIR。LLVM IR 虽然比高层 MLIR 更低，但对当前规则、固定邻域 stencil 已保留足够的循环和地址关系。

为了让 pass 输入稳定，建议在预取 pass 前运行：

```text
mem2reg
loop-simplify
lcssa
indvars（可选）
```

不能依赖某一种具体的基本块编号或 SSA 名称；应通过 LLVM analysis API 和 SCEV 表达式识别循环与地址。

### 步骤 2：建立 LLVM new-pass-manager 插件

实现一个 function pass：

```cpp
class StencilPrefetchPass
    : public llvm::PassInfoMixin<StencilPrefetchPass> {
public:
  llvm::PreservedAnalyses run(
      llvm::Function &F,
      llvm::FunctionAnalysisManager &FAM);
};
```

pass 至少获取以下分析：

| LLVM analysis | 用途 |
|---|---|
| `LoopAnalysis` | 找到最内层向量循环和 preheader/latch |
| `ScalarEvolutionAnalysis` | 解析归纳变量、行跨度、平面跨度和未来地址 |
| `DominatorTreeAnalysis` | 选择支配真实 load 的合法插入点 |
| `TargetIRAnalysis` | 读取目标相关信息，并为后续代价判断留接口 |
| `AssumptionAnalysis` | 利用已有范围和对齐假设 |

插件通过 `PassBuilder` 注册，可先支持显式管线：

```bash
opt -load-pass-plugin ./libStencilPrefetchPass.so \
  -passes='function(stencil-prefetch)' \
  input.ll -S -o output.ll
```

功能稳定后再接入 Clang：

```bash
clang -O3 -march=armv9.2-a+sme+sve2 \
  -fpass-plugin=./libStencilPrefetchPass.so \
  stencil_sme_kernels.c -S -o stencil_sme_kernels.s
```

第一版可以通过函数属性、命令行过滤器或函数名限制处理范围，避免误优化其他循环；但 2D/3D 判断和内存流识别不能只依赖函数名。

### 步骤 3：从循环和地址识别 2D5P/3D7P

#### 3.1 找到候选内层循环

候选循环应同时满足：

1. 是最内层循环。
2. 包含 `llvm.masked.load` 和 masked/vector store。
3. 归纳变量按 `svcntsw()` 或等价可伸缩向量步长递增。
4. 多个 load 使用相同谓词，并由同一组基址/跨度派生。
5. 循环体不包含无法安全跨越的副作用调用。

#### 3.2 规范化 load 地址

对每个 masked load，使用 SCEV 或 GEP 链提取：

```text
Address = Base + IV * sizeof(float) + ConstantOrLoopInvariantOffset
```

以中心流为基准，2D5P 应能归纳出元素偏移：

```text
0, -1, +1, -W, +W
```

3D7P 应能归纳出：

```text
0, -1, +1, -W, +W, -(H*W), +(H*W)
```

识别时不要求这些偏移在 IR 中已经折叠成单个整数。应允许 `mul`、`add`、`sext/zext` 和嵌套 GEP，并通过 SCEV 判定两个地址之差是否为循环不变量。

#### 3.3 合并逻辑 load 为物理流

```text
2D5P:
  current row: left + center + right
  north row
  south row
  => 3 条主要 cache-line 流

3D7P:
  current-plane current row: left + center + right
  current-plane north row
  current-plane south row
  front-plane current row
  back-plane current row
  => 5 条主要 cache-line 流
```

同一 cache line 内的 left/center/right 只生成一个预取。pass 内可使用短生命周期的数据结构：

```cpp
struct StreamInfo {
  Value *RepresentativePointer;
  const SCEV *Address;
  StreamKind Kind;
  unsigned LogicalLoadCount;
  unsigned ReuseCount;
  uint64_t ReuseDistanceBytes;
};

struct PrefetchDecision {
  bool Enable;
  unsigned DistanceIterations;
  CacheLevel Level;
  LocalityPolicy Policy;
  DecisionReason Reason;
};
```

这些对象只存在于当前 pass 运行期间。识别一条流后立即做决策并插入，不序列化为 JSON，也不要求跨 pass 保存分析结果。

如果邻域关系无法可靠证明，必须跳过该循环，而不是按 load 数量猜测 stencil 类型。

### 步骤 4：边分析边选择并插入预取

本步骤必须把第二部分的原则变成确定的 pass 算法。决策不能只写成“根据代价选择”，而要明确输入、计算公式、阈值、降级顺序和默认结果。

#### 4.1 决策输入

决策输入分为目标机参数和当前循环属性。

目标机参数由 pass 命令行选项或目标机 profile 提供：

```text
cache_line_bytes
  // 一个数据 cache line 的字节数，用于地址对齐、去重和流量估算

L1_capacity_bytes
  // 每个执行该 kernel 的核心可使用的 L1 data cache 标称容量，单位为 byte

L2_capacity_bytes
  // 目标核心或核心簇可用于该 kernel 的 L2 cache 标称容量，单位为 byte

L1_prefetch_latency_cycles
  // 从预期数据来源把一个 line 拉到 L1 所需的估计周期，用于计算 L1 提前距离

L2_prefetch_latency_cycles
  // 从预期数据来源把一个 line 拉到 L2 所需的估计周期，用于计算 L2 warming 距离

memory_latency_cycles
  // LLC miss 后从主存返回数据的估计周期；缺少分层实测时作为远距离上界

max_prefetch_streams
  // 允许同时启用的独立地址流数量，例如 north 和 south 计为两条流

max_prefetch_instructions_per_iteration
  // 每次最内层向量迭代允许增加的 PRFM 指令数上限

max_prefetch_bytes_per_iteration
  // 每次向量迭代允许由软件预取请求的 cache-line 字节数上限

alpha1, alpha2
  // L1/L2 标称容量的可用比例，用于给真实 load/store 和其他线程预留空间

assumed_streaming_vl_bytes
  // 容量和流量建模采用的 SME streaming vector length，单位为 byte

expected_row_bytes
  // W 为动态值时，workload profile 给出的代表性或保守行长度，单位为 byte

expected_plane_or_tile_bytes
  // H/W 或 tile 动态时，用于判断 L2 复用的代表性 plane/tile 字节数
```

LLVM 的 TTI 不保证提供完整、准确的 cache 容量和内存延迟，因此不能假设这些值都能从后端查询。第一版在 pass 中维护按 CPU 名称选择的 C++ `TargetPrefetchProfile` 表；命令行参数可以覆盖 profile，便于实验扫描。该 profile 是目标机配置，不是分析结果，不使用 JSON，也不在分析和插入之间传递文件。

SME streaming vector length 在编译时可能是可伸缩值。距离以“向量迭代数”保存，不依赖固定 VL；只有估算 cache 占用时才使用 `assumed_streaming_vl_bytes`。如果目标部署允许多个 VL，应为每个 VL 建立 profile，或使用预期最大 VL 做保守容量判断。

当前循环属性由 `LoopInfo`、SCEV 和步骤 3 的流识别得到：

```text
stencil_kind
  // 已识别的算子类型：2D5P 或 3D7P，决定流类别和准入优先级

inner_trip_count
  // 最内层 x 循环的向量迭代次数，不是元素数；用于限制最大预取距离

row_bytes = W * sizeof(float)
  // 一整行输入数据的字节数，用于估算跨行复用距离

plane_bytes = H * row_bytes
  // 一个完整输入平面的字节数，仅 3D 使用

bytes_per_vector_iteration
  // 一条物理流在一次 x 向量迭代中前进并被真实 load 消费的字节数

useful_cycles_per_iteration
  // 不计等待 cache miss 时，一次 x 向量迭代预计完成计算所需的周期

stream_kind
  // 当前物理流的类型，如 current-row、north-row、south-row、front-plane

reuse_count
  // 同一 cache line 在被逐出前预计还会被 stencil 访问的次数

reuse_distance_bytes
  // 从本次访问到下一次复用之间预计会访问的数据量，单位为 byte
```

`useful_cycles_per_iteration` 第一版采用目标 profile 中的 2D/3D 基准值；后续可结合 TTI 对循环体 load、FMA 和 add 的吞吐量估算。不能直接用 IR 指令条数代替周期，因为 SME/SVE 指令吞吐和 load issue 宽度不同。

当前 C kernel 的 `W/H` 可能是运行时参数，而 `llvm.aarch64.prefetch` 的层级和 KEEP/STRM 参数必须是编译期立即数。pass 按以下顺序获得容量判断所需的尺寸：

1. 优先使用常量传播后 SCEV 可证明的 `W/H` 或 tile 尺寸。
2. 尺寸动态时，使用 workload profile 中的 `expected_row_bytes` 和 `expected_plane_or_tile_bytes`。
3. 如果既没有静态尺寸也没有 workload profile，则把复用距离视为未知：近距离前沿仍可按预算生成 STRM，依赖整行或整平面驻留的 KEEP 和远距离 warming 默认关闭。
4. 只有确实需要覆盖两类差异很大的尺寸时，才通过 loop versioning 生成两套具有不同立即数的循环，并在函数入口按 `W/H` 分派；第一版不默认启用这种代码膨胀。

#### 4.2 为每条流生成距离候选

对目标层级 `L` 计算：

```text
raw_distance(L)
  = ceil(prefetch_latency_cycles(L)
         / useful_cycles_per_iteration)

distance(L)
  = clamp(raw_distance(L), min_distance(L), max_distance)
```

其中：

```text
max_distance
  = floor(inner_trip_count / 2)    // trip count 已知
  = profile.max_distance           // trip count 未知
```

如果 `inner_trip_count <= 2 * raw_distance(L)`，说明稳定预取区间太短，关闭该流的内层前向预取，避免大部分迭代都落入 guard 或尾部。

距离还要向 cache-line 前沿取整：

```text
line_iterations
  = ceil(cache_line_bytes / assumed_streaming_vl_bytes)

distance(L)
  = ceil(distance(L) / line_iterations) * line_iterations
```

这里的取整只用于减少同一 cache line 的重复预取，不改变最终未来地址仍以运行时 `svcntsw()` 计算的事实。

#### 4.3 选择缓存层级

先为每个流计算放入目标层级后的在途占用：

```text
live_bytes(stream, L)
  = distance(stream, L)
  * assumed_streaming_vl_bytes

L1_budget = alpha1 * L1_capacity_bytes
L2_budget = alpha2 * L2_capacity_bytes
```

再分别计算 L1 的活跃 cache-line 前沿和 L2 的平面/tile 工作集：

```text
frontier_bytes_per_stream
  = max(cache_line_bytes, assumed_streaming_vl_bytes)

2D active_L1_frontier
  = 3 * frontier_bytes_per_stream

3D active_L1_frontier
  = 5 * frontier_bytes_per_stream

3D active_L2_working_set
  = 3 * min(plane_bytes, tile_plane_bytes)
```

若没有 tiling，`tile_plane_bytes = plane_bytes`。L1 只计算当前计算前沿涉及的 cache lines，不把完整行或完整平面都计入 L1；完整工作集能否保留由 4.4 的 KEEP/STRM 判定负责。L2 才额外评估 plane 或 plane tile 的驻留。层级按以下规则确定：

1. A/B 类和 C 类近距离候选先尝试 L1。
2. 只有 `active_L1_frontier + sum(live_bytes of admitted L1 streams) <= L1_budget` 时才接受 L1。
3. L1 超预算时，不是简单缩短到无法覆盖延迟；先尝试把远距离 warming 改为 L2，再关闭低优先级流。
4. C 类远距离和 D 类从 L2 开始，满足对应 L2 预算后才接受。
5. L3 默认禁用；只有 profile 明确声明共享末级缓存可用且候选使用时间明显晚于 L2 距离时才生成 L3 候选。

对 3D plane 流，两级接力仅在以下条件同时成立时启用：

```text
distance(L2) > distance(L1)
L2 capacity check passes
L1 near-frontier capacity check passes
plane/tile has enough iterations to cover both distances
```

否则只保留近距离 L1，或在 L1 压力过大时只保留 L2 warming，不能无条件插入两条预取。

#### 4.4 选择 KEEP 或 STRM

对每条流估算：

```text
reuse_fits(level)
  = reuse_count > 1
  && reuse_distance_bytes <= effective_capacity(level)
```

决策为：

```text
if reuse_fits(level):
  policy = KEEP
else:
  policy = STRM
```

当前两个算子的复用距离按下列方式计算：

| 流 | 复用关系 | 初始 `reuse_distance_bytes` |
|---|---|---:|
| 2D current/north/south row | 同一输入行随 `y` 轮换角色 | 约 `3 * row_bytes` |
| 3D current-plane row | 同一平面内随 `y` 轮换 | 约 `5 * row_bytes` |
| 3D front/back plane | 同一输入平面随 `z` 轮换 | 约一个 plane 工作集 |
| D next-row/plane/tile | 是否复用取决于下一块的 tile | 下一块有效工作集 |

因此 2D B 类通常得到 L1 + KEEP。3D C 类的近距离 L1 候选在完整 plane 不能留在 L1 时得到 STRM；若 plane tile 能留在 L2，远距离 L2 warming 得到 KEEP，否则得到 STRM。

#### 4.5 流准入、裁剪和降级

一个未来 SME 向量可能跨越多个 cache line。先计算每条物理流在一次向量迭代中需要覆盖的 line 数：

```text
lines_per_vector
  = ceil(assumed_streaming_vl_bytes / cache_line_bytes)

prefetch_instructions_per_iteration
  = admitted_physical_streams * lines_per_vector

candidate_prefetch_bytes_per_iteration
  = prefetch_instructions_per_iteration * cache_line_bytes

candidate_stream_count
```

`candidate_stream_count` 用于限制硬件同时跟踪的独立地址流，`prefetch_instructions_per_iteration` 用于限制额外指令数，二者不能混为一个指标。若 `lines_per_vector > 1`，同一未来向量地址需要按 cache-line 步长生成多个 `PRFM`；如果 profile 不能保证运行时 VL，则第一版只允许为已知部署 VL 生成该展开，否则采用单 cache-line 的保守模式并在诊断中标记覆盖不完整。

只有同时满足以下条件才准入：

```text
candidate_stream_count <= max_prefetch_streams
prefetch_instructions_per_iteration
  <= max_prefetch_instructions_per_iteration
candidate_prefetch_bytes_per_iteration
  <= max_prefetch_bytes_per_iteration
cache capacity check passes
distance can be covered by the main loop
```

预算超限时按最低优先级开始删除：

| 算子 | 从高到低的保留优先级 |
|---|---|
| 2D5P | B 跨行 → D next-row → A 连续维 |
| 3D7P | C 跨平面近距离 → B 跨行 → C 跨平面远距离 → D next-plane/tile → A 连续维 |

A 类默认最后考虑，因为连续 `x` 流最可能已被硬件预取覆盖。D 类只有在行、平面或 tile 切换的冷启动成本能够摊销时启用。删除一项候选后必须重新计算层级容量，不能沿用删除前的占用。

如果某个候选不满足预算，按以下顺序降级：

```text
取消两级接力中的远距离预取
-> 将远距离 L1 warming 改为 L2
-> 缩短距离，但不得短于覆盖目标层延迟的最小值
-> 改为 STRM 减少保留倾向
-> 关闭该流
```

`STRM` 只是 cache replacement hint，不能被当成突破容量或带宽预算的理由。

#### 4.6 第一版的确定性默认决策

当 profile 只有 cache/延迟参数、没有 PMU 反馈时，pass 使用以下基线：

```text
2D5P:
  current row A: disabled
  north/south row B:
    L1 + policy from reuse_fits(L1), distance(L1)
  next-row D: disabled

3D7P:
  current row A: disabled
  north/south row B:
    L1 + policy from reuse_fits(L1), distance(L1)
  front/back plane C near: L1 + STRM, distance(L1)
  front/back plane C far:
    enabled only if L2 capacity and stream budgets pass
    L2 + KEEP when plane tile fits L2, otherwise L2 + STRM
  next-plane/tile D: disabled
```

该默认值不是最终调优结果，但它保证相同 IR 和相同 target profile 产生相同决策。PMU 数据用于更新 profile 或默认参数，不在一次编译过程中动态改变 pass 逻辑。

#### 4.7 pass 决策伪代码

```cpp
for (Loop *L : findCandidateInnerLoops(F)) {
  StencilInfo SI = recognizeStencil(L, SE);
  if (!SI.isValid())
    continue;

  SmallVector<StreamInfo> Streams = mergePhysicalStreams(SI);
  SmallVector<PrefetchDecision> Candidates;

  for (const StreamInfo &S : Streams) {
    for (CacheLevel Level : initialLevels(SI.Kind, S.Kind)) {
      unsigned Distance = computeDistance(S, Level, Profile, SI);
      if (!hasStablePrefetchWindow(SI, Distance))
        continue;

      LocalityPolicy Policy =
          reuseFits(S, Level, Profile) ? KEEP : STRM;
      Candidates.push_back(
          {true, Distance, Level, Policy, InitialCandidate});
    }
  }

  sortByStencilPriority(Candidates, SI.Kind);
  SmallVector<PrefetchDecision> Admitted =
      admitWithinCacheStreamAndBandwidthBudgets(
          Candidates, SI, Profile);

  for (const PrefetchDecision &D : Admitted)
    for (Value *Address : buildSafeFutureAddresses(D, SI))
      insertAArch64ReadPrefetch(Address, D);
}
```

`buildSafeFutureAddresses` 根据 `lines_per_vector` 返回一个或多个 cache-line 地址。`Reason` 字段记录 `InitialCandidate`、`L1CapacityReject`、`BandwidthReject`、`ShortTripCount` 等原因。调试模式打印每条流的输入值、候选值和最终结果，使性能异常能够追溯，而不是只看到“插入或未插入”。

#### 4.8 构造未来地址并插入

未来位置为：

```text
future_x = x + distance_iterations * vector_step
vector_step = svcntsw()
```

对应的未来地址不应通过复制当前 load 的 `inbounds getelementptr` 后盲目增加偏移。即使预取本身通常不产生同步异常，越过 C 对象边界的 `inbounds` GEP 仍可能在 LLVM IR 中产生 poison。

建议采用以下两种方式之一：

1. 生成不带 `inbounds` 的未来 GEP，并保证地址仍落在已分配对象内。
2. 把内层循环分成可无条件预取的 main loop 和尾部，或增加 `future_x < width - 1` 条件，只在合法范围内发出预取。

第一版优先使用 main-loop/尾部拆分，使热循环中的预取保持无分支。若暂不实现 loop versioning，则使用条件保护保证 IR 语义正确。

插入位置通常选择候选循环体中、真实 load 之前且所有未来地址操作数均可用的位置。两级接力策略可对同一流插入：

```text
较大距离：L2 + KEEP/STRM
较小距离：L1 + KEEP/STRM
真实 masked load
```

去重至少以以下键进行：

```text
(stream, future cache-line, cache level, policy)
```

当静态情况下无法得到精确 cache-line 编号时，可按代表地址的 `Base + SCEV offset` 等价类去重；left/center/right 必须先合流。

### 步骤 5：插入 AArch64 预取 intrinsic

最终插入的 LLVM intrinsic 形式为：

```llvm
declare void @llvm.aarch64.prefetch(
  ptr,
  i32 immarg,
  i32 immarg,
  i32 immarg,
  i32 immarg)

call void @llvm.aarch64.prefetch(
  ptr %future_address,
  i32 0,
  i32 TARGET,
  i32 STREAM,
  i32 1)
```

参数映射：

| 参数 | 本方案取值 | 含义 |
|---|---:|---|
| `isWrite` | `0` | 数据读预取 |
| `target` | `0/1/2` | 分别对应 L1/L2/L3 |
| `isStream` | `0/1` | 分别对应 KEEP/STRM |
| `isData` | `1` | 预取数据而非指令 |

典型映射为：

| 决策 | 典型 AArch64 汇编提示 |
|---|---|
| L1 + KEEP | `prfm pldl1keep, [address]` |
| L1 + STRM | `prfm pldl1strm, [address]` |
| L2 + KEEP | `prfm pldl2keep, [address]` |
| L2 + STRM | `prfm pldl2strm, [address]` |
| L3 + KEEP | `prfm pldl3keep, [address]` |
| L3 + STRM | `prfm pldl3strm, [address]` |

最终一般表现为 `PRFM`，但具体地址模式也可能使后端选择等价的 `PRFUM`。方案应检查语义提示 `PLDLxKEEP/STRM`，不能只检查助记符名称。

pass 直接构造 `Intrinsic::aarch64_prefetch` declaration 和 call，不需要自定义 op，也不需要额外的 MLIR lowering。

### 步骤 6：接入原始 Clang 编译流程

目标是让用户继续编译原始 `stencil_sme_kernels.c`，而非维护第二份结构化 kernel。

建议分两个阶段接入：

1. **独立验证阶段**：使用 `clang -emit-llvm` 和 `opt -passes='function(stencil-prefetch)'`，便于查看 pass 前后 IR。
2. **Clang 插件阶段**：使用 `-fpass-plugin` 加载插件，并在 `PassBuilder` 的 optimizer extension point 注册。

注册点需要位于循环和 GEP 已经规范化、但地址关系尚未被过度改写的阶段。推荐先在显式 `-O2/-O3` pipeline 中通过 callback 插入，并用测试确认 pass 前已有 `LoopSimplify`/LCSSA。若 optimizer-early 时 IR 尚未规范化，可改用 pipeline parsing callback 或更靠后的 scalar optimizer callback，而不是把规则绑定到固定 LLVM pass 序号。

示意注册代码：

```cpp
extern "C" LLVM_ATTRIBUTE_WEAK PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION,
    "StencilPrefetchPass",
    LLVM_VERSION_STRING,
    [](PassBuilder &PB) {
      PB.registerPipelineParsingCallback(
        [](StringRef Name, FunctionPassManager &FPM,
           ArrayRef<PassBuilder::PipelineElement>) {
          if (Name != "stencil-prefetch")
            return false;
          FPM.addPass(StencilPrefetchPass());
          return true;
        });

      PB.registerOptimizerEarlyEPCallback(
        [](ModulePassManager &MPM, OptimizationLevel) {
          FunctionPassManager FPM;
          FPM.addPass(StencilPrefetchPass());
          MPM.addPass(createModuleToFunctionPassAdaptor(
              std::move(FPM)));
        });
    }
  };
}
```

实际开发时只保留一个经过测试的自动注册点，避免同一编译中重复运行并重复插入预取。pass 还应给已插入的 call 加 metadata，或在运行前检查已有 `llvm.aarch64.prefetch`，保证幂等。

### 步骤 7：验证正确性、汇编和性能

#### 7.1 LLVM IR 验证

对 pass 前后 IR 使用 `FileCheck`：

```text
2D5P:
  识别 3 条主要流
  不为 left/center/right 重复预取
  不出现 plane 预取

3D7P:
  识别 5 条主要流
  包含 front/back plane 决策
  L1/L2 和 KEEP/STRM 参数与配置一致

通用:
  llvm.aarch64.prefetch 参数均为合法立即数
  尾部未来地址不会形成 poison
  再次运行 pass 不增加重复 call
```

还要加入负例：普通向量拷贝、不规则 gather、无法证明偏移关系的循环都不应被识别为 stencil。

#### 7.2 汇编验证

```bash
clang -O3 -march=armv9.2-a+sme+sve2 \
  -fpass-plugin=./libStencilPrefetchPass.so \
  stencil_sme_kernels.c -S -o stencil_sme_kernels.s

rg -n 'prfm|prfum|pldl[123](keep|strm)' stencil_sme_kernels.s
```

同时确认原有 SME/SVE 指令和 streaming-mode 边界仍然存在，例如 `smstart/smstop`、谓词 load/store 和向量浮点运算。

#### 7.3 数值正确性

预取不应改变计算结果，但地址构造错误仍可能破坏 IR 或触发 sanitizer/guard-page 问题。至少覆盖：

1. 最小合法尺寸。
2. 宽度不是 streaming vector length 整数倍。
3. 很短的 row 和很浅的 plane。
4. 2D/3D 边界附近的尾部。
5. pass 开启与关闭时输出逐元素一致。

#### 7.4 性能验证

2D 和 3D 分开扫描：

```text
distance
x cache_level
x KEEP/STRM
x enabled_stream_set
x problem_size
x thread_count
```

至少记录：

1. 总运行时间与有效 stencil 更新率。
2. L1/L2/LLC miss。
3. cache refill、TLB walk 和内存带宽。
4. 软件预取指令数。
5. pass 关闭、仅 A 类、B 类、B+C 类和两级接力的对照。

最终参数必须分别为 2D5P 和 3D7P 保存。3D 的 plane 流不能沿用 2D 的距离和策略。

### 步骤 8：明确高层 MLIR 不作为前置条件

Clang 可生成 LLVM IR，但标准流程不会生成保留 `affine.for`、`memref` 或 `vector.transfer` 语义的高层 MLIR。把 LLVM IR 导入 MLIR 通常只得到 LLVM dialect；循环、数组维度和 stencil 邻域不会自动恢复成 affine/vector MLIR。

另一条路线是实现基于 Clang AST 的 C-to-MLIR lowering，或使用受限 C 前端把特定循环提升为高层 MLIR。但这相当于维护新的前端和大量 C/ACLE 语义映射，对 `arm_sme.h`、`arm_sve.h` intrinsic 尤其复杂，也违背“不结构化改写原始 C kernel”的要求。

因此本项目采用 LLVM pass 作为主线。只有未来需要跨算子 polyhedral 变换、tiling/fusion，且愿意约束输入 C 子集时，才单独评估 C-to-high-level-MLIR；它不是实现软件预取的前置条件。

## 实施里程碑

1. **M1：IR 识别**
   在现有 2D5P/3D7P LLVM IR 上稳定识别最内层循环、3/5 条物理流和 row/plane 类型，不插入指令。

2. **M2：单级预取**
   边分析边插入 L1/L2 `llvm.aarch64.prefetch`，支持 KEEP/STRM、合法未来地址和 cache-line 去重。

3. **M3：Clang 集成**
   通过 `-fpass-plugin` 直接编译原始 C kernel，汇编出现预期 `PRFM PLDLxKEEP/STRM`。

4. **M4：两级与空间块预取**
   支持 plane 的 L2-to-L1 接力和 next-row/next-plane/next-tile warming。

5. **M5：调参与固化**
   分别建立 2D5P、3D7P 的候选参数和 PMU 基准，以目标机器实测结果决定默认策略。
