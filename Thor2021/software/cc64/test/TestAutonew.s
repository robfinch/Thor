	code
	align	2
;====================================================
; Basic Block 0
;====================================================
public code _main:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	sw       	$lr,24[$sp]
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#8
; 	if (x = 10)
	      	ldi      	$t0,#10
	      	sw       	$t0,32[$fp]
	      	beq      	$t0,$r0,TestAutonew_11
TestAutonew_7:
TestAutonew_10:
	      	call     	__autodel
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	lw       	$lr,24[$sp]
	      	ret      	#40
TestAutonew_11:
; 	pd = auto new __int8[256];
	      	push     	#256
	      	call     	__autonew
	      	mov      	$t0,$v0
	      	sw       	$t0,-8[$fp]
	      	bra      	TestAutonew_10
endpublic

;====================================================
; Basic Block 0
;====================================================
public code _Test2:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	sw       	$lr,24[$sp]
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#16
	      	sw       	$r11,0[$sp]
	      	lw       	$r11,-8[$fp]
; 	pd = new __int8[256];
	      	push     	#256
	      	call     	__new
	      	mov      	$r11,$v0
; 	delete pd;
	      	push     	$r11
	      	call     	__delete
TestAutonew_17:
TestAutonew_20:
	      	lw       	$r11,0[$sp]
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	lw       	$lr,24[$sp]
	      	ret      	#32
endpublic

	rodata
	align	16
;	global	_main
;	global	_Test2
