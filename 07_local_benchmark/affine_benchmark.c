#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

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

static double now_seconds(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static void init_matrix(float *ptr, int64_t rows, int64_t cols, int seed) {
  for (int64_t i = 0; i < rows; ++i) {
    for (int64_t j = 0; j < cols; ++j) {
      ptr[i * cols + j] = (float)(((i * 17 + j * 13 + seed) % 23) - 11) / 7.0f;
    }
  }
}

static double checksum_matrix(const float *ptr, int64_t rows, int64_t cols) {
  double sum = 0.0;
  for (int64_t i = 0; i < rows * cols; ++i)
    sum += ptr[i];
  return sum;
}

int main(int argc, char **argv) {
  const int64_t m = (argc > 1) ? atoll(argv[1]) : 128;
  const int64_t n = (argc > 2) ? atoll(argv[2]) : 128;
  const int64_t k = (argc > 3) ? atoll(argv[3]) : 128;
  const int iters = (argc > 4) ? atoi(argv[4]) : 10;

  float *a = NULL;
  float *b = NULL;
  float *c = NULL;
  if (posix_memalign((void **)&a, 64, (size_t)(m * k * sizeof(float))) != 0 ||
      posix_memalign((void **)&b, 64, (size_t)(k * n * sizeof(float))) != 0 ||
      posix_memalign((void **)&c, 64, (size_t)(m * n * sizeof(float))) != 0) {
    fprintf(stderr, "allocation failed\n");
    return 1;
  }

  init_matrix(a, m, k, 1);
  init_matrix(b, k, n, 2);

  for (int i = 0; i < 2; ++i) {
    memset(c, 0, (size_t)(m * n * sizeof(float)));
    gemm_fp32_affine(a, a, 0, m, k, k, 1,
                     b, b, 0, k, n, n, 1,
                     c, c, 0, m, n, n, 1);
  }

  double start = now_seconds();
  for (int i = 0; i < iters; ++i) {
    memset(c, 0, (size_t)(m * n * sizeof(float)));
    gemm_fp32_affine(a, a, 0, m, k, k, 1,
                     b, b, 0, k, n, n, 1,
                     c, c, 0, m, n, n, 1);
  }
  double elapsed = now_seconds() - start;
  double checksum = checksum_matrix(c, m, n);

  printf("elapsed_sec=%.9f\n", elapsed);
  printf("avg_ms=%.6f\n", elapsed * 1000.0 / (double)iters);
  printf("checksum=%.9f\n", checksum);

  free(a);
  free(b);
  free(c);
  return 0;
}
