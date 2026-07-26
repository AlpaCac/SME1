target triple = "arm64-apple-macosx15.0.0"

define void @stencil_vector_copy(i64 %count, ptr %input, ptr %output) {
entry:
  br label %loop

loop:
  %index = phi i64 [ 0, %entry ], [ %next, %loop ]
  %input.address = getelementptr float, ptr %input, i64 %index
  %value = load float, ptr %input.address, align 4
  %output.address = getelementptr float, ptr %output, i64 %index
  store float %value, ptr %output.address, align 4
  %next = add nuw i64 %index, 1
  %continue = icmp ult i64 %next, %count
  br i1 %continue, label %loop, label %exit

exit:
  ret void
}
