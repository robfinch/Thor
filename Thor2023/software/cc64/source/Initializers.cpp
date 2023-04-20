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

extern int catchdecl;
extern void genstorageskip(int nbytes);

void endinit();
extern int curseg;
static char glbl1[500];
static char glbl2[500];
bool hasPointer;
bool firstPrim;
std::streampos patchpoint;
short int brace_level;

static void pad(char *p, int n)
{
	int nn;

	nn = strlen(p);
	while (nn < n) {
		p[nn] = ' ';
		nn++;
	}
	p[nn] = '\n';
	p[nn + 1] = '\0';
}

static bool IsFuncptrAssign(Symbol* sp)
{
	if (sp->tp->type == bt_pointer) {
		if (sp->tp->btpp->type == bt_func || sp->tp->btpp->type == bt_ifunc) {
			if (sp->initexp) {
				return (true);
			}
		}
	}
	return (false);
}

static void ProcessInitExp(Symbol* sp, ENODE* n2)
{
	int64_t val;
	Int128 val128;

	if (n2 == nullptr)
		return;
	opt_const_unchecked(&n2);	// This should reduce to a single integer expression
	if (n2->nodetype == en_add) {
		if (n2->p[0]->nodetype == en_labcon && n2->p[1]->nodetype == en_icon) {
			val = n2->i;
			val128 = n2->i128;
		}
		if (n2->p[0]->nodetype == en_icon && n2->p[1]->nodetype == en_labcon) {
			val = n2->i;
			val128 = n2->i128;
		}
	}
	if (n2->nodetype != en_icon && n2->nodetype != en_cnacon && n2->nodetype != en_labcon) {
		// A type cast is represented by a tempref node associated with a value.
		// There may be an integer typecast to another value that can be used.
		if (n2->nodetype == en_void || n2->nodetype == en_cast) {
			if (n2->p[0]->nodetype == en_type) {
				if (n2->p[1]->nodetype == en_icon) {
					val = n2->i;
					val128 = n2->i128;
				}
			}
		}
	}
	ProcessInitExp(sp, n2->p[0]);
	ProcessInitExp(sp, n2->p[1]);
}

