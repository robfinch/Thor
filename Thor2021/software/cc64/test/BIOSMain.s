	code
	align	16
public code _BIOSMain:
	      	push 	xlr
	      	ldi  	xlr,#BIOSMain_4
	      	link 	bp,#40
	      	push 	r11
	      	ldi  	r11,#_GetButton
	      	lw   	r3,BIOSMain_1
	      	sw   	r3,-8[bp]
	      	sw   	r0,-40[bp]
	      	ldi  	r3,#8911872
	      	sh   	r3,_DBGAttr
	      	call 	_DBGClearScreen
	      	call 	_DBGHomeCursor
	      	push 	r18
	      	ldi  	r3,#BIOSMain_2
	      	mov  	r18,r3
	      	call 	_DBGDisplayString
	      	pop  	r18
	      	push 	r18
	      	ldi  	r3,#BIOSMain_3
	      	mov  	r18,r3
	      	call 	_DBGDisplayString
	      	pop  	r18
BIOSMain_7:
	      	call 	[r11]
	      	sw   	r1,-32[bp]
	      	lw   	r3,-32[bp]
	      	bbs  	r3,#3,BIOSMain_14
	      	bbs  	r3,#1,BIOSMain_15
	      	bbs  	r3,#0,BIOSMain_16
	      	bra  	BIOSMain_9
BIOSMain_14:
BIOSMain_17:
	      	call 	[r11]
	      	beq  	r1,r0,BIOSMain_18
	      	bra  	BIOSMain_17
BIOSMain_18:
	      	call 	_ramtest
	      	bra  	BIOSMain_9
BIOSMain_15:
BIOSMain_19:
	      	call 	[r11]
	      	beq  	r1,r0,BIOSMain_20
	      	bra  	BIOSMain_19
BIOSMain_20:
	      	call 	_ramtest
	      	bra  	BIOSMain_9
BIOSMain_16:
BIOSMain_21:
	      	call 	[r11]
	      	beq  	r1,r0,BIOSMain_22
	      	bra  	BIOSMain_21
BIOSMain_22:
	      	call 	_ramtest
BIOSMain_9:
	      	bra  	BIOSMain_7
BIOSMain_23:
	      	pop  	r11
	      	unlink	bp
	      	pop  	xlr
	      	ret  
BIOSMain_4:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	BIOSMain_23
endpublic

public code _BTNCIRQHandler:
	      	push 	r1
	      	push 	r2
	      	push 	r3
	      	push 	r4
	      	push 	r5
	      	push 	r6
	      	push 	r7
	      	push 	r8
	      	push 	r9
	      	push 	r10
	      	push 	r11
	      	push 	r12
	      	push 	r13
	      	push 	r14
	      	push 	r15
	      	push 	r16
	      	push 	r17
	      	push 	r18
	      	push 	r19
	      	push 	r20
	      	push 	r21
	      	push 	r22
	      	push 	r23
	      	push 	r24
	      	push 	r25
	      	push 	r26
	      	push 	gp
	      	push 	xlr
	      	push 	lr
	      	push 	bp
	      	push 	xlr
	      	ldi  	xlr,#BIOSMain_29
	      	link 	bp,#8
	      	push 	r11
	      	     	
			ldi		r1,#30
			sh		r1,PIC_ESR
	      	push 	r18
	      	ldi  	r3,#BIOSMain_28
	      	mov  	r18,r3
	      	call 	_DBGDisplayString
	      	pop  	r18
	      	ldi  	r11,#63
BIOSMain_32:
	      	blt  	r11,r0,BIOSMain_33
	      	push 	r18
	      	mov  	r18,r11
	      	     	
			csrrw	r0,#$101,r18
	      	pop  	r18
	      	push 	r18
	      	     	
			csrrd	r1,#$100,r0
	      	mov  	r18,r1
	      	call 	_puthex
	      	pop  	r18
	      	push 	r18
	      	ldi  	r3,#32
	      	mov  	r18,r3
	      	call 	_putch
	      	pop  	r18
	      	sub  	r11,r11,#1
	      	bra  	BIOSMain_32
