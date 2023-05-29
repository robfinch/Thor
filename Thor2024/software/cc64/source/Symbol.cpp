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

#define ADD_SYMS \
n = 0; \
for (nn = TABLE::matchno; gSearchCnt < 100 && nn > 0; nn--) \
	gSearchSyms[gSearchCnt++] = TABLE::match[n++];

int Symbol::acnt = 0;
Symbol * Symbol::initsym = nullptr;
int Symbol::initlvl = 0;
char *prefix;
extern int nparms;
extern bool isRegister;
Symbol* currentSym = nullptr;

static Symbol* gSearchSyms[100];
static int gSearchCnt;

Function* Symbol::MakeFunction(int symnum, bool isPascal) {
	Function* fn = compiler.ff.MakeFunction(symnum, this, isPascal);
	return (fn);
};

Symbol* Symbol::GetTemp()
{
	static int64_t i=0;
	Symbol* sym;
	char buf[100];

	sym = allocSYM();
	sprintf_s(buf, sizeof(buf), "__tempsym%d", i);
	i++;
	sym->SetName(buf);
	sym->tp = allocTYP();
	sym->tp->type = bt_aggregate;
	return (sym);
}

Symbol *Symbol::GetPtr(int n)
{ 
	Symbol* p1;
  if (n==0)
    return (nullptr);
	if ((n >> 15) > 9)
		return (nullptr);
	p1 = compiler.symTables[n >> 15];
	if (p1 == nullptr)
		return (nullptr);
  return (Symbol *)&compiler.symTables[n>>15][n & 0x7fff]; 
}

Symbol *Symbol::GetNextPtr()
{ 
	Symbol* p1;
	if (next == 0)
		return (nullptr);
	if ((next >> 15) > 9)
		return (nullptr);
	p1 = compiler.symTables[next >> 15];
	if (p1 == nullptr)
		return (nullptr);
	return (Symbol*)&compiler.symTables[next >> 15][next & 0x7fff];
}

Symbol *Symbol::GetParentPtr()
{
	Symbol* p1;
	if (parent == 0)
		return (nullptr);
	if ((parent >> 15) > 9)
		return (nullptr);
	p1 = compiler.symTables[parent >> 15];
	if (p1 == nullptr)
		return (nullptr);
	return (Symbol*)&compiler.symTables[parent >> 15][parent & 0x7fff];
};

// Dead code
int Symbol::GetIndex()
{
	Symbol* p1;
	if (this==nullptr)
     return 0;
	return (this->id);
//	return this - &compiler.symbolTable[0];
};

bool Symbol::IsTypedef()
{
	Symbol* p, * q, *first, *next;

	q = nullptr;
	for (first = p = parentp; p; p = next) {
		q = p;
		next = p->parentp;
		if (next == first) {
			break;
		}
	}
	if (q)
		if (q->storage_class == sc_typedef)
			return (true);
	return (storage_class == sc_typedef);
}


uint8_t hashadd(char *nm)
{
	uint8_t hsh;

	for(hsh=0;*nm;nm++)
		hsh += *nm;
	return hsh;
}

Symbol *search2(std::string na,TABLE *tbl,TypeArray *typearray)
{
	Symbol *thead, *sp;
	TYP* tp;
	TypeArray *ta;

	if (&na == nullptr || tbl==nullptr || na == "")
		return nullptr;
//	printf("Enter search2\r\n");
	if (tbl == &gsyms[0])
		thead = compiler.symbolTable[0].GetPtr(hashadd((char*)na.c_str()));
	else if (tbl == &tagtable)
		thead = tagtable.headp;
	else
		thead = tbl->headp;
	while( thead != NULL) {
		if (thead->name && thead->name->length() != 0) {
		  /*
			if (prefix)
				strncpy(namebuf,prefix,sizeof(namebuf)-1);
			else
				namebuf[0]='\0';
			strncat(namebuf,thead->name,sizeof(namebuf)-1);
			*/
			if(thead->name->compare(na)==0) {
				if (typearray) {
					ta = thead->fi->GetProtoTypes();
					if (ta->IsEqual(typearray))
						break;
					if (ta)
						delete ta;
				}
				else
					break;
			}
		}
    thead = thead->GetNextPtr();
    }
//	printf("Leave search2\r\n");
    return (thead);
}

Symbol *search(std::string na,TABLE *tbl)
{
	return search2(na,tbl,nullptr);
}

static void SearchStatements(Statement* stmt, std::string na, __int16 rettype, TypeArray* typearray, bool exact)
{
	Statement* st = stmt;
	Symbol* sp;
	int n;
	int nn;

	if (st == nullptr)
		return;
	for (; st && gSearchCnt < 100; st = st->outer) {
		dfs.puts("Looking in statement table: ");
		dfs.puts((char *)st->name->c_str());
		dfs.puts("\n");
		if (st->ssyms.Find(na, rettype, typearray, exact)) {
			sp = TABLE::match[TABLE::matchno - 1];
			ADD_SYMS
				dfs.printf("Found as an auto var\n");
		}
		// If the statment is a function body
		if (st->fi) {
			dfs.printf("Looking at params %p\n", (char*)&st->fi->params);
			if (st->fi->params.Find(na, rettype, typearray, exact)) {
				sp = TABLE::match[TABLE::matchno - 1];
				ADD_SYMS
					dfs.printf("Found as parameter\n");
			}
		}
	}
}

