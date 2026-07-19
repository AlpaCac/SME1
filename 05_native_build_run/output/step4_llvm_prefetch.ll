; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define { ptr, ptr, i64, [2 x i64], [2 x i64] } @gemm_step4_compute(ptr %0, ptr %1, i64 %2, i64 %3, i64 %4, i64 %5, i64 %6, ptr %7, ptr %8, i64 %9, i64 %10, i64 %11, i64 %12, i64 %13, ptr %14, ptr %15, i64 %16, i64 %17, i64 %18, i64 %19, i64 %20) #0 {
  %22 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } poison, ptr %14, 0
  %23 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %22, ptr %15, 1
  %24 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %23, i64 %16, 2
  %25 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %24, i64 %17, 3, 0
  %26 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %25, i64 %19, 4, 0
  %27 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %26, i64 %18, 3, 1
  %28 = insertvalue { ptr, ptr, i64, [2 x i64], [2 x i64] } %27, i64 %20, 4, 1
  %29 = call i64 @llvm.vscale.i64()
  %30 = mul i64 %29, 4
  %31 = mul i64 %30, %30
  %32 = alloca float, i64 %31, align 4
  %33 = mul i64 %30, %30
  %34 = alloca float, i64 %33, align 4
  %35 = mul i64 %30, %30
  %36 = alloca float, i64 %35, align 4
  %37 = mul i64 %30, %30
  %38 = alloca float, i64 %37, align 4
  %39 = mul i64 %30, %30
  %40 = alloca float, i64 %39, align 4
  %41 = mul i64 %30, %30
  %42 = alloca float, i64 %41, align 4
  %43 = mul i64 %30, %30
  %44 = alloca float, i64 %43, align 4
  %45 = mul i64 %30, %30
  %46 = alloca float, i64 %45, align 4
  %47 = mul i64 %30, %30
  %48 = alloca float, i64 %47, align 4
  %49 = mul i64 %30, %30
  %50 = alloca float, i64 %49, align 4
  %51 = mul i64 %30, %30
  %52 = alloca float, i64 %51, align 4
  %53 = mul i64 %30, %30
  %54 = alloca float, i64 %53, align 4
  %55 = mul i64 %29, 16
  br label %56

56:                                               ; preds = %1664, %21
  %57 = phi i64 [ %1665, %1664 ], [ 0, %21 ]
  %58 = icmp slt i64 %57, %3
  br i1 %58, label %59, label %1666

59:                                               ; preds = %56
  %60 = sub i64 %3, %57
  %61 = call i64 @llvm.smin.i64(i64 %55, i64 %60)
  %62 = call <vscale x 16 x i32> @llvm.stepvector.nxv16i32()
  %63 = call i64 @llvm.smin.i64(i64 %61, i64 2147483647)
  %64 = trunc i64 %63 to i32
  %65 = insertelement <vscale x 16 x i32> poison, i32 %64, i32 0
  %66 = shufflevector <vscale x 16 x i32> %65, <vscale x 16 x i32> poison, <vscale x 16 x i32> zeroinitializer
  %67 = icmp slt <vscale x 16 x i32> %62, %66
  br label %68

68:                                               ; preds = %1662, %59
  %69 = phi i64 [ %1663, %1662 ], [ 0, %59 ]
  %70 = icmp slt i64 %69, %11
  br i1 %70, label %71, label %1664

71:                                               ; preds = %68
  %72 = sub i64 %11, %69
  %73 = call i64 @llvm.smin.i64(i64 %55, i64 %72)
  %74 = mul nsw i64 %57, %19
  %75 = add i64 %16, %74
  %76 = mul nsw i64 %69, %20
  %77 = add i64 %75, %76
  %78 = call <vscale x 16 x i32> @llvm.stepvector.nxv16i32()
  %79 = call i64 @llvm.smin.i64(i64 %73, i64 2147483647)
  %80 = trunc i64 %79 to i32
  %81 = insertelement <vscale x 16 x i32> poison, i32 %80, i32 0
  %82 = shufflevector <vscale x 16 x i32> %81, <vscale x 16 x i32> poison, <vscale x 16 x i32> zeroinitializer
  %83 = icmp slt <vscale x 16 x i32> %78, %82
  br label %84

84:                                               ; preds = %1660, %71
  %85 = phi i64 [ %1661, %1660 ], [ 0, %71 ]
  %86 = icmp slt i64 %85, %4
  br i1 %86, label %87, label %1662

87:                                               ; preds = %84
  %88 = mul nsw i64 %57, %5
  %89 = add i64 %2, %88
  %90 = mul nsw i64 %85, %6
  %91 = add i64 %89, %90
  %92 = getelementptr float, ptr %1, i64 %91
  %93 = mul i64 %5, 0
  %94 = getelementptr float, ptr %92, i64 %93
  call void @llvm.prefetch.p0(ptr %94, i32 0, i32 3, i32 1)
  br label %95

95:                                               ; preds = %107, %87
  %96 = phi i64 [ %109, %107 ], [ 0, %87 ]
  %97 = phi <vscale x 16 x float> [ %108, %107 ], [ poison, %87 ]
  %98 = icmp slt i64 %96, %55
  br i1 %98, label %99, label %110

99:                                               ; preds = %95
  %100 = extractelement <vscale x 16 x i1> %67, i64 %96
  br i1 %100, label %101, label %107

101:                                              ; preds = %99
  %102 = getelementptr float, ptr %1, i64 %91
  %103 = mul nsw i64 %96, %5
  %104 = getelementptr inbounds float, ptr %102, i64 %103
  %105 = load float, ptr %104, align 4
  %106 = insertelement <vscale x 16 x float> %97, float %105, i64 %96
  br label %107

107:                                              ; preds = %101, %99
  %108 = phi <vscale x 16 x float> [ %106, %101 ], [ %97, %99 ]
  %109 = add i64 %96, 1
  br label %95

110:                                              ; preds = %95
  %111 = mul nsw i64 %85, %12
  %112 = add i64 %9, %111
  %113 = mul nsw i64 %69, %13
  %114 = add i64 %112, %113
  %115 = getelementptr float, ptr %8, i64 %114
  %116 = mul i64 %13, 0
  %117 = getelementptr float, ptr %115, i64 %116
  call void @llvm.prefetch.p0(ptr %117, i32 0, i32 3, i32 1)
  br label %118

118:                                              ; preds = %130, %110
  %119 = phi i64 [ %132, %130 ], [ 0, %110 ]
  %120 = phi <vscale x 16 x float> [ %131, %130 ], [ poison, %110 ]
  %121 = icmp slt i64 %119, %55
  br i1 %121, label %122, label %133

122:                                              ; preds = %118
  %123 = extractelement <vscale x 16 x i1> %83, i64 %119
  br i1 %123, label %124, label %130

124:                                              ; preds = %122
  %125 = getelementptr float, ptr %8, i64 %114
  %126 = mul nsw i64 %119, %13
  %127 = getelementptr inbounds float, ptr %125, i64 %126
  %128 = load float, ptr %127, align 4
  %129 = insertelement <vscale x 16 x float> %120, float %128, i64 %119
  br label %130

130:                                              ; preds = %124, %122
  %131 = phi <vscale x 16 x float> [ %129, %124 ], [ %120, %122 ]
  %132 = add i64 %119, 1
  br label %118

133:                                              ; preds = %118
  %134 = trunc i64 %73 to i32
  br label %135

135:                                              ; preds = %183, %133
  %136 = phi i64 [ %184, %183 ], [ 0, %133 ]
  %137 = icmp slt i64 %136, %30
  br i1 %137, label %138, label %185

138:                                              ; preds = %135
  %139 = icmp slt i64 %136, %61
  %140 = sext i1 %139 to i32
  %141 = and i32 %140, %134
  %142 = sext i32 %141 to i64
  %143 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %144 = call i64 @llvm.smin.i64(i64 %142, i64 2147483647)
  %145 = trunc i64 %144 to i32
  %146 = insertelement <vscale x 4 x i32> poison, i32 %145, i32 0
  %147 = shufflevector <vscale x 4 x i32> %146, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %148 = icmp slt <vscale x 4 x i32> %143, %147
  %149 = getelementptr float, ptr %15, i64 %77
  %150 = mul i64 %136, %19
  %151 = mul i64 %20, 0
  %152 = add i64 %150, %151
  %153 = getelementptr float, ptr %149, i64 %152
  %154 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %153, <vscale x 4 x i1> %148, <vscale x 4 x float> poison)
  br label %155

155:                                              ; preds = %158, %138
  %156 = phi i64 [ %167, %158 ], [ 0, %138 ]
  %157 = icmp slt i64 %156, %30
  br i1 %157, label %158, label %168

158:                                              ; preds = %155
  %159 = trunc i64 %156 to i32
  %160 = mul i64 %156, %30
  %161 = add i64 %160, 0
  %162 = getelementptr float, ptr %54, i64 %161
  %163 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %159)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %162, i32 0, i32 %159)
  %164 = mul i64 %156, %30
  %165 = add i64 %164, 0
  %166 = getelementptr float, ptr %54, i64 %165
  store <vscale x 4 x float> %163, ptr %166, align 4
  %167 = add i64 %156, 1
  br label %155

168:                                              ; preds = %155
  %169 = trunc i64 %136 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %169, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %154)
  br label %170

170:                                              ; preds = %173, %168
  %171 = phi i64 [ %182, %173 ], [ 0, %168 ]
  %172 = icmp slt i64 %171, %30
  br i1 %172, label %173, label %183

173:                                              ; preds = %170
  %174 = trunc i64 %171 to i32
  %175 = mul i64 %171, %30
  %176 = add i64 %175, 0
  %177 = getelementptr float, ptr %54, i64 %176
  %178 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %174)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %177, i32 0, i32 %174)
  %179 = mul i64 %171, %30
  %180 = add i64 %179, 0
  %181 = getelementptr float, ptr %54, i64 %180
  store <vscale x 4 x float> %178, ptr %181, align 4
  %182 = add i64 %171, 1
  br label %170

183:                                              ; preds = %170
  %184 = add i64 %136, 1
  br label %135

185:                                              ; preds = %135
  %186 = mul i64 %29, -4
  %187 = add i64 %73, %186
  %188 = trunc i64 %187 to i32
  br label %189

189:                                              ; preds = %237, %185
  %190 = phi i64 [ %238, %237 ], [ 0, %185 ]
  %191 = icmp slt i64 %190, %30
  br i1 %191, label %192, label %239

192:                                              ; preds = %189
  %193 = icmp slt i64 %190, %61
  %194 = sext i1 %193 to i32
  %195 = and i32 %194, %188
  %196 = sext i32 %195 to i64
  %197 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %198 = call i64 @llvm.smin.i64(i64 %196, i64 2147483647)
  %199 = trunc i64 %198 to i32
  %200 = insertelement <vscale x 4 x i32> poison, i32 %199, i32 0
  %201 = shufflevector <vscale x 4 x i32> %200, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %202 = icmp slt <vscale x 4 x i32> %197, %201
  %203 = getelementptr float, ptr %15, i64 %77
  %204 = mul i64 %190, %19
  %205 = mul i64 %30, %20
  %206 = add i64 %204, %205
  %207 = getelementptr float, ptr %203, i64 %206
  %208 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %207, <vscale x 4 x i1> %202, <vscale x 4 x float> poison)
  br label %209

209:                                              ; preds = %212, %192
  %210 = phi i64 [ %221, %212 ], [ 0, %192 ]
  %211 = icmp slt i64 %210, %30
  br i1 %211, label %212, label %222

212:                                              ; preds = %209
  %213 = trunc i64 %210 to i32
  %214 = mul i64 %210, %30
  %215 = add i64 %214, 0
  %216 = getelementptr float, ptr %52, i64 %215
  %217 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %213)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %216, i32 0, i32 %213)
  %218 = mul i64 %210, %30
  %219 = add i64 %218, 0
  %220 = getelementptr float, ptr %52, i64 %219
  store <vscale x 4 x float> %217, ptr %220, align 4
  %221 = add i64 %210, 1
  br label %209

222:                                              ; preds = %209
  %223 = trunc i64 %190 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %223, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %208)
  br label %224

224:                                              ; preds = %227, %222
  %225 = phi i64 [ %236, %227 ], [ 0, %222 ]
  %226 = icmp slt i64 %225, %30
  br i1 %226, label %227, label %237

