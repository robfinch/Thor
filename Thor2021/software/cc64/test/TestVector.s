	code
	align	16
_TestVector:
	      	push 	xlr
	      	ldi  	xlr,#TestVector_0
	      	link 	#1560
	      	;    		register int vector b;
	      	;    		vm0 = 0xFFFFF;
	      	ldi  	r3,#1048575
	      	sw   	r3,-1560[bp]
	      	;    		vm0(e=e+g);
	      	vadd 	v3,v3,v4,vm5
	      	sv   	v3,-1536[bp]
TestVector_3:
	      	unlink
	      	pop  	xlr
	      	ret  	#8
TestVector_0:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	TestVector_3
_vmin:
	      	link 	#0
	      	;    	}
	      	unlink
	      	ret  	#8
	rodata
	align	16
	extern	_vmin
	extern	_TestVector