// first look in the current compound statement for the symbol,
// Next look in progressively more outer compound statements
// Next look in the local symbol table for the function
// Finally look in the global symbol table.
//
Symbol *Expression::gsearch2(std::string na, __int16 rettype, TypeArray *typearray, bool exact)
{
	Symbol *sp;
	Symbol* sp1;
	Statement *st;
	Symbol *p, *q, *f;
	int n;
	int nn;

	gSearchCnt = 0;
	ZeroMemory(gSearchSyms, sizeof(gSearchSyms));
	dfs.printf("\n<gsearch2> for: |%s|\n", (char *)na.c_str());
	prefix = nullptr;
	sp = currentSym;
	if (sp) {
		if (p = sp->Find(na)) {
			gSearchCnt = 0;
			gSearchSyms[0] = p;
			return (p);
		}
		else {
			if (sp->tp->lst.FindRising(na))
				p = sp->tp->lst.match[0];
			if (p)
				return (p);
		}
	}
	sp = nullptr;
	// There might not be a current statement if global declarations are
	// being processed.
	if (owning_stmt==nullptr) {
	  dfs.printf("Stmt=null, looking in global table\n");
		if (gsyms[0].Find(na,rettype,typearray,exact)) {
			sp = TABLE::match[TABLE::matchno-1];
			dfs.printf("Found in global symbol table\n");
			dfs.puts("</gsearch2>\n");
			return (sp);
		}
		dfs.puts("</gsearch2>\n");
		goto j2;
		return (nullptr);
	}

	/*
	if (currentStmt->ssyms.ownerp) {
		sp = currentStmt->ssyms.ownerp;
		if (sp->Find(na)) {	// Will search parent tables
			sp = TABLE::match[TABLE::matchno - 1];
			ADD_SYMS
			dfs.printf("Found as an auto var\n");
		}
	}
	*/
	// Look in progressively more outer statements for the symbol.
	SearchStatements(owning_stmt, na, rettype, typearray, exact);
j2:
	// If the statment is a function body
	if (owning_func) {
		dfs.printf("Looking at params %p\n", (char*)&owning_func->params);
		if (owning_func->params.Find(na, rettype, typearray, exact)) {
			sp = TABLE::match[TABLE::matchno - 1];
			ADD_SYMS
				dfs.printf("Found as parameter\n");
		}
		if (sp == nullptr)
			SearchStatements(owning_func->body, na, rettype, typearray, exact);
	}

	/*
	for (st = owning_stmt; st && gSearchCnt < 100; st = st->outer) {
		dfs.printf("Looking in statement table\n");
		if (st->ssyms.Find(na,rettype,typearray,exact)) {
			sp = TABLE::match[TABLE::matchno-1];
			ADD_SYMS
			dfs.printf("Found as an auto var\n");
		}
		// If the statment is a function body
		if (st->fi) {
			dfs.printf("Looking at params %p\n", (char*)&st->fi->params);
			if (st->fi->params.Find(na, rettype, typearray, exact)) {
				sp = TABLE::match[TABLE::matchno - 1];
				ADD_SYMS
				dfs.printf("Found as parameter\n");
			}
		}
	}
	*/

j1:
	/*
	p = nullptr;
	if (currentFn->sym->fi) {
		if (currentFn->sym->fi->body)
			p = currentFn->sym->fi->body->ssyms.headp;
	}
	else
	*/
	/*
	p = currentFn->sym;
	if (p) {
		while (p) {
			
			dfs.printf("Looking in function's symbol table\n");
  		if (p->lsyms.Find(na,rettype,typearray,exact)) {
  			sp = TABLE::match[TABLE::matchno-1];
				ADD_SYMS
				dfs.printf("Found in function symbol table (a label)\n");
  			//dfs.puts("</gsearch2>\n");
  			//return (sp);
  		}
			
  		dfs.printf((char *)"Searching method/class:%s|%p\n",(char *)p->name->c_str(),(char *)p);
  		if (p->tp) {
    		if (p->tp->type != bt_class) {
      		dfs.printf("Looking at params %p\n",(char *)&p->fi->params);
      		if (p->fi->params.Find(na,rettype,typearray,exact)) {
      			sp = TABLE::match[TABLE::matchno-1];
						ADD_SYMS
						dfs.printf("Found as parameter\n");
      		}
					q = p->parentp;
					if (q)
						dfs.printf("Looking at params %p\n", (char*)&q->fi->params);
					while (q) {
						if (q->fi->params.Find(na, rettype, typearray, exact)) {
							sp = TABLE::match[TABLE::matchno - 1];
							ADD_SYMS
							dfs.printf("Found as parameter\n");
						}
						q = q->parentp;
					}
					q = p->lsyms.headp;
					if (q) {
						dfs.printf("Looking at childs params %p\n", (char*)&q->fi->params);
					}
					while (q) {
						if (q->fi->params.Find(na, rettype, typearray, exact)) {
							sp = TABLE::match[TABLE::matchno - 1];
							ADD_SYMS
							dfs.printf("Found as parameter\n");
						}
						q = q->nextp;
						if (q == p->lsyms.headp)
							break;
					}
    		}
    		// Search for class member
    		dfs.printf("Looking at class members %p\n",(char *)&p->tp->lst);
    		if (p->tp->type == bt_class) {
    			Symbol *tab;
    			int nn;
    			if (p->tp->lst.Find(na,rettype,typearray,exact)) {
    				sp = TABLE::match[TABLE::matchno-1];
						ADD_SYMS
						dfs.printf("Found in class\n");
    			}
    			dfs.printf("Base=%p",(char *)p->tp->lst.basep);
    			tab = p->tp->lst.basep;
    			dfs.printf("Base=%p",(char *)tab);
    			if (tab) {
    				dfs.puts("Has a base class");
    				if (tab->tp) {
           		dfs.printf("Looking at base class members:%p\n",(char *)tab);
        			nn = tab->tp->lst.FindRising(na);
        			if (nn > 0) {
                dfs.printf("Found in base class\n");
        				if (exact) {
           				//sp = sp->FindRisingMatch();
        				  sp = Function::FindExactMatch(TABLE::matchno, na, bt_int, typearray)->sym;
        				  if (sp) {
										if (gSearchCnt < 100) {
											gSearchSyms[gSearchCnt] = sp;
											gSearchCnt++;
										}
                		dfs.puts("</gsearch2>\n");
        				    return (sp);
      				    }
        				}
        				else {
    				      sp = TABLE::match[0];
									ADD_SYMS
    				    }
    				  }
      			}
    			}
  			}
  		}
			if (p->nextp)
				p = p->nextp;
			else
	  		p = p->parentp;
  	}
  }
	*/
	// Finally, look in the global symbol table
	dfs.printf("Looking at global symbols\n");
	if (gsyms[0].Find(na,rettype,typearray,exact)) {
		sp = TABLE::match[TABLE::matchno-1];
		ADD_SYMS
		dfs.printf("Found in global symbol table\n");
//			dfs.puts("</gsearch2>\n");
//			return (sp);
	}
	// Second finally, search for an enum
	dfs.printf("Looking at enums\n");
	for (n = 0; n < 32768*10; n++) {
		sp1 = compiler.symTables[n >> 15];
		if (sp1) {
			sp = &compiler.symTables[n >> 15][n & 0x7fff];
			if (sp->name) {
				if (sp->name->compare(na) == 0) {
					if (sp->tp == &stdconst || sp->tp->type == bt_enum) {
						if (gSearchCnt < 100) {
							gSearchSyms[gSearchCnt] = sp;
							gSearchCnt++;
						}
						TABLE::match[0] = sp;
						TABLE::matchno = 1;
					}
				}
			}
		}
	}
	ZeroMemory(TABLE::match, sizeof(TABLE::match));
	memcpy(TABLE::match, gSearchSyms, gSearchCnt * sizeof(Symbol*));
	TABLE::matchno = gSearchCnt;
	if (TABLE::matchno > 0)
		sp = TABLE::match[0];
	else
		sp = nullptr;
	dfs.puts("</gsearch2>\n");
  return (sp);
}

