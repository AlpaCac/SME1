; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define void @gemm_fp32_linalg(ptr %0, ptr %1, i64 %2, i64 %3, i64 %4, i64 %5, i64 %6, ptr %7, ptr %8, i64 %9, i64 %10, i64 %11, i64 %12, i64 %13, ptr %14, ptr %15, i64 %16, i64 %17, i64 %18, i64 %19, i64 %20) #0 {
  %22 = call i64 @llvm.vscale.i64()
  %23 = mul i64 %22, 4
  %24 = mul i64 %23, %23
  %25 = alloca float, i64 %24, align 4
  %26 = mul i64 %23, %23
  %27 = alloca float, i64 %26, align 4
  %28 = mul i64 %23, %23
  %29 = alloca float, i64 %28, align 4
  %30 = mul i64 %23, %23
  %31 = alloca float, i64 %30, align 4
  %32 = mul i64 %23, %23
  %33 = alloca float, i64 %32, align 4
  %34 = mul i64 %23, %23
  %35 = alloca float, i64 %34, align 4
  %36 = mul i64 %23, %23
  %37 = alloca float, i64 %36, align 4
  %38 = mul i64 %23, %23
  %39 = alloca float, i64 %38, align 4
  %40 = mul i64 %23, %23
  %41 = alloca float, i64 %40, align 4
  %42 = mul i64 %23, %23
  %43 = alloca float, i64 %42, align 4
  %44 = mul i64 %23, %23
  %45 = alloca float, i64 %44, align 4
  %46 = mul i64 %23, %23
  %47 = alloca float, i64 %46, align 4
  %48 = mul i64 %22, 16
  br label %49

49:                                               ; preds = %1688, %21
  %50 = phi i64 [ %1689, %1688 ], [ 0, %21 ]
  %51 = icmp slt i64 %50, %3
  br i1 %51, label %52, label %1690

52:                                               ; preds = %49
  %53 = sub i64 %3, %50
  %54 = call i64 @llvm.smin.i64(i64 %53, i64 128)
  br label %55

55:                                               ; preds = %1686, %52
  %56 = phi i64 [ %1687, %1686 ], [ 0, %52 ]
  %57 = icmp slt i64 %56, %11
  br i1 %57, label %58, label %1688

58:                                               ; preds = %55
  %59 = sub i64 %11, %56
  %60 = call i64 @llvm.smin.i64(i64 %59, i64 128)
  br label %61

61:                                               ; preds = %1684, %58
  %62 = phi i64 [ %1685, %1684 ], [ 0, %58 ]
  %63 = icmp slt i64 %62, %54
  br i1 %63, label %64, label %1686

64:                                               ; preds = %61
  %65 = sub i64 %54, %62
  %66 = call i64 @llvm.smin.i64(i64 %65, i64 16)
  %67 = add i64 %50, %62
  br label %68

68:                                               ; preds = %1682, %64
  %69 = phi i64 [ %1683, %1682 ], [ 0, %64 ]
  %70 = icmp slt i64 %69, %60
  br i1 %70, label %71, label %1684

71:                                               ; preds = %68
  %72 = sub i64 %60, %69
  %73 = call i64 @llvm.smin.i64(i64 %72, i64 16)
  %74 = add i64 %56, %69
  %75 = mul nsw i64 %50, %19
  %76 = add i64 %75, %56
  %77 = mul nsw i64 %62, %19
  %78 = add i64 %76, %77
  %79 = add i64 %78, %69
  br label %80

80:                                               ; preds = %92, %71
  %81 = phi i64 [ %93, %92 ], [ 0, %71 ]
  %82 = icmp slt i64 %81, %66
  br i1 %82, label %83, label %94

83:                                               ; preds = %86, %80
  %84 = phi i64 [ %91, %86 ], [ 0, %80 ]
  %85 = icmp slt i64 %84, %73
  br i1 %85, label %86, label %92

86:                                               ; preds = %83
  %87 = getelementptr float, ptr %15, i64 %79
  %88 = mul nsw i64 %81, %19
  %89 = add nsw i64 %88, %84
  %90 = getelementptr inbounds float, ptr %87, i64 %89
  store float 0.000000e+00, ptr %90, align 4
  %91 = add i64 %84, 1
  br label %83

92:                                               ; preds = %83
  %93 = add i64 %81, 1
  br label %80

94:                                               ; preds = %1680, %80
  %95 = phi i64 [ %1681, %1680 ], [ 0, %80 ]
  %96 = icmp slt i64 %95, %4
  br i1 %96, label %97, label %1682

97:                                               ; preds = %94
  %98 = sub i64 %4, %95
  %99 = call i64 @llvm.smin.i64(i64 %98, i64 128)
  br label %100

100:                                              ; preds = %1678, %97
  %101 = phi i64 [ %1679, %1678 ], [ 0, %97 ]
  %102 = icmp slt i64 %101, %66
  br i1 %102, label %103, label %1680

103:                                              ; preds = %100
  %104 = sub i64 %66, %101
  %105 = call i64 @llvm.smin.i64(i64 %48, i64 %104)
  %106 = call <vscale x 16 x i32> @llvm.stepvector.nxv16i32()
  %107 = call i64 @llvm.smin.i64(i64 %105, i64 2147483647)
  %108 = trunc i64 %107 to i32
  %109 = insertelement <vscale x 16 x i32> poison, i32 %108, i32 0
  %110 = shufflevector <vscale x 16 x i32> %109, <vscale x 16 x i32> poison, <vscale x 16 x i32> zeroinitializer
  %111 = icmp slt <vscale x 16 x i32> %106, %110
  br label %112

112:                                              ; preds = %1676, %103
  %113 = phi i64 [ %1677, %1676 ], [ 0, %103 ]
  %114 = icmp slt i64 %113, %73
  br i1 %114, label %115, label %1678

115:                                              ; preds = %112
  %116 = sub i64 %73, %113
  %117 = call i64 @llvm.smin.i64(i64 %48, i64 %116)
  %118 = mul nsw i64 %50, %19
  %119 = add i64 %118, %56
  %120 = mul nsw i64 %62, %19
  %121 = add i64 %119, %120
  %122 = add i64 %121, %69
  %123 = mul nsw i64 %101, %19
  %124 = add i64 %122, %123
  %125 = add i64 %124, %113
  %126 = call <vscale x 16 x i32> @llvm.stepvector.nxv16i32()
  %127 = call i64 @llvm.smin.i64(i64 %117, i64 2147483647)
  %128 = trunc i64 %127 to i32
  %129 = insertelement <vscale x 16 x i32> poison, i32 %128, i32 0
  %130 = shufflevector <vscale x 16 x i32> %129, <vscale x 16 x i32> poison, <vscale x 16 x i32> zeroinitializer
  %131 = icmp slt <vscale x 16 x i32> %126, %130
  br label %132

132:                                              ; preds = %1674, %115
  %133 = phi i64 [ %1675, %1674 ], [ 0, %115 ]
  %134 = icmp slt i64 %133, %99
  br i1 %134, label %135, label %1676

135:                                              ; preds = %132
  %136 = mul nsw i64 %67, %5
  %137 = add i64 %136, %95
  %138 = mul nsw i64 %101, %5
  %139 = add i64 %137, %138
  %140 = add i64 %139, %133
  %141 = getelementptr float, ptr %1, i64 %140
  %142 = mul i64 %5, 0
  %143 = getelementptr float, ptr %141, i64 %142
  call void @llvm.prefetch.p0(ptr %143, i32 0, i32 3, i32 1)
  br label %144

144:                                              ; preds = %156, %135
  %145 = phi i64 [ %158, %156 ], [ 0, %135 ]
  %146 = phi <vscale x 16 x float> [ %157, %156 ], [ poison, %135 ]
  %147 = icmp slt i64 %145, %48
  br i1 %147, label %148, label %159

148:                                              ; preds = %144
  %149 = extractelement <vscale x 16 x i1> %111, i64 %145
  br i1 %149, label %150, label %156

150:                                              ; preds = %148
  %151 = getelementptr float, ptr %1, i64 %140
  %152 = mul nsw i64 %145, %5
  %153 = getelementptr inbounds float, ptr %151, i64 %152
  %154 = load float, ptr %153, align 4
  %155 = insertelement <vscale x 16 x float> %146, float %154, i64 %145
  br label %156

156:                                              ; preds = %150, %148
  %157 = phi <vscale x 16 x float> [ %155, %150 ], [ %146, %148 ]
  %158 = add i64 %145, 1
  br label %144

159:                                              ; preds = %144
  %160 = mul nsw i64 %95, %12
  %161 = add i64 %160, %74
  %162 = mul nsw i64 %133, %12
  %163 = add i64 %161, %162
  %164 = add i64 %163, %113
  %165 = getelementptr float, ptr %8, i64 %164
  call void @llvm.prefetch.p0(ptr %165, i32 0, i32 3, i32 1)
  %166 = getelementptr float, ptr %8, i64 %164
  %167 = call <vscale x 16 x float> @llvm.masked.load.nxv16f32.p0(ptr align 4 %166, <vscale x 16 x i1> %131, <vscale x 16 x float> poison)
  %168 = trunc i64 %117 to i32
  br label %169

169:                                              ; preds = %216, %159
  %170 = phi i64 [ %217, %216 ], [ 0, %159 ]
  %171 = icmp slt i64 %170, %23
  br i1 %171, label %172, label %218

172:                                              ; preds = %169
  %173 = icmp slt i64 %170, %105
  %174 = sext i1 %173 to i32
  %175 = and i32 %174, %168
  %176 = sext i32 %175 to i64
  %177 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %178 = call i64 @llvm.smin.i64(i64 %176, i64 2147483647)
  %179 = trunc i64 %178 to i32
  %180 = insertelement <vscale x 4 x i32> poison, i32 %179, i32 0
  %181 = shufflevector <vscale x 4 x i32> %180, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %182 = icmp slt <vscale x 4 x i32> %177, %181
  %183 = getelementptr float, ptr %15, i64 %125
  %184 = mul i64 %170, %19
  %185 = add i64 %184, 0
  %186 = getelementptr float, ptr %183, i64 %185
  %187 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %186, <vscale x 4 x i1> %182, <vscale x 4 x float> poison)
  br label %188

188:                                              ; preds = %191, %172
  %189 = phi i64 [ %200, %191 ], [ 0, %172 ]
  %190 = icmp slt i64 %189, %23
  br i1 %190, label %191, label %201

191:                                              ; preds = %188
  %192 = trunc i64 %189 to i32
  %193 = mul i64 %189, %23
  %194 = add i64 %193, 0
  %195 = getelementptr float, ptr %47, i64 %194
  %196 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %192)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %195, i32 0, i32 %192)
  %197 = mul i64 %189, %23
  %198 = add i64 %197, 0
  %199 = getelementptr float, ptr %47, i64 %198
  store <vscale x 4 x float> %196, ptr %199, align 4
  %200 = add i64 %189, 1
  br label %188

201:                                              ; preds = %188
  %202 = trunc i64 %170 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %202, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %187)
  br label %203

203:                                              ; preds = %206, %201
  %204 = phi i64 [ %215, %206 ], [ 0, %201 ]
  %205 = icmp slt i64 %204, %23
  br i1 %205, label %206, label %216

206:                                              ; preds = %203
  %207 = trunc i64 %204 to i32
  %208 = mul i64 %204, %23
  %209 = add i64 %208, 0
  %210 = getelementptr float, ptr %47, i64 %209
  %211 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %207)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %210, i32 0, i32 %207)
  %212 = mul i64 %204, %23
  %213 = add i64 %212, 0
  %214 = getelementptr float, ptr %47, i64 %213
  store <vscale x 4 x float> %211, ptr %214, align 4
  %215 = add i64 %204, 1
  br label %203

216:                                              ; preds = %203
  %217 = add i64 %170, 1
  br label %169

218:                                              ; preds = %169
  %219 = mul i64 %22, -4
  %220 = add i64 %117, %219
  %221 = trunc i64 %220 to i32
  br label %222

222:                                              ; preds = %269, %218
  %223 = phi i64 [ %270, %269 ], [ 0, %218 ]
  %224 = icmp slt i64 %223, %23
  br i1 %224, label %225, label %271

225:                                              ; preds = %222
  %226 = icmp slt i64 %223, %105
  %227 = sext i1 %226 to i32
  %228 = and i32 %227, %221
  %229 = sext i32 %228 to i64
  %230 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %231 = call i64 @llvm.smin.i64(i64 %229, i64 2147483647)
  %232 = trunc i64 %231 to i32
  %233 = insertelement <vscale x 4 x i32> poison, i32 %232, i32 0
  %234 = shufflevector <vscale x 4 x i32> %233, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %235 = icmp slt <vscale x 4 x i32> %230, %234
  %236 = getelementptr float, ptr %15, i64 %125
  %237 = mul i64 %223, %19
  %238 = add i64 %237, %23
  %239 = getelementptr float, ptr %236, i64 %238
  %240 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %239, <vscale x 4 x i1> %235, <vscale x 4 x float> poison)
  br label %241

