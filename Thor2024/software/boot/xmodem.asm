# ============================================================================
#        __
#   \\__/ o\    (C) 2022-2023  Robert Finch, Waterloo
#    \  __ /    All rights reserved.
#     \/_//     robfinch<remove>@opencores.org
#       ||
#  
#
# BSD 3-Clause License
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#                                                                          
# ============================================================================

	.extern Delay3s
#
# Xmodem variables
#
.set SOH,1
.set EOT,4
.set ACK,6
.set LF,10
.set CR,13
.set NAK,21
.set ETB,23			# end of transfer block
.set CAN,24
.set xm_timer,0xFFFC0020
.set xm_protocol,0xFFFC0028
.set xm_flag,0xFFFC0029
.set xm_checksum,0xFFFC0030
.set xm_tmp2,0xFFFC0040
.set xm_tmp,0xFFFC0048
.set xm_packetnum,0xFFFC0050
.set xm_crc,0xFFFC0058
.set xm_ibuf,0xFFFC0080
.set xm_obuf,0xFFFC0100

# ------------------------------------------------------------------------------
# Send data using XModem.
# ------------------------------------------------------------------------------

xm_SendStart:
	bsr	GetRange
	ldx		mon_r1+2				; x = buffer address
	tfr		x,u
	ldi		t0,1						# packet numbers start at one
	sto		t0,xm_packetnum+1
	# Wait for receiver to send a NAK
xm_send:							
	bsr SerialGetChar			# select blocking input
	beq a0,NAK,xm_send5		# should have got a NAK
	bne a0,'C',xm_send		# or a 'C'
xm_send5:
	stb	a0,xm_protocol
xm_send4:
	ldi a0,SOH
	bsr SerialPutChar			# send start
	ldb a0,xm_packetnum+1	# send packet number
	bsr SerialPutChar
	xor a0,a0,-1					# one's complement
	bsr SerialPutChar
	ldi a1,0							# a1 = byte count
	tfr		x,u							; u = buffer address
xm_send1:
	ldb a0,[a2]						# grab a byte from the buffer
	add a2,a2,1
	bsr SerialPutChar			# send it out
	add a1,a1,1
	blt a1,128,xm_send1		# number of bytes in payload
	ldb a0,xm_protocol
	bne a0,'C',xm_send2		# CRC protocol?
	bsr	xm_calc_crc				# compute CRC
	ldw a0,xm_crc					# get crc
	ror a0,a0,8						# transfer high eight bits first, so
	bsr SerialPutChar
	rol a0,a0,8
	bsr SerialPutChar			# and send out low byte
	bra	xm_send3
xm_send2:
	bsr	xm_calc_checksum
	ldb a0,xm_checksum
	bsr SerialPutChar
xm_send3:
	bsr SerialGetChar			# block until input is present
	bne a0,ACK,xm_send4		# not an ACK then resend the record
	ldo a0,xm_packetnum		# increment packet number
	add a0,a0,1
	sto a0,xm_packetnum
	add a2,a2,128					# advance buffer pointer
	cmpx	mon_r2+2
	blo		xm_send4				; go send next record
	ldi a0,EOT
	bsr SerialPutChar			# send end of transmission
	bsr SerialPutChar			# send end of transmission
	bsr SerialPutChar			# send end of transmission
	ret

# ------------------------------------------------------------------------------
# Get a byte, checking for a receive timeout.
#
# Returns:
#		accb = byte (0 to 255) or -1 if timed out
# ------------------------------------------------------------------------------

xm_getbyte:
	push a1
xm_gb1:
	ldo a1,xm_timer
	bgt a1,2047,xm_gb2	# check the timeout - 2048 ticks (3 seconds approx.)
	bsr SerialPeekChar	# non-blocking, try and get a character
	blt a0,r0,xm_gb1		# if no character, try again
	bsr	xm_outbyteAsHex
	pop a1
	ret
xm_gb2:
	ldi	a0,-1
	pop a1
	ret

