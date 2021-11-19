	.set	CSR_MGDT,0x3051
	.set	IOBASE,0xFF800000
	.set	RODATABASE,0xFFFE0000
	.set	LEDS,0xFFFFFFFFFF910000

	.bss
_bss_a:
	.space	10

	.data
_data_a:
	.space	10

	.text
	.align	2
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
	jmp			MachineStart
	nop
	nop
	nop

MachineStart:
  # Map 4kB GDT area
#	ldi			$t0,#$8000000000000C00	# entry number = $000, way = 3, write = true
#	ldi			$t1,#$008E000000000000
#	tlbrw		$x0,$t0,$t1
#	FFFC0000
#	1111_1111_1111_1100_0000_0000_0000_0000
#	1111_1111_11_11_1100_0000
	ldi			t0,0x8000000000000FC0		# entry number = $3C0, way = 3, write = true
	ldi			t1,0x008E000FFC0FFFC0
	tlbrw		r0,t0,t1
#	add			t0,t0,1
#	tlbrw		x0,t0,t1
#	add			t0,t0,1
#	tlbrw		x0,t0,t1
#	add			t0,t0,1
#	tlbrw		x0,t0,t1
	# Setup segments, codeseg already set at reset.
	# set data segment
	ldi			a2,0xFFFFFFFFFFFFFFC0			# start of scratchpad area
	csrrw		r0,a2,CSR_MGDT
	sllp		a2,r0,a2,12						# align
	and			a2,a2,-256
	ldi			a1,0x0000000000000000	# 0MB boundary
	sto			a1,0000*32[a2]
	sto			a1,0000*32+8[a2]
	ldi			a1,0xFFFFFFFFFFFFFFFF	# All - debug mode only
	sto			a1,0000*32+16[a2]
	ldi			a1,0x8EFF000000000000	# R/W cacheable data segment
	sto			a1,0000*32+24[a2]
	ldi			a0,001								# DS
	ldi			a1,0xFF000000
	mtsel		a0,a1
	# set stack segment
	ldi			a1,0xFFFC7000>>6			# last 4kB of bss
	sto			a1,0003*32[a2]
	ldi			a1,0
	sto			a1,0003*32+8[a2]
	ldi			a1,0x0000000000001000	# 4kB top of stack limit
	sto			a1,0003*32+16[a2]
	ldi			a1,0x8EFF000000000000	# R/W cacheable data segment
	sto			a1,0003*32+24[a2]
	ldi			a0,006								# SS
	ldi			a1,0xFF000003					#
	mtsel		a0,a1
	# set io segment
	ldi			a1,IOBASE>>6
	sto			a1,0004*32[a2]
	ldi			a1,0
	sto			a1,0004*32+8[a2]
	ldi			a1,0x00000000007FFFFF	# 8MB
	sto			a1,0004*32+16[a2]			# set limit
	ldi			a1,0x86FF000000000000	# R/W non-cacheable data segment
	sto			a1,0004*32+24[a2]
	ldi			a0,005								# HS
	ldi			a1,0xFF000004					# Max priv.
	mtsel		a0,a1
	# set read-only segment
	ldi			a1,RODATABASE>>6			#
	sto			a1,0005*32[a2]
	ldi			a1,0
	sto			a1,0005*32+8[a2]
	ldi			a1,0x000000000001FFFF	# 128kB
	sto			a1,0005*32+16[a2]
	ldi			a1,0x8CFF000000000000	# R-only cacheable data segment
	sto			a1,0005*32+24[a2]
	ldi			a0,2
	ldi			a1,0xFF000005
	mtsel		a0,a1
  # Map 32kB scratchpad stack area into stack segment
#	FFFC8000
#	1111_1111_1111_1100_1000_0000_0000_0000
#	1111_1111_11_11_1100_1000
	ldi			t0,0x8000000000000FC8		# entry number = $, way = 3, write = true
	ldi			t1,0x008E000FFC0FFFC8
	ldi			a1,8
	mtlc		a1
.0001:
	tlbrw		r0,t0,t1
	add			t0,t0,1							# map next 4kB
	dbra		.0001

	# Map LEDS
	# FF910000
	# 1111_1111_10 01_0001_0000_ 0000_0000_0000
	ldi			t0,0x8000000000000D10	# entry number = $110, way = 3, write = true
	ldi			t1,0x008E000FF80FF910
	tlbrw		r0,t0,t1

	# Map text screen - first 16kB
	# FFD00000
	# 1111_1111_11 01_0000_0000 _0000_0000_0000
	ldi			t0,0x8000000000000D00	# entry number = $100, way = 3, write = true
	ldi			t1,0x008E000FFC0FFD00	
	tlbrw		r0,t0,t1
	add			t0,t0,1							# map next 4kB
	tlbrw		r0,t0,t1
	add			t0,t0,1							# map next 4kB
	tlbrw		r0,t0,t1
	add			t0,t0,1							# map next 4kB
	tlbrw		r0,t0,t1

	# Setup debug mode stack pointer. The debug stack is set to a high order
	# address in the scratchpad memory area.
	ldi			sp,0xFF8

  ldi   	t0,0xAA
  stb   	t0,LEDS
  ldi   	a0,0xAA
  stb   	a0,LEDS
.0002:
	jmp			_main
	bra			.0002
	.type		MachineStart,@function
	.size		MachineStart,$-MachineStart

  
	.bss
	.align	8

	.bss
	.type	_xx,@object
	.size	_xx,256
_xx:

	.space	256,0x00                    


	.align	8

	.bss
	.type	_yy,@object
	.size	_yy,256
_yy:

	.space	256,0x00                    


	.align	8

	.bss
	.type	_dx,@object
	.size	_dx,256
_dx:

	.space	256,0x00                    


	.align	8

	.bss
	.type	_dy,@object
	.size	_dy,256
_dy:

	.space	256,0x00                    

 
	.align	2

	.bss
	.type	_state,@object
	.size	_state,8
_state:

	.space	8,0x00                    

          
#{++ _my_abs

	.text
	.align	4

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_my_abs:
# if (a < 0) a = -a;
  ldo      t0,[r0]
  bge      t0,r0,.00013
  ldo      t1,[r0]
  neg      t0,t1
  sto      t0,[r0]
.00013:
# return (a);
  ldo      a0,[r0]
.00012:
  ret    
	.type	_my_abs,@function
	.size	_my_abs,$-_my_abs


#--}
   
#{++ _my_srand

	.align 4

	.sdreg	61
  #====================================================
# Basic Block 0
#====================================================
_my_srand:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,16
  sto      s0,0[sp]
  sto      s1,8[sp]
# int* pRand = 0;
  mov      s1,r0
# pRand += (0xFF940000/sizeof(int));
  add      s1,s1,4287889408
# for (ch = 0; ch < 256; ch++) {
  mov      s0,r0
  sgt      t0,s0,255
  bne      t0,r0,.00029
