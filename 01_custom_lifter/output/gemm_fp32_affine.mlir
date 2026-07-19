// ============================================================================ 
// 自动生成文件：gemm_fp32_affine.mlir
// 来源：gemm_mlir_kernel.c
// 目标：保留规则循环、索引关系和标量访存，作为后续 affine 分析与预取研究的输入
//
// 阅读建议：
// 1. 先看 affine.for，它们对应论文中的分块循环层次。
// 2. 再看 affine.load / affine.store，它们暴露了最直接的访存行为。
// 3. 这里故意不使用 linalg.matmul，而是保留标量归约结构，方便研究 reuse distance、
//    working set、stride 和预取距离。
// ============================================================================
#tile_outer = affine_map<(d0, d1) -> (128, d0 - d1)>
#row_index = affine_map<(d0, d1, d2) -> (d0 + d1 + d2)>
#col_index = affine_map<(d0, d1, d2) -> (d0 + d1 + d2)>

module {
  // 这个函数保留的是“规则循环 + 标量访存 + 标量归约”形式，适合做 affine 层分析。
  func.func @gemm_fp32_affine(%a: memref<?x?xf32>, %b: memref<?x?xf32>, %c: memref<?x?xf32>) attributes {
    c_kernel = "gemm_fp32",
    semantic = "C = A * B",
    layout = "A row-major, B row-major, C row-major",
    mlir_level = "affine"
  } {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c128 = arith.constant 128 : index
    %c128_n = arith.constant 128 : index
    %c128_k = arith.constant 128 : index
    %c16 = arith.constant 16 : index
    %c16_n = arith.constant 16 : index
    %f0 = arith.constant 0.0 : f32

    // 从输入矩阵中恢复问题规模。
    %m = memref.dim %a, %c0 : memref<?x?xf32>
    %k = memref.dim %a, %c1 : memref<?x?xf32>
    %n = memref.dim %b, %c1 : memref<?x?xf32>

    // 外层三层 affine.for 对应论文中的 mc / nc / kc。
    affine.for %i = 0 to %m step 128 {
      %mc = affine.min #tile_outer(%m, %i)

      affine.for %j = 0 to %n step 128 {
        %nc = affine.min #tile_outer(%n, %j)

        affine.for %ko = 0 to %k step 128 {
          %kc = affine.min #tile_outer(%k, %ko)

          // 这里把 ii / jj / kk 都固定在论文给定的块大小上，
          // 再用条件判断裁掉边界块。这样既保留 affine 结构，
          // 又避免动态上界在嵌套 affine.for 中触发符号约束。
          affine.for %ii = 0 to 128 step 16 {
            %ii_in_bound = arith.cmpi ult, %ii, %mc : index
            scf.if %ii_in_bound {
              affine.for %jj = 0 to 128 step 16 {
                %jj_in_bound = arith.cmpi ult, %jj, %nc : index
                scf.if %jj_in_bound {
                  // 第一步：对当前输出微块清零。
                  affine.for %i_inner = 0 to 16 {
                    %c_row_offset = affine.apply #row_index(%ii, %c0, %i_inner)
                    %row_valid = arith.cmpi ult, %c_row_offset, %mc : index
                    scf.if %row_valid {
                      %c_row = affine.apply #row_index(%i, %ii, %i_inner)

                      affine.for %j_inner = 0 to 16 {
                        %c_col_offset = affine.apply #col_index(%jj, %c0, %j_inner)
                        %col_valid = arith.cmpi ult, %c_col_offset, %nc : index
                        scf.if %col_valid {
                          %c_col = affine.apply #col_index(%j, %jj, %j_inner)
                          affine.store %f0, %c[%c_row, %c_col] : memref<?x?xf32>
                        }
                      }
                    }
                  }

                  // 第二步：显式保留 kk 归约循环和标量乘加模式。
                  affine.for %kk = 0 to 128 {
                    %in_k_bound = arith.cmpi ult, %kk, %kc : index
                    scf.if %in_k_bound {
                      affine.for %i_inner = 0 to 16 {
                        %a_row_offset = affine.apply #row_index(%ii, %c0, %i_inner)
                        %row_valid = arith.cmpi ult, %a_row_offset, %mc : index
                        scf.if %row_valid {
                          %a_row = affine.apply #row_index(%i, %ii, %i_inner)
                          %a_col = affine.apply #col_index(%ko, %c0, %kk)
                          %a_val = affine.load %a[%a_row, %a_col] : memref<?x?xf32>

                          affine.for %j_inner = 0 to 16 {
                            %b_col_offset = affine.apply #col_index(%jj, %c0, %j_inner)
                            %col_valid = arith.cmpi ult, %b_col_offset, %nc : index
                            scf.if %col_valid {
                              %b_row = affine.apply #row_index(%ko, %c0, %kk)
                              %b_col = affine.apply #col_index(%j, %jj, %j_inner)
                              %c_row = affine.apply #row_index(%i, %ii, %i_inner)
                              %c_col = affine.apply #col_index(%j, %jj, %j_inner)

                              %b_val = affine.load %b[%b_row, %b_col] : memref<?x?xf32>
                              %c_old = affine.load %c[%c_row, %c_col] : memref<?x?xf32>
                              %prod = arith.mulf %a_val, %b_val : f32
                              %sum = arith.addf %c_old, %prod : f32
                              affine.store %sum, %c[%c_row, %c_col] : memref<?x?xf32>
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    return
  }
}
