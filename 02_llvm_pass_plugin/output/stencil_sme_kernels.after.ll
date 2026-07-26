; ModuleID = '/Users/alpaca/Documents/SME/SME1/02_llvm_pass_plugin/build/stencil_sme_kernels.llvm18.ll'
source_filename = "stencil_sme_kernels.c"
target datalayout = "e-m:o-i64:64-i128:128-n32:64-S128"
target triple = "arm64-apple-macosx16.0.0"

; Function Attrs: nofree norecurse nosync nounwind ssp memory(argmem: readwrite) uwtable(sync) vscale_range(1,16)
define void @stencil_2d5p_sme_f32(i64 noundef %0, i64 noundef %1, ptr noalias nocapture noundef readonly %2, ptr noalias nocapture noundef writeonly %3, float noundef %4, float noundef %5) local_unnamed_addr #0 {
  %7 = icmp ult i64 %0, 3
  %8 = icmp ult i64 %1, 3
  %9 = or i1 %7, %8
  br i1 %9, label %.loopexit, label %10

10:                                               ; preds = %6
  %11 = tail call i64 @llvm.aarch64.sme.cntsw()
  %12 = add i64 %1, -1
  %13 = sub i64 0, %1
  %14 = insertelement <vscale x 4 x float> poison, float %5, i64 0
  %15 = shufflevector <vscale x 4 x float> %14, <vscale x 4 x float> poison, <vscale x 4 x i32> zeroinitializer
  %16 = insertelement <vscale x 4 x float> poison, float %4, i64 0
  %17 = shufflevector <vscale x 4 x float> %16, <vscale x 4 x float> poison, <vscale x 4 x i32> zeroinitializer
  %prefetch.step = shl i64 %11, 2
  br label %21

18:                                               ; preds = %34
  %19 = add nuw i64 %22, 1
  %20 = icmp eq i64 %19, %0
  br i1 %20, label %.loopexit, label %21, !llvm.loop !6

21:                                               ; preds = %18, %10
  %22 = phi i64 [ 2, %10 ], [ %19, %18 ]
  %23 = phi i64 [ 1, %10 ], [ %22, %18 ]
  %24 = mul i64 %23, %1
  %25 = getelementptr inbounds float, ptr %2, i64 %24
  %26 = getelementptr inbounds float, ptr %25, i64 %13
  %27 = getelementptr inbounds float, ptr %25, i64 %1
  %28 = getelementptr inbounds float, ptr %3, i64 %24
  br label %29

29:                                               ; preds = %34, %21
  %30 = phi i64 [ 1, %21 ], [ %50, %34 ]
  %31 = tail call <vscale x 4 x i1> @llvm.aarch64.sve.whilelo.nxv4i1.i64(i64 %30, i64 %12)
  %32 = getelementptr inbounds float, ptr %25, i64 %30
  %prefetch.future.x = add i64 %30, %prefetch.step
  %prefetch.in.range = icmp ult i64 %prefetch.future.x, %12
  br i1 %prefetch.in.range, label %33, label %34

33:                                               ; preds = %29
  %prefetch.addr = getelementptr float, ptr %26, i64 %prefetch.future.x
  tail call void @llvm.aarch64.prefetch(ptr %prefetch.addr, i32 0, i32 0, i32 0, i32 1)
  %prefetch.addr4 = getelementptr float, ptr %27, i64 %prefetch.future.x
  tail call void @llvm.aarch64.prefetch(ptr %prefetch.addr4, i32 0, i32 0, i32 0, i32 1)
  br label %34

