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
extern char* lptr;
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

static int nnn = 0;
std::map<int, std::string> fnames;

void AppendFiles()
{
	List* lst, *plst;
	txtiStream ifs;
	std::string fname;
	char buf[4096];
	int kkk;

	for (kkk = 0; kkk < nnn; kkk++) {
		fname = fnames[kkk];
		if (fname.length()) {
			ifs.open(fname, std::ios::in);
			while (!ifs.eof()) {
				ifs.getline(buf, 4096, '\n');
				ofs << buf;
				ofs << "\n";
			};
			ofs.flush();
			ifs.close();
			remove(fname.c_str());
		}
	}
}

static std::string GetObjdecl(Symbol* sp, int64_t sz)
{
	std::string objdecl;
	char buf[100];

	_itoa_s(sz, buf, sizeof(buf), 10);
	switch (syntax) {
	case MOT:
		if (curseg == bssseg) {
			objdecl = "comm ";
			objdecl.append((char*)sp->name->c_str());
			objdecl.append(",");
			objdecl.append(buf);
			objdecl.append("\n");
		}
		else {
			objdecl = "";
			objdecl.append((char*)sp->name->c_str());
			objdecl.append(":\n");
			objdecl.append("\tdc.b\t");
			objdecl.append(buf);
			objdecl.append("\n");
		}
		break;
	default:
		if (curseg == bssseg) {
			objdecl = ".lcomm ";
			objdecl.append((char*)sp->name->c_str());
			objdecl.append(",");
			objdecl.append(buf);
			objdecl.append("\n");
		}
		else {
			objdecl = "";
			objdecl.append((char*)sp->name->c_str());
			objdecl.append(":\n");
		}
		objdecl.append("\t.type\t");
		objdecl.append((char*)sp->name->c_str());
		objdecl.append(",@object\n");
		objdecl.append("\t.size\t");
		objdecl.append((char*)sp->name->c_str());
		objdecl.append(",");
		objdecl.append(buf);
	}
	return (objdecl);
}

static std::string GetSegmentDecl(Symbol* sp)
{
	std::string decl;

	if (sp->storage_class == sc_global) {
		//strcpy_s(lbl, sizeof(lbl), ".global ");
		decl = "";
		switch (syntax) {
		case MOT:
			if (curseg == dataseg)
				decl.append("\tdata\n");
			else if (curseg == bssseg)
				decl.append("\tbss\n");
			else if (curseg == tlsseg)
				decl.append("\ttls\n");
			break;
		default:
			if (curseg == dataseg)
				decl.append("\t.data\n");
			else if (curseg == bssseg)
				decl.append("\t.bss\n");
			else if (curseg == tlsseg)
				decl.append("\t.tls\n");
		}
	}
	return (decl);
}

std::string GetAlignStatement()
{
	switch (syntax) {
	case MOT:
		return (std::string("\talign 4\n"));
	case STD:
		return (std::string("\t.align 4\n"));
	}
	return (std::string("\t.align 4\n"));
}

std::string GetSkipFormatWord(Symbol* sp)
{
	if (sp->tp->IsSkippable()) {
		switch (syntax) {
		case MOT:
			return (std::string("\talign 3\n\tdc.q\t$FFF0200000000001\n"));
		default:
			return (std::string("\t.align 3\t.8byte\t$FFF0200000000001\n"));
		}
		//			lblpoint = ofs.tellp();
		return (std::string("\t.align 3\t.8byte\t$FFF0200000000001\n"));
	}
	return (std::string(""));
}

// The skip amount word indicates how far ahead the garbage collector can skip
// while scanning for pointers. The compiler "knows" that there are no pointers
// in the area, so we make the collectors job a little easier.

std::string GetSkipAmountWord()
{
	char buf[200];

	switch (syntax) {
	case MOT:
		sprintf_s(buf, sizeof(buf), "\tdc.q\t0x%I64X\n", ((genst_cumulative + 7LL) >> 3LL) | 0xFFF0200000000000LL);
		break;
	default:
		sprintf_s(buf, sizeof(buf), "\t.8byte\t0x%I64X\n", ((genst_cumulative + 7LL) >> 3LL) | 0xFFF0200000000000LL);
	}
	genst_cumulative = 0;
	return (std::string(buf));
}

std::string GetBlankSkipAmountWord()
{
	switch (syntax) {
	case MOT:
		return (std::string("\t  \t                 \n"));
	default:
		return (std::string("\t  \t                 \n"));
	}
}

