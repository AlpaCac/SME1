; ModuleID = 'stencil_sme_kernels.c'
source_filename = "stencil_sme_kernels.c"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx15.0.0"

; Function Attrs: nofree norecurse nosync nounwind ssp memory(argmem: readwrite) uwtable(sync) vscale_range(1,16)
define void @stencil_2d5p_sme_f32(i64 noundef %0, i64 noundef %1, ptr noalias noundef readonly captures(none) %2, ptr noalias noundef writeonly captures(none) %3, float noundef %4, float noundef %5) local_unnamed_addr #0 {
  %7 = icmp ult i64 %0, 3
  %8 = icmp ult i64 %1, 3
  %9 = or i1 %7, %8
  br i1 %9, label %52, label %10

10:                                               ; preds = %6
  %11 = tail call i64 @llvm.aarch64.sme.cntsw()
  %12 = add i64 %1, -1
  %13 = icmp ugt i64 %12, 1
  %14 = sub i64 0, %1
  %15 = insertelement <vscale x 4 x float> poison, float %5, i64 0
  %16 = shufflevector <vscale x 4 x float> %15, <vscale x 4 x float> poison, <vscale x 4 x i32> zeroinitializer
  %17 = insertelement <vscale x 4 x float> poison, float %4, i64 0
  %18 = shufflevector <vscale x 4 x float> %17, <vscale x 4 x float> poison, <vscale x 4 x i32> zeroinitializer
  br label %22

19:                                               ; preds = %31, %22
  %20 = add nuw i64 %23, 1
  %21 = icmp eq i64 %20, %0
  br i1 %21, label %52, label %22, !llvm.loop !6

22:                                               ; preds = %10, %19
  %23 = phi i64 [ 2, %10 ], [ %20, %19 ]
  %24 = phi i64 [ 1, %10 ], [ %23, %19 ]
  br i1 %13, label %25, label %19

25:                                               ; preds = %22
  %26 = mul i64 %24, %1
  %27 = getelementptr inbounds nuw float, ptr %2, i64 %26
  %28 = getelementptr inbounds float, ptr %27, i64 %14
  %29 = getelementptr inbounds nuw float, ptr %27, i64 %1
  %30 = getelementptr inbounds nuw float, ptr %3, i64 %26
  br label %31

31:                                               ; preds = %25, %31
  %32 = phi i64 [ 1, %25 ], [ %50, %31 ]
  %33 = tail call <vscale x 4 x i1> @llvm.aarch64.sve.whilelo.nxv4i1.i64(i64 %32, i64 %12)
  %34 = getelementptr inbounds nuw float, ptr %27, i64 %32
  %35 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %34, i32 1, <vscale x 4 x i1> %33, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %36 = getelementptr inbounds i8, ptr %34, i64 -4
  %37 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %36, i32 1, <vscale x 4 x i1> %33, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %38 = getelementptr inbounds nuw i8, ptr %34, i64 4
  %39 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %38, i32 1, <vscale x 4 x i1> %33, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %40 = getelementptr inbounds nuw float, ptr %28, i64 %32
  %41 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %40, i32 1, <vscale x 4 x i1> %33, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %42 = getelementptr inbounds nuw float, ptr %29, i64 %32
  %43 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %42, i32 1, <vscale x 4 x i1> %33, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %44 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %33, <vscale x 4 x float> %37, <vscale x 4 x float> %39)
  %45 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %33, <vscale x 4 x float> %44, <vscale x 4 x float> %41)
  %46 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %33, <vscale x 4 x float> %45, <vscale x 4 x float> %43)
  %47 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fmul.u.nxv4f32(<vscale x 4 x i1> %33, <vscale x 4 x float> %46, <vscale x 4 x float> %16)
  %48 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fmla.u.nxv4f32(<vscale x 4 x i1> %33, <vscale x 4 x float> %47, <vscale x 4 x float> %35, <vscale x 4 x float> %18)
  %49 = getelementptr inbounds nuw float, ptr %30, i64 %32
  tail call void @llvm.masked.store.nxv4f32.p0(<vscale x 4 x float> %48, ptr %49, i32 1, <vscale x 4 x i1> %33), !tbaa !9
  %50 = add i64 %32, %11
  %51 = icmp ult i64 %50, %12
  br i1 %51, label %31, label %19, !llvm.loop !13

52:                                               ; preds = %19, %6
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
define void @stencil_3d7p_sme_f32(i64 noundef %0, i64 noundef %1, i64 noundef %2, ptr noalias noundef readonly captures(none) %3, ptr noalias noundef writeonly captures(none) %4, float noundef %5, float noundef %6) local_unnamed_addr #0 {
  %8 = icmp ult i64 %0, 3
  %9 = icmp ult i64 %1, 3
  %10 = or i1 %8, %9
  %11 = icmp ult i64 %2, 3
  %12 = or i1 %10, %11
  br i1 %12, label %73, label %13

13:                                               ; preds = %7
  %14 = tail call i64 @llvm.aarch64.sme.cntsw()
  %15 = mul i64 %2, %1
  %16 = add i64 %2, -1
  %17 = icmp ugt i64 %16, 1
  %18 = sub i64 0, %2
  %19 = sub i64 0, %15
  %20 = insertelement <vscale x 4 x float> poison, float %6, i64 0
  %21 = shufflevector <vscale x 4 x float> %20, <vscale x 4 x float> poison, <vscale x 4 x i32> zeroinitializer
  %22 = insertelement <vscale x 4 x float> poison, float %5, i64 0
  %23 = shufflevector <vscale x 4 x float> %22, <vscale x 4 x float> poison, <vscale x 4 x i32> zeroinitializer
  br label %27

