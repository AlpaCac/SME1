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

#if defined(SMESTENCIL_PAPER_SINGLE_ZA)
constexpr bool kUseTwoZaTiles = false;
#else
constexpr bool kUseTwoZaTiles = true;
#endif

#if defined(SMESTENCIL_PAPER_DISABLE_LOAD_REUSE)
constexpr bool kReuseOverlappingLoads = false;
#else
constexpr bool kReuseOverlappingLoads = true;
#endif

// 用 MOPA 的纵向谓词选择 dy=-1/0/+1 对应的 ZA 行，避免构造稀疏系数向量。
template <int Stride>
static inline __attribute__((always_inline)) svbool_t shifted_row_predicate(
    svbool_t pg_rows,
    svint64_t row_lanes,
    int64_t source_row_offset) __arm_streaming {
    int64_t first_row;
    int64_t last_row;
    if constexpr (Stride == 1) {
        first_row = source_row_offset - 1;
        last_row = source_row_offset + 1;
    } else {
        first_row = source_row_offset < 0 ? -1 : source_row_offset / 2;
        last_row = (source_row_offset + 1) / 2;
    }
    const svbool_t lower = svcmpge_n_s64(pg_rows, row_lanes, first_row);
    const svbool_t upper = svcmple_n_s64(pg_rows, row_lanes, last_row);
    return svand_b_z(pg_rows, lower, upper);
}

// 为只允许 dy=0 的四条流选择唯一的 ZA 输出行。
static inline __attribute__((always_inline)) svbool_t one_hot_row_predicate(
    svbool_t pg_rows, svint64_t row_lanes, int64_t output_row) __arm_streaming {
    return svcmpeq_n_s64(pg_rows, row_lanes, output_row);
}

template <int Tile>
static inline __attribute__((always_inline)) void accumulate_address(
    svbool_t selected_rows,
    svbool_t pg_cols,
    svfloat64_t weight,
    const double* address) __arm_streaming __arm_inout("za") {
    const svfloat64_t values = svld1_f64(pg_cols, address);
    svmopa_za64_f64_m(Tile, selected_rows, pg_cols, weight, values);
}

// 同平面的 dx=-1/0/+1 高度重叠。完整 tile 用两次 load 加两次 ext 构造三个
// 向量；尾 tile 回退到三个谓词 load，避免跨过当前输入行。
template <int Tile>
static inline __attribute__((always_inline)) void accumulate_same_plane(
    svbool_t shifted_rows,
    svbool_t one_hot_rows,
    svbool_t pg_cols,
    svbool_t pg_two,
    svfloat64_t weight,
    const double* center_address,
    bool output_row,
    bool full_tile) __arm_streaming __arm_inout("za") {
    if (output_row && full_tile && kReuseOverlappingLoads) {
        const svfloat64_t left_block = svld1_f64(pg_cols, center_address - 1);
        const svfloat64_t tail_block = svld1_f64(pg_two, center_address + svcntd() - 1);
        const svfloat64_t center = svext_f64(left_block, tail_block, 1);
        const svfloat64_t right = svext_f64(left_block, tail_block, 2);
        svmopa_za64_f64_m(Tile, shifted_rows, pg_cols, weight, center);
        svmopa_za64_f64_m(Tile, one_hot_rows, pg_cols, weight, left_block);
        svmopa_za64_f64_m(Tile, one_hot_rows, pg_cols, weight, right);
        return;
    }

    accumulate_address<Tile>(shifted_rows, pg_cols, weight, center_address);
    if (output_row) {
        accumulate_address<Tile>(one_hot_rows, pg_cols, weight, center_address - 1);
        accumulate_address<Tile>(one_hot_rows, pg_cols, weight, center_address + 1);
    }
}

template <int Tile>
static inline __attribute__((always_inline)) void write_output_rows(
    svbool_t pg_cols,
    double* output_base,
    int cols,
    int stride,
    int64_t active_rows) __arm_streaming __arm_inout("za") {
    for (int64_t row = 0; row < active_rows; ++row) {
        const svfloat64_t result =
            svread_hor_za64_m(svdup_n_f64(0.0), pg_cols, Tile, row);
        svst1_f64(pg_cols, output_base + row * stride * cols, result);
    }
}

