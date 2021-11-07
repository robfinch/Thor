#
PATH = $PATH;D:\cores2021\Thor\software\CC64\cc64\cc64\debug;"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\bin\Hostx64\x64\bin\Hostx64\x64\"
INC = D:\cores2021\Thor\software\source\;D:\cores2021\Thor\software\FMTK\source\kernel\;D:\cores2021\Thor\software\inc\
INCLUDE = D:\cores2021\Thor\software\source\;D:\cores2021\Thor\software\FMTK\source\kernel\;D:\cores2021\Thor\software\inc\
CXX = vbccppc
CFLAGS2 = -c99 -ID:\cores2021\Thor\software\inc\ -O=31
CFLAGS = -w -S -fno-exceptions

#

BIOS:
	del boot_rom.bin
	del boot_rom.lst
#	cc64 $(CFLAGS) SieveOfE.c
#	cc64 $(CFLAGS) rom_bios.c
#	cc64 $(CFLAGS) os_stub.c
#	cc64 $(CFLAGS) ..\fmtk\source\kernel\DBGConsole.c
#	copy rom_bios_start.asm +rom_bios.asm +SieveOfE.asm +os_stub.asm +..\fmtk\source\kernel\DBGConsole.asm build.asm
#	secsrt build.asm
#	vasmppc_std_win32 -L SieveOfE.lst -Fbin SieveOfE.asm
#	vasmppc_std_win32 -Fbin -L SieveOfE.lst SieveOfE.asm -o Sieve.out
#	vasmppc_std_win32 -Fbin -L rom_bios.lst rom_bios_start.asm -o rom_bios.bin
#	vasmppc_std_win32 -maxerrors=0 -Felf -L build.lst secsorted.asm -o rom_bios.elf
#	vlink -T rom_bios.cmd -brawbin1 -multibase rom_bios.elf
#	ren a.out rom_bios.bin
#	bin2ver rom_bios.bin 32

#	vasmppc_std_win32 -L SieveOfE.lst -Fbin SieveOfE.asm
#	vasmppc_std_win32 -L rom_bios.lst -Fbin rom_bios_start.asm
	vasmThor_std_win32.exe.lnk -abits=23 -Fvobj -L boot_rom.lst boot_rom.t64 -o boot_rom.o
	vlink -T boot_rom.cmd -brawbin1 boot_rom.o -o boot_rom.bin
	bin2ver boot_rom.bin 128


