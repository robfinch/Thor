
# used to create vbcc, vc and ucpp
#CC = gcc -std=c9x -g -DHAVE_AOS4 #-fsanitize=address #-DHAVE_ECPP -DHAVE_MISRA 
#LDFLAGS = -lm
LDFLAGS =
TARGET=Thor2022
CC = cl -DHAVE_AOS4 #-DHAVE_ECPP -DHAVE_MISRA -Imachines\$(TARGET)

# native version; used to create dtgen
NCC = $(CC)
NLDFLAGS = $(LDFLAGS)

all: bin\vc.exe bin\vprof.exe bin\vbcc$(TARGET).exe #bin\vcpp

vbccs.exe: bin\vbccs$(TARGET).obj

bin\vc.exe: frontend\vc.c
	$(CC) frontend\vc.c /Fo bin\vc.exe $(LDFLAGS)

bin\vprof.exe: vprof\vprof.c
	$(CC) vprof\vprof.c /Fo bin\vprof.exe $(LDFLAGS)

doc\vbcc.pdf:
	texi2dvi --pdf doc\vbcc.texi
	rm -f vbcc.cp vbcc.fn vbcc.vr vbcc.tp vbcc.ky vbcc.pg vbcc.toc \
	      vbcc.aux vbcc.log

doc\vbcc.html:
	(cd doc;texi2html -split=chapter -nosec_nav -frames vbcc.texi)
	sed -e s\vbcc_13\vbcc_1\ <doc\vbcc_frame.html >doc\vbcc.html

vcppobjs = vcpp\cpp.obj vcpp\eval.obj vcpp\getopt.obj vcpp\hideset.obj vcpp\include.obj \
	   vcpp\lex.obj vcpp\macro.obj vcpp\nlist.obj vcpp\tokens.obj vcpp\unix.obj

_vbcc.tar.gz:
	(cd ..;tar zcvf vbcc.tar.gz --exclude=*\dt.c --exclude=*\dt.h vbcc\Makefile vbcc\bin\.dummy vbcc\*.[ch] vbcc\datatypes\*.[ch] vbcc\doc\*.texi vbcc\frontend\vc.c vbcc\machines\*\*.[ch] vbcc\machines\*\machine.dt vbcc\machines\*\schedule.[ch] vbcc\machines\*\compress.[ch] vbcc\ucpp\*.[ch] vbcc\ucpp\README vbcc\vprof\vprof.c vbcc\vsc\vsc.[ch] vbcc\vcpr\vcpr.[ch])

bin\osekrm.exe: osekrm.c
	$(CC) osekrm.c /Fo"bin\osekrm.exe"

dist: bin\osekrm
	mv supp.h t1
	mv supp.c t2
	mv main.c t3
	mv machines\ppc\machine.c t4
	mv declaration.c t5
	mv flow.c t6
	mv ic.c t7
	mv parse_expr.c t8
	mv statements.c t9
	mv rd.c t10
	mv type_expr.c t11
	bin\osekrm <t1 >supp.h
	bin\osekrm <t2 >supp.c
	bin\osekrm <t3 >main.c
	bin\osekrm <t4 >machines\ppc\machine.c
	bin\osekrm <t5 >declaration.c
	bin\osekrm <t6 >flow.c
	bin\osekrm <t7 >ic.c
	bin\osekrm <t8 >parse_expr.c
	bin\osekrm <t9 >statements.c
	bin\osekrm <t10 >rd.c
	bin\osekrm <t11 >type_expr.c
	make _vbcc.tar.gz
	mv t1 supp.h
	mv t2 supp.c
	mv t3 main.c
	mv t4 machines\ppc\machine.c
	mv t5 declaration.c
	mv t6 flow.c
	mv t7 ic.c
	mv t8 parse_expr.c
	mv t9 statements.c
	mv t10 rd.c
	mv t11 type_expr.c	

bin\vcpp: $(vcppobjs)
	$(CC) $(LDFLAGS) $(vcppobjs) /Fo"bin\vcpp.exe"

vcpp\cpp.obj: vcpp\cpp.c vcpp\cpp.h
	$(CC) -c -Ivcpp vcpp\cpp.c /Fo"vcpp\cpp.obj"

