	bss
	align	8
	align	8
	dw	$FFF020000000000F
public bss _var:
	fill.b	120,0x00

endpublic
	align	8
	align	8
	dw	$FFF0200000000078
public bss _vara:
	fill.b	960,0x00

endpublic
	code
	align	2
;====================================================
; Basic Block 0
;====================================================
public code _main:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	sw       	$xlr,16[$sp]
	      	sw       	$lr,24[$sp]
	      	ldi      	$xlr,#TestAddrof_5
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#32
; 	return ch = in64(&vara[ndx]);
	      	lw       	$t2,32[$fp]
	      	shl      	$t1,$t2,#3
	      	add      	$t0,$t1,#_vara
	      	push     	$t0
	      	call     	_in64
	      	add      	$sp,$sp,#8
	      	mov      	$t0,$v0
	      	sc       	$t0,-2[$fp]
	      	lw       	$t0,-2[$fp]
	      	mov      	$v0,$t0
TestAddrof_8:
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	lw       	$xlr,16[$sp]
	      	lw       	$lr,24[$sp]
	      	ret      	#32
TestAddrof_5:
	      	lw       	$lr,16[$fp]
	      	sw       	$lr,24[$fp]
	      	bra      	TestAddrof_8
endpublic

	rodata
	align	16
;	global	_main
;	global	_vara
	extern	_in64
;	global	_var
