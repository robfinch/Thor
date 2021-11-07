	code
	align	2
;====================================================
; Basic Block 0
;====================================================
public code _main:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#16
	      	sw       	$r11,0[$sp]
	      	lea      	$r11,-8[$fp]
; 	a.bf2 = 10;
	      	ldi      	$v0,#10
	      	lw       	$v1,[$r0+$r11]
	      	and      	$v0,$v0,#7
	      	bfclr    	$v1,$v1,#10,#2
	      	ror      	$v1,$v1,#10
	      	or       	$v1,$v1,$v0
	      	rol      	$v1,$v1,#10
	      	sw       	$v1,[$r0+$r11]
; 	a.bf2++;
	      	lw       	$v0,[$r0+$r11]
	      	bfextu   	$v0,$v0,#10,#2
	      	lw       	$v1,[$r0+$r11]
	      	bfext    	$t0,$v1,#10,#2
	      	add      	$t0,$t0,#1
	      	and      	$t0,$t0,#7
	      	bfclr    	$v1,$v1,#10,#2
	      	ror      	$v1,$v1,#10
	      	or       	$v1,$v1,$t0
	      	rol      	$v1,$v1,#10
	      	sw       	$v1,[$r0+$r11]
; 	return (a.bf2);
	      	lw       	$v1,[$r0+$r11]
	      	mov      	$v0,$v1
	      	bfextu   	$v0,$v0,#10,#2
TestBitfieldInc_8:
	      	lw       	$r11,0[$sp]
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	ret      	#40
endpublic

	rodata
	align	16
;	global	_main
