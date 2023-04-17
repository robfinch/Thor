# Makefile for LOCALE
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

ASMS = \
	localeco.t64 \
	setlocal.t64 \
	xdefloc.t64 \
	xfmtval.t64 \
	xfreeloc.t64 \
	xgetloc.t64 \
	xloctab.t64 \
	xlocterm.t64 \
	xmakeloc.t64 \
	xreadloc.t64 \
	xsetloc.t64 \
	xstate.t64
	
OUT = \
	localeco.o \
	setlocal.o \
	xdefloc.o \
	xfmtval.o \
	xfreeloc.o \
	xgetloc.o \
	xloctab.o \
	xlocterm.o \
	xmakeloc.o \
	xreadloc.o \
	xsetloc.o \
	xstate.o
	
all:	$(OUT)
	echo "made LOCALE"

LOCALE:	$(OUT)
	echo "made LOCALE"

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

