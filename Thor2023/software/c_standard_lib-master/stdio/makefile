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

ASMS =     clearerr.asm \
           fclose.asm \
           feof.asm \
           fflush.asm \
           fgetc.asm \
           fgetpos.asm \
           fgets.asm \
           fopen.asm \
           fprintf.asm \
           fputc.asm \
           fputs.asm \
           fread.asm \
           freopen.asm \
           fscanf.asm \
           fseek.asm \
           fsetpos.asm \
           ftell.asm \
           fwrite.asm \
           getc.asm \
           getchar.asm \
           gets.asm \
           perror.asm \
           printf.asm \
           putc.asm \
           putchar.asm \
           puts.asm \
           rename.asm \
           remove.asm \
           rewind.asm \
           scanf.asm \
           setbuf.asm \
           setvbuf.asm \
           sprintf.asm \
           sscanf.asm \
           tmpfile.asm \
           tmpnam.asm \
           ungetc.asm \
           vfprintf.asm \
           vprintf.asm \
           vsprintf.asm \
           xfgpos.asm \
           xfiles.asm \
           xfopen.asm \
           xfoprep.asm \
           xfrprep.asm \
           xfspos.asm \
           xfwprep.asm \
           xgenld.asm \
           xgetfld.asm \
           xgetfloa.asm \
           xgetint.asm \
           xldtob.asm \
           xlitob.asm \
           xprintf.asm \
           xputfld.asm \
           xscanf.asm

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
	vasmThor_std_win32 $(AFLAGS) $*.asm -L $*.lst -o $*.o
	
clean:
	del *.o
	del *.lst
	del *.asm
	del *.lis
	del *.c.xml
	del *.fpp
	del *.hir
