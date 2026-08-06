# 3D13P SME 测试用例执行流程

## 1.1 总体说明执行流程

本目录的 `stencil_all_sme.cpp` 是从服务器抄写的 3D 13-point stencil 测试片段，
由三个部分组成：

1. `main`：选择要执行的测试场景。
2. `test_stencil_3d_13point`：分配数据、初始化输入、计时并重复调用 kernel。
3. `stencil3D_13point_sme`：使用 SVE 加载 13 个邻域向量，通过 SME ZA 完成累加和
   平均值计算。

```mermaid
flowchart TD
    A[main] --> B[test 3D13P stride=1]
    A --> C[test 3D13P stride=2]
    B --> D[分配并初始化 g1/g2]
    C --> E[分配并初始化 g1/g2]
    D --> F[计时调用 kernel 100 次]
    E --> G[计时调用 kernel 100 次]
    F --> H[输出时间并释放内存]
    G --> H
```

测试规模固定为 `128 x 512 x 512`。`g1` 和 `g2` 各包含 33,554,432 个
`double`，每个约 256 MiB，合计约 512 MiB。内存分配和输入初始化不在计时范围内；
`Time:` 表示 100 次 kernel sweep 的墙钟总时间，单次平均时间需要除以 100。

100 次调用始终读取 `g1` 并覆盖 `g2`，两个数组不会交换。因此该测试不是 100 个
相互依赖的时间步，而是对同一个输入重复执行相同计算。当前片段也没有 reference
kernel 或结果比较，只能测量运行时间，不能独立验证计算正确性。

kernel 的执行顺序为：

```text
获取 streaming VL
  -> 遍历内部 k/i/j
  -> 生成 j 方向尾部谓词
  -> 加载中心和 12 个邻域向量
  -> 清空 ZA
  -> 执行 13 次 MOPA 累加
  -> 从 ZA 读出结果
  -> 乘以 1/13
  -> 写入 new_grid
```

`stride=2` 只让 `k/i` 跳过平面或行，并让 `j` 跳过一个完整向量块。单次
`svld1_f64` 仍然加载连续元素，不是 lane 内步长为 2 的 gather。

## 1.2 以代码块形式逐语句说明

以下代码块保持原文件的语句和顺序，并用 `//` 注释解释。注释不属于服务器原代码。
其中明显的抄写错误不会直接修正，而是在对应位置标出。

### 1.2.1 头文件和 Kernel 声明

```cpp
// 引入 SME ZA tile、MOPA 和 ZA 读写相关 ACLE 声明。
#include <arm_sme.h>

// 引入 SVE 向量类型、谓词、加载、存储和向量运算声明。
#include <arm_sve.h>

// 提供 high_resolution_clock 和 duration。
#include <chrono>

// 提供 std::cout 和 std::endl。
#include <iostream>

// 提供 aligned_alloc 和 free。
#include <cstdlib>

// 提供 C 字符串接口；当前片段没有实际使用。
#include <cstring>

// 请求函数进入时使用新的 ZA 状态。
__arm_new("za")

// 声明输入网格、输出网格、三维尺寸和 stride。
// __restrict__ 表示 grid 与 new_grid 不发生别名。
void stencil3D_13point_sme(
    double* __restrict__ grid,
    double* __restrict__ new_grid,
    int depth, int rows, int cols, int stride)

// 声明函数在 SME streaming mode 中运行并开始函数体。
__arm_streaming {
```

### 1.2.2 Kernel 初始化和循环控制

