	data
	align	8
	align	8
	align	8
	dw	$FFF0200000000003
public data _a:
	dw	21
	dc	104
	db	0,0,0,0,0,0
	align 8
	dh	0x00000000,0x00000000
endpublic

	align	8
	align	8
	dw	$FFF0200000000003
public data _b:
	dw	16
	dc	105
	db	0,0,0,0,0,0
	align 8
	dh	0x00000000,0x40454000
endpublic

	code
	align	2
;====================================================
; Basic Block 0
;====================================================
public code _TestStructAssign:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	sw       	$xlr,16[$sp]
	      	sw       	$lr,24[$sp]
	      	ldi      	$xlr,#TestStructAssign_9
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#72
	      	sw       	$r11,0[$sp]
	      	lea      	$t0,-24[$fp]
	      	mov      	$r11,$t0
; 	c = (UT){10,'k',21.5};
	      	lea      	$t0,TestStructAssign_4
	      	mov      	$a0,$r11
	      	mov      	$a1,$t0
	      	ldi      	$a2,#24
	      	call     	__aacpy
; 	c = d;
	      	lea      	$t0,-48[$fp]
	      	mov      	$a0,$r11
	      	mov      	$a1,$t0
	      	call     	__aacpy
; 	return (b.f + a.i);
	      	lf.d     	$fp4,_b+16
	      	lw       	$t0,_a
	      	itof.d   	$fp5,$t0
	      	fadd.d   	$fp3,$fp4,$fp5
	      	ftoi.d   	$v0,$fp3
TestStructAssign_12:
	      	lw       	$r11,0[$sp]
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	lw       	$xlr,16[$sp]
	      	lw       	$lr,24[$sp]
	      	ret      	#32
TestStructAssign_9:
	      	lw       	$lr,16[$fp]
	      	sw       	$lr,24[$fp]
	      	bra      	TestStructAssign_12
endpublic

	rodata
	align	16
	align	8
	align	8
TestStructAssign_4:
align 8	dw	10
align 2	dc	107
align 8	dw	0x4035800000000000
;	global	_a
;	global	_b
;	global	_TestStructAssign