// A wrapper for gsearch2() when we only care about finding any match.
/*
Symbol *gsearch(std::string name)
{
	return (gsearch2(name, bt_int, nullptr, false));
}
*/

// Create a copy of a symbol, used when creating derived classes from base
// classes. The type is copyied and extended by a derived class.

Symbol *Symbol::Copy(Symbol *src)
{
	Symbol *dst = nullptr;

  dfs.printf("Enter Symbol::Copy\n");
	if (src) {
		dst = Symbol::alloc();
		dfs.printf("A");
		memcpy(dst, src, sizeof(Symbol));
//		dst->tp = TYP::Copy(src->tp);
//		dst->name = src->name;
//		dst->shortname = src->shortname;
		dst->SetNext(0);
		if (src->fi) {
			dst->fi = dst->MakeFunction(src->id, false);
			memcpy(dst->fi, src->fi, sizeof(Function));
			dst->fi->sym = dst;
			dst->fi->params.ownerp = src;// SetOwner(src->id);
			dst->fi->proto.ownerp = src;// SetOwner(src->id);
		}
  }
  dfs.printf("Leave Symbol::Copy\n");
	return (dst);
}

Symbol* Symbol::FindInUnion(std::string nme)
{
	return (tp->lst.Find(nme,false));
}

Symbol *Symbol::Find(std::string nme)
{
	Symbol *sp;
	Symbol* head, * n;

//	printf("Enter Find(char *)\r\n");

	sp = lsyms.Find(nme,false);			// search for a variable
	if (sp)
		return (sp);
	sp = tp->lst.Find(nme, false);	// search for method name
	if (sp)
		return (sp);
	if (stmt) {
		sp = stmt->ssyms.Find(nme, false);
		if (sp)
			return (sp);
	}
	if (fi)
		if (fi->body)
			sp = fi->body->ssyms.Find(nme, false);
	if (sp)
		return (sp);

	if (parentp)										// search parent object
		sp = parentp->Find(nme);
	if (sp == nullptr) {
		for (n = tp->lst.headp; n; n = n->nextp) {
			if (n->tp->IsUnion()) {
				if (sp = n->FindInUnion(nme))
					return (sp);
			}
			if (n == tp->lst.tailp)
				break;
		}
	}
//	printf("Leave Find(char *):%p\r\n",sp);
	return (sp);
}