.00028:
# pRand[1] = ch;
  sto      s0,8[s1]
# pRand[2] = a;
  ldo      t0,[r0]
  sto      t0,16[s1]
# pRand[3] = b;
  ldo      t0,[r0]
  sto      t0,24[s1]
.00030:
  add      s0,s0,1
  slt      t0,s0,256
  bne      t0,r0,.00028
.00029:
.00027:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  add      sp,sp,16
  ret    
	.type	_my_srand,@function
	.size	_my_srand,$-_my_srand


#--}
  
#{++ _my_rand

	.align 4

	.sdreg	61
  #====================================================
# Basic Block 0
#====================================================
_my_rand:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,16
  sto      s0,0[sp]
  sto      s1,8[sp]
# int* pRand = 0;
  mov      s0,r0
# pRand += (0xFF940000/sizeof(int));
  add      s0,s0,4287889408
# pRand[1] = ch;
  ldo      t0,[r0]
  sto      t0,8[s0]
# r = *pRand;
  ldo      s1,[s0]
# *pRand = r;
  sto      s1,[s0]
# return (r);
  mov      a0,s1
.00040:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  add      sp,sp,8
  ret    
	.type	_my_rand,@function
	.size	_my_rand,$-_my_rand


#--}
 
#{++ _ramtest

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_ramtest:
.00050:
  ret    
	.type	_ramtest,@function
	.size	_ramtest,$-_ramtest


#--}
  
#{++ _PutNybble

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_PutNybble:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,8
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  sto      s0,0[sp]
  ldo      s0,96[fp]
# n = n & 15;
  and      s0,s0,15
# if (n > 9)
  slt      t0,s0,10
  bne      t0,r0,.00063
# n = n + 'A' - 10;
  add      t1,s0,65
  sub      s0,t1,10
  bra      .00064
.00063:
# n = n + '0';
  add      s0,s0,48
.00064:
# DBGDisplayChar(n);
  sto      s0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
