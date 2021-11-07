	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _ptrTest:
	      	sub  	$sp,$sp,#32
	      	sw   	$fp,[$sp]
	      	sw   	$r0,8[$sp]
	      	mov  	$fp,$sp
	      	sub  	$sp,$sp,#32
	      	sw   	$r11,0[$sp]
	      	sw   	$r12,8[$sp]
	      	lw   	$r12,24[$fp]
; 	p.a = ab->a;
	      	lw   	$v0,[$r12]
	      	sptr 	$v0,[$r11]
; 	p.b = ab->b;
	      	lw   	$v0,8[$r12]
	      	sptr 	$v0,8[$r11]
; 	return (&p->a);
	      	mov  	$v0,$r11
	      	lw   	$r11,0[$sp]
	      	lw   	$r12,8[$sp]
	      	mov  	$sp,$fp
	      	lw   	$fp,[$sp]
	      	ret  	#32
endpublic

	rodata
	align	16
;	global	_ptrTest