template <int Stride>
static inline __attribute__((always_inline)) void stencil3d_13point_sme_paper_impl(
    const double* __restrict__ input,
    double* __restrict__ output,
    int depth,
    int rows,
    int cols) __arm_streaming __arm_inout("za") {
    static_assert(Stride == 1 || Stride == 2);
    const int64_t lanes = static_cast<int64_t>(svcntd());
    const int64_t plane_size = static_cast<int64_t>(rows) * cols;
    const int64_t column_step = lanes * Stride;
    const svbool_t pg_all = svptrue_b64();
    const svbool_t pg_two = svwhilelt_b64_s64(0, 2);
    const svint64_t row_lanes = svindex_s64(0, 1);
    const svfloat64_t weight = svdup_n_f64(kPointWeight);

    for (int k = 1; k < depth - 1; k += Stride) {
        for (int i = 1; i < rows - 1; i += lanes * Stride) {
            const svint64_t output_rows = svadd_n_s64_x(
                pg_all, svmul_n_s64_x(pg_all, row_lanes, Stride), i);
            const svbool_t pg_rows = svcmplt_n_s64(pg_all, output_rows, rows - 1);
            const int64_t active_rows =
                std::min<int64_t>(lanes, (rows - 2 - i) / Stride + 1);
            const int source_row_end =
                std::min<int64_t>(rows, i + (lanes - 1) * Stride + 2);

            // ZA0/ZA1 分别处理相邻的两个 j tile，使独立 MOPA 可以交错发射。
            const int64_t tile_group_step =
                (kUseTwoZaTiles ? 2 : 1) * column_step;
            for (int64_t j = 1; j < cols - 1; j += tile_group_step) {
                const int64_t next_j = j + column_step;
                const svbool_t pg_cols0 = svwhilelt_b64_s64(j, cols - 1);
                const svbool_t pg_cols1 = svwhilelt_b64_s64(next_j, cols - 1);
                const bool has_second_tile = kUseTwoZaTiles && next_j < cols - 1;
                const bool full_tile0 = j + lanes <= cols - 1;
                const bool full_tile1 = next_j + lanes <= cols - 1;
                svzero_za();

                for (int source_i = i - 1; source_i < source_row_end; ++source_i) {
                    const int64_t source_row_offset = source_i - i;
                    const svbool_t shifted_rows = shifted_row_predicate<Stride>(
                        pg_rows, row_lanes, source_row_offset);

                    bool has_output_row;
                    int64_t output_row_index;
                    if constexpr (Stride == 1) {
                        has_output_row = source_row_offset >= 0 &&
                                         source_row_offset < active_rows;
                        output_row_index = source_row_offset;
                    } else {
                        has_output_row = source_row_offset >= 0 &&
                                         (source_row_offset & 1) == 0 &&
                                         source_row_offset / 2 < active_rows;
                        output_row_index = source_row_offset / 2;
                    }
                    svbool_t one_hot_rows = svpfalse_b();
                    if (has_output_row) {
                        one_hot_rows = one_hot_row_predicate(
                            pg_rows, row_lanes, output_row_index);
                    }

                    const int64_t center0 =
                        static_cast<int64_t>(k) * plane_size +
                        static_cast<int64_t>(source_i) * cols + j;
                    accumulate_same_plane<0>(
                        shifted_rows,
                        one_hot_rows,
                        pg_cols0,
                        pg_two,
                        weight,
                        &input[center0],
                        has_output_row,
                        full_tile0);
                    if (has_second_tile) {
                        accumulate_same_plane<1>(
                            shifted_rows,
                            one_hot_rows,
                            pg_cols1,
                            pg_two,
                            weight,
                            &input[center0 + column_step],
                            has_output_row,
                            full_tile1);
                    }

                    // 相邻 z 平面的 dx=0 流共享移位系数列。
                    accumulate_address<0>(
                        shifted_rows,
                        pg_cols0,
                        weight,
                        &input[center0 - plane_size]);
                    if (has_second_tile) {
                        accumulate_address<1>(
                            shifted_rows,
                            pg_cols1,
                            weight,
                            &input[center0 - plane_size + column_step]);
                    }
                    accumulate_address<0>(
                        shifted_rows,
                        pg_cols0,
                        weight,
                        &input[center0 + plane_size]);
                    if (has_second_tile) {
                        accumulate_address<1>(
                            shifted_rows,
                            pg_cols1,
                            weight,
                            &input[center0 + plane_size + column_step]);
                    }

                    // 两条跨 z/x 对角流仅在 source_i 对应真实输出行时执行。
                    if (has_output_row) {
                        accumulate_address<0>(
                            one_hot_rows,
                            pg_cols0,
                            weight,
                            &input[center0 - plane_size - 1]);
                        if (has_second_tile) {
                            accumulate_address<1>(
                                one_hot_rows,
                                pg_cols1,
                                weight,
                                &input[center0 - plane_size - 1 + column_step]);
                        }
                        accumulate_address<0>(
                            one_hot_rows,
                            pg_cols0,
                            weight,
                            &input[center0 + plane_size + 1]);
                        if (has_second_tile) {
                            accumulate_address<1>(
                                one_hot_rows,
                                pg_cols1,
                                weight,
                                &input[center0 + plane_size + 1 + column_step]);
                        }
                    }
                }

                const int64_t output0 =
                    static_cast<int64_t>(k) * plane_size +
                    static_cast<int64_t>(i) * cols + j;
                write_output_rows<0>(
                    pg_cols0, &output[output0], cols, Stride, active_rows);
                if (has_second_tile) {
                    write_output_rows<1>(
                        pg_cols1,
                        &output[output0 + column_step],
                        cols,
                        Stride,
                        active_rows);
                }
            }
        }
    }
}

}  // 匿名命名空间

