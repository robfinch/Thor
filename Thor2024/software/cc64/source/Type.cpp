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

extern short int brace_level;
TYP *typ_vector[100];
short int typ_sp = 0;

void push_typ(TYP *tp)
{
	if (typ_sp < 99) {
		typ_vector[typ_sp] = tp;
		typ_sp++;
	}
}

TYP *pop_typ()
{
	if (typ_sp >= 0) {
		typ_sp--;
		return (typ_vector[typ_sp]);
	}
	return (nullptr);
}

bool TYP::IsScalar()
{
	if (this == nullptr)
		return (false);
	return
		type == bt_byte ||
		type == bt_ichar ||
		type == bt_char ||
		type == bt_short ||
		type == bt_int ||
		type == bt_long ||
		type == bt_ubyte ||
		type == bt_iuchar ||
		type == bt_uchar ||
		type == bt_ushort ||
		type == bt_uint ||
		type == bt_ulong ||
		type == bt_enum ||
		type == bt_exception ||
		type == bt_unsigned;
}


bool TYP::IsScalar(e_sym type)
{
	return
		type == bt_byte ||
		type == bt_ichar ||
		type == bt_char ||
		type == bt_short ||
		type == bt_int ||
		type == bt_long ||
		type == bt_ubyte ||
		type == bt_iuchar ||
		type == bt_uchar ||
		type == bt_ushort ||
		type == bt_uint ||
		type == bt_ulong ||
		type == bt_enum ||
		type == bt_exception ||
		type == bt_unsigned;
}


TYP *TYP::GetPtr(int n) {
  if (n==0)
    return nullptr;
  return &compiler.typeTable[n];
};
int64_t TYP::GetIndex() { return this - &compiler.typeTable[0]; };

TYP *TYP::Copy(TYP *src)
{
	TYP *dst = nullptr;
 
  dfs.printf("<TYP__Copy>\n");
	if (src) {
		dst = allocTYP();
//		if (dst==nullptr)
//			throw gcnew C64::C64Exception();
		memcpy(dst,src,sizeof(TYP));
		dfs.printf("A");
		if (src->btpp) {
  		dfs.printf("B");
			dst->btpp = Copy(src->btpp);
		}
		dfs.printf("C");
		// We want to keep any base type indicator so Clear() isn't called.
		dst->lst.headp = nullptr;
		dst->lst.tailp = nullptr;
		if (src->sname)
			dst->sname = new std::string(*(src->sname));
		else
			dst->sname = nullptr;
		dfs.printf("D");
		TABLE::CopySymbolTable(&dst->lst,&src->lst);
	}
  dfs.printf("</TYP__Copy>\n");
	return (dst);
}

TYP *TYP::Make(int bt, int64_t siz)
{
	TYP *tp;
	dfs.puts("<TYP__Make>\n");
	tp = allocTYP();
	if (tp == nullptr)
		return (nullptr);
	tp->rd_cache = nullptr;
	tp->wr_cache = nullptr;
	tp->val_flag = false;
	tp->isArray = FALSE;
	tp->size = siz;
	tp->type = bt;
	tp->typeno = bt;
	tp->precision = siz * 8;
	if (bt == bt_pointer)
		tp->isUnsigned = TRUE;
	dfs.puts("</TYP__Make>\n");
	return (tp);
}

// Given just a type number return the size

int64_t TYP::GetSize(int num)
{
  if (num == 0)
    return (0);
  return (compiler.typeTable[num].size);
}

// Basic type is one of the built in types supported by the compiler.
// Returns the basic type number for the type. The basic type number does
// not include complex types like struct, union, or class. For a struct,
// union, or class one of bt_struct, bt_union or bt_class is returned.

int TYP::GetBasicType(int num)
{
  if (num==0)
    return 0;
  return compiler.typeTable[num].type;
}

int TYP::GetHash()
{
	int n;
	TYP *p, *p1;

	n = 0;
	p = this;
	if (p==nullptr)
		throw new C64PException(ERR_NULLPOINTER,2);
	do {
		if (p->type==bt_pointer)
			n+=8192;//20000;
		p1 = p;
		p = p->btpp;
	} while (p);
	n += p1->typeno;
	return (n);
}

int64_t TYP::GetElementSize()
{
	int n;
	TYP *p, *p1;

	n = 0;
	p = this;
	do {
		p1 = p;
		p = p->btpp;
	} while (p);
	switch(p1->type) {
	case bt_byte:
	case bt_ubyte:
		return 1;
	case bt_ichar:
	case bt_iuchar:
	case bt_char:
	case bt_uchar:
		return 2;
	case bt_short:
	case bt_ushort:
		return 4;
	case bt_int:
	case bt_uint:
		return sizeOfInt;
	case bt_long:
	case bt_ulong:
	case bt_pointer:
		return sizeOfWord;
	case bt_decimal:
		return sizeOfDecimal;
	case bt_float:
	case bt_double:
	case bt_posit:
		return 8;
	case bt_struct:
	case bt_class:
		return p1->size;
	default:
		return 8;
	}
	return n;
}