227:                                              ; preds = %224
  %228 = trunc i64 %225 to i32
  %229 = mul i64 %225, %30
  %230 = add i64 %229, 0
  %231 = getelementptr float, ptr %52, i64 %230
  %232 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %228)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %231, i32 0, i32 %228)
  %233 = mul i64 %225, %30
  %234 = add i64 %233, 0
  %235 = getelementptr float, ptr %52, i64 %234
  store <vscale x 4 x float> %232, ptr %235, align 4
  %236 = add i64 %225, 1
  br label %224

237:                                              ; preds = %224
  %238 = add i64 %190, 1
  br label %189

239:                                              ; preds = %189
  %240 = mul i64 %29, -8
  %241 = add i64 %73, %240
  %242 = mul i64 %29, 8
  %243 = trunc i64 %241 to i32
  br label %244

244:                                              ; preds = %292, %239
  %245 = phi i64 [ %293, %292 ], [ 0, %239 ]
  %246 = icmp slt i64 %245, %30
  br i1 %246, label %247, label %294

247:                                              ; preds = %244
  %248 = icmp slt i64 %245, %61
  %249 = sext i1 %248 to i32
  %250 = and i32 %249, %243
  %251 = sext i32 %250 to i64
  %252 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %253 = call i64 @llvm.smin.i64(i64 %251, i64 2147483647)
  %254 = trunc i64 %253 to i32
  %255 = insertelement <vscale x 4 x i32> poison, i32 %254, i32 0
  %256 = shufflevector <vscale x 4 x i32> %255, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %257 = icmp slt <vscale x 4 x i32> %252, %256
  %258 = getelementptr float, ptr %15, i64 %77
  %259 = mul i64 %245, %19
  %260 = mul i64 %242, %20
  %261 = add i64 %259, %260
  %262 = getelementptr float, ptr %258, i64 %261
  %263 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %262, <vscale x 4 x i1> %257, <vscale x 4 x float> poison)
  br label %264

264:                                              ; preds = %267, %247
  %265 = phi i64 [ %276, %267 ], [ 0, %247 ]
  %266 = icmp slt i64 %265, %30
  br i1 %266, label %267, label %277

267:                                              ; preds = %264
  %268 = trunc i64 %265 to i32
  %269 = mul i64 %265, %30
  %270 = add i64 %269, 0
  %271 = getelementptr float, ptr %50, i64 %270
  %272 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %268)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %271, i32 0, i32 %268)
  %273 = mul i64 %265, %30
  %274 = add i64 %273, 0
  %275 = getelementptr float, ptr %50, i64 %274
  store <vscale x 4 x float> %272, ptr %275, align 4
  %276 = add i64 %265, 1
  br label %264

277:                                              ; preds = %264
  %278 = trunc i64 %245 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %278, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %263)
  br label %279

279:                                              ; preds = %282, %277
  %280 = phi i64 [ %291, %282 ], [ 0, %277 ]
  %281 = icmp slt i64 %280, %30
  br i1 %281, label %282, label %292

282:                                              ; preds = %279
  %283 = trunc i64 %280 to i32
  %284 = mul i64 %280, %30
  %285 = add i64 %284, 0
  %286 = getelementptr float, ptr %50, i64 %285
  %287 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %283)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %286, i32 0, i32 %283)
  %288 = mul i64 %280, %30
  %289 = add i64 %288, 0
  %290 = getelementptr float, ptr %50, i64 %289
  store <vscale x 4 x float> %287, ptr %290, align 4
  %291 = add i64 %280, 1
  br label %279

292:                                              ; preds = %279
  %293 = add i64 %245, 1
  br label %244

294:                                              ; preds = %244
  %295 = mul i64 %29, -12
  %296 = add i64 %73, %295
  %297 = mul i64 %29, 12
  %298 = trunc i64 %296 to i32
  br label %299

299:                                              ; preds = %347, %294
  %300 = phi i64 [ %348, %347 ], [ 0, %294 ]
  %301 = icmp slt i64 %300, %30
  br i1 %301, label %302, label %349

302:                                              ; preds = %299
  %303 = icmp slt i64 %300, %61
  %304 = sext i1 %303 to i32
  %305 = and i32 %304, %298
  %306 = sext i32 %305 to i64
  %307 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %308 = call i64 @llvm.smin.i64(i64 %306, i64 2147483647)
  %309 = trunc i64 %308 to i32
  %310 = insertelement <vscale x 4 x i32> poison, i32 %309, i32 0
  %311 = shufflevector <vscale x 4 x i32> %310, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %312 = icmp slt <vscale x 4 x i32> %307, %311
  %313 = getelementptr float, ptr %15, i64 %77
  %314 = mul i64 %300, %19
  %315 = mul i64 %297, %20
  %316 = add i64 %314, %315
  %317 = getelementptr float, ptr %313, i64 %316
  %318 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %317, <vscale x 4 x i1> %312, <vscale x 4 x float> poison)
  br label %319

319:                                              ; preds = %322, %302
  %320 = phi i64 [ %331, %322 ], [ 0, %302 ]
  %321 = icmp slt i64 %320, %30
  br i1 %321, label %322, label %332

322:                                              ; preds = %319
  %323 = trunc i64 %320 to i32
  %324 = mul i64 %320, %30
  %325 = add i64 %324, 0
  %326 = getelementptr float, ptr %48, i64 %325
  %327 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %323)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %326, i32 0, i32 %323)
  %328 = mul i64 %320, %30
  %329 = add i64 %328, 0
  %330 = getelementptr float, ptr %48, i64 %329
  store <vscale x 4 x float> %327, ptr %330, align 4
  %331 = add i64 %320, 1
  br label %319

332:                                              ; preds = %319
  %333 = trunc i64 %300 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %333, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %318)
  br label %334

334:                                              ; preds = %337, %332
  %335 = phi i64 [ %346, %337 ], [ 0, %332 ]
  %336 = icmp slt i64 %335, %30
  br i1 %336, label %337, label %347

337:                                              ; preds = %334
  %338 = trunc i64 %335 to i32
  %339 = mul i64 %335, %30
  %340 = add i64 %339, 0
  %341 = getelementptr float, ptr %48, i64 %340
  %342 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %338)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %341, i32 0, i32 %338)
  %343 = mul i64 %335, %30
  %344 = add i64 %343, 0
  %345 = getelementptr float, ptr %48, i64 %344
  store <vscale x 4 x float> %342, ptr %345, align 4
  %346 = add i64 %335, 1
  br label %334

347:                                              ; preds = %334
  %348 = add i64 %300, 1
  br label %299

349:                                              ; preds = %299
  %350 = add i64 %61, %186
  br label %351

351:                                              ; preds = %400, %349
  %352 = phi i64 [ %401, %400 ], [ 0, %349 ]
  %353 = icmp slt i64 %352, %30
  br i1 %353, label %354, label %402

354:                                              ; preds = %351
  %355 = icmp slt i64 %352, %350
  %356 = sext i1 %355 to i32
  %357 = and i32 %356, %134
  %358 = sext i32 %357 to i64
  %359 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %360 = call i64 @llvm.smin.i64(i64 %358, i64 2147483647)
  %361 = trunc i64 %360 to i32
  %362 = insertelement <vscale x 4 x i32> poison, i32 %361, i32 0
  %363 = shufflevector <vscale x 4 x i32> %362, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %364 = icmp slt <vscale x 4 x i32> %359, %363
  %365 = add i64 %30, %352
  %366 = getelementptr float, ptr %15, i64 %77
  %367 = mul i64 %365, %19
  %368 = mul i64 %20, 0
  %369 = add i64 %367, %368
  %370 = getelementptr float, ptr %366, i64 %369
  %371 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %370, <vscale x 4 x i1> %364, <vscale x 4 x float> poison)
  br label %372

372:                                              ; preds = %375, %354
  %373 = phi i64 [ %384, %375 ], [ 0, %354 ]
  %374 = icmp slt i64 %373, %30
  br i1 %374, label %375, label %385

375:                                              ; preds = %372
  %376 = trunc i64 %373 to i32
  %377 = mul i64 %373, %30
  %378 = add i64 %377, 0
  %379 = getelementptr float, ptr %46, i64 %378
  %380 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %376)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %379, i32 0, i32 %376)
  %381 = mul i64 %373, %30
  %382 = add i64 %381, 0
  %383 = getelementptr float, ptr %46, i64 %382
  store <vscale x 4 x float> %380, ptr %383, align 4
  %384 = add i64 %373, 1
  br label %372

385:                                              ; preds = %372
  %386 = trunc i64 %352 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %386, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %371)
  br label %387

387:                                              ; preds = %390, %385
  %388 = phi i64 [ %399, %390 ], [ 0, %385 ]
  %389 = icmp slt i64 %388, %30
  br i1 %389, label %390, label %400

390:                                              ; preds = %387
  %391 = trunc i64 %388 to i32
  %392 = mul i64 %388, %30
  %393 = add i64 %392, 0
  %394 = getelementptr float, ptr %46, i64 %393
  %395 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %391)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %394, i32 0, i32 %391)
  %396 = mul i64 %388, %30
  %397 = add i64 %396, 0
  %398 = getelementptr float, ptr %46, i64 %397
  store <vscale x 4 x float> %395, ptr %398, align 4
  %399 = add i64 %388, 1
  br label %387

400:                                              ; preds = %387
  %401 = add i64 %352, 1
  br label %351

402:                                              ; preds = %451, %351
  %403 = phi i64 [ %452, %451 ], [ 0, %351 ]
  %404 = icmp slt i64 %403, %30
  br i1 %404, label %405, label %453

405:                                              ; preds = %402
  %406 = icmp slt i64 %403, %350
  %407 = sext i1 %406 to i32
  %408 = and i32 %407, %188
  %409 = sext i32 %408 to i64
  %410 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %411 = call i64 @llvm.smin.i64(i64 %409, i64 2147483647)
  %412 = trunc i64 %411 to i32
  %413 = insertelement <vscale x 4 x i32> poison, i32 %412, i32 0
  %414 = shufflevector <vscale x 4 x i32> %413, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %415 = icmp slt <vscale x 4 x i32> %410, %414
  %416 = add i64 %30, %403
  %417 = getelementptr float, ptr %15, i64 %77
  %418 = mul i64 %416, %19
  %419 = mul i64 %30, %20
  %420 = add i64 %418, %419
  %421 = getelementptr float, ptr %417, i64 %420
  %422 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %421, <vscale x 4 x i1> %415, <vscale x 4 x float> poison)
  br label %423

423:                                              ; preds = %426, %405
  %424 = phi i64 [ %435, %426 ], [ 0, %405 ]
  %425 = icmp slt i64 %424, %30
  br i1 %425, label %426, label %436

426:                                              ; preds = %423
  %427 = trunc i64 %424 to i32
  %428 = mul i64 %424, %30
  %429 = add i64 %428, 0
  %430 = getelementptr float, ptr %44, i64 %429
  %431 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %427)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %430, i32 0, i32 %427)
  %432 = mul i64 %424, %30
  %433 = add i64 %432, 0
  %434 = getelementptr float, ptr %44, i64 %433
  store <vscale x 4 x float> %431, ptr %434, align 4
  %435 = add i64 %424, 1
  br label %423

436:                                              ; preds = %423
  %437 = trunc i64 %403 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %437, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %422)
  br label %438

438:                                              ; preds = %441, %436
  %439 = phi i64 [ %450, %441 ], [ 0, %436 ]
  %440 = icmp slt i64 %439, %30
  br i1 %440, label %441, label %451

441:                                              ; preds = %438
  %442 = trunc i64 %439 to i32
  %443 = mul i64 %439, %30
  %444 = add i64 %443, 0
  %445 = getelementptr float, ptr %44, i64 %444
  %446 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %442)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %445, i32 0, i32 %442)
  %447 = mul i64 %439, %30
  %448 = add i64 %447, 0
  %449 = getelementptr float, ptr %44, i64 %448
  store <vscale x 4 x float> %446, ptr %449, align 4
  %450 = add i64 %439, 1
  br label %438

451:                                              ; preds = %438
  %452 = add i64 %403, 1
  br label %402

453:                                              ; preds = %502, %402
  %454 = phi i64 [ %503, %502 ], [ 0, %402 ]
  %455 = icmp slt i64 %454, %30
  br i1 %455, label %456, label %504