```cpp
    // 返回当前 streaming vector length 能容纳的 double lane 数。
    // 例如 streaming VL=512 bit 时，SVL=512/64=8。
    uint64_t SVL = svcntd();

    // 一个 k 平面包含 rows*cols 个 double，用于三维下标线性化。
    int plane_size = rows * cols;

    // 创建所有 lane 都为 1/13 的向量，最后用于计算平均值。
    svfloat64_t weight_vec = svdup_f64(1.0 / 13.0);

    // 创建全 1 向量，作为每次 ZA 外积的纵向操作数。
    svfloat64_t ones = svdup_f64(1.0);

    // 创建所有 64-bit lane 都有效的谓词，控制 ZA 纵向维度。
    svbool_t pg_all = svptrue_b64();

    // 从 k=1 开始，避开第 0 个平面和最后一个平面。
    // stride=2 时每次跳过一个平面。
    for (int k = 1; k < depth - 1; k += stride) {

        // 从 i=1 开始，避开第 0 行和最后一行。
        // stride=2 时每次跳过一行。
        for (int i = 1; i < rows - 1; i += stride) {

            // j 沿连续维按向量块前进。
            // stride=2 时跳过一个完整向量块，不是隔元素加载。
            for (int j = 1; j < cols - 1; j += SVL * stride) {

                // 计算当前迭代采用的 j 上界。
                // stride=2 时该范围可大于一个向量，但谓词最多仍有 SVL 个 lane。
                int j_limit = (cols - 1 < j + SVL * stride - 1)
                                  ? cols - 1
                                  : j + SVL * stride - 1;

                // 第 n 个 lane 在 j+n < j_limit+1 时有效。
                // svld1_f64 最多加载 SVL 个连续 double。
                svbool_t pg = svwhilelt_b64(j, j_limit + 1);

                // 若谓词中没有有效 lane，则结束 j 循环。
                // 当前源码写成 svptrue_b64 而不是 svptrue_b64()，需核对 ACLE 写法。
                if (!svptest_any(svptrue_b64, pg))
                    break;

                // 把当前坐标 (k,i,j) 转换为一维数组起始下标。
                int base_idx = k * plane_size + i * cols + j;
```

这里需要注意尾部边界：`j_limit` 最多取 `cols-1`，随后谓词使用
`j_limit+1`，因此可能允许输出列 `cols-1`。对于需要访问 `j+1` 的邻域，最末 lane
还可能跨到下一行。分析预取前应与服务器原代码核对这里是否应限制到 `cols-2`。

### 1.2.3 加载 13 个输入向量

```cpp
                // (0,0,0)：加载中心向量。
                svfloat64_t center =
                    svld1_f64(pg, &grid[base_idx]);

                // (-1,0,0)：前一个平面的同位置向量。
                svfloat64_t k1_i0_j0 =
                    svld1_f64(pg, &grid[(k - 1) * plane_size + i * cols + j]);

                // (+1,0,0)：后一个平面的同位置向量。
                svfloat64_t kp1_i0_j0 =
                    svld1_f64(pg, &grid[(k + 1) * plane_size + i * cols + j]);

                // (0,-1,0)：当前平面的上一行。
                svfloat64_t k0_i1_j0 =
                    svld1_f64(pg, &grid[k * plane_size + (i - 1) * cols + j]);

                // (0,+1,0)：当前平面的下一行。
                svfloat64_t k0_ip1_j0 =
                    svld1_f64(pg, &grid[k * plane_size + (i + 1) * cols + j]);

                // (0,0,-1)：从中心左侧一个元素开始连续加载。
                svfloat64_t k0_i0_j1 =
                    svld1_f64(pg, &grid[k * plane_size + i * cols + (j - 1)]);

                // (0,0,+1)：从中心右侧一个元素开始连续加载。
                svfloat64_t k0_i0_jp1 =
                    svld1_f64(pg, &grid[k * plane_size + i * cols + (j + 1)]);

                // (-1,-1,0)：前一平面的上一行。
                svfloat64_t k1_i1_j0 = svld1_f64(
                    pg, &grid[(k - 1) * plane_size + (i - 1) * cols + j]);

                // (-1,+1,0)：前一平面的下一行。
                svfloat64_t k1_ip1_j0 = svld1_f64(
                    pg, &grid[(k - 1) * plane_size + (i + 1) * cols + j]);

                // (+1,-1,0)：后一平面的上一行。
                svfloat64_t kp1_i1_j0 = svld1_f64(
                    pg, &grid[(k + 1) * plane_size + (i - 1) * cols + j]);

                // (+1,+1,0)：后一平面的下一行。
                svfloat64_t kp1_ip1_j0 = svld1_f64(
                    pg, &grid[(k + 1) * plane_size + (i + 1) * cols + j]);

                // (-1,0,-1)：前一平面中从 j-1 开始的向量。
                svfloat64_t k1_i0_j1 = svld1_f64(
                    pg, &grid[(k - 1) * plane_size + i * cols + (j - 1)]);

                // (+1,0,+1)：后一平面中从 j+1 开始的向量。
                svfloat64_t kp1_i0_jp1 = svld1_f64(
                    pg, &grid[(k + 1) * plane_size + i * cols + (j + 1)]);
```

