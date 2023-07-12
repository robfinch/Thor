# ============================================================================
#        __
#   \\__/ o\    (C) 2022-2023  Robert Finch, Waterloo
#    \  __ /    All rights reserved.
#     \/_//     robfinch<remove>@finitron.ca
#       ||
#  
#
# Serial port routines for a WDC6551 compatible circuit.
#
# ============================================================================
#
	.extern Delay

	.bss
	.space	10
.set XON,0x11
.set XOFF,0x13
.set ACIA_RX,0xFED00000
.set ACIA_TX,0xFED00000
.set ACIA_STAT,0xFED00004
.set ACIA_CMD,0xFED00008
.set ACIA_CTRL,0xFED0000C
.set SerTailRcv,0xFFFC0000
.set SerHeadRcv,0xFFFC0004
.set SerTailXmit,0xFFFC0008
.set SerHeadXmit,0xFFFC000C
.set SerRcvXon,0xFFFC0010
.set SerRcvXoff,0xFFFC0011
.set SerRcvBuf,0xFFFC1000
.set uart,0xFED00000

	.text
#------------------------------------------------------------------------------
# Initialize serial port.
#
# Clear buffer indexes. Two bytes are used for the buffer index.
# The port is initialized for 57600 baud, 1 stop bit and 8 bits data sent.
# The internal baud rate generator is used.
#
# Stack Space:
#		none
# Parameters:
#		none
# Modifies:
#		mc0
# Returns:
#		none
#------------------------------------------------------------------------------

InitSerial:
SerialInit:
	stt	r0,SerHeadRcv
	stt	r0,SerTailRcv
	stt	r0,SerHeadXmit
	stt	r0,SerTailXmit
	stb	r0,SerRcvXon
	stb	r0,SerRcvXoff
	ldi	mc0,0x09						#	dtr,rts active, rxint enabled (bit 1=0), no parity
	stt mc0,ACIA_CMD
	ldi	mc0,0x6001E					# baud 9600, 1 stop bit, 8 bit, internal baud gen
	stt mc0,ACIA_CTRL		# disable fifos (bit zero, one), reset fifos
	ret
#	lda		COREID
#sini1:
#	cmpa	IOFocusID
#	bne		sini1
#	orcc	#$290						; mask off interrupts
#	ldd		#ACIA_MMU				; map ACIA into address space
#	std		MMU
	ldi	mc0,0x09						#	dtr,rts active, rxint enabled (bit 1=0), no parity
	stt mc0,ACIA_CMD
	ldi	mc0,0x6001E					# baud 9600, 1 stop bit, 8 bit, internal baud gen
#	ldi	mc0,0x08060011			# baud 57600, 1 stop bit, 8 bit, internal baud gen
	stt mc0,ACIA_CTRL		# disable fifos (bit zero, one), reset fifos
#	ldd		#$000F00				; map out ACIA
#	std		MMU
	ret

#------------------------------------------------------------------------------
# Calculate number of character in input buffer. Must be called with interrupts
# disabled.
#
# Stack Space:
#		none
# Parameters:
#		none
# Modifies:
#		mc0,mc1
# Returns:
#		a0 = number of bytes in buffer.
#------------------------------------------------------------------------------

SerialRcvCount:
	mov	a0,r0
	ldtu mc0,SerTailRcv
	ldtu mc1,SerHeadRcv
	sub	a0,mc0,mc1
	bge	a0,r0,.srcXit
	ldi	a0,0x1000
	ldtu mc1,SerHeadRcv
	ldtu mc0,SerTailRcv
	sub	a0,a0,mc1
	add	a0,a0,mc0
.srcXit:
	ret

#------------------------------------------------------------------------------
# SerialGetChar
#
# Check the serial port buffer to see if there's a char available. If there's
# a char available then return it. If the buffer is almost empty then send an
# XON.
#
# Stack Space:
#		3 words
# Parameters:
#		none
# Modifies:
#		none
# Returns:
#		a0 = character or -1
#------------------------------------------------------------------------------

SerialGetChar:
	push lr1,a1,a2
	ldi	a0,8							# bit 3=machine interrupt enable, mask off interrupts
	csrrc	a2,a0,0x3004		# status reg
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bsr	SerialRcvCount			# check number of chars in receive buffer
	bgt	a0,8,.sgc2
	ldb	a0,SerRcvXon			# skip sending XON if already sent
	bnez a0,.sgc2        	# XON already sent?
	ldi	a0,XON						# if <8 send an XON
	stb	r0,SerRcvXoff			# clear XOFF status
	stb	a0,SerRcvXon			# flag so we don't send it multiple times
	bsr	SerialPutChar
