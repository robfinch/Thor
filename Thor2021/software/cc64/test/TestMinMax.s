	code
	align	16
_min:
	      	push 	xlr
	      	ldi  	xlr,#TestMinMax_0
	      	link 	bp,#0
	      	bge  	r18,r0,TestMinMax_3
	      	ldi  	r1,#21
	      	ldi  	r2,#17
	      	bra  	TestMinMax_0
TestMinMax_3:
	      	bge  	r18,r19,TestMinMax_5,#0
	      	mov  	r2,r18
	      	bra  	TestMinMax_6
TestMinMax_5:
	      	mov  	r3,r19
	      	mov  	r2,r3
TestMinMax_6:
	      	mov  	r1,r2
TestMinMax_7:
	      	unlink	bp
	      	pop  	xlr
	      	ret  
TestMinMax_0:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	TestMinMax_7
_max:
	      	bge  	r19,r18,TestMinMax_11,#0
	      	mov  	r2,r18
	      	bra  	TestMinMax_12
TestMinMax_11:
	      	mov  	r3,r19
	      	mov  	r2,r3
TestMinMax_12:
	      	mov  	r1,r2
	      	ret  
_minu:
	      	bgeu 	r18,r19,TestMinMax_17
	      	mov  	r2,r18
	      	bra  	TestMinMax_18
TestMinMax_17:
	      	mov  	r3,r19
	      	mov  	r2,r3
TestMinMax_18:
	      	mov  	r1,r2
	      	ret  
	rodata
	align	16
	extern	_amin
	extern	_minu
	extern	_min
	extern	_max
