	bss
	align	8
	align	8
	dw	$FFF0200000019000
public bss _t:
	fill.b	819200,0x00

endpublic
	code
	align	2
;====================================================
; Basic Block 0
;====================================================
public code _TestPtrSub:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#40
	      	sw       	$r11,0[$sp]
	      	lw       	$r11,-8[$fp]
; 	x.ndx = a - t;
	      	lw       	$t0,32[$fp]
	      	sub      	$v1,$t0,#_t
	      	shru     	$v0,$v1,#13
	      	mov      	$r11,$v0
; 	return (x.ndx);
	      	mov      	$v0,$r11
	      	lw       	$r11,0[$sp]
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	ret      	#32
endpublic

	rodata
	align	16
;	global	_TestPtrSub
;	global	_t