`svld1_f64(pg, address)` 的第 `n` 个有效 lane 加载 `address[n]`。逻辑加载量为
`有效 lane 数 x 8 byte`；无效 lane 不访问内存。处理完整向量时，一条加载最多读取
`SVL x 8 byte`，但硬件 cache 传输仍以 cache line 为基本粒度。

### 1.2.4 ZA 累加、缩放和写回

```cpp
                // 每个输出向量开始前清空 ZA，避免保留上一次 j 迭代的结果。
                svzero_za();

                // 第 1 项：累加中心向量。
                svmopa_za64_f64_m(0, pg_all, pg, ones, center);

                // 第 2 项：累加 (-1,0,0)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, k1_i0_j0);

                // 第 3 项：累加 (+1,0,0)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, kp1_i0_j0);

                // 第 4 项：累加 (0,-1,0)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, k0_i1_j0);

                // 第 5 项：累加 (0,+1,0)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, k0_ip1_j0);

                // 第 6 项：累加 (0,0,-1)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, k0_i0_j1);

                // 第 7 项：累加 (0,0,+1)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, k0_i0_jp1);

                // 第 8 项：累加 (-1,-1,0)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, k1_i1_j0);

                // 第 9 项：累加 (-1,+1,0)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, k1_ip1_j0);

                // 第 10 项：累加 (+1,-1,0)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, kp1_i1_j0);

                // 第 11 项：累加 (+1,+1,0)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, kp1_ip1_j0);

                // 第 12 项：累加 (-1,0,-1)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, k1_i0_j1);

                // 第 13 项：累加 (+1,0,+1)。
                svmopa_za64_f64_m(0, pg_all, pg, ones, kp1_i0_jp1);

                // 从 ZA tile 0 的第 0 行读出逐 lane 累加结果。
                svfloat64_t sum =
                    svread_hor_za64_m(svundef_f64(), pg_all, 0, 0);

                // 有效 lane 乘以 1/13，无效 lane 清零。
                svfloat64_t result = svmul_f64_z(pg, sum, weight_vec);

                // 在 pg 控制下把有效 lane 写回 new_grid[base_idx]。
                svst1_f64(pg, &new_grid[base_idx], result);
            }
        }
    }
}
```

### 1.2.5 测试函数