.sgc2:
	ldtu a0,SerHeadRcv		# check if anything is in buffer
	ldtu a1,SerTailRcv
	beq	a0,a1,.sgcNoChars
	mov	a1,a0
	ldbu a0,SerRcvBuf[a1]	# get byte from buffer
	add	a1,a1,1
	and	a1,a1,0xfff				# 4k wrap around
	stt	a1,SerHeadRcv
	csrrw	r0,a2,0x3004		# restore interrupts
	pop lr1,a1,a2
	ret
.sgcNoChars:
	ldi	a0,-1							#-1
	csrrw	r0,a2,0x3004		# restore interrupts
	pop lr1,a1,a2
	ret

#------------------------------------------------------------------------------
# SerialPeekChar
#
# Check the serial port buffer to see if there's a char available. If there's
# a char available then return it. But don't update the buffer indexes. No need
# to send an XON here.
#
# Stack Space:
#		none
# Parameters:
#		none
# Modifies:
#		mc0
# Returns:
#		a0 = character or -1
#------------------------------------------------------------------------------

SerialPeekChar:
	atom 077777							# temporarily mask interrupts
	ldtu a0,SerHeadRcv			# check if anything is in buffer
	ldtu mc0,SerTailRcv
	beq	a0,mc0,.spcNoChars		# no?
	ldbu a0,SerRcvBuf[a0]		# get byte from buffer
	ret
.spcNoChars:
	ldi	a0,-1
	ret

#------------------------------------------------------------------------------
# SerialPeekChar
#		Get a character directly from the I/O port. This bypasses the input
# buffer.
#
# Stack Space:
#		none
# Parameters:
#		none
# Modifies:
#		a0
# Returns:
#		a0 = character or -1
#------------------------------------------------------------------------------

SerialPeekCharDirect:
#	lda		COREID					; Ensure we have the IO Focus
#	cmpa	IOFocusID
#	bne		spcd0001
# Disallow interrupts between status read and rx read.
#	orcc	#$290						; mask off interrupts
	atom 077777
	ldbu.io	a0,ACIA_STAT
	bbc	a0,3,.0001				# look for Rx not empty
	ldbu.io	a0,ACIA_RX
	ret
.0001:
	ldi	a0,-1
	ret

#------------------------------------------------------------------------------
# SerialPutChar
#    Put a character to the serial transmitter. This routine blocks until the
# transmitter is empty. 
#
# Stack Space
#		1 words
# Parameters:
#		a1 = character to put
# Modifies:
#		mc0
#------------------------------------------------------------------------------

SerialPutChar:
.0001:
#	lda		COREID					; Ensure we have the IO Focus
#	cmpa	IOFocusID
#	bne		spc0001
	nop										# provide a window for an interrupt to occur
	nop
	# Between the status read and the transmit do not allow an
	# intervening interrupt.
	atom 0777
	ldtu.io mc0,ACIA_STAT	# wait until the uart indicates tx empty
	bbc	mc0,4,.0001				# branch if transmitter is not empty, bit #4 of the status reg
	stt.io a1,ACIA_TX			# send the byte
	ret

#------------------------------------------------------------------------------
# Serial IRQ routine
#
# Keeps looping as long as it finds characters in the ACIA recieve buffer/fifo.
# Received characters are buffered. If the buffer becomes full, new characters
# will be lost.
#
# Stack Space:
#		1 word
# Parameters:
#		none
# Modifies:
#		d,x
# Returns:
#		none
#------------------------------------------------------------------------------

SerialIRQ:
#	lda		$2000+$D3				; Serial active interrupt flag
#	beq		notSerInt
.0002:
	ldt.io a0,ACIA_STAT		# look for IRQs
	bgt	a0,r0,.0001				# quick test for any irqs
	bbc	a0,3,.0001				# check bit 3 = rx full (not empty)
	ldbu.io	a0,ACIA_RX		# get data from Rx buffer to clear interrupt
	ldtu a1,SerTailRcv		# check if recieve buffer full
	add	a1,a1,1
	and	a1,a1,0xfff				# 4k Limit
	ldtu a2,SerHeadRcv
	beq	a1,a2,.0001				# ignore byte if buffer full
	stt	a1,SerTailRcv			# update tail pointer
	sub	a1,a1,1						# backup
	and	a1,a1,0xfff
	stb	a0,SerRcvBuf[a1]	# store recieved byte in buffer
	ldbu a0,SerRcvXoff		# check if xoff already sent
	bne	a0,r0,.0002
	bsr	SerialRcvCount		# if more than 4070 chars in buffer
	blt	a0,4070,.0002
	ldi	a0,XOFF						# send an XOFF
	stb	r0,SerRcvXon			# clear XON status
	stb	a0,SerRcvXoff			# set XOFF status
	stb.io a0,ACIA_TX
	bra	.0002     				# check the status for another byte
	# Process other serial IRQs
