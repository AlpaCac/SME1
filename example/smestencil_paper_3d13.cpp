#include <arm_sme.h>
#include <arm_sve.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
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
static inline __attribute__((always_inline)) void accumulate_three_columns(
    svbool_t left_rows,
    svbool_t center_rows,
    svbool_t right_rows,
    svbool_t pg_cols,
    svbool_t pg_two,
    svfloat64_t weight,
    const double* center_address,
    bool full_tile) __arm_streaming __arm_inout("za") {
    if (full_tile && kReuseOverlappingLoads) {
        const svfloat64_t left = svld1_f64(pg_cols, center_address - 1);
        const svfloat64_t tail = svld1_f64(pg_two, center_address + svcntd() - 1);
        const svfloat64_t center = svext_f64(left, tail, 1);
        const svfloat64_t right = svext_f64(left, tail, 2);
        svmopa_za64_f64_m(Tile, left_rows, pg_cols, weight, left);
        svmopa_za64_f64_m(Tile, center_rows, pg_cols, weight, center);
        svmopa_za64_f64_m(Tile, right_rows, pg_cols, weight, right);
        return;
    }

    accumulate_address<Tile>(left_rows, pg_cols, weight, center_address - 1);
    accumulate_address<Tile>(center_rows, pg_cols, weight, center_address);
    accumulate_address<Tile>(right_rows, pg_cols, weight, center_address + 1);
}

template <int Stride>
static inline __attribute__((always_inline)) bool source_output_row(
    int64_t source_row_offset,
    int64_t active_rows,
    int64_t& output_row_index) __arm_streaming {
    static_assert(Stride == 1 || Stride == 2);
    if constexpr (Stride == 1) {
        output_row_index = source_row_offset;
        return source_row_offset >= 0 && source_row_offset < active_rows;
    } else {
        output_row_index = source_row_offset / 2;
        return source_row_offset >= 0 && (source_row_offset & 1) == 0 &&
               output_row_index < active_rows;
    }
}

