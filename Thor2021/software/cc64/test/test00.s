	bss
	align	8
	align	8
	dw	$FFF0200000000001
public bss _globa:
	fill.b	8,0x00

endpublic
	code
	align	16
;====================================================
; Basic Block 0
;====================================================
;   globa.m = ss + globa.l[0] + globa.l[1] + aaa;
	      	lc       	$t1,_globa
	      	add      	$t0,$t1,#34
	      	lc       	$t1,_globa+2
	      	add      	$v1,$t0,$t1
	      	add      	$v0,$v1,$a0
	      	sc       	$v0,_globa+4
;   return globa.m;
	      	lc       	$v0,_globa+4
test00_8:
	      	ret      	#0
endpublic

;====================================================
; Basic Block 0
;====================================================
public code _test00:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#72
	      	sw       	$r11,0[$sp]
	      	lw       	$r11,32[$fp]
;   a->m = ss + a->l[0] + a->l[1] + aaa;
	      	lc       	$t1,[$r11]
	      	add      	$t0,$t1,#34
	      	lc       	$t1,2[$r11]
	      	add      	$v1,$t0,$t1
	      	lw       	$t0,40[$fp]
	      	add      	$v0,$v1,$t0
	      	sc       	$v0,4[$r11]
;   return a->m;
	      	lc       	$v0,4[$r11]
	      	lw       	$r11,0[$sp]
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	ret      	#32
endpublic

	rodata
	align	16
;	global	_test0
;	global	_globa
;	global	_test00
