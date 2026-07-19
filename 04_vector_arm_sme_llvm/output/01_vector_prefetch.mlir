#map = affine_map<(d0)[s0, s1] -> (-d0 + s0, s1)>
#map1 = affine_map<(d0)[s0, s1] -> (d0 * s1 + s0)>
module {
  func.func @gemm_step4_compute(%arg0: memref<?x?xf32, strided<[?, ?], offset: ?>>, %arg1: memref<?x?xf32, strided<[?, ?], offset: ?>>, %arg2: memref<?x?xf32, strided<[?, ?], offset: ?>>) -> memref<?x?xf32, strided<[?, ?], offset: ?>> attributes {step4_vector_prefetch = "memref_prefetch"} {
    %0 = ub.poison : f32
    %c16 = arith.constant 16 : index
    %c1 = arith.constant 1 : index
    %c0 = arith.constant 0 : index
    %dim = memref.dim %arg0, %c0 : memref<?x?xf32, strided<[?, ?], offset: ?>>
    %dim_0 = memref.dim %arg0, %c1 : memref<?x?xf32, strided<[?, ?], offset: ?>>
    %dim_1 = memref.dim %arg1, %c1 : memref<?x?xf32, strided<[?, ?], offset: ?>>
    %vscale = vector.vscale
    %c16_vscale = arith.muli %vscale, %c16 : index
    %vscale_2 = vector.vscale
    %c16_vscale_3 = arith.muli %vscale_2, %c16 : index
    scf.for %arg3 = %c0 to %dim step %c16_vscale {
      %1 = affine.min #map(%arg3)[%dim, %c16_vscale]
      %2 = vector.create_mask %1 : vector<[16]xi1>
      scf.for %arg4 = %c0 to %dim_1 step %c16_vscale_3 {
        %3 = affine.min #map(%arg4)[%dim_1, %c16_vscale_3]
        %subview = memref.subview %arg2[%arg3, %arg4] [%1, %3] [1, 1] : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>
        %4 = vector.create_mask %3 : vector<[16]xi1>
        %5 = vector.create_mask %1, %3 : vector<[16]x[16]xi1>
        %6 = vector.create_mask %1, %3 : vector<[16]x[16]xi1>
        %subview_4 = memref.subview %arg2[%arg3, %arg4] [%1, %3] [1, 1] : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>
        scf.for %arg5 = %c0 to %dim_0 step %c1 {
          %subview_5 = memref.subview %arg0[%arg3, %arg5] [%1, 1] [1, 1] : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x1xf32, strided<[?, ?], offset: ?>>
          %subview_6 = memref.subview %arg1[%arg5, %arg4] [1, %3] [1, 1] : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<1x?xf32, strided<[?, ?], offset: ?>>
          %subview_7 = memref.subview %subview_5[0, 0] [%1, 1] [1, 1] : memref<?x1xf32, strided<[?, ?], offset: ?>> to memref<?xf32, #map1>
          memref.prefetch %subview_7[%c0], read, locality<3>, data : memref<?xf32, #map1>
          %7 = vector.transfer_read %subview_7[%c0], %0, %2 {in_bounds = [true]} : memref<?xf32, #map1>, vector<[16]xf32>
          %subview_8 = memref.subview %subview_6[0, 0] [1, %3] [1, 1] : memref<1x?xf32, strided<[?, ?], offset: ?>> to memref<?xf32, #map1>
          memref.prefetch %subview_8[%c0], read, locality<3>, data : memref<?xf32, #map1>
          %8 = vector.transfer_read %subview_8[%c0], %0, %4 {in_bounds = [true]} : memref<?xf32, #map1>, vector<[16]xf32>
          %9 = vector.transfer_read %subview[%c0, %c0], %0, %5 {in_bounds = [true, true]} : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[16]x[16]xf32>
          %10 = vector.mask %6 { vector.outerproduct %7, %8, %9 {kind = #vector.kind<add>} : vector<[16]xf32>, vector<[16]xf32> } : vector<[16]x[16]xi1> -> vector<[16]x[16]xf32>
          vector.transfer_write %10, %subview[%c0, %c0], %5 {in_bounds = [true, true]} : vector<[16]x[16]xf32>, memref<?x?xf32, strided<[?, ?], offset: ?>>
          memref.copy %subview, %subview_4 : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>
        }
      }
    }
    return %arg2 : memref<?x?xf32, strided<[?, ?], offset: ?>>
  }
  module attributes {transform.with_named_sequence} {
  }
}