456:                                              ; preds = %453
  %457 = icmp slt i64 %454, %350
  %458 = sext i1 %457 to i32
  %459 = and i32 %458, %243
  %460 = sext i32 %459 to i64
  %461 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %462 = call i64 @llvm.smin.i64(i64 %460, i64 2147483647)
  %463 = trunc i64 %462 to i32
  %464 = insertelement <vscale x 4 x i32> poison, i32 %463, i32 0
  %465 = shufflevector <vscale x 4 x i32> %464, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %466 = icmp slt <vscale x 4 x i32> %461, %465
  %467 = add i64 %30, %454
  %468 = getelementptr float, ptr %15, i64 %77
  %469 = mul i64 %467, %19
  %470 = mul i64 %242, %20
  %471 = add i64 %469, %470
  %472 = getelementptr float, ptr %468, i64 %471
  %473 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %472, <vscale x 4 x i1> %466, <vscale x 4 x float> poison)
  br label %474

474:                                              ; preds = %477, %456
  %475 = phi i64 [ %486, %477 ], [ 0, %456 ]
  %476 = icmp slt i64 %475, %30
  br i1 %476, label %477, label %487

477:                                              ; preds = %474
  %478 = trunc i64 %475 to i32
  %479 = mul i64 %475, %30
  %480 = add i64 %479, 0
  %481 = getelementptr float, ptr %42, i64 %480
  %482 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %478)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %481, i32 0, i32 %478)
  %483 = mul i64 %475, %30
  %484 = add i64 %483, 0
  %485 = getelementptr float, ptr %42, i64 %484
  store <vscale x 4 x float> %482, ptr %485, align 4
  %486 = add i64 %475, 1
  br label %474

487:                                              ; preds = %474
  %488 = trunc i64 %454 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %488, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %473)
  br label %489

489:                                              ; preds = %492, %487
  %490 = phi i64 [ %501, %492 ], [ 0, %487 ]
  %491 = icmp slt i64 %490, %30
  br i1 %491, label %492, label %502

492:                                              ; preds = %489
  %493 = trunc i64 %490 to i32
  %494 = mul i64 %490, %30
  %495 = add i64 %494, 0
  %496 = getelementptr float, ptr %42, i64 %495
  %497 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %493)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %496, i32 0, i32 %493)
  %498 = mul i64 %490, %30
  %499 = add i64 %498, 0
  %500 = getelementptr float, ptr %42, i64 %499
  store <vscale x 4 x float> %497, ptr %500, align 4
  %501 = add i64 %490, 1
  br label %489

502:                                              ; preds = %489
  %503 = add i64 %454, 1
  br label %453

504:                                              ; preds = %553, %453
  %505 = phi i64 [ %554, %553 ], [ 0, %453 ]
  %506 = icmp slt i64 %505, %30
  br i1 %506, label %507, label %555

507:                                              ; preds = %504
  %508 = icmp slt i64 %505, %350
  %509 = sext i1 %508 to i32
  %510 = and i32 %509, %298
  %511 = sext i32 %510 to i64
  %512 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %513 = call i64 @llvm.smin.i64(i64 %511, i64 2147483647)
  %514 = trunc i64 %513 to i32
  %515 = insertelement <vscale x 4 x i32> poison, i32 %514, i32 0
  %516 = shufflevector <vscale x 4 x i32> %515, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %517 = icmp slt <vscale x 4 x i32> %512, %516
  %518 = add i64 %30, %505
  %519 = getelementptr float, ptr %15, i64 %77
  %520 = mul i64 %518, %19
  %521 = mul i64 %297, %20
  %522 = add i64 %520, %521
  %523 = getelementptr float, ptr %519, i64 %522
  %524 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %523, <vscale x 4 x i1> %517, <vscale x 4 x float> poison)
  br label %525

525:                                              ; preds = %528, %507
  %526 = phi i64 [ %537, %528 ], [ 0, %507 ]
  %527 = icmp slt i64 %526, %30
  br i1 %527, label %528, label %538

528:                                              ; preds = %525
  %529 = trunc i64 %526 to i32
  %530 = mul i64 %526, %30
  %531 = add i64 %530, 0
  %532 = getelementptr float, ptr %40, i64 %531
  %533 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %529)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %532, i32 0, i32 %529)
  %534 = mul i64 %526, %30
  %535 = add i64 %534, 0
  %536 = getelementptr float, ptr %40, i64 %535
  store <vscale x 4 x float> %533, ptr %536, align 4
  %537 = add i64 %526, 1
  br label %525

538:                                              ; preds = %525
  %539 = trunc i64 %505 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %539, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %524)
  br label %540

540:                                              ; preds = %543, %538
  %541 = phi i64 [ %552, %543 ], [ 0, %538 ]
  %542 = icmp slt i64 %541, %30
  br i1 %542, label %543, label %553

543:                                              ; preds = %540
  %544 = trunc i64 %541 to i32
  %545 = mul i64 %541, %30
  %546 = add i64 %545, 0
  %547 = getelementptr float, ptr %40, i64 %546
  %548 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %544)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %547, i32 0, i32 %544)
  %549 = mul i64 %541, %30
  %550 = add i64 %549, 0
  %551 = getelementptr float, ptr %40, i64 %550
  store <vscale x 4 x float> %548, ptr %551, align 4
  %552 = add i64 %541, 1
  br label %540

553:                                              ; preds = %540
  %554 = add i64 %505, 1
  br label %504

555:                                              ; preds = %504
  %556 = add i64 %61, %240
  br label %557

557:                                              ; preds = %606, %555
  %558 = phi i64 [ %607, %606 ], [ 0, %555 ]
  %559 = icmp slt i64 %558, %30
  br i1 %559, label %560, label %608

560:                                              ; preds = %557
  %561 = icmp slt i64 %558, %556
  %562 = sext i1 %561 to i32
  %563 = and i32 %562, %134
  %564 = sext i32 %563 to i64
  %565 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %566 = call i64 @llvm.smin.i64(i64 %564, i64 2147483647)
  %567 = trunc i64 %566 to i32
  %568 = insertelement <vscale x 4 x i32> poison, i32 %567, i32 0
  %569 = shufflevector <vscale x 4 x i32> %568, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %570 = icmp slt <vscale x 4 x i32> %565, %569
  %571 = add i64 %242, %558
  %572 = getelementptr float, ptr %15, i64 %77
  %573 = mul i64 %571, %19
  %574 = mul i64 %20, 0
  %575 = add i64 %573, %574
  %576 = getelementptr float, ptr %572, i64 %575
  %577 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %576, <vscale x 4 x i1> %570, <vscale x 4 x float> poison)
  br label %578

578:                                              ; preds = %581, %560
  %579 = phi i64 [ %590, %581 ], [ 0, %560 ]
  %580 = icmp slt i64 %579, %30
  br i1 %580, label %581, label %591

581:                                              ; preds = %578
  %582 = trunc i64 %579 to i32
  %583 = mul i64 %579, %30
  %584 = add i64 %583, 0
  %585 = getelementptr float, ptr %38, i64 %584
  %586 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %582)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %585, i32 0, i32 %582)
  %587 = mul i64 %579, %30
  %588 = add i64 %587, 0
  %589 = getelementptr float, ptr %38, i64 %588
  store <vscale x 4 x float> %586, ptr %589, align 4
  %590 = add i64 %579, 1
  br label %578

591:                                              ; preds = %578
  %592 = trunc i64 %558 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %592, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %577)
  br label %593

593:                                              ; preds = %596, %591
  %594 = phi i64 [ %605, %596 ], [ 0, %591 ]
  %595 = icmp slt i64 %594, %30
  br i1 %595, label %596, label %606

596:                                              ; preds = %593
  %597 = trunc i64 %594 to i32
  %598 = mul i64 %594, %30
  %599 = add i64 %598, 0
  %600 = getelementptr float, ptr %38, i64 %599
  %601 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %597)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %600, i32 0, i32 %597)
  %602 = mul i64 %594, %30
  %603 = add i64 %602, 0
  %604 = getelementptr float, ptr %38, i64 %603
  store <vscale x 4 x float> %601, ptr %604, align 4
  %605 = add i64 %594, 1
  br label %593

606:                                              ; preds = %593
  %607 = add i64 %558, 1
  br label %557

608:                                              ; preds = %657, %557
  %609 = phi i64 [ %658, %657 ], [ 0, %557 ]
  %610 = icmp slt i64 %609, %30
  br i1 %610, label %611, label %659

611:                                              ; preds = %608
  %612 = icmp slt i64 %609, %556
  %613 = sext i1 %612 to i32
  %614 = and i32 %613, %188
  %615 = sext i32 %614 to i64
  %616 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %617 = call i64 @llvm.smin.i64(i64 %615, i64 2147483647)
  %618 = trunc i64 %617 to i32
  %619 = insertelement <vscale x 4 x i32> poison, i32 %618, i32 0
  %620 = shufflevector <vscale x 4 x i32> %619, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %621 = icmp slt <vscale x 4 x i32> %616, %620
  %622 = add i64 %242, %609
  %623 = getelementptr float, ptr %15, i64 %77
  %624 = mul i64 %622, %19
  %625 = mul i64 %30, %20
  %626 = add i64 %624, %625
  %627 = getelementptr float, ptr %623, i64 %626
  %628 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %627, <vscale x 4 x i1> %621, <vscale x 4 x float> poison)
  br label %629

629:                                              ; preds = %632, %611
  %630 = phi i64 [ %641, %632 ], [ 0, %611 ]
  %631 = icmp slt i64 %630, %30
  br i1 %631, label %632, label %642

632:                                              ; preds = %629
  %633 = trunc i64 %630 to i32
  %634 = mul i64 %630, %30
  %635 = add i64 %634, 0
  %636 = getelementptr float, ptr %36, i64 %635
  %637 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %633)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %636, i32 0, i32 %633)
  %638 = mul i64 %630, %30
  %639 = add i64 %638, 0
  %640 = getelementptr float, ptr %36, i64 %639
  store <vscale x 4 x float> %637, ptr %640, align 4
  %641 = add i64 %630, 1
  br label %629

642:                                              ; preds = %629
  %643 = trunc i64 %609 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %643, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %628)
  br label %644

644:                                              ; preds = %647, %642
  %645 = phi i64 [ %656, %647 ], [ 0, %642 ]
  %646 = icmp slt i64 %645, %30
  br i1 %646, label %647, label %657

647:                                              ; preds = %644
  %648 = trunc i64 %645 to i32
  %649 = mul i64 %645, %30
  %650 = add i64 %649, 0
  %651 = getelementptr float, ptr %36, i64 %650
  %652 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %648)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %651, i32 0, i32 %648)
  %653 = mul i64 %645, %30
  %654 = add i64 %653, 0
  %655 = getelementptr float, ptr %36, i64 %654
  store <vscale x 4 x float> %652, ptr %655, align 4
  %656 = add i64 %645, 1
  br label %644

657:                                              ; preds = %644
  %658 = add i64 %609, 1
  br label %608

659:                                              ; preds = %708, %608
  %660 = phi i64 [ %709, %708 ], [ 0, %608 ]
  %661 = icmp slt i64 %660, %30
  br i1 %661, label %662, label %710

662:                                              ; preds = %659
  %663 = icmp slt i64 %660, %556
  %664 = sext i1 %663 to i32
  %665 = and i32 %664, %243
  %666 = sext i32 %665 to i64
  %667 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %668 = call i64 @llvm.smin.i64(i64 %666, i64 2147483647)
  %669 = trunc i64 %668 to i32
  %670 = insertelement <vscale x 4 x i32> poison, i32 %669, i32 0
  %671 = shufflevector <vscale x 4 x i32> %670, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %672 = icmp slt <vscale x 4 x i32> %667, %671
  %673 = add i64 %242, %660
  %674 = getelementptr float, ptr %15, i64 %77
  %675 = mul i64 %673, %19
  %676 = mul i64 %242, %20
  %677 = add i64 %675, %676
  %678 = getelementptr float, ptr %674, i64 %677
  %679 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %678, <vscale x 4 x i1> %672, <vscale x 4 x float> poison)
  br label %680

680:                                              ; preds = %683, %662
  %681 = phi i64 [ %692, %683 ], [ 0, %662 ]
  %682 = icmp slt i64 %681, %30
  br i1 %682, label %683, label %693

