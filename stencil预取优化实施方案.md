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

### 2.8 2D 与 3D 的推荐初始策略

2D5P：

```text
A 连续维：默认关闭，作为对照实验
B 跨行：默认开启，近距离预取 north/south
C 跨平面：不适用
D 下一块：先实现 next-row，再评估空间 tile
```

3D7P：

```text
A 连续维：默认关闭，作为对照实验
B 跨行：开启
C 跨平面：优先实现并单独扫描距离
D 下一块：实现 plane/tile prefetch frontier
```

## 第三部分：通过 MLIR 实现预取方案

### 3.1 总体编译流程

建议使用一个“边分析、边决策、边插入”的集成 pass，不生成 JSON，也不把分析结果交给另一个注入 pass：

```text
stencil C / 高层 MLIR
-> scf / affine-normalized 循环
-> vectorization / SME mapping
-> AnalyzeAndInsertStencilPrefetchPass
   1. 识别维度、邻域偏移和独立内存流
   2. 在 pass 内存中计算 enable/level/policy/distance
   3. 立即计算未来地址并插入 stencil.prefetch
-> Arm SME lowering
-> LLVM dialect
-> llvm.aarch64.prefetch
-> 目标汇编与性能验证
```

集成 pass 在 vector/scf 层运行：这一层仍保留循环、memref 来源和下标关系，同时已经知道一次向量迭代消费多少元素。pass 可以回溯 `vector.transfer_read` 的 source、indices、`memref.subview` 和外围循环，恢复 stencil 邻域关系。

如果前序 vectorization 会丢失邻域 offset，应该在 vectorization 时把 offset 作为 op attribute 保留在相应 `vector.transfer_read` 上；该 attribute 属于 IR 语义的一部分，不是分析与插入之间的外部传递文件。

### 3.2 高层 MLIR 表达

2D5P 可先表达为：

```mlir
func.func @stencil_2d5p(
    %input: memref<?x?xf32>,
    %output: memref<?x?xf32>,
    %height: index,
    %width: index,
    %wc: f32,
    %wa: f32) {
  affine.for %y = 1 to %height_minus_1 {
    affine.for %x = 1 to %width_minus_1 {
      %c = affine.load %input[%y, %x] : memref<?x?xf32>
      %l = affine.load %input[%y, %x - 1] : memref<?x?xf32>
      %r = affine.load %input[%y, %x + 1] : memref<?x?xf32>
      %n = affine.load %input[%y - 1, %x] : memref<?x?xf32>
      %s = affine.load %input[%y + 1, %x] : memref<?x?xf32>
      // 乘加后写入 output[y, x]
    }
  }
  return
}
```

3D7P 在此基础上增加 `%z` 循环和两个 load：

```mlir
%f = affine.load %input[%z - 1, %y, %x] : memref<?x?x?xf32>
%b = affine.load %input[%z + 1, %y, %x] : memref<?x?x?xf32>
```

建议在函数上保留显式属性：

```mlir
attributes {
  stencil.dimension = 2 : i64,
  stencil.radius = 1 : i64,
  stencil.kind = "2d5p",
  stencil.layout = "row-major",
  stencil.inner_dimension = 1 : i64
}
```

3D7P 使用 `dimension = 3`、`kind = "3d7p"`、`inner_dimension = 2`。

### 3.3 集成 pass 的邻域识别

`AnalyzeAndInsertStencilPrefetchPass` 遍历同一输出 store 所依赖的所有输入 load，并把 load 下标与输出下标相减。实际在 vector IR 中，应对 `vector.transfer_read` 和 `vector.transfer_write` 做相同的来源与 index 表达式比较。

2D5P 期望识别：

```text
(dy, dx):
( 0,  0) center
( 0, -1) left
( 0, +1) right
(-1,  0) north
(+1,  0) south
```

3D7P 期望识别：

```text
(dz, dy, dx):
( 0,  0,  0) center
( 0,  0, -1) left
( 0,  0, +1) right
( 0, -1,  0) north
( 0, +1,  0) south
(-1,  0,  0) front
(+1,  0,  0) back
```

识别后按 cache-line 流合并：

```text
2D:
  (0, 0/-1/+1) -> current-row
  (-1, 0)       -> north-row
  (+1, 0)       -> south-row

3D:
  (0, 0, 0/-1/+1) -> current-row
  (0, -1, 0)       -> north-row
  (0, +1, 0)       -> south-row
  (-1, 0, 0)       -> front-plane
  (+1, 0, 0)       -> back-plane
```