241:                                              ; preds = %244, %225
  %242 = phi i64 [ %253, %244 ], [ 0, %225 ]
  %243 = icmp slt i64 %242, %23
  br i1 %243, label %244, label %254

244:                                              ; preds = %241
  %245 = trunc i64 %242 to i32
  %246 = mul i64 %242, %23
  %247 = add i64 %246, 0
  %248 = getelementptr float, ptr %45, i64 %247
  %249 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %245)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %248, i32 0, i32 %245)
  %250 = mul i64 %242, %23
  %251 = add i64 %250, 0
  %252 = getelementptr float, ptr %45, i64 %251
  store <vscale x 4 x float> %249, ptr %252, align 4
  %253 = add i64 %242, 1
  br label %241

254:                                              ; preds = %241
  %255 = trunc i64 %223 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %255, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %240)
  br label %256

256:                                              ; preds = %259, %254
  %257 = phi i64 [ %268, %259 ], [ 0, %254 ]
  %258 = icmp slt i64 %257, %23
  br i1 %258, label %259, label %269

259:                                              ; preds = %256
  %260 = trunc i64 %257 to i32
  %261 = mul i64 %257, %23
  %262 = add i64 %261, 0
  %263 = getelementptr float, ptr %45, i64 %262
  %264 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %260)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %263, i32 0, i32 %260)
  %265 = mul i64 %257, %23
  %266 = add i64 %265, 0
  %267 = getelementptr float, ptr %45, i64 %266
  store <vscale x 4 x float> %264, ptr %267, align 4
  %268 = add i64 %257, 1
  br label %256

269:                                              ; preds = %256
  %270 = add i64 %223, 1
  br label %222

271:                                              ; preds = %222
  %272 = mul i64 %22, -8
  %273 = add i64 %117, %272
  %274 = mul i64 %22, 8
  %275 = trunc i64 %273 to i32
  br label %276

276:                                              ; preds = %323, %271
  %277 = phi i64 [ %324, %323 ], [ 0, %271 ]
  %278 = icmp slt i64 %277, %23
  br i1 %278, label %279, label %325

279:                                              ; preds = %276
  %280 = icmp slt i64 %277, %105
  %281 = sext i1 %280 to i32
  %282 = and i32 %281, %275
  %283 = sext i32 %282 to i64
  %284 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %285 = call i64 @llvm.smin.i64(i64 %283, i64 2147483647)
  %286 = trunc i64 %285 to i32
  %287 = insertelement <vscale x 4 x i32> poison, i32 %286, i32 0
  %288 = shufflevector <vscale x 4 x i32> %287, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %289 = icmp slt <vscale x 4 x i32> %284, %288
  %290 = getelementptr float, ptr %15, i64 %125
  %291 = mul i64 %277, %19
  %292 = add i64 %291, %274
  %293 = getelementptr float, ptr %290, i64 %292
  %294 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %293, <vscale x 4 x i1> %289, <vscale x 4 x float> poison)
  br label %295

295:                                              ; preds = %298, %279
  %296 = phi i64 [ %307, %298 ], [ 0, %279 ]
  %297 = icmp slt i64 %296, %23
  br i1 %297, label %298, label %308

298:                                              ; preds = %295
  %299 = trunc i64 %296 to i32
  %300 = mul i64 %296, %23
  %301 = add i64 %300, 0
  %302 = getelementptr float, ptr %43, i64 %301
  %303 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %299)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %302, i32 0, i32 %299)
  %304 = mul i64 %296, %23
  %305 = add i64 %304, 0
  %306 = getelementptr float, ptr %43, i64 %305
  store <vscale x 4 x float> %303, ptr %306, align 4
  %307 = add i64 %296, 1
  br label %295

308:                                              ; preds = %295
  %309 = trunc i64 %277 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %309, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %294)
  br label %310

310:                                              ; preds = %313, %308
  %311 = phi i64 [ %322, %313 ], [ 0, %308 ]
  %312 = icmp slt i64 %311, %23
  br i1 %312, label %313, label %323

313:                                              ; preds = %310
  %314 = trunc i64 %311 to i32
  %315 = mul i64 %311, %23
  %316 = add i64 %315, 0
  %317 = getelementptr float, ptr %43, i64 %316
  %318 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %314)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %317, i32 0, i32 %314)
  %319 = mul i64 %311, %23
  %320 = add i64 %319, 0
  %321 = getelementptr float, ptr %43, i64 %320
  store <vscale x 4 x float> %318, ptr %321, align 4
  %322 = add i64 %311, 1
  br label %310

323:                                              ; preds = %310
  %324 = add i64 %277, 1
  br label %276

325:                                              ; preds = %276
  %326 = mul i64 %22, -12
  %327 = add i64 %117, %326
  %328 = mul i64 %22, 12
  %329 = trunc i64 %327 to i32
  br label %330

330:                                              ; preds = %377, %325
  %331 = phi i64 [ %378, %377 ], [ 0, %325 ]
  %332 = icmp slt i64 %331, %23
  br i1 %332, label %333, label %379

333:                                              ; preds = %330
  %334 = icmp slt i64 %331, %105
  %335 = sext i1 %334 to i32
  %336 = and i32 %335, %329
  %337 = sext i32 %336 to i64
  %338 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %339 = call i64 @llvm.smin.i64(i64 %337, i64 2147483647)
  %340 = trunc i64 %339 to i32
  %341 = insertelement <vscale x 4 x i32> poison, i32 %340, i32 0
  %342 = shufflevector <vscale x 4 x i32> %341, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %343 = icmp slt <vscale x 4 x i32> %338, %342
  %344 = getelementptr float, ptr %15, i64 %125
  %345 = mul i64 %331, %19
  %346 = add i64 %345, %328
  %347 = getelementptr float, ptr %344, i64 %346
  %348 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %347, <vscale x 4 x i1> %343, <vscale x 4 x float> poison)
  br label %349

349:                                              ; preds = %352, %333
  %350 = phi i64 [ %361, %352 ], [ 0, %333 ]
  %351 = icmp slt i64 %350, %23
  br i1 %351, label %352, label %362

352:                                              ; preds = %349
  %353 = trunc i64 %350 to i32
  %354 = mul i64 %350, %23
  %355 = add i64 %354, 0
  %356 = getelementptr float, ptr %41, i64 %355
  %357 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %353)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %356, i32 0, i32 %353)
  %358 = mul i64 %350, %23
  %359 = add i64 %358, 0
  %360 = getelementptr float, ptr %41, i64 %359
  store <vscale x 4 x float> %357, ptr %360, align 4
  %361 = add i64 %350, 1
  br label %349

362:                                              ; preds = %349
  %363 = trunc i64 %331 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %363, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %348)
  br label %364

364:                                              ; preds = %367, %362
  %365 = phi i64 [ %376, %367 ], [ 0, %362 ]
  %366 = icmp slt i64 %365, %23
  br i1 %366, label %367, label %377

367:                                              ; preds = %364
  %368 = trunc i64 %365 to i32
  %369 = mul i64 %365, %23
  %370 = add i64 %369, 0
  %371 = getelementptr float, ptr %41, i64 %370
  %372 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %368)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %371, i32 0, i32 %368)
  %373 = mul i64 %365, %23
  %374 = add i64 %373, 0
  %375 = getelementptr float, ptr %41, i64 %374
  store <vscale x 4 x float> %372, ptr %375, align 4
  %376 = add i64 %365, 1
  br label %364

377:                                              ; preds = %364
  %378 = add i64 %331, 1
  br label %330

379:                                              ; preds = %330
  %380 = add i64 %105, %219
  br label %381

381:                                              ; preds = %429, %379
  %382 = phi i64 [ %430, %429 ], [ 0, %379 ]
  %383 = icmp slt i64 %382, %23
  br i1 %383, label %384, label %431

384:                                              ; preds = %381
  %385 = icmp slt i64 %382, %380
  %386 = sext i1 %385 to i32
  %387 = and i32 %386, %168
  %388 = sext i32 %387 to i64
  %389 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %390 = call i64 @llvm.smin.i64(i64 %388, i64 2147483647)
  %391 = trunc i64 %390 to i32
  %392 = insertelement <vscale x 4 x i32> poison, i32 %391, i32 0
  %393 = shufflevector <vscale x 4 x i32> %392, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %394 = icmp slt <vscale x 4 x i32> %389, %393
  %395 = add i64 %23, %382
  %396 = getelementptr float, ptr %15, i64 %125
  %397 = mul i64 %395, %19
  %398 = add i64 %397, 0
  %399 = getelementptr float, ptr %396, i64 %398
  %400 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %399, <vscale x 4 x i1> %394, <vscale x 4 x float> poison)
  br label %401

401:                                              ; preds = %404, %384
  %402 = phi i64 [ %413, %404 ], [ 0, %384 ]
  %403 = icmp slt i64 %402, %23
  br i1 %403, label %404, label %414

404:                                              ; preds = %401
  %405 = trunc i64 %402 to i32
  %406 = mul i64 %402, %23
  %407 = add i64 %406, 0
  %408 = getelementptr float, ptr %39, i64 %407
  %409 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %405)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %408, i32 0, i32 %405)
  %410 = mul i64 %402, %23
  %411 = add i64 %410, 0
  %412 = getelementptr float, ptr %39, i64 %411
  store <vscale x 4 x float> %409, ptr %412, align 4
  %413 = add i64 %402, 1
  br label %401

414:                                              ; preds = %401
  %415 = trunc i64 %382 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %415, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %400)
  br label %416

416:                                              ; preds = %419, %414
  %417 = phi i64 [ %428, %419 ], [ 0, %414 ]
  %418 = icmp slt i64 %417, %23
  br i1 %418, label %419, label %429

419:                                              ; preds = %416
  %420 = trunc i64 %417 to i32
  %421 = mul i64 %417, %23
  %422 = add i64 %421, 0
  %423 = getelementptr float, ptr %39, i64 %422
  %424 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %420)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %423, i32 0, i32 %420)
  %425 = mul i64 %417, %23
  %426 = add i64 %425, 0
  %427 = getelementptr float, ptr %39, i64 %426
  store <vscale x 4 x float> %424, ptr %427, align 4
  %428 = add i64 %417, 1
  br label %416

429:                                              ; preds = %416
  %430 = add i64 %382, 1
  br label %381

431:                                              ; preds = %479, %381
  %432 = phi i64 [ %480, %479 ], [ 0, %381 ]
  %433 = icmp slt i64 %432, %23
  br i1 %433, label %434, label %481

434:                                              ; preds = %431
  %435 = icmp slt i64 %432, %380
  %436 = sext i1 %435 to i32
  %437 = and i32 %436, %221
  %438 = sext i32 %437 to i64
  %439 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %440 = call i64 @llvm.smin.i64(i64 %438, i64 2147483647)
  %441 = trunc i64 %440 to i32
  %442 = insertelement <vscale x 4 x i32> poison, i32 %441, i32 0
  %443 = shufflevector <vscale x 4 x i32> %442, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %444 = icmp slt <vscale x 4 x i32> %439, %443
  %445 = add i64 %23, %432
  %446 = getelementptr float, ptr %15, i64 %125
  %447 = mul i64 %445, %19
  %448 = add i64 %447, %23
  %449 = getelementptr float, ptr %446, i64 %448
  %450 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %449, <vscale x 4 x i1> %444, <vscale x 4 x float> poison)
  br label %451

451:                                              ; preds = %454, %434
  %452 = phi i64 [ %463, %454 ], [ 0, %434 ]
  %453 = icmp slt i64 %452, %23
  br i1 %453, label %454, label %464

454:                                              ; preds = %451
  %455 = trunc i64 %452 to i32
  %456 = mul i64 %452, %23
  %457 = add i64 %456, 0
  %458 = getelementptr float, ptr %37, i64 %457
  %459 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %455)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %458, i32 0, i32 %455)
  %460 = mul i64 %452, %23
  %461 = add i64 %460, 0
  %462 = getelementptr float, ptr %37, i64 %461
  store <vscale x 4 x float> %459, ptr %462, align 4
  %463 = add i64 %452, 1
  br label %451

464:                                              ; preds = %451
  %465 = trunc i64 %432 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %465, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %450)
  br label %466

466:                                              ; preds = %469, %464
  %467 = phi i64 [ %478, %469 ], [ 0, %464 ]
  %468 = icmp slt i64 %467, %23
  br i1 %468, label %469, label %479

