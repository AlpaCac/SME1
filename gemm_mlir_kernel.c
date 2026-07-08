#include <stddef.h>

#define GEMM_MC 128
#define GEMM_NC 128
#define GEMM_KC 128
#define GEMM_MR 16
#define GEMM_NR 64

static int min_int(int a, int b) {
  return a < b ? a : b;
}

/*
 * Pack A into a K-major layout:
 *   packed_a[kk * m_block + ii] = A[ii, kk]
 *
 * This makes the inner computation look like a clean outer-product loop,
 * which is easier for MLIR to represent than target-specific intrinsics.
 */
static void pack_a_block_fp32(const float *restrict a,
                              float *restrict packed_a,
                              int lda,
                              int m_block,
                              int k_block) {
  int kk;
  int ii;

  for (kk = 0; kk < k_block; ++kk) {
    for (ii = 0; ii < m_block; ++ii) {
      packed_a[kk * m_block + ii] = a[ii * lda + kk];
    }
  }
}

/*
 * Pack B into a K-major layout:
 *   packed_b[kk * n_block + jj] = B[kk, jj]
 *
 * Both packed buffers then use the same kk-major traversal order.
 */
static void pack_b_block_fp32(const float *restrict b,
                              float *restrict packed_b,
                              int ldb,
                              int k_block,
                              int n_block) {
  int kk;
  int jj;

  for (kk = 0; kk < k_block; ++kk) {
    for (jj = 0; jj < n_block; ++jj) {
      packed_b[kk * n_block + jj] = b[kk * ldb + jj];
    }
  }
}

/*
 * Outer-product micro-kernel inspired by the paper's 16x64 shape, but written
 * in plain C so it is easy to lower into MLIR affine/scf/memref/vector forms.
 */
static void gemm_microkernel_outer_fp32(
    int m_block,
    int n_block,
    int k_block,
    float alpha,
    const float *restrict packed_a,
    const float *restrict packed_b,
    float beta,
    float *restrict c,
    int ldc) {
  int ii;
  int jj;
  int kk;

  for (ii = 0; ii < m_block; ii += GEMM_MR) {
    int mr = min_int(GEMM_MR, m_block - ii);

    for (jj = 0; jj < n_block; jj += GEMM_NR) {
      int nr = min_int(GEMM_NR, n_block - jj);
      float acc[GEMM_MR][GEMM_NR];
      int i;
      int j;

      for (i = 0; i < mr; ++i) {
        for (j = 0; j < nr; ++j) {
          acc[i][j] = 0.0f;
        }
      }

      for (kk = 0; kk < k_block; ++kk) {
        for (i = 0; i < mr; ++i) {
          float a_val = packed_a[kk * m_block + (ii + i)];

          for (j = 0; j < nr; ++j) {
            float b_val = packed_b[kk * n_block + (jj + j)];
            acc[i][j] += a_val * b_val;
          }
        }
      }

      for (i = 0; i < mr; ++i) {
        for (j = 0; j < nr; ++j) {
          float old_val = c[(ii + i) * ldc + (jj + j)];
          c[(ii + i) * ldc + (jj + j)] = alpha * acc[i][j] + beta * old_val;
        }
      }
    }
  }
}

/*
 * A blocked FP32 GEMM kernel derived from the paper's main ideas:
 * - cache-aware blocking
 * - packing both A and B
 * - outer-product style micro-kernel
 *
 * Expected storage:
 * - A: row-major [M, K]
 * - B: row-major [K, N]
 * - C: row-major [M, N]
 *
 * Scratch buffer requirements:
 * - packed_a: at least GEMM_MC * GEMM_KC floats
 * - packed_b: at least GEMM_KC * GEMM_NC floats
 */
void gemm_fp32_mlir_kernel(int m,
                           int n,
                           int k,
                           float alpha,
                           const float *restrict a,
                           int lda,
                           const float *restrict b,
                           int ldb,
                           float beta,
                           float *restrict c,
                           int ldc,
                           float *restrict packed_a,
                           float *restrict packed_b) {
  int i0;
  int k0;
  int j0;

  for (i0 = 0; i0 < m; i0 += GEMM_MC) {
    int mc = min_int(GEMM_MC, m - i0);

    for (k0 = 0; k0 < k; k0 += GEMM_KC) {
      int kc = min_int(GEMM_KC, k - k0);

      pack_a_block_fp32(a + i0 * lda + k0, packed_a, lda, mc, kc);

      for (j0 = 0; j0 < n; j0 += GEMM_NC) {
        int nc = min_int(GEMM_NC, n - j0);
        float block_beta = (k0 == 0) ? beta : 1.0f;

        pack_b_block_fp32(b + k0 * ldb + j0, packed_b, ldb, kc, nc);

        gemm_microkernel_outer_fp32(mc,
                                    nc,
                                    kc,
                                    alpha,
                                    packed_a,
                                    packed_b,
                                    block_beta,
                                    c + i0 * ldc + j0,
                                    ldc);
      }
    }
  }
}
