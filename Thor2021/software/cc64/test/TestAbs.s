	code
	align	16
_abs:
; 	return a < 0 ? -a : a;
	      	mov  	r1,r18
	      	bge  	r18,r0,TestAbs_3
	      	neg  	r1,r18
TestAbs_3:
	      	ret  	#8
_min:
; 	return a < b ? a : b;
	      	mov  	r1,r19
	      	bge  	r18,r19,TestAbs_9,#0
	      	mov  	r1,r18
TestAbs_9:
	      	ret  	#8
_max:
; 	return a > b ? a : b + b * 20;
	      	mul  	r2,r19,#20
	      	add  	r1,r19,r2
	      	bge  	r19,r18,TestAbs_15,#0
	      	mov  	r1,r18
TestAbs_15:
	      	ret  	#8
_minu:
; 	return a < b ? a : b;
	      	mov  	r1,r19
	      	bgeu 	r18,r19,TestAbs_21
	      	mov  	r1,r18
TestAbs_21:
	      	ret  	#8
	rodata
	align	16
	extern	_minu
	extern	_abs
	extern	_min
	extern	_max
