# Makefile for STDIO
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

ASMS =     clearerr.t64 \
           fclose.t64 \
           feof.t64 \
           fflush.t64 \
           fgetc.t64 \
           fgetpos.t64 \
           fgets.t64 \
           fopen.t64 \
           fprintf.t64 \
           fputc.t64 \
           fputs.t64 \
           fread.t64 \
           freopen.t64 \
           fscanf.t64 \
           fseek.t64 \
           fsetpos.t64 \
           ftell.t64 \
           fwrite.t64 \
           getc.t64 \
           getchar.t64 \
           gets.t64 \
           perror.t64 \
           printf.t64 \
           putc.t64 \
           putchar.t64 \
           puts.t64 \
           rename.t64 \
           remove.t64 \
           rewind.t64 \
           scanf.t64 \
           setbuf.t64 \
           setvbuf.t64 \
           sprintf.t64 \
           sscanf.t64 \
           tmpfile.t64 \
           tmpnam.t64 \
           ungetc.t64 \
           vfprintf.t64 \
           vprintf.t64 \
           vsprintf.t64 \
           xfgpos.t64 \
           xfiles.t64 \
           xfopen.t64 \
           xfoprep.t64 \
           xfrprep.t64 \
           xfspos.t64 \
           xfwprep.t64 \
           xgenld.t64 \
           xgetfld.t64 \
           xgetfloa.t64 \
           xgetint.t64 \
           xldtob.t64 \
           xlitob.t64 \
           xprintf.t64 \
           xputfld.t64 \
           xscanf.t64

OUT =     clearerr.o \
           fclose.o \
           feof.o \
           fflush.o \
           fgetc.o \
           fgetpos.o \
           fgets.o \
           fopen.o \
           fprintf.o \
           fputc.o \
           fputs.o \
           fread.o \
           freopen.o \
           fscanf.o \
           fseek.o \
           fsetpos.o \
           ftell.o \
           fwrite.o \
           getc.o \
           getchar.o \
           gets.o \
           perror.o \
           printf.o \
           putc.o \
           putchar.o \
           puts.o \
           rename.o \
           remove.o \
           rewind.o \
           scanf.o \
           setbuf.o \
           setvbuf.o \
           sprintf.o \
           sscanf.o \
           tmpfile.o \
           tmpnam.o \
           ungetc.o \
           vfprintf.o \
           vprintf.o \
           vsprintf.o \
           xfgpos.o \
           xfiles.o \
           xfopen.o \
           xfoprep.o \
           xfrprep.o \
           xfspos.o \
           xfwprep.o \
           xgenld.o \
           xgetfld.o \
           xgetfloa.o \
           xgetint.o \
           xldtob.o \
           xlitob.o \
           xprintf.o \
           xputfld.o \
           xscanf.o
           
all:	$(OUT)
	echo "made STDIO"

STDIO:	$(OUT)
	echo "made STDIO"

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
