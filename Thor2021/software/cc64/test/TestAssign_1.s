	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _main:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	sw       	$xlr,16[$sp]
	      	sw       	$lr,24[$sp]
	      	ldi      	$xlr,#TestAssign_4
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#48
	      	sub      	$sp,$sp,#8
	      	sw       	$r11,0[$sp]
	      	lea      	$t0,-16[$fp]
	      	mov      	$r11,$t0
	      	;        		ABC aaa;
	      	;        		aaa = bbb;
	      	lea      	$t0,-32[$fp]
	      	mov      	$a0,$r11
	      	mov      	$a1,$t0
	      	ldi      	$a2,#16
	      	call     	memcpy
	      	;        		return (aaa.abc);
	      	lw       	$t0,[$r11]
	      	mov      	$v0,$t0
TestAssign_7:
	      	lw       	$r11,0[$sp]
	      	add      	$sp,$sp,#8
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	lw       	$xlr,16[$sp]
	      	lw       	$lr,24[$sp]
	      	ret      	#32
;====================================================
; Basic Block 1
;====================================================
	      	bra      	TestAssign_6
TestAssign_4:
;====================================================
; Basic Block 2
;====================================================
	      	lw       	$lr,16[$fp]
	      	sw       	$lr,24[$fp]
TestAssign_6:
	      	bra      	TestAssign_7
endpublic

	rodata
	align	16
;	global	_main
