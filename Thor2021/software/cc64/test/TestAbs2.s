	code
	align	16
_TestAbs:
	      	link 	#0
; 	return (abs(a));
	      	lw   	r2,16[bp]
	      	abs  	r1,r2
TestAbs2_3:
	      	unlink
	      	ret  	#8
_TestAbs2:
	      	abs  	r1,r18
TestAbs2_7:
	      	ret  	#8
	rodata
	align	16
	extern	_TestAbs
	extern	_TestAbs2
