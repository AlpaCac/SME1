# 04 预取参数映射说明

这份文档说明第四步中涉及的多层预取表示：

1. `research.prefetch`
2. `affine.prefetch`
3. `llvm.intr.prefetch`
4. LLVM IR `.ll` 中的 `@llvm.prefetch`
5. AArch64 汇编中的 `prfm`

重点回答三个问题：

1. 每一层支持哪些预取参数
2. 从高层往低层转换时哪些信息会被保留
3. 哪些研究信息会丢失，以及后续如何解决

---

## 1. 多层预取表示的定位

可以把三者理解成从“研究语义”逐步走向“目标可执行语义”的过程。

```text
research.prefetch
-> affine.prefetch
-> memref.prefetch
-> llvm.intr.prefetch / llvm.prefetch
-> LLVM IR @llvm.prefetch
-> AArch64 prfm
```

其中：

- `research.prefetch`
  - 位于第三步
  - 用来完整保存第二步 cost module 给出的高层预取决策
- `affine.prefetch`
  - 位于第四步前半段
  - 是 MLIR Affine dialect 中已有的标准预取 op
- `llvm.intr.prefetch`
  - 位于 LLVM dialect / LLVM IR 层
  - 接近最终 LLVM intrinsic
- `@llvm.prefetch`
  - 位于导出的 LLVM IR `.ll` 文件中
  - 是 LLVM intrinsic 的文本 IR 形式
- `prfm`
  - 位于 AArch64 汇编层
  - 是最终目标指令形式之一

越往低层，表示越接近机器能识别的形式；但同时，高层研究信息也会逐渐被压缩。

---

## 2. research.prefetch 支持的参数

第三步中使用的 `research.prefetch` 现在由第 03 步插件注册为 `research` dialect 中的动态 op，但它仍然采用 MLIR generic assembly 形式打印，不是 MLIR 官方标准 op。

第 04 步不再重复注册 `research` dialect，而是通过加载第 03 步插件解析该 op，再用第 04 步 C++ MLIR pass 将它桥接到标准 `affine.prefetch`。

当前形式如下：

```mlir
"research.prefetch"(%b, %ko, %j, %jj, %kk) <{
  target = "B", kind = "read", priority = "high",
  cache = "L1", locality = "KEEP",
  distance = "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界"
}> : (memref<?x?xf32>, index, index, index, index) -> ()
```

它支持的参数可以分成两类。

## 2.1 操作数

```mlir
(%b, %ko, %j, %jj, %kk)
```

这些操作数用于保存预取对象和循环上下文。

- `%b`
  - 表示预取对象来自矩阵 `B`
- `%ko`
  - 表示当前归约宏块起点
- `%j`
  - 表示当前列宏块起点
- `%jj`
  - 表示当前列微块起点
- `%kk`
  - 表示当前归约维内部位置

这些值不是最终物理地址，而是高层语义定位信息。  
后续 pass 可以利用它们恢复或计算具体预取地址。

## 2.2 属性参数

`research.prefetch` 当前保存的属性包括：

- `target`
  - 预取对象，例如 `A` / `B` / `C`
- `kind`
  - 预取类型，例如 `read` / `write`
- `priority`
  - 研究模型中的优先级，例如 `high` / `medium` / `low`
- `cache`
  - 期望目标缓存层级，例如 `L1`
- `locality`
  - 局部性策略，例如 `KEEP` / `STRM`
- `distance`
  - 预取距离策略，可以是自然语言或模型描述

这些字段的价值在于：

- 能记录“为什么预取”
- 能记录“预取谁”
- 能记录“按什么策略预取”
- 能保留 cost module 的高层决策结果

因此，`research.prefetch` 是信息最丰富的一层。

---

## 3. affine.prefetch 支持的参数

第四步中会先把 `research.prefetch` 桥接为标准 `affine.prefetch`。

典型形式如下：

```mlir
affine.prefetch %b[%ko + %kk, %j + %jj], read, locality<3>, data : memref<?x?xf32>
```

`affine.prefetch` 支持的核心参数是：

- 预取对象
  - 例如 `%b`
- 预取下标
  - 例如 `[%ko + %kk, %j + %jj]`
- 读写类型
  - `read` 或 `write`
- locality hint
  - `locality<0>` 到 `locality<3>`
- cache type
  - `data` 或 `instr`
- memref 类型
  - 例如 `memref<?x?xf32>`

## 3.1 预取对象和下标

```mlir
%b[%ko + %kk, %j + %jj]
```

这一部分已经比 `research.prefetch` 更接近真实预取地址。

它不再只是说：

```text
预取 B，并携带 ko/j/jj/kk 上下文
```

而是直接表达：

