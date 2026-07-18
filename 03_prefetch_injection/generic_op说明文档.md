# 03 Generic Op 说明文档

这份文档的目标是说明三件事：

1. 什么是 `generic assembly` 形式
2. 为什么第三步仍用这种文本形式表达研究版预取语义
3. 结合第三步生成的 [gemm_fp32_affine_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir)，解释它包含哪些部分、各类语句是什么意思

---

## 1. 什么是 generic op

在 `MLIR` 里，通常我们看到的操作都是“已经注册好的 op”，例如：

- `arith.constant`
- `affine.for`
- `scf.if`
- `affine.load`
- `linalg.matmul`

这些 op 都属于某个已经定义好的 `dialect`，有明确的：

- 名字
- 操作数格式
- 结果类型
- 属性结构
- 语义规则

但是在研究阶段，经常会遇到一个问题：

- 我们想表达一种新语义
- 这种语义现在还没有正式 dialect
- 但又想先把它放进 IR 里继续实验

这时可以先使用 MLIR 的 generic assembly 形式表达它。

### 1.1 generic assembly 的写法

第三步里采用的写法是：

```mlir
"research.prefetch"(%a, %i, %ii, %ko, %kk) <{ ... }> : (...) -> ()
```

这类写法的特点是：

- 操作名写成字符串形式
- 可以携带操作数
- 可以携带属性
- 可以显式写出类型签名
- 如果 dialect/op 已注册，它就是“注册 op 的通用打印形式”
- 如果 dialect/op 未注册，它也可以作为研究原型临时承载语义

也就是说，generic assembly 本质上是一种“通用文本表示形式”：

- 既可以打印已注册 op
- 也可以临时表达未注册 op
- 后续再由自定义 pass 去识别、解释、桥接或重写

### 1.2 generic op 和“正式自定义 dialect op”的区别

两者的主要区别在于成熟度和工具支持。

`generic op` 的特点：

- 上手快
- 适合研究原型
- 方便先表达语义
- 不必先写完整 dialect 定义

正式自定义 dialect op 的特点：

- 语义更规范
- 工具支持更完整
- 更适合长期维护
- 更适合做验证、推理和大规模 pass 配合

当前第三步已经比最早的未注册 generic op 更进一步：

- 文本上仍打印成 `"research.prefetch"(...)`
- 插件里已经用 DynamicDialect 注册 `research.prefetch`
- verifier 可以检查 operand、result、region 和关键属性
- 后续还可以升级为 TableGen/ODS 定义的正式 dialect op

---

## 2. 为什么第三步仍保留 generic assembly 形式

第三步的任务不是立刻生成最终机器预取指令，而是先把第二步得到的预取决策写进高层 IR。

这里有几个现实原因。

### 2.1 预取语义还在研究中

当前我们关心的不是某一个固定后端的唯一表示，而是先把下面这些信息表达出来：

- 对谁预取
- 是读预取还是写预取
- 优先级是什么
- 目标缓存层级是什么
- 采用 `KEEP` 还是 `STRM`
- 预取距离如何描述

这些信息在第三步里都还是“研究语义”，并不一定已经完全收敛为一个最终官方表示。

### 2.2 需要和后端表示解耦

如果第三步一开始就强行绑定到某个低层后端形式，例如直接写成目标相关 intrinsic，就会带来两个问题：

- 高层分析结果和后端编码耦合过早
- 不利于继续研究不同 lowering 路线

所以第三步更合适的做法是：

- 先保留“高层预取决策”的原貌
- 后续再做桥接

### 2.3 方便后续 pass 重写

第三步的 `research.prefetch` 很适合后续做这些事情：

- 识别注入点
- 读取属性
- 转写为标准 `affine.prefetch`
- 转写为 `memref.prefetch`
- 再继续转到 `llvm.prefetch`

这正是 generic assembly 在研究原型阶段最有价值的地方。

---

## 3. 第三步产物在整个方案中的位置

第三步生成的文件是：

- [output/gemm_fp32_affine_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir)

它的来源是：

- 第一步的 `affine` 版高层 MLIR
- 第二步的 `cost module` 决策结果

它的作用是：

- 保留 `affine` 层结构
- 保留显式访存与归约
- 同时把“预取语义”也插入进去

