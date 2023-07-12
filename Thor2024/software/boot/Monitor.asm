	.set CmdBuf,0xFFFC0480
	.set CmdBufEnd,0xFFFC0500
	.text
#==============================================================================
#==============================================================================
# Monitor
#
# Register Usage
#		t0 = text pointer
#==============================================================================
#==============================================================================

StartMon:
Monitor:
	ldi sp,0xFFFCFFF0	# reset stack
	ldi gp,0xFFFF0000	# and global pointer
	stb r0,_KeybdEcho	# turn off keyboard echo
PromptLn:
	bsr	CRLF
	ldi a1,'$'
	bsr	DisplayChar

# Get characters until a CR is keyed

Prompt3:
	bsr	GetKey
	beq a1,CR,Prompt1
	bsr	DisplayChar
	bra	Prompt3

# Process the screen line that the CR was keyed on

Prompt1:
	stb r0,CursorCol		# go back to the start of the line
	bsr	CalcScreenLoc		# a0 = screen memory location
	mov t0,a0
	ldb a1,[t0]
	add t0,t0,1
	bne a1,'$',Prompt2	# skip over '$' prompt character
	ldb a1,[t0]
	add t0,t0,1
	
# Dispatch based on command character

Prompt2:
	bne a1,'x',.0001
	ldb a1,[t0]
	add t0,t0,1
	bne a1,'r',.0002		# 'r' - receive
	bsr	GetHexNumber				# Get the transfer address
	beq a0,r0,Monitor		# Make sure we got a value
	mov a0,a1
	bsr xm_ReceiveStart
	bra Monitor
.0002:
	bne a1,'s',Monitor	# 's' - send
	bsr GetRange
	bsr xm_SendStart
	bra Monitor
.0001:
	beq a1,':',EditMem
	beq a1,'d',DumpMem
	beq a1,'f',FillMem
	beq a1,'l',LoadS19
	beq a1,'j',ExecuteCode
	beq a1,'?',DisplayHelp
	beq a1,'c',TestCLS
	bra Monitor

TestCLS:
	ldb a1,[t0]
	add t0,t0,1
	bne a1,'l',Monitor
	ldb a1,[t0]
	add t0,t0,1
	bne a1,'s',Monitor
	bsr ClearScreen
	bra Monitor
	
DisplayHelp:
	lda	a0,HelpMsg[gp]
	bsr	DisplayString
	bra	Monitor

	.rodata
HelpMsg:
	.byte	"? = Display help",CR,LF
	.byte	"CLS = clear screen",CR,LF
	.byte	": = Edit memory bytes",CR,LF
	.byte	"F = Fill memory",CR,LF
	.byte	"L = Load S19 file",CR,LF
	.byte	"D = Dump memory",CR,LF
	.byte	"B = start tiny basic",CR,LF
	.byte	"J = Jump to code",CR,LF,0

	.text
#------------------------------------------------------------------------------
# This routine borrowed from Gordo's Tiny Basic interpreter.
# Used to fetch a command line. (Not currently used).
#
# d0.b	- command prompt
#------------------------------------------------------------------------------

GetCmdLine:
	push a0,a1,t1
	bsr	DisplayChar		; display prompt
	ldi a1,' '
	bsr	DisplayChar
	lda	a0,CmdBuf
.0001:
	bsr	GetKey
	beq a1,CTRLH,.0003
	beq a1,CTRLX,.0004
	beq a1,CR,.0002
	blt a1,' ',.0001
.0002:
	stb a1,[a0]
	add a0,a0,1
	bsr	DisplayChar
	beq a1,CR,.0007
	blt a0,CmdBufEnd-1,.0001
.0003:
	bsr	DisplayChar
	ldi a1, ' '
	bsr	DisplayChar
	ble a0,CmdBuf,.0001
	ldi a1,CTRLH
	bsr	DisplayChar
	sub a0,a0,1
	bra .0001
.0004:
	beq a0,CmdBuf,.0001		# if nothing in buffer
	sub t1,a0,1
.0005:
	ldi a1,CTRLH
	bsr	DisplayChar
	ldi a1, ' '
	bsr	DisplayChar
	ldi a1,CTRLH
	bsr	DisplayChar
	sub t1,t1,1
	bge t1,r0,.0005
.0006:
	lda a0,CmdBuf
	bra	.0001
.0007:
	ldi a1,LF
	bsr	DisplayChar
	pop a0,a1,t1
	ret

		
#------------------------------------------------------------------------------
# Fill memory
# FB = fill bytes		FB 00000010 100 FF	; fill starting at 10 for 256 bytes
# FW = fill wydes
# FT = fill tetra
# FO = fill octas
# F = fill bytes
#------------------------------------------------------------------------------

