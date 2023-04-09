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

char *prefix;
extern int nparms;
extern bool isRegister;
SYM* currentSym = nullptr;

static SYM* gSearchSyms[100];
static int gSearchCnt;

Function* SYM::MakeFunction(int symnum, bool isPascal) {
	Function* fn = compiler.ff.MakeFunction(symnum, this, isPascal);
	return (fn);
};

SYM *SYM::GetPtr(int n)
{ 
	SYM* p1;
  if (n==0)
    return (nullptr);
	if ((n >> 15) > 9)
		return (nullptr);
	p1 = compiler.symTables[n >> 15];
	if (p1 == nullptr)
		return (nullptr);
  return (SYM *)&compiler.symTables[n>>15][n & 0x7fff]; 
}

SYM *SYM::GetNextPtr()
{ 
	SYM* p1;
	if (next == 0)
		return (nullptr);
	if ((next >> 15) > 9)
		return (nullptr);
	p1 = compiler.symTables[next >> 15];
	if (p1 == nullptr)
		return (nullptr);
	return (SYM*)&compiler.symTables[next >> 15][next & 0x7fff];
}

SYM *SYM::GetParentPtr()
{
	SYM* p1;
	if (parent == 0)
		return (nullptr);
	if ((parent >> 15) > 9)
		return (nullptr);
	p1 = compiler.symTables[parent >> 15];
	if (p1 == nullptr)
		return (nullptr);
	return (SYM*)&compiler.symTables[parent >> 15][parent & 0x7fff];
};

int SYM::GetIndex()
{
	SYM* p1;
	if (this==nullptr)
     return 0;
	return (this->id);
//	return this - &compiler.symbolTable[0];
};

