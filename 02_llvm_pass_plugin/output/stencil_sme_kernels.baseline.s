	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 16, 0
	.globl	_stencil_2d5p_sme_f32           ; -- Begin function stencil_2d5p_sme_f32
	.p2align	2
_stencil_2d5p_sme_f32:                  ; @stencil_2d5p_sme_f32
	.cfi_startproc
; %bb.0:                                ; %entry
	stp	d15, d14, [sp, #-80]!           ; 16-byte Folded Spill
	stp	d13, d12, [sp, #16]             ; 16-byte Folded Spill
	stp	d11, d10, [sp, #32]             ; 16-byte Folded Spill
	stp	d9, d8, [sp, #48]               ; 16-byte Folded Spill
	stp	x28, x27, [sp, #64]             ; 16-byte Folded Spill
	addsvl	sp, sp, #-2
	.cfi_escape 0x0f, 0x0d, 0x8f, 0x00, 0x11, 0xd0, 0x00, 0x22, 0x11, 0x10, 0x92, 0x2e, 0x00, 0x1e, 0x22 ; sp + 80 + 16 * VG
	.cfi_offset w27, -8
	.cfi_offset w28, -16
	.cfi_offset b8, -24
	.cfi_offset b9, -32
	.cfi_offset b10, -40
	.cfi_offset b11, -48
	.cfi_offset b12, -56
	.cfi_offset b13, -64
	.cfi_offset b14, -72
	.cfi_offset b15, -80
	str	d1, [sp]                        ; 16-byte Folded Spill
	addsvl	x8, sp, #1
	str	d0, [x8]                        ; 16-byte Folded Spill
	smstart	sm
	cmp	x0, #3
	b.lo	LBB0_7
; %bb.1:                                ; %entry
	cmp	x1, #3
	b.lo	LBB0_7
; %bb.2:                                ; %if.end
	rdsvl	x8, #1
	lsr	x8, x8, #2
	sub	x9, x1, #1
	ldr	z0, [sp]                        ; 16-byte Folded Reload
	mov	z0.s, s0
	lsl	x10, x1, #2
	add	x11, x10, x3
	add	x11, x11, #4
	add	x12, x2, x1, lsl #3
	ldr	z1, [sp, #1, mul vl]            ; 16-byte Folded Reload
	mov	z1.s, s1
	add	x12, x12, #4
	add	x13, x2, x10
	mov	w14, #2                         ; =0x2
	mov	x15, #1                         ; =0x1
	mov	x16, #2                         ; =0x2
	b	LBB0_4
LBB0_3:                                 ; %for.cond.loopexit
                                        ;   in Loop: Header=BB0_4 Depth=1
	add	x14, x14, #1
	add	x11, x11, x10
	add	x12, x12, x10
	add	x2, x2, x10
	add	x13, x13, x10
	cmp	x14, x0
	b.eq	LBB0_7
LBB0_4:                                 ; %for.body
                                        ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB0_6 Depth 2
	cmp	x9, #2
	b.lo	LBB0_3
; %bb.5:                                ; %for.body6.lr.ph
                                        ;   in Loop: Header=BB0_4 Depth=1
	mov	x17, #0                         ; =0x0
LBB0_6:                                 ; %for.body6
                                        ;   Parent Loop BB0_4 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	add	x1, x17, #1
	whilelo	p0.s, x1, x9
	lsl	x1, x17, #2
	add	x3, x13, x1
	ld1w	{ z2.s }, p0/z, [x3, x15, lsl #2]
	ld1w	{ z3.s }, p0/z, [x13, x17, lsl #2]
	ld1w	{ z4.s }, p0/z, [x3, x16, lsl #2]
	add	x1, x2, x1
	ld1w	{ z5.s }, p0/z, [x1, x15, lsl #2]
	ld1w	{ z6.s }, p0/z, [x12, x17, lsl #2]
	fadd	z3.s, p0/m, z3.s, z4.s
	fadd	z3.s, p0/m, z3.s, z5.s
	fadd	z3.s, p0/m, z3.s, z6.s
	fmul	z3.s, p0/m, z3.s, z0.s
	fmad	z2.s, p0/m, z1.s, z3.s
	st1w	{ z2.s }, p0, [x11, x17, lsl #2]
	add	x17, x17, x8
	add	x1, x17, #1
	cmp	x1, x9
	b.lo	LBB0_6
	b	LBB0_3
LBB0_7:                                 ; %return
	smstop	sm
	addsvl	sp, sp, #2
	ldp	x28, x27, [sp, #64]             ; 16-byte Folded Reload
	ldp	d9, d8, [sp, #48]               ; 16-byte Folded Reload
	ldp	d11, d10, [sp, #32]             ; 16-byte Folded Reload
	ldp	d13, d12, [sp, #16]             ; 16-byte Folded Reload
	ldp	d15, d14, [sp], #80             ; 16-byte Folded Reload
	ret
	.cfi_endproc
                                        ; -- End function
	.globl	_stencil_3d7p_sme_f32           ; -- Begin function stencil_3d7p_sme_f32
	.p2align	2
_stencil_3d7p_sme_f32:                  ; @stencil_3d7p_sme_f32
	.cfi_startproc
; %bb.0:                                ; %entry
	stp	d15, d14, [sp, #-128]!          ; 16-byte Folded Spill
	stp	d13, d12, [sp, #16]             ; 16-byte Folded Spill
	stp	d11, d10, [sp, #32]             ; 16-byte Folded Spill
	stp	d9, d8, [sp, #48]               ; 16-byte Folded Spill
	stp	x28, x27, [sp, #64]             ; 16-byte Folded Spill
	stp	x24, x23, [sp, #80]             ; 16-byte Folded Spill
	stp	x22, x21, [sp, #96]             ; 16-byte Folded Spill
	stp	x20, x19, [sp, #112]            ; 16-byte Folded Spill
	addsvl	sp, sp, #-2
	.cfi_escape 0x0f, 0x0d, 0x8f, 0x00, 0x11, 0x80, 0x01, 0x22, 0x11, 0x10, 0x92, 0x2e, 0x00, 0x1e, 0x22 ; sp + 128 + 16 * VG
	.cfi_offset w19, -8
	.cfi_offset w20, -16
	.cfi_offset w21, -24
	.cfi_offset w22, -32
	.cfi_offset w23, -40
	.cfi_offset w24, -48
	.cfi_offset w27, -56
	.cfi_offset w28, -64
	.cfi_offset b8, -72
	.cfi_offset b9, -80
	.cfi_offset b10, -88
	.cfi_offset b11, -96
	.cfi_offset b12, -104
	.cfi_offset b13, -112
	.cfi_offset b14, -120
	.cfi_offset b15, -128
	str	d1, [sp]                        ; 16-byte Folded Spill
	addsvl	x8, sp, #1
	str	d0, [x8]                        ; 16-byte Folded Spill
	smstart	sm
	cmp	x0, #3
	b.lo	LBB1_10
; %bb.1:                                ; %entry
	cmp	x1, #3
	b.lo	LBB1_10
; %bb.2:                                ; %entry
	cmp	x2, #3
	b.lo	LBB1_10
; %bb.3:                                ; %if.end
	rdsvl	x8, #1
	lsr	x8, x8, #2
	sub	x9, x2, #1
	ldr	z0, [sp]                        ; 16-byte Folded Reload
	mov	z0.s, s0
	ldr	z1, [sp, #1, mul vl]            ; 16-byte Folded Reload
	mov	z1.s, s1
	mul	x11, x2, x1
	add	x10, x2, x11
	lsl	x17, x10, #2
	add	x10, x17, x4
	add	x10, x10, #4
	lsl	x11, x11, #2
	lsl	x12, x2, #2
	mov	w13, #4                         ; =0x4
	orr	x13, x13, x1, lsl #3
	madd	x13, x2, x13, x3
	add	x13, x13, #4
	add	x14, x12, x3
	add	x14, x14, #4
	lsl	x15, x1, #2
	add	x15, x15, #8
	madd	x15, x2, x15, x3
	add	x15, x15, #4
	add	x16, x11, x3
	add	x16, x16, #4
	add	x17, x3, x17
	mov	w2, #2                          ; =0x2
	mov	x3, #1                          ; =0x1
	mov	x4, #2                          ; =0x2
	b	LBB1_5
LBB1_4:                                 ; %for.cond.loopexit
                                        ;   in Loop: Header=BB1_5 Depth=1
	add	x2, x2, #1
	add	x10, x10, x11
	add	x13, x13, x11
	add	x14, x14, x11
	add	x15, x15, x11
	add	x16, x16, x11
	add	x17, x17, x11
	cmp	x2, x0
	b.eq	LBB1_10
LBB1_5:                                 ; %for.body
                                        ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB1_7 Depth 2
                                        ;       Child Loop BB1_9 Depth 3
	mov	x5, x17
	mov	x6, x16
	mov	x7, x15
	mov	x19, x14
	mov	x20, x13
	mov	x21, x10
	mov	w22, #2                         ; =0x2
	b	LBB1_7
LBB1_6:                                 ; %for.cond6.loopexit
                                        ;   in Loop: Header=BB1_7 Depth=2
	add	x22, x22, #1
	add	x21, x21, x12
	add	x20, x20, x12
	add	x19, x19, x12
	add	x7, x7, x12
	add	x6, x6, x12
	add	x5, x5, x12
	cmp	x22, x1
	b.eq	LBB1_4
LBB1_7:                                 ; %for.body10
                                        ;   Parent Loop BB1_5 Depth=1
                                        ; =>  This Loop Header: Depth=2
                                        ;       Child Loop BB1_9 Depth 3
	cmp	x9, #2
	b.lo	LBB1_6
; %bb.8:                                ; %for.body16.lr.ph
                                        ;   in Loop: Header=BB1_7 Depth=2
	mov	x23, #0                         ; =0x0
LBB1_9:                                 ; %for.body16
                                        ;   Parent Loop BB1_5 Depth=1
                                        ;     Parent Loop BB1_7 Depth=2
                                        ; =>    This Inner Loop Header: Depth=3
	add	x24, x23, #1
	whilelo	p0.s, x24, x9
	add	x24, x5, x23, lsl #2
	ld1w	{ z2.s }, p0/z, [x24, x3, lsl #2]
	ld1w	{ z3.s }, p0/z, [x5, x23, lsl #2]
	ld1w	{ z4.s }, p0/z, [x24, x4, lsl #2]
	ld1w	{ z5.s }, p0/z, [x6, x23, lsl #2]
	ld1w	{ z6.s }, p0/z, [x7, x23, lsl #2]
	ld1w	{ z7.s }, p0/z, [x19, x23, lsl #2]
	ld1w	{ z16.s }, p0/z, [x20, x23, lsl #2]
	fadd	z3.s, p0/m, z3.s, z4.s
	fadd	z3.s, p0/m, z3.s, z5.s
	fadd	z3.s, p0/m, z3.s, z6.s
	fadd	z3.s, p0/m, z3.s, z7.s
	fadd	z3.s, p0/m, z3.s, z16.s
	fmul	z3.s, p0/m, z3.s, z0.s
	fmad	z2.s, p0/m, z1.s, z3.s
	st1w	{ z2.s }, p0, [x21, x23, lsl #2]
	add	x23, x23, x8
	add	x24, x23, #1
	cmp	x24, x9
	b.lo	LBB1_9
	b	LBB1_6
LBB1_10:                                ; %return
	smstop	sm
	addsvl	sp, sp, #2
	ldp	x20, x19, [sp, #112]            ; 16-byte Folded Reload
	ldp	x22, x21, [sp, #96]             ; 16-byte Folded Reload
	ldp	x24, x23, [sp, #80]             ; 16-byte Folded Reload
	ldp	x28, x27, [sp, #64]             ; 16-byte Folded Reload
	ldp	d9, d8, [sp, #48]               ; 16-byte Folded Reload
	ldp	d11, d10, [sp, #32]             ; 16-byte Folded Reload
	ldp	d13, d12, [sp, #16]             ; 16-byte Folded Reload
	ldp	d15, d14, [sp], #128            ; 16-byte Folded Reload
	ret
	.cfi_endproc
                                        ; -- End function
.subsections_via_symbols