因此它是一个“带研究版预取语义的 affine MLIR”。

---

## 4. 这份 MLIR 文件由哪些部分组成

第三步的这份文件，可以分成下面几部分理解。

### 4.1 第三步新增的文件头注释

例如：

```mlir
// 自动生成文件：gemm_fp32_affine_prefetch.mlir
// 来源：gemm_fp32_affine.mlir + 第二步 cost module 决策
// 目标：在 affine 层显式注入研究版预取语义
```

这一部分的作用是：

- 告诉读者这不是原始第一步文件
- 而是第三步“注入后”的版本

### 4.2 第一份 affine 文件的主体

这份文件的大部分结构仍然来自第一步生成的：

- `affine_map`
- `module`
- `func.func`
- 常量
- 维度恢复
- 外层分块循环
- 内层微块循环
- 标量 load/store
- 标量乘加

也就是说，第三步不是重写整个程序，而是在原有 `affine` 表示上做“语义增强”。

### 4.3 新增的函数属性

例如：

```mlir
prefetch_injected = "true"
```

这说明：

- 当前这份函数已经注入预取语义
- 后续 pass 可以据此快速识别它

### 4.4 新增的 research.prefetch op

例如：

```mlir
"research.prefetch"(...) <{ ... }> : (...) -> ()
```

这一部分才是第三步最核心的新内容。

---

## 5. 以生成文件为例，说明每部分是什么

下面按结构来解释 [gemm_fp32_affine_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir)。

### 5.1 顶部注释部分

文件最开头有两段注释。

第一段是第三步新增的说明：

```mlir
// 自动生成文件：gemm_fp32_affine_prefetch.mlir
// 来源：gemm_fp32_affine.mlir + 第二步 cost module 决策
// 目标：在 affine 层显式注入研究版预取语义
```

含义：

- 当前文件是自动生成的
- 它来自第一步的 `affine` MLIR 和第二步的分析结果
- 它的主要任务是表达预取语义

接着的第二段注释来自第一步文件本身，说明基础 `affine` 表示的用途。

### 5.2 affine_map 定义

```mlir
#tile_outer = affine_map<(d0, d1) -> (128, d0 - d1)>
#row_index = affine_map<(d0, d1, d2) -> (d0 + d1 + d2)>
#col_index = affine_map<(d0, d1, d2) -> (d0 + d1 + d2)>
```

这些并不是第三步新加的，但它们仍然是理解整份文件的基础。

含义：

- `#tile_outer`
  - 用来计算边界块真实大小
- `#row_index`
  - 用来统一表达行坐标计算
- `#col_index`
  - 用来统一表达列坐标计算

例如：

```mlir
%c_row = affine.apply #row_index(%i, %ii, %i_inner)
```

它的含义就是：

```text
c_row = i + ii + i_inner
```

### 5.3 module

```mlir
module {
  ...
}
```

含义：

- 这是整份 IR 的顶层容器
- 函数和符号定义都放在这里

### 5.4 函数定义

```mlir
func.func @gemm_fp32_affine(%a: memref<?x?xf32>, %b: memref<?x?xf32>, %c: memref<?x?xf32>) attributes {
  c_kernel = "gemm_fp32",
  semantic = "C = A * B",
  layout = "A row-major, B row-major, C row-major",
  mlir_level = "affine",
  prefetch_injected = "true"
} {
```

这段可以拆开看。

`func.func`

- 定义一个函数

`@gemm_fp32_affine`

- 函数名

`%a`、`%b`、`%c`

- 三个矩阵输入输出参数
- 类型都是 `memref<?x?xf32>`
- 表示二维动态大小的 `f32` 矩阵

`attributes`

- 是对函数的补充语义说明

这里最值得注意的是：

```mlir
prefetch_injected = "true"
```

它表示：

- 当前函数已经完成第三步预取注入

这类属性很适合后续 pass 做快速筛选。

### 5.5 常量定义

```mlir
%c0 = arith.constant 0 : index
%c1 = arith.constant 1 : index
%c128 = arith.constant 128 : index
%c16 = arith.constant 16 : index
%f0 = arith.constant 0.0 : f32
```

含义：

