# Makefile for MATH
#
PATH = $PATH;F:\Cores2023\Thor\software\cc64\cc64\x64\debug\;F:\Cores2023\Thor\software\FPP64\FPP64\x64\debug\;"F:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133\bin\Hostx64\x64"
FPPINC = f:\Cores2023\Thor\software\c_standard_lib-master\_HEADERS\;f:\Cores2023\Thor\software\source\;f:\Cores2023\Thor\software\Femtiki\source\kernel\
INC = f:\Cores2023\Thor\software\c_standard_lib-master\_HEADERS\;f:\Cores2023\Thor\software\source\;f:\Cores2023\Thor\software\Femtiki\source\kernel\
INCLUDE = f:\Cores2023\Thor\software\c_standard_lib-master\_HEADERS\;f:\Cores2023\Thor\software\source\;f:\Cores2023\Thor\software\Femtiki\source\kernel\
#CCX = cc64
CFLAGS = -w -S -fno-exceptions
APPINC = d:\Cores5\FT64\v7\software\source\;d:\Cores5\FT64\v7\software\FMTK\source\kernel\;d:\Cores5\FT64\v7\software\inc
#CCX = cc64
CFLAGS = -w -S -fno-exceptions
#CXX = cc64 -w -S 
AFLAGS = -Fvobj -Lbpl=5

OUT =     acos.o \
           asin.o \
           atan.o \
           atan2.o \
           ceil.o \
           cos.o \
           cosh.o \
           exp.o \
           fabs.o \
           floor.o \
           fmod.o \
           frexp.o \
           ldexp.o \
           log.o \
           log10.o \
           modf.o \
           pow.o \
           sin.o \
           sinh.o \
           sqrt.o \
           tan.o \
           tanh.o \
           xasin.o \
           xatan.o \
           xdint.o \
           xdnorm.o \
           xdscale.o \
           xdtento.o \
           xdtest.o \
           xdunscal.o \
           xexp.o \
           xldunsca.o \
           xlog.o \
           xpoly.o \
           xsin.o \
           xvalues.o

ASMS =     acos.asm \
           asin.asm \
           atan.asm \
           atan2.asm \
           ceil.asm \
           cos.asm \
           cosh.asm \
           exp.asm \
           fabs.asm \
           floor.asm \
           fmod.asm \
           frexp.asm \
           ldexp.asm \
           log.asm \
           log10.asm \
           modf.asm \
           pow.asm \
           sin.asm \
           sinh.asm \
           sqrt.asm \
           tan.asm \
           tanh.asm \
           xasin.asm \
           xatan.asm \
           xdint.asm \
           xdnorm.asm \
           xdscale.asm \
           xdtento.asm \
           xdtest.asm \
           xdunscal.asm \
           xexp.asm \
           xldunsca.asm \
           xlog.asm \
           xpoly.asm \
           xsin.asm \
           xvalues.asm

all:	$(OUT)
	echo "made MATH"

MATH:	$(OUT)
	echo "made MATH"

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


