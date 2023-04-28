# Makefile for STDLIB
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
	abort.asm \
	abs.asm \
	atexit.asm \
	atof.asm \
	atoi.asm \
	atol.asm \
	bsearch.asm \
	calloc.asm \
	div.asm \
	exit.asm \
	free.asm \
	getenv.asm \
	labs.asm \
	ldiv.asm \
	malloc.asm \
	mblen.asm \
	mbstowcs.asm \
	mbtowc.asm \
	qsort.asm \
	rand.asm \
	realloc.asm \
	srand.asm \
	strtod.asm \
	strtol.asm \
	strtoul.asm \
	system.asm \
	wcstombs.asm \
	wctomb.asm \
	xgetmem.asm \
	xmbtowc.asm \
	xstod.asm \
	xstoul.asm
           
OUT = \
	abort.o \
	abs.o \
	atexit.o \
	atof.o \
	atoi.o \
	atol.o \
	bsearch.o \
	calloc.o \
	div.o \
	exit.o \
	free.o \
	getenv.o \
	labs.o \
	ldiv.o \
	malloc.o \
	mblen.o \
	mbstowcs.o \
	mbtowc.o \
	qsort.o \
	rand.o \
	realloc.o \
	srand.o \
	strtod.o \
	strtol.o \
	strtoul.o \
	system.o \
	wcstombs.o \
	wctomb.o \
	xgetmem.o \
	xmbtowc.o \
	xstod.o \
	xstoul.o

all:	$(OUT)
	echo "made STDLIB"

STDLIB:	$(OUT)
	echo "made STDLIB"

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
