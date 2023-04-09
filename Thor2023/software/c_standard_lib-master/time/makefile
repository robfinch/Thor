# Makefile for TIME
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

ASMS = \
	asctime.t64 \
	clock.t64 \
	ctime.t64 \
	difftime.t64 \
	gmtime.t64 \
	localtim.t64 \
	mktime.t64 \
	strftime.t64 \
	time.t64 \
	xgentime.t64 \
	xgetdst.t64 \
	xgettime.t64 \
	xgetzone.t64 \
	xisdst.t64 \
	xstrftim.t64 \
	xttotm.t64
           
OUT = \
	asctime.o \
	clock.o \
	ctime.o \
	difftime.o \
	gmtime.o \
	localtim.o \
	mktime.o \
	strftime.o \
	time.o \
	xgentime.o \
	xgetdst.o \
	xgettime.o \
	xgetzone.o \
	xisdst.o \
	xstrftim.o \
	xttotm.o
           
all:	$(OUT)
	echo "made TIME"

TIME:	$(ASMS)
	echo "made TIME"

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
