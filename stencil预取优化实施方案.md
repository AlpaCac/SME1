# SME Stencil 读预取优化实施方案

本文面向 `SME1` 项目中的两个单时间步、常系数 stencil：

1. 2D 5-point（2D5P）
2. 3D 7-point（3D7P）

本文只讨论数据读预取。整体目标是先从 stencil 计算语义中识别独立内存流，再通过自定义 `stencil.prefetch` op 保存缓存层级和 `KEEP/STRM` 策略，最终把预取与 SME 向量计算一起降低到目标代码。

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

两个算子应共享同一套 MLIR 分析框架，但必须分别生成预取决策。尤其不能把 2D 的最优预取距离和流数量直接用于 3D。

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

再换算为 `x` 方向元素距离：

```text
d_elements
  = d_iterations * streaming_vector_length_in_f32
```

未来地址为：

```text
2D:
  address(y + dy, x + d_elements)

3D:
  address(z + dz, y + dy, x + d_elements)
```

其中 `(dz, dy)` 决定当前预取属于当前行、跨行还是跨平面流。

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

其中 `alpha1/alpha2` 可先取 `0.5~0.7`，为真实 load、store、栈和其他线程争用保留空间。

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

这意味着 `StreamInfo` 不一定只生成一个 `stencil.prefetch`；启用两级策略时，可以生成一个远距离 L2 op 和一个近距离 L1 op。

### 2.9 KEEP/STRM 策略选择模型

`KEEP/STRM` 回答“数据进入目标 cache 后是否值得尽量保留”。选择依据不是地址是否连续，而是复用次数和复用距离。

建议为每条流估算：

```text
reuse_count(stream)
reuse_distance_bytes(stream)
```

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

## 第三部分：通过 MLIR 实现预取方案

本部分按照实际开发顺序实现。分析和插入由同一个 pass 完成，不生成 JSON，也不通过外部文件传递决策。

整体流程：

```text
高层 stencil MLIR
-> 规范化并向量化
-> 定义并注册 stencil.prefetch
-> AnalyzeAndInsertStencilPrefetchPass
-> LowerStencilPrefetchToAArch64Pass
-> LLVM IR / AArch64 汇编
-> 正确性与性能验证
```

### 步骤 1：准备可分析的 stencil MLIR

#### 目标

让 2D5P 和 3D7P 在进入预取 pass 时仍保留循环、输入 memref、向量 load 和邻域下标关系。

#### 输入要求

2D5P 函数至少保留：

```mlir
attributes {
  stencil.kind = "2d5p",
  stencil.dimension = 2 : i64,
  stencil.radius = 1 : i64,
  stencil.inner_dimension = 1 : i64
}
```

3D7P 函数至少保留：

```mlir
attributes {
  stencil.kind = "3d7p",
  stencil.dimension = 3 : i64,
  stencil.radius = 1 : i64,
  stencil.inner_dimension = 2 : i64
}
```

最内层 `x` 循环完成 vectorization 后，应能看到：

```text
scf.for / affine.for
vector.transfer_read
vector arithmetic
vector.transfer_write
```

预取 pass 需要能够从每个 `vector.transfer_read` 回溯：

1. 底层输入 memref
2. `memref.subview` 来源
3. 当前 `z/y/x` 下标
4. 相对于输出点的邻域偏移
5. 外层行、平面和 tile 循环

如果 vectorization 后无法从下标表达式恢复邻域偏移，应在 vectorization 前给 load 添加 `stencil.offset` 属性，并让该属性保留到 vector IR。

#### 输出

步骤 1 的输出是仍具有 stencil 访存语义的 vector/scf MLIR，它是集成预取 pass 的直接输入。

### 步骤 2：定义自定义 `stencil.prefetch` op

#### 目标

在 MLIR 中无损保存未来地址、目标 cache 层级以及 `KEEP/STRM` 策略。

标准 `memref.prefetch` 只有抽象 locality，不能精确表达这些信息，因此本方案使用：

```mlir
stencil.prefetch %input[%z, %y, %xp] {
  level = #stencil.cache_level<l2>,
  policy = #stencil.prefetch_policy<keep>,
  stream = "back-plane",
  distance_iterations = 4 : i64
} : memref<?x?x?xf32>
```

#### Op 字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `source` | memref | 输入网格 |
| `indices` | variadic index | 未来预取地址 |
| `level` | enum | `L1/L2/L3` |
| `policy` | enum | `KEEP/STRM` |
| `stream` | string | row、plane 或 tile 流 |
| `distance_iterations` | i64 | 提前的向量迭代次数 |