int Symbol::FindNextExactMatch(int startpos, TypeArray * tb)
{
	Symbol *sp1;
	int nn;
	TypeArray *ta;

	sp1 = nullptr;
	for (nn = startpos; nn < TABLE::matchno; nn++) {
		sp1 = TABLE::match[nn];
		if (fi) {
			ta = sp1->fi->GetProtoTypes();
			if (ta->IsEqual(tb)) {
				delete ta;
				return (nn);
			}
			delete ta;
		}
	}
	return (-1);
}


Symbol *Symbol::FindRisingMatch(bool ignore)
{
	int nn;
	int em;
	int iter;
	Symbol *s = this;
	std::string nme;
	TypeArray *ta = nullptr;

	nme = *name;//*GetFullName();// *name;
	if (fi)
		ta = fi->GetProtoTypes();
	dfs.printf((char *)"<FindRisingMatch>%s type %d ", (char *)name->c_str(), tp->type);
	if (GetParentPtr() != nullptr)
		nn = GetParentPtr()->tp->lst.FindRising(nme);
	else
		nn = 1;
	//  nn = tp->lst.FindRising(nme);
	iter = 0;
	if (nn) {
		dfs.puts("Found method:");
		for (iter = 0; true; iter = em + 1) {
			em = FindNextExactMatch(iter, ta);
			if (em < 0)
				break;
			s = TABLE::match[em];
			if (!ignore || s->GetParentPtr() != GetParentPtr()) { // ignore entry here
				dfs.puts("Found in a base class:");
				break;
			}
			s = nullptr;
		}
	}
	if (ta)
		delete ta;
	dfs.printf("</FindRisingMatch>\n");
	return (s);
}


// Convert a type number to a character string
// These will always be four characters.

std::string *TypenoToChars(int typeno)
{
	const char *alphabet =
		"ABCDEFGHIJKLMNOPQRSTUVWXYZ123456";
	char c[8];
	std::string *str;

  dfs.puts("<TypenoToChars>");
  str = new std::string();
  dfs.putch('A');
	c[0] = alphabet[typeno & 31];
  dfs.putch('B');
	c[1] = alphabet[(typeno>>5) & 31];
  dfs.putch('C');
	c[2] = alphabet[(typeno>>10) & 31];
  c[3] = alphabet[(typeno>>15) & 31];
  c[4] = '\0';
  c[5] = '\0';
  c[6] = '\0';
  c[7] = '\0';
  dfs.puts("D:");
	str->append(c);
	dfs.printf("%s",(char *)str->c_str());
  dfs.puts("</TypenoToChars>");
	return (str);
}

// Get the mangled name for the function
//
std::string *Symbol::GetNameHash()
{
	std::string *nh;
  Symbol *sp;
  int nn;

  dfs.puts("<GetNameHash>");
  dfs.printf("tp:%p",(char *)tp);
//  if (tp==(TYP *)0x500000005LL) {
//    nh = new std::string("TAA");
//    return nh;
//  }
	nh = TypenoToChars(tp->typeno);
  dfs.putch('A');
  sp = GetParentPtr();
  if (sp) {
     nh->append(*sp->GetNameHash());
	   sp = sp->tp->lst.basep;
     dfs.putch('B');
   	 for (nn = 0; sp && nn < 200; nn++) {
  	   dfs.putch('.');
  	   nh->append(*sp->GetNameHash());
			 sp = sp->tp->lst.basep;
  	 }
	   if (nn >= 200) {
	     error(ERR_CIRCULAR_LIST);
    }
	}
/*
	if (parent) {
	  sp = GetPtr(parent);
		nh += sp->GetNameHash();
	}
*/
  dfs.puts("</GetNameHash>\n");
	return (nh);
}

// Build a function signature string including
// the return type, base classes, and any parameters.

