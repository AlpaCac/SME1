#map = affine_map<(d0)[s0] -> (-d0 + s0, 128)>
#map1 = affine_map<(d0, d1) -> (16, d0 - d1)>
#map2 = affine_map<(d0, d1) -> (d0 + d1)>
module {
  func.func @gemm_fp32_linalg(%arg0: memref<?x?xf32>, %arg1: memref<?x?xf32>, %arg2: memref<?x?xf32>) attributes {c_kernel = "gemm_fp32", layout = "A row-major, B row-major, C row-major", lift_target = "linalg.matmul -> scf/affine -> vector -> arm_sme", mlir_level = "linalg+scf", semantic = "C = A * B", step2.analysis_layer = "affine-normalized", step2.analysis_note = "linalg mainline lowered to loops and conservatively normalized to affine form for prefetch analysis", step2.count.affine_for = 10 : i64, step2.count.affine_load = 3 : i64, step2.count.affine_store = 2 : i64, step2.count.memref_load = 0 : i64, step2.count.memref_store = 0 : i64, step2.count.scf_for = 0 : i64, step2.normalized_to_affine = "conservative", step2.prefetch.A = "enable=true,kind=read,priority=medium,cache=L1,locality=KEEP,distance=1-2 kk cache lines", step2.prefetch.B = "enable=true,kind=read,priority=high,cache=L1,locality=KEEP,distance=2 kk cache lines or next B micro-tile", step2.prefetch.C = "enable=false,reason=short-lived accumulation tile", step2.tile.kc = 128 : i64, step2.tile.mc = 128 : i64, step2.tile.mr = 16 : i64, step2.tile.nc = 128 : i64, step2.tile.nr = 16 : i64} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %cst = arith.constant 0.000000e+00 : f32
    %dim = memref.dim %arg0, %c0 : memref<?x?xf32>
    %dim_0 = memref.dim %arg0, %c1 : memref<?x?xf32>
    %dim_1 = memref.dim %arg1, %c1 : memref<?x?xf32>
    affine.for %arg3 = 0 to %dim step 128 {
      %0 = affine.min #map(%arg3)[%dim]
      affine.for %arg4 = 0 to %dim_1 step 128 {
        %1 = affine.min #map(%arg4)[%dim_1]
        %subview = memref.subview %arg2[%arg3, %arg4] [%0, %1] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
        affine.for %arg5 = 0 to 128 step 16 {
          %2 = arith.cmpi ult, %arg5, %0 : index
          scf.if %2 {
            %3 = affine.min #map1(%0, %arg5)
            affine.for %arg6 = 0 to 128 step 16 {
              %4 = arith.cmpi ult, %arg6, %1 : index
              scf.if %4 {
                %5 = affine.min #map1(%1, %arg6)
                %6 = affine.apply #map2(%arg3, %arg5)
                %7 = affine.apply #map2(%arg4, %arg6)
                %subview_2 = memref.subview %subview[%arg5, %arg6] [%3, %5] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<?x?xf32, strided<[?, 1], offset: ?>>
                affine.for %arg7 = 0 to 16 {
                  %8 = arith.cmpi ult, %arg7, %3 : index
                  scf.if %8 {
                    affine.for %arg8 = 0 to 16 {
                      %9 = arith.cmpi ult, %arg8, %5 : index
                      scf.if %9 {
                        affine.store %cst, %subview_2[%arg7, %arg8] : memref<?x?xf32, strided<[?, 1], offset: ?>>
                      }
                    }
                  }
                }
                affine.for %arg7 = 0 to %dim_0 step 128 {
                  %8 = affine.min #map(%arg7)[%dim_0]
                  %subview_3 = memref.subview %arg0[%6, %arg7] [%3, %8] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
                  %subview_4 = memref.subview %arg1[%arg7, %7] [%8, %5] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
                  affine.for %arg8 = 0 to 16 {
                    %9 = arith.cmpi ult, %arg8, %3 : index
                    scf.if %9 {
                      affine.for %arg9 = 0 to 16 {
                        %10 = arith.cmpi ult, %arg9, %5 : index
                        scf.if %10 {
                          affine.for %arg10 = 0 to 128 {
                            %11 = arith.cmpi ult, %arg10, %8 : index
                            scf.if %11 {
                              %12 = affine.load %subview_3[%arg8, %arg10] : memref<?x?xf32, strided<[?, 1], offset: ?>>
                              %13 = affine.load %subview_4[%arg10, %arg9] : memref<?x?xf32, strided<[?, 1], offset: ?>>
                              %14 = affine.load %subview_2[%arg8, %arg9] : memref<?x?xf32, strided<[?, 1], offset: ?>>
                              %15 = arith.mulf %12, %13 : f32
                              %16 = arith.addf %14, %15 : f32
                              affine.store %16, %subview_2[%arg8, %arg9] : memref<?x?xf32, strided<[?, 1], offset: ?>>
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

