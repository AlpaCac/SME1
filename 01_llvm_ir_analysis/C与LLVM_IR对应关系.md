# Stencil C 与 LLVM IR 代码对应关系

> 此文档描述仓库内 2D5P/3D7P 回归 fixture。服务器上的实际入口改为
> `stencil_all_sme.cpp`：步骤 1 先生成完整 IR，再提取多个计算函数的
> kernel-only IR，具体命令见本目录 `README.md`。

本文说明以下两个文件之间的对应关系：

1. C 源码：`../stencil_sme_kernels.c`
2. LLVM IR：`output/stencil_sme_kernels.ll`

LLVM IR 由以下命令生成：

```bash
clang -target arm64-apple-macos15 \
  -march=armv9.2-a+sme+sve2 \
  -O1 -S -emit-llvm stencil_sme_kernels.c \
  -o 01_llvm_ir_analysis/output/stencil_sme_kernels.ll
```

本文行号对应当前提交的 IR 快照。重新生成 IR 后，SSA 名称和行号可能变化，但函数属性、循环、地址差和 intrinsic 语义应保持可识别。

## 1. 不能按源码行机械对应 IR

Clang `-O1` 会执行常量传播、公共子表达式消除和循环规范化，因此 C 与 LLVM IR 不是一行对一行：

1. C 局部变量名通常消失，变成 `%0`、`%1` 等 SSA value。
2. `row + x - 1` 可能变成“中心地址减 4 byte”，而不是重新计算完整下标。
3. north/south 和 front/back 会先形成不同的 row/plane 基址，再共同叠加 `x`。
4. `center_weight` 和 `axis_weight` 会在循环外广播成可伸缩向量。
5. `for` 循环会变成基本块、`phi`、条件分支和回边。

后续 pass 应通过 LLVM 类型、LoopInfo、ScalarEvolution、GEP 和 intrinsic 数据流识别语义，不能依赖 SSA 名称或本文记录的基本块编号。

## 2. 公共类型和属性

### 2.1 C 类型到 LLVM 类型

| C/ACLE 类型 | LLVM IR 类型 | 说明 |
|---|---|---|
| `size_t` | `i64` | 当前 AArch64 target 使用 64 位 `size_t` |
| `const float *restrict input` | `ptr noalias readonly` | `restrict` 形成 `noalias`，只读行为形成 `readonly` |
| `float *restrict output` | `ptr noalias writeonly` | 输出指针不与输入重叠，当前函数只写 output |
| `float` | `float` | 两个权重仍是标量参数 |
| `svbool_t` | `<vscale x 4 x i1>` | 可伸缩的 32-bit lane 谓词 |
| `svfloat32_t` | `<vscale x 4 x float>` | 每个 `vscale` 包含 4 个 `float32` lane |

`<vscale x 4 x float>` 不是固定 4 lane。实际 lane 数为 `vscale * 4`，由目标 SME streaming vector length 决定。

### 2.2 `__arm_locally_streaming`

C 中两个函数前的 `__arm_locally_streaming`：

```c
__arm_locally_streaming void stencil_...(...)
```

在 IR 中不直接表现为 `smstart`/`smstop` 调用，而是两个函数共同引用属性组 `#0`：

```llvm
define void @stencil_2d5p_sme_f32(...) #0
define void @stencil_3d7p_sme_f32(...) #0

attributes #0 = {
  ...
  "aarch64_pstate_sm_body"
  ...
}
```

对应 IR 第 7、86、179 行。AArch64 后端根据该属性在最终函数边界处理 streaming mode。

## 3. 2D5P 对应关系

### 3.1 函数参数

C 第 29 至 31 行：

```c
stencil_2d5p_sme_f32(size_t height, size_t width,
                     const float *restrict input,
                     float *restrict output,
                     float center_weight, float axis_weight)
```

对应 IR 第 7 行：

| C 参数 | LLVM SSA |
|---|---|
| `height` | `%0` |
| `width` | `%1` |
| `input` | `%2` |
| `output` | `%3` |
| `center_weight` | `%4` |
| `axis_weight` | `%5` |

### 3.2 尺寸保护

C 第 32 至 34 行：

```c
if (height < 3 || width < 3)
  return;
```

对应 IR 第 8 至 11 行：

```llvm
%7 = icmp ult i64 %0, 3
%8 = icmp ult i64 %1, 3
%9 = or i1 %7, %8
br i1 %9, label %52, label %10
```

`size_t` 是无符号类型，因此比较使用 `icmp ult`。

### 3.3 streaming VL、内部终点和权重广播

C 第 36 至 37 行：

```c
vector_width = svcntsw();
interior_end = width - 1;
```

对应 IR 第 14 至 17 行：

```llvm
%11 = call i64 @llvm.aarch64.sme.cntsw()
%12 = add i64 %1, -1
%14 = sub i64 0, %1
```