该 op 只表示数据读预取，不提供 write 模式。

#### TableGen 骨架

```tablegen
def CacheLevelL1 : I32EnumAttrCase<"L1", 0>;
def CacheLevelL2 : I32EnumAttrCase<"L2", 1>;
def CacheLevelL3 : I32EnumAttrCase<"L3", 2>;

def PrefetchKeep : I32EnumAttrCase<"KEEP", 0>;
def PrefetchStrm : I32EnumAttrCase<"STRM", 1>;

def Stencil_PrefetchOp : Stencil_Op<"prefetch"> {
  let arguments = (ins
    AnyMemRef:$source,
    Variadic<Index>:$indices,
    Stencil_CacheLevelAttr:$level,
    Stencil_PrefetchPolicyAttr:$policy,
    StrAttr:$stream,
    I64Attr:$distance_iterations);
}
```

#### Verifier

verifier 检查：

1. indices 数量等于 memref rank
2. indices 均为 `index`
3. `distance_iterations > 0`
4. `level` 和 `policy` 是合法枚举
5. op 具有防止 DCE 删除的 memory effect

地址是否越界由步骤 4 的循环范围或 guard 保证。

#### 输出

完成 dialect 注册，使 `mlir-opt` 能解析、打印和验证 `stencil.prefetch`。

### 步骤 3：在一个 pass 中分析数据流并形成决策

#### Pass

新增：

```text
AnalyzeAndInsertStencilPrefetchPass
```

该 pass 在 vector/scf 层运行，分析结果只保存在 pass 的局部数据结构中。

#### 3.1 收集计算组

以一个 `vector.transfer_write` 为输出根节点，沿 def-use 链收集参与该 stencil 更新的 `vector.transfer_read`。

不能按 load 出现顺序分类，必须比较 source 和 index 表达式。

#### 3.2 识别并合并数据流

2D5P 识别：

```text
( 0,  0) center
( 0, -1) left
( 0, +1) right
(-1,  0) north
(+1,  0) south
```

合并为：

```text
current-row
north-row
south-row
```

3D7P 额外识别：

```text
(-1, 0, 0) front
(+1, 0, 0) back
```

最终合并为：

```text
current-row
north-row
south-row
front-plane
back-plane
```

left、center、right 必须合并，避免同一 cache line 重复预取。

#### 3.3 计算三维决策

每条流形成：

```cpp
struct PrefetchDecision {
  bool enable;
  int64_t distanceIterations;
  CacheLevel level;
  PrefetchPolicy policy;
};
```

依次执行：

```text
chooseDistance
-> chooseCacheLevel
-> choosePolicy
-> fitsCacheAndBandwidthBudgets
```

决策依据来自第二部分：

1. 距离由访问延迟和每次向量迭代周期决定
2. L1/L2/L3 由使用时间窗口和 cache 占用决定
3. KEEP/STRM 由复用次数和复用距离决定
4. 超出容量或带宽预算时关闭低优先级流

第一版通过 pass options 提供初始参数：

```text
--stencil-prefetch-row-distance=2
--stencil-prefetch-plane-near-distance=3
--stencil-prefetch-plane-far-distance=8
--stencil-prefetch-row-level=L1
--stencil-prefetch-plane-near-level=L1
--stencil-prefetch-plane-far-level=L2
--stencil-prefetch-row-policy=KEEP
--stencil-prefetch-plane-near-policy=STRM
--stencil-prefetch-plane-far-policy=KEEP
```

距离为 0 表示关闭对应预取。

#### 输出

pass 不输出 JSON。每得到一条启用决策，就立即进入步骤 4 插入 `stencil.prefetch`。

### 步骤 4：计算未来地址并立即插入预取

#### 4.1 计算未来 `x`

当前内层索引为 `%x`，一次向量迭代处理 `%vl` 个元素，距离为 `%d`：

```mlir
%step = arith.muli %vl, %d : index
%xp = arith.addi %x, %step : index
```

预取必须使用 `%xp`，不能使用真实 load 当前正在访问的 `%x`。

#### 4.2 插入 row 预取

2D/3D 的 north-row：

```mlir
%north = arith.subi %y, %c1 : index
stencil.prefetch %input[%north, %xp] {
  level = #stencil.cache_level<l1>,
  policy = #stencil.prefetch_policy<keep>,
  stream = "north-row",
  distance_iterations = 2 : i64
} : memref<?x?xf32>
```

south-row 使用 `%y + 1`。