这些流信息只保存在当前 pass 的局部数据结构中。完成一组 load 的识别后，pass 立即为该组流做决策并插入自定义 op，不输出外部文件，也不等待后续 pass。不能继续采用现有 pass 中“按 rank-1 `vector.transfer_read` 出现顺序猜对象”的方式。

### 3.4 Pass 内部数据结构与即时决策

pass 内部使用 C++ 结构体保存临时分析结果：

```cpp
enum class StreamKind {
  CurrentRow,
  NorthRow,
  SouthRow,
  FrontPlane,
  BackPlane,
  NextRow,
  NextPlane,
  NextTile
};

enum class CacheLevel { L1, L2, L3 };
enum class PrefetchPolicy { Keep, Strm };

struct StreamInfo {
  StreamKind kind;
  SmallVector<int64_t> neighborOffset;
  Value source;
  SmallVector<Value> currentIndices;
  scf::ForOp innerLoop;
};

struct PrefetchDecision {
  bool enable;
  CacheLevel level;
  PrefetchPolicy policy;
  int64_t distanceIterations;
};
```

对每个 stencil 内层循环，pass 按以下顺序执行：

1. 收集同一计算组中的所有输入 `vector.transfer_read`
2. 根据下标差识别 2D 的 3 条流或 3D 的 5 条流
3. 合并 left/center/right 等价 cache-line 流
4. 对每个 `StreamInfo` 调用 `decidePrefetch(stream, loopContext)`
5. 如果 `enable = true`，立即生成未来索引、边界 guard 和 `stencil.prefetch`
6. 继续处理下一条流或下一个内层循环

第一版决策可以直接由 pass options 和静态启发式驱动：

```text
--stencil-prefetch-inner-distance=0
--stencil-prefetch-row-distance=2
--stencil-prefetch-plane-distance=3
--stencil-prefetch-tile-distance=1
--stencil-prefetch-row-level=L1
--stencil-prefetch-plane-level=L1
--stencil-prefetch-tile-level=L2
--stencil-prefetch-policy=KEEP
```

其中距离为 0 表示关闭该类预取。实验扫描 `1/2/4/8` 次向量迭代时，直接改变 pass option 并重新编译，不再生成或编辑中间 JSON。

分析与插入在一次 pass 运行中完成，但决策仍会固化在新生成的 `stencil.prefetch` 属性中，供后续 lowering 和调试使用。

### 3.5 为什么必须使用自定义 `stencil.prefetch`

标准 `memref.prefetch` 只能表达：

1. read 或 write
2. `locality<0..3>` 抽象局部性
3. data 或 instruction cache

其中 `locality` 不是目标缓存层级，不能精确表达 `L1/L2/L3`；标准 op 也没有独立的 `KEEP/STRM` 字段。如果把 `L1 + KEEP` 和 `L2 + STRM` 都压缩成 `locality`，中间层就无法无损保存预取决策。

因此 stencil 主线不再使用 `memref.prefetch`，而是定义：

```mlir
stencil.prefetch %input[%z, %y, %xp] {
  level = #stencil.cache_level<l2>,
  policy = #stencil.prefetch_policy<keep>,
  stream = "back-plane",
  distance_iterations = 4 : i64
} : memref<?x?x?xf32>
```

该 op 只表示数据读预取，不提供 read/write 开关。建议包含以下字段：

| 字段 | 类型 | 作用 |
|---|---|---|
| `source` | memref | 被预取的数据对象 |
| `indices` | variadic index | 未来合法地址 |
| `level` | enum `L1/L2/L3` | 精确目标缓存层级 |
| `policy` | enum `KEEP/STRM` | 精确保留或流式策略 |
| `stream` | string | current-row、north-row、front-plane 等 |
| `distance_iterations` | i64 | 提前的向量迭代次数 |

`level` 和 `policy` 必须是编译期枚举属性，因为后续 AArch64 intrinsic 的对应参数要求立即数。

TableGen 设计可采用：

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

op verifier 至少检查：

1. `indices` 数量等于 memref rank
2. 所有下标类型都是 `index`
3. `distance_iterations > 0`
4. `stream` 属于集成 pass 已识别的数据流
5. op 位于可证明地址合法的区域，或受 `scf.if` guard 控制
6. op 带有适当 memory effect，不能被 DCE 当成无效纯操作删除

### 3.6 Vector 层计算未来地址