char* TYP::ToString(int ndx)
{
	static char buf[1000];
	if (this == nullptr) {
		strcpy_s(&buf[ndx], sizeof(buf)-ndx, "<null ptr>");
		return (buf);
	}
	switch (type) {
	case bt_exception:
		strcpy_s(&buf[ndx], sizeof(buf)-ndx, "Exception");
		return (buf);
	case bt_byte:
		strcpy_s(&buf[ndx], sizeof(buf), "Byte");
		return (buf);
	case bt_ubyte:
		strcpy_s(&buf[ndx], sizeof(buf), "Unsigned Byte");
		return (buf);
	case bt_char:
	case bt_ichar:
		strcpy_s(&buf[ndx], sizeof(buf), "Char");
		return (buf);
	case bt_uchar:
	case bt_iuchar:
		strcpy_s(&buf[ndx], sizeof(buf), "Unsigned Char");
		return (buf);
	case bt_short:
		strcpy_s(&buf[ndx], sizeof(buf), "Short Integer");
		return (buf);
	case bt_ushort:
		strcpy_s(&buf[ndx], sizeof(buf), "Unsigned Short Integer");
		return (buf);
	case bt_int:
		strcpy_s(&buf[ndx], sizeof(buf), "Integer");
		return (buf);
	case bt_uint:
		strcpy_s(&buf[ndx], sizeof(buf), "Unsigned Integer");
		return (buf);
	case bt_long:
		strcpy_s(&buf[ndx], sizeof(buf), "Long Integer");
		return (buf);
	case bt_ulong:
		strcpy_s(&buf[ndx], sizeof(buf), "Unsigned Long Integer");
		return (buf);
	case bt_enum:
		strcpy_s(&buf[ndx], sizeof(buf), "Enumeration");
		return (buf);
	case bt_float:
		strcpy_s(&buf[ndx], sizeof(buf), "Float");
		return (buf);
	case bt_double:
		strcpy_s(&buf[ndx], sizeof(buf), "Double");
		return (buf);
	case bt_quad:
		strcpy_s(&buf[ndx], sizeof(buf), "Long Double");
		return (buf);
	case bt_posit:
		strcpy_s(&buf[ndx], sizeof(buf), "Posit");
		return (buf);
	case bt_pointer:
		if (val_flag) {
			strcpy_s(&buf[ndx], sizeof(buf), "Array of ");
			btpp->ToString(ndx + 9);
		}
		else {
			strcpy_s(&buf[ndx], sizeof(buf), "Pointer to ");
			btpp->ToString(ndx + 11);
		}
		return (buf);
	case bt_func:
	case bt_ifunc:
		strcpy_s(&buf[ndx], sizeof(buf), "Function returning ");
		btpp->ToString(ndx + 19);
		return (buf);
	case bt_class:
		strcpy_s(&buf[ndx], sizeof(buf), "Class ");
		ndx += 6;
		goto j1;
	case bt_struct:
		strcpy_s(&buf[ndx], sizeof(buf), "Struct ");
		ndx += 7;
		goto j1;
	case bt_union:
		strcpy_s(&buf[ndx], sizeof(buf), "Union ");
		ndx += 6;
		goto j1;
	}
	return ((char *)"<unknown>");
j1:
	if (sname->length() == 0)
		strcpy_s(&buf[ndx], sizeof(buf), "<no name>");
	else
		strcpy_s(&buf[ndx], sizeof(buf), (char *)sname->c_str());
	return (buf);
}

void TYP::put_ty()
{
	char* str;

	str = ToString(0);
	lfs.puts(str);
}

