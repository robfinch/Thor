	code
	align	2
;====================================================
; Basic Block 0
;====================================================
public code _TestArrayAssign4:
	      	sub      	$sp,$sp,#32
	      	sw       	$fp,[$sp]
	      	sw       	$r0,8[$sp]
	      	mov      	$fp,$sp
	      	sub      	$sp,$sp,#1880
	      	sw       	$r11,0[$sp]
	      	lea      	$v0,-720[$fp]
	      	mov      	$r11,$v0
; 	int x[3][5][6];
	      	lea      	$v0,TestArrayAssign_1
	      	lw       	$v0,[$v0]
	      	sw       	$v0,-1848[$fp]
; 	x[2][0][0] = 21;
	      	ldi      	$v0,#21
	      	sw       	$v0,480[$r11]
; 	x[1][4] = (int[6]){1,2,3,4,5,6};
	      	add      	$v0,$r11,#432
	      	lea      	$v1,TestArrayAssign_2
	      	mov      	$a0,$v0
	      	mov      	$a1,$v1
	      	ldi      	$a2,#48
	      	call     	__aacpy
; 	k = &x[2];
	      	add      	$v0,$r11,#480
	      	sw       	$v0,-1856[$fp]
; 	x[2] = (int[5][6]){{10,2,1,0},{9,6,2},{8},{7},{6}};
	      	add      	$v0,$r11,#480
	      	lea      	$v1,TestArrayAssign_8
	      	mov      	$a0,$v0
	      	mov      	$a1,$v1
	      	ldi      	$a2,#240
	      	call     	__aacpy
; 	x = y;
	      	lea      	$v0,-1840[$fp]
	      	mov      	$a0,$r11
	      	mov      	$a1,$v0
	      	ldi      	$a2,#1120
	      	call     	__aacpy
	      	lw       	$r11,0[$sp]
	      	mov      	$sp,$fp
	      	lw       	$fp,[$sp]
	      	ret      	#40
endpublic

	rodata
	align	16
	align	8
TestArrayAssign_1:
db	15
db	20
db	25
fill.b 5,0x00
TestArrayAssign_2:
dw	1
dw	2
dw	3
dw	4
dw	5
dw	6
TestArrayAssign_8:
dw	10
dw	2
dw	1
dw	0
fill.b 8,0x00
dw	9
dw	6
dw	2
fill.b 16,0x00
dw	8
fill.b 32,0x00
dw	7
fill.b 32,0x00
dw	6
fill.b 32,0x00
fill.b 160,0x00
;	global	_TestArrayAssign4
