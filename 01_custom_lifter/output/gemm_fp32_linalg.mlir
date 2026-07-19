// ============================================================================ 
// 自动生成文件：gemm_fp32_linalg.mlir
// 来源：gemm_mlir_kernel.c
// 目标：保留 GEMM 的高层算子语义，作为后续 vector / arm_sme lowering 的输入
//
// 阅读建议：
// 1. 先看外层 scf.for，它们对应 C kernel 中的 mc / nc / kc 分块。
// 2. 再看内层 scf.for，它们对应 mr / nr 微块切分。
// 3. 最后看 linalg.matmul，它是从 C 中恢复出的核心矩阵乘语义。
// ============================================================================
#tile_outer = affine_map<(d0, d1) -> (128, d0 - d1)>
#tile_inner_m = affine_map<(d0, d1) -> (16, d0 - d1)>
#tile_inner_n = affine_map<(d0, d1) -> (16, d0 - d1)>

module {
  // 这个函数不是逐条模拟 C 语句，而是把 C kernel 提升为“块级 matmul 语义”。
  func.func @gemm_fp32_linalg(%a: memref<?x?xf32>, %b: memref<?x?xf32>, %c: memref<?x?xf32>) attributes {
    c_kernel = "gemm_fp32",
    semantic = "C = A * B",
    layout = "A row-major, B row-major, C row-major",
    lift_target = "linalg.matmul -> scf/affine -> vector -> arm_sme",
    mlir_level = "linalg+scf"
  } {
    // 动态维度来自输入 memref，本文件保留的是“高层结构”，不是固定形状特化版本。
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %cst_0 = arith.constant 0.0 : f32
    %mc0 = arith.constant 128 : index
    %nc0 = arith.constant 128 : index
    %kc0 = arith.constant 128 : index
    %mr0 = arith.constant 16 : index
    %nr0 = arith.constant 16 : index

    // 通过 memref.dim 恢复矩阵问题规模。
    %m = memref.dim %a, %c0 : memref<?x?xf32>
    %k = memref.dim %a, %c1 : memref<?x?xf32>
    %n = memref.dim %b, %c1 : memref<?x?xf32>

    // 外层三层循环保持论文中的 mc / nc / kc 分块结构。
    scf.for %i = %c0 to %m step %mc0 {
      %mc = affine.min #tile_outer(%m, %i)

      scf.for %j = %c0 to %n step %nc0 {
        %nc = affine.min #tile_outer(%n, %j)

        scf.for %ko = %c0 to %k step %kc0 {
          %kc = affine.min #tile_outer(%k, %ko)

          // subview 把整矩阵裁成当前 tile，便于后续继续做向量化和 ArmSME lowering。
          %a_tile = memref.subview %a[%i, %ko] [%mc, %kc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>
          %b_tile = memref.subview %b[%ko, %j] [%kc, %nc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>
          %c_tile = memref.subview %c[%i, %j] [%mc, %nc] [%c1, %c1]
            : memref<?x?xf32> to memref<?x?xf32, strided<[?, ?], offset: ?>>

          // 内层两层循环保留 mr / nr 微块信息。
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

              // 研究版语义只保留 C = A * B，所以每个输出微块先清零。
              linalg.fill ins(%cst_0 : f32)
                          outs(%c_block : memref<?x?xf32, strided<[?, ?], offset: ?>>)

              // 这里是最关键的提升结果：把标量乘加模式恢复成 linalg.matmul。
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