- `arith.constant` 用来定义常量
- `index` 类型主要用于下标、维度、循环边界
- `f32` 是浮点数

这些常量支持后续：

- 循环边界计算
- 索引计算
- 清零输出块

### 5.6 维度恢复

```mlir
%m = memref.dim %a, %c0 : memref<?x?xf32>
%k = memref.dim %a, %c1 : memref<?x?xf32>
%n = memref.dim %b, %c1 : memref<?x?xf32>
```

含义：

- `memref.dim` 读取矩阵某一维的大小

具体来说：

- `%m` 是 `A` 的行数
- `%k` 是 `A` 的列数
- `%n` 是 `B` 的列数

### 5.7 外层 affine.for

```mlir
affine.for %i = 0 to %m step 128 {
  %mc = affine.min #tile_outer(%m, %i)
```

含义：

- `%i` 是外层行块起点
- 每次按 `128` 前进
- `%mc` 计算当前块真实高度

后面的 `%j` 和 `%ko` 也一样，分别对应：

- 列块
- 归约块

### 5.8 边界判断

```mlir
%ii_in_bound = arith.cmpi ult, %ii, %mc : index
scf.if %ii_in_bound {
```

含义：

- 比较 `%ii < %mc` 是否成立
- 如果成立就进入分支

这样做是因为：

- `ii`、`jj`、`kk` 在结构上是固定块大小循环
- 但边界块时真实大小可能变小
- 所以要显式裁掉越界部分

### 5.9 清零输出微块

例如：

```mlir
affine.store %f0, %c[%c_row, %c_col] : memref<?x?xf32>
```

含义：

- 把 `0.0` 写到当前 `C` 的对应位置

这对应研究版 `C = A * B` 语义里的“每个输出微块先清零”。

---

## 6. 第三步最关键的部分：research.prefetch

第三步真正新增的核心语句是下面这两段。

### 6.1 对 B 的预取

```mlir
"research.prefetch"(%b, %ko, %j, %jj, %kk) <{
  target = "B", kind = "read", priority = "high",
  cache = "L1", locality = "KEEP",
  distance = "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界"
}> : (memref<?x?xf32>, index, index, index, index) -> ()
```

这一段可以分成几部分看。

#### 6.1.1 操作名

```mlir
"research.prefetch"
```

含义：

- 这是一个通过插件注册的 `research.prefetch` op
- 当前文件使用 generic assembly 形式打印它
- 名字叫 `research.prefetch`
- 说明它是研究阶段定义的预取语义操作

#### 6.1.2 操作数

```mlir
(%b, %ko, %j, %jj, %kk)
```

含义：

- `%b`
  - 说明预取目标来自矩阵 `B`
- `%ko, %j, %jj, %kk`
  - 提供当前循环上下文
  - 后续 pass 可以利用这些值恢复预取地址或预取点位置

这里要注意：

- 这几个参数不一定等于“最终物理地址”
- 它们更像是“语义定位信息”

#### 6.1.3 属性字典

```mlir
<{
  target = "B", kind = "read", priority = "high",
  cache = "L1", locality = "KEEP",
  distance = "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界"
}>
```

这是第三步最有研究价值的一部分，因为它把第二步 `cost module` 的决策显式写进了 IR。

每个字段的含义如下。

`target = "B"`

- 预取对象是矩阵 `B`

`kind = "read"`

- 这是读预取

`priority = "high"`

- 表示在当前策略中，`B` 的预取优先级较高

`cache = "L1"`

- 预取目标缓存层级是 `L1`

`locality = "KEEP"`

- 表示希望保留局部性
- 后续通常可映射到较强保留型的 hint

`distance = "..."`

- 用自然语言记录当前研究阶段的预取距离策略
- 这在原型阶段很有帮助，因为距离模型还可能继续演化

#### 6.1.4 类型签名

```mlir
: (memref<?x?xf32>, index, index, index, index) -> ()
```

含义：

- 这个操作接收 5 个输入
- 分别是一个矩阵对象和 4 个索引值
- 不产生返回值

`-> ()`

- 表示这个 op 没有结果值
- 它的作用是表达语义，不是产生一个可继续参与算术的数值

### 6.2 对 A 的预取

