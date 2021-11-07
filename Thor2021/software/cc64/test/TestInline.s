	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _TestInline:
; 	__asm {
	      	;asm     	
			.0002:
			lc		r1,[lr]
			beq		.0001
			push	lr
			push	r1
			call	_DBGDisplayChar
			lw		lr,8[sp]
			add		sp,sp,#16
			add		lr,lr,#2
			bra		.0002
			.0001:
			add		lr,lr,#2
			ret
	      	;        		}
endpublic

;====================================================
; Basic Block 0
;====================================================
public code _main:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	sw       	$xlr,16[$sp]
	      	sw       	$lr,24[$sp]
	      	ldi      	$xlr,#TestInline_15
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#8
	      	ldi      	$t0,#2
	      	push     	$t0
	      	call     	_TestInline
	      	dc         	"Hello World!",0
	      	dc         	"A second parameter",0
	      	add      	$sp,$sp,#8
	      	mov      	$t0,$v0
	      	bra      	TestInline_17
TestInline_15:
;====================================================
; Basic Block 1
;====================================================
	      	lw       	$lr,16[$fp]
	      	sw       	$lr,24[$fp]
TestInline_17:
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	lw       	$xlr,16[$sp]
	      	lw       	$lr,24[$sp]
	      	ret      	#32
endpublic

	rodata
	align	16
	align	8
TestInline_10:	; A second parameter
	dc	65,32,115,101,99,111,110,100
	dc	32,112,97,114,97,109,101,116
	dc	101,114,0
TestInline_9:	; Hello World!
	dc	72,101,108,108,111,32,87,111
	dc	114,108,100,33,0
;	global	_main
;	global	_TestInline
