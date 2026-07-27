	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 16, 0	sdk_version 26, 5
	.globl	_stencil_2d5p_sme_f32           ; -- Begin function stencil_2d5p_sme_f32
	.p2align	2
_stencil_2d5p_sme_f32:                  ; @stencil_2d5p_sme_f32
	.cfi_startproc
; %bb.0:
	stp	d15, d14, [sp, #-96]!           ; 16-byte Folded Spill
	stp	d13, d12, [sp, #16]             ; 16-byte Folded Spill
	stp	d11, d10, [sp, #32]             ; 16-byte Folded Spill
	stp	d9, d8, [sp, #48]               ; 16-byte Folded Spill
	stp	x28, x27, [sp, #64]             ; 16-byte Folded Spill
	stp	x20, x19, [sp, #80]             ; 16-byte Folded Spill
	addsvl	sp, sp, #-2
	.cfi_escape 0x0f, 0x0d, 0x8f, 0x00, 0x11, 0xe0, 0x00, 0x22, 0x11, 0x10, 0x92, 0x2e, 0x00, 0x1e, 0x22 ; sp + 96 + 16 * VG
	.cfi_offset w19, -8
	.cfi_offset w20, -16
	.cfi_offset w27, -24
	.cfi_offset w28, -32
	.cfi_offset b8, -40
	.cfi_offset b9, -48
	.cfi_offset b10, -56
	.cfi_offset b11, -64
	.cfi_offset b12, -72
	.cfi_offset b13, -80
	.cfi_offset b14, -88
	.cfi_offset b15, -96
	addsvl	x8, sp, #1
	str	d1, [x8]                        ; 16-byte Folded Spill
	str	d0, [sp]                        ; 16-byte Folded Spill
	smstart	sm
	cmp	x0, #3
	b.lo	LBB0_8
; %bb.1:
	cmp	x1, #3
	b.lo	LBB0_8
; %bb.2:
	rdsvl	x8, #1
	lsr	x8, x8, #2
	sub	x9, x1, #1
	lsl	x10, x8, #2
	lsl	x11, x1, #2
	add	x12, x11, x3
	mov	w13, #4                         ; =0x4
	orr	x15, x13, x1, lsl #3
	add	x12, x12, #4
	ldr	z0, [sp, #1, mul vl]            ; 16-byte Folded Reload
	mov	z0.s, s0
	ldr	z1, [sp]                        ; 16-byte Folded Reload
	mov	z1.s, s1
	add	x13, x2, x15
	lsl	x14, x8, #4
	add	x15, x15, x14
	mov	w16, #1                         ; =0x1
	bfi	x16, x8, #2, #62
	add	x17, x2, x11
	mov	w1, #2                          ; =0x2
	mov	x3, #2                          ; =0x2
	mov	x4, #1                          ; =0x1
	b	LBB0_4
LBB0_3:                                 ;   in Loop: Header=BB0_4 Depth=1
	add	x1, x1, #1
	add	x12, x12, x11
	add	x13, x13, x11
	add	x2, x2, x11
	add	x17, x17, x11
	cmp	x1, x0
	b.eq	LBB0_8
LBB0_4:                                 ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB0_6 Depth 2
	mov	x5, #0                          ; =0x0
	mov	x6, x15
	mov	x7, x14
	b	LBB0_6
LBB0_5:                                 ;   in Loop: Header=BB0_6 Depth=2
	add	x19, x5, #1
	whilelo	p0.s, x19, x9
	add	x19, x17, x5, lsl #2
	add	x19, x19, #4
	ld1w	{ z2.s }, p0/z, [x19]
	lsl	x19, x5, #2
	add	x20, x17, x19
	ld1w	{ z3.s }, p0/z, [x17, x5, lsl #2]
	ld1w	{ z4.s }, p0/z, [x20, x3, lsl #2]
	add	x19, x2, x19
	ld1w	{ z5.s }, p0/z, [x19, x4, lsl #2]
	ld1w	{ z6.s }, p0/z, [x13, x5, lsl #2]
	fadd	z3.s, p0/m, z3.s, z4.s
	fadd	z3.s, p0/m, z3.s, z5.s
	fadd	z3.s, p0/m, z3.s, z6.s
	fmul	z3.s, p0/m, z3.s, z0.s
	fmad	z2.s, p0/m, z1.s, z3.s
	st1w	{ z2.s }, p0, [x12, x5, lsl #2]
	add	x5, x5, x8
	add	x19, x5, #1
	add	x7, x7, x10
	add	x6, x6, x10
	cmp	x19, x9
	b.hs	LBB0_3
LBB0_6:                                 ;   Parent Loop BB0_4 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	add	x19, x16, x5
	cmp	x19, x9
	b.hs	LBB0_5
; %bb.7:                                ;   in Loop: Header=BB0_6 Depth=2
	add	x19, x2, x7
	prfum	pldl1keep, [x19, #4]
	add	x19, x2, x6
	prfm	pldl1keep, [x19]
	b	LBB0_5
LBB0_8:                                 ; %.loopexit
	smstop	sm
	addsvl	sp, sp, #2
	ldp	x20, x19, [sp, #80]             ; 16-byte Folded Reload
	ldp	x28, x27, [sp, #64]             ; 16-byte Folded Reload
	ldp	d9, d8, [sp, #48]               ; 16-byte Folded Reload
	ldp	d11, d10, [sp, #32]             ; 16-byte Folded Reload
	ldp	d13, d12, [sp, #16]             ; 16-byte Folded Reload
	ldp	d15, d14, [sp], #96             ; 16-byte Folded Reload
	ret
	.cfi_endproc
                                        ; -- End function
	.globl	_stencil_3d7p_sme_f32           ; -- Begin function stencil_3d7p_sme_f32
	.p2align	2
_stencil_3d7p_sme_f32:                  ; @stencil_3d7p_sme_f32
	.cfi_startproc
; %bb.0:
	stp	d15, d14, [sp, #-160]!          ; 16-byte Folded Spill
	stp	d13, d12, [sp, #16]             ; 16-byte Folded Spill
	stp	d11, d10, [sp, #32]             ; 16-byte Folded Spill
	stp	d9, d8, [sp, #48]               ; 16-byte Folded Spill
	stp	x28, x27, [sp, #64]             ; 16-byte Folded Spill
	stp	x26, x25, [sp, #80]             ; 16-byte Folded Spill
	stp	x24, x23, [sp, #96]             ; 16-byte Folded Spill
	stp	x22, x21, [sp, #112]            ; 16-byte Folded Spill
	stp	x20, x19, [sp, #128]            ; 16-byte Folded Spill
	stp	x29, x30, [sp, #144]            ; 16-byte Folded Spill
	addsvl	sp, sp, #-2
	.cfi_escape 0x0f, 0x0d, 0x8f, 0x00, 0x11, 0xa0, 0x01, 0x22, 0x11, 0x10, 0x92, 0x2e, 0x00, 0x1e, 0x22 ; sp + 160 + 16 * VG
	.cfi_offset w30, -8
	.cfi_offset w29, -16
	.cfi_offset w19, -24
	.cfi_offset w20, -32
	.cfi_offset w21, -40
	.cfi_offset w22, -48
	.cfi_offset w23, -56
	.cfi_offset w24, -64
	.cfi_offset w25, -72
	.cfi_offset w26, -80
	.cfi_offset w27, -88
	.cfi_offset w28, -96
	.cfi_offset b8, -104
	.cfi_offset b9, -112
	.cfi_offset b10, -120
	.cfi_offset b11, -128
	.cfi_offset b12, -136
	.cfi_offset b13, -144
	.cfi_offset b14, -152
	.cfi_offset b15, -160
	str	d1, [sp]                        ; 16-byte Folded Spill
	addsvl	x8, sp, #1
	str	d0, [x8]                        ; 16-byte Folded Spill
	smstart	sm
	cmp	x0, #3
	b.lo	LBB1_13
; %bb.1:
	cmp	x1, #3
	b.lo	LBB1_13
; %bb.2:
	cmp	x2, #3
	b.lo	LBB1_13
; %bb.3:
	mov	x8, #0                          ; =0x0
	rdsvl	x9, #1
	lsr	x9, x9, #2
	sub	x10, x2, #1
	ldr	z0, [sp]                        ; 16-byte Folded Reload
	mov	z0.s, s0
	ldr	z1, [sp, #1, mul vl]            ; 16-byte Folded Reload
	mov	z1.s, s1
	lsl	x11, x9, #2
	add	x5, x11, x9
	lsl	x12, x5, #1
	mul	x14, x2, x1
	add	x13, x2, x14
	lsl	x22, x13, #2
	add	x13, x22, x4
	add	x13, x13, #4
	lsl	x14, x14, #2
	lsl	x15, x2, #2
	mov	w16, #4                         ; =0x4
	orr	x16, x16, x1, lsl #3
	madd	x16, x2, x16, x3
	add	x16, x16, #4
	add	x17, x15, x3
	add	x17, x17, #4
	lsl	x4, x1, #2
	add	x4, x4, #8
	madd	x2, x2, x4, x3
	add	x2, x2, #4
	add	x4, x14, x3
	add	x4, x4, #4
	lsl	x6, x5, #3
	add	x5, x17, x6
	add	x6, x16, x6
	lsl	x21, x9, #4
	add	x7, x17, x21
	add	x19, x16, x21
	add	x20, x4, x21
	add	x21, x2, x21
	add	x3, x3, x22
	mov	w22, #2                         ; =0x2
	mov	x23, #2                         ; =0x2
	b	LBB1_5
LBB1_4:                                 ;   in Loop: Header=BB1_5 Depth=1
	add	x22, x22, #1
	add	x8, x8, x14
	cmp	x22, x0
	b.eq	LBB1_13
LBB1_5:                                 ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB1_7 Depth 2
                                        ;       Child Loop BB1_9 Depth 3
	mov	x24, x8
	mov	w25, #2                         ; =0x2
	b	LBB1_7
LBB1_6:                                 ;   in Loop: Header=BB1_7 Depth=2
	add	x25, x25, #1
	add	x24, x24, x15
	cmp	x25, x1
	b.eq	LBB1_4
LBB1_7:                                 ;   Parent Loop BB1_5 Depth=1
                                        ; =>  This Loop Header: Depth=2
                                        ;       Child Loop BB1_9 Depth 3
	mov	x26, x24
	mov	w27, #1                         ; =0x1
	b	LBB1_9
LBB1_8:                                 ;   in Loop: Header=BB1_9 Depth=3
	whilelo	p0.s, x27, x10
	add	x28, x3, x26
	add	x28, x28, #4
	ld1w	{ z2.s }, p0/z, [x28]
	add	x28, x3, x26
	ld1w	{ z3.s }, p0/z, [x28]
	ld1w	{ z4.s }, p0/z, [x28, x23, lsl #2]
	add	x28, x4, x26
	ld1w	{ z5.s }, p0/z, [x28]
	add	x28, x2, x26
	ld1w	{ z6.s }, p0/z, [x28]
	add	x28, x17, x26
	ld1w	{ z7.s }, p0/z, [x28]
	add	x28, x16, x26
	ld1w	{ z16.s }, p0/z, [x28]
	fadd	z3.s, p0/m, z3.s, z4.s
	fadd	z3.s, p0/m, z3.s, z5.s
	fadd	z3.s, p0/m, z3.s, z6.s
	fadd	z3.s, p0/m, z3.s, z7.s
	fadd	z3.s, p0/m, z3.s, z16.s
	fmul	z3.s, p0/m, z3.s, z0.s
	fmad	z2.s, p0/m, z1.s, z3.s
	add	x28, x13, x26
	st1w	{ z2.s }, p0, [x28]
	add	x26, x26, x11
	add	x27, x27, x9
	cmp	x27, x10
	b.hs	LBB1_6
LBB1_9:                                 ;   Parent Loop BB1_5 Depth=1
                                        ;     Parent Loop BB1_7 Depth=2
                                        ; =>    This Inner Loop Header: Depth=3
	add	x28, x11, x27
	cmp	x28, x10
	b.hs	LBB1_11
; %bb.10:                               ;   in Loop: Header=BB1_9 Depth=3
	add	x28, x7, x26
	prfm	pldl1strm, [x28]
	add	x28, x19, x26
	prfm	pldl1strm, [x28]
	add	x28, x20, x26
	prfm	pldl1keep, [x28]
	add	x28, x21, x26
	prfm	pldl1keep, [x28]
LBB1_11:                                ;   in Loop: Header=BB1_9 Depth=3
	add	x28, x12, x27
	cmp	x28, x10
	b.hs	LBB1_8
; %bb.12:                               ;   in Loop: Header=BB1_9 Depth=3
	add	x28, x5, x26
	prfm	pldl2keep, [x28]
	add	x28, x6, x26
	prfm	pldl2keep, [x28]
	b	LBB1_8
LBB1_13:                                ; %.loopexit
	smstop	sm
	addsvl	sp, sp, #2
	ldp	x29, x30, [sp, #144]            ; 16-byte Folded Reload
	ldp	x20, x19, [sp, #128]            ; 16-byte Folded Reload
	ldp	x22, x21, [sp, #112]            ; 16-byte Folded Reload
	ldp	x24, x23, [sp, #96]             ; 16-byte Folded Reload
	ldp	x26, x25, [sp, #80]             ; 16-byte Folded Reload
	ldp	x28, x27, [sp, #64]             ; 16-byte Folded Reload
	ldp	d9, d8, [sp, #48]               ; 16-byte Folded Reload
	ldp	d11, d10, [sp, #32]             ; 16-byte Folded Reload
	ldp	d13, d12, [sp, #16]             ; 16-byte Folded Reload
	ldp	d15, d14, [sp], #160            ; 16-byte Folded Reload
	ret
	.cfi_endproc
                                        ; -- End function
.subsections_via_symbols