// 使用 SMEStencil 第 IV-A 节的外积映射，计算 stencil_all_sme.cpp 中相同的 3D 13 点算子。
//
// stride-1/2 分别生成专用实现；每次用 ZA0/ZA1 计算两个 SVL x SVL 输出 tile。
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
    if (stride == 1)
        stencil3d_13point_sme_paper_impl<1>(input, output, depth, rows, cols);
    else if (stride == 2)
        stencil3d_13point_sme_paper_impl<2>(input, output, depth, rows, cols);
}

int64_t smestencil_streaming_double_lanes() __arm_streaming {
    return static_cast<int64_t>(svcntd());
}

void stencil3d_13point_reference(const double* input,
                                 double* output,
                                 int depth,
                                 int rows,
                                 int cols,
                                 int stride,
                                 int64_t lanes) {
    const int64_t plane_size = static_cast<int64_t>(rows) * cols;
    for (int k = 1; k < depth - 1; k += stride) {
        for (int i = 1; i < rows - 1; i += stride) {
            for (int64_t block_j = 1; block_j < cols - 1;
                 block_j += lanes * stride) {
                for (int64_t lane = 0;
                     lane < lanes && block_j + lane < cols - 1;
                     ++lane) {
                    const int64_t j = block_j + lane;
                    const int64_t center = static_cast<int64_t>(k) * plane_size +
                                           static_cast<int64_t>(i) * cols + j;
                    const double sum =
                        input[center] +
                        input[center - plane_size] + input[center + plane_size] +
                        input[center - cols] + input[center + cols] +
                        input[center - 1] + input[center + 1] +
                        input[center - plane_size - cols] +
                        input[center - plane_size + cols] +
                        input[center + plane_size - cols] +
                        input[center + plane_size + cols] +
                        input[center - plane_size - 1] +
                        input[center + plane_size + 1];
                    output[center] = kPointWeight * sum;
                }
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
    for (int64_t index = 0; index < element_count; ++index)
        input[index] = std::sin(static_cast<double>(index) * 0.125) + index * 0.001;

    const int64_t lanes = smestencil_streaming_double_lanes();
    double max_error = 0.0;
    for (int stride : {1, 2}) {
        std::vector<double> reference(element_count, -1.0);
        std::vector<double> actual(element_count, -1.0);
        stencil3d_13point_reference(
            input.data(), reference.data(), kDepth, kRows, kCols, stride, lanes);
        stencil3d_13point_sme_paper(
            input.data(), actual.data(), kDepth, kRows, kCols, stride);

        double stride_error = 0.0;
        for (int64_t index = 0; index < element_count; ++index) {
            stride_error =
                std::max(stride_error, std::abs(reference[index] - actual[index]));
        }
        std::cout << "SMEStencil 3D13P stride-" << stride
                  << " max error: " << stride_error << '\n';
        max_error = std::max(max_error, stride_error);
    }

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