34:                                               ; preds = %29, %33
  %35 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %32, i32 1, <vscale x 4 x i1> %31, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %36 = getelementptr inbounds i8, ptr %32, i64 -4
  %37 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %36, i32 1, <vscale x 4 x i1> %31, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %38 = getelementptr inbounds i8, ptr %32, i64 4
  %39 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %38, i32 1, <vscale x 4 x i1> %31, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %40 = getelementptr inbounds float, ptr %26, i64 %30
  %41 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %40, i32 1, <vscale x 4 x i1> %31, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %42 = getelementptr inbounds float, ptr %27, i64 %30
  %43 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %42, i32 1, <vscale x 4 x i1> %31, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %44 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %31, <vscale x 4 x float> %37, <vscale x 4 x float> %39)
  %45 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %31, <vscale x 4 x float> %44, <vscale x 4 x float> %41)
  %46 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %31, <vscale x 4 x float> %45, <vscale x 4 x float> %43)
  %47 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fmul.u.nxv4f32(<vscale x 4 x i1> %31, <vscale x 4 x float> %46, <vscale x 4 x float> %15)
  %48 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fmla.u.nxv4f32(<vscale x 4 x i1> %31, <vscale x 4 x float> %47, <vscale x 4 x float> %35, <vscale x 4 x float> %17)
  %49 = getelementptr inbounds float, ptr %28, i64 %30
  tail call void @llvm.masked.store.nxv4f32.p0(<vscale x 4 x float> %48, ptr %49, i32 1, <vscale x 4 x i1> %31), !tbaa !9
  %50 = add i64 %30, %11
  %51 = icmp ult i64 %50, %12
  br i1 %51, label %29, label %18, !llvm.loop !13

.loopexit:                                        ; preds = %18, %6
  ret void
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(none)
declare i64 @llvm.aarch64.sme.cntsw() #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 4 x i1> @llvm.aarch64.sve.whilelo.nxv4i1.i64(i64, i64) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1>, <vscale x 4 x float>, <vscale x 4 x float>) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 4 x float> @llvm.aarch64.sve.fmul.u.nxv4f32(<vscale x 4 x i1>, <vscale x 4 x float>, <vscale x 4 x float>) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(none)
declare <vscale x 4 x float> @llvm.aarch64.sve.fmla.u.nxv4f32(<vscale x 4 x i1>, <vscale x 4 x float>, <vscale x 4 x float>, <vscale x 4 x float>) #1

; Function Attrs: nofree norecurse nosync nounwind ssp memory(argmem: readwrite) uwtable(sync) vscale_range(1,16)
define void @stencil_3d7p_sme_f32(i64 noundef %0, i64 noundef %1, i64 noundef %2, ptr noalias nocapture noundef readonly %3, ptr noalias nocapture noundef writeonly %4, float noundef %5, float noundef %6) local_unnamed_addr #0 {
  %8 = icmp ult i64 %0, 3
  %9 = icmp ult i64 %1, 3
  %10 = or i1 %8, %9
  %11 = icmp ult i64 %2, 3
  %12 = or i1 %10, %11
  br i1 %12, label %.loopexit, label %13

13:                                               ; preds = %7
  %14 = tail call i64 @llvm.aarch64.sme.cntsw()
  %15 = mul i64 %2, %1
  %16 = add i64 %2, -1
  %17 = sub i64 0, %2
  %18 = sub i64 0, %15
  %19 = insertelement <vscale x 4 x float> poison, float %6, i64 0
  %20 = shufflevector <vscale x 4 x float> %19, <vscale x 4 x float> poison, <vscale x 4 x i32> zeroinitializer
  %21 = insertelement <vscale x 4 x float> poison, float %5, i64 0
  %22 = shufflevector <vscale x 4 x float> %21, <vscale x 4 x float> poison, <vscale x 4 x i32> zeroinitializer
  %prefetch.step = shl i64 %14, 2
  %prefetch.step9 = mul i64 %14, 10
  br label %26

23:                                               ; preds = %30
  %24 = add nuw i64 %27, 1
  %25 = icmp eq i64 %24, %0
  br i1 %25, label %.loopexit, label %26, !llvm.loop !14