void doinit(Symbol *sp)
{
	static bool first = true;
	static char workbuf[5000];
	char lbl[200];
  int algn;
  enum e_sg oseg;
  char buf[500];
  std::streampos endpoint;
	std::streampos lblpoint;
	int64_t szpoint;
	bool setsz = false;
	TYP *tp;
	int n;
	ENODE* node;
	Expression exp;

	sp->storage_pos = ofs.tellp();
  hasPointer = false;
  if (first) {
	  firstPrim = true;
	  first = false;
  }

  oseg = noseg;
	lbl[0] = 0;
	// Initialize constants into read-only data segment. Constants may be placed
	// in ROM along with code.
	if (sp->isConst) {
    oseg = rodataseg;
  }
	if (IsFuncptrAssign(sp)) {
		algn = sizeOfWord;
		seg(oseg == noseg ? dataseg : oseg, algn);          /* initialize into data segment */
		nl();                   /* start a new line in object */
	}
	else if (sp->storage_class == sc_thread) {
        if (sp->tp->type==bt_struct || sp->tp->type==bt_union)
           algn = imax(sp->tp->alignment,8);
        else if (sp->tp->type==bt_pointer)// && sp->tp->val_flag)
           algn = imax(sp->tp->btpp->alignment,8);
        else
            algn = 2;
		seg(oseg==noseg ? tlsseg : oseg,algn);
		nl();
	}
	else if (sp->storage_class == sc_static || lastst==assign) {
        if (sp->tp->type==bt_struct || sp->tp->type==bt_union)
           algn = imax(sp->tp->alignment,8);
        else if (sp->tp->type==bt_pointer)// && sp->tp->val_flag)
           algn = imax(sp->tp->btpp->alignment,8);
        else
            algn = 2;
		seg(oseg==noseg ? dataseg : oseg,algn);          /* initialize into data segment */
		nl();                   /* start a new line in object */
	}
	else {
        if (sp->tp->type==bt_struct || sp->tp->type==bt_union)
           algn = imax(sp->tp->alignment,8);
        else if (sp->tp->type==bt_pointer)// && sp->tp->val_flag)
           algn = imax(sp->tp->btpp->alignment,8);
        else
            algn = 2;
		seg(oseg==noseg ? (lastst==assign ? dataseg : bssseg) : oseg,algn);            /* initialize into data segment */
		nl();                   /* start a new line in object */
	}
	
	if (sp->storage_class == sc_static || sp->storage_class == sc_thread) {
		//strcpy_s(glbl, sizeof(glbl), gen_label((int)sp->value.i, (char *)sp->name->c_str(), GetNamespace(), 'D'));
		if (sp->tp->IsSkippable()) {
			patchpoint = ofs.tellp();
			if (syntax == MOT)
				sprintf_s(buf, sizeof(buf), "\talign\t3\n\tdc.q\t$FFF0200000000001\n");
			else
				sprintf_s(buf, sizeof(buf), "\t.align\t3\n\t.8byte\t$FFF0200000000001\n");
			ofs.printf(buf);
		}
		sp->realname = my_strdup(put_label((int)sp->value.i, (char *)sp->name->c_str(), GetNamespace(), 'D', sp->tp->size));
		strcpy_s(glbl2, sizeof(glbl2), gen_label((int)sp->value.i, (char *)sp->name->c_str(), GetNamespace(), 'D', sp->tp->size));
	}
	else {
		if (sp->storage_class == sc_global) {
			//strcpy_s(lbl, sizeof(lbl), ".global ");
			strcpy_s(lbl, sizeof(lbl), "");
			switch (syntax) {
			case MOT:
				if (curseg == dataseg)
					strcat_s(lbl, sizeof(lbl), "\tdata\n");
				else if (curseg == bssseg)
					strcat_s(lbl, sizeof(lbl), "\tbss\n");
				else if (curseg == tlsseg)
					strcat_s(lbl, sizeof(lbl), "\ttls\n");
				break;
			default:
				if (curseg == dataseg)
					strcat_s(lbl, sizeof(lbl), "\t.data\n");
				else if (curseg == bssseg)
					strcat_s(lbl, sizeof(lbl), "\t.bss\n");
				else if (curseg == tlsseg)
					strcat_s(lbl, sizeof(lbl), "\t.tls\n");
			}
		}
		switch (syntax) {
		case MOT:
			ofs.puts("\talign 4\n");
			break;
		case STD:
			ofs.puts("\t.align 4\n");
			break;
		}
		switch (syntax) {
		case MOT:
			if (curseg == bssseg)
				sprintf_s(&lbl[strlen(lbl)], sizeof(lbl) - strlen(lbl), "comm %s,%I64d\n", (char*)sp->name->c_str(), sp->tp->size);
			else {
				sprintf_s(&lbl[strlen(lbl)], sizeof(lbl) - strlen(lbl), "%s:\n", (char*)sp->name->c_str());
				sprintf_s(&lbl[strlen(lbl)], sizeof(lbl) - strlen(lbl), "\tdcb.b\t%I64d\n", sp->tp->size);
			}
			break;
		default:
			if (curseg == bssseg) {
				sprintf_s(&lbl[strlen(lbl)], sizeof(lbl) - strlen(lbl), ".lcomm %s,%I64d\n", (char*)sp->name->c_str(), sp->tp->size);
			}
			else
				sprintf_s(&lbl[strlen(lbl)], sizeof(lbl) - strlen(lbl), "%s:\n", (char*)sp->name->c_str());
			sprintf_s(&lbl[strlen(lbl)], sizeof(lbl) - strlen(lbl), "\t.type\t%s,@object\n", (char*)sp->name->c_str());
			szpoint = strlen(lbl);
			sprintf_s(&lbl[strlen(lbl)], sizeof(lbl) - strlen(lbl), "\t.size\t%s,%I64d\n", (char*)sp->name->c_str(), sp->tp->size);
			if (sp->tp->size == 0)
				setsz = true;
		}
		//		strcat_s(lbl, sizeof(lbl), sp->name->c_str());
//		sprintf_s(&lbl[strlen(lbl)], sizeof(lbl) - strlen(lbl), "[xxx%d]", sp->tp->size);
		if (sp->tp->IsSkippable()) {
			patchpoint = ofs.tellp();
			switch (syntax) {
			case MOT:
				sprintf_s(buf, sizeof(buf), "\tdc.q\t$FFF0200000000001\n");
				break;
			default:
				sprintf_s(buf, sizeof(buf), "\t.8byte\t$FFF0200000000001\n");
			}
			ofs.printf(buf);
		}
		strcpy_s(glbl2, sizeof(glbl2), sp->name->c_str());
		lblpoint = ofs.tellp();
		ofs.printf(lbl);
		//gen_strlab(lbl);
	}
	if (lastst == kw_firstcall) {
        GenerateByte(1);
        goto xit;
    }
	else if( lastst != assign && !IsFuncptrAssign(sp)) {
		hasPointer = sp->tp->FindPointer();
		genstorage(sp->tp->size);
	}
	else {
		ENODE* node;
		Expression exp;

		if (!IsFuncptrAssign(sp)) {
			NextToken();
			if (lastst == bitandd) {
				ENODE* n;
				char buf[400];
				char buf2[40];
				if (sp->storage_class == sc_global)
					strcpy_s(buf2, sizeof(buf2), "\n");
				else
					strcpy_s(buf2, sizeof(buf2), "");
				switch (syntax) {
				case MOT:
					sprintf_s(buf, sizeof(buf), "%s\n\tdc.q %s_dat\n%s%s_dat:\n", lbl, sp->name->c_str(), buf2, sp->name->c_str());
					break;
				default:
					sprintf_s(buf, sizeof(buf), "%s\n\t.8byte %s_dat\n%s%s_dat:\n", lbl, sp->name->c_str(), buf2, sp->name->c_str());
				}
				ofs.seekp(lblpoint);
				ofs.write(buf);
				//			while (lastst != begin && lastst != semicolon && lastst != my_eof)
				//				NextToken();

			}
		}
		else {
			ENODE* n, *n2;
			char buf[400];
			char buf2[40];
			int64_t val = 0;
			Int128 val128;

			val128.low = val128.high = 0;
			if (sp->storage_class == sc_global)
				strcpy_s(buf2, sizeof(buf2), "\n");
			else
				strcpy_s(buf2, sizeof(buf2), "");
			if (sp->initexp) {
				n2 = sp->initexp->p[1];
				ProcessInitExp(sp, n2);
				switch (syntax) {
				case MOT:
					sprintf_s(buf, sizeof(buf), "%s:\ndc.q ", lbl);
					break;
				default:
					sprintf_s(buf, sizeof(buf), "%s:\n.8byte ", lbl);
				}
				ofs.seekp(lblpoint);
				ofs.write(buf);
				n2->PutConstant(ofs, 0, 0, false, 0);
			}
			else {
				switch (syntax) {
				case MOT:
					sprintf_s(buf, sizeof(buf), "%s:\ndc.q %s_func\n", lbl, sp->name->c_str());
					break;
				default:
					sprintf_s(buf, sizeof(buf), "%s:\n.8byte %s_func\n", lbl, sp->name->c_str());
				}
				ofs.seekp(lblpoint);
				ofs.write(buf);
			}
			//			while (lastst != begin && lastst != semicolon && lastst != my_eof)
			//				NextToken();

		}
		hasPointer = false;
		if (!IsFuncptrAssign(sp)) {
			Symbol* s2;
			TYP* et;
			hasPointer = sp->tp->FindPointer();
			typ_sp = 0;
			tp = sp->tp;
			push_typ(tp);
			while (tp = tp->btpp) {
				push_typ(tp);
			}
			brace_level = 0;
			strncpy_s(lastid, sizeof(lastid), sp->name->c_str(), sizeof(lastid));
			//gNameRefNode = exp.ParseNameRef(sp);
			s2 = currentSym;
			//currentSym = sp;
			et = exp.ParseExpression(&node, sp);	// Collect up aggregate initializers
			opt_const_unchecked(&node);			// This should reduce to a single integer expression
			//if (!node->AssignTypeToList(sp->tp)) {
			//	error(ERR_CASTAGGR);
			//}
			if (sp->tp->type == bt_array || (sp->tp->type==bt_pointer && sp->tp->val_flag)) {
				if (sp->tp->size == 0) {
					sp->tp->size = et->size;
					sp->tp->numele = et->numele;
				}
			}
			currentSym = s2;
			ENODE::initializedSet.clear();
			if (node != nullptr)
				sp->Initialize(node, sp->tp, 1);
			if (sp->tp->numele == 0) {
				if (sp->tp->btpp) {
					if (sp->tp->btpp->type == bt_char || sp->tp->btpp->type == bt_uchar
						|| sp->tp->btpp->type == bt_ichar || sp->tp->btpp->type == bt_iuchar
						) {
						sp->tp->numele = laststrlen;
						sp->tp->size = laststrlen * 2;
					}
				}
			}
		}
	}
	if (!hasPointer && sp->tp->IsSkippable()) {
		endpoint = ofs.tellp();
		ofs.seekp(patchpoint);
		switch (syntax) {
		case MOT:
			sprintf_s(buf, sizeof(buf), "\tdc.q\t0x%I64X\n", ((genst_cumulative + 7LL) >> 3LL) | 0xFFF0200000000000LL);
			break;
		default:
			sprintf_s(buf, sizeof(buf), "\t.8byte\t0x%I64X\n", ((genst_cumulative + 7LL) >> 3LL) | 0xFFF0200000000000LL);
		}
		ofs.printf(buf);
		ofs.seekp(endpoint);
		genst_cumulative = 0;
	}
	else if (sp->tp->IsSkippable()) {
		endpoint = ofs.tellp();
		ofs.seekp(patchpoint);
		switch (syntax) {
		case MOT:
			sprintf_s(buf, sizeof(buf), "\t  \t                 \n");
			break;
		default:
			sprintf_s(buf, sizeof(buf), "\t  \t                 \n");
		}
		ofs.printf(buf);
		ofs.seekp(endpoint);
		genst_cumulative = 0;
	}
	if (!IsFuncptrAssign(sp))
		endinit();
	if (sp->storage_class == sc_global)
		ofs.printf("\n");
xit:
	sp->storage_endpos = ofs.tellp();
}