```mlir
"research.prefetch"(%a, %i, %ii, %ko, %kk) <{
  target = "A", kind = "read", priority = "medium",
  cache = "L1", locality = "KEEP",
  distance = "按未来 1 到 2 个 kk-cache-line"
}> : (memref<?x?xf32>, index, index, index, index) -> ()
```

这段和对 `B` 的预取结构相同，只是语义不同。

主要区别是：

- `target = "A"`
  - 预取对象换成 `A`
- `priority = "medium"`
  - 优先级低于 `B`
- `distance`
  - 采用了 `A` 自己的距离策略

这正好反映了第二步分析结果的差异化判断。

---

## 7. 为什么注入点放在这里

第三步没有把 `research.prefetch` 随便插在任何地方，而是放在：

```mlir
affine.for %kk = 0 to 128 {
  %in_k_bound = arith.cmpi ult, %kk, %kc : index
  scf.if %in_k_bound {
    "research.prefetch"(...)
    "research.prefetch"(...)
    ...
    %a_val = affine.load ...
    ...
    %b_val = affine.load ...
```

也就是说，它放在：

- `kk` 归约推进内部
- 越界判断之后
- 真正的 `affine.load` 之前

这样做有三个好处。

### 7.1 接近真实读流

这里紧挨着后面的 `A/B` 读取，因此：

- 很容易对应真实访存时序

### 7.2 保留循环上下文

在这个位置插入时，周围的：

- `%ko`
- `%j`
- `%jj`
- `%kk`
- `%i`
- `%ii`

都还在作用域内，后续更容易恢复地址关系。

### 7.3 便于继续 lowering

后续如果要把它桥接成：

- `affine.prefetch`
- `memref.prefetch`
- `llvm.prefetch`

这个位置也更容易做机械化重写。

---

## 8. generic op 和普通标准 op 的阅读区别

读标准 op 时，一般更关注：

- 它的固定语义是什么
- 它的输入输出怎样组织

读 generic op 时，除了这些，还要额外关注两件事。

### 8.1 操作名本身

例如：

```mlir
"research.prefetch"
```

这就已经在告诉你：

- 这不是标准 `affine` op
- 这不是标准 `memref` op
- 这是一种研究阶段语义标记

### 8.2 属性字典

generic op 的语义核心，往往更多体现在属性里。

在第三步里，真正重要的不是“它叫 prefetch”这么简单，而是这些字段：

- `target`
- `kind`
- `priority`
- `cache`
- `locality`
- `distance`

这些字段共同构成了“高层预取决策”的语义内容。

---

## 9. 如果把第三步生成物一句话说清楚

可以这样理解：

第一步的 `affine` 文件是在说：

- 程序的循环、索引、标量访存长什么样

第三步的 `affine_prefetch` 文件是在这个基础上进一步说：

- 在这些循环和访存结构中，哪些地方应该发起预取
- 预取谁
- 预取到哪一级缓存
- 用什么局部性策略

也就是说，第三步不是改变计算语义，而是在原有 `affine` 计算结构上附加“预取语义”。

---

## 10. 一句话总结

如果只用一句话概括第三步的 `generic op`：

它就是一种“先把研究中的预取决策写进 MLIR，再交给后续 pass 继续解释和 lowering 的语义占位符”。

---

## 11. 当前 MLIR pass 是如何插入预取的

第三步现在通过 C++ MLIR pass 注入预取语义：

- [passes/InjectResearchPrefetch.cpp](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/passes/InjectResearchPrefetch.cpp)

pass 名称是：

```text
inject-research-prefetch
```

它不再查找固定文本，而是在 MLIR IR 结构上工作。

### 11.1 pass 的输入

当前 pass 的输入是第一步生成的 affine MLIR：

- [gemm_fp32_affine.mlir](/Users/alpaca/Documents/SME/SME1/01_custom_lifter/output/gemm_fp32_affine.mlir)

从文件层面看，它不是 C 源码，也不是 LLVM IR，而是已经提升到高层结构后的 MLIR：

```text
01_custom_lifter/output/gemm_fp32_affine.mlir
```

这个输入保留了三类关键信息：