std::string *Symbol::BuildSignature(int opt)
{
	std::string *str;
	std::string *nh;

	dfs.printf("<BuildSignature>");
	if (this == nullptr) {
		str = new std::string("");
		str->append(*name);
		dfs.printf(":%s</BuildSignature>", (char *)str->c_str());
		return (str);
	}
	if (mangledNames) {
		str = new std::string("_Z");		// 'C' likes this
		dfs.printf("A");
		nh = GetNameHash();
		dfs.printf("B");
		str->append(*nh);
		dfs.printf("C");
		delete nh;
		dfs.printf("D");
		if (name > (std::string *)0x15)
			str->append(*name);
	}
	else {
		str = new std::string("");
		str->append(*name);
	}
	if (opt) {
		dfs.printf("E");
		str->append(*fi->GetParameterTypes()->BuildSignature());
	}
	else {
		dfs.printf("F");
		str->append(*fi->GetProtoTypes()->BuildSignature());
	}
	dfs.printf(":%s</BuildSignature>", (char *)str->c_str());
	return str;
}

std::string* Symbol::GetFullName()
{
	Symbol* s;
	int n;
	std::string *nme;
	static std::string *names[32];

	ZeroMemory(names, sizeof(names));
	for (n = 0,s = this->parentp; s && n < 32; s = s->parentp) {
		if (mangledNames)
			names[n] = s->mangledName;
		else
			names[n] = s->name;
		n++;
	}
	nme = new std::string("");
	for (--n; n >= 0; n--) {
		nme->append(*names[n]);
		nme->append("_");
	}
	if (mangledNames)
		nme->append(*BuildSignature(0));
	else
		nme->append(*name);
	return (nme);
}

std::string* Symbol::GetFullNameByFunc(std::string nm)
{
	Symbol* s;
	int n;
	std::string* nme;
	static std::string* names[32];

	ZeroMemory(names, sizeof(names));
	s = currentFn->sym;
	for (n = 0; s && n < 32; s = s->parentp) {
		names[n] = s->mangledName;
		n++;
	}
	nme = new std::string("");
	for (--n; n >= 0; n--) {
		nme->append(*names[n]);
		nme->append("_");
	}
	nme->append(nm);
	return (nme);
}

// Called during declaration parsing.

// Auto variables are referenced negative to the base pointer
// Structs need to be aligned on the boundary of the largest
// struct element. If a struct is all chars this will be 2.
// If a struct contains a pointer this will be 8. It has to
// be the worst case alignment.

void Symbol::SetStorageOffset(TYP *head, int nbytes, int al, int ilc, int ztype)
{
	if (head == nullptr) {
		head = this->tp;
		if (head == nullptr)
			head = TYP::Make(bt_int, sizeOfInt);
	}
	// Set the struct member storage offset.
	if (al == sc_static || al == sc_thread) {
		value.i = nextlabel++;
	}
	else if (ztype == bt_union) {
		value.i = ilc;// + parentBytes;
	}
	else if (al != sc_auto) {
		value.i = ilc + nbytes;// + parentBytes;
	}
	else {
		value.i = -(ilc + nbytes + head->roundSize());// + parentBytes);
	}
//	if (head == nullptr) {
//		head = TYP::Make(bt_int, sizeOfInt);
//	}
	head->struct_offset = value.i;
}


// Increase the storage allocation by the type size.

int Symbol::AdjustNbytes(int nbytes, int al, int ztype)
{
	if (ztype == bt_union)
		nbytes = imax(nbytes, tp->roundSize());
	else if (al != sc_external) {
		// If a pointer to a function is defined in a struct.
		if (isStructDecl) {
			if (tp->type == bt_func) {
				nbytes += 8;
			}
			else if (tp->type != bt_ifunc) {
				nbytes += tp->roundSize();
			}
		}
		else {
			nbytes += tp->roundSize();
		}
	}
	return (nbytes);
}

// Initialize the type. Unions can't be initialized. Oh yes they can.
// The node list coming in already has proper types assigned to it.

int64_t Symbol::Initialize(txtoStream& tfs, ENODE* pnode, TYP* tp2, int opt)
{
	static int level = 0;
	int64_t nbytes;
	int base, nn;
	int64_t sizes[100];
	char idbuf[sizeof(lastid) + 1];
	ENODE* node;
	Expression exp(cg.stmt);
	bool init_array = false;

	if (ENODE::initializedSet.isMember(pnode->number))
		return (0);
	// Assign a default node if there isn't one.
	if (pnode == nullptr) {
		if (tp2->IsFloatType())
			pnode = makefqnode(en_fcon, Float128::Zero());
		else if (tp2->IsScalar())
			pnode = makeinode(en_icon, 0);
	}
	return (GenerateT(tfs, pnode, tp2));
	/*
	do {
		//if (lastst == assign)
		//	NextToken();
		switch (tp->type) {
		case bt_ubyte:
		case bt_byte:
			nbytes = initbyte(this,opt);
			break;
		case bt_uchar:
		case bt_char:
		case bt_enum:
			nbytes = initchar(this, opt);
			break;
		case bt_ushort:
		case bt_short:
			nbytes = initshort(this, pnode ? pnode->i : 0, opt);
			break;
		case bt_uint:
		case bt_int:
			nbytes = initint(this, pnode ? pnode->i : 0, opt);// (this, opt);
			break;
		case bt_pointer:
			if (tp->val_flag)
				nbytes = InitializeArray(pnode);
			else
				nbytes = InitializePointer(tp, opt, this);
			break;
		case bt_exception:
		case bt_ulong:
		case bt_long:
			//strncpy(idbuf, lastid, sizeof(lastid));
			//strncpy(lastid, pnode->sym->name->c_str(), sizeof(lastid));
			//gNameRefNode = exp.ParseNameRef();
			nbytes = initlong(this, opt);
			//strncpy(lastid, idbuf, sizeof(lastid));
			break;
		case bt_struct:
			nbytes = InitializeStruct(pnode);
			break;
		case bt_union:
			nbytes = InitializeUnion(pnode);
			break;
		case bt_quad:
			nbytes = initquad(this, opt);
			break;
		case bt_float:
		case bt_double:
			nbytes = initfloat(this, opt);
			break;
		case bt_posit:
			nbytes = initPosit(this, opt);
			break;
		default:
			error(ERR_NOINIT);
			nbytes = 0;
		}
		if (tp2 != nullptr)
			return (nbytes);
		if (lastst != comma || brace_level == 0)
			break;
		//NextToken();
		if (lastst == end)
			break;
	} while (0);
	*/
j2:
	/*
	if (init_array) {
		while (lastst == end) {
			brace_level--;
			NextToken();
		}
		if (brace_level != 0) {
			if (lastst == comma) {
				NextToken();
				if (lastst == end)
					goto j2;
				goto j1;
			}
		}
	}
	*/
	return (nbytes);
}

