#include "stdafx.h"
extern CSet* ru, * rru;

Function* FunctionFactory::MakeFunction(int symnum, Symbol* sp, bool isPascal)
{
	int count;

	for (count = 0; count < 3000; count++) {
		Function* sym = &compiler.functionTable[compiler.funcnum];
		if (!sym->valid) {
			ZeroMemory(sym, sizeof(Function));
			sym->sym = sp;
			sym->IsPascal = isPascal;
			sym->IsCoroutine = false;
			sym->Islocal = false;
			sym->alloced = true;
			sym->valid = TRUE;
			sym->NumParms = 0;	// was -1
			sym->numa = 0;	// was -1
			sym->params.ownerp = sp->parentp;// .SetOwner(symnum);
			sym->proto.ownerp = sp->parentp;// .SetOwner(symnum);
			sym->UsesTemps = true;
			sym->UsesStackParms = true;
			sym->inline_threshold = compiler.autoInline;
			sym->number = compiler.funcnum;
			compiler.funcnum++;
			if (compiler.funcnum > 2999)
				compiler.funcnum = 0;
			return (sym);
		}
		compiler.funcnum++;
		if (compiler.funcnum > 2999)
			compiler.funcnum = 0;
	}
	dfs.printf("Too many functions.\n");
	throw new C64PException(ERR_TOOMANY_SYMBOLS, 1);
}
