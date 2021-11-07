	code
	align	16
;====================================================
; Basic Block 0
;====================================================
public code _TestCompl:
	      	sub  	$sp,$sp,#32
	      	sw   	$fp,[$sp]
	      	sw   	$r0,8[$sp]
	      	mov  	$fp,$sp
	      	sub  	$sp,$sp,#64
	      	sw   	$r11,0[$sp]
	      	sw   	$r12,8[$sp]
	      	sw   	$r13,16[$sp]
	      	sw   	$r14,24[$sp]
	      	sw   	$r15,32[$sp]
	      	lw   	$r11,32[$fp]
	      	lw   	$r12,40[$fp]
	      	lw   	$r13,-16[$fp]
	      	lw   	$r14,-8[$fp]
	      	lw   	$r15,-24[$fp]
; 	x = ~((y=(a & b)));
	      	and  	$v1,$r11,$r12
	      	mov  	$r13,$v1
	      	com  	$v0,$r13
	      	mov  	$r14,$v0
; 	x = ~(a & b);
	      	nand 	$v0,$r11,$r12
	      	mov  	$r14,$v0
; 	y = !(a && b);
	      	redor	$v2,$r11
	      	redor	$v3,$r12
	      	and  	$v1,$v2,$v3
	      	not  	$v0,$v1
	      	mov  	$r13,$v0
; 	z = (a || b);
	      	redor	$v1,$r11
	      	redor	$v2,$r12
	      	or   	$v0,$v1,$v2
	      	mov  	$r15,$v0
; 	return x+y+z;
	      	add  	$v1,$r14,$r13
	      	add  	$v0,$v1,$r15
	      	lw   	$r11,0[$sp]
	      	lw   	$r12,8[$sp]
	      	lw   	$r13,16[$sp]
	      	lw   	$r14,24[$sp]
	      	lw   	$r15,32[$sp]
	      	mov  	$sp,$fp
	      	lw   	$fp,[$sp]
	      	ret  	#32
endpublic

	rodata
	align	16
;	global	_TestCompl