std::string GetBitandReference(Symbol* sp)
{
	std::string bar;
	std::string delim;

	if (sp->storage_class == sc_global)
		delim = "\n";
	else
		delim = "";
	switch (syntax) {
	case MOT:
		bar = "";
		bar.append((char*)sp->name->c_str());
		bar.append(":\n\tdc.q ");
		bar.append((char*)sp->name->c_str());
		bar.append("_dat\n");
		bar.append(delim);
		bar.append((char*)sp->name->c_str());
		bar.append("_dat:\n");
		break;
	default:
		bar = "";
		bar.append((char*)sp->name->c_str());
		bar.append(":\n\t.8byte ");
		bar.append((char*)sp->name->c_str());
		bar.append("_dat\n");
		bar.append(delim);
		bar.append((char*)sp->name->c_str());
		bar.append("_dat:\n");
	}
	return (bar);
}

static void SetFuncPointerAlign(Symbol* sp, e_sg oseg)
{
	int64_t algn;

	algn = sizeOfWord;
	seg(ofs, oseg == noseg ? dataseg : oseg, algn);          /* initialize into data segment */
	nl(ofs);                   /* start a new line in object */
}

static void SetThreadAlign(Symbol* sp, e_sg oseg)
{
	int64_t algn;
	e_sg os;

	if (sp->tp->type == bt_struct || sp->tp->type == bt_union)
		algn = imax(sp->tp->alignment, 8);
	else if (sp->tp->type == bt_pointer)// && sp->tp->val_flag)
		algn = imax(sp->tp->btpp->alignment, 8);
	else
		algn = 2;

	os = oseg == noseg ? tlsseg : oseg;
	curseg = os;
	if (os != bssseg) {
		seg(ofs, os, algn);
		nl(ofs);
	}
}

static void SetStaticAlign(Symbol* sp, e_sg oseg)
{
	int64_t algn;
	e_sg os;

	if (sp->tp->type == bt_struct || sp->tp->type == bt_union)
		algn = imax(sp->tp->alignment, 8);
	else if (sp->tp->type == bt_pointer)// && sp->tp->val_flag)
		algn = imax(sp->tp->btpp->alignment, 8);
	else
		algn = 2;
	os = oseg == noseg ? dataseg : oseg;
	curseg = os;
	if (os != bssseg) {
		seg(ofs, os, algn);          /* initialize into data segment */
		nl(ofs);                   /* start a new line in object */
	}
}