bool SYM::IsTypedef()
{
	SYM* p, * q, *first, *next;

	q = nullptr;
	for (first = p = GetParentPtr(); p; p = next) {
		q = p;
		next = p->GetParentPtr();
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

SYM *search2(std::string na,TABLE *tbl,TypeArray *typearray)
{
	SYM *thead, *sp;
	TYP* tp;
	TypeArray *ta;

	if (&na == nullptr || tbl==nullptr || na == "")
		return nullptr;
//	printf("Enter search2\r\n");
	if (tbl == &gsyms[0])
		thead = compiler.symbolTable[0].GetPtr(hashadd((char*)na.c_str()));
	else if (tbl == &tagtable)
		thead = SYM::GetPtr(tagtable.GetHead());
	else
		thead = &compiler.symTables[tbl->GetHead() >> 15][tbl->GetHead() & 0x7fff];
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

SYM *search(std::string na,TABLE *tbl)
{
	return search2(na,tbl,nullptr);
}

// first look in the current compound statement for the symbol,
// Next look in progressively more outer compound statements
// Next look in the local symbol table for the function
// Finally look in the global symbol table.
//
SYM *gsearch2(std::string na, __int16 rettype, TypeArray *typearray, bool exact)
{
	SYM *sp;
	SYM* sp1;
	Statement *st;
	SYM *p, *q;
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
	}
	sp = nullptr;
	// There might not be a current statement if global declarations are
	// being processed.
	if (currentStmt==NULL) {
	  dfs.printf("Stmt=null, looking in global table\n");
		if (gsyms[0].Find(na,rettype,typearray,exact)) {
			sp = TABLE::match[TABLE::matchno-1];
			dfs.printf("Found in global symbol table\n");
			dfs.puts("</gsearch2>\n");
			return (sp);
		}
		dfs.puts("</gsearch2>\n");
		return (nullptr);
	}
	else {
    dfs.printf("Looking in statement table\n");
		if (currentStmt->ssyms.Find(na,rettype,typearray,exact)) {
			sp = TABLE::match[TABLE::matchno-1];
			ADD_SYMS
			dfs.printf("Found as an auto var\n");
//			dfs.puts("</gsearch2>\n");
//			return (sp);
		}
		st = currentStmt->outer;
		while (st && gSearchCnt < 100) {
			dfs.printf("Looking in outer statement table\n");
			if (st->ssyms.Find(na,rettype,typearray,exact)) {
				sp = TABLE::match[TABLE::matchno-1];
				ADD_SYMS
				dfs.printf("Found as an auto var\n");
//  			dfs.puts("</gsearch2>\n");
//				return (sp);
			}
			st = st->outer;
		}
j1:
		p = currentFn->sym;
		if (p) {
      dfs.printf("Looking in function's symbol table\n");
  		if (currentFn->sym->lsyms.Find(na,rettype,typearray,exact)) {
  			sp = TABLE::match[TABLE::matchno-1];
				ADD_SYMS
				dfs.printf("Found in function symbol table (a label)\n");
  			//dfs.puts("</gsearch2>\n");
  			//return (sp);
  		}
  		while(p) {
  			dfs.printf((char *)"Searching method/class:%s|%p\n",(char *)p->name->c_str(),(char *)p);
  			if (p->tp) {
    			if (p->tp->type != bt_class) {
      			dfs.printf("Looking at params %p\n",(char *)&p->fi->params);
      			if (p->fi->params.Find(na,rettype,typearray,exact)) {
      				sp = TABLE::match[TABLE::matchno-1];
							ADD_SYMS
							dfs.printf("Found as parameter\n");
//        			dfs.puts("</gsearch2>\n");
//      				return (sp);
      			}
						q = q->GetPtr(p->parent);
						if (q)
							dfs.printf("Looking at parents params %p\n", (char*)&q->fi->params);
						while (q) {
							if (q->fi->params.Find(na, rettype, typearray, exact)) {
								sp = TABLE::match[TABLE::matchno - 1];
								ADD_SYMS
								dfs.printf("Found as parameter\n");
//								dfs.puts("</gsearch2>\n");
//								return (sp);
							}
							q = q->GetPtr(p->parent);
						}
						q->GetPtr(p->lsyms.head);
						if (q) {
							dfs.printf("Looking at childs params %p\n", (char*)&q->fi->params);
						}
						while (q) {
							if (q->fi->params.Find(na, rettype, typearray, exact)) {
								sp = TABLE::match[TABLE::matchno - 1];
								ADD_SYMS
								dfs.printf("Found as parameter\n");
//								dfs.puts("</gsearch2>\n");
//								return (sp);
							}
							q = q->GetNextPtr();
							if (q == q->GetPtr(p->lsyms.head))
								break;
						}
    		  }
    			// Search for class member
    			dfs.printf("Looking at class members %p\n",(char *)&p->tp->lst);
    			if (p->tp->type == bt_class) {
    			  SYM *tab;
    			  int nn;
    				if (p->tp->lst.Find(na,rettype,typearray,exact)) {
    					sp = TABLE::match[TABLE::matchno-1];
							ADD_SYMS
							dfs.printf("Found in class\n");
//        			dfs.puts("</gsearch2>\n");
//    					return (sp);
    				}
    				dfs.printf("Base=%d",p->tp->lst.base);
    				tab = p->GetPtr(p->tp->lst.base);
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
//										dfs.puts("</gsearch2>\n");
//    				        return (sp);
    				      }
    				    }
      				}
    			  }
  			  }
  			}
  			p = p->GetParentPtr();
  		}
  	}
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
						if (sp->tp == &stdconst) {
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
	}
	ZeroMemory(TABLE::match, sizeof(TABLE::match));
	memcpy(TABLE::match, gSearchSyms, gSearchCnt * sizeof(SYM*));
	TABLE::matchno = gSearchCnt;
	if (TABLE::matchno > 0)
		sp = TABLE::match[0];
	else
		sp = nullptr;
	dfs.puts("</gsearch2>\n");
  return (sp);
}

// A wrapper for gsearch2() when we only care about finding any match.

SYM *gsearch(std::string name)
{
	return (gsearch2(name, bt_int, nullptr, false));
}


// Create a copy of a symbol, used when creating derived classes from base
// classes. The type is copyied and extended by a derived class.

SYM *SYM::Copy(SYM *src)
{
	SYM *dst = nullptr;

  dfs.printf("Enter SYM::Copy\n");
	if (src) {
		dst = allocSYM();
		dfs.printf("A");
		memcpy(dst, src, sizeof(SYM));
//		dst->tp = TYP::Copy(src->tp);
//		dst->name = src->name;
//		dst->shortname = src->shortname;
		dst->SetNext(0);
		if (src->fi) {
			dst->fi = dst->MakeFunction(src->id, false);
			memcpy(dst->fi, src->fi, sizeof(Function));
			dst->fi->sym = dst;
			dst->fi->params.SetOwner(src->id);
			dst->fi->proto.SetOwner(src->id);
		}
  }
  dfs.printf("Leave SYM::Copy\n");
	return (dst);
}

SYM* SYM::FindInUnion(std::string nme)
{
	return (tp->lst.Find(nme,false));
}