```text
预取 B[ko + kk, j + jj]
```

## 3.2 read / write

```mlir
read
```

表示读预取。

如果是写预取，则可以写成：

```mlir
write
```

当前仓库中 A/B 都是读流，所以使用 `read`。

## 3.3 locality

```mlir
locality<3>
```

`locality` 是一个数值 hint，范围通常是 `0` 到 `3`。

- `locality<0>`
  - 表示低时间局部性，更接近 streaming
- `locality<3>`
  - 表示高时间局部性，希望数据保留在 cache 中

当前第四步把第三步中的：

```mlir
locality = "KEEP"
```

映射为：

```mlir
locality<3>
```

## 3.4 data / instr

```mlir
data
```

表示这是数据预取。

另一种可能是：

```mlir
instr
```

表示指令预取。

当前 GEMM 场景预取的是矩阵数据，所以使用 `data`。

---

## 4. llvm.intr.prefetch / llvm.prefetch 支持的参数

继续 lowering 到 LLVM 层后，会接近 LLVM intrinsic：

```llvm
declare void @llvm.prefetch.p0(ptr, i32, i32, i32)
```

其典型形式可以理解为：

```text
llvm.prefetch(address, rw, locality, cache_type)
```

四个参数分别是：

- `address`
  - 要预取的最终内存地址
- `rw`
  - `0` 表示 read
  - `1` 表示 write
- `locality`
  - `0` 到 `3`
  - `0` 表示没有时间局部性
  - `3` 表示最高时间局部性
- `cache_type`
  - `0` 表示 instruction cache
  - `1` 表示 data cache

例如，一个“读数据、最高局部性”的预取可以理解为：

```llvm
call void @llvm.prefetch.p0(ptr %addr, i32 0, i32 3, i32 1)
```

这一层已经很低层：

- 不再知道矩阵名是 `A` 还是 `B`
- 不再知道 `ko / kk / jj` 的高层循环含义
- 不再知道 cost module 中的原因
- 只知道对某个地址发出预取 hint

---

## 5. 核心参数对照表

| 高层语义 | `research.prefetch` | `affine.prefetch` | `llvm.prefetch` |
|---|---|---|---|
| 预取对象 | `target = "A"` / `"B"` | 体现在 memref 名和下标中 | 只剩最终地址 |
| 读写类型 | `kind = "read"` / `"write"` | `read` / `write` | `rw = 0 / 1` |
| 优先级 | `priority = "high"` / `"medium"` | 不支持 | 不支持 |
| 缓存层级 | `cache = "L1"` | 不直接支持明确 L1/L2/L3 | 不直接支持明确 L1/L2/L3 |
| 局部性策略 | `locality = "KEEP"` / `"STRM"` | `locality<0..3>` | `locality = 0..3` |
| 预取距离 | `distance = "..."` | 体现在注入位置和下标偏移中 | 体现在最终地址计算中 |
| 数据/指令 | 可扩展字段 | `data` / `instr` | `cache_type = 1 / 0` |
| 决策原因 | 可扩展字段保存 | 不支持 | 不支持 |
| 循环上下文 | 操作数中保留 `ko/j/jj/kk` | 折叠进 affine 下标表达式 | 折叠进地址计算 |

---

## 6. 从 research.prefetch 到 affine.prefetch 会丢失什么

当前第四步把 `research.prefetch` 转成 `affine.prefetch` 后，能保留下来的主要是：

- 预取对象对应的 memref
- 预取地址或下标
- `read` / `write`
- `locality`
- `data` / `instr`

但会丢失或压缩下面这些信息：

- `target = "A" / "B"`
  - 变成了 memref 名和下标，不再作为显式属性保留
- `priority = "high" / "medium"`
  - `affine.prefetch` 没有这个字段
- `cache = "L1"`
  - 标准 `affine.prefetch` 不显式指定 L1/L2/L3
- `distance = "..."`
  - 只能体现在插入位置或下标偏移中
- cost module 的决策原因
  - 标准 op 不保存原因

因此，`affine.prefetch` 更适合做 lowering，而不是保存完整研究决策。

---

## 7. 从 affine.prefetch 到 llvm.prefetch 会进一步丢失什么

当继续 lowering 到 LLVM 层时，信息会进一步收缩。

保留下来的主要是：

- 最终地址
- read/write 数值
- locality 数值
- data/instruction cache 类型

继续丢失的是：

- memref 的高层形状
- affine 下标表达式
- tensor 名称
- tile 层次
- 循环变量语义
- cost module 上下文

这也是为什么本课题强调：

- 决策要尽量在高层做
- 高层研究信息要尽量在 lowering 前保存

---

## 8. LLVM IR .ll 中的预取表示