469:                                              ; preds = %466
  %470 = trunc i64 %467 to i32
  %471 = mul i64 %467, %23
  %472 = add i64 %471, 0
  %473 = getelementptr float, ptr %37, i64 %472
  %474 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %470)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %473, i32 0, i32 %470)
  %475 = mul i64 %467, %23
  %476 = add i64 %475, 0
  %477 = getelementptr float, ptr %37, i64 %476
  store <vscale x 4 x float> %474, ptr %477, align 4
  %478 = add i64 %467, 1
  br label %466

479:                                              ; preds = %466
  %480 = add i64 %432, 1
  br label %431

481:                                              ; preds = %529, %431
  %482 = phi i64 [ %530, %529 ], [ 0, %431 ]
  %483 = icmp slt i64 %482, %23
  br i1 %483, label %484, label %531

484:                                              ; preds = %481
  %485 = icmp slt i64 %482, %380
  %486 = sext i1 %485 to i32
  %487 = and i32 %486, %275
  %488 = sext i32 %487 to i64
  %489 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %490 = call i64 @llvm.smin.i64(i64 %488, i64 2147483647)
  %491 = trunc i64 %490 to i32
  %492 = insertelement <vscale x 4 x i32> poison, i32 %491, i32 0
  %493 = shufflevector <vscale x 4 x i32> %492, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %494 = icmp slt <vscale x 4 x i32> %489, %493
  %495 = add i64 %23, %482
  %496 = getelementptr float, ptr %15, i64 %125
  %497 = mul i64 %495, %19
  %498 = add i64 %497, %274
  %499 = getelementptr float, ptr %496, i64 %498
  %500 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %499, <vscale x 4 x i1> %494, <vscale x 4 x float> poison)
  br label %501

501:                                              ; preds = %504, %484
  %502 = phi i64 [ %513, %504 ], [ 0, %484 ]
  %503 = icmp slt i64 %502, %23
  br i1 %503, label %504, label %514

504:                                              ; preds = %501
  %505 = trunc i64 %502 to i32
  %506 = mul i64 %502, %23
  %507 = add i64 %506, 0
  %508 = getelementptr float, ptr %35, i64 %507
  %509 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %505)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %508, i32 0, i32 %505)
  %510 = mul i64 %502, %23
  %511 = add i64 %510, 0
  %512 = getelementptr float, ptr %35, i64 %511
  store <vscale x 4 x float> %509, ptr %512, align 4
  %513 = add i64 %502, 1
  br label %501

514:                                              ; preds = %501
  %515 = trunc i64 %482 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %515, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %500)
  br label %516

516:                                              ; preds = %519, %514
  %517 = phi i64 [ %528, %519 ], [ 0, %514 ]
  %518 = icmp slt i64 %517, %23
  br i1 %518, label %519, label %529

519:                                              ; preds = %516
  %520 = trunc i64 %517 to i32
  %521 = mul i64 %517, %23
  %522 = add i64 %521, 0
  %523 = getelementptr float, ptr %35, i64 %522
  %524 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %520)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %523, i32 0, i32 %520)
  %525 = mul i64 %517, %23
  %526 = add i64 %525, 0
  %527 = getelementptr float, ptr %35, i64 %526
  store <vscale x 4 x float> %524, ptr %527, align 4
  %528 = add i64 %517, 1
  br label %516

529:                                              ; preds = %516
  %530 = add i64 %482, 1
  br label %481

531:                                              ; preds = %579, %481
  %532 = phi i64 [ %580, %579 ], [ 0, %481 ]
  %533 = icmp slt i64 %532, %23
  br i1 %533, label %534, label %581

534:                                              ; preds = %531
  %535 = icmp slt i64 %532, %380
  %536 = sext i1 %535 to i32
  %537 = and i32 %536, %329
  %538 = sext i32 %537 to i64
  %539 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %540 = call i64 @llvm.smin.i64(i64 %538, i64 2147483647)
  %541 = trunc i64 %540 to i32
  %542 = insertelement <vscale x 4 x i32> poison, i32 %541, i32 0
  %543 = shufflevector <vscale x 4 x i32> %542, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %544 = icmp slt <vscale x 4 x i32> %539, %543
  %545 = add i64 %23, %532
  %546 = getelementptr float, ptr %15, i64 %125
  %547 = mul i64 %545, %19
  %548 = add i64 %547, %328
  %549 = getelementptr float, ptr %546, i64 %548
  %550 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %549, <vscale x 4 x i1> %544, <vscale x 4 x float> poison)
  br label %551

551:                                              ; preds = %554, %534
  %552 = phi i64 [ %563, %554 ], [ 0, %534 ]
  %553 = icmp slt i64 %552, %23
  br i1 %553, label %554, label %564

554:                                              ; preds = %551
  %555 = trunc i64 %552 to i32
  %556 = mul i64 %552, %23
  %557 = add i64 %556, 0
  %558 = getelementptr float, ptr %33, i64 %557
  %559 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %555)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %558, i32 0, i32 %555)
  %560 = mul i64 %552, %23
  %561 = add i64 %560, 0
  %562 = getelementptr float, ptr %33, i64 %561
  store <vscale x 4 x float> %559, ptr %562, align 4
  %563 = add i64 %552, 1
  br label %551

564:                                              ; preds = %551
  %565 = trunc i64 %532 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %565, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %550)
  br label %566

566:                                              ; preds = %569, %564
  %567 = phi i64 [ %578, %569 ], [ 0, %564 ]
  %568 = icmp slt i64 %567, %23
  br i1 %568, label %569, label %579

569:                                              ; preds = %566
  %570 = trunc i64 %567 to i32
  %571 = mul i64 %567, %23
  %572 = add i64 %571, 0
  %573 = getelementptr float, ptr %33, i64 %572
  %574 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %570)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %573, i32 0, i32 %570)
  %575 = mul i64 %567, %23
  %576 = add i64 %575, 0
  %577 = getelementptr float, ptr %33, i64 %576
  store <vscale x 4 x float> %574, ptr %577, align 4
  %578 = add i64 %567, 1
  br label %566

579:                                              ; preds = %566
  %580 = add i64 %532, 1
  br label %531

581:                                              ; preds = %531
  %582 = add i64 %105, %272
  br label %583

583:                                              ; preds = %631, %581
  %584 = phi i64 [ %632, %631 ], [ 0, %581 ]
  %585 = icmp slt i64 %584, %23
  br i1 %585, label %586, label %633

586:                                              ; preds = %583
  %587 = icmp slt i64 %584, %582
  %588 = sext i1 %587 to i32
  %589 = and i32 %588, %168
  %590 = sext i32 %589 to i64
  %591 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %592 = call i64 @llvm.smin.i64(i64 %590, i64 2147483647)
  %593 = trunc i64 %592 to i32
  %594 = insertelement <vscale x 4 x i32> poison, i32 %593, i32 0
  %595 = shufflevector <vscale x 4 x i32> %594, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %596 = icmp slt <vscale x 4 x i32> %591, %595
  %597 = add i64 %274, %584
  %598 = getelementptr float, ptr %15, i64 %125
  %599 = mul i64 %597, %19
  %600 = add i64 %599, 0
  %601 = getelementptr float, ptr %598, i64 %600
  %602 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %601, <vscale x 4 x i1> %596, <vscale x 4 x float> poison)
  br label %603

603:                                              ; preds = %606, %586
  %604 = phi i64 [ %615, %606 ], [ 0, %586 ]
  %605 = icmp slt i64 %604, %23
  br i1 %605, label %606, label %616

606:                                              ; preds = %603
  %607 = trunc i64 %604 to i32
  %608 = mul i64 %604, %23
  %609 = add i64 %608, 0
  %610 = getelementptr float, ptr %31, i64 %609
  %611 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %607)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %610, i32 0, i32 %607)
  %612 = mul i64 %604, %23
  %613 = add i64 %612, 0
  %614 = getelementptr float, ptr %31, i64 %613
  store <vscale x 4 x float> %611, ptr %614, align 4
  %615 = add i64 %604, 1
  br label %603

616:                                              ; preds = %603
  %617 = trunc i64 %584 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %617, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %602)
  br label %618

618:                                              ; preds = %621, %616
  %619 = phi i64 [ %630, %621 ], [ 0, %616 ]
  %620 = icmp slt i64 %619, %23
  br i1 %620, label %621, label %631

621:                                              ; preds = %618
  %622 = trunc i64 %619 to i32
  %623 = mul i64 %619, %23
  %624 = add i64 %623, 0
  %625 = getelementptr float, ptr %31, i64 %624
  %626 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %622)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %625, i32 0, i32 %622)
  %627 = mul i64 %619, %23
  %628 = add i64 %627, 0
  %629 = getelementptr float, ptr %31, i64 %628
  store <vscale x 4 x float> %626, ptr %629, align 4
  %630 = add i64 %619, 1
  br label %618

631:                                              ; preds = %618
  %632 = add i64 %584, 1
  br label %583

633:                                              ; preds = %681, %583
  %634 = phi i64 [ %682, %681 ], [ 0, %583 ]
  %635 = icmp slt i64 %634, %23
  br i1 %635, label %636, label %683

636:                                              ; preds = %633
  %637 = icmp slt i64 %634, %582
  %638 = sext i1 %637 to i32
  %639 = and i32 %638, %221
  %640 = sext i32 %639 to i64
  %641 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %642 = call i64 @llvm.smin.i64(i64 %640, i64 2147483647)
  %643 = trunc i64 %642 to i32
  %644 = insertelement <vscale x 4 x i32> poison, i32 %643, i32 0
  %645 = shufflevector <vscale x 4 x i32> %644, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %646 = icmp slt <vscale x 4 x i32> %641, %645
  %647 = add i64 %274, %634
  %648 = getelementptr float, ptr %15, i64 %125
  %649 = mul i64 %647, %19
  %650 = add i64 %649, %23
  %651 = getelementptr float, ptr %648, i64 %650
  %652 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %651, <vscale x 4 x i1> %646, <vscale x 4 x float> poison)
  br label %653

653:                                              ; preds = %656, %636
  %654 = phi i64 [ %665, %656 ], [ 0, %636 ]
  %655 = icmp slt i64 %654, %23
  br i1 %655, label %656, label %666

656:                                              ; preds = %653
  %657 = trunc i64 %654 to i32
  %658 = mul i64 %654, %23
  %659 = add i64 %658, 0
  %660 = getelementptr float, ptr %29, i64 %659
  %661 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %657)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %660, i32 0, i32 %657)
  %662 = mul i64 %654, %23
  %663 = add i64 %662, 0
  %664 = getelementptr float, ptr %29, i64 %663
  store <vscale x 4 x float> %661, ptr %664, align 4
  %665 = add i64 %654, 1
  br label %653

666:                                              ; preds = %653
  %667 = trunc i64 %634 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %667, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %652)
  br label %668

668:                                              ; preds = %671, %666
  %669 = phi i64 [ %680, %671 ], [ 0, %666 ]
  %670 = icmp slt i64 %669, %23
  br i1 %670, label %671, label %681

671:                                              ; preds = %668
  %672 = trunc i64 %669 to i32
  %673 = mul i64 %669, %23
  %674 = add i64 %673, 0
  %675 = getelementptr float, ptr %29, i64 %674
  %676 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %672)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %675, i32 0, i32 %672)
  %677 = mul i64 %669, %23
  %678 = add i64 %677, 0
  %679 = getelementptr float, ptr %29, i64 %678
  store <vscale x 4 x float> %676, ptr %679, align 4
  %680 = add i64 %669, 1
  br label %668

681:                                              ; preds = %668
  %682 = add i64 %634, 1
  br label %633

683:                                              ; preds = %731, %633
  %684 = phi i64 [ %732, %731 ], [ 0, %633 ]
  %685 = icmp slt i64 %684, %23
  br i1 %685, label %686, label %733

686:                                              ; preds = %683
  %687 = icmp slt i64 %684, %582
  %688 = sext i1 %687 to i32
  %689 = and i32 %688, %275
  %690 = sext i32 %689 to i64
  %691 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %692 = call i64 @llvm.smin.i64(i64 %690, i64 2147483647)
  %693 = trunc i64 %692 to i32
  %694 = insertelement <vscale x 4 x i32> poison, i32 %693, i32 0
  %695 = shufflevector <vscale x 4 x i32> %694, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %696 = icmp slt <vscale x 4 x i32> %691, %695
  %697 = add i64 %274, %684
  %698 = getelementptr float, ptr %15, i64 %125
  %699 = mul i64 %697, %19
  %700 = add i64 %699, %274
  %701 = getelementptr float, ptr %698, i64 %700
  %702 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %701, <vscale x 4 x i1> %696, <vscale x 4 x float> poison)
  br label %703

703:                                              ; preds = %706, %686
  %704 = phi i64 [ %715, %706 ], [ 0, %686 ]
  %705 = icmp slt i64 %704, %23
  br i1 %705, label %706, label %716