#### 4.3 插入 plane 预取

3D 的 front-plane：

```mlir
%front = arith.subi %z, %c1 : index
stencil.prefetch %input[%front, %y, %xp] {
  level = #stencil.cache_level<l1>,
  policy = #stencil.prefetch_policy<strm>,
  stream = "front-plane",
  distance_iterations = 3 : i64
} : memref<?x?x?xf32>
```

back-plane 使用 `%z + 1`。

远距离 plane warming 可在更早位置额外插入 `L2` op，形成：

```text
L2 远距离预热
-> L1 近距离接力
-> 真实 load
```

#### 4.4 边界保护

未来地址必须满足：

```text
xp < width - 1
```

动态边界使用：

```mlir
%valid = arith.cmpi ult, %xp, %width_minus_1 : index
scf.if %valid {
  // stencil.prefetch
}
```

内部区已保证 `y +/- 1`、`z +/- 1` 合法；边界 kernel 默认不插入预取。

#### 4.5 Cache-line 去重

只在 `%xp` 进入新 cache line 时发出预取。对于 64-byte cache line 和 `float32`：

```text
elements_per_line = 16
line_id = xp / 16
```

若当前 line id 与上一向量迭代相同，则跳过本次预取。

#### 输出

步骤 4 输出带 `stencil.prefetch` 的 vector/scf MLIR。`level`、`policy`、`stream` 和距离已经固化在 op 中。

### 步骤 5：Lowering 到 AArch64 预取 intrinsic

#### Pass

新增：

```text
LowerStencilPrefetchToAArch64Pass
```

该 pass 与 memref-to-LLVM conversion 配合：

1. 将 source memref descriptor 和 indices 转换为元素 pointer
2. 读取 `level` 与 `policy`
3. 创建 `llvm.aarch64.prefetch`
4. 删除原 `stencil.prefetch`

#### 属性映射

| 自定义 op | intrinsic 参数 |
|---|---:|
| 数据读 | `isWrite = 0` |
| `L1` | `target = 0` |
| `L2` | `target = 1` |
| `L3` | `target = 2` |
| `KEEP` | `isStream = 0` |
| `STRM` | `isStream = 1` |
| data cache | `isData = 1` |

MLIR 结果形态：

```mlir
llvm.call_intrinsic "llvm.aarch64.prefetch"(
    %ptr, %is_write, %target, %is_stream, %is_data)
    : (!llvm.ptr, i32, i32, i32, i32) -> ()
```

最终 AArch64 汇编应出现：

```asm
prfm pldl1keep, [address]
prfm pldl1strm, [address]
prfm pldl2keep, [address]
prfm pldl2strm, [address]
```

非 AArch64 目标应报错或保留自定义 op，不能静默降低为语义较弱的通用预取。

### 步骤 6：接入 pass pipeline 并验证

#### Pipeline

```text
stencil normalization
-> vectorization
-> analyze-and-insert-stencil-prefetch
-> SME lowering
-> lower-stencil-prefetch-to-aarch64
-> memref/func/arith to LLVM
-> LLVM IR translation
```

实际 conversion 中，`LowerStencilPrefetchToAArch64Pass` 应与 memref descriptor 转换放在同一轮，确保既能读取自定义属性，又能得到 LLVM pointer。

#### IR 验证

2D5P：

1. 识别 3 条合并流
2. 不出现 plane 预取
3. row 预取使用未来 `%xp`

3D7P：

1. 识别 5 条合并流
2. front/back 可独立配置
3. L1/L2 两级 plane 预取属性正确

共同检查：

1. 没有 JSON 输入输出
2. 没有 `memref.prefetch`
3. 所有未来地址都有合法边界
4. lowering 后出现 `llvm.aarch64.prefetch`
5. 汇编中的 `pldl{1|2|3}{keep|strm}` 与自定义 op 一致

#### 正确性与性能验证

预取版本必须与无预取 baseline 数值一致。性能测试至少扫描：

1. 距离 `1/2/4/8`
2. 近距离 `L1/L2`
3. 远距离 `L2/L3`
4. `KEEP/STRM`

记录：

1. cell updates/s
2. 总周期
3. L1/L2/LLC miss
4. TLB miss
5. memory bandwidth
6. 指令数

完成标准：

```text
能够从 2D5P/3D7P vector IR 自动识别数据流
-> 在同一 pass 中立即插入合法 stencil.prefetch
-> 精确降低为 llvm.aarch64.prefetch
-> 汇编生成对应 PRFM
-> 数值正确且具备可重复的性能数据
```
