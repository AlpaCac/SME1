#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

void gemm_fp32_affine(float *a_allocated,
                      float *a_aligned,
                      int64_t a_offset,
                      int64_t a_size0,
                      int64_t a_size1,
                      int64_t a_stride0,
                      int64_t a_stride1,
                      float *b_allocated,
                      float *b_aligned,
                      int64_t b_offset,
                      int64_t b_size0,
                      int64_t b_size1,
                      int64_t b_stride0,
                      int64_t b_stride1,
                      float *c_allocated,
                      float *c_aligned,
                      int64_t c_offset,
                      int64_t c_size0,
                      int64_t c_size1,
                      int64_t c_stride0,
                      int64_t c_stride1);

static void print_matrix(const char *name, const float *data, int64_t rows, int64_t cols) {
  int64_t i;
  int64_t j;
  printf("%s =\n", name);
  for (i = 0; i < rows; ++i) {
    for (j = 0; j < cols; ++j) {
      printf("%6.1f ", data[i * cols + j]);
    }
    printf("\n");
  }
}

static int check_result(const float *c, const float *expected, int64_t rows, int64_t cols) {
  int64_t i;
  for (i = 0; i < rows * cols; ++i) {
    if (fabsf(c[i] - expected[i]) > 1e-4f) {
      return 1;
    }
  }
  return 0;
}

int main(void) {
  const int64_t m = 4;
  const int64_t n = 4;
  const int64_t k = 4;

  float a[16] = {
      1, 2, 3, 4,
      5, 6, 7, 8,
      9, 10, 11, 12,
      13, 14, 15, 16,
  };
  float b[16] = {
      1, 0, 2, 0,
      0, 1, 0, 2,
      3, 0, 4, 0,
      0, 3, 0, 4,
  };
  float c[16] = {0};
  float expected[16] = {
      10, 14, 14, 20,
      26, 30, 38, 44,
      42, 46, 62, 68,
      58, 62, 86, 92,
  };

  gemm_fp32_affine(
      a, a, 0, m, k, k, 1,
      b, b, 0, k, n, n, 1,
      c, c, 0, m, n, n, 1);

  print_matrix("C", c, m, n);

  if (check_result(c, expected, m, n) != 0) {
    fprintf(stderr, "result check failed\n");
    return 1;
  }

  printf("result check passed\n");
  return 0;
}