683:                                              ; preds = %680
  %684 = trunc i64 %681 to i32
  %685 = mul i64 %681, %30
  %686 = add i64 %685, 0
  %687 = getelementptr float, ptr %34, i64 %686
  %688 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %684)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %687, i32 0, i32 %684)
  %689 = mul i64 %681, %30
  %690 = add i64 %689, 0
  %691 = getelementptr float, ptr %34, i64 %690
  store <vscale x 4 x float> %688, ptr %691, align 4
  %692 = add i64 %681, 1
  br label %680

693:                                              ; preds = %680
  %694 = trunc i64 %660 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %694, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %679)
  br label %695

695:                                              ; preds = %698, %693
  %696 = phi i64 [ %707, %698 ], [ 0, %693 ]
  %697 = icmp slt i64 %696, %30
  br i1 %697, label %698, label %708

698:                                              ; preds = %695
  %699 = trunc i64 %696 to i32
  %700 = mul i64 %696, %30
  %701 = add i64 %700, 0
  %702 = getelementptr float, ptr %34, i64 %701
  %703 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %699)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %702, i32 0, i32 %699)
  %704 = mul i64 %696, %30
  %705 = add i64 %704, 0
  %706 = getelementptr float, ptr %34, i64 %705
  store <vscale x 4 x float> %703, ptr %706, align 4
  %707 = add i64 %696, 1
  br label %695

708:                                              ; preds = %695
  %709 = add i64 %660, 1
  br label %659

710:                                              ; preds = %759, %659
  %711 = phi i64 [ %760, %759 ], [ 0, %659 ]
  %712 = icmp slt i64 %711, %30
  br i1 %712, label %713, label %761

713:                                              ; preds = %710
  %714 = icmp slt i64 %711, %556
  %715 = sext i1 %714 to i32
  %716 = and i32 %715, %298
  %717 = sext i32 %716 to i64
  %718 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %719 = call i64 @llvm.smin.i64(i64 %717, i64 2147483647)
  %720 = trunc i64 %719 to i32
  %721 = insertelement <vscale x 4 x i32> poison, i32 %720, i32 0
  %722 = shufflevector <vscale x 4 x i32> %721, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %723 = icmp slt <vscale x 4 x i32> %718, %722
  %724 = add i64 %242, %711
  %725 = getelementptr float, ptr %15, i64 %77
  %726 = mul i64 %724, %19
  %727 = mul i64 %297, %20
  %728 = add i64 %726, %727
  %729 = getelementptr float, ptr %725, i64 %728
  %730 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %729, <vscale x 4 x i1> %723, <vscale x 4 x float> poison)
  br label %731

731:                                              ; preds = %734, %713
  %732 = phi i64 [ %743, %734 ], [ 0, %713 ]
  %733 = icmp slt i64 %732, %30
  br i1 %733, label %734, label %744

734:                                              ; preds = %731
  %735 = trunc i64 %732 to i32
  %736 = mul i64 %732, %30
  %737 = add i64 %736, 0
  %738 = getelementptr float, ptr %32, i64 %737
  %739 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %735)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %738, i32 0, i32 %735)
  %740 = mul i64 %732, %30
  %741 = add i64 %740, 0
  %742 = getelementptr float, ptr %32, i64 %741
  store <vscale x 4 x float> %739, ptr %742, align 4
  %743 = add i64 %732, 1
  br label %731

744:                                              ; preds = %731
  %745 = trunc i64 %711 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %745, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %730)
  br label %746

746:                                              ; preds = %749, %744
  %747 = phi i64 [ %758, %749 ], [ 0, %744 ]
  %748 = icmp slt i64 %747, %30
  br i1 %748, label %749, label %759

749:                                              ; preds = %746
  %750 = trunc i64 %747 to i32
  %751 = mul i64 %747, %30
  %752 = add i64 %751, 0
  %753 = getelementptr float, ptr %32, i64 %752
  %754 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %750)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %753, i32 0, i32 %750)
  %755 = mul i64 %747, %30
  %756 = add i64 %755, 0
  %757 = getelementptr float, ptr %32, i64 %756
  store <vscale x 4 x float> %754, ptr %757, align 4
  %758 = add i64 %747, 1
  br label %746

759:                                              ; preds = %746
  %760 = add i64 %711, 1
  br label %710

761:                                              ; preds = %710
  %762 = add i64 %61, %295
  br label %763

763:                                              ; preds = %766, %761
  %764 = phi i64 [ %785, %766 ], [ 0, %761 ]
  %765 = icmp slt i64 %764, %30
  br i1 %765, label %766, label %786

766:                                              ; preds = %763
  %767 = icmp slt i64 %764, %762
  %768 = sext i1 %767 to i32
  %769 = and i32 %768, %134
  %770 = sext i32 %769 to i64
  %771 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %772 = call i64 @llvm.smin.i64(i64 %770, i64 2147483647)
  %773 = trunc i64 %772 to i32
  %774 = insertelement <vscale x 4 x i32> poison, i32 %773, i32 0
  %775 = shufflevector <vscale x 4 x i32> %774, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %776 = icmp slt <vscale x 4 x i32> %771, %775
  %777 = add i64 %297, %764
  %778 = getelementptr float, ptr %15, i64 %77
  %779 = mul i64 %777, %19
  %780 = mul i64 %20, 0
  %781 = add i64 %779, %780
  %782 = getelementptr float, ptr %778, i64 %781
  %783 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %782, <vscale x 4 x i1> %776, <vscale x 4 x float> poison)
  %784 = trunc i64 %764 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %784, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %783)
  %785 = add i64 %764, 1
  br label %763

786:                                              ; preds = %789, %763
  %787 = phi i64 [ %808, %789 ], [ 0, %763 ]
  %788 = icmp slt i64 %787, %30
  br i1 %788, label %789, label %809

789:                                              ; preds = %786
  %790 = icmp slt i64 %787, %762
  %791 = sext i1 %790 to i32
  %792 = and i32 %791, %188
  %793 = sext i32 %792 to i64
  %794 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %795 = call i64 @llvm.smin.i64(i64 %793, i64 2147483647)
  %796 = trunc i64 %795 to i32
  %797 = insertelement <vscale x 4 x i32> poison, i32 %796, i32 0
  %798 = shufflevector <vscale x 4 x i32> %797, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %799 = icmp slt <vscale x 4 x i32> %794, %798
  %800 = add i64 %297, %787
  %801 = getelementptr float, ptr %15, i64 %77
  %802 = mul i64 %800, %19
  %803 = mul i64 %30, %20
  %804 = add i64 %802, %803
  %805 = getelementptr float, ptr %801, i64 %804
  %806 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %805, <vscale x 4 x i1> %799, <vscale x 4 x float> poison)
  %807 = trunc i64 %787 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 1, i32 %807, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %806)
  %808 = add i64 %787, 1
  br label %786

809:                                              ; preds = %812, %786
  %810 = phi i64 [ %831, %812 ], [ 0, %786 ]
  %811 = icmp slt i64 %810, %30
  br i1 %811, label %812, label %832

812:                                              ; preds = %809
  %813 = icmp slt i64 %810, %762
  %814 = sext i1 %813 to i32
  %815 = and i32 %814, %243
  %816 = sext i32 %815 to i64
  %817 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %818 = call i64 @llvm.smin.i64(i64 %816, i64 2147483647)
  %819 = trunc i64 %818 to i32
  %820 = insertelement <vscale x 4 x i32> poison, i32 %819, i32 0
  %821 = shufflevector <vscale x 4 x i32> %820, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %822 = icmp slt <vscale x 4 x i32> %817, %821
  %823 = add i64 %297, %810
  %824 = getelementptr float, ptr %15, i64 %77
  %825 = mul i64 %823, %19
  %826 = mul i64 %242, %20
  %827 = add i64 %825, %826
  %828 = getelementptr float, ptr %824, i64 %827
  %829 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %828, <vscale x 4 x i1> %822, <vscale x 4 x float> poison)
  %830 = trunc i64 %810 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 2, i32 %830, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %829)
  %831 = add i64 %810, 1
  br label %809

832:                                              ; preds = %835, %809
  %833 = phi i64 [ %854, %835 ], [ 0, %809 ]
  %834 = icmp slt i64 %833, %30
  br i1 %834, label %835, label %855

835:                                              ; preds = %832
  %836 = icmp slt i64 %833, %762
  %837 = sext i1 %836 to i32
  %838 = and i32 %837, %298
  %839 = sext i32 %838 to i64
  %840 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %841 = call i64 @llvm.smin.i64(i64 %839, i64 2147483647)
  %842 = trunc i64 %841 to i32
  %843 = insertelement <vscale x 4 x i32> poison, i32 %842, i32 0
  %844 = shufflevector <vscale x 4 x i32> %843, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %845 = icmp slt <vscale x 4 x i32> %840, %844
  %846 = add i64 %297, %833
  %847 = getelementptr float, ptr %15, i64 %77
  %848 = mul i64 %846, %19
  %849 = mul i64 %297, %20
  %850 = add i64 %848, %849
  %851 = getelementptr float, ptr %847, i64 %850
  %852 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %851, <vscale x 4 x i1> %845, <vscale x 4 x float> poison)
  %853 = trunc i64 %833 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 3, i32 %853, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %852)
  %854 = add i64 %833, 1
  br label %832

855:                                              ; preds = %832
  %856 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %97, i64 0)
  %857 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %120, i64 0)
  %858 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %859 = call i64 @llvm.smin.i64(i64 %61, i64 2147483647)
  %860 = trunc i64 %859 to i32
  %861 = insertelement <vscale x 4 x i32> poison, i32 %860, i32 0
  %862 = shufflevector <vscale x 4 x i32> %861, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %863 = icmp slt <vscale x 4 x i32> %858, %862
  %864 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %865 = call i64 @llvm.smin.i64(i64 %73, i64 2147483647)
  %866 = trunc i64 %865 to i32
  %867 = insertelement <vscale x 4 x i32> poison, i32 %866, i32 0
  %868 = shufflevector <vscale x 4 x i32> %867, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %869 = icmp slt <vscale x 4 x i32> %864, %868
  br label %870

870:                                              ; preds = %873, %855
  %871 = phi i64 [ %882, %873 ], [ 0, %855 ]
  %872 = icmp slt i64 %871, %30
  br i1 %872, label %873, label %883

873:                                              ; preds = %870
  %874 = trunc i64 %871 to i32
  %875 = mul i64 %871, %30
  %876 = add i64 %875, 0
  %877 = getelementptr float, ptr %54, i64 %876
  %878 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %874)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %877, i32 0, i32 %874)
  %879 = mul i64 %871, %30
  %880 = add i64 %879, 0
  %881 = getelementptr float, ptr %54, i64 %880
  store <vscale x 4 x float> %878, ptr %881, align 4
  %882 = add i64 %871, 1
  br label %870

883:                                              ; preds = %870
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %863, <vscale x 4 x i1> %869, <vscale x 4 x float> %856, <vscale x 4 x float> %857)
  br label %884

884:                                              ; preds = %887, %883
  %885 = phi i64 [ %896, %887 ], [ 0, %883 ]
  %886 = icmp slt i64 %885, %30
  br i1 %886, label %887, label %897

887:                                              ; preds = %884
  %888 = trunc i64 %885 to i32
  %889 = mul i64 %885, %30
  %890 = add i64 %889, 0
  %891 = getelementptr float, ptr %54, i64 %890
  %892 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %888)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %891, i32 0, i32 %888)
  %893 = mul i64 %885, %30
  %894 = add i64 %893, 0
  %895 = getelementptr float, ptr %54, i64 %894
  store <vscale x 4 x float> %892, ptr %895, align 4
  %896 = add i64 %885, 1
  br label %884

897:                                              ; preds = %884
  %898 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %120, i64 4)
  %899 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %900 = call i64 @llvm.smin.i64(i64 %187, i64 2147483647)
  %901 = trunc i64 %900 to i32
  %902 = insertelement <vscale x 4 x i32> poison, i32 %901, i32 0
  %903 = shufflevector <vscale x 4 x i32> %902, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %904 = icmp slt <vscale x 4 x i32> %899, %903
  br label %905

905:                                              ; preds = %908, %897
  %906 = phi i64 [ %917, %908 ], [ 0, %897 ]
  %907 = icmp slt i64 %906, %30
  br i1 %907, label %908, label %918

908:                                              ; preds = %905
  %909 = trunc i64 %906 to i32
  %910 = mul i64 %906, %30
  %911 = add i64 %910, 0
  %912 = getelementptr float, ptr %52, i64 %911
  %913 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %909)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %912, i32 0, i32 %909)
  %914 = mul i64 %906, %30
  %915 = add i64 %914, 0
  %916 = getelementptr float, ptr %52, i64 %915
  store <vscale x 4 x float> %913, ptr %916, align 4
  %917 = add i64 %906, 1
  br label %905

