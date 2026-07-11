module {
  func.func @gemm_fp32_affine(%arg0: memref<?x?xf32>, %arg1: memref<?x?xf32>, %arg2: memref<?x?xf32>) attributes {c_kernel = "gemm_fp32", layout = "A row-major, B row-major, C row-major", mlir_level = "affine", prefetch_injected = "true", semantic = "C = A * B"} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c128 = arith.constant 128 : index
    %c16 = arith.constant 16 : index
    %cst = arith.constant 0.000000e+00 : f32
    %dim = memref.dim %arg0, %c0 : memref<?x?xf32>
    %dim_0 = memref.dim %arg0, %c1 : memref<?x?xf32>
    %dim_1 = memref.dim %arg1, %c1 : memref<?x?xf32>
    scf.for %arg3 = %c0 to %dim step %c128 {
      %0 = arith.subi %dim, %arg3 : index
      %1 = arith.minsi %0, %c128 : index
      scf.for %arg4 = %c0 to %dim_1 step %c128 {
        %2 = arith.subi %dim_1, %arg4 : index
        %3 = arith.minsi %2, %c128 : index
        scf.for %arg5 = %c0 to %dim_0 step %c128 {
          %4 = arith.subi %dim_0, %arg5 : index
          %5 = arith.minsi %4, %c128 : index
          scf.for %arg6 = %c0 to %c128 step %c16 {
            %6 = arith.cmpi ult, %arg6, %1 : index
            scf.if %6 {
              scf.for %arg7 = %c0 to %c128 step %c16 {
                %7 = arith.cmpi ult, %arg7, %3 : index
                scf.if %7 {
                  scf.for %arg8 = %c0 to %c16 step %c1 {
                    %8 = arith.addi %arg6, %arg8 : index
                    %9 = arith.cmpi ult, %8, %1 : index
                    scf.if %9 {
                      %10 = arith.addi %arg3, %arg6 : index
                      %11 = arith.addi %10, %arg8 : index
                      scf.for %arg9 = %c0 to %c16 step %c1 {
                        %12 = arith.addi %arg7, %arg9 : index
                        %13 = arith.cmpi ult, %12, %3 : index
                        scf.if %13 {
                          %14 = arith.addi %arg4, %arg7 : index
                          %15 = arith.addi %14, %arg9 : index
                          memref.store %cst, %arg2[%11, %15] : memref<?x?xf32>
                        }
                      }
                    }
                  }
                  scf.for %arg8 = %c0 to %c128 step %c1 {
                    %8 = arith.cmpi ult, %arg8, %5 : index
                    scf.if %8 {
                      %9 = arith.addi %arg5, %arg8 : index
                      %10 = arith.addi %arg4, %arg7 : index
                      memref.prefetch %arg1[%9, %10], read, locality<3>, data : memref<?x?xf32>
                      %11 = arith.addi %arg3, %arg6 : index
                      memref.prefetch %arg0[%11, %9], read, locality<3>, data : memref<?x?xf32>
                      scf.for %arg9 = %c0 to %c16 step %c1 {
                        %12 = arith.addi %arg6, %arg9 : index
                        %13 = arith.cmpi ult, %12, %1 : index
                        scf.if %13 {
                          %14 = arith.addi %11, %arg9 : index
                          %15 = memref.load %arg0[%14, %9] : memref<?x?xf32>
                          scf.for %arg10 = %c0 to %c16 step %c1 {
                            %16 = arith.addi %arg7, %arg10 : index
                            %17 = arith.cmpi ult, %16, %3 : index
                            scf.if %17 {
                              %18 = arith.addi %10, %arg10 : index
                              %19 = memref.load %arg1[%9, %18] : memref<?x?xf32>
                              %20 = memref.load %arg2[%14, %18] : memref<?x?xf32>
                              %21 = arith.mulf %15, %19 : f32
                              %22 = arith.addf %20, %21 : f32
                              memref.store %22, %arg2[%14, %18] : memref<?x?xf32>
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

