.set txtscreen,0xFEC00000
.set rand,0xFEE1FD00

	.text
	.org 0x0000
ramtest:
	bra .0006
	ldi a0,0xfffc0000
	ldi a1,0xaaaaaaaaaaaaaaaa
	ldi a2,0x5555555555555555
	# write checkboard pattern to RAM
.0001:
	sto a1,[a0]
	sto a2,8[a0]
	add a0,a0,16
	bltu a0,0xfffd0000,.0001
	# read back pattern
	ldi a0,0xfffc0000
.0002:
	ldo a1,[a0]
	ldo a2,8[a0]
	add a0,a0,16
	xor a1,a1,a2
	add a1,a1,1
	bne a1,r0,.0003
	bltu a0,0xfffd0000,.0002
.0006:
	ldi a5,0x43FFFFE0003F002E
	# now write / read some random values
	ldi a0,0
	stt a0,rand+4										# select stream 0
	ldi a3,65536*4									# number of iterations
.0005:
	ldtu a0,rand
	stt a0,rand
	ldtu a1,rand
	stt a1,rand
	ldtu a2,rand
	stt a2,rand
	asl a2,a2,32
	or a1,a1,a2
	and a0,a0,0xfff8
	lsr a6,a3,4
	and a6,a6,0x3ff8
	sto a5,0xfec00000[a6]
	sto a1,0xfffc0000[a0]
	ldo a4,0xfffc0000[a0]
	bne a4,a1,.0003
	sub a3,a3,1
	bne a3,r0,.0005
	ldi t0,0x43FFFFE0003F0000+'P'		# white foreground, blue background
	sto t0,txtscreen
	ldi t0,0x43FFFFE0003F0000+'a'		# white foreground, blue background
	sto t0,txtscreen+8
	ldi t0,0x43FFFFE0003F0000+'s'		# white foreground, blue background
	sto t0,txtscreen+16
	ldi t0,0x43FFFFE0003F0000+'s'		# white foreground, blue background
	sto t0,txtscreen+24
	ret
.0004:
	bra .0004
.0003:	
	ldi t0,0x43FFFFE0003F0000+'F'		# white foreground, blue background
	sto t0,txtscreen
	ldi t0,0x43FFFFE0003F0000+'a'		# white foreground, blue background
	sto t0,txtscreen+8
	ldi t0,0x43FFFFE0003F0000+'i'		# white foreground, blue background
	sto t0,txtscreen+16
	ldi t0,0x43FFFFE0003F0000+'l'		# white foreground, blue background
	sto t0,txtscreen+24
	bra .0004

	.balign 0x1000,0xff
