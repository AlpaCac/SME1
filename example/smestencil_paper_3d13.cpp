#include <arm_sme.h>
#include <arm_sve.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <vector>

namespace {

constexpr double kPointWeight = 1.0 / 13.0;

// 判断原始 stencil 中的一个 (dk, dy, dx) 相对偏移是否存在。
// 这里刻意保留原 stencil_all_sme.cpp 的非对称跨平面对角拓扑。
constexpr bool is_source_offset(int dk, int dy, int dx) {
    if (dk == 0 && dx == 0)
        return dy >= -1 && dy <= 1;
    if (dk == 0 && (dx == -1 || dx == 1))
        return dy == 0;
    if ((dk == -1 || dk == 1) && dx == 0)
        return dy >= -1 && dy <= 1;
    return (dk == -1 && dx == -1 && dy == 0) ||
           (dk == 1 && dx == 1 && dy == 0);
}

// 构造论文式移位系数列向量。lane r 对应输出行 i + r * stride；当前
// 输入行相对 i 的偏移为 source_row_offset。只有原算子实际使用的邻域 lane 为非零。
static inline __attribute__((always_inline)) svfloat64_t paper_stream_coefficients(
    svbool_t pg_rows,
    svint64_t row_lanes,
    int64_t source_row_offset,
    int stride,
    int dk,
    int dx) __arm_streaming {
    const svint64_t source = svdup_n_s64(source_row_offset);
    const svint64_t output_offsets = svmul_n_s64_x(pg_rows, row_lanes, stride);
    const svint64_t delta = svsub_s64_x(pg_rows, source, output_offsets);
    svfloat64_t coefficients = svdup_n_f64(0.0);

    for (int dy = -1; dy <= 1; ++dy) {
        if (!is_source_offset(dk, dy, dx))
            continue;
        const svbool_t matches = svcmpeq_n_s64(pg_rows, delta, dy);
        coefficients = svsel_f64(matches, svdup_n_f64(kPointWeight), coefficients);
    }
    return coefficients;
}

}  // 匿名命名空间

// 使用 SMEStencil 第 IV-A 节的外积映射，计算 stencil_all_sme.cpp 中相同的 3D 13 点算子。
//
// 每次迭代计算一个 SVL x SVL 的 (i,j) 输出 tile。每个 (dk, dx) 输入流加载连续行
// 向量；移位系数列向量只选择该流在原算子中存在的 dy 邻居。因此一次外积会为多个
// 不同 ZA 行贡献数据，而不再像原示例那样将同一输入广播到全部 ZA 行。
__arm_new("za")
void stencil3d_13point_sme_paper(const double* __restrict__ input,
                                  double* __restrict__ output,
                                  int depth,
                                  int rows,
                                  int cols,
                                  int stride)
    __arm_streaming {
    if (depth < 3 || rows < 3 || cols < 3 || stride <= 0)
        return;

    const int64_t lanes = static_cast<int64_t>(svcntd());
    const int64_t plane_size = static_cast<int64_t>(rows) * cols;
    const svbool_t pg_all = svptrue_b64();
    const svint64_t row_lanes = svindex_s64(0, 1);

    for (int k = 1; k < depth - 1; k += stride) {
        for (int i = 1; i < rows - 1; i += lanes * stride) {
            const svint64_t output_rows =
                svadd_n_s64_x(pg_all, svmul_n_s64_x(pg_all, row_lanes, stride), i);
            const svbool_t pg_rows = svcmplt_n_s64(pg_all, output_rows, rows - 1);
            const int64_t active_rows =
                std::min<int64_t>(lanes, (rows - 2 - i) / stride + 1);

            for (int j = 1; j < cols - 1; j += lanes * stride) {
                const svbool_t pg_cols = svwhilelt_b64_s64(j, cols - 1);
                if (!svptest_any(pg_all, pg_cols))
                    break;

                svzero_za();

                // 7 个物理连续输入流覆盖原算子的全部 13 个点；dy 关系由系数列编码。
                const int source_row_end =
                    std::min<int64_t>(rows, i + (lanes - 1) * stride + 2);
                for (int dk = -1; dk <= 1; ++dk) {
                    for (int dx = -1; dx <= 1; ++dx) {
                        if (!is_source_offset(dk, 0, dx) &&
                            !is_source_offset(dk, -1, dx) &&
                            !is_source_offset(dk, 1, dx))
                            continue;

                        for (int source_i = i - 1; source_i < source_row_end; ++source_i) {
                            const svfloat64_t coefficients = paper_stream_coefficients(
                                pg_rows,
                                row_lanes,
                                static_cast<int64_t>(source_i - i),
                                stride,
                                dk,
                                dx);
                            const int64_t source_index =
                                static_cast<int64_t>(k + dk) * plane_size +
                                static_cast<int64_t>(source_i) * cols + j + dx;
                            const svfloat64_t values = svld1_f64(pg_cols, &input[source_index]);
                            svmopa_za64_f64_m(0, pg_rows, pg_cols, coefficients, values);
                        }
                    }
                }

                // 每个 ZA 水平 slice 对应 tile 中一个不同的输出行。
                for (int64_t row = 0; row < active_rows; ++row) {
                    const svfloat64_t result =
                        svread_hor_za64_m(svdup_n_f64(0.0), pg_cols, 0, row);
                    const int64_t output_index =
                        static_cast<int64_t>(k) * plane_size +
                        static_cast<int64_t>(i + row * stride) * cols + j;
                    svst1_f64(pg_cols, &output[output_index], result);
                }
            }
        }
    }
}