vcpp\eval.obj: vcpp\eval.c vcpp\cpp.h
	$(CC) -c -Ivcpp vcpp\eval.c /Fo"vcpp\eval.obj"

vcpp\getopt.obj: vcpp\getopt.c
	$(CC) -c -Ivcpp vcpp\getopt.c /Fo"vcpp\getopt.obj"

vcpp\hideset.obj: vcpp\hideset.c vcpp\cpp.h
	$(CC) -c -Ivcpp vcpp\hideset.c /Fo"vcpp\hideset.obj"

vcpp\include.obj: vcpp\include.c vcpp\cpp.h
	$(CC) -c -Ivcpp vcpp\include.c /Fo"vcpp\include.obj"

vcpp\lex.obj: vcpp\lex.c vcpp\cpp.h
	$(CC) -c -Ivcpp vcpp\lex.c /Fo"vcpp\lex.obj"

vcpp\macro.obj: vcpp\macro.c vcpp\cpp.h
	$(CC) -c -Ivcpp vcpp\macro.c /Fo"vcpp\macro.obj"

vcpp\nlist.obj: vcpp\nlist.c vcpp\cpp.h
	$(CC) -c -Ivcpp vcpp\nlist.c /Fo"vcpp\nlist.obj"

vcpp\tokens.obj: vcpp\tokens.c vcpp\cpp.h
	$(CC) -c -Ivcpp vcpp\tokens.c /Fo"vcpp\tokens.obj"

vcpp\unix.obj: vcpp\unix.c vcpp\cpp.h
	$(CC) -c -Ivcpp vcpp\unix.c /Fo"vcpp\unix.obj"

TRGDIR = machines\$(TARGET)

bobjects = $(TRGDIR)\main.obj $(TRGDIR)\vars.obj $(TRGDIR)\declaration.obj \
	   $(TRGDIR)\parse_expr.obj $(TRGDIR)\type_expr.obj $(TRGDIR)\ic.obj \
	   $(TRGDIR)\machine.obj $(TRGDIR)\statements.obj \
	   $(TRGDIR)\supp.obj $(TRGDIR)\dt.obj \
           $(TRGDIR)\assert.obj $(TRGDIR)\cpp.obj $(TRGDIR)\hash.obj \
           $(TRGDIR)\lexer.obj $(TRGDIR)\macro.obj $(TRGDIR)\mem.obj \
           $(TRGDIR)\eval.obj
#           $(TRGDIR)\AdjList.obj $(TRGDIR)\DUChain.obj \
#           $(TRGDIR)\ICodeInsertion.obj $(TRGDIR)\NodeList.obj \
#           $(TRGDIR)\RAllocMain.obj $(TRGDIR)\Web.obj

fobjects = $(TRGDIR)\opt.obj $(TRGDIR)\av.obj $(TRGDIR)\rd.obj $(TRGDIR)\regs.obj \
	   $(TRGDIR)\flow.obj $(TRGDIR)\cse.obj $(TRGDIR)\cp.obj $(TRGDIR)\loop.obj \
	   $(TRGDIR)\alias.obj $(TRGDIR)\range.obj $(bobjects)

sobjects = $(TRGDIR)\opts.obj $(TRGDIR)\regss.obj $(bobjects)

tasm	 = $(TRGDIR)\supp.obj $(TRGDIR)\tasm.obj $(TRGDIR)\dt.obj \
	   $(TRGDIR)\opt.obj $(TRGDIR)\av.obj $(TRGDIR)\rd.obj $(TRGDIR)\regs.obj \
	   $(TRGDIR)\flow.obj $(TRGDIR)\cse.obj $(TRGDIR)\cp.obj $(TRGDIR)\loop.obj \
	   $(TRGDIR)\alias.obj $(TRGDIR)\machine.obj

mbasic	 = $(TRGDIR)\supp.obj $(TRGDIR)\mbasic.obj $(TRGDIR)\dt.obj \
	   $(TRGDIR)\opt.obj $(TRGDIR)\av.obj $(TRGDIR)\rd.obj $(TRGDIR)\regs.obj \
	   $(TRGDIR)\flow.obj $(TRGDIR)\cse.obj $(TRGDIR)\cp.obj $(TRGDIR)\loop.obj \
	   $(TRGDIR)\alias.obj $(TRGDIR)\machine.obj

