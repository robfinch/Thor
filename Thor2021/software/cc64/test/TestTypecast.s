	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _TestTypecast:
	      	sub  	$sp,$sp,#32
	      	sw   	$fp,[$sp]
	      	sw   	$r0,8[$sp]
	      	mov  	$fp,$sp
	      	sub  	$sp,$sp,#8
	      	;    		int *tmp;
	      	;    		(int *)(*tmp) = a;
	      	lw   	$v0,-8[$fp]
	      	lw   	$v1,24[$fp]
	      	sptr 	$v1,[$v0]
	      	ldi  	$v2,#1
	      	spt  	$v2,[$v0]
	      	;    		return (int *)21;
	      	ldi  	$v0,#21
TestTypecast_7:
	      	mov  	$sp,$fp
	      	lw   	$fp,[$sp]
	      	ret  	#32
;====================================================
; Basic Block 1
;====================================================
	      	bra  	TestTypecast_6
TestTypecast_6:
;====================================================
; Basic Block 2
;====================================================
	      	bra  	TestTypecast_7
endpublic

	rodata
	align	16
;	global	_TestTypecast
