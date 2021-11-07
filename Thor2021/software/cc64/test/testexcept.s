	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _testexcept:
	      	sub  	$sp,$sp,#32
	      	sw   	$lr,24[$sp]
	      	sw   	$xlr,16[$sp]
	      	sw   	$r0,8[$sp]
	      	sw   	$fp,[$sp]
	      	ldi  	$xlr,#testexcept_10
	      	mov  	$fp,$sp
	      	sub  	$sp,$sp,#0
	      	sub  	$sp,$sp,#16
	      	sw   	$r11,0[$sp]
	      	sw   	$r12,8[$sp]
	      	lw   	$r11,40[$fp]
	      	lw   	$r12,32[$fp]
; 	if (a)
	      	beq  	$r12,$r0,testexcept_13
;====================================================
; Basic Block 1
;====================================================
; 		throw (__exception)66;
	      	ldi  	$v0,#66
	      	brk  	$v0,#1
testexcept_13:
; 	if (b)
	      	beq  	$r11,$r0,testexcept_15
;====================================================
; Basic Block 2
;====================================================
; 		throw "Hello World";
	      	ldi  	$v0,#testexcept_0
	      	ldi  	$v1,#20015
	      	bra  	testexcept_10
testexcept_15:
;====================================================
; Basic Block 3
;====================================================
; 	printf("Test over");
	      	sub  	$sp,$sp,#8
	      	ldi  	$v2,#testexcept_1
	      	sw   	$v2,0[$sp]
	      	call 	_printf
	      	add  	$sp,$sp,#8
	      	bra  	testexcept_12
testexcept_10:
;====================================================
; Basic Block 4
;====================================================
	      	lw   	$lr,16[$fp]
	      	sw   	$lr,24[$fp]
testexcept_12:
	      	lw   	$r11,0[$sp]
	      	lw   	$r12,8[$sp]
	      	mov  	$sp,$fp
	      	lw   	$fp,[$sp]
	      	lw   	$xlr,16[$sp]
	      	lw   	$lr,24[$sp]
	      	ret  	#32
endpublic

	rodata
	align	16
	align	2
testexcept_1:	; Test over
	dc	84,101,115,116,32,111,118,101
	dc	114,0
testexcept_0:	; Hello World
	dc	72,101,108,108,111,32,87,111
	dc	114,108,100,0
;	global	_testexcept
	extern	_printf