706:                                              ; preds = %703
  %707 = trunc i64 %704 to i32
  %708 = mul i64 %704, %23
  %709 = add i64 %708, 0
  %710 = getelementptr float, ptr %27, i64 %709
  %711 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %707)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %710, i32 0, i32 %707)
  %712 = mul i64 %704, %23
  %713 = add i64 %712, 0
  %714 = getelementptr float, ptr %27, i64 %713
  store <vscale x 4 x float> %711, ptr %714, align 4
  %715 = add i64 %704, 1
  br label %703

716:                                              ; preds = %703
  %717 = trunc i64 %684 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %717, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %702)
  br label %718

718:                                              ; preds = %721, %716
  %719 = phi i64 [ %730, %721 ], [ 0, %716 ]
  %720 = icmp slt i64 %719, %23
  br i1 %720, label %721, label %731

721:                                              ; preds = %718
  %722 = trunc i64 %719 to i32
  %723 = mul i64 %719, %23
  %724 = add i64 %723, 0
  %725 = getelementptr float, ptr %27, i64 %724
  %726 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %722)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %725, i32 0, i32 %722)
  %727 = mul i64 %719, %23
  %728 = add i64 %727, 0
  %729 = getelementptr float, ptr %27, i64 %728
  store <vscale x 4 x float> %726, ptr %729, align 4
  %730 = add i64 %719, 1
  br label %718

731:                                              ; preds = %718
  %732 = add i64 %684, 1
  br label %683

733:                                              ; preds = %781, %683
  %734 = phi i64 [ %782, %781 ], [ 0, %683 ]
  %735 = icmp slt i64 %734, %23
  br i1 %735, label %736, label %783

736:                                              ; preds = %733
  %737 = icmp slt i64 %734, %582
  %738 = sext i1 %737 to i32
  %739 = and i32 %738, %329
  %740 = sext i32 %739 to i64
  %741 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %742 = call i64 @llvm.smin.i64(i64 %740, i64 2147483647)
  %743 = trunc i64 %742 to i32
  %744 = insertelement <vscale x 4 x i32> poison, i32 %743, i32 0
  %745 = shufflevector <vscale x 4 x i32> %744, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %746 = icmp slt <vscale x 4 x i32> %741, %745
  %747 = add i64 %274, %734
  %748 = getelementptr float, ptr %15, i64 %125
  %749 = mul i64 %747, %19
  %750 = add i64 %749, %328
  %751 = getelementptr float, ptr %748, i64 %750
  %752 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %751, <vscale x 4 x i1> %746, <vscale x 4 x float> poison)
  br label %753

753:                                              ; preds = %756, %736
  %754 = phi i64 [ %765, %756 ], [ 0, %736 ]
  %755 = icmp slt i64 %754, %23
  br i1 %755, label %756, label %766

756:                                              ; preds = %753
  %757 = trunc i64 %754 to i32
  %758 = mul i64 %754, %23
  %759 = add i64 %758, 0
  %760 = getelementptr float, ptr %25, i64 %759
  %761 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %757)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %760, i32 0, i32 %757)
  %762 = mul i64 %754, %23
  %763 = add i64 %762, 0
  %764 = getelementptr float, ptr %25, i64 %763
  store <vscale x 4 x float> %761, ptr %764, align 4
  %765 = add i64 %754, 1
  br label %753

766:                                              ; preds = %753
  %767 = trunc i64 %734 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %767, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %752)
  br label %768

768:                                              ; preds = %771, %766
  %769 = phi i64 [ %780, %771 ], [ 0, %766 ]
  %770 = icmp slt i64 %769, %23
  br i1 %770, label %771, label %781

771:                                              ; preds = %768
  %772 = trunc i64 %769 to i32
  %773 = mul i64 %769, %23
  %774 = add i64 %773, 0
  %775 = getelementptr float, ptr %25, i64 %774
  %776 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %772)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %775, i32 0, i32 %772)
  %777 = mul i64 %769, %23
  %778 = add i64 %777, 0
  %779 = getelementptr float, ptr %25, i64 %778
  store <vscale x 4 x float> %776, ptr %779, align 4
  %780 = add i64 %769, 1
  br label %768

781:                                              ; preds = %768
  %782 = add i64 %734, 1
  br label %733

783:                                              ; preds = %733
  %784 = add i64 %105, %326
  br label %785

785:                                              ; preds = %788, %783
  %786 = phi i64 [ %806, %788 ], [ 0, %783 ]
  %787 = icmp slt i64 %786, %23
  br i1 %787, label %788, label %807

788:                                              ; preds = %785
  %789 = icmp slt i64 %786, %784
  %790 = sext i1 %789 to i32
  %791 = and i32 %790, %168
  %792 = sext i32 %791 to i64
  %793 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %794 = call i64 @llvm.smin.i64(i64 %792, i64 2147483647)
  %795 = trunc i64 %794 to i32
  %796 = insertelement <vscale x 4 x i32> poison, i32 %795, i32 0
  %797 = shufflevector <vscale x 4 x i32> %796, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %798 = icmp slt <vscale x 4 x i32> %793, %797
  %799 = add i64 %328, %786
  %800 = getelementptr float, ptr %15, i64 %125
  %801 = mul i64 %799, %19
  %802 = add i64 %801, 0
  %803 = getelementptr float, ptr %800, i64 %802
  %804 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %803, <vscale x 4 x i1> %798, <vscale x 4 x float> poison)
  %805 = trunc i64 %786 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 0, i32 %805, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %804)
  %806 = add i64 %786, 1
  br label %785

807:                                              ; preds = %810, %785
  %808 = phi i64 [ %828, %810 ], [ 0, %785 ]
  %809 = icmp slt i64 %808, %23
  br i1 %809, label %810, label %829

810:                                              ; preds = %807
  %811 = icmp slt i64 %808, %784
  %812 = sext i1 %811 to i32
  %813 = and i32 %812, %221
  %814 = sext i32 %813 to i64
  %815 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %816 = call i64 @llvm.smin.i64(i64 %814, i64 2147483647)
  %817 = trunc i64 %816 to i32
  %818 = insertelement <vscale x 4 x i32> poison, i32 %817, i32 0
  %819 = shufflevector <vscale x 4 x i32> %818, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %820 = icmp slt <vscale x 4 x i32> %815, %819
  %821 = add i64 %328, %808
  %822 = getelementptr float, ptr %15, i64 %125
  %823 = mul i64 %821, %19
  %824 = add i64 %823, %23
  %825 = getelementptr float, ptr %822, i64 %824
  %826 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %825, <vscale x 4 x i1> %820, <vscale x 4 x float> poison)
  %827 = trunc i64 %808 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 1, i32 %827, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %826)
  %828 = add i64 %808, 1
  br label %807

829:                                              ; preds = %832, %807
  %830 = phi i64 [ %850, %832 ], [ 0, %807 ]
  %831 = icmp slt i64 %830, %23
  br i1 %831, label %832, label %851

832:                                              ; preds = %829
  %833 = icmp slt i64 %830, %784
  %834 = sext i1 %833 to i32
  %835 = and i32 %834, %275
  %836 = sext i32 %835 to i64
  %837 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %838 = call i64 @llvm.smin.i64(i64 %836, i64 2147483647)
  %839 = trunc i64 %838 to i32
  %840 = insertelement <vscale x 4 x i32> poison, i32 %839, i32 0
  %841 = shufflevector <vscale x 4 x i32> %840, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %842 = icmp slt <vscale x 4 x i32> %837, %841
  %843 = add i64 %328, %830
  %844 = getelementptr float, ptr %15, i64 %125
  %845 = mul i64 %843, %19
  %846 = add i64 %845, %274
  %847 = getelementptr float, ptr %844, i64 %846
  %848 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %847, <vscale x 4 x i1> %842, <vscale x 4 x float> poison)
  %849 = trunc i64 %830 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 2, i32 %849, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %848)
  %850 = add i64 %830, 1
  br label %829

851:                                              ; preds = %854, %829
  %852 = phi i64 [ %872, %854 ], [ 0, %829 ]
  %853 = icmp slt i64 %852, %23
  br i1 %853, label %854, label %873

854:                                              ; preds = %851
  %855 = icmp slt i64 %852, %784
  %856 = sext i1 %855 to i32
  %857 = and i32 %856, %329
  %858 = sext i32 %857 to i64
  %859 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %860 = call i64 @llvm.smin.i64(i64 %858, i64 2147483647)
  %861 = trunc i64 %860 to i32
  %862 = insertelement <vscale x 4 x i32> poison, i32 %861, i32 0
  %863 = shufflevector <vscale x 4 x i32> %862, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %864 = icmp slt <vscale x 4 x i32> %859, %863
  %865 = add i64 %328, %852
  %866 = getelementptr float, ptr %15, i64 %125
  %867 = mul i64 %865, %19
  %868 = add i64 %867, %328
  %869 = getelementptr float, ptr %866, i64 %868
  %870 = call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr align 4 %869, <vscale x 4 x i1> %864, <vscale x 4 x float> poison)
  %871 = trunc i64 %852 to i32
  call void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 3, i32 %871, <vscale x 4 x i1> splat (i1 true), <vscale x 4 x float> %870)
  %872 = add i64 %852, 1
  br label %851

873:                                              ; preds = %851
  %874 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %146, i64 0)
  %875 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %167, i64 0)
  %876 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %877 = call i64 @llvm.smin.i64(i64 %105, i64 2147483647)
  %878 = trunc i64 %877 to i32
  %879 = insertelement <vscale x 4 x i32> poison, i32 %878, i32 0
  %880 = shufflevector <vscale x 4 x i32> %879, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %881 = icmp slt <vscale x 4 x i32> %876, %880
  %882 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %883 = call i64 @llvm.smin.i64(i64 %117, i64 2147483647)
  %884 = trunc i64 %883 to i32
  %885 = insertelement <vscale x 4 x i32> poison, i32 %884, i32 0
  %886 = shufflevector <vscale x 4 x i32> %885, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %887 = icmp slt <vscale x 4 x i32> %882, %886
  br label %888

888:                                              ; preds = %891, %873
  %889 = phi i64 [ %900, %891 ], [ 0, %873 ]
  %890 = icmp slt i64 %889, %23
  br i1 %890, label %891, label %901

891:                                              ; preds = %888
  %892 = trunc i64 %889 to i32
  %893 = mul i64 %889, %23
  %894 = add i64 %893, 0
  %895 = getelementptr float, ptr %47, i64 %894
  %896 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %892)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %895, i32 0, i32 %892)
  %897 = mul i64 %889, %23
  %898 = add i64 %897, 0
  %899 = getelementptr float, ptr %47, i64 %898
  store <vscale x 4 x float> %896, ptr %899, align 4
  %900 = add i64 %889, 1
  br label %888

901:                                              ; preds = %888
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %881, <vscale x 4 x i1> %887, <vscale x 4 x float> %874, <vscale x 4 x float> %875)
  br label %902

902:                                              ; preds = %905, %901
  %903 = phi i64 [ %914, %905 ], [ 0, %901 ]
  %904 = icmp slt i64 %903, %23
  br i1 %904, label %905, label %915

905:                                              ; preds = %902
  %906 = trunc i64 %903 to i32
  %907 = mul i64 %903, %23
  %908 = add i64 %907, 0
  %909 = getelementptr float, ptr %47, i64 %908
  %910 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %906)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %909, i32 0, i32 %906)
  %911 = mul i64 %903, %23
  %912 = add i64 %911, 0
  %913 = getelementptr float, ptr %47, i64 %912
  store <vscale x 4 x float> %910, ptr %913, align 4
  %914 = add i64 %903, 1
  br label %902

915:                                              ; preds = %902
  %916 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %167, i64 4)
  %917 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %918 = call i64 @llvm.smin.i64(i64 %220, i64 2147483647)
  %919 = trunc i64 %918 to i32
  %920 = insertelement <vscale x 4 x i32> poison, i32 %919, i32 0
  %921 = shufflevector <vscale x 4 x i32> %920, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %922 = icmp slt <vscale x 4 x i32> %917, %921
  br label %923

923:                                              ; preds = %926, %915
  %924 = phi i64 [ %935, %926 ], [ 0, %915 ]
  %925 = icmp slt i64 %924, %23
  br i1 %925, label %926, label %936

926:                                              ; preds = %923
  %927 = trunc i64 %924 to i32
  %928 = mul i64 %924, %23
  %929 = add i64 %928, 0
  %930 = getelementptr float, ptr %45, i64 %929
  %931 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %927)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %930, i32 0, i32 %927)
  %932 = mul i64 %924, %23
  %933 = add i64 %932, 0
  %934 = getelementptr float, ptr %45, i64 %933
  store <vscale x 4 x float> %931, ptr %934, align 4
  %935 = add i64 %924, 1
  br label %923

