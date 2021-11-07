	code
	align	16
public code _TestBitfield:
	      	link 	#16
	      	push 	r11
	      	lea  	r1,-8[bp]
	      	mov  	r11,r1
; 	j.a = 1;
	      	ldi  	r1,#1
	      	lw   	r2,0[r11]
	      	and  	r1,#1
	      	and  	r2,#-2
	      	or   	r2,r2,r1
	      	sw   	r2,0[r11]
; 	j.b = 10;
	      	ldi  	r1,#10
	      	lw   	r2,0[r11]
	      	and  	r1,#31
	      	ror  	r2,r2,#1
	      	and  	r2,#-32
	      	or   	r2,r2,r1
	      	rol  	r2,r2,#1
	      	sw   	r2,0[r11]
; 	j.c = j.a + j.b;
	      	lw   	r3,0[r11]
	      	mov  	r2,r3
	      	and  	r2,#1
	      	ldi  	r3,#-1
	      	add  	r2,r2,r3
	      	xor  	r2,r2,r3
	      	lw   	r4,0[r11]
	      	mov  	r3,r4
	      	shru 	r3,r3,#1
	      	and  	r3,#31
	      	ldi  	r4,#-16
	      	add  	r3,r3,r4
	      	xor  	r3,r3,r4
	      	add  	r1,r2,r3
	      	lw   	r2,0[r11]
	      	and  	r1,#2047
	      	ror  	r2,r2,#6
	      	and  	r2,#-2048
	      	or   	r2,r2,r1
	      	rol  	r2,r2,#6
	      	sw   	r2,0[r11]
	      	mov  	r1,r2
	      	shru 	r1,r1,#6
	      	and  	r1,#2047
	      	ldi  	r2,#-1024
	      	add  	r1,r1,r2
	      	xor  	r1,r1,r2
TestBitfield_3:
	      	pop  	r11
	      	unlink
	      	ret  	#8
endpublic



	rodata
	align	16
;	global	_TestBitfield