其中：

1. `%11` 是每次 `x` 迭代增加的 `float32` lane 数。
2. `%12` 是 `interior_end`。
3. `%14` 是 `-width`，供 north row 地址计算复用。

C 中两个标量权重在 IR 第 18 至 21 行通过 `insertelement + shufflevector` 广播：

| C 权重 | 标量 SSA | 广播后的向量 SSA |
|---|---|---|
| `axis_weight` | `%5` | `%16` |
| `center_weight` | `%4` | `%18` |

### 3.4 `y` 循环

C 第 39 至 40 行：

```c
for (size_t y = 1; y + 1 < height; ++y)
  row = y * width;
```

对应 IR 第 24 至 40 行：

1. `%24` 表示当前 `y`。
2. `%23`/`%20` 用于表示和更新 `y + 1`。
3. `%26 = mul i64 %24, %1` 对应 `row = y * width`。
4. 第 27 行带 `!llvm.loop !6` 的分支是外层循环回边。

Clang 还提前构造三条 row 基址：

```llvm
%27 = gep input, row       ; current row
%28 = gep %27, -width      ; north row
%29 = gep %27, +width      ; south row
%30 = gep output, row      ; output row
```

### 3.5 `x` 循环和尾部谓词

C 第 42 至 44 行：

```c
for (size_t x = 1; x < interior_end; x += vector_width)
  pg = svwhilelt_b32_u64(x, interior_end);
```

对应 IR 第 42 至 44、62 至 64 行：

```llvm
%32 = phi i64 [ 1, %25 ], [ %50, %31 ]
%33 = call <vscale x 4 x i1>
  @llvm.aarch64.sve.whilelo.nxv4i1.i64(i64 %32, i64 %12)

%50 = add i64 %32, %11
%51 = icmp ult i64 %50, %12
br i1 %51, label %31, label %19, !llvm.loop !13
```

对应关系：

| C 值 | LLVM SSA |
|---|---|
| `x` | `%32` |
| `pg` | `%33` |
| `vector_width` | `%11` |
| `x + vector_width` | `%50` |

`svwhilelt_b32_u64` 使用无符号 64 位比较，因此降低为 SVE `whilelo` intrinsic。

### 3.6 五个邻域 load

C 第 46 至 50 行对应 IR 第 45 至 54 行：

| C 变量 | C 元素地址 | LLVM 地址 | LLVM load 结果 |
|---|---|---|---|
| `center` | `input[row + x]` | `%34 = gep %27, %32` | `%35` |
| `left` | `input[row + x - 1]` | `%36 = gep i8 %34, -4` | `%37` |
| `right` | `input[row + x + 1]` | `%38 = gep i8 %34, +4` | `%39` |
| `north` | `input[row - width + x]` | `%40 = gep %28, %32` | `%41` |
| `south` | `input[row + width + x]` | `%42 = gep %29, %32` | `%43` |

每个 `float` 占 4 byte，因此 left/right 被规范化为中心地址的 `i8 -4/+4`。五个 `svld1_f32` 均降低为：

```llvm
call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(
  ptr %address, i32 1, <vscale x 4 x i1> %33, ...)
```

这里的 `%33` 是共同谓词，`i32 1` 是当前 IR 中的对齐参数。

### 3.7 加权计算和 store

C 第 52 至 59 行对应 IR 第 55 至 61 行：

| C 操作 | LLVM intrinsic | 结果 |
|---|---|---|
| `left + right` | `llvm.aarch64.sve.fadd` | `%44` |
| `+ north` | `llvm.aarch64.sve.fadd` | `%45` |
| `+ south` | `llvm.aarch64.sve.fadd` | `%46` |
| `neighbors * axis_weight` | `llvm.aarch64.sve.fmul` | `%47` |
| `result + center * center_weight` | `llvm.aarch64.sve.fmla` | `%48` |
| `svst1_f32(...)` | `llvm.masked.store` | 写入 `%49` |

输出地址 `%49 = gep %30, %32` 对应 `output + row + x`。

## 4. 3D7P 对应关系

### 4.1 函数参数

C 第 77 至 79 行对应 IR 第 86 行：

| C 参数 | LLVM SSA |
|---|---|
| `depth` | `%0` |
| `height` | `%1` |
| `width` | `%2` |
| `input` | `%3` |
| `output` | `%4` |
| `center_weight` | `%5` |
| `axis_weight` | `%6` |

### 4.2 尺寸保护和公共量

C 第 80 至 86 行对应 IR 第 87 至 104 行：

