# Fibonacci calculator Thor2021 asm
# r1 in the end will hold the Nth fibonacci number

#	.org	0xFFFFFFFFFFFE0000

start:
	LDI	r2,0xFD
	LDI	r2,0x01		# x = 1
	STO	r2,00

	LDI	r3,0x10		# calculates 16th fibonacci number (13 = D in hex) (CHANGE HERE IF YOU WANT TO CALCULATE ANOTHER NUMBER)
	OR	r1,r3,r0	# transfer y register to accumulator
	ADD	r3,r3,-3	# handles the algorithm iteration counting

	LDI	r1,2		# a = 2
	STO	r1,4		# stores a

floop: 
	LDO	r2,4		# x = a
	ADD	r1,r1,r2	# a += x
	STO	r1,4		# stores a
	STO	r2,0		# stores x
	ADD	r3,r3,-1	# y -= 1
  BNE r3,r0,floop	# jumps back to loop if Z bit != 0 (y's decremention isn't zero yet)
  NOP
  NOP
  NOP
  NOP
  NOP
	NOP  