24:                                               ; preds = %31
  %25 = add nuw i64 %28, 1
  %26 = icmp eq i64 %25, %0
  br i1 %26, label %73, label %27, !llvm.loop !14

27:                                               ; preds = %13, %24
  %28 = phi i64 [ 2, %13 ], [ %25, %24 ]
  %29 = phi i64 [ 1, %13 ], [ %28, %24 ]
  %30 = mul i64 %29, %15
  br label %34

31:                                               ; preds = %46, %34
  %32 = add nuw i64 %35, 1
  %33 = icmp eq i64 %32, %1
  br i1 %33, label %24, label %34, !llvm.loop !15

34:                                               ; preds = %27, %31
  %35 = phi i64 [ %32, %31 ], [ 2, %27 ]
  %36 = phi i64 [ %35, %31 ], [ 1, %27 ]
  br i1 %17, label %37, label %31

37:                                               ; preds = %34
  %38 = mul i64 %36, %2
  %39 = add i64 %38, %30
  %40 = getelementptr inbounds nuw float, ptr %3, i64 %39
  %41 = getelementptr inbounds float, ptr %40, i64 %18
  %42 = getelementptr inbounds nuw float, ptr %40, i64 %2
  %43 = getelementptr inbounds float, ptr %40, i64 %19
  %44 = getelementptr inbounds nuw float, ptr %40, i64 %15
  %45 = getelementptr inbounds nuw float, ptr %4, i64 %39
  br label %46

46:                                               ; preds = %37, %46
  %47 = phi i64 [ 1, %37 ], [ %71, %46 ]
  %48 = tail call <vscale x 4 x i1> @llvm.aarch64.sve.whilelo.nxv4i1.i64(i64 %47, i64 %16)
  %49 = getelementptr inbounds nuw float, ptr %40, i64 %47
  %50 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %49, i32 1, <vscale x 4 x i1> %48, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %51 = getelementptr inbounds i8, ptr %49, i64 -4
  %52 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %51, i32 1, <vscale x 4 x i1> %48, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %53 = getelementptr inbounds nuw i8, ptr %49, i64 4
  %54 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %53, i32 1, <vscale x 4 x i1> %48, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %55 = getelementptr inbounds nuw float, ptr %41, i64 %47
  %56 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr nonnull %55, i32 1, <vscale x 4 x i1> %48, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %57 = getelementptr inbounds nuw float, ptr %42, i64 %47
  %58 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %57, i32 1, <vscale x 4 x i1> %48, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %59 = getelementptr inbounds nuw float, ptr %43, i64 %47
  %60 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %59, i32 1, <vscale x 4 x i1> %48, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %61 = getelementptr inbounds nuw float, ptr %44, i64 %47
  %62 = tail call <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr %61, i32 1, <vscale x 4 x i1> %48, <vscale x 4 x float> zeroinitializer), !tbaa !9
  %63 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %48, <vscale x 4 x float> %52, <vscale x 4 x float> %54)
  %64 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %48, <vscale x 4 x float> %63, <vscale x 4 x float> %56)
  %65 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %48, <vscale x 4 x float> %64, <vscale x 4 x float> %58)
  %66 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %48, <vscale x 4 x float> %65, <vscale x 4 x float> %60)
  %67 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fadd.u.nxv4f32(<vscale x 4 x i1> %48, <vscale x 4 x float> %66, <vscale x 4 x float> %62)
  %68 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fmul.u.nxv4f32(<vscale x 4 x i1> %48, <vscale x 4 x float> %67, <vscale x 4 x float> %21)
  %69 = tail call <vscale x 4 x float> @llvm.aarch64.sve.fmla.u.nxv4f32(<vscale x 4 x i1> %48, <vscale x 4 x float> %68, <vscale x 4 x float> %50, <vscale x 4 x float> %23)
  %70 = getelementptr inbounds nuw float, ptr %45, i64 %47
  tail call void @llvm.masked.store.nxv4f32.p0(<vscale x 4 x float> %69, ptr %70, i32 1, <vscale x 4 x i1> %48), !tbaa !9
  %71 = add i64 %47, %14
  %72 = icmp ult i64 %71, %16
  br i1 %72, label %46, label %31, !llvm.loop !16

73:                                               ; preds = %24, %7
  ret void
}

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: read)
declare <vscale x 4 x float> @llvm.masked.load.nxv4f32.p0(ptr captures(none), i32 immarg, <vscale x 4 x i1>, <vscale x 4 x float>) #2

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(argmem: write)
declare void @llvm.masked.store.nxv4f32.p0(<vscale x 4 x float>, ptr captures(none), i32 immarg, <vscale x 4 x i1>) #3

attributes #0 = { nofree norecurse nosync nounwind ssp memory(argmem: readwrite) uwtable(sync) vscale_range(1,16) "aarch64_pstate_sm_body" "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+bf16,+bti,+ccidx,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fullfp16,+i8mm,+jsconv,+lse,+mec,+neon,+pauth,+predres,+ras,+rcpc,+rdm,+rme,+sb,+sme,+spe-eef,+ssbs,+sve,+sve2,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8.6a,+v8.7a,+v8a,+v9.1a,+v9.2a,+v9a,+wfxt" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(none) }
attributes #2 = { nocallback nofree nosync nounwind willreturn memory(argmem: read) }
attributes #3 = { nocallback nofree nosync nounwind willreturn memory(argmem: write) }

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
