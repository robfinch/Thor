# boot.asm Thor2024 assembly language

	.bss
	.space	10
.set ary,0xFFFC0000
.set txtscreen,0xFEC00000
.set leds,0xFEDFFF00
.set keybd,0xFEDCFE00
.set rand,0xFEE1FD00
.set CTRLH,8
.set CTRLX,24

.set CursorRow,0xFFFC0400
.set CursorCol,0xFFFC0401
.set TextRows,0xFFFC0402
.set TextCols,0xFFFC0403
.set TextCurpos,0xFFFC0404
.set TextScr,0xFFFC0408
.set TextAttr,0xFFFC0410

.set mon_r1,0xFFFC0430
.set mon_r2,0xFFFC0440

.extern	SerialInit
.extern SerialPutString
.extern SerialTest

	.data
	.space	10
	.sdreg 60

#	.org	0xFFFFFFFFFFFD0000
	.text
#	.align	0
start:
	ldi t0,-1
	stt t0,leds
	stt r0,rand+4								# select stream 0
	ldi a0,0x99999999						# set random seed
	asl a0,a0,3
	stt a0,rand+8
	stt a0,rand+12
	ldt a0,rand
	stt a0,rand
	ldi a3,0xfffc0000
#	stt r0,rand+4								# select stream 0
#	bsr Delay3s	
#	bsr ramtest
	bsr Delay3s	
	bsr SerialInit
	bsr Delay3s	
#	bsr SerialTest
	ldi a0,0xfffde000
	ldi a1,4096
	bsr SerialGetBufDirect
	nop
	nop
	jsr 0xfffde000
	jsr 0xfffde000
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bsr Delay3s	
	bsr Delay3s	
	ldi t0,ExcHandler
	csrrw r0,t0,0x3033					# set kernel exception vector
	ldi	t0,txtscreen
	stt t0,TextScr
	ldi t0,0x43FFFFE0003F0000		# white foreground, blue background
	sto t0,TextAttr
	ldi t0,32
	stb t0,TextRows
	ldi t0,64
	stb t0,TextCols
	
	bsr	Delay3s
	ldi gp,0xffff0000
	lda a0,msgStart[gp]
	bsr	SerialPutString
#	bsr SerialTest
	bsr HomeCursor
	bsr ClearScreen
	lda a0,msgStart[gp]
	bsr DisplayString

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
	ldi	a0,10000000
Delay:
.0001:
	lsr	a1,a0,17
	stt a1,leds
	sub	a0,a0,1
	bgt	a0,r0,.0001	
doRet:
	ret

#------------------------------------------------------------------------------
# clearscreen
# Parameters:
# 	none
# Modifies:
#		mc0,mc1,mc2
# Stack space:
#		none
#------------------------------------------------------------------------------

ClearScreen:
	ldo mc0,TextAttr
	add mc0,mc0,' '
#	ldtu mc1,TextScr
	ldi mc1,txtscreen
	add mc2,mc1,64*8*32						# 64x32x8
.0001:
	sto mc0,[mc1]
	add mc1,mc1,8
	bltu mc1,mc2,.0001
	ret

#------------------------------------------------------------------------------
# Calculate screen memory location from CursorRow,CursorCol.
# Returns:
#		a0 = screen location
# Stack space:
#		1 word
#------------------------------------------------------------------------------

CalcScreenLoc:
	ldb	a0,CursorRow			# cursor row
	and a0,a0,0x7f
	ldb mc0,TextCols			# times number of columns
	mul a0,a0,mc0
	ldb mc0,CursorCol			# plus cursor col
	and mc0,mc0,0x7f
	add a0,a0,mc0
	stw a0,TextCurpos			# update text position
	asl a0,a0,3						# multiply by text cell size
	ldtu mc0,TextScr			# add in text screen location
	add a0,a0,txtscreen	#mc0
	ret

#------------------------------------------------------------------------------
# Display a character on the screen
#
# Parameters:
# 	a1 = char to display
# Modifies:
#		screen and text cursor position updated
#------------------------------------------------------------------------------

DisplayChar:
	push lr1
	bne a1,'\r',.0010				# carriage return?
	stb r0,CursorCol				# just set cursor column to zero on a CR
	bsr SyncCursor
	pop lr1
	ret
.0010:
	push a0,a1,a2,a3
	and a1,a1,0xff					# make char unsigned
	bne a1,0x91,.0005				# cursor right?
	# Cursor right
	ldb a0,CursorCol				# Is rightmost column reached?
	ldb a2,TextCols
	sub a2,a2,1
	bge a0,a2,.0001
	add	a0,a0,1							# not rightmost, add 1 to column
	stb a0,CursorCol