26:                                               ; preds = %23, %13
  %27 = phi i64 [ 2, %13 ], [ %24, %23 ]
  %28 = phi i64 [ 1, %13 ], [ %27, %23 ]
  %29 = mul i64 %28, %15
  br label %33

30:                                               ; preds = %51
  %31 = add nuw i64 %34, 1
  %32 = icmp eq i64 %31, %1
  br i1 %32, label %23, label %33, !llvm.loop !15

33:                                               ; preds = %30, %26
  %34 = phi i64 [ %31, %30 ], [ 2, %26 ]
  %35 = phi i64 [ %34, %30 ], [ 1, %26 ]
  %36 = mul i64 %35, %2
  %37 = add i64 %36, %29
  %38 = getelementptr inbounds float, ptr %3, i64 %37
  %39 = getelementptr inbounds float, ptr %38, i64 %17
  %40 = getelementptr inbounds float, ptr %38, i64 %2
  %41 = getelementptr inbounds float, ptr %38, i64 %18
  %42 = getelementptr inbounds float, ptr %38, i64 %15
  %43 = getelementptr inbounds float, ptr %4, i64 %37
  br label %44

44:                                               ; preds = %51, %33
  %45 = phi i64 [ 1, %33 ], [ %73, %51 ]
  %46 = tail call <vscale x 4 x i1> @llvm.aarch64.sve.whilelo.nxv4i1.i64(i64 %45, i64 %16)
  %47 = getelementptr inbounds float, ptr %38, i64 %45
  %prefetch.future.x = add i64 %45, %prefetch.step
  %prefetch.in.range = icmp ult i64 %prefetch.future.x, %16
  br i1 %prefetch.in.range, label %48, label %49

48:                                               ; preds = %44
  %prefetch.addr = getelementptr float, ptr %41, i64 %prefetch.future.x
  tail call void @llvm.aarch64.prefetch(ptr %prefetch.addr, i32 0, i32 0, i32 1, i32 1)
  %prefetch.addr6 = getelementptr float, ptr %42, i64 %prefetch.future.x
  tail call void @llvm.aarch64.prefetch(ptr %prefetch.addr6, i32 0, i32 0, i32 1, i32 1)
  %prefetch.addr7 = getelementptr float, ptr %39, i64 %prefetch.future.x
  tail call void @llvm.aarch64.prefetch(ptr %prefetch.addr7, i32 0, i32 0, i32 0, i32 1)
  %prefetch.addr8 = getelementptr float, ptr %40, i64 %prefetch.future.x
  tail call void @llvm.aarch64.prefetch(ptr %prefetch.addr8, i32 0, i32 0, i32 0, i32 1)
  br label %49

49:                                               ; preds = %44, %48
  %prefetch.future.x10 = add i64 %45, %prefetch.step9
  %prefetch.in.range11 = icmp ult i64 %prefetch.future.x10, %16
  br i1 %prefetch.in.range11, label %50, label %51

50:                                               ; preds = %49
  %prefetch.addr12 = getelementptr float, ptr %41, i64 %prefetch.future.x10
  tail call void @llvm.aarch64.prefetch(ptr %prefetch.addr12, i32 0, i32 1, i32 0, i32 1)
  %prefetch.addr13 = getelementptr float, ptr %42, i64 %prefetch.future.x10
  tail call void @llvm.aarch64.prefetch(ptr %prefetch.addr13, i32 0, i32 1, i32 0, i32 1)
  br label %51

