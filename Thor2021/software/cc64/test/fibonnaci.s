	bss
	align	2
public bss _nums:
	fill.b	240,0x00

endpublic
	code
	align	16
public code _main:
	      	link 	bp,#32
	      	push 	r11
	      	push 	r12
	      	push 	r13
	      	push 	r14
	      	push 	r15
	      	ldi  	r11,#_nums
	      	ldi  	r15,#1
	      	sw   	r0,-16[bp]
	      	mov  	r13,r15
	      	ldi  	r12,#0
fibonnaci_3:
	      	cmp  	r1,r12,#23
	      	bge  	r1,r0,fibonnaci_4,#2
	      	bge  	r12,r15,fibonnaci_6,#0
	      	sw   	r15,[r11]
	      	mov  	r14,r15
	      	bra  	fibonnaci_7
fibonnaci_6:
	      	sw   	r14,[r11+r12*8]
	      	lw   	r2,-16[bp]
	      	add  	r14,r2,r13
	      	sw   	r13,-16[bp]
	      	mov  	r13,r14
fibonnaci_7:
	      	add  	r12,r12,r15
	      	bra  	fibonnaci_3
fibonnaci_4:
fibonnaci_8:
	      	pop  	r15
	      	pop  	r14
	      	pop  	r13
	      	pop  	r12
	      	pop  	r11
	      	unlink	bp
	      	ret  
endpublic



	rodata
	align	16
;	global	_main
;	global	_nums
