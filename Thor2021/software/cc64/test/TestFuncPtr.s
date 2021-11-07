	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _TestFuncptr:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	sw       	$xlr,16[$sp]
	      	sw       	$lr,24[$sp]
	      	ldi      	$xlr,#TestFuncPtr_5
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#24
; 	(*ExecAddress)();
	      	lw       	$t0,_ExecAddress
	      	sw       	$t0,-24[$fp]
	      	call     	[$t0]
	      	lw       	$t0,-24[$fp]
	      	mov      	$t1,$v0
; 	(*(ag->fptr))(21);
	      	lw       	$t0,-8[$fp]
	      	lw       	$t0,8[$t0]
	      	ldi      	$t1,#21
	      	push     	$t1
	      	call     	[$t0]
	      	add      	$sp,$sp,#8
	      	mov      	$t0,$v0
	      	bra      	TestFuncPtr_7
TestFuncPtr_5:
;====================================================
; Basic Block 1
;====================================================
	      	lw       	$lr,16[$fp]
	      	sw       	$lr,24[$fp]
TestFuncPtr_7:
TestFuncPtr_8:
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	lw       	$xlr,16[$sp]
	      	lw       	$lr,24[$sp]
	      	ret      	#32
endpublic

	rodata
	align	16
	extern	_ExecAddress
;	global	_TestFuncptr
