#include <stdint.h>
#include <stdio.h>

typedef struct {
  float *allocated;
  float *aligned;
  int64_t offset;
  int64_t sizes[2];
  int64_t strides[2];
} memref2d_f32;

// 这里调用稳定 wrapper，而不是直接承接原始 lowering 导出的返回 ABI。
extern memref2d_f32 gemm_step4_compute_stable(
    float *a_allocated, float *a_aligned, int64_t a_offset, int64_t a_size0,
    int64_t a_size1, int64_t a_stride0, int64_t a_stride1, float *b_allocated,
    float *b_aligned, int64_t b_offset, int64_t b_size0, int64_t b_size1,
    int64_t b_stride0, int64_t b_stride1, float *c_allocated, float *c_aligned,
    int64_t c_offset, int64_t c_size0, int64_t c_size1, int64_t c_stride0,
    int64_t c_stride1);

static void print_matrix(const char *name, const float *data, int64_t m,
                         int64_t n) {
  printf("%s =\n", name);
  for (int64_t i = 0; i < m; ++i) {
    for (int64_t j = 0; j < n; ++j)
      printf("%6.1f ", data[i * n + j]);
    printf("\n");
  }
}

int main(void) {
  enum { M = 4, K = 4, N = 4 };

  // 研究版最小输入：4x4 矩阵，便于快速确认统一主线是否真的执行。
  float A[M * K] = {
      1, 2, 3, 4,
      5, 6, 7, 8,
      9, 10, 11, 12,
      13, 14, 15, 16,
  };
  float B[K * N] = {
      1, 0, 1, 0,
      0, 1, 0, 1,
      1, 1, 1, 1,
      2, 2, 2, 2,
  };
  float C[M * N] = {0};

  // 通过稳定 wrapper 调用统一主线：
  // 原始函数负责执行，wrapper 负责把结果重新包装成稳定的 memref descriptor。
  memref2d_f32 result = gemm_step4_compute_stable(
      A, A, 0, M, K, K, 1,
      B, B, 0, K, N, N, 1,
      C, C, 0, M, N, N, 1);

  // 这里同时验证两件事：
  // 1. 原地写回的 C 是否正确
  // 2. 稳定 wrapper 返回的 descriptor 是否也能正确描述这个 C
  print_matrix("C", C, M, N);
  print_matrix("C_from_descriptor", result.aligned + result.offset, result.sizes[0],
               result.sizes[1]);
  return 0;
}
