# SME 测试用例执行与编译流程

## 1. 3D13P SME 测试用例执行流程

### 1.1 总体说明执行流程

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

### 1.2 以代码块形式逐语句说明

以下代码块保持原文件的语句和顺序，并用 `//` 注释解释。注释不属于服务器原代码。
其中明显的抄写错误不会直接修正，而是在对应位置标出。

#### 1.2.1 头文件和 Kernel 声明

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

#### 1.2.2 Kernel 初始化和循环控制

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

#### 1.2.3 加载 13 个输入向量

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

#### 1.2.4 ZA 累加、缩放和写回

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

#### 1.2.5 测试函数

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

#### 1.2.6 `main` 入口

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

## 2. 毕昇编译器从 C++ 到 LLVM IR 的过程

### 2.1 毕昇与 LLVM/Clang 的关系

毕昇编译器以 LLVM/Clang 为基础，因此 `clang++` 编译这个 `.cpp` 文件时，主干
流程仍是 Clang Driver 调度 Clang 前端，再由 Clang CodeGen 生成 LLVM IR。毕昇
在此基础上提供面向鲲鹏/AArch64 的目标支持、优化和运行时适配。查阅源码时需要
区分以下两类仓库：

- [openEuler 毕昇编译器仓库](https://gitee.com/openeuler/bisheng-compiler)：毕昇项目源码与说明入口。
- [src-openEuler 毕昇软件包仓库](https://gitee.com/src-openeuler/bisheng-compiler)：发行包的 spec、补丁和构建材料；它不等同于完整 LLVM 源码树。
- [LLVM monorepo](https://github.com/llvm/llvm-project)：Clang 前端、LLVM IR 优化器和 AArch64 后端的上游实现。

毕昇 Enterprise 5.x 的具体补丁和目录可能与上游同版本 LLVM 不完全一致，但下文
描述的前端阶段及主要源码入口是一致的。服务器上应以
`$BISHENG_CXX --version`、`$BISHENG_CXX -print-resource-dir` 和实际发行包源码为准。

### 2.2 总体编译流水线

```mermaid
flowchart LR
    A[stencil_all_sme.cpp] --> B[clang++ Driver]
    B --> C[预处理器]
    C --> D[Parser]
    D --> E[Sema + AST]
    E --> F[Clang CodeGen]
    F --> G[LLVM IR Module]
    G --> H[LLVM IR 优化]
    H --> I[AArch64 指令选择与寄存器分配]
    I --> J[汇编/目标文件]
    J --> K[链接器]
    K --> L[可执行文件]
```

`clang++` 是编译驱动，不亲自完成所有转换。它分析命令行，确定目标架构、头文件
路径、优化等级和链接选项，然后生成前端、汇编器和链接器任务。可用
`$BISHENG_CXX -### stencil_all_sme.cpp` 只打印这些任务而不执行。

如果命令带 `-S -emit-llvm`，流水线在 LLVM IR 处停止并输出 `.ll`。`.ll` 不是
另一种 IR 层级，而是 LLVM IR 的文本表示；对应的二进制表示是 `.bc`。

### 2.3 各阶段做了什么

| 阶段 | 主要工作 | 输出或观察命令 | 上游源码入口 |
|---|---|---|---|
| Driver | 解析 `-target`、`-march`、`-O1` 等参数，组装编译任务 | `clang++ -###` | [`clang/tools/driver/driver.cpp`](https://github.com/llvm/llvm-project/blob/main/clang/tools/driver/driver.cpp)、[`clang/lib/Driver/Driver.cpp`](https://github.com/llvm/llvm-project/blob/main/clang/lib/Driver/Driver.cpp) |
| 预处理 | 展开 `#include`、宏和条件编译；找到毕昇资源目录中的 `arm_sve.h`、`arm_sme.h` | `clang++ -E` | [`clang/lib/Lex`](https://github.com/llvm/llvm-project/tree/main/clang/lib/Lex) |
| Parser | 将 token 解析为声明、表达式、循环和属性等语法结构 | 与 AST 一起观察 | [`clang/lib/Parse`](https://github.com/llvm/llvm-project/tree/main/clang/lib/Parse) |
| Sema/AST | 类型检查、重载解析、名称绑定，并验证 SME 属性与 ACLE 内建函数是否满足目标特性 | `-Xclang -ast-dump -fsyntax-only` | [`clang/lib/Sema`](https://github.com/llvm/llvm-project/tree/main/clang/lib/Sema)、[Clang AST 说明](https://clang.llvm.org/docs/IntroductionToTheClangAST.html) |
| CodeGen | 遍历 AST，把函数、循环、内存访问和目标内建函数转换为 LLVM IR | `-S -emit-llvm` | [`clang/lib/CodeGen/CodeGenAction.cpp`](https://github.com/llvm/llvm-project/blob/main/clang/lib/CodeGen/CodeGenAction.cpp)、[`CodeGenFunction.cpp`](https://github.com/llvm/llvm-project/blob/main/clang/lib/CodeGen/CodeGenFunction.cpp) |
| IR 优化 | 按 `-O0/-O1/-O2/-O3` 构造 Pass pipeline，执行内联、循环和标量优化等 | `-Rpass` 或 `-mllvm -debug-pass-manager`（是否可用取决于发行版） | [`clang/lib/CodeGen/BackendUtil.cpp`](https://github.com/llvm/llvm-project/blob/main/clang/lib/CodeGen/BackendUtil.cpp)、[`llvm/lib/Passes/PassBuilder.cpp`](https://github.com/llvm/llvm-project/blob/main/llvm/lib/Passes/PassBuilder.cpp) |
| AArch64 后端 | IR 指令选择、合法化、寄存器分配、调度和 MC 编码 | `-S` 生成 `.s`，`-c` 生成 `.o` | [`llvm/lib/Target/AArch64`](https://github.com/llvm/llvm-project/tree/main/llvm/lib/Target/AArch64)、[LLVM Code Generator](https://llvm.org/docs/CodeGenerator.html) |
| 链接 | 合并目标文件和 C/C++、SME ABI 等运行时，生成可执行文件 | 不加 `-S` 或 `-c` | 驱动选择的系统链接器或 LLD |

其中从驱动进入前端的关键调用链可以概括为：

```text
clang++ main
  -> Driver::BuildCompilation
  -> 执行 clang -cc1 前端任务
  -> ExecuteCompilerInvocation
  -> CompilerInstance::ExecuteAction
  -> Parser + Sema 构造 AST
  -> CodeGenAction / CodeGenerator 构造 llvm::Module
  -> EmitBackendOutput 运行 LLVM Pass pipeline 并输出 IR/汇编/目标文件
```

这是便于定位源码的逻辑调用链；不同 LLVM/毕昇版本中的辅助函数和内部调用层次可能
发生变化。

### 2.4 当前 SME kernel 如何转换

#### 2.4.1 头文件与函数属性

`arm_sve.h` 和 `arm_sme.h` 位于编译器资源目录中。它们主要提供 ACLE 类型、属性、
重载入口和内建函数映射，不包含一个像普通 `.cpp` 库那样的循环实现。因此
`svld1_f64`、`svmopa_za64_f64_m` 等调用通常不会编译成对同名外部函数的调用。

`__arm_streaming` 和 `__arm_new("za")` 先作为 Clang 能理解的函数属性进入 AST，
随后转换为 LLVM IR 中的 AArch64/SME 函数属性及状态约束。编译器还会检查
`-march` 是否包含这些操作要求的特性，例如 `sme-f64f64`。

#### 2.4.2 SVE/SME 操作

以 kernel 中的语句为例：

```text
svwhilelt_b64(...)       -> 构造可伸缩向量谓词
svld1_f64(pg, ptr)       -> 带谓词的 SVE 向量加载
svmopa_za64_f64_m(...)   -> SME ZA 外积累加语义
svread_hor_za64_m(...)   -> 从 ZA 水平切片读取向量
svst1_f64(pg, ptr, vec)  -> 带谓词的 SVE 向量存储
```

CodeGen 会把这些目标相关操作降为 `llvm.aarch64.sve.*` 或
`llvm.aarch64.sme.*` 一类 LLVM intrinsic，普通地址计算则表现为 `getelementptr`
（GEP），循环表现为基本块、`phi` 和条件分支。intrinsic 的确切名称和参数随 LLVM
版本变化，应以服务器生成的 `.ll` 为准。

### 2.5 本项目预取 Pass 在流水线中的位置

本项目没有在 C++ AST 或 Clang CodeGen 中插入预取，而是在已经生成的 LLVM IR
上运行独立的 new-PM 插件：

```mermaid
flowchart LR
    A[C++ 与 SME ACLE] -->|毕昇 clang++ -O1 -emit-llvm| B[完整 LLVM IR]
    B --> C[提取 stencil kernel]
    C -->|独立 LLVM 19 opt| D[StencilAnalysis]
    D --> E[StencilPrefetchDecision]
    E --> F[插入 llvm.aarch64.prefetch]
    F -->|LLVM AArch64 后端| G[PRFM/PRFUM]
```

具体对应关系如下：

1. `01_llvm_ir_analysis/generate_and_check.sh` 调用毕昇 `clang++`，使用
   `-O1 -fno-inline -S -emit-llvm` 生成完整 `.ll`，再从包含 `test` 和 `main` 的
   Module 中提取 stencil kernel。
2. `02_llvm_pass_plugin/build_and_test.sh` 使用独立 LLVM 19 构建并加载
   `StencilPrefetchPass`。
3. `StencilAnalysis` 从 GEP、load、循环、SCEV 和可伸缩向量步长中恢复数据流；
   `StencilPrefetchDecision` 立即作出距离、层级和 KEEP/STRM 决策。
4. 同一个 Pass 在循环中插入 `llvm.aarch64.prefetch`，然后 `verify` 检查 IR。
5. AArch64 后端把 intrinsic 选择为目标预取指令。当前脚本还会核对 IR 中 intrinsic
   数量与汇编中的 `PRFM`/`PRFUM` 数量。

因此我们的 Pass 位于 **Clang 前端和初始 `-O1` IR 优化之后、AArch64 指令选择
之前**。它能看到规范化后的 SSA、GEP、循环和 SCEV，但已经失去一部分 C++ 层的
数组形状、源码变量名和 stencil 邻域表达式语义，这也是当前分析必须从 IR 拓扑
恢复物理流的原因。

### 2.6 在服务器观察每一步

以下命令只观察编译过程，不需要修改源码。`BISHENG_CXX` 应指向能直接编译原 SME
程序的毕昇 `clang++`：

```bash
# 1. 查看版本、资源头文件目录和 Driver 将执行的子任务。
"$BISHENG_CXX" --version
"$BISHENG_CXX" -print-resource-dir
"$BISHENG_CXX" -### -march=armv9-a+sme+sme-f64f64 stencil_all_sme.cpp

# 2. 查看预处理结果。
"$BISHENG_CXX" -E -march=armv9-a+sme+sme-f64f64 \
  stencil_all_sme.cpp -o stencil_all_sme.ii

# 3. 查看 Clang AST；输出很大，重定向到文件。
"$BISHENG_CXX" -march=armv9-a+sme+sme-f64f64 -fsyntax-only \
  -Xclang -ast-dump stencil_all_sme.cpp > stencil_all_sme.ast.txt

# 4. 生成 LLVM IR。项目步骤 1 使用 -O1 和 -fno-inline。
"$BISHENG_CXX" -O1 -fno-inline -S -emit-llvm \
  -march=armv9-a+sme+sme-f64f64 stencil_all_sme.cpp -o stencil_all_sme.ll

# 5. 不经过汇编和链接，直接查看 AArch64 汇编。
"$BISHENG_CXX" -O1 -S -march=armv9-a+sme+sme-f64f64 \
  stencil_all_sme.cpp -o stencil_all_sme.s
```

本项目的真实服务器流程不能简单地把所有步骤都换成独立 LLVM 的 `clang++`：原始
C++ 应先由毕昇前端处理 SME ACLE 与 ABI；独立 LLVM 19 负责读取兼容的 LLVM IR、
运行自定义 `opt` Pass。生成最终可执行文件时仍需使用能正确提供毕昇 SME ABI
运行时和链接参数的毕昇驱动。

## 3. SMEStencil 论文分析

### 3.1 论文信息与研究范围

本节分析本地论文
`论文/SMEStencil_Optimizing_High-Order_Stencils_on_ARM_Multicore_Using_SME_Unit.pdf`：

- 题目：*SMEStencil: Optimizing High-Order Stencils on ARM Multicore Using SME Unit*。
- 作者：Yinuo Wang、Tianqi Mao、Lin Gan 等。
- 期刊：IEEE Transactions on Parallel and Distributed Systems，Vol. 37，No. 3，
  2026 年 3 月。
- DOI：[10.1109/TPDS.2025.3650515](https://doi.org/10.1109/TPDS.2025.3650515)。

论文研究的是 **ARMv9-A 多核 CPU 上利用 SME 加速高阶 stencil 的全栈方案**。
它不仅优化单个 kernel，还同时处理内存布局、多核数据共享、NUMA 通信和真实 RTM
应用集成。论文不是编译器自动识别和插入软件预取的工作，也没有提出一个通用的
LLVM Pass。

### 3.2 研究问题

论文要解决的核心问题是：**如何让面向矩阵乘法设计的 SME 单元，在 3D 高阶
stencil 及真实 HPC 应用中持续获得高利用率，并使 ARM 多核 CPU 的端到端性能达到
或超过 GPU。** 这一问题可以拆成五个层次。

#### 3.2.1 高阶 3D stencil 的性能下降

简单的 2D stencil 和低阶 3D stencil 已能被编译器或手写 SIMD 高效执行，进一步
优化的空间有限。但是 stencil 半径增大后：

- 邻域点数和计算量增长，传统 SIMD 的指令数和调度压力随之增加；
- 工作集和 halo 扩大，跨行、跨平面访问以及数据复用更加困难；
- star 与 box 等不同拓扑的计算和访存特征差异很大；
- CPU 和 GPU 上已有方案的带宽利用率都会明显下降。

因此论文没有把“所有 stencil 都换成 SME”作为前提，而是把重点放在现有编译器和
SIMD 表现较差的 **3D 高阶 stencil** 上。

#### 3.2.2 stencil 与 SME 外积模型不天然匹配

SME 的核心计算形式是向量外积并累加到 ZA tile，而 stencil 是邻域加权求和。两者
需要进行算法映射。此外，3D stencil 的不同方向还带来不同问题：

- y 方向可以连续加载行向量，较容易映射；
- x 方向需要列向量，原始布局会产生非连续访问和转置开销；
- z 方向与 x/y 方向使用的 tile 形状不同，中间结果需要保存和重新加载；
- box stencil 分解为多个一维 stencil 后会产生重复加载和非对齐访问。

#### 3.2.3 SME 加速后瓶颈重新转向内存

SME 提高了计算吞吐率，但 stencil 仍需要持续读取输入并写回输出。论文平台的片上
高带宽内存具有很宽的数据端口；如果访问流数量过多、访问不连续或预取不及时，
理论带宽无法被充分利用。高计算吞吐反而使内存供给更容易成为瓶颈。

#### 3.2.4 多核私有缓存导致 halo 重复流量

论文平台没有可供所有核心共享的大容量 LLC，每个核心主要依赖私有数据缓存。
线程分块后，相邻 tile 的 halo 会被多个核心重复从内存读取，限制数据复用和带宽
效率。传统“交给共享 LLC”的做法在该平台上不可用。

#### 3.2.5 NUMA 与真实应用集成

真实 RTM 包含多种 stencil、混合偏导数、中间结果和标量运算，不是独立 benchmark
kernel。跨 NUMA 扩展时，MPI 的锁、halo 打包和通信也可能掩盖 kernel 加速收益。
论文因此还必须回答两个问题：优化 kernel 如何组合成真实应用，以及如何把性能扩展
到多个 NUMA 域和多个处理器。

### 3.3 研究目标

论文的目标不是只让某一个固定 stencil 获得最高速度，而是形成一个覆盖 kernel、
内存和并行层次的 SMEStencil 框架：

1. 建立 stencil 到 SME 外积的通用映射，使 star/box、2D/3D 和不同半径都能利用
   SME，而不是仅支持矩阵乘法或单一 stencil。
2. 通过 SME/SVE 微架构优化，减少跨方向访问、转置、中间结果和重复加载的成本。
3. 通过数据布局和软件预取提高片上高带宽内存利用率，使 SME 不因数据供给不足而
   空闲。
4. 在缺少共享 LLC 的多核平台上减少 halo 的重复主存流量。
5. 使用 NUMA 感知通信和计算通信重叠，提高多进程扩展性。
6. 将基本 stencil 算子组合到 VTI/TTI RTM 中，验证 kernel 收益能转化为真实应用
   的端到端收益。

### 3.4 具体方案

论文方案可以概括为以下流水线：

```mermaid
flowchart TD
    A[高阶 star/box stencil] --> B[按 x/y/z 分解为一维 stencil]
    B --> C[映射为 SME 外积与 ZA tile 累加]
    C --> D[Tile 级 ILP 与 ZA 辅助转置]
    D --> E[消除重复访问并安排中间结果]
    E --> F[brick 数据布局]
    F --> G[SVE gather-based 软件预取]
    G --> H[cache-snoop 多线程共享]
    H --> I[SDMA NUMA halo 交换与流水重叠]
    I --> J[组合为 VTI/TTI RTM]
```

#### 3.4.1 将 stencil 映射到 SME 外积

论文先把一维 stencil 映射为外积。设 SME 的输出 tile 为
`(Vx, Vy)`，stencil 半径为 `r`：

- y 方向从 `(Vx, Vy + 2r)` 输入块逐行加载 `(Vx, 1)` 向量；
- 将带有 stencil 系数和零元素的列向量作为另一外积操作数；
- 每次外积把一个输入向量按系数广播并累加到相应输出行；
- x 方向使用对称的列向量映射；
- z 方向把最外层维度按相同思想处理；
- 复杂 3D stencil 通过组合 x、y、z 三个方向的一维映射实现。

这不是把完整 stencil 先转换成通用矩阵乘法，而是直接利用“外积向 tile 多行或多列
广播并累加”的语义。

#### 3.4.2 初步性能模型

对于 SIMD 向量长度 `VL`、半径 `r` 的一维 stencil，论文比较计算一个
`(VL, VL)` 输出块所需的指令周期：

```text
Cycles_SIMD = VL * (2r + 1) * CPI_SIMD
Cycles_SME  = (VL + 2r) * CPI_SME

FLOPS_SMEStencil
  = [VL * (2r + 1) * CPI_SIMD / ((VL + 2r) * CPI_SME)]
    * FLOPS_SIMD
```

其中 `CPI_SIMD` 是 SIMD FMA 的每指令周期，`CPI_SME` 是 SME 外积的每指令周期。
该模型说明：SIMD 指令数随 `VL * (2r+1)` 增长，而 SME 外积数只随 `VL+2r`
增长，所以半径越大，SME 越可能体现计算吞吐优势。论文平台采用
`CPI_SIMD=0.5`、单精度 `CPI_SME=2` 的模型参数，并指出 `r>1` 时 SME 开始具有
理论优势。

该模型只估计计算部分，并不包含转置、load/store、cache miss 和中间结果开销；
这些成本由后续优化和实验进一步评估。

#### 3.4.3 四项微架构优化

论文围绕 SME/SVE 提出四项 kernel 级优化：

1. **Tile-Based ILP**：在多个 ZA matrix tile 之间交错执行彼此无依赖的外积，
   让乱序执行器隐藏外积延迟并提高指令级并行度。
2. **Tile-Assisted Vector Transpose**：x 方向需要列访问。论文不使用大量 SVE
   permutation，而是先水平写入 ZA tile，再从 ZA 垂直读出，实现 tile 辅助转置。
3. **Cache Pollution Avoiding Intermediate Result Placement**：x/y 与 z 方向 tile
   形状不一致，需要暂存部分结果。论文写入临时缓冲区，而不是直接写最终输出，
   避免最终目标的额外 read-for-ownership/写回过程污染缓存。
4. **Redundant-Access Zeroing Box Stencil**：把多个 y 方向一维 stencil 的选择放入
   内层，在一次迭代中共享相邻 cache line，并用 SIMD splice 提取各外积需要的
   数据，减少 box stencil 的重复和非对齐访问。

#### 3.4.4 数据布局优化

Tile-Based ILP 会同时访问大量离散数据流。论文以单精度 3DStarR4 为例，在
`Vx=Vy=16, Vz=4` 时可产生 226 条访问流，难以充分利用宽内存端口。

为此，论文借鉴 BrickLib，把规则网格重排为 `(Bx, By, Bz)` brick，并在 halo 与
brick 相交时加载整个 brick。论文取 `Bx=VL`、`By=Bz=4`，用更少、更连续的物理
访问流换取一定的 halo 额外流量。这里的 `4` 与其典型应用最大半径和 tile 整除
关系有关，不是适用于所有硬件和算子的通用常量。

#### 3.4.5 Gather-Based 软件预取

论文认为目标 ARM 多核核心的硬件预取能力不足，因此显式加入软件预取。其方案并非
为每条普通加载单独发出一个 64 B 预取，而是：

1. 先通过 brick layout 让一个 tile 需要的 cache line 具有规则结构；
2. 在 SVE 向量的每个 lane 中放置一个 cache line 头地址；
3. 使用 gather-prefetch，一条指令同时触达 `VL` 条 cache line；
4. 单精度情况下，用一次 gather-prefetch 覆盖一个 brick；
5. 以较少预取指令把内存访问与 SME 计算重叠，避免普通预取大量穿插后增加调度
   压力。

该方案的成立条件包括：已采用论文的 brick 数据布局、目标支持 SVE gather
prefetch、cache 以 cache line 为传输粒度，而且额外预取流量能够被高带宽内存
承受。

#### 3.4.6 真实应用的算子组合

论文提供处理 `(Vx, Vy, Vz)` 小块的基本一维 stencil 算子，再把复杂 RTM kernel
分解为一系列小算子。对于 TTI 中的混合二阶偏导：

- 先计算一阶导数并放入线程私有临时缓冲区；
- 利用混合偏导的交换性选择更有利的 x/y/z 组合顺序；
- 必要时对中间结果转置，再执行下一方向的一维 stencil；
- 最后用 SVE 标量/向量运算组合偏导数和介质参数。

只要临时缓冲区不挤出私有缓存，就可以在后续 stencil 中复用中间结果，避免回到
主存。

#### 3.4.7 多线程 cache-snoop 数据共享

在没有共享 LLC 的平台上，论文把每个线程的 tile 在空间上相邻放置，并让 tile 在
y 方向较窄。相邻线程读取 halo 时，如果数据已经在另一核心的私有缓存中，就通过
缓存一致性目录和片上互连取得，而不是再次读取主存。

该方案利用硬件 cache snoop 隐式共享 halo，减少每个核心必须独立维护的数据复用
维度。它依赖目标 SoC 的缓存一致性、核心拓扑和私有缓存容量，不是仅修改 kernel
内部指令即可获得的效果。

#### 3.4.8 NUMA 通信与流水重叠

论文在 NUMA 域内使用 OpenMP，在 NUMA 域间采用多进程。由于少量 MPI 进程难以
充分利用域间带宽，论文使用 SoC 的 SDMA 引擎执行异步、可跨步的 halo 拷贝。

网格沿 z 方向分层：CPU 计算当前层时，SDMA 传输下一层 halo；进入下一层前检查
传输是否完成。这样既避免 SDMA 占用 CPU 核心和污染 cache，也实现计算与通信
重叠。该方案是平台相关优化，需要目标服务器提供可编程 SDMA 能力。

### 3.5 实验如何验证方案

论文使用 8 个不同维度、形状和半径的 benchmark，包括 2D/3D、star/box 和多个
半径，并使用 elapsed time、Gpoints/s、有效带宽和实际 memory traffic 四类指标。
主要观察如下：

- brick layout 是 DDR 和片上高带宽内存上最主要的单项收益来源；
- cache-snoop 在四个代表性 3D kernel 上将全局内存流量降低约 22% 到 26%，在
  DDR 上带来最高约 26% 性能提升；
- gather-prefetch 在 DDR 上大多收益很小，但在片上高带宽内存上分别带来约
  38.09%、8.19%、24.26% 和 19.74% 的附加收益；
- 简单 3DStarR2 上手写 SIMD 仍可能优于 SME，说明 SME 并非对所有算子都适用；
- 对高阶 stencil，相比最佳 CPU 实现平均加速约 80%；
- VTI/TTI RTM 相比工业优化 SIMD 版本分别约为 2.00 倍和 2.06 倍；
- 多 NUMA/双 CPU 结合 SDMA 后，论文报告相对 GPU 实现最高 3.5 倍加速。

这些结果来自论文的特定 ARM 多核 SoC、片上内存、数据精度、布局和并行配置，不能
直接当作本项目服务器的预期加速比。

### 3.6 与本项目预取 Pass 的关系

论文能为本项目提供重要依据，但两种预取方案并不等价：

| 对比项 | SMEStencil 论文 | 本项目当前方案 |
|---|---|---|
| 实现层级 | 手工设计 kernel、布局和并行算法 | LLVM IR Function Pass |
| 数据布局 | 先将规则网格重排为 brick | 保留原 C++/LLVM IR 的线性布局 |
| 预取形式 | SVE gather-prefetch，一次覆盖多个 cache line | `llvm.aarch64.prefetch`，后端生成 `PRFM/PRFUM` |
| 候选单位 | 一个 brick 及其 halo cache line | 从循环、GEP 和 load 恢复出的物理访问流 |
| 决策依据 | 方案人工设计并通过分解实验验证 | 分析模型生成距离、cache 层级和 KEEP/STRM 决策 |
| 平台依赖 | 片上高带宽内存、SVE gather、SDMA、特定缓存拓扑 | LLVM/AArch64 通用表示加服务器 profile |

论文对当前工作的直接启示是：

1. **候选预取本身必须受布局和访问流数量约束。** 如果 IR 中仍有大量离散流，逐流
   插入预取可能只会增加指令和带宽压力；筛选 mask 并不能从根本上修复不合适的
   候选集合。
2. **预取收益高度依赖内存层次。** 论文中 gather-prefetch 在 DDR 上大多无明显
   收益、在片上高带宽内存上收益显著，因此 profile 至少要区分实际内存位置、延迟
   和可用带宽，不能只按 stencil 名称决策。
3. **短半径和规则硬件预取并不必然意味着无需软件预取。** 论文的短半径 halo
   brick 存在跨步访问，整 brick 预取可以改善连续传输；但这依赖额外流量可接受。
4. **预取必须与计算重叠且控制指令开销。** 论文选择 gather-prefetch 正是为了用
   更少指令覆盖更多 cache line。当前普通 `PRFM` 方案应把“每次迭代发出多少条
   预取”作为硬约束，而不仅考虑距离。
5. **SME 不应无条件替代 SIMD。** 简单和低阶算子可能已经接近峰值，甚至因 SME
   模式切换和中间结果开销而变慢；本项目的预取决策也应允许稳定地选择“不插入”。

论文没有回答如何从任意 LLVM IR 自动恢复 brick、如何自动选择预取距离/层级/
KEEP/STRM，也没有比较普通 `PRFM` 四类流。因此它可以支撑“高吞吐 SME stencil
需要布局感知、硬件感知的软件预取”这一研究动机，但不能单独证明本项目当前四类
预取和每项参数的具体取值正确。
