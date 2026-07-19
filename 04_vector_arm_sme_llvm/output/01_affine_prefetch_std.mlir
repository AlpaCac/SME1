#map = affine_map<(d0, d1) -> (128, d0 - d1)>
#map1 = affine_map<(d0, d1, d2) -> (d0 + d1 + d2)>
module {
  func.func @gemm_fp32_affine(%arg0: memref<?x?xf32>, %arg1: memref<?x?xf32>, %arg2: memref<?x?xf32>) attributes {c_kernel = "gemm_fp32", layout = "A row-major, B row-major, C row-major", mlir_level = "affine", prefetch_injected = "true", semantic = "C = A * B", step4_prefetch_bridge = "research_to_affine"} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c128 = arith.constant 128 : index
    %c128_0 = arith.constant 128 : index
    %c128_1 = arith.constant 128 : index
    %c16 = arith.constant 16 : index
    %c16_2 = arith.constant 16 : index
    %cst = arith.constant 0.000000e+00 : f32
    %dim = memref.dim %arg0, %c0 : memref<?x?xf32>
    %dim_3 = memref.dim %arg0, %c1 : memref<?x?xf32>
    %dim_4 = memref.dim %arg1, %c1 : memref<?x?xf32>
    affine.for %arg3 = 0 to %dim step 128 {
      %0 = affine.min #map(%dim, %arg3)
      affine.for %arg4 = 0 to %dim_4 step 128 {
        %1 = affine.min #map(%dim_4, %arg4)
        affine.for %arg5 = 0 to %dim_3 step 128 {
          %2 = affine.min #map(%dim_3, %arg5)
          affine.for %arg6 = 0 to 128 step 16 {
            %3 = arith.cmpi ult, %arg6, %0 : index
            scf.if %3 {
              affine.for %arg7 = 0 to 128 step 16 {
                %4 = arith.cmpi ult, %arg7, %1 : index
                scf.if %4 {
                  affine.for %arg8 = 0 to 16 {
                    %5 = affine.apply #map1(%arg6, %c0, %arg8)
                    %6 = arith.cmpi ult, %5, %0 : index
                    scf.if %6 {
                      %7 = affine.apply #map1(%arg3, %arg6, %arg8)
                      affine.for %arg9 = 0 to 16 {
                        %8 = affine.apply #map1(%arg7, %c0, %arg9)
                        %9 = arith.cmpi ult, %8, %1 : index
                        scf.if %9 {
                          %10 = affine.apply #map1(%arg4, %arg7, %arg9)
                          affine.store %cst, %arg2[%7, %10] : memref<?x?xf32>
                        }
                      }
                    }
                  }
                  affine.for %arg8 = 0 to 128 {
                    %5 = arith.cmpi ult, %arg8, %2 : index
                    scf.if %5 {
                      affine.prefetch %arg1[%arg5 + %arg8, %arg4 + %arg7], read, locality<3>, data : memref<?x?xf32>
                      affine.prefetch %arg0[%arg3 + %arg6, %arg5 + %arg8], read, locality<3>, data : memref<?x?xf32>
                      affine.for %arg9 = 0 to 16 {
                        %6 = affine.apply #map1(%arg6, %c0, %arg9)
                        %7 = arith.cmpi ult, %6, %0 : index
                        scf.if %7 {
                          %8 = affine.apply #map1(%arg3, %arg6, %arg9)
                          %9 = affine.apply #map1(%arg5, %c0, %arg8)
                          %10 = affine.load %arg0[%8, %9] : memref<?x?xf32>
                          affine.for %arg10 = 0 to 16 {
                            %11 = affine.apply #map1(%arg7, %c0, %arg10)
                            %12 = arith.cmpi ult, %11, %1 : index
                            scf.if %12 {
                              %13 = affine.apply #map1(%arg5, %c0, %arg8)
                              %14 = affine.apply #map1(%arg4, %arg7, %arg10)
                              %15 = affine.apply #map1(%arg3, %arg6, %arg9)
                              %16 = affine.apply #map1(%arg4, %arg7, %arg10)
                              %17 = affine.load %arg1[%13, %14] : memref<?x?xf32>
                              %18 = affine.load %arg2[%15, %16] : memref<?x?xf32>
                              %19 = arith.mulf %10, %17 : f32
                              %20 = arith.addf %18, %19 : f32
                              affine.store %20, %arg2[%15, %16] : memref<?x?xf32>
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
