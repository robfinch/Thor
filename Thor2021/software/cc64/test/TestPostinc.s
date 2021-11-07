	code
	align	2
;====================================================
; Basic Block 0
;====================================================
public code _TestPostinc:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	sw       	$lr,24[$sp]
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#8
	      	sub      	$sp,$sp,#24
	      	sw       	$r11,0[$sp]
	      	sw       	$r12,8[$sp]
	      	sw       	$r13,16[$sp]
	      	lw       	$r11,32[$fp]
	      	lw       	$r12,-8[$fp]
	      	lw       	$r13,40[$fp]
	      	;        		int x;
	      	;        		*s1++ = *s2++ = *s1++;
	      	lc       	$t0,[$r11]
	      	sc       	$t0,[$r13]
	      	lc       	$t0,[$r13]
	      	sc       	$t0,[$r11]
	      	add      	$r11,$r11,#2
	      	add      	$r13,$r13,#2
	      	add      	$r11,$r11,#2
	      	;        		x = func()++;
	      	call     	_func
	      	mov      	$t0,$v0
	      	mov      	$r12,$t0
	      	;        		return (x);
	      	mov      	$v0,$r12
TestPostinc_5:
TestPostinc_8:
	      	lw       	$r11,0[$sp]
	      	lw       	$r12,8[$sp]
	      	lw       	$r13,16[$sp]
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	lw       	$lr,24[$sp]
	      	ret      	#48
	      	bra      	TestPostinc_8
endpublic

	rodata
	align	16
	extern	_func
;	global	_TestPostinc
