	code
	align	16
_TestConstant:
	      	link 	bp,#8
	      	push 	r11
	      	ldi  	r11,#0
TestConstant_3:
	      	or   	r2,r0,#34464
	      	orq1 	r2,#1
	      	cmp  	r1,r11,r2
	      	bge  	r1,r0,TestConstant_4,#2
	      	lw   	r2,16[bp]
	      	add  	r1,r2,r11
	      	sw   	r1,16[bp]
	      	add  	r11,r11,#1
	      	bra  	TestConstant_3
TestConstant_4:
	      	lw   	r1,16[bp]
	      	pop  	r11
	      	unlink	bp
	      	ret  
	rodata
	align	16
	extern	_TestConstant
