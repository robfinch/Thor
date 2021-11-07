	bss
	align	8
	align	8
	dw	$FFF0200000000002 ; GC_skip
public bss _a:
	fill.b	16,0x00

endpublic
	align	8
	align	8
	dw	$FFF0200000000002 ; GC_skip
public bss _b:
	fill.b	16,0x00

endpublic
	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _TestUnion:
	      	sub  	$sp,$sp,#32
	      	sw   	$fp,[$sp]
	      	sw   	$r0,8[$sp]
	      	mov  	$fp,$sp
	      	ldi  	$v0,#8
	      	lf.d 	$fp2,_b[$v0]
	      	lw   	$v0,_a
	      	itof.d	$fp3,$v0
	      	fadd.d	$fp1,$fp2,$fp3
	      	mov  	$sp,$fp
	      	lw   	$fp,[$sp]
	      	ret  	#32
endpublic

	rodata
	align	16
;	global	_TestUnion
;	global	_a
;	global	_b