- 循环结构：由 `affine.for` 表达外层分块和内层归约
- 索引关系：由 `affine.apply` / affine map 表达矩阵下标计算
- 访存行为：由 `affine.load` / `affine.store` 暴露 A、B、C 的访问模式

这正是第三步能判断“在哪里插入预取”的前提。

### 11.2 pass 的输出

当前 pass 的输出是：

- [gemm_fp32_affine_prefetch.mlir](/Users/alpaca/Documents/SME/SME1/03_prefetch_injection/output/gemm_fp32_affine_prefetch.mlir)

输出仍然是 affine 层 MLIR，并没有继续降到 `vector`、`arm_sme` 或 `llvm` 层。

输出相对输入的变化主要有两类。

第一类是函数属性变化：

```mlir
prefetch_injected = "true"
```

它表示第三步 pass 已经处理过这个函数。

第二类是新增已注册的 `research.prefetch` op：

```mlir
"research.prefetch"(...)
```

这些 op 被插入到 `kk` 归约循环的边界保护内部、真实 `affine.load` 之前。当前会插入两条：

- 一条面向 `B` 的高优先级读预取
- 一条面向 `A` 的中优先级读预取

第三步不改变原来的矩阵乘语义。也就是说，原来的 `affine.load`、`arith.mulf`、`arith.addf`、`affine.store` 仍然存在，只是在它们之前增加了“研究版预取语义”。

### 11.3 输入必须满足什么限制

当前 pass 是一个面向研究原型的结构匹配 pass。它已经比 Python 文本替换稳定，但还不是任意 affine 程序的通用预取器。

输入需要满足以下限制。

第一，输入必须是 affine 层 MLIR。

如果输入是 C 文件，需要先经过第一步提升器得到 `gemm_fp32_affine.mlir`。如果输入已经降到 LLVM dialect 或 LLVM IR，原始的 affine 循环、memref 下标和高层访存结构已经部分丢失，当前 pass 无法工作。

第二，目标函数必须是 `func.func`，并且至少有三个参数。

当前实现默认参数顺序为：

```text
argument 0 -> A
argument 1 -> B
argument 2 -> C
```

这个限制来自当前 pass 的实现方式。pass 在插入 `research.prefetch` 时直接使用：

```cpp
func.getArgument(0)  // A
func.getArgument(1)  // B
```

因此变量名不重要，但参数顺序重要。

第三，矩阵参数当前按二维 `memref` 理解。

研究示例使用：

```mlir
memref<?x?xf32>
```

当前 pass 没有完整实现类型检查，但插入的预取 op 会带上四个索引值，例如：

```mlir
"research.prefetch"(%b, %ko, %j, %jj, %kk) ...
```

这些索引语义默认对应二维矩阵的块坐标和归约坐标。如果输入改成一维 buffer、三维 tensor 或 packed layout，当前预取语义就需要同步修改。

第四，输入需要保留第一步生成的受限 GEMM affine 形态：

- 外层 `affine.for` 表达 `i / j / ko`
- 中层 `affine.for` 表达 `ii / jj`
- 内层 `affine.for` 表达 `kk`
- `kk` 循环内部存在 `scf.if` 边界保护
- `scf.if` 内部存在真实 `affine.load`

当前 pass 不依赖 SSA 变量名。例如 `%i` 被 MLIR 打印成 `%arg3` 也可以。但它依赖循环嵌套顺序，因为 pass 会收集祖先 induction variables，并按如下顺序解释：

```text
i, j, ko, ii, jj, kk
```

如果循环顺序改成 `i, ko, j`，或者把 `kk` 提到更外层，当前 pass 的索引解释就会错误。

第五，`kk` 候选循环需要满足当前实现中的结构条件：

- `affine.for` 的 step 为 `1`
- upper bound 是常量，并且足够大，例如当前示例中的 `128`
- 循环体中存在一个 `scf.if`
- 这个 `scf.if` 的 then region 中有嵌套 `affine.for`
- 这个 `scf.if` 的 then region 中有 `affine.load`

这些条件共同用于区分“初始化 C 的循环”和“真正执行 A/B 读取与乘加的 kk 归约循环”。

第六，当前 pass 只在第一个匹配到的候选点插入预取。

