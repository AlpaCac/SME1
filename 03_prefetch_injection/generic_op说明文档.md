# 03 Generic Op 说明文档

这份文档的目标是说明三件事：

1. 什么是 `generic op`
2. 为什么第三步选择用 `generic op` 表达研究版预取语义
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

这时就可以使用 `generic op`。

### 1.1 generic op 的写法

第三步里采用的写法是：

```mlir
"research.prefetch"(%a, %i, %ii, %ko, %kk) <{ ... }> : (...) -> ()
```

这类写法的特点是：

- 操作名写成字符串形式
- 不要求当前工具链已经正式注册这个 op
- 可以携带操作数
- 可以携带属性
- 可以显式写出类型签名

也就是说，`generic op` 本质上是一种“通用文本表示形式”：

- 先把一个暂时未正式建模的操作写进 IR
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

所以可以把第三步的 `generic op` 理解成：

- 不是最终工程形态
- 而是研究阶段的“语义占位符”

---

## 2. 为什么第三步要使用 generic op

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

这正是 generic op 在研究原型阶段最有价值的地方。

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

### 4.4 新增的 generic op

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

- 这是一个 generic op
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