918:                                              ; preds = %905
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %863, <vscale x 4 x i1> %904, <vscale x 4 x float> %856, <vscale x 4 x float> %898)
  br label %919

919:                                              ; preds = %922, %918
  %920 = phi i64 [ %931, %922 ], [ 0, %918 ]
  %921 = icmp slt i64 %920, %30
  br i1 %921, label %922, label %932

922:                                              ; preds = %919
  %923 = trunc i64 %920 to i32
  %924 = mul i64 %920, %30
  %925 = add i64 %924, 0
  %926 = getelementptr float, ptr %52, i64 %925
  %927 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %923)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %926, i32 0, i32 %923)
  %928 = mul i64 %920, %30
  %929 = add i64 %928, 0
  %930 = getelementptr float, ptr %52, i64 %929
  store <vscale x 4 x float> %927, ptr %930, align 4
  %931 = add i64 %920, 1
  br label %919

932:                                              ; preds = %919
  %933 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %120, i64 8)
  %934 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %935 = call i64 @llvm.smin.i64(i64 %241, i64 2147483647)
  %936 = trunc i64 %935 to i32
  %937 = insertelement <vscale x 4 x i32> poison, i32 %936, i32 0
  %938 = shufflevector <vscale x 4 x i32> %937, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %939 = icmp slt <vscale x 4 x i32> %934, %938
  br label %940

940:                                              ; preds = %943, %932
  %941 = phi i64 [ %952, %943 ], [ 0, %932 ]
  %942 = icmp slt i64 %941, %30
  br i1 %942, label %943, label %953

943:                                              ; preds = %940
  %944 = trunc i64 %941 to i32
  %945 = mul i64 %941, %30
  %946 = add i64 %945, 0
  %947 = getelementptr float, ptr %50, i64 %946
  %948 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %944)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %947, i32 0, i32 %944)
  %949 = mul i64 %941, %30
  %950 = add i64 %949, 0
  %951 = getelementptr float, ptr %50, i64 %950
  store <vscale x 4 x float> %948, ptr %951, align 4
  %952 = add i64 %941, 1
  br label %940

953:                                              ; preds = %940
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %863, <vscale x 4 x i1> %939, <vscale x 4 x float> %856, <vscale x 4 x float> %933)
  br label %954

954:                                              ; preds = %957, %953
  %955 = phi i64 [ %966, %957 ], [ 0, %953 ]
  %956 = icmp slt i64 %955, %30
  br i1 %956, label %957, label %967

957:                                              ; preds = %954
  %958 = trunc i64 %955 to i32
  %959 = mul i64 %955, %30
  %960 = add i64 %959, 0
  %961 = getelementptr float, ptr %50, i64 %960
  %962 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %958)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %961, i32 0, i32 %958)
  %963 = mul i64 %955, %30
  %964 = add i64 %963, 0
  %965 = getelementptr float, ptr %50, i64 %964
  store <vscale x 4 x float> %962, ptr %965, align 4
  %966 = add i64 %955, 1
  br label %954

967:                                              ; preds = %954
  %968 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %120, i64 12)
  %969 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %970 = call i64 @llvm.smin.i64(i64 %296, i64 2147483647)
  %971 = trunc i64 %970 to i32
  %972 = insertelement <vscale x 4 x i32> poison, i32 %971, i32 0
  %973 = shufflevector <vscale x 4 x i32> %972, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %974 = icmp slt <vscale x 4 x i32> %969, %973
  br label %975

975:                                              ; preds = %978, %967
  %976 = phi i64 [ %987, %978 ], [ 0, %967 ]
  %977 = icmp slt i64 %976, %30
  br i1 %977, label %978, label %988

978:                                              ; preds = %975
  %979 = trunc i64 %976 to i32
  %980 = mul i64 %976, %30
  %981 = add i64 %980, 0
  %982 = getelementptr float, ptr %48, i64 %981
  %983 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %979)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %982, i32 0, i32 %979)
  %984 = mul i64 %976, %30
  %985 = add i64 %984, 0
  %986 = getelementptr float, ptr %48, i64 %985
  store <vscale x 4 x float> %983, ptr %986, align 4
  %987 = add i64 %976, 1
  br label %975

988:                                              ; preds = %975
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %863, <vscale x 4 x i1> %974, <vscale x 4 x float> %856, <vscale x 4 x float> %968)
  br label %989

989:                                              ; preds = %992, %988
  %990 = phi i64 [ %1001, %992 ], [ 0, %988 ]
  %991 = icmp slt i64 %990, %30
  br i1 %991, label %992, label %1002

992:                                              ; preds = %989
  %993 = trunc i64 %990 to i32
  %994 = mul i64 %990, %30
  %995 = add i64 %994, 0
  %996 = getelementptr float, ptr %48, i64 %995
  %997 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %993)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %996, i32 0, i32 %993)
  %998 = mul i64 %990, %30
  %999 = add i64 %998, 0
  %1000 = getelementptr float, ptr %48, i64 %999
  store <vscale x 4 x float> %997, ptr %1000, align 4
  %1001 = add i64 %990, 1
  br label %989

1002:                                             ; preds = %989
  %1003 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %97, i64 4)
  %1004 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %1005 = call i64 @llvm.smin.i64(i64 %350, i64 2147483647)
  %1006 = trunc i64 %1005 to i32
  %1007 = insertelement <vscale x 4 x i32> poison, i32 %1006, i32 0
  %1008 = shufflevector <vscale x 4 x i32> %1007, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %1009 = icmp slt <vscale x 4 x i32> %1004, %1008
  br label %1010

1010:                                             ; preds = %1013, %1002
  %1011 = phi i64 [ %1022, %1013 ], [ 0, %1002 ]
  %1012 = icmp slt i64 %1011, %30
  br i1 %1012, label %1013, label %1023

1013:                                             ; preds = %1010
  %1014 = trunc i64 %1011 to i32
  %1015 = mul i64 %1011, %30
  %1016 = add i64 %1015, 0
  %1017 = getelementptr float, ptr %46, i64 %1016
  %1018 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1014)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1017, i32 0, i32 %1014)
  %1019 = mul i64 %1011, %30
  %1020 = add i64 %1019, 0
  %1021 = getelementptr float, ptr %46, i64 %1020
  store <vscale x 4 x float> %1018, ptr %1021, align 4
  %1022 = add i64 %1011, 1
  br label %1010

1023:                                             ; preds = %1010
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1009, <vscale x 4 x i1> %869, <vscale x 4 x float> %1003, <vscale x 4 x float> %857)
  br label %1024

1024:                                             ; preds = %1027, %1023
  %1025 = phi i64 [ %1036, %1027 ], [ 0, %1023 ]
  %1026 = icmp slt i64 %1025, %30
  br i1 %1026, label %1027, label %1037

1027:                                             ; preds = %1024
  %1028 = trunc i64 %1025 to i32
  %1029 = mul i64 %1025, %30
  %1030 = add i64 %1029, 0
  %1031 = getelementptr float, ptr %46, i64 %1030
  %1032 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1028)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1031, i32 0, i32 %1028)
  %1033 = mul i64 %1025, %30
  %1034 = add i64 %1033, 0
  %1035 = getelementptr float, ptr %46, i64 %1034
  store <vscale x 4 x float> %1032, ptr %1035, align 4
  %1036 = add i64 %1025, 1
  br label %1024

1037:                                             ; preds = %1040, %1024
  %1038 = phi i64 [ %1049, %1040 ], [ 0, %1024 ]
  %1039 = icmp slt i64 %1038, %30
  br i1 %1039, label %1040, label %1050

1040:                                             ; preds = %1037
  %1041 = trunc i64 %1038 to i32
  %1042 = mul i64 %1038, %30
  %1043 = add i64 %1042, 0
  %1044 = getelementptr float, ptr %44, i64 %1043
  %1045 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1041)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1044, i32 0, i32 %1041)
  %1046 = mul i64 %1038, %30
  %1047 = add i64 %1046, 0
  %1048 = getelementptr float, ptr %44, i64 %1047
  store <vscale x 4 x float> %1045, ptr %1048, align 4
  %1049 = add i64 %1038, 1
  br label %1037

1050:                                             ; preds = %1037
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1009, <vscale x 4 x i1> %904, <vscale x 4 x float> %1003, <vscale x 4 x float> %898)
  br label %1051

1051:                                             ; preds = %1054, %1050
  %1052 = phi i64 [ %1063, %1054 ], [ 0, %1050 ]
  %1053 = icmp slt i64 %1052, %30
  br i1 %1053, label %1054, label %1064

1054:                                             ; preds = %1051
  %1055 = trunc i64 %1052 to i32
  %1056 = mul i64 %1052, %30
  %1057 = add i64 %1056, 0
  %1058 = getelementptr float, ptr %44, i64 %1057
  %1059 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1055)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1058, i32 0, i32 %1055)
  %1060 = mul i64 %1052, %30
  %1061 = add i64 %1060, 0
  %1062 = getelementptr float, ptr %44, i64 %1061
  store <vscale x 4 x float> %1059, ptr %1062, align 4
  %1063 = add i64 %1052, 1
  br label %1051

1064:                                             ; preds = %1067, %1051
  %1065 = phi i64 [ %1076, %1067 ], [ 0, %1051 ]
  %1066 = icmp slt i64 %1065, %30
  br i1 %1066, label %1067, label %1077

1067:                                             ; preds = %1064
  %1068 = trunc i64 %1065 to i32
  %1069 = mul i64 %1065, %30
  %1070 = add i64 %1069, 0
  %1071 = getelementptr float, ptr %42, i64 %1070
  %1072 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1068)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1071, i32 0, i32 %1068)
  %1073 = mul i64 %1065, %30
  %1074 = add i64 %1073, 0
  %1075 = getelementptr float, ptr %42, i64 %1074
  store <vscale x 4 x float> %1072, ptr %1075, align 4
  %1076 = add i64 %1065, 1
  br label %1064

1077:                                             ; preds = %1064
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1009, <vscale x 4 x i1> %939, <vscale x 4 x float> %1003, <vscale x 4 x float> %933)
  br label %1078

1078:                                             ; preds = %1081, %1077
  %1079 = phi i64 [ %1090, %1081 ], [ 0, %1077 ]
  %1080 = icmp slt i64 %1079, %30
  br i1 %1080, label %1081, label %1091

1081:                                             ; preds = %1078
  %1082 = trunc i64 %1079 to i32
  %1083 = mul i64 %1079, %30
  %1084 = add i64 %1083, 0
  %1085 = getelementptr float, ptr %42, i64 %1084
  %1086 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1082)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1085, i32 0, i32 %1082)
  %1087 = mul i64 %1079, %30
  %1088 = add i64 %1087, 0
  %1089 = getelementptr float, ptr %42, i64 %1088
  store <vscale x 4 x float> %1086, ptr %1089, align 4
  %1090 = add i64 %1079, 1
  br label %1078

1091:                                             ; preds = %1094, %1078
  %1092 = phi i64 [ %1103, %1094 ], [ 0, %1078 ]
  %1093 = icmp slt i64 %1092, %30
  br i1 %1093, label %1094, label %1104

1094:                                             ; preds = %1091
  %1095 = trunc i64 %1092 to i32
  %1096 = mul i64 %1092, %30
  %1097 = add i64 %1096, 0
  %1098 = getelementptr float, ptr %40, i64 %1097
  %1099 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1095)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1098, i32 0, i32 %1095)
  %1100 = mul i64 %1092, %30
  %1101 = add i64 %1100, 0
  %1102 = getelementptr float, ptr %40, i64 %1101
  store <vscale x 4 x float> %1099, ptr %1102, align 4
  %1103 = add i64 %1092, 1
  br label %1091

1104:                                             ; preds = %1091
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1009, <vscale x 4 x i1> %974, <vscale x 4 x float> %1003, <vscale x 4 x float> %968)
  br label %1105

1105:                                             ; preds = %1108, %1104
  %1106 = phi i64 [ %1117, %1108 ], [ 0, %1104 ]
  %1107 = icmp slt i64 %1106, %30
  br i1 %1107, label %1108, label %1118

