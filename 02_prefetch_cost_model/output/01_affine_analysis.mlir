#map = affine_map<(d0)[s0] -> (-d0 + s0, 128)>
#map1 = affine_map<(d0, d1) -> (16, d0 - d1)>
#map2 = affine_map<(d0, d1) -> (d0 + d1)>
module {
  func.func @gemm_fp32_linalg(%arg0: memref<?x?xf32>, %arg1: memref<?x?xf32>, %arg2: memref<?x?xf32>) attributes {c_kernel = "gemm_fp32", layout = "A row-major, B row-major, C row-major", lift_target = "linalg.matmul -> scf/affine -> vector -> arm_sme", mlir_level = "linalg+scf", semantic = "C = A * B", step2.analysis_layer = "scf+affine-indexing", step2.analysis_note = "linalg mainline lowered to loop form for affine/scf prefetch analysis", step2.count.memref_load = 3 : i64, step2.count.memref_store = 2 : i64, step2.count.scf_for = 10 : i64, step2.prefetch.A = "enable=true,kind=read,priority=medium,cache=L1,locality=KEEP,distance=1-2 kk cache lines", step2.prefetch.B = "enable=true,kind=read,priority=high,cache=L1,locality=KEEP,distance=2 kk cache lines or next B micro-tile", step2.prefetch.C = "enable=false,reason=short-lived accumulation tile", step2.tile.kc = 128 : i64, step2.tile.mc = 128 : i64, step2.tile.mr = 16 : i64, step2.tile.nc = 128 : i64, step2.tile.nr = 16 : i64} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %cst = arith.constant 0.000000e+00 : f32
    %c128 = arith.constant 128 : index
    %c16 = arith.constant 16 : index
    %dim = memref.dim %arg0, %c0 : memref<?x?xf32>
    %dim_0 = memref.dim %arg0, %c1 : memref<?x?xf32>
    %dim_1 = memref.dim %arg1, %c1 : memref<?x?xf32>
    scf.for %arg3 = %c0 to %dim step %c128 {
      %0 = affine.min #map(%arg3)[%dim]
      scf.for %arg4 = %c0 to %dim_1 step %c128 {
        %1 = affine.min #map(%arg4)[%dim_1]
        %subview = memref.subview %arg2[%arg3, %arg4] [%0, %1] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
        scf.for %arg5 = %c0 to %0 step %c16 {
          %2 = affine.min #map1(%0, %arg5)
          scf.for %arg6 = %c0 to %1 step %c16 {
            %3 = affine.min #map1(%1, %arg6)
            %4 = affine.apply #map2(%arg3, %arg5)
            %5 = affine.apply #map2(%arg4, %arg6)
            %subview_2 = memref.subview %subview[%arg5, %arg6] [%2, %3] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<?x?xf32, strided<[?, 1], offset: ?>>
            scf.for %arg7 = %c0 to %2 step %c1 {
              scf.for %arg8 = %c0 to %3 step %c1 {
                memref.store %cst, %subview_2[%arg7, %arg8] : memref<?x?xf32, strided<[?, 1], offset: ?>>
              }
            }
            scf.for %arg7 = %c0 to %dim_0 step %c128 {
              %6 = affine.min #map(%arg7)[%dim_0]
              %subview_3 = memref.subview %arg0[%4, %arg7] [%2, %6] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
              %subview_4 = memref.subview %arg1[%arg7, %5] [%6, %3] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
              scf.for %arg8 = %c0 to %2 step %c1 {
                scf.for %arg9 = %c0 to %3 step %c1 {
                  scf.for %arg10 = %c0 to %6 step %c1 {
                    %7 = memref.load %subview_3[%arg8, %arg10] : memref<?x?xf32, strided<[?, 1], offset: ?>>
                    %8 = memref.load %subview_4[%arg10, %arg9] : memref<?x?xf32, strided<[?, 1], offset: ?>>
                    %9 = memref.load %subview_2[%arg8, %arg9] : memref<?x?xf32, strided<[?, 1], offset: ?>>
                    %10 = arith.mulf %7, %8 : f32
                    %11 = arith.addf %9, %10 : f32
                    memref.store %11, %subview_2[%arg8, %arg9] : memref<?x?xf32, strided<[?, 1], offset: ?>>
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