minicomp	 = $(TRGDIR)\supp.obj $(TRGDIR)\minicompg.tab.obj $(TRGDIR)\minicomp.obj $(TRGDIR)\dt.obj \
	   $(TRGDIR)\opt.obj $(TRGDIR)\av.obj $(TRGDIR)\rd.obj $(TRGDIR)\regs.obj \
	   $(TRGDIR)\flow.obj $(TRGDIR)\cse.obj $(TRGDIR)\cp.obj $(TRGDIR)\loop.obj \
	   $(TRGDIR)\alias.obj $(TRGDIR)\machine.obj

vscobjects = $(TRGDIR)\vsc.obj $(TRGDIR)\schedule.obj

vcprobjects = $(TRGDIR)\vcpr.obj $(TRGDIR)\compress.obj

bin\vbcc$(TARGET).exe: $(fobjects)
	$(CC) $(LDFLAGS) $(fobjects) /Fobin\vbcc$(TARGET).exe

bin\vbccs$(TARGET).exe: $(sobjects)
	$(CC) $(LDFLAGS) $(sobjects) /Fobin\vbccs$(TARGET).exe

bin\vsc$(TARGET).exe: $(vscobjects)
	$(CC) $(LDFLAGS) $(vscobjects) /Fobin\vsc$(TARGET).exe

bin\vcpr$(TARGET).exe: $(vcprobjects)
	$(CC) $(LDFLAGS) $(vcprobjects) /Fobin\vcpr$(TARGET).exe

bin\tasm$(TARGET).exe: $(tasm)
	$(CC) $(LDFLAGS) $(tasm) /Fobin\tasm$(TARGET).exe

bin\mbasic$(TARGET).exe: $(mbasic)
	$(CC) $(LDFLAGS) $(mbasic) /Fobin\mbasic$(TARGET).exe

bin\minicomp$(TARGET).exe: $(minicomp)
	$(CC) $(LDFLAGS) $(minicomp) /Fobin\minicomp$(TARGET).exe

bin\dtgen.exe: datatypes\dtgen.c datatypes\datatypes.h datatypes\dtconv.h
	$(NCC) datatypes\dtgen.c /Fobin\dtgen.exe -Idatatypes $(NLDFLAGS)

$(TRGDIR)\dt.h: bin\dtgen.exe $(TRGDIR)\machine.dt
	bin\dtgen $(TRGDIR)\machine.dt $(TRGDIR)\dt.h $(TRGDIR)\dt.c

$(TRGDIR)\dt.c: bin\dtgen.exe $(TRGDIR)\machine.dt
	bin\dtgen.exe $(TRGDIR)\machine.dt $(TRGDIR)\dt.h $(TRGDIR)\dt.c

$(TRGDIR)\dt.obj: $(TRGDIR)\dt.h $(TRGDIR)\dt.c
	$(CC) -c $(TRGDIR)\dt.c /Fo$(TRGDIR)\dt.obj /I$(TRGDIR) -Idatatypes

$(TRGDIR)\tasm.obj: tasm.c supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c tasm.c /Fo$(TRGDIR)\tasm.obj /I$(TRGDIR)

$(TRGDIR)\mbasic.obj: mbasic.c supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c mbasic.c /Fo$(TRGDIR)\mbasic.obj /I$(TRGDIR)

$(TRGDIR)\minicomp.obj: minicomp.c minicomp.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c minicomp.c /Fo$(TRGDIR)\minicomp.obj /I$(TRGDIR)

$(TRGDIR)\minicompg.tab.obj: minicompg.y minicomplexer.c minicomp.h supp.h
	bison minicompg.y
	$(CC) -c minicompg.tab.c /Fo$(TRGDIR)\minicompg.tab.obj /I$(TRGDIR)

$(TRGDIR)\supp.obj: supp.c supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c supp.c /Fo$(TRGDIR)\supp.obj /I$(TRGDIR)

$(TRGDIR)\main.obj: main.c vbc.h supp.h vbcc_cpp.h ucpp\cpp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c main.c /Fo$(TRGDIR)\main.obj /I$(TRGDIR)

$(TRGDIR)\vars.obj: vars.c vbc.h supp.h $(TRGDIR)\machine.h errors.h $(TRGDIR)\dt.h
	$(CC) -c vars.c /Fo$(TRGDIR)\vars.obj /I$(TRGDIR)