# ------------------------------------------------------------------------------
# XModem Receive
#
# Parameters:
#		none
# Modifies:
#		All
#	Returns:
#		none
# ------------------------------------------------------------------------------

xm_ReceiveStart:
	ldi gp,0xffff0000
	bsr	Delay3s				# give a little bit of time for sender
	bsr	Delay3s
	bsr	Delay3s
	bsr	GetNumber			# Get the transfer address
	tstb							# Make sure we got a value
	lbeq Monitor
	ldx	mon_numwka+2	; X = transfer address
	sto	r0,xm_packetnum	# initialize
	ldi	a0,#'C'				# try for CRC first
	stb	a0,xm_protocol
xm_receive:
	ldi	a1,2					# number of times to retry -1
xm_rcv5:
	ldb	a0,xm_protocol	# indicate we want a transfer (send protocol byte)
	bsr SerialPutChar
xm_rcv4:
	sto r0,xm_timer		# clear the timeout
xm_rcv1:
	bsr	xm_getbyte
	blt a0,r0,xm_retry1	# timeout on protocol id?
	beq a0,SOH,xm_SOH	# it should be start of a transfer
	beq a0,EOT,xm_EOT	# or end of transfer (EOT)
	beq a0,CAN,xm_receive	# might be a cancel
	beq a0,ETB,xm_EOT
xm_rcv_nak:					# wasn't a valid start so
	ldi a0,NAK				# send a NAK
	bsr SerialPutChar	# and try again
	bra	xm_rcv4
xm_SOH:
	bsr	xm_getbyte		# get packet number
	blt a0,r0,xm_rcv_to1
	stb a0,xm_packetnum
	mov a2,a0					# save it
	bsr	xm_getbyte		# get complement of packet number
	blt a0,r0,xm_rcv_to2
	add a0,a0,a2			# add the two values
	and a0,a0,0xff		# the sum should be $FF
	sub a0,a0,0xff
	stb	a0,xm_flag		# should be storing a zero if there is no error
	ldi a2,0					# a2 = payload byte counter
	tfr		x,u
xm_rcv2:
	bsr	xm_getbyte
	blt a0,r0,xm_rcv_to1
	stb a0,[a3]				# store the byte to memory
	add a3,a3,1
	add a2,a2,1
	blt a2,128,xm_rcv3	# 128 bytes per payload
	bsr	xm_getbyte		# get checksum or CRC byte
	blt a0,r0,xm_rcv_to1
	stb	a0,xm_tmp			# stuff checksum/CRC byte
	ldb	a0,xm_protocol
	bne a0,'C',xm_rcv_chksum
	bsr	xm_getbyte		# get low order CRC byte
	blt a0,r0,xm_rcv_to1
	ldb a1,xm_tmp			# get the high byte
	and a0,a0,0xff
	asl a1,a1,8
	or a0,a0,a1				# combine high and low byte
	stw a0,xm_tmp2
	bsr	xm_calc_crc		# compute the CRC-16 for the received data
	ldw	a0,xm_crc			# and compare to received value
	ldw a1,xm_tmp2
	bra	xm_rcv3
xm_rcv_chksum:
	bsr	xm_calc_checksum
	ldb	a0,xm_checksum
	ldb a1,xm_tmp			# where we stuffed the byte
xm_rcv3:
	bne a0,a1,xm_rcv_nak	# if not the same, NAK
	ldb a0,xm_flag
	bne	a0,r0,xm_rcv_nak	# bad packet number?
	ldi a0,ACK				# packet recieved okay, send back an ACK
	bsr SerialPutChar
	ldb a0,xm_packetnum+1	# did we receive the same packet
	ldb a1,xm_packetnum
	beq	a0,a1,xm_rcv4		# same packet received, dont update buffer pointer
	stb	a0,xm_packetnum	# update last seen packet number
	add a3,a3,128				# increment buffer pointer
	bra	xm_rcv4					# and go back for next packet
