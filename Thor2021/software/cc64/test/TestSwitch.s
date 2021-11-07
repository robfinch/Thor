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
; 	switch(x) {
	      	lw       	$t0,32[$fp]
	      	sge      	$t1,$t0,#1
	      	sle      	$t2,$t0,#9
	      	sub      	$t0,$t0,#1
	      	shl      	$t0,$t0,#3
	      	lw       	$t0,TestSwitch_43[$t0]
	      	band     	$t1,$t2,$t0
	      	bra      	TestSwitch_31
TestSwitch_32:
	      	push     	#TestSwitch_1
	      	call     	_printf
	      	bra      	TestSwitch_31
TestSwitch_33:
	      	push     	#TestSwitch_2
	      	call     	_printf
	      	bra      	TestSwitch_31
TestSwitch_34:
	      	push     	#TestSwitch_3
	      	call     	_printf
	      	bra      	TestSwitch_31
TestSwitch_35:
	      	push     	#TestSwitch_4
	      	call     	_printf
	      	bra      	TestSwitch_31
TestSwitch_36:
	      	push     	#TestSwitch_5
	      	call     	_printf
	      	bra      	TestSwitch_31
TestSwitch_37:
	      	push     	#TestSwitch_6
	      	call     	_printf
	      	bra      	TestSwitch_31
TestSwitch_38:
	      	push     	#TestSwitch_7
	      	call     	_printf
	      	bra      	TestSwitch_31
TestSwitch_39:
	      	push     	#TestSwitch_8
	      	call     	_printf
	      	bra      	TestSwitch_31
TestSwitch_40:
	      	push     	#TestSwitch_9
	      	call     	_printf
TestSwitch_31:
TestSwitch_27:
TestSwitch_30:
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	lw       	$lr,24[$sp]
	      	ret      	#40
endpublic

	rodata
	align	16
	align	8
TestSwitch_43:
	dw	TestSwitch_32,TestSwitch_33,TestSwitch_34,TestSwitch_35,TestSwitch_36,TestSwitch_37,TestSwitch_38
	dw	TestSwitch_39,TestSwitch_40
	align	8
TestSwitch_1:	; 1
	dc	49,0
TestSwitch_2:	; 2
	dc	50,0
TestSwitch_3:	; 3
	dc	51,0
TestSwitch_4:	; 4
	dc	52,0
TestSwitch_5:	; 5
	dc	53,0
TestSwitch_6:	; 6
	dc	54,0
TestSwitch_7:	; 7
	dc	55,0
TestSwitch_8:	; 8
	dc	56,0
TestSwitch_9:	; 9
	dc	57,0
;	global	_main
	extern	_printf