$(TRGDIR)\declaration.obj: declaration.c vbc.h supp.h vbcc_cpp.h ucpp\cpp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c declaration.c /Fo$(TRGDIR)\declaration.obj /I$(TRGDIR)

$(TRGDIR)\parse_expr.obj: parse_expr.c vbc.h supp.h vbcc_cpp.h ucpp\cpp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c parse_expr.c /Fo$(TRGDIR)\parse_expr.obj /I$(TRGDIR)

$(TRGDIR)\type_expr.obj: type_expr.c vbc.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c type_expr.c /Fo$(TRGDIR)\type_expr.obj /I$(TRGDIR)

$(TRGDIR)\ic.obj: ic.c vbc.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c ic.c /Fo$(TRGDIR)\ic.obj /I$(TRGDIR)

$(TRGDIR)\statements.obj: statements.c vbc.h supp.h vbcc_cpp.h ucpp\cpp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c statements.c /Fo$(TRGDIR)\statements.obj /I$(TRGDIR)

$(TRGDIR)\opt.obj: opt.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c opt.c /Fo$(TRGDIR)\opt.obj /I$(TRGDIR)

$(TRGDIR)\av.obj: av.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c av.c /Fo$(TRGDIR)\av.obj /I$(TRGDIR)

$(TRGDIR)\rd.obj: rd.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c rd.c /Fo$(TRGDIR)\rd.obj /I$(TRGDIR)

$(TRGDIR)\regs.obj: regs.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c regs.c /Fo$(TRGDIR)\regs.obj /I$(TRGDIR)

$(TRGDIR)\flow.obj: flow.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c flow.c /Fo$(TRGDIR)\flow.obj /I$(TRGDIR)

$(TRGDIR)\cse.obj: cse.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c cse.c /Fo$(TRGDIR)\cse.obj /I$(TRGDIR)

$(TRGDIR)\cp.obj: cp.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c cp.c /Fo$(TRGDIR)\cp.obj /I$(TRGDIR)

$(TRGDIR)\loop.obj: loop.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c loop.c /Fo$(TRGDIR)\loop.obj /I$(TRGDIR)

$(TRGDIR)\alias.obj: alias.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c alias.c /Fo$(TRGDIR)\alias.obj /I$(TRGDIR)

$(TRGDIR)\range.obj: range.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c range.c /Fo$(TRGDIR)\range.obj /I$(TRGDIR)

$(TRGDIR)\preproc.obj: preproc.c vbpp.h supp.h vbc.h $(TRGDIR)\dt.h
	$(CC) -c preproc.c /Fo$(TRGDIR)\preproc.obj /I$(TRGDIR)

$(TRGDIR)\assert.obj: ucpp\assert.c ucpp\cpp.h ucpp\mem.h ucpp\hash.h ucpp\tune.h $(TRGDIR)\dt.h
	$(CC) -DNO_UCPP_ERROR_FUNCTIONS -c ucpp\assert.c /Fo$(TRGDIR)\assert.obj /I$(TRGDIR)

$(TRGDIR)\cpp.obj: ucpp\cpp.c ucpp\cpp.h ucpp\mem.h ucpp\hash.h ucpp\tune.h $(TRGDIR)\dt.h
	$(CC) -DNO_UCPP_ERROR_FUNCTIONS -c ucpp\cpp.c /Fo$(TRGDIR)\cpp.obj /I$(TRGDIR)

$(TRGDIR)\hash.obj: ucpp\hash.c ucpp\cpp.h ucpp\mem.h ucpp\hash.h ucpp\tune.h $(TRGDIR)\dt.h
	$(CC) -DNO_UCPP_ERROR_FUNCTIONS -c ucpp\hash.c /Fo$(TRGDIR)\hash.obj /I$(TRGDIR)

$(TRGDIR)\lexer.obj: ucpp\lexer.c ucpp\cpp.h ucpp\mem.h ucpp\hash.h ucpp\tune.h $(TRGDIR)\dt.h
	$(CC) -DNO_UCPP_ERROR_FUNCTIONS -c ucpp\lexer.c /Fo$(TRGDIR)\lexer.obj /I$(TRGDIR)