.00062:
  ldo      s0,0[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,104
  ret    
	.type	_PutNybble,@function
	.size	_PutNybble,$-_PutNybble


#--}
  
#{++ _PutByte

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_PutByte:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,8
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  sto      s0,0[sp]
  ldo      s0,96[fp]
# PutNybble(n >> 4);
  sra      t0,s0,4
  sto      t0,0[sp]
  jsr      lk1,_PutNybble
  add      sp,sp,8
# PutNybble(n);
  sto      s0,0[sp]
  jsr      lk1,_PutNybble
  add      sp,sp,8
.00074:
  ldo      s0,0[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,104
  ret    
	.type	_PutByte,@function
	.size	_PutByte,$-_PutByte


#--}
  
#{++ _PutWyde

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_PutWyde:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,8
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  sto      s0,0[sp]
  ldo      s0,96[fp]
# PutByte(n >> 8);
  sra      t0,s0,8
  sto      t0,0[sp]
  jsr      lk1,_PutByte
  add      sp,sp,8
# PutByte(n);
  sto      s0,0[sp]
  jsr      lk1,_PutByte
  add      sp,sp,8
.00084:
  ldo      s0,0[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,104
  ret    
	.type	_PutWyde,@function
	.size	_PutWyde,$-_PutWyde


#--}
  
#{++ _PutTetra

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_PutTetra:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,8
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  sto      s0,0[sp]
  ldo      s0,96[fp]
# PutWyde(n >> 16);
  sra      t0,s0,16
  sto      t0,0[sp]
  jsr      lk1,_PutWyde
  add      sp,sp,8
# PutWyde(n);
  sto      s0,0[sp]
  jsr      lk1,_PutWyde
  add      sp,sp,8
.00094:
  ldo      s0,0[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,104
  ret    
	.type	_PutTetra,@function
	.size	_PutTetra,$-_PutTetra


#--}
 
#{++ _FlashLEDs

	.align 4

	.sdreg	61
  #====================================================
# Basic Block 0
#====================================================
_FlashLEDs:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,24
  sto      s0,0[sp]
  sto      s1,8[sp]
  sto      s2,16[sp]
  ldi      s2,2000000
# int* pLEDS = 0;
  mov      s1,r0
# pLEDS += (0xFF910000/sizeof(int));
  add      s1,s1,4287692800
# *pLEDS = 0xAAAA;
  ldi      t0,43690
  sto      t0,[s1]
# for (n = 0; n < 2000000; n++)
  mov      s0,r0
  bge      s0,s2,.00109
.00108:
# *pLEDS = n >> 13;
  sra      t0,s0,13
  sto      t0,[s1]
  add      s0,s0,1
  blt      s0,s2,.00108
.00109:
.00107:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  ldo      s2,16[sp]
  ret    
	.type	_FlashLEDs,@function
	.size	_FlashLEDs,$-_FlashLEDs


#--}
 
#{++ _SetSpriteColor

	.align 4

	.sdreg	61
   #====================================================
# Basic Block 0
#====================================================
_SetSpriteColor:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,48
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  sto      s0,0[sp]
  sto      s1,8[sp]
  sto      s2,16[sp]
  sto      s3,24[sp]
  sto      s4,32[sp]
# int:16* pSpr = 0;
  mov      s3,r0
# pSpr += (0x00300000/sizeof(int:16));
  add      s3,s3,3145728
# for (m = 0; m < 32; m++) {
  mov      s1,r0
  sgt      t0,s1,31
  bne      t0,r0,.00152
.00151:
# c = my_rand(0);
  sto      r0,0[sp]
  jsr      lk1,_my_rand
  add      sp,sp,8
  mov      t0,a0
  mov      s2,t0
# k = m * 2048;
  sll      s4,s1,11
# for (n = 0; n < 2048; n++)
  mov      s0,r0
  sgt      t0,s0,2047
  bne      t0,r0,.00155
.00154:
# pSpr[k + n] = c;
  add      t1,s4,s0
  sll      t0,t1,1
  stw      s2,[t0+s3]
  add      s0,s0,1
  slt      t0,s0,2048
  bne      t0,r0,.00154
.00155:
  add      s1,s1,1
  slt      t0,s1,32
  bne      t0,r0,.00151
.00152:
# c = 0x7fff;
  ldi      s2,32767
# for (m = 0; m < 32; m++) {
  mov      s1,r0
  sgt      t0,s1,31
  bne      t0,r0,.00158
.00157:
# k = m * 2048;
  sll      s4,s1,11
# for (n = 0; n < 56; n++)	// Top
  mov      s0,r0
  sgt      t0,s0,55
  bne      t0,r0,.00161
.00160:
# pSpr[k + n] = c;
  add      t1,s4,s0
  sll      t0,t1,1
  stw      s2,[t0+s3]
  add      s0,s0,1
  slt      t0,s0,56
  bne      t0,r0,.00160
.00161:
# for (n = 0; n < 56; n++)	// Bottom
  mov      s0,r0
  sgt      t0,s0,55
  bne      t0,r0,.00164
.00163:
# pSpr[k + 35*56 + n] = c;
  add      t2,s4,1960
  add      t1,t2,s0
  sll      t0,t1,1
  stw      s2,[t0+s3]
  add      s0,s0,1
  slt      t0,s0,56
  bne      t0,r0,.00163
.00164:
# for (n = 0; n < 36; n++)	// Left
  mov      s0,r0
  sgt      t0,s0,35
  bne      t0,r0,.00167
.00166:
# pSpr[k + n * 56] = c;
  mul      t2,s0,56
  add      t1,s4,t2
  sll      t0,t1,1
  stw      s2,[t0+s3]
  add      s0,s0,1
  slt      t0,s0,36
  bne      t0,r0,.00166
.00167:
# for (n = 0; n < 36; n++)	// Right
  mov      s0,r0
  sgt      t0,s0,35
  bne      t0,r0,.00170
.00169:
# pSpr[k + 55 + n * 56] = c;
  add      t2,s4,55
  mul      t3,s0,56
  add      t1,t2,t3
  sll      t0,t1,1
  stw      s2,[t0+s3]
  add      s0,s0,1
  slt      t0,s0,36
  bne      t0,r0,.00169
.00170:
# for (n = 0; n < 36; n++)
  mov      s0,r0
  sgt      t0,s0,35
  bne      t0,r0,.00173
.00172:
# pSpr[k + n * 57] = c;
  mul      t2,s0,57
  add      t1,s4,t2
  sll      t0,t1,1
  stw      s2,[t0+s3]
  add      s0,s0,1
  slt      t0,s0,36
  bne      t0,r0,.00172
.00173:
# for (n = 0; n < 36; n++)
  mov      s0,r0
  sgt      t0,s0,35
  bne      t0,r0,.00176
.00175:
# pSpr[k + n * 55 + 55] = c;
  mul      t3,s0,55
  add      t2,s4,t3
  add      t1,t2,55
  sll      t0,t1,1
  stw      s2,[t0+s3]
  add      s0,s0,1
  slt      t0,s0,36
  bne      t0,r0,.00175
.00176:
  add      s1,s1,1
  slt      t0,s1,32
  bne      t0,r0,.00157
.00158:
# for (m = 0; m < 1000000; m++)
  mov      s1,r0
  sgt      t0,s1,999999
  bne      t0,r0,.00179
.00178:
# ;
  add      s1,s1,1
  slt      t0,s1,1000000
  bne      t0,r0,.00178
.00179:
# *pSprVDT = 0;
  stt      r0,4287300568
.00150:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  ldo      s2,16[sp]
  ldo      s3,24[sp]
  ldo      s4,32[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,96
  ret    
	.type	_SetSpriteColor,@function
	.size	_SetSpriteColor,$-_SetSpriteColor


#--}
 
#{++ _SetSpritePosAndSpeed

	.align 4

	.sdreg	61
  #====================================================
# Basic Block 0
#====================================================
_SetSpritePosAndSpeed:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,32
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  lea      gp,_data_start
  sto      s0,0[sp]
  sto      s1,8[sp]
# int:16* pSpr16 = 0;
  mov      s1,r0
# pSpr16 += (0xFF8B0000/sizeof(int:16));
  add      s1,s1,4287299584
# for (n = 0; n < 32; n++)
  mov      s0,r0
  sgt      t0,s0,31
  bne      t0,r0,.00195
.00194:
# xx[n] = (my_rand(0) & 511) + 210;
  sll      t0,s0,3
  lea      t1,_xx[gp]
  sto      t0,-32[fp]
  sto      t1,-40[fp]
  sto      t2,-48[fp]
  sto      t3,-56[fp]
  sto      r0,0[sp]
  jsr      lk1,_my_rand
  add      sp,sp,8
  ldo      t1,-40[fp]
  ldo      t0,-32[fp]
  mov      t4,a0
  and      t3,t4,511
  add      t2,t3,210
  sto      t2,[t0+t1]
# yy[n] = (my_rand(0) & 511) + 36;
  sll      t0,s0,3
  lea      t1,_yy[gp]
  sto      t0,-32[fp]
  sto      t1,-40[fp]
  sto      t2,-48[fp]
  sto      t3,-56[fp]
  sto      r0,0[sp]
  jsr      lk1,_my_rand
  add      sp,sp,8
  ldo      t1,-40[fp]
  ldo      t0,-32[fp]
  mov      t4,a0
  and      t3,t4,511
  add      t2,t3,36
  sto      t2,[t0+t1]
# dx[n] = (my_rand(0) & 7) - 4;
  sll      t0,s0,3
  lea      t1,_dx[gp]
  sto      t0,-32[fp]
  sto      t1,-40[fp]
  sto      t2,-48[fp]
  sto      t3,-56[fp]
  sto      r0,0[sp]
  jsr      lk1,_my_rand
  add      sp,sp,8
  ldo      t1,-40[fp]
  ldo      t0,-32[fp]
  mov      t4,a0
  and      t3,t4,7
  sub      t2,t3,4
  sto      t2,[t0+t1]
# dy[n] = (my_rand(0) & 7) - 4;
  sll      t0,s0,3
  lea      t1,_dy[gp]
  sto      t0,-32[fp]
  sto      t1,-40[fp]
  sto      t2,-48[fp]
  sto      t3,-56[fp]
  sto      r0,0[sp]
  jsr      lk1,_my_rand
  add      sp,sp,8
  ldo      t1,-40[fp]
  ldo      t0,-32[fp]
  mov      t4,a0
  and      t3,t4,7
  sub      t2,t3,4
  sto      t2,[t0+t1]
# pSpr16[n*8] = xx[n];
  sll      t1,s0,3
  sll      t0,t1,1
  sll      t1,s0,3
  lea      t2,_xx[gp]
  ldw      t3,[t1+t2]
  stw      t3,[t0+s1]
# pSpr16[n*8+1] = yy[n];
  sll      t2,s0,3
  add      t1,t2,1
  sll      t0,t1,1
  sll      t1,s0,3
  lea      t2,_yy[gp]
  ldw      t3,[t1+t2]
  stw      t3,[t0+s1]
# pSpr16[n*8+2] = 0x2a30;		// set size 48x42
  sll      t2,s0,3
  add      t1,t2,2
  sll      t0,t1,1
  ldi      t1,10800
  stw      t1,[t0+s1]
  add      s0,s0,1
  slt      t0,s0,32
  bne      t0,r0,.00194
.00195:
.00193:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,96
  ret    
	.type	_SetSpritePosAndSpeed,@function
	.size	_SetSpritePosAndSpeed,$-_SetSpritePosAndSpeed


#--}
 
#{++ _MoveSprites

	.align 4

	.sdreg	61
     #====================================================
# Basic Block 0
#====================================================
_MoveSprites:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,80
  lea      gp,_data_start
  sto      s0,0[sp]
  sto      s1,8[sp]
  sto      s2,16[sp]
  sto      s3,24[sp]
  sto      s4,32[sp]
  sto      s5,40[sp]
  sto      s6,48[sp]
  sto      s7,56[sp]
  sto      s8,64[sp]
  sto      a0,72[sp]
  ldi      a0,2145448001
# int* pScreen = 0;
  mov      s3,r0
  mov      s4,r0
# pSpr16 += (0xFF8B0000/sizeof(int:16));
  add      s4,s4,4287299584
# pScreen += (0xFF800000/sizeof(int));
  add      s3,s3,4286578688
# for (m = 0; m < 10000; m++)
  mov      s2,r0
  sgt      t0,s2,9999
  bne      t0,r0,.00242
.00241:
# ;
  add      s2,s2,1
  slt      t0,s2,10000
  bne      t0,r0,.00241
.00242:
# for (n = 0; n < 32; n++) {
  mov      s0,r0
  sgt      t0,s0,31
  bne      t0,r0,.00245
.00244:
# j = xx[n];
  sll      t0,s0,3
  lea      t1,_xx[gp]
  ldo      s6,[t0+t1]
# k = dx[n];
  sll      t0,s0,3
  lea      t1,_dx[gp]
  ldo      s5,[t0+t1]
# a = yy[n];
  sll      t0,s0,3
  lea      t1,_yy[gp]
  ldo      s8,[t0+t1]
# b = dy[n];
  sll      t0,s0,3
  lea      t1,_dy[gp]
  ldo      s7,[t0+t1]
# t = j < 210 && k < 0;
  slt      t0,s6,210
  slt      t1,s5,r0
  and      s1,t0,t1
# pScreen[0] = t + 0x7FE0F041;
  add      t0,s1,a0
  sto      t0,[s3]
# if (t)
  beqz     s1,.00252
# dx[n] = -dx[n];
  sll      t0,s0,3
  lea      t1,_dx[gp]
  sll      t3,s0,3
  lea      t4,_dx[gp]
  ldo      t3,[t3+t4]
  neg      t2,t3
  sto      t2,[t0+t1]
.00252:
# t = j > 210 + 800 && k > 0;
  sgt      t0,s6,1010
  slt      t1,r0,s5
  and      s1,t0,t1
# pScreen[1] = t + 0x7FE0F041;
  add      t0,s1,a0
  sto      t0,8[s3]
# if (t)
  beqz     s1,.00259
# dx[n] = -dx[n];
  sll      t0,s0,3
  lea      t1,_dx[gp]
  sll      t3,s0,3
  lea      t4,_dx[gp]
  ldo      t3,[t3+t4]
  neg      t2,t3
  sto      t2,[t0+t1]
.00259:
# t = a < 36 && b < 0;
  slt      t0,s8,36
  slt      t1,s7,r0
  and      s1,t0,t1
# pScreen[2] = t + 0x7FE0F041;
  add      t0,s1,a0
  sto      t0,16[s3]
# if (t)
  beqz     s1,.00266
# dy[n] = -dy[n];
  sll      t0,s0,3
  lea      t1,_dy[gp]
  sll      t3,s0,3
  lea      t4,_dy[gp]
  ldo      t3,[t3+t4]
  neg      t2,t3
  sto      t2,[t0+t1]
.00266:
# t = a > 600 + 26 && b > 0;
  sgt      t0,s8,626
  slt      t1,r0,s7
  and      s1,t0,t1
# pScreen[3] = t + 0x7FE0F041;
  add      t0,s1,a0
  sto      t0,24[s3]
# if (t)
  beqz     s1,.00273
# dy[n] = -dy[n];
  sll      t0,s0,3
  lea      t1,_dy[gp]
  sll      t3,s0,3
  lea      t4,_dy[gp]
  ldo      t3,[t3+t4]
  neg      t2,t3
  sto      t2,[t0+t1]
.00273:
# pSpr16[n*8] = xx[n];
  sll      t1,s0,3
  sll      t0,t1,1
  sll      t1,s0,3
  lea      t2,_xx[gp]
  ldw      t3,[t1+t2]
  stw      t3,[t0+s4]
# pSpr16[n*8+1] = yy[n];
  sll      t2,s0,3
  add      t1,t2,1
  sll      t0,t1,1
  sll      t1,s0,3
  lea      t2,_yy[gp]
  ldw      t3,[t1+t2]
  stw      t3,[t0+s4]
# xx[n] += dx[n];
  sll      t0,s0,3
  lea      t1,_xx[gp]
  sll      t2,s0,3
  lea      t3,_dx[gp]
  ldo      t2,[t2+t3]
  ldo      t3,[t0+t1]
  add      t3,t3,t2
  sto      t3,[t0+t1]
# yy[n] += dy[n];
  sll      t0,s0,3
  lea      t1,_yy[gp]
  sll      t2,s0,3
  lea      t3,_dy[gp]
  ldo      t2,[t2+t3]
  ldo      t3,[t0+t1]
  add      t3,t3,t2
  sto      t3,[t0+t1]
  add      s0,s0,1
  slt      t0,s0,32
  bne      t0,r0,.00244
.00245:
.00240:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  ldo      s2,16[sp]
  ldo      s3,24[sp]
  ldo      s4,32[sp]
  ldo      s5,40[sp]
  ldo      s6,48[sp]
  ldo      s7,56[sp]
  ldo      s8,64[sp]
  ldo      a0,72[sp]
  ret    
	.type	_MoveSprites,@function
	.size	_MoveSprites,$-_MoveSprites


#--}
 
#{++ _main

	.align 4

	.sdreg	61
      #====================================================
# Basic Block 0
#====================================================
_main:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,56
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  lea      gp,_data_start
  lea      gp1,_rodata_start
  sto      s0,0[sp]
  sto      s1,8[sp]
  sto      s2,16[sp]
  sto      s3,24[sp]
  sto      s4,32[sp]
  sto      s5,40[sp]
  sto      s6,48[sp]
  ldi      s4,100000
# int* pScreen = 0;
  mov      s1,r0
  mov      s6,r0
  lea      t0,rom_bios_c_275[gp1]
  sto      t0,-40[fp]
  ldi      s5,4294836224
  mov      s3,r0
# pLEDS += (0xFF910000/sizeof(int));
  add      s3,s3,4287692800
# *pLEDS = 0x01;
  ldi      t0,1
  sto      t0,[s3]
# state++;
  ldo      t0,_state[gp]
  add      t0,t0,1
  sto      t0,_state[gp]
# FlashLEDs();
  jsr      lk1,_FlashLEDs
# *pLEDS = 0x55;
  ldi      t0,85
  sto      t0,[s3]
# DBGAttr = 0x7FE0F000;
  ldi      t0,2145447936
  sto      t0,_DBGAttr[gp]
# pMem += (0xFFFC0000/sizeof(int));
  add      s6,s6,4294705152
# pScreen += (0xFF800000/sizeof(int));
  add      s1,s1,4286578688
# DBGClearScreen();
  jsr      lk1,_DBGClearScreen
# DBGHomeCursor();
  jsr      lk1,_DBGHomeCursor
# pScreen[0] = DBGAttr|'A';
  ldo      t1,_DBGAttr[gp]
  or       t0,t1,65
  sto      t0,[s1]
# pScreen[1] = DBGAttr|'A';
  ldo      t1,_DBGAttr[gp]
  or       t0,t1,65
  sto      t0,8[s1]
# pScreen[2] = DBGAttr|'A';
  ldo      t1,_DBGAttr[gp]
  or       t0,t1,65
  sto      t0,16[s1]
# pScreen[3] = DBGAttr|'A';
  ldo      t1,_DBGAttr[gp]
  or       t0,t1,65
  sto      t0,24[s1]
# n = 1;
  ldi      s0,1
# if (n)
  beqz     s0,.00303
# pScreen[4] = DBGAttr|'B';
  ldo      t1,_DBGAttr[gp]
  or       t0,t1,66
  sto      t0,32[s1]
.00303:
# n++;
  add      s0,s0,1
# if (n==2)
  bne      s0,2,.00305
# pScreen[5] = DBGAttr|'C';
  ldo      t1,_DBGAttr[gp]
  or       t0,t1,67
  sto      t0,40[s1]
.00305:
# if (n==4)
  bne      s0,4,.00307
# pScreen[6] = DBGAttr|'D';
  ldo      t1,_DBGAttr[gp]
  or       t0,t1,68
  sto      t0,48[s1]
.00307:
# DBGCRLF();
  jsr      lk1,_DBGCRLF
# DBGDisplayChar('E');
  ldi      t0,69
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
# DBGDisplayChar('F');
  ldi      t0,70
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
# DBGDisplayChar('G');
  ldi      t0,71
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
# PutWyde(0x1234);
  ldi      t0,4660
  sto      t0,0[sp]
  jsr      lk1,_PutWyde
  add      sp,sp,8
# DBGDisplayChar('\r');
  ldi      t0,13
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
# DBGDisplayChar('\n');
  ldi      t0,10
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
# PutWyde(btstr[0]);
  ldw      t0,[s5]
  sto      t0,0[sp]
  jsr      lk1,_PutWyde
  add      sp,sp,8
# DBGDisplayChar('\r');
  ldi      t0,13
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
# DBGDisplayChar('\n');
  ldi      t0,10
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
# DBGDisplayChar(' ');
  ldi      t0,32
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
# my_srand(1234,4567);
  ldi      t0,1234
  sto      t0,0[sp]
  ldi      t0,4567
  sto      t0,8[sp]
  jsr      lk1,_my_srand
  add      sp,sp,8
# SetSpriteColor();
  jsr      lk1,_SetSpriteColor
# state++;
  ldo      t0,_state[gp]
  add      t0,t0,1
  sto      t0,_state[gp]
# SetSpritePosAndSpeed();
  jsr      lk1,_SetSpritePosAndSpeed
.00309:
# MoveSprites();
  jsr      lk1,_MoveSprites
# for (n = 0; n < 100000; n = n + 1)
  mov      s0,r0
  bge      s0,s4,.00312
.00311:
# pScreen[my_abs(my_rand(0))%(64*32)+64] = my_rand(0);
  sto      t0,-56[fp]
  sto      t1,-64[fp]
  sto      t2,-72[fp]
  sto      r0,0[sp]
  jsr      lk1,_my_rand
  add      sp,sp,8
  mov      t3,a0
  sto      t3,0[sp]
  jsr      lk1,_my_abs
  add      sp,sp,8
  mov      t3,a0
  and      t2,t3,2047
  add      t1,t2,64
  sll      t0,t1,3
  sto      r0,0[sp]
  jsr      lk1,_my_rand
  add      sp,sp,8
  mov      t3,a0
  sto      t3,[t0+s1]
  add      s0,s0,1
  blt      s0,s4,.00311
.00312:
# for (m = 0; m < 10000; m = m + 1) {
  mov      s2,r0
  sgt      t0,s2,9999
  bne      t0,r0,.00315
.00314:
# pScreen = 0;
  mov      s1,r0
# pScreen += (0xFF800010/sizeof(int));
  add      s1,s1,4286578704
# for (n = 0; n < 64*33; n = n + 1)
  mov      s0,r0
  sgt      t0,s0,2111
  bne      t0,r0,.00318
.00317:
# *pScreen++ = my_rand(0);
  sto      r0,0[sp]
  jsr      lk1,_my_rand
  add      sp,sp,8
  mov      t0,a0
  sto      t0,[s1]
  add      s1,s1,8
  add      s0,s0,1
  slt      t0,s0,2112
  bne      t0,r0,.00317
.00318:
  add      s2,s2,1
  slt      t0,s2,10000
  bne      t0,r0,.00314
.00315:
  bra      .00309
.00302:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  ldo      s2,16[sp]
  ldo      s3,24[sp]
  ldo      s4,32[sp]
  ldo      s5,40[sp]
  ldo      s6,48[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,96
  ret    
	.type	_main,@function
	.size	_main,$-_main


#--}
 
#{++ _last_func

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_last_func:
.00329:
  ret    
	.type	_last_func,@function
	.size	_last_func,$-_last_func


#--}

	.rodata
	.align	16

	.align	8


	.type	rom_bios_c_275,@object
	.size	rom_bios_c_275,46
rom_bios_c_275: # rfPower SoC Booting...

	.2byte	114,102,80,111,119,101,114,32
	.2byte	83,111,67,32,66,111,111,116
	.2byte	105,110,103,46,46,46,0
	.extern	_rand
	.extern	_SieveOfEratosthenes
	.extern	_DBGHomeCursor
	.extern	_DBGCRLF
	.extern	_DBGClearScreen
	.extern	_srand
	.extern	_DBGDisplayChar
	.extern	_DBGDisplayAsciiStringCRLF
	.extern	_DBGAttr
                                                                                                                                                                                                                                                         
#{++ _UnlockSemaphore

	.text
	.align	4
	.sdreg	61

#--}
  
#{++ _SetVBA
	.sdreg	61

#--}
       
#{++ _UnlockIOFSemaphore
	.sdreg	61

#--}
 
#{++ _UnlockKbdSemaphore
	.sdreg	61

#--}
 
#{++ _GetImLevel
	.sdreg	61

#--}
  
#{++ _RestoreImLevel
	.sdreg	61

#--}
   
#{++ _LEDS
	.sdreg	61

#--}
                         
	.bss
	.align	2

	.bss
	.type	_DBGCursorCol,@object
	.size	_DBGCursorCol,2
_DBGCursorCol:

	.space	2,0x00                    

 
	.align	2

	.bss
	.type	_DBGCursorRow,@object
	.size	_DBGCursorRow,2
_DBGCursorRow:

	.space	2,0x00                    

 
	.align	2

	.bss
	.type	_DBGAttr,@object
	.size	_DBGAttr,8
_DBGAttr:

	.space	8,0x00                    

      
	.align	8

	.bss
	.type	_tabstops,@object
	.size	_tabstops,64
_tabstops:

	.space	64,0x00                    

 
#{++ _DBGClearScreen

	.text
	.align	4

	.align 4

	.sdreg	61
   #====================================================
# Basic Block 0
#====================================================
_DBGClearScreen:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,32
  lea      gp,_data_start
  sto      s0,0[sp]
  sto      s2,16[sp]
# vc = ' ' | DBGAttr;
  ldo      t1,_DBGAttr[gp]
  or       s2,t1,32
# for (n = 0; n < 33*64; n++)
  mov      s0,r0
  sgt      t0,s0,2111
  bne      t0,r0,.00015
.00014:
# p[n] = vc;
  sll      t0,s0,3
  sto      s2,[t0+s1]
  add      s0,s0,1
  slt      t0,s0,2112
  bne      t0,r0,.00014
.00015:
.00013:
  ldo      s0,0[sp]
  ldo      s2,16[sp]
  ret    
	.type	_DBGClearScreen,@function
	.size	_DBGClearScreen,$-_DBGClearScreen


#--}
   
#{++ _DBGSetVideoReg

	.align 4

	.sdreg	61
 #====================================================
# Basic Block 0
#====================================================
_DBGSetVideoReg:
.00026:
  ret    
	.type	_DBGSetVideoReg,@function
	.size	_DBGSetVideoReg,$-_DBGSetVideoReg


#--}
  
#{++ _DBGSetCursorPos

	.align 4

	.sdreg	61
 #====================================================
# Basic Block 0
#====================================================
_DBGSetCursorPos:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,8
  sto      s0,0[sp]
# p = (int *)0xFFD17F00;
  ldi      s0,4291919616
# p[7] = pos;
  ldo      t0,[r0]
  sto      t0,56[s0]
.00036:
  ldo      s0,0[sp]
  add      sp,sp,8
  ret    
	.type	_DBGSetCursorPos,@function
	.size	_DBGSetCursorPos,$-_DBGSetCursorPos


#--}
 
#{++ _DBGUpdateCursorPos

	.align 4

	.sdreg	61
 #====================================================
# Basic Block 0
#====================================================
_DBGUpdateCursorPos:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,8
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  lea      gp,_data_start
  sto      s0,0[sp]
# pos = DBGCursorRow * 64 + DBGCursorCol;
  ldwu     t2,_DBGCursorRow[gp]
  sll.w    t1,t2,6
  ldwu     t2,_DBGCursorCol[gp]
  add      s0,t1,t2
# DBGSetCursorPos(pos);
  sto      s0,0[sp]
  jsr      lk1,_DBGSetCursorPos
  add      sp,sp,8
.00046:
  ldo      s0,0[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,96
  ret    
	.type	_DBGUpdateCursorPos,@function
	.size	_DBGUpdateCursorPos,$-_DBGUpdateCursorPos


#--}
 
#{++ _DBGHomeCursor

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_DBGHomeCursor:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  lea      gp,_data_start
# DBGCursorCol = 0;
  stw      r0,_DBGCursorCol[gp]
# DBGCursorRow = 0;
  stw      r0,_DBGCursorRow[gp]
# DBGUpdateCursorPos();
  jsr      lk1,_DBGUpdateCursorPos
.00056:
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,96
  ret    
	.type	_DBGHomeCursor,@function
	.size	_DBGHomeCursor,$-_DBGHomeCursor


#--}
  
#{++ _DBGBlankLine

	.align 4

	.sdreg	61
    #====================================================
# Basic Block 0
#====================================================
_DBGBlankLine:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,24
  lea      gp,_data_start
  sto      s0,0[sp]
  sto      s1,8[sp]
  sto      s2,16[sp]
# p = (int *)0xFFD00000;
  ldi      s1,4291821568
# p = p + row * 64;
  ldo      t3,[r0]
  sll      t2,t3,6
  sll      t1,t2,3
  add      s1,s1,t1
# vc = DBGAttr | ' ';
  ldo      t1,_DBGAttr[gp]
  or       s2,t1,32
# for (nn = 0; nn < 64; nn++)
  mov      s0,r0
  sgt      t0,s0,63
  bne      t0,r0,.00071
.00070:
# p[nn] = vc;
  sll      t0,s0,3
  sto      s2,[t0+s1]
  add      s0,s0,1
  slt      t0,s0,64
  bne      t0,r0,.00070
.00071:
.00069:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  ldo      s2,16[sp]
  add      sp,sp,8
  ret    
	.type	_DBGBlankLine,@function
	.size	_DBGBlankLine,$-_DBGBlankLine


#--}
 
#{++ _DBGScrollUp

	.align 4

	.sdreg	61
    #====================================================
# Basic Block 0
#====================================================
_DBGScrollUp:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,32
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  sto      s0,0[sp]
  sto      s1,8[sp]
  sto      s2,16[sp]
# int *scrn = (int *)0xFFD00000;
  ldi      s2,4291822080
# count = 33 * 64;
  ldi      s1,2112
# for (nn = 0; nn < count; nn++)
  mov      s0,r0
  bge      s0,s1,.00087
.00086:
# scrn[nn] = scrn2[nn];
  sll      t0,s0,3
  sll      t1,s0,3
  ldo      t2,[t1+s2]
  sto      t2,[t0+s3]
  add      s0,s0,1
  blt      s0,s1,.00086
.00087:
# DBGBlankLine(33-1);
  ldi      t0,32
  sto      t0,0[sp]
  jsr      lk1,_DBGBlankLine
  add      sp,sp,8
.00085:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  ldo      s2,16[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,96
  ret    
	.type	_DBGScrollUp,@function
	.size	_DBGScrollUp,$-_DBGScrollUp


#--}
 
#{++ _DBGIncrementCursorRow

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_DBGIncrementCursorRow:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  lea      gp,_data_start
# if (DBGCursorRow < 33 - 1) {
  ldwu     t0,_DBGCursorRow[gp]
  sgt      t1,t0,31
  bne      t1,r0,.00101
# DBGCursorRow++;
  ldw      t0,_DBGCursorRow[gp]
  add      t0,t0,1
  stw      t0,_DBGCursorRow[gp]
# DBGUpdateCursorPos();
  jsr      lk1,_DBGUpdateCursorPos
.00100:
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,96
  ret    
.00101:
# DBGScrollUp();
  jsr      lk1,_DBGScrollUp
# DBGCursorRow--;
  ldw      t0,_DBGCursorRow[gp]
  sub      t0,t0,1
  stw      t0,_DBGCursorRow[gp]
  bra      .00100
	.type	_DBGIncrementCursorRow,@function
	.size	_DBGIncrementCursorRow,$-_DBGIncrementCursorRow


#--}
 
#{++ _DBGIncrementCursorPos

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_DBGIncrementCursorPos:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  lea      gp,_data_start
# if (DBGCursorCol < 64) {
  ldwu     t0,_DBGCursorCol[gp]
  sgt      t1,t0,63
  bne      t1,r0,.00115
# DBGCursorCol++;
  ldw      t0,_DBGCursorCol[gp]
  add      t0,t0,1
  stw      t0,_DBGCursorCol[gp]
# DBGUpdateCursorPos();
  jsr      lk1,_DBGUpdateCursorPos
.00114:
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,96
  ret    
.00115:
# DBGCursorCol = 0;
  stw      r0,_DBGCursorCol[gp]
# DBGIncrementCursorRow();
  jsr      lk1,_DBGIncrementCursorRow
  bra      .00114
	.type	_DBGIncrementCursorPos,@function
	.size	_DBGIncrementCursorPos,$-_DBGIncrementCursorPos


#--}
  
#{++ _DBGDisplayChar

	.align 4

	.sdreg	61
  #====================================================
# Basic Block 0
#====================================================
_DBGDisplayChar:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,32
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  lea      gp,_data_start
  sto      s0,0[sp]
  sto      s1,8[sp]
  sto      s2,16[sp]
  ldw      s2,96[fp]
# switch(ch) {
  ldi      t0,144
  bge      s2,t0,.00278
  blt      s2,t0,.00279
# if (DBGCursorRow > 0) {
  ldwu     t0,_DBGCursorRow[gp]
  bge      r0,t0,.00280
# DBGCursorRow--;
  ldw      t0,_DBGCursorRow[gp]
  sub      t0,t0,1
  stw      t0,_DBGCursorRow[gp]
# DBGUpdateCursorPos();
  jsr      lk1,_DBGUpdateCursorPos
.00280:
  bra      .00229
.00278:
  ldi      t0,146
  bge      s2,t0,.00282
  blt      s2,t0,.00283
# if (DBGCursorRow < 33-1) {
  ldwu     t0,_DBGCursorRow[gp]
  sgt      t1,t0,31
  bne      t1,r0,.00284
# DBGCursorRow++;
  ldw      t0,_DBGCursorRow[gp]
  add      t0,t0,1
  stw      t0,_DBGCursorRow[gp]
# DBGUpdateCursorPos();
  jsr      lk1,_DBGUpdateCursorPos
.00284:
  bra      .00229
.00282:
  ldi      t0,147
  bge      s2,t0,.00286
  blt      s2,t0,.00287
# if (DBGCursorCol > 0) {
  ldwu     t0,_DBGCursorCol[gp]
  bge      r0,t0,.00288
# DBGCursorCol--;
  ldw      t0,_DBGCursorCol[gp]
  sub      t0,t0,1
  stw      t0,_DBGCursorCol[gp]
# DBGUpdateCursorPos();
  jsr      lk1,_DBGUpdateCursorPos
.00288:
  bra      .00229
.00286:
  ldi      t0,148
  bne      s2,t0,.00292
# if (DBGCursorCol==0)
  ldwu     t0,_DBGCursorCol[gp]
  bnez     t0,.00293
# DBGCursorRow = 0;
  stw      r0,_DBGCursorRow[gp]
.00293:
  bra      .00229
.00292:
  ldi      t0,153
  bne      s2,t0,.00229
# p = (int *)0xFFD00000 + DBGCursorRow * 64;
  ldwu     t3,_DBGCursorRow[gp]
  sll      t2,t3,6
  sll      t1,t2,3
  add      s1,t1,4291821568
  bra      .00229
.00287:
  ldi      t0,147
  bne      s2,t0,.00297
# if (DBGCursorCol > 0) {
  ldwu     t0,_DBGCursorCol[gp]
  bge      r0,t0,.00298
# DBGCursorCol--;
  ldw      t0,_DBGCursorCol[gp]
  sub      t0,t0,1
  stw      t0,_DBGCursorCol[gp]
# DBGUpdateCursorPos();
  jsr      lk1,_DBGUpdateCursorPos
.00298:
  bra      .00229
.00297:
  ldi      t0,148
  bne      s2,t0,.00229
# if (DBGCursorCol==0)
  ldwu     t0,_DBGCursorCol[gp]
  bnez     t0,.00300
# DBGCursorRow = 0;
  stw      r0,_DBGCursorRow[gp]
.00300:
  bra      .00229
.00283:
  ldi      t0,145
  bne      s2,t0,.00229
# if (DBGCursorCol < 64 - 1) {
  ldwu     t0,_DBGCursorCol[gp]
  sgt      t1,t0,62
  bne      t1,r0,.00305
# DBGCursorCol++;
  ldw      t0,_DBGCursorCol[gp]
  add      t0,t0,1
  stw      t0,_DBGCursorCol[gp]
# DBGUpdateCursorPos();
  jsr      lk1,_DBGUpdateCursorPos
.00305:
  bra      .00229
.00279:
  bge      s2,10,.00307
  blt      s2,10,.00308
# DBGCursorCol = 0;
  stw      r0,_DBGCursorCol[gp]
  bra      .00229
.00307:
  bge      s2,12,.00309
  blt      s2,12,.00310
# DBGClearScreen();
  jsr      lk1,_DBGClearScreen
  bra      .00229
.00309:
  bne      s2,13,.00229
# DBGCursorCol = 0;
  stw      r0,_DBGCursorCol[gp]
  bra      .00229
.00310:
  bne      s2,12,.00316
# DBGClearScreen();
  jsr      lk1,_DBGClearScreen
  bra      .00229
.00316:
  ldi      t0,13
  bne      s2,t0,.00229
# DBGCursorCol = 0;
  stw      r0,_DBGCursorCol[gp]
  bra      .00229
.00308:
  bne      s2,8,.00319
# if (DBGCursorCol > 0) {
  ldwu     t0,_DBGCursorCol[gp]
  bge      r0,t0,.00320
# DBGCursorCol--;
  ldw      t0,_DBGCursorCol[gp]
  sub      t0,t0,1
  stw      t0,_DBGCursorCol[gp]
# p = (int *)0xFFD00000 + DBGCursorRow * 64;
  ldwu     t3,_DBGCursorRow[gp]
  sll      t2,t3,6
  sll      t1,t2,3
  add      s1,t1,4291821568
# for (nn = DBGCursorCol; nn < 64-1; nn++) {
  ldwu     t0,_DBGCursorCol[gp]
  sxw      s0,t0
  sgt      t0,s0,62
  bne      t0,r0,.00323
.00322:
# p[nn] = p[nn+1];
  sll      t0,s0,3
  add      t2,s0,1
  sll      t1,t2,3
  ldo      t2,[t1+s1]
  sto      t2,[t0+s1]
  add      s0,s0,1
  slt      t0,s0,63
  bne      t0,r0,.00322
.00323:
# p[nn] = DBGAttr | ' ';
  sll      t0,s0,3
  ldo      t2,_DBGAttr[gp]
  or       t1,t2,32
  sto      t1,[t0+s1]
.00320:
  bra      .00229
.00319:
  bne      s2,9,.00229
# for (nn = 0; nn < 32; nn++) {
  mov      s0,r0
  sgt      t0,s0,31
  bne      t0,r0,.00327
.00326:
# if (DBGCursorCol < tabstops[nn]) {
  ldwu     t0,_DBGCursorCol[gp]
  sll      t1,s0,1
  lea      t2,_tabstops[gp]
  ldw      t1,[t1+t2]
  bge      t0,t1,.00329
# DBGCursorCol = tabstops[nn];
  sll      t0,s0,1
  lea      t1,_tabstops[gp]
  ldw      t2,[t0+t1]
  stw      t2,_DBGCursorCol[gp]
# break;
  bra      .00327
.00329:
  add      s0,s0,1
  slt      t0,s0,32
  bne      t0,r0,.00326
.00327:
.00229:
.00228:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  ldo      s2,16[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,104
  ret    
	.type	_DBGDisplayChar,@function
	.size	_DBGDisplayChar,$-_DBGDisplayChar


#--}
 
#{++ _DBGCRLF

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_DBGCRLF:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  csrrw    t0,r0,12546
  sto      t0,16[fp]
# DBGDisplayChar('\r');
  ldi      t0,13
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
# DBGDisplayChar('\n');
  ldi      t0,10
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
.00340:
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,96
  ret    
	.type	_DBGCRLF,@function
	.size	_DBGCRLF,$-_DBGCRLF


#--}
  
#{++ _DBGDisplayString

	.align 4

	.sdreg	61
 #====================================================
# Basic Block 0
#====================================================
_DBGDisplayString:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,16
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  sto      s0,0[sp]
  sto      s1,8[sp]
  ldo      s0,96[fp]
# while (ch = *s) { DBGDisplayChar(ch); s++; }
  ldw      s1,[s0]
  beqz     s1,.00354
.00353:
  sto      s1,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
  add      s0,s0,2
  ldw      s1,[s0]
  sne      t0,s1,r0
  bne      t0,r0,.00353
.00354:
.00352:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t1,16[fp]
  csrrw    r0,t1,12546
  add      sp,sp,104
  ret    
	.type	_DBGDisplayString,@function
	.size	_DBGDisplayString,$-_DBGDisplayString


#--}
  
#{++ _DBGDisplayAsciiString

	.align 4

	.sdreg	61
 #====================================================
# Basic Block 0
#====================================================
_DBGDisplayAsciiString:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,16
  csrrw    t0,r0,12546
  sto      t0,16[fp]
  sto      s0,0[sp]
  sto      s1,8[sp]
  ldo      s0,96[fp]
# while (ch = *s) { DBGDisplayChar(ch); s++; }
  ldw      s1,[s0]
  beqz     s1,.00368
.00367:
  sto      s1,0[sp]
  jsr      lk1,_DBGDisplayChar
  add      sp,sp,8
  add      s0,s0,2
  ldw      s1,[s0]
  sne      t0,s1,r0
  bne      t0,r0,.00367
.00368:
.00366:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t1,16[fp]
  csrrw    r0,t1,12546
  add      sp,sp,104
  ret    
	.type	_DBGDisplayAsciiString,@function
	.size	_DBGDisplayAsciiString,$-_DBGDisplayAsciiString


#--}
  
#{++ _DBGDisplayStringCRLF

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_DBGDisplayStringCRLF:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  csrrw    t0,r0,12546
  sto      t0,16[fp]
# DBGDisplayString(s);
  ldo      t0,96[fp]
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayString
  add      sp,sp,8
# DBGCRLF();
  jsr      lk1,_DBGCRLF
.00378:
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,104
  ret    
	.type	_DBGDisplayStringCRLF,@function
	.size	_DBGDisplayStringCRLF,$-_DBGDisplayStringCRLF


#--}
  
#{++ _DBGDisplayAsciiStringCRLF

	.align 4

	.sdreg	61
#====================================================
# Basic Block 0
#====================================================
_DBGDisplayAsciiStringCRLF:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  csrrw    t0,r0,12546
  sto      t0,16[fp]
# DBGDisplayAsciiString(s);
  ldo      t0,96[fp]
  sto      t0,0[sp]
  jsr      lk1,_DBGDisplayAsciiString
  add      sp,sp,8
# DBGCRLF();
  jsr      lk1,_DBGCRLF
.00388:
  mov      sp,fp
  ldo      fp,[sp]
  ldo      t0,16[fp]
  csrrw    r0,t0,12546
  add      sp,sp,104
  ret    
	.type	_DBGDisplayAsciiStringCRLF,@function
	.size	_DBGDisplayAsciiStringCRLF,$-_DBGDisplayAsciiStringCRLF


#--}
  
#{++ _DBGHideCursor

	.align 4

	.sdreg	61
  #====================================================
# Basic Block 0
#====================================================
_DBGHideCursor:
  sub      sp,sp,96
  sto      fp,[sp]
  mov      fp,sp
  sub      sp,sp,16
  sto      s0,0[sp]
  sto      s1,8[sp]
# p = (int *)0xFFD17F00;
  ldi      s0,4291919616
# val = p[6];
  ldo      s1,48[s0]
# if (hide) {
  ldo      t0,[r0]
  beqz     t0,.00401
# p[6] = (val & 0xffff0000) | 0xffff;
  and      t1,s1,4294901760
  or       t0,t1,65535
  sto      t0,48[s0]
  bra      .00402
.00401:
# p[6] = (val & 0xffff0000) | 0x00E7;
  and      t1,s1,4294901760
  or       t0,t1,231
  sto      t0,48[s0]
.00402:
.00400:
  ldo      s0,0[sp]
  ldo      s1,8[sp]
  add      sp,sp,8
  ret    
	.type	_DBGHideCursor,@function
	.size	_DBGHideCursor,$-_DBGHideCursor


#--}

	.rodata
	.align	16

	.extern	_mmu_Free512kPage
	.extern	_mmu_Alloc8kPage
	.extern	_mmu_alloc
	.extern	_mmu_MapCardMemory
	.extern	_IOFocusNdx
	.extern	_mmu_SetOperateKey
	.extern	_puthexnum
	.extern	_mmu_AllocateMap
	.extern	_mmu_SetMapEntry
	.extern	_mmu_Alloc512kPage
	.extern	_mmu_FreeMap
	.extern	_mmu_Free8kPage
	.extern	_mmu_free
	.extern	_mmu_SetAccessKey
