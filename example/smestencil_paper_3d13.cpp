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

// 四阶中心二阶导数系数。三个一维算子相加后构成半径为 2 的 3D 13 点 star stencil。
constexpr double kCenter = -7.5;
constexpr double kNear = 4.0 / 3.0;
constexpr double kFar = -1.0 / 12.0;

inline double axis_coefficient(int delta, bool include_center) {
    if (delta == 0)
        return include_center ? kCenter : 0.0;
    if (delta == -1 || delta == 1)
        return kNear;
    if (delta == -2 || delta == 2)
        return kFar;
    return 0.0;
}

// 构造 SMEStencil 论文第 IV-A 节中的移位系数列向量。
// lane r 对应输出行 i + r * stride，source_row_offset 表示当前加载行相对 i 的偏移。
static inline __attribute__((always_inline)) svfloat64_t paper_y_coefficients(
    svbool_t pg_rows, svint64_t row_lanes, int64_t source_row_offset, int stride)
    __arm_streaming {
    const svint64_t source = svdup_n_s64(source_row_offset);
    const svint64_t output_offsets = svmul_n_s64_x(pg_rows, row_lanes, stride);
    const svint64_t delta = svsub_s64_x(pg_rows, source, output_offsets);
    svfloat64_t coefficients = svdup_n_f64(0.0);

    for (int64_t offset = -2; offset <= 2; ++offset) {
        const svbool_t matches = svcmpeq_n_s64(pg_rows, delta, offset);
        coefficients = svsel_f64(
            matches, svdup_n_f64(axis_coefficient(static_cast<int>(offset), true)),
            coefficients);
    }
    return coefficients;
}

// 选择一个 ZA 行。x/z 方向向量只来自一个源行，不能广播累加到所有输出行。
static inline __attribute__((always_inline)) svfloat64_t paper_one_hot_row(
    svbool_t pg_rows, svint64_t row_lanes, int64_t output_row, double coefficient)
    __arm_streaming {
    const svbool_t selected = svcmpeq_n_s64(pg_rows, row_lanes, output_row);
    return svsel_f64(selected, svdup_n_f64(coefficient), svdup_n_f64(0.0));
}

}  // 匿名命名空间