如果一个 module 里有多个 GEMM 函数，或者一个函数中有多个可预取的计算区域，当前实现不会逐个处理。后续如果要扩展，需要把 `injected` 这个单点控制改成按函数或按 loop 多点处理。

第七，输出使用已注册 dialect 的 op，但仍采用 generic assembly 格式打印。

当前 pass 插件通过 `DynamicDialect` 注册了：

```text
research.prefetch
```

因此运行 pass 生成输出时不需要 `--allow-unregistered-dialect`。验证输出文件时，需要加载同一个插件提供的 dialect 注册入口：

```text
--load-dialect-plugin=03_prefetch_injection/build/SMEPrefetchInjectionPass.dylib
```

如果不加载 dialect 插件，MLIR 会把 `research` 看作未知 dialect 并拒绝解析。这个行为是预期的，因为注册信息在插件里，而不是内置在 `mlir-opt` 主程序里。

这意味着当前 pass 已经摆脱文本替换，但还没有变成任意 affine 程序的通用预取注入器。

### 11.4 pass 如何定位注入点

pass 会遍历 `func.func` 中的 `affine.for`，寻找一个候选归约循环。

当前候选条件包括：

- step 为 `1`
- upper bound 是较大的常量，例如当前 `128`
- 循环体内有 `scf.if`
- `scf.if` 的 then region 中包含嵌套 `affine.for`
- then region 中包含 `affine.load`

这些条件共同描述了当前受限 GEMM 中的 `kk` 归约循环。

找到候选循环后，pass 会收集祖先 `affine.for` 的 induction variables：

```text
i, j, ko, ii, jj, kk
```

然后在 `scf.if` 的 then block 开头插入预取。

### 11.5 pass 如何构造 research.prefetch

pass 使用 MLIR 的 `OperationState` 构造 `research.prefetch` op：

```cpp
OperationState state(loc, "research.prefetch");
state.addOperands(...);
state.addAttribute("target", builder.getStringAttr("B"));
state.addAttribute("kind", builder.getStringAttr("read"));
state.addAttribute("priority", builder.getStringAttr("high"));
state.addAttribute("cache", builder.getStringAttr("L1"));
state.addAttribute("locality", builder.getStringAttr("KEEP"));
state.addAttribute("distance", builder.getStringAttr("..."));
builder.create(state);
```

这说明：

- `research.prefetch` 已经在插件中注册
- 当前文本仍用 generic assembly 形式打印
- 但它已经由 MLIR pass 在 IR 上创建
- verifier 会检查 operand、result、region 和关键字符串属性
- 不再是 Python 字符串拼接

当前注册方式不是 TableGen/ODS，而是 DynamicDialect：

```cpp
registry.insertDynamic("research", ...);
dialect->registerDynamicOp(DynamicOpDefinition::get(
    "prefetch", dialect, verifyResearchPrefetchOp, verifyRegions));
```

这样做的含义是：

- `research` dialect 已经被插件注册
- `research.prefetch` op 已经被插件注册
- 可以通过 `verifyResearchPrefetchOp` 做基础合法性检查
- 暂时不需要维护 `.td` 文件和生成代码
- 后续如果语义稳定，可以升级为 ODS/TableGen 形式

### 11.6 pass 插入的两条预取

对 `B` 插入：

```mlir
"research.prefetch"(%b, %ko, %j, %jj, %kk) <{
  target = "B",
  kind = "read",
  priority = "high",
  cache = "L1",
  locality = "KEEP",
  distance = "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界"
}> : (memref<?x?xf32>, index, index, index, index) -> ()
```

对 `A` 插入：

```mlir
"research.prefetch"(%a, %i, %ii, %ko, %kk) <{
  target = "A",
  kind = "read",
  priority = "medium",
  cache = "L1",
  locality = "KEEP",
  distance = "按未来 1 到 2 个 kk-cache-line"
}> : (memref<?x?xf32>, index, index, index, index) -> ()
```

这两条语义和早期 Python 版本保持一致，但实现方式已经变成 MLIR pass。

### 11.7 pass 如何标记函数

注入完成后，pass 会给函数增加属性：

```mlir
prefetch_injected = "true"
```

这样后续 pass 或文档检查可以知道：

- 当前函数已经完成第三步预取注入

---