void stencil3d_13point_reference(const double* input,
                                 double* output,
                                 int depth,
                                 int rows,
                                 int cols) {
    const int64_t plane_size = static_cast<int64_t>(rows) * cols;
    for (int k = 1; k < depth - 1; ++k) {
        for (int i = 1; i < rows - 1; ++i) {
            for (int j = 1; j < cols - 1; ++j) {
                const int64_t center = static_cast<int64_t>(k) * plane_size +
                                       static_cast<int64_t>(i) * cols + j;
                const double sum =
                    input[center] +
                    input[center - plane_size] + input[center + plane_size] +
                    input[center - cols] + input[center + cols] +
                    input[center - 1] + input[center + 1] +
                    input[center - plane_size - cols] + input[center - plane_size + cols] +
                    input[center + plane_size - cols] + input[center + plane_size + cols] +
                    input[center - plane_size - 1] + input[center + plane_size + 1];
                output[center] = kPointWeight * sum;
            }
        }
    }
}

bool smestencil_paper_3d13_self_test() {
    // 在 512 位 SVL 系统上，此尺寸会同时产生行尾块和列尾块。
    constexpr int kDepth = 7;
    constexpr int kRows = 13;
    constexpr int kCols = 17;
    const int64_t element_count = static_cast<int64_t>(kDepth) * kRows * kCols;
    std::vector<double> input(element_count);
    std::vector<double> reference(element_count, -1.0);
    std::vector<double> actual(element_count, -1.0);

    for (int64_t index = 0; index < element_count; ++index)
        input[index] = std::sin(static_cast<double>(index) * 0.125) + index * 0.001;

    stencil3d_13point_reference(input.data(), reference.data(), kDepth, kRows, kCols);
    stencil3d_13point_sme_paper(input.data(), actual.data(), kDepth, kRows, kCols, 1);

    double max_error = 0.0;
    for (int64_t index = 0; index < element_count; ++index)
        max_error = std::max(max_error, std::abs(reference[index] - actual[index]));

    std::cout << "SMEStencil 3D13P max error: " << max_error << '\n';
    return max_error <= 1.0e-11;
}

// 保持与 stencil_all_sme.cpp 相同的性能测试结构，便于按相同的 stride-1/stride-2
// 流程运行和对比两个实现。
double test_stencil_3d_13point(bool run_stride1, bool run_stride2) {
    std::cout << std::endl << "------3d13p-paper-----" << std::endl;
    constexpr int kDepth = 128;
    constexpr int kRows = 512;
    constexpr int kCols = 512;
    constexpr int kIterations = 100;
    const size_t bytes = static_cast<size_t>(kDepth) * kRows * kCols * sizeof(double);
    double* input = static_cast<double*>(aligned_alloc(64, bytes));
    double* output = static_cast<double*>(aligned_alloc(64, bytes));
    if (input == nullptr || output == nullptr) {
        std::cerr << "aligned_alloc failed" << std::endl;
        free(input);
        free(output);
        return 0.0;
    }

    double total_time = 0.0;
    const auto run = [&](int stride) {
        for (int k = 0; k < kDepth; ++k)
            for (int i = 0; i < kRows; ++i)
                for (int j = 0; j < kCols; ++j)
                    input[(k * kRows + i) * kCols + j] =
                        1.0 + static_cast<double>((k * kRows + i) * kCols + j);

        std::cout << "stride=" << stride << "..." << std::endl;
        const auto start = std::chrono::high_resolution_clock::now();
        for (int iteration = 0; iteration < kIterations; ++iteration)
            stencil3d_13point_sme_paper(input, output, kDepth, kRows, kCols, stride);
        const auto end = std::chrono::high_resolution_clock::now();
        const double elapsed = std::chrono::duration<double>(end - start).count();
        std::cout << "Time:" << elapsed << std::endl;
        total_time += elapsed;
    };

    if (run_stride1)
        run(1);
    if (run_stride2)
        run(2);

    free(input);
    free(output);
    return total_time;
}

#ifdef SMESTENCIL_PAPER_DEMO
int main() {
    if (!smestencil_paper_3d13_self_test())
        return 1;

    const double total_time = test_stencil_3d_13point(true, false) +
                              test_stencil_3d_13point(false, true);
    std::cout << "Total Time:" << total_time << std::endl;
    return 0;
}
#endif