936:                                              ; preds = %923
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %881, <vscale x 4 x i1> %922, <vscale x 4 x float> %874, <vscale x 4 x float> %916)
  br label %937

937:                                              ; preds = %940, %936
  %938 = phi i64 [ %949, %940 ], [ 0, %936 ]
  %939 = icmp slt i64 %938, %23
  br i1 %939, label %940, label %950

940:                                              ; preds = %937
  %941 = trunc i64 %938 to i32
  %942 = mul i64 %938, %23
  %943 = add i64 %942, 0
  %944 = getelementptr float, ptr %45, i64 %943
  %945 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %941)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %944, i32 0, i32 %941)
  %946 = mul i64 %938, %23
  %947 = add i64 %946, 0
  %948 = getelementptr float, ptr %45, i64 %947
  store <vscale x 4 x float> %945, ptr %948, align 4
  %949 = add i64 %938, 1
  br label %937

950:                                              ; preds = %937
  %951 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %167, i64 8)
  %952 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %953 = call i64 @llvm.smin.i64(i64 %273, i64 2147483647)
  %954 = trunc i64 %953 to i32
  %955 = insertelement <vscale x 4 x i32> poison, i32 %954, i32 0
  %956 = shufflevector <vscale x 4 x i32> %955, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %957 = icmp slt <vscale x 4 x i32> %952, %956
  br label %958

958:                                              ; preds = %961, %950
  %959 = phi i64 [ %970, %961 ], [ 0, %950 ]
  %960 = icmp slt i64 %959, %23
  br i1 %960, label %961, label %971

961:                                              ; preds = %958
  %962 = trunc i64 %959 to i32
  %963 = mul i64 %959, %23
  %964 = add i64 %963, 0
  %965 = getelementptr float, ptr %43, i64 %964
  %966 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %962)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %965, i32 0, i32 %962)
  %967 = mul i64 %959, %23
  %968 = add i64 %967, 0
  %969 = getelementptr float, ptr %43, i64 %968
  store <vscale x 4 x float> %966, ptr %969, align 4
  %970 = add i64 %959, 1
  br label %958

971:                                              ; preds = %958
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %881, <vscale x 4 x i1> %957, <vscale x 4 x float> %874, <vscale x 4 x float> %951)
  br label %972

972:                                              ; preds = %975, %971
  %973 = phi i64 [ %984, %975 ], [ 0, %971 ]
  %974 = icmp slt i64 %973, %23
  br i1 %974, label %975, label %985

975:                                              ; preds = %972
  %976 = trunc i64 %973 to i32
  %977 = mul i64 %973, %23
  %978 = add i64 %977, 0
  %979 = getelementptr float, ptr %43, i64 %978
  %980 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %976)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %979, i32 0, i32 %976)
  %981 = mul i64 %973, %23
  %982 = add i64 %981, 0
  %983 = getelementptr float, ptr %43, i64 %982
  store <vscale x 4 x float> %980, ptr %983, align 4
  %984 = add i64 %973, 1
  br label %972

985:                                              ; preds = %972
  %986 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %167, i64 12)
  %987 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %988 = call i64 @llvm.smin.i64(i64 %327, i64 2147483647)
  %989 = trunc i64 %988 to i32
  %990 = insertelement <vscale x 4 x i32> poison, i32 %989, i32 0
  %991 = shufflevector <vscale x 4 x i32> %990, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %992 = icmp slt <vscale x 4 x i32> %987, %991
  br label %993

993:                                              ; preds = %996, %985
  %994 = phi i64 [ %1005, %996 ], [ 0, %985 ]
  %995 = icmp slt i64 %994, %23
  br i1 %995, label %996, label %1006

996:                                              ; preds = %993
  %997 = trunc i64 %994 to i32
  %998 = mul i64 %994, %23
  %999 = add i64 %998, 0
  %1000 = getelementptr float, ptr %41, i64 %999
  %1001 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %997)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1000, i32 0, i32 %997)
  %1002 = mul i64 %994, %23
  %1003 = add i64 %1002, 0
  %1004 = getelementptr float, ptr %41, i64 %1003
  store <vscale x 4 x float> %1001, ptr %1004, align 4
  %1005 = add i64 %994, 1
  br label %993

1006:                                             ; preds = %993
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %881, <vscale x 4 x i1> %992, <vscale x 4 x float> %874, <vscale x 4 x float> %986)
  br label %1007

1007:                                             ; preds = %1010, %1006
  %1008 = phi i64 [ %1019, %1010 ], [ 0, %1006 ]
  %1009 = icmp slt i64 %1008, %23
  br i1 %1009, label %1010, label %1020

1010:                                             ; preds = %1007
  %1011 = trunc i64 %1008 to i32
  %1012 = mul i64 %1008, %23
  %1013 = add i64 %1012, 0
  %1014 = getelementptr float, ptr %41, i64 %1013
  %1015 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1011)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1014, i32 0, i32 %1011)
  %1016 = mul i64 %1008, %23
  %1017 = add i64 %1016, 0
  %1018 = getelementptr float, ptr %41, i64 %1017
  store <vscale x 4 x float> %1015, ptr %1018, align 4
  %1019 = add i64 %1008, 1
  br label %1007

1020:                                             ; preds = %1007
  %1021 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %146, i64 4)
  %1022 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %1023 = call i64 @llvm.smin.i64(i64 %380, i64 2147483647)
  %1024 = trunc i64 %1023 to i32
  %1025 = insertelement <vscale x 4 x i32> poison, i32 %1024, i32 0
  %1026 = shufflevector <vscale x 4 x i32> %1025, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %1027 = icmp slt <vscale x 4 x i32> %1022, %1026
  br label %1028

1028:                                             ; preds = %1031, %1020
  %1029 = phi i64 [ %1040, %1031 ], [ 0, %1020 ]
  %1030 = icmp slt i64 %1029, %23
  br i1 %1030, label %1031, label %1041

1031:                                             ; preds = %1028
  %1032 = trunc i64 %1029 to i32
  %1033 = mul i64 %1029, %23
  %1034 = add i64 %1033, 0
  %1035 = getelementptr float, ptr %39, i64 %1034
  %1036 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1032)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1035, i32 0, i32 %1032)
  %1037 = mul i64 %1029, %23
  %1038 = add i64 %1037, 0
  %1039 = getelementptr float, ptr %39, i64 %1038
  store <vscale x 4 x float> %1036, ptr %1039, align 4
  %1040 = add i64 %1029, 1
  br label %1028

1041:                                             ; preds = %1028
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1027, <vscale x 4 x i1> %887, <vscale x 4 x float> %1021, <vscale x 4 x float> %875)
  br label %1042

1042:                                             ; preds = %1045, %1041
  %1043 = phi i64 [ %1054, %1045 ], [ 0, %1041 ]
  %1044 = icmp slt i64 %1043, %23
  br i1 %1044, label %1045, label %1055

1045:                                             ; preds = %1042
  %1046 = trunc i64 %1043 to i32
  %1047 = mul i64 %1043, %23
  %1048 = add i64 %1047, 0
  %1049 = getelementptr float, ptr %39, i64 %1048
  %1050 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1046)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1049, i32 0, i32 %1046)
  %1051 = mul i64 %1043, %23
  %1052 = add i64 %1051, 0
  %1053 = getelementptr float, ptr %39, i64 %1052
  store <vscale x 4 x float> %1050, ptr %1053, align 4
  %1054 = add i64 %1043, 1
  br label %1042

1055:                                             ; preds = %1058, %1042
  %1056 = phi i64 [ %1067, %1058 ], [ 0, %1042 ]
  %1057 = icmp slt i64 %1056, %23
  br i1 %1057, label %1058, label %1068

1058:                                             ; preds = %1055
  %1059 = trunc i64 %1056 to i32
  %1060 = mul i64 %1056, %23
  %1061 = add i64 %1060, 0
  %1062 = getelementptr float, ptr %37, i64 %1061
  %1063 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1059)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1062, i32 0, i32 %1059)
  %1064 = mul i64 %1056, %23
  %1065 = add i64 %1064, 0
  %1066 = getelementptr float, ptr %37, i64 %1065
  store <vscale x 4 x float> %1063, ptr %1066, align 4
  %1067 = add i64 %1056, 1
  br label %1055

1068:                                             ; preds = %1055
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1027, <vscale x 4 x i1> %922, <vscale x 4 x float> %1021, <vscale x 4 x float> %916)
  br label %1069

1069:                                             ; preds = %1072, %1068
  %1070 = phi i64 [ %1081, %1072 ], [ 0, %1068 ]
  %1071 = icmp slt i64 %1070, %23
  br i1 %1071, label %1072, label %1082

1072:                                             ; preds = %1069
  %1073 = trunc i64 %1070 to i32
  %1074 = mul i64 %1070, %23
  %1075 = add i64 %1074, 0
  %1076 = getelementptr float, ptr %37, i64 %1075
  %1077 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1073)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1076, i32 0, i32 %1073)
  %1078 = mul i64 %1070, %23
  %1079 = add i64 %1078, 0
  %1080 = getelementptr float, ptr %37, i64 %1079
  store <vscale x 4 x float> %1077, ptr %1080, align 4
  %1081 = add i64 %1070, 1
  br label %1069

1082:                                             ; preds = %1085, %1069
  %1083 = phi i64 [ %1094, %1085 ], [ 0, %1069 ]
  %1084 = icmp slt i64 %1083, %23
  br i1 %1084, label %1085, label %1095

1085:                                             ; preds = %1082
  %1086 = trunc i64 %1083 to i32
  %1087 = mul i64 %1083, %23
  %1088 = add i64 %1087, 0
  %1089 = getelementptr float, ptr %35, i64 %1088
  %1090 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1086)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1089, i32 0, i32 %1086)
  %1091 = mul i64 %1083, %23
  %1092 = add i64 %1091, 0
  %1093 = getelementptr float, ptr %35, i64 %1092
  store <vscale x 4 x float> %1090, ptr %1093, align 4
  %1094 = add i64 %1083, 1
  br label %1082

1095:                                             ; preds = %1082
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1027, <vscale x 4 x i1> %957, <vscale x 4 x float> %1021, <vscale x 4 x float> %951)
  br label %1096

1096:                                             ; preds = %1099, %1095
  %1097 = phi i64 [ %1108, %1099 ], [ 0, %1095 ]
  %1098 = icmp slt i64 %1097, %23
  br i1 %1098, label %1099, label %1109

1099:                                             ; preds = %1096
  %1100 = trunc i64 %1097 to i32
  %1101 = mul i64 %1097, %23
  %1102 = add i64 %1101, 0
  %1103 = getelementptr float, ptr %35, i64 %1102
  %1104 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1100)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1103, i32 0, i32 %1100)
  %1105 = mul i64 %1097, %23
  %1106 = add i64 %1105, 0
  %1107 = getelementptr float, ptr %35, i64 %1106
  store <vscale x 4 x float> %1104, ptr %1107, align 4
  %1108 = add i64 %1097, 1
  br label %1096

1109:                                             ; preds = %1112, %1096
  %1110 = phi i64 [ %1121, %1112 ], [ 0, %1096 ]
  %1111 = icmp slt i64 %1110, %23
  br i1 %1111, label %1112, label %1122

1112:                                             ; preds = %1109
  %1113 = trunc i64 %1110 to i32
  %1114 = mul i64 %1110, %23
  %1115 = add i64 %1114, 0
  %1116 = getelementptr float, ptr %33, i64 %1115
  %1117 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1113)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1116, i32 0, i32 %1113)
  %1118 = mul i64 %1110, %23
  %1119 = add i64 %1118, 0
  %1120 = getelementptr float, ptr %33, i64 %1119
  store <vscale x 4 x float> %1117, ptr %1120, align 4
  %1121 = add i64 %1110, 1
  br label %1109

1122:                                             ; preds = %1109
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1027, <vscale x 4 x i1> %992, <vscale x 4 x float> %1021, <vscale x 4 x float> %986)
  br label %1123

1123:                                             ; preds = %1126, %1122
  %1124 = phi i64 [ %1135, %1126 ], [ 0, %1122 ]
  %1125 = icmp slt i64 %1124, %23
  br i1 %1125, label %1126, label %1136

1126:                                             ; preds = %1123
  %1127 = trunc i64 %1124 to i32
  %1128 = mul i64 %1124, %23
  %1129 = add i64 %1128, 0
  %1130 = getelementptr float, ptr %33, i64 %1129
  %1131 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1127)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1130, i32 0, i32 %1127)
  %1132 = mul i64 %1124, %23
  %1133 = add i64 %1132, 0
  %1134 = getelementptr float, ptr %33, i64 %1133
  store <vscale x 4 x float> %1131, ptr %1134, align 4
  %1135 = add i64 %1124, 1
  br label %1123