| C 表达式 | LLVM IR |
|---|---|
| `depth < 3` | `%8 = icmp ult i64 %0, 3` |
| `height < 3` | `%9 = icmp ult i64 %1, 3` |
| `width < 3` | `%11 = icmp ult i64 %2, 3` |
| `vector_width = svcntsw()` | `%14 = llvm.aarch64.sme.cntsw()` |
| `plane_stride = height * width` | `%15 = mul i64 %2, %1` |
| `interior_end = width - 1` | `%16 = add i64 %2, -1` |
| `-width` | `%18 = sub i64 0, %2` |
| `-plane_stride` | `%19 = sub i64 0, %15` |

`axis_weight` 被广播为 `%21`，`center_weight` 被广播为 `%23`。

### 4.3 `z`、`y`、`x` 三层循环

C 第 88 至 94 行的三层循环对应 IR：

| C 循环值 | LLVM SSA | 关键位置 |
|---|---|---|
| 当前 `z` | `%29` | IR 第 112 至 115 行 |
| `plane = z * plane_stride` | `%30` | IR 第 115 行 |
| 当前 `y` | `%36` | IR 第 123 至 129 行 |
| `y * width` | `%38` | IR 第 129 行 |
| `row = plane + y * width` | `%39` | IR 第 130 行 |
| 当前 `x` | `%47` | IR 第 139 至 140 行 |
| `pg` | `%48` | IR 第 141 行 |
| `x + vector_width` | `%71` | IR 第 165 行 |

三条回边分别带有：

1. `!llvm.loop !14`：`z` 循环
2. `!llvm.loop !15`：`y` 循环
3. `!llvm.loop !16`：`x` 循环

### 4.4 五个物理基址

IR 第 131 至 136 行先构造当前 `(z,y)` 位置对应的 row 基址：

```llvm
%40 = gep input, %39          ; current row
%41 = gep %40, -width         ; north row
%42 = gep %40, +width         ; south row
%43 = gep %40, -plane_stride  ; front plane row
%44 = gep %40, +plane_stride  ; back plane row
%45 = gep output, %39         ; output row
```

这正是预取方案中 3D7P 的五条主要 cache-line 物理流。left/center/right 共享 `%40`，只在叠加 `x` 后相差一个元素。

### 4.5 七个邻域 load

C 第 98 至 108 行对应 IR 第 142 至 155 行：

| C 变量 | C 元素地址 | LLVM 地址 | LLVM load 结果 |
|---|---|---|---|
| `center` | `input[row + x]` | `%49 = gep %40, %47` | `%50` |
| `left` | `input[row + x - 1]` | `%51 = gep i8 %49, -4` | `%52` |
| `right` | `input[row + x + 1]` | `%53 = gep i8 %49, +4` | `%54` |
| `north` | `input[row - width + x]` | `%55 = gep %41, %47` | `%56` |
| `south` | `input[row + width + x]` | `%57 = gep %42, %47` | `%58` |
| `front` | `input[row - plane_stride + x]` | `%59 = gep %43, %47` | `%60` |
| `back` | `input[row + plane_stride + x]` | `%61 = gep %44, %47` | `%62` |

七个 load 使用同一个谓词 `%48`，并全部降低为 `llvm.masked.load.nxv4f32.p0`。

### 4.6 加权计算和 store

C 第 110 至 119 行对应 IR 第 156 至 164 行：

1. `%63` 至 `%67`：五次 SVE `fadd`，累加六个轴向邻居。
2. `%68`：SVE `fmul`，乘以广播后的 `axis_weight` `%21`。
3. `%69`：SVE `fmla`，加上 `center * center_weight`。
4. `%70 = gep %45, %47`：形成 `output + row + x`。
5. `llvm.masked.store(... %69, ptr %70, ... %48)`：按尾部谓词写回。

## 5. 对后续预取 pass 的意义

当前 IR 保留了做 stencil 预取所需的稳定关系：

1. `cntsw` 给出每次最内层迭代的运行时 SME VL 步长。
2. `phi + llvm.loop` 表示 2D 的 `y/x` 和 3D 的 `z/y/x` 循环。
3. `whilelo` 给出内部终点和尾部有效 lane。
4. GEP/SCEV 地址差仍可归纳为 `0`、`±1`、`±W`、`±H*W`。
5. 2D 的五个逻辑 load 可合并为三条物理流。
6. 3D 的七个逻辑 load 可合并为五条物理流。
7. 真实 load 使用的代表地址可以沿 `x + distance * cntsw` 构造未来预取地址。

不稳定、不能作为 pass 匹配条件的内容：

1. `%34`、`%49` 等 SSA 编号。
2. `31`、`46` 等基本块编号。
3. 当前快照中的具体行号。
4. GEP 是否被拆成 `float` 元素偏移或 `i8` 字节偏移。
5. Clang 后续版本选择的具体 intrinsic 拼写细节。

因此正式实现必须基于 LLVM analysis 和语义等价关系，而不是复刻本文中的文本模式。