int64_t Symbol::InitializeArray(txtoStream& tfs, ENODE* rootnode, TYP* tp)
{
	int64_t nbytes;
	int64_t count;
	ENODE* node, *temp;
	ENODE tnode;
	List* lst, *hlst;
	bool oval;

	nbytes = 0;

	// Do we have a pointer to a character type? These may be initialized with a
	// string.
	if (rootnode->tp->btpp->IsCharType()) {
		if (rootnode->sp) {
			string_exclude.add(rootnode->i);
			for (count = 0; count < rootnode->sp->length() && (count < tp->size || tp->unknown_size); count++) {
				tnode.nodetype = en_icon;
				tnode.i = rootnode->sp->c_str()[count];
				nbytes += GenerateT(tfs, &tnode, rootnode->tp->btpp);
			}
			// Generate null character at end of string.
			tnode.nodetype = en_icon;
			tnode.i = 0;
			nbytes += GenerateT(tfs, &tnode, rootnode->tp->btpp);
			count++;
			if (nbytes < tp->size)
				genstorage(tfs, tp->size - nbytes);
			if (tp->unknown_size) {
				tp->numele = count;
				return (count * tp->btpp->size);
			}
			return (tp->size);
		}
	}

	node = rootnode;
	hlst = lst = node->ReverseList(node);
	for (count = tp->numele; lst != nullptr; lst = lst->nxt) {
		node = lst->node;
		/*
		while (nbytes < sp->tp->size) {// sp->value.i) {     // align properly
											 //                    nbytes += GenerateByte(0);
			GenerateByte(0);
			nbytes++;
		}
		*/
		if (node != nullptr && node != rootnode) {
			tp->dimen;
			if (tp->dimen < 2) {
				oval = lst->node->tp->val_flag;
				lst->node->tp->val_flag = false;
			}
			if (true || !ENODE::initializedSet.isMember(node->number)) {
				nbytes += Initialize(tfs, node, tp->btpp, 0);
//				ENODE::initializedSet.add(node->number);
			}
			if (tp->dimen < 2)
				lst->node->tp->val_flag = oval;
			count--;
		}
	}
	if (nbytes < tp->size)
		genstorage(tfs, tp->size - nbytes);
	delete[] hlst;
	return (tp->size);
}

int64_t Symbol::InitializeStruct(txtoStream& tfs, ENODE* rootnode, TYP* tp)
{
	static int level = 0;
	Symbol* sp, *hd;
	int64_t nbytes;
	int count;
	TYP* typ, *t;
	TABLE* tbl;
	List* lst, *hlst;
	ENODE* node, *temp;

	level++;
	nbytes = 0;
	//sp = sp->GetPtr(tp->lst.GetHead());      /* start at top of symbol table */
	//tbl = &this->tp->lst;
	tbl = &tp->lst;
	hd = sp = tbl->headp;// this->GetPtr(tbl->GetHead());
	count = 0;
	typ = nullptr;
	node = rootnode;
	hlst = lst = node->ReverseList(node);
	for (; sp != 0 && lst != nullptr; lst = lst->nxt) {
		node = lst->node;
		/*
		while (nbytes < sp->tp->size) {// sp->value.i) {     // align properly
											 //                    nbytes += GenerateByte(0);
			GenerateByte(0);
			nbytes++;
		}
		*/
		//currentSym = sp;
		if (node == nullptr)
			continue;
		if (node != nullptr && node != rootnode) {
			if (!ENODE::initializedSet.isMember(node->number)) {
				//t = node->tp;
				//if (t == nullptr)
					t = sp->tp;
				if (node->nodetype == en_unknown) {
					node = makeinode(en_icon, 0);
					node->SetType(&stdint);
				}
				nbytes += sp->Initialize(tfs, node, t, 0);
//				ENODE::initializedSet.add(node->number);
			}
		}
		else {
			temp = makeinode(en_icon, 0);
			temp->tp = &stdint;
			nbytes += sp->Initialize(tfs, temp, sp->tp, 0);
		}
		sp = sp->nextp;
		if (sp == hd || sp == nullptr)
			break;
		count++;
	}
	if (nbytes < tp->size)
		genstorage(tfs, tp->size - nbytes);
	//	needpunc(end, 26);
	level--;
	delete[] hlst;
	return (tp->size);
}