.0001:
	ret

#------------------------------------------------------------------------------
# Put a string to the serial port.
#
# Stack Space:
#		none
# Parameters:
#		a0 = pointer to string
# Modifies:
#		mc0,mc1,mc2,mc3
# Returns:
#		none
#------------------------------------------------------------------------------

SerialPutString:
	mov mc1,a0
	mov mc2,a1
.0002:
	ldb a1,[a0]
	beq	a1,r0,.0003				# NULL terminator encountered?
	add	a0,a0,1
	# inline serial putchar, avoid stacks pushes and pops
.0001:
	nop										# provide a window for an interrupt to occur
	nop
	nop
	# Between the status read and the transmit do not allow an
	# intervening interrupt.
	atom 0777
	ldtu mc0,ACIA_STAT		# wait until the uart indicates tx empty
	bbc	mc0,4,.0001				# branch if transmitter is not empty, bit #4 of the status reg
	stt a1,ACIA_TX				# send the byte
	bra	.0002
.0003:
	mov a0,mc1
	mov a1,mc2
	ret

#------------------------------------------------------------------------------
# Put a buffer to the serial port.
#
# Stack Space:
#		none
# Parameters:
#		a0 = pointer to buffer
#		a1 = number of bytes
# Modifies:
#		mc0,mc1,mc2,mc3
# Returns:
#		none
#------------------------------------------------------------------------------

SerialPutBuf:
	mov mc1,a0
	mov mc2,a1
.0002:
	ble a1,r0,.0003				# end of buffer reached?
	sub a1,a1,1
	ldb mc3,[a0]
	add	a0,a0,1
	# inline serial putchar, avoid stacks pushes and pops
.0001:
	nop										# provide a window for an interrupt to occur
	nop
	# Between the status read and the transmit do not allow an
	# intervening interrupt.
	atom 0777
	ldtu mc0,ACIA_STAT		# wait until the uart indicates tx empty
	bbc	mc0,4,.0001				# branch if transmitter is not empty, bit #4 of the status reg
	stt mc3,ACIA_TX				# send the byte
	bra	.0002
.0003:
	mov a0,mc1
	mov a1,mc2
	ret

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

SerialTest:
.0001:
	ldi a1,'A'
	bsr SerialPutChar
	bra .0001

#------------------------------------------------------------------------------
# Get a buffer from the serial port.
#
# Stack Space:
#		none
# Parameters:
#		a0 = pointer to buffer
#		a1 = number of bytes
# Modifies:
#		mc0,mc1,mc2,mc3,t0
# Returns:
#		none
#------------------------------------------------------------------------------

SerialGetBufDirect:
	mov mc1,a0						# preserve a0,a1
	mov mc2,a1
	ldi mc3,0
.0001:
	nop										# interrupt ramp
	nop
	nop
	atom 07777						# no interrupts for 4 instructions
	ldtu mc0,ACIA_STAT		# check the status
	bbc	mc0,3,.0001				# look for Rx not empty
	ldtu mc0,ACIA_RX			# grab the char from the port
	stb mc0,[a0]					# store in buffer
	ror t0,mc0,4
	and t0,t0,15
	add t0,t0,'0'
	ble t0,'9',.0002
	add t0,t0,7
.0002:
	or t0,t0,0x43FFFFE0003F0000
	sto t0,txtscreen[mc3]
	add mc3,mc3,8
	mov t0,mc0
	and t0,t0,15
	add t0,t0,'0'
	ble t0,'9',.0003
	add t0,t0,7
.0003:
	or t0,t0,0x43FFFFE0003F0000
	sto t0,txtscreen[mc3]
	add mc3,mc3,8
	ldi t0,0x43FFFFE0003F0020
	sto t0,txtscreen[mc3]
	add mc3,mc3,8
	add a0,a0,1						# increment buffer pointer
	sub a1,a1,1						# and decrement buffer count
	bne a1,r0,.0001				# go back for another character
	mov a0,mc1
	mov a1,mc2
	jmp [a0]
	ret

	.rodata
nmeSerial:
	.byte "Serial",0

.global SerialInit
.global SerialPutString
.global SerialPutBuf
.global SerialTest