第四步生成的 MLIR 继续通过 `mlir-translate --mlir-to-llvmir` 导出后，会在 `.ll` 文件中出现 LLVM intrinsic 调用。

当前仓库中的例子位于：

- [05_native_build_run/output/09_unified_llvm_prefetch.ll](/Users/alpaca/Documents/SME/SME1/05_native_build_run/output/09_unified_llvm_prefetch.ll)

其中可以看到类似语句：

```llvm
call void @llvm.prefetch.p0(ptr %94, i32 0, i32 3, i32 1)
call void @llvm.prefetch.p0(ptr %117, i32 0, i32 3, i32 1)
```

以及声明：

```llvm
declare void @llvm.prefetch.p0(ptr readonly captures(none), i32 immarg, i32 immarg, i32 immarg)
```

这里的四个实参含义是：

- `ptr %94` / `ptr %117`
  - 最终要预取的地址
- `i32 0`
  - `rw = 0`，表示读预取
- `i32 3`
  - `locality = 3`，表示最高时间局部性
- `i32 1`
  - `cache_type = 1`，表示 data cache

也就是说，`.ll` 层已经完全进入 LLVM intrinsic 语义：

```text
@llvm.prefetch(address, rw, locality, cache_type)
```

这一层相对 `llvm.intr.prefetch` MLIR 又少了一些 MLIR 层结构信息。  
例如：

- 不再有 MLIR op attribute 的形式
- 不再知道这是从 `affine.prefetch` 还是 `memref.prefetch` 来的
- 只剩 LLVM IR 中的函数调用和地址计算

但 `.ll` 层仍然保留了 LLVM 后端需要的关键预取参数：

- 地址
- 读写
- locality
- data/instruction cache 类型

---

## 9. 汇编级预取表示

LLVM 后端继续把 `.ll` 编译为目标对象或汇编后，在 AArch64 上会生成 `prfm` 指令。

当前本机对象文件反汇编中可以看到类似结果：

```asm
prfm pldl1keep, [x13, x12]
prfm pldl1keep, [x13, x12]
```

这里的 `prfm` 是 AArch64 的 prefetch memory 指令。

以：

```asm
prfm pldl1keep, [x13, x12]
```

为例，可以拆成两部分：

- `pldl1keep`
  - prefetch load
  - 目标是 L1 data cache
  - `keep` 表示希望保留局部性
- `[x13, x12]`
  - 最终地址表达式
  - 由 LLVM 后端根据前面的地址计算选择寄存器寻址形式

这里要注意：

- 汇编层已经不再知道 `A` / `B` / `C`
- 也不知道 `ko`、`jj`、`kk` 这些循环变量的高层名字
- 更不知道 cost module 的决策原因

但它保留了目标机器真正执行或解释的预取 hint：

- load 还是 store 方向
- cache 层级 hint
- keep 或 stream 风格
- 最终地址

---

## 10. research.prefetch 如何逐步降到汇编

当前仓库中的完整链路可以概括为：

```text
research.prefetch
-> affine.prefetch
-> memref.prefetch
-> llvm.intr.prefetch
-> LLVM IR @llvm.prefetch.p0
-> AArch64 prfm
```

每一级的作用不同，信息也逐级收缩。

| 阶段 | 示例 | 保留的信息 | 丢失或压缩的信息 |
|---|---|---|---|
| `research.prefetch` | `"research.prefetch"(%b, %ko, %j, %jj, %kk) <{...}>` | target、kind、priority、cache、locality、distance、循环上下文 | 暂无明显丢失，是信息最丰富层 |
| `affine.prefetch` | `affine.prefetch %b[%ko + %kk, %j + %jj], read, locality<3>, data` | memref、affine 下标、read/write、locality、data/instr | priority、决策原因、显式 target 属性、自然语言 distance、明确 cache 层级 |
| `memref.prefetch` | `memref.prefetch %subview[%c0], read, locality<3>, data` | memref/subview、索引、read/write、locality、data/instr | affine 映射结构进一步弱化，高层 tile 语义更不明显 |
| `llvm.intr.prefetch` | `"llvm.intr.prefetch"(%84) <{cache = 1, hint = 3, rw = 0}>` | LLVM 指针、rw、hint、cache type | memref 形状、affine 下标、tensor 名称、循环语义 |
| LLVM IR `.ll` | `call void @llvm.prefetch.p0(ptr %94, i32 0, i32 3, i32 1)` | 地址、rw、locality、cache type | MLIR op 属性和 dialect 层语义 |
| 汇编 | `prfm pldl1keep, [x13, x12]` | 目标机器 hint、地址寄存器、load/store/cache/keep 风格 | LLVM intrinsic 形式、高层循环、cost module 信息 |

