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

ASMS =     acos.t64 \
           asin.t64 \
           atan.t64 \
           atan2.t64 \
           ceil.t64 \
           cos.t64 \
           cosh.t64 \
           exp.t64 \
           fabs.t64 \
           floor.t64 \
           fmod.t64 \
           frexp.t64 \
           ldexp.t64 \
           log.t64 \
           log10.t64 \
           modf.t64 \
           pow.t64 \
           sin.t64 \
           sinh.t64 \
           sqrt.t64 \
           tan.t64 \
           tanh.t64 \
           xasin.t64 \
           xatan.t64 \
           xdint.t64 \
           xdnorm.t64 \
           xdscale.t64 \
           xdtento.t64 \
           xdtest.t64 \
           xdunscal.t64 \
           xexp.t64 \
           xldunsca.t64 \
           xlog.t64 \
           xpoly.t64 \
           xsin.t64 \
           xvalues.t64

all:	$(OUT)
	echo "made MATH"

MATH:	$(OUT)
	echo "made MATH"

.c.o:
	cc64 $(CFLAGS) $<
	vasmThor_std_win32 $(AFLAGS) $*.t64 -L $*.lst -o $*.o
	
clean:
	del *.o
	del *.lst
	del *.t64
	del *.lis
	del *.c.xml
	del *.fpp
	del *.hir