// Patch the last gc_skip

void doInitCleanup()
{
	std::streampos endpoint;
	char buf[500];

	if (genst_cumulative && !hasPointer) {
		endpoint = ofs.tellp();
		if (patchpoint > 0) {
			ofs.seekp(patchpoint);
			switch (syntax) {
			case MOT:
				sprintf_s(buf, sizeof(buf), "\talign\t3\n\tdc.q\t0x%I64X\n", ((genst_cumulative + 7LL) >> 3LL) | 0xFFF0200000000000LL);
				break;
			default:
				sprintf_s(buf, sizeof(buf), "\t.align\t3\n\t.8byte\t0x%I64X\n", ((genst_cumulative + 7LL) >> 3LL) | 0xFFF0200000000000LL);
			}
			ofs.printf(buf);
			ofs.seekp(endpoint);
		}
		genst_cumulative = 0;
	}
}

int64_t initbyte(Symbol* symi, int opt)
{   
	GenerateByte(opt ? (int)GetIntegerExpression((ENODE **)NULL,symi,0).low : 0);
    return (1LL);
}

int64_t initchar(Symbol* symi, int opt)
{   
	GenerateChar(opt ? (int)GetIntegerExpression((ENODE **)NULL,symi,0).low : 0);
    return (2LL);
}

