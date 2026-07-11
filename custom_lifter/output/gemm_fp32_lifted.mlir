#tile_outer = affine_map<(d0, d1) -> (128, d0 - d1)>
#tile_inner_m = affine_map<(d0, d1) -> (16, d0 - d1)>
#tile_inner_n = affine_map<(d0, d1) -> (16, d0 - d1)>

module {
  func.func @gemm_fp32_lifted(%a: memref<?x?xf32>, %b: memref<?x?xf32>, %c: memref<?x?xf32>) attributes {
    c_kernel = "gemm_fp32",
    semantic = "C = A * B",
    layout = "A row-major, B row-major, C row-major",
    lift_target = "linalg.matmul -> scf/affine -> vector -> arm_sme"
  } {
    // 从输入 memref 中恢复矩阵维度，作为高层 MLIR 的动态边界。
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %cst_0 = arith.constant 0.0 : f32
    %mc0 = arith.constant 128 : index
    %nc0 = arith.constant 128 : index
    %kc0 = arith.constant 128 : index
    %mr0 = arith.constant 16 : index
    %nr0 = arith.constant 16 : index

    %m = memref.dim %a, %c0 : memref<?x?xf32>
    %k = memref.dim %a, %c1 : memref<?x?xf32>
    %n = memref.dim %b, %c1 : memref<?x?xf32>

    // 这组 affine.min 保留了 C kernel 中的 mc/nc/kc/mr/nr 分块语义。
    scf.for %i = %c0 to %m step %mc0 {
      %mc = affine.min #tile_outer(%m, %i)

      scf.for %j = %c0 to %n step %nc0 {
        %nc = affine.min #tile_outer(%n, %j)

        scf.for %ko = %c0 to %k step %kc0 {
          %kc = affine.min #tile_outer(%k, %ko)

          %a_tile = memref.subview %a[%i, %ko] [%mc, %kc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>
          %b_tile = memref.subview %b[%ko, %j] [%kc, %nc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>
          %c_tile = memref.subview %c[%i, %j] [%mc, %nc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>

          // 外层大块内部继续切分为 mr x nr 微块。
          scf.for %ii = %c0 to %mc step %mr0 {
            %mr = affine.min #tile_inner_m(%mc, %ii)

            scf.for %jj = %c0 to %nc step %nr0 {
              %nr = affine.min #tile_inner_n(%nc, %jj)

              %a_block = memref.subview %a_tile[%ii, %c0] [%mr, %kc] [%c1, %c1]
                : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>
              %b_block = memref.subview %b_tile[%c0, %jj] [%kc, %nr] [%c1, %c1]
                : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>
              %c_block = memref.subview %c_tile[%ii, %jj] [%mr, %nr] [%c1, %c1]
                : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>

              // 当前研究版只保留 C = A * B，因此每个输出块先清零再做 matmul。
              linalg.fill ins(%cst_0 : f32)
                          outs(%c_block : memref<?x?xf32, strided<[?, ?], offset: ?>>)

              // 这里显式恢复矩阵乘高层语义，后续可以继续进入 vector/arm_sme。
              linalg.matmul
                ins(%a_block, %b_block : memref<?x?xf32, strided<[?, ?], offset: ?>>,
                                         memref<?x?xf32, strided<[?, ?], offset: ?>>)
                outs(%c_block : memref<?x?xf32, strided<[?, ?], offset: ?>>)
            }
          }
        }
      }
    }

    return
  }
}