## 12. 当前预取决策是如何进入 pass 的

第二步仍然负责预取分析：

- [analyze_prefetch.py](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/analyze_prefetch.py)
- [prefetch_analysis.json](/Users/alpaca/Documents/SME/SME1/02_prefetch_cost_model/output/prefetch_analysis.json)

第二步的核心结论仍然是：

- `B` 优先级最高
- `A` 次一级
- `C` 当前不主动预取

当前 C++ pass 先把这个策略固化在源码中：

- `B`
  - `priority = "high"`
  - `distance = "按未来 2 个 kk-cache-line 或未来 1 个 B 微块边界"`
- `A`
  - `priority = "medium"`
  - `distance = "按未来 1 到 2 个 kk-cache-line"`
- `C`
  - 不插入

这样做是第一版 pass 的折中：

- 注入机制已经工程化为 MLIR pass
- 决策来源暂时仍然沿用第二步研究结论
- 后续可以把 hard-coded 决策替换成真正的 analysis result

---

## 13. 后续如何让 pass 消费第二步分析结果

当前 pass 还没有直接读取 `prefetch_analysis.json`。更正式的演进方向有三种。

### 13.1 方式一：pass option

可以把 A/B 的策略做成 pass option，例如：

```text
--inject-research-prefetch="enable-a=true enable-b=true locality=KEEP"
```

优点是简单，适合少量参数。

缺点是表达复杂 cost module 不方便。

### 13.2 方式二：把分析结果写入 MLIR 属性

第二步可以把 cost module 决策写成 `func.func` 或 `module` attribute。

第三步 pass 再从 IR 属性读取：

```mlir
prefetch.decisions = [
  {target = "B", priority = "high", cache = "L1", locality = "KEEP"},
  {target = "A", priority = "medium", cache = "L1", locality = "KEEP"}
]
```

优点是：

- 不依赖外部 JSON
- 决策跟 IR 一起流动
- 更适合 pipeline

### 13.3 方式三：分析 pass + 注入 pass

更完整的工程方式是拆成两个 pass：

```text
analyze-prefetch-cost
-> inject-research-prefetch
```

第一个 pass 在 affine 层分析访存模式和复用，第二个 pass 消费分析结果并插入 op。

这会让第三步真正摆脱外部脚本，也更符合 MLIR 的 pass pipeline 思路。

---

## 14. 和 Transform Dialect 的关系

当前已经采用 C++ MLIR pass，不再把 Transform Dialect 作为第三步的主实现。

Transform Dialect 仍然有价值，但更适合做：

- 声明式调度
- 控制 pass 应用于哪些函数
- 描述更高层的 transform pipeline

而当前第三步需要：

- 根据 IR 结构识别注入点
- 构造 `research.prefetch` op
- 携带复杂属性
- 后续接入 cost analysis

这些事情用 C++ pass 更直接。

因此当前推荐路线是：

```text
C++ MLIR analysis/injection pass
-> 必要时用 Transform Dialect 管理 pipeline 调度
```

---

## 15. 当前实现的边界

当前 pass 已经比 Python 文本替换更稳健，并且 `research.prefetch` 已由插件注册，但仍然是研究版。

当前边界是：

- 只支持第一步生成的受限 affine GEMM 结构
- 默认函数参数顺序是 `A, B, C` 对应 func arguments 0、1、2
- 只注入 A/B 的读预取
- 决策内容暂时固化在 pass 中
- `research.prefetch` 当前通过 DynamicDialect 注册，还不是 ODS/TableGen 形式的完整 dialect op

后续最重要的改进是：

- 将当前 DynamicDialect 版 `research` dialect 升级为 ODS/TableGen 版正式 dialect
- 把第二步 cost module 迁移成 MLIR analysis pass
- 让注入 pass 消费分析结果，而不是固化策略

---

## 16. 一句话补充总结

第三步现在已经从“Python 文本注入”升级为“C++ MLIR pass 注入”。

它的核心变化是：

- 过去是在字符串里插入 `research.prefetch`
- 现在是在 MLIR IR 结构中创建 `research.prefetch`

这一步让方案更接近正式编译器实现，也为后续接入真正的 analysis pass 和 dialect lowering 打下基础。
