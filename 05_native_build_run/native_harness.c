#include <stdint.h>
#include <stdio.h>

extern void gemm_fp32_linalg(
    float *a_allocated, float *a_aligned, int64_t a_offset, int64_t a_size0,
    int64_t a_size1, int64_t a_stride0, int64_t a_stride1,
    float *b_allocated, float *b_aligned, int64_t b_offset, int64_t b_size0,
    int64_t b_size1, int64_t b_stride0, int64_t b_stride1,
    float *c_allocated, float *c_aligned, int64_t c_offset, int64_t c_size0,
    int64_t c_size1, int64_t c_stride0, int64_t c_stride1);

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

  gemm_fp32_linalg(A, A, 0, M, K, K, 1,
                   B, B, 0, K, N, N, 1,
                   C, C, 0, M, N, N, 1);

  print_matrix("C", C, M, N);
  return 0;
}
