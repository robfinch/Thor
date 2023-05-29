// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// CC64 - 'C' derived language compiler
//  - 64 bit CPU
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
#include "stdafx.h"

extern int lstackptr;
extern char* lptr;
extern int options(char *);
extern int openfiles(char *);
extern void summary();
extern void ParseGlobalDeclarations();
extern void makename_s(char *s, size_t ln, char *e);
extern char *errtext(int errnum);
extern std::string *classname;
extern void doInitCleanup();

int Compiler::GetReturnBlockSize()
{
	return (4 * sizeOfWord);
}

int Compiler::main2(int argc, char **argv)
{
	uctran_off = 0;
	optimize =1;
	exceptions=1;
	dfs.printf("c64 starting...\r\n");
	while(--argc) {
        if( **++argv == '-')
            options(*argv);
		else {
			if (PreprocessFile(*argv) == -1)
				break;
			if( openfiles(*argv)) {
				lineno = 0;
				initsym();
				lstackptr = 0;
				lastst = 0;
				NextToken();
				compile();
				summary();
//				MBlk::ReleaseAll();
//				ReleaseGlobalMemory();
				CloseFiles();
			}
        }
    }
	//getchar();
	return 0;
}

// Builds the debugging log as an XML document
//
void Compiler::compile()
{
	GlobalDeclaration *gd;
	int nn;
	Symbol* sp;
	Symbol* fsp;
	char buf[10];

	dfs.printf("<compile>\n");
	genst_cumulative = 0;
	typenum = 1;
	symnum = 257;
	pass = 1;
	classname = nullptr;
	//pCSETable = new CSETable;
	//pCSETable->Clear();
	ru = CSet::MakeNew();
	rru = CSet::MakeNew();
	ZeroMemory(&gsyms[0],sizeof(gsyms));
	ZeroMemory(&defsyms,sizeof(defsyms));
	ZeroMemory(&tagtable,sizeof(tagtable));
	ZeroMemory(&symbolTable,sizeof(symbolTable));
	ZeroMemory(&typeTable,sizeof(typeTable));
	ZeroMemory(&functionTable, sizeof(functionTable));
	ZeroMemory(&DataLabels, sizeof(DataLabels));
	AddStandardTypes();

	// Setup a master function.
	fsp = allocSYM();
	fsp->name = new std::string(nmspace[0]);
	fsp->storage_class = sc_global;
	fsp->tp = &stdint;
	programFn = currentFn = ff.MakeFunction(fsp->id, fsp, false);

	RTFClasses::Random::srand((RANDOM_TYPE)time(NULL));
	decls = GlobalDeclaration::Make();
	gd = decls;
	lastst = tk_nop;

	funcnum = 0;
	AddBuiltinFunctions();
	Instruction::SetMap();

	MachineReg::MarkColorable();

	getch();
	lstackptr = 0;
	lastst = 0;
	NextToken();
	string_exclude.clear();
	try {
		while(lastst != my_eof)
		{
			if (gd==nullptr)
				break;
			dfs.printf("<Parsing GlobalDecl>\n");
			gd->Parse();
			dfs.printf("</Parsing GlobalDecl>\n");
			if( lastst != my_eof) {
				NextToken();
				gd->next = (Declaration *)GlobalDeclaration::Make();
				gd = (GlobalDeclaration*)gd->next;
			}
		}
		doInitCleanup();
		dfs.printf("</compile>\n");
	}
	catch (C64PException * ex) {
		dfs.printf(errtext(ex->errnum));
 		dfs.printf("</compile>\n");
	}
	dumplits(ofs);
	DumpGlobals();
	// Cleanup the label map
	for (nn = 0; nn < nextlabel; nn++)
		if (DataLabelMap[nn])
			delete DataLabelMap[nn];
}

int Compiler::PreprocessFile(char *nm)
{
	static char outname[1000];
	static char sysbuf[500];

	strcpy_s(outname, sizeof(outname), nm);
	makename_s(outname, sizeof(outname), (char *)".fpp");
	sprintf_s(sysbuf, sizeof(sysbuf), "fpp -b %s %s", nm, outname);
	return system(sysbuf);
}

