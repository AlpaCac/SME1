#include <stdint.h>

typedef struct {
  float *allocated;
  float *aligned;
  int64_t offset;
  int64_t sizes[2];
  int64_t strides[2];
} memref2d_f32;

// 原始 lowering 结果对应的导出符号。
// 在 Darwin + 当前 llc 产物上，它的返回 ABI 不适合直接用普通 C struct 返回来承接，
// 但“原地写回 C 缓冲区”这一语义是稳定可用的。
extern void gemm_fp32_linalg(
    float *a_allocated, float *a_aligned, int64_t a_offset, int64_t a_size0,
    int64_t a_size1, int64_t a_stride0, int64_t a_stride1, float *b_allocated,
    float *b_aligned, int64_t b_offset, int64_t b_size0, int64_t b_size1,
    int64_t b_stride0, int64_t b_stride1, float *c_allocated, float *c_aligned,
    int64_t c_offset, int64_t c_size0, int64_t c_size1, int64_t c_stride0,
    int64_t c_stride1);

// 稳定研究接口：
// 1. 直接调用原始 SME lowering 函数完成计算
// 2. 明确按“结果就是输出缓冲区 C”来重建返回的 memref descriptor
memref2d_f32 gemm_step4_compute_stable(
    float *a_allocated, float *a_aligned, int64_t a_offset, int64_t a_size0,
    int64_t a_size1, int64_t a_stride0, int64_t a_stride1, float *b_allocated,
    float *b_aligned, int64_t b_offset, int64_t b_size0, int64_t b_size1,
    int64_t b_stride0, int64_t b_stride1, float *c_allocated, float *c_aligned,
    int64_t c_offset, int64_t c_size0, int64_t c_size1, int64_t c_stride0,
    int64_t c_stride1) {
  gemm_fp32_linalg(
      a_allocated, a_aligned, a_offset, a_size0, a_size1, a_stride0, a_stride1,
      b_allocated, b_aligned, b_offset, b_size0, b_size1, b_stride0, b_stride1,
      c_allocated, c_aligned, c_offset, c_size0, c_size1, c_stride0,
      c_stride1);

  memref2d_f32 result = {
      .allocated = c_allocated,
      .aligned = c_aligned,
      .offset = c_offset,
      .sizes = {c_size0, c_size1},
      .strides = {c_stride0, c_stride1},
  };
  return result;
}