1108:                                             ; preds = %1105
  %1109 = trunc i64 %1106 to i32
  %1110 = mul i64 %1106, %30
  %1111 = add i64 %1110, 0
  %1112 = getelementptr float, ptr %40, i64 %1111
  %1113 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1109)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1112, i32 0, i32 %1109)
  %1114 = mul i64 %1106, %30
  %1115 = add i64 %1114, 0
  %1116 = getelementptr float, ptr %40, i64 %1115
  store <vscale x 4 x float> %1113, ptr %1116, align 4
  %1117 = add i64 %1106, 1
  br label %1105

1118:                                             ; preds = %1105
  %1119 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %97, i64 8)
  %1120 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %1121 = call i64 @llvm.smin.i64(i64 %556, i64 2147483647)
  %1122 = trunc i64 %1121 to i32
  %1123 = insertelement <vscale x 4 x i32> poison, i32 %1122, i32 0
  %1124 = shufflevector <vscale x 4 x i32> %1123, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %1125 = icmp slt <vscale x 4 x i32> %1120, %1124
  br label %1126

1126:                                             ; preds = %1129, %1118
  %1127 = phi i64 [ %1138, %1129 ], [ 0, %1118 ]
  %1128 = icmp slt i64 %1127, %30
  br i1 %1128, label %1129, label %1139

1129:                                             ; preds = %1126
  %1130 = trunc i64 %1127 to i32
  %1131 = mul i64 %1127, %30
  %1132 = add i64 %1131, 0
  %1133 = getelementptr float, ptr %38, i64 %1132
  %1134 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1130)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1133, i32 0, i32 %1130)
  %1135 = mul i64 %1127, %30
  %1136 = add i64 %1135, 0
  %1137 = getelementptr float, ptr %38, i64 %1136
  store <vscale x 4 x float> %1134, ptr %1137, align 4
  %1138 = add i64 %1127, 1
  br label %1126

1139:                                             ; preds = %1126
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1125, <vscale x 4 x i1> %869, <vscale x 4 x float> %1119, <vscale x 4 x float> %857)
  br label %1140

1140:                                             ; preds = %1143, %1139
  %1141 = phi i64 [ %1152, %1143 ], [ 0, %1139 ]
  %1142 = icmp slt i64 %1141, %30
  br i1 %1142, label %1143, label %1153

1143:                                             ; preds = %1140
  %1144 = trunc i64 %1141 to i32
  %1145 = mul i64 %1141, %30
  %1146 = add i64 %1145, 0
  %1147 = getelementptr float, ptr %38, i64 %1146
  %1148 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1144)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1147, i32 0, i32 %1144)
  %1149 = mul i64 %1141, %30
  %1150 = add i64 %1149, 0
  %1151 = getelementptr float, ptr %38, i64 %1150
  store <vscale x 4 x float> %1148, ptr %1151, align 4
  %1152 = add i64 %1141, 1
  br label %1140

1153:                                             ; preds = %1156, %1140
  %1154 = phi i64 [ %1165, %1156 ], [ 0, %1140 ]
  %1155 = icmp slt i64 %1154, %30
  br i1 %1155, label %1156, label %1166

1156:                                             ; preds = %1153
  %1157 = trunc i64 %1154 to i32
  %1158 = mul i64 %1154, %30
  %1159 = add i64 %1158, 0
  %1160 = getelementptr float, ptr %36, i64 %1159
  %1161 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1157)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1160, i32 0, i32 %1157)
  %1162 = mul i64 %1154, %30
  %1163 = add i64 %1162, 0
  %1164 = getelementptr float, ptr %36, i64 %1163
  store <vscale x 4 x float> %1161, ptr %1164, align 4
  %1165 = add i64 %1154, 1
  br label %1153

1166:                                             ; preds = %1153
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1125, <vscale x 4 x i1> %904, <vscale x 4 x float> %1119, <vscale x 4 x float> %898)
  br label %1167

1167:                                             ; preds = %1170, %1166
  %1168 = phi i64 [ %1179, %1170 ], [ 0, %1166 ]
  %1169 = icmp slt i64 %1168, %30
  br i1 %1169, label %1170, label %1180

1170:                                             ; preds = %1167
  %1171 = trunc i64 %1168 to i32
  %1172 = mul i64 %1168, %30
  %1173 = add i64 %1172, 0
  %1174 = getelementptr float, ptr %36, i64 %1173
  %1175 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1171)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1174, i32 0, i32 %1171)
  %1176 = mul i64 %1168, %30
  %1177 = add i64 %1176, 0
  %1178 = getelementptr float, ptr %36, i64 %1177
  store <vscale x 4 x float> %1175, ptr %1178, align 4
  %1179 = add i64 %1168, 1
  br label %1167

1180:                                             ; preds = %1183, %1167
  %1181 = phi i64 [ %1192, %1183 ], [ 0, %1167 ]
  %1182 = icmp slt i64 %1181, %30
  br i1 %1182, label %1183, label %1193

1183:                                             ; preds = %1180
  %1184 = trunc i64 %1181 to i32
  %1185 = mul i64 %1181, %30
  %1186 = add i64 %1185, 0
  %1187 = getelementptr float, ptr %34, i64 %1186
  %1188 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1184)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1187, i32 0, i32 %1184)
  %1189 = mul i64 %1181, %30
  %1190 = add i64 %1189, 0
  %1191 = getelementptr float, ptr %34, i64 %1190
  store <vscale x 4 x float> %1188, ptr %1191, align 4
  %1192 = add i64 %1181, 1
  br label %1180

1193:                                             ; preds = %1180
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1125, <vscale x 4 x i1> %939, <vscale x 4 x float> %1119, <vscale x 4 x float> %933)
  br label %1194

1194:                                             ; preds = %1197, %1193
  %1195 = phi i64 [ %1206, %1197 ], [ 0, %1193 ]
  %1196 = icmp slt i64 %1195, %30
  br i1 %1196, label %1197, label %1207

1197:                                             ; preds = %1194
  %1198 = trunc i64 %1195 to i32
  %1199 = mul i64 %1195, %30
  %1200 = add i64 %1199, 0
  %1201 = getelementptr float, ptr %34, i64 %1200
  %1202 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1198)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1201, i32 0, i32 %1198)
  %1203 = mul i64 %1195, %30
  %1204 = add i64 %1203, 0
  %1205 = getelementptr float, ptr %34, i64 %1204
  store <vscale x 4 x float> %1202, ptr %1205, align 4
  %1206 = add i64 %1195, 1
  br label %1194

1207:                                             ; preds = %1210, %1194
  %1208 = phi i64 [ %1219, %1210 ], [ 0, %1194 ]
  %1209 = icmp slt i64 %1208, %30
  br i1 %1209, label %1210, label %1220

1210:                                             ; preds = %1207
  %1211 = trunc i64 %1208 to i32
  %1212 = mul i64 %1208, %30
  %1213 = add i64 %1212, 0
  %1214 = getelementptr float, ptr %32, i64 %1213
  %1215 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1211)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1214, i32 0, i32 %1211)
  %1216 = mul i64 %1208, %30
  %1217 = add i64 %1216, 0
  %1218 = getelementptr float, ptr %32, i64 %1217
  store <vscale x 4 x float> %1215, ptr %1218, align 4
  %1219 = add i64 %1208, 1
  br label %1207

1220:                                             ; preds = %1207
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1125, <vscale x 4 x i1> %974, <vscale x 4 x float> %1119, <vscale x 4 x float> %968)
  br label %1221

1221:                                             ; preds = %1224, %1220
  %1222 = phi i64 [ %1233, %1224 ], [ 0, %1220 ]
  %1223 = icmp slt i64 %1222, %30
  br i1 %1223, label %1224, label %1234

1224:                                             ; preds = %1221
  %1225 = trunc i64 %1222 to i32
  %1226 = mul i64 %1222, %30
  %1227 = add i64 %1226, 0
  %1228 = getelementptr float, ptr %32, i64 %1227
  %1229 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1225)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1228, i32 0, i32 %1225)
  %1230 = mul i64 %1222, %30
  %1231 = add i64 %1230, 0
  %1232 = getelementptr float, ptr %32, i64 %1231
  store <vscale x 4 x float> %1229, ptr %1232, align 4
  %1233 = add i64 %1222, 1
  br label %1221

1234:                                             ; preds = %1221
  %1235 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %97, i64 12)
  %1236 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %1237 = call i64 @llvm.smin.i64(i64 %762, i64 2147483647)
  %1238 = trunc i64 %1237 to i32
  %1239 = insertelement <vscale x 4 x i32> poison, i32 %1238, i32 0
  %1240 = shufflevector <vscale x 4 x i32> %1239, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %1241 = icmp slt <vscale x 4 x i32> %1236, %1240
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1241, <vscale x 4 x i1> %869, <vscale x 4 x float> %1235, <vscale x 4 x float> %857)
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 1, <vscale x 4 x i1> %1241, <vscale x 4 x i1> %904, <vscale x 4 x float> %1235, <vscale x 4 x float> %898)
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 2, <vscale x 4 x i1> %1241, <vscale x 4 x i1> %939, <vscale x 4 x float> %1235, <vscale x 4 x float> %933)
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 3, <vscale x 4 x i1> %1241, <vscale x 4 x i1> %974, <vscale x 4 x float> %1235, <vscale x 4 x float> %968)
  br label %1242

1242:                                             ; preds = %1640, %1234
  %1243 = phi i64 [ %1659, %1640 ], [ 0, %1234 ]
  %1244 = icmp slt i64 %1243, %30
  br i1 %1244, label %1245, label %1660

1245:                                             ; preds = %1242
  %1246 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1> %83)
  %1247 = trunc i64 %1243 to i32
  %1248 = call <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1> %1246, <vscale x 16 x i1> %67, i32 %1247)
  %1249 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1> %1248)
  %1250 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1249, i64 0)
  br label %1251

1251:                                             ; preds = %1254, %1245
  %1252 = phi i64 [ %1263, %1254 ], [ 0, %1245 ]
  %1253 = icmp slt i64 %1252, %30
  br i1 %1253, label %1254, label %1264

1254:                                             ; preds = %1251
  %1255 = trunc i64 %1252 to i32
  %1256 = mul i64 %1252, %30
  %1257 = add i64 %1256, 0
  %1258 = getelementptr float, ptr %54, i64 %1257
  %1259 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1255)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1258, i32 0, i32 %1255)
  %1260 = mul i64 %1252, %30
  %1261 = add i64 %1260, 0
  %1262 = getelementptr float, ptr %54, i64 %1261
  store <vscale x 4 x float> %1259, ptr %1262, align 4
  %1263 = add i64 %1252, 1
  br label %1251

1264:                                             ; preds = %1251
  %1265 = getelementptr float, ptr %15, i64 %77
  %1266 = mul i64 %1243, %19
  %1267 = mul i64 %20, 0
  %1268 = add i64 %1266, %1267
  %1269 = getelementptr float, ptr %1265, i64 %1268
  %1270 = trunc i64 %1243 to i32
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1250, ptr %1269, i32 0, i32 %1270)
  br label %1271

1271:                                             ; preds = %1274, %1264
  %1272 = phi i64 [ %1283, %1274 ], [ 0, %1264 ]
  %1273 = icmp slt i64 %1272, %30
  br i1 %1273, label %1274, label %1284

1274:                                             ; preds = %1271
  %1275 = trunc i64 %1272 to i32
  %1276 = mul i64 %1272, %30
  %1277 = add i64 %1276, 0
  %1278 = getelementptr float, ptr %54, i64 %1277
  %1279 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1275)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1278, i32 0, i32 %1275)
  %1280 = mul i64 %1272, %30
  %1281 = add i64 %1280, 0
  %1282 = getelementptr float, ptr %54, i64 %1281
  store <vscale x 4 x float> %1279, ptr %1282, align 4
  %1283 = add i64 %1272, 1
  br label %1271

1284:                                             ; preds = %1271
  %1285 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1249, i64 4)
  br label %1286

1286:                                             ; preds = %1289, %1284
  %1287 = phi i64 [ %1298, %1289 ], [ 0, %1284 ]
  %1288 = icmp slt i64 %1287, %30
  br i1 %1288, label %1289, label %1299