---

## 11. 信息在哪一级丢失

更具体地看，信息丢失主要发生在以下几个节点。

## 11.1 research.prefetch -> affine.prefetch

这是高层研究信息丢失最多的一步。

丢失或压缩的信息包括：

- `priority`
- `distance` 的自然语言描述
- `target_cache = "L1"` 这类显式字段
- cost module 的 reason
- `target = "A" / "B"` 作为属性的显式存在形式

保留下来的信息包括：

- 预取对象对应的 memref
- 预取下标
- `read`
- `locality<3>`
- `data`

这一层的本质变化是：

```text
高层决策记录
-> 标准预取动作
```

## 11.2 affine.prefetch -> memref.prefetch

这一层主要丢失的是 affine 层的结构化表达能力。

保留下来的信息包括：

- memref 或 subview
- 具体索引
- read/write
- locality
- data/instr

弱化的信息包括：

- affine map 的显式结构
- 原始分块循环和下标表达式的可读性

## 11.3 memref.prefetch -> llvm.intr.prefetch

这一层开始进入 LLVM dialect，丢失的是 memref 级信息。

丢失的信息包括：

- memref 的维度
- stride / offset 的高层可读形式
- subview 语义
- 矩阵对象身份

保留下来的信息包括：

- 最终 LLVM 指针
- `rw`
- `hint`
- `cache`

## 11.4 llvm.intr.prefetch -> LLVM IR .ll

这一层主要是表示形式变化。

保留下来的信息包括：

- `ptr`
- `rw`
- `locality`
- `cache_type`

丢失或弱化的信息包括：

- MLIR dialect op 名称
- MLIR attribute 语法
- MLIR 类型系统中的部分结构

## 11.5 LLVM IR .ll -> 汇编 prfm

这一层进入目标后端选择。

保留下来的信息包括：

- 最终地址
- load/store hint
- L1/data/keep 等目标 hint

丢失的信息包括：

- LLVM intrinsic 调用形式
- SSA 值名
- 高层矩阵对象
- 循环结构语义
- cost module 上下文

---

## 12. 如何解决信息丢失问题

可以考虑三种方式。

## 12.1 方式一：保留旁路 metadata

在把 `research.prefetch` 转成 `affine.prefetch` 时，同时保留一份旁路信息。

例如：

```mlir
affine.prefetch %b[%ko + %kk, %j + %jj], read, locality<3>, data
  : memref<?x?xf32>
```

同时在函数或 module 属性中保存：

```mlir
prefetch.metadata = [
  {target = "B", priority = "high", cache = "L1", distance = "..."}
]
```

这种方式的优点是：

- 不影响标准 lowering
- 还能保留研究信息

缺点是：

- metadata 和实际 op 之间需要维护映射关系

## 12.2 方式二：双表示

桥接时不直接替换掉 `research.prefetch`，而是同时保留：

```mlir
"research.prefetch.info"(...)
affine.prefetch ...
```

这样：

- `affine.prefetch` 负责进入标准 lowering
- `research.prefetch.info` 负责保存完整研究语义

这种方式适合当前研究阶段，因为它简单、直观，也便于调试。

## 12.3 方式三：正式自定义 dialect

更长期的方式是把 `research.prefetch` 从 generic op 升级成正式 dialect op。

例如：

```mlir
research.prefetch %b[%ko, %j, %jj, %kk]
  {target = "B", kind = "read", priority = "high", cache = "L1", locality = "KEEP", distance = "..."}
```

然后编写 lowering pass：

```text
research.prefetch
-> affine.prefetch
-> memref.prefetch
-> llvm.prefetch
```

这种方式最稳健，也最适合后续写正式论文实验链路。

---

## 13. 当前仓库中应如何理解第四步

当前第四步的定位是：

- 证明 `research.prefetch` 可以被桥接到标准预取表示
- 证明预取语义可以继续 lowering 到 LLVM 层
- 证明统一主线中预取和 SME lowering 可以共存

但也要明确：

- 当前转换会压缩部分高层研究信息
- `cache = "L1"`、`priority`、`distance` 等字段并不会完整保留到 `affine.prefetch` / `llvm.prefetch`
- 如果后续需要更严谨地研究预取策略，应该引入 metadata、双表示或正式 dialect

---

## 14. 一句话总结

`research.prefetch` 保存“为什么预取、预取谁、策略是什么”；  
`affine.prefetch` 表达“在 affine 层对哪个 memref 下标发预取”；  
`llvm.prefetch` 表达“对哪个最终地址发 LLVM 预取 intrinsic”。

三者是同一条预取语义在不同抽象层上的表示，但不是等价的信息容器。
