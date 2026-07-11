#map = affine_map<()[s0, s1, s2] -> (s1, s0 - s2)>
#map1 = affine_map<(d0)[s0, s1] -> (d0 * s1 + s0)>
module {
  func.func @gemm_step4_compute(%arg0: memref<?x?xf32, strided<[?, ?], offset: ?>>, %arg1: memref<?x?xf32, strided<[?, ?], offset: ?>>, %arg2: memref<?x?xf32, strided<[?, ?], offset: ?>>) -> memref<?x?xf32, strided<[?, ?], offset: ?>> attributes {llvm.arm_locally_streaming, llvm.arm_new_za} {
    %c0_i64 = arith.constant 0 : i64
    %0 = llvm.mlir.poison : vector<[4]xf32>
    %cst = arith.constant dense<true> : vector<[4]xi1>
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c16 = arith.constant 16 : index
    %c-4 = arith.constant -4 : index
    %c-8 = arith.constant -8 : index
    %c8 = arith.constant 8 : index
    %c-12 = arith.constant -12 : index
    %c12 = arith.constant 12 : index
    %1 = ub.poison : vector<[4]xf32>
    %2 = ub.poison : vector<[16]xf32>
    %c4 = arith.constant 4 : index
    %vscale = vector.vscale
    %c4_vscale = arith.muli %vscale, %c4 : index
    %alloca = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 27 : i32} : memref<?x?xf32>
    %alloca_0 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 26 : i32} : memref<?x?xf32>
    %alloca_1 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 25 : i32} : memref<?x?xf32>
    %alloca_2 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 24 : i32} : memref<?x?xf32>
    %alloca_3 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 23 : i32} : memref<?x?xf32>
    %alloca_4 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 22 : i32} : memref<?x?xf32>
    %alloca_5 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 21 : i32} : memref<?x?xf32>
    %alloca_6 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 20 : i32} : memref<?x?xf32>
    %alloca_7 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 19 : i32} : memref<?x?xf32>
    %alloca_8 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 18 : i32} : memref<?x?xf32>
    %alloca_9 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 17 : i32} : memref<?x?xf32>
    %alloca_10 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 16 : i32} : memref<?x?xf32>
    %3 = builtin.unrealized_conversion_cast %c0 : index to i64
    %dim = memref.dim %arg0, %c0 : memref<?x?xf32, strided<[?, ?], offset: ?>>
    %dim_11 = memref.dim %arg0, %c1 : memref<?x?xf32, strided<[?, ?], offset: ?>>
    %dim_12 = memref.dim %arg1, %c1 : memref<?x?xf32, strided<[?, ?], offset: ?>>
    %c16_vscale = arith.muli %vscale, %c16 : index
    cf.br ^bb1(%c0 : index)
  ^bb1(%4: index):  // 2 preds: ^bb0, ^bb69
    %5 = arith.cmpi slt, %4, %dim : index
    cf.cond_br %5, ^bb2, ^bb70
  ^bb2:  // pred: ^bb1
    %6 = affine.min #map()[%dim, %c16_vscale, %4]
    %7 = vector.create_mask %6 : vector<[16]xi1>
    cf.br ^bb3(%c0 : index)
  ^bb3(%8: index):  // 2 preds: ^bb2, ^bb68
    %9 = arith.cmpi slt, %8, %dim_12 : index
    cf.cond_br %9, ^bb4, ^bb69
  ^bb4:  // pred: ^bb3
    %10 = affine.min #map()[%dim_12, %c16_vscale, %8]
    %subview = memref.subview %arg2[%4, %8] [%6, %10] [1, 1] : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x?xf32, strided<[?, ?], offset: ?>>
    %11 = builtin.unrealized_conversion_cast %subview : memref<?x?xf32, strided<[?, ?], offset: ?>> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %12 = vector.create_mask %10 : vector<[16]xi1>
    cf.br ^bb5(%c0 : index)
  ^bb5(%13: index):  // 2 preds: ^bb4, ^bb67
    %14 = arith.cmpi slt, %13, %dim_11 : index
    cf.cond_br %14, ^bb6, ^bb68
  ^bb6:  // pred: ^bb5
    %subview_13 = memref.subview %arg0[%4, %13] [%6, 1] [1, 1] : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<?x1xf32, strided<[?, ?], offset: ?>>
    %subview_14 = memref.subview %arg1[%13, %8] [1, %10] [1, 1] : memref<?x?xf32, strided<[?, ?], offset: ?>> to memref<1x?xf32, strided<[?, ?], offset: ?>>
    %subview_15 = memref.subview %subview_13[0, 0] [%6, 1] [1, 1] : memref<?x1xf32, strided<[?, ?], offset: ?>> to memref<?xf32, #map1>
    cf.br ^bb7(%c0, %2 : index, vector<[16]xf32>)
  ^bb7(%15: index, %16: vector<[16]xf32>):  // 2 preds: ^bb6, ^bb10
    %17 = arith.cmpi slt, %15, %c16_vscale : index
    cf.cond_br %17, ^bb8, ^bb11
  ^bb8:  // pred: ^bb7
    %18 = vector.extract %7[%15] : i1 from vector<[16]xi1>
    cf.cond_br %18, ^bb9, ^bb10(%16 : vector<[16]xf32>)
  ^bb9:  // pred: ^bb8
    %19 = memref.load %subview_15[%15] : memref<?xf32, #map1>
    %20 = vector.insert %19, %16 [%15] : f32 into vector<[16]xf32>
    cf.br ^bb10(%20 : vector<[16]xf32>)
  ^bb10(%21: vector<[16]xf32>):  // 2 preds: ^bb8, ^bb9
    %22 = arith.addi %15, %c1 : index
    cf.br ^bb7(%22, %21 : index, vector<[16]xf32>)
  ^bb11:  // pred: ^bb7
    %subview_16 = memref.subview %subview_14[0, 0] [1, %10] [1, 1] : memref<1x?xf32, strided<[?, ?], offset: ?>> to memref<?xf32, #map1>
    cf.br ^bb12(%c0, %2 : index, vector<[16]xf32>)
  ^bb12(%23: index, %24: vector<[16]xf32>):  // 2 preds: ^bb11, ^bb15
    %25 = arith.cmpi slt, %23, %c16_vscale : index
    cf.cond_br %25, ^bb13, ^bb16
  ^bb13:  // pred: ^bb12
    %26 = vector.extract %12[%23] : i1 from vector<[16]xi1>
    cf.cond_br %26, ^bb14, ^bb15(%24 : vector<[16]xf32>)
  ^bb14:  // pred: ^bb13
    %27 = memref.load %subview_16[%23] : memref<?xf32, #map1>
    %28 = vector.insert %27, %24 [%23] : f32 into vector<[16]xf32>
    cf.br ^bb15(%28 : vector<[16]xf32>)
  ^bb15(%29: vector<[16]xf32>):  // 2 preds: ^bb13, ^bb14
    %30 = arith.addi %23, %c1 : index
    cf.br ^bb12(%30, %29 : index, vector<[16]xf32>)
  ^bb16:  // pred: ^bb12
    %31 = arith.index_castui %10 : index to i32
    cf.br ^bb17(%c0 : index)
  ^bb17(%32: index):  // 2 preds: ^bb16, ^bb18
    %33 = arith.cmpi slt, %32, %c4_vscale : index
    cf.cond_br %33, ^bb18, ^bb19
  ^bb18:  // pred: ^bb17
    %34 = arith.cmpi slt, %32, %6 : index
    %35 = arith.extsi %34 : i1 to i32
    %36 = arith.andi %35, %31 : i32
    %37 = arith.index_cast %36 : i32 to index
    %38 = vector.create_mask %37 : vector<[4]xi1>
    %39 = vector.maskedload %subview[%32, %c0], %38, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %40 = arith.index_castui %32 : index to i32
    "arm_sme.intr.write.horiz"(%40, %cst, %39) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %41 = arith.addi %32, %c1 : index
    cf.br ^bb17(%41 : index)
  ^bb19:  // pred: ^bb17
    %c-4_vscale = arith.muli %vscale, %c-4 : index
    %42 = arith.addi %10, %c-4_vscale : index
    %43 = builtin.unrealized_conversion_cast %c4_vscale : index to i64
    %44 = arith.index_castui %42 : index to i32
    cf.br ^bb20(%c0 : index)
  ^bb20(%45: index):  // 2 preds: ^bb19, ^bb21
    %46 = arith.cmpi slt, %45, %c4_vscale : index
    cf.cond_br %46, ^bb21, ^bb22
  ^bb21:  // pred: ^bb20
    %47 = arith.cmpi slt, %45, %6 : index
    %48 = arith.extsi %47 : i1 to i32
    %49 = arith.andi %48, %44 : i32
    %50 = arith.index_cast %49 : i32 to index
    %51 = vector.create_mask %50 : vector<[4]xi1>
    %52 = vector.maskedload %subview[%45, %c4_vscale], %51, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %53 = arith.index_castui %45 : index to i32
    "arm_sme.intr.write.horiz"(%53, %cst, %52) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %54 = arith.addi %45, %c1 : index
    cf.br ^bb20(%54 : index)
  ^bb22:  // pred: ^bb20
    %c-8_vscale = arith.muli %vscale, %c-8 : index
    %55 = arith.addi %10, %c-8_vscale : index
    %c8_vscale = arith.muli %vscale, %c8 : index
    %56 = builtin.unrealized_conversion_cast %c8_vscale : index to i64
    %57 = arith.index_castui %55 : index to i32
    cf.br ^bb23(%c0 : index)
  ^bb23(%58: index):  // 2 preds: ^bb22, ^bb24
    %59 = arith.cmpi slt, %58, %c4_vscale : index
    cf.cond_br %59, ^bb24, ^bb25
  ^bb24:  // pred: ^bb23
    %60 = arith.cmpi slt, %58, %6 : index
    %61 = arith.extsi %60 : i1 to i32
    %62 = arith.andi %61, %57 : i32
    %63 = arith.index_cast %62 : i32 to index
    %64 = vector.create_mask %63 : vector<[4]xi1>
    %65 = vector.maskedload %subview[%58, %c8_vscale], %64, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %66 = arith.index_castui %58 : index to i32
    "arm_sme.intr.write.horiz"(%66, %cst, %65) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %67 = arith.addi %58, %c1 : index
    cf.br ^bb23(%67 : index)
  ^bb25:  // pred: ^bb23
    %c-12_vscale = arith.muli %vscale, %c-12 : index
    %68 = arith.addi %10, %c-12_vscale : index
    %c12_vscale = arith.muli %vscale, %c12 : index
    %69 = builtin.unrealized_conversion_cast %c12_vscale : index to i64
    %70 = arith.index_castui %68 : index to i32
    cf.br ^bb26(%c0 : index)
  ^bb26(%71: index):  // 2 preds: ^bb25, ^bb27
    %72 = arith.cmpi slt, %71, %c4_vscale : index
    cf.cond_br %72, ^bb27, ^bb28
  ^bb27:  // pred: ^bb26
    %73 = arith.cmpi slt, %71, %6 : index
    %74 = arith.extsi %73 : i1 to i32
    %75 = arith.andi %74, %70 : i32
    %76 = arith.index_cast %75 : i32 to index
    %77 = vector.create_mask %76 : vector<[4]xi1>
    %78 = vector.maskedload %subview[%71, %c12_vscale], %77, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %79 = arith.index_castui %71 : index to i32
    "arm_sme.intr.write.horiz"(%79, %cst, %78) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %80 = arith.addi %71, %c1 : index
    cf.br ^bb26(%80 : index)
  ^bb28:  // pred: ^bb26
    %81 = arith.addi %6, %c-4_vscale : index
    cf.br ^bb29(%c0 : index)
  ^bb29(%82: index):  // 2 preds: ^bb28, ^bb30
    %83 = arith.cmpi slt, %82, %c4_vscale : index
    cf.cond_br %83, ^bb30, ^bb31
  ^bb30:  // pred: ^bb29
    %84 = arith.cmpi slt, %82, %81 : index
    %85 = arith.extsi %84 : i1 to i32
    %86 = arith.andi %85, %31 : i32
    %87 = arith.index_cast %86 : i32 to index
    %88 = vector.create_mask %87 : vector<[4]xi1>
    %89 = arith.addi %c4_vscale, %82 : index
    %90 = vector.maskedload %subview[%89, %c0], %88, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %91 = arith.index_castui %82 : index to i32
    "arm_sme.intr.write.horiz"(%91, %cst, %90) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %92 = arith.addi %82, %c1 : index
    cf.br ^bb29(%92 : index)
  ^bb31:  // pred: ^bb29
    cf.br ^bb32(%c0 : index)
  ^bb32(%93: index):  // 2 preds: ^bb31, ^bb33
    %94 = arith.cmpi slt, %93, %c4_vscale : index
    cf.cond_br %94, ^bb33, ^bb34
  ^bb33:  // pred: ^bb32
    %95 = arith.cmpi slt, %93, %81 : index
    %96 = arith.extsi %95 : i1 to i32
    %97 = arith.andi %96, %44 : i32
    %98 = arith.index_cast %97 : i32 to index
    %99 = vector.create_mask %98 : vector<[4]xi1>
    %100 = arith.addi %c4_vscale, %93 : index
    %101 = vector.maskedload %subview[%100, %c4_vscale], %99, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %102 = arith.index_castui %93 : index to i32
    "arm_sme.intr.write.horiz"(%102, %cst, %101) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %103 = arith.addi %93, %c1 : index
    cf.br ^bb32(%103 : index)
  ^bb34:  // pred: ^bb32
    cf.br ^bb35(%c0 : index)
  ^bb35(%104: index):  // 2 preds: ^bb34, ^bb36
    %105 = arith.cmpi slt, %104, %c4_vscale : index
    cf.cond_br %105, ^bb36, ^bb37
  ^bb36:  // pred: ^bb35
    %106 = arith.cmpi slt, %104, %81 : index
    %107 = arith.extsi %106 : i1 to i32
    %108 = arith.andi %107, %57 : i32
    %109 = arith.index_cast %108 : i32 to index
    %110 = vector.create_mask %109 : vector<[4]xi1>
    %111 = arith.addi %c4_vscale, %104 : index
    %112 = vector.maskedload %subview[%111, %c8_vscale], %110, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %113 = arith.index_castui %104 : index to i32
    "arm_sme.intr.write.horiz"(%113, %cst, %112) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %114 = arith.addi %104, %c1 : index
    cf.br ^bb35(%114 : index)
  ^bb37:  // pred: ^bb35
    cf.br ^bb38(%c0 : index)
  ^bb38(%115: index):  // 2 preds: ^bb37, ^bb39
    %116 = arith.cmpi slt, %115, %c4_vscale : index
    cf.cond_br %116, ^bb39, ^bb40
  ^bb39:  // pred: ^bb38
    %117 = arith.cmpi slt, %115, %81 : index
    %118 = arith.extsi %117 : i1 to i32
    %119 = arith.andi %118, %70 : i32
    %120 = arith.index_cast %119 : i32 to index
    %121 = vector.create_mask %120 : vector<[4]xi1>
    %122 = arith.addi %c4_vscale, %115 : index
    %123 = vector.maskedload %subview[%122, %c12_vscale], %121, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %124 = arith.index_castui %115 : index to i32
    "arm_sme.intr.write.horiz"(%124, %cst, %123) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %125 = arith.addi %115, %c1 : index
    cf.br ^bb38(%125 : index)
  ^bb40:  // pred: ^bb38
    %126 = arith.addi %6, %c-8_vscale : index
    cf.br ^bb41(%c0 : index)
  ^bb41(%127: index):  // 2 preds: ^bb40, ^bb42
    %128 = arith.cmpi slt, %127, %c4_vscale : index
    cf.cond_br %128, ^bb42, ^bb43
  ^bb42:  // pred: ^bb41
    %129 = arith.cmpi slt, %127, %126 : index
    %130 = arith.extsi %129 : i1 to i32
    %131 = arith.andi %130, %31 : i32
    %132 = arith.index_cast %131 : i32 to index
    %133 = vector.create_mask %132 : vector<[4]xi1>
    %134 = arith.addi %c8_vscale, %127 : index
    %135 = vector.maskedload %subview[%134, %c0], %133, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %136 = arith.index_castui %127 : index to i32
    "arm_sme.intr.write.horiz"(%136, %cst, %135) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %137 = arith.addi %127, %c1 : index
    cf.br ^bb41(%137 : index)
  ^bb43:  // pred: ^bb41
    cf.br ^bb44(%c0 : index)
  ^bb44(%138: index):  // 2 preds: ^bb43, ^bb45
    %139 = arith.cmpi slt, %138, %c4_vscale : index
    cf.cond_br %139, ^bb45, ^bb46
  ^bb45:  // pred: ^bb44
    %140 = arith.cmpi slt, %138, %126 : index
    %141 = arith.extsi %140 : i1 to i32
    %142 = arith.andi %141, %44 : i32
    %143 = arith.index_cast %142 : i32 to index
    %144 = vector.create_mask %143 : vector<[4]xi1>
    %145 = arith.addi %c8_vscale, %138 : index
    %146 = vector.maskedload %subview[%145, %c4_vscale], %144, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %147 = arith.index_castui %138 : index to i32
    "arm_sme.intr.write.horiz"(%147, %cst, %146) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %148 = arith.addi %138, %c1 : index
    cf.br ^bb44(%148 : index)
  ^bb46:  // pred: ^bb44
    cf.br ^bb47(%c0 : index)
  ^bb47(%149: index):  // 2 preds: ^bb46, ^bb48
    %150 = arith.cmpi slt, %149, %c4_vscale : index
    cf.cond_br %150, ^bb48, ^bb49
  ^bb48:  // pred: ^bb47
    %151 = arith.cmpi slt, %149, %126 : index
    %152 = arith.extsi %151 : i1 to i32
    %153 = arith.andi %152, %57 : i32
    %154 = arith.index_cast %153 : i32 to index
    %155 = vector.create_mask %154 : vector<[4]xi1>
    %156 = arith.addi %c8_vscale, %149 : index
    %157 = vector.maskedload %subview[%156, %c8_vscale], %155, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_0 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_0[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %158 = arith.index_castui %149 : index to i32
    "arm_sme.intr.write.horiz"(%158, %cst, %157) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_0 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_0[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %159 = arith.addi %149, %c1 : index
    cf.br ^bb47(%159 : index)
  ^bb49:  // pred: ^bb47
    cf.br ^bb50(%c0 : index)
  ^bb50(%160: index):  // 2 preds: ^bb49, ^bb51
    %161 = arith.cmpi slt, %160, %c4_vscale : index
    cf.cond_br %161, ^bb51, ^bb52
  ^bb51:  // pred: ^bb50
    %162 = arith.cmpi slt, %160, %126 : index
    %163 = arith.extsi %162 : i1 to i32
    %164 = arith.andi %163, %70 : i32
    %165 = arith.index_cast %164 : i32 to index
    %166 = vector.create_mask %165 : vector<[4]xi1>
    %167 = arith.addi %c8_vscale, %160 : index
    %168 = vector.maskedload %subview[%167, %c12_vscale], %166, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %169 = arith.index_castui %160 : index to i32
    "arm_sme.intr.write.horiz"(%169, %cst, %168) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %170 = arith.addi %160, %c1 : index
    cf.br ^bb50(%170 : index)
  ^bb52:  // pred: ^bb50
    %171 = arith.addi %6, %c-12_vscale : index
    cf.br ^bb53(%c0 : index)
  ^bb53(%172: index):  // 2 preds: ^bb52, ^bb54
    %173 = arith.cmpi slt, %172, %c4_vscale : index
    cf.cond_br %173, ^bb54, ^bb55
  ^bb54:  // pred: ^bb53
    %174 = arith.cmpi slt, %172, %171 : index
    %175 = arith.extsi %174 : i1 to i32
    %176 = arith.andi %175, %31 : i32
    %177 = arith.index_cast %176 : i32 to index
    %178 = vector.create_mask %177 : vector<[4]xi1>
    %179 = arith.addi %c12_vscale, %172 : index
    %180 = vector.maskedload %subview[%179, %c0], %178, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    %181 = arith.index_castui %172 : index to i32
    "arm_sme.intr.write.horiz"(%181, %cst, %180) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %182 = arith.addi %172, %c1 : index
    cf.br ^bb53(%182 : index)
  ^bb55:  // pred: ^bb53
    cf.br ^bb56(%c0 : index)
  ^bb56(%183: index):  // 2 preds: ^bb55, ^bb57
    %184 = arith.cmpi slt, %183, %c4_vscale : index
    cf.cond_br %184, ^bb57, ^bb58
  ^bb57:  // pred: ^bb56
    %185 = arith.cmpi slt, %183, %171 : index
    %186 = arith.extsi %185 : i1 to i32
    %187 = arith.andi %186, %44 : i32
    %188 = arith.index_cast %187 : i32 to index
    %189 = vector.create_mask %188 : vector<[4]xi1>
    %190 = arith.addi %c12_vscale, %183 : index
    %191 = vector.maskedload %subview[%190, %c4_vscale], %189, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    %192 = arith.index_castui %183 : index to i32
    "arm_sme.intr.write.horiz"(%192, %cst, %191) <{tile_id = 1 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %193 = arith.addi %183, %c1 : index
    cf.br ^bb56(%193 : index)
  ^bb58:  // pred: ^bb56
    cf.br ^bb59(%c0 : index)
  ^bb59(%194: index):  // 2 preds: ^bb58, ^bb60
    %195 = arith.cmpi slt, %194, %c4_vscale : index
    cf.cond_br %195, ^bb60, ^bb61
  ^bb60:  // pred: ^bb59
    %196 = arith.cmpi slt, %194, %171 : index
    %197 = arith.extsi %196 : i1 to i32
    %198 = arith.andi %197, %57 : i32
    %199 = arith.index_cast %198 : i32 to index
    %200 = vector.create_mask %199 : vector<[4]xi1>
    %201 = arith.addi %c12_vscale, %194 : index
    %202 = vector.maskedload %subview[%201, %c8_vscale], %200, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    %203 = arith.index_castui %194 : index to i32
    "arm_sme.intr.write.horiz"(%203, %cst, %202) <{tile_id = 2 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %204 = arith.addi %194, %c1 : index
    cf.br ^bb59(%204 : index)
  ^bb61:  // pred: ^bb59
    cf.br ^bb62(%c0 : index)
  ^bb62(%205: index):  // 2 preds: ^bb61, ^bb63
    %206 = arith.cmpi slt, %205, %c4_vscale : index
    cf.cond_br %206, ^bb63, ^bb64
  ^bb63:  // pred: ^bb62
    %207 = arith.cmpi slt, %205, %171 : index
    %208 = arith.extsi %207 : i1 to i32
    %209 = arith.andi %208, %70 : i32
    %210 = arith.index_cast %209 : i32 to index
    %211 = vector.create_mask %210 : vector<[4]xi1>
    %212 = arith.addi %c12_vscale, %205 : index
    %213 = vector.maskedload %subview[%212, %c12_vscale], %211, %1 : memref<?x?xf32, strided<[?, ?], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    %214 = arith.index_castui %205 : index to i32
    "arm_sme.intr.write.horiz"(%214, %cst, %213) <{tile_id = 3 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %215 = arith.addi %205, %c1 : index
    cf.br ^bb62(%215 : index)
  ^bb64:  // pred: ^bb62
    %216 = vector.scalable.extract %16[0] : vector<[4]xf32> from vector<[16]xf32>
    %217 = vector.scalable.extract %24[0] : vector<[4]xf32> from vector<[16]xf32>
    %218 = vector.create_mask %6 : vector<[4]xi1>
    %219 = vector.create_mask %10 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%218, %219, %216, %217) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %220 = vector.scalable.extract %24[4] : vector<[4]xf32> from vector<[16]xf32>
    %221 = vector.create_mask %42 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%218, %221, %216, %220) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %222 = vector.scalable.extract %24[8] : vector<[4]xf32> from vector<[16]xf32>
    %223 = vector.create_mask %55 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%218, %223, %216, %222) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %224 = vector.scalable.extract %24[12] : vector<[4]xf32> from vector<[16]xf32>
    %225 = vector.create_mask %68 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%218, %225, %216, %224) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %226 = vector.scalable.extract %16[4] : vector<[4]xf32> from vector<[16]xf32>
    %227 = vector.create_mask %81 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%227, %219, %226, %217) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%227, %221, %226, %220) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%227, %223, %226, %222) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%227, %225, %226, %224) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %228 = vector.scalable.extract %16[8] : vector<[4]xf32> from vector<[16]xf32>
    %229 = vector.create_mask %126 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%229, %219, %228, %217) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%229, %221, %228, %220) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_0 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_0[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%229, %223, %228, %222) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_0 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_0[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%229, %225, %228, %224) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %230 = vector.scalable.extract %16[12] : vector<[4]xf32> from vector<[16]xf32>
    %231 = vector.create_mask %171 : vector<[4]xi1>
    "arm_sme.intr.mopa"(%231, %219, %230, %217) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    "arm_sme.intr.mopa"(%231, %221, %230, %220) <{tile_id = 1 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    "arm_sme.intr.mopa"(%231, %223, %230, %222) <{tile_id = 2 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    "arm_sme.intr.mopa"(%231, %225, %230, %224) <{tile_id = 3 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    cf.br ^bb65(%c0 : index)
  ^bb65(%232: index):  // 2 preds: ^bb64, ^bb66
    %233 = builtin.unrealized_conversion_cast %232 : index to i64
    %234 = arith.cmpi slt, %232, %c4_vscale : index
    cf.cond_br %234, ^bb66, ^bb67
  ^bb66:  // pred: ^bb65
    %235 = arm_sve.psel %12, %7[%232] : vector<[16]xi1>, vector<[16]xi1>
    %236 = vector.scalable.extract %235[0] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %237 = llvm.extractvalue %11[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %238 = llvm.extractvalue %11[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %239 = llvm.getelementptr %237[%238] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %240 = llvm.extractvalue %11[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %241 = llvm.mul %233, %240 : i64
    %242 = llvm.extractvalue %11[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %243 = llvm.mul %3, %242 : i64
    %244 = llvm.add %241, %243 : i64
    %245 = llvm.getelementptr %239[%244] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %246 = arith.index_castui %232 : index to i32
    "arm_sme.intr.st1w.horiz"(%236, %245, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %247 = vector.scalable.extract %235[4] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %248 = llvm.mul %43, %242 : i64
    %249 = llvm.add %241, %248 : i64
    %250 = llvm.getelementptr %239[%249] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%247, %250, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %251 = vector.scalable.extract %235[8] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %252 = llvm.mul %56, %242 : i64
    %253 = llvm.add %241, %252 : i64
    %254 = llvm.getelementptr %239[%253] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%251, %254, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %255 = vector.scalable.extract %235[12] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %256 = llvm.mul %69, %242 : i64
    %257 = llvm.add %241, %256 : i64
    %258 = llvm.getelementptr %239[%257] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%255, %258, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %259 = arith.addi %c4_vscale, %232 : index
    %260 = builtin.unrealized_conversion_cast %259 : index to i64
    %261 = arm_sve.psel %12, %7[%259] : vector<[16]xi1>, vector<[16]xi1>
    %262 = vector.scalable.extract %261[0] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %263 = llvm.mul %260, %240 : i64
    %264 = llvm.add %263, %243 : i64
    %265 = llvm.getelementptr %239[%264] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%262, %265, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %266 = vector.scalable.extract %261[4] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %267 = llvm.add %263, %248 : i64
    %268 = llvm.getelementptr %239[%267] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%266, %268, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %269 = vector.scalable.extract %261[8] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %270 = llvm.add %263, %252 : i64
    %271 = llvm.getelementptr %239[%270] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%269, %271, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %272 = vector.scalable.extract %261[12] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %273 = llvm.add %263, %256 : i64
    %274 = llvm.getelementptr %239[%273] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%272, %274, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %275 = arith.addi %c8_vscale, %232 : index
    %276 = builtin.unrealized_conversion_cast %275 : index to i64
    %277 = arm_sve.psel %12, %7[%275] : vector<[16]xi1>, vector<[16]xi1>
    %278 = vector.scalable.extract %277[0] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %279 = llvm.mul %276, %240 : i64
    %280 = llvm.add %279, %243 : i64
    %281 = llvm.getelementptr %239[%280] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%278, %281, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %282 = vector.scalable.extract %277[4] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %283 = llvm.add %279, %248 : i64
    %284 = llvm.getelementptr %239[%283] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%282, %284, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %285 = vector.scalable.extract %277[8] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_0 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_0[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %286 = llvm.add %279, %252 : i64
    %287 = llvm.getelementptr %239[%286] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%285, %287, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca_0 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca_0[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %288 = vector.scalable.extract %277[12] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %289 = llvm.add %279, %256 : i64
    %290 = llvm.getelementptr %239[%289] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%288, %290, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %311 = arith.index_cast %arg3 : index to i32
      %312 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %313 = arith.index_cast %arg3 : index to i64
      %314 = llvm.extractvalue %312[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %315 = llvm.extractvalue %312[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %316 = llvm.mul %313, %315 : i64
      %317 = llvm.add %316, %c0_i64 : i64
      %318 = llvm.getelementptr %314[%317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %319 = "arm_sme.intr.read.horiz"(%0, %cst, %311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %318, %311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %319, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %291 = arith.addi %c12_vscale, %232 : index
    %292 = builtin.unrealized_conversion_cast %291 : index to i64
    %293 = arm_sve.psel %12, %7[%291] : vector<[16]xi1>, vector<[16]xi1>
    %294 = vector.scalable.extract %293[0] : vector<[4]xi1> from vector<[16]xi1>
    %295 = llvm.mul %292, %240 : i64
    %296 = llvm.add %295, %243 : i64
    %297 = llvm.getelementptr %239[%296] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%294, %297, %246) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %298 = vector.scalable.extract %293[4] : vector<[4]xi1> from vector<[16]xi1>
    %299 = llvm.add %295, %248 : i64
    %300 = llvm.getelementptr %239[%299] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%298, %300, %246) <{tile_id = 1 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %301 = vector.scalable.extract %293[8] : vector<[4]xi1> from vector<[16]xi1>
    %302 = llvm.add %295, %252 : i64
    %303 = llvm.getelementptr %239[%302] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%301, %303, %246) <{tile_id = 2 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %304 = vector.scalable.extract %293[12] : vector<[4]xi1> from vector<[16]xi1>
    %305 = llvm.add %295, %256 : i64
    %306 = llvm.getelementptr %239[%305] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%304, %306, %246) <{tile_id = 3 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %307 = arith.addi %232, %c1 : index
    cf.br ^bb65(%307 : index)
  ^bb67:  // pred: ^bb65
    %308 = arith.addi %13, %c1 : index
    cf.br ^bb5(%308 : index)
  ^bb68:  // pred: ^bb5
    %309 = arith.addi %8, %c16_vscale : index
    cf.br ^bb3(%309 : index)
  ^bb69:  // pred: ^bb3
    %310 = arith.addi %4, %c16_vscale : index
    cf.br ^bb1(%310 : index)
  ^bb70:  // pred: ^bb1
    return %arg2 : memref<?x?xf32, strided<[?, ?], offset: ?>>
  }
  module attributes {transform.with_named_sequence} {
  }
}

