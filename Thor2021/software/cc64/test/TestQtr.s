	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _TestQtr:
	      	sub  	$sp,$sp,#32
	      	sw   	$fp,[$sp]
	      	sw   	$r0,8[$sp]
	      	sw   	$xlr,16[$sp]
	      	sw   	$lr,24[$sp]
	      	ldi  	$xlr,#TestQtr_8
	      	mov  	$fp,$sp
	      	sub  	$sp,$sp,#8
	      	sw   	$r11,0[$sp]
	      	lw   	$r11,32[$fp]
; 	if (!IsNullPointer(qtr)) {
	      	sub  	$sp,$sp,#8
	      	sw   	$r11,0[$sp]
	      	call 	_IsNullPointer
	      	add  	$sp,$sp,#8
	      	bne  	$v0,$r0,TestQtr_11
;====================================================
; Basic Block 1
;====================================================
; 		if (*qtr == (('O' << 40) | ('B' << 32) | ('J' << 24) | ('E' << 16) | ('C' << 8) | 'T')) {
	      	lw   	$v2,[$r11]
	      	cmp  	$v3,$v2,#87146132489044
	      	bne  	$v3,$r0,TestQtr_13
;====================================================
; Basic Block 2
;====================================================
; 			return (21);
	      	ldi  	$v0,#21
TestQtr_15:
	      	lw   	$r11,0[$sp]
	      	mov  	$sp,$fp
	      	lw   	$fp,[$sp]
	      	lw   	$xlr,16[$sp]
	      	lw   	$lr,24[$sp]
	      	ret  	#32
TestQtr_13:
TestQtr_11:
;====================================================
; Basic Block 3
;====================================================
	      	bra  	TestQtr_10
TestQtr_8:
;====================================================
; Basic Block 4
;====================================================
	      	lw   	$lr,16[$fp]
	      	sw   	$lr,24[$fp]
TestQtr_10:
	      	bra  	TestQtr_15
endpublic

	rodata
	align	16
;	global	_TestQtr
	extern	_IsNullPointer
