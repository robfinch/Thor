	data
	align	8
	bss
	align	2
public bss _c1:
	fill.b	2,0x00

endpublic
	align	2
public bss _i8:
	fill.b	1,0x00

endpublic
	data
	align	8
	fill.b	5,0x00
	bss
	align	8
	align	8
	dw	$FFF0200000000002 ; GC_skip
public bss _gblA:
	fill.b	8,0x00

endpublic
	data
	align	8
	align	8
	dw	$FFF0200000000029 ; GC_skip
public data _gblB:
	dc	72,101,108,108,111,32,119,111
	dc	114,108,100,0
	fill.b	76,0x00
	fill.b	228,0x00

endpublic
	bss
	align	8
	align	8
	dw	$FFF02000000007D0 ; GC_skip
public bss _iarray:
	fill.b	16000,0x00

endpublic
	align	8
	align	8
	dw	$FFF020000001E078 ; GC_skip
public bss _sarray:
	fill.b	984000,0x00

endpublic
	align	8
	align	8
	  	                  ; GC_skip
public bss _cvar:
	fill.b	16,0x00

endpublic
	data
	align	8
	align	8
	  	                  ; GC_skip
public data _dvar:
	dw	10,-4486007441326060
endpublic

	bss
	align	8
	align	8
	dw	$FFF020000000001E ; GC_skip
public bss _s2array:
	fill.b	984000,0x00

endpublic
	align	8
public bss _vararray:
	fill.b	240,0x00

endpublic
	rodata
	align	16
;	global	_i8
;	global	_cvar
;	global	_dvar
;	global	_s2array
;	global	_vararray
;	global	_gblA
;	global	_gblB
;	global	_iarray
;	global	_sarray
;	global	_c1