BIOSMain_33:
BIOSMain_43:
	      	pop  	r11
	      	unlink	bp
	      	pop  	xlr
	      	pop  	bp
	      	pop  	lr
	      	pop  	xlr
	      	pop  	gp
	      	pop  	r26
	      	pop  	r25
	      	pop  	r24
	      	pop  	r23
	      	pop  	r22
	      	pop  	r21
	      	pop  	r20
	      	pop  	r19
	      	pop  	r18
	      	pop  	r17
	      	pop  	r16
	      	pop  	r15
	      	pop  	r14
	      	pop  	r13
	      	pop  	r12
	      	pop  	r11
	      	pop  	r10
	      	pop  	r9
	      	pop  	r8
	      	pop  	r7
	      	pop  	r6
	      	pop  	r5
	      	pop  	r4
	      	pop  	r3
	      	pop  	r2
	      	pop  	r1
	      	rti  
BIOSMain_29:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	BIOSMain_43
endpublic

public code _DBERout:
	      	push 	r1
	      	push 	r2
	      	push 	r3
	      	push 	r4
	      	push 	r5
	      	push 	r6
	      	push 	r7
	      	push 	r8
	      	push 	r9
	      	push 	r10
	      	push 	r11
	      	push 	r12
	      	push 	r13
	      	push 	r14
	      	push 	r15
	      	push 	r16
	      	push 	r17
	      	push 	r18
	      	push 	r19
	      	push 	r20
	      	push 	r21
	      	push 	r22
	      	push 	r23
	      	push 	r24
	      	push 	r25
	      	push 	r26
	      	push 	gp
	      	push 	xlr
	      	push 	lr
	      	push 	bp
	      	push 	xlr
	      	ldi  	xlr,#BIOSMain_45
	      	link 	bp,#8
	      	push 	r11
	      	push 	r18
	      	ldi  	r3,#BIOSMain_44
	      	mov  	r18,r3
	      	call 	_DBGDisplayString
	      	pop  	r18
	      	push 	r18
	      	     	
			csrrd	r1,#$40,r0
	      	mov  	r18,r1
	      	call 	_puthex
	      	pop  	r18
	      	push 	r18
	      	ldi  	r3,#32
	      	mov  	r18,r3
	      	call 	_putch
	      	pop  	r18
	      	push 	r18
	      	     	
			csrrd	r1,#7,r0
			sh		r1,$FFDC0080
	      	mov  	r18,r1
	      	call 	_puthex
	      	pop  	r18
	      	push 	r18
	      	ldi  	r3,#32
	      	mov  	r18,r3
	      	call 	_putch
	      	pop  	r18
	      	ldi  	r11,#63
BIOSMain_56:
	      	blt  	r11,r0,BIOSMain_57
	      	push 	r18
	      	mov  	r18,r11
	      	     	
			csrrw	r0,#$101,r18
	      	pop  	r18
	      	push 	r18
	      	     	
			csrrd	r1,#$100,r0
BIOSMain_63:
	      	mov  	r18,r1
	      	call 	_puthex
	      	pop  	r18
	      	push 	r18
	      	ldi  	r3,#32
	      	mov  	r18,r3
	      	call 	_putch
	      	pop  	r18
	      	sub  	r11,r11,#1
	      	bra  	BIOSMain_56
BIOSMain_57:
BIOSMain_67:
	      	bra  	BIOSMain_67
BIOSMain_69:
	      	pop  	r11
	      	unlink	bp
	      	pop  	xlr
	      	pop  	bp
	      	pop  	lr
	      	pop  	xlr
	      	pop  	gp
	      	pop  	r26
	      	pop  	r25
	      	pop  	r24
	      	pop  	r23
	      	pop  	r22
	      	pop  	r21
	      	pop  	r20
	      	pop  	r19
	      	pop  	r18
	      	pop  	r17
	      	pop  	r16
	      	pop  	r15
	      	pop  	r14
	      	pop  	r13
	      	pop  	r12
	      	pop  	r11
	      	pop  	r10
	      	pop  	r9
	      	pop  	r8
	      	pop  	r7
	      	pop  	r6
	      	pop  	r5
	      	pop  	r4
	      	pop  	r3
	      	pop  	r2
	      	pop  	r1
	      	rti  
BIOSMain_45:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	BIOSMain_69
endpublic

