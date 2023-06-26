# boot.asm Thor2024 assembly language

	.bss
	.space	10
.set ary,0xFFFC0000
.set txtscreen,0xFEC00000
.set leds,0xFEDFFF00
.set keybd,0xFEDCFE00
.set rand,0xFEE1FD00

	.data
	.space	10

#	.org	0xFFFFFFFFFFFD0000
	.text
#	.align	0
start:
	ldi t0,-1
	stt t0,leds

	# clearscreen
	ldi t0,0x43FFFFE0003F0020
	mov t3,r0
	ldi t2,16384
.st1:
	sto t0,txtscreen[t3]
	add t3,t3,8
	blt t3,t2,.st1

	bsr	Delay3s

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

	ldi r2,0xFD
	ldi r2,0x01					# x = 1
	stt r2,ary@got

	ldi r3,0x10		# calculates 16th fibonacci number (13 = D in hex) (CHANGE HERE IF YOU WANT TO CALCULATE ANOTHER NUMBER)
	or r1,r3,r0	# transfer y register to accumulator
	add r3,r3,-3	# handles the algorithm iteration counting

	ldi r1,2		# a = 2
	stt r1,0xFFFC0004		# stores a

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

# ------------------------------------------------------------------------------
# Delay for a few seconds at startup.
# ------------------------------------------------------------------------------

Delay3s:
	ldi		a0,300000
.0001:
	lsr		a1,a0,16
	stt		a1,leds
	sub		a0,a0,1
	bgt		a0,r0,.0001	
	ret

	.balign	0x100,0x0B
	
	.rodata
	.org 0xffe0
	.8byte	0xFFFFFFFFFFFCFFF0
	.8byte	0xFFFFFFFFFFFFFFFF
	.8byte	0xFFFFFFFFD0000000
	.8byte	0xFFFFFFFFFFFFFFFF