```cpp
// run_stride1/run_stride2 分别决定是否执行两个场景。
// 返回值是本次调用实际执行场景的耗时之和。
double test_stencil_3d_13point(bool run_stride1, bool run_stride2) {

    // 输出算子标题，不属于 kernel 计时范围。
    std::cout << std::endl << "------3d13p-----" << std::endl;

    // 固定测试规模为 128x512x512。
    const int DEPTH = 128, ROWS = 512, COLS = 512;

    // 分配约 256 MiB、64-byte 对齐的输入网格。
    double* g1 = (double*)aligned_alloc(
        64, DEPTH * ROWS * COLS * sizeof(double));

    // 分配约 256 MiB、64-byte 对齐的输出网格。
    double* g2 = (double*)aligned_alloc(
        64, DEPTH * ROWS * COLS * sizeof(double));

    // 初始化两个可选场景的累计耗时。
    double total_time = 0.0;

    // 保存单个场景的耗时。
    double elapsed;

    // 只有调用者请求 stride=1 时才执行第一段测试。
    if (run_stride1) {

        // 在计时前初始化 g1[k,i,j] = 1 + linear_index。
        // g2 没有初始化。
        for (int k = 0; k < DEPTH; k++)
            for (int i = 0; i < ROWS; i++)
                for (int j = 0; j < COLS; j++)
                    g1[k * ROWS * COLS + i * COLS + j] =
                        1.0 + (k * ROWS + i) * COLS + j;

        // 标记即将执行 stride=1。
        std::cout << "stride=1..." << std::endl;

        // 记录计时起点。
        auto start = std::chrono::high_resolution_clock::now();

        // 连续调用 100 次；每次读取相同 g1 并覆盖 g2。
        for (int iter = 0; iter < 100; iter++)
            stencil3D_13point_sme(g1, g2, DEPTH, ROWS, COLS, 1);

        // 记录计时终点。
        auto end = std::chrono::high_resolution_clock::now();

        // 计算 100 次调用的墙钟总秒数。
        elapsed = std::chrono::duration<double>(end - start).count();

        // 输出 stride=1 时间。
        std::cout << "Time:" << elapsed << std::endl;

        // 加入测试函数的总时间。
        total_time += elapsed;
    }

    // 只有调用者请求 stride=2 时才执行第二段测试。
    if (run_stride2) {

        // 在 stride=2 计时前重新写入与 stride=1 相同的输入。
        for (int k = 0; k < DEPTH; k++)
            for (int i = 0; i < ROWS; i++)
                for (int j = 0; j < COLS; j++)
                    g1[k * ROWS * COLS + i * COLS + j] =
                        1.0 + (k * ROWS + i) * COLS + j;

        // 标记即将执行 stride=2。
        std::cout << "stride=2..." << std::endl;

        // 记录计时起点。
        auto start = std::chrono::high_resolution_clock::now();

        // 连续调用 100 次 stride=2 kernel。
        for (int iter = 0; iter < 100; iter++)
            stencil3D_13point_sme(g1, g2, DEPTH, ROWS, COLS, 2);

        // 记录计时终点。
        auto end = std::chrono::high_resolution_clock::now();

        // 计算 stride=2 的 100 次调用总秒数。
        elapsed = std::chrono::duration<double>(end - start).count();

        // 输出 stride=2 时间。
        std::cout << "Time:" << elapsed << std::endl;

        // 加入测试函数的总时间。
        total_time += elapsed;
    }

    // 释放输入和输出网格。
    free(g1);
    free(g2);

    // 返回本次函数实际执行场景的耗时之和。
    return total_time;
}
```

当前代码没有检查 `aligned_alloc` 是否失败，也没有初始化或校验输出边界。

### 1.2.6 `main` 入口

```cpp
// 程序入口保留 argc/argv，但当前片段没有读取命令行参数。
int main(int argc, char* argv[]) {

    // 服务器原程序会根据参数选择 stencil 用例；具体逻辑已被省略。
    // ...根据参数判断执行哪些stencil用例

    // 分配一套网格，只执行 stride=1；返回的耗时没有保存。
    test_stencil_3d_13point(true, false);

    // 再分配一套网格，只执行 stride=2；返回的耗时没有保存。
    test_stencil_3d_13point(false, true);

    // 服务器原程序还会累计并输出总时间；当前片段已省略。
    // ...记录并输出总运行时间

    // 到达 main 末尾等价于 return 0。
}
```

在分析 LLVM IR 或评估预取效果前，仍应核对第 23 行 `svptrue_b64` 是否应为
`svptrue_b64()`，并确认 `j_limit` 是否应将右边界限制到 `cols-2`。否则编译
错误或越界访问可能被误判为 Pass 或预取模型问题。