1136:                                             ; preds = %1123
  %1137 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %146, i64 8)
  %1138 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %1139 = call i64 @llvm.smin.i64(i64 %582, i64 2147483647)
  %1140 = trunc i64 %1139 to i32
  %1141 = insertelement <vscale x 4 x i32> poison, i32 %1140, i32 0
  %1142 = shufflevector <vscale x 4 x i32> %1141, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %1143 = icmp slt <vscale x 4 x i32> %1138, %1142
  br label %1144

1144:                                             ; preds = %1147, %1136
  %1145 = phi i64 [ %1156, %1147 ], [ 0, %1136 ]
  %1146 = icmp slt i64 %1145, %23
  br i1 %1146, label %1147, label %1157

1147:                                             ; preds = %1144
  %1148 = trunc i64 %1145 to i32
  %1149 = mul i64 %1145, %23
  %1150 = add i64 %1149, 0
  %1151 = getelementptr float, ptr %31, i64 %1150
  %1152 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1148)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1151, i32 0, i32 %1148)
  %1153 = mul i64 %1145, %23
  %1154 = add i64 %1153, 0
  %1155 = getelementptr float, ptr %31, i64 %1154
  store <vscale x 4 x float> %1152, ptr %1155, align 4
  %1156 = add i64 %1145, 1
  br label %1144

1157:                                             ; preds = %1144
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1143, <vscale x 4 x i1> %887, <vscale x 4 x float> %1137, <vscale x 4 x float> %875)
  br label %1158

1158:                                             ; preds = %1161, %1157
  %1159 = phi i64 [ %1170, %1161 ], [ 0, %1157 ]
  %1160 = icmp slt i64 %1159, %23
  br i1 %1160, label %1161, label %1171

1161:                                             ; preds = %1158
  %1162 = trunc i64 %1159 to i32
  %1163 = mul i64 %1159, %23
  %1164 = add i64 %1163, 0
  %1165 = getelementptr float, ptr %31, i64 %1164
  %1166 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1162)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1165, i32 0, i32 %1162)
  %1167 = mul i64 %1159, %23
  %1168 = add i64 %1167, 0
  %1169 = getelementptr float, ptr %31, i64 %1168
  store <vscale x 4 x float> %1166, ptr %1169, align 4
  %1170 = add i64 %1159, 1
  br label %1158

1171:                                             ; preds = %1174, %1158
  %1172 = phi i64 [ %1183, %1174 ], [ 0, %1158 ]
  %1173 = icmp slt i64 %1172, %23
  br i1 %1173, label %1174, label %1184

1174:                                             ; preds = %1171
  %1175 = trunc i64 %1172 to i32
  %1176 = mul i64 %1172, %23
  %1177 = add i64 %1176, 0
  %1178 = getelementptr float, ptr %29, i64 %1177
  %1179 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1175)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1178, i32 0, i32 %1175)
  %1180 = mul i64 %1172, %23
  %1181 = add i64 %1180, 0
  %1182 = getelementptr float, ptr %29, i64 %1181
  store <vscale x 4 x float> %1179, ptr %1182, align 4
  %1183 = add i64 %1172, 1
  br label %1171

1184:                                             ; preds = %1171
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1143, <vscale x 4 x i1> %922, <vscale x 4 x float> %1137, <vscale x 4 x float> %916)
  br label %1185

1185:                                             ; preds = %1188, %1184
  %1186 = phi i64 [ %1197, %1188 ], [ 0, %1184 ]
  %1187 = icmp slt i64 %1186, %23
  br i1 %1187, label %1188, label %1198

1188:                                             ; preds = %1185
  %1189 = trunc i64 %1186 to i32
  %1190 = mul i64 %1186, %23
  %1191 = add i64 %1190, 0
  %1192 = getelementptr float, ptr %29, i64 %1191
  %1193 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1189)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1192, i32 0, i32 %1189)
  %1194 = mul i64 %1186, %23
  %1195 = add i64 %1194, 0
  %1196 = getelementptr float, ptr %29, i64 %1195
  store <vscale x 4 x float> %1193, ptr %1196, align 4
  %1197 = add i64 %1186, 1
  br label %1185

1198:                                             ; preds = %1201, %1185
  %1199 = phi i64 [ %1210, %1201 ], [ 0, %1185 ]
  %1200 = icmp slt i64 %1199, %23
  br i1 %1200, label %1201, label %1211

1201:                                             ; preds = %1198
  %1202 = trunc i64 %1199 to i32
  %1203 = mul i64 %1199, %23
  %1204 = add i64 %1203, 0
  %1205 = getelementptr float, ptr %27, i64 %1204
  %1206 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1202)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1205, i32 0, i32 %1202)
  %1207 = mul i64 %1199, %23
  %1208 = add i64 %1207, 0
  %1209 = getelementptr float, ptr %27, i64 %1208
  store <vscale x 4 x float> %1206, ptr %1209, align 4
  %1210 = add i64 %1199, 1
  br label %1198

1211:                                             ; preds = %1198
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1143, <vscale x 4 x i1> %957, <vscale x 4 x float> %1137, <vscale x 4 x float> %951)
  br label %1212

1212:                                             ; preds = %1215, %1211
  %1213 = phi i64 [ %1224, %1215 ], [ 0, %1211 ]
  %1214 = icmp slt i64 %1213, %23
  br i1 %1214, label %1215, label %1225

1215:                                             ; preds = %1212
  %1216 = trunc i64 %1213 to i32
  %1217 = mul i64 %1213, %23
  %1218 = add i64 %1217, 0
  %1219 = getelementptr float, ptr %27, i64 %1218
  %1220 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1216)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1219, i32 0, i32 %1216)
  %1221 = mul i64 %1213, %23
  %1222 = add i64 %1221, 0
  %1223 = getelementptr float, ptr %27, i64 %1222
  store <vscale x 4 x float> %1220, ptr %1223, align 4
  %1224 = add i64 %1213, 1
  br label %1212

1225:                                             ; preds = %1228, %1212
  %1226 = phi i64 [ %1237, %1228 ], [ 0, %1212 ]
  %1227 = icmp slt i64 %1226, %23
  br i1 %1227, label %1228, label %1238

1228:                                             ; preds = %1225
  %1229 = trunc i64 %1226 to i32
  %1230 = mul i64 %1226, %23
  %1231 = add i64 %1230, 0
  %1232 = getelementptr float, ptr %25, i64 %1231
  %1233 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1229)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1232, i32 0, i32 %1229)
  %1234 = mul i64 %1226, %23
  %1235 = add i64 %1234, 0
  %1236 = getelementptr float, ptr %25, i64 %1235
  store <vscale x 4 x float> %1233, ptr %1236, align 4
  %1237 = add i64 %1226, 1
  br label %1225

1238:                                             ; preds = %1225
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1143, <vscale x 4 x i1> %992, <vscale x 4 x float> %1137, <vscale x 4 x float> %986)
  br label %1239

1239:                                             ; preds = %1242, %1238
  %1240 = phi i64 [ %1251, %1242 ], [ 0, %1238 ]
  %1241 = icmp slt i64 %1240, %23
  br i1 %1241, label %1242, label %1252

1242:                                             ; preds = %1239
  %1243 = trunc i64 %1240 to i32
  %1244 = mul i64 %1240, %23
  %1245 = add i64 %1244, 0
  %1246 = getelementptr float, ptr %25, i64 %1245
  %1247 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1243)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1246, i32 0, i32 %1243)
  %1248 = mul i64 %1240, %23
  %1249 = add i64 %1248, 0
  %1250 = getelementptr float, ptr %25, i64 %1249
  store <vscale x 4 x float> %1247, ptr %1250, align 4
  %1251 = add i64 %1240, 1
  br label %1239

1252:                                             ; preds = %1239
  %1253 = call <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float> %146, i64 12)
  %1254 = call <vscale x 4 x i32> @llvm.stepvector.nxv4i32()
  %1255 = call i64 @llvm.smin.i64(i64 %784, i64 2147483647)
  %1256 = trunc i64 %1255 to i32
  %1257 = insertelement <vscale x 4 x i32> poison, i32 %1256, i32 0
  %1258 = shufflevector <vscale x 4 x i32> %1257, <vscale x 4 x i32> poison, <vscale x 4 x i32> zeroinitializer
  %1259 = icmp slt <vscale x 4 x i32> %1254, %1258
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 0, <vscale x 4 x i1> %1259, <vscale x 4 x i1> %887, <vscale x 4 x float> %1253, <vscale x 4 x float> %875)
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 1, <vscale x 4 x i1> %1259, <vscale x 4 x i1> %922, <vscale x 4 x float> %1253, <vscale x 4 x float> %916)
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 2, <vscale x 4 x i1> %1259, <vscale x 4 x i1> %957, <vscale x 4 x float> %1253, <vscale x 4 x float> %951)
  call void @llvm.aarch64.sme.mopa.nxv4f32(i32 3, <vscale x 4 x i1> %1259, <vscale x 4 x i1> %992, <vscale x 4 x float> %1253, <vscale x 4 x float> %986)
  br label %1260

1260:                                             ; preds = %1654, %1252
  %1261 = phi i64 [ %1673, %1654 ], [ 0, %1252 ]
  %1262 = icmp slt i64 %1261, %23
  br i1 %1262, label %1263, label %1674

1263:                                             ; preds = %1260
  %1264 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1> %131)
  %1265 = trunc i64 %1261 to i32
  %1266 = call <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1> %1264, <vscale x 16 x i1> %111, i32 %1265)
  %1267 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1> %1266)
  %1268 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1267, i64 0)
  br label %1269

1269:                                             ; preds = %1272, %1263
  %1270 = phi i64 [ %1281, %1272 ], [ 0, %1263 ]
  %1271 = icmp slt i64 %1270, %23
  br i1 %1271, label %1272, label %1282

1272:                                             ; preds = %1269
  %1273 = trunc i64 %1270 to i32
  %1274 = mul i64 %1270, %23
  %1275 = add i64 %1274, 0
  %1276 = getelementptr float, ptr %47, i64 %1275
  %1277 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1273)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1276, i32 0, i32 %1273)
  %1278 = mul i64 %1270, %23
  %1279 = add i64 %1278, 0
  %1280 = getelementptr float, ptr %47, i64 %1279
  store <vscale x 4 x float> %1277, ptr %1280, align 4
  %1281 = add i64 %1270, 1
  br label %1269

1282:                                             ; preds = %1269
  %1283 = getelementptr float, ptr %15, i64 %125
  %1284 = mul i64 %1261, %19
  %1285 = add i64 %1284, 0
  %1286 = getelementptr float, ptr %1283, i64 %1285
  %1287 = trunc i64 %1261 to i32
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1268, ptr %1286, i32 0, i32 %1287)
  br label %1288

1288:                                             ; preds = %1291, %1282
  %1289 = phi i64 [ %1300, %1291 ], [ 0, %1282 ]
  %1290 = icmp slt i64 %1289, %23
  br i1 %1290, label %1291, label %1301

1291:                                             ; preds = %1288
  %1292 = trunc i64 %1289 to i32
  %1293 = mul i64 %1289, %23
  %1294 = add i64 %1293, 0
  %1295 = getelementptr float, ptr %47, i64 %1294
  %1296 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1292)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1295, i32 0, i32 %1292)
  %1297 = mul i64 %1289, %23
  %1298 = add i64 %1297, 0
  %1299 = getelementptr float, ptr %47, i64 %1298
  store <vscale x 4 x float> %1296, ptr %1299, align 4
  %1300 = add i64 %1289, 1
  br label %1288

1301:                                             ; preds = %1288
  %1302 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1267, i64 4)
  br label %1303

1303:                                             ; preds = %1306, %1301
  %1304 = phi i64 [ %1315, %1306 ], [ 0, %1301 ]
  %1305 = icmp slt i64 %1304, %23
  br i1 %1305, label %1306, label %1316

1306:                                             ; preds = %1303
  %1307 = trunc i64 %1304 to i32
  %1308 = mul i64 %1304, %23
  %1309 = add i64 %1308, 0
  %1310 = getelementptr float, ptr %45, i64 %1309
  %1311 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1307)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1310, i32 0, i32 %1307)
  %1312 = mul i64 %1304, %23
  %1313 = add i64 %1312, 0
  %1314 = getelementptr float, ptr %45, i64 %1313
  store <vscale x 4 x float> %1311, ptr %1314, align 4
  %1315 = add i64 %1304, 1
  br label %1303

1316:                                             ; preds = %1303
  %1317 = add i64 %1284, %23
  %1318 = getelementptr float, ptr %1283, i64 %1317
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1302, ptr %1318, i32 0, i32 %1287)
  br label %1319

1319:                                             ; preds = %1322, %1316
  %1320 = phi i64 [ %1331, %1322 ], [ 0, %1316 ]
  %1321 = icmp slt i64 %1320, %23
  br i1 %1321, label %1322, label %1332

