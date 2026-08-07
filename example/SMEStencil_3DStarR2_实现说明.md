# SMEStencil 论文式 3DStarR2 实现说明

## 1. 文件与目标

`smestencil_paper_3d13.cpp` 是基于论文 *SMEStencil: Optimizing High-Order
Stencils on ARM Multicore Using SME Unit* 第 IV-A 节实现的、以正确性为优先的
3D 高阶 stencil kernel。

它的目标是验证论文中“移位系数向量与输入向量做 SME 外积，直接在 ZA 中产生多个
不同输出”的映射方式。它不是对原 `stencil_all_sme.cpp` 的原地替换：原文件中的
13 个邻域包含跨平面对角访问，而本文件实现的是论文所对应的轴向 3DStarR2。

| 文件 | 用途 |
|---|---|
| `stencil_all_sme.cpp` | 原始示例：全 1 向量参与外积，ZA 各行重复，只读取第 0 行 |
| `smestencil_paper_3d13.cpp` | 新实现：移位系数向量参与外积，ZA 各行对应不同输出 |
| `smestencil_sme_mapping.svg` | 论文外积映射的图解 |
| `za_outer_product_flow.svg` | 原始示例为何产生重复 ZA 行的图解 |

## 2. 算子定义

实现的算子是半径为 2 的三维 star stencil。对内部网格点 `(k, i, j)`，计算：

```text
out[k,i,j] = -7.5 * in[k,i,j]

           + 4/3 * sum(in[k,i,j +/- 1], in[k,i +/- 1,j], in[k +/- 1,i,j])

           - 1/12 * sum(in[k,i,j +/- 2], in[k,i +/- 2,j], in[k +/- 2,i,j])
```

它包含：

- 1 个中心点；
- 6 个轴向距离 1 邻居；
- 6 个轴向距离 2 邻居；
- 共 13 个点。

系数来自一维四阶中心二阶导数：

```text
d2f/dx2 approximately equals
  [-f(x-2h) + 16f(x-h) - 30f(x) + 16f(x+h) - f(x+2h)] / (12h2)
```

将 x、y、z 三个方向的二阶导数相加时，三个方向的中心项合并为 `-7.5`，距离
1 和距离 2 的轴向系数分别为 `4/3` 和 `-1/12`。

因为半径为 2，kernel 只写入：

```text
2 <= k < depth - 2
2 <= i < rows  - 2
2 <= j < cols  - 2
```

边界值保持调用者提供的原值。

## 3. 论文映射如何落到 ZA

令：

```text
N = svcntd()
```

`N` 是 streaming SVE 向量中 `double` lane 的数量。一次 `(i,j)` tile 计算
`N x N` 个输出：

```text
output rows:    i ... i + N - 1
output columns: j ... j + N - 1
```

ZA 的行对应 tile 中的 `i` 方向输出，ZA 的列对应 `j` 方向输出。

### 3.1 y 方向

对于一个输入行 `source_i`，kernel 连续加载：

```text
values = in[k, source_i, j ... j+N-1]
```

同时构造移位系数列向量 `coefficients`。其第 `r` 个 lane 对应输出行 `i+r`：

```text
delta = source_i - (i + r)
coefficients[r] = coefficient(delta)
```

只有 `delta` 在 `[-2, 2]` 内时该 lane 非零。随后执行：

```text
ZA += coefficients(column) x values(row)
```

遍历带 halo 的全部输入行后，ZA 中得到 y 方向的结果：

```text
ZA[r,c] = sum(delta=-2..2) coefficient(delta)
          * in[k, i+r+delta, j+c]
```

这正是论文“一个输入行按不同系数广播给多个输出行”的映射。与原示例的
`ones x values` 不同，`coefficients` 的 lane 不相同，因此 ZA 行不会重复。

### 3.2 x 方向

x 方向的数学形式是：

```text
out[i,j] = sum(delta=-2..2) coefficient(delta) * in[i,j+delta]
```

本实现为了直接在 row-major 数组上验证该映射，对 tile 中的每个输出行构造 one-hot
系数列向量：只有当前输出行 lane 为非零。然后加载偏移后的连续行向量并执行外积。
这会把 x 方向的贡献只累加到正确的 ZA 行。

论文的完整高性能版本会先通过 ZA 辅助转置改善列访问；本实现没有引入中间转置或
临时缓冲区，因为这里的重点是验证外积映射和正确性。

### 3.3 z 方向

z 方向对相邻平面采用与 x 方向相同的 one-hot 行映射。对于每个输出行和
`delta in {-2,-1,1,2}`，加载：

```text
in[k+delta, i+r, j ... j+N-1]
```

