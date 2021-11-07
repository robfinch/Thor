	data
	align	2
public data _b:
	dw	262144
endpublic

	code
	align	16
_TestShift1:
	      	link 	#0
; 	return a+b;
	      	lw   	r2,16[bp]
	      	lw   	r3,_b
	      	add  	r1,r2,r3
TestShift1_3:
	      	unlink
	      	ret  	#8
	rodata
	align	16
	extern	_TestShift1
;	global	_b
