	code
	align	16
public code _TestFor:
	      	push 	xlr
	      	ldi  	xlr,#TestFor_0
	      	link 	#16
; 	for (x = 1; x < 100; x++) {
	      	ldi  	r3,#1
	      	sw   	r3,-8[bp]
TestFor_3:
	      	lw   	r3,-8[bp]
	      	cmp  	r4,r3,#100
	      	bge  	r4,r0,TestFor_4,#2
; 		putch('a');
	      	ldi  	r3,#97
	      	push 	r3
	      	call 	_putch
	      	add  	sp,sp,#8
TestFor_5:
	      	lw   	r3,-8[bp]
	      	add  	r3,r3,#1
	      	sw   	r3,-8[bp]
	      	bra  	TestFor_3
TestFor_4:
; 	y = 50;
	      	ldi  	r3,#50
	      	sw   	r3,-16[bp]
TestFor_6:
	      	lw   	r3,-16[bp]
	      	bge  	r0,r3,TestFor_7
; 		putch('b');
	      	ldi  	r3,#98
	      	push 	r3
	      	call 	_putch
	      	add  	sp,sp,#8
; 		--y;
	      	lw   	r3,-16[bp]
	      	sub  	r3,r3,#1
	      	sw   	r3,-16[bp]
TestFor_8:
	      	bra  	TestFor_6
TestFor_7:
TestFor_9:
	      	unlink
	      	pop  	xlr
	      	ret  	#8
TestFor_0:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	TestFor_9
endpublic



	rodata
	align	16
;	global	_TestFor
	extern	_putch