SYM *SYM::Find(std::string nme)
{
	SYM *sp;
	SYM* head, * n;

//	printf("Enter Find(char *)\r\n");
	sp = tp->lst.Find(nme,false);
	if (sp==nullptr) {
		if (parent) {
			sp = GetPtr(parent)->Find(nme);
		}
	}
	if (sp == nullptr) {
		for (n = SYM::GetPtr(tp->lst.head); n; n = n->GetNextPtr()) {
			if (n->tp->IsUnion()) {
				if (sp = n->FindInUnion(nme))
					return (sp);
			}
			if (n == SYM::GetPtr(tp->lst.tail))
				break;
		}
	}
//	printf("Leave Find(char *):%p\r\n",sp);
	return (sp);
}

int SYM::FindNextExactMatch(int startpos, TypeArray * tb)
{
	SYM *sp1;
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


SYM *SYM::FindRisingMatch(bool ignore)
{
	int nn;
	int em;
	int iter;
	SYM *s = this;
	std::string nme;
	TypeArray *ta = nullptr;

	nme = *name;
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
	return str;
}

// Get the mangled name for the function
//
std::string *SYM::GetNameHash()
{
	std::string *nh;
  SYM *sp;
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
	   sp = GetPtr(sp->tp->lst.base);
     dfs.putch('B');
   	 for (nn = 0; sp && nn < 200; nn++) {
  	   dfs.putch('.');
  	   nh->append(*sp->GetNameHash());
       sp = GetPtr(sp->tp->lst.base);
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
	return nh;
}

// Build a function signature string including
// the return type, base classes, and any parameters.

std::string *SYM::BuildSignature(int opt)
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


// Called during declaration parsing.

// Auto variables are referenced negative to the base pointer
// Structs need to be aligned on the boundary of the largest
// struct element. If a struct is all chars this will be 2.
// If a struct contains a pointer this will be 8. It has to
// be the worst case alignment.

void SYM::SetStorageOffset(TYP *head, int nbytes, int al, int ilc, int ztype)
{
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
	if (head == nullptr) {
		head = TYP::Make(bt_int, sizeOfInt);
	}
	head->struct_offset = value.i;
}


// Increase the storage allocation by the type size.

int SYM::AdjustNbytes(int nbytes, int al, int ztype)
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

int64_t SYM::Initialize(ENODE* pnode, TYP* tp2, int opt)
{
	static int level = 0;
	int64_t nbytes;
	int base, nn;
	int64_t sizes[100];
	char idbuf[sizeof(lastid) + 1];
	ENODE* node;
	Expression exp;
	bool init_array = false;

	return (GenerateT(pnode));
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

int64_t SYM::InitializeArray(ENODE* rootnode)
{
	int64_t nbytes;
	int64_t count;
	List* lst;
	ENODE* node;

	nbytes = 0;
	node = rootnode;
	if (node->nodetype == en_aggregate)
		node = node->p[0];
	lst = sortedList(nullptr, node);
	for (count = tp->numele; count && lst != nullptr; lst = lst->nxt, count--) {
		node = lst->node;
		/*
		while (nbytes < sp->tp->size) {// sp->value.i) {     // align properly
											 //                    nbytes += GenerateByte(0);
			GenerateByte(0);
			nbytes++;
		}
		*/
		if (node == nullptr || node==rootnode)
			break;
		nbytes += Initialize(node, tp, 0);
	}
	if (nbytes < tp->size)
		genstorage(tp->size - nbytes);
	return (tp->size);
}

int64_t SYM::InitializeStruct(ENODE* node)
{
	static int level = 0;
	SYM* sp, *hd;
	int64_t nbytes;
	int count;
	TYP* typ;
	ENODE* node2;
	TABLE* tbl;
	List* lst;

	level++;
	nbytes = 0;
	//sp = sp->GetPtr(tp->lst.GetHead());      /* start at top of symbol table */
	tbl = &this->tp->lst;
	hd = sp = tbl->headp;// this->GetPtr(tbl->GetHead());
	count = 0;
	typ = nullptr;
	lst = sortedList(nullptr, node);
	if (node->nodetype == en_aggregate)
		node = node->p[0];
	for (; sp != 0 && lst != nullptr; lst = lst->nxt) {
		node = lst->node;
		/*
		while (nbytes < sp->tp->size) {// sp->value.i) {     // align properly
											 //                    nbytes += GenerateByte(0);
			GenerateByte(0);
			nbytes++;
		}
		*/
		currentSym = sp;
		if (node == nullptr)
			break;
		nbytes += sp->Initialize(node, sp->tp, 0);
		sp = sp->nextp;
		if (sp == hd || sp == nullptr)
			break;
		count++;
	}
	if (nbytes < tp->size)
		genstorage(tp->size - nbytes);
	//	needpunc(end, 26);
	level--;
	return (tp->size);
}

int64_t SYM::InitializeUnion(ENODE* node)
{
	SYM* sp, * osp;
	int64_t nbytes;
	int64_t val;
	bool found = false;
	TYP* ntp;
	int count;
	ENODE* pnode;
	List* lst;

	nbytes = 0;
	if (node == nullptr)	// syntax error in GetConstExpression()
		return (0);
	      /* start at top of symbol table */
	count = 0;
	// An array of values matching a union?
	ntp = node->tp;
	if (ntp->type == bt_pointer && ntp->val_flag) {
		ntp = ntp->btpp;
		for (count = 0; count < ntp->numele; count++)
			nbytes += ntp->GenerateT(node);
	}
	else if (ntp->type != bt_union) {
		pnode = node;
		if (TYP::IsSameType(ntp, tp->btpp, false)) {
			lst = sortedList(nullptr, node);
			do {
				pnode = lst->node;
				nbytes += ntp->GenerateT(pnode);
				ntp = pnode->tp;
				lst = lst->nxt;
			} while (lst && TYP::IsSameType(ntp, tp->btpp, false));
		}
	}
	else {
		for (osp = sp = tp->lst.headp; sp != 0; sp = sp->nextp) {
			// Detect array of values
			if (TYP::IsSameType(sp->tp, node->tp, false)) {
				nbytes = sp->tp->GenerateT(node);
				found = true;
				break;
			}
			if (sp == osp)
				break;
		}
		if (!found)
			error(ERR_INIT_UNION);
		if (lastst != semicolon && lastst != comma && lastst != end)
			error(ERR_PUNCT);
	}
	if (nbytes < tp->size)
		genstorage(tp->size - nbytes);
	return (tp->size);
}

int64_t SYM::GenerateT(ENODE* node)
{
	int64_t nbytes;
	int64_t val;

	if (node == nullptr)
		return (0);
	if (!node->constflag)
		;
	if (node->nodetype==en_ref)
		;
	switch (tp->type) {
	case bt_byte:
		val = node->i;
		nbytes = 1; GenerateByte(val);
		break;
	case bt_ubyte:
		val = node->i;
		nbytes = 1;
		GenerateByte(val);
		break;
	case bt_ichar:
	case bt_char:
	case bt_enum:
		val = node->i;
		nbytes = 2; GenerateChar(val); break;
	case bt_iuchar:
	case bt_uchar:
		val = node->i;
		nbytes = 2; GenerateChar(val); break;
	case bt_short:
		val = node->i;
		nbytes = 4; GenerateHalf(val); break;
	case bt_ushort:
		val = node->i;
		nbytes = 4; GenerateHalf(val); break;
	case bt_int:
	case bt_uint:
		val = node->i;
		nbytes = 8; GenerateInt(val); break;
	case bt_long:
		val = node->i;
		nbytes = 8; GenerateLong(val); break;
	case bt_exception:
	case bt_ulong:
		val = node->i;
		nbytes = 8; GenerateLong(val); break;
	case bt_float:
		nbytes = 8; GenerateFloat((Float128*)&node->f128); break;
	case bt_double:
		nbytes = 8; GenerateFloat((Float128*)&node->f128); break;
	case bt_quad:
		nbytes = 16; GenerateQuad((Float128*)&node->f128); break;
	case bt_posit:
		nbytes = 8; GeneratePosit(node->posit); break;
	case bt_struct:
		nbytes = InitializeStruct(node);
		break;
	case bt_union:
		nbytes = InitializeUnion(node);
		break;
	case bt_pointer:
		// Is it an array?
		if (tp->val_flag)
			nbytes = InitializeArray(node);
		else {
			val = node->i;
			nbytes = sizeOfPtr;
			switch (sizeOfPtr) {
			case 4: GenerateHalf(val); break;
			case 8: GenerateInt(val); break;
			case 16: GenerateLong(val); break;
			}
		}
		//case bt_struct:	nbytes = InitializeStruct(); break;
	default:
		;
	}
	return (nbytes);
}


void SYM::storeHex(txtoStream& ofs)
{
	ofs.write("SYM:");
	ofs.writeAsHex((char *)this, sizeof(SYM));
	ofs.printf(":%05d", fi->number);
	ofs.printf(":%05d", tp->typeno);
}
