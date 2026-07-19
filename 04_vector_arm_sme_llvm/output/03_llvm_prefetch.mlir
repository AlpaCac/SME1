module {
  llvm.func @gemm_fp32_affine(%arg0: !llvm.ptr, %arg1: !llvm.ptr, %arg2: i64, %arg3: i64, %arg4: i64, %arg5: i64, %arg6: i64, %arg7: !llvm.ptr, %arg8: !llvm.ptr, %arg9: i64, %arg10: i64, %arg11: i64, %arg12: i64, %arg13: i64, %arg14: !llvm.ptr, %arg15: !llvm.ptr, %arg16: i64, %arg17: i64, %arg18: i64, %arg19: i64, %arg20: i64) attributes {c_kernel = "gemm_fp32", layout = "A row-major, B row-major, C row-major", mlir_level = "affine", prefetch_injected = "true", semantic = "C = A * B", step4_prefetch_bridge = "research_to_affine"} {
    %0 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %1 = llvm.insertvalue %arg14, %0[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %2 = llvm.insertvalue %arg15, %1[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %3 = llvm.insertvalue %arg16, %2[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %4 = llvm.insertvalue %arg17, %3[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %5 = llvm.insertvalue %arg19, %4[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %6 = llvm.insertvalue %arg18, %5[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %7 = llvm.insertvalue %arg20, %6[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %8 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %9 = llvm.insertvalue %arg7, %8[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %10 = llvm.insertvalue %arg8, %9[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %11 = llvm.insertvalue %arg9, %10[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %12 = llvm.insertvalue %arg10, %11[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %13 = llvm.insertvalue %arg12, %12[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %14 = llvm.insertvalue %arg11, %13[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %15 = llvm.insertvalue %arg13, %14[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %16 = llvm.mlir.poison : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)>
    %17 = llvm.insertvalue %arg0, %16[0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %18 = llvm.insertvalue %arg1, %17[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %19 = llvm.insertvalue %arg2, %18[2] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %20 = llvm.insertvalue %arg3, %19[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %21 = llvm.insertvalue %arg5, %20[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %22 = llvm.insertvalue %arg4, %21[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %23 = llvm.insertvalue %arg6, %22[4, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %24 = llvm.mlir.constant(0 : index) : i64
    %25 = llvm.mlir.constant(1 : index) : i64
    %26 = llvm.mlir.constant(128 : index) : i64
    %27 = llvm.mlir.constant(16 : index) : i64
    %28 = llvm.mlir.constant(0.000000e+00 : f32) : f32
    %29 = llvm.extractvalue %23[3, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %30 = llvm.extractvalue %23[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %31 = llvm.extractvalue %15[3, 1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    llvm.br ^bb1(%24 : i64)
  ^bb1(%32: i64):  // 2 preds: ^bb0, ^bb43
    %33 = llvm.icmp "slt" %32, %29 : i64
    llvm.cond_br %33, ^bb2, ^bb44
  ^bb2:  // pred: ^bb1
    %34 = llvm.sub %29, %32 : i64
    %35 = llvm.intr.smin(%34, %26) : (i64, i64) -> i64
    llvm.br ^bb3(%24 : i64)
  ^bb3(%36: i64):  // 2 preds: ^bb2, ^bb42
    %37 = llvm.icmp "slt" %36, %31 : i64
    llvm.cond_br %37, ^bb4, ^bb43
  ^bb4:  // pred: ^bb3
    %38 = llvm.sub %31, %36 : i64
    %39 = llvm.intr.smin(%38, %26) : (i64, i64) -> i64
    llvm.br ^bb5(%24 : i64)
  ^bb5(%40: i64):  // 2 preds: ^bb4, ^bb41
    %41 = llvm.icmp "slt" %40, %30 : i64
    llvm.cond_br %41, ^bb6, ^bb42
  ^bb6:  // pred: ^bb5
    %42 = llvm.sub %30, %40 : i64
    %43 = llvm.intr.smin(%42, %26) : (i64, i64) -> i64
    llvm.br ^bb7(%24 : i64)
  ^bb7(%44: i64):  // 2 preds: ^bb6, ^bb40
    %45 = llvm.icmp "slt" %44, %26 : i64
    llvm.cond_br %45, ^bb8, ^bb41
  ^bb8:  // pred: ^bb7
    %46 = llvm.icmp "ult" %44, %35 : i64
    llvm.cond_br %46, ^bb9, ^bb40
  ^bb9:  // pred: ^bb8
    llvm.br ^bb10(%24 : i64)
  ^bb10(%47: i64):  // 2 preds: ^bb9, ^bb38
    %48 = llvm.icmp "slt" %47, %26 : i64
    llvm.cond_br %48, ^bb11, ^bb39
  ^bb11:  // pred: ^bb10
    %49 = llvm.icmp "ult" %47, %39 : i64
    llvm.cond_br %49, ^bb12, ^bb38
  ^bb12:  // pred: ^bb11
    llvm.br ^bb13(%24 : i64)
  ^bb13(%50: i64):  // 2 preds: ^bb12, ^bb21
    %51 = llvm.icmp "slt" %50, %27 : i64
    llvm.cond_br %51, ^bb14, ^bb22
  ^bb14:  // pred: ^bb13
    %52 = llvm.add %44, %50 : i64
    %53 = llvm.icmp "ult" %52, %35 : i64
    llvm.cond_br %53, ^bb15, ^bb21
  ^bb15:  // pred: ^bb14
    %54 = llvm.add %32, %44 : i64
    %55 = llvm.add %54, %50 : i64
    llvm.br ^bb16(%24 : i64)
  ^bb16(%56: i64):  // 2 preds: ^bb15, ^bb19
    %57 = llvm.icmp "slt" %56, %27 : i64
    llvm.cond_br %57, ^bb17, ^bb20
  ^bb17:  // pred: ^bb16
    %58 = llvm.add %47, %56 : i64
    %59 = llvm.icmp "ult" %58, %39 : i64
    llvm.cond_br %59, ^bb18, ^bb19
  ^bb18:  // pred: ^bb17
    %60 = llvm.add %36, %47 : i64
    %61 = llvm.add %60, %56 : i64
    %62 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %63 = llvm.extractvalue %7[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %64 = llvm.mul %55, %63 overflow<nsw> : i64
    %65 = llvm.add %64, %61 overflow<nsw> : i64
    %66 = llvm.getelementptr inbounds %62[%65] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %28, %66 : f32, !llvm.ptr
    llvm.br ^bb19
  ^bb19:  // 2 preds: ^bb17, ^bb18
    %67 = llvm.add %56, %25 : i64
    llvm.br ^bb16(%67 : i64)
  ^bb20:  // pred: ^bb16
    llvm.br ^bb21
  ^bb21:  // 2 preds: ^bb14, ^bb20
    %68 = llvm.add %50, %25 : i64
    llvm.br ^bb13(%68 : i64)
  ^bb22:  // pred: ^bb13
    llvm.br ^bb23(%24 : i64)
  ^bb23(%69: i64):  // 2 preds: ^bb22, ^bb36
    %70 = llvm.icmp "slt" %69, %26 : i64
    llvm.cond_br %70, ^bb24, ^bb37
  ^bb24:  // pred: ^bb23
    %71 = llvm.icmp "ult" %69, %43 : i64
    llvm.cond_br %71, ^bb25, ^bb36
  ^bb25:  // pred: ^bb24
    %72 = llvm.add %40, %69 : i64
    %73 = llvm.add %36, %47 : i64
    %74 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %75 = llvm.extractvalue %15[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %76 = llvm.mul %72, %75 : i64
    %77 = llvm.add %76, %73 : i64
    %78 = llvm.getelementptr %74[%77] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "llvm.intr.prefetch"(%78) <{cache = 1 : i32, hint = 3 : i32, rw = 0 : i32}> : (!llvm.ptr) -> ()
    %79 = llvm.add %32, %44 : i64
    %80 = llvm.extractvalue %23[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %81 = llvm.extractvalue %23[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %82 = llvm.mul %79, %81 : i64
    %83 = llvm.add %82, %72 : i64
    %84 = llvm.getelementptr %80[%83] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    "llvm.intr.prefetch"(%84) <{cache = 1 : i32, hint = 3 : i32, rw = 0 : i32}> : (!llvm.ptr) -> ()
    llvm.br ^bb26(%24 : i64)
  ^bb26(%85: i64):  // 2 preds: ^bb25, ^bb34
    %86 = llvm.icmp "slt" %85, %27 : i64
    llvm.cond_br %86, ^bb27, ^bb35
  ^bb27:  // pred: ^bb26
    %87 = llvm.add %44, %85 : i64
    %88 = llvm.icmp "ult" %87, %35 : i64
    llvm.cond_br %88, ^bb28, ^bb34
  ^bb28:  // pred: ^bb27
    %89 = llvm.add %79, %85 : i64
    %90 = llvm.extractvalue %23[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %91 = llvm.extractvalue %23[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %92 = llvm.mul %89, %91 overflow<nsw> : i64
    %93 = llvm.add %92, %72 overflow<nsw> : i64
    %94 = llvm.getelementptr inbounds %90[%93] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %95 = llvm.load %94 : !llvm.ptr -> f32
    llvm.br ^bb29(%24 : i64)
  ^bb29(%96: i64):  // 2 preds: ^bb28, ^bb32
    %97 = llvm.icmp "slt" %96, %27 : i64
    llvm.cond_br %97, ^bb30, ^bb33
  ^bb30:  // pred: ^bb29
    %98 = llvm.add %47, %96 : i64
    %99 = llvm.icmp "ult" %98, %39 : i64
    llvm.cond_br %99, ^bb31, ^bb32
  ^bb31:  // pred: ^bb30
    %100 = llvm.add %73, %96 : i64
    %101 = llvm.extractvalue %15[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %102 = llvm.extractvalue %15[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %103 = llvm.mul %72, %102 overflow<nsw> : i64
    %104 = llvm.add %103, %100 overflow<nsw> : i64
    %105 = llvm.getelementptr inbounds %101[%104] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %106 = llvm.load %105 : !llvm.ptr -> f32
    %107 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %108 = llvm.extractvalue %7[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %109 = llvm.mul %89, %108 overflow<nsw> : i64
    %110 = llvm.add %109, %100 overflow<nsw> : i64
    %111 = llvm.getelementptr inbounds %107[%110] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    %112 = llvm.load %111 : !llvm.ptr -> f32
    %113 = llvm.fmul %95, %106 : f32
    %114 = llvm.fadd %112, %113 : f32
    %115 = llvm.extractvalue %7[1] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %116 = llvm.extractvalue %7[4, 0] : !llvm.struct<(ptr, ptr, i64, array<2 x i64>, array<2 x i64>)> 
    %117 = llvm.mul %89, %116 overflow<nsw> : i64
    %118 = llvm.add %117, %100 overflow<nsw> : i64
    %119 = llvm.getelementptr inbounds %115[%118] : (!llvm.ptr, i64) -> !llvm.ptr, f32
    llvm.store %114, %119 : f32, !llvm.ptr
    llvm.br ^bb32
  ^bb32:  // 2 preds: ^bb30, ^bb31
    %120 = llvm.add %96, %25 : i64
    llvm.br ^bb29(%120 : i64)
  ^bb33:  // pred: ^bb29
    llvm.br ^bb34
  ^bb34:  // 2 preds: ^bb27, ^bb33
    %121 = llvm.add %85, %25 : i64
    llvm.br ^bb26(%121 : i64)
  ^bb35:  // pred: ^bb26
    llvm.br ^bb36
  ^bb36:  // 2 preds: ^bb24, ^bb35
    %122 = llvm.add %69, %25 : i64
    llvm.br ^bb23(%122 : i64)
  ^bb37:  // pred: ^bb23
    llvm.br ^bb38
  ^bb38:  // 2 preds: ^bb11, ^bb37
    %123 = llvm.add %47, %27 : i64
    llvm.br ^bb10(%123 : i64)
  ^bb39:  // pred: ^bb10
    llvm.br ^bb40
  ^bb40:  // 2 preds: ^bb8, ^bb39
    %124 = llvm.add %44, %27 : i64
    llvm.br ^bb7(%124 : i64)
  ^bb41:  // pred: ^bb7
    %125 = llvm.add %40, %26 : i64
    llvm.br ^bb5(%125 : i64)
  ^bb42:  // pred: ^bb5
    %126 = llvm.add %36, %26 : i64
    llvm.br ^bb3(%126 : i64)
  ^bb43:  // pred: ^bb3
    %127 = llvm.add %32, %26 : i64
    llvm.br ^bb1(%127 : i64)
  ^bb44:  // pred: ^bb1
    llvm.return
  }
}

