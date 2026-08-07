# 论文式 SME 3D 13-point 实现说明

## 1. 目标与文件关系

`smestencil_paper_3d13.cpp` 使用 SMEStencil 论文第 IV-A 节的“移位系数向量与
输入向量外积”方法，重写 `stencil_all_sme.cpp` 中的 `stencil3D_13point_sme`。

两份代码计算的是**同一个算子**：网格范围、stride 行为、13 个输入点和 `1/13`
权重都保持一致。区别只在计算组织方式：原实现把每个输入向量与全 1 向量外积，ZA
的全部行因而相同，且只读取第 0 行；新实现把邻域关系编码在移位系数列向量中，使
一个外积同时更新多个不同的 ZA 输出行，并逐行写回。

| 文件 | 用途 |
|---|---|
| `stencil_all_sme.cpp` | 原始 3D 13-point 实现及测试流程 |
| `smestencil_paper_3d13.cpp` | 与原算子等价的论文式 ZA 映射实现 |
| `smestencil_sme_mapping.svg` | 移位系数外积的一维原理图 |
| `za_outer_product_flow.svg` | 原实现中 ZA 行重复的原因 |

## 2. 与源代码一致的算子

令输出点为 `(k, i, j)`。原 `stencil_all_sme.cpp` 加载下列 13 个点，结果为它们的
平均值：

```text
( 0,  0,  0)                    中心
(-1,  0,  0), (+1,  0,  0)      相邻平面
( 0, -1,  0), ( 0, +1,  0)      相邻行
( 0,  0, -1), ( 0,  0, +1)      相邻列
(-1, -1,  0), (-1, +1,  0)      前一平面的行对角点
(+1, -1,  0), (+1, +1,  0)      后一平面的行对角点
(-1,  0, -1), (+1,  0, +1)      两个跨平面列对角点

out[k,i,j] = sum(in[k+dk, i+dy, j+dx]) / 13
```

三元组顺序为 `(dk, dy, dx)`。它是半径 1 的非对称 3D 13-point stencil，不是论文
实验中使用的轴向半径 2 `3DStarR2`；文件名保留 `paper` 是因为采用论文的计算映射，
不表示算子拓扑相同。

因此 kernel 的有效输出范围也与原文件一致：

```text
1 <= k < depth - 1
1 <= i < rows  - 1
1 <= j < cols  - 1
```

## 3. 13 点如何映射到 ZA

设 `N = svcntd()`，一个 `(i,j)` tile 对应 `N x N` 个输出：ZA 行是 `i` 方向输出行，
ZA 列是 `j` 方向连续输出列。

把 13 个偏移按 `(dk, dx)` 分组后，只剩 7 个物理连续输入流：

| `(dk, dx)` | 允许的 `dy` | 覆盖的原始点数 |
|---|---|---|
| `(0, 0)` | `-1, 0, +1` | 3 |
| `(0, -1)`、`(0, +1)` | `0` | 2 |
| `(-1, 0)`、`(+1, 0)` | `-1, 0, +1` | 6 |
| `(-1, -1)`、`(+1, +1)` | `0` | 2 |

对一个流 `(dk, dx)` 和已加载输入行 `source_i`，第 `r` 个系数 lane 的含义为：

```text
output_row = i + r * stride
dy = source_i - output_row
coefficient[r] = 1/13, 若 (dk, dy, dx) 属于上述 13 点
                 0,    否则
```

随后执行：

```text
ZA += coefficient_column x input[k+dk, source_i, j+dx : j+dx+N]
```

所有流和输入行累加后，`ZA[r,c]` 恰好是原算子在
`(k, i + r * stride, j + c)` 的结果。代码通过 `svread_hor_za64_m` 读取每个有效
ZA 水平 slice，并用 `svst1_f64` 写回该行。

![论文式外积映射](./smestencil_sme_mapping.svg)

## 4. 谓词、尾块与 stride

`pg_rows` 根据 `i + r * stride < rows - 1` 屏蔽无效 ZA 行；`pg_cols` 根据
`j + c < cols - 1` 屏蔽无效列。因此 rows 或 cols 无需是 `svcntd()` 的倍数。

与原实现相同：

- `stride` 控制 k 的步长；
- i 每次前进 `N * stride`，一个 ZA tile 中的行坐标为 `i + r * stride`；
- j 每次前进 `N * stride`，因而 stride-2 与原代码一样跳过中间 tile；
- 每种 stride 的输出只覆盖其实际遍历到的位置，未访问位置不写入。

## 5. 测试与构建

`smestencil_paper_3d13_self_test()` 用小尺寸随机输入与
`stencil3d_13point_reference()` 逐点比较，参考函数完全按照原代码的 13 次 load 和
除以 13 的定义计算。测试尺寸使 512 位 SVL 环境同时出现行、列尾块。

通过自检后，`test_stencil_3d_13point()` 按原 `test_stencil_3d_13point()` 的结构执行：
`128 x 512 x 512` 初始化、每种 stride 调用 100 次、输出 `Time:`，最后输出
`Total Time:`。

```bash
clang++ -std=c++17 -O2 -Wall -Wextra -Werror \
  -march=armv9-a+sme+sme-f64f64 \
  -DSMESTENCIL_PAPER_DEMO example/smestencil_paper_3d13.cpp \
  -o smestencil_paper_3d13_demo

./smestencil_paper_3d13_demo
```

可以检查是否生成预期 SME 指令：

```bash
clang++ -std=c++17 -O2 -march=armv9-a+sme+sme-f64f64 \
  -S example/smestencil_paper_3d13.cpp -o smestencil_paper_3d13.s
rg 'fmopa|za0h' smestencil_paper_3d13.s
```

## 6. 验证边界与论文差距

本机 Apple Clang 可以编译该文件并生成 `fmopa za0.d` 与 ZA slice 读取指令，但当前
macOS 用户态不能执行 ZA 操作，会触发 `SIGILL`。数值自检和性能测试应在向用户态开放
ZA、且支持 `sme-f64f64` 的 AArch64 Linux 服务器完成。

本实现只使用论文的 stencil-to-SME 外积映射。论文的多 ZA tile ILP、ZA 辅助转置、
临时缓冲、brick 布局、gather 预取和多核/NUMA 调度均未实现；这些优化应在算子等价性
验证通过后再逐项加入。
