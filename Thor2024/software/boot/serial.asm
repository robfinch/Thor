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
# Clear buffer indexes. Two bytes are used for the buffer index even though
# only a single byte is needed. This is for convenience in calculating the
# number of characters in the buffer, done later. The upper byte remains at
# zero.
# The port is initialized for 9600 baud, 1 stop bit and 8 bits data sent.
# The internal baud rate generator is used.
#
# Parameters:
#		none
# Modifies:
#		a0
# Returns:
#		none
#------------------------------------------------------------------------------

InitSerial:
SerialInit:
	stt		r0,SerHeadRcv
	stt		r0,SerTailRcv
	stt		r0,SerHeadXmit
	stt		r0,SerTailXmit
	stb		r0,SerRcvXon
	stb		r0,SerRcvXoff
#	lda		COREID
#sini1:
#	cmpa	IOFocusID
#	bne		sini1
#	orcc	#$290						; mask off interrupts
#	ldd		#ACIA_MMU				; map ACIA into address space
#	std		MMU
	ldi	a0,0x09					# dtr,rts active, rxint enabled (bit 1=0), no parity
	stt.io a0,ACIA_CMD
	ldi	a0,0x6001E			# baud 9600, 1 stop bit, 8 bit, internal baud gen
	stt.io a0,ACIA_CTRL		# disable fifos (bit zero, one), reset fifos
#	ldd		#$000F00				; map out ACIA
#	std		MMU
	ret

#------------------------------------------------------------------------------
# Calculate number of character in input buffer.
#
# Parameters:
#		none
# Returns:
#		a0 = number of bytes in buffer.
#------------------------------------------------------------------------------

SerialRcvCount:
	push a1,a2
	mov	a0,r0
	ldtu a1,SerTailRcv
	ldtu a2,SerHeadRcv
	sub	a0,a1,a2
	bge	a0,r0,.srcXit
	ldi	a0,0x1000
	ldtu a2,SerHeadRcv
	ldtu a1,SerTailRcv
	sub	a0,a0,a2
	add	a0,a0,a1
.srcXit:
	pop a1,a2
	ret

#------------------------------------------------------------------------------
# SerialGetChar
#
# Check the serial port buffer to see if there's a char available. If there's
# a char available then return it. If the buffer is almost empty then send an
# XON.
#
# Stack Space:
#		4 words
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
#		3 words
# Parameters:
#		none
# Modifies:
#		none
# Returns:
#		a0 = character or -1
#------------------------------------------------------------------------------

SerialPeekChar:
#	orcc	#$290							; mask off interrupts
	push a1
	atom 07777
	ldtu a0,SerHeadRcv			# check if anything is in buffer
	ldtu a1,SerTailRcv
	beq	a0,a1,.spcNoChars		# no?
	ldbu a0,SerRcvBuf[a0]		# get byte from buffer
	pop a1
	ret
.spcNoChars:
	ldi	a0,-1
	pop a1
	ret

#------------------------------------------------------------------------------
# SerialPeekChar
#		Get a character directly from the I/O port. This bypasses the input
# buffer.
#
# Stack Space:
#		3 words
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
	and	a0,a0,8					# look for Rx not empty
	beq	a0,r0,.spcd0001
	ldbu.io	a0,ACIA_RX
	ret
.spcd0001:
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
#		none
#------------------------------------------------------------------------------

SerialPutChar:
	push a0
.spc0001:
#	lda		COREID					; Ensure we have the IO Focus
#	cmpa	IOFocusID
#	bne		spc0001
	nop										# provide a window for an interrupt to occur
	nop
	# Between the status read and the transmit do not allow an
	# intervening interrupt.
	atom 0777
	ldtu.io a0,ACIA_STAT	# wait until the uart indicates tx empty
	bbc	a0,4,.spc0001			# branch if transmitter is not empty, bit #4 of the status reg
	stt.io a1,ACIA_TX			# send the byte
	pop a0
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
.sirqNxtByte:
	ldt.io a0,ACIA_STAT			# look for IRQs
	bgt	a0,r0,.notSerInt	# quick test for any irqs
	and	a0,a0,8						# check bit 3 = rx full (not empty)
	beq	a0,r0,.notRxInt1
	ldbu.io	a0,ACIA_RX				# get data from Rx buffer to clear interrupt
	ldtu a1,SerTailRcv			# check if recieve buffer full
	add	a1,a1,1
	and	a1,a1,0xfff
	ldtu a2,SerHeadRcv
	beq	a1,a2,.sirqRxFull
	stt	a1,SerTailRcv			# update tail pointer
	sub	a1,a1,1						# backup
	and	a1,a1,0xfff
	stb	a0,SerRcvBuf[a1]	# store recieved byte in buffer
	ldbu a0,SerRcvXoff			# check if xoff already sent
	bne	a0,r0,.sirqNxtByte
	bsr	SerialRcvCount		# if more than 4070 chars in buffer
	blt	a0,4070,.sirqNxtByte
	ldi	a0,XOFF						# send an XOFF
	stb	r0,SerRcvXon			# clear XON status
	stb	a0,SerRcvXoff			# set XOFF status
	stb.io a0,ACIA_TX
	bra	.sirqNxtByte     	# check the status for another byte
	# Process other serial IRQs
.notRxInt1:
.sirqRxFull:
.notRxInt:
.notSerInt:
	ret

#------------------------------------------------------------------------------
# Put a string to the serial port.
#
# Parameters:
#		a0 = pointer to string
# Modifies:
#		none
# Returns:
#		none
#------------------------------------------------------------------------------

SerialPutString:
	push lr1,a0,a1
.sps2:
	ldb	a1,[a0]
	add	a0,a0,1
	beq	a1,r0,.spsXit
	bsr	SerialPutChar
	bra	.sps2
.spsXit:
	pop lr1,a0,a1
	ret

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

SerialTest:
.0001:
	ldi a1,'A'
	bsr SerialPutChar
	bra .0001

#nmeSerial:
#	fcb		"Serial",0

.global SerialInit
.global SerialPutString
.global SerialTest
