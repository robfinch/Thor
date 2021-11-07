	data
	align	2
public data _a:
	dw	31351931521954931
endpublic

	align	2
public data _b:
	dw	31351931521954931
endpublic

	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _TestConst:
	      	sub  	$sp,$sp,#32
	      	sw   	$fp,[$sp]
	      	sw   	$r0,8[$sp]
	      	sw   	$xlr,16[$sp]
	      	sw   	$lr,24[$sp]
	      	ldi  	$xlr,#TestConst_7
	      	mov  	$fp,$sp
	      	sub  	$sp,$sp,#8
; 	if (*ptr==(('o' << 48) | ('b' << 40) | ('j' << 32) | ('e' << 24) | ('c' << 16) | ('t' << 8) | 's'))
	      	lw   	$v2,-8[$fp]
	      	lw   	$v2,[$v2]
	      	cmp  	$v3,$v2,#31351931521954931
	      	bne  	$v3,$r0,TestConst_10
;====================================================
; Basic Block 1
;====================================================
; 		printf("hello");
	      	sub  	$sp,$sp,#8
	      	sw   	$r0,0[$sp]
	      	call 	_printf
	      	add  	$sp,$sp,#8
TestConst_10:
	      	bra  	TestConst_9
TestConst_7:
;====================================================
; Basic Block 2
;====================================================
	      	lw   	$lr,16[$fp]
	      	sw   	$lr,24[$fp]
TestConst_9:
	      	mov  	$sp,$fp
	      	lw   	$fp,[$sp]
	      	lw   	$xlr,16[$sp]
	      	lw   	$lr,24[$sp]
	      	ret  	#32
endpublic

	rodata
	align	16
	align	8
TestConst_0:	; hello
	dc	104,101,108,108,111,0
;	global	_TestConst
;	global	_a
;	global	_b
	extern	_printf