.0002:
	bsr SyncCursor
.0001:
	pop a0,a1,a2,a3
	pop lr1
	ret
.0005:
	bne a1,0x90,.0006
	# Cursor up
	ldb a0,CursorRow				# can the cursor move up?
	beq a0,r0,.0001
	sub a0,a0,1
	stb a0,CursorRow
	bra .0002
.0006:
	bne a1,0x93,.0007
	# Cursor left
	ldb a0,CursorCol				# can the cursor move left?
	beq a0,r0,.0001	
	sub a0,a0,1
	stb a0,CursorCol
	bra .0002
.0007:
	bne a1,0x92,.0008
	# Cursor down
	ldb a0,CursorRow				# can cursor move down?
	ldb a2,TextRows
	sub a2,a2,1
	bge a0,a2,.0001
	add a0,a0,1
	stb a0,CursorRow
	bra .0002
.0008:										# home cursor
	bne a1,0x94,.0011
	# Home cursor
	ldb a0,CursorCol
	beq a0,r0,.0003
	stb r0,CursorCol
	bra .0002
.0003:
	stb r0,CursorRow
	bra .0002
.0011:
	beq a1,0x99,doDelete
	beq a1,CTRLH,doBackspace
	beq a1,CTRLX,doCtrlX
	beq a1,'\n',.0012				# line feed
	# Regular char
	bsr CalcScreenLoc				# a0 = screen location
	ldo a2,TextAttr
	or a2,a2,a1
	sto a2,[a0]
	bsr IncCursorPos
.0004:
	bsr SyncCursor
	pop a0,a1,a2,a3
	pop lr1
	ret
.0012:										# line feed
	bsr IncCursorRow
	bra .0004
			
	#---------------------------
	# CTRL-H: backspace
	#---------------------------
doBackspace:
	ldb a0,CursorCol				# At start of line already?
	bne a0,a0,.0001
	pop a0,a1,a2,a3
	pop lr1
	ret
.0001:
	sub a0,a0,1							#decrement column
	stb a0,CursorCol

	#---------------------------
	# Delete key
	#---------------------------
doDelete:
	bsr	CalcScreenLoc				# a0 = screen location
	ldb a2,CursorCol
	ldb a3,TextCols
.0001:
	ldo a1,8[a0]
	sto.io a1,[a0]
	add a0,a0,8
	add a2,a2,1
	blt a2,a3,.0001
	ldi a1,' '							# one space
	stb.io a1,-8[a0]				# terminate line with space char
	pop a0,a1,a2,a3
	pop lr1
	ret

	#---------------------------
	# CTRL-X: erase line
	#---------------------------
doCtrlX:
	stb r0,CursorCol			# Reset cursor to start of line
	ldb a0,TextCols				# and display TextCols number of spaces
	ldi	a1,' '						# one space
.0001:
	# DisplayChar is called recursively here
	# It's safe to do because we know it won't recurse again due to the
	# fact we know the character being displayed is a space char
	bsr DisplayChar
	sub a0,a0,1
	bge a0,r0,.0001
	stb r0,CursorCol			# Reset cursor to start of line
	pop a0,a1,a2,a3
	pop lr1
	ret										# we're done

#------------------------------------------------------------------------------
# Increment the cursor position, scroll the screen if needed.
#------------------------------------------------------------------------------
#
IncCursorPos:
	push a0,a1
	ldb a0,CursorCol
	add a0,a0,1
	stb a0,CursorCol
	ldb a0,TextCols
	ldb a1,CursorCol
	blt a1,a0,IncCursorPos1	# return if text cols not exceeded
	stb r0,CursorCol
	pop a0,a1
IncCursorRow:
	nop
	nop
	push a0,a1
	ldb a0,CursorRow
	add a0,a0,1
	stb a0,CursorRow
	ldb a1,TextRows
	blt a0,a1,IncCursorPos1	# return if text rows not exceeded
	sub a1,a1,1
	stb a1,CursorRow
	push lr1
	bsr CalcScreenLoc
	bsr ScrollUp
	pop lr1
IncCursorPos1:
	pop	a0,a1
	ret

#------------------------------------------------------------------------------
# Scroll text screen
#------------------------------------------------------------------------------