int64_t initshort(Symbol* symi, int64_t i, int opt)
{
	GenerateHalf(opt ? (int)GetIntegerExpression((ENODE **)NULL,symi,0).low : i);
    return (4LL);
}

int64_t initint(Symbol* symi, int64_t i, int opt)
{
	GenerateInt(opt ? GetIntegerExpression((ENODE**)NULL, symi, 0).low : i);
	return (8LL);
}

int64_t initlong(Symbol* symi, int opt)
{
	GenerateLong(opt ? GetIntegerExpression((ENODE**)NULL,symi,0) : symi->enode ? symi->enode->i128 : *Int128::Zero());
    return (16LL);
}

int64_t initquad(Symbol* symi, int opt)
{
	GenerateQuad(opt ? GetFloatExpression((ENODE **)NULL, symi) : Float128::Zero());
	return (16LL);
}

int64_t initfloat(Symbol* symi, int opt)
{
	GenerateFloat(opt ? GetFloatExpression((ENODE **)NULL, symi): symi->enode ? &symi->enode->f128 : &symi->f128);
	return (8LL);
}

int64_t initPosit(Symbol* symi, int opt)
{
	GeneratePosit(opt ? GetPositExpression((ENODE**)NULL, symi) : 0);
	return (8LL);
}

int64_t inittriple(Symbol* symi, int opt)
{
	GenerateQuad(opt ? GetFloatExpression((ENODE **)NULL, symi) : Float128::Zero());
	return (12LL);
}

