#map = affine_map<()[s0, s1] -> (128, s0 - s1)>
#map1 = affine_map<()[s0, s1] -> (16, s0 - s1)>
#map2 = affine_map<()[s0, s1] -> (s0 + s1)>
#map3 = affine_map<()[s0, s1, s2] -> (s1, s0 - s2)>
module {
  func.func @gemm_fp32_linalg(%arg0: memref<?x?xf32>, %arg1: memref<?x?xf32>, %arg2: memref<?x?xf32>) attributes {c_kernel = "gemm_fp32", layout = "A row-major, B row-major, C row-major", lift_target = "linalg.matmul -> scf/affine -> vector -> arm_sme", llvm.arm_locally_streaming, llvm.arm_new_za, mlir_level = "linalg+scf", semantic = "C = A * B", step3.prefetch.A = "enable=true,priority=medium,cache=L1,locality=KEEP,distance=1-2 kk cache lines", step3.prefetch.B = "enable=true,priority=high,cache=L1,locality=KEEP,distance=2 kk cache lines or next B micro-tile", step3.prefetch_count = 2 : i64, step3.prefetch_injected = "vector.memref.prefetch"} {
    %c0_i64 = arith.constant 0 : i64
    %0 = llvm.mlir.poison : vector<[4]xf32>
    %cst = arith.constant dense<true> : vector<[4]xi1>
    %c16 = arith.constant 16 : index
    %c128 = arith.constant 128 : index
    %cst_0 = arith.constant 0.000000e+00 : f32
    %c1 = arith.constant 1 : index
    %c0 = arith.constant 0 : index
    %1 = ub.poison : f32
    %c-4 = arith.constant -4 : index
    %c-8 = arith.constant -8 : index
    %c8 = arith.constant 8 : index
    %c-12 = arith.constant -12 : index
    %c12 = arith.constant 12 : index
    %2 = ub.poison : vector<[4]xf32>
    %3 = ub.poison : vector<[16]xf32>
    %c4 = arith.constant 4 : index
    %vscale = vector.vscale
    %c4_vscale = arith.muli %vscale, %c4 : index
    %alloca = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 27 : i32} : memref<?x?xf32>
    %alloca_1 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 26 : i32} : memref<?x?xf32>
    %alloca_2 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 25 : i32} : memref<?x?xf32>
    %alloca_3 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 24 : i32} : memref<?x?xf32>
    %alloca_4 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 23 : i32} : memref<?x?xf32>
    %alloca_5 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 22 : i32} : memref<?x?xf32>
    %alloca_6 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 21 : i32} : memref<?x?xf32>
    %alloca_7 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 20 : i32} : memref<?x?xf32>
    %alloca_8 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 19 : i32} : memref<?x?xf32>
    %alloca_9 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 18 : i32} : memref<?x?xf32>
    %alloca_10 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 17 : i32} : memref<?x?xf32>
    %alloca_11 = memref.alloca(%c4_vscale, %c4_vscale) {arm_sme.in_memory_tile_id = 16 : i32} : memref<?x?xf32>
    %4 = builtin.unrealized_conversion_cast %c0 : index to i64
    %dim = memref.dim %arg0, %c0 : memref<?x?xf32>
    %dim_12 = memref.dim %arg0, %c1 : memref<?x?xf32>
    %dim_13 = memref.dim %arg1, %c1 : memref<?x?xf32>
    %c16_vscale = arith.muli %vscale, %c16 : index
    cf.br ^bb1(%c0 : index)
  ^bb1(%5: index):  // 2 preds: ^bb0, ^bb79
    %6 = arith.cmpi slt, %5, %dim : index
    cf.cond_br %6, ^bb2, ^bb80
  ^bb2:  // pred: ^bb1
    %7 = affine.min #map()[%dim, %5]
    cf.br ^bb3(%c0 : index)
  ^bb3(%8: index):  // 2 preds: ^bb2, ^bb78
    %9 = arith.cmpi slt, %8, %dim_13 : index
    cf.cond_br %9, ^bb4, ^bb79
  ^bb4:  // pred: ^bb3
    %10 = affine.min #map()[%dim_13, %8]
    %subview = memref.subview %arg2[%5, %8] [%7, %10] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
    cf.br ^bb5(%c0 : index)
  ^bb5(%11: index):  // 2 preds: ^bb4, ^bb77
    %12 = arith.cmpi slt, %11, %7 : index
    cf.cond_br %12, ^bb6, ^bb78
  ^bb6:  // pred: ^bb5
    %13 = affine.min #map1()[%7, %11]
    %14 = affine.apply #map2()[%5, %11]
    cf.br ^bb7(%c0 : index)
  ^bb7(%15: index):  // 2 preds: ^bb6, ^bb76
    %16 = arith.cmpi slt, %15, %10 : index
    cf.cond_br %16, ^bb8, ^bb77
  ^bb8:  // pred: ^bb7
    %17 = affine.min #map1()[%10, %15]
    %18 = affine.apply #map2()[%8, %15]
    %subview_14 = memref.subview %subview[%11, %15] [%13, %17] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<?x?xf32, strided<[?, 1], offset: ?>>
    linalg.fill ins(%cst_0 : f32) outs(%subview_14 : memref<?x?xf32, strided<[?, 1], offset: ?>>)
    cf.br ^bb9(%c0 : index)
  ^bb9(%19: index):  // 2 preds: ^bb8, ^bb75
    %20 = arith.cmpi slt, %19, %dim_12 : index
    cf.cond_br %20, ^bb10, ^bb76
  ^bb10:  // pred: ^bb9
    %21 = affine.min #map()[%dim_12, %19]
    %subview_15 = memref.subview %arg0[%14, %19] [%13, %21] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
    %subview_16 = memref.subview %arg1[%19, %18] [%21, %17] [1, 1] : memref<?x?xf32> to memref<?x?xf32, strided<[?, 1], offset: ?>>
    cf.br ^bb11(%c0 : index)
  ^bb11(%22: index):  // 2 preds: ^bb10, ^bb74
    %23 = arith.cmpi slt, %22, %13 : index
    cf.cond_br %23, ^bb12, ^bb75
  ^bb12:  // pred: ^bb11
    %24 = affine.min #map3()[%13, %c16_vscale, %22]
    %25 = vector.create_mask %24 : vector<[16]xi1>
    cf.br ^bb13(%c0 : index)
  ^bb13(%26: index):  // 2 preds: ^bb12, ^bb73
    %27 = arith.cmpi slt, %26, %17 : index
    cf.cond_br %27, ^bb14, ^bb74
  ^bb14:  // pred: ^bb13
    %28 = affine.min #map3()[%17, %c16_vscale, %26]
    %subview_17 = memref.subview %subview_14[%22, %26] [%24, %28] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<?x?xf32, strided<[?, 1], offset: ?>>
    %29 = builtin.unrealized_conversion_cast %subview_17 : memref<?x?xf32, strided<[?, 1], offset: ?>> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %30 = vector.create_mask %28 : vector<[16]xi1>
    cf.br ^bb15(%c0 : index)
  ^bb15(%31: index):  // 2 preds: ^bb14, ^bb72
    %32 = arith.cmpi slt, %31, %21 : index
    cf.cond_br %32, ^bb16, ^bb73
  ^bb16:  // pred: ^bb15
    %subview_18 = memref.subview %subview_15[%22, %31] [%24, 1] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<?x1xf32, strided<[?, 1], offset: ?>>
    %subview_19 = memref.subview %subview_16[%31, %26] [1, %28] [1, 1] : memref<?x?xf32, strided<[?, 1], offset: ?>> to memref<1x?xf32, strided<[?, 1], offset: ?>>
    %subview_20 = memref.subview %subview_18[0, 0] [%24, 1] [1, 1] : memref<?x1xf32, strided<[?, 1], offset: ?>> to memref<?xf32, strided<[?], offset: ?>>
    memref.prefetch %subview_20[%c0], read, locality<3>, data : memref<?xf32, strided<[?], offset: ?>>
    cf.br ^bb17(%c0, %3 : index, vector<[16]xf32>)
  ^bb17(%33: index, %34: vector<[16]xf32>):  // 2 preds: ^bb16, ^bb20
    %35 = arith.cmpi slt, %33, %c16_vscale : index
    cf.cond_br %35, ^bb18, ^bb21
  ^bb18:  // pred: ^bb17
    %36 = vector.extract %25[%33] : i1 from vector<[16]xi1>
    cf.cond_br %36, ^bb19, ^bb20(%34 : vector<[16]xf32>)
  ^bb19:  // pred: ^bb18
    %37 = memref.load %subview_20[%33] : memref<?xf32, strided<[?], offset: ?>>
    %38 = vector.insert %37, %34 [%33] : f32 into vector<[16]xf32>
    cf.br ^bb20(%38 : vector<[16]xf32>)
  ^bb20(%39: vector<[16]xf32>):  // 2 preds: ^bb18, ^bb19
    %40 = arith.addi %33, %c1 : index
    cf.br ^bb17(%40, %39 : index, vector<[16]xf32>)
  ^bb21:  // pred: ^bb17
    %subview_21 = memref.subview %subview_19[0, 0] [1, %28] [1, 1] : memref<1x?xf32, strided<[?, 1], offset: ?>> to memref<?xf32, strided<[1], offset: ?>>
    memref.prefetch %subview_21[%c0], read, locality<3>, data : memref<?xf32, strided<[1], offset: ?>>
    %41 = vector.transfer_read %subview_21[%c0], %1, %30 {in_bounds = [true]} : memref<?xf32, strided<[1], offset: ?>>, vector<[16]xf32>
    %42 = arith.index_castui %28 : index to i32
    cf.br ^bb22(%c0 : index)
  ^bb22(%43: index):  // 2 preds: ^bb21, ^bb23
    %44 = arith.cmpi slt, %43, %c4_vscale : index
    cf.cond_br %44, ^bb23, ^bb24
  ^bb23:  // pred: ^bb22
    %45 = arith.cmpi slt, %43, %24 : index
    %46 = arith.extsi %45 : i1 to i32
    %47 = arith.andi %46, %42 : i32
    %48 = arith.index_cast %47 : i32 to index
    %49 = vector.create_mask %48 : vector<[4]xi1>
    %50 = vector.maskedload %subview_17[%43, %c0], %49, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_11 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_11[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %51 = arith.index_castui %43 : index to i32
    "arm_sme.intr.write.horiz"(%51, %cst, %50) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_11 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_11[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %52 = arith.addi %43, %c1 : index
    cf.br ^bb22(%52 : index)
  ^bb24:  // pred: ^bb22
    %c-4_vscale = arith.muli %vscale, %c-4 : index
    %53 = arith.addi %28, %c-4_vscale : index
    %54 = builtin.unrealized_conversion_cast %c4_vscale : index to i64
    %55 = arith.index_castui %53 : index to i32
    cf.br ^bb25(%c0 : index)
  ^bb25(%56: index):  // 2 preds: ^bb24, ^bb26
    %57 = arith.cmpi slt, %56, %c4_vscale : index
    cf.cond_br %57, ^bb26, ^bb27
  ^bb26:  // pred: ^bb25
    %58 = arith.cmpi slt, %56, %24 : index
    %59 = arith.extsi %58 : i1 to i32
    %60 = arith.andi %59, %55 : i32
    %61 = arith.index_cast %60 : i32 to index
    %62 = vector.create_mask %61 : vector<[4]xi1>
    %63 = vector.maskedload %subview_17[%56, %c4_vscale], %62, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %64 = arith.index_castui %56 : index to i32
    "arm_sme.intr.write.horiz"(%64, %cst, %63) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %65 = arith.addi %56, %c1 : index
    cf.br ^bb25(%65 : index)
  ^bb27:  // pred: ^bb25
    %c-8_vscale = arith.muli %vscale, %c-8 : index
    %66 = arith.addi %28, %c-8_vscale : index
    %c8_vscale = arith.muli %vscale, %c8 : index
    %67 = builtin.unrealized_conversion_cast %c8_vscale : index to i64
    %68 = arith.index_castui %66 : index to i32
    cf.br ^bb28(%c0 : index)
  ^bb28(%69: index):  // 2 preds: ^bb27, ^bb29
    %70 = arith.cmpi slt, %69, %c4_vscale : index
    cf.cond_br %70, ^bb29, ^bb30
  ^bb29:  // pred: ^bb28
    %71 = arith.cmpi slt, %69, %24 : index
    %72 = arith.extsi %71 : i1 to i32
    %73 = arith.andi %72, %68 : i32
    %74 = arith.index_cast %73 : i32 to index
    %75 = vector.create_mask %74 : vector<[4]xi1>
    %76 = vector.maskedload %subview_17[%69, %c8_vscale], %75, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %77 = arith.index_castui %69 : index to i32
    "arm_sme.intr.write.horiz"(%77, %cst, %76) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %78 = arith.addi %69, %c1 : index
    cf.br ^bb28(%78 : index)
  ^bb30:  // pred: ^bb28
    %c-12_vscale = arith.muli %vscale, %c-12 : index
    %79 = arith.addi %28, %c-12_vscale : index
    %c12_vscale = arith.muli %vscale, %c12 : index
    %80 = builtin.unrealized_conversion_cast %c12_vscale : index to i64
    %81 = arith.index_castui %79 : index to i32
    cf.br ^bb31(%c0 : index)
  ^bb31(%82: index):  // 2 preds: ^bb30, ^bb32
    %83 = arith.cmpi slt, %82, %c4_vscale : index
    cf.cond_br %83, ^bb32, ^bb33
  ^bb32:  // pred: ^bb31
    %84 = arith.cmpi slt, %82, %24 : index
    %85 = arith.extsi %84 : i1 to i32
    %86 = arith.andi %85, %81 : i32
    %87 = arith.index_cast %86 : i32 to index
    %88 = vector.create_mask %87 : vector<[4]xi1>
    %89 = vector.maskedload %subview_17[%82, %c12_vscale], %88, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %90 = arith.index_castui %82 : index to i32
    "arm_sme.intr.write.horiz"(%90, %cst, %89) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %91 = arith.addi %82, %c1 : index
    cf.br ^bb31(%91 : index)
  ^bb33:  // pred: ^bb31
    %92 = arith.addi %24, %c-4_vscale : index
    cf.br ^bb34(%c0 : index)
  ^bb34(%93: index):  // 2 preds: ^bb33, ^bb35
    %94 = arith.cmpi slt, %93, %c4_vscale : index
    cf.cond_br %94, ^bb35, ^bb36
  ^bb35:  // pred: ^bb34
    %95 = arith.cmpi slt, %93, %92 : index
    %96 = arith.extsi %95 : i1 to i32
    %97 = arith.andi %96, %42 : i32
    %98 = arith.index_cast %97 : i32 to index
    %99 = vector.create_mask %98 : vector<[4]xi1>
    %100 = arith.addi %c4_vscale, %93 : index
    %101 = vector.maskedload %subview_17[%100, %c0], %99, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %102 = arith.index_castui %93 : index to i32
    "arm_sme.intr.write.horiz"(%102, %cst, %101) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %103 = arith.addi %93, %c1 : index
    cf.br ^bb34(%103 : index)
  ^bb36:  // pred: ^bb34
    cf.br ^bb37(%c0 : index)
  ^bb37(%104: index):  // 2 preds: ^bb36, ^bb38
    %105 = arith.cmpi slt, %104, %c4_vscale : index
    cf.cond_br %105, ^bb38, ^bb39
  ^bb38:  // pred: ^bb37
    %106 = arith.cmpi slt, %104, %92 : index
    %107 = arith.extsi %106 : i1 to i32
    %108 = arith.andi %107, %55 : i32
    %109 = arith.index_cast %108 : i32 to index
    %110 = vector.create_mask %109 : vector<[4]xi1>
    %111 = arith.addi %c4_vscale, %104 : index
    %112 = vector.maskedload %subview_17[%111, %c4_vscale], %110, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %113 = arith.index_castui %104 : index to i32
    "arm_sme.intr.write.horiz"(%113, %cst, %112) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %114 = arith.addi %104, %c1 : index
    cf.br ^bb37(%114 : index)
  ^bb39:  // pred: ^bb37
    cf.br ^bb40(%c0 : index)
  ^bb40(%115: index):  // 2 preds: ^bb39, ^bb41
    %116 = arith.cmpi slt, %115, %c4_vscale : index
    cf.cond_br %116, ^bb41, ^bb42
  ^bb41:  // pred: ^bb40
    %117 = arith.cmpi slt, %115, %92 : index
    %118 = arith.extsi %117 : i1 to i32
    %119 = arith.andi %118, %68 : i32
    %120 = arith.index_cast %119 : i32 to index
    %121 = vector.create_mask %120 : vector<[4]xi1>
    %122 = arith.addi %c4_vscale, %115 : index
    %123 = vector.maskedload %subview_17[%122, %c8_vscale], %121, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %124 = arith.index_castui %115 : index to i32
    "arm_sme.intr.write.horiz"(%124, %cst, %123) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %125 = arith.addi %115, %c1 : index
    cf.br ^bb40(%125 : index)
  ^bb42:  // pred: ^bb40
    cf.br ^bb43(%c0 : index)
  ^bb43(%126: index):  // 2 preds: ^bb42, ^bb44
    %127 = arith.cmpi slt, %126, %c4_vscale : index
    cf.cond_br %127, ^bb44, ^bb45
  ^bb44:  // pred: ^bb43
    %128 = arith.cmpi slt, %126, %92 : index
    %129 = arith.extsi %128 : i1 to i32
    %130 = arith.andi %129, %81 : i32
    %131 = arith.index_cast %130 : i32 to index
    %132 = vector.create_mask %131 : vector<[4]xi1>
    %133 = arith.addi %c4_vscale, %126 : index
    %134 = vector.maskedload %subview_17[%133, %c12_vscale], %132, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %135 = arith.index_castui %126 : index to i32
    "arm_sme.intr.write.horiz"(%135, %cst, %134) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %136 = arith.addi %126, %c1 : index
    cf.br ^bb43(%136 : index)
  ^bb45:  // pred: ^bb43
    %137 = arith.addi %24, %c-8_vscale : index
    cf.br ^bb46(%c0 : index)
  ^bb46(%138: index):  // 2 preds: ^bb45, ^bb47
    %139 = arith.cmpi slt, %138, %c4_vscale : index
    cf.cond_br %139, ^bb47, ^bb48
  ^bb47:  // pred: ^bb46
    %140 = arith.cmpi slt, %138, %137 : index
    %141 = arith.extsi %140 : i1 to i32
    %142 = arith.andi %141, %42 : i32
    %143 = arith.index_cast %142 : i32 to index
    %144 = vector.create_mask %143 : vector<[4]xi1>
    %145 = arith.addi %c8_vscale, %138 : index
    %146 = vector.maskedload %subview_17[%145, %c0], %144, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %147 = arith.index_castui %138 : index to i32
    "arm_sme.intr.write.horiz"(%147, %cst, %146) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %148 = arith.addi %138, %c1 : index
    cf.br ^bb46(%148 : index)
  ^bb48:  // pred: ^bb46
    cf.br ^bb49(%c0 : index)
  ^bb49(%149: index):  // 2 preds: ^bb48, ^bb50
    %150 = arith.cmpi slt, %149, %c4_vscale : index
    cf.cond_br %150, ^bb50, ^bb51
  ^bb50:  // pred: ^bb49
    %151 = arith.cmpi slt, %149, %137 : index
    %152 = arith.extsi %151 : i1 to i32
    %153 = arith.andi %152, %55 : i32
    %154 = arith.index_cast %153 : i32 to index
    %155 = vector.create_mask %154 : vector<[4]xi1>
    %156 = arith.addi %c8_vscale, %149 : index
    %157 = vector.maskedload %subview_17[%156, %c4_vscale], %155, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %158 = arith.index_castui %149 : index to i32
    "arm_sme.intr.write.horiz"(%158, %cst, %157) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %159 = arith.addi %149, %c1 : index
    cf.br ^bb49(%159 : index)
  ^bb51:  // pred: ^bb49
    cf.br ^bb52(%c0 : index)
  ^bb52(%160: index):  // 2 preds: ^bb51, ^bb53
    %161 = arith.cmpi slt, %160, %c4_vscale : index
    cf.cond_br %161, ^bb53, ^bb54
  ^bb53:  // pred: ^bb52
    %162 = arith.cmpi slt, %160, %137 : index
    %163 = arith.extsi %162 : i1 to i32
    %164 = arith.andi %163, %68 : i32
    %165 = arith.index_cast %164 : i32 to index
    %166 = vector.create_mask %165 : vector<[4]xi1>
    %167 = arith.addi %c8_vscale, %160 : index
    %168 = vector.maskedload %subview_17[%167, %c8_vscale], %166, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %169 = arith.index_castui %160 : index to i32
    "arm_sme.intr.write.horiz"(%169, %cst, %168) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %170 = arith.addi %160, %c1 : index
    cf.br ^bb52(%170 : index)
  ^bb54:  // pred: ^bb52
    cf.br ^bb55(%c0 : index)
  ^bb55(%171: index):  // 2 preds: ^bb54, ^bb56
    %172 = arith.cmpi slt, %171, %c4_vscale : index
    cf.cond_br %172, ^bb56, ^bb57
  ^bb56:  // pred: ^bb55
    %173 = arith.cmpi slt, %171, %137 : index
    %174 = arith.extsi %173 : i1 to i32
    %175 = arith.andi %174, %81 : i32
    %176 = arith.index_cast %175 : i32 to index
    %177 = vector.create_mask %176 : vector<[4]xi1>
    %178 = arith.addi %c8_vscale, %171 : index
    %179 = vector.maskedload %subview_17[%178, %c12_vscale], %177, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %180 = arith.index_castui %171 : index to i32
    "arm_sme.intr.write.horiz"(%180, %cst, %179) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %181 = arith.addi %171, %c1 : index
    cf.br ^bb55(%181 : index)
  ^bb57:  // pred: ^bb55
    %182 = arith.addi %24, %c-12_vscale : index
    cf.br ^bb58(%c0 : index)
  ^bb58(%183: index):  // 2 preds: ^bb57, ^bb59
    %184 = arith.cmpi slt, %183, %c4_vscale : index
    cf.cond_br %184, ^bb59, ^bb60
  ^bb59:  // pred: ^bb58
    %185 = arith.cmpi slt, %183, %182 : index
    %186 = arith.extsi %185 : i1 to i32
    %187 = arith.andi %186, %42 : i32
    %188 = arith.index_cast %187 : i32 to index
    %189 = vector.create_mask %188 : vector<[4]xi1>
    %190 = arith.addi %c12_vscale, %183 : index
    %191 = vector.maskedload %subview_17[%190, %c0], %189, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    %192 = arith.index_castui %183 : index to i32
    "arm_sme.intr.write.horiz"(%192, %cst, %191) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %193 = arith.addi %183, %c1 : index
    cf.br ^bb58(%193 : index)
  ^bb60:  // pred: ^bb58
    cf.br ^bb61(%c0 : index)
  ^bb61(%194: index):  // 2 preds: ^bb60, ^bb62
    %195 = arith.cmpi slt, %194, %c4_vscale : index
    cf.cond_br %195, ^bb62, ^bb63
  ^bb62:  // pred: ^bb61
    %196 = arith.cmpi slt, %194, %182 : index
    %197 = arith.extsi %196 : i1 to i32
    %198 = arith.andi %197, %55 : i32
    %199 = arith.index_cast %198 : i32 to index
    %200 = vector.create_mask %199 : vector<[4]xi1>
    %201 = arith.addi %c12_vscale, %194 : index
    %202 = vector.maskedload %subview_17[%201, %c4_vscale], %200, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    %203 = arith.index_castui %194 : index to i32
    "arm_sme.intr.write.horiz"(%203, %cst, %202) <{tile_id = 1 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %204 = arith.addi %194, %c1 : index
    cf.br ^bb61(%204 : index)
  ^bb63:  // pred: ^bb61
    cf.br ^bb64(%c0 : index)
  ^bb64(%205: index):  // 2 preds: ^bb63, ^bb65
    %206 = arith.cmpi slt, %205, %c4_vscale : index
    cf.cond_br %206, ^bb65, ^bb66
  ^bb65:  // pred: ^bb64
    %207 = arith.cmpi slt, %205, %182 : index
    %208 = arith.extsi %207 : i1 to i32
    %209 = arith.andi %208, %68 : i32
    %210 = arith.index_cast %209 : i32 to index
    %211 = vector.create_mask %210 : vector<[4]xi1>
    %212 = arith.addi %c12_vscale, %205 : index
    %213 = vector.maskedload %subview_17[%212, %c8_vscale], %211, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    %214 = arith.index_castui %205 : index to i32
    "arm_sme.intr.write.horiz"(%214, %cst, %213) <{tile_id = 2 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %215 = arith.addi %205, %c1 : index
    cf.br ^bb64(%215 : index)
  ^bb66:  // pred: ^bb64
    cf.br ^bb67(%c0 : index)
  ^bb67(%216: index):  // 2 preds: ^bb66, ^bb68
    %217 = arith.cmpi slt, %216, %c4_vscale : index
    cf.cond_br %217, ^bb68, ^bb69
  ^bb68:  // pred: ^bb67
    %218 = arith.cmpi slt, %216, %182 : index
    %219 = arith.extsi %218 : i1 to i32
    %220 = arith.andi %219, %81 : i32
    %221 = arith.index_cast %220 : i32 to index
    %222 = vector.create_mask %221 : vector<[4]xi1>
    %223 = arith.addi %c12_vscale, %216 : index
    %224 = vector.maskedload %subview_17[%223, %c12_vscale], %222, %2 : memref<?x?xf32, strided<[?, 1], offset: ?>>, vector<[4]xi1>, vector<[4]xf32> into vector<[4]xf32>
    %225 = arith.index_castui %216 : index to i32
    "arm_sme.intr.write.horiz"(%225, %cst, %224) <{tile_id = 3 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %226 = arith.addi %216, %c1 : index
    cf.br ^bb67(%226 : index)
  ^bb69:  // pred: ^bb67
    %227 = vector.scalable.extract %34[0] : vector<[4]xf32> from vector<[16]xf32>
    %228 = vector.scalable.extract %41[0] : vector<[4]xf32> from vector<[16]xf32>
    %229 = vector.create_mask %24 : vector<[4]xi1>
    %230 = vector.create_mask %28 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_11 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_11[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%229, %230, %227, %228) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_11 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_11[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %231 = vector.scalable.extract %41[4] : vector<[4]xf32> from vector<[16]xf32>
    %232 = vector.create_mask %53 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%229, %232, %227, %231) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %233 = vector.scalable.extract %41[8] : vector<[4]xf32> from vector<[16]xf32>
    %234 = vector.create_mask %66 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%229, %234, %227, %233) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %235 = vector.scalable.extract %41[12] : vector<[4]xf32> from vector<[16]xf32>
    %236 = vector.create_mask %79 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%229, %236, %227, %235) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %237 = vector.scalable.extract %34[4] : vector<[4]xf32> from vector<[16]xf32>
    %238 = vector.create_mask %92 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%238, %230, %237, %228) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%238, %232, %237, %231) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%238, %234, %237, %233) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%238, %236, %237, %235) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %239 = vector.scalable.extract %34[8] : vector<[4]xf32> from vector<[16]xf32>
    %240 = vector.create_mask %137 : vector<[4]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%240, %230, %239, %228) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%240, %232, %239, %231) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%240, %234, %239, %233) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    "arm_sme.intr.mopa"(%240, %236, %239, %235) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %241 = vector.scalable.extract %34[12] : vector<[4]xf32> from vector<[16]xf32>
    %242 = vector.create_mask %182 : vector<[4]xi1>
    "arm_sme.intr.mopa"(%242, %230, %241, %228) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    "arm_sme.intr.mopa"(%242, %232, %241, %231) <{tile_id = 1 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    "arm_sme.intr.mopa"(%242, %234, %241, %233) <{tile_id = 2 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    "arm_sme.intr.mopa"(%242, %236, %241, %235) <{tile_id = 3 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    cf.br ^bb70(%c0 : index)
  ^bb70(%243: index):  // 2 preds: ^bb69, ^bb71
    %244 = builtin.unrealized_conversion_cast %243 : index to i64
    %245 = arith.cmpi slt, %243, %c4_vscale : index
    cf.cond_br %245, ^bb71, ^bb72
  ^bb71:  // pred: ^bb70
    %246 = arm_sve.psel %30, %25[%243] : vector<[16]xi1>, vector<[16]xi1>
    %247 = vector.scalable.extract %246[0] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_11 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_11[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %248 = llvm.extractvalue %29[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %249 = llvm.extractvalue %29[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %250 = llvm.getelementptr %248[%249] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %251 = llvm.extractvalue %29[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %252 = llvm.mul %244, %251 : i64
    %253 = llvm.add %252, %4 : i64
    %254 = llvm.getelementptr %250[%253] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %255 = arith.index_castui %243 : index to i32
    "arm_sme.intr.st1w.horiz"(%247, %254, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_11 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_11[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %256 = vector.scalable.extract %246[4] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %257 = llvm.add %252, %54 : i64
    %258 = llvm.getelementptr %250[%257] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%256, %258, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_10 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_10[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %259 = vector.scalable.extract %246[8] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %260 = llvm.add %252, %67 : i64
    %261 = llvm.getelementptr %250[%260] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%259, %261, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_9 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_9[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %262 = vector.scalable.extract %246[12] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %263 = llvm.add %252, %80 : i64
    %264 = llvm.getelementptr %250[%263] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%262, %264, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_8 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_8[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %265 = arith.addi %c4_vscale, %243 : index
    %266 = builtin.unrealized_conversion_cast %265 : index to i64
    %267 = arm_sve.psel %30, %25[%265] : vector<[16]xi1>, vector<[16]xi1>
    %268 = vector.scalable.extract %267[0] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %269 = llvm.mul %266, %251 : i64
    %270 = llvm.add %269, %4 : i64
    %271 = llvm.getelementptr %250[%270] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%268, %271, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_7 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_7[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %272 = vector.scalable.extract %267[4] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %273 = llvm.add %269, %54 : i64
    %274 = llvm.getelementptr %250[%273] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%272, %274, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_6 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_6[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %275 = vector.scalable.extract %267[8] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %276 = llvm.add %269, %67 : i64
    %277 = llvm.getelementptr %250[%276] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%275, %277, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_5 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_5[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %278 = vector.scalable.extract %267[12] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %279 = llvm.add %269, %80 : i64
    %280 = llvm.getelementptr %250[%279] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%278, %280, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_4 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_4[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %281 = arith.addi %c8_vscale, %243 : index
    %282 = builtin.unrealized_conversion_cast %281 : index to i64
    %283 = arm_sve.psel %30, %25[%281] : vector<[16]xi1>, vector<[16]xi1>
    %284 = vector.scalable.extract %283[0] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %285 = llvm.mul %282, %251 : i64
    %286 = llvm.add %285, %4 : i64
    %287 = llvm.getelementptr %250[%286] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%284, %287, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_3 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_3[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %288 = vector.scalable.extract %283[4] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %289 = llvm.add %285, %54 : i64
    %290 = llvm.getelementptr %250[%289] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%288, %290, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_2 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_2[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %291 = vector.scalable.extract %283[8] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %292 = llvm.add %285, %67 : i64
    %293 = llvm.getelementptr %250[%292] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%291, %293, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca_1 : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca_1[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %294 = vector.scalable.extract %283[12] : vector<[4]xi1> from vector<[16]xi1>
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %295 = llvm.add %285, %80 : i64
    %296 = llvm.getelementptr %250[%295] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%294, %296, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    scf.for %arg3 = %c0 to %c4_vscale step %c1 {
      %322 = arith.index_cast %arg3 : index to i32
      %323 = builtin.unrealized_conversion_cast %alloca : memref<?x?xf32> to !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
      %324 = arith.index_cast %arg3 : index to i64
      %325 = llvm.extractvalue %323[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %326 = llvm.extractvalue %323[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
      %327 = llvm.mul %324, %326 : i64
      %328 = llvm.add %327, %c0_i64 : i64
      %329 = llvm.getelementptr %325[%328] : (!llvm.ptr, i64) -> !llvm.ptr, f32
      %330 = "arm_sme.intr.read.horiz"(%0, %cst, %322) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
      "arm_sme.intr.ld1w.horiz"(%cst, %329, %322) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
      vector.store %330, %alloca[%arg3, %c0] : memref<?x?xf32>, vector<[4]xf32>
    }
    %297 = arith.addi %c12_vscale, %243 : index
    %298 = builtin.unrealized_conversion_cast %297 : index to i64
    %299 = arm_sve.psel %30, %25[%297] : vector<[16]xi1>, vector<[16]xi1>
    %300 = vector.scalable.extract %299[0] : vector<[4]xi1> from vector<[16]xi1>
    %301 = llvm.mul %298, %251 : i64
    %302 = llvm.add %301, %4 : i64
    %303 = llvm.getelementptr %250[%302] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%300, %303, %255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %304 = vector.scalable.extract %299[4] : vector<[4]xi1> from vector<[16]xi1>
    %305 = llvm.add %301, %54 : i64
    %306 = llvm.getelementptr %250[%305] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%304, %306, %255) <{tile_id = 1 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %307 = vector.scalable.extract %299[8] : vector<[4]xi1> from vector<[16]xi1>
    %308 = llvm.add %301, %67 : i64
    %309 = llvm.getelementptr %250[%308] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%307, %309, %255) <{tile_id = 2 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %310 = vector.scalable.extract %299[12] : vector<[4]xi1> from vector<[16]xi1>
    %311 = llvm.add %301, %80 : i64
    %312 = llvm.getelementptr %250[%311] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%310, %312, %255) <{tile_id = 3 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %313 = arith.addi %243, %c1 : index
    cf.br ^bb70(%313 : index)
  ^bb72:  // pred: ^bb70
    %314 = arith.addi %31, %c1 : index
    cf.br ^bb15(%314 : index)
  ^bb73:  // pred: ^bb15
    %315 = arith.addi %26, %c16_vscale : index
    cf.br ^bb13(%315 : index)
  ^bb74:  // pred: ^bb13
    %316 = arith.addi %22, %c16_vscale : index
    cf.br ^bb11(%316 : index)
  ^bb75:  // pred: ^bb11
    %317 = arith.addi %19, %c128 : index
    cf.br ^bb9(%317 : index)
  ^bb76:  // pred: ^bb9
    %318 = arith.addi %15, %c16 : index
    cf.br ^bb7(%318 : index)
  ^bb77:  // pred: ^bb7
    %319 = arith.addi %11, %c16 : index
    cf.br ^bb5(%319 : index)
  ^bb78:  // pred: ^bb5
    %320 = arith.addi %8, %c128 : index
    cf.br ^bb3(%320 : index)
  ^bb79:  // pred: ^bb3
    %321 = arith.addi %5, %c128 : index
    cf.br ^bb1(%321 : index)
  ^bb80:  // pred: ^bb1
    return
  }
}