// SMEStencil 论文第 IV-A 节的 3DStarR2 映射实现。
//
// 每次迭代计算一个 SVL x SVL 的 (i,j) 输出 tile。y 方向使用移位系数向量，使一个
// 输入行能为多个不同 ZA 行贡献数据；x/z 方向使用对称的行/列映射。此实现只验证
// 映射正确性，未包含论文中的 brick 布局、gather 预取或多核调度。
__arm_new("za")
void stencil3d_star_r2_sme_paper(const double* __restrict__ input,
                                 double* __restrict__ output,
                                 int depth,
                                 int rows,
                                 int cols,
                                 int stride)
    __arm_streaming {
    if (depth < 5 || rows < 5 || cols < 5 || stride <= 0)
        return;

    const int64_t lanes = static_cast<int64_t>(svcntd());
    const int64_t plane_size = static_cast<int64_t>(rows) * cols;
    const svbool_t pg_all = svptrue_b64();
    const svint64_t row_lanes = svindex_s64(0, 1);

    for (int k = 2; k < depth - 2; k += stride) {
        for (int i = 2; i < rows - 2; i += lanes * stride) {
            const svint64_t output_rows =
                svadd_n_s64_x(pg_all, svmul_n_s64_x(pg_all, row_lanes, stride), i);
            const svbool_t pg_rows = svcmplt_n_s64(pg_all, output_rows, rows - 2);
            const int64_t active_rows =
                std::min<int64_t>(lanes, (rows - 3 - i) / stride + 1);

            for (int j = 2; j < cols - 2; j += lanes * stride) {
                const svbool_t pg_cols = svwhilelt_b64_s64(j, cols - 2);
                if (!svptest_any(pg_all, pg_cols))
                    break;

                svzero_za();

                // y 方向：移位系数列向量 x 连续输入行。
                const int source_row_end =
                    std::min<int64_t>(rows, i + (lanes - 1) * stride + 3);
                for (int source_i = i - 2; source_i < source_row_end; ++source_i) {
                    const svfloat64_t coefficients = paper_y_coefficients(
                        pg_rows, row_lanes, static_cast<int64_t>(source_i - i), stride);
                    const int64_t source_index =
                        static_cast<int64_t>(k) * plane_size +
                        static_cast<int64_t>(source_i) * cols + j;
                    const svfloat64_t values = svld1_f64(pg_cols, &input[source_index]);
                    svmopa_za64_f64_m(0, pg_rows, pg_cols, coefficients, values);
                }

                // x 方向：仅选中的一个输出行 x 横向移位的输入行。
                // dx=0 已由 y 方向中的中心系数覆盖。
                for (int64_t row = 0; row < active_rows; ++row) {
                    for (int dx = -2; dx <= 2; ++dx) {
                        if (dx == 0)
                            continue;
                        const svfloat64_t coefficients = paper_one_hot_row(
                            pg_rows, row_lanes, row, axis_coefficient(dx, false));
                        const int64_t source_index =
                            static_cast<int64_t>(k) * plane_size +
                            static_cast<int64_t>(i + row * stride) * cols + j + dx;
                        const svfloat64_t values = svld1_f64(pg_cols, &input[source_index]);
                        svmopa_za64_f64_m(0, pg_rows, pg_cols, coefficients, values);
                    }
                }

                // z 方向：对相邻平面使用相同的选中行映射。
                for (int64_t row = 0; row < active_rows; ++row) {
                    for (int dz = -2; dz <= 2; ++dz) {
                        if (dz == 0)
                            continue;
                        const svfloat64_t coefficients = paper_one_hot_row(
                            pg_rows, row_lanes, row, axis_coefficient(dz, false));
                        const int64_t source_index =
                            static_cast<int64_t>(k + dz) * plane_size +
                            static_cast<int64_t>(i + row * stride) * cols + j;
                        const svfloat64_t values = svld1_f64(pg_cols, &input[source_index]);
                        svmopa_za64_f64_m(0, pg_rows, pg_cols, coefficients, values);
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

void stencil3d_star_r2_reference(const double* input,
                                 double* output,
                                 int depth,
                                 int rows,
                                 int cols) {
    const int64_t plane_size = static_cast<int64_t>(rows) * cols;
    for (int k = 2; k < depth - 2; ++k) {
        for (int i = 2; i < rows - 2; ++i) {
            for (int j = 2; j < cols - 2; ++j) {
                const int64_t center = static_cast<int64_t>(k) * plane_size +
                                       static_cast<int64_t>(i) * cols + j;
                double value = kCenter * input[center];
                for (int delta = 1; delta <= 2; ++delta) {
                    const double coefficient = axis_coefficient(delta, false);
                    value += coefficient *
                             (input[center - delta] + input[center + delta] +
                              input[center - static_cast<int64_t>(delta) * cols] +
                              input[center + static_cast<int64_t>(delta) * cols] +
                              input[center - static_cast<int64_t>(delta) * plane_size] +
                              input[center + static_cast<int64_t>(delta) * plane_size]);
                }
                output[center] = value;
            }
        }
    }
}

bool smestencil_paper_3d13_self_test() {
    // 在 512 位 SVL 系统上，此尺寸会同时产生行尾块和列尾块。
    constexpr int kDepth = 9;
    constexpr int kRows = 13;
    constexpr int kCols = 17;
    const int64_t element_count = static_cast<int64_t>(kDepth) * kRows * kCols;
    std::vector<double> input(element_count);
    std::vector<double> reference(element_count, -1.0);
    std::vector<double> actual(element_count, -1.0);

    for (int64_t index = 0; index < element_count; ++index)
        input[index] = std::sin(static_cast<double>(index) * 0.125) + index * 0.001;

    stencil3d_star_r2_reference(input.data(), reference.data(), kDepth, kRows, kCols);
    stencil3d_star_r2_sme_paper(input.data(), actual.data(), kDepth, kRows, kCols, 1);

    double max_error = 0.0;
    for (int64_t index = 0; index < element_count; ++index)
        max_error = std::max(max_error, std::abs(reference[index] - actual[index]));

    std::cout << "SMEStencil 3DStarR2 max error: " << max_error << '\n';
    return max_error <= 1.0e-11;
}

// 保持与 stencil_all_sme.cpp 相同的性能测试结构，便于按相同的 stride-1/stride-2
// 流程运行和对比两个实现。
double test_stencil_3d_star_r2(bool run_stride1, bool run_stride2) {
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
            stencil3d_star_r2_sme_paper(input, output, kDepth, kRows, kCols, stride);
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

    const double total_time = test_stencil_3d_star_r2(true, false) +
                              test_stencil_3d_star_r2(false, true);
    std::cout << "Total Time:" << total_time << std::endl;
    return 0;
}
#endif