static void SetDefaultAlign(Symbol* sp, e_sg oseg)
{
	int64_t algn;
	e_sg os;

	if (sp->tp->type == bt_struct || sp->tp->type == bt_union)
		algn = imax(sp->tp->alignment, 8);
	else if (sp->tp->type == bt_pointer)// && sp->tp->val_flag)
		algn = imax(sp->tp->btpp->alignment, 8);
	else
		algn = 2;
	os = oseg == noseg ? (lastst == assign ? dataseg : bssseg) : oseg;
	curseg = os;
	if (os != bssseg) {
		seg(ofs, os, algn);            /* initialize into data segment */
		nl(ofs);                   /* start a new line in object */
	}
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
	std::streampos patchsz;
	std::streampos patch_saw;
	int64_t szpoint;
	bool setsz = false;
	bool parsed_something = false;
	char* slptr;
	TYP *tp;
	int n;
	ENODE* node;
	Expression exp(cg.stmt);
	txtoStream* old_ofs;
	std::string ofname;
	char nmbuf[300];
	bool move_file = false;
	int64_t bytes_inserted_or_deleted = 0;

	std::string objdecl;
	std::string segdecl;
	std::string aligndecl;
	std::string skipfmtword;
	std::string bar;
	std::string output_name;
	std::string init_str;
	std::string saw;

	old_ofs = &ofs;
	ofname = ofs.name;
	if (sp->storage_class != sc_global) {
		move_file = true;
		ofs.flush();
		ofs.close();
		tmpnam_s(nmbuf, sizeof(nmbuf));
		fnames.insert(std::pair<int, std::string>(nnn, nmbuf));
		nnn++;
		std::string fname = nmbuf;
		ofs.open(fname, std::ios::out | std::ios::trunc);
	}
	sp->storage_pos = ofs.tellp();
  hasPointer = false;
  if (first) {
	  firstPrim = true;
	  first = false;
  }

	// Ignore request to output function to data segment. This is a to be fixed
	// issue in the code generation. Somehow an extra symbol is being created
	// that looks like a .bss var when really it is a function. It was showing
	// up occasionally in the .bss output causing a duplicate symbol error
	// in the linker.
	if ((sp->tp->type == bt_func || sp->tp->type == bt_ifunc) || sp->fi)
		return;

  oseg = noseg;
	lbl[0] = 0;

	// Initialize constants into read-only data segment. Constants may be placed
	// in ROM along with code.
	if (sp->isConst)
    oseg = rodataseg;

	slptr = lptr;
	// Spit out an alignment pseudo-op
	if (IsFuncptrAssign(sp))
		SetFuncPointerAlign(sp, oseg);
	else if (sp->storage_class == sc_thread)
		SetThreadAlign(sp, oseg);
	else if (sp->storage_class == sc_static || lastst==assign)
		SetStaticAlign(sp, oseg);
	else
		SetDefaultAlign(sp, oseg);
	
	oseg = (e_sg)curseg;

	if (sp->storage_class == sc_static || sp->storage_class == sc_thread) {
		segdecl = "";
		aligndecl = "";
		objdecl = "";
		skipfmtword = "";// GetSkipFormatWord(sp);
		sp->realname = my_strdup(put_label(ofs,(int)sp->value.i, (char *)sp->name->c_str(), GetPrivateNamespace(), 'D', sp->tp->size));
		output_name = sp->realname;
	}
	else {
		segdecl = GetSegmentDecl(sp);
		aligndecl = GetAlignStatement();
		objdecl = GetObjdecl(sp, sp->tp->size);
		skipfmtword = "";// GetSkipFormatWord(sp);
		output_name = sp->name->c_str();
	}

	init_str = "";
	init_str.append(segdecl);
	init_str.append(aligndecl);
	init_str.append(objdecl);
	// Insert garbage collector command word to skip pointerless area.
	if (sp->tp->IsSkippable() && curseg != bssseg) {
		//init_str.append(skipfmtword);
		//init_str.append(GetSkipAmountWord());
	}
	if (curseg == dataseg) {
		sp->data_string = init_str;
		ofs << init_str;
		ofs.flush();
	}
	else if (oseg == bssseg)
		sp->bss_string = init_str;
	else {
		patch_saw = ofs.tellp();
		ofs << init_str;
		ofs.flush();
	}

	if (lastst == kw_firstcall) {
    GenerateByte(ofs,1);
    goto xit;
  }
	else if( lastst != assign && !IsFuncptrAssign(sp)) {
		hasPointer = sp->tp->FindPointer();
		if (!sp->IsExternal && oseg != bssseg)
			genstorage(ofs, sp->tp->size);
	}
	else {
		ENODE* node;
		Expression exp(cg.stmt);

		if (!IsFuncptrAssign(sp)) {
			NextToken();
			if (lastst == bitandd)
				bar = GetBitandReference(sp);
		}
		else {
			ENODE* n, *n2;
			char buf[400];
			int64_t val = 0;
			Int128 val128;

			val128.low = val128.high = 0;
			if (sp->initexp) { /*
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
				ofs << buf;
				n2->PutConstant(ofs, 0, 0, false, 0);
				*/
			}
			else {
				switch (syntax) {
				case MOT:
					sprintf_s(buf, sizeof(buf), "%s:\ndc.q %s_func\n", lbl, sp->name->c_str());
					break;
				default:
					sprintf_s(buf, sizeof(buf), "%s:\n.8byte %s_func\n", lbl, sp->name->c_str());
				}
				//ofs.seekp(lblpoint);
				ofs << buf;
			}
		}
		hasPointer = false;
		if (!IsFuncptrAssign(sp)) {
			Symbol* s2;
			TYP* et;
			int64_t sz = 0;

			hasPointer = sp->tp->FindPointer();
			typ_sp = 0;
			tp = sp->tp;
			push_typ(tp);
			while (tp = tp->btpp) {
				push_typ(tp);
			}
			brace_level = 0;
			strncpy_s(lastid, sizeof(lastid), sp->name->c_str(), sizeof(lastid));
			s2 = currentSym;
			et = exp.ParseExpression(&node, sp);	// Collect up aggregate initializers
			opt_const_unchecked(&node);			// This should reduce to a single integer expression
			if (sp->tp->type == bt_array || (sp->tp->type==bt_pointer && sp->tp->val_flag)) {
				if (sp->tp->size == 0) {
					sp->tp->size = et->size;
					sp->tp->numele = et->numele;
				}
			}
			currentSym = s2;
			ENODE::initializedSet.clear();
			if (node != nullptr)
				if (!sp->IsExternal && oseg != bssseg) {
					Symbol::initsym = sp;
					Symbol::initlvl = 0;
					sz = sp->Initialize(ofs, node, sp->tp, 1);
				}
			if (sp->tp->unknown_size) {
				sp->tp->size = sz;
				sp->tp->unknown_size = false;
			}
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
			// Under construction
			// It is allowed to specify an unknown size for the last array dimension.
			// This size will be unknown until initializers are output.
			// Override the object size if it was unknown with the size of initializers.
			/*
			if (sp->tp->unknown_size) {
				ofs.flush();
				std::streampos pos = ofs.tellp();
				ofs.seekp(patchsz+bytes_inserted_or_deleted);
				ofs << sz;
				ofs.flush();
				ofs.seekp(pos);
			}
			*/
		}
	}

	// Go back and patch the skip amount with the cumulative number of bytes
	// output.
	//endpoint = ofs.tellp();
	if (!sp->IsExternal && oseg != bssseg) {
/*
		ofs.seekp(patch_saw);
		if (!hasPointer && sp->tp->IsSkippable())
			saw = GetSkipAmountWord();
		else if (sp->tp->IsSkippable())
			saw = GetBlankSkipAmountWord();
		ofs << saw;
*/
		ofs.flush();
//		ofs.seekp(endpoint);
	}
	genst_cumulative = 0;

	// Do not call endinit() if nothing was parsed.
	if (!IsFuncptrAssign(sp) && slptr != lptr)
		endinit();
	if (sp->storage_class == sc_global)
		ofs << "\n";
xit:
	ofs.flush();
	sp->storage_endpos = ofs.tellp();
	if (move_file) {
		ofs.close();
		ofs.open(ofname, std::ios::out);// | std::ios::app);
	}
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
	GenerateByte(ofs, opt ? (int)GetIntegerExpression((ENODE **)NULL,symi,0).low : 0);
    return (1LL);
}