51:                                               ; preds = %49, %50
  %52 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %47, i32 1, <vscale x 4 x i1> %46, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %53 = getelementptr inbounds i8, ptr %47, i64 -4
  %54 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %53, i32 1, <vscale x 4 x i1> %46, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %55 = getelementptr inbounds i8, ptr %47, i64 4
  %56 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %55, i32 1, <vscale x 4 x i1> %46, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %57 = getelementptr inbounds float, ptr %39, i64 %45
  %58 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %57, i32 1, <vscale x 4 x i1> %46, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %59 = getelementptr inbounds float, ptr %40, i64 %45
  %60 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %59, i32 1, <vscale x 4 x i1> %46, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %61 = getelementptr inbounds float, ptr %41, i64 %45
  %62 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %61, i32 1, <vscale x 4 x i1> %46, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %63 = getelementptr inbounds float, ptr %42, i64 %45
  %64 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %63, i32 1, <vscale x 4 x i1> %46, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %65 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %46, <vscale x 4 x float> %54, <vscale x 4 x float> %56)
  %66 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %46, <vscale x 4 x float> %65, <vscale x 4 x float> %58)
  %67 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %46, <vscale x 4 x float> %66, <vscale x 4 x float> %60)
  %68 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %46, <vscale x 4 x float> %67, <vscale x 4 x float> %62)
  %69 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %46, <vscale x 4 x float> %68, <vscale x 4 x float> %64)
  %70 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fmul.u.nxv4f32(<vscale x 4 x i1> %46, <vscale x 4 x float> %69, <vscale x 4 x float> %20)
  %71 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fmla.u.nxv4f32(<vscale x 4 x i1> %46, <vscale x 4 x float> %70, <vscale x 4 x float> %52, <vscale x 4 x float> %22)
  %72 = getelementptr inbounds float, ptr %43, i64 %45
  tail call void @llvm.masked.store.nxv4f32.p0(<vscale x 4 x float> %71, ptr %72, i32 1, <vscale x 4 x i1> %46), !tbaa !9
  %73 = add i64 %45, %14
  %74 = icmp ult i64 %73, %16
  br i1 %74, label %44, label %30, !llvm.loop !16

.loopexit:                                        ; preds = %23, %7
  ret void
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: read)
declare <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nocapture, i32 immarg, <vscale x 4 x i1>, <vscale x 4 x float>) #2

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: write)
declare void @llvm.masked.store.nxv4f32.p0(<vscale x 4 x float>, ptr nocapture, i32 immarg, <vscale x 4 x i1>) #3

; Function Attrs: nounwind willreturn memory(argmem: readwrite, inaccessiblemem: readwrite)
declare void @llvm.aarch64.prefetch(ptr readonly, i32 immarg, i32 immarg, i32 immarg, i32 immarg) #4

attributes #0 = { nofree norecurse nosync nounwind ssp memory(argmem: readwrite) uwtable(sync) vscale_range(1,16) "aarch64_pstate_sm_body" "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+bf16,+bti,+ccidx,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fullfp16,+i8mm,+jsconv,+lse,+mec,+neon,+pauth,+predres,+ras,+rcpc,+rdm,+rme,+sb,+sme,+spe-eef,+ssbs,+sve,+sve2,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8.6a,+v8.7a,+v8a,+v9.1a,+v9.2a,+v9a,+wfxt" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(none) }
attributes #2 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: read) }
attributes #3 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: write) }
attributes #4 = { nounwind willreturn memory(argmem: readwrite, inaccessiblemem: readwrite) }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 2, !"SDK Version", [2 x i32] [i32 26, i32 5]}
!1 = !{i32 1, !"wchar_size", i32 4}
!2 = !{i32 8, !"PIC Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 1}
!4 = !{i32 7, !"frame-pointer", i32 1}
!5 = !{!"Apple clang version 21.0.0 (clang-2100.1.1.101)"}
!6 = distinct !{!6, !7, !8}
!7 = !{!"llvm.loop.mustprogress"}
!8 = !{!"llvm.loop.unroll.disable"}
!9 = !{!10, !10, i64 0}
!10 = !{!"float", !11, i64 0}
!11 = !{!"omnipotent char", !12, i64 0}
!12 = !{!"Simple C/C++ TBAA"}
!13 = distinct !{!13, !7, !8}
!14 = distinct !{!14, !7, !8}
!15 = distinct !{!15, !7, !8}
!16 = distinct !{!16, !7, !8}
