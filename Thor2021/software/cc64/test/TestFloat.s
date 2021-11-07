	code
	align	2
;====================================================
; Basic Block 0
;====================================================
public code _main:
; 	return (x+flt);
	      	lw       	$v0,0[$sp]
	      	itof.d   	$fp2,$v0
	      	lf.d     	$fp3,-8[$sp]
	      	fadd.d   	$fp1,$fp2,$fp3
	      	ftoi.d   	$v0,$fp1
TestFloat_8:
	      	ret      	#0
endpublic

	rodata
	align	16
;	global	_main