FillMem:
	ldb t1,[t0]
	add t0,t0,1
	mov t4,t1						# t4 = fill size
		#bsr		ScreenToAscii
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	mov t1,a1						# t1 = start
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	mov t3,a1						# t3 = count	
	bsr	ignBlanks
	bsr	GetHexNumber		# fill value
	beq t4,'O',fmemO
	beq t4,'T',fmemT
	beq t4,'W',fmemW
	beq t4,'B',fmemB
	bra fmemB
fmemO:
	sto a1,[t1]
	add t1,t1,8
	sub t3,t3,1
	bgtu t3,r0,fmemO
	bra	Monitor
fmemT:
	stt a1,[t1]
	add t1,t1,4
	sub t3,t3,1
	bgtu t3,r0,fmemT
	bra	Monitor
fmemW:
	stw a1,[t1]
	add t1,t1,2
	sub t3,t3,1
	bgtu t3,r0,fmemW
	bra	Monitor
fmemB:
	stb a1,[t1]
	add t1,t1,1
	sub t3,t3,1
	bgtu t3,r0,fmemB
	bra	Monitor

#------------------------------------------------------------------------------
# Ignore blank spaces in input
#
# Modifies:
#		a0	- text pointer
#------------------------------------------------------------------------------

ignBlanks:
	push a1
.0001:
	ldb a1,[t0]
	add t0,t0,1
	beq a1,' ',.0001
	sub t0,t0,1
	pop a1
	ret

#------------------------------------------------------------------------------
# Edit memory byte.
#------------------------------------------------------------------------------

EditMem:
	bsr	ignBlanks
	bsr	GetHexNumber
	mov a2,a1
edtmem1:
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	stb a1,[a2]
	add a2,a2,1
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	stb a1,[a2]
	add a2,a2,1
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	stb a1,[a2]
	add a2,a2,1
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	stb a1,[a2]
	add a2,a2,1
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	stb a1,[a2]
	add a2,a2,1
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	stb a1,[a2]
	add a2,a2,1
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	stb a1,[a2]
	add a2,a2,1
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	stb a1,[a2]
	add a2,a2,1
	bra	Monitor

#------------------------------------------------------------------------------
# Execute code at the specified address.
#------------------------------------------------------------------------------

ExecuteCode:
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor
	jsr	[a1]
	bra Monitor

#------------------------------------------------------------------------------
# Do a memory dump of the requested location.
#------------------------------------------------------------------------------

DumpMem:
	bsr	ignBlanks
	bsr	GetHexNumber
	beq a0,r0,Monitor		# was there a number ? Digits > 0?
	mov a2,a1						# save off start of range
	bsr	ignBlanks
	bsr	GetHexNumber
	bne a0,r0,DumpMem1	# was there a number ? Digits > 0?
	add a3,a2,64				# no end specified, just dump 64 bytes
DumpMem1:
	mov a0,a2
	mov a1,a3
	bsr	CRLF
.0001:
	bgtu a0,a1,Monitor
	bsr	DisplayMem
	bra	.0001


#------------------------------------------------------------------------------
# Get a hexidecimal number. Maximum of eight digits.
#
# Returns:
#		a0 = number of digits
#		a1 = value of number
#------------------------------------------------------------------------------

GetHexNumber:
	push t2,t1
	ldi t2,0
	ldi t1,0							# number of digits
.0002:
	ldb a1,[t0]
	add t0,t0,1
	bsr	AsciiToHexNybble
	beq a1,0xff,.0001
	asl t2,t2,4
	and a1,a1,0xf
	or t2,t2,a1
	add t1,t1,1
	blt t1,16,.0002
.0001:
	mov a1,t2
	mov a0,t1
	pop t2,t1
	ret

#------------------------------------------------------------------------------
# Get a decimal number. Maximum of 20 digits.
#
# Returns:
#		a0 = number of digits
#		a1 = value of number
#------------------------------------------------------------------------------

GetDecNumber:
	push t2,t1
	ldi t2,0
	ldi t1,0							# number of digits
.0002:
	ldb a1,[t0]
	add t0,t0,1
	blt a1,'0',.0001
	bgt a1,'9',.0001
	sub a1,a1,'0'
	mul t2,t2,10
	add t2,t2,a1
	add t1,t1,1
	blt t1,24,.0002
.0001:
	mov a1,t2
	mov a0,t1
	pop t2,t1
	ret

#------------------------------------------------------------------------------
# Returns:
#		a0 = start of range
#		a1 = end of range
#------------------------------------------------------------------------------

GetRange:
	push lr1
	bsr ignBlanks
	bsr GetHexNumber
	push a1
	bsr ignBlanks
	bsr GetHexNumber
	pop a0
	pop lr1
	ret

LoadS19:
	ret

DisplayMem:
	ret

AsciiToHexNybble:
	ret

	.global GetRange
