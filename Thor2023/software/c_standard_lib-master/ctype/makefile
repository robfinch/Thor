# Makefile for CTYPE
#
PATH = $PATH;F:\Cores2023\Thor\software\cc64\cc64\x64\debug\;F:\Cores2023\Thor\software\FPP64\FPP64\x64\debug\;"F:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133\bin\Hostx64\x64"
FPPINC = f:\Cores2023\Thor\software\c_standard_lib-master\_HEADERS\;f:\Cores2023\Thor\software\source\;f:\Cores2023\Thor\software\Femtiki\source\kernel\;f:\Cores2023\Thor\software\inc
INC = f:\Cores2023\Thor\software\c_standard_lib-master\_HEADERS\;f:\Cores2023\Thor\software\source\;f:\Cores2023\Thor\software\Femtiki\source\kernel\;f:\Cores2023\Thor\software\inc
INCLUDE = f:\Cores2023\Thor\software\c_standard_lib-master\_HEADERS\;f:\Cores2023\Thor\software\source\;f:\Cores2023\Thor\software\Femtiki\source\kernel\;f:\Cores2023\Thor\software\inc
#CCX = cc64
CFLAGS = -w -S -fno-exceptions
APPINC = d:\Cores5\FT64\v7\software\source\;d:\Cores5\FT64\v7\software\FMTK\source\kernel\;d:\Cores5\FT64\v7\software\inc
#CCX = cc64
CFLAGS = -w -S -fno-exceptions
#CXX = cc64 -w -S 
AFLAGS = -Fvobj -Lbpl=5

ASMS =     isalnum.asm \
           isalpha.asm \
           iscntrl.asm \
           isdigit.asm \
           isgraph.asm \
           islower.asm \
           isprint.asm \
           ispunct.asm \
           isspace.asm \
           isupper.asm \
           isxdigit.asm \
           tolower.asm \
           toupper.asm \
           xctype.asm \
           xtolower.asm \
           xtoupper.asm

OUT =     isalnum.o \
           isalpha.o \
           iscntrl.o \
           isdigit.o \
           isgraph.o \
           islower.o \
           isprint.o \
           ispunct.o \
           isspace.o \
           isupper.o \
           isxdigit.o \
           tolower.o \
           toupper.o \
           xctype.o \
           xtolower.o \
           xtoupper.o

ALL:	$(OUT)
	echo "made CTYPE"

CTYPE:	$(OUT)
	echo "made CTYPE"

.c.o:
	cc64 $(CFLAGS) $<
	vasmThor_std_win32 $(AFLAGS) $*.asm -L $*.lst -o $*.o
	
clean:
	del *.o
	del *.lst
	del *.asm
	del *.lis
	del *.c.xml
	del *.fpp
	del *.hir