int64_t initchar(Symbol* symi, int opt)
{   
	GenerateChar(ofs, opt ? (int)GetIntegerExpression((ENODE **)NULL,symi,0).low : 0);
    return (2LL);
}

int64_t initshort(Symbol* symi, int64_t i, int opt)
{
	GenerateHalf(ofs, opt ? (int)GetIntegerExpression((ENODE **)NULL,symi,0).low : i);
    return (4LL);
}

int64_t initint(Symbol* symi, int64_t i, int opt)
{
	GenerateInt(ofs, opt ? GetIntegerExpression((ENODE**)NULL, symi, 0).low : i);
	return (8LL);
}

int64_t initlong(Symbol* symi, int opt)
{
	GenerateLong(ofs, opt ? GetIntegerExpression((ENODE**)NULL,symi,0) : symi->enode ? symi->enode->i128 : *Int128::Zero());
    return (16LL);
}

int64_t initquad(Symbol* symi, int opt)
{
	GenerateQuad(ofs, opt ? GetFloatExpression((ENODE **)NULL, symi) : Float128::Zero());
	return (16LL);
}

int64_t initfloat(Symbol* symi, int opt)
{
	GenerateFloat(ofs, opt ? GetFloatExpression((ENODE **)NULL, symi): symi->enode ? &symi->enode->f128 : &symi->f128);
	return (8LL);
}

int64_t initPosit(Symbol* symi, int opt)
{
	GeneratePosit(ofs, opt ? GetPositExpression((ENODE**)NULL, symi) : 0);
	return (8LL);
}

int64_t inittriple(Symbol* symi, int opt)
{
	GenerateQuad(ofs, opt ? GetFloatExpression((ENODE **)NULL, symi) : Float128::Zero());
	return (12LL);
}

// Dead code
int64_t InitializePointer(TYP *tp2, int opt, Symbol* symi)
{   
	Symbol *sp;
	ENODE *n = nullptr;
	int64_t lng;
	TYP *tp;
	bool need_end = false;
	Expression exp(cg.stmt);
/*
	if (opt==0) {
		GenerateLong(ofs, 0);
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
    if(lastst == bitandd) {     /* address of a variable
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
				sp = exp.gsearch2(*n->sp, bt_int, nullptr, false);
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
    return (sizeOfPtr);       /* pointers are 8 bytes long
	*/
	return(0);
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
		if (lastst == closepa) {
			return;
			NextToken();
		}
		else
			error(ERR_PUNCT);
	while( lastst != comma && lastst != semicolon && lastst != end && lastst != assign && lastst != my_eof)
    NextToken();
  }
}