int64_t Symbol::InitializeUnion(txtoStream& tfs, ENODE* rootnode, TYP* tp)
{
	Symbol* sp, * osp;
	int64_t nbytes;
	bool found = false;
	TYP* ntp;
	int count;
	List* lst, *hlst;
	ENODE* node, *pnode;
	int64_t ne;
	bool oval;

	nbytes = 0;
	node = rootnode;
	if (node == nullptr)	// syntax error in GetConstExpression()
		return (0);
	pnode = node->p[0];
	/* start at top of symbol table */
	hlst = lst = node->ReverseList(node);
	count = 0;
	// An array of values matching a union?
	// pnode might be null as there may just be a single value coming in.
	if (pnode && pnode->nodetype == en_end_aggregate) {
		ntp = pnode->tp;
		node = pnode->p[0];
	}
	else
		ntp = tp;
	// There is only one element in the union position, though it may be an array.
	// So, we only count to one.
	if (ntp->type == bt_array || (ntp->type == bt_pointer && ntp->val_flag)) {
		ne = ntp->numele;
		ntp = ntp->btpp;
		for (count = 0; count < 1; count++)
			nbytes += ntp->GenerateT(tfs, node);
//		ENODE::initializedSet.add(node->number);
	}
	else if (ntp->type != bt_union) {
		if (TYP::IsSameType(ntp, tp->btpp, false)) {
			do {
				if (lst->node == rootnode)
					continue;
				if (!ENODE::initializedSet.isMember(lst->node->number)) {
					nbytes += GenerateT(tfs, lst->node, ntp);
//					ENODE::initializedSet.add(lst->node->number);
				}
				ntp = lst->node->tp;
				if (lst->node)
					if (!TYP::IsSameType(lst->node->tp, tp->btpp, false))
						break;
				lst = lst->nxt;
			} while (lst);
		}
	}
	else {
		node = nullptr;
		for (; lst; lst = lst->nxt) {
			node = lst->node;
			if (node == rootnode)
				continue;
			// If node is a null pointer then there was an empty exression at the 
			// location of the field to fill. Assume a zero value, and use the
			// first type of the list. Some type contained in the list of types must
			// be set.
			if (node == nullptr) {
				node = makeinode(en_icon, 0);	// set value field to null
				node->tp = tp->lst.headp->tp;
			}
			// Search the list of types in the union for a type matching the node.
			for (osp = sp = tp->lst.headp; sp != nullptr; sp = sp->nextp) {
				if (TYP::IsSameType(sp->tp, node->tp, false)) {
					if (!ENODE::initializedSet.isMember(node->number)) {
						nbytes = GenerateT(tfs, node, sp->tp);
						ENODE::initializedSet.add(node->number);
					}
					found = true;
					break;
				}
				if (sp == osp || sp == tp->lst.tailp)
					break;
			}
			if (!found)
				error(ERR_INIT_UNION);
			if (lastst != semicolon && lastst != comma && lastst != end)
				error(ERR_PUNCT);
		}
	}
	if (nbytes < tp->size)
		genstorage(tfs, tp->size - nbytes);
	delete[] hlst;
	return (tp->size);
}

int64_t Symbol::InitializePointerToUnion(txtoStream& tfs, ENODE* rootnode, TYP* tp)
{
	int64_t nbytes;
	Symbol* sp;
	std::string lbl;

	nbytes = sizeOfPtr;
	switch (sizeOfPtr) {
	case 4: rootnode->GenerateShort(tfs); break;
	case 8: rootnode->GenerateInt(tfs); break;
	case 16: rootnode->GenerateLong(tfs); break;
	}
	sp = Symbol::initsym;
	if (sp) {
		lbl = *sp->name;
		lbl.append("_data");
		put_label(tfs, (int)sp->value.i, (char*)lbl.c_str(), GetPrivateNamespace(), 'D', tp->size);
	}
	return (nbytes);
}

