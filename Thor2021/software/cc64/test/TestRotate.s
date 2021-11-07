	code
	align	16
_TestRotate:
	      	link 	#0
; 	return ((a << b) | (a >> (16-b)));
	      	lw   	r3,16[bp]
	      	lw   	r4,24[bp]
	      	asl  	r2,r3,r4
	      	lw   	r4,16[bp]
	      	ldi  	r6,#16
	      	lw   	r7,24[bp]
	      	sub  	r5,r6,r7
	      	asr  	r3,r4,r5
	      	or   	r1,r2,r3
	      	unlink
	      	ret  	#8
_TestRotate2:
	      	asl  	r2,r18,r19
	      	ldi  	r5,#16
	      	sub  	r4,r5,r19
	      	asr  	r3,r18,r4
	      	or   	r1,r2,r3
	      	ret  	#8
_TestRotate3:
	      	shlu 	r2,r18,r19
	      	ldi  	r5,#16
	      	sub  	r4,r5,r19
	      	shru 	r3,r18,r4
	      	or   	r1,r2,r3
	      	ret  	#8
_TestRotate4:
; 	return (a <<< b);
	      	rol  	r1,r18,r19
	      	ret  	#8
_TestRotate5:
; 	return (a >>> b);
	      	ror  	r1,r18,r19
	      	ret  	#8
	rodata
	align	16
	extern	_TestRotate
	extern	_TestRotate2
	extern	_TestRotate3
	extern	_TestRotate4
	extern	_TestRotate5
