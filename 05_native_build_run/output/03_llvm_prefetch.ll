; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define void @gemm_fp32_affine(ptr %0, ptr %1, i64 %2, i64 %3, i64 %4, i64 %5, i64 %6, ptr %7, ptr %8, i64 %9, i64 %10, i64 %11, i64 %12, i64 %13, ptr %14, ptr %15, i64 %16, i64 %17, i64 %18, i64 %19, i64 %20) {
  %22 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %14, 0
  %23 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %22, ptr %15, 1
  %24 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %23, i64 %16, 2
  %25 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %24, i64 %17, 3, 0
  %26 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %25, i64 %19, 4, 0
  %27 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %26, i64 %18, 3, 1
  %28 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %27, i64 %20, 4, 1
  %29 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %7, 0
  %30 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %29, ptr %8, 1
  %31 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %30, i64 %9, 2
  %32 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %31, i64 %10, 3, 0
  %33 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %32, i64 %12, 4, 0
  %34 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %33, i64 %11, 3, 1
  %35 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %34, i64 %13, 4, 1
  %36 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %0, 0
  %37 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %36, ptr %1, 1
  %38 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %37, i64 %2, 2
  %39 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %38, i64 %3, 3, 0
  %40 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %39, i64 %5, 4, 0
  %41 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %40, i64 %4, 3, 1
  %42 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %41, i64 %6, 4, 1
  %43 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %42, 3, 0
  %44 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %42, 3, 1
  %45 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %35, 3, 1
  br label %46

46:                                               ; preds = %183, %21
  %47 = phi i64 [ %184, %183 ], [ 0, %21 ]
  %48 = icmp slt i64 %47, %43
  br i1 %48, label %49, label %185

49:                                               ; preds = %46
  %50 = sub i64 %43, %47
  %51 = call i64 @llvm.smin.i64(i64 %50, i64 128)
  br label %52

52:                                               ; preds = %181, %49
  %53 = phi i64 [ %182, %181 ], [ 0, %49 ]
  %54 = icmp slt i64 %53, %45
  br i1 %54, label %55, label %183

55:                                               ; preds = %52
  %56 = sub i64 %45, %53
  %57 = call i64 @llvm.smin.i64(i64 %56, i64 128)
  br label %58

58:                                               ; preds = %179, %55
  %59 = phi i64 [ %180, %179 ], [ 0, %55 ]
  %60 = icmp slt i64 %59, %44
  br i1 %60, label %61, label %181

61:                                               ; preds = %58
  %62 = sub i64 %44, %59
  %63 = call i64 @llvm.smin.i64(i64 %62, i64 128)
  br label %64

64:                                               ; preds = %177, %61
  %65 = phi i64 [ %178, %177 ], [ 0, %61 ]
  %66 = icmp slt i64 %65, 128
  br i1 %66, label %67, label %179

67:                                               ; preds = %64
  %68 = icmp ult i64 %65, %51
  br i1 %68, label %69, label %177

69:                                               ; preds = %67
  br label %70

70:                                               ; preds = %174, %69
  %71 = phi i64 [ %175, %174 ], [ 0, %69 ]
  %72 = icmp slt i64 %71, 128
  br i1 %72, label %73, label %176

73:                                               ; preds = %70
  %74 = icmp ult i64 %71, %57
  br i1 %74, label %75, label %174

75:                                               ; preds = %73
  br label %76

76:                                               ; preds = %102, %75
  %77 = phi i64 [ %103, %102 ], [ 0, %75 ]
  %78 = icmp slt i64 %77, 16
  br i1 %78, label %79, label %104

79:                                               ; preds = %76
  %80 = add i64 %65, %77
  %81 = icmp ult i64 %80, %51
  br i1 %81, label %82, label %102

82:                                               ; preds = %79
  %83 = add i64 %47, %65
  %84 = add i64 %83, %77
  br label %85

85:                                               ; preds = %99, %82
  %86 = phi i64 [ %100, %99 ], [ 0, %82 ]
  %87 = icmp slt i64 %86, 16
  br i1 %87, label %88, label %101

88:                                               ; preds = %85
  %89 = add i64 %71, %86
  %90 = icmp ult i64 %89, %57
  br i1 %90, label %91, label %99

91:                                               ; preds = %88
  %92 = add i64 %53, %71
  %93 = add i64 %92, %86
  %94 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %95 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 4, 0
  %96 = mul nsw i64 %84, %95
  %97 = add nsw i64 %96, %93
  %98 = getelementptr inbounds float, ptr %94, i64 %97
  store float 0.000000e+00, ptr %98, align 4
  br label %99

99:                                               ; preds = %91, %88
  %100 = add i64 %86, 1
  br label %85

101:                                              ; preds = %85
  br label %102

102:                                              ; preds = %101, %79
  %103 = add i64 %77, 1
  br label %76

104:                                              ; preds = %76
  br label %105

105:                                              ; preds = %171, %104
  %106 = phi i64 [ %172, %171 ], [ 0, %104 ]
  %107 = icmp slt i64 %106, 128
  br i1 %107, label %108, label %173

108:                                              ; preds = %105
  %109 = icmp ult i64 %106, %63
  br i1 %109, label %110, label %171

110:                                              ; preds = %108
  %111 = add i64 %59, %106
  %112 = add i64 %53, %71
  %113 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %35, 1
  %114 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %35, 4, 0
  %115 = mul i64 %111, %114
  %116 = add i64 %115, %112
  %117 = getelementptr float, ptr %113, i64 %116
  call void @llvm.prefetch.p0(ptr %117, i32 0, i32 3, i32 1)
  %118 = add i64 %47, %65
  %119 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %42, 1
  %120 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %42, 4, 0
  %121 = mul i64 %118, %120
  %122 = add i64 %121, %111
  %123 = getelementptr float, ptr %119, i64 %122
  call void @llvm.prefetch.p0(ptr %123, i32 0, i32 3, i32 1)
  br label %124

124:                                              ; preds = %168, %110
  %125 = phi i64 [ %169, %168 ], [ 0, %110 ]
  %126 = icmp slt i64 %125, 16
  br i1 %126, label %127, label %170

127:                                              ; preds = %124
  %128 = add i64 %65, %125
  %129 = icmp ult i64 %128, %51
  br i1 %129, label %130, label %168

130:                                              ; preds = %127
  %131 = add i64 %118, %125
  %132 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %42, 1
  %133 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %42, 4, 0
  %134 = mul nsw i64 %131, %133
  %135 = add nsw i64 %134, %111
  %136 = getelementptr inbounds float, ptr %132, i64 %135
  %137 = load float, ptr %136, align 4
  br label %138

138:                                              ; preds = %165, %130
  %139 = phi i64 [ %166, %165 ], [ 0, %130 ]
  %140 = icmp slt i64 %139, 16
  br i1 %140, label %141, label %167

141:                                              ; preds = %138
  %142 = add i64 %71, %139
  %143 = icmp ult i64 %142, %57
  br i1 %143, label %144, label %165

144:                                              ; preds = %141
  %145 = add i64 %112, %139
  %146 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %35, 1
  %147 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %35, 4, 0
  %148 = mul nsw i64 %111, %147
  %149 = add nsw i64 %148, %145
  %150 = getelementptr inbounds float, ptr %146, i64 %149
  %151 = load float, ptr %150, align 4
  %152 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %153 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 4, 0
  %154 = mul nsw i64 %131, %153
  %155 = add nsw i64 %154, %145
  %156 = getelementptr inbounds float, ptr %152, i64 %155
  %157 = load float, ptr %156, align 4
  %158 = fmul float %137, %151
  %159 = fadd float %157, %158
  %160 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 1
  %161 = extractvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %28, 4, 0
  %162 = mul nsw i64 %131, %161
  %163 = add nsw i64 %162, %145
  %164 = getelementptr inbounds float, ptr %160, i64 %163
  store float %159, ptr %164, align 4
  br label %165

165:                                              ; preds = %144, %141
  %166 = add i64 %139, 1
  br label %138

167:                                              ; preds = %138
  br label %168

168:                                              ; preds = %167, %127
  %169 = add i64 %125, 1
  br label %124

170:                                              ; preds = %124
  br label %171

171:                                              ; preds = %170, %108
  %172 = add i64 %106, 1
  br label %105

173:                                              ; preds = %105
  br label %174

174:                                              ; preds = %173, %73
  %175 = add i64 %71, 16
  br label %70

176:                                              ; preds = %70
  br label %177

177:                                              ; preds = %176, %67
  %178 = add i64 %65, 16
  br label %64

179:                                              ; preds = %64
  %180 = add i64 %59, 128
  br label %58

181:                                              ; preds = %58
  %182 = add i64 %53, 128
  br label %52

183:                                              ; preds = %52
  %184 = add i64 %47, 128
  br label %46

185:                                              ; preds = %46
  ret void
}

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smin.i64(i64, i64) #0

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, inaccessiblemem: readwrite)
declare void @llvm.prefetch.p0(ptr readonly captures(none), i32 immarg range(i32 0, 2), i32 immarg range(i32 0, 4), i32 immarg range(i32 0, 2)) #1

attributes #0 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #1 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, inaccessiblemem: readwrite) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