void Compiler::CloseFiles()
{    
	lfs.close();
	ofs.close();
	dfs.close();
	ifs->close();
}

void Compiler::AddStandardTypes()
{
	TYP *p, *pchar, *pint, *pbyte;
	TYP *pichar;

	p = TYP::Make(bt_bit, sizeOfWord);
	stdbit = *p;
	pint = p;
	p->precision = sizeOfWord * 8;

	p = TYP::Make(bt_decimal, sizeOfDecimal);
	stddecimal = *p;
	pint = p;
	p->precision = sizeOfDecimal * 8;

	p = TYP::Make(bt_int,sizeOfInt);
	stdint = *p;
	pint = p;
	p->precision = sizeOfInt * 8;
  
	p = TYP::Make(bt_int,sizeOfInt);
	p->isUnsigned = true;
	p->precision = sizeOfInt * 8;
	stduint = *p;
  
	p = TYP::Make(bt_long,sizeOfWord);
	p->precision = sizeOfWord * 8;
	stdlong = *p;
  
	p = TYP::Make(bt_long,sizeOfWord);
	p->isUnsigned = true;
	p->precision = sizeOfWord * 8;
	stdulong = *p;
  
	p = TYP::Make(bt_short,sizeOfWord/2);
	p->precision = sizeOfWord * 4;
	stdshort = *p;
  
	p = TYP::Make(bt_short,sizeOfWord/2);
	p->isUnsigned = true;
	p->precision = sizeOfWord * 4;
	stdushort = *p;
  
	p = TYP::Make(bt_char,2);
	stdchar = *p;
	p->precision = 16;
	pchar = p;
  
	p = TYP::Make(bt_uchar,2);
	p->isUnsigned = true;
	p->precision = 16;
	stduchar = *p;
  
	p = TYP::Make(bt_ichar, 2);
	stdichar = *p;
	p->precision = 16;
	pichar = p;

	p = TYP::Make(bt_iuchar, 2);
	stdiuchar = *p;
	p->precision = 16;
//	pchar = p;

	p = TYP::Make(bt_byte,1);
	stdbyte = *p;
	p->precision = 8;
	pbyte = p;
  
	p = TYP::Make(bt_ubyte,1);
	p->isUnsigned = true;
	p->precision = 8;
	stdubyte = *p;
  
	p = TYP::Make(bt_pointer,sizeOfPtr);
	p->val_flag = 1;
	p->btpp = pchar;
	p->isUnsigned = true;
	stdstring = *p;
 
	p = TYP::Make(bt_pointer,sizeOfPtr);
	p->val_flag = 1;
	p->btpp = pichar;
	p->isUnsigned = true;
	stdistring = *p;

	p = TYP::Make(bt_pointer,sizeOfPtr);
	p->val_flag = 1;
	p->btpp = pbyte;
	p->isUnsigned = true;
	stdastring = *p;

	p = TYP::Make(bt_half,2);
	stdhalf = *p;

	p = TYP::Make(bt_single,4);
	stdsingle = *p;

	p = TYP::Make(bt_double,8);
	stddbl = *p;
	stddouble = *p;
  
	p = TYP::Make(bt_quad,16);
	stdquad = *p;
  
	p = TYP::Make(bt_float,4);
	stdflt = *p;
  
	p = TYP::Make(bt_posit,8);
	stdposit = *p;

	p = TYP::Make(bt_posit,4);
	stdposit32 = *p;

	p = TYP::Make(bt_posit,2);
	stdposit16 = *p;

	p = TYP::Make(bt_func,0);
	p->btpp = pint;
	stdfunc = *p;

	p = TYP::Make(bt_exception, 8);
	p->isUnsigned = true;
	stdexception = *p;

	p = TYP::Make(bt_int,sizeOfInt);
	p->val_flag = 1;
	stdconst = *p;

	p = TYP::Make(bt_vector,64);
	p->val_flag = 1;
	stdvector = *p;

	p = TYP::Make(bt_vector_mask,8);
	p->val_flag = 1;
	stdvectormask = *p;

	p = TYP::Make(bt_void,8);
	p->val_flag = 1;
	stdvoid = *p;

	p = TYP::Make(bt_enum,2);
	p->val_flag = 1;
	stdenum = *p;

	p = TYP::Make(bt_pointer,sizeOfPtr);
	p->val_flag = 1;
	stdptr = *p;
}

