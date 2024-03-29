set	txtscreen,0xFD000000
set leds,0xFD0FFF00
set keybd,0xFD0FFE00
set rand,0xFD0FFD00

	data
	dc.l		$0001FFFC
	dc.l		start

	code
start:
	move.l	0xFFFFFFE0,d0		; get core number
	cmpi.b	#2,d0
	bne			do_nothing
	bsr			Delay3s
	lea			txtscreen,a0
	move.l	#64*32,d0
	move.l	#32,d1
	move.l	#$43FFFFE0,d2
loop3:
	move.l	d1,(a0)+
	move.l	d2,(a0)+
	dbra		d0,loop3
loop2:
	move.l	#$FF,d0
loop1:
	move.b	d0,leds
	dbra		d0,loop1
	bra			loop2
do_nothing:
	bra			do_nothing

; -----------------------------------------------------------------------------
; Delay for a few seconds to allow some I/O reset operations to take place.
; -----------------------------------------------------------------------------
	
Delay3s:
	move.l	#2000000,d0
	lea			leds,a0
	bra			dly3s1
dly3s2:	
	swap		d0
dly3s1:
	move.l	d0,d1
	rol.l		#8,d1
	move.b	d1,(a0)
	dbra		d0,dly3s1
	swap		d0
	dbra		d0,dly3s2
	rts