ScrollUp:
	push lr1,t0
	push a0,a1,a2,a3
	ldt a0,TextScr				# a0 = pointer to screen
	ldb a1,TextCols				# a1 = number of columns
	ldb a2,TextRows
	sub a2,a2,1
	mul a2,a1,a2					# a2 = number of cells to move
	mov a3,a1
.0001:
	ldo t0,[a0+a3]
	sub a3,a3,a1
	sto.io t0,[a0+a3]
	add a3,a3,a1
	add a3,a3,a1
	sub a2,a2,1
	bgt a2,r0,.0001
	bsr BlankLastLine
	pop a0,a1,a2,a3
	pop lr1,t0
	ret

#------------------------------------------------------------------------------
# Blank out the last line of the screen.
#------------------------------------------------------------------------------

BlankLastLine:
	ldt mc0,TextScr
	ldb mc1,TextCols
	ldb mc2,TextRows
	sub mc2,mc2,1
	mul mc1,mc1,mc2
	asl mc1,mc1,3
	ldi mc3,' '
	ldb mc2,TextCols
.0001:
	stb.io mc3,[mc0+mc1]
	add mc1,mc1,8
	sub mc2,mc2,1
	bgt mc2,r0,.0001
	ret	

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

HomeCursor:
	stb r0,CursorRow
	stb r0,CursorCol
	stw r0,TextCurpos

#------------------------------------------------------------------------------
# SyncCursor:
#
# Sync the hardware cursor's position to the text cursor position.
#
# Parameters:
#		none
# Returns:
#		none
# Registers Affected:
#		mc0
#------------------------------------------------------------------------------

SyncCursor:
	ldw mc0,TextCurpos
	stw mc0,0xfec80024
	ret
	
#------------------------------------------------------------------------------
# Display string on screen
#
# Parameters:
# 	a0 = pointer to string to display
# Returns:
#		<none>
# Modifies:
#		<none>
#------------------------------------------------------------------------------

DisplayString:
	push lr1,a0,a1
.0002:
	ldb.io a1,[a0]
	beq a1,r0,.0001
	bsr DisplayChar
	add a0,a0,1
	bra .0002
.0001:
	pop lr1,a0,a1
	ret

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
CRLF:
	push a1
	ldi a1,'\r'
	bsr DisplayChar
	ldi a1,'\n'
	bsr DisplayChar
	pop a1
	ret

#------------------------------------------------------------------------------
# Display nybble in a1
#------------------------------------------------------------------------------

DisplayNybble:
	push a1,lr1
	and a1,a1,15
	add a1,a1,'0'
	ble a1,'9',.0001
	add a1,a1,7
.0001:
	bsr DisplayChar
	pop a1,lr1
	ret

#------------------------------------------------------------------------------
# Display the byte in a1
#------------------------------------------------------------------------------

DisplayByte:
	push lr1
	ror a1,a1,4
	bsr DisplayNybble
	rol a1,a1,4
	bsr DisplayNybble
	pop lr1
	ret

#------------------------------------------------------------------------------
# Display the wyde in a0.B
#------------------------------------------------------------------------------

DisplayWyde:
	push lr1
	ror a1,a1,8
	bsr DisplayByte
	rol a1,a1,8
	bsr DisplayByte
	pop lr1
	ret

#------------------------------------------------------------------------------
# Display the tetra in a1
#------------------------------------------------------------------------------

DisplayTetra:
	push lr1
	ror a1,a1,16
	bsr DisplayWyde
	rol a1,a1,16
	bsr DisplayWyde
	pop lr1
	ret

#------------------------------------------------------------------------------
# Display the octa in a1
#------------------------------------------------------------------------------

DisplayOcta:
	push lr1
	ror a1,a1,32
	bsr DisplayTetra
	rol a1,a1,32
	bsr DisplayTetra
	pop lr1
	ret

GetNumber:
	ret

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
	.align 4
ExcHandler:
	rti

	.include "serial.asm"
	.include "xmodem.asm"
	.include "keyboard.asm"
	.include "Monitor.asm"
#	.include "ramtest.asm"

	.balign	0x100,0xff
	
	.rodata
msgStart:
	.byte "Thor2024 System Starting.",0

	.org 0xffe0
	# initial machine stack pointer
	.8byte	0xFFFFFFFFFFFCFFF0
	.8byte	0xFFFFFFFFFFFFFFFF
	# initial program counter
	.8byte	0xFFFFFFFFD0000000
	.8byte	0xFFFFFFFFFFFFFFFF

	.global Delay3s
	.global Delay