1289:                                             ; preds = %1286
  %1290 = trunc i64 %1287 to i32
  %1291 = mul i64 %1287, %30
  %1292 = add i64 %1291, 0
  %1293 = getelementptr float, ptr %52, i64 %1292
  %1294 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1290)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1293, i32 0, i32 %1290)
  %1295 = mul i64 %1287, %30
  %1296 = add i64 %1295, 0
  %1297 = getelementptr float, ptr %52, i64 %1296
  store <vscale x 4 x float> %1294, ptr %1297, align 4
  %1298 = add i64 %1287, 1
  br label %1286

1299:                                             ; preds = %1286
  %1300 = mul i64 %30, %20
  %1301 = add i64 %1266, %1300
  %1302 = getelementptr float, ptr %1265, i64 %1301
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1285, ptr %1302, i32 0, i32 %1270)
  br label %1303

1303:                                             ; preds = %1306, %1299
  %1304 = phi i64 [ %1315, %1306 ], [ 0, %1299 ]
  %1305 = icmp slt i64 %1304, %30
  br i1 %1305, label %1306, label %1316

1306:                                             ; preds = %1303
  %1307 = trunc i64 %1304 to i32
  %1308 = mul i64 %1304, %30
  %1309 = add i64 %1308, 0
  %1310 = getelementptr float, ptr %52, i64 %1309
  %1311 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1307)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1310, i32 0, i32 %1307)
  %1312 = mul i64 %1304, %30
  %1313 = add i64 %1312, 0
  %1314 = getelementptr float, ptr %52, i64 %1313
  store <vscale x 4 x float> %1311, ptr %1314, align 4
  %1315 = add i64 %1304, 1
  br label %1303

1316:                                             ; preds = %1303
  %1317 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1249, i64 8)
  br label %1318

1318:                                             ; preds = %1321, %1316
  %1319 = phi i64 [ %1330, %1321 ], [ 0, %1316 ]
  %1320 = icmp slt i64 %1319, %30
  br i1 %1320, label %1321, label %1331

1321:                                             ; preds = %1318
  %1322 = trunc i64 %1319 to i32
  %1323 = mul i64 %1319, %30
  %1324 = add i64 %1323, 0
  %1325 = getelementptr float, ptr %50, i64 %1324
  %1326 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1322)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1325, i32 0, i32 %1322)
  %1327 = mul i64 %1319, %30
  %1328 = add i64 %1327, 0
  %1329 = getelementptr float, ptr %50, i64 %1328
  store <vscale x 4 x float> %1326, ptr %1329, align 4
  %1330 = add i64 %1319, 1
  br label %1318

1331:                                             ; preds = %1318
  %1332 = mul i64 %242, %20
  %1333 = add i64 %1266, %1332
  %1334 = getelementptr float, ptr %1265, i64 %1333
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1317, ptr %1334, i32 0, i32 %1270)
  br label %1335

1335:                                             ; preds = %1338, %1331
  %1336 = phi i64 [ %1347, %1338 ], [ 0, %1331 ]
  %1337 = icmp slt i64 %1336, %30
  br i1 %1337, label %1338, label %1348

1338:                                             ; preds = %1335
  %1339 = trunc i64 %1336 to i32
  %1340 = mul i64 %1336, %30
  %1341 = add i64 %1340, 0
  %1342 = getelementptr float, ptr %50, i64 %1341
  %1343 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1339)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1342, i32 0, i32 %1339)
  %1344 = mul i64 %1336, %30
  %1345 = add i64 %1344, 0
  %1346 = getelementptr float, ptr %50, i64 %1345
  store <vscale x 4 x float> %1343, ptr %1346, align 4
  %1347 = add i64 %1336, 1
  br label %1335

1348:                                             ; preds = %1335
  %1349 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1249, i64 12)
  br label %1350

1350:                                             ; preds = %1353, %1348
  %1351 = phi i64 [ %1362, %1353 ], [ 0, %1348 ]
  %1352 = icmp slt i64 %1351, %30
  br i1 %1352, label %1353, label %1363

1353:                                             ; preds = %1350
  %1354 = trunc i64 %1351 to i32
  %1355 = mul i64 %1351, %30
  %1356 = add i64 %1355, 0
  %1357 = getelementptr float, ptr %48, i64 %1356
  %1358 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1354)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1357, i32 0, i32 %1354)
  %1359 = mul i64 %1351, %30
  %1360 = add i64 %1359, 0
  %1361 = getelementptr float, ptr %48, i64 %1360
  store <vscale x 4 x float> %1358, ptr %1361, align 4
  %1362 = add i64 %1351, 1
  br label %1350

1363:                                             ; preds = %1350
  %1364 = mul i64 %297, %20
  %1365 = add i64 %1266, %1364
  %1366 = getelementptr float, ptr %1265, i64 %1365
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1349, ptr %1366, i32 0, i32 %1270)
  br label %1367

1367:                                             ; preds = %1370, %1363
  %1368 = phi i64 [ %1379, %1370 ], [ 0, %1363 ]
  %1369 = icmp slt i64 %1368, %30
  br i1 %1369, label %1370, label %1380

1370:                                             ; preds = %1367
  %1371 = trunc i64 %1368 to i32
  %1372 = mul i64 %1368, %30
  %1373 = add i64 %1372, 0
  %1374 = getelementptr float, ptr %48, i64 %1373
  %1375 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1371)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1374, i32 0, i32 %1371)
  %1376 = mul i64 %1368, %30
  %1377 = add i64 %1376, 0
  %1378 = getelementptr float, ptr %48, i64 %1377
  store <vscale x 4 x float> %1375, ptr %1378, align 4
  %1379 = add i64 %1368, 1
  br label %1367

1380:                                             ; preds = %1367
  %1381 = add i64 %30, %1243
  %1382 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1> %83)
  %1383 = trunc i64 %1381 to i32
  %1384 = call <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1> %1382, <vscale x 16 x i1> %67, i32 %1383)
  %1385 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1> %1384)
  %1386 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1385, i64 0)
  br label %1387

1387:                                             ; preds = %1390, %1380
  %1388 = phi i64 [ %1399, %1390 ], [ 0, %1380 ]
  %1389 = icmp slt i64 %1388, %30
  br i1 %1389, label %1390, label %1400

1390:                                             ; preds = %1387
  %1391 = trunc i64 %1388 to i32
  %1392 = mul i64 %1388, %30
  %1393 = add i64 %1392, 0
  %1394 = getelementptr float, ptr %46, i64 %1393
  %1395 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1391)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1394, i32 0, i32 %1391)
  %1396 = mul i64 %1388, %30
  %1397 = add i64 %1396, 0
  %1398 = getelementptr float, ptr %46, i64 %1397
  store <vscale x 4 x float> %1395, ptr %1398, align 4
  %1399 = add i64 %1388, 1
  br label %1387

1400:                                             ; preds = %1387
  %1401 = mul i64 %1381, %19
  %1402 = add i64 %1401, %1267
  %1403 = getelementptr float, ptr %1265, i64 %1402
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1386, ptr %1403, i32 0, i32 %1270)
  br label %1404

1404:                                             ; preds = %1407, %1400
  %1405 = phi i64 [ %1416, %1407 ], [ 0, %1400 ]
  %1406 = icmp slt i64 %1405, %30
  br i1 %1406, label %1407, label %1417

1407:                                             ; preds = %1404
  %1408 = trunc i64 %1405 to i32
  %1409 = mul i64 %1405, %30
  %1410 = add i64 %1409, 0
  %1411 = getelementptr float, ptr %46, i64 %1410
  %1412 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1408)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1411, i32 0, i32 %1408)
  %1413 = mul i64 %1405, %30
  %1414 = add i64 %1413, 0
  %1415 = getelementptr float, ptr %46, i64 %1414
  store <vscale x 4 x float> %1412, ptr %1415, align 4
  %1416 = add i64 %1405, 1
  br label %1404

1417:                                             ; preds = %1404
  %1418 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1385, i64 4)
  br label %1419

1419:                                             ; preds = %1422, %1417
  %1420 = phi i64 [ %1431, %1422 ], [ 0, %1417 ]
  %1421 = icmp slt i64 %1420, %30
  br i1 %1421, label %1422, label %1432

1422:                                             ; preds = %1419
  %1423 = trunc i64 %1420 to i32
  %1424 = mul i64 %1420, %30
  %1425 = add i64 %1424, 0
  %1426 = getelementptr float, ptr %44, i64 %1425
  %1427 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1423)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1426, i32 0, i32 %1423)
  %1428 = mul i64 %1420, %30
  %1429 = add i64 %1428, 0
  %1430 = getelementptr float, ptr %44, i64 %1429
  store <vscale x 4 x float> %1427, ptr %1430, align 4
  %1431 = add i64 %1420, 1
  br label %1419

1432:                                             ; preds = %1419
  %1433 = add i64 %1401, %1300
  %1434 = getelementptr float, ptr %1265, i64 %1433
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1418, ptr %1434, i32 0, i32 %1270)
  br label %1435

1435:                                             ; preds = %1438, %1432
  %1436 = phi i64 [ %1447, %1438 ], [ 0, %1432 ]
  %1437 = icmp slt i64 %1436, %30
  br i1 %1437, label %1438, label %1448

1438:                                             ; preds = %1435
  %1439 = trunc i64 %1436 to i32
  %1440 = mul i64 %1436, %30
  %1441 = add i64 %1440, 0
  %1442 = getelementptr float, ptr %44, i64 %1441
  %1443 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1439)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1442, i32 0, i32 %1439)
  %1444 = mul i64 %1436, %30
  %1445 = add i64 %1444, 0
  %1446 = getelementptr float, ptr %44, i64 %1445
  store <vscale x 4 x float> %1443, ptr %1446, align 4
  %1447 = add i64 %1436, 1
  br label %1435

1448:                                             ; preds = %1435
  %1449 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1385, i64 8)
  br label %1450

1450:                                             ; preds = %1453, %1448
  %1451 = phi i64 [ %1462, %1453 ], [ 0, %1448 ]
  %1452 = icmp slt i64 %1451, %30
  br i1 %1452, label %1453, label %1463

1453:                                             ; preds = %1450
  %1454 = trunc i64 %1451 to i32
  %1455 = mul i64 %1451, %30
  %1456 = add i64 %1455, 0
  %1457 = getelementptr float, ptr %42, i64 %1456
  %1458 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1454)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1457, i32 0, i32 %1454)
  %1459 = mul i64 %1451, %30
  %1460 = add i64 %1459, 0
  %1461 = getelementptr float, ptr %42, i64 %1460
  store <vscale x 4 x float> %1458, ptr %1461, align 4
  %1462 = add i64 %1451, 1
  br label %1450

1463:                                             ; preds = %1450
  %1464 = add i64 %1401, %1332
  %1465 = getelementptr float, ptr %1265, i64 %1464
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1449, ptr %1465, i32 0, i32 %1270)
  br label %1466

1466:                                             ; preds = %1469, %1463
  %1467 = phi i64 [ %1478, %1469 ], [ 0, %1463 ]
  %1468 = icmp slt i64 %1467, %30
  br i1 %1468, label %1469, label %1479

1469:                                             ; preds = %1466
  %1470 = trunc i64 %1467 to i32
  %1471 = mul i64 %1467, %30
  %1472 = add i64 %1471, 0
  %1473 = getelementptr float, ptr %42, i64 %1472
  %1474 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1470)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1473, i32 0, i32 %1470)
  %1475 = mul i64 %1467, %30
  %1476 = add i64 %1475, 0
  %1477 = getelementptr float, ptr %42, i64 %1476
  store <vscale x 4 x float> %1474, ptr %1477, align 4
  %1478 = add i64 %1467, 1
  br label %1466

1479:                                             ; preds = %1466
  %1480 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1385, i64 12)
  br label %1481

1481:                                             ; preds = %1484, %1479
  %1482 = phi i64 [ %1493, %1484 ], [ 0, %1479 ]
  %1483 = icmp slt i64 %1482, %30
  br i1 %1483, label %1484, label %1494

1484:                                             ; preds = %1481
  %1485 = trunc i64 %1482 to i32
  %1486 = mul i64 %1482, %30
  %1487 = add i64 %1486, 0
  %1488 = getelementptr float, ptr %40, i64 %1487
  %1489 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1485)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1488, i32 0, i32 %1485)
  %1490 = mul i64 %1482, %30
  %1491 = add i64 %1490, 0
  %1492 = getelementptr float, ptr %40, i64 %1491
  store <vscale x 4 x float> %1489, ptr %1492, align 4
  %1493 = add i64 %1482, 1
  br label %1481

