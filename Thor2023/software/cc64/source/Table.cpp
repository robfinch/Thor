// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2022  Robert Finch, Waterloo
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

extern char *prefix;
Symbol *search2(char *na,TABLE *tbl,TypeArray *typearray);
uint8_t hashadd(char *nm);

#ifndef min
int min (int a, int b) { return a < b ? a : b; }
#endif

Symbol *TABLE::match[100];
int TABLE::matchno;

TABLE::TABLE()
{
  basep = nullptr;
  headp = nullptr;
  tailp = nullptr;
  ownerp = nullptr;
}

// Used when deriving classes from base clasases.

void TABLE::CopySymbolTable(TABLE *dst, TABLE *src)
{
	int count = 0;
	static int level = 0;

	Symbol *sp, *newsym, *first, *next;
	level++;
	dfs.puts("<CopySymbolTable>\n");
	if (src) {
	  dfs.printf("A");
		first = sp = src->headp;
		while (sp) {
  	  dfs.printf("B");
			newsym = Symbol::Copy(sp);
  	  dfs.printf("C");
			dst->insert(newsym);
			if (newsym->tp->IsStructType()) {
				if (level > 15)
					break;
				CopySymbolTable(&newsym->tp->lst, &sp->tp->lst);
			}
  	  dfs.printf("D");
			next = sp->nextp;
			if (next == first)
				break;
			sp = next;
			count++;
			if (count > 1000)
				break;
		}
	}
	level--;
	dfs.puts("</CopySymbolTable>\n");
}

//Generic table insert routine, used for all inserts.

Symbol* TABLE::insert(Symbol *sp)
{
	int nn;
	TypeArray *ta = nullptr;
	if (sp->fi)
		ta = sp->fi->GetProtoTypes();
	int s1;
	TABLE* tab = this;
	std::string nm;
	Symbol *sp1 = nullptr;
	Symbol* sp2;
//  std::string sig;

	if (sp == nullptr || this == nullptr ) {
	  dfs.printf("Null pointer at insert\n");
		throw new C64PException(ERR_NULLPOINTER,1);
  }

  if (this==&tagtable) {
    dfs.printf("Insert into tagtable:%s|\n",(char *)sp->name->c_str());
		tab = this;
  }
	sp2 = ownerp;
	if (sp2 != nullptr)
		if (sp2->name != nullptr)
			dfs.printf("(%s)\n",ownerp ? (char *)ownerp->name->c_str(): (char *)"");
//  sig = sp->BuildSignature();
	if (tab==&gsyms[0]) {
	  dfs.printf("Insert into global table\n");
		s1 = hashadd((char *)sp->name->c_str());
		tab = &gsyms[s1];
	}
	dfs.printf((char*)"Insert %s into %p", (char*)sp->name->c_str(), (char*)this);

	nm = *sp->name;// name;
  // The symbol may not have a type if it's just a label. Find doens't
  // look at the return type parameter anyway, so we just set it to bt_long
  // if tp isn't set.
	if (nm.length() > 0)
		nn = tab->Find(nm, sp->tp ? sp->tp->typeno : bt_int, ta, true);
	else
		nn = 0;
	if(nn == 0) {
    if(tab->headp == nullptr) {
			tab->headp = sp;
			tab->tailp = sp;
		}
    else {
			tab->tailp->nextp = sp;
			tab->tailp = sp;
    }
		sp->nextp = nullptr;
    dfs.printf("At insert:\n");
    sp->fi->GetProtoTypes()->Print();
  }
	// If we have an exactly matching symbol, just ignore.
	else {
		for (nn = 0; nn < TABLE::matchno; nn++) {
			sp1 = TABLE::match[0];
			if (sp->fi) {
				if (sp1->fi->ParameterTypesMatch(sp->fi->GetParameterTypes()))
					goto j1;
				if (sp1->fi->ParameterTypesMatch(sp->fi->GetProtoTypes()))
					goto j1;
			}
			else
				goto j1;
		}
		error(ERR_DUPSYM);
	}
j1:
	if (ta)
		delete ta;
//  p = tab->GetHead();
//  while(p) {
//    printf("Xele:%p|%s|\r\n", p, p->name.c_str());
//    p = p->GetNext();
//  }
	return (sp1);
}

// Parameters:
//  na:			the name to search for
//	rettype:	this parameter is ignored

