#include "stdafx.h"

Symbol* SymbolFactory::Make(std::string nme, TYP* ty, Symbol* parent, int depth, e_sc sc)
{
	Symbol* sym;

	sym = Symbol::alloc();
	sym->SetName(nme);
	sym->depth = depth;
	sym->storage_class = sc;
	sym->SetType(ty);
	sym->parentp = parent;
	return (sym);
}