并将其累加到 ZA 的第 `r` 行。`delta=0` 的中心项已经由 y 方向加入，因此 x/z
方向跳过零偏移，避免把中心点重复计算三次。

### 3.4 写回

所有方向贡献累加完毕后，ZA 的每个水平 slice 都是一行独立输出：

```text
result_row = svread_hor_za64_m(..., tile=0, slice=row)
svst1_f64(pg_cols, &output[k, i+row, j], result_row)
```

这与原示例只读取 `slice=0` 不同。新实现会遍历 tile 中所有有效行并逐行写回。

![论文式外积映射](./smestencil_sme_mapping.svg)

## 4. 谓词与尾块

`pg_rows` 和 `pg_cols` 分别处理 i、j 方向不能整除 `N` 的尾部：

```text
pg_rows = svwhilelt_b64(i, rows - 2)
pg_cols = svwhilelt_b64(j, cols - 2)
```

- `pg_rows` 限制外积写入的 ZA 行，并限制移位系数向量的有效 lane；
- `pg_cols` 限制连续加载和最终存储的 ZA 列；
- `active_rows` 限制读取 ZA slice 的次数，避免读取尾 tile 中不存在的输出行。

因此不要求 `rows-4` 或 `cols-4` 是 `svcntd()` 的整数倍。

## 5. 代码结构

| 符号 | 作用 |
|---|---|
| `axis_coefficient` | 返回中心、距离 1、距离 2 的标量系数 |
| `paper_y_coefficients` | 构造论文式移位系数列向量 |
| `paper_one_hot_row` | 只选择一个 ZA 输出行 |
| `stencil3d_star_r2_sme_paper` | SME/ZA kernel |
| `stencil3d_star_r2_reference` | 逐点标量参考实现 |
| `smestencil_paper_3d13_self_test` | 对比两种实现的最大绝对误差 |
| `test_stencil_3d_star_r2` | 与原示例同结构的 stride-1/stride-2 性能测试 |

两个系数构造 helper 强制内联。这样最终 kernel 的内层循环不会为构造向量反复离开和
重新进入 streaming 状态；生成的汇编应包含 `fmopa za0.d`，并通过 ZA 水平 slice
读取结果。

## 6. 构建与自检

在支持 SME 与双精度 SME 外积的 AArch64 环境中：

```bash
clang++ -std=c++17 -O2 -Wall -Wextra -Werror \
  -march=armv9-a+sme+sme-f64f64 \
  -DSMESTENCIL_PAPER_DEMO example/smestencil_paper_3d13.cpp \
  -o smestencil_paper_3d13_demo

./smestencil_paper_3d13_demo
```

程序先使用 `9 x 13 x 17` 网格进行自检，使得 i/j 方向都包含尾 tile。通过后，按照
`stencil_all_sme.cpp` 的测试结构，分别运行 stride-1 与 stride-2：每一项均初始化
`128 x 512 x 512` 输入，连续调用 kernel 100 次，输出 `Time:`，最后输出累计的
`Total Time:`。成功时先输出：

```text
SMEStencil 3DStarR2 max error: <接近 0 的值>
```

并以退出码 0 结束。自检比较整个输出数组；因为 reference 和 SME kernel 都不写
边界，边界位置的初始哨兵值也会一并被检查。

可检查是否确实生成 SME 指令：

```bash
clang++ -std=c++17 -O2 -march=armv9-a+sme+sme-f64f64 \
  -S example/smestencil_paper_3d13.cpp -o smestencil_paper_3d13.s

rg 'fmopa|za0h' smestencil_paper_3d13.s
```

## 7. 本机验证边界

本机 Apple Clang 能编译该文件，并产生 `fmopa za0.d` 和 ZA slice 读取指令。
不过当前 macOS 进程可执行 `smstart sm`，但执行任何 ZA 操作会触发 `SIGILL`。
因此本机只能完成编译和汇编验证，不能完成数值运行验证。

这说明当前用户态环境没有开放 ZA 状态；不应把该异常解释为 kernel 的数值算法错误。
应在已向用户态开放 ZA、并支持 `sme-f64f64` 的 Linux AArch64 服务器上运行第 6 节
自检，再进行性能测量。

## 8. 与论文完整方案的关系

当前实现覆盖论文第 IV-A 节的 stencil-to-SME 外积映射。以下论文优化尚未合入：

- 多 ZA tile 交错的 Tile-Based ILP；
- ZA 辅助转置；
- 中间结果临时缓冲区与 cache 污染规避；
- brick 数据布局；
- SVE gather-based 软件预取；
- cache-snoop 线程数据共享；
- SDMA NUMA halo 交换与计算通信重叠。

这些优化应建立在本实现通过数值自检之后，再按论文顺序逐项加入并做消融实验。
