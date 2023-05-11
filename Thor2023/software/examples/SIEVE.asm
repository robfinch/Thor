       
  
	.text
	.align	0

#{++ _main

	.align 5

	.sdreg	61
	.sd2reg	60
_main:
  sub sp,sp,64
  store.h fp,[sp]
  mov fp,sp
  store.h lr1,32[fp]
  sub sp,sp,144
  lea gp,_start_bss
  lea gp1,_main
  bsr lr2,__store_s0s4
  load.h s0,-16[fp]
  load.h s2,-48[fp]
  load.h s3,-64[fp]
  load.h s4,-32[fp]
  sub sp,sp,16
  lea t0,_main.00001[gp1]
  store.h t0,0[sp]
  bsr _printf
  loadi s1,1
  bgt s1,10,.00027
.00026:
  mov s3,r0
  mov s0,r0
  bgt s0,8190,.00030
.00029:
  loadi t1,1
  store.w t1,_flags[gp+s0*]
.00031:
  add s0,s0,1
  ble s0,8190,.00029
.00030:
  mov s0,r0
  bgt s0,8190,.00033
.00032:
  load.w t0,_flags[gp+s0*]
  beqz t0,.00035
  add t1,s0,s0
  add s4,t1,3
  add s2,s0,s4
  bgt s2,8190,.00038
.00037:
  store.w r0,_flags[gp+s2*]
  add s2,s2,s4
  ble s2,8190,.00037
.00038:
  add s3,s3,1
.00035:
.00034:
  add s0,s0,1
  ble s0,8190,.00032
.00033:
.00028:
  add s1,s1,1
  ble s1,10,.00026
.00027:
  sub sp,sp,32
  lea t0,_main.00002[gp1]
  store.h t0,0[sp]
  store.h s3,16[sp]
  bsr _printf_again
.00025:
  bsr lr2,__load_s0s4
  load.h lr1,32[fp]
  mov sp,fp
  load.h fp,[sp]
  rtd sp,sp,64
	.type	_main,@function
	.size	_main,$-_main


	.bss
	.align	14
	.bss
	.align 4
.lcomm _flags,16382
	.type	_flags,@object
	.size	_flags,16382
#--}

	.rodata
	.align	14

	.align	8


	.type	_main.00001,@object
	.size	_main.00001,30
_main.00001: # 10 iterations

	.2byte	49,48,32,105,116,101,114,97
	.2byte	116,105,111,110,115,10,0
	.type	_main.00002,@object
	.size	_main.00002,24
_main.00002: # %d primes

	.2byte	10,37,100,32,112,114,105,109
	.2byte	101,115,10,0
	.global	_main
	.extern	_start_bss
	.extern	_printf_again
	.extern	_start_rodata
	.global	_flags
	.extern	_start_data
	.extern	_printf
