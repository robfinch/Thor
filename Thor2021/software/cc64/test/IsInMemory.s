	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _IsInMemory:
	      	sub  	$sp,$sp,#32
	      	sw   	$fp,[$sp]
	      	sw   	$r0,8[$sp]
	      	mov  	$fp,$sp
	      	sub  	$sp,$sp,#8
	      	lw   	$v0,[$a0]
	      	bltu 	$a1,$v0,IsInMemory_9
;====================================================
; Basic Block 1
;====================================================
	      	lw   	$v1,[$a0]
	      	lw   	$v2,8[$a0]
	      	add  	$v0,$v1,$v2
	      	bgeu 	$a1,$v0,IsInMemory_9
;====================================================
; Basic Block 2
;====================================================
	      	ldi  	$v0,#1
	      	bra  	IsInMemory_10
IsInMemory_9:
;====================================================
; Basic Block 3
;====================================================
	      	ldi  	$v0,#0
IsInMemory_10:
IsInMemory_11:
	      	mov  	$sp,$fp
	      	lw   	$fp,[$sp]
	      	ret  	#32
IsInMemory_8:
;====================================================
; Basic Block 4
;====================================================
	      	bra  	IsInMemory_11
endpublic

	rodata
	align	16
;	global	_IsInMemory
