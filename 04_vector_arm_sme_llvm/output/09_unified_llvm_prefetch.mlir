module {
  llvm.func @gemm_step4_compute(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: i64, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: i64, %arg7: !llvm.ptr, %arg8: !llvm.ptr, %arg9: i64, %arg10: i64, %arg11: i64, %arg12: i64, %arg13: i64, %arg14: !llvm.ptr, %arg15: !llvm.ptr, %arg16: i64, %arg17: i64, %arg18: i64, %arg19: i64, %arg20: i64) -> !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> attributes {arm_locally_streaming, arm_new_za, step4_vector_prefetch = "memref_prefetch"} {
    %0 = llvm.mlir.constant(0 : index) : i64
    %1 = llvm.mlir.constant(dense<true> : vector<[4]xi1>) : vector<[4]xi1>
    %2 = llvm.mlir.constant(0 : i64) : i64
    %3 = llvm.mlir.constant(1 : index) : i64
    %4 = llvm.mlir.constant(16 : index) : i64
    %5 = llvm.mlir.constant(-4 : index) : i64
    %6 = llvm.mlir.constant(-8 : index) : i64
    %7 = llvm.mlir.constant(8 : index) : i64
    %8 = llvm.mlir.constant(-12 : index) : i64
    %9 = llvm.mlir.constant(12 : index) : i64
    %10 = llvm.mlir.poison : vector<[4]xf32>
    %11 = llvm.mlir.poison : vector<[16]xf32>
    %12 = llvm.mlir.constant(4 : index) : i64
    %13 = llvm.mlir.constant(2147483647 : index) : i64
    %14 = llvm.mlir.poison : vector<[16]xi32>
    %15 = llvm.mlir.constant(0 : i32) : i32
    %16 = llvm.mlir.poison : vector<[4]xi32>
    %17 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %18 = llvm.insertvalue %arg14, %17[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %19 = llvm.insertvalue %arg15, %18[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %20 = llvm.insertvalue %arg16, %19[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %21 = llvm.insertvalue %arg17, %20[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %22 = llvm.insertvalue %arg19, %21[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %23 = llvm.insertvalue %arg18, %22[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %24 = llvm.insertvalue %arg20, %23[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %25 = "llvm.intr.vscale"() : () -> i64
    %26 = llvm.mul %25, %12 : i64
    %27 = llvm.mul %26, %26 : i64
    %28 = llvm.alloca %27 x f32 : (i64) -> !llvm.ptr
    %29 = llvm.mul %26, %26 : i64
    %30 = llvm.alloca %29 x f32 : (i64) -> !llvm.ptr
    %31 = llvm.mul %26, %26 : i64
    %32 = llvm.alloca %31 x f32 : (i64) -> !llvm.ptr
    %33 = llvm.mul %26, %26 : i64
    %34 = llvm.alloca %33 x f32 : (i64) -> !llvm.ptr
    %35 = llvm.mul %26, %26 : i64
    %36 = llvm.alloca %35 x f32 : (i64) -> !llvm.ptr
    %37 = llvm.mul %26, %26 : i64
    %38 = llvm.alloca %37 x f32 : (i64) -> !llvm.ptr
    %39 = llvm.mul %26, %26 : i64
    %40 = llvm.alloca %39 x f32 : (i64) -> !llvm.ptr
    %41 = llvm.mul %26, %26 : i64
    %42 = llvm.alloca %41 x f32 : (i64) -> !llvm.ptr
    %43 = llvm.mul %26, %26 : i64
    %44 = llvm.alloca %43 x f32 : (i64) -> !llvm.ptr
    %45 = llvm.mul %26, %26 : i64
    %46 = llvm.alloca %45 x f32 : (i64) -> !llvm.ptr
    %47 = llvm.mul %26, %26 : i64
    %48 = llvm.alloca %47 x f32 : (i64) -> !llvm.ptr
    %49 = llvm.mul %26, %26 : i64
    %50 = llvm.alloca %49 x f32 : (i64) -> !llvm.ptr
    %51 = llvm.mul %25, %4 : i64
    llvm.br ^bb1(%0 : i64)
  ^bb1(%52: i64):  // 2 preds: ^bb0, ^bb270
    %53 = llvm.icmp "slt" %52, %arg3 : i64
    llvm.cond_br %53, ^bb2, ^bb271
  ^bb2:  // pred: ^bb1
    %54 = llvm.sub %arg3, %52 : i64
    %55 = llvm.intr.smin(%51, %54) : (i64, i64) -> i64
    %56 = llvm.intr.stepvector : vector<[16]xi32>
    %57 = llvm.intr.smin(%55, %13) : (i64, i64) -> i64
    %58 = llvm.trunc %57 : i64 to i32
    %59 = llvm.insertelement %58, %14[%15 : i32] : vector<[16]xi32>
    %60 = llvm.shufflevector %59, %14 [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] : vector<[16]xi32> 
    %61 = llvm.icmp "slt" %56, %60 : vector<[16]xi32>
    llvm.br ^bb3(%0 : i64)
  ^bb3(%62: i64):  // 2 preds: ^bb2, ^bb269
    %63 = llvm.icmp "slt" %62, %arg11 : i64
    llvm.cond_br %63, ^bb4, ^bb270
  ^bb4:  // pred: ^bb3
    %64 = llvm.sub %arg11, %62 : i64
    %65 = llvm.intr.smin(%51, %64) : (i64, i64) -> i64
    %66 = llvm.mul %52, %arg19 overflow<nsw> : i64
    %67 = llvm.add %arg16, %66 : i64
    %68 = llvm.mul %62, %arg20 overflow<nsw> : i64
    %69 = llvm.add %67, %68 : i64
    %70 = llvm.intr.stepvector : vector<[16]xi32>
    %71 = llvm.intr.smin(%65, %13) : (i64, i64) -> i64
    %72 = llvm.trunc %71 : i64 to i32
    %73 = llvm.insertelement %72, %14[%15 : i32] : vector<[16]xi32>
    %74 = llvm.shufflevector %73, %14 [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] : vector<[16]xi32> 
    %75 = llvm.icmp "slt" %70, %74 : vector<[16]xi32>
    llvm.br ^bb5(%0 : i64)
  ^bb5(%76: i64):  // 2 preds: ^bb4, ^bb268
    %77 = llvm.icmp "slt" %76, %arg4 : i64
    llvm.cond_br %77, ^bb6, ^bb269
  ^bb6:  // pred: ^bb5
    %78 = llvm.mul %52, %arg5 overflow<nsw> : i64
    %79 = llvm.add %arg2, %78 : i64
    %80 = llvm.mul %76, %arg6 overflow<nsw> : i64
    %81 = llvm.add %79, %80 : i64
    %82 = llvm.getelementptr %arg1[%81] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %83 = llvm.mul %arg5, %0 : i64
    %84 = llvm.getelementptr %82[%83] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "llvm.intr.prefetch"(%84) <{cache = 1 : i32, hint = 3 : i32, rw = 0 : i32}> : (!llvm.ptr) -> ()
    llvm.br ^bb7(%0, %11 : i64, vector<[16]xf32>)
  ^bb7(%85: i64, %86: vector<[16]xf32>):  // 2 preds: ^bb6, ^bb10
    %87 = llvm.icmp "slt" %85, %51 : i64
    llvm.cond_br %87, ^bb8, ^bb11
  ^bb8:  // pred: ^bb7
    %88 = llvm.extractelement %61[%85 : i64] : vector<[16]xi1>
    llvm.cond_br %88, ^bb9, ^bb10(%86 : vector<[16]xf32>)
  ^bb9:  // pred: ^bb8
    %89 = llvm.getelementptr %arg1[%81] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %90 = llvm.mul %85, %arg5 overflow<nsw> : i64
    %91 = llvm.getelementptr inbounds %89[%90] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %92 = llvm.load %91 : !llvm.ptr -> f32
    %93 = llvm.insertelement %92, %86[%85 : i64] : vector<[16]xf32>
    llvm.br ^bb10(%93 : vector<[16]xf32>)
  ^bb10(%94: vector<[16]xf32>):  // 2 preds: ^bb8, ^bb9
    %95 = llvm.add %85, %3 : i64
    llvm.br ^bb7(%95, %94 : i64, vector<[16]xf32>)
  ^bb11:  // pred: ^bb7
    %96 = llvm.mul %76, %arg12 overflow<nsw> : i64
    %97 = llvm.add %arg9, %96 : i64
    %98 = llvm.mul %62, %arg13 overflow<nsw> : i64
    %99 = llvm.add %97, %98 : i64
    %100 = llvm.getelementptr %arg8[%99] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %101 = llvm.mul %arg13, %0 : i64
    %102 = llvm.getelementptr %100[%101] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "llvm.intr.prefetch"(%102) <{cache = 1 : i32, hint = 3 : i32, rw = 0 : i32}> : (!llvm.ptr) -> ()
    llvm.br ^bb12(%0, %11 : i64, vector<[16]xf32>)
  ^bb12(%103: i64, %104: vector<[16]xf32>):  // 2 preds: ^bb11, ^bb15
    %105 = llvm.icmp "slt" %103, %51 : i64
    llvm.cond_br %105, ^bb13, ^bb16
  ^bb13:  // pred: ^bb12
    %106 = llvm.extractelement %75[%103 : i64] : vector<[16]xi1>
    llvm.cond_br %106, ^bb14, ^bb15(%104 : vector<[16]xf32>)
  ^bb14:  // pred: ^bb13
    %107 = llvm.getelementptr %arg8[%99] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %108 = llvm.mul %103, %arg13 overflow<nsw> : i64
    %109 = llvm.getelementptr inbounds %107[%108] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %110 = llvm.load %109 : !llvm.ptr -> f32
    %111 = llvm.insertelement %110, %104[%103 : i64] : vector<[16]xf32>
    llvm.br ^bb15(%111 : vector<[16]xf32>)
  ^bb15(%112: vector<[16]xf32>):  // 2 preds: ^bb13, ^bb14
    %113 = llvm.add %103, %3 : i64
    llvm.br ^bb12(%113, %112 : i64, vector<[16]xf32>)
  ^bb16:  // pred: ^bb12
    %114 = llvm.trunc %65 : i64 to i32
    llvm.br ^bb17(%0 : i64)
  ^bb17(%115: i64):  // 2 preds: ^bb16, ^bb24
    %116 = llvm.icmp "slt" %115, %26 : i64
    llvm.cond_br %116, ^bb18, ^bb25
  ^bb18:  // pred: ^bb17
    %117 = llvm.icmp "slt" %115, %55 : i64
    %118 = llvm.sext %117 : i1 to i32
    %119 = llvm.and %118, %114 : i32
    %120 = llvm.sext %119 : i32 to i64
    %121 = llvm.intr.stepvector : vector<[4]xi32>
    %122 = llvm.intr.smin(%120, %13) : (i64, i64) -> i64
    %123 = llvm.trunc %122 : i64 to i32
    %124 = llvm.insertelement %123, %16[%15 : i32] : vector<[4]xi32>
    %125 = llvm.shufflevector %124, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %126 = llvm.icmp "slt" %121, %125 : vector<[4]xi32>
    %127 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %128 = llvm.mul %115, %arg19 : i64
    %129 = llvm.mul %arg20, %0 : i64
    %130 = llvm.add %128, %129 : i64
    %131 = llvm.getelementptr %127[%130] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %132 = llvm.intr.masked.load %131, %126, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb19(%0 : i64)
  ^bb19(%133: i64):  // 2 preds: ^bb18, ^bb20
    %134 = llvm.icmp "slt" %133, %26 : i64
    llvm.cond_br %134, ^bb20, ^bb21
  ^bb20:  // pred: ^bb19
    %135 = llvm.trunc %133 : i64 to i32
    %136 = llvm.mul %133, %26 : i64
    %137 = llvm.add %136, %2 : i64
    %138 = llvm.getelementptr %50[%137] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %139 = "arm_sme.intr.read.horiz"(%10, %1, %135) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %138, %135) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %140 = llvm.mul %133, %26 : i64
    %141 = llvm.add %140, %0 : i64
    %142 = llvm.getelementptr %50[%141] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %139, %142 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %143 = llvm.add %133, %3 : i64
    llvm.br ^bb19(%143 : i64)
  ^bb21:  // pred: ^bb19
    %144 = llvm.trunc %115 : i64 to i32
    "arm_sme.intr.write.horiz"(%144, %1, %132) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb22(%0 : i64)
  ^bb22(%145: i64):  // 2 preds: ^bb21, ^bb23
    %146 = llvm.icmp "slt" %145, %26 : i64
    llvm.cond_br %146, ^bb23, ^bb24
  ^bb23:  // pred: ^bb22
    %147 = llvm.trunc %145 : i64 to i32
    %148 = llvm.mul %145, %26 : i64
    %149 = llvm.add %148, %2 : i64
    %150 = llvm.getelementptr %50[%149] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %151 = "arm_sme.intr.read.horiz"(%10, %1, %147) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %150, %147) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %152 = llvm.mul %145, %26 : i64
    %153 = llvm.add %152, %0 : i64
    %154 = llvm.getelementptr %50[%153] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %151, %154 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %155 = llvm.add %145, %3 : i64
    llvm.br ^bb22(%155 : i64)
  ^bb24:  // pred: ^bb22
    %156 = llvm.add %115, %3 : i64
    llvm.br ^bb17(%156 : i64)
  ^bb25:  // pred: ^bb17
    %157 = llvm.mul %25, %5 : i64
    %158 = llvm.add %65, %157 : i64
    %159 = llvm.trunc %158 : i64 to i32
    llvm.br ^bb26(%0 : i64)
  ^bb26(%160: i64):  // 2 preds: ^bb25, ^bb33
    %161 = llvm.icmp "slt" %160, %26 : i64
    llvm.cond_br %161, ^bb27, ^bb34
  ^bb27:  // pred: ^bb26
    %162 = llvm.icmp "slt" %160, %55 : i64
    %163 = llvm.sext %162 : i1 to i32
    %164 = llvm.and %163, %159 : i32
    %165 = llvm.sext %164 : i32 to i64
    %166 = llvm.intr.stepvector : vector<[4]xi32>
    %167 = llvm.intr.smin(%165, %13) : (i64, i64) -> i64
    %168 = llvm.trunc %167 : i64 to i32
    %169 = llvm.insertelement %168, %16[%15 : i32] : vector<[4]xi32>
    %170 = llvm.shufflevector %169, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %171 = llvm.icmp "slt" %166, %170 : vector<[4]xi32>
    %172 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %173 = llvm.mul %160, %arg19 : i64
    %174 = llvm.mul %26, %arg20 : i64
    %175 = llvm.add %173, %174 : i64
    %176 = llvm.getelementptr %172[%175] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %177 = llvm.intr.masked.load %176, %171, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb28(%0 : i64)
  ^bb28(%178: i64):  // 2 preds: ^bb27, ^bb29
    %179 = llvm.icmp "slt" %178, %26 : i64
    llvm.cond_br %179, ^bb29, ^bb30
  ^bb29:  // pred: ^bb28
    %180 = llvm.trunc %178 : i64 to i32
    %181 = llvm.mul %178, %26 : i64
    %182 = llvm.add %181, %2 : i64
    %183 = llvm.getelementptr %48[%182] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %184 = "arm_sme.intr.read.horiz"(%10, %1, %180) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %183, %180) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %185 = llvm.mul %178, %26 : i64
    %186 = llvm.add %185, %0 : i64
    %187 = llvm.getelementptr %48[%186] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %184, %187 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %188 = llvm.add %178, %3 : i64
    llvm.br ^bb28(%188 : i64)
  ^bb30:  // pred: ^bb28
    %189 = llvm.trunc %160 : i64 to i32
    "arm_sme.intr.write.horiz"(%189, %1, %177) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb31(%0 : i64)
  ^bb31(%190: i64):  // 2 preds: ^bb30, ^bb32
    %191 = llvm.icmp "slt" %190, %26 : i64
    llvm.cond_br %191, ^bb32, ^bb33
  ^bb32:  // pred: ^bb31
    %192 = llvm.trunc %190 : i64 to i32
    %193 = llvm.mul %190, %26 : i64
    %194 = llvm.add %193, %2 : i64
    %195 = llvm.getelementptr %48[%194] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %196 = "arm_sme.intr.read.horiz"(%10, %1, %192) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %195, %192) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %197 = llvm.mul %190, %26 : i64
    %198 = llvm.add %197, %0 : i64
    %199 = llvm.getelementptr %48[%198] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %196, %199 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %200 = llvm.add %190, %3 : i64
    llvm.br ^bb31(%200 : i64)
  ^bb33:  // pred: ^bb31
    %201 = llvm.add %160, %3 : i64
    llvm.br ^bb26(%201 : i64)
  ^bb34:  // pred: ^bb26
    %202 = llvm.mul %25, %6 : i64
    %203 = llvm.add %65, %202 : i64
    %204 = llvm.mul %25, %7 : i64
    %205 = llvm.trunc %203 : i64 to i32
    llvm.br ^bb35(%0 : i64)
  ^bb35(%206: i64):  // 2 preds: ^bb34, ^bb42
    %207 = llvm.icmp "slt" %206, %26 : i64
    llvm.cond_br %207, ^bb36, ^bb43
  ^bb36:  // pred: ^bb35
    %208 = llvm.icmp "slt" %206, %55 : i64
    %209 = llvm.sext %208 : i1 to i32
    %210 = llvm.and %209, %205 : i32
    %211 = llvm.sext %210 : i32 to i64
    %212 = llvm.intr.stepvector : vector<[4]xi32>
    %213 = llvm.intr.smin(%211, %13) : (i64, i64) -> i64
    %214 = llvm.trunc %213 : i64 to i32
    %215 = llvm.insertelement %214, %16[%15 : i32] : vector<[4]xi32>
    %216 = llvm.shufflevector %215, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %217 = llvm.icmp "slt" %212, %216 : vector<[4]xi32>
    %218 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %219 = llvm.mul %206, %arg19 : i64
    %220 = llvm.mul %204, %arg20 : i64
    %221 = llvm.add %219, %220 : i64
    %222 = llvm.getelementptr %218[%221] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %223 = llvm.intr.masked.load %222, %217, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb37(%0 : i64)
  ^bb37(%224: i64):  // 2 preds: ^bb36, ^bb38
    %225 = llvm.icmp "slt" %224, %26 : i64
    llvm.cond_br %225, ^bb38, ^bb39
  ^bb38:  // pred: ^bb37
    %226 = llvm.trunc %224 : i64 to i32
    %227 = llvm.mul %224, %26 : i64
    %228 = llvm.add %227, %2 : i64
    %229 = llvm.getelementptr %46[%228] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %230 = "arm_sme.intr.read.horiz"(%10, %1, %226) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %229, %226) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %231 = llvm.mul %224, %26 : i64
    %232 = llvm.add %231, %0 : i64
    %233 = llvm.getelementptr %46[%232] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %230, %233 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %234 = llvm.add %224, %3 : i64
    llvm.br ^bb37(%234 : i64)
  ^bb39:  // pred: ^bb37
    %235 = llvm.trunc %206 : i64 to i32
    "arm_sme.intr.write.horiz"(%235, %1, %223) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb40(%0 : i64)
  ^bb40(%236: i64):  // 2 preds: ^bb39, ^bb41
    %237 = llvm.icmp "slt" %236, %26 : i64
    llvm.cond_br %237, ^bb41, ^bb42
  ^bb41:  // pred: ^bb40
    %238 = llvm.trunc %236 : i64 to i32
    %239 = llvm.mul %236, %26 : i64
    %240 = llvm.add %239, %2 : i64
    %241 = llvm.getelementptr %46[%240] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %242 = "arm_sme.intr.read.horiz"(%10, %1, %238) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %241, %238) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %243 = llvm.mul %236, %26 : i64
    %244 = llvm.add %243, %0 : i64
    %245 = llvm.getelementptr %46[%244] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %242, %245 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %246 = llvm.add %236, %3 : i64
    llvm.br ^bb40(%246 : i64)
  ^bb42:  // pred: ^bb40
    %247 = llvm.add %206, %3 : i64
    llvm.br ^bb35(%247 : i64)
  ^bb43:  // pred: ^bb35
    %248 = llvm.mul %25, %8 : i64
    %249 = llvm.add %65, %248 : i64
    %250 = llvm.mul %25, %9 : i64
    %251 = llvm.trunc %249 : i64 to i32
    llvm.br ^bb44(%0 : i64)
  ^bb44(%252: i64):  // 2 preds: ^bb43, ^bb51
    %253 = llvm.icmp "slt" %252, %26 : i64
    llvm.cond_br %253, ^bb45, ^bb52
  ^bb45:  // pred: ^bb44
    %254 = llvm.icmp "slt" %252, %55 : i64
    %255 = llvm.sext %254 : i1 to i32
    %256 = llvm.and %255, %251 : i32
    %257 = llvm.sext %256 : i32 to i64
    %258 = llvm.intr.stepvector : vector<[4]xi32>
    %259 = llvm.intr.smin(%257, %13) : (i64, i64) -> i64
    %260 = llvm.trunc %259 : i64 to i32
    %261 = llvm.insertelement %260, %16[%15 : i32] : vector<[4]xi32>
    %262 = llvm.shufflevector %261, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %263 = llvm.icmp "slt" %258, %262 : vector<[4]xi32>
    %264 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %265 = llvm.mul %252, %arg19 : i64
    %266 = llvm.mul %250, %arg20 : i64
    %267 = llvm.add %265, %266 : i64
    %268 = llvm.getelementptr %264[%267] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %269 = llvm.intr.masked.load %268, %263, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb46(%0 : i64)
  ^bb46(%270: i64):  // 2 preds: ^bb45, ^bb47
    %271 = llvm.icmp "slt" %270, %26 : i64
    llvm.cond_br %271, ^bb47, ^bb48
  ^bb47:  // pred: ^bb46
    %272 = llvm.trunc %270 : i64 to i32
    %273 = llvm.mul %270, %26 : i64
    %274 = llvm.add %273, %2 : i64
    %275 = llvm.getelementptr %44[%274] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %276 = "arm_sme.intr.read.horiz"(%10, %1, %272) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %275, %272) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %277 = llvm.mul %270, %26 : i64
    %278 = llvm.add %277, %0 : i64
    %279 = llvm.getelementptr %44[%278] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %276, %279 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %280 = llvm.add %270, %3 : i64
    llvm.br ^bb46(%280 : i64)
  ^bb48:  // pred: ^bb46
    %281 = llvm.trunc %252 : i64 to i32
    "arm_sme.intr.write.horiz"(%281, %1, %269) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb49(%0 : i64)
  ^bb49(%282: i64):  // 2 preds: ^bb48, ^bb50
    %283 = llvm.icmp "slt" %282, %26 : i64
    llvm.cond_br %283, ^bb50, ^bb51
  ^bb50:  // pred: ^bb49
    %284 = llvm.trunc %282 : i64 to i32
    %285 = llvm.mul %282, %26 : i64
    %286 = llvm.add %285, %2 : i64
    %287 = llvm.getelementptr %44[%286] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %288 = "arm_sme.intr.read.horiz"(%10, %1, %284) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %287, %284) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %289 = llvm.mul %282, %26 : i64
    %290 = llvm.add %289, %0 : i64
    %291 = llvm.getelementptr %44[%290] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %288, %291 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %292 = llvm.add %282, %3 : i64
    llvm.br ^bb49(%292 : i64)
  ^bb51:  // pred: ^bb49
    %293 = llvm.add %252, %3 : i64
    llvm.br ^bb44(%293 : i64)
  ^bb52:  // pred: ^bb44
    %294 = llvm.add %55, %157 : i64
    llvm.br ^bb53(%0 : i64)
  ^bb53(%295: i64):  // 2 preds: ^bb52, ^bb60
    %296 = llvm.icmp "slt" %295, %26 : i64
    llvm.cond_br %296, ^bb54, ^bb61(%0 : i64)
  ^bb54:  // pred: ^bb53
    %297 = llvm.icmp "slt" %295, %294 : i64
    %298 = llvm.sext %297 : i1 to i32
    %299 = llvm.and %298, %114 : i32
    %300 = llvm.sext %299 : i32 to i64
    %301 = llvm.intr.stepvector : vector<[4]xi32>
    %302 = llvm.intr.smin(%300, %13) : (i64, i64) -> i64
    %303 = llvm.trunc %302 : i64 to i32
    %304 = llvm.insertelement %303, %16[%15 : i32] : vector<[4]xi32>
    %305 = llvm.shufflevector %304, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %306 = llvm.icmp "slt" %301, %305 : vector<[4]xi32>
    %307 = llvm.add %26, %295 : i64
    %308 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %309 = llvm.mul %307, %arg19 : i64
    %310 = llvm.mul %arg20, %0 : i64
    %311 = llvm.add %309, %310 : i64
    %312 = llvm.getelementptr %308[%311] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %313 = llvm.intr.masked.load %312, %306, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb55(%0 : i64)
  ^bb55(%314: i64):  // 2 preds: ^bb54, ^bb56
    %315 = llvm.icmp "slt" %314, %26 : i64
    llvm.cond_br %315, ^bb56, ^bb57
  ^bb56:  // pred: ^bb55
    %316 = llvm.trunc %314 : i64 to i32
    %317 = llvm.mul %314, %26 : i64
    %318 = llvm.add %317, %2 : i64
    %319 = llvm.getelementptr %42[%318] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %320 = "arm_sme.intr.read.horiz"(%10, %1, %316) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %319, %316) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %321 = llvm.mul %314, %26 : i64
    %322 = llvm.add %321, %0 : i64
    %323 = llvm.getelementptr %42[%322] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %320, %323 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %324 = llvm.add %314, %3 : i64
    llvm.br ^bb55(%324 : i64)
  ^bb57:  // pred: ^bb55
    %325 = llvm.trunc %295 : i64 to i32
    "arm_sme.intr.write.horiz"(%325, %1, %313) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb58(%0 : i64)
  ^bb58(%326: i64):  // 2 preds: ^bb57, ^bb59
    %327 = llvm.icmp "slt" %326, %26 : i64
    llvm.cond_br %327, ^bb59, ^bb60
  ^bb59:  // pred: ^bb58
    %328 = llvm.trunc %326 : i64 to i32
    %329 = llvm.mul %326, %26 : i64
    %330 = llvm.add %329, %2 : i64
    %331 = llvm.getelementptr %42[%330] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %332 = "arm_sme.intr.read.horiz"(%10, %1, %328) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %331, %328) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %333 = llvm.mul %326, %26 : i64
    %334 = llvm.add %333, %0 : i64
    %335 = llvm.getelementptr %42[%334] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %332, %335 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %336 = llvm.add %326, %3 : i64
    llvm.br ^bb58(%336 : i64)
  ^bb60:  // pred: ^bb58
    %337 = llvm.add %295, %3 : i64
    llvm.br ^bb53(%337 : i64)
  ^bb61(%338: i64):  // 2 preds: ^bb53, ^bb68
    %339 = llvm.icmp "slt" %338, %26 : i64
    llvm.cond_br %339, ^bb62, ^bb69(%0 : i64)
  ^bb62:  // pred: ^bb61
    %340 = llvm.icmp "slt" %338, %294 : i64
    %341 = llvm.sext %340 : i1 to i32
    %342 = llvm.and %341, %159 : i32
    %343 = llvm.sext %342 : i32 to i64
    %344 = llvm.intr.stepvector : vector<[4]xi32>
    %345 = llvm.intr.smin(%343, %13) : (i64, i64) -> i64
    %346 = llvm.trunc %345 : i64 to i32
    %347 = llvm.insertelement %346, %16[%15 : i32] : vector<[4]xi32>
    %348 = llvm.shufflevector %347, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %349 = llvm.icmp "slt" %344, %348 : vector<[4]xi32>
    %350 = llvm.add %26, %338 : i64
    %351 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %352 = llvm.mul %350, %arg19 : i64
    %353 = llvm.mul %26, %arg20 : i64
    %354 = llvm.add %352, %353 : i64
    %355 = llvm.getelementptr %351[%354] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %356 = llvm.intr.masked.load %355, %349, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb63(%0 : i64)
  ^bb63(%357: i64):  // 2 preds: ^bb62, ^bb64
    %358 = llvm.icmp "slt" %357, %26 : i64
    llvm.cond_br %358, ^bb64, ^bb65
  ^bb64:  // pred: ^bb63
    %359 = llvm.trunc %357 : i64 to i32
    %360 = llvm.mul %357, %26 : i64
    %361 = llvm.add %360, %2 : i64
    %362 = llvm.getelementptr %40[%361] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %363 = "arm_sme.intr.read.horiz"(%10, %1, %359) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %362, %359) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %364 = llvm.mul %357, %26 : i64
    %365 = llvm.add %364, %0 : i64
    %366 = llvm.getelementptr %40[%365] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %363, %366 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %367 = llvm.add %357, %3 : i64
    llvm.br ^bb63(%367 : i64)
  ^bb65:  // pred: ^bb63
    %368 = llvm.trunc %338 : i64 to i32
    "arm_sme.intr.write.horiz"(%368, %1, %356) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb66(%0 : i64)
  ^bb66(%369: i64):  // 2 preds: ^bb65, ^bb67
    %370 = llvm.icmp "slt" %369, %26 : i64
    llvm.cond_br %370, ^bb67, ^bb68
  ^bb67:  // pred: ^bb66
    %371 = llvm.trunc %369 : i64 to i32
    %372 = llvm.mul %369, %26 : i64
    %373 = llvm.add %372, %2 : i64
    %374 = llvm.getelementptr %40[%373] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %375 = "arm_sme.intr.read.horiz"(%10, %1, %371) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %374, %371) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %376 = llvm.mul %369, %26 : i64
    %377 = llvm.add %376, %0 : i64
    %378 = llvm.getelementptr %40[%377] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %375, %378 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %379 = llvm.add %369, %3 : i64
    llvm.br ^bb66(%379 : i64)
  ^bb68:  // pred: ^bb66
    %380 = llvm.add %338, %3 : i64
    llvm.br ^bb61(%380 : i64)
  ^bb69(%381: i64):  // 2 preds: ^bb61, ^bb76
    %382 = llvm.icmp "slt" %381, %26 : i64
    llvm.cond_br %382, ^bb70, ^bb77(%0 : i64)
  ^bb70:  // pred: ^bb69
    %383 = llvm.icmp "slt" %381, %294 : i64
    %384 = llvm.sext %383 : i1 to i32
    %385 = llvm.and %384, %205 : i32
    %386 = llvm.sext %385 : i32 to i64
    %387 = llvm.intr.stepvector : vector<[4]xi32>
    %388 = llvm.intr.smin(%386, %13) : (i64, i64) -> i64
    %389 = llvm.trunc %388 : i64 to i32
    %390 = llvm.insertelement %389, %16[%15 : i32] : vector<[4]xi32>
    %391 = llvm.shufflevector %390, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %392 = llvm.icmp "slt" %387, %391 : vector<[4]xi32>
    %393 = llvm.add %26, %381 : i64
    %394 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %395 = llvm.mul %393, %arg19 : i64
    %396 = llvm.mul %204, %arg20 : i64
    %397 = llvm.add %395, %396 : i64
    %398 = llvm.getelementptr %394[%397] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %399 = llvm.intr.masked.load %398, %392, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb71(%0 : i64)
  ^bb71(%400: i64):  // 2 preds: ^bb70, ^bb72
    %401 = llvm.icmp "slt" %400, %26 : i64
    llvm.cond_br %401, ^bb72, ^bb73
  ^bb72:  // pred: ^bb71
    %402 = llvm.trunc %400 : i64 to i32
    %403 = llvm.mul %400, %26 : i64
    %404 = llvm.add %403, %2 : i64
    %405 = llvm.getelementptr %38[%404] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %406 = "arm_sme.intr.read.horiz"(%10, %1, %402) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %405, %402) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %407 = llvm.mul %400, %26 : i64
    %408 = llvm.add %407, %0 : i64
    %409 = llvm.getelementptr %38[%408] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %406, %409 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %410 = llvm.add %400, %3 : i64
    llvm.br ^bb71(%410 : i64)
  ^bb73:  // pred: ^bb71
    %411 = llvm.trunc %381 : i64 to i32
    "arm_sme.intr.write.horiz"(%411, %1, %399) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb74(%0 : i64)
  ^bb74(%412: i64):  // 2 preds: ^bb73, ^bb75
    %413 = llvm.icmp "slt" %412, %26 : i64
    llvm.cond_br %413, ^bb75, ^bb76
  ^bb75:  // pred: ^bb74
    %414 = llvm.trunc %412 : i64 to i32
    %415 = llvm.mul %412, %26 : i64
    %416 = llvm.add %415, %2 : i64
    %417 = llvm.getelementptr %38[%416] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %418 = "arm_sme.intr.read.horiz"(%10, %1, %414) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %417, %414) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %419 = llvm.mul %412, %26 : i64
    %420 = llvm.add %419, %0 : i64
    %421 = llvm.getelementptr %38[%420] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %418, %421 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %422 = llvm.add %412, %3 : i64
    llvm.br ^bb74(%422 : i64)
  ^bb76:  // pred: ^bb74
    %423 = llvm.add %381, %3 : i64
    llvm.br ^bb69(%423 : i64)
  ^bb77(%424: i64):  // 2 preds: ^bb69, ^bb84
    %425 = llvm.icmp "slt" %424, %26 : i64
    llvm.cond_br %425, ^bb78, ^bb85
  ^bb78:  // pred: ^bb77
    %426 = llvm.icmp "slt" %424, %294 : i64
    %427 = llvm.sext %426 : i1 to i32
    %428 = llvm.and %427, %251 : i32
    %429 = llvm.sext %428 : i32 to i64
    %430 = llvm.intr.stepvector : vector<[4]xi32>
    %431 = llvm.intr.smin(%429, %13) : (i64, i64) -> i64
    %432 = llvm.trunc %431 : i64 to i32
    %433 = llvm.insertelement %432, %16[%15 : i32] : vector<[4]xi32>
    %434 = llvm.shufflevector %433, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %435 = llvm.icmp "slt" %430, %434 : vector<[4]xi32>
    %436 = llvm.add %26, %424 : i64
    %437 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %438 = llvm.mul %436, %arg19 : i64
    %439 = llvm.mul %250, %arg20 : i64
    %440 = llvm.add %438, %439 : i64
    %441 = llvm.getelementptr %437[%440] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %442 = llvm.intr.masked.load %441, %435, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb79(%0 : i64)
  ^bb79(%443: i64):  // 2 preds: ^bb78, ^bb80
    %444 = llvm.icmp "slt" %443, %26 : i64
    llvm.cond_br %444, ^bb80, ^bb81
  ^bb80:  // pred: ^bb79
    %445 = llvm.trunc %443 : i64 to i32
    %446 = llvm.mul %443, %26 : i64
    %447 = llvm.add %446, %2 : i64
    %448 = llvm.getelementptr %36[%447] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %449 = "arm_sme.intr.read.horiz"(%10, %1, %445) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %448, %445) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %450 = llvm.mul %443, %26 : i64
    %451 = llvm.add %450, %0 : i64
    %452 = llvm.getelementptr %36[%451] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %449, %452 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %453 = llvm.add %443, %3 : i64
    llvm.br ^bb79(%453 : i64)
  ^bb81:  // pred: ^bb79
    %454 = llvm.trunc %424 : i64 to i32
    "arm_sme.intr.write.horiz"(%454, %1, %442) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb82(%0 : i64)
  ^bb82(%455: i64):  // 2 preds: ^bb81, ^bb83
    %456 = llvm.icmp "slt" %455, %26 : i64
    llvm.cond_br %456, ^bb83, ^bb84
  ^bb83:  // pred: ^bb82
    %457 = llvm.trunc %455 : i64 to i32
    %458 = llvm.mul %455, %26 : i64
    %459 = llvm.add %458, %2 : i64
    %460 = llvm.getelementptr %36[%459] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %461 = "arm_sme.intr.read.horiz"(%10, %1, %457) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %460, %457) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %462 = llvm.mul %455, %26 : i64
    %463 = llvm.add %462, %0 : i64
    %464 = llvm.getelementptr %36[%463] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %461, %464 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %465 = llvm.add %455, %3 : i64
    llvm.br ^bb82(%465 : i64)
  ^bb84:  // pred: ^bb82
    %466 = llvm.add %424, %3 : i64
    llvm.br ^bb77(%466 : i64)
  ^bb85:  // pred: ^bb77
    %467 = llvm.add %55, %202 : i64
    llvm.br ^bb86(%0 : i64)
  ^bb86(%468: i64):  // 2 preds: ^bb85, ^bb93
    %469 = llvm.icmp "slt" %468, %26 : i64
    llvm.cond_br %469, ^bb87, ^bb94(%0 : i64)
  ^bb87:  // pred: ^bb86
    %470 = llvm.icmp "slt" %468, %467 : i64
    %471 = llvm.sext %470 : i1 to i32
    %472 = llvm.and %471, %114 : i32
    %473 = llvm.sext %472 : i32 to i64
    %474 = llvm.intr.stepvector : vector<[4]xi32>
    %475 = llvm.intr.smin(%473, %13) : (i64, i64) -> i64
    %476 = llvm.trunc %475 : i64 to i32
    %477 = llvm.insertelement %476, %16[%15 : i32] : vector<[4]xi32>
    %478 = llvm.shufflevector %477, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %479 = llvm.icmp "slt" %474, %478 : vector<[4]xi32>
    %480 = llvm.add %204, %468 : i64
    %481 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %482 = llvm.mul %480, %arg19 : i64
    %483 = llvm.mul %arg20, %0 : i64
    %484 = llvm.add %482, %483 : i64
    %485 = llvm.getelementptr %481[%484] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %486 = llvm.intr.masked.load %485, %479, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb88(%0 : i64)
  ^bb88(%487: i64):  // 2 preds: ^bb87, ^bb89
    %488 = llvm.icmp "slt" %487, %26 : i64
    llvm.cond_br %488, ^bb89, ^bb90
  ^bb89:  // pred: ^bb88
    %489 = llvm.trunc %487 : i64 to i32
    %490 = llvm.mul %487, %26 : i64
    %491 = llvm.add %490, %2 : i64
    %492 = llvm.getelementptr %34[%491] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %493 = "arm_sme.intr.read.horiz"(%10, %1, %489) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %492, %489) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %494 = llvm.mul %487, %26 : i64
    %495 = llvm.add %494, %0 : i64
    %496 = llvm.getelementptr %34[%495] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %493, %496 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %497 = llvm.add %487, %3 : i64
    llvm.br ^bb88(%497 : i64)
  ^bb90:  // pred: ^bb88
    %498 = llvm.trunc %468 : i64 to i32
    "arm_sme.intr.write.horiz"(%498, %1, %486) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb91(%0 : i64)
  ^bb91(%499: i64):  // 2 preds: ^bb90, ^bb92
    %500 = llvm.icmp "slt" %499, %26 : i64
    llvm.cond_br %500, ^bb92, ^bb93
  ^bb92:  // pred: ^bb91
    %501 = llvm.trunc %499 : i64 to i32
    %502 = llvm.mul %499, %26 : i64
    %503 = llvm.add %502, %2 : i64
    %504 = llvm.getelementptr %34[%503] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %505 = "arm_sme.intr.read.horiz"(%10, %1, %501) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %504, %501) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %506 = llvm.mul %499, %26 : i64
    %507 = llvm.add %506, %0 : i64
    %508 = llvm.getelementptr %34[%507] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %505, %508 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %509 = llvm.add %499, %3 : i64
    llvm.br ^bb91(%509 : i64)
  ^bb93:  // pred: ^bb91
    %510 = llvm.add %468, %3 : i64
    llvm.br ^bb86(%510 : i64)
  ^bb94(%511: i64):  // 2 preds: ^bb86, ^bb101
    %512 = llvm.icmp "slt" %511, %26 : i64
    llvm.cond_br %512, ^bb95, ^bb102(%0 : i64)
  ^bb95:  // pred: ^bb94
    %513 = llvm.icmp "slt" %511, %467 : i64
    %514 = llvm.sext %513 : i1 to i32
    %515 = llvm.and %514, %159 : i32
    %516 = llvm.sext %515 : i32 to i64
    %517 = llvm.intr.stepvector : vector<[4]xi32>
    %518 = llvm.intr.smin(%516, %13) : (i64, i64) -> i64
    %519 = llvm.trunc %518 : i64 to i32
    %520 = llvm.insertelement %519, %16[%15 : i32] : vector<[4]xi32>
    %521 = llvm.shufflevector %520, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %522 = llvm.icmp "slt" %517, %521 : vector<[4]xi32>
    %523 = llvm.add %204, %511 : i64
    %524 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %525 = llvm.mul %523, %arg19 : i64
    %526 = llvm.mul %26, %arg20 : i64
    %527 = llvm.add %525, %526 : i64
    %528 = llvm.getelementptr %524[%527] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %529 = llvm.intr.masked.load %528, %522, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb96(%0 : i64)
  ^bb96(%530: i64):  // 2 preds: ^bb95, ^bb97
    %531 = llvm.icmp "slt" %530, %26 : i64
    llvm.cond_br %531, ^bb97, ^bb98
  ^bb97:  // pred: ^bb96
    %532 = llvm.trunc %530 : i64 to i32
    %533 = llvm.mul %530, %26 : i64
    %534 = llvm.add %533, %2 : i64
    %535 = llvm.getelementptr %32[%534] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %536 = "arm_sme.intr.read.horiz"(%10, %1, %532) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %535, %532) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %537 = llvm.mul %530, %26 : i64
    %538 = llvm.add %537, %0 : i64
    %539 = llvm.getelementptr %32[%538] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %536, %539 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %540 = llvm.add %530, %3 : i64
    llvm.br ^bb96(%540 : i64)
  ^bb98:  // pred: ^bb96
    %541 = llvm.trunc %511 : i64 to i32
    "arm_sme.intr.write.horiz"(%541, %1, %529) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb99(%0 : i64)
  ^bb99(%542: i64):  // 2 preds: ^bb98, ^bb100
    %543 = llvm.icmp "slt" %542, %26 : i64
    llvm.cond_br %543, ^bb100, ^bb101
  ^bb100:  // pred: ^bb99
    %544 = llvm.trunc %542 : i64 to i32
    %545 = llvm.mul %542, %26 : i64
    %546 = llvm.add %545, %2 : i64
    %547 = llvm.getelementptr %32[%546] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %548 = "arm_sme.intr.read.horiz"(%10, %1, %544) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %547, %544) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %549 = llvm.mul %542, %26 : i64
    %550 = llvm.add %549, %0 : i64
    %551 = llvm.getelementptr %32[%550] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %548, %551 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %552 = llvm.add %542, %3 : i64
    llvm.br ^bb99(%552 : i64)
  ^bb101:  // pred: ^bb99
    %553 = llvm.add %511, %3 : i64
    llvm.br ^bb94(%553 : i64)
  ^bb102(%554: i64):  // 2 preds: ^bb94, ^bb109
    %555 = llvm.icmp "slt" %554, %26 : i64
    llvm.cond_br %555, ^bb103, ^bb110(%0 : i64)
  ^bb103:  // pred: ^bb102
    %556 = llvm.icmp "slt" %554, %467 : i64
    %557 = llvm.sext %556 : i1 to i32
    %558 = llvm.and %557, %205 : i32
    %559 = llvm.sext %558 : i32 to i64
    %560 = llvm.intr.stepvector : vector<[4]xi32>
    %561 = llvm.intr.smin(%559, %13) : (i64, i64) -> i64
    %562 = llvm.trunc %561 : i64 to i32
    %563 = llvm.insertelement %562, %16[%15 : i32] : vector<[4]xi32>
    %564 = llvm.shufflevector %563, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %565 = llvm.icmp "slt" %560, %564 : vector<[4]xi32>
    %566 = llvm.add %204, %554 : i64
    %567 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %568 = llvm.mul %566, %arg19 : i64
    %569 = llvm.mul %204, %arg20 : i64
    %570 = llvm.add %568, %569 : i64
    %571 = llvm.getelementptr %567[%570] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %572 = llvm.intr.masked.load %571, %565, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb104(%0 : i64)
  ^bb104(%573: i64):  // 2 preds: ^bb103, ^bb105
    %574 = llvm.icmp "slt" %573, %26 : i64
    llvm.cond_br %574, ^bb105, ^bb106
  ^bb105:  // pred: ^bb104
    %575 = llvm.trunc %573 : i64 to i32
    %576 = llvm.mul %573, %26 : i64
    %577 = llvm.add %576, %2 : i64
    %578 = llvm.getelementptr %30[%577] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %579 = "arm_sme.intr.read.horiz"(%10, %1, %575) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %578, %575) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %580 = llvm.mul %573, %26 : i64
    %581 = llvm.add %580, %0 : i64
    %582 = llvm.getelementptr %30[%581] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %579, %582 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %583 = llvm.add %573, %3 : i64
    llvm.br ^bb104(%583 : i64)
  ^bb106:  // pred: ^bb104
    %584 = llvm.trunc %554 : i64 to i32
    "arm_sme.intr.write.horiz"(%584, %1, %572) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb107(%0 : i64)
  ^bb107(%585: i64):  // 2 preds: ^bb106, ^bb108
    %586 = llvm.icmp "slt" %585, %26 : i64
    llvm.cond_br %586, ^bb108, ^bb109
  ^bb108:  // pred: ^bb107
    %587 = llvm.trunc %585 : i64 to i32
    %588 = llvm.mul %585, %26 : i64
    %589 = llvm.add %588, %2 : i64
    %590 = llvm.getelementptr %30[%589] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %591 = "arm_sme.intr.read.horiz"(%10, %1, %587) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %590, %587) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %592 = llvm.mul %585, %26 : i64
    %593 = llvm.add %592, %0 : i64
    %594 = llvm.getelementptr %30[%593] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %591, %594 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %595 = llvm.add %585, %3 : i64
    llvm.br ^bb107(%595 : i64)
  ^bb109:  // pred: ^bb107
    %596 = llvm.add %554, %3 : i64
    llvm.br ^bb102(%596 : i64)
  ^bb110(%597: i64):  // 2 preds: ^bb102, ^bb117
    %598 = llvm.icmp "slt" %597, %26 : i64
    llvm.cond_br %598, ^bb111, ^bb118
  ^bb111:  // pred: ^bb110
    %599 = llvm.icmp "slt" %597, %467 : i64
    %600 = llvm.sext %599 : i1 to i32
    %601 = llvm.and %600, %251 : i32
    %602 = llvm.sext %601 : i32 to i64
    %603 = llvm.intr.stepvector : vector<[4]xi32>
    %604 = llvm.intr.smin(%602, %13) : (i64, i64) -> i64
    %605 = llvm.trunc %604 : i64 to i32
    %606 = llvm.insertelement %605, %16[%15 : i32] : vector<[4]xi32>
    %607 = llvm.shufflevector %606, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %608 = llvm.icmp "slt" %603, %607 : vector<[4]xi32>
    %609 = llvm.add %204, %597 : i64
    %610 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %611 = llvm.mul %609, %arg19 : i64
    %612 = llvm.mul %250, %arg20 : i64
    %613 = llvm.add %611, %612 : i64
    %614 = llvm.getelementptr %610[%613] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %615 = llvm.intr.masked.load %614, %608, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    llvm.br ^bb112(%0 : i64)
  ^bb112(%616: i64):  // 2 preds: ^bb111, ^bb113
    %617 = llvm.icmp "slt" %616, %26 : i64
    llvm.cond_br %617, ^bb113, ^bb114
  ^bb113:  // pred: ^bb112
    %618 = llvm.trunc %616 : i64 to i32
    %619 = llvm.mul %616, %26 : i64
    %620 = llvm.add %619, %2 : i64
    %621 = llvm.getelementptr %28[%620] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %622 = "arm_sme.intr.read.horiz"(%10, %1, %618) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %621, %618) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %623 = llvm.mul %616, %26 : i64
    %624 = llvm.add %623, %0 : i64
    %625 = llvm.getelementptr %28[%624] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %622, %625 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %626 = llvm.add %616, %3 : i64
    llvm.br ^bb112(%626 : i64)
  ^bb114:  // pred: ^bb112
    %627 = llvm.trunc %597 : i64 to i32
    "arm_sme.intr.write.horiz"(%627, %1, %615) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    llvm.br ^bb115(%0 : i64)
  ^bb115(%628: i64):  // 2 preds: ^bb114, ^bb116
    %629 = llvm.icmp "slt" %628, %26 : i64
    llvm.cond_br %629, ^bb116, ^bb117
  ^bb116:  // pred: ^bb115
    %630 = llvm.trunc %628 : i64 to i32
    %631 = llvm.mul %628, %26 : i64
    %632 = llvm.add %631, %2 : i64
    %633 = llvm.getelementptr %28[%632] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %634 = "arm_sme.intr.read.horiz"(%10, %1, %630) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %633, %630) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %635 = llvm.mul %628, %26 : i64
    %636 = llvm.add %635, %0 : i64
    %637 = llvm.getelementptr %28[%636] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %634, %637 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %638 = llvm.add %628, %3 : i64
    llvm.br ^bb115(%638 : i64)
  ^bb117:  // pred: ^bb115
    %639 = llvm.add %597, %3 : i64
    llvm.br ^bb110(%639 : i64)
  ^bb118:  // pred: ^bb110
    %640 = llvm.add %55, %248 : i64
    llvm.br ^bb119(%0 : i64)
  ^bb119(%641: i64):  // 2 preds: ^bb118, ^bb120
    %642 = llvm.icmp "slt" %641, %26 : i64
    llvm.cond_br %642, ^bb120, ^bb121(%0 : i64)
  ^bb120:  // pred: ^bb119
    %643 = llvm.icmp "slt" %641, %640 : i64
    %644 = llvm.sext %643 : i1 to i32
    %645 = llvm.and %644, %114 : i32
    %646 = llvm.sext %645 : i32 to i64
    %647 = llvm.intr.stepvector : vector<[4]xi32>
    %648 = llvm.intr.smin(%646, %13) : (i64, i64) -> i64
    %649 = llvm.trunc %648 : i64 to i32
    %650 = llvm.insertelement %649, %16[%15 : i32] : vector<[4]xi32>
    %651 = llvm.shufflevector %650, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %652 = llvm.icmp "slt" %647, %651 : vector<[4]xi32>
    %653 = llvm.add %250, %641 : i64
    %654 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %655 = llvm.mul %653, %arg19 : i64
    %656 = llvm.mul %arg20, %0 : i64
    %657 = llvm.add %655, %656 : i64
    %658 = llvm.getelementptr %654[%657] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %659 = llvm.intr.masked.load %658, %652, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    %660 = llvm.trunc %641 : i64 to i32
    "arm_sme.intr.write.horiz"(%660, %1, %659) <{tile_id = 0 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %661 = llvm.add %641, %3 : i64
    llvm.br ^bb119(%661 : i64)
  ^bb121(%662: i64):  // 2 preds: ^bb119, ^bb122
    %663 = llvm.icmp "slt" %662, %26 : i64
    llvm.cond_br %663, ^bb122, ^bb123(%0 : i64)
  ^bb122:  // pred: ^bb121
    %664 = llvm.icmp "slt" %662, %640 : i64
    %665 = llvm.sext %664 : i1 to i32
    %666 = llvm.and %665, %159 : i32
    %667 = llvm.sext %666 : i32 to i64
    %668 = llvm.intr.stepvector : vector<[4]xi32>
    %669 = llvm.intr.smin(%667, %13) : (i64, i64) -> i64
    %670 = llvm.trunc %669 : i64 to i32
    %671 = llvm.insertelement %670, %16[%15 : i32] : vector<[4]xi32>
    %672 = llvm.shufflevector %671, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %673 = llvm.icmp "slt" %668, %672 : vector<[4]xi32>
    %674 = llvm.add %250, %662 : i64
    %675 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %676 = llvm.mul %674, %arg19 : i64
    %677 = llvm.mul %26, %arg20 : i64
    %678 = llvm.add %676, %677 : i64
    %679 = llvm.getelementptr %675[%678] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %680 = llvm.intr.masked.load %679, %673, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    %681 = llvm.trunc %662 : i64 to i32
    "arm_sme.intr.write.horiz"(%681, %1, %680) <{tile_id = 1 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %682 = llvm.add %662, %3 : i64
    llvm.br ^bb121(%682 : i64)
  ^bb123(%683: i64):  // 2 preds: ^bb121, ^bb124
    %684 = llvm.icmp "slt" %683, %26 : i64
    llvm.cond_br %684, ^bb124, ^bb125(%0 : i64)
  ^bb124:  // pred: ^bb123
    %685 = llvm.icmp "slt" %683, %640 : i64
    %686 = llvm.sext %685 : i1 to i32
    %687 = llvm.and %686, %205 : i32
    %688 = llvm.sext %687 : i32 to i64
    %689 = llvm.intr.stepvector : vector<[4]xi32>
    %690 = llvm.intr.smin(%688, %13) : (i64, i64) -> i64
    %691 = llvm.trunc %690 : i64 to i32
    %692 = llvm.insertelement %691, %16[%15 : i32] : vector<[4]xi32>
    %693 = llvm.shufflevector %692, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %694 = llvm.icmp "slt" %689, %693 : vector<[4]xi32>
    %695 = llvm.add %250, %683 : i64
    %696 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %697 = llvm.mul %695, %arg19 : i64
    %698 = llvm.mul %204, %arg20 : i64
    %699 = llvm.add %697, %698 : i64
    %700 = llvm.getelementptr %696[%699] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %701 = llvm.intr.masked.load %700, %694, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    %702 = llvm.trunc %683 : i64 to i32
    "arm_sme.intr.write.horiz"(%702, %1, %701) <{tile_id = 2 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %703 = llvm.add %683, %3 : i64
    llvm.br ^bb123(%703 : i64)
  ^bb125(%704: i64):  // 2 preds: ^bb123, ^bb126
    %705 = llvm.icmp "slt" %704, %26 : i64
    llvm.cond_br %705, ^bb126, ^bb127
  ^bb126:  // pred: ^bb125
    %706 = llvm.icmp "slt" %704, %640 : i64
    %707 = llvm.sext %706 : i1 to i32
    %708 = llvm.and %707, %251 : i32
    %709 = llvm.sext %708 : i32 to i64
    %710 = llvm.intr.stepvector : vector<[4]xi32>
    %711 = llvm.intr.smin(%709, %13) : (i64, i64) -> i64
    %712 = llvm.trunc %711 : i64 to i32
    %713 = llvm.insertelement %712, %16[%15 : i32] : vector<[4]xi32>
    %714 = llvm.shufflevector %713, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %715 = llvm.icmp "slt" %710, %714 : vector<[4]xi32>
    %716 = llvm.add %250, %704 : i64
    %717 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %718 = llvm.mul %716, %arg19 : i64
    %719 = llvm.mul %250, %arg20 : i64
    %720 = llvm.add %718, %719 : i64
    %721 = llvm.getelementptr %717[%720] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %722 = llvm.intr.masked.load %721, %715, %10 {alignment = 4 : i32} : (!llvm.ptr, vector<[4]xi1>, vector<[4]xf32>) -> vector<[4]xf32>
    %723 = llvm.trunc %704 : i64 to i32
    "arm_sme.intr.write.horiz"(%723, %1, %722) <{tile_id = 3 : i32}> : (i32, vector<[4]xi1>, vector<[4]xf32>) -> ()
    %724 = llvm.add %704, %3 : i64
    llvm.br ^bb125(%724 : i64)
  ^bb127:  // pred: ^bb125
    %725 = llvm.intr.vector.extract %86[0] : vector<[4]xf32> from vector<[16]xf32>
    %726 = llvm.intr.vector.extract %104[0] : vector<[4]xf32> from vector<[16]xf32>
    %727 = llvm.intr.stepvector : vector<[4]xi32>
    %728 = llvm.intr.smin(%55, %13) : (i64, i64) -> i64
    %729 = llvm.trunc %728 : i64 to i32
    %730 = llvm.insertelement %729, %16[%15 : i32] : vector<[4]xi32>
    %731 = llvm.shufflevector %730, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %732 = llvm.icmp "slt" %727, %731 : vector<[4]xi32>
    %733 = llvm.intr.stepvector : vector<[4]xi32>
    %734 = llvm.intr.smin(%65, %13) : (i64, i64) -> i64
    %735 = llvm.trunc %734 : i64 to i32
    %736 = llvm.insertelement %735, %16[%15 : i32] : vector<[4]xi32>
    %737 = llvm.shufflevector %736, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %738 = llvm.icmp "slt" %733, %737 : vector<[4]xi32>
    llvm.br ^bb128(%0 : i64)
  ^bb128(%739: i64):  // 2 preds: ^bb127, ^bb129
    %740 = llvm.icmp "slt" %739, %26 : i64
    llvm.cond_br %740, ^bb129, ^bb130
  ^bb129:  // pred: ^bb128
    %741 = llvm.trunc %739 : i64 to i32
    %742 = llvm.mul %739, %26 : i64
    %743 = llvm.add %742, %2 : i64
    %744 = llvm.getelementptr %50[%743] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %745 = "arm_sme.intr.read.horiz"(%10, %1, %741) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %744, %741) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %746 = llvm.mul %739, %26 : i64
    %747 = llvm.add %746, %0 : i64
    %748 = llvm.getelementptr %50[%747] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %745, %748 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %749 = llvm.add %739, %3 : i64
    llvm.br ^bb128(%749 : i64)
  ^bb130:  // pred: ^bb128
    "arm_sme.intr.mopa"(%732, %738, %725, %726) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb131(%0 : i64)
  ^bb131(%750: i64):  // 2 preds: ^bb130, ^bb132
    %751 = llvm.icmp "slt" %750, %26 : i64
    llvm.cond_br %751, ^bb132, ^bb133
  ^bb132:  // pred: ^bb131
    %752 = llvm.trunc %750 : i64 to i32
    %753 = llvm.mul %750, %26 : i64
    %754 = llvm.add %753, %2 : i64
    %755 = llvm.getelementptr %50[%754] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %756 = "arm_sme.intr.read.horiz"(%10, %1, %752) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %755, %752) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %757 = llvm.mul %750, %26 : i64
    %758 = llvm.add %757, %0 : i64
    %759 = llvm.getelementptr %50[%758] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %756, %759 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %760 = llvm.add %750, %3 : i64
    llvm.br ^bb131(%760 : i64)
  ^bb133:  // pred: ^bb131
    %761 = llvm.intr.vector.extract %104[4] : vector<[4]xf32> from vector<[16]xf32>
    %762 = llvm.intr.stepvector : vector<[4]xi32>
    %763 = llvm.intr.smin(%158, %13) : (i64, i64) -> i64
    %764 = llvm.trunc %763 : i64 to i32
    %765 = llvm.insertelement %764, %16[%15 : i32] : vector<[4]xi32>
    %766 = llvm.shufflevector %765, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %767 = llvm.icmp "slt" %762, %766 : vector<[4]xi32>
    llvm.br ^bb134(%0 : i64)
  ^bb134(%768: i64):  // 2 preds: ^bb133, ^bb135
    %769 = llvm.icmp "slt" %768, %26 : i64
    llvm.cond_br %769, ^bb135, ^bb136
  ^bb135:  // pred: ^bb134
    %770 = llvm.trunc %768 : i64 to i32
    %771 = llvm.mul %768, %26 : i64
    %772 = llvm.add %771, %2 : i64
    %773 = llvm.getelementptr %48[%772] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %774 = "arm_sme.intr.read.horiz"(%10, %1, %770) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %773, %770) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %775 = llvm.mul %768, %26 : i64
    %776 = llvm.add %775, %0 : i64
    %777 = llvm.getelementptr %48[%776] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %774, %777 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %778 = llvm.add %768, %3 : i64
    llvm.br ^bb134(%778 : i64)
  ^bb136:  // pred: ^bb134
    "arm_sme.intr.mopa"(%732, %767, %725, %761) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb137(%0 : i64)
  ^bb137(%779: i64):  // 2 preds: ^bb136, ^bb138
    %780 = llvm.icmp "slt" %779, %26 : i64
    llvm.cond_br %780, ^bb138, ^bb139
  ^bb138:  // pred: ^bb137
    %781 = llvm.trunc %779 : i64 to i32
    %782 = llvm.mul %779, %26 : i64
    %783 = llvm.add %782, %2 : i64
    %784 = llvm.getelementptr %48[%783] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %785 = "arm_sme.intr.read.horiz"(%10, %1, %781) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %784, %781) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %786 = llvm.mul %779, %26 : i64
    %787 = llvm.add %786, %0 : i64
    %788 = llvm.getelementptr %48[%787] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %785, %788 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %789 = llvm.add %779, %3 : i64
    llvm.br ^bb137(%789 : i64)
  ^bb139:  // pred: ^bb137
    %790 = llvm.intr.vector.extract %104[8] : vector<[4]xf32> from vector<[16]xf32>
    %791 = llvm.intr.stepvector : vector<[4]xi32>
    %792 = llvm.intr.smin(%203, %13) : (i64, i64) -> i64
    %793 = llvm.trunc %792 : i64 to i32
    %794 = llvm.insertelement %793, %16[%15 : i32] : vector<[4]xi32>
    %795 = llvm.shufflevector %794, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %796 = llvm.icmp "slt" %791, %795 : vector<[4]xi32>
    llvm.br ^bb140(%0 : i64)
  ^bb140(%797: i64):  // 2 preds: ^bb139, ^bb141
    %798 = llvm.icmp "slt" %797, %26 : i64
    llvm.cond_br %798, ^bb141, ^bb142
  ^bb141:  // pred: ^bb140
    %799 = llvm.trunc %797 : i64 to i32
    %800 = llvm.mul %797, %26 : i64
    %801 = llvm.add %800, %2 : i64
    %802 = llvm.getelementptr %46[%801] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %803 = "arm_sme.intr.read.horiz"(%10, %1, %799) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %802, %799) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %804 = llvm.mul %797, %26 : i64
    %805 = llvm.add %804, %0 : i64
    %806 = llvm.getelementptr %46[%805] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %803, %806 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %807 = llvm.add %797, %3 : i64
    llvm.br ^bb140(%807 : i64)
  ^bb142:  // pred: ^bb140
    "arm_sme.intr.mopa"(%732, %796, %725, %790) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb143(%0 : i64)
  ^bb143(%808: i64):  // 2 preds: ^bb142, ^bb144
    %809 = llvm.icmp "slt" %808, %26 : i64
    llvm.cond_br %809, ^bb144, ^bb145
  ^bb144:  // pred: ^bb143
    %810 = llvm.trunc %808 : i64 to i32
    %811 = llvm.mul %808, %26 : i64
    %812 = llvm.add %811, %2 : i64
    %813 = llvm.getelementptr %46[%812] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %814 = "arm_sme.intr.read.horiz"(%10, %1, %810) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %813, %810) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %815 = llvm.mul %808, %26 : i64
    %816 = llvm.add %815, %0 : i64
    %817 = llvm.getelementptr %46[%816] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %814, %817 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %818 = llvm.add %808, %3 : i64
    llvm.br ^bb143(%818 : i64)
  ^bb145:  // pred: ^bb143
    %819 = llvm.intr.vector.extract %104[12] : vector<[4]xf32> from vector<[16]xf32>
    %820 = llvm.intr.stepvector : vector<[4]xi32>
    %821 = llvm.intr.smin(%249, %13) : (i64, i64) -> i64
    %822 = llvm.trunc %821 : i64 to i32
    %823 = llvm.insertelement %822, %16[%15 : i32] : vector<[4]xi32>
    %824 = llvm.shufflevector %823, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %825 = llvm.icmp "slt" %820, %824 : vector<[4]xi32>
    llvm.br ^bb146(%0 : i64)
  ^bb146(%826: i64):  // 2 preds: ^bb145, ^bb147
    %827 = llvm.icmp "slt" %826, %26 : i64
    llvm.cond_br %827, ^bb147, ^bb148
  ^bb147:  // pred: ^bb146
    %828 = llvm.trunc %826 : i64 to i32
    %829 = llvm.mul %826, %26 : i64
    %830 = llvm.add %829, %2 : i64
    %831 = llvm.getelementptr %44[%830] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %832 = "arm_sme.intr.read.horiz"(%10, %1, %828) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %831, %828) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %833 = llvm.mul %826, %26 : i64
    %834 = llvm.add %833, %0 : i64
    %835 = llvm.getelementptr %44[%834] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %832, %835 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %836 = llvm.add %826, %3 : i64
    llvm.br ^bb146(%836 : i64)
  ^bb148:  // pred: ^bb146
    "arm_sme.intr.mopa"(%732, %825, %725, %819) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb149(%0 : i64)
  ^bb149(%837: i64):  // 2 preds: ^bb148, ^bb150
    %838 = llvm.icmp "slt" %837, %26 : i64
    llvm.cond_br %838, ^bb150, ^bb151
  ^bb150:  // pred: ^bb149
    %839 = llvm.trunc %837 : i64 to i32
    %840 = llvm.mul %837, %26 : i64
    %841 = llvm.add %840, %2 : i64
    %842 = llvm.getelementptr %44[%841] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %843 = "arm_sme.intr.read.horiz"(%10, %1, %839) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %842, %839) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %844 = llvm.mul %837, %26 : i64
    %845 = llvm.add %844, %0 : i64
    %846 = llvm.getelementptr %44[%845] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %843, %846 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %847 = llvm.add %837, %3 : i64
    llvm.br ^bb149(%847 : i64)
  ^bb151:  // pred: ^bb149
    %848 = llvm.intr.vector.extract %86[4] : vector<[4]xf32> from vector<[16]xf32>
    %849 = llvm.intr.stepvector : vector<[4]xi32>
    %850 = llvm.intr.smin(%294, %13) : (i64, i64) -> i64
    %851 = llvm.trunc %850 : i64 to i32
    %852 = llvm.insertelement %851, %16[%15 : i32] : vector<[4]xi32>
    %853 = llvm.shufflevector %852, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %854 = llvm.icmp "slt" %849, %853 : vector<[4]xi32>
    llvm.br ^bb152(%0 : i64)
  ^bb152(%855: i64):  // 2 preds: ^bb151, ^bb153
    %856 = llvm.icmp "slt" %855, %26 : i64
    llvm.cond_br %856, ^bb153, ^bb154
  ^bb153:  // pred: ^bb152
    %857 = llvm.trunc %855 : i64 to i32
    %858 = llvm.mul %855, %26 : i64
    %859 = llvm.add %858, %2 : i64
    %860 = llvm.getelementptr %42[%859] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %861 = "arm_sme.intr.read.horiz"(%10, %1, %857) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %860, %857) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %862 = llvm.mul %855, %26 : i64
    %863 = llvm.add %862, %0 : i64
    %864 = llvm.getelementptr %42[%863] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %861, %864 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %865 = llvm.add %855, %3 : i64
    llvm.br ^bb152(%865 : i64)
  ^bb154:  // pred: ^bb152
    "arm_sme.intr.mopa"(%854, %738, %848, %726) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb155(%0 : i64)
  ^bb155(%866: i64):  // 2 preds: ^bb154, ^bb156
    %867 = llvm.icmp "slt" %866, %26 : i64
    llvm.cond_br %867, ^bb156, ^bb157(%0 : i64)
  ^bb156:  // pred: ^bb155
    %868 = llvm.trunc %866 : i64 to i32
    %869 = llvm.mul %866, %26 : i64
    %870 = llvm.add %869, %2 : i64
    %871 = llvm.getelementptr %42[%870] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %872 = "arm_sme.intr.read.horiz"(%10, %1, %868) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %871, %868) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %873 = llvm.mul %866, %26 : i64
    %874 = llvm.add %873, %0 : i64
    %875 = llvm.getelementptr %42[%874] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %872, %875 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %876 = llvm.add %866, %3 : i64
    llvm.br ^bb155(%876 : i64)
  ^bb157(%877: i64):  // 2 preds: ^bb155, ^bb158
    %878 = llvm.icmp "slt" %877, %26 : i64
    llvm.cond_br %878, ^bb158, ^bb159
  ^bb158:  // pred: ^bb157
    %879 = llvm.trunc %877 : i64 to i32
    %880 = llvm.mul %877, %26 : i64
    %881 = llvm.add %880, %2 : i64
    %882 = llvm.getelementptr %40[%881] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %883 = "arm_sme.intr.read.horiz"(%10, %1, %879) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %882, %879) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %884 = llvm.mul %877, %26 : i64
    %885 = llvm.add %884, %0 : i64
    %886 = llvm.getelementptr %40[%885] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %883, %886 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %887 = llvm.add %877, %3 : i64
    llvm.br ^bb157(%887 : i64)
  ^bb159:  // pred: ^bb157
    "arm_sme.intr.mopa"(%854, %767, %848, %761) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb160(%0 : i64)
  ^bb160(%888: i64):  // 2 preds: ^bb159, ^bb161
    %889 = llvm.icmp "slt" %888, %26 : i64
    llvm.cond_br %889, ^bb161, ^bb162(%0 : i64)
  ^bb161:  // pred: ^bb160
    %890 = llvm.trunc %888 : i64 to i32
    %891 = llvm.mul %888, %26 : i64
    %892 = llvm.add %891, %2 : i64
    %893 = llvm.getelementptr %40[%892] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %894 = "arm_sme.intr.read.horiz"(%10, %1, %890) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %893, %890) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %895 = llvm.mul %888, %26 : i64
    %896 = llvm.add %895, %0 : i64
    %897 = llvm.getelementptr %40[%896] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %894, %897 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %898 = llvm.add %888, %3 : i64
    llvm.br ^bb160(%898 : i64)
  ^bb162(%899: i64):  // 2 preds: ^bb160, ^bb163
    %900 = llvm.icmp "slt" %899, %26 : i64
    llvm.cond_br %900, ^bb163, ^bb164
  ^bb163:  // pred: ^bb162
    %901 = llvm.trunc %899 : i64 to i32
    %902 = llvm.mul %899, %26 : i64
    %903 = llvm.add %902, %2 : i64
    %904 = llvm.getelementptr %38[%903] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %905 = "arm_sme.intr.read.horiz"(%10, %1, %901) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %904, %901) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %906 = llvm.mul %899, %26 : i64
    %907 = llvm.add %906, %0 : i64
    %908 = llvm.getelementptr %38[%907] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %905, %908 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %909 = llvm.add %899, %3 : i64
    llvm.br ^bb162(%909 : i64)
  ^bb164:  // pred: ^bb162
    "arm_sme.intr.mopa"(%854, %796, %848, %790) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb165(%0 : i64)
  ^bb165(%910: i64):  // 2 preds: ^bb164, ^bb166
    %911 = llvm.icmp "slt" %910, %26 : i64
    llvm.cond_br %911, ^bb166, ^bb167(%0 : i64)
  ^bb166:  // pred: ^bb165
    %912 = llvm.trunc %910 : i64 to i32
    %913 = llvm.mul %910, %26 : i64
    %914 = llvm.add %913, %2 : i64
    %915 = llvm.getelementptr %38[%914] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %916 = "arm_sme.intr.read.horiz"(%10, %1, %912) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %915, %912) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %917 = llvm.mul %910, %26 : i64
    %918 = llvm.add %917, %0 : i64
    %919 = llvm.getelementptr %38[%918] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %916, %919 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %920 = llvm.add %910, %3 : i64
    llvm.br ^bb165(%920 : i64)
  ^bb167(%921: i64):  // 2 preds: ^bb165, ^bb168
    %922 = llvm.icmp "slt" %921, %26 : i64
    llvm.cond_br %922, ^bb168, ^bb169
  ^bb168:  // pred: ^bb167
    %923 = llvm.trunc %921 : i64 to i32
    %924 = llvm.mul %921, %26 : i64
    %925 = llvm.add %924, %2 : i64
    %926 = llvm.getelementptr %36[%925] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %927 = "arm_sme.intr.read.horiz"(%10, %1, %923) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %926, %923) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %928 = llvm.mul %921, %26 : i64
    %929 = llvm.add %928, %0 : i64
    %930 = llvm.getelementptr %36[%929] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %927, %930 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %931 = llvm.add %921, %3 : i64
    llvm.br ^bb167(%931 : i64)
  ^bb169:  // pred: ^bb167
    "arm_sme.intr.mopa"(%854, %825, %848, %819) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb170(%0 : i64)
  ^bb170(%932: i64):  // 2 preds: ^bb169, ^bb171
    %933 = llvm.icmp "slt" %932, %26 : i64
    llvm.cond_br %933, ^bb171, ^bb172
  ^bb171:  // pred: ^bb170
    %934 = llvm.trunc %932 : i64 to i32
    %935 = llvm.mul %932, %26 : i64
    %936 = llvm.add %935, %2 : i64
    %937 = llvm.getelementptr %36[%936] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %938 = "arm_sme.intr.read.horiz"(%10, %1, %934) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %937, %934) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %939 = llvm.mul %932, %26 : i64
    %940 = llvm.add %939, %0 : i64
    %941 = llvm.getelementptr %36[%940] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %938, %941 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %942 = llvm.add %932, %3 : i64
    llvm.br ^bb170(%942 : i64)
  ^bb172:  // pred: ^bb170
    %943 = llvm.intr.vector.extract %86[8] : vector<[4]xf32> from vector<[16]xf32>
    %944 = llvm.intr.stepvector : vector<[4]xi32>
    %945 = llvm.intr.smin(%467, %13) : (i64, i64) -> i64
    %946 = llvm.trunc %945 : i64 to i32
    %947 = llvm.insertelement %946, %16[%15 : i32] : vector<[4]xi32>
    %948 = llvm.shufflevector %947, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %949 = llvm.icmp "slt" %944, %948 : vector<[4]xi32>
    llvm.br ^bb173(%0 : i64)
  ^bb173(%950: i64):  // 2 preds: ^bb172, ^bb174
    %951 = llvm.icmp "slt" %950, %26 : i64
    llvm.cond_br %951, ^bb174, ^bb175
  ^bb174:  // pred: ^bb173
    %952 = llvm.trunc %950 : i64 to i32
    %953 = llvm.mul %950, %26 : i64
    %954 = llvm.add %953, %2 : i64
    %955 = llvm.getelementptr %34[%954] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %956 = "arm_sme.intr.read.horiz"(%10, %1, %952) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %955, %952) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %957 = llvm.mul %950, %26 : i64
    %958 = llvm.add %957, %0 : i64
    %959 = llvm.getelementptr %34[%958] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %956, %959 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %960 = llvm.add %950, %3 : i64
    llvm.br ^bb173(%960 : i64)
  ^bb175:  // pred: ^bb173
    "arm_sme.intr.mopa"(%949, %738, %943, %726) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb176(%0 : i64)
  ^bb176(%961: i64):  // 2 preds: ^bb175, ^bb177
    %962 = llvm.icmp "slt" %961, %26 : i64
    llvm.cond_br %962, ^bb177, ^bb178(%0 : i64)
  ^bb177:  // pred: ^bb176
    %963 = llvm.trunc %961 : i64 to i32
    %964 = llvm.mul %961, %26 : i64
    %965 = llvm.add %964, %2 : i64
    %966 = llvm.getelementptr %34[%965] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %967 = "arm_sme.intr.read.horiz"(%10, %1, %963) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %966, %963) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %968 = llvm.mul %961, %26 : i64
    %969 = llvm.add %968, %0 : i64
    %970 = llvm.getelementptr %34[%969] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %967, %970 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %971 = llvm.add %961, %3 : i64
    llvm.br ^bb176(%971 : i64)
  ^bb178(%972: i64):  // 2 preds: ^bb176, ^bb179
    %973 = llvm.icmp "slt" %972, %26 : i64
    llvm.cond_br %973, ^bb179, ^bb180
  ^bb179:  // pred: ^bb178
    %974 = llvm.trunc %972 : i64 to i32
    %975 = llvm.mul %972, %26 : i64
    %976 = llvm.add %975, %2 : i64
    %977 = llvm.getelementptr %32[%976] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %978 = "arm_sme.intr.read.horiz"(%10, %1, %974) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %977, %974) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %979 = llvm.mul %972, %26 : i64
    %980 = llvm.add %979, %0 : i64
    %981 = llvm.getelementptr %32[%980] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %978, %981 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %982 = llvm.add %972, %3 : i64
    llvm.br ^bb178(%982 : i64)
  ^bb180:  // pred: ^bb178
    "arm_sme.intr.mopa"(%949, %767, %943, %761) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb181(%0 : i64)
  ^bb181(%983: i64):  // 2 preds: ^bb180, ^bb182
    %984 = llvm.icmp "slt" %983, %26 : i64
    llvm.cond_br %984, ^bb182, ^bb183(%0 : i64)
  ^bb182:  // pred: ^bb181
    %985 = llvm.trunc %983 : i64 to i32
    %986 = llvm.mul %983, %26 : i64
    %987 = llvm.add %986, %2 : i64
    %988 = llvm.getelementptr %32[%987] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %989 = "arm_sme.intr.read.horiz"(%10, %1, %985) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %988, %985) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %990 = llvm.mul %983, %26 : i64
    %991 = llvm.add %990, %0 : i64
    %992 = llvm.getelementptr %32[%991] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %989, %992 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %993 = llvm.add %983, %3 : i64
    llvm.br ^bb181(%993 : i64)
  ^bb183(%994: i64):  // 2 preds: ^bb181, ^bb184
    %995 = llvm.icmp "slt" %994, %26 : i64
    llvm.cond_br %995, ^bb184, ^bb185
  ^bb184:  // pred: ^bb183
    %996 = llvm.trunc %994 : i64 to i32
    %997 = llvm.mul %994, %26 : i64
    %998 = llvm.add %997, %2 : i64
    %999 = llvm.getelementptr %30[%998] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1000 = "arm_sme.intr.read.horiz"(%10, %1, %996) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %999, %996) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1001 = llvm.mul %994, %26 : i64
    %1002 = llvm.add %1001, %0 : i64
    %1003 = llvm.getelementptr %30[%1002] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1000, %1003 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1004 = llvm.add %994, %3 : i64
    llvm.br ^bb183(%1004 : i64)
  ^bb185:  // pred: ^bb183
    "arm_sme.intr.mopa"(%949, %796, %943, %790) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb186(%0 : i64)
  ^bb186(%1005: i64):  // 2 preds: ^bb185, ^bb187
    %1006 = llvm.icmp "slt" %1005, %26 : i64
    llvm.cond_br %1006, ^bb187, ^bb188(%0 : i64)
  ^bb187:  // pred: ^bb186
    %1007 = llvm.trunc %1005 : i64 to i32
    %1008 = llvm.mul %1005, %26 : i64
    %1009 = llvm.add %1008, %2 : i64
    %1010 = llvm.getelementptr %30[%1009] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1011 = "arm_sme.intr.read.horiz"(%10, %1, %1007) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1010, %1007) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1012 = llvm.mul %1005, %26 : i64
    %1013 = llvm.add %1012, %0 : i64
    %1014 = llvm.getelementptr %30[%1013] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1011, %1014 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1015 = llvm.add %1005, %3 : i64
    llvm.br ^bb186(%1015 : i64)
  ^bb188(%1016: i64):  // 2 preds: ^bb186, ^bb189
    %1017 = llvm.icmp "slt" %1016, %26 : i64
    llvm.cond_br %1017, ^bb189, ^bb190
  ^bb189:  // pred: ^bb188
    %1018 = llvm.trunc %1016 : i64 to i32
    %1019 = llvm.mul %1016, %26 : i64
    %1020 = llvm.add %1019, %2 : i64
    %1021 = llvm.getelementptr %28[%1020] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1022 = "arm_sme.intr.read.horiz"(%10, %1, %1018) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1021, %1018) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1023 = llvm.mul %1016, %26 : i64
    %1024 = llvm.add %1023, %0 : i64
    %1025 = llvm.getelementptr %28[%1024] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1022, %1025 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1026 = llvm.add %1016, %3 : i64
    llvm.br ^bb188(%1026 : i64)
  ^bb190:  // pred: ^bb188
    "arm_sme.intr.mopa"(%949, %825, %943, %819) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb191(%0 : i64)
  ^bb191(%1027: i64):  // 2 preds: ^bb190, ^bb192
    %1028 = llvm.icmp "slt" %1027, %26 : i64
    llvm.cond_br %1028, ^bb192, ^bb193
  ^bb192:  // pred: ^bb191
    %1029 = llvm.trunc %1027 : i64 to i32
    %1030 = llvm.mul %1027, %26 : i64
    %1031 = llvm.add %1030, %2 : i64
    %1032 = llvm.getelementptr %28[%1031] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1033 = "arm_sme.intr.read.horiz"(%10, %1, %1029) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1032, %1029) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1034 = llvm.mul %1027, %26 : i64
    %1035 = llvm.add %1034, %0 : i64
    %1036 = llvm.getelementptr %28[%1035] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1033, %1036 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1037 = llvm.add %1027, %3 : i64
    llvm.br ^bb191(%1037 : i64)
  ^bb193:  // pred: ^bb191
    %1038 = llvm.intr.vector.extract %86[12] : vector<[4]xf32> from vector<[16]xf32>
    %1039 = llvm.intr.stepvector : vector<[4]xi32>
    %1040 = llvm.intr.smin(%640, %13) : (i64, i64) -> i64
    %1041 = llvm.trunc %1040 : i64 to i32
    %1042 = llvm.insertelement %1041, %16[%15 : i32] : vector<[4]xi32>
    %1043 = llvm.shufflevector %1042, %16 [0, 0, 0, 0] : vector<[4]xi32> 
    %1044 = llvm.icmp "slt" %1039, %1043 : vector<[4]xi32>
    "arm_sme.intr.mopa"(%1044, %738, %1038, %726) <{tile_id = 0 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    "arm_sme.intr.mopa"(%1044, %767, %1038, %761) <{tile_id = 1 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    "arm_sme.intr.mopa"(%1044, %796, %1038, %790) <{tile_id = 2 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    "arm_sme.intr.mopa"(%1044, %825, %1038, %819) <{tile_id = 3 : i32}> : (vector<[4]xi1>, vector<[4]xi1>, vector<[4]xf32>, vector<[4]xf32>) -> ()
    llvm.br ^bb194(%0 : i64)
  ^bb194(%1045: i64):  // 2 preds: ^bb193, ^bb267
    %1046 = llvm.icmp "slt" %1045, %26 : i64
    llvm.cond_br %1046, ^bb195, ^bb268
  ^bb195:  // pred: ^bb194
    %1047 = "arm_sve.intr.convert.to.svbool"(%75) : (vector<[16]xi1>) -> vector<[16]xi1>
    %1048 = llvm.trunc %1045 : i64 to i32
    %1049 = "arm_sve.intr.psel"(%1047, %61, %1048) : (vector<[16]xi1>, vector<[16]xi1>, i32) -> vector<[16]xi1>
    %1050 = "arm_sve.intr.convert.from.svbool"(%1049) : (vector<[16]xi1>) -> vector<[16]xi1>
    %1051 = llvm.intr.vector.extract %1050[0] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb196(%0 : i64)
  ^bb196(%1052: i64):  // 2 preds: ^bb195, ^bb197
    %1053 = llvm.icmp "slt" %1052, %26 : i64
    llvm.cond_br %1053, ^bb197, ^bb198
  ^bb197:  // pred: ^bb196
    %1054 = llvm.trunc %1052 : i64 to i32
    %1055 = llvm.mul %1052, %26 : i64
    %1056 = llvm.add %1055, %2 : i64
    %1057 = llvm.getelementptr %50[%1056] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1058 = "arm_sme.intr.read.horiz"(%10, %1, %1054) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1057, %1054) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1059 = llvm.mul %1052, %26 : i64
    %1060 = llvm.add %1059, %0 : i64
    %1061 = llvm.getelementptr %50[%1060] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1058, %1061 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1062 = llvm.add %1052, %3 : i64
    llvm.br ^bb196(%1062 : i64)
  ^bb198:  // pred: ^bb196
    %1063 = llvm.getelementptr %arg15[%69] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1064 = llvm.mul %1045, %arg19 : i64
    %1065 = llvm.mul %arg20, %0 : i64
    %1066 = llvm.add %1064, %1065 : i64
    %1067 = llvm.getelementptr %1063[%1066] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1068 = llvm.trunc %1045 : i64 to i32
    "arm_sme.intr.st1w.horiz"(%1051, %1067, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb199(%0 : i64)
  ^bb199(%1069: i64):  // 2 preds: ^bb198, ^bb200
    %1070 = llvm.icmp "slt" %1069, %26 : i64
    llvm.cond_br %1070, ^bb200, ^bb201
  ^bb200:  // pred: ^bb199
    %1071 = llvm.trunc %1069 : i64 to i32
    %1072 = llvm.mul %1069, %26 : i64
    %1073 = llvm.add %1072, %2 : i64
    %1074 = llvm.getelementptr %50[%1073] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1075 = "arm_sme.intr.read.horiz"(%10, %1, %1071) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1074, %1071) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1076 = llvm.mul %1069, %26 : i64
    %1077 = llvm.add %1076, %0 : i64
    %1078 = llvm.getelementptr %50[%1077] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1075, %1078 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1079 = llvm.add %1069, %3 : i64
    llvm.br ^bb199(%1079 : i64)
  ^bb201:  // pred: ^bb199
    %1080 = llvm.intr.vector.extract %1050[4] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb202(%0 : i64)
  ^bb202(%1081: i64):  // 2 preds: ^bb201, ^bb203
    %1082 = llvm.icmp "slt" %1081, %26 : i64
    llvm.cond_br %1082, ^bb203, ^bb204
  ^bb203:  // pred: ^bb202
    %1083 = llvm.trunc %1081 : i64 to i32
    %1084 = llvm.mul %1081, %26 : i64
    %1085 = llvm.add %1084, %2 : i64
    %1086 = llvm.getelementptr %48[%1085] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1087 = "arm_sme.intr.read.horiz"(%10, %1, %1083) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1086, %1083) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1088 = llvm.mul %1081, %26 : i64
    %1089 = llvm.add %1088, %0 : i64
    %1090 = llvm.getelementptr %48[%1089] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1087, %1090 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1091 = llvm.add %1081, %3 : i64
    llvm.br ^bb202(%1091 : i64)
  ^bb204:  // pred: ^bb202
    %1092 = llvm.mul %26, %arg20 : i64
    %1093 = llvm.add %1064, %1092 : i64
    %1094 = llvm.getelementptr %1063[%1093] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1080, %1094, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb205(%0 : i64)
  ^bb205(%1095: i64):  // 2 preds: ^bb204, ^bb206
    %1096 = llvm.icmp "slt" %1095, %26 : i64
    llvm.cond_br %1096, ^bb206, ^bb207
  ^bb206:  // pred: ^bb205
    %1097 = llvm.trunc %1095 : i64 to i32
    %1098 = llvm.mul %1095, %26 : i64
    %1099 = llvm.add %1098, %2 : i64
    %1100 = llvm.getelementptr %48[%1099] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1101 = "arm_sme.intr.read.horiz"(%10, %1, %1097) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1100, %1097) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1102 = llvm.mul %1095, %26 : i64
    %1103 = llvm.add %1102, %0 : i64
    %1104 = llvm.getelementptr %48[%1103] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1101, %1104 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1105 = llvm.add %1095, %3 : i64
    llvm.br ^bb205(%1105 : i64)
  ^bb207:  // pred: ^bb205
    %1106 = llvm.intr.vector.extract %1050[8] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb208(%0 : i64)
  ^bb208(%1107: i64):  // 2 preds: ^bb207, ^bb209
    %1108 = llvm.icmp "slt" %1107, %26 : i64
    llvm.cond_br %1108, ^bb209, ^bb210
  ^bb209:  // pred: ^bb208
    %1109 = llvm.trunc %1107 : i64 to i32
    %1110 = llvm.mul %1107, %26 : i64
    %1111 = llvm.add %1110, %2 : i64
    %1112 = llvm.getelementptr %46[%1111] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1113 = "arm_sme.intr.read.horiz"(%10, %1, %1109) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1112, %1109) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1114 = llvm.mul %1107, %26 : i64
    %1115 = llvm.add %1114, %0 : i64
    %1116 = llvm.getelementptr %46[%1115] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1113, %1116 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1117 = llvm.add %1107, %3 : i64
    llvm.br ^bb208(%1117 : i64)
  ^bb210:  // pred: ^bb208
    %1118 = llvm.mul %204, %arg20 : i64
    %1119 = llvm.add %1064, %1118 : i64
    %1120 = llvm.getelementptr %1063[%1119] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1106, %1120, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb211(%0 : i64)
  ^bb211(%1121: i64):  // 2 preds: ^bb210, ^bb212
    %1122 = llvm.icmp "slt" %1121, %26 : i64
    llvm.cond_br %1122, ^bb212, ^bb213
  ^bb212:  // pred: ^bb211
    %1123 = llvm.trunc %1121 : i64 to i32
    %1124 = llvm.mul %1121, %26 : i64
    %1125 = llvm.add %1124, %2 : i64
    %1126 = llvm.getelementptr %46[%1125] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1127 = "arm_sme.intr.read.horiz"(%10, %1, %1123) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1126, %1123) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1128 = llvm.mul %1121, %26 : i64
    %1129 = llvm.add %1128, %0 : i64
    %1130 = llvm.getelementptr %46[%1129] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1127, %1130 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1131 = llvm.add %1121, %3 : i64
    llvm.br ^bb211(%1131 : i64)
  ^bb213:  // pred: ^bb211
    %1132 = llvm.intr.vector.extract %1050[12] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb214(%0 : i64)
  ^bb214(%1133: i64):  // 2 preds: ^bb213, ^bb215
    %1134 = llvm.icmp "slt" %1133, %26 : i64
    llvm.cond_br %1134, ^bb215, ^bb216
  ^bb215:  // pred: ^bb214
    %1135 = llvm.trunc %1133 : i64 to i32
    %1136 = llvm.mul %1133, %26 : i64
    %1137 = llvm.add %1136, %2 : i64
    %1138 = llvm.getelementptr %44[%1137] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1139 = "arm_sme.intr.read.horiz"(%10, %1, %1135) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1138, %1135) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1140 = llvm.mul %1133, %26 : i64
    %1141 = llvm.add %1140, %0 : i64
    %1142 = llvm.getelementptr %44[%1141] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1139, %1142 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1143 = llvm.add %1133, %3 : i64
    llvm.br ^bb214(%1143 : i64)
  ^bb216:  // pred: ^bb214
    %1144 = llvm.mul %250, %arg20 : i64
    %1145 = llvm.add %1064, %1144 : i64
    %1146 = llvm.getelementptr %1063[%1145] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1132, %1146, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb217(%0 : i64)
  ^bb217(%1147: i64):  // 2 preds: ^bb216, ^bb218
    %1148 = llvm.icmp "slt" %1147, %26 : i64
    llvm.cond_br %1148, ^bb218, ^bb219
  ^bb218:  // pred: ^bb217
    %1149 = llvm.trunc %1147 : i64 to i32
    %1150 = llvm.mul %1147, %26 : i64
    %1151 = llvm.add %1150, %2 : i64
    %1152 = llvm.getelementptr %44[%1151] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1153 = "arm_sme.intr.read.horiz"(%10, %1, %1149) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1152, %1149) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1154 = llvm.mul %1147, %26 : i64
    %1155 = llvm.add %1154, %0 : i64
    %1156 = llvm.getelementptr %44[%1155] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1153, %1156 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1157 = llvm.add %1147, %3 : i64
    llvm.br ^bb217(%1157 : i64)
  ^bb219:  // pred: ^bb217
    %1158 = llvm.add %26, %1045 : i64
    %1159 = "arm_sve.intr.convert.to.svbool"(%75) : (vector<[16]xi1>) -> vector<[16]xi1>
    %1160 = llvm.trunc %1158 : i64 to i32
    %1161 = "arm_sve.intr.psel"(%1159, %61, %1160) : (vector<[16]xi1>, vector<[16]xi1>, i32) -> vector<[16]xi1>
    %1162 = "arm_sve.intr.convert.from.svbool"(%1161) : (vector<[16]xi1>) -> vector<[16]xi1>
    %1163 = llvm.intr.vector.extract %1162[0] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb220(%0 : i64)
  ^bb220(%1164: i64):  // 2 preds: ^bb219, ^bb221
    %1165 = llvm.icmp "slt" %1164, %26 : i64
    llvm.cond_br %1165, ^bb221, ^bb222
  ^bb221:  // pred: ^bb220
    %1166 = llvm.trunc %1164 : i64 to i32
    %1167 = llvm.mul %1164, %26 : i64
    %1168 = llvm.add %1167, %2 : i64
    %1169 = llvm.getelementptr %42[%1168] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1170 = "arm_sme.intr.read.horiz"(%10, %1, %1166) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1169, %1166) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1171 = llvm.mul %1164, %26 : i64
    %1172 = llvm.add %1171, %0 : i64
    %1173 = llvm.getelementptr %42[%1172] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1170, %1173 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1174 = llvm.add %1164, %3 : i64
    llvm.br ^bb220(%1174 : i64)
  ^bb222:  // pred: ^bb220
    %1175 = llvm.mul %1158, %arg19 : i64
    %1176 = llvm.add %1175, %1065 : i64
    %1177 = llvm.getelementptr %1063[%1176] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1163, %1177, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb223(%0 : i64)
  ^bb223(%1178: i64):  // 2 preds: ^bb222, ^bb224
    %1179 = llvm.icmp "slt" %1178, %26 : i64
    llvm.cond_br %1179, ^bb224, ^bb225
  ^bb224:  // pred: ^bb223
    %1180 = llvm.trunc %1178 : i64 to i32
    %1181 = llvm.mul %1178, %26 : i64
    %1182 = llvm.add %1181, %2 : i64
    %1183 = llvm.getelementptr %42[%1182] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1184 = "arm_sme.intr.read.horiz"(%10, %1, %1180) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1183, %1180) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1185 = llvm.mul %1178, %26 : i64
    %1186 = llvm.add %1185, %0 : i64
    %1187 = llvm.getelementptr %42[%1186] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1184, %1187 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1188 = llvm.add %1178, %3 : i64
    llvm.br ^bb223(%1188 : i64)
  ^bb225:  // pred: ^bb223
    %1189 = llvm.intr.vector.extract %1162[4] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb226(%0 : i64)
  ^bb226(%1190: i64):  // 2 preds: ^bb225, ^bb227
    %1191 = llvm.icmp "slt" %1190, %26 : i64
    llvm.cond_br %1191, ^bb227, ^bb228
  ^bb227:  // pred: ^bb226
    %1192 = llvm.trunc %1190 : i64 to i32
    %1193 = llvm.mul %1190, %26 : i64
    %1194 = llvm.add %1193, %2 : i64
    %1195 = llvm.getelementptr %40[%1194] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1196 = "arm_sme.intr.read.horiz"(%10, %1, %1192) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1195, %1192) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1197 = llvm.mul %1190, %26 : i64
    %1198 = llvm.add %1197, %0 : i64
    %1199 = llvm.getelementptr %40[%1198] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1196, %1199 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1200 = llvm.add %1190, %3 : i64
    llvm.br ^bb226(%1200 : i64)
  ^bb228:  // pred: ^bb226
    %1201 = llvm.add %1175, %1092 : i64
    %1202 = llvm.getelementptr %1063[%1201] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1189, %1202, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb229(%0 : i64)
  ^bb229(%1203: i64):  // 2 preds: ^bb228, ^bb230
    %1204 = llvm.icmp "slt" %1203, %26 : i64
    llvm.cond_br %1204, ^bb230, ^bb231
  ^bb230:  // pred: ^bb229
    %1205 = llvm.trunc %1203 : i64 to i32
    %1206 = llvm.mul %1203, %26 : i64
    %1207 = llvm.add %1206, %2 : i64
    %1208 = llvm.getelementptr %40[%1207] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1209 = "arm_sme.intr.read.horiz"(%10, %1, %1205) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1208, %1205) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1210 = llvm.mul %1203, %26 : i64
    %1211 = llvm.add %1210, %0 : i64
    %1212 = llvm.getelementptr %40[%1211] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1209, %1212 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1213 = llvm.add %1203, %3 : i64
    llvm.br ^bb229(%1213 : i64)
  ^bb231:  // pred: ^bb229
    %1214 = llvm.intr.vector.extract %1162[8] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb232(%0 : i64)
  ^bb232(%1215: i64):  // 2 preds: ^bb231, ^bb233
    %1216 = llvm.icmp "slt" %1215, %26 : i64
    llvm.cond_br %1216, ^bb233, ^bb234
  ^bb233:  // pred: ^bb232
    %1217 = llvm.trunc %1215 : i64 to i32
    %1218 = llvm.mul %1215, %26 : i64
    %1219 = llvm.add %1218, %2 : i64
    %1220 = llvm.getelementptr %38[%1219] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1221 = "arm_sme.intr.read.horiz"(%10, %1, %1217) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1220, %1217) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1222 = llvm.mul %1215, %26 : i64
    %1223 = llvm.add %1222, %0 : i64
    %1224 = llvm.getelementptr %38[%1223] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1221, %1224 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1225 = llvm.add %1215, %3 : i64
    llvm.br ^bb232(%1225 : i64)
  ^bb234:  // pred: ^bb232
    %1226 = llvm.add %1175, %1118 : i64
    %1227 = llvm.getelementptr %1063[%1226] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1214, %1227, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb235(%0 : i64)
  ^bb235(%1228: i64):  // 2 preds: ^bb234, ^bb236
    %1229 = llvm.icmp "slt" %1228, %26 : i64
    llvm.cond_br %1229, ^bb236, ^bb237
  ^bb236:  // pred: ^bb235
    %1230 = llvm.trunc %1228 : i64 to i32
    %1231 = llvm.mul %1228, %26 : i64
    %1232 = llvm.add %1231, %2 : i64
    %1233 = llvm.getelementptr %38[%1232] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1234 = "arm_sme.intr.read.horiz"(%10, %1, %1230) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1233, %1230) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1235 = llvm.mul %1228, %26 : i64
    %1236 = llvm.add %1235, %0 : i64
    %1237 = llvm.getelementptr %38[%1236] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1234, %1237 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1238 = llvm.add %1228, %3 : i64
    llvm.br ^bb235(%1238 : i64)
  ^bb237:  // pred: ^bb235
    %1239 = llvm.intr.vector.extract %1162[12] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb238(%0 : i64)
  ^bb238(%1240: i64):  // 2 preds: ^bb237, ^bb239
    %1241 = llvm.icmp "slt" %1240, %26 : i64
    llvm.cond_br %1241, ^bb239, ^bb240
  ^bb239:  // pred: ^bb238
    %1242 = llvm.trunc %1240 : i64 to i32
    %1243 = llvm.mul %1240, %26 : i64
    %1244 = llvm.add %1243, %2 : i64
    %1245 = llvm.getelementptr %36[%1244] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1246 = "arm_sme.intr.read.horiz"(%10, %1, %1242) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1245, %1242) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1247 = llvm.mul %1240, %26 : i64
    %1248 = llvm.add %1247, %0 : i64
    %1249 = llvm.getelementptr %36[%1248] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1246, %1249 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1250 = llvm.add %1240, %3 : i64
    llvm.br ^bb238(%1250 : i64)
  ^bb240:  // pred: ^bb238
    %1251 = llvm.add %1175, %1144 : i64
    %1252 = llvm.getelementptr %1063[%1251] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1239, %1252, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb241(%0 : i64)
  ^bb241(%1253: i64):  // 2 preds: ^bb240, ^bb242
    %1254 = llvm.icmp "slt" %1253, %26 : i64
    llvm.cond_br %1254, ^bb242, ^bb243
  ^bb242:  // pred: ^bb241
    %1255 = llvm.trunc %1253 : i64 to i32
    %1256 = llvm.mul %1253, %26 : i64
    %1257 = llvm.add %1256, %2 : i64
    %1258 = llvm.getelementptr %36[%1257] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1259 = "arm_sme.intr.read.horiz"(%10, %1, %1255) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1258, %1255) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1260 = llvm.mul %1253, %26 : i64
    %1261 = llvm.add %1260, %0 : i64
    %1262 = llvm.getelementptr %36[%1261] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1259, %1262 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1263 = llvm.add %1253, %3 : i64
    llvm.br ^bb241(%1263 : i64)
  ^bb243:  // pred: ^bb241
    %1264 = llvm.add %204, %1045 : i64
    %1265 = "arm_sve.intr.convert.to.svbool"(%75) : (vector<[16]xi1>) -> vector<[16]xi1>
    %1266 = llvm.trunc %1264 : i64 to i32
    %1267 = "arm_sve.intr.psel"(%1265, %61, %1266) : (vector<[16]xi1>, vector<[16]xi1>, i32) -> vector<[16]xi1>
    %1268 = "arm_sve.intr.convert.from.svbool"(%1267) : (vector<[16]xi1>) -> vector<[16]xi1>
    %1269 = llvm.intr.vector.extract %1268[0] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb244(%0 : i64)
  ^bb244(%1270: i64):  // 2 preds: ^bb243, ^bb245
    %1271 = llvm.icmp "slt" %1270, %26 : i64
    llvm.cond_br %1271, ^bb245, ^bb246
  ^bb245:  // pred: ^bb244
    %1272 = llvm.trunc %1270 : i64 to i32
    %1273 = llvm.mul %1270, %26 : i64
    %1274 = llvm.add %1273, %2 : i64
    %1275 = llvm.getelementptr %34[%1274] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1276 = "arm_sme.intr.read.horiz"(%10, %1, %1272) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1275, %1272) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1277 = llvm.mul %1270, %26 : i64
    %1278 = llvm.add %1277, %0 : i64
    %1279 = llvm.getelementptr %34[%1278] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1276, %1279 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1280 = llvm.add %1270, %3 : i64
    llvm.br ^bb244(%1280 : i64)
  ^bb246:  // pred: ^bb244
    %1281 = llvm.mul %1264, %arg19 : i64
    %1282 = llvm.add %1281, %1065 : i64
    %1283 = llvm.getelementptr %1063[%1282] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1269, %1283, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb247(%0 : i64)
  ^bb247(%1284: i64):  // 2 preds: ^bb246, ^bb248
    %1285 = llvm.icmp "slt" %1284, %26 : i64
    llvm.cond_br %1285, ^bb248, ^bb249
  ^bb248:  // pred: ^bb247
    %1286 = llvm.trunc %1284 : i64 to i32
    %1287 = llvm.mul %1284, %26 : i64
    %1288 = llvm.add %1287, %2 : i64
    %1289 = llvm.getelementptr %34[%1288] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1290 = "arm_sme.intr.read.horiz"(%10, %1, %1286) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1289, %1286) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1291 = llvm.mul %1284, %26 : i64
    %1292 = llvm.add %1291, %0 : i64
    %1293 = llvm.getelementptr %34[%1292] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1290, %1293 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1294 = llvm.add %1284, %3 : i64
    llvm.br ^bb247(%1294 : i64)
  ^bb249:  // pred: ^bb247
    %1295 = llvm.intr.vector.extract %1268[4] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb250(%0 : i64)
  ^bb250(%1296: i64):  // 2 preds: ^bb249, ^bb251
    %1297 = llvm.icmp "slt" %1296, %26 : i64
    llvm.cond_br %1297, ^bb251, ^bb252
  ^bb251:  // pred: ^bb250
    %1298 = llvm.trunc %1296 : i64 to i32
    %1299 = llvm.mul %1296, %26 : i64
    %1300 = llvm.add %1299, %2 : i64
    %1301 = llvm.getelementptr %32[%1300] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1302 = "arm_sme.intr.read.horiz"(%10, %1, %1298) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1301, %1298) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1303 = llvm.mul %1296, %26 : i64
    %1304 = llvm.add %1303, %0 : i64
    %1305 = llvm.getelementptr %32[%1304] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1302, %1305 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1306 = llvm.add %1296, %3 : i64
    llvm.br ^bb250(%1306 : i64)
  ^bb252:  // pred: ^bb250
    %1307 = llvm.add %1281, %1092 : i64
    %1308 = llvm.getelementptr %1063[%1307] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1295, %1308, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb253(%0 : i64)
  ^bb253(%1309: i64):  // 2 preds: ^bb252, ^bb254
    %1310 = llvm.icmp "slt" %1309, %26 : i64
    llvm.cond_br %1310, ^bb254, ^bb255
  ^bb254:  // pred: ^bb253
    %1311 = llvm.trunc %1309 : i64 to i32
    %1312 = llvm.mul %1309, %26 : i64
    %1313 = llvm.add %1312, %2 : i64
    %1314 = llvm.getelementptr %32[%1313] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1315 = "arm_sme.intr.read.horiz"(%10, %1, %1311) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1314, %1311) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1316 = llvm.mul %1309, %26 : i64
    %1317 = llvm.add %1316, %0 : i64
    %1318 = llvm.getelementptr %32[%1317] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1315, %1318 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1319 = llvm.add %1309, %3 : i64
    llvm.br ^bb253(%1319 : i64)
  ^bb255:  // pred: ^bb253
    %1320 = llvm.intr.vector.extract %1268[8] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb256(%0 : i64)
  ^bb256(%1321: i64):  // 2 preds: ^bb255, ^bb257
    %1322 = llvm.icmp "slt" %1321, %26 : i64
    llvm.cond_br %1322, ^bb257, ^bb258
  ^bb257:  // pred: ^bb256
    %1323 = llvm.trunc %1321 : i64 to i32
    %1324 = llvm.mul %1321, %26 : i64
    %1325 = llvm.add %1324, %2 : i64
    %1326 = llvm.getelementptr %30[%1325] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1327 = "arm_sme.intr.read.horiz"(%10, %1, %1323) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1326, %1323) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1328 = llvm.mul %1321, %26 : i64
    %1329 = llvm.add %1328, %0 : i64
    %1330 = llvm.getelementptr %30[%1329] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1327, %1330 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1331 = llvm.add %1321, %3 : i64
    llvm.br ^bb256(%1331 : i64)
  ^bb258:  // pred: ^bb256
    %1332 = llvm.add %1281, %1118 : i64
    %1333 = llvm.getelementptr %1063[%1332] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1320, %1333, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb259(%0 : i64)
  ^bb259(%1334: i64):  // 2 preds: ^bb258, ^bb260
    %1335 = llvm.icmp "slt" %1334, %26 : i64
    llvm.cond_br %1335, ^bb260, ^bb261
  ^bb260:  // pred: ^bb259
    %1336 = llvm.trunc %1334 : i64 to i32
    %1337 = llvm.mul %1334, %26 : i64
    %1338 = llvm.add %1337, %2 : i64
    %1339 = llvm.getelementptr %30[%1338] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1340 = "arm_sme.intr.read.horiz"(%10, %1, %1336) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1339, %1336) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1341 = llvm.mul %1334, %26 : i64
    %1342 = llvm.add %1341, %0 : i64
    %1343 = llvm.getelementptr %30[%1342] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1340, %1343 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1344 = llvm.add %1334, %3 : i64
    llvm.br ^bb259(%1344 : i64)
  ^bb261:  // pred: ^bb259
    %1345 = llvm.intr.vector.extract %1268[12] : vector<[4]xi1> from vector<[16]xi1>
    llvm.br ^bb262(%0 : i64)
  ^bb262(%1346: i64):  // 2 preds: ^bb261, ^bb263
    %1347 = llvm.icmp "slt" %1346, %26 : i64
    llvm.cond_br %1347, ^bb263, ^bb264
  ^bb263:  // pred: ^bb262
    %1348 = llvm.trunc %1346 : i64 to i32
    %1349 = llvm.mul %1346, %26 : i64
    %1350 = llvm.add %1349, %2 : i64
    %1351 = llvm.getelementptr %28[%1350] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1352 = "arm_sme.intr.read.horiz"(%10, %1, %1348) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1351, %1348) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1353 = llvm.mul %1346, %26 : i64
    %1354 = llvm.add %1353, %0 : i64
    %1355 = llvm.getelementptr %28[%1354] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1352, %1355 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1356 = llvm.add %1346, %3 : i64
    llvm.br ^bb262(%1356 : i64)
  ^bb264:  // pred: ^bb262
    %1357 = llvm.add %1281, %1144 : i64
    %1358 = llvm.getelementptr %1063[%1357] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1345, %1358, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    llvm.br ^bb265(%0 : i64)
  ^bb265(%1359: i64):  // 2 preds: ^bb264, ^bb266
    %1360 = llvm.icmp "slt" %1359, %26 : i64
    llvm.cond_br %1360, ^bb266, ^bb267
  ^bb266:  // pred: ^bb265
    %1361 = llvm.trunc %1359 : i64 to i32
    %1362 = llvm.mul %1359, %26 : i64
    %1363 = llvm.add %1362, %2 : i64
    %1364 = llvm.getelementptr %28[%1363] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %1365 = "arm_sme.intr.read.horiz"(%10, %1, %1361) <{tile_id = 0 : i32}> : (vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
    "arm_sme.intr.ld1w.horiz"(%1, %1364, %1361) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1366 = llvm.mul %1359, %26 : i64
    %1367 = llvm.add %1366, %0 : i64
    %1368 = llvm.getelementptr %28[%1367] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %1365, %1368 {alignment = 4 : i64} : vector<[4]xf32>, !llvm.ptr
    %1369 = llvm.add %1359, %3 : i64
    llvm.br ^bb265(%1369 : i64)
  ^bb267:  // pred: ^bb265
    %1370 = llvm.add %250, %1045 : i64
    %1371 = "arm_sve.intr.convert.to.svbool"(%75) : (vector<[16]xi1>) -> vector<[16]xi1>
    %1372 = llvm.trunc %1370 : i64 to i32
    %1373 = "arm_sve.intr.psel"(%1371, %61, %1372) : (vector<[16]xi1>, vector<[16]xi1>, i32) -> vector<[16]xi1>
    %1374 = "arm_sve.intr.convert.from.svbool"(%1373) : (vector<[16]xi1>) -> vector<[16]xi1>
    %1375 = llvm.intr.vector.extract %1374[0] : vector<[4]xi1> from vector<[16]xi1>
    %1376 = llvm.mul %1370, %arg19 : i64
    %1377 = llvm.add %1376, %1065 : i64
    %1378 = llvm.getelementptr %1063[%1377] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1375, %1378, %1068) <{tile_id = 0 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1379 = llvm.intr.vector.extract %1374[4] : vector<[4]xi1> from vector<[16]xi1>
    %1380 = llvm.add %1376, %1092 : i64
    %1381 = llvm.getelementptr %1063[%1380] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1379, %1381, %1068) <{tile_id = 1 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1382 = llvm.intr.vector.extract %1374[8] : vector<[4]xi1> from vector<[16]xi1>
    %1383 = llvm.add %1376, %1118 : i64
    %1384 = llvm.getelementptr %1063[%1383] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1382, %1384, %1068) <{tile_id = 2 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1385 = llvm.intr.vector.extract %1374[12] : vector<[4]xi1> from vector<[16]xi1>
    %1386 = llvm.add %1376, %1144 : i64
    %1387 = llvm.getelementptr %1063[%1386] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "arm_sme.intr.st1w.horiz"(%1385, %1387, %1068) <{tile_id = 3 : i32}> : (vector<[4]xi1>, !llvm.ptr, i32) -> ()
    %1388 = llvm.add %1045, %3 : i64
    llvm.br ^bb194(%1388 : i64)
  ^bb268:  // pred: ^bb194
    %1389 = llvm.add %76, %3 : i64
    llvm.br ^bb5(%1389 : i64)
  ^bb269:  // pred: ^bb5
    %1390 = llvm.add %62, %51 : i64
    llvm.br ^bb3(%1390 : i64)
  ^bb270:  // pred: ^bb3
    %1391 = llvm.add %52, %51 : i64
    llvm.br ^bb1(%1391 : i64)
  ^bb271:  // pred: ^bb1
    llvm.return %24 : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
  }
  module attributes {transform.with_named_sequence} {
  }
}