$(TRGDIR)\macro.obj: ucpp\macro.c ucpp\cpp.h ucpp\mem.h ucpp\hash.h ucpp\tune.h $(TRGDIR)\dt.h
	$(CC) -DNO_UCPP_ERROR_FUNCTIONS -c ucpp\macro.c /Fo$(TRGDIR)\macro.obj /I$(TRGDIR)

$(TRGDIR)\mem.obj: ucpp\mem.c ucpp\cpp.h ucpp\mem.h ucpp\hash.h ucpp\tune.h $(TRGDIR)\dt.h
	$(CC) -DNO_UCPP_ERROR_FUNCTIONS -c ucpp\mem.c /Fo$(TRGDIR)\mem.obj /I$(TRGDIR)

$(TRGDIR)\eval.obj: ucpp\eval.c ucpp\cpp.h ucpp\mem.h ucpp\tune.h $(TRGDIR)\dt.h
	$(CC) -DNO_UCPP_ERROR_FUNCTIONS -c ucpp\eval.c /Fo$(TRGDIR)\eval.obj /I$(TRGDIR)

$(TRGDIR)\machine.obj: $(TRGDIR)\machine.c supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h dwarf2.c
	$(CC) -c $(TRGDIR)\machine.c /Fo$(TRGDIR)\machine.obj /I$(TRGDIR) /I.

$(TRGDIR)\opts.obj: opt.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c -DNO_OPTIMIZER opt.c /Fo$(TRGDIR)\opts.obj /I$(TRGDIR)

$(TRGDIR)\regss.obj: regs.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c -DNO_OPTIMIZER regs.c /Fo$(TRGDIR)\regss.obj /I$(TRGDIR)

$(TRGDIR)\vsc.obj: vsc\vsc.h vsc\vsc.c $(TRGDIR)\schedule.h
	$(CC) -c vsc\vsc.c /Fo$(TRGDIR)\vsc.obj /I$(TRGDIR)

$(TRGDIR)\schedule.obj: vsc\vsc.h $(TRGDIR)\schedule.h $(TRGDIR)\schedule.c
	$(CC) -c $(TRGDIR)\schedule.c /Fo$(TRGDIR)\schedule.obj /I$(TRGDIR) -Ivsc

$(TRGDIR)\vcpr.obj: vcpr\vcpr.h vcpr\vcpr.c
	$(CC) -c vcpr\vcpr.c /Fo$(TRGDIR)\vcpr.obj /I$(TRGDIR)

$(TRGDIR)\compress.obj: vcpr\vcpr.h $(TRGDIR)\compress.c
	$(CC) -c $(TRGDIR)\compress.c /Fo$(TRGDIR)\compress.obj /I$(TRGDIR) -Ivcpr



# Graph coloring register allocator by Alex
$(TRGDIR)\AdjList.obj: GCRegAlloc\AdjList.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c GCRegAlloc\AdjList.c /Fo$(TRGDIR)\AdjList.obj -IGCRegAlloc /I$(TRGDIR)

$(TRGDIR)\DUChain.obj: GCRegAlloc\DUChain.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c GCRegAlloc\DUChain.c /Fo$(TRGDIR)\DUChain.obj -IGCRegAlloc /I$(TRGDIR)

$(TRGDIR)\ICodeInsertion.obj: GCRegAlloc\ICodeInsertion.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c GCRegAlloc\ICodeInsertion.c /Fo$(TRGDIR)\ICodeInsertion.obj -IGCRegAlloc /I$(TRGDIR)

$(TRGDIR)\NodeList.obj: GCRegAlloc\NodeList.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c GCRegAlloc\NodeList.c /Fo$(TRGDIR)\NodeList.obj -IGCRegAlloc /I$(TRGDIR)

$(TRGDIR)\RAllocMain.obj: GCRegAlloc\RAllocMain.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c GCRegAlloc\RAllocMain.c /Fo$(TRGDIR)\RAllocMain.obj -IGCRegAlloc /I$(TRGDIR)

$(TRGDIR)\Web.obj: GCRegAlloc\Web.c opt.h supp.h $(TRGDIR)\machine.h $(TRGDIR)\dt.h
	$(CC) -c GCRegAlloc\Web.c /Fo$(TRGDIR)\Web.obj -IGCRegAlloc /I$(TRGDIR)