int64_t InitializePointer(TYP *tp2, int opt, Symbol* symi)
{   
	Symbol *sp;
	ENODE *n = nullptr;
	int64_t lng;
	TYP *tp;
	bool need_end = false;
	Expression exp;

	if (opt==0) {
		GenerateLong(0);
		return (sizeOfPtr);
	}
	sp = nullptr;
	if (lastst == begin) {
		need_end = true;
		NextToken();
		if (lastst == begin) {
			NextToken();
			lng = tp2->Initialize(nullptr, nullptr,1, symi);
			needpunc(end, 13);
			needpunc(end, 14);
			return (lng);
		}
	}
    if(lastst == bitandd) {     /* address of a variable */
        NextToken();
				//tp = expression(&n);
				n = nullptr;
				tp = exp.ParseNonCommaExpression(&n, symi);
				opt_const(&n);
				if (n->nodetype != en_icon) {
					if (n->nodetype == en_ref) {
						if (n->p[0]->nodetype == en_add) {
							if (n->p[0]->p[0]->nodetype == en_labcon) {
								sp = n->p[0]->p[0]->sym;
								GenerateReference(n->p[0]->p[0]->sym, n->p[0]->p[1]->i);
							}
							else if (n->p[0]->p[1]->nodetype == en_labcon) {
								sp = n->p[0]->p[1]->sym;
								GenerateReference(n->p[0]->p[1]->sym, n->p[0]->p[0]->i);
							}
							else
								error(ERR_ILLINIT);
						}
						else if (n->p[0]->nodetype == en_sub || n->p[0]->nodetype == en_ptrdif) {
							if (n->p[0]->p[0]->nodetype == en_labcon) {
								sp = n->p[0]->p[0]->sym;
								GenerateReference(n->p[0]->p[0]->sym, -n->p[0]->p[1]->i);
							}
							else if (n->p[0]->p[1]->nodetype == en_labcon) {
								sp = n->p[0]->p[1]->sym;
								GenerateReference(n->p[0]->p[1]->sym, -n->p[0]->p[0]->i);
							}
							else
								error(ERR_ILLINIT);
						}
					}
				}
				else
					GenerateLong(n->i);
				if (sp)
					if (sp->storage_class == sc_auto)
						error(ERR_NOINIT);
				/*
        if( lastst != id)
            error(ERR_IDEXPECT);
		else if( (sp = gsearch(lastid)) == NULL)
            error(ERR_UNDEFINED);
        else {
            NextToken();
            if( lastst == plus || lastst == minus)
                GenerateReference(sp,(int)GetIntegerExpression((ENODE **)NULL));
            else
                GenerateReference(sp,0);
            if( sp->storage_class == sc_auto)
                    error(ERR_NOINIT);
        }
				*/
    }
    else if(lastst == sconst || lastst == asconst) {
			char *str;

			str = GetStrConst();
      GenerateLabelReference(stringlit(str),0, (char*)currentFn->sym->GetFullName()->c_str());
			free(str);
    }
		else if (lastst == rconst) {
			GenerateLabelReference(quadlit(&rval128), 0, (char*)currentFn->sym->GetFullName()->c_str());
			NextToken();
		}
		else if (lastst == pconst) {
			GeneratePosit(pval64);
			NextToken();
		}
	//else if (lastst == id) {
	//	sp = gsearch(lastid);
	//	if (sp->tp->type == bt_func || sp->tp->type == bt_ifunc) {
	//		NextToken();
	//		GenerateReference(sp,0);
	//	}
	//	else
	//		GenerateLong(GetIntegerExpression(NULL));
	//}
	else {
		lng = GetIntegerExpression(&n,symi,0).low;
		if (n && n->nodetype == en_cnacon) {
			if (n->sp->length()) {
				sp = gsearch(*n->sp);
				GenerateReference(sp,0);
			}
			else
				GenerateLong(lng);
		}
		else if (n && n->nodetype == en_labcon) {
			GenerateLabelReference(n->i,0, (char*)currentFn->sym->GetFullName()->c_str());
		}
		else if (n && n->nodetype == en_add) {
			if (n->p[0]->nodetype==en_labcon)
				GenerateLabelReference(n->p[0]->i, n->p[1]->i, (char*)currentFn->sym->GetFullName()->c_str());
			else
				GenerateLabelReference(n->p[1]->i, n->p[0]->i, (char*)currentFn->sym->GetFullName()->c_str());
		}
		else {
//			GenerateLong((lng & 0xFFFFFFFFFFFLL)|0xFFF0100000000000LL);
			GenerateLong(lng);
		}
	}
	if (need_end)
		needpunc(end, 8);
	endinit();
    return (sizeOfPtr);       /* pointers are 8 bytes long */
}

void endinit()
{    
  if (catchdecl) {
    if (lastst!=closepa)
      error(ERR_PUNCT);
  }
  else if( lastst != comma && lastst != semicolon && lastst != end && lastst != assign) {
		if (lastst == openpa)
			return;
		if (lastst == closepa)
			NextToken();
		else
			error(ERR_PUNCT);
	while( lastst != comma && lastst != semicolon && lastst != end && lastst != assign)
    NextToken();
  }
}