template <int Stride>
static inline __attribute__((always_inline)) svbool_t exact_delta_row_predicate(
    svbool_t pg_rows,
    svint64_t row_lanes,
    int64_t source_row_offset,
    int64_t delta) __arm_streaming {
    const int64_t numerator = source_row_offset - delta;
    if (numerator < 0 || numerator % Stride != 0)
        return svpfalse_b();
    return one_hot_row_predicate(pg_rows, row_lanes, numerator / Stride);
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
static inline __attribute__((always_inline)) void stencil1d_3point_sme_paper_impl(
    const double* __restrict__ input,
    double* __restrict__ output,
    int size) __arm_streaming __arm_inout("za") {
    static_assert(Stride == 1 || Stride == 2);
    const int64_t lanes = static_cast<int64_t>(svcntd());
    const int64_t column_step = lanes * Stride;
    const int64_t tile_group_step = (kUseTwoZaTiles ? 2 : 1) * column_step;
    const svbool_t row0 = svwhilelt_b64_s64(0, 1);
    const svbool_t pg_two = svwhilelt_b64_s64(0, 2);
    const svfloat64_t weight = svdup_n_f64(1.0 / 3.0);

    for (int64_t index = 1; index < size - 1; index += tile_group_step) {
        const int64_t next_index = index + column_step;
        const svbool_t pg_cols0 = svwhilelt_b64_s64(index, size - 1);
        const svbool_t pg_cols1 = svwhilelt_b64_s64(next_index, size - 1);
        const bool has_second_tile = kUseTwoZaTiles && next_index < size - 1;
        svzero_za();

        accumulate_three_columns<0>(
            row0,
            row0,
            row0,
            pg_cols0,
            pg_two,
            weight,
            &input[index],
            index + lanes <= size - 1);
        if (has_second_tile) {
            accumulate_three_columns<1>(
                row0,
                row0,
                row0,
                pg_cols1,
                pg_two,
                weight,
                &input[next_index],
                next_index + lanes <= size - 1);
        }

        const svfloat64_t result0 =
            svread_hor_za64_m(svdup_n_f64(0.0), pg_cols0, 0, 0);
        svst1_f64(pg_cols0, &output[index], result0);
        if (has_second_tile) {
            const svfloat64_t result1 =
                svread_hor_za64_m(svdup_n_f64(0.0), pg_cols1, 1, 0);
            svst1_f64(pg_cols1, &output[next_index], result1);
        }
    }
}

enum class Paper2DKind { Point5, Point9 };

template <Paper2DKind Kind, int Stride>
static inline __attribute__((always_inline)) void stencil2d_sme_paper_impl(
    const double* __restrict__ input,
    double* __restrict__ output,
    int rows,
    int cols) __arm_streaming __arm_inout("za") {
    static_assert(Stride == 1 || Stride == 2);
    constexpr double point_weight = Kind == Paper2DKind::Point5 ? 1.0 / 5.0 : 1.0 / 9.0;
    const int64_t lanes = static_cast<int64_t>(svcntd());
    const int64_t column_step = lanes * Stride;
    const int64_t tile_group_step = (kUseTwoZaTiles ? 2 : 1) * column_step;
    const svbool_t pg_all = svptrue_b64();
    const svbool_t pg_two = svwhilelt_b64_s64(0, 2);
    const svint64_t row_lanes = svindex_s64(0, 1);
    const svfloat64_t weight = svdup_n_f64(point_weight);

    for (int i = 1; i < rows - 1; i += lanes * Stride) {
        const svint64_t output_rows = svadd_n_s64_x(
            pg_all, svmul_n_s64_x(pg_all, row_lanes, Stride), i);
        const svbool_t pg_rows = svcmplt_n_s64(pg_all, output_rows, rows - 1);
        const int64_t active_rows =
            std::min<int64_t>(lanes, (rows - 2 - i) / Stride + 1);
        const int source_row_end =
            std::min<int64_t>(rows, i + (lanes - 1) * Stride + 2);

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
                int64_t output_row_index;
                const bool has_output_row = source_output_row<Stride>(
                    source_row_offset, active_rows, output_row_index);
                svbool_t one_hot_rows = svpfalse_b();
                if (has_output_row) {
                    one_hot_rows = one_hot_row_predicate(
                        pg_rows, row_lanes, output_row_index);
                }

                const int64_t center0 = static_cast<int64_t>(source_i) * cols + j;
                if constexpr (Kind == Paper2DKind::Point5) {
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
                } else {
                    accumulate_three_columns<0>(
                        shifted_rows,
                        shifted_rows,
                        shifted_rows,
                        pg_cols0,
                        pg_two,
                        weight,
                        &input[center0],
                        full_tile0);
                    if (has_second_tile) {
                        accumulate_three_columns<1>(
                            shifted_rows,
                            shifted_rows,
                            shifted_rows,
                            pg_cols1,
                            pg_two,
                            weight,
                            &input[center0 + column_step],
                            full_tile1);
                    }
                }
            }

            const int64_t output0 = static_cast<int64_t>(i) * cols + j;
            write_output_rows<0>(pg_cols0, &output[output0], cols, Stride, active_rows);
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

enum class Paper3DBoxKind { Point25, Point27 };

template <Paper3DBoxKind Kind, int Stride>
static inline __attribute__((always_inline)) void stencil3d_box_sme_paper_impl(
    const double* __restrict__ input,
    double* __restrict__ output,
    int depth,
    int rows,
    int cols) __arm_streaming __arm_inout("za") {
    static_assert(Stride == 1 || Stride == 2);
    constexpr double point_weight =
        Kind == Paper3DBoxKind::Point25 ? 1.0 / 25.0 : 1.0 / 27.0;
    const int64_t lanes = static_cast<int64_t>(svcntd());
    const int64_t plane_size = static_cast<int64_t>(rows) * cols;
    const int64_t column_step = lanes * Stride;
    const int64_t tile_group_step = (kUseTwoZaTiles ? 2 : 1) * column_step;
    const svbool_t pg_all = svptrue_b64();
    const svbool_t pg_two = svwhilelt_b64_s64(0, 2);
    const svint64_t row_lanes = svindex_s64(0, 1);
    const svfloat64_t weight = svdup_n_f64(point_weight);

    for (int k = 1; k < depth - 1; k += Stride) {
        for (int i = 1; i < rows - 1; i += lanes * Stride) {
            const svint64_t output_rows = svadd_n_s64_x(
                pg_all, svmul_n_s64_x(pg_all, row_lanes, Stride), i);
            const svbool_t pg_rows = svcmplt_n_s64(pg_all, output_rows, rows - 1);
            const int64_t active_rows =
                std::min<int64_t>(lanes, (rows - 2 - i) / Stride + 1);
            const int source_row_end =
                std::min<int64_t>(rows, i + (lanes - 1) * Stride + 2);

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
                    svbool_t minus_left_rows = shifted_rows;
                    svbool_t plus_right_rows = shifted_rows;
                    if constexpr (Kind == Paper3DBoxKind::Point25) {
                        const svbool_t minus_corner = exact_delta_row_predicate<Stride>(
                            pg_rows, row_lanes, source_row_offset, -1);
                        const svbool_t plus_corner = exact_delta_row_predicate<Stride>(
                            pg_rows, row_lanes, source_row_offset, 1);
                        minus_left_rows = svbic_b_z(pg_rows, shifted_rows, minus_corner);
                        plus_right_rows = svbic_b_z(pg_rows, shifted_rows, plus_corner);
                    }

                    const int64_t center0 =
                        static_cast<int64_t>(k) * plane_size +
                        static_cast<int64_t>(source_i) * cols + j;
                    accumulate_three_columns<0>(
                        minus_left_rows,
                        shifted_rows,
                        shifted_rows,
                        pg_cols0,
                        pg_two,
                        weight,
                        &input[center0 - plane_size],
                        full_tile0);
                    accumulate_three_columns<0>(
                        shifted_rows,
                        shifted_rows,
                        shifted_rows,
                        pg_cols0,
                        pg_two,
                        weight,
                        &input[center0],
                        full_tile0);
                    accumulate_three_columns<0>(
                        shifted_rows,
                        shifted_rows,
                        plus_right_rows,
                        pg_cols0,
                        pg_two,
                        weight,
                        &input[center0 + plane_size],
                        full_tile0);
                    if (has_second_tile) {
                        accumulate_three_columns<1>(
                            minus_left_rows,
                            shifted_rows,
                            shifted_rows,
                            pg_cols1,
                            pg_two,
                            weight,
                            &input[center0 - plane_size + column_step],
                            full_tile1);
                        accumulate_three_columns<1>(
                            shifted_rows,
                            shifted_rows,
                            shifted_rows,
                            pg_cols1,
                            pg_two,
                            weight,
                            &input[center0 + column_step],
                            full_tile1);
                        accumulate_three_columns<1>(
                            shifted_rows,
                            shifted_rows,
                            plus_right_rows,
                            pg_cols1,
                            pg_two,
                            weight,
                            &input[center0 + plane_size + column_step],
                            full_tile1);
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

__arm_new("za")
void stencil1d_3point_sme_paper(const double* __restrict__ input,
                                double* __restrict__ output,
                                int size,
                                int stride)
    __arm_streaming {
    if (size < 3 || stride <= 0)
        return;
    if (stride == 1)
        stencil1d_3point_sme_paper_impl<1>(input, output, size);
    else if (stride == 2)
        stencil1d_3point_sme_paper_impl<2>(input, output, size);
}

__arm_new("za")
void stencil2d_5point_sme_paper(const double* __restrict__ input,
                                double* __restrict__ output,
                                int rows,
                                int cols,
                                int stride)
    __arm_streaming {
    if (rows < 3 || cols < 3 || stride <= 0)
        return;
    if (stride == 1)
        stencil2d_sme_paper_impl<Paper2DKind::Point5, 1>(input, output, rows, cols);
    else if (stride == 2)
        stencil2d_sme_paper_impl<Paper2DKind::Point5, 2>(input, output, rows, cols);
}

__arm_new("za")
void stencil2d_9point_sme_paper(const double* __restrict__ input,
                                double* __restrict__ output,
                                int rows,
                                int cols,
                                int stride)
    __arm_streaming {
    if (rows < 3 || cols < 3 || stride <= 0)
        return;
    if (stride == 1)
        stencil2d_sme_paper_impl<Paper2DKind::Point9, 1>(input, output, rows, cols);
    else if (stride == 2)
        stencil2d_sme_paper_impl<Paper2DKind::Point9, 2>(input, output, rows, cols);
}

__arm_new("za")
void stencil3d_25point_sme_paper(const double* __restrict__ input,
                                 double* __restrict__ output,
                                 int depth,
                                 int rows,
                                 int cols,
                                 int stride)
    __arm_streaming {
    if (depth < 3 || rows < 3 || cols < 3 || stride <= 0)
        return;
    if (stride == 1) {
        stencil3d_box_sme_paper_impl<Paper3DBoxKind::Point25, 1>(
            input, output, depth, rows, cols);
    } else if (stride == 2) {
        stencil3d_box_sme_paper_impl<Paper3DBoxKind::Point25, 2>(
            input, output, depth, rows, cols);
    }
}

__arm_new("za")
void stencil3d_27point_sme_paper(const double* __restrict__ input,
                                 double* __restrict__ output,
                                 int depth,
                                 int rows,
                                 int cols,
                                 int stride)
    __arm_streaming {
    if (depth < 3 || rows < 3 || cols < 3 || stride <= 0)
        return;
    if (stride == 1) {
        stencil3d_box_sme_paper_impl<Paper3DBoxKind::Point27, 1>(
            input, output, depth, rows, cols);
    } else if (stride == 2) {
        stencil3d_box_sme_paper_impl<Paper3DBoxKind::Point27, 2>(
            input, output, depth, rows, cols);
    }
}

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

double max_output_error(const std::vector<double>& reference,
                        const std::vector<double>& actual) {
    double max_error = 0.0;
    for (size_t index = 0; index < reference.size(); ++index)
        max_error = std::max(max_error, std::abs(reference[index] - actual[index]));
    return max_error;
}

void stencil1d_3point_reference(const double* input,
                                double* output,
                                int size,
                                int stride,
                                int64_t lanes) {
    for (int64_t block = 1; block < size - 1; block += lanes * stride) {
        for (int64_t lane = 0; lane < lanes && block + lane < size - 1; ++lane) {
            const int64_t index = block + lane;
            output[index] =
                (input[index - 1] + input[index] + input[index + 1]) / 3.0;
        }
    }
}

void stencil2d_reference(const double* input,
                         double* output,
                         int rows,
                         int cols,
                         int stride,
                         int64_t lanes,
                         bool point9) {
    const double weight = point9 ? 1.0 / 9.0 : 1.0 / 5.0;
    for (int i = 1; i < rows - 1; i += stride) {
        for (int64_t block_j = 1; block_j < cols - 1;
             block_j += lanes * stride) {
            for (int64_t lane = 0;
                 lane < lanes && block_j + lane < cols - 1;
                 ++lane) {
                const int64_t j = block_j + lane;
                const int64_t center = static_cast<int64_t>(i) * cols + j;
                double sum = 0.0;
                if (point9) {
                    for (int dy = -1; dy <= 1; ++dy)
                        for (int dx = -1; dx <= 1; ++dx)
                            sum += input[center + static_cast<int64_t>(dy) * cols + dx];
                } else {
                    sum = input[center] + input[center - cols] + input[center + cols] +
                          input[center - 1] + input[center + 1];
                }
                output[center] = sum * weight;
            }
        }
    }
}

void stencil3d_box_reference(const double* input,
                             double* output,
                             int depth,
                             int rows,
                             int cols,
                             int stride,
                             int64_t lanes,
                             bool point27) {
    const int64_t plane_size = static_cast<int64_t>(rows) * cols;
    const double weight = point27 ? 1.0 / 27.0 : 1.0 / 25.0;
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
                    double sum = 0.0;
                    for (int dz = -1; dz <= 1; ++dz) {
                        for (int dy = -1; dy <= 1; ++dy) {
                            for (int dx = -1; dx <= 1; ++dx) {
                                // 25P 是 3x3x3 box 去掉两个相对角点。
                                if (!point27 &&
                                    ((dz == -1 && dy == -1 && dx == -1) ||
                                     (dz == 1 && dy == 1 && dx == 1))) {
                                    continue;
                                }
                                sum += input[center + static_cast<int64_t>(dz) * plane_size +
                                             static_cast<int64_t>(dy) * cols + dx];
                            }
                        }
                    }
                    output[center] = sum * weight;
                }
            }
        }
    }
}

bool smestencil_paper_1d3p_self_test() {
    const int64_t lanes = smestencil_streaming_double_lanes();
    const int size = static_cast<int>(4 * lanes + 7);
    std::vector<double> input(size);
    for (int index = 0; index < size; ++index)
        input[index] = std::sin(index * 0.125) + index * 0.001;

    double max_error = 0.0;
    for (int stride : {1, 2}) {
        std::vector<double> reference(size, -1.0);
        std::vector<double> actual(size, -1.0);
        stencil1d_3point_reference(
            input.data(), reference.data(), size, stride, lanes);
        stencil1d_3point_sme_paper(input.data(), actual.data(), size, stride);
        const double stride_error = max_output_error(reference, actual);
        std::cout << "SMEStencil 1D3P stride-" << stride
                  << " max error: " << stride_error << '\n';
        max_error = std::max(max_error, stride_error);
    }
    return max_error <= 1.0e-11;
}

bool smestencil_paper_2d_self_test(bool point9) {
    const int64_t lanes = smestencil_streaming_double_lanes();
    const int rows = static_cast<int>(2 * lanes + 7);
    const int cols = static_cast<int>(4 * lanes + 7);
    const int64_t element_count = static_cast<int64_t>(rows) * cols;
    std::vector<double> input(element_count);
    for (int64_t index = 0; index < element_count; ++index)
        input[index] = std::sin(index * 0.125) + index * 0.001;

    double max_error = 0.0;
    for (int stride : {1, 2}) {
        std::vector<double> reference(element_count, -1.0);
        std::vector<double> actual(element_count, -1.0);
        stencil2d_reference(
            input.data(), reference.data(), rows, cols, stride, lanes, point9);
        if (point9) {
            stencil2d_9point_sme_paper(
                input.data(), actual.data(), rows, cols, stride);
        } else {
            stencil2d_5point_sme_paper(
                input.data(), actual.data(), rows, cols, stride);
        }
        const double stride_error = max_output_error(reference, actual);
        std::cout << "SMEStencil " << (point9 ? "2D9P" : "2D5P")
                  << " stride-" << stride << " max error: " << stride_error << '\n';
        max_error = std::max(max_error, stride_error);
    }
    return max_error <= 1.0e-11;
}

bool smestencil_paper_3d_box_self_test(bool point27) {
    const int64_t lanes = smestencil_streaming_double_lanes();
    constexpr int depth = 7;
    const int rows = static_cast<int>(2 * lanes + 7);
    const int cols = static_cast<int>(4 * lanes + 7);
    const int64_t element_count = static_cast<int64_t>(depth) * rows * cols;
    std::vector<double> input(element_count);
    for (int64_t index = 0; index < element_count; ++index)
        input[index] = std::sin(index * 0.125) + index * 0.001;

    double max_error = 0.0;
    for (int stride : {1, 2}) {
        std::vector<double> reference(element_count, -1.0);
        std::vector<double> actual(element_count, -1.0);
        stencil3d_box_reference(input.data(),
                                reference.data(),
                                depth,
                                rows,
                                cols,
                                stride,
                                lanes,
                                point27);
        if (point27) {
            stencil3d_27point_sme_paper(
                input.data(), actual.data(), depth, rows, cols, stride);
        } else {
            stencil3d_25point_sme_paper(
                input.data(), actual.data(), depth, rows, cols, stride);
        }
        const double stride_error = max_output_error(reference, actual);
        std::cout << "SMEStencil " << (point27 ? "3D27P" : "3D25P")
                  << " stride-" << stride << " max error: " << stride_error << '\n';
        max_error = std::max(max_error, stride_error);
    }
    return max_error <= 1.0e-11;
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

        const double stride_error = max_output_error(reference, actual);
        std::cout << "SMEStencil 3D13P stride-" << stride
                  << " max error: " << stride_error << '\n';
        max_error = std::max(max_error, stride_error);
    }

    return max_error <= 1.0e-11;
}

double test_stencil_1d_3point(bool run_stride1, bool run_stride2) {
    std::cout << std::endl << "------1d3p-paper-----" << std::endl;
    constexpr int kSize = 1048576;
    constexpr int kIterations = 100;
    const size_t bytes = static_cast<size_t>(kSize) * sizeof(double);
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
        for (int i = 0; i < kSize; ++i)
            input[i] = 1.0 + i;
        std::cout << "stride=" << stride << "..." << std::endl;
        const auto start = std::chrono::high_resolution_clock::now();
        for (int iteration = 0; iteration < kIterations; ++iteration)
            stencil1d_3point_sme_paper(input, output, kSize, stride);
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

double test_stencil_2d(bool point9, bool run_stride1, bool run_stride2) {
    std::cout << std::endl << (point9 ? "------2d9p-paper-----" : "------2d5p-paper-----")
              << std::endl;
    constexpr int kRows = 1024;
    constexpr int kCols = 1024;
    constexpr int kIterations = 100;
    const size_t bytes = static_cast<size_t>(kRows) * kCols * sizeof(double);
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
        for (int i = 0; i < kRows; ++i)
            for (int j = 0; j < kCols; ++j)
                input[i * kCols + j] = 1.0 + static_cast<double>(i * kCols + j);
        std::cout << "stride=" << stride << "..." << std::endl;
        const auto start = std::chrono::high_resolution_clock::now();
        for (int iteration = 0; iteration < kIterations; ++iteration) {
            if (point9)
                stencil2d_9point_sme_paper(input, output, kRows, kCols, stride);
            else
                stencil2d_5point_sme_paper(input, output, kRows, kCols, stride);
        }
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

double test_stencil_2d_5point(bool run_stride1, bool run_stride2) {
    return test_stencil_2d(false, run_stride1, run_stride2);
}

double test_stencil_2d_9point(bool run_stride1, bool run_stride2) {
    return test_stencil_2d(true, run_stride1, run_stride2);
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

double test_stencil_3d_box(bool point27, bool run_stride1, bool run_stride2) {
    std::cout << std::endl
              << (point27 ? "------3d27p-paper-----" : "------3d25p-paper-----")
              << std::endl;
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
        for (int iteration = 0; iteration < kIterations; ++iteration) {
            if (point27) {
                stencil3d_27point_sme_paper(
                    input, output, kDepth, kRows, kCols, stride);
            } else {
                stencil3d_25point_sme_paper(
                    input, output, kDepth, kRows, kCols, stride);
            }
        }
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

double test_stencil_3d_25point(bool run_stride1, bool run_stride2) {
    return test_stencil_3d_box(false, run_stride1, run_stride2);
}

double test_stencil_3d_27point(bool run_stride1, bool run_stride2) {
    return test_stencil_3d_box(true, run_stride1, run_stride2);
}

#ifdef SMESTENCIL_PAPER_DEMO
int main(int argc, char* argv[]) {
    bool self_test_only = false;
    bool run_1d3p_s1 = false, run_1d3p_s2 = false;
    bool run_2d5p_s1 = false, run_2d5p_s2 = false;
    bool run_2d9p_s1 = false, run_2d9p_s2 = false;
    bool run_3d13p_s1 = false, run_3d13p_s2 = false;
    bool run_3d25p_s1 = false, run_3d25p_s2 = false;
    bool run_3d27p_s1 = false, run_3d27p_s2 = false;

    const auto print_usage = [&]() {
        std::cout << "Usage: " << argv[0] << " [options]\n"
                  << "  --1d3p-s1  --1d3p-s2\n"
                  << "  --2d5p-s1  --2d5p-s2\n"
                  << "  --2d9p-s1  --2d9p-s2\n"
                  << "  --3d13p-s1 --3d13p-s2\n"
                  << "  --3d25p-s1 --3d25p-s2\n"
                  << "  --3d27p-s1 --3d27p-s2\n"
                  << "  --self-test-only  只运行所选算子的正确性自检" << std::endl;
    };
    if (argc == 1) {
        print_usage();
        return 1;
    }

    for (int arg = 1; arg < argc; ++arg) {
        if (std::strcmp(argv[arg], "--1d3p-s1") == 0) run_1d3p_s1 = true;
        else if (std::strcmp(argv[arg], "--1d3p-s2") == 0) run_1d3p_s2 = true;
        else if (std::strcmp(argv[arg], "--2d5p-s1") == 0) run_2d5p_s1 = true;
        else if (std::strcmp(argv[arg], "--2d5p-s2") == 0) run_2d5p_s2 = true;
        else if (std::strcmp(argv[arg], "--2d9p-s1") == 0) run_2d9p_s1 = true;
        else if (std::strcmp(argv[arg], "--2d9p-s2") == 0) run_2d9p_s2 = true;
        else if (std::strcmp(argv[arg], "--3d13p-s1") == 0) run_3d13p_s1 = true;
        else if (std::strcmp(argv[arg], "--3d13p-s2") == 0) run_3d13p_s2 = true;
        else if (std::strcmp(argv[arg], "--3d25p-s1") == 0) run_3d25p_s1 = true;
        else if (std::strcmp(argv[arg], "--3d25p-s2") == 0) run_3d25p_s2 = true;
        else if (std::strcmp(argv[arg], "--3d27p-s1") == 0) run_3d27p_s1 = true;
        else if (std::strcmp(argv[arg], "--3d27p-s2") == 0) run_3d27p_s2 = true;
        else if (std::strcmp(argv[arg], "--self-test-only") == 0) self_test_only = true;
        else if (std::strcmp(argv[arg], "--help") == 0) {
            print_usage();
            return 0;
        } else {
            std::cerr << "Unknown option: " << argv[arg] << std::endl;
            print_usage();
            return 1;
        }
    }

    const bool operator_selected =
        run_1d3p_s1 || run_1d3p_s2 || run_2d5p_s1 || run_2d5p_s2 ||
        run_2d9p_s1 || run_2d9p_s2 || run_3d13p_s1 || run_3d13p_s2 ||
        run_3d25p_s1 || run_3d25p_s2 || run_3d27p_s1 || run_3d27p_s2;
    if (!operator_selected) {
        std::cerr << "No stencil operator selected." << std::endl;
        print_usage();
        return 1;
    }

    bool self_test_passed = true;
    if (run_1d3p_s1 || run_1d3p_s2)
        self_test_passed &= smestencil_paper_1d3p_self_test();
    if (run_2d5p_s1 || run_2d5p_s2)
        self_test_passed &= smestencil_paper_2d_self_test(false);
    if (run_2d9p_s1 || run_2d9p_s2)
        self_test_passed &= smestencil_paper_2d_self_test(true);
    if (run_3d13p_s1 || run_3d13p_s2)
        self_test_passed &= smestencil_paper_3d13_self_test();
    if (run_3d25p_s1 || run_3d25p_s2)
        self_test_passed &= smestencil_paper_3d_box_self_test(false);
    if (run_3d27p_s1 || run_3d27p_s2)
        self_test_passed &= smestencil_paper_3d_box_self_test(true);
    if (!self_test_passed)
        return 1;
    if (self_test_only)
        return 0;

    double total_time = 0.0;
    if (run_1d3p_s1 || run_1d3p_s2)
        total_time += test_stencil_1d_3point(run_1d3p_s1, run_1d3p_s2);
    if (run_2d5p_s1 || run_2d5p_s2)
        total_time += test_stencil_2d_5point(run_2d5p_s1, run_2d5p_s2);
    if (run_2d9p_s1 || run_2d9p_s2)
        total_time += test_stencil_2d_9point(run_2d9p_s1, run_2d9p_s2);
    if (run_3d13p_s1 || run_3d13p_s2)
        total_time += test_stencil_3d_13point(run_3d13p_s1, run_3d13p_s2);
    if (run_3d25p_s1 || run_3d25p_s2)
        total_time += test_stencil_3d_25point(run_3d25p_s1, run_3d25p_s2);
    if (run_3d27p_s1 || run_3d27p_s2)
        total_time += test_stencil_3d_27point(run_3d27p_s1, run_3d27p_s2);
    std::cout << "Total Time:" << total_time << std::endl;
    return 0;
}
#endif
