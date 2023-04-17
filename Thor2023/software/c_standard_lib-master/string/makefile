# Makefile for STRING
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
	memchr.t64 \
	memcmp.t64 \
	memcpy.t64 \
	memmove.t64 \
	memset.t64 \
	strcat.t64 \
	strchr.t64 \
	strcmp.t64 \
	strcoll.t64 \
	strcpy.t64 \
	strcspn.t64 \
	strerror.t64 \
	strlen.t64 \
	strncat.t64 \
	strncpy.t64 \
	strpbrk.t64 \
	strrchr.t64 \
	strspn.t64 \
	strstr.t64 \
	strtok.t64 \
	strxfrm.t64 \
	xstrxfrm.t64

OUT = \
	memchr.o \
	memcmp.o \
	memcpy.o \
	memmove.o \
	memset.o \
	strcat.o \
	strchr.o \
	strcmp.o \
	strcoll.o \
	strcpy.o \
	strcspn.o \
	strerror.o \
	strlen.o \
	strncat.o \
	strncpy.o \
	strpbrk.o \
	strrchr.o \
	strspn.o \
	strstr.o \
	strtok.o \
	strxfrm.o \
	xstrxfrm.o

all:	$(OUT)
	echo "made STRING"
           
STRING:	$(OUT)
	echo "made STRING"

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