假设 vector 层的当前内层索引为 `%x`，一次处理 `%vl` 个 `f32` 元素，预取距离为 `%d` 次向量迭代：

```mlir
%step = arith.muli %vl, %d : index
%xp = arith.addi %x, %step : index
%valid = arith.cmpi ult, %xp, %width_minus_1 : index
scf.if %valid {
  stencil.prefetch %input[%y, %xp] {
    level = #stencil.cache_level<l1>,
    policy = #stencil.prefetch_policy<keep>,
    stream = "current-row",
    distance_iterations = 2 : i64
  } : memref<?x?xf32>
}
```

2D 跨行预取：

```mlir
%north = arith.subi %y, %c1 : index
%south = arith.addi %y, %c1 : index

stencil.prefetch %input[%north, %xp] {
  level = #stencil.cache_level<l1>,
  policy = #stencil.prefetch_policy<keep>,
  stream = "north-row",
  distance_iterations = 2 : i64
} : memref<?x?xf32>

stencil.prefetch %input[%south, %xp] {
  level = #stencil.cache_level<l1>,
  policy = #stencil.prefetch_policy<keep>,
  stream = "south-row",
  distance_iterations = 2 : i64
} : memref<?x?xf32>
```

3D 跨平面预取：

```mlir
%front = arith.subi %z, %c1 : index
%back = arith.addi %z, %c1 : index

stencil.prefetch %input[%front, %y, %xp] {
  level = #stencil.cache_level<l1>,
  policy = #stencil.prefetch_policy<keep>,
  stream = "front-plane",
  distance_iterations = 3 : i64
} : memref<?x?x?xf32>

stencil.prefetch %input[%back, %y, %xp] {
  level = #stencil.cache_level<l1>,
  policy = #stencil.prefetch_policy<keep>,
  stream = "back-plane",
  distance_iterations = 3 : i64
} : memref<?x?x?xf32>
```

这里的关键是预取 `%xp`，而不是预取当前真实 load 正在访问的 `%x`。如果仍对 `%x` 插入预取，通常已经太晚。

### 3.7 Cache-line 去重

假设 cache line 为 64 字节，`float32` 每行包含 16 个元素。只在未来地址进入新 cache line 时发出预取：

```text
line(xp) != line(xp - vector_step)
```

MLIR 可通过整数除法或位移计算 line id：

```mlir
%line = arith.divui %xp, %c16 : index
%prev_xp = arith.subi %xp, %vl : index
%prev_line = arith.divui %prev_xp, %c16 : index
%new_line = arith.cmpi ne, %line, %prev_line : index
```

只有 `%new_line` 为真时才插入/执行预取。若 vector step 本身大于等于 cache-line 元素数，可以省略该动态判断，由编译期调度控制每次迭代的预取数量。

### 3.8 边界与尾部

预取未来地址必须满足：

```text
1 <= xp < width - 1
1 <= y + dy < height - 1 或位于合法输入边界
1 <= z + dz < depth - 1 或位于合法输入边界
```

当前两个 kernel 的主循环只处理内部点，因此 `y +/- 1`、`z +/- 1` 的真实邻域 load 合法。但 `xp = x + distance` 可能超过行尾，必须 guard。

推荐把执行结构拆成：

1. 无预取或有 guard 的边界区
2. 可证明地址合法的内部预取主循环
3. 使用 predicate 的向量尾部

不要因为目标预取指令通常不触发异常，就在 MLIR 中构造越界 memref 下标。

### 3.9 下一行、平面和 tile 的远距离注入

远距离预取需要观察外层循环，不能只匹配单个 `vector.transfer_read`。

2D next-row：

```text
当前处理 row y 的后半段
-> 预取 row y + 2 的首批内部 cache line
-> 下一轮处理 row y + 1 时，该行将作为 south 邻居使用
```

3D plane frontier：

```text
当前处理 (z, y, x)
-> 按相同 y/x 前沿预取 z + 2 平面的数据
-> 下一轮进入 z + 1 后，该数据成为 back 邻居
```

如果做空间 tiling，则在当前 tile 剩余计算周期足以覆盖下一 tile 延迟时，预取下一 tile 的首批内部行。需要限制每次只预热少量 cache line，不能一次展开整个 tile 的预取。

### 3.10 与 SME lowering 的顺序

推荐顺序：

```text
stencil 规范化
-> vectorization
-> vector/scf 层边分析边插入
-> SME lowering
-> memref/LLVM lowering
```

