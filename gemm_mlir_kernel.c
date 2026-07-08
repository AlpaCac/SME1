#include <stddef.h>

/*
 * @kernel gemm_fp32
 * @semantic C = A * B
 * @layout A row-major, B row-major, C row-major
 * @blocking mc=128 nc=128 kc=128 mr=16 nr=16
 * @lift-target linalg.matmul -> scf/affine -> vector -> arm_sme
 *
 * 这份 C 代码刻意限制在“规则循环 + 规则访存 + 显式分块”范围内，
 * 目标不是直接高性能执行，而是方便后续自定义前端把它提升成高层 MLIR。
 *
 * 对自定义提升器来说，可以直接识别出：
 * 1. 外层的 mc/nc/kc 分块结构；
 * 2. 内层的 mr/nr 微块结构；
 * 3. A(i,k) / B(k,j) / C(i,j) 的矩阵乘语义；
 * 4. 归约维是 k，空间维是 i 和 j。
 */
void gemm_fp32_mlir_kernel(int M,
                           int N,
                           int K,
                           const float *A,
                           int lda,
                           const float *B,
                           int ldb,
                           float *C,
                           int ldc) {
  const int mc0 = 128;
  const int nc0 = 128;
  const int kc0 = 128;
  const int mr0 = 16;
  const int nr0 = 16;

  int i;
  int j;
  int k;
  int ii;
  int jj;
  int kk;

  /*
   * L1/L2/L3:
   * 外层按论文中的 mc/nc/kc 做规则分块。
   * 这三层循环是最适合提升成高层 tile 结构的部分。
   */
  for (i = 0; i < M; i += mc0) {
    int mc = (M - i < mc0) ? (M - i) : mc0;

    for (j = 0; j < N; j += nc0) {
      int nc = (N - j < nc0) ? (N - j) : nc0;

      for (k = 0; k < K; k += kc0) {
        int kc = (K - k < kc0) ? (K - k) : kc0;

        /*
         * L4/L5:
         * 在当前大块内部继续切成 mr x nr 的小块。
         * 这里保留规则微块结构，但不显式引入底层向量类型，
         * 方便后续把它提升成 vector 或 ArmSME 前的中间表示。
         */
        for (ii = 0; ii < mc; ii += mr0) {
          int mr = (mc - ii < mr0) ? (mc - ii) : mr0;

          for (jj = 0; jj < nc; jj += nr0) {
            int nr = (nc - jj < nr0) ? (nc - jj) : nr0;
            float Cr[16][16];
            int i_inner;
            int j_inner;

            /*
             * 当前研究版只保留 C = A * B 语义。
             * 因此当前输出子块从 0 开始累加。
             */
            for (i_inner = 0; i_inner < mr; ++i_inner) {
              for (j_inner = 0; j_inner < nr; ++j_inner) {
                Cr[i_inner][j_inner] = 0.0f;
              }
            }

            /*
             * L6:
             * 沿归约维 kk 做矩阵乘累加。
             * 这里的核心语义是：
             *   Cr[i_inner][j_inner] += A(c_row, kk) * B(kk, c_col)
             *
             * 对自定义提升器来说，这一段最适合识别成：
             * - linalg.matmul 的局部块
             * - 或者 scf/affine 中的乘加归约模式
             */
            for (kk = 0; kk < kc; ++kk) {
              for (i_inner = 0; i_inner < mr; ++i_inner) {
                int a_row = i + ii + i_inner;
                int a_col = k + kk;
                float a_val = A[a_row * lda + a_col];

                for (j_inner = 0; j_inner < nr; ++j_inner) {
                  int b_row = k + kk;
                  int b_col = j + jj + j_inner;
                  Cr[i_inner][j_inner] += a_val * B[b_row * ldb + b_col];
                }
              }
            }

            /* 当前 mr x nr 输出子块累加完成后，写回到 C。 */
            for (i_inner = 0; i_inner < mr; ++i_inner) {
              for (j_inner = 0; j_inner < nr; ++j_inner) {
                int c_row = i + ii + i_inner;
                int c_col = j + jj + j_inner;
                C[c_row * ldc + c_col] = Cr[i_inner][j_inner];
              }
            }
          }
        }
      }
    }
  }
}