1322:                                             ; preds = %1319
  %1323 = trunc i64 %1320 to i32
  %1324 = mul i64 %1320, %23
  %1325 = add i64 %1324, 0
  %1326 = getelementptr float, ptr %45, i64 %1325
  %1327 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1323)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1326, i32 0, i32 %1323)
  %1328 = mul i64 %1320, %23
  %1329 = add i64 %1328, 0
  %1330 = getelementptr float, ptr %45, i64 %1329
  store <vscale x 4 x float> %1327, ptr %1330, align 4
  %1331 = add i64 %1320, 1
  br label %1319

1332:                                             ; preds = %1319
  %1333 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1267, i64 8)
  br label %1334

1334:                                             ; preds = %1337, %1332
  %1335 = phi i64 [ %1346, %1337 ], [ 0, %1332 ]
  %1336 = icmp slt i64 %1335, %23
  br i1 %1336, label %1337, label %1347

1337:                                             ; preds = %1334
  %1338 = trunc i64 %1335 to i32
  %1339 = mul i64 %1335, %23
  %1340 = add i64 %1339, 0
  %1341 = getelementptr float, ptr %43, i64 %1340
  %1342 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1338)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1341, i32 0, i32 %1338)
  %1343 = mul i64 %1335, %23
  %1344 = add i64 %1343, 0
  %1345 = getelementptr float, ptr %43, i64 %1344
  store <vscale x 4 x float> %1342, ptr %1345, align 4
  %1346 = add i64 %1335, 1
  br label %1334

1347:                                             ; preds = %1334
  %1348 = add i64 %1284, %274
  %1349 = getelementptr float, ptr %1283, i64 %1348
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1333, ptr %1349, i32 0, i32 %1287)
  br label %1350

1350:                                             ; preds = %1353, %1347
  %1351 = phi i64 [ %1362, %1353 ], [ 0, %1347 ]
  %1352 = icmp slt i64 %1351, %23
  br i1 %1352, label %1353, label %1363

1353:                                             ; preds = %1350
  %1354 = trunc i64 %1351 to i32
  %1355 = mul i64 %1351, %23
  %1356 = add i64 %1355, 0
  %1357 = getelementptr float, ptr %43, i64 %1356
  %1358 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1354)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1357, i32 0, i32 %1354)
  %1359 = mul i64 %1351, %23
  %1360 = add i64 %1359, 0
  %1361 = getelementptr float, ptr %43, i64 %1360
  store <vscale x 4 x float> %1358, ptr %1361, align 4
  %1362 = add i64 %1351, 1
  br label %1350

1363:                                             ; preds = %1350
  %1364 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1267, i64 12)
  br label %1365

1365:                                             ; preds = %1368, %1363
  %1366 = phi i64 [ %1377, %1368 ], [ 0, %1363 ]
  %1367 = icmp slt i64 %1366, %23
  br i1 %1367, label %1368, label %1378

1368:                                             ; preds = %1365
  %1369 = trunc i64 %1366 to i32
  %1370 = mul i64 %1366, %23
  %1371 = add i64 %1370, 0
  %1372 = getelementptr float, ptr %41, i64 %1371
  %1373 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1369)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1372, i32 0, i32 %1369)
  %1374 = mul i64 %1366, %23
  %1375 = add i64 %1374, 0
  %1376 = getelementptr float, ptr %41, i64 %1375
  store <vscale x 4 x float> %1373, ptr %1376, align 4
  %1377 = add i64 %1366, 1
  br label %1365

1378:                                             ; preds = %1365
  %1379 = add i64 %1284, %328
  %1380 = getelementptr float, ptr %1283, i64 %1379
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1364, ptr %1380, i32 0, i32 %1287)
  br label %1381

1381:                                             ; preds = %1384, %1378
  %1382 = phi i64 [ %1393, %1384 ], [ 0, %1378 ]
  %1383 = icmp slt i64 %1382, %23
  br i1 %1383, label %1384, label %1394

1384:                                             ; preds = %1381
  %1385 = trunc i64 %1382 to i32
  %1386 = mul i64 %1382, %23
  %1387 = add i64 %1386, 0
  %1388 = getelementptr float, ptr %41, i64 %1387
  %1389 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1385)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1388, i32 0, i32 %1385)
  %1390 = mul i64 %1382, %23
  %1391 = add i64 %1390, 0
  %1392 = getelementptr float, ptr %41, i64 %1391
  store <vscale x 4 x float> %1389, ptr %1392, align 4
  %1393 = add i64 %1382, 1
  br label %1381

1394:                                             ; preds = %1381
  %1395 = add i64 %23, %1261
  %1396 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1> %131)
  %1397 = trunc i64 %1395 to i32
  %1398 = call <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1> %1396, <vscale x 16 x i1> %111, i32 %1397)
  %1399 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1> %1398)
  %1400 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1399, i64 0)
  br label %1401

1401:                                             ; preds = %1404, %1394
  %1402 = phi i64 [ %1413, %1404 ], [ 0, %1394 ]
  %1403 = icmp slt i64 %1402, %23
  br i1 %1403, label %1404, label %1414

1404:                                             ; preds = %1401
  %1405 = trunc i64 %1402 to i32
  %1406 = mul i64 %1402, %23
  %1407 = add i64 %1406, 0
  %1408 = getelementptr float, ptr %39, i64 %1407
  %1409 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1405)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1408, i32 0, i32 %1405)
  %1410 = mul i64 %1402, %23
  %1411 = add i64 %1410, 0
  %1412 = getelementptr float, ptr %39, i64 %1411
  store <vscale x 4 x float> %1409, ptr %1412, align 4
  %1413 = add i64 %1402, 1
  br label %1401

1414:                                             ; preds = %1401
  %1415 = mul i64 %1395, %19
  %1416 = add i64 %1415, 0
  %1417 = getelementptr float, ptr %1283, i64 %1416
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1400, ptr %1417, i32 0, i32 %1287)
  br label %1418

1418:                                             ; preds = %1421, %1414
  %1419 = phi i64 [ %1430, %1421 ], [ 0, %1414 ]
  %1420 = icmp slt i64 %1419, %23
  br i1 %1420, label %1421, label %1431

1421:                                             ; preds = %1418
  %1422 = trunc i64 %1419 to i32
  %1423 = mul i64 %1419, %23
  %1424 = add i64 %1423, 0
  %1425 = getelementptr float, ptr %39, i64 %1424
  %1426 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1422)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1425, i32 0, i32 %1422)
  %1427 = mul i64 %1419, %23
  %1428 = add i64 %1427, 0
  %1429 = getelementptr float, ptr %39, i64 %1428
  store <vscale x 4 x float> %1426, ptr %1429, align 4
  %1430 = add i64 %1419, 1
  br label %1418

1431:                                             ; preds = %1418
  %1432 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1399, i64 4)
  br label %1433

1433:                                             ; preds = %1436, %1431
  %1434 = phi i64 [ %1445, %1436 ], [ 0, %1431 ]
  %1435 = icmp slt i64 %1434, %23
  br i1 %1435, label %1436, label %1446

1436:                                             ; preds = %1433
  %1437 = trunc i64 %1434 to i32
  %1438 = mul i64 %1434, %23
  %1439 = add i64 %1438, 0
  %1440 = getelementptr float, ptr %37, i64 %1439
  %1441 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1437)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1440, i32 0, i32 %1437)
  %1442 = mul i64 %1434, %23
  %1443 = add i64 %1442, 0
  %1444 = getelementptr float, ptr %37, i64 %1443
  store <vscale x 4 x float> %1441, ptr %1444, align 4
  %1445 = add i64 %1434, 1
  br label %1433

1446:                                             ; preds = %1433
  %1447 = add i64 %1415, %23
  %1448 = getelementptr float, ptr %1283, i64 %1447
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1432, ptr %1448, i32 0, i32 %1287)
  br label %1449

1449:                                             ; preds = %1452, %1446
  %1450 = phi i64 [ %1461, %1452 ], [ 0, %1446 ]
  %1451 = icmp slt i64 %1450, %23
  br i1 %1451, label %1452, label %1462

1452:                                             ; preds = %1449
  %1453 = trunc i64 %1450 to i32
  %1454 = mul i64 %1450, %23
  %1455 = add i64 %1454, 0
  %1456 = getelementptr float, ptr %37, i64 %1455
  %1457 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1453)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1456, i32 0, i32 %1453)
  %1458 = mul i64 %1450, %23
  %1459 = add i64 %1458, 0
  %1460 = getelementptr float, ptr %37, i64 %1459
  store <vscale x 4 x float> %1457, ptr %1460, align 4
  %1461 = add i64 %1450, 1
  br label %1449

1462:                                             ; preds = %1449
  %1463 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1399, i64 8)
  br label %1464

1464:                                             ; preds = %1467, %1462
  %1465 = phi i64 [ %1476, %1467 ], [ 0, %1462 ]
  %1466 = icmp slt i64 %1465, %23
  br i1 %1466, label %1467, label %1477

1467:                                             ; preds = %1464
  %1468 = trunc i64 %1465 to i32
  %1469 = mul i64 %1465, %23
  %1470 = add i64 %1469, 0
  %1471 = getelementptr float, ptr %35, i64 %1470
  %1472 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1468)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1471, i32 0, i32 %1468)
  %1473 = mul i64 %1465, %23
  %1474 = add i64 %1473, 0
  %1475 = getelementptr float, ptr %35, i64 %1474
  store <vscale x 4 x float> %1472, ptr %1475, align 4
  %1476 = add i64 %1465, 1
  br label %1464

1477:                                             ; preds = %1464
  %1478 = add i64 %1415, %274
  %1479 = getelementptr float, ptr %1283, i64 %1478
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1463, ptr %1479, i32 0, i32 %1287)
  br label %1480

1480:                                             ; preds = %1483, %1477
  %1481 = phi i64 [ %1492, %1483 ], [ 0, %1477 ]
  %1482 = icmp slt i64 %1481, %23
  br i1 %1482, label %1483, label %1493

1483:                                             ; preds = %1480
  %1484 = trunc i64 %1481 to i32
  %1485 = mul i64 %1481, %23
  %1486 = add i64 %1485, 0
  %1487 = getelementptr float, ptr %35, i64 %1486
  %1488 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1484)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1487, i32 0, i32 %1484)
  %1489 = mul i64 %1481, %23
  %1490 = add i64 %1489, 0
  %1491 = getelementptr float, ptr %35, i64 %1490
  store <vscale x 4 x float> %1488, ptr %1491, align 4
  %1492 = add i64 %1481, 1
  br label %1480

1493:                                             ; preds = %1480
  %1494 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1399, i64 12)
  br label %1495

1495:                                             ; preds = %1498, %1493
  %1496 = phi i64 [ %1507, %1498 ], [ 0, %1493 ]
  %1497 = icmp slt i64 %1496, %23
  br i1 %1497, label %1498, label %1508

1498:                                             ; preds = %1495
  %1499 = trunc i64 %1496 to i32
  %1500 = mul i64 %1496, %23
  %1501 = add i64 %1500, 0
  %1502 = getelementptr float, ptr %33, i64 %1501
  %1503 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1499)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1502, i32 0, i32 %1499)
  %1504 = mul i64 %1496, %23
  %1505 = add i64 %1504, 0
  %1506 = getelementptr float, ptr %33, i64 %1505
  store <vscale x 4 x float> %1503, ptr %1506, align 4
  %1507 = add i64 %1496, 1
  br label %1495

1508:                                             ; preds = %1495
  %1509 = add i64 %1415, %328
  %1510 = getelementptr float, ptr %1283, i64 %1509
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1494, ptr %1510, i32 0, i32 %1287)
  br label %1511

1511:                                             ; preds = %1514, %1508
  %1512 = phi i64 [ %1523, %1514 ], [ 0, %1508 ]
  %1513 = icmp slt i64 %1512, %23
  br i1 %1513, label %1514, label %1524

1514:                                             ; preds = %1511
  %1515 = trunc i64 %1512 to i32
  %1516 = mul i64 %1512, %23
  %1517 = add i64 %1516, 0
  %1518 = getelementptr float, ptr %33, i64 %1517
  %1519 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1515)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1518, i32 0, i32 %1515)
  %1520 = mul i64 %1512, %23
  %1521 = add i64 %1520, 0
  %1522 = getelementptr float, ptr %33, i64 %1521
  store <vscale x 4 x float> %1519, ptr %1522, align 4
  %1523 = add i64 %1512, 1
  br label %1511

1524:                                             ; preds = %1511
  %1525 = add i64 %274, %1261
  %1526 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1> %131)
  %1527 = trunc i64 %1525 to i32
  %1528 = call <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1> %1526, <vscale x 16 x i1> %111, i32 %1527)
  %1529 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1> %1528)
  %1530 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1529, i64 0)
  br label %1531