这样做的原因是：

1. 不需要维护 JSON schema、文件路径和解析器
2. 分析结果不会与已经变化的 IR 失配
3. vector 层已经知道一次迭代的实际数据宽度
4. 识别一条流后可以直接使用当前 SSA value 构造未来地址
5. 自定义 op 能在 SME lowering 期间完整保留 level 和 policy

当前 `03_prefetch_injection/passes/InjectVectorPrefetch.cpp` 需要重构：

1. 删除 `loadAnalysisDecisions`、JSON 字段解析和固定对象结构
2. pass 重命名为 `AnalyzeAndInsertStencilPrefetchPass`
3. 新增 `StreamInfo` 收集、邻域 offset 恢复和流合并
4. 新增基于 pass options 的 `decidePrefetch`
5. 识别一条流后立即计算未来索引并插入 `stencil.prefetch`
6. 增加边界 guard 和 cache-line 去重
7. 3D 增加 plane stream 与外层 frontier 分析
8. 不再创建 `memref::PrefetchOp`

### 3.11 自定义 op 的 AArch64 lowering

新增 `LowerStencilPrefetchToAArch64Pass`，并把它放入 memref-to-LLVM 的同一轮 dialect conversion。conversion pattern 接收已经由 type converter 转换的 memref descriptor，在删除 `stencil.prefetch` 前计算元素 pointer 并读取自定义属性。

lowering 分两步：

1. 使用转换后的 memref descriptor、strides 和 indices 计算预取元素的 LLVM pointer
2. 把枚举属性转换成 AArch64 intrinsic 的立即数参数

精确映射为：

| `stencil.prefetch` | `llvm.aarch64.prefetch` 参数 |
|---|---:|
| 数据读 | `isWrite = 0` |
| `L1` | `target = 0` |
| `L2` | `target = 1` |
| `L3` | `target = 2` |
| `KEEP` | `isStream = 0` |
| `STRM` | `isStream = 1` |
| data cache | `isData = 1` |

例如 `L2 + STRM` 降为：

```mlir
%is_write = llvm.mlir.constant(0 : i32) : i32
%target_l2 = llvm.mlir.constant(1 : i32) : i32
%is_stream = llvm.mlir.constant(1 : i32) : i32
%is_data = llvm.mlir.constant(1 : i32) : i32

llvm.call_intrinsic "llvm.aarch64.prefetch"(
    %ptr, %is_write, %target_l2, %is_stream, %is_data)
    : (!llvm.ptr, i32, i32, i32, i32) -> ()
```

这一路径不能替换成通用 `llvm.prefetch`，因为通用 intrinsic 同样不能无损承载精确的目标层级和 `KEEP/STRM`。

对于非 AArch64 目标，pass 应明确报错或保留 `stencil.prefetch`，不能静默降成语义较弱的通用预取。

### 3.12 Lowering 与验证

预取 lowering 主线：

```text
stencil.prefetch
-> llvm.call_intrinsic "llvm.aarch64.prefetch"
-> 精确的 L1/L2/L3 + KEEP/STRM 读预取
```

每个阶段都要验证：

1. affine 分析结果中，2D 是 3 条合并流，3D 是 5 条合并流
2. vector IR 中预取地址使用未来索引 `%xp`
3. 边界 guard 存在且没有越界 memref
4. 2D 不出现 plane 预取
5. 3D 的 front/back 预取可独立开关
6. `stencil.prefetch` 的 level/policy 在 lowering 前保持不变
7. LLVM dialect 中出现 `llvm.aarch64.prefetch`
8. 最终目标代码中的层级和 KEEP/STRM 与自定义 op 一致
9. 最终汇编同时保留 SME 向量计算和读预取
10. 数值结果与无预取 baseline 一致

性能实验至少包含：

```text
2D5P:
  baseline
  A-inner
  B-row
  A+B
  B+D-next-row

3D7P:
  baseline
  B-row
  C-plane
  B+C
  B+C+D-plane-frontier
```

每组扫描 `1/2/4/8` 次向量迭代的距离，并记录：

1. cell updates/s
2. 总周期
3. L1/L2/LLC miss
4. TLB miss
5. memory bandwidth
6. 指令数
7. 单核与多核扩展效率

第一阶段的完成标准是：正确识别 2D/3D 数据流，预取使用未来合法地址，并能稳定降低到最终目标代码。第二阶段才根据 PMU 数据选择每个算子的默认流和距离。
