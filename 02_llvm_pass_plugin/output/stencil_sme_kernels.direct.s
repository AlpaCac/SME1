	.section	__TEXT,__text,regular,pure_instructions
	.build_version macos, 16, 0
	.globl	_stencil_2d5p_sme_f32           ; -- Begin function stencil_2d5p_sme_f32
	.p2align	2
_stencil_2d5p_sme_f32:                  ; @stencil_2d5p_sme_f32
	.cfi_startproc
; %bb.0:                                ; %entry
	stp	d15, d14, [sp, #-112]!          ; 16-byte Folded Spill
	stp	d13, d12, [sp, #16]             ; 16-byte Folded Spill
	stp	d11, d10, [sp, #32]             ; 16-byte Folded Spill
	stp	d9, d8, [sp, #48]               ; 16-byte Folded Spill
	stp	x24, x23, [sp, #64]             ; 16-byte Folded Spill
	stp	x22, x21, [sp, #80]             ; 16-byte Folded Spill
	stp	x20, x19, [sp, #96]             ; 16-byte Folded Spill
	addsvl	sp, sp, #-2
	.cfi_escape 0x0f, 0x0d, 0x8f, 0x00, 0x11, 0xf0, 0x00, 0x22, 0x11, 0x10, 0x92, 0x2e, 0x00, 0x1e, 0x22 ; sp + 112 + 16 * VG
	.cfi_offset w19, -8
	.cfi_offset w20, -16
	.cfi_offset w21, -24
	.cfi_offset w22, -32
	.cfi_offset w23, -40
	.cfi_offset w24, -48
	.cfi_offset b8, -56
	.cfi_offset b9, -64
	.cfi_offset b10, -72
	.cfi_offset b11, -80
	.cfi_offset b12, -88
	.cfi_offset b13, -96
	.cfi_offset b14, -104
	.cfi_offset b15, -112
	addsvl	x8, sp, #1
	str	d1, [x8]                        ; 16-byte Folded Spill
	str	d0, [sp]                        ; 16-byte Folded Spill
	smstart	sm
	cmp	x0, #3
	b.lo	LBB0_9
; %bb.1:                                ; %entry
	cmp	x1, #3
	b.lo	LBB0_9
; %bb.2:                                ; %if.end
	mov	x8, #0                          ; =0x0
	rdsvl	x9, #1
	lsr	x9, x9, #2
	sub	x10, x1, #1
	lsl	x11, x9, #2
	lsl	x12, x1, #2
	lsl	x16, x9, #4
	lsl	x14, x1, #3
	add	x13, x2, #4
	ldr	z0, [sp, #1, mul vl]            ; 16-byte Folded Reload
	mov	z0.s, s0
	ldr	z1, [sp]                        ; 16-byte Folded Reload
	mov	z1.s, s1
	add	x14, x13, x14
	add	x15, x14, x16
	add	x16, x13, x16
	add	x17, x12, x3
	add	x17, x17, #4
	add	x1, x2, x12
	mov	w2, #2                          ; =0x2
	mov	x3, #2                          ; =0x2
	b	LBB0_4
LBB0_3:                                 ; %for.cond.loopexit
                                        ;   in Loop: Header=BB0_4 Depth=1
	add	x2, x2, #1
	add	x8, x8, x12
	cmp	x2, x0
	b.eq	LBB0_9
LBB0_4:                                 ; %for.body
                                        ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB0_7 Depth 2
	cmp	x10, #2
	b.lo	LBB0_3
; %bb.5:                                ; %for.body6.lr.ph
                                        ;   in Loop: Header=BB0_4 Depth=1
	mov	x4, x1
	mov	x5, x13
	mov	x6, x14
	mov	x7, x17
	mov	x19, x16
	mov	x20, x15
	mov	w21, #1                         ; =0x1
	b	LBB0_7
LBB0_6:                                 ;   in Loop: Header=BB0_7 Depth=2
	whilelo	p0.s, x21, x10
	add	x22, x4, x8
	add	x23, x22, #4
	ld1w	{ z2.s }, p0/z, [x23]
	ld1w	{ z3.s }, p0/z, [x22]
	ld1w	{ z4.s }, p0/z, [x22, x3, lsl #2]
	add	x22, x5, x8
	ld1w	{ z5.s }, p0/z, [x22]
	add	x22, x6, x8
	ld1w	{ z6.s }, p0/z, [x22]
	fadd	z3.s, p0/m, z3.s, z4.s
	fadd	z3.s, p0/m, z3.s, z5.s
	fadd	z3.s, p0/m, z3.s, z6.s
	add	x22, x7, x8
	fmul	z3.s, p0/m, z3.s, z0.s
	fmad	z2.s, p0/m, z1.s, z3.s
	st1w	{ z2.s }, p0, [x22]
	add	x20, x20, x11
	add	x19, x19, x11
	add	x7, x7, x11
	add	x6, x6, x11
	add	x5, x5, x11
	add	x4, x4, x11
	add	x21, x21, x9
	cmp	x21, x10
	b.hs	LBB0_3
LBB0_7:                                 ; %for.body6
                                        ;   Parent Loop BB0_4 Depth=1
                                        ; =>  This Inner Loop Header: Depth=2
	add	x22, x11, x21
	cmp	x22, x10
	b.hs	LBB0_6
; %bb.8:                                ;   in Loop: Header=BB0_7 Depth=2
	add	x22, x19, x8
	prfm	pldl1keep, [x22]
	add	x22, x20, x8
	prfm	pldl1keep, [x22]
	b	LBB0_6
LBB0_9:                                 ; %return
	smstop	sm
	addsvl	sp, sp, #2
	ldp	x20, x19, [sp, #96]             ; 16-byte Folded Reload
	ldp	x22, x21, [sp, #80]             ; 16-byte Folded Reload
	ldp	x24, x23, [sp, #64]             ; 16-byte Folded Reload
	ldp	d9, d8, [sp, #48]               ; 16-byte Folded Reload
	ldp	d11, d10, [sp, #32]             ; 16-byte Folded Reload
	ldp	d13, d12, [sp, #16]             ; 16-byte Folded Reload
	ldp	d15, d14, [sp], #112            ; 16-byte Folded Reload
	ret
	.cfi_endproc
                                        ; -- End function
	.globl	_stencil_3d7p_sme_f32           ; -- Begin function stencil_3d7p_sme_f32
	.p2align	2
_stencil_3d7p_sme_f32:                  ; @stencil_3d7p_sme_f32
	.cfi_startproc
; %bb.0:                                ; %entry
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
	b.lo	LBB1_14
; %bb.1:                                ; %entry
	cmp	x1, #3
	b.lo	LBB1_14
; %bb.2:                                ; %entry
	cmp	x2, #3
	b.lo	LBB1_14
; %bb.3:                                ; %if.end
	mov	x8, #0                          ; =0x0
	rdsvl	x9, #1
	lsr	x9, x9, #2
	sub	x10, x2, #1
	ldr	z0, [sp]                        ; 16-byte Folded Reload
	mov	z0.s, s0
	ldr	z1, [sp, #1, mul vl]            ; 16-byte Folded Reload
	mov	z1.s, s1
	lsl	x11, x9, #2
	add	x13, x11, x9
	lsl	x12, x13, #1
	mov	w14, #4                         ; =0x4
	orr	x14, x14, x1, lsl #3
	lsl	x5, x13, #3
	madd	x13, x2, x14, x3
	add	x13, x13, #4
	add	x14, x13, x5
	mul	x23, x2, x1
	lsl	x15, x23, #2
	lsl	x16, x2, #2
	add	x17, x16, x3
	add	x17, x17, #4
	add	x5, x17, x5
	lsl	x6, x1, #2
	add	x6, x6, #8
	lsl	x22, x9, #4
	madd	x6, x2, x6, x3
	add	x6, x6, #4
	add	x7, x6, x22
	add	x19, x15, x3
	add	x19, x19, #4
	add	x20, x19, x22
	add	x21, x13, x22
	add	x22, x17, x22
	add	x2, x2, x23
	lsl	x23, x2, #2
	add	x2, x23, x4
	add	x2, x2, #4
	add	x3, x3, x23
	mov	w4, #2                          ; =0x2
	mov	x23, #2                         ; =0x2
	b	LBB1_5
LBB1_4:                                 ; %for.cond.loopexit
                                        ;   in Loop: Header=BB1_5 Depth=1
	add	x4, x4, #1
	add	x8, x8, x15
	cmp	x4, x0
	b.eq	LBB1_14
LBB1_5:                                 ; %for.body
                                        ; =>This Loop Header: Depth=1
                                        ;     Child Loop BB1_7 Depth 2
                                        ;       Child Loop BB1_10 Depth 3
	mov	x24, x8
	mov	w25, #2                         ; =0x2
	b	LBB1_7
LBB1_6:                                 ; %for.cond6.loopexit
                                        ;   in Loop: Header=BB1_7 Depth=2
	add	x25, x25, #1
	add	x24, x24, x16
	cmp	x25, x1
	b.eq	LBB1_4
LBB1_7:                                 ; %for.body10
                                        ;   Parent Loop BB1_5 Depth=1
                                        ; =>  This Loop Header: Depth=2
                                        ;       Child Loop BB1_10 Depth 3
	cmp	x10, #2
	b.lo	LBB1_6
; %bb.8:                                ; %for.body16.lr.ph
                                        ;   in Loop: Header=BB1_7 Depth=2
	mov	x26, x24
	mov	w27, #1                         ; =0x1
	b	LBB1_10
LBB1_9:                                 ;   in Loop: Header=BB1_10 Depth=3
	whilelo	p0.s, x27, x10
	add	x28, x3, x26
	add	x28, x28, #4
	ld1w	{ z2.s }, p0/z, [x28]
	add	x28, x3, x26
	ld1w	{ z3.s }, p0/z, [x28]
	ld1w	{ z4.s }, p0/z, [x28, x23, lsl #2]
	add	x28, x19, x26
	ld1w	{ z5.s }, p0/z, [x28]
	add	x28, x6, x26
	ld1w	{ z6.s }, p0/z, [x28]
	add	x28, x17, x26
	ld1w	{ z7.s }, p0/z, [x28]
	add	x28, x13, x26
	ld1w	{ z16.s }, p0/z, [x28]
	fadd	z3.s, p0/m, z3.s, z4.s
	fadd	z3.s, p0/m, z3.s, z5.s
	fadd	z3.s, p0/m, z3.s, z6.s
	fadd	z3.s, p0/m, z3.s, z7.s
	fadd	z3.s, p0/m, z3.s, z16.s
	fmul	z3.s, p0/m, z3.s, z0.s
	fmad	z2.s, p0/m, z1.s, z3.s
	add	x28, x2, x26
	st1w	{ z2.s }, p0, [x28]
	add	x26, x26, x11
	add	x27, x27, x9
	cmp	x27, x10
	b.hs	LBB1_6
LBB1_10:                                ; %for.body16
                                        ;   Parent Loop BB1_5 Depth=1
                                        ;     Parent Loop BB1_7 Depth=2
                                        ; =>    This Inner Loop Header: Depth=3
	add	x28, x11, x27
	cmp	x28, x10
	b.hs	LBB1_12
; %bb.11:                               ;   in Loop: Header=BB1_10 Depth=3
	add	x28, x22, x26
	prfm	pldl1strm, [x28]
	add	x28, x21, x26
	prfm	pldl1strm, [x28]
	add	x28, x20, x26
	prfm	pldl1keep, [x28]
	add	x28, x7, x26
	prfm	pldl1keep, [x28]
LBB1_12:                                ;   in Loop: Header=BB1_10 Depth=3
	add	x28, x12, x27
	cmp	x28, x10
	b.hs	LBB1_9
; %bb.13:                               ;   in Loop: Header=BB1_10 Depth=3
	add	x28, x5, x26
	prfm	pldl2keep, [x28]
	add	x28, x14, x26
	prfm	pldl2keep, [x28]
	b	LBB1_9
LBB1_14:                                ; %return
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