bool TYP::IsSameType(TYP *a, TYP *b, bool exact)
{
	if (a == b)
		return (true);
	if (a == nullptr || b == nullptr) {
		if (!exact)
			return (true);
		else
			return (false);
	}

	if (a->type == b->type && a->typeno == b->typeno)
		return (true);

	switch (a->type) {

	// None will match any type.
	// For argument lists where the argument is not specified so a default is
	// assumed.
	case bt_none:
		return (true);

	case bt_float:
		if (b->type == bt_float)
			return (true);
		if (b->type == bt_double)
			return (true);
		goto chk;

	case bt_double:
		if (b->type == bt_float)
			return (true);
		if (b->type == bt_double)
			return (true);
		goto chk;

	case bt_long:
		if (b->type == bt_long)
			return (true);
		if (!exact) {
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_ulong:
		if (b->type == bt_ulong)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_int:
		if (b->type == bt_int)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_uint:
		if (b->type == bt_uint)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_short:
		if (b->type == bt_short)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_ushort:
		if (b->type == bt_ushort)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_uchar:
		if (b->type == bt_uchar)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_iuchar:
		if (b->type == bt_iuchar)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_char:
		if (b->type == bt_char)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_ichar:
		if (b->type == bt_ichar)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_byte:
		if (b->type == bt_byte)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_ubyte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_ubyte:
		if (b->type == bt_ubyte)
			return (true);
		if (!exact) {
			if (b->type == bt_long)
				return (true);
			if (b->type == bt_ulong)
				return (true);
			if (b->type == bt_short)
				return (true);
			if (b->type == bt_ushort)
				return (true);
			if (b->type == bt_int)
				return (true);
			if (b->type == bt_uint)
				return (true);
			if (b->type == bt_uchar)
				return (true);
			if (b->type == bt_char)
				return (true);
			if (b->type == bt_iuchar)
				return (true);
			if (b->type == bt_ichar)
				return (true);
			if (b->type == bt_byte)
				return (true);
			if (b->type == bt_enum)
				return (true);
		}
		goto chk;

	case bt_pointer:
		if (a->val_flag && b->type == bt_struct) {
			return (true);
		}
		if (a->type != b->type)
			goto chk;
		if (a->btpp == b->btpp)
			return (true);
		if (a->btpp && b->btpp)
			return (TYP::IsSameType(a->btpp, b->btpp, exact));
		goto chk;

	case bt_struct:
	case bt_union:
	case bt_class:
		if (a->type != b->type)
			goto chk;
		if (a->btpp == b->btpp || !exact)
			return (true);
		if (a->btpp && b->btpp)
			return (TYP::IsSameType(a->btpp, b->btpp, exact));
		goto chk;

	case bt_enum:
		if (a->typeno == b->typeno)
			return (true);
		if (!exact) {
			if (b->type == bt_long
				|| b->type == bt_ulong
				|| b->type == bt_short
				|| b->type == bt_ushort
				|| b->type == bt_int
				|| b->type == bt_uint
				|| b->type == bt_char
				|| b->type == bt_uchar
				|| b->type == bt_ichar
				|| b->type == bt_iuchar
				|| b->type == bt_enum
				)
				return (true);
		}
	}
chk:
	if (b->type == bt_union || a->type == bt_union)
		return (IsSameUnionType(a, b));
	if (a->type == bt_struct && b->type == bt_struct)
		return (IsSameStructType(a, b));
	return (false);
}

// Do we really want to compare all the fields?
// As long as the sizes are the same there should be no issues with
// memory overwrites.

bool TYP::IsSameStructType(TYP* a, TYP* b)
{
	Symbol* spA, * spB;
	int64_t maxa = 0, maxb = 0;

	return (a->size == b->size);
	spA = a->lst.headp;      /* start at top of symbol table */
	while (spA != nullptr) {
		maxa = maxa + spA->tp->size;
		spA = spA->nextp;
	}
	spB = b->lst.headp;      /* start at top of symbol table */
	while (spB != nullptr) {
		maxb = maxb + spB->tp->size;
		spB = spB->nextp;
	}
	return (maxa == maxb);
}

// Unions are considered the same if the max size of the union is the same.
// The target needs to be at least the size o f the source. ToDo.

bool TYP::IsSameUnionType(TYP* a, TYP* b)
{
	Symbol* spA, * spB;
	int64_t maxa=0, maxb=0;

	// union will match anything
	return (true);
	spA = a->lst.headp;      /* start at top of symbol table */
	maxa = a->size;
	while (spA != nullptr) {
		maxa = max(maxa, spA->tp->size);
		spA = spA->nextp;
	}
	spB = b->lst.headp;      /* start at top of symbol table */
	maxb = b->size;
	while (spB != nullptr) {
		maxb = max(maxb, spB->tp->size);
		spB = spB->nextp;
	}
	return (maxa==maxb);
}

// Initialize the type. Unions can't be initialized. Oh yes they can.

int64_t TYP::Initialize(txtoStream& tfs, ENODE* pnode, TYP *tp2, int opt, Symbol* symi)
{
	int64_t nbytes;
	TYP *tp;
	int base, nn;
	int64_t sizes[100];
	char idbuf[sizeof(lastid)+1];
	Expression exp(cg.stmt);

	for (base = typ_sp-1; base >= 0; base--) {
		if (typ_vector[base]->isArray)
			break;
		if (typ_vector[base]->IsStructType())
			break;
	}
	sizes[0] = typ_vector[min(base + 1,typ_sp-1)]->size * typ_vector[0]->numele;
	for (nn = 1; nn <= base; nn++)
		sizes[nn] = sizes[nn - 1] * typ_vector[nn]->numele;

j1:
	/*
	while (lastst == begin) {
		brace_level++;
		NextToken();
	}
	*/
	if (tp2)
		tp = tp2;
	else {
		tp = typ_vector[max(base-brace_level,0)];
	}
	do {
		//if (lastst == assign)
		//	NextToken();
		switch (tp->type) {
		case bt_ubyte:
		case bt_byte:
			nbytes = initbyte(symi, opt);
			break;
		case bt_uchar:
		case bt_char:
		case bt_enum:
			nbytes = initchar(symi, opt);
			break;
		case bt_ushort:
		case bt_short:
//			nbytes = initshort(symi, opt);
			break;
		case bt_uint:
		case bt_int:
			nbytes = initint(symi, symi->value.i, opt);
			break;
		case bt_pointer:
			if (tp->val_flag)
				nbytes = tp->InitializeArray(tfs, sizes[max(base-brace_level,0)], symi);
			else
				nbytes = InitializePointer(tp, opt, symi);
			break;
		case bt_exception:
		case bt_ulong:
		case bt_long:
			//strncpy(idbuf, lastid, sizeof(lastid));
			//strncpy(lastid, pnode->sym->name->c_str(), sizeof(lastid));
			//gNameRefNode = exp.ParseNameRef();
			nbytes = initlong(symi, opt);
			//strncpy(lastid, idbuf, sizeof(lastid));
			break;
		case bt_struct:
			nbytes = tp->InitializeStruct(tfs, pnode,symi);
			break;
		case bt_union:
			nbytes = tp->InitializeUnion(tfs, symi,pnode);
			break;
		case bt_quad:
			nbytes = initquad(symi,opt);
			break;
		case bt_float:
		case bt_double:
			nbytes = initfloat(symi,opt);
			break;
		case bt_posit:
			nbytes = initPosit(symi, opt);
			break;
		default:
			error(ERR_NOINIT);
			nbytes = 0;
		}
		//if (brace_level > 0) {
		//	if (typ_vector[brace_level - 1]->val_flag) {

		//	}
		//}
		if (tp2 != nullptr)
			return (nbytes);
		if (lastst != comma || brace_level==0)
			break;
		NextToken();
		if (lastst == end)
			break;
	} while (1);
j2:
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
	return (nbytes);
}


// Dead code
int64_t TYP::InitializeArray(txtoStream& tfs, int64_t maxsz, Symbol* symi)
{
/*
	int64_t nbytes;
	int64_t size;
	char *p;
	char *str;
	int64_t pos = 0;
	int64_t n, nh;
	ENODE* cnode, *node;
	int64_t fill = 0;
	int64_t poscount = 0;
	Value* values;
	int64_t* buckets;
	int64_t* bucketshi;
	int npos = 0;
	bool recval;
	bool spitout;

	/*
	typedef struct _tagSP {
		std::streampos poses;
	} Strmpos;

	Strmpos* poses;
	*/
	// First create array full of empty elements.
	/*
	size = btpp->size;
	poses = new Strmpos[(numele+1) * sizeof(Strmpos)];
	for (n = 0; n < numele; n++) {
		poses[n].poses = ofs.tellp();
		btpp->Initialize(nullptr, btpp, 0);
	}
	poses[numele].poses = ofs.tellp();
	
	// Fill in the elements as encountered.
	nbytes = 0;
//	values = new Value[100];
	values = (Value*)allocx(100 * sizeof(Value));
	buckets = new int64_t[100];
	ZeroMemory(buckets, 100 * sizeof(int64_t));
	bucketshi = new int64_t[100];
	ZeroMemory(bucketshi, 100 * sizeof(int64_t));
	npos = 0;
	recval = false;
	if (symi) {
		node = symi->enode;

	}
	if (lastst == begin)
		NextToken();
	{
//		NextToken();               /* skip past the brace
		for (n = 0; lastst != end; n++) {
/*
			ofs.seekp(poses[n].poses);

			if (lastst == openbr) {
				NextToken();
				if (npos > 98) {
					return (nbytes);
					//error(TOO_MANY_DESIGNATORS);
				}
				n = GetConstExpression(&cnode, symi).low;
//				ofs.seekp(poses[n].poses);
				//fill = min(1000000, n - pos + 1);
				if (lastst == ellipsis) {
					NextToken();
					nh = GetConstExpression(&cnode, symi).low;
				}
				else
					nh = n;
				needpunc(closebr,50);
				needpunc(assign,50);
				buckets[npos] = n;
				bucketshi[npos] = nh;
				recval = true;
			}

			// Allow char array initialization like { "something", "somethingelse" }
			if (lastst == sconst && (btpp->type == bt_char || btpp->type == bt_uchar
				|| btpp->type == bt_ichar || btpp->type == bt_iuchar)) {
				if (fill > 0) {
					while (fill > 0) {
						fill--;
						spitout = false;
						for (n = 0; n < npos; n++) {
							if (pos >= buckets[n] && pos <= bucketshi[n]) {
								p = (char*)values[n].sp->c_str();
								while (*p) {
									GenerateChar(*p++);
								}
								GenerateChar(0);
								spitout = true;
							}
						}
						if (!spitout)
							GenerateChar(0);
						pos++;
					}
				}
				str = GetStrConst();
				if (recval) {
					values[npos].sp = new std::string(str);
					npos++;
				}
				nbytes = strlen(str) * 2 + 2;
				spitout = false;
				for (n = 0; n < npos; n++) {
					if (pos >= buckets[n] && pos <= bucketshi[n]) {
						p = (char*)values[n].sp->c_str();
						while (*p) {
							GenerateChar(*p++);
						}
						GenerateChar(0);
						spitout = true;
					}
				}
				if (!spitout) {
					p = str;
					while (*p) {
						GenerateChar(*p++);
					}
					GenerateChar(0);
				}
				free(str);
				pos++;
			}
			else if (lastst == asconst && btpp->type == bt_byte) {
				while (fill > 0) {
					fill--;
					spitout = false;
					for (n = 0; n <= npos; n++) {
						if (pos >= buckets[n] && pos <= bucketshi[n]) {
							p = (char*)values[n].sp->c_str();
							while (*p) {
								GenerateByte(*p++);
							}
							GenerateByte(0);
							spitout = true;
						}
					}
					if (!spitout)
						GenerateByte(0);
					pos++;
				}
				str = GetStrConst();
				if (recval) {
					values[npos].sp = new std::string(str);
					npos++;
				}
				nbytes = strlen(str) * 1 + 1;
				spitout = false;
				for (n = 0; n < npos; n++) {
					if (pos >= buckets[n] && pos <= bucketshi[n]) {
						p = (char*)values[n].sp->c_str();
						while (*p) {
							GenerateByte(*p++);
						}
						GenerateByte(0);
						spitout = true;
					}
				}
				if (!spitout) {
					p = str;
					while (*p)
						GenerateByte(*p++);
					GenerateByte(0);
				}
				free(str);
				pos++;
			}
			else {
				switch (btpp->type) {
				case bt_array:
					nbytes += btpp->Initialize(nullptr, btpp, fill == 0, symi);
					pos++;
					break;
				case bt_byte:
				case bt_ubyte:
					if (recval) {
						values[npos].value.i = GetIntegerExpression(nullptr,symi,0).low;
						npos++;
					}
					spitout = false;
					for (n = 0; n < npos; n++) {
						if (pos >= buckets[n] && pos <= bucketshi[n]) {
							GenerateByte(values[n].value.i);
							nbytes += 1;
							spitout = true;
							pos++;
						}
					}
					if (!spitout && !recval) {
						GenerateByte(GetIntegerExpression(nullptr,symi,0).low);
						nbytes += 1;
						pos++;
					}
					break;
				case bt_char:
				case bt_uchar:
				case bt_ichar:
					if (recval) {
						values[npos].value.i = GetIntegerExpression(nullptr,symi,0).low;
						npos++;
					}
					spitout = false;
					for (n = 0; n < npos; n++) {
						if (pos >= buckets[n] && pos <= bucketshi[n]) {
							GenerateChar(values[n].value.i);
							nbytes += 2;
							spitout = true;
							pos++;
						}
					}
					if (!spitout && !recval) {
						GenerateChar(GetIntegerExpression(nullptr,symi,0).low);
						nbytes += 2;
						pos++;
					}
					break;
				case bt_class:
					nbytes += btpp->Initialize(nullptr, btpp, fill == 0, symi);
					pos++;
					break;
				case bt_double:
				case bt_float:
					if (recval) {
						values[npos].f128 = GetFloatExpression(nullptr, symi);
						npos++;
					}
					spitout = false;
					for (n = 0; n < npos; n++) {
						if (pos >= buckets[n] && pos <= bucketshi[n]) {
							GenerateFloat(&values[n].f128);
							nbytes += 8;
							spitout = true;
							pos++;
						}
					}
					if (!spitout && !recval) {
						GenerateFloat(GetFloatExpression(nullptr, symi));
						nbytes += 8;
						pos++;
					}
					break;
				case bt_enum:
					if (recval) {
						values[npos].value.i = GetIntegerExpression(nullptr,symi,0).low;
						npos++;
					}
					spitout = false;
					for (n = 0; n < npos; n++) {
						if (pos >= buckets[n] && pos <= bucketshi[n]) {
							GenerateChar(values[n].value.i);
							nbytes += 2;
							spitout = true;
							pos++;
						}
					}
					if (!spitout && !recval) {
						GenerateChar(GetIntegerExpression(nullptr,symi,0).low);
						nbytes += 2;
						pos++;
					}
					break;
				case bt_long:
				case bt_ulong:
					if (recval) {
						values[npos].value.i = GetIntegerExpression(nullptr,symi,0).low;
						npos++;
					}
					spitout = false;
					for (n = 0; n < npos; n++) {
						if (pos >= buckets[n] && pos <= bucketshi[n]) {
							GenerateLong(values[n].value.i);
							nbytes += 8;
							spitout = true;
							pos++;
						}
					}
					if (!spitout && !recval) {
						GenerateLong(GetIntegerExpression(nullptr,symi,0));
						nbytes += 8;
						pos++;
					}
					break;
				case bt_short:
				case bt_ushort:
					if (recval) {
						values[npos].value.i = GetIntegerExpression(nullptr,symi,0).low;
						npos++;
					}
					spitout = false;
					for (n = 0; n < npos; n++) {
						if (pos >= buckets[n] && pos <= bucketshi[n]) {
							GenerateHalf(values[n].value.i);
							nbytes += 4;
							spitout = true;
							pos++;
						}
					}
					if (!spitout && !recval) {
						GenerateHalf(GetIntegerExpression(nullptr,symi,0).low);
						nbytes += 4;
						pos++;
					}
					break;
				case bt_int:
				case bt_uint:
					if (recval) {
						values[npos].value.i = GetIntegerExpression(nullptr, symi, 0).low;
						npos++;
					}
					spitout = false;
					for (n = 0; n < npos; n++) {
						if (pos >= buckets[n] && pos <= bucketshi[n]) {
							GenerateInt(values[n].value.i);
							nbytes += 4;
							spitout = true;
							pos++;
						}
					}
					if (!spitout && !recval) {
						GenerateHalf(GetIntegerExpression(nullptr, symi, 0).low);
						nbytes += 4;
						pos++;
					}
					break;
				default:
					if (fill > 0) {
						while (fill > 0) {
							fill--;
							nbytes += btpp->Initialize(nullptr, btpp, fill == 0, symi);
							pos++;
						}
					}
					else {
						nbytes += btpp->Initialize(nullptr, btpp, 1, symi);
						pos++;
					}
					break;
				}
			}
			recval = false;
			// Allow an extra comma at the end of the list of values
			if (lastst == comma) {
				NextToken();
				if (lastst == end) {
					break;
				}
			}
			else if (lastst == end) {
				//brace_level--;
				break;
			}
			else if (lastst == semicolon)
				break;
			else
				error(ERR_PUNCT);
		}
		while (nbytes < maxsz) {
			GenerateByte(0);
			nbytes++;
		}
		/*
			switch (btpp->type) {
			case bt_array:
				nbytes += btpp->Initialize(nullptr, btpp, fill == 0);
				pos++;
				break;
			case bt_byte:
			case bt_ubyte:
				spitout = false;
				for (n = 0; n < npos; n++) {
					if (pos >= buckets[n] && pos <= bucketshi[n]) {
						GenerateByte(values[n].value.i);
						nbytes += 1;
						spitout = true;
						pos++;
					}
				}
				if (!spitout) {
					GenerateByte(0);
					nbytes += 1;
					pos++;
				}
				break;
			case bt_char:
			case bt_uchar:
			case bt_ichar:
				spitout = false;
				for (n = 0; n < npos; n++) {
					if (pos >= buckets[n] && pos <= bucketshi[n]) {
						GenerateChar(values[n].value.i);
						nbytes += 2;
						spitout = true;
						pos++;
					}
				}
				if (!spitout) {
					GenerateChar(0);
					nbytes += 2;
					pos++;
				}
				break;
			case bt_class:
				nbytes += btpp->Initialize(nullptr, btpp, fill == 0);
				pos++;
				break;
			case bt_double:
			case bt_float:
				spitout = false;
				for (n = 0; n < npos; n++) {
					if (pos >= buckets[n] && pos <= bucketshi[n]) {
						GenerateFloat(&values[n].f128);
						nbytes += 8;
						spitout = true;
						pos++;
					}
				}
				if (!spitout) {
					GenerateFloat(rval128.Zero());
					nbytes += 8;
					pos++;
				}
				break;
			case bt_enum:
				spitout = false;
				for (n = 0; n < npos; n++) {
					if (pos >= buckets[n] && pos <= bucketshi[n]) {
						GenerateChar(values[n].value.i);
						nbytes += 2;
						spitout = true;
						pos++;
					}
				}
				if (!spitout) {
					GenerateChar(0);
					nbytes += 2;
					pos++;
				}
				break;
			case bt_long:
			case bt_ulong:
				spitout = false;
				for (n = 0; n < npos; n++) {
					if (pos >= buckets[n] && pos <= bucketshi[n]) {
						GenerateLong(values[n].value.i);
						nbytes += 8;
						spitout = true;
						pos++;
						break;
					}
				}
				if (!spitout) {
					GenerateLong(0);
					nbytes += 8;
					pos++;
				}
				break;
			case bt_short:
			case bt_ushort:
				spitout = false;
				for (n = 0; n < npos; n++) {
					if (pos >= buckets[n] && pos <= bucketshi[n]) {
						GenerateHalf(values[n].value.i);
						nbytes += 4;
						spitout = true;
						pos++;
					}
				}
				if (!spitout) {
					GenerateHalf(0);
					nbytes += 4;
					pos++;
				}
				break;
			default:
				if (fill > 0) {
					while (fill > 0) {
						fill--;
						nbytes += btpp->Initialize(nullptr, btpp, fill == 0);
						pos++;
					}
				}
				else {
					nbytes += btpp->Initialize(nullptr, btpp, 1);
					pos++;
				}
				break;
			}
		
//		}
//		NextToken();               /* skip closing brace
	}
	//else if (lastst == sconst && (btpp->type == bt_char || btpp->type == bt_uchar)) {
	//	str = GetStrConst();
	//	nbytes = strlen(str) * 2 + 2;
	//	p = str;
	//	while (*p)
	//		GenerateChar(*p++);
	//	GenerateChar(0);
	//	free(str);
	//}
	//else if (lastst != semicolon)
	//	error(ERR_ILLINIT);
	if (nbytes < maxsz) {
		genstorage(maxsz - nbytes);
		nbytes = maxsz;
	}
	else if (maxsz != 0 && nbytes > maxsz)
		;// error(ERR_INITSIZE);    /* too many initializers
xit:
	/*
	ofs.seekp(poses[numele].poses);
	delete[] poses;
	return (numele * size);

	delete[] values;
	delete[] buckets;
	return (nbytes);
	*/
	return (0);
}

// Dead code
int64_t TYP::InitializeStruct(txtoStream& tfs, ENODE* node, Symbol* symi)
{
	Symbol *sp;
	int64_t nbytes;
	int count;
	
//	needpunc(begin, 25);
	nbytes = 0;
	sp = lst.headp;
	count = 0;
	while (sp != 0) {
		while (nbytes < sp->value.i) {     /* align properly */
										   //                    nbytes += GenerateByte(0);
			GenerateByte(tfs, 0);
			nbytes++;
		}
		nbytes += sp->tp->Initialize(tfs, node, sp->tp, 1, symi);
		if (lastst == comma)
			NextToken();
		else if (lastst == end || lastst==semicolon) {
			break;
		}
		else
			error(ERR_PUNCT);
		sp = sp->nextp;
		count++;
	}
	if (sp == nullptr) {
		if (lastst != end && lastst != semicolon) {
			error(ERR_INITSIZE);
			while (lastst != end && lastst != semicolon && lastst != end)
				NextToken();
		}
	}
	if (nbytes < size)
		genstorage(tfs, size - nbytes);
//	needpunc(end, 26);
	return (size);
}

int64_t TYP::GenerateT(txtoStream& tfs, ENODE *node)
{
	int64_t nbytes;
	int64_t val;
	int64_t n, nele;
	ENODE *nd, *pnode;

	if (this == nullptr)
		return (0);
	switch (type) {
	case bt_byte:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 1; GenerateByte(tfs, val);
		break;
	case bt_ubyte:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 1;
		GenerateByte(tfs, val);
		break;
	case bt_ichar:
	case bt_char:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 2; GenerateChar(tfs, val); break;
	case bt_iuchar:
	case bt_uchar:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 2; GenerateChar(tfs, val); break;
	case bt_short:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 4; GenerateHalf(tfs, val); break;
	case bt_ushort:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 4; GenerateHalf(tfs, val); break;
	case bt_int:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 8; GenerateInt(tfs, val); break;
	case bt_uint:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 16; GenerateInt(tfs, val); break;
	case bt_long:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 16; GenerateLong(tfs, val); break;
	case bt_ulong:
		if (node == nullptr)
			val = 0;
		else
			val = node->i;
		nbytes = 8; GenerateLong(tfs, val); break;
	case bt_float:
		nbytes = 8; GenerateFloat(tfs, (Float128 *)&node->f128); break;
	case bt_double:
		nbytes = 8; GenerateFloat(tfs, (Float128 *)&node->f128); break;
	case bt_quad:
		nbytes = 16; GenerateQuad(tfs, (Float128 *)&node->f128); break;
	case bt_posit:
		nbytes = 8; GeneratePosit(tfs, node->posit); break;
	case bt_pointer:
		if (val_flag) {
			nbytes = 0;
			nele = numele;
			for (n = 0, pnode = node; pnode && n < nele; n++, pnode = pnode->p[0]) {
				nd = pnode->p[1];
				if (nd == nullptr)
					break;
				nbytes += btpp->GenerateT(tfs, nd);
			}
		}
		else {
			if (node == nullptr)
				val = 0;
			else
				val = node->i;
			nbytes = sizeOfPtr;
		}
		//case bt_struct:	nbytes = InitializeStruct(); break;
	}
	return (nbytes);
}

// Dead code
int64_t TYP::InitializeUnion(txtoStream& tfs, Symbol* symi, ENODE* node)
{
	Symbol *sp, *osp;
	int64_t nbytes;
	int64_t val;
	bool found = false;
	TYP *tp, *ntp;
	int count;

	nbytes = 0;
//	val = GetConstExpression(&node, symi).low;
	if (node == nullptr)	// syntax error in GetConstExpression()
		return (0);
	sp = lst.headp;      /* start at top of symbol table */
	osp = sp;
	count = 0;
	while (sp != 0) {
		// Detect array of values
		if (sp->tp->type == bt_pointer && sp->tp->val_flag) {
			tp = sp->tp->btpp;
			if (node->tp == nullptr)
				break;
			ntp = node->tp->btpp;
			if (IsSameType(tp, ntp, false))
			{
				nbytes = node->esize;
				nbytes = GenerateT(tfs, node);
				found = true;
				/*
				while (lastst == comma && count < sp->tp->numele) {
					NextToken();
					val = GetConstExpression(&node, symi).low;
					//nbytes = node->esize;
					nbytes += GenerateT(tp, node);
					count++;
				}
				if (count >= sp->tp->numele)
					error(ERR_INITSIZE);
				*/
				goto j1;
			}
		}
		if (IsSameType(sp->tp, node->tp, false)) {
			nbytes = node->esize;
//			nbytes = GenerateT(sp->tp, node);
			found = true;
			break;
		}
		sp = sp->nextp;
		if (sp == osp)
			break;
	}
j1:
	if (!found)
		error(ERR_INIT_UNION);
	if (lastst != semicolon && lastst != comma && lastst != end)
		error(ERR_PUNCT);
	if (nbytes < size)
		genstorage(tfs, size - nbytes);
	return (size);
}


// GC support

bool TYP::FindPointerInStruct()
{
	Symbol *sp;

	sp = lst.headp;// sp->GetPtr(lst.GetHead());      // start at top of symbol table
	while (sp != 0) {
		if (sp->tp->FindPointer())
			return (true);
		sp = sp->nextp;// sp->GetNextPtr();
	}
	return (false);
}

bool TYP::FindPointer()
{
	switch (type) {
	case bt_pointer: return (val_flag == false);	// array ?
	case bt_struct: return (FindPointerInStruct());
	case bt_union: return (FindPointerInStruct());
	case bt_class: return (FindPointerInStruct());
	}
	return (false);
}


// Return whether or not the type might be able to be skipped over by the GC.

bool TYP::IsSkippable()
{
	if (compiler.nogcskips)
		return (false);
	switch (type) {
	case bt_struct:	return(true);
	case bt_union: return(true);
	case bt_class: return(true);
	case bt_pointer:
		if (val_flag == TRUE)
			return (true);
		return(false);
	}
	// For now primitive types are not skipped over. They would need to be 
	// grouped for skipping.
	return (false);
}

// The problem is there are two trees of information. The LHS and the RHS.
// The RHS is a tree of nodes containing expressions and data to load.
// The nodes in the RHS have to be matched up against the structure elements
// of the target LHS.

// This little bit of code is dead code. But it might be useful to match
// the expression trees at some point.

ENODE *TYP::BuildEnodeTree()
{
	ENODE *ep1, *ep2, *ep3;
	Symbol *thead, *first;

	first = thead = lst.headp;
	ep1 = ep2 = nullptr;
	while (thead) {
		if (thead->tp->IsStructType()) {
			ep3 = thead->tp->BuildEnodeTree();
		}
		else
			ep3 = nullptr;
		ep1 = makenode(en_void, ep1, ep2);
		ep1->SetType(thead->tp);
		ep1->p[2] = ep3;
		thead = thead->nextp;
	}
	return (ep1);
}


// Get the natural alignment for a given type.

int64_t TYP::Alignment()
{
	//printf("DIAG: type NULL in alignment()\r\n");
	if (this == NULL)
		return AL_BYTE;
	switch (type) {
	case bt_byte:	case bt_ubyte:	return AL_BYTE;
	case bt_char:   case bt_uchar:  return AL_CHAR;
	case bt_ichar:   case bt_iuchar:  return AL_CHAR;
	case bt_short:  case bt_ushort: return AL_SHORT;
	case bt_int:  case bt_uint: return AL_INT;
	case bt_long:   case bt_ulong:  return AL_LONG;
	case bt_enum:           return AL_CHAR;
	case bt_pointer:
		if (val_flag)
			return (btpp->Alignment());
		else
			return (sizeOfPtr);//isShort ? AL_SHORT : AL_POINTER);
	case bt_float:          return AL_FLOAT;
	case bt_double:         return AL_DOUBLE;
	case bt_posit:					return AL_POSIT;
	case bt_quad:         return AL_QUAD;
	case bt_class:
	case bt_struct:
	case bt_union:
		return (alignment) ? alignment : AL_STRUCT;
	default:                return AL_CHAR;
	}
}


// Figure out the worst alignment required.

int64_t TYP::walignment()
{
	Symbol *sp;
	int64_t retval = 0;
	static int level = 0;

	level++;
	if (level > 15) {
		retval = imax(AL_BYTE, worstAlignment);
		goto xit;
	}
	//printf("DIAG: type NULL in alignment()\r\n");
	if (this == NULL) {
		retval = imax(AL_BYTE, worstAlignment);
		goto xit;
	}
	switch (type) {
	case bt_byte:	case bt_ubyte:		level--; return imax(AL_BYTE, worstAlignment);
	case bt_char:   case bt_uchar:     level--; return imax(AL_CHAR, worstAlignment);
	case bt_ichar:   case bt_iuchar:     level--; return imax(AL_CHAR, worstAlignment);
	case bt_short:  case bt_ushort:    level--; return imax(AL_SHORT, worstAlignment);
	case bt_int:  case bt_uint:    level--; return imax(AL_INT, worstAlignment);
	case bt_long:   case bt_ulong:     level--; return imax(AL_LONG, worstAlignment);
	case bt_enum:           level--; return imax(AL_CHAR, worstAlignment);
	case bt_pointer:
		if (val_flag) {
			retval = imax(btpp->Alignment(), worstAlignment);
			goto xit;
		}
		else {
			return (imax(sizeOfPtr, worstAlignment));
			//				return (imax(AL_POINTER,worstAlignment));
		}
	case bt_float:          level--; return imax(AL_FLOAT, worstAlignment);
	case bt_double:         level--; return imax(AL_DOUBLE, worstAlignment);
	case bt_posit:					level--; return imax(AL_POSIT, worstAlignment);
	case bt_quad:         level--; return imax(AL_QUAD, worstAlignment);
	case bt_class:
	case bt_struct:
	case bt_union:
		sp = (Symbol *)this->lst.headp;
		worstAlignment = alignment;
		if (worstAlignment == 0)
			worstAlignment = 2;
		while (sp != NULL) {
			if (sp->tp && sp->tp->alignment) {
				worstAlignment = imax(worstAlignment, sp->tp->alignment);
			}
			else
				worstAlignment = imax(worstAlignment, sp->tp->walignment());
			sp = sp->GetNextPtr();
		}
		retval = worstAlignment;
		goto xit;
	default:                level--; return (imax(AL_CHAR, worstAlignment));
	}
xit:
	level--;
	return (retval);
}


int64_t TYP::roundAlignment()
{
	worstAlignment = 0;
	if (this == nullptr)
		return (1);
	if (type == bt_struct || type == bt_union || type == bt_class) {
		return (walignment());
	}
	return (Alignment());
}


// Round the size of the type up according to the worst alignment.

int64_t TYP::roundSize()
{
	int64_t sz;
	int64_t wa;

	worstAlignment = 0;
	if (type == bt_struct || type == bt_union || type == bt_class) {
		wa = walignment();
		sz = size;
		if (sz == 0)
			return (0);
		if (sz % wa)
			sz += (wa - (sz % wa));
		//while (sz % wa)
		//	sz++;
		return (sz);
	}
	//	return ((tp->precision+7)/8);
	return (size);
}

void TYP::storeHex(txtoStream& ofs)
{

}
