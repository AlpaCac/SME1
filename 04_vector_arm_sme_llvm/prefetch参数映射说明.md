# 04 预取参数映射说明

这份文档说明当前第四步中预取语义如何从第三步输出继续降低。

当前实际主线是：

```text
03_prefetch_injection/output/02_vector_prefetch.mlir
  memref.prefetch
-> 04_vector_arm_sme_llvm/output/01_arm_sme_prefetch.mlir
  memref.prefetch
-> 04_vector_arm_sme_llvm/output/02_llvm_prefetch.mlir
  llvm.intr.prefetch
-> LLVM IR .ll
  @llvm.prefetch
-> AArch64 汇编
  prfm
```

注意：早期方案讨论过 `research.prefetch -> affine.prefetch`，但当前第四步已经不再走这条支线。第三步直接在 vector 主线中插入 MLIR 标准 `memref.prefetch`，第四步只负责继续 lowering。

## 1. 当前主线中的预取表示

### 1.1 `memref.prefetch`

第三步输出中的预取形式是：

```mlir
memref.prefetch %subview_10[%c0], read, locality<3>, data
  : memref<?xf32, strided<[?], offset: ?>>
```

它支持的核心参数包括：

- 预取对象：例如 `%subview_10`
- 预取下标：例如 `[%c0]`
- 读写类型：`read` 或 `write`
- 局部性 hint：`locality<0>` 到 `locality<3>`
- cache 类型：`data` 或 `instr`
- memref 类型：例如 `memref<?xf32, strided<[?], offset: ?>>`

在当前实验中：

- A/B 的 rank-1 vector 读前插入 `memref.prefetch`
- 使用 `read`
- 使用 `locality<3>`
- 使用 `data`

### 1.2 `llvm.intr.prefetch`

降到 LLVM dialect 后，预取形式变成：

```mlir
"llvm.intr.prefetch"(%84)
  <{cache = 1 : i32, hint = 3 : i32, rw = 0 : i32}>
  : (!llvm.ptr) -> ()
```

它支持的核心参数包括：

- 地址：LLVM pointer，例如 `%84`
- `rw`：读写方向
- `hint`：局部性 hint
- `cache`：cache 类型

参数含义是：

- `rw = 0` 表示读预取
- `rw = 1` 表示写预取
- `hint = 0..3` 对应 locality 强弱
- `cache = 1` 表示 data cache
- `cache = 0` 表示 instruction cache

### 1.3 LLVM IR `.ll` 中的 `@llvm.prefetch`

使用 `mlir-translate --mlir-to-llvmir` 导出后，预取会表现为 LLVM IR intrinsic：

```llvm
call void @llvm.prefetch.p0(ptr %84, i32 0, i32 3, i32 1)
```

四个参数依次表示：

- `ptr %84`：预取地址
- `i32 0`：读预取
- `i32 3`：局部性 hint
- `i32 1`：data cache

### 1.4 AArch64 汇编中的 `prfm`

继续经过后端生成 AArch64 汇编时，LLVM 预取 intrinsic 通常会被选择成 `prfm` 指令，例如：

```asm
prfm pldl1keep, [x13, x12]
```

其中：

- `pld` 表示 preload for load
- `l1` 表示 L1 data cache hint
- `keep` 表示高局部性，倾向保留在 cache 中
- `[x13, x12]` 是最终地址寄存器表达式

具体汇编形式由 LLVM 后端、目标 CPU、优化级别和地址模式共同决定。

## 2. 当前主线中哪些信息被保留

从 `memref.prefetch` 降到 `llvm.intr.prefetch` 后，可以稳定保留的信息包括：

- 预取动作本身
- 读写方向
- locality hint
- data/instruction cache 类型
- 最终预取地址

这些信息足够让 LLVM IR 和后端表达实际预取动作。

## 3. 当前主线中哪些信息会丢失

从高层 MLIR 降到 LLVM dialect 后，会逐步丢失或弱化：

- 原始矩阵名称，例如 A/B/C
- memref 形状信息
- subview 的高层 tile 语义
- `vector.transfer_read` 与预取之间的直接邻接关系
- cost model 的决策原因
- 预取优先级、预取距离这类研究语义

这些信息不是 `memref.prefetch` 或 `llvm.intr.prefetch` 的标准字段，因此不能自然保留到 LLVM 层。

## 4. 与 `research.prefetch` / `affine.prefetch` 的区别

早期讨论中的 `research.prefetch` 是研究型自定义表示，适合保存更丰富的信息，例如：

- `target = "A" / "B"`
- `priority = "high" / "medium"`
- `cache = "L1"`
- `distance = "..."`
- cost model 决策原因
- 循环上下文

`affine.prefetch` 则适合在 affine 循环中表达结构化下标预取，例如：

```mlir
affine.prefetch %b[%ko + %kk, %j + %jj], read, locality<3>, data
  : memref<?x?xf32>
```

但是当前方案已经调整为：

```text
第二步在 affine-normalized 层分析
第三步在 vector 主线中插入 memref.prefetch
第四步继续 lowering 到 Arm SME / LLVM
```

因此 `research.prefetch` 和 `affine.prefetch` 当前只作为设计背景和可选扩展，不是第 04 步实际输入输出。

## 5. 如何解决高层信息丢失

如果后续需要在 LLVM 或汇编层回溯“为什么这里有预取”，可以考虑三种方式。

### 5.1 保留函数属性

当前第三步已经在函数属性中保留了一部分来源信息，例如：

```mlir
step3.prefetch.A = "enable=true,priority=medium,..."
step3.prefetch.B = "enable=true,priority=high,..."
step3.prefetch_injected = "vector.memref.prefetch"
```

这些属性可以帮助从低层文件追踪回第三步决策。

### 5.2 为预取生成旁路 metadata

可以在插入 `memref.prefetch` 时，同时在 module 或函数上生成结构化 metadata：

```mlir
prefetch.metadata = [
  {id = 0, target = "A", priority = "medium", distance = "..."},
  {id = 1, target = "B", priority = "high", distance = "..."}
]
```

优点是不影响标准 lowering；缺点是需要维护 metadata 与具体预取 op 的对应关系。

### 5.3 定义正式 research dialect

更长期的方式是把预取研究语义定义成正式 dialect op，然后编写 lowering pass：

```text
research.prefetch
-> memref.prefetch
-> llvm.intr.prefetch
```

这种方式信息最完整，也更适合后续论文实验，但实现成本更高。

## 6. 一句话总结

当前第四步采用标准主线：第三步输出的 `memref.prefetch` 在 Arm SME lowering 中继续保留，并在 LLVM lowering 后变成 `llvm.intr.prefetch`。真正会丢失的是 cost model 的高层决策语义；若后续需要保留这些信息，应通过函数属性、旁路 metadata 或正式 research dialect 补充。