int64_t Symbol::InitializePointerToStruct(txtoStream& tfs, ENODE* rootnode, TYP* tp)
{
	int64_t nbytes;
	Symbol* sp;

	if (initlvl == 1) {
		nbytes = sizeOfPtr;
		switch (syntax) {
		case MOT:
			switch (sizeOfPtr) {
			case 4: tfs.puts("\n\tdc.l\t"); nbytes = 4; break;
			case 8: tfs.puts("\n\tdc.q\t"); nbytes = 8; break;
			case 16: tfs.puts("\n????\t"); nbytes = 16; break;
			}
			break;
		default:
			switch (sizeOfPtr) {
			case 4: tfs.puts("\n\t.4byte\t"); nbytes = 4; break;
			case 8: tfs.puts("\n\t.8byte\t"); nbytes = 8; break;
			case 16: tfs.puts("\n\t.16byte\t"); nbytes = 16; break;
			}
		}
		sp = Symbol::initsym;
		if (sp) {
			//lbl = GetPrivateNamespace();
			tfs.puts(sp->name->c_str());
			tfs.puts("_data\n");
			tfs.puts(sp->name->c_str());
			tfs.puts("_data:\n");
			tfs.flush();
			//		put_label(tfs, (int)sp->value.i, (char*)lbl.c_str(), GetPrivateNamespace(), 'D', tp->size);
		}
	}
	else {
		nbytes = sizeOfPtr;
		switch (sizeOfPtr) {
		case 4: rootnode->GenerateShort(tfs); nbytes = 4;  break;
		case 8: rootnode->GenerateInt(tfs); nbytes = 8;  break;
		case 16: rootnode->GenerateLong(tfs); nbytes = 16; break;
		}
	}
	return (nbytes);
}

int64_t Symbol::GenerateT(txtoStream& tfs, ENODE* node, TYP* ptp)
{
	int64_t nbytes;
	int64_t val;

	nbytes = 0;
	if (node == nullptr)
		return (0);
	if (!node->constflag)
		;
	if (node->nodetype==en_ref)
		;
	if (ENODE::initializedSet.isMember(node->number))
		return (0);
	if (ptp == nullptr)
		ptp = this->tp;
	initlvl++;
	switch (ptp->type) {
	case bt_byte:
		val = node->i;
		nbytes = 1; GenerateByte(tfs, val);
		break;
	case bt_ubyte:
		val = node->i;
		nbytes = 1;
		GenerateByte(tfs, val);
		break;
	case bt_ichar:
	case bt_char:
	case bt_enum:
		val = node->i;
		nbytes = 2; GenerateChar(tfs, val); break;
	case bt_iuchar:
	case bt_uchar:
		val = node->i;
		nbytes = 2; GenerateChar(tfs, val); break;
	case bt_short:
		val = node->i;
		nbytes = 4; GenerateHalf(tfs, val); break;
	case bt_ushort:
		val = node->i;
		nbytes = 4; GenerateHalf(tfs, val); break;
	case bt_int:
	case bt_uint:
		val = node->i;
		nbytes = 8; GenerateInt(tfs, val); break;
	case bt_long:
		val = node->i;
		nbytes = 8; GenerateLong(tfs, val); break;
	case bt_exception:
	case bt_ulong:
		val = node->i;
		nbytes = 8; GenerateLong(tfs, val); break;
	case bt_float:
		nbytes = 8; GenerateFloat(tfs, (Float128*)&node->f128); break;
	case bt_double:
		nbytes = 8; GenerateFloat(tfs, (Float128*)&node->f128); break;
	case bt_quad:
		nbytes = 16; GenerateQuad(tfs, (Float128*)&node->f128); break;
	case bt_posit:
		nbytes = 8; GeneratePosit(tfs, node->posit); break;
	case bt_struct:
		nbytes = InitializeStruct(tfs, node, ptp);
		break;
	case bt_union:
		nbytes = InitializeUnion(tfs, node, ptp);
		break;
	case bt_pointer:
		// Is it an array?
		if (ptp->val_flag)
			nbytes = InitializeArray(tfs, node, ptp);
		else {
			if (ptp->btpp->IsAggregateType()) {
				if (ptp->btpp->type == bt_union) {
					nbytes = InitializePointerToUnion(tfs, node, ptp->btpp);
					nbytes += InitializeUnion(tfs, node, ptp->btpp);
				}
				else if (ptp->btpp->type == bt_struct) {
					nbytes = InitializePointerToStruct(tfs, node, ptp->btpp);
					nbytes += InitializeStruct(tfs, node, ptp->btpp);
				}
			}
			else {
				if (node->nodetype == en_labcon) {
					GenerateLabelReference(tfs, node->i_lhs, 0, (char *)node->GetLabconLabel(node->i_lhs)->c_str());
				}
				else {
					nbytes = sizeOfPtr;
					switch (sizeOfPtr) {
					case 4: node->GenerateShort(tfs); break;
					case 8: node->GenerateInt(tfs); break;
					case 16: node->GenerateLong(tfs); break;
					}
				}
			}
		}
		break;
	case bt_array:
		nbytes = this->InitializeArray(tfs, node, ptp);
		break;
		//case bt_struct:	nbytes = InitializeStruct(); break;
	default:
		;
	}
//	ENODE::initializedSet.add(node->number);
	initlvl--;
	return (nbytes);
}


void Symbol::storeHex(txtoStream& ofs)
{
	ofs.write("Symbol:");
	ofs.writeAsHex((char *)this, sizeof(Symbol));
	ofs.printf(":%05d", fi->number);
	ofs.printf(":%05d", tp->typeno);
}
