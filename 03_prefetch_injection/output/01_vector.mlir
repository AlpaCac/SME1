#map = affine_map<(d0)[s0] -> (-d0 + s0, 128)>
#map1 = affine_map<(d0, d1) -> (16, d0 - d1)>
#map2 = affine_map<(d0, d1) -> (d0 + d1)>
#map3 = affine_map<(d0)[s0, s1] -> (-d0 + s0, s1)>
module {
  func.func @gemm_fp32_linalg(%arg0: memref<?x?xf32>, %arg1: memref<?x?xf32>, %arg2: memref<?x?xf32>) attributes {c_kernel = "gemm_fp32", layout = "A row-major, B row-major, C row-major", lift_target = "linalg.matmul -> scf/affine -> vector -> arm_sme", mlir_level = "linalg+scf", semantic = "C = A * B"} {
    %0 = ub.poison : f32
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %cst = arith.constant 0.000000e+00 : f32
    %c128 = arith.constant 128 : index
    %c16 = arith.constant 16 : index
    %dim = memref.dim %arg0, %c0 : memref<?x?xf32>
    %dim_0 = memref.dim %arg0, %c1 : memref<?x?xf32>
    %dim_1 = memref.dim %arg1, %c1 : memref<?x?xf32>
    %vscale = vector.vscale
    %c16_vscale = arith.muli %vscale, %c16 : index
    %vscale_2 = vector.vscale
    %c16_vscale_3 = arith.muli %vscale_2, %c16 : index
    scf.for %arg3 = %c0 to %dim step %c128 {
      %1 = affine.min #map(%arg3)[%dim]
      scf.for %arg4 = %c0 to %dim_1 step %c128 {
        %2 = affine.min #map(%arg4)[%dim_1]
        %subview = memref.subview %arg2[%arg3, %arg4] [%1, %2] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
        scf.for %arg5 = %c0 to %1 step %c16 {
          %3 = affine.min #map1(%1, %arg5)
          %4 = affine.apply #map2(%arg3, %arg5)
          scf.for %arg6 = %c0 to %2 step %c16 {
            %5 = affine.min #map1(%2, %arg6)
            %6 = affine.apply #map2(%arg4, %arg6)
            %subview_4 = memref.subview %subview[%arg5, %arg6] [%3, %5] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<?x?xf32, strided<[?, 1], offset: ?>>
            linalg.fill ins(%cst : f32) outs(%subview_4 : memref<?x?xf32, strided<[?, 1], offset: ?>>)
            scf.for %arg7 = %c0 to %dim_0 step %c128 {
              %7 = affine.min #map(%arg7)[%dim_0]
              %subview_5 = memref.subview %arg0[%4, %arg7] [%3, %7] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
              %subview_6 = memref.subview %arg1[%arg7, %6] [%7, %5] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
              scf.for %arg8 = %c0 to %3 step %c16_vscale {
                %8 = affine.min #map3(%arg8)[%3, %c16_vscale]
                %9 = vector.create_mask %8 : vector<[16]xi1>
                scf.for %arg9 = %c0 to %5 step %c16_vscale_3 {
                  %10 = affine.min #map3(%arg9)[%5, %c16_vscale_3]
                  %subview_7 = memref.subview %subview_4[%arg8, %arg9] [%8, %10] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<?x?xf32, strided<[?, 1], offset: ?>>
                  %11 = vector.create_mask %10 : vector<[16]xi1>
                  %12 = vector.create_mask %8, %10 : vector<[16]x[16]xi1>
                  %13 = vector.create_mask %8, %10 : vector<[16]x[16]xi1>
                  scf.for %arg10 = %c0 to %7 step %c1 {
                    %subview_8 = memref.subview %subview_5[%arg8, %arg10] [%8, 1] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<?x1xf32, strided<[?, 1], offset: ?>>
                    %subview_9 = memref.subview %subview_6[%arg10, %arg9] [1, %10] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<1x?xf32, strided<[?, 1], offset: ?>>
                    %subview_10 = memref.subview %subview_8[0, 0] [%8, 1] [1, 1] : memref<?x1xf32, strided<[?, 1], offset: ?>> to memref<?xf32, strided<[?], offset: ?>>
                    %14 = vector.transfer_read %subview_10[%c0], %0, %9 {in_bounds = [true]} : memref<?xf32, strided<[?], offset: ?>>, vector<[16]xf32>
                    %subview_11 = memref.subview %subview_9[0, 0] [1, %10] [1, 1] : memref<1x?xf32, strided<[?, 1], offset: ?>> to memref<?xf32, strided<[1], offset: ?>>
                    %15 = vector.transfer_read %subview_11[%c0], %0, %11 {in_bounds = [true]} : memref<?xf32, strided<[1], offset: ?>>, vector<[16]xf32>
                    %16 = vector.transfer_read %subview_7[%c0, %c0], %0, %12 {in_bounds = [true, true]} : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[16]x[16]xf32>
                    %17 = vector.mask %13 { vector.outerproduct %14, %15, %16 {kind = #vector.kind<add>} : vector<[16]xf32>, vector<[16]xf32> } : vector<[16]x[16]xi1> -> vector<[16]x[16]xf32>
                    vector.transfer_write %17, %subview_7[%c0, %c0], %12 {in_bounds = [true, true]} : vector<[16]x[16]xf32>, memref<?x?xf32, strided<[?, 1], offset: ?>>
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

