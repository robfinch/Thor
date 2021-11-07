	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _TestBFAI:
	      	sub  	$sp,$sp,#32
	      	sw   	$fp,[$sp]
	      	sw   	$r0,8[$sp]
	      	mov  	$fp,$sp
	      	sub  	$sp,$sp,#8
	      	;    		bf->bf++;
	      	lw   	$v2,24[$fp]
	      	lw   	$v1,0[$v2]
	      	and  	$v1,$v1,#15
	      	ldi  	$v3,#-8
	      	add  	$v1,$v1,$v3
	      	xor  	$v1,$v1,$v3
	      	mov  	$v0,$v1
	      	add  	$v1,$v1,#1
	      	and  	$v1,#15
	      	and  	$v0,$v0,#-16
	      	or   	$v0,$v0,$v1
	      	sw   	$v0,0[$v2]
	      	;    		return bf->bf;
	      	lw   	$v1,24[$fp]
	      	lw   	$v1,0[$v1]
	      	mov  	$v0,$v1
	      	and  	$v0,$v0,#15
	      	ldi  	$v2,#-8
	      	add  	$v0,$v0,$v2
	      	xor  	$v0,$v0,$v2
	      	mov  	$v0,$v0
TestBFAI_7:
	      	mov  	$sp,$fp
	      	lw   	$fp,[$sp]
	      	ret  	#32
;====================================================
; Basic Block 1
;====================================================
	      	bra  	TestBFAI_6
TestBFAI_6:
;====================================================
; Basic Block 2
;====================================================
	      	bra  	TestBFAI_7
endpublic

	rodata
	align	16
;	global	_TestBFAI