int TABLE::Find(std::string na,__int16 rettype, TypeArray *typearray, bool exact)
{
	Symbol *thead, *first;
	TypeArray *ta;
	int s1,s2,s3;
	std::string name;
	static int level = 0;

  dfs.puts("<Find>");
  dfs.puts((char *)na.c_str());
	level++;
  if (this==nullptr) {
    matchno = 0;
		level--;
    return 0;
  }
	if (na.length()==0) {
	  dfs.printf("name is empty string\n");
		throw new C64PException(ERR_NULLPOINTER,1);
  }

	matchno = 0;
	if (this==&gsyms[0])
		thead = gsyms[hashadd((char *)na.c_str())].headp;
	else
		thead = headp;
	first = thead;
//	while(thead != NULL) {
//	  lfs.printf("Ele:%s|\n", (char *)thead->name->c_str());
//	  thead = thead->GetNext();
// }
 thead = first;
	while( thead != NULL) {
//		dfs.printf((char *)"|%s|,|%s|\n",(char *)thead->name->c_str(),(char *)na.c_str());
		if (thead->name) {	// ???
    name = *thead->name;
		s1 = thead->name->compare(na);
		if (s1==0) { //((s1&s2)|(s1&s3)|(s2&s3))==0) {
		  dfs.printf(":Match");
			match[matchno] = thead;
			matchno++;
			if (matchno > 98)
				break;
		
			if (exact) {
				ta = thead->fi->GetProtoTypes();
				if (ta->IsEqual(typearray)) {
				  dfs.printf(":Exact match");
				  ta->Print();
				  typearray->Print();
				  delete ta;
					level--;
				  return 1;
				}
				ta->Print();
				delete ta;
			}
		}
		}
    thead = thead->nextp;
    if (thead==first) {
      dfs.printf("Circular list.\n");
      throw new C64PException(ERR_CIRCULAR_LIST,1);
    }
  }
  dfs.puts("</Find>\n");

	// Try for a union match
	if (matchno == 0) {
		thead = first;
		while (thead != NULL) {
			if (thead->tp->IsAggregateType()) {
				if (level > 15)
					break;
				thead->tp->lst.Find(na, rettype, typearray, exact);
				if (matchno > 0) {
					level--;
					return (exact ? 0 : matchno);
				}
			}
			thead = thead->nextp;
			if (thead == first) {
				dfs.printf("Circular list.\n");
				throw new C64PException(ERR_CIRCULAR_LIST, 1);
			}
		}
	}
	level--;
  return (exact ? 0 : matchno);
}

int TABLE::Find(std::string na)
{
	return Find(na,(__int16)bt_int,nullptr,false);
}


// Findrising searchs the table hierarchy at higher and higher
// levels until the symbol is found. It returns a table full of matches
// which is ordered according to the level at which the symbol was found.
// Subclasses appear in the table before base classes, so that a 
// subclass definiton of the symbol shadows a base class definition.
//
int TABLE::FindRising(std::string na)
{
	int sp;
  Symbol *sym;
  int bse;
	Symbol* bsep;
  static Symbol *mt[110];
  int nn, ii;
  int ndx;
  TypeArray *ta;

  ndx = 0;
  dfs.printf("<FindRising>%s \n",(char *)na.c_str());
  if (this==nullptr)
    return 0;
	sp = Find(na);
	nn = min(100,ndx+TABLE::matchno);
	memcpy(&mt[0],TABLE::match,nn*sizeof(Symbol *));
	ndx += nn;
	bsep = basep;
	while (bsep) {
		sym = bsep;
	  dfs.printf("Searching class:%s \n",(char *)sym->name->c_str());
		sp = sym->tp->lst.Find(na);
  	nn = min(100,ndx+TABLE::matchno);
  	memcpy(&mt[ndx],TABLE::match,nn*sizeof(Symbol *));
  	ndx += nn;
		bsep = sym->tp->lst.basep;
	}
	dfs.puts("</FindRising>");

  memcpy(TABLE::match,mt,ndx*sizeof(Symbol *));
  TABLE::matchno = ndx;
  for (nn = 0; nn < ndx; nn++) {
    sym = TABLE::match[nn];
	if (sym) {
		if (sym->tp->type == bt_func || sym->tp->type == bt_ifunc) {
			if (sym->name)
				dfs.printf("Sym:%s Types: (", (char *)sym->name->c_str());
			else
				dfs.printf("Sym:%s Types: (", (char *)"<no name>");
			ta = sym->fi->GetProtoTypes();
			if (ta) {
				for (ii = 0; ii < 20; ii++) {
					dfs.printf("%03d, ", ta->types[ii]);
				}
			}
			dfs.puts(")\n");
		}
    }
  }
  return (ndx);
}

Symbol *TABLE::Find(std::string na, bool opt)
{
	Find(na,(__int16)bt_int,nullptr,false);
	if (matchno==0)
		return (nullptr);
	return (match[matchno-1]);
}

Symbol* TABLE::Find(std::string na, bool opt, e_bt bt)
{
	Symbol* sp;

	for (sp = headp; sp; sp = sp->nextp) {
		if (sp->name->compare(na) == 0) {
			if (sp->tp) {
				if (sp->tp->type == bt)
					return (sp);
			}
		}
	}
	return (nullptr);
}

Symbol** TABLE::GetParameters()
{
	Symbol** params;
	Symbol* thead, * first;

	params = new Symbol * [30];
	ZeroMemory(&params[0], sizeof(Symbol*) * 30);
	thead = headp;
	first = thead;
	while (thead != nullptr) {
		if (thead->IsParameter) {
			if (thead->parmno < 30) {
				params[thead->parmno] = thead;
			}
		}
		thead = thead->nextp;
		if (thead == first) {
			dfs.printf("Circular list.\n");
			throw new C64PException(ERR_CIRCULAR_LIST, 1);
		}
	}
	return (&params[0]);
}

void TABLE::AddTo(TABLE* dst)
{
	Symbol* thead, * first, *next;

	thead = headp;
	first = thead;
	while (thead != nullptr) {
		next = thead->nextp;
		if (thead->IsParameter) {
			dst->insert(thead);
		}
		thead = next;
		if (thead == first) {
			dfs.printf("Circular list.\n");
			throw new C64PException(ERR_CIRCULAR_LIST, 1);
		}
	}
}