1531:                                             ; preds = %1534, %1524
  %1532 = phi i64 [ %1543, %1534 ], [ 0, %1524 ]
  %1533 = icmp slt i64 %1532, %23
  br i1 %1533, label %1534, label %1544

1534:                                             ; preds = %1531
  %1535 = trunc i64 %1532 to i32
  %1536 = mul i64 %1532, %23
  %1537 = add i64 %1536, 0
  %1538 = getelementptr float, ptr %31, i64 %1537
  %1539 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1535)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1538, i32 0, i32 %1535)
  %1540 = mul i64 %1532, %23
  %1541 = add i64 %1540, 0
  %1542 = getelementptr float, ptr %31, i64 %1541
  store <vscale x 4 x float> %1539, ptr %1542, align 4
  %1543 = add i64 %1532, 1
  br label %1531

1544:                                             ; preds = %1531
  %1545 = mul i64 %1525, %19
  %1546 = add i64 %1545, 0
  %1547 = getelementptr float, ptr %1283, i64 %1546
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1530, ptr %1547, i32 0, i32 %1287)
  br label %1548

1548:                                             ; preds = %1551, %1544
  %1549 = phi i64 [ %1560, %1551 ], [ 0, %1544 ]
  %1550 = icmp slt i64 %1549, %23
  br i1 %1550, label %1551, label %1561

1551:                                             ; preds = %1548
  %1552 = trunc i64 %1549 to i32
  %1553 = mul i64 %1549, %23
  %1554 = add i64 %1553, 0
  %1555 = getelementptr float, ptr %31, i64 %1554
  %1556 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1552)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1555, i32 0, i32 %1552)
  %1557 = mul i64 %1549, %23
  %1558 = add i64 %1557, 0
  %1559 = getelementptr float, ptr %31, i64 %1558
  store <vscale x 4 x float> %1556, ptr %1559, align 4
  %1560 = add i64 %1549, 1
  br label %1548

1561:                                             ; preds = %1548
  %1562 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1529, i64 4)
  br label %1563

1563:                                             ; preds = %1566, %1561
  %1564 = phi i64 [ %1575, %1566 ], [ 0, %1561 ]
  %1565 = icmp slt i64 %1564, %23
  br i1 %1565, label %1566, label %1576

1566:                                             ; preds = %1563
  %1567 = trunc i64 %1564 to i32
  %1568 = mul i64 %1564, %23
  %1569 = add i64 %1568, 0
  %1570 = getelementptr float, ptr %29, i64 %1569
  %1571 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1567)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1570, i32 0, i32 %1567)
  %1572 = mul i64 %1564, %23
  %1573 = add i64 %1572, 0
  %1574 = getelementptr float, ptr %29, i64 %1573
  store <vscale x 4 x float> %1571, ptr %1574, align 4
  %1575 = add i64 %1564, 1
  br label %1563

1576:                                             ; preds = %1563
  %1577 = add i64 %1545, %23
  %1578 = getelementptr float, ptr %1283, i64 %1577
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1562, ptr %1578, i32 0, i32 %1287)
  br label %1579

1579:                                             ; preds = %1582, %1576
  %1580 = phi i64 [ %1591, %1582 ], [ 0, %1576 ]
  %1581 = icmp slt i64 %1580, %23
  br i1 %1581, label %1582, label %1592

1582:                                             ; preds = %1579
  %1583 = trunc i64 %1580 to i32
  %1584 = mul i64 %1580, %23
  %1585 = add i64 %1584, 0
  %1586 = getelementptr float, ptr %29, i64 %1585
  %1587 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1583)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1586, i32 0, i32 %1583)
  %1588 = mul i64 %1580, %23
  %1589 = add i64 %1588, 0
  %1590 = getelementptr float, ptr %29, i64 %1589
  store <vscale x 4 x float> %1587, ptr %1590, align 4
  %1591 = add i64 %1580, 1
  br label %1579

1592:                                             ; preds = %1579
  %1593 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1529, i64 8)
  br label %1594

1594:                                             ; preds = %1597, %1592
  %1595 = phi i64 [ %1606, %1597 ], [ 0, %1592 ]
  %1596 = icmp slt i64 %1595, %23
  br i1 %1596, label %1597, label %1607

1597:                                             ; preds = %1594
  %1598 = trunc i64 %1595 to i32
  %1599 = mul i64 %1595, %23
  %1600 = add i64 %1599, 0
  %1601 = getelementptr float, ptr %27, i64 %1600
  %1602 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1598)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1601, i32 0, i32 %1598)
  %1603 = mul i64 %1595, %23
  %1604 = add i64 %1603, 0
  %1605 = getelementptr float, ptr %27, i64 %1604
  store <vscale x 4 x float> %1602, ptr %1605, align 4
  %1606 = add i64 %1595, 1
  br label %1594

1607:                                             ; preds = %1594
  %1608 = add i64 %1545, %274
  %1609 = getelementptr float, ptr %1283, i64 %1608
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1593, ptr %1609, i32 0, i32 %1287)
  br label %1610

1610:                                             ; preds = %1613, %1607
  %1611 = phi i64 [ %1622, %1613 ], [ 0, %1607 ]
  %1612 = icmp slt i64 %1611, %23
  br i1 %1612, label %1613, label %1623

1613:                                             ; preds = %1610
  %1614 = trunc i64 %1611 to i32
  %1615 = mul i64 %1611, %23
  %1616 = add i64 %1615, 0
  %1617 = getelementptr float, ptr %27, i64 %1616
  %1618 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1614)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1617, i32 0, i32 %1614)
  %1619 = mul i64 %1611, %23
  %1620 = add i64 %1619, 0
  %1621 = getelementptr float, ptr %27, i64 %1620
  store <vscale x 4 x float> %1618, ptr %1621, align 4
  %1622 = add i64 %1611, 1
  br label %1610

1623:                                             ; preds = %1610
  %1624 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1529, i64 12)
  br label %1625

1625:                                             ; preds = %1628, %1623
  %1626 = phi i64 [ %1637, %1628 ], [ 0, %1623 ]
  %1627 = icmp slt i64 %1626, %23
  br i1 %1627, label %1628, label %1638

1628:                                             ; preds = %1625
  %1629 = trunc i64 %1626 to i32
  %1630 = mul i64 %1626, %23
  %1631 = add i64 %1630, 0
  %1632 = getelementptr float, ptr %25, i64 %1631
  %1633 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1629)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1632, i32 0, i32 %1629)
  %1634 = mul i64 %1626, %23
  %1635 = add i64 %1634, 0
  %1636 = getelementptr float, ptr %25, i64 %1635
  store <vscale x 4 x float> %1633, ptr %1636, align 4
  %1637 = add i64 %1626, 1
  br label %1625

1638:                                             ; preds = %1625
  %1639 = add i64 %1545, %328
  %1640 = getelementptr float, ptr %1283, i64 %1639
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1624, ptr %1640, i32 0, i32 %1287)
  br label %1641

1641:                                             ; preds = %1644, %1638
  %1642 = phi i64 [ %1653, %1644 ], [ 0, %1638 ]
  %1643 = icmp slt i64 %1642, %23
  br i1 %1643, label %1644, label %1654

1644:                                             ; preds = %1641
  %1645 = trunc i64 %1642 to i32
  %1646 = mul i64 %1642, %23
  %1647 = add i64 %1646, 0
  %1648 = getelementptr float, ptr %25, i64 %1647
  %1649 = call <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float> poison, <vscale x 4 x i1> splat (i1 true), i32 0, i32 %1645)
  call void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1> splat (i1 true), ptr %1648, i32 0, i32 %1645)
  %1650 = mul i64 %1642, %23
  %1651 = add i64 %1650, 0
  %1652 = getelementptr float, ptr %25, i64 %1651
  store <vscale x 4 x float> %1649, ptr %1652, align 4
  %1653 = add i64 %1642, 1
  br label %1641

1654:                                             ; preds = %1641
  %1655 = add i64 %328, %1261
  %1656 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1> %131)
  %1657 = trunc i64 %1655 to i32
  %1658 = call <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1> %1656, <vscale x 16 x i1> %111, i32 %1657)
  %1659 = call <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1> %1658)
  %1660 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1659, i64 0)
  %1661 = mul i64 %1655, %19
  %1662 = add i64 %1661, 0
  %1663 = getelementptr float, ptr %1283, i64 %1662
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1660, ptr %1663, i32 0, i32 %1287)
  %1664 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1659, i64 4)
  %1665 = add i64 %1661, %23
  %1666 = getelementptr float, ptr %1283, i64 %1665
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1664, ptr %1666, i32 1, i32 %1287)
  %1667 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1659, i64 8)
  %1668 = add i64 %1661, %274
  %1669 = getelementptr float, ptr %1283, i64 %1668
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1667, ptr %1669, i32 2, i32 %1287)
  %1670 = call <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1> %1659, i64 12)
  %1671 = add i64 %1661, %328
  %1672 = getelementptr float, ptr %1283, i64 %1671
  call void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1> %1670, ptr %1672, i32 3, i32 %1287)
  %1673 = add i64 %1261, 1
  br label %1260

1674:                                             ; preds = %1260
  %1675 = add i64 %133, 1
  br label %132

1676:                                             ; preds = %132
  %1677 = add i64 %113, %48
  br label %112

1678:                                             ; preds = %112
  %1679 = add i64 %101, %48
  br label %100

1680:                                             ; preds = %100
  %1681 = add i64 %95, 128
  br label %94

1682:                                             ; preds = %94
  %1683 = add i64 %69, 16
  br label %68

1684:                                             ; preds = %68
  %1685 = add i64 %62, 16
  br label %61

1686:                                             ; preds = %61
  %1687 = add i64 %56, 128
  br label %55

1688:                                             ; preds = %55
  %1689 = add i64 %50, 128
  br label %49

1690:                                             ; preds = %49
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.vscale.i64() #1

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smin.i64(i64, i64) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 16 x i32> @llvm.stepvector.nxv16i32() #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, inaccessiblemem: readwrite)
declare void @llvm.prefetch.p0(ptr readonly captures(none), i32 immarg range(i32 0, 2), i32 immarg range(i32 0, 4), i32 immarg range(i32 0, 2)) #4

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: read)
declare <vscale x 16 x float> @llvm.masked.load.nxv16f32.p0(ptr captures(none), <vscale x 16 x i1>, <vscale x 16 x float>) #5

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <vscale x 4 x float> @llvm.vector.extract.nxv4f32.nxv16f32(<vscale x 16 x float>, i64 immarg) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 4 x i32> @llvm.stepvector.nxv4i32() #3

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(target_mem1: readwrite)
declare void @llvm.aarch64.sme.mopa.nxv4f32(i32 immarg, <vscale x 4 x i1>, <vscale x 4 x i1>, <vscale x 4 x float>, <vscale x 4 x float>) #6

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <vscale x 16 x i1> @llvm.aarch64.sve.convert.to.svbool.nxv16i1(<vscale x 16 x i1>) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 16 x i1> @llvm.aarch64.sve.psel.nxv16i1(<vscale x 16 x i1>, <vscale x 16 x i1>, i32) #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <vscale x 16 x i1> @llvm.aarch64.sve.convert.from.svbool.nxv16i1(<vscale x 16 x i1>) #1

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare <vscale x 4 x i1> @llvm.vector.extract.nxv4i1.nxv16i1(<vscale x 16 x i1>, i64 immarg) #1

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, target_mem1: readwrite)
declare void @llvm.aarch64.sme.st1w.horiz.p0(<vscale x 4 x i1>, ptr, i32 immarg, i32) #7

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(target_mem1: read)
declare <vscale x 4 x float> @llvm.aarch64.sme.read.horiz.nxv4f32(<vscale x 4 x float>, <vscale x 4 x i1>, i32 immarg, i32) #8

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, target_mem1: readwrite)
declare void @llvm.aarch64.sme.ld1w.horiz.p0(<vscale x 4 x i1>, ptr, i32 immarg, i32) #7

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: read)
declare <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr captures(none), <vscale x 4 x i1>, <vscale x 4 x float>) #5

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(target_mem1: readwrite)
declare void @llvm.aarch64.sme.write.horiz.nxv4f32(i32 immarg, i32, <vscale x 4 x i1>, <vscale x 4 x float>) #6

attributes #0 = { "aarch64_new_za" "aarch64_pstate_sm_body" }
attributes #1 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(none) }
attributes #4 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, inaccessiblemem: readwrite) }
attributes #5 = { nocallback nofree nosync nounwind willreturn memory(argmem: read) }
attributes #6 = { nocallback nofree nosync nounwind willreturn memory(target_mem1: readwrite) }
attributes #7 = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite, target_mem1: readwrite) }
attributes #8 = { nocallback nofree nosync nounwind willreturn memory(target_mem1: read) }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