xm_rcv_to2:
xm_rcv_to1:
	lda a0,msgXmTimeout[gp]
	bsr DisplayString
	bra	Monitor
xm_EOT:								# end of transmission received, return
	ldi a0,ACK
	bsr SerialPutChar		# ACK the EOT
	bra	Monitor
xm_retry1:
	sub a1,a1,1
	bgt a1,r0,xm_rcv5
	ldb a0,xm_protocol	# are we already lowered down to checksum protocol?
	beq a0,NAK,xm_noTransmitter		# did we try both checksum and CRC?
	ldi a0,NAK
	stb	a0,xm_protocol
	bra xm_receive
xm_noTransmitter:
	lda a0,msgXmNoTransmitter
	bsr DisplayString
	bra	Monitor	

	.rodata
msgXmTimeout:
	.byte "Xmodem: timed out",CR,LF,0
msgXmNoTransmitter:
	.byte "XModem: transmitter not responding",CR,LF,0

	.text
# ------------------------------------------------------------------------------
# Calculate checksum value. The checksum is simply the low order eight bits of
# the sum of all the bytes in the payload area.
#
# Stack space:
#		two words
#	Modifies:
#		xm_checksum		contains the checksum value for the record
# Parameters:
#		a0 = buffer address
#	Returns:
#		none
# ------------------------------------------------------------------------------

xm_calc_checksum:
	push a1,a2,a3
	ldi a1,0
	ldi a3,0
xm_cs1:
	ldb a2,[a0+a3]
	add a3,a3,1
	add a1,a1,a2
	blt a3,128,xm_cs1
	and a1,a1,0xff
	stb	a1,xm_checksum
	mov a0,a1
	pop a1,a2,a3
	ret

# ------------------------------------------------------------------------------
# Compute CRC-16 of buffer.
#
#int calcrc(char *ptr, int count)
#{
#    int  crc;
#    char i;
#    crc = 0;
#    while (--count >= 0)
#    {
#        crc = crc ^ (int) (*ptr++ << 8);
#        i = 8;
#        do
#        {
#            if (crc & 0x8000)
#                crc = crc << 1 ^ 0x1021;
#            else
#                crc = crc << 1;
#        } while(--i);
#    }
#    return (crc);
#}
#
# Modifies:
#		xm_crc variable
# Parameters:
#		a0 = buffer address
# Returns:
#		a0 = crc
# ------------------------------------------------------------------------------

xm_calc_crc:
	push a1,a2,a3,a4
	push a5
	mov a2,r0					# crc = 0
	ldi	a5,0					# a5 = byte count
xm_crc1:
	ldbu a3,[a0+a5]		# get byte
	asl a3,a3,8
	xor a2,a3,a2			# crc = crc ^ tmp
	ldi a1,0
xm_crc4:
	and a4,a2,0x8000	# check for $8000
	beq	a4,r0,xm_crc2	# no? then just go shift
	asl a2,a2,1
	xor a2,a2,0x1021	# and xor
	bra	xm_crc3
xm_crc2:
	asl a2,a2,1
xm_crc3:
	add a1,a1,1
	blt a1,8,xm_crc4	# repeat eight times
	add a5,a5,1				# increment byte count
	blt a5,128,xm_crc1
	and a0,a2,0xffff	# we want only a 16-bit CRC
	stw a0,xm_crc
	pop a5
	pop a1,a2,a3,a4
	ret

#xm_outbyteAsHex:
#	pshs	d
#	ldd		CharOutVec						; get current char out vector
#	pshs	d											; save it
#	ldd		#ScreenDisplayChar		; set output vector to screen display
#	std		CharOUtVec
#	ldd		2,s										; get passed data
#	lbsr	DispByteAsHex					; and display on-screen
#	ldb		#' '
#	lbsr	ScreenDisplayChar
#	puls	d											; get back old char out vector
#	std		CharOutVec						; and restore it
#	puls	d											; restore input arguments
#	rts

	