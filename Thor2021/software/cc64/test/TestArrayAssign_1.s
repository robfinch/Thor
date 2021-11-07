	code
	align	16
public code _TestArrayAssign:
	      	link 	#424
	      	push 	r11
	      	push 	r12
	      	push 	r13
	      	push 	r14
	      	push 	r15
	      	push 	r16
	      	push 	r17
	      	ldi  	r14,#1
	      	ldi  	r15,#2
	      	ldi  	r16,#3
	      	ldi  	r17,#5
	      	lea  	r1,-184[bp]
	      	mov  	r11,r1
	      	lea  	r1,-424[bp]
	      	mov  	r12,r1
	      	lea  	r1,-120[bp]
	      	mov  	r13,r1
; 	y[0] = 1;
	      	sw   	r14,[r11]
; 	y[1] = 2;
	      	sw   	r15,8[r11]
; 	y[2] = 2;
	      	sw   	r15,16[r11]
; 	y[3] = 2;
	      	sw   	r15,24[r11]
; 	y[4] = 2;
	      	sw   	r15,32[r11]
; 	y[5] = 2;
	      	sw   	r15,40[r11]
; 	y[6] = 2;
	      	sw   	r15,48[r11]
; 	y[7] = 2;
	      	sw   	r15,56[r11]
; 	x[0][0] = 1;
	      	sw   	r14,[r13]
; 	x[0][1] = 2;
	      	sw   	r15,8[r13]
; 	x[0][2] = 2;
	      	sw   	r15,16[r13]
; 	x[0][3] = 2;
	      	sw   	r15,24[r13]
; 	x[0][4] = 2;
	      	sw   	r15,32[r13]
; 	x[1][0] = 3;
	      	sw   	r16,40[r13]
; 	x[1][1] = 3;
	      	sw   	r16,48[r13]
; 	x[1][2] = 3;
	      	sw   	r16,56[r13]
; 	x[1][3] = 3;
	      	sw   	r16,64[r13]
; 	x[1][4] = 5;
	      	sw   	r17,72[r13]
; 	x[2][0] = 5;
	      	sw   	r17,80[r13]
; 	x[2][1] = 5;
	      	sw   	r17,88[r13]
; 	x[2][2] = 5;
	      	sw   	r17,96[r13]
; 	x[2][3] = 5;
	      	sw   	r17,104[r13]
; 	x[2][4] = 5;
	      	sw   	r17,112[r13]
; 	z[0][0][0] = 1;
	      	sw   	r14,[r12]
; 	z[0][0][1] = 1;
	      	sw   	r14,8[r12]
; 	z[0][0][2] = 1;
	      	sw   	r14,16[r12]
; 	z[0][0][3] = 1;
	      	sw   	r14,24[r12]
; 	z[0][0][4] = 1;
	      	sw   	r14,32[r12]
; 	z[0][1][0] = 2;
	      	sw   	r15,40[r12]
; 	z[0][1][1] = 2;
	      	sw   	r15,48[r12]
; 	z[0][1][2] = 2;
	      	sw   	r15,56[r12]
; 	z[0][1][3] = 2;
	      	sw   	r15,64[r12]
; 	z[0][1][4] = 2;
	      	sw   	r15,72[r12]
; 	z[0][2][0] = 2;
	      	sw   	r15,80[r12]
TestArrayAssign_3:
	      	pop  	r17
	      	pop  	r16
	      	pop  	r15
	      	pop  	r14
	      	pop  	r13
	      	pop  	r12
	      	pop  	r11
	      	unlink
	      	ret  	#8
endpublic



public code _TestArrayAssign3:
	      	push 	xlr
	      	ldi  	xlr,#TestArrayAssign_4
	      	link 	#504
; 	for (m = 0; m < 3; m++) {
	      	sw   	r0,-24[bp]
TestArrayAssign_7:
	      	lw   	r3,-24[bp]
	      	cmp  	r4,r3,#3
	      	bge  	r4,r0,TestArrayAssign_8,#2
; 		for (j = 0; j < 4; j++) {
	      	sw   	r0,-8[bp]
TestArrayAssign_10:
	      	lw   	r3,-8[bp]
	      	cmp  	r4,r3,#4
	      	bge  	r4,r0,TestArrayAssign_11,#2
; 			for (k = 0; k < 5; k++)
	      	sw   	r0,-16[bp]
TestArrayAssign_13:
	      	lw   	r3,-16[bp]
	      	cmp  	r4,r3,#5
	      	bge  	r4,r0,TestArrayAssign_14,#2
; 				x[m][j][k] = rand();
	      	lw   	r4,-16[bp]
	      	shl  	r3,r4,#3
	      	lw   	r6,-8[bp]
	      	mulu 	r5,r6,#40
	      	lw   	r8,-24[bp]
	      	mulu 	r7,r8,#160
	      	lea  	r8,-504[bp]
	      	add  	r6,r7,r8
	      	add  	r4,r5,r6
	      	push 	r3
	      	push 	r4
	      	call 	_rand
	      	pop  	r4
	      	pop  	r3
	      	sw   	r1,[r4+r3]
	      	lw   	r3,-16[bp]
	      	add  	r3,r3,#1
	      	sw   	r3,-16[bp]
	      	bra  	TestArrayAssign_13
TestArrayAssign_14:
	      	lw   	r3,-8[bp]
	      	add  	r3,r3,#1
	      	sw   	r3,-8[bp]
	      	bra  	TestArrayAssign_10
TestArrayAssign_11:
TestArrayAssign_9:
	      	lw   	r3,-24[bp]
	      	add  	r3,r3,#1
	      	sw   	r3,-24[bp]
	      	bra  	TestArrayAssign_7
TestArrayAssign_8:
TestArrayAssign_16:
	      	unlink
	      	pop  	xlr
	      	ret  	#8
TestArrayAssign_4:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	TestArrayAssign_16
endpublic



public code _TestArrayAssign4:
	      	push 	xlr
	      	ldi  	xlr,#TestArrayAssign_17
	      	link 	#720
; 	x[2][3] = {10,9,8,7,6};
	      	ldi  	r4,#624
	      	lea  	r5,-720[bp]
	      	add  	r3,r4,r5
	      	mov  	r4,r3
	      	ldi  	r5,#10
	      	sw   	r5,0[r4]
	      	ldi  	r5,#9
	      	sw   	r5,8[r4]
	      	ldi  	r5,#8
	      	sw   	r5,16[r4]
	      	ldi  	r5,#7
	      	sw   	r5,24[r4]
	      	ldi  	r5,#6
	      	sw   	r5,32[r4]
TestArrayAssign_20:
	      	unlink
	      	pop  	xlr
	      	ret  	#8
TestArrayAssign_17:
	      	lw   	lr,8[bp]
	      	sw   	lr,16[bp]
	      	bra  	TestArrayAssign_20
endpublic



	rodata
	align	16
	extern	_rand
;	global	_TestArrayAssign
;	global	_TestArrayAssign3
;	global	_TestArrayAssign4