// Actually compiler support routines

void Compiler::AddBuiltinFunctions()
{
	Symbol *sp;
	TypeArray tanew, tadelete;

	sp = Symbol::alloc();
	sp->SetName("__new");
	sp->fi = sp->MakeFunction(sp->id, true);
	tanew.Add(bt_long, ::cpu.argregs[0]);
	//tanew.Add(bt_pointer,19);
	//tanew.Add(bt_long, 20);
	sp->fi->AddProto(&tanew);
	sp->tp = &stdvoid;
	gsyms->insert(sp);

	sp = Symbol::alloc();
	sp->SetName("__autonew");
	sp->fi = sp->MakeFunction(sp->id, true);
	//tanew.Add(bt_long, 0);
	//tanew.Add(bt_pointer,19);
	//tanew.Add(bt_long, 20);
	sp->fi->AddProto(&tanew);
	sp->tp = &stdvoid;
	gsyms->insert(sp);

	sp = Symbol::alloc();
	sp->SetName("__delete");
	sp->fi = sp->MakeFunction(sp->id, true);
	tadelete.Add(bt_pointer, ::cpu.argregs[0]);
	sp->fi->AddProto(&tadelete);
	sp->tp = &stdvoid;
	gsyms->insert(sp);

	sp = Symbol::alloc();
	sp->SetName("_start_bss");
	sp->tp = &stdint;
	sp->storage_class = sc_external;
	sp->segment = bssseg;
	gsyms->insert(sp);

	sp = Symbol::alloc();
	sp->SetName("_start_data");
	sp->tp = &stdint;
	sp->storage_class = sc_external;
	sp->segment = dataseg;
	gsyms->insert(sp);

	sp = Symbol::alloc();
	sp->SetName("_start_rodata");
	sp->tp = &stdint;
	sp->storage_class = sc_external;
	sp->segment = rodataseg;
	gsyms->insert(sp);

}


void Compiler::DumpGlobals()
{
	Symbol* sym;
	int nn;
	char* nm;

	return;
	seg(ofs, dataseg, 14);

	ofs.puts("__GLOBAL_OFFSET_TABLE_:\n");
	sym = nullptr;
	for (nn = 0; nn < compiler.symnum; nn++) {
		if (compiler.symbolTable[nn].storage_class == sc_global) {
//			if (compiler.symbolTable[nn].segment != noseg) {
				sym = &compiler.symbolTable[nn];
				nm = (char *)sym->name->c_str();
				if (sym && nm[0]=='_') {
					ofs.puts("\t.8byte\t");
					ofs.puts(sym->name->c_str());
					ofs.puts("\n");
				}
			}
//		}
	}
	ofs.puts("\n");
}


void Compiler::storeHex(txtoStream& ofs)
{
	int nn, mm;
	char buf[20];

	nn = compiler.symnum;
	sprintf_s(buf, sizeof(buf), "SYMTBL%05d\n", nn);
	ofs.write(buf);
	for (mm = 0; mm < nn; mm++)
		symTables[mm >> 15][mm & 0x7fff].storeHex(ofs);
	nn = compiler.funcnum;
	sprintf_s(buf, sizeof(buf), "FNCTBL%05d\n", nn);
	ofs.write(buf);
	for (mm = 0; mm < nn; mm++)
		functionTable[mm].storeHex(ofs);
	nn = typenum;
	sprintf_s(buf, sizeof(buf), "TYPTBL%05d\n", nn);
	ofs.write(buf);
	for (mm = 0; mm < nn; mm++)
		typeTable[mm].storeHex(ofs);
}

void Compiler::loadHex(txtiStream& ifs)
{

}

void Compiler::storeTables()
{
	txtoStream* oofs;
	extern char irfile[256];

	oofs = new txtoStream();
	oofs->open(irfile, std::ios::out);
	oofs->printf("; CC64 Hex Intermediate Representation File\n");
	oofs->printf("; This is an automatically generated file.\n");
	storeHex(*oofs);
	oofs->close();
	delete oofs;
}