public code _IBERout:
	      	push 	r1
	      	push 	r2
	      	push 	r3
	      	push 	r4
	      	push 	r5
	      	push 	r6
	      	push 	r7
	      	push 	r8
	      	push 	r9
	      	push 	r10
	      	push 	r11
	      	push 	r12
	      	push 	r13
	      	push 	r14
	      	push 	r15
	      	push 	r16
	      	push 	r17
	      	push 	r18
	      	push 	r19
	      	push 	r20
	      	push 	r21
	      	push 	r22
	      	push 	r23
	      	push 	r24
	      	push 	r25
	      	push 	r26
	      	push 	gp
	      	push 	xlr
	      	push 	lr
	      	push 	bp
	      	push 	xlr
	      	ldi  	xlr,#BIOSMain_72
	      	link 	bp,#8
	      	push 	r11
	      	push 	r18
	      	ldi  	r3,#BIOSMain_70
	      	mov  	r18,r3
	      	call 	_DBGDisplayString
	      	pop  	r18
	      	push 	r18
	      	ldi  	r3,#BIOSMain_71
	      	mov  	r18,r3
	      	call 	_DBGDisplayString
	      	pop  	r18
	      	ldi  	r11,#63
BIOSMain_75:
	      	blt  	r11,r0,BIOSMain_76
	      	push 	r18
	      	mov  	r18,r11
	      	     	
			csrrw	r0,#$101,r18
	      	pop  	r18
	      	push 	r18
	      	     	
			csrrd	r1,#$100,r0
	      	mov  	r18,r1
	      	call 	_puthex
	      	pop  	r18
	      	push 	r18
	      	ldi  	r3,#32
	      	mov  	r18,r3
	      	call 	_putch
	      	pop  	r18
	      	sub  	r11,r11,#1
	      	bra  	BIOSMain_75
BIOSMain_76:
BIOSMain_86:
	      	bra  	BIOSMain_86
BIOSMain_88:
	      	pop  	r11
	      	unlink	bp
	      	pop  	xlr
	      	pop  	bp
	      	pop  	lr
	      	pop  	xlr
	      	pop  	gp
	      	pop  	r26
	      	pop  	r25
	      	pop  	r24
	      	pop  	r23
	      	pop  	r22
	      	pop  	r21
	      	pop  	r20
	      	pop  	r19
	      	pop  	r18
	      	pop  	r17
	      	pop  	r16
	      	pop  	r15
	      	pop  	r14
	      	pop  	r13
	      	pop  	r12
	      	pop  	r11
	      	pop  	r10
	      	pop  	r9
	      	pop  	r8
	      	pop  	r7
	      	pop  	r6
	      	pop  	r5
	      	pop  	r4
	      	pop  	r3
	      	pop  	r2
	      	pop  	r1
	      	rti  
BIOSMain_72:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	BIOSMain_88
endpublic

	rodata
	align	16
	align	8
BIOSMain_1:
	dh	0x54442D18,0x400921FB
	align	2
BIOSMain_71:	; PC History:
	dc	80,67,32,72,105,115,116,111
	dc	114,121,58,13,10,0
BIOSMain_70:	; Instruction Bus Error:
	dc	13,10,73,110,115,116,114,117
	dc	99,116,105,111,110,32,66,117
	dc	115,32,69,114,114,111,114,58
	dc	13,10,0
BIOSMain_44:	; Databus error: 
	dc	13,10,68,97,116,97,98,117
	dc	115,32,101,114,114,111,114,58
	dc	32,0
BIOSMain_28:	; PC History:
	dc	13,10,80,67,32,72,105,115
	dc	116,111,114,121,58,13,10,0
BIOSMain_3:	;   Menu  up = ramtest  left = float test  right=TinyBasic
	dc	32,32,77,101,110,117,13,10
	dc	32,32,117,112,32,61,32,114
	dc	97,109,116,101,115,116,13,10
	dc	32,32,108,101,102,116,32,61
	dc	32,102,108,111,97,116,32,116
	dc	101,115,116,13,10,32,32,114
	dc	105,103,104,116,61,84,105,110
	dc	121,66,97,115,105,99,13,10
	dc	0
BIOSMain_2:	;   FT64 Bios Started
	dc	32,32,70,84,54,52,32,66
	dc	105,111,115,32,83,116,97,114
	dc	116,101,100,13,10,0
;	global	_BIOSMain
;	global	_BTNCIRQHandler
	extern	_DBGHomeCursor
	extern	_ramtest
	extern	_DBGClearScreen
	extern	_DBGDisplayString
	extern	_putch
	extern	_DBGAttr
;	global	_DBERout
;	global	_IBERout
	extern	_printf
	extern	_FloatTest
	extern	_prtflt
	extern	_puthex
