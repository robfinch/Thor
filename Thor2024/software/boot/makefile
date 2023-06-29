#
PATH = $PATH;F:\cores2023\Thor\software\CC64\cc64\cc64\debug;"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\bin\Hostx64\x64\bin\Hostx64\x64\"
INC = F:\cores2023\Thor\software\source\;F:\cores2023\Thor\software\Femtiki\source\kernel\;F:\cores2023\Thor\software\inc\
INCLUDE = D:\cores2023\Thor\software\source\;F:\cores2023\Thor\software\Femtiki\source\kernel\;F:\cores2023\Thor\software\inc\
FPPINC  = D:\cores2023\Thor\software\source\;F:\cores2023\Thor\software\Femtiki\source\kernel\;F:\cores2023\Thor\software\inc\
CXX = cc64
#CXX = opt
CFLAGS2 = -c99 -ID:\cores2023\Thor\software\inc\ -O=31
#CFLAGS = -w -S -fno-exceptions
CFLAGS = -w -fno-exceptions


#

BIOS:
	del boot_rom.bin
	del boot_rom.lst
	cc64 $(CFLAGS) SIEVE.c
	cc64 $(CFLAGS) printf_again.c
#	cc64 $(CFLAGS) os_stub.c

	vasmThor_std_win32.exe -Fvobj -L boot.lst boot.asm -o boot.o
	vasmThor_std_win32.exe -Fvobj -L serial.lst serial.asm -o serial.o
	vasmThor_std_win32.exe -Fvobj -L fibonacci.lst fibonacci.asm -o fibonacci.o
#	vasmThor_mot_win32.exe -Fvobj -L tlbmiss34.lst tlbmiss34.asm -o tlbmiss34.o
	vasmThor_std_win32.exe -Fvobj -Lbpl=5 -L sieve.lst sieve.asm -o sieve.o
	vasmThor_std_win32.exe -Fvobj -Lbpl=5 -L printf_again.lst printf_again.asm -o printf_again.o
	vasmThor_std_win32.exe -Fvobj -Lbpl=5 -L ..\cc64rt\source\__store.lst ..\cc64rt\source\__store.asm -o __store.o
	vasmThor_std_win32.exe -Fvobj -Lbpl=5 -L ..\cc64rt\source\__load.lst ..\cc64rt\source\__load.asm -o __load.o
#	vasmThor_std_win32.exe -Fvobj -L LEDTest.lst LEDTest.asm -o LEDTest.o
#	vasmrf68000_mot_win32.exe -Fvobj -L cputest.lst cputest.asm -o cputest.o
#	vasmrf68000_mot_win32.exe -Fvobj -L boot.lst boot.asm -o boot.o -m68010
#	vasmrfPhoenix_std_win32.exe -Fvobj -L add.lst add.asm -o add.o
	vlink -T rom_bios.cmd -brawbin1 boot.o serial.o -o boot.bin
	vlink -T rom_bios.cmd -brawbin1 fibonacci.o -o fibonacci.bin
#	vlink -T rom_bios.cmd -brawbin1 __store.o __load.o printf_again.o sieve.o -o sieve.bin
#	vlink -T rom_bios.cmd -brawbin1 LEDTest.o -o LEDTest.bin
#	vlink -T rom_bios.cmd -brawbin1 cputest.o -o cputest.bin
#	vlink -T rom_bios.cmd -bsrec37 boot.o -o boot.s37
#	vlink -T rom_bios.cmd -brawbin1 boot.o -o boot.bin
#	vlink -T rom_bios.cmd -brawbin1 add.o -o add.bin
#	bin2ver fibonacci.bin 128 m
#	bin2ver fibonacci.bin 128
	bin2ver boot.bin 128 m
	bin2ver boot.bin 128
#	bin2ver LEDTest.bin 32 m
#	bin2ver boot.bin 32 m
#	bin2ver cputest.bin 32 m
#	bin2ver add.bin 128

