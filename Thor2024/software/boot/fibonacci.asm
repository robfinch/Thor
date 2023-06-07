# Fibonacci calculator Thor2023 asm
# r1 in the end will hold the Nth fibonacci number

	.bss
	.space	10
.set	ary,0xFFFC0000
.set	txtscreen,0xFD000000
.set leds,0xFD0FFF00
.set keybd,0xFD0FFE00
.set rand,0xFD0FFD00

	.data
	.space	10

#	.org	0xFFFFFFFFFFFD0000
	.text
#	.align	0
start:
	ldi t0,-1
	stt t0,leds
	ldi t0,0x43FFFFE000000020

	mov t3,r0
	ldi t2,16384
.st1:
	sto t0,txtscreen[r0+t3]
	add t3,t3,8
	blt t3,t2,.st1

	mov t3,r0
	ldi t2,40
.st2:
	sto r0,0xfffc0000[r0+t3]
	add t3,t3,8
	blt t3,t2,.st2
	
	csrrd r2,r0,0x3001	# get the thread number
	and r2,r2,15				# 0 to 3
	ldi t0,1
	bne r2,t0,stall			# Allow only thread 1 to work

	LDI r2,0xFD
	LDI r2,0x01					# x = 1
	STT r2,ary@got

	LDI r3,0x10		# calculates 16th fibonacci number (13 = D in hex) (CHANGE HERE IF YOU WANT TO CALCULATE ANOTHER NUMBER)
	OR r1,r3,r0	# transfer y register to accumulator
	ADD r3,r3,-3	# handles the algorithm iteration counting

	LDI r1,2		# a = 2
	STT r1,0xFFFC0004		# stores a

floop: 
	LDT r2,0xFFFC0004		# x = a
	ADD r1,r1,r2					# a += x
	STT r1,0xFFFC0004		# stores a
	STT r2,0xFFFC0000		# stores x
	ADD r3,r3,-1					# y -= 1
  bnez r3,floop		# jumps back to loop if Z bit != 0 (y's decremention isn't zero yet)
  NOP
  NOP
  NOP
  NOP
  NOP
	NOP  
stall:
	BRA	stall

	.balign	0x100,0x0B