1494:                                             ; preds = %1481
  %1495 = add i64 %1401, %1364
  %1496 = getelementptr float, ptr %1265, i64 %1495
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1480, ptr %1496, i32 0, i32 %1270)
  br label %1497

1497:                                             ; preds = %1500, %1494
  %1498 = phi i64 [ %1509, %1500 ], [ 0, %1494 ]
  %1499 = icmp slt i64 %1498, %30
  br i1 %1499, label %1500, label %1510

1500:                                             ; preds = %1497
  %1501 = trunc i64 %1498 to i32
  %1502 = mul i64 %1498, %30
  %1503 = add i64 %1502, 0
  %1504 = getelementptr float, ptr %40, i64 %1503
  %1505 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1501)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1504, i32 0, i32 %1501)
  %1506 = mul i64 %1498, %30
  %1507 = add i64 %1506, 0
  %1508 = getelementptr float, ptr %40, i64 %1507
  store <vscale x 4 x float> %1505, ptr %1508, align 4
  %1509 = add i64 %1498, 1
  br label %1497

1510:                                             ; preds = %1497
  %1511 = add i64 %242, %1243
  %1512 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1> %83)
  %1513 = trunc i64 %1511 to i32
  %1514 = call <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1> %1512, <vscale x 16 x i1> %67, i32 %1513)
  %1515 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1> %1514)
  %1516 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1515, i64 0)
  br label %1517

1517:                                             ; preds = %1520, %1510
  %1518 = phi i64 [ %1529, %1520 ], [ 0, %1510 ]
  %1519 = icmp slt i64 %1518, %30
  br i1 %1519, label %1520, label %1530

1520:                                             ; preds = %1517
  %1521 = trunc i64 %1518 to i32
  %1522 = mul i64 %1518, %30
  %1523 = add i64 %1522, 0
  %1524 = getelementptr float, ptr %38, i64 %1523
  %1525 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1521)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1524, i32 0, i32 %1521)
  %1526 = mul i64 %1518, %30
  %1527 = add i64 %1526, 0
  %1528 = getelementptr float, ptr %38, i64 %1527
  store <vscale x 4 x float> %1525, ptr %1528, align 4
  %1529 = add i64 %1518, 1
  br label %1517

1530:                                             ; preds = %1517
  %1531 = mul i64 %1511, %19
  %1532 = add i64 %1531, %1267
  %1533 = getelementptr float, ptr %1265, i64 %1532
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1516, ptr %1533, i32 0, i32 %1270)
  br label %1534

1534:                                             ; preds = %1537, %1530
  %1535 = phi i64 [ %1546, %1537 ], [ 0, %1530 ]
  %1536 = icmp slt i64 %1535, %30
  br i1 %1536, label %1537, label %1547

1537:                                             ; preds = %1534
  %1538 = trunc i64 %1535 to i32
  %1539 = mul i64 %1535, %30
  %1540 = add i64 %1539, 0
  %1541 = getelementptr float, ptr %38, i64 %1540
  %1542 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1538)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1541, i32 0, i32 %1538)
  %1543 = mul i64 %1535, %30
  %1544 = add i64 %1543, 0
  %1545 = getelementptr float, ptr %38, i64 %1544
  store <vscale x 4 x float> %1542, ptr %1545, align 4
  %1546 = add i64 %1535, 1
  br label %1534

1547:                                             ; preds = %1534
  %1548 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1515, i64 4)
  br label %1549

1549:                                             ; preds = %1552, %1547
  %1550 = phi i64 [ %1561, %1552 ], [ 0, %1547 ]
  %1551 = icmp slt i64 %1550, %30
  br i1 %1551, label %1552, label %1562

1552:                                             ; preds = %1549
  %1553 = trunc i64 %1550 to i32
  %1554 = mul i64 %1550, %30
  %1555 = add i64 %1554, 0
  %1556 = getelementptr float, ptr %36, i64 %1555
  %1557 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1553)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1556, i32 0, i32 %1553)
  %1558 = mul i64 %1550, %30
  %1559 = add i64 %1558, 0
  %1560 = getelementptr float, ptr %36, i64 %1559
  store <vscale x 4 x float> %1557, ptr %1560, align 4
  %1561 = add i64 %1550, 1
  br label %1549

1562:                                             ; preds = %1549
  %1563 = add i64 %1531, %1300
  %1564 = getelementptr float, ptr %1265, i64 %1563
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1548, ptr %1564, i32 0, i32 %1270)
  br label %1565

1565:                                             ; preds = %1568, %1562
  %1566 = phi i64 [ %1577, %1568 ], [ 0, %1562 ]
  %1567 = icmp slt i64 %1566, %30
  br i1 %1567, label %1568, label %1578

1568:                                             ; preds = %1565
  %1569 = trunc i64 %1566 to i32
  %1570 = mul i64 %1566, %30
  %1571 = add i64 %1570, 0
  %1572 = getelementptr float, ptr %36, i64 %1571
  %1573 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1569)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1572, i32 0, i32 %1569)
  %1574 = mul i64 %1566, %30
  %1575 = add i64 %1574, 0
  %1576 = getelementptr float, ptr %36, i64 %1575
  store <vscale x 4 x float> %1573, ptr %1576, align 4
  %1577 = add i64 %1566, 1
  br label %1565

1578:                                             ; preds = %1565
  %1579 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1515, i64 8)
  br label %1580

1580:                                             ; preds = %1583, %1578
  %1581 = phi i64 [ %1592, %1583 ], [ 0, %1578 ]
  %1582 = icmp slt i64 %1581, %30
  br i1 %1582, label %1583, label %1593

1583:                                             ; preds = %1580
  %1584 = trunc i64 %1581 to i32
  %1585 = mul i64 %1581, %30
  %1586 = add i64 %1585, 0
  %1587 = getelementptr float, ptr %34, i64 %1586
  %1588 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1584)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1587, i32 0, i32 %1584)
  %1589 = mul i64 %1581, %30
  %1590 = add i64 %1589, 0
  %1591 = getelementptr float, ptr %34, i64 %1590
  store <vscale x 4 x float> %1588, ptr %1591, align 4
  %1592 = add i64 %1581, 1
  br label %1580

1593:                                             ; preds = %1580
  %1594 = add i64 %1531, %1332
  %1595 = getelementptr float, ptr %1265, i64 %1594
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1579, ptr %1595, i32 0, i32 %1270)
  br label %1596

1596:                                             ; preds = %1599, %1593
  %1597 = phi i64 [ %1608, %1599 ], [ 0, %1593 ]
  %1598 = icmp slt i64 %1597, %30
  br i1 %1598, label %1599, label %1609

1599:                                             ; preds = %1596
  %1600 = trunc i64 %1597 to i32
  %1601 = mul i64 %1597, %30
  %1602 = add i64 %1601, 0
  %1603 = getelementptr float, ptr %34, i64 %1602
  %1604 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1600)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1603, i32 0, i32 %1600)
  %1605 = mul i64 %1597, %30
  %1606 = add i64 %1605, 0
  %1607 = getelementptr float, ptr %34, i64 %1606
  store <vscale x 4 x float> %1604, ptr %1607, align 4
  %1608 = add i64 %1597, 1
  br label %1596

1609:                                             ; preds = %1596
  %1610 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1515, i64 12)
  br label %1611

1611:                                             ; preds = %1614, %1609
  %1612 = phi i64 [ %1623, %1614 ], [ 0, %1609 ]
  %1613 = icmp slt i64 %1612, %30
  br i1 %1613, label %1614, label %1624

1614:                                             ; preds = %1611
  %1615 = trunc i64 %1612 to i32
  %1616 = mul i64 %1612, %30
  %1617 = add i64 %1616, 0
  %1618 = getelementptr float, ptr %32, i64 %1617
  %1619 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1615)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1618, i32 0, i32 %1615)
  %1620 = mul i64 %1612, %30
  %1621 = add i64 %1620, 0
  %1622 = getelementptr float, ptr %32, i64 %1621
  store <vscale x 4 x float> %1619, ptr %1622, align 4
  %1623 = add i64 %1612, 1
  br label %1611

1624:                                             ; preds = %1611
  %1625 = add i64 %1531, %1364
  %1626 = getelementptr float, ptr %1265, i64 %1625
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1610, ptr %1626, i32 0, i32 %1270)
  br label %1627

1627:                                             ; preds = %1630, %1624
  %1628 = phi i64 [ %1639, %1630 ], [ 0, %1624 ]
  %1629 = icmp slt i64 %1628, %30
  br i1 %1629, label %1630, label %1640

1630:                                             ; preds = %1627
  %1631 = trunc i64 %1628 to i32
  %1632 = mul i64 %1628, %30
  %1633 = add i64 %1632, 0
  %1634 = getelementptr float, ptr %32, i64 %1633
  %1635 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1631)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1634, i32 0, i32 %1631)
  %1636 = mul i64 %1628, %30
  %1637 = add i64 %1636, 0
  %1638 = getelementptr float, ptr %32, i64 %1637
  store <vscale x 4 x float> %1635, ptr %1638, align 4
  %1639 = add i64 %1628, 1
  br label %1627

1640:                                             ; preds = %1627
  %1641 = add i64 %297, %1243
  %1642 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1> %83)
  %1643 = trunc i64 %1641 to i32
  %1644 = call <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1> %1642, <vscale x 16 x i1> %67, i32 %1643)
  %1645 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1> %1644)
  %1646 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1645, i64 0)
  %1647 = mul i64 %1641, %19
  %1648 = add i64 %1647, %1267
  %1649 = getelementptr float, ptr %1265, i64 %1648
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1646, ptr %1649, i32 0, i32 %1270)
  %1650 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1645, i64 4)
  %1651 = add i64 %1647, %1300
  %1652 = getelementptr float, ptr %1265, i64 %1651
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1650, ptr %1652, i32 1, i32 %1270)
  %1653 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1645, i64 8)
  %1654 = add i64 %1647, %1332
  %1655 = getelementptr float, ptr %1265, i64 %1654
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1653, ptr %1655, i32 2, i32 %1270)
  %1656 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1645, i64 12)
  %1657 = add i64 %1647, %1364
  %1658 = getelementptr float, ptr %1265, i64 %1657
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1656, ptr %1658, i32 3, i32 %1270)
  %1659 = add i64 %1243, 1
  br label %1242

1660:                                             ; preds = %1242
  %1661 = add i64 %85, 1
  br label %84

1662:                                             ; preds = %84
  %1663 = add i64 %69, %55
  br label %68

1664:                                             ; preds = %68
  %1665 = add i64 %57, %55
  br label %56

1666:                                             ; preds = %56
  ret { ptr, ptr, i64, [2 x i64], [2 x i64] } %28
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.vscale.i64() #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smin.i64(i64, i64) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 16 x i32> @llvm.stepvector.nxv16i32() #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, inaccessiblemem: readwrite)
declare void @llvm.prefetch.p0(ptr readonly captures(none), i32 immarg range(i32 0, 2), i32 immarg range(i32 0, 4), i32 immarg range(i32 0, 2)) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float>, i64 immarg) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 4 x i32> @llvm.stepvector.nxv4i32() #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(target_mem1: readwrite)
declare void @llvm.aarch64.sme.mopa.nxv4f32(i32 immarg, <vscale x 4 x i1>, <vscale x 4 x i1>, <vscale x 4 x float>, <vscale x 4 x float>) #5

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1>) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1>, <vscale x 16 x i1>, i32) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1>) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1>, i64 immarg) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, target_mem1: readwrite)
declare void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1>, ptr, i32 immarg, i32) #6

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(target_mem1: read)
declare <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float>, <vscale x 4 x i1>, i32 immarg, i32) #7

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, target_mem1: readwrite)
declare void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1>, ptr, i32 immarg, i32) #6

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: read)
declare <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr captures(none), <vscale x 4 x i1>, <vscale x 4 x float>) #8

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(target_mem1: readwrite)
declare void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 immarg, i32, <vscale x 4 x i1>, <vscale x 4 x float>) #5

attributes #0 = { "aarch64_new_za" "aarch64_pstate_sm_body" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, inaccessiblemem: readwrite) }
attributes #5 = { nocallback nofree nosync nounwind willreturn memory(target_mem1: readwrite) }
attributes #6 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, target_mem1: readwrite) }
attributes #7 = { nocallback nofree nosync nounwind willreturn memory(target_mem1: read) }
attributes #8 = { nocallback nofree nosync nounwind willreturn memory(argmem: read) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
