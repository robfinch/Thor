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
using namespace std;
#include <map>

/*
 *      this module contains all of the code generation routines
 *      for evaluating expressions and conditions.
 */

int hook_predreg=15;

Operand *GenerateExpression();            /* forward ParseSpecifieraration */

extern Operand *GenExpr(ENODE *node);

void GenLoad(Operand *ap3, Operand *ap1, int ssize, int size);

extern int throwlab;
static int nest_level = 0;

static void Enter(char *p)
{
/*
     int nn;
     
     for (nn = 0; nn < nest_level; nn++)
         printf(" ");
     printf("%s: %d ", p, lineno);
     nest_level++;
*/
}
static void Enter(const char* p) {
	Enter((char*)p);
}

static void Leave(char *p, int n)
{
/*
     int nn;
     
     nest_level--;
     for (nn = 0; nn < nest_level; nn++)
         printf(" ");
     printf("%s (%d) ", p, n);
*/
}


Operand *CodeGenerator::MakeDataLabel(int lab, int ndxreg)
{
	return (compiler.of.MakeDataLabel(lab, ndxreg));
}

Operand *CodeGenerator::MakeCodeLabel(int lab)
{
	return (compiler.of.MakeCodeLabel(lab));
}

Operand *CodeGenerator::MakeStringAsNameConst(char *s, e_sg seg)
{
	return (compiler.of.MakeStringAsNameConst(s, seg));
}

Operand *CodeGenerator::MakeString(char *s)
{
	return (compiler.of.MakeString(s));
}

Operand *CodeGenerator::MakeImmediate(int64_t i, int display)
{
	return (compiler.of.MakeImmediate(i, display));
}

Operand* CodeGenerator::MakeImmediate(Int128 i, int display)
{
	return (compiler.of.MakeImmediate(i, display));
}

Operand *CodeGenerator::MakeIndirect(int i)
{
	return (compiler.of.MakeIndirect(i));
}

Operand *CodeGenerator::MakeIndexed(int64_t o, int i)
{
	return (compiler.of.MakeIndexed(o, i));
}

Operand *CodeGenerator::MakeDoubleIndexed(int i, int j, int scale)
{
	return (compiler.of.MakeDoubleIndexed(i, j, scale));
}

Operand *CodeGenerator::MakeDirect(ENODE *node)
{
	return (compiler.of.MakeDirect(node));
}

Operand *CodeGenerator::MakeIndexed(ENODE *node, int rg)
{
	return (compiler.of.MakeIndexed(node, rg));
}

Operand* CodeGenerator::MakeIndexedName(std::string nme, int rg)
{
	return (compiler.of.MakeIndexedName(nme, rg));
}

void CodeGenerator::GenerateHint(int num)
{
	GenerateMonadic(op_hint,0,MakeImmediate(num));
}

void CodeGenerator::GenerateComment(char *cm)
{
	GenerateMonadic(op_rem2,0,MakeStringAsNameConst(cm,codeseg));
}

Operand* CodeGenerator::GetTempRegister() 
{
	return (::GetTempRegister());
}

Operand* CodeGenerator::GetTempFPRegister()
{
	return (::GetTempRegister());
}

//
// Generate code to evaluate a condition operator node (?:)
//
Operand* CodeGenerator::GenerateHook(ENODE* inode, int flags, int size)
{
	Operand* ap1, * ap2, * ap3;
	int false_label, end_label;
	ENODE* node;
	bool voidResult;

	false_label = nextlabel++;
	end_label = nextlabel++;
	//flags = (flags & am_reg) | am_volatile;
	flags |= am_volatile;
	//ip1 = currentFn->pl.tail;
	//ap2 = cg.GenerateExpression(p[1]->p[1], flags, size);
	//n1 = currentFn->pl.Count(ip1);
	//if (opt_nocgo)
	//	n1 = 9999;
	//ReleaseTempReg(ap2);
	//currentFn->pl.tail = ip1;
	//currentFn->pl.tail->fwd = nullptr;
	voidResult = inode->p[0]->etype == bt_void;
	cg.GenerateFalseJump(inode->p[0], false_label, 0);
	node = inode->p[1];
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], flags, size, 0);
	if (!voidResult)
		switch (ap1->mode) {
		case am_reg:
			GenerateMove(ap3, ap1);
			break;
		case am_imm:
			GenerateLoadConst(ap3, ap1);
			break;
		default:
			GenerateLoad(ap3, ap1, sizeOfWord, sizeOfWord);
			break;
		}
	ReleaseTempRegister(ap1);
	GenerateBra(end_label);
	GenerateLabel(false_label);
	ap2 = cg.GenerateExpression(node->p[1], flags, size, 1);
	if (!Operand::IsSameType(ap1, ap2) && !voidResult)
		error(ERR_MISMATCH);
	if (!voidResult)
		switch (ap2->mode) {
		case am_reg:
			GenerateMove(ap3, ap2);
			break;
		case am_imm:
			GenerateLoadConst(ap3, ap2);	// I think this is backwards, test
			break;
		default:
			GenerateLoad(ap3, ap2, sizeOfWord, sizeOfWord);
			break;
		}
	ReleaseTempRegister(ap2);
	GenerateLabel(end_label);
	ap3->MakeLegal(flags, size);
	return (ap3);
}

Operand* CodeGenerator::GenerateMux(ENODE* inode, int flags, int size)
{
	List* lst, *hlst;
	ENODE* pnode;
	Operand* ap1, *ap2, *ap3;
	int nn, kk;
	int64_t lab, labxit;
	bool void_result = false;

	labxit = nextlabel++;
	if (inode->nodetype != en_safe_cond)
		throw new C64PException(ERR_MISSING_MUX, 0);

	// Put the node list in the order we need.
	nn = 0;
	for (pnode = inode->p[1]; pnode; pnode = pnode->p[0])
		nn++;
	hlst = lst = new List[nn];
	kk = nn;
	for (pnode = inode->p[1]; pnode; pnode = pnode->p[0]) {
		--kk;
		lst[kk].node = pnode->p[1];
	}

	ap3 = GetTempRegister();
	ap2 = cg.GenerateExpression(inode->p[0], flags, size, 0);
	void_result = inode->etype == bt_void;
	for (kk = 0; kk < nn; kk++) {
		lab = nextlabel++;
		if (kk < nn - 1)
			GenerateBne(ap2, MakeImmediate(kk), lab);
		ap1 = cg.GenerateExpression(lst[kk].node, flags, size, 0);
		if (!void_result)
			switch (ap1->mode) {
			case am_reg:
				GenerateMove(ap3, ap1);
				break;
			case am_imm:
				GenerateLoadConst(ap1, ap3);
				break;
			default:
				GenerateLoad(ap3, ap1, sizeOfWord, sizeOfWord);
				break;
			}
		ReleaseTempRegister(ap1);
		GenerateBra(labxit);
		GenerateLabel(lab);
	}
	GenerateLabel(labxit);
	ReleaseTempRegister(ap2);
	return (ap3);
}

void CodeGenerator::GenerateLoadAddress(Operand* ap3, Operand* ap1)
{
	GenerateDiadic(op_lea, 0, ap3, ap1);
}

void CodeGenerator::GenerateLoad(Operand *ap3, Operand *ap1, int ssize, int size, Operand* mask)
{
	if (ap3->typep==&stdposit) {
		switch (ap3->tp->precision) {
		case 16:
			GenerateTriadic(op_pldw, 0, ap3, ap1, mask);
			break;
		case 32:
			GenerateTriadic(op_pldt, 0, ap3, ap1, mask);
			break;
		default:
			GenerateTriadic(op_pldo, 0, ap3, ap1, mask);
			break;
		}
	}
	else if (ap3->typep==&stdvector) {
		GenerateTriadic(op_loadv,0,ap3,ap1, mask);
	}
	else if (ap3->typep->IsFloatType())
		GenerateLoadFloat(ap3, ap1, ssize, size, mask);
	//else if (ap3->mode == am_fpreg) {
	//	GenerateTriadic(op_fldo, 0, ap3, ap1);
	//}
	else if (ap3->isUnsigned) {
		// If size is zero, probably a pointer to void being processed.
			switch (size) {
			case 0: GenerateTriadic(op_loadz, 0, ap3, ap1, mask); break;
			case 1:	GenerateTriadic(op_loadz, 'b', ap3, ap1, mask); break;
			case 2:	GenerateTriadic(op_loadz, 'w', ap3, ap1, mask); break;
			case 4:	GenerateTriadic(op_loadz, 't', ap3, ap1, mask); break;
			case 8: GenerateTriadic(op_loadz, 'o', ap3, ap1, mask); break;
			case 16:	GenerateTriadic(op_load, 0, ap3, ap1, mask); break;
			}
    }
    else {
			switch (size) {
			case 0: GenerateTriadic(op_load, 0, ap3, ap1, mask); break;
			case 1:	GenerateTriadic(op_load, 'b', ap3, ap1, mask); break;
			case 2:	GenerateTriadic(op_load, 'w', ap3, ap1, mask); break;
			case 4:	GenerateTriadic(op_load, 't', ap3, ap1, mask); break;
			case 8:	GenerateTriadic(op_load, 'o', ap3, ap1, mask); break;
			case 16: GenerateTriadic(op_load, 0, ap3, ap1, mask); break;
			}
    }
	ap3->memref = true;
	ap3->memop = ap1->Clone();
}

void CodeGenerator::GenerateStore(Operand *ap1, Operand *ap3, int size, Operand* mask)
{
	//if (ap1->isPtr) {
	//	GenerateTriadic(op_std, 0, ap1, ap3);
	//}
	//else
	if (ap3->tp && ap3->tp->IsPositType()) {
		switch (ap3->tp->precision) {
		case 16:
			GenerateTriadic(op_pstw, 0, ap1, ap3, mask);
			break;
		case 32:
			GenerateTriadic(op_pstt, 0, ap1, ap3, mask);
			break;
		default:
			GenerateTriadic(op_psto, 0, ap1, ap3, mask);
			break;
		}
	}
	if (ap3->typep==&stdposit) {
		GenerateTriadic(op_sto, 0, ap1, ap3, mask);
	}
	else if (ap1->typep==&stdvector)
	    GenerateTriadic(op_sv,0,ap1,ap3, mask);
	else if (ap1->typep == &stdflt) {
		GenerateTriadic(op_sto, 0, ap1, ap3, mask);
	}
	else if (ap1->typep == &stddouble) {
		if (ap1->mode == am_fpreg)
			printf("ho");
		GenerateTriadic(op_sto, 0, ap1, ap3, mask);
	}
	else if (ap1->typep == &stdquad) {
		GenerateTriadic(op_stf, 'q', ap1, ap3, mask);
	}
	else if (ap1->typep == &stdtriple) {
		GenerateTriadic(op_stf, 't', ap1, ap3, mask);
	}
	//else if (ap1->mode==am_fpreg)
	//	GenerateTriadic(op_fsto,0,ap1,ap3, mask);
	else {
		switch (size) {
		case 1: GenerateTriadic(op_store, 'b', ap1, ap3, mask); break;
		case 2: GenerateTriadic(op_store, 'w', ap1, ap3, mask); break;
		case 4: GenerateTriadic(op_store, 't', ap1, ap3, mask); break;
		case 8:	GenerateTriadic(op_store, 'o', ap1, ap3, mask); break;
		case 16:	GenerateTriadic(op_store, 0, ap1, ap3, mask); break;
		default:
			;
		}
	}
}

Operand* CodeGenerator::GenerateBitfieldDereference(ENODE* node, int flags, int size, int opt)
{
	return (node->GenerateBitfieldDereference(flags, size, opt));
}

ENODE* FindAnd(ENODE *node)
{
	if (node->nodetype == en_and) {
		if (node->p[1]->nodetype == en_icon) {
			if (node->p[1]->i == 63) {
				return (node->p[1]);
			}
		}
	}
}

Operand* CodeGenerator::GenerateFieldrefDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size)
{
	Operand* ap1;

	ap1 = GenerateExpression(node, am_reg | am_mem, sizeOfWord, 0);
	ap1->bit_offset = node->bit_offset;
	ap1->bit_width = node->bit_width;
	ap1->isPtr = isRefType;
	ap1->tp = tp;
	ap1->segment = dataseg;
	ap1->MakeLegal(flags, size);
	return (ap1);
}

Operand* CodeGenerator::GenerateAddDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su)
{
	Operand* ap1;

	ap1 = node->GenIndex(false);
	ap1->isUnsigned = !su;//node->isUnsigned;
// *** may have to fix for stackseg
	ap1->segment = dataseg;
	ap1->tp = tp;
	ap1->bit_offset = node->bit_offset;
	ap1->bit_width = node->bit_width;
	//		ap2->mode = ap1->mode;
	//		ap2->segment = dataseg;
	//		ap2->offset = ap1->offset;
	//		ReleaseTempRegister(ap1);
	if (!node->isUnsigned) {
		if (size < siz1)
			ap1 = ap1->GenerateSignExtend(siz1, size, flags);
	}
	else
		ap1->MakeLegal(flags, siz1);
	ap1->MakeLegal(flags, size);
	return (ap1);
}

Operand* CodeGenerator::GenerateAsaddDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su, bool neg)
{
	Operand* ap1, * ap2;

	ap2 = GetTempRegister();
	ap1 = GenerateExpression(node, flags, size, 0);
	ap1->mode = am_ind;
	GenerateLoad(ap2, ap1, size, size);
	ReleaseTempRegister(ap1);
	ap2->MakeLegal(flags, size);
	return (ap2);
}

Operand* CodeGenerator::GenerateAutoconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su)
{
	Operand* ap1, *ap3;
	int nn, ni;

	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	ap1->mode = am_indx;
	ap1->preg = regFP;
	ap1->segment = stackseg;
	ap1->offset = makeinode(en_icon, node->i);
	ap1->offset->sym = node->sym;
	ap1->bit_offset = node->bit_offset;
	ap1->bit_width = node->bit_width;
	ap1->argref = node->sym->IsParameter;
	ap1->isUnsigned = !su;
	ap1->tp = tp;

	ni = nn = (currentFn->depth + 1) - (node->sym->IsParameter?node->sym->depth + 3 : node->sym->depth);
	if (nn > 0) {
		ap3 = GetTempRegister();
		if (nn==1)
			GenerateLoad(ap3, MakeIndirect(regFP), size, size);
		else
			GenerateLoad(ap3, MakeIndirect(regFP), sizeOfWord, sizeOfWord);
		for (--nn; nn > 0; nn--) {
			if (nn == 1)
				GenerateLoad(ap3, MakeIndirect(ap3->preg), size, size);
			else
				GenerateLoad(ap3, MakeIndirect(regFP), sizeOfWord, sizeOfWord);
		}
		ap1->isPtr = true;// node->etype == bt_pointer;
		ap1->preg = ap3->preg;
		ap1->mode = am_indx;
	}

	//if (!compiler.os_code)
	//	GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(10));
	if (!node->isUnsigned)
		ap1 = ap1->GenerateSignExtend(siz1, size, flags);
	else
		ap1->MakeLegal(flags, siz1);
	return (ap1);             /* return reg */
}

Operand* CodeGenerator::GenerateClassconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su)
{
	Operand* ap1;

	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	ap1->mode = am_indx;
	ap1->preg = regCLP;
	ap1->segment = dataseg;
	ap1->offset = makeinode(en_icon, node->i);
	ap1->offset->sym = node->sym;
	ap1->isUnsigned = !su;
	ap1->tp = tp;
	if (!node->isUnsigned)
		ap1 = ap1->GenerateSignExtend(siz1, size, flags);
	else
		ap1->MakeLegal(flags, siz1);
	ap1->MakeLegal(flags, size);
	return (ap1);
}

Operand* CodeGenerator::GenerateAutofconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size)
{
	Operand* ap1;

	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	ap1->mode = am_indx;
	ap1->preg = regFP;
	ap1->offset = makeinode(en_icon, node->i);
	ap1->offset->sym = node->sym;
	ap1->tp = tp;
	if (node->tp)
		switch (node->tp->precision) {
		case 8: ap1->FloatSize = 'b'; break;
		case 16: ap1->FloatSize = 'h'; break;
		case 32: ap1->FloatSize = 's'; break;
		case 64: ap1->FloatSize = ' '; break;
		case 128: ap1->FloatSize = 'q'; break;
		default: ap1->FloatSize = 'd'; break;
		}
	else
		ap1->FloatSize = ' ';
	ap1->segment = stackseg;
	if (node->tp) {
		switch (node->tp->type) {
		case bt_float:	ap1->typep = &stdflt; break;
		case bt_double:	ap1->typep = &stddouble; break;
		case bt_quad:	ap1->typep = &stdquad; break;
		case bt_posit:	ap1->typep = &stdposit; break;
		}
	}
	else {
		node->tp = TYP::Make(bt_double, sizeOfFPD);
	}
	//	    ap1->MakeLegal(flags,siz1);
	ap1->MakeLegal(flags, size);
	return (ap1);
}

Operand* CodeGenerator::GenerateAutopconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size)
{
	Operand* ap1;

	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	ap1->mode = am_indx;
	ap1->preg = regFP;
	ap1->offset = makeinode(en_icon, node->i);
	ap1->offset->sym = node->sym;
	ap1->tp = node->tp;
	if (node->tp)
		switch (node->tp->precision) {
		case 16: ap1->FloatSize = 'h'; break;
		case 32: ap1->FloatSize = 's'; break;
		default: ap1->FloatSize = ' '; break;
		}
	else
		ap1->FloatSize = ' ';
	ap1->segment = stackseg;
	switch (node->tp->type) {
	case bt_posit: ap1->typep = &stdposit; break;
	}
	//	    ap1->MakeLegal(flags,siz1);
	ap1->MakeLegal(flags, size);
	return (ap1);
}

Operand* CodeGenerator::GenerateNaconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su)
{
	Operand* ap1;

	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	if (use_gp)
	{
		ap1->mode = am_indx;
		switch (node->segment) {
		case dataseg:	ap1->preg = regGP; break;
		case rodataseg: ap1->preg = regGP1; break;
		case tlsseg:	ap1->preg = regTP; break;
		default:	ap1->preg = regPP; break;
		}
		ap1->segment = node->segment;
	}
	else
	{
		ap1->mode = am_direct;
		ap1->preg = 0;
		ap1->segment = dataseg;
	}
	ap1->offset = node;//makeinode(en_icon,node->p[0]->i);
	ap1->tp = tp;
	ap1->isUnsigned = !su;
	if (!node->isUnsigned)
		ap1 = ap1->GenerateSignExtend(siz1, size, flags);
	else
		ap1->MakeLegal(flags, siz1);
	ap1->isVolatile = node->isVolatile;
	switch (node->tp->type) {
	case bt_float:	ap1->typep = &stdflt; break;
	case bt_double:	ap1->typep = &stddouble; break;
	case bt_quad:	ap1->typep = &stdquad; break;
	case bt_posit:	ap1->typep = &stdposit; break;
	}
	ap1->MakeLegal(flags, size);
	return (ap1);
}

Operand* CodeGenerator::GenerateAutovconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size)
{
	Operand* ap1;

	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	ap1->mode = am_indx;
	ap1->preg = regFP;
	ap1->offset = makeinode(en_icon, node->i);
	ap1->offset->sym = node->sym;
	ap1->tp = tp;
	if (node->tp)
		switch (node->tp->precision) {
		case 16: ap1->FloatSize = 'h'; break;
		case 32: ap1->FloatSize = 's'; break;
		case 64: ap1->FloatSize = 'd'; break;
		case 128: ap1->FloatSize = 'q'; break;
		default: ap1->FloatSize = 'd'; break;
		}
	else
		ap1->FloatSize = 'd';
	ap1->segment = stackseg;
	ap1->typep = &stdvector;
	//	    ap1->MakeLegal(flags,siz1);
	ap1->MakeLegal(flags, size);
	return (ap1);
}

Operand* CodeGenerator::GenerateAutovmconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size)
{
	Operand* ap1;

	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	ap1->mode = am_indx;
	ap1->preg = regFP;
	ap1->offset = makeinode(en_icon, node->i);
	ap1->offset->sym = node->sym;
	ap1->tp = tp;
	if (node->tp)
		switch (node->tp->precision) {
		case 32: ap1->FloatSize = 's'; break;
		case 64: ap1->FloatSize = 'd'; break;
		default: ap1->FloatSize = 'd'; break;
		}
	else
		ap1->FloatSize = 'd';
	ap1->segment = stackseg;
	ap1->typep = &stdvectormask;
	//	    ap1->MakeLegal(flags,siz1);
	ap1->MakeLegal(flags, size);
	return (ap1);
}

Operand* CodeGenerator::GenerateRegvarDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size)
{
	Operand* ap1;

	ap1 = allocOperand();
	ap1->isPtr = isRefType;

	// For parameters we want Rn, for others [Rn]
	// This seems like an error earlier in the compiler
	// See setting val_flag in ParseExpressions
	ap1->mode = (IsArgReg(node->rg)) ? am_reg : am_ind;
	//		ap1->mode = node->p[0]->tp->val_flag ? am_reg : am_ind;
	ap1->preg = node->rg;
	ap1->tp = node->tp;
	if (node->tp)
		ap1->isUnsigned = node->tp->isUnsigned;
	ap1->MakeLegal(flags, size);
	Leave((char *)"Genderef", 3);
	return (ap1);
}

// Dead code??? the register file is unified for Thor so register references 
// are strictly to the GPRs.

Operand* CodeGenerator::GenerateFPRegvarDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size)
{
	Operand* ap1;

	/*error(ERR_DEREF)*/;
	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	ap1->mode = (IsArgReg(node->rg)) ? am_reg : am_ind;
	ap1->preg = node->rg;
	ap1->tp = tp;
	switch (node->tp->type) {
	case bt_float:	ap1->typep = &stdflt; break;
	case bt_double:	ap1->typep = &stddouble; break;
	case bt_quad:	ap1->typep = &stdquad; break;
	case bt_posit:	ap1->typep = &stdposit; break;
	}
	ap1->MakeLegal(flags, size);
	Leave((char *)"</Genderef>", 3);
	return (ap1);
}

// Dead code??? as above

Operand* CodeGenerator::GeneratePositRegvarDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size)
{
	Operand* ap1;

	/*error(ERR_DEREF)*/;
	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	ap1->mode = (IsArgReg(node->rg)) ? am_reg : am_ind;
	ap1->preg = node->rg;
	ap1->tp = tp;
	switch (node->tp->type) {
	case bt_posit:	ap1->typep = &stdposit; break;
	}
	ap1->MakeLegal(flags, size);
	Leave((char *)"</Genderef>", 3);
	return (ap1);
}

Operand* CodeGenerator::GenerateLabconDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su)
{
	Operand* ap1;

	ap1 = allocOperand();
	ap1->isPtr = isRefType;
	if (use_gp)
	{
		ap1->mode = am_indx;
		switch (node->segment) {
		case dataseg:	ap1->preg = regGP; break;
		case rodataseg: ap1->preg = regGP1; break;
		case tlsseg:	ap1->preg = regTP; break;
		default:	ap1->preg = regPP; break;
		}
		ap1->segment = node->segment;
	}
	else
	{
		ap1->mode = am_direct;
		ap1->preg = 0;
		ap1->segment = node->segment;
	}
	ap1->offset = node;//makeinode(en_icon,node->p[0]->i);
	ap1->tp = tp;
	ap1->isUnsigned = !su;
	if (!node->isUnsigned)
		ap1 = ap1->GenerateSignExtend(siz1, size, flags);
	else
		ap1->MakeLegal(flags, siz1);
	ap1->isVolatile = node->isVolatile;
	ap1->MakeLegal(flags, size);
	return (ap1);
}

Operand* CodeGenerator::GenerateBitoffsetDereference(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int opt)
{
	Operand* ap1, * ap2, * ap3, * ap4, * ap5;
	OCODE* ip;

//	ap5 = GenerateBitfieldExtract(node->p[0], node->p[1], node->p[2]);
//	return (ap5);

	ap4 = GetTempRegister();
	ap1 = GenerateExpression(node->p[0], am_reg, sizeOfWord,0);
	if (opt) {
		ip = currentFn->pl.tail;
		ap2 = GenerateExpression(node->p[1], am_reg | am_imm | am_imm0, sizeOfWord,1);
		ap3 = GenerateExpression(node->p[2], am_reg | am_imm | am_imm0, sizeOfWord,1);
		if (ap2->mode != ap3->mode) {
			ReleaseTempReg(ap3);
			ReleaseTempReg(ap2);
			currentFn->pl.tail = ip;
			ap2 = GenerateExpression(node->p[1], am_reg, sizeOfWord,1);
			ap3 = GenerateExpression(node->p[2], am_reg, sizeOfWord,1);
		}
		ReleaseTempReg(ap3);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
	}
	else
		ap4 = ap1;
	ap4->bit_offset = node->p[1];
	ap4->bit_width = node->p[2];
	//ap4->isPtr = node->IsRefType();

	// For parameters we want Rn, for others [Rn]
	// This seems like an error earlier in the compiler
	// See setting val_flag in ParseExpressions
	//		ap1->mode = node->p[0]->rg < regFirstArg ? am_ind : am_reg;
			//		ap1->mode = node->p[0]->tp->val_flag ? am_reg : am_ind;
	//		ap1->preg = node->p[0]->rg;
	ap4->tp = tp;
	ap4->isUnsigned = node->tp->isUnsigned;
	ap4->MakeLegal(flags, size);
	Leave((char *)"Genderef", 3);
	return (ap4);
}

Operand* CodeGenerator::GenerateDereference2(ENODE* node, TYP* tp, bool isRefType, int flags, int64_t size, int64_t siz1, int su, int opt)
{
	Operand* ap1, * ap2, * ap3, * ap4;

	if (node == nullptr)
		return (nullptr);
	switch (node->nodetype) {
	case en_fieldref: return (GenerateFieldrefDereference(node, tp, isRefType, flags, size));
	case en_asadd:	return (GenerateAsaddDereference(node, tp, isRefType, flags, size, siz1, su, false));
	case en_assub:	return (GenerateAsaddDereference(node, tp, isRefType, flags, size, siz1, su, true));
	case en_add: return (GenerateAddDereference(node, tp, isRefType, flags, size, siz1, su));
	case en_autocon: return (GenerateAutoconDereference(node, tp, isRefType, flags, size, siz1, su));
	case en_classcon: return (GenerateClassconDereference(node, tp, isRefType, flags, size, siz1, su));
	case en_autofcon: return (GenerateAutofconDereference(node, tp, isRefType, flags, size));
	case en_autopcon: return (GenerateAutopconDereference(node, tp, isRefType, flags, size));
	case en_nacon: return (GenerateNaconDereference(node, tp, isRefType, flags, size, siz1, su));
	case en_autovcon: return (GenerateAutovconDereference(node, tp, isRefType, flags, size));
	case en_autovmcon: return (GenerateAutovmconDereference(node, tp, isRefType, flags, size));
	case en_labcon: return (GenerateLabconDereference(node, tp, isRefType, flags, size, siz1, su));
	case en_regvar: return (GenerateRegvarDereference(node, tp, isRefType, flags, size));
	case en_fpregvar: return (GenerateFPRegvarDereference(node, tp, isRefType, flags, size));
	case en_pregvar: return (GeneratePositRegvarDereference(node, tp, isRefType, flags, size));
	case en_bitoffset: return (GenerateBitoffsetDereference(node, tp, isRefType, flags, size, opt));

	// Dereferencing a reference, I think the two operations cancel out. I tried
	// just a return here, and the compiler seems to work.

	case en_ref:
		return (nullptr);
		// Dead code
		ap2 = GetTempRegister();
		ap1 = GenerateExpression(node, am_reg, sizeOfWord, 0);
		ap1->isPtr = isRefType;
		ap1->tp = tp;
		ap1->segment = dataseg;
		//ap1->MakeLegal(flags, size);
		//ap2->isPtr = TRUE;
		//ap1->mode = am_ind;
		ap3 = MakeIndirect(ap1->preg);
		GenerateLoad(ap2, ap3, size, size);
		ReleaseTempRegister(ap3);
		ReleaseTempRegister(ap1);
		//ap2->MakeLegal(flags, size);
		return (ap2);
		//		return (GenerateDereference2(node->p[0], tp, isRefType, flags, size, siz1, su, opt));
		return (GenerateDereference(node->p[0], flags, size, siz1, su, opt));
	
	// Should not get an en_type as it is just an artifact of typecasting
	// containing just a type and no variable. It should have been processed and
	// removed by optimization.

	case en_type:
		return (nullptr);
	default:
		return (nullptr);
	}
/*
	if (node->nodetype == en_vex) {
		Operand* ap2;
		if (node->nodetype == en_vector_ref) {
			ap1 = GenerateDereference(node->p[0], am_reg, 8, 0, 0);
			ap2 = GenerateExpression(node->p[1], am_reg, 8);
			if (ap1->offset && ap2->offset) {
				GenerateTriadic(op_add, 0, ap1, makereg(0), MakeImmediate(ap2->offset->i));
			}
			ReleaseTempReg(ap2);
			//ap1->mode = node->p[0]->i < 18 ? am_ind : am_reg;
			//ap1->preg = node->p[0]->i;
			ap1->type = stdvector.GetIndex();
			ap1->MakeLegal(flags, size);
			return (ap1);
		}
	}
*/
	return (nullptr);
}

//
//  Return the addressing mode of a dereferenced node.
//
Operand *CodeGenerator::GenerateDereference(ENODE *node,int flags,int size, int su, int opt, int rhs)
{    
	Operand *ap1, *ap2, *ap3, * ap4;
  int siz1;
	int typ;

  Enter((char *)"<Genderef>");
	siz1 = node->GetReferenceSize();
	// When dereferencing a struct or union return a pointer to the struct or
	// union.
	//if (node->tp)
	//	if (node->tp->type==bt_struct || node->tp->type==bt_union) {
	//		return GenerateExpression(node, am_reg | am_mem, size);
	//	}
	if (node->p[0] == nullptr) {
		if (rhs) {
			ap2 = GetTempRegister();
			ap1 = GenerateExpression(node->p[0], am_reg, size, 1);
			ap1->isPtr = node->IsRefType();
			//ap1->tp = node->tp;
			ap1->segment = dataseg;
			//ap1->MakeLegal(flags, size);
			//ap2->isPtr = TRUE;
			//ap1->mode = am_ind;
			ap3 = MakeIndirect(ap1->preg);
			GenerateLoad(ap2, ap3, size, size);
			ReleaseTempRegister(ap3);
			ReleaseTempRegister(ap1);
			ap1 = ap2;
		}
		else {
			ap1 = GetTempRegister();// GenerateExpression(node->p[0], am_reg, sizeOfWord, 0);
		}
	}
//	ap1 = GenerateDereference2(node, node->tp, node->IsRefType(), flags, size, siz1, su, opt);
	else
		ap1 = GenerateDereference2(node->p[0], node->tp, node->IsRefType(), flags, size, siz1, su, opt);
	if (ap1) {
		ap1->rhs = rhs;
		if (node->nodetype == en_fieldref) {
			ap1->bit_offset = node->bit_offset;
			ap1->bit_width = node->bit_width;
		}
		return(ap1);
	}
	ap1 = GenerateExpression(node->p[0], am_reg | am_imm, sizeOfWord,rhs); // generate address
	if (ap1 == nullptr)
		return (nullptr);
	ap1->isPtr = node->IsRefType();
	ap1->rhs = rhs;
	if(ap1->mode == am_reg)
  {
			// This seems a bit of a kludge. If we are dereferencing and there's a
			// pointer in the register, then we want the value at the pointer location.
			// Makes the ch=*s work in: while (ch = *s) { DBGDisplayChar(ch); s++; }
			// But it breaks: the *su = uc; so we want to do this only for the RHS.
			if (ap1->isPtr && rhs){// && !IsLValue(node)) {
				int sz = node->GetReferenceSize();
				int rg = ap1->preg;
				ReleaseTempRegister(ap1);
				ap1 = GetTempRegister();
				GenerateLoad(ap1, MakeIndirect(rg), sz, sz);
				ap1->mode = am_reg;
				ap1->isPtr = node->p[0]->IsRefType();
			}
			else
			{
			j1:
				if (!ap1->argref && FALSE) {
					//        ap1->mode = am_ind;
					if (use_gp) {
						ap1->mode = am_indx;
						ap1->preg = node->segment == rodataseg ? regGP1 : regGP;
					}
					else
						ap1->mode = am_ind;
					if (node->p[0]->constflag == TRUE)
						;// ap1->offset = node->p[0];
					else
						ap1->offset = nullptr;	// ****
					ap1->isUnsigned = !su | ap1->isPtr;
					if (!node->isUnsigned)
						ap1 = ap1->GenerateSignExtend(siz1, size, flags);
					else
						ap1->MakeLegal(flags, siz1);
					ap1->isVolatile = node->isVolatile;
				}
				ap1->MakeLegal(flags, size);
			}
			goto xit;
    }
	// Note sure about this, but immediate were being incorrectly
	// dereferenced as direct addresses because it would fall through
	// to the following dead code.
	
	if (ap1->mode == am_imm) {
		ap1->MakeLegal( flags, size);
		goto xit;
	}
	
	// *********************************************************************
	// I think what follows is dead code.
	// am_reg and am_imm the only codes that should be generated are
	// checked for above.
	// *********************************************************************

	// See segments notes
	//if (node->p[0]->nodetype == en_labcon &&
	//	node->p[0]->etype == bt_pointer && node->p[0]->constflag)
	//	ap1->segment = codeseg;
	//else
	//	ap1->segment = dataseg;
	if (use_gp) {
    ap1->mode = am_indx;
    ap1->preg = node->segment==rodataseg ? regGP1 : regGP;
    ap1->segment = dataseg;
  }
  else {
//    ap1->mode = am_direct;
	  ap1->isUnsigned = !su | ap1->isPtr;
  }
	if (ap1->isPtr) {
//		ap3 = GetTempRegister();
		ap2 = GetTempRegister();
		GenerateDiadic(op_ldo, 0, ap2, ap1);
//		GenLoad(ap3, MakeIndirect(ap2->preg), size, size);
//		ReleaseTempRegister(ap2);
		ap2->MakeLegal(flags, 8);
		return (ap2);
	}
//    ap1->offset = makeinode(en_icon,node->p[0]->i);
  ap1->isUnsigned = !su | ap1->isPtr;
	if (!node->isUnsigned)
	    ap1 = ap1->GenerateSignExtend(siz1,size,flags);
	else
		ap1->MakeLegal(flags,siz1);
  ap1->isVolatile = node->isVolatile;
  ap1->MakeLegal(flags,size);
xit:
  Leave((char *)"</Genderef>",0);
  return (ap1);
}


void CodeGenerator::GenMemop(int op, Operand *ap1, Operand *ap2, int ssize, int typ)
{
	Operand *ap3;
	int tp;

	if (typ == bt_double || typ == bt_float) {
		ap3 = GetTempFPRegister();
		GenerateLoad(ap3, ap1, ssize, ssize);
		GenerateTriadic(op, 0, ap3, ap3, ap2);
		GenerateStore(ap3, ap1, ssize);
		ReleaseTempReg(ap3);
		return;
	}
	if (typ == bt_posit) {
		ap3 = GetTempPositRegister();
		GenerateLoad(ap3, ap1, ssize, ssize);
		GenerateTriadic(op, 0, ap3, ap3, ap2);
		GenerateStore(ap3, ap1, ssize);
		ReleaseTempReg(ap3);
		return;
	}
	if (ap1->typep==&stddouble) {
     	ap3 = GetTempFPRegister();
		GenerateLoad(ap3,ap1,ssize,ssize);
		GenerateTriadic(op,ap1->FloatSize,ap3,ap3,ap2);
		GenerateStore(ap3,ap1,ssize);
		ReleaseTempReg(ap3);
		return;
	}
	if (ap1->typep == &stdposit) {
		ap3 = GetTempPositRegister();
		GenerateLoad(ap3, ap1, ssize, ssize);
		GenerateTriadic(op, ap1->FloatSize, ap3, ap3, ap2);
		GenerateStore(ap3, ap1, ssize);
		ReleaseTempReg(ap3);
		return;
	}
	if (ap1->typep==&stdvector) {
   		ap3 = GetTempVectorRegister();
		GenerateLoad(ap3,ap1,ssize,ssize);
		GenerateTriadic(op,0,ap3,ap3,ap2);
		GenerateStore(ap3,ap1,ssize);
		ReleaseTempReg(ap3);
		return;
	}
	//if (ap1->mode != am_indx2)
	// Increment / decrement not supported
	if (0) {
		if (op==op_add && ap2->mode==am_imm && ap2->offset->i >= -16 && ap2->offset->i < 16 && ssize==8) {
			GenerateDiadic(op_inc,0,ap1,ap2);
			return;
		}
		if (op==op_sub && ap2->mode==am_imm && ap2->offset->i >= -15 && ap2->offset->i < 15 && ssize==8) {
			GenerateDiadic(op_dec,0,ap1,ap2);
			return;
		}
	}
   	ap3 = GetTempRegister();
	ap3->isPtr = ap1->isPtr;
    GenerateLoad(ap3,ap1,ssize,ssize);
	GenerateTriadic(op,0,ap3,ap3,ap2);
	GenerateStore(ap3,ap1,ssize);
	ReleaseTempReg(ap3);
}

Operand* CodeGenerator::GenerateBitfieldAssignAdd(ENODE* node, int flags, int size, int op)
{
	Operand* ap1, * ap2, * ap3, * ap4;
	int ssize;

	ssize = node->p[0]->GetNaturalSize();
	if (ssize > size)
		size = ssize;
	ap3 = GetTempRegister();
	ap1 = GenerateBitfieldDereference(node->p[0], am_reg | am_mem, size, 1);
	//		GenerateDiadic(op_mov, 0, ap3, ap1);
	//ap1 = cg.GenerateExpression(p[0], am_reg | am_mem, size);
	ap2 = GenerateExpression(node->p[1], am_reg | am_imm, size, 1);
	if (ap1->mode == am_reg) {
		GenerateTriadic(op, 0, ap1, ap1, ap2);
		//			if (ap1->bit_offset < 0)
		//				GenerateBitfieldInsert(ap3, ap1, ap1->next, MakeImmediate(1));
		//			else
		GenerateBitfieldInsert(ap3, ap1, ap1->bit_offset, ap1->bit_width);
		//cg.GenerateBitfieldInsert(ap3, ap1, ap1->offset->bit_offset, ap1->offset->bit_width);
	}
	else {
		GenerateLoad(ap3, ap1, size, size);
		//Generate4adic(op_bfext, 0, ap4, ap3, MakeImmediate(ap1->offset->bit_offset), MakeImmediate(ap1->offset->bit_width-1));
		ap4 = GenerateBitfieldExtract(ap3, ap1->bit_offset, ap1->bit_width);
		GenerateTriadic(op, 0, ap4, ap4, ap2);
		GenerateBitfieldInsert(ap3, ap4, ap1->bit_offset, ap1->bit_width);
		node->GenStore(ap3, ap1, ssize);
		ReleaseTempReg(ap4);
	}
	ReleaseTempReg(ap2);
	ReleaseTempReg(ap1);
	ap3->MakeLegal(flags, size);
	return (ap3);
}

Operand* CodeGenerator::GenerateVectorBinaryFloat(ENODE* node, int flags, int size, e_op op)
{
	Operand* ap1 = nullptr, * ap2 = nullptr, * ap3, * ap4, * vap3, * vap4, *apm;
	bool dup = false;
	bool vec = false;
	int flags2;

	ap3 = GetTempVectorRegister();
	ap4 = GetTempVectorRegister();
	if (ENODE::IsEqual(node->p[0], node->p[1]))
		dup = !opt_nocgo;
	switch (op) {
	case op_vadds: op = op_vfadds; break;
	case op_vmul: op = op_vfmul; break;
	case op_fadd: op = op_vfadd; break;
	case op_fsub: op = op_vfsub; break;
	case op_fmul: op = op_vfmul; break;
	}
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op)->amclass2, size, 0);
	if (!dup) {
		flags2 = Instruction::Get(op)->amclass3;
		ap2 = cg.GenerateExpression(node->p[1], flags2, size, 1);
	}
	apm = cg.GenerateExpression(node->vmask, am_reg, size, 0);

	// Generate a convert operation ?
	if (!dup) {
		if (ap1->fpsize() != ap2->fpsize()) {
			if (ap2->fpsize() == 's')
				GenerateDiadic(op_fcvtsq, 0, ap2, ap2);
		}
	}
	// Two immediate operands not supported.
	if (ap1->mode == am_imm && ap2->mode == am_imm) {
		GenerateLoadFloatConst(ap4, ap1);
		ap1 = ap4;
	}
	if (dup)
		Generate4adic(op, 0, ap3, ap1, ap1, apm);
	else
		Generate4adic(op, 0, ap3, ap1, ap2, apm);
	ap3->type = ap1->type;

	if (ap2)
		ReleaseTempReg(ap2);
	if (ap1)
		ReleaseTempReg(ap1);
	ReleaseTempReg(ap4);
	return (ap3);
}

Operand* CodeGenerator::GenerateVectorBinary(ENODE* node, int flags, int size, e_op op)
{
	Operand* ap1 = nullptr, * ap2 = nullptr, * ap3, * ap4, * vap3, * vap4, * apm;
	bool dup = false;
	bool vec = false;
	int flags2;

	if (node->IsFloatType())
		return (GenerateVectorBinaryFloat(node, flags, size, op));

	ap3 = GetTempVectorRegister();
	ap4 = GetTempVectorRegister();
	if (ENODE::IsEqual(node->p[0], node->p[1]))
		dup = !opt_nocgo;
	switch (op) {
	case op_add: op = op_vadd; break;
	case op_sub: op = op_vsub; break;
	case op_mul: op = op_vmul; break;
	}
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op)->amclass2, size, 0);
	if (!dup) {
		flags2 = Instruction::Get(op)->amclass3;
		ap2 = cg.GenerateExpression(node->p[1], flags2, size, 1);
	}
	apm = cg.GenerateExpression(node->vmask, am_reg, size, 0);

	// Generate a convert operation ?
	if (!dup) {
		if (ap1->fpsize() != ap2->fpsize()) {
			if (ap2->fpsize() == 's')
				GenerateDiadic(op_fcvtsq, 0, ap2, ap2);
		}
	}
	// Two immediate operands not supported.
	if (ap1->mode == am_imm && ap2->mode == am_imm) {
		GenerateLoadFloatConst(ap4, ap1);
		ap1 = ap4;
	}
	if (dup)
		Generate4adic(op, 0, ap3, ap1, ap1, apm);
	else
		Generate4adic(op, 0, ap3, ap1, ap2, apm);
	ap3->type = ap1->type;

	if (ap2)
		ReleaseTempReg(ap2);
	if (ap1)
		ReleaseTempReg(ap1);
	ReleaseTempReg(ap4);
	return (ap3);
}

Operand* CodeGenerator::GenerateBinaryFloat(ENODE* node, int flags, int size, e_op op)
{
	Operand* ap1 = nullptr, * ap2 = nullptr, * ap3, * ap4, *vap3, *vap4;
	bool dup = false;
	bool vec = false;

	if (node->IsVectorType())
		return (GenerateVectorBinary(node, flags, size, op));

	ap3 = GetTempRegister();
	ap4 = GetTempRegister();
	if (ENODE::IsEqual(node->p[0], node->p[1]))
		dup = !opt_nocgo;
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op)->amclass2, size, 0);
	if (!dup) {
		ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op)->amclass3, size, 1);
	}
	if (ap1->mode == am_vreg || (ap2 && ap2->mode == am_vreg)) {
		vec = true;
		op = op_vfmul;
	}
	// Generate a convert operation ?
	if (!dup) {
		if (ap1->fpsize() != ap2->fpsize()) {
			if (ap2->fpsize() == 's')
				GenerateDiadic(op_fcvtsq, 0, ap2, ap2);
		}
	}
	// Two immediate operands not supported.
	if (ap1->mode == am_imm && ap2->mode == am_imm) {
		GenerateLoadFloatConst(ap4, ap1);
		ap1 = ap4;
	}
	if (dup)
		GenerateTriadic(op, 0, ap3, ap1, ap1);
	else
		GenerateTriadic(op, 0, ap3, ap1, ap2);
	ap3->type = ap1->type;

	if (ap2)
		ReleaseTempReg(ap2);
	if (ap1)
		ReleaseTempReg(ap1);
	ap3->MakeLegal(flags, size);
	return (ap3);
}

Operand* CodeGenerator::GenerateAssignAdd(ENODE* node, int flags, int size, int op)
{
	Operand* ap1, * ap2, * ap3, * ap4;
	int ssize;
	bool negf = false;
	bool intreg = false;
	MachineReg* mr;

	if (node->p[0]->IsBitfield())
		return (GenerateBitfieldAssignAdd(node, flags, size, op));

	ssize = node->p[0]->GetNaturalSize();
	if (ssize > size)
		size = ssize;

	// Select which opcode is being used.
	if (node->IsFloatType()) {
		if (op == op_add)
			op = op_fadd;
		else if (op == op_sub)
			op = op_fsub;
	}
	else if (node->etype == bt_vector) {
		if (op == op_add)
			op = op_vadd;
		else if (op == op_sub)
			op = op_vsub;
	}
	else {
		intreg = true;
	}

	ap1 = GenerateExpression(node->p[0], Instruction::Get(op)->amclass1, ssize, 0);
	ap2 = GenerateExpression(node->p[1], Instruction::Get(op)->amclass3, size, 1);
	if (ap1->mode == am_reg) {
		GenerateTriadic(op, 0, ap1, ap1, ap2);
		if (intreg) {
			mr = &regs[ap1->preg];
			if (mr->assigned)
				mr->modified = true;
			mr->assigned = true;
			mr->isConst = ap1->isConst && ap2->isConst;
		}
	}
	//else if (ap1->mode == am_fpreg) {
	//	GenerateTriadic(op, ap1->fpsize(), ap1, ap1, ap2);
	//	ReleaseTempReg(ap2);
	//	ap1->MakeLegal( flags, size);
	//	return (ap1);
	//}
	else {
		GenMemop(op, ap1, ap2, ssize, node->etype);
	}
	ReleaseTempReg(ap2);
	//if (ap1->type != stddouble.GetIndex() && !ap1->isUnsigned)
	//	ap1 = ap1->GenSignExtend(ssize, size, flags);
	ap1->MakeLegal(flags, size);
	return (ap1);
}

//
//      generate a *= node.
//
Operand *CodeGenerator::GenerateAssignMultiply(ENODE *node,int flags, int size, int op)
{
	Operand *ap1, *ap2, *ap3, *ap4;
  int ssize;
	MachineReg *mr;
	int typ;

	typ = node->etype;
  ssize = node->p[0]->GetNaturalSize();
  if( ssize > size )
    size = ssize;
	if (node->p[0]->IsBitfield()) {
		ap3 = GetTempRegister();
		ap1 = GenerateBitfieldDereference(node->p[0], am_reg | am_mem, size, 1);
		if (ap1->mode == am_reg)
			GenerateMove(ap3, ap1);
		else
			GenerateLoad(ap3, ap1, size, size);
		ap2 = GenerateExpression(node->p[1], am_reg | am_imm, size, 1);
		GenerateTriadic(op, 0, ap1, ap1, ap2);
//		ap4 = GenerateExpression(ap1->offset->bit_offset, am_reg | am_imm | am_imm0, sizeOfWord, 1);
//		if (ap4 < 0)
//			GenerateBitfieldInsert(ap3, ap1, ap1->next, MakeImmediate(1));
//		else
			GenerateBitfieldInsert(ap3, ap1, ap1->offset->bit_offset, ap1->offset->bit_width);
		GenerateStore(ap3, ap1->next, ssize);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1->next);
		ReleaseTempReg(ap1);
		ap3->MakeLegal( flags, size);
		return (ap3);
	}
	if (node->IsFloatType()) {
    ap1 = GenerateExpression(node->p[0],am_reg | am_mem,ssize,0);
    ap2 = GenerateExpression(node->p[1],am_reg,size,1);
    op = op_fmul;
  }
	else if (node->IsPositType()) {
		ap1 = GenerateExpression(node->p[0], am_reg | am_mem, ssize,0);
		ap2 = GenerateExpression(node->p[1], am_reg, size,1);
		op = op_pmul;
	}
	else if (node->etype==bt_vector) {
    ap1 = GenerateExpression(node->p[0],am_reg | am_mem,ssize,0);
    ap2 = GenerateExpression(node->p[1],am_reg,size,1);
		//op = ap2->type==stdvector.GetIndex() ? op_vmul : op_vmuls;
		op = ap2->typep == &stdvector ? op_vmul : op_vmuls;
	}
  else {
    ap1 = GenerateExpression(node->p[0],am_all & ~am_imm & ~am_fpreg,ssize,0);
    ap2 = GenerateExpression(node->p[1],am_reg | am_imm,size,1);
  }
	if (ap1->mode==am_reg) {
	    GenerateTriadic(op,0,ap1,ap1,ap2);
			if (op == op_mulu || op == op_mul) {
				mr = &regs[ap1->preg];
				if (mr->assigned)
					mr->modified = true;
				mr->assigned = true;
				mr->isConst = ap1->isConst && ap2->isConst;
			}
	}
	else if (ap1->tp->IsFloatType()) {
		ap3 = GetTempRegister();
		GenerateLoad(ap3, ap1, ssize, ssize);
	  GenerateTriadic(op,0, ap3,ap3,ap2);
		GenerateStore(ap3, ap1, ssize);
		ReleaseTempRegister(ap3);
	  ReleaseTempReg(ap2);
	  ap1->MakeLegal(flags,size);
		return (ap1);
	}
	else if (ap1->tp->IsPositType()) {
		GenerateTriadic(op, ssize == 4 ? 's' : ssize == 8 ? ' ' : ssize == 2 ? 'h' : ' ', ap1, ap1, ap2);
		ReleaseTempReg(ap2);
		ap1->MakeLegal(flags, size);
		return (ap1);
	}
	else {
		GenMemop(op, ap1, ap2, ssize, typ);
	}
    ReleaseTempReg(ap2);
    ap1 = ap1->GenerateSignExtend(ssize,size,flags);
    ap1->MakeLegal(flags,size);
    return (ap1);
}

/*
 *      generate /= and %= nodes.
 */
Operand *CodeGenerator::GenerateAssignModiv(ENODE *node,int flags,int size,int op)
{
	Operand *ap1, *ap2, *ap3;
    int             siz1;
    int isFP;
		bool isPosit;
		MachineReg *mr;
		bool cnst = false;
 
    siz1 = node->p[0]->GetNaturalSize();
	if (node->p[0]->IsBitfield()) {
		ap3 = GetTempRegister();
		ap1 = GenerateBitfieldDereference(node->p[0], am_reg | am_mem, size, 1);
		if (ap1->mode == am_reg)
			GenerateMove(ap3, ap1);
		else
			GenerateLoad(ap3, ap1, size, size);
		ap2 = GenerateExpression(node->p[1], am_reg | am_imm, size,1);
		GenerateTriadic(op, 0, ap1, ap1, ap2);
//		if (ap1->offset->bit_offset < 0)
//			GenerateBitfieldInsert(ap3, ap1, ap1->next, MakeImmediate(1));
//		else
			GenerateBitfieldInsert(ap3, ap1, ap1->offset->bit_offset, ap1->offset->bit_width);
		GenerateStore(ap3, ap1->next, siz1);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1->next);
		ReleaseTempReg(ap1);
		ap3->MakeLegal( flags, size);
		return (ap3);
	}
	isFP = node->etype==bt_double || node->etype==bt_float || node->etype==bt_quad;
	isPosit = node->etype == bt_posit;
    if (isFP) {
        if (op==op_div || op==op_divu)
           op = op_fdiv;
        ap1 = GenerateExpression(node->p[0],am_reg,siz1,1);
        ap2 = GenerateExpression(node->p[1],am_reg,size,1);
		GenerateTriadic(op,siz1==4?'s':siz1==8?' ':siz1==12?'t':siz1==16?'q':'d',ap1,ap1,ap2);
	    ReleaseTempReg(ap2);
		ap1->MakeLegal(flags,size);
	    return (ap1);
//        else if (op==op_mod || op==op_modu)
//           op = op_fdmod;
    }
		else if (isPosit) {
			if (op == op_div || op == op_divu)
				op = op_pdiv;
			ap1 = GenerateExpression(node->p[0], am_reg, siz1,1);
			ap2 = GenerateExpression(node->p[1], am_reg, size,1);
			GenerateTriadic(op, siz1 == 4 ? 's' : siz1 == 8 ? ' ' : siz1 == 16 ? 'q' : 'd', ap1, ap1, ap2);
			ReleaseTempReg(ap2);
			ap1->MakeLegal(flags, size);
			return (ap1);
			//        else if (op==op_mod || op==op_modu)
			//           op = op_fdmod;
		}
		else {
        ap1 = GetTempRegister();
        ap2 = GenerateExpression(node->p[0],am_all & ~am_imm & ~am_fpreg,siz1,1);
    }
	if (ap2->mode==am_reg && ap2->preg != ap1->preg)
		GenerateMove(ap1,ap2);
	//else if (ap2->mode==am_fpreg && ap2->preg != ap1->preg)
	//	GenerateDiadic(op_mov,0,ap1,ap2);
	else
        GenerateLoad(ap1,ap2,siz1,siz1);
    //GenerateSignExtend(ap1,siz1,2,flags);
    if (isFP)
        ap3 = GenerateExpression(node->p[1],am_reg,sizeOfWord, 1);
		else {
			// modu doesn't support immediate mode
			ap3 = GenerateExpression(node->p[1], op==op_modu ? am_reg : am_reg | am_imm, sizeOfWord, 1);
		}
	if (op==op_fdiv) {
		GenerateTriadic(op,siz1==4?'s':siz1==8?' ':siz1==12?'t':siz1==16?'q':'d',ap1,ap1,ap3);
	}
	else {
		GenerateTriadic(op, 0, ap1, ap1, ap3);
		cnst = ap1->isConst && ap3->isConst;
		mr = &regs[ap1->preg];
		if (mr->assigned)
			mr->modified = true;
		mr->assigned = true;
		mr->isConst = cnst;
	}
  ReleaseTempReg(ap3);
  //GenerateDiadic(op_ext,0,ap1,0);
	if (ap2->mode == am_reg) {
		GenerateMove(ap2, ap1);
		mr = &regs[ap2->preg];
		if (mr->assigned)
			mr->modified = true;
		mr->assigned = true;
		mr->isConst = cnst;
	}
	//else if (ap2->mode==am_fpreg)
	//	GenerateDiadic(op_mov,0,ap2,ap1);
	else
	    GenerateStore(ap1,ap2,siz1);
    ReleaseTempReg(ap2);
	if (!isFP)
		ap1->MakeLegal(flags,size);
    return (ap1);
}

// This little bit of code a debugging aid.
// Dumps the expression nodes associated with an aggregate assignment.

void DumpStructEnodes(ENODE *node)
{
	ENODE *head;
	TYP *tp;

	lfs.printf("{");
	head = node;
	while (head) {
		tp = head->tp;
		if (tp)
			tp->put_ty();
		if (head->nodetype==en_aggregate) {
			DumpStructEnodes(head->p[0]);
		}
		if (head->nodetype==en_icon)
			lfs.printf((char *)"%d", head->i);
		head = head->p[1];
	}
	lfs.printf("}");
}


// Generate an assignment to a structure type. The type passed must be a
// structure type.

void CodeGenerator::GenerateStructAssign(TYP *tp, int64_t offset, ENODE *ep, Operand *base)
{
	Symbol *thead, *first;
	Operand *ap1, *ap2;
	int64_t offset2;
	ENODE *node;

	first = thead = tp->lst.headp;
	ep = ep->p[0];
	while (thead) {
		if (ep == nullptr)
			break;
		if (thead->tp->IsAggregateType()) {
			/*
			if (thead->tp->isArray) {
				if (ep->p[2])
					GenerateArrayAssign(thead->tp, offset, ep->p[2], base);
				else if (ep->p[0])
					GenerateArrayAssign(thead->tp, offset, ep->p[0], base);
			}
			else
			*/
			{
				if (ep->p[2])
					GenerateStructAssign(thead->tp, offset, ep->p[2], base);
				else if (ep->p[0])
					GenerateStructAssign(thead->tp, offset, ep->p[0], base);
			}
/*
			else {
				ap1 = GenerateExpression(ep, am_reg, thead->tp->size);
				if (ap1->mode == am_imm) {
					ap2 = GetTempRegister();
					GenLdi(ap2, ap1);
				}
				else {
					ap2 = ap1;
					ap1 = nullptr;
				}
				if (base->offset)
					offset2 = base->offset->i + offset;
				else
					offset2 = offset;
				switch (thead->tp->size)
				{
				case 1:	GenerateDiadic(op_stb, 0, ap2, MakeIndexed(offset, base->preg)); break;
				case 2:	GenerateDiadic(op_stw, 0, ap2, MakeIndexed(offset, base->preg)); break;
				case 4:	GenerateDiadic(op_stp, 0, ap2, MakeIndexed(offset, base->preg)); break;
				case 512:	GenerateDiadic(op_sv, 0, ap2, MakeIndexed(offset, base->preg)); break;
				default:	GenerateDiadic(op_std, 0, ap2, MakeIndexed(offset, base->preg)); break;
				}
				if (ap2)
					ReleaseTempReg(ap2);
				if (ap1)
					ReleaseTempReg(ap1);
			}
*/
		}
		else {
			ap2 = nullptr;
			if (ep->p[2]==nullptr)
				break;
			ap1 = GenerateExpression(ep->p[2],am_reg,thead->tp->size,1);
			if (ap1->mode==am_imm) {
				ap2 = GetTempRegister();
				GenerateLoadConst(ap2, ap1);
			}
			else {
				ap2 = ap1;
				ap1 = nullptr;
			}
			if (base->offset)
				offset2 = base->offset->i + offset;
			else
				offset2 = offset;
			switch(thead->tp->size)
			{
			case 1:	GenerateDiadic(op_stb,0,ap2,MakeIndexed(offset,base->preg)); break;
			case 2:	GenerateDiadic(op_stw,0,ap2,MakeIndexed(offset,base->preg)); break;
			case 4:	GenerateDiadic(op_stt,0,ap2,MakeIndexed(offset,base->preg)); break;
			case 8:	GenerateDiadic(op_sto, 0, ap2, MakeIndexed(offset, base->preg)); break;
			case 64:	GenerateDiadic(op_sv,0,ap2,MakeIndexed(offset,base->preg)); break;
			default:	GenerateDiadic(op_sto,0,ap2,MakeIndexed(offset,base->preg)); break;
			}
			if (ap2)
				ReleaseTempReg(ap2);
			if (ap1)
				ReleaseTempReg(ap1);
		}
		if (!thead->tp->IsUnion())
			offset += thead->tp->size;
		thead = Symbol::GetPtr(thead->next);
		ep = ep->p[2];
	}
	if (!thead && ep)
		error(ERR_TOOMANYELEMENTS);
}


OCODE* CodeGenerator::GenerateLoadFloatConst(Operand* ap1, Operand* ap2)
{
	float f;
	double d, * pd;
	int32_t* pi;
	float* pf = &f;
	int32_t i;
	OCODE* ip = currentFn->pl.tail;

	pi = (int32_t*)pf;
	i = *pi;
	Float128 f128;
	uint16_t h;

	Float128::FloatQuadToHalf(&h, &ap1->offset->f128);
	Float128::Float128ToSingle(&f, &ap1->offset->f128);
	GenerateTriadic(op_orf, 0, ap2, makereg(regZero), MakeImmediate(h));
	if (ap1->offset->f128.IsHalf())
		;
	else if (ap1->offset->f128.IsSingle())
		GenerateMonadic(op_pfx0, 0, MakeImmediate(i));
	else {
		int64_t i;
		int64_t* pi;

		pi = (int64_t*)&d;
		i = *pi;
		if (ap1->offset->f128.IsDouble()) {
			Float128::Float128ToDouble(&d, &ap1->offset->f128);
			GenerateMonadic(op_pfx0, 0, MakeImmediate(0xffffffffLL & i));
			GenerateMonadic(op_pfx1, 0, MakeImmediate((i >> 32LL) & 0xffffffffLL));
		}
		else {
			Float128::Assign(&f128, &ap1->offset->f128);
			f128.Pack(128);
			GenerateMonadic(op_pfx0, 0, MakeImmediate(f128.pack[0]));
			GenerateMonadic(op_pfx1, 0, MakeImmediate(f128.pack[1]));
			GenerateMonadic(op_pfx2, 0, MakeImmediate(f128.pack[2]));
			GenerateMonadic(op_pfx2, 0, MakeImmediate(f128.pack[3]));
		}
	}
	return (ip->fwd);
}

// Generate an assignment to an array.
void CodeGenerator::GenerateLoadConst(Operand *ap1, Operand *ap2)
{
	Operand *ap3;

	if (ap1->isPtr) {
		ap3 = ap1->Clone();
		ap3->mode = am_direct;
		GenerateDiadic(cpu.lea_op, 0, ap2, ap3);
		//if (!compiler.os_code) {
		//	switch (ap1->segment) {
		//	case tlsseg:		GenerateTriadic(op_base, 0, ap2, ap2, MakeImmediate(8));	break;
		//	case rodataseg:	GenerateTriadic(op_base, 0, ap2, ap2, MakeImmediate(12));	break;
		//	}
		//}
	}
	else {
		OCODE* ip;
		if (ap1->offset == nullptr)
			;
//		if (ap1->offset->esize <= 8)
//			ip = GenerateDiadic(cpu.ldi_op, 0, ap2, MakeImmediate(ap1->offset->i));
//		else 
		 {
			// Try to compress a float into the smallest representation.
			if (ap1->tp->IsFloatType())
				ip = GenerateLoadFloatConst(ap1, ap2);
			else {
				ip = GenerateDiadic(cpu.ldi_op, 0, ap2, MakeImmediate(ap1->offset->i128.low & 0xffffLL));
				if (!ap1->offset->i128.IsNBit(16))
					GenerateMonadic(op_pfx0, 0, MakeImmediate(ap1->offset->i128.low & 0xfffffffffLL));
				if (!ap1->offset->i128.IsNBit(32))
					GenerateMonadic(op_pfx1, 0, MakeImmediate(ap1->offset->i128.low >> 32LL));
				if (!ap1->offset->i128.IsNBit(64))
					GenerateMonadic(op_pfx2, 0, MakeImmediate(ap1->offset->i128.high & 0xffffffffLL));
				if (!ap1->offset->i128.IsNBit(96))
					GenerateMonadic(op_pfx3, 0, MakeImmediate(ap1->offset->i128.high >> 32LL));
			}
		}
		if (ip->oper2)
			if (ip->oper2->offset)
				ip->oper2->offset->constflag = true;
		regs[ap2->preg].isConst = true;
			if (ap2->tp) {
//				ap2->tp->type = bt_long;
//				ap2->tp->size = 16;
			}
	}
	// ap2 inherits type from ap1
//	ap2->tp = ap1->tp;
	regs[ap2->preg].offset = ap1->offset;
}

void CodeGenerator::GenerateArrayAssign(TYP *tp, ENODE *node1, ENODE *node2, Operand *base)
{
	ENODE *ep1;
	Operand *ap1, *ap2;
	int size = tp->size;
	int64_t offset, offset2;

	offset = 0;
	if (node1->tp)
		tp = node1->tp->btpp;
	else
		tp = nullptr;
	if (tp==nullptr)
		tp = &stdlong;
	if (tp->IsStructType()) {
		ep1 = nullptr;
		ep1 = node2->p[0];
		while (ep1 && offset < size) {
			GenerateStructAssign(tp, offset, ep1->p[2], base);
			if (!tp->IsUnion())
				offset += tp->size;
			ep1 = ep1->p[2];
		}
	}
	else if (tp->IsAggregateType()){
		GenerateAggregateAssign(node1->p[0],node2->p[0]);
	}
	else {
		ep1 = node2->p[0];
		offset = 0;
		if (base->offset)
			offset = base->offset->i;
		ep1 = ep1->p[2];
		while (ep1) {
			ap1 = GenerateExpression(ep1,am_reg|am_imm,sizeOfWord,1);
			ap2 = GetTempRegister();
			if (ap1->mode == am_imm)
				GenerateLoadConst(ap1, ap2);
			else {
				if (ap1->offset)
					offset2 = ap1->offset->i;
				else
					offset2 = 0;
				GenerateMove(ap2,ap1);
			}
			switch(tp->GetElementSize())
			{
			case 1:	GenerateDiadic(op_stb,0,ap2,MakeIndexed(offset,base->preg)); break;
			case 2:	GenerateDiadic(op_stw,0,ap2,MakeIndexed(offset,base->preg)); break;
			case 4:	GenerateDiadic(op_stt,0,ap2,MakeIndexed(offset,base->preg)); break;
			case 8:	GenerateDiadic(op_sto, 0, ap2, MakeIndexed(offset, base->preg)); break;
			case 64:	GenerateDiadic(op_sv,0,ap2,MakeIndexed(offset,base->preg)); break;
			default:	GenerateDiadic(op_sto,0,ap2,MakeIndexed(offset,base->preg)); break;
			}
			offset += tp->GetElementSize();
			ReleaseTempReg(ap2);
			ReleaseTempReg(ap1);
			ep1 = ep1->p[2];
		}
	}
}

Operand *CodeGenerator::GenerateAggregateAssign(ENODE *node1, ENODE *node2)
{
	Operand *base, *base2;
	TYP *tp;
	int64_t offset = 0;

	if (node1==nullptr || node2==nullptr)
		return nullptr;
	//DumpStructEnodes(node2);
	base = GenerateExpression(node1,am_reg,sizeOfWord,0);
	base2 = GenerateExpression(node2, am_reg, sizeOfWord,1);
	GenerateMove(makereg(cpu.argregs[0]), base);
	GenerateMove(makereg(cpu.argregs[1]), base2);
	GenerateLoadConst(MakeImmediate(node2->esize), makereg(cpu.argregs[2]));
//	GenerateDiadic(op_ldi, 0, makereg(regFirstArg + 2), MakeImmediate(node1->esize));
#ifdef RISCV
		GenerateMonadic(op_call, 0, MakeStringAsNameConst((char *)"__aacpy", codeseg));
#endif
#ifdef THOR
	GenerateDiadic(op_jsr, 0, makereg(regLR), MakeStringAsNameConst((char *)"__aacpy",codeseg));
#endif
	ReleaseTempReg(base2);
	currentFn->IsLeaf = false;
	return (base);
	//base = GenerateDereference(node1,am_mem,sizeOfWord,0);
	tp = node1->tp;
	if (tp==nullptr)
		tp = &stdlong;
	if (tp->IsStructType()) {
		if (base->offset)
			offset = base->offset->i;
		else
			offset = 0;
		GenerateStructAssign(tp,offset,node2->p[0],base);
		//GenerateStructAssign(tp,offset2,node2->p[0]->p[0],base);
	}
	// Process Array
	else {
		GenerateArrayAssign(tp, node1, node2, base);
	}
	return base;
}

Operand* CodeGenerator::GenerateBigAssign(Operand* ap1, Operand* ap2, int size, int ssize)
{
	Operand* ap3;

	if (ap1->typep == &stdvector && (ap2->typep == &stdvector || ap2->mode == am_vreg)) {
		if (ap2->mode == am_vreg)
			GenerateStore(ap2, ap1, ssize);
		else {
			ap3 = GetTempVectorRegister();
			GenerateLoad(ap3, ap2, ssize, ssize);
			GenerateStore(ap3, ap1, ssize);
			ReleaseTempRegister(ap3);
		}
	}
	else {
		GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(3 * sizeOfWord));
		ap3 = GetTempRegister();
		GenerateDiadic(cpu.ldi_op, 0, ap3, MakeImmediate(size));
		GenerateDiadic(cpu.sto_op, 0, ap3, MakeIndexed(2 * sizeOfWord, regSP));
		if (ap2->mode != am_reg) {
			GenerateLoad(ap3, ap2, ssize, ssize);
			GenerateDiadic(cpu.sto_op, 0, ap3, MakeIndexed(1 * sizeOfWord, regSP));
		}
		else
			GenerateDiadic(cpu.sto_op, 0, ap2, MakeIndexed(1 * sizeOfWord, regSP));
		if (ap1->mode != am_reg) {
			GenerateLoad(ap3, ap1, ssize, ssize);
			GenerateDiadic(cpu.sto_op, 0, ap3, MakeIndirect(regSP));
		}
		else
			GenerateDiadic(cpu.sto_op, 0, ap1, MakeIndirect(regSP));
		GenerateCall(MakeStringAsNameConst((char*)"_aacpy", codeseg));
	}
	return (ap1);
}

Operand* CodeGenerator::GenerateImmToMemAssign(Operand* ap1, Operand* ap2, int ssize)
{
	Operand* ap3;

	if (ap2->tp->IsFloatType()) {
		if (Float128::IsEqual(&ap2->offset->f128, Float128::Zero())) {
			GenerateStore(makereg(regZero), ap1, ssize);
			return (ap1);
		}
		ap3 = GetTempRegister();
		GenerateLoadFloatConst(ap2,ap3);
		GenerateStore(ap3, ap1, ssize);
		ReleaseTempRegister(ap3);
		return (ap1);
	}
	if (ap2->offset->i == 0 && ap2->offset->nodetype != en_labcon) {
		GenerateStore(makereg(regZero), ap1, ssize);
	}
	else {
		//if (ap2->offset->nodetype == en_icon && ap2->offset->i >= -32 && ap2->offset->i < 32) {
		//	GenerateStore(ap2, ap1, ssize);
		//}
		//else
		if (ap2->offset->nodetype == en_icon && ap2->offset->i == 0)
			GenerateStore(makereg(regZero), ap1, ssize);
		else
		{
			ap3 = GetTempRegister();
			GenerateLoadConst(ap2, ap3);
			GenerateStore(ap3, ap1, ssize);
			ReleaseTempReg(ap3);
		}
	}
	return (ap1);
}

Operand* CodeGenerator::GenerateRegToMemAssign(Operand* ap1, Operand* ap2, int ssize)
{
	GenerateStore(ap2, ap1, ssize);
	return (ap1);
}

Operand* CodeGenerator::GenerateRegToRegAssign(ENODE* node, Operand* ap1, Operand* ap2, int ssize)
{
	Operand* ap3;

	GenerateHint(2);
	if (node->p[0]->IsRefType() && node->p[1]->IsRefType()) {
		ap3 = GetTempRegister();
		GenerateLoad(ap3, MakeIndirect(ap2->preg), ssize, node->p[1]->GetReferenceSize());
		GenerateStore(ap3, MakeIndirect(ap1->preg), ssize);
		ReleaseTempRegister(ap3);
	}
	else if (node->p[1]->IsRefType()) {
		ap3 = GetTempRegister();
		GenerateLoad(ap3, MakeIndirect(ap2->preg), ssize, node->p[1]->GetReferenceSize());
		GenerateMove(ap1, ap3);
		ReleaseTempRegister(ap3);
		//GenerateZeradic(op_setwb);
		ap1->isPtr = TRUE;
	}
	else if (node->p[0]->IsRefType()) {
		GenerateStore(ap2, MakeIndirect(ap1->preg), ssize);
	}
	else {
		GenerateMove(ap1, ap2);
	}
	return (ap1);
}

Operand* CodeGenerator::GenerateVregToVregAssign(ENODE* node, Operand* ap1, Operand* ap2, int ssize)
{
	Operand* ap3, *mask;

	GenerateHint(2);
	mask = nullptr;
	if (node->mask)
		mask = GenerateExpression(node->vmask, am_reg, sizeOfWord, 0);
	if (node->p[0]->IsRefType() && node->p[1]->IsRefType()) {
		ap3 = GetTempVectorRegister();
		GenerateLoad(ap3, MakeIndirect(ap2->preg), ssize, node->p[1]->GetReferenceSize(), mask);
		GenerateStore(ap3, MakeIndirect(ap1->preg), ssize, mask);
		ReleaseTempRegister(ap3);
	}
	else if (node->p[1]->IsRefType()) {
		ap3 = GetTempVectorRegister();
		GenerateLoad(ap3, MakeIndirect(ap2->preg), ssize, node->p[1]->GetReferenceSize(), mask);
		GenerateMove(ap1, ap3, mask);
		ReleaseTempRegister(ap3);
		//GenerateZeradic(op_setwb);
		ap1->isPtr = TRUE;
	}
	else if (node->p[0]->IsRefType()) {
		GenerateStore(ap2, MakeIndirect(ap1->preg), ssize, mask);
	}
	else {
		GenerateMove(ap1, ap2, mask);
	}
	ReleaseTempRegister(mask);
	return (ap1);
}

Operand* CodeGenerator::GenerateImmToRegAssign(Operand* ap1, Operand* ap2, int ssize)
{
	Operand* ap3;

	//if (ap2->isPtr)
//	GenerateZeradic(op_setwb);
	GenerateLoadConst(ap2, ap1);
	ap1->isPtr = ap2->isPtr;
	return (ap1);
}


Operand* CodeGenerator::GenerateMemToRegAssign(Operand* ap1, Operand* ap2, int size, int ssize)
{
	Operand* ap3;

	if (ap1->isPtr) {
		ap3 = GetTempRegister();
		GenerateLoad(ap3, ap2, ssize, size);
		GenerateStore(ap3, MakeIndirect(ap1->preg), ssize);
	}
	else {
		//if (ap1->preg >= 0x20 && ap1->preg <= 0x3f)
		//	ap1->mode = am_fpreg;
		GenerateLoad(ap1, ap2, ssize, size);
	}
	ap1->isPtr = ap2->isPtr;
	return (ap1);
}


// ----------------------------------------------------------------------------
// Generate code for an assignment node. If the size of the assignment
// destination is larger than the size passed then everything below this node
// will be evaluated with the assignment size.
// ----------------------------------------------------------------------------
Operand *CodeGenerator::GenerateAssign(ENODE *node, int flags, int64_t size)
{
	Operand *ap1, *ap2 ,*ap3, *ap4, *ap5;
	TYP *tp;
    int ssize;
		int RHsize;
		MachineReg *mr;
		int flg;
		OCODE* ip;

    Enter((char *)"GenAssign");

    if (node->p[0]->IsBitfield()) {
      Leave((char *)"GenAssign",0);
		return (node->GenerateBitfieldAssign(flags|am_bf_assign, size));
    }

	ssize = node->p[0]->GetReferenceSize();
//	if( ssize > size )
//			size = ssize;
/*
    if (node->tp->type==bt_struct || node->tp->type==bt_union) {
		ap1 = GenerateExpression(node->p[0],am_reg,ssize);
		ap2 = GenerateExpression(node->p[1],am_reg,size);
		GenerateMonadic(op_push,0,MakeImmediate(node->tp->size));
		GenerateMonadic(op_push,0,ap2);
		GenerateMonadic(op_push,0,ap1);
		GenerateMonadic(op_bsr,0,MakeStringAsNameConst("memcpy_"));
		GenerateTriadic(op_addui,0,makereg(regSP),makereg(regSP),MakeImmediate(24));
		ReleaseTempReg(ap2);
		return ap1;
    }
*/
	tp = node->p[0]->tp;
	if (tp) {
		if (tp->size > sizeOfWord) {
			if (node->p[0]->tp->IsAggregateType() || node->p[1]->nodetype == en_list || node->p[1]->nodetype == en_end_aggregate)
				return GenerateAggregateAssign(node->p[0], node->p[1]);
		}
	}
	//if (size > 8) {
	//	ap1 = GenerateExpression(node->p[0],am_mem,ssize);
	//	ap2 = GenerateExpression(node->p[1],am_mem,size);
	//}
	//else {
		ap1 = GenerateExpression(node->p[0], am_reg | am_mem | am_vreg, ssize, 1);
		flg = am_all;
		flg = am_reg | am_mem | am_imm | am_vreg;
		/*
		if (ap1->typep == &stddouble)
			flg = am_fpreg;
		else 
		if (ap1->typep == &stdposit)
			flg = am_preg;
		*/

		// We want the size of the RHS to be its natural size.
		ap2 = GenerateExpression(node->p[1], flg, RHsize = node->p[1]->GetNaturalSize(), 0);// size);
		//if (node->p[0]->isUnsigned && !node->p[1]->isUnsigned)
		//    ap2->GenZeroExtend(RHsize,ssize);
		// Supposed to be handled in parse
		//if (RHsize != ssize)
		//	forcefit(&(node->p[1]), ap1->tp, &(node->p[0]), ap2->tp, true, true);
//	}
	if (ap1->mode == am_reg) {
		if (ap1->preg == regZero)
			printf("hello");
		mr = &regs[ap1->preg];
		if (mr->assigned)
			mr->modified = true;
		mr->assigned = true;
		switch(ap2->mode) {

		case am_reg:
			ap1 = GenerateRegToRegAssign(node, ap1, ap2, ssize);
			mr->val = regs[ap2->preg].val;
			mr->val128 = regs[ap2->preg].val128;
			mr->isConst = ap2->isConst;
			break;

		case am_imm:
			ap1 = GenerateImmToRegAssign(ap1, ap2, ssize);
			if (ap2->tp->IsPositType())
				mr->val = ap2->offset->posit.val;
			else if (ap2->tp->IsFloatType())
				mr->val = ap2->offset->f;
			else {
				mr->val = ap2->offset->i;
				mr->val128 = ap2->offset->i128;
			}
			mr->offset = ap2->offset;
			mr->isConst = true;
			break;

		default:
			ap1 = GenerateMemToRegAssign(ap1, ap2, node->p[1]->GetReferenceSize(), ssize);
			mr->modified = true;
			break;
		}
	}
	else if (ap1->mode == am_vreg) {
		mr = &vregs[ap1->preg];
		if (ap2->mode==am_vreg) {
			ap1 = GenerateVregToVregAssign(node, ap1, ap2, ssize);
			mr->val = vregs[ap2->preg].val;
			mr->val128 = vregs[ap2->preg].val128;
			mr->isConst = ap2->isConst;
		}
		else
			GenerateLoad(ap1,ap2,ssize,size);
	}
	// ap1 is memory
	else {
		if (ap2->mode == am_reg) {
			ap1 = GenerateRegToMemAssign(ap1, ap2, ssize);
    }
		else if (ap2->mode == am_imm) {
			ap1 = GenerateImmToMemAssign(ap1, ap2, ssize);
		}
		else {
			// Generate a memory to memory move? (struct assignments)
			if (ssize > sizeOfWord)
				ap1 = GenerateBigAssign(ap1, ap2, size, ssize);
			else {
				Operand* ap4;
				ap3 = GetTempRegister();
				ap3->tp = ap1->tp;
				ap3->isPtr = ap2->isPtr;
				GenerateLoad(ap3, ap2, ssize, size);
//				GenLoad(ap3,ap2, node->p[0]->GetReferenceSize(),node->p[1]->GetReferenceSize());
				//if (ap1->isPtr) {
				//	ap4 = GetTempRegister();
				//	GenerateLoad(ap4, ap1, ssize, size);
				//	GenerateStore(ap3, ap4, ssize);
				//	ReleaseTempRegister(ap4);
				//}
				//else
					GenerateStore(ap3,ap1,ssize);
				ReleaseTempRegister(ap3);
			}
		}
	}
/*
	if (ap1->mode == am_reg) {
		if (ap2->mode==am_imm)	// must be zero
			GenerateDiadic(op_mov,0,ap1,makereg(0));
		else
			GenerateDiadic(op_mov,0,ap1,ap2);
	}
	else {
		if (ap2->mode==am_imm)
		switch(size) {
		case 1:	GenerateDiadic(op_stb,0,makereg(0),ap1); break;
		case 2:	GenerateDiadic(op_stw,0,makereg(0),ap1); break;
		case 4: GenerateDiadic(op_stp,0,makereg(0),ap1); break;
		case 8:	GenerateDiadic(op_std,0,makereg(0),ap1); break;
		}
		else
		switch(size) {
		case 1:	GenerateDiadic(op_stb,0,ap2,ap1); break;
		case 2:	GenerateDiadic(op_stw,0,ap2,ap1); break;
		case 4: GenerateDiadic(op_stp,0,ap2,ap1); break;
		case 8:	GenerateDiadic(op_std,0,ap2,ap1); break;
		// Do structure assignment
		default: {
			ap3 = GetTempRegister();
			GenerateDiadic(op_ldi,0,ap3,MakeImmediate(size));
			GenerateTriadic(op_push,0,ap3,ap2,ap1);
			GenerateDiadic(op_jal,0,makereg(LR),MakeStringAsNameConst("memcpy"));
			GenerateTriadic(op_addui,0,makereg(SP),makereg(SP),MakeImmediate(24));
			ReleaseTempRegister(ap3);
		}
		}
	}
*/
	ReleaseTempReg(ap2);
    ap1->MakeLegal(flags,size);
    Leave((char *)"GenAssign",1);
	return (ap1);
}

// autocon and autofcon nodes

Operand *CodeGenerator::GenerateAutocon(ENODE *node, int flags, int64_t size, TYP* typ)
{
	Operand *ap1, *ap2, *ap3;
	short nn, ni;

	// We always want an address register (GPR) for lea
	ap1 = GetTempRegister();
	ap2 = allocOperand();
	ap2->isPtr = node->etype == bt_pointer;
	ap2->mode = am_indx;
	ap2->preg = regFP;          // frame pointer
	ap2->offset = node;     /* use as constant node */
	ap2->bit_offset = node->bit_offset;
	ap2->bit_width = node->bit_width;
	DataLabels[ap2->offset->i]++;
//	ap2->type = type;
	ap2->tp = node->tp;
//	ap1->type = &stdint;
	ap1->typep = typ;
	ap1->tp = node->tp;
	ni = nn = node->sym->depth - currentFn->depth;
	if (nn > 0) {
		ap3 = GetTempRegister();
		if (nn == 1)
			GenerateLoad(ap3, MakeIndirect(regFP), size, size);
		else
			GenerateLoad(ap3, MakeIndirect(regFP), sizeOfWord, sizeOfWord);	
		for (--nn; nn > 0; nn--) {
			if (nn == 1)
				GenerateLoad(ap3, MakeIndirect(ap3->preg), size, size);
			else
				GenerateLoad(ap3, MakeIndirect(ap3->preg), sizeOfWord, sizeOfWord);
		}
		ReleaseTempRegister(ap3);
		ap3->isPtr = node->etype == bt_pointer;
		ap3->mode = am_indx;
		ap3->preg = regFP;          // frame pointer
		ap3->offset = node;     /* use as constant node */
		ap3->bit_offset = node->bit_offset;
		ap3->bit_width = node->bit_width;
		//	ap2->type = type;
		ap3->tp = node->tp;
		GenerateDiadic(cpu.lea_op, 0, ap1, ap3);
	}
	else
		GenerateDiadic(cpu.lea_op,0,ap1,ap2);
	//if (!compiler.os_code)
	//	GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(10));
	ap1->MakeLegal(flags,size);
	return (ap1);             /* return reg */
}

Operand* CodeGenerator::GenerateFloatcon(ENODE* node, int flags, int64_t size)
{
	Operand* ap1, * ap2;

#ifdef THOR
	ap1 = allocOperand();
	ap1->mode = am_imm;
	ap1->offset = node;
	ap1->tp = node->tp;
	return (ap1);
#endif
#ifdef RISCV
	// Code for generating a reference to the constant which is 
	// stored in rodata. This is not needed by Thor since Thor can use immediates
	// with floats, but some other architectures cannot.
	ap1 = allocOperand();
	ap1->isPtr = node->IsPtr();
	if (node->constflag && node->f128.IsZero()) {
		ap1->mode = am_reg;
		ap1->isConst = true;
		ap1->preg = regZero;
	}
	else {
		if (use_gp) {
			ap1->mode = am_indx;
			ap1->preg = node->segment == rodataseg ? regGP1 : regGP;
		}
		else
			ap1->mode = am_direct;
		ap1->offset = node;
		if (node)
			DataLabels[node->i]++;
	}
	ap1->typep = &stddouble;
	if (node)
		ap1->tp = node->tp;
	// Don't allow the constant to be loaded into an integer register.
	ap1->MakeLegal(flags, size);
	return (ap1);
#endif
}

Operand* CodeGenerator::GenPositcon(ENODE* node, int flags, int64_t size)
{
	Operand* ap1, * ap2;

	ap1 = allocOperand();
	ap1->isPtr = node->IsPtr();
	if (use_gp) {
		ap1->mode = am_indx;
		ap1->preg = node->segment == rodataseg ? regGP1 : regGP;
	}
	else
		ap1->mode = am_direct;
	ap1->offset = node;
	if (node)
		DataLabels[node->i]++;
	ap1->typep = &stdposit;
	if (node)
		ap1->tp = node->tp;
	// Don't allow the constant to be loaded into an integer register.
	ap1->MakeLegal(flags & ~am_reg, size);
	return (ap1);
}

Operand* CodeGenerator::GenLabelcon(ENODE* node, int flags, int64_t size)
{
	Operand* ap1, * ap2;

	if (use_gp) {
		ap1 = GetTempRegister();
		ap2 = allocOperand();
		ap2->mode = am_indx;
		switch (node->segment) {
		case tlsseg:	ap2->preg = regTP; break;
		case dataseg:	ap2->preg = regGP; break;
		case rodataseg: ap2->preg = regGP1; break;
		default:	ap2->preg = regPP;
		}
		ap2->offset = node;     // use as constant node
		GenerateLoadAddress(ap1, ap2);
		//if (!compiler.os_code) {
		//	switch (node->segment) {
		//	case tlsseg:		GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(8));	break;
		//	case rodataseg:	GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(12));	break;
		//	}
		//}
		ap1->MakeLegal(flags, size);
		return (ap1);
	}
	ap1 = allocOperand();
	ap1->isPtr = node->IsPtr();
	ap1->mode = am_imm;
	ap1->offset = node;
	ap1->isUnsigned = node->isUnsigned;
	ap1->tp = node->tp;
	ap1->MakeLegal(flags, size);
}

//
// General expression evaluation. returns the addressing mode
// of the result.
//
Operand *CodeGenerator::GenerateExpression(ENODE *node, int flags, int64_t size, int rhs)
{   
	Operand *ap1, *ap2, *ap3;
  int natsize, siz1;
	int lab0, lab1;
	static char buf[4][20];
	static int ndx;
	static int numDiags = 0;
	OCODE* ip;
	int ndxreg;
	ENODE* n2, * n3;
	size_t tpsz;
	Symbol* sym;
	char nmbuf[200];

  Enter((char *)"<GenerateExpression>"); 
  if( node == (ENODE *)NULL )
  {
		throw new C64PException(ERR_NULLPOINTER, 'G');
		numDiags++;
        printf("DIAG - null node in GenerateExpression.\n");
		if (numDiags > 100)
			exit(0);
        Leave((char *)"</GenerateExpression>",2); 
        return (Operand *)NULL;
    }
	//size = node->esize;
  switch( node->nodetype )
  {
	case en_aggregate:
	case en_end_aggregate:
		if (pass == 1) {
			sym = Symbol::alloc();
			sprintf_s(nmbuf, sizeof(nmbuf), "__aggregate_tag", sym->acnt);
			sym->tp = node->tp;
			sym->storage_class = sc_global;
			node->AssignTypeToList(sym->tp);
			ofs.puts("\n");
			put_label(ofs, sym->acnt, nmbuf, GetNamespace(), 'D', sym->tp->size);
			sprintf_s(nmbuf, sizeof(nmbuf), "__aggregate_tag_%d", sym->acnt);
			sym->SetName(std::string((char*)nmbuf));
			sym->Initialize(ofs, node, sym->tp, 1);
			ofs.puts("\n\n");
			node->sp = sym->name;
		}
//		GenerateReference(sym, 0);
		ap1 = GetTempRegister();
		GenerateLoadAddress(ap1, MakeStringAsNameConst((char *)node->sp->c_str(), rodataseg));
		ap1->isPtr = true;
		sym->acnt++;
		/*
		ap2 = allocOperand();
		ap2->mode = am_reg;
		ap2->preg = ap1->preg;
		if (node->tp->IsScalar())
			GenerateLoad(ap1, ap2, size, size);
		else
			ap1->isPtr = true;
		*/
		goto retpt;
		//ap1 = allocOperand();
		//ap1->offset = node;
		//ap1->type = 9999;
		goto retpt;
	
	case en_fcon:
		ap1 = GenerateFloatcon(node, flags, size);
		goto retpt;
/*
	case en_pcon:
		ap1 = GenPositcon(node, flags, size);
		goto retpt;
*/
	case en_pcon:
		ap1 = allocOperand();
		ap1->mode = am_imm;
		ap1->offset = node;
		ap1->offset->i = ap1->offset->posit.val;
		ap1->tp = node->tp;
		Leave((char *)"GenExpression", 3);
		goto retpt;
	case en_icon:
    ap1 = allocOperand();
    ap1->mode = am_imm;
    ap1->offset = node;
		ap1->tp = node->tp;
		Leave((char *)"GenExpression",3);
		goto retpt;

	case en_pfx0:
		ap1 = allocOperand();
		ap1->mode = am_imm;
		ap1->offset = node;
		ap1->tp = node->tp;
		GenerateMonadic(op_pfx0, 0, ap1);
		goto retpt2;
	case en_pfx1:
		ap1 = allocOperand();
		ap1->mode = am_imm;
		ap1->offset = node;
		ap1->tp = node->tp;
		GenerateMonadic(op_pfx1, 0, ap1);
		goto retpt2;
	case en_pfx2:
		ap1 = allocOperand();
		ap1->mode = am_imm;
		ap1->offset = node;
		ap1->tp = node->tp;
		GenerateMonadic(op_pfx2, 0, ap1);
		goto retpt2;
	case en_pfx3:
		ap1 = allocOperand();
		ap1->mode = am_imm;
		ap1->offset = node;
		ap1->tp = node->tp;
		GenerateMonadic(op_pfx3, 0, ap1);
		goto retpt2;

	case en_labcon:
		ap1 = GenLabelcon(node, flags, size);
		goto retpt;

  case en_nacon:
    if (use_gp) {
      ap1 = GetTempRegister();
      ap2 = allocOperand();
      ap2->mode = am_indx;
      ap2->preg = node->segment==rodataseg ? regGP1 : regGP;      // global pointer
			//if (node->segment != rodataseg) {
			//	n2 = makeinode(en_icon, 2048LL);
			//	ap2->offset = makenode(en_add, ap2->offset, n2);
			//}
			//else
	      ap2->offset = node;     // use as constant node
			if (node)
				DataLabels[node->i]++;
      GenerateDiadic(cpu.lea_op,0,ap1,ap2);
			//if (!compiler.os_code) {
			//	switch (node->segment) {
			//	case tlsseg:		GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(8));	break;
			//	case rodataseg:	GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(12));	break;
			//	}
			//}
			ap1->MakeLegal(flags,size);
			Leave((char *)"GenExpression",6); 
			goto retpt;
		}
    // fallthru
	case en_cnacon:
      ap1 = allocOperand();
			ap1->isPtr = node->IsPtr();
			ap1->mode = am_imm;
      ap1->offset = node;
			if (node->i==0)
				node->i = -1;
			ap1->isUnsigned = node->isUnsigned;
            ap1->MakeLegal(flags,size);
			Leave((char *)"GenExpression",7); 
			goto retpt;
	case en_clabcon:
    ap1 = allocOperand();
    ap1->mode = am_imm;
    ap1->offset = node;
		ap1->isUnsigned = node->isUnsigned;
    ap1->MakeLegal(flags,size);
		Leave((char *)"GenExpression",7); 
		goto retpt;
	case en_autocon:
		ap1 = GenerateAutocon(node, flags, size, &stdint);
		goto retpt;
  case en_autofcon:	
		switch (node->tp->type)
		{
		case bt_float:
			ap1 = GenerateAutocon(node, flags, size, &stdflt);
			goto retpt;
		case bt_double:
			ap1 = GenerateAutocon(node, flags, size, &stddouble);
			goto retpt;
		case bt_quad:	return GenerateAutocon(node, flags, size, &stdquad);
		case bt_posit: return GenerateAutocon(node, flags, size, &stdposit);
		case bt_pointer:
			ap1 = GenerateAutocon(node, flags, size, &stdint);
			goto retpt;
		}
		break;

	case en_autopcon:
		switch (node->tp->type)
		{
		case bt_float:
			ap1 = GenerateAutocon(node, flags, size, &stdflt);
			goto retpt;
		case bt_double:
			ap1 = GenerateAutocon(node, flags, size, &stddouble);
			goto retpt;
		case bt_quad:	return GenerateAutocon(node, flags, size, &stdquad);
		case bt_posit: return GenerateAutocon(node, flags, size, &stdposit);
		case bt_pointer:
			ap1 = GenerateAutocon(node, flags, size, &stdint);
			goto retpt;
		}
		break;

	case en_autovcon:	return GenerateAutocon(node, flags, size, &stdvector);
    case en_autovmcon:	return GenerateAutocon(node, flags, size, &stdvectormask);
  case en_classcon:
    ap1 = GetTempRegister();
    ap2 = allocOperand();
    ap2->mode = am_indx;
    ap2->preg = regCLP;     /* frame pointer */
    ap2->offset = node;     /* use as constant node */
		GenerateLea(ap1, ap2);
		goto retpt;
	case en_addrof:
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0], flags, sizeOfPtr, rhs);
		GenerateLea(ap1, ap2);
		ReleaseTempReg(ap2);
		goto retpt;
  case en_ref:
		if (node->tp == nullptr)
			tpsz = sizeOfWord;
		else
			tpsz = node->tp->size;
		ap1 = GenerateDereference(node, flags, tpsz, !node->isUnsigned, (flags & am_bf_assign) ? 0 : 1, rhs);
		if (ap1 == nullptr)
			return (nullptr);
		ap1->isPtr = TRUE;
		ap1->rhs = rhs;
		goto retpt;
	case en_fieldref:
		ap1 = (flags & am_bf_assign) ? GenerateDereference(node,flags & ~am_bf_assign,node->tp->size,!node->isUnsigned, (flags & am_bf_assign) != 0, rhs)
			: GenerateBitfieldDereference(node, flags, node->tp->size, (flags & am_bf_assign) != 0);//!node->isUnsigned);
		goto retpt;
	case en_regvar:
    ap1 = allocOperand();
		ap1->isPtr = node->IsPtr();
		ap1->tp = node->tp;
    ap1->mode = am_reg;
    ap1->preg = node->rg;
    ap1->tempflag = 0;      /* not a temporary */
    ap1->MakeLegal(flags,size);
		ap1->tp = node->tp;
		goto retpt;

	case en_type:
		if (node->tp)
			tpsz = node->tp->size;
		else
			tpsz = sizeOfWord;
		ap1 = GenerateDereference(node, flags & ~am_bf_assign, tpsz, !node->isUnsigned, (flags & am_bf_assign) != 0, rhs);
		ap1->isPtr = true;
		goto retpt;

	// ToDo: dereference tempref nodes
	case en_tempfpref:
		ap1 = allocOperand();
		ap1->isPtr = node->IsPtr();
		ap1->mode = node->IsPtr() ? am_reg : am_reg;
		ap1->preg = node->rg;
		ap1->tempflag = 0;      /* not a temporary */
		if (node->tp)
			switch (node->tp->type) {
			case bt_float:	ap1->typep = &stdflt; break;
			case bt_double:	ap1->typep = &stddouble; break;
			case bt_quad:	ap1->typep = &stdquad; break;
			case bt_posit: ap1->typep = &stdposit; break;
			default: ap1->typep = &stdint; break;
			}
		else
			ap1->typep = &stddouble;
		ap1->tp = node->tp;
		goto retpt;

	case en_temppref:
		ap1 = allocOperand();
		ap1->isPtr = node->IsPtr();
		ap1->mode = node->IsPtr() ? am_reg : am_preg;
		ap1->preg = node->rg;
		ap1->tempflag = 0;      /* not a temporary */
		if (node->tp)
			switch (node->tp->type) {
			case bt_posit: ap1->typep = &stdposit; break;
			default: ap1->typep = &stdint; break;
			}
		else
			ap1->typep = &stdposit;
		ap1->tp = node->tp;
		goto retpt;

	case en_fpregvar:
//    case en_fptempref:
    ap1 = allocOperand();
		ap1->isPtr = node->IsPtr();
		ap1->mode = node->IsPtr() ? am_reg : am_reg;
    ap1->preg = node->rg;
		ap1->tempflag = 0;      /* not a temporary */
		if (node->tp)
			switch (node->tp->type) {
			case bt_float:	ap1->typep = &stdflt; break;
			case bt_double:	ap1->typep = &stddouble; break;
			case bt_quad:	ap1->typep = &stdquad; break;
			case bt_posit: ap1->typep = &stdposit; break;
			default: ap1->typep = &stdint; break;
			}
		else
			ap1->typep = &stddouble;
		ap1->MakeLegal(flags,size);
		goto retpt;

	case en_pregvar:
		//    case en_fptempref:
		ap1 = allocOperand();
		ap1->isPtr = node->IsPtr();
		ap1->mode = node->IsPtr() ? am_reg : am_preg;
		ap1->preg = node->rg;
		ap1->tempflag = 0;      /* not a temporary */
		if (node->tp)
			switch (node->tp->type) {
			case bt_posit: ap1->typep = &stdposit; break;
			default: ap1->typep = &stdint; break;
			}
		else
			ap1->typep = &stdposit;
		ap1->MakeLegal(flags, size);
		goto retpt;

	case en_abs:	return node->GenerateUnary(flags,size,op_abs);
    case en_uminus: 
			ap1 = node->GenerateUnary(flags, size, op_neg);
			goto retpt;
    case en_compl:
			ap1 = node->GenerateUnary(flags,size,op_com);
			goto retpt;
	case en_not:	
		ap1 = (node->GenerateUnary(flags, sizeOfWord, op_not));
		goto retpt;
	case en_add:    ap1 = GenerateBinary(node, flags, size, op_add); goto retpt;
	case en_sub:  ap1 = GenerateBinary(node, flags, size, op_sub); goto retpt;
	case en_ptrdif:  ap1 = GenerateBinary(node, flags, size, op_ptrdif); goto retpt;
	case en_i2p:
		ap1 = GetTempFPRegister();
		ap2 = GenerateExpression(node->p[0], am_reg, 8, rhs);
		GenerateDiadic(op_itop, 0, ap1, ap2);
		ReleaseTempReg(ap2);
		goto retpt;
	case en_i2d:
    ap1 = GetTempFPRegister();	
    ap2=GenerateExpression(node->p[0],am_reg,8,rhs);
    GenerateDiadic(op_itof,' ',ap1,ap2);
    ReleaseTempReg(ap2);
		goto retpt;
  case en_i2q:
    ap1 = GetTempFPRegister();	
    ap2 = GenerateExpression(node->p[0],am_reg,8,rhs);
		//GenerateTriadic(op_csrrw,0,makereg(regZero),MakeImmediate(0x18),ap2);
		//GenerateZeradic(op_nop);
		//GenerateZeradic(op_nop);
    GenerateDiadic(op_itof,'q',ap1,makereg(63));
    ReleaseTempReg(ap2);
		goto retpt;
  case en_d2i:
    ap1 = GetTempRegister();	
    ap2 = GenerateExpression(node->p[0],am_reg,sizeOfWord,rhs);
    GenerateDiadic(op_ftoi,' ',ap1,ap2);
    ReleaseTempReg(ap2);
		goto retpt;
	case en_q2i:
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0],am_reg,sizeOfWord,rhs);
		GenerateDiadic(op_ftoi,'q',makereg(63),ap2);
		//GenerateZeradic(op_nop);
		//GenerateZeradic(op_nop);
		//GenerateTriadic(op_csrrw,0,ap1,MakeImmediate(0x18),makereg(0));
		ReleaseTempReg(ap2);
		goto retpt;
	case en_t2i:
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0],am_reg,sizeOfWord,rhs);
		GenerateDiadic(op_ftoi,'t',makereg(63),ap2);
		//GenerateZeradic(op_nop);
		//GenerateZeradic(op_nop);
		//GenerateTriadic(op_csrrw,0,ap1,MakeImmediate(0x18),makereg(0));
    ReleaseTempReg(ap2);
		goto retpt;
	case en_s2q:
		ap1 = GetTempFPRegister();
    ap2 = GenerateExpression(node->p[0],am_reg,sizeOfFPQ,rhs);
    GenerateDiadic(op_fcvtsq,0,ap1,ap2);
		ap1->typep = &stdquad;
		ReleaseTempReg(ap2);
		goto retpt;
	case en_d2q:
		ap1 = GetTempFPRegister();
		ap2 = GenerateExpression(node->p[0], am_reg, sizeOfFPQ,rhs);
		GenerateFcvtdq(ap1, ap2);
		ap1->typep = &stdquad;
		ReleaseTempReg(ap2);
		goto retpt;
	case en_t2q:
		ap1 = GetTempFPRegister();
		ap2 = GenerateExpression(node->p[0], am_reg, sizeOfFPQ,rhs);
		GenerateDiadic(op_fcvttq, 0, ap1, ap2);
		ap1->typep = &stdquad;
		ReleaseTempReg(ap2);
		goto retpt;

	case en_vadd:	  return GenerateBinary(node,flags,size,op_vadd);
	case en_vsub:	  return node->GenerateBinary(flags,size,op_vsub);
	case en_vmul:	  return node->GenerateBinary(flags,size,op_vmul);
	case en_vadds:	  return node->GenerateBinary(flags,size,op_vadds);
	case en_vsubs:	  return node->GenerateBinary(flags,size,op_vsubs);
	case en_vmuls:	  return node->GenerateBinary(flags,size,op_vmuls);
	case en_vex:      return node->GenerateBinary(flags,size,op_vex);
	case en_veins:    return node->GenerateBinary(flags,size,op_veins);

	case en_fadd:	  ap1 = node->GenerateBinary(flags, size, op_fadd); goto retpt;
	case en_fsub:	  ap1 = node->GenerateBinary(flags, size, op_fsub); goto retpt;
	case en_fmul:	  ap1 = node->GenerateBinary(flags, size, op_fmul); goto retpt;
	case en_fdiv:	  ap1 = node->GenerateBinary(flags, size, op_fdiv); goto retpt;

	case en_padd:	  ap1 = node->GenerateBinary(flags, size, op_padd); goto retpt;
	case en_psub:	  ap1 = node->GenerateBinary(flags, size, op_psub); goto retpt;
	case en_pmul:	  ap1 = node->GenerateBinary(flags, size, op_pmul); goto retpt;
	case en_pdiv:	  ap1 = node->GenerateBinary(flags, size, op_pdiv); goto retpt;

	case en_fdadd:    return node->GenerateBinary(flags,size,op_fdadd);
  case en_fdsub:    return node->GenerateBinary(flags,size,op_fdsub);
  case en_fsadd:    return node->GenerateBinary(flags,size,op_fsadd);
  case en_fssub:    return node->GenerateBinary(flags,size,op_fssub);
  case en_fdmul:    return node->GenMultiply(flags,size,op_fmul);
  case en_fsmul:    return node->GenMultiply(flags,size,op_fmul);
  case en_fddiv:    return node->GenMultiply(flags,size,op_fddiv);
  case en_fsdiv:    return node->GenMultiply(flags,size,op_fsdiv);
	case en_ftadd:    return node->GenerateBinary(flags,size,op_ftadd);
  case en_ftsub:    return node->GenerateBinary(flags,size,op_ftsub);
  case en_ftmul:    return node->GenMultiply(flags,size,op_ftmul);
  case en_ftdiv:    return node->GenMultiply(flags,size,op_ftdiv);

	case en_land:
		/*
		lab0 = nextlabel++;
		lab1 = nextlabel++;
		GenerateFalseJump(node, lab0, 0);
		ap1 = GetTempRegister();
		GenerateDiadic(op_ld, 0, ap1, MakeImmediate(1));
		GenerateMonadic(op_bra, 0, MakeDataLabel(lab1));
		GenerateLabel(lab0);
		GenerateDiadic(op_ld, 0, ap1, MakeImmediate(0));
		GenerateLabel(lab1);
		return (ap1);
		*/
		ap1 = (node->GenLand(flags, op_and, !ExpressionHasReference));
		goto retpt;
	case en_lor:
		ap1 = (node->GenLand(flags, op_or, !ExpressionHasReference));
		goto retpt;
	case en_land_safe:
		ap1 = (node->GenLand(flags, op_and, true));
		goto retpt;
	case en_lor_safe:
		ap1 = (node->GenLand(flags, op_or, true));
		goto retpt;

	case en_isnullptr:	ap1 = node->GenerateUnary(flags, size, op_isnullptr); goto retpt;
	case en_and:    ap1 = GenerateBinary(node, flags, size, op_and); goto retpt;
  case en_or:     ap1 = GenerateBinary(node,flags,size,op_or); goto retpt;
	case en_xor:	ap1 = GenerateBinary(node, flags,size,op_xor); goto retpt;
	case en_bmap:	ap1 = node->GenerateBinary(flags, size, op_bmap); goto retpt;
	case en_bytendx:	ap1 = node->GenerateBinary(flags, size, op_bytendx); goto retpt;
	case en_wydendx:	ap1 = node->GenerateBinary(flags, size, op_wydendx); goto retpt;
	case en_ext:			ap1 = GenerateTrinary(node, flags, size, op_ext); goto retpt;
	case en_extu:			ap1 = GenerateTrinary(node, flags, size, op_extu); goto retpt;
	case en_mulf:    ap1 = node->GenMultiply(flags, size, op_mulf); goto retpt;
	case en_mul:    ap1 = node->GenMultiply(flags,size,op_mul); goto retpt;
  case en_mulu:   ap1 = node->GenMultiply(flags,size,op_mulu); goto retpt;
	case en_scndx:	ap1 = node->GenerateScaledIndexing(flags, size, rhs); goto retpt;
  case en_div:    ap1 = node->GenDivMod(flags,size,op_div); goto retpt;
  case en_udiv:   ap1 = node->GenDivMod(flags,size,op_divu); goto retpt;
  case en_mod:    ap1 = node->GenDivMod(flags,size,op_rem); goto retpt;
  case en_umod:   ap1 = node->GenDivMod(flags,size,op_remu); goto retpt;
  case en_asl:    ap1 = node->GenerateShift(flags,size,op_asl); goto retpt;
  case en_shl:    ap1 = node->GenerateShift(flags,size,op_asl); goto retpt;
  case en_shlu:   ap1 = node->GenerateShift(flags,size,op_asl); goto retpt;
  case en_asr:	ap1 = node->GenerateShift(flags,size,op_sra); goto retpt;
  case en_shr:	ap1 = node->GenerateShift(flags,size,op_sra); goto retpt;
  case en_shru:   ap1 = node->GenerateShift(flags,size,op_srl); goto retpt;
	case en_rol:   ap1 = node->GenerateShift(flags,size,op_rol); goto retpt;
	case en_ror:   ap1 = node->GenerateShift(flags,size,op_ror); goto retpt;
	case en_bitoffset:
		ap1 = GetTempRegister();
		ip = currentFn->pl.tail;
		ap2 = GenerateExpression(node->p[1], am_reg | am_imm | am_imm0, sizeOfWord, rhs);
		ap3 = GenerateExpression(node->p[2], am_reg | am_imm | am_imm0, sizeOfWord, rhs);
		if (ap2->mode != ap3->mode) {
			ReleaseTempReg(ap3);
			ReleaseTempReg(ap2);
			currentFn->pl.tail = ip;
			ap2 = GenerateExpression(node->p[1], am_reg, sizeOfWord,rhs);
			ap3 = GenerateExpression(node->p[2], am_reg, sizeOfWord,rhs);
		}
		GenerateTriadic(op_ext, 0, ap1, ap2, ap3);
		ReleaseTempReg(ap3);
		ReleaseTempReg(ap2);
		/*
		ip = currentFn->pl.tail;
		ap1 = GenerateExpression(node->p[1], am_reg|am_imm|am_imm0, size);
		ap2 = GenerateExpression(node->p[2], am_reg|am_imm|am_imm0, size);
		if (ap1->mode != ap2->mode) {
			ReleaseTempReg(ap2);
			ReleaseTempReg(ap1);
			currentFn->pl.tail = ip;
			ap1 = GenerateExpression(node->p[1], am_reg, size);
			ap2 = GenerateExpression(node->p[2], am_reg, size);
		}
		//GenerateTriadic(op_and, 0, ap3, ap1, MakeImmediate(63));
		//GenerateTriadic(op_lsr, 0, ap1, ap1, ap2);
		ReleaseTempReg(ap2);
		ap1->next = ap3;
		ap1->preserveNextReg = true;
		*/
		goto retpt;
		/*
	case en_asfadd: return GenerateAssignAdd(node,flags,size,op_fadd);
	case en_asfsub: return GenerateAssignAdd(node,flags,size,op_fsub);
	case en_asfmul: return GenerateAssignAdd(node,flags,size,op_fmul);
	case en_asfdiv: return GenerateAssignAdd(node,flags,size,op_fdiv);
	*/
  case en_asadd:  ap1 = node->GenerateAssignAdd(flags, size, op_add);	goto retpt;
  case en_assub:  ap1 = node->GenerateAssignAdd(flags,size,op_sub); goto retpt;
  case en_asand:  ap1 = node->GenerateAssignLogic(flags,size,op_and); goto retpt;
  case en_asor:   ap1 = node->GenerateAssignLogic(flags,size,op_or); goto retpt;
	case en_asxor:  ap1 = node->GenerateAssignLogic(flags,size,op_xor); goto retpt;
  case en_aslsh:  ap1 = (node->GenerateAssignShift(flags,size,op_asl)); goto retpt;
  case en_asrsh:  ap1 = (node->GenerateAssignShift(flags,size,op_asr)); goto retpt;
	case en_asrshu: ap1 = (node->GenerateAssignShift(flags,size,op_lsr)); goto retpt;
  case en_asmul: ap1 = GenerateAssignMultiply(node,flags,size,op_mul); goto retpt;
  case en_asmulu: ap1 = GenerateAssignMultiply(node,flags,size,op_mulu); goto retpt;
  case en_asdiv: ap1 = GenerateAssignModiv(node,flags,size,op_div); goto retpt;
  case en_asdivu: ap1 = GenerateAssignModiv(node,flags,size,op_divu); goto retpt;
  case en_asmod: ap1 = GenerateAssignModiv(node,flags,size,op_mod); goto retpt;
  case en_asmodu: ap1 = GenerateAssignModiv(node,flags,size,op_modu); goto retpt;
  case en_assign:
		ap1 = GenerateAssign(node, flags, size);
		goto retpt;

	case en_chk:
        return (GenExpr(node));
         
  case en_eq:     case en_ne:
  case en_lt:     case en_le:
  case en_gt:     case en_ge:
  case en_ult:    case en_ule:
  case en_ugt:    case en_uge:
  case en_feq:    case en_fne:
  case en_flt:    case en_fle:
  case en_fgt:    case en_fge:
  case en_veq:    case en_vne:
  case en_vlt:    case en_vle:
  case en_vgt:    case en_vge:
		ap1 = GenExpr(node);
		ap1->isBool = true;
		goto retpt;

	case en_cond:
		ap1 = GenerateHook(node, flags, size);
		goto retpt;
	case en_safe_cond:
		ap1 = GenerateMux(node, flags, size);
		goto retpt;

	case en_void:
    natsize = node->p[0]->GetNaturalSize();
		ap1 = GenerateExpression(node->p[0], am_all | am_novalue, natsize, rhs);
		ReleaseTempRegister(GenerateExpression(node->p[1], flags, size, rhs));
		ap1->isPtr = node->IsPtr();
		goto retpt;

	// A cast is represented as a node containing only the type and a second node
	// containing the expression tree. There is nothing to evaluate for the type,
	// it is simply transferred to the expression tree result.

	case en_cast:
		natsize = node->p[0]->GetNaturalSize();
		//ReleaseTempRegister(GenerateExpression(node->p[0], am_all | am_novalue, natsize, rhs));
		ap1 = GenerateExpression(node->p[1], flags, natsize, rhs);
		ap1->tp = node->p[0]->tp;
		ap1->isPtr = node->p[0]->IsPtr();
		goto retpt;

  case en_fcall:
		ap1 = (cg.GenerateFunctionCall(node,flags));
		goto retpt;

	case en_sxb:
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0], am_reg, 1, rhs);
		Generate4adic(op_sbx, 0, ap1, ap2, MakeImmediate(7), MakeImmediate(127));
		ReleaseTempReg(ap2);
		goto retpt;

	case en_sxc:
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0], am_reg, 2, rhs);
		Generate4adic(op_sbx, 0, ap1, ap2, MakeImmediate(15), MakeImmediate(127));
		//GenerateDiadic(op_sxw, 0, ap1, ap2);
		ReleaseTempReg(ap2);
		goto retpt;

	case en_sxh:
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0], am_reg|am_imm, 4, rhs);
		if (ap2->mode == am_imm) {
			Int128 j = Int128::Convert(0xffffffffLL);
			if (Int128::IsLT(&ap2->offset->i128, &j)) {
				ReleaseTempRegister(ap1);
				ap1 = ap2;
				goto retpt;
			}
		}
		if (regs[ap2->preg].isConst) {
			Int128 j = Int128::Convert(0xffffffffLL);
			if (Int128::IsLT(&regs[ap2->preg].val128, &j)) {
				ap1 = MakeImmediate(regs[ap2->preg].val128);
				goto retpt;
			}
		}
		ap2->MakeLegal(am_reg, 4);
		Generate4adic(op_sbx, 0, ap1, ap2, MakeImmediate(31), MakeImmediate(127));
		//GenerateDiadic(op_sxt, 0, ap1, ap2);
		ReleaseTempReg(ap2);
		goto retpt;

	case en_ubyt2hexi:
	case en_ubyt2octa:
	case en_ubyt2tetra:
		ap1 = GenerateExpression(node->p[0],am_reg|am_imm,1,rhs);
		if (ap1->mode == am_imm) {
			ap1->offset->i &= 0xffLL;
			ap1->offset->i128.low & 0xffLL;
			ap1->offset->i128.high = 0;
		}
		else
			GenerateTriadic(op_and,0,ap1,ap1,MakeImmediate(0xff));
		goto retpt;

	case en_uwyde2hexi:
	case en_uwyde2octa:
	case en_uwyde2tetra:
		ap1 = GenerateExpression(node->p[0],am_reg,2,rhs);
		Generate4adic(op_clr,0,ap1,ap1,MakeImmediate(16), MakeImmediate(127));
		goto retpt;
	case en_wyde2ptr:
	case en_ccwp:
		ap1 = GenerateExpression(node->p[0], am_reg, 2,rhs);
		ap1->isPtr = TRUE;
		Generate4adic(op_sbx, 0, ap1, ap1, MakeImmediate(15), MakeImmediate(127));
		goto retpt;
	case en_uwyde2ptr:
	case en_cucwp:
		ap1 = GenerateExpression(node->p[0], am_reg, 2,rhs);
		ap1->isPtr = TRUE;
		Generate4adic(op_clr, 0, ap1, ap1, MakeImmediate(16), MakeImmediate(127));
		goto retpt;
	case en_utetra2hexi:
	case en_utetra2octa:
		ap1 = GenerateExpression(node->p[0],am_reg,4,rhs);
		Generate4adic(op_clr, 0, ap1, ap1, MakeImmediate(32), MakeImmediate(127));
		goto retpt;
	case en_byt2hexi:
	case en_byt2octa:
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0],am_reg,1,rhs);
		if (ap2->mode != am_imm)
			Generate4adic(op_sbx, 0, ap1, ap2, MakeImmediate(7), MakeImmediate(127));
		ReleaseTempRegister(ap2);
		//GenerateDiadic(op_sxb,0,ap1,ap1);
		//GenerateDiadic(op_sxb,0,ap1,ap1);
		goto retpt;
	case en_wyde2hexi:
	case en_wyde2octa:
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0],am_reg|am_imm,2,rhs);
		if (ap2->mode != am_imm)
			Generate4adic(op_sbx, 0, ap1, ap2, MakeImmediate(15), MakeImmediate(127));
//		GenerateDiadic(op_sxw,0,ap1,ap1);
		ReleaseTempRegister(ap2);
		goto retpt;
	case en_tetra2hexi:
	case en_tetra2octa:
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0],am_reg|am_imm,4,rhs);
		if (ap2->mode != am_imm)
			Generate4adic(op_sbx, 0, ap1, ap2, MakeImmediate(15), MakeImmediate(127));
//		GenerateDiadic(op_sxt,0,ap1,ap1);
		ReleaseTempRegister(ap2);
		goto retpt;
	case en_octa2hexi:
		/*
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0], am_reg | am_imm, 8, rhs);
		if (ap2->mode == am_imm) {
			Int128 j = Int128::Convert(0xffffffffLL);
			if (Int128::IsLT(&ap2->offset->i128, &j)) {
				ReleaseTempRegister(ap1);
				ap1 = ap2;
				goto retpt;
			}
		}
		if (regs[ap2->preg].isConst) {
			Int128 j = Int128::Convert(0xffffffffLL);
			if (Int128::IsLT(&regs[ap2->preg].val128, &j)) {
				ap1 = MakeImmediate(regs[ap2->preg].val128);
				goto retpt;
			}
		}
		Generate4adic(op_sbx, 0, ap1, ap2, MakeImmediate(31), MakeImmediate(95));
		//GenerateDiadic(op_sxt, 0, ap1, ap2);
		ReleaseTempReg(ap2);
		goto retpt;
		*/
		ap1 = GetTempRegister();
		ap2 = GenerateExpression(node->p[0], am_reg|am_imm, 8, rhs);
		if (ap2->mode != am_imm)
			Generate4adic(op_sbx, 0, ap1, ap2, MakeImmediate(31), MakeImmediate(127));
		ReleaseTempRegister(ap2);
		goto retpt;
	case en_uocta2hexi:
		ap1 = GenerateExpression(node->p[0], am_reg | am_imm, 8, rhs);
		//GenerateDiadic(op_zxo, 0, ap1, ap1);
		goto retpt;

	case en_list:
		ap1 = GetTempRegister();
		if (use_gp) {
			switch (node->segment) {
			case dataseg:	ndxreg = regGP; break;
			case rodataseg: ndxreg = regGP1; break;
			case tlsseg:	ndxreg = regTP; break;
			default:	ndxreg = regPP; break;
			}
			GenerateDiadic(cpu.lea_op, 0, ap1, MakeDataLabel(node->i, ndxreg));
		}
		else
			GenerateDiadic(cpu.lea_op, 0, ap1, MakeDataLabel(node->i, regZero));
		//if (!compiler.os_code) {
		//	switch (node->segment) {
		//	case tlsseg:		GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(8));	break;
		//	case rodataseg:	GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(12));	break;
		//	}
		//}
		ap1->isPtr = true;
		goto retpt;
	case en_object_list:
		ap1 = GetTempRegister();
		GenerateDiadic(cpu.lea_op,0,ap1,MakeIndexed(-8,regFP));
		//if (!compiler.os_code) {
		//	switch (node->segment) {
		//	case tlsseg:		GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(8));	break;
		//	case rodataseg:	GenerateTriadic(op_base, 0, ap1, ap1, MakeImmediate(12));	break;
		//	}
		//}
		goto retpt;

	case en_switch:
		ap1 = StatementGenerator::GenerateSwitch(node);
		goto retpt;

	default:
    printf("DIAG - uncoded node (%d) in GenerateExpression.\n", node->nodetype);
    return 0;
  }
	ap1 = nullptr;
	goto retpt2;
	return(0);
retpt:
	ap1->MakeLegal(flags, size);
retpt2:
	if (node->pfl) {
		ReleaseTempRegister(cg.GenerateExpression(node->pfl, flags, size, rhs));
	}
	return (ap1);
}

//
// Generate a jump to label if the node passed evaluates to
// a true condition.
//
void CodeGenerator::GenerateTrueJump(ENODE *node, int label, unsigned int prediction)
{ 
	Operand  *ap1, *ap2, *ap3;
	int lab0;
	int siz1;

	if( node == 0 )
		return;
	switch( node->nodetype )
	{
	case en_bchk:	break;
	case en_eq:	GenerateBranch(node, op_eq, label, 0, prediction, false); break;
	case en_ne: GenerateBranch(node, op_ne, label, 0, prediction, false); break;
	case en_lt: GenerateBranch(node, op_lt, label, 0, prediction, false); break;
	case en_le:	GenerateBranch(node, op_le, label, 0, prediction, false); break;
	case en_gt: GenerateBranch(node, op_gt, label, 0, prediction, false); break;
	case en_ge: GenerateBranch(node, op_ge, label, 0, prediction, false); break;
	case en_ult: GenerateBranch(node, op_ltu, label, 0, prediction, false); break;
	case en_ule: GenerateBranch(node, op_leu, label, 0, prediction, false); break;
	case en_ugt: GenerateBranch(node, op_gtu, label, 0, prediction, false); break;
	case en_uge: GenerateBranch(node, op_geu, label, 0, prediction, false); break;
	case en_feq: GenerateBranch(node, op_feq, label, 0, prediction, false); break;
	case en_fne: GenerateBranch(node, op_fne, label, 0, prediction, false); break;
	case en_flt: GenerateBranch(node, op_flt, label, 0, prediction, false); break;
	case en_fle: GenerateBranch(node, op_fle, label, 0, prediction, false); break;
	case en_fgt: GenerateBranch(node, op_fgt, label, 0, prediction, false); break;
	case en_fge: GenerateBranch(node, op_fge, label, 0, prediction, false); break;
	case en_veq: GenerateBranch(node, op_vseq, label, 0, prediction, false); break;
	case en_vne: GenerateBranch(node, op_vsne, label, 0, prediction, false); break;
	case en_vlt: GenerateBranch(node, op_vslt, label, 0, prediction, false); break;
	case en_vle: GenerateBranch(node, op_vsle, label, 0, prediction, false); break;
	case en_vgt: GenerateBranch(node, op_vsgt, label, 0, prediction, false); break;
	case en_vge: GenerateBranch(node, op_vsge, label, 0, prediction, false); break;
	case en_lor_safe:
		if (GenerateBranch(node, op_or, label, 0, prediction, true))
			break;
	case en_lor:
		GenerateTrueJump(node->p[0], label, prediction);
		GenerateTrueJump(node->p[1], label, prediction);
		break;
	case en_land_safe:
		if (GenerateBranch(node, op_and, label, 0, prediction, true))
			break;
	case en_land:
		lab0 = nextlabel++;
		GenerateFalseJump(node->p[0], lab0, prediction);
		GenerateTrueJump(node->p[1], label, prediction ^ 1);
		GenerateLabel(lab0);
		break;
	default:
		siz1 = node->GetNaturalSize();
		ap1 = GenerateExpression(node,am_reg,siz1,1);
		//                        GenerateDiadic(op_tst,siz1,ap1,0);
		ReleaseTempRegister(ap1);
		if (ap1->tp->IsFloatType()) {
			ap2 = GetTempRegister();
			GenerateTriadic(op_fcmp, 0, ap2, ap1, makereg(regZero));
			GenerateTriadic(op_bbs, 0, ap2, MakeImmediate(0), MakeCodeLabel(label));	// bit 0 is eq
			ReleaseTempReg(ap2);
		}
		else {
			ap2 = MakeBoolean(ap1);
			ReleaseTempReg(ap1);
			GenerateBranchTrue(ap2, label);
		}
		break;
	}
}

//
// Generate code to execute a jump to label if the expression
// passed is false.
//
void CodeGenerator::GenerateFalseJump(ENODE *node,int label, unsigned int prediction)
{
	Operand *ap, *ap1, *ap2, *ap3;
	int siz1;
	int lab0;

	if( node == (ENODE *)NULL )
		return;
	switch( node->nodetype )
	{
	case en_bchk:	break;
	case en_eq:	GenerateBranch(node, op_ne, label, 0, prediction, false); break;
	case en_ne: GenerateBranch(node, op_eq, label, 0, prediction, false); break;
	case en_lt: GenerateBranch(node, op_ge, label, 0, prediction, false); break;
	case en_le: GenerateBranch(node, op_gt, label, 0, prediction, false); break;
	case en_gt: GenerateBranch(node, op_le, label, 0, prediction, false); break;
	case en_ge: GenerateBranch(node, op_lt, label, 0, prediction, false); break;
	case en_ult: GenerateBranch(node, op_geu, label, 0, prediction, false); break;
	case en_ule: GenerateBranch(node, op_gtu, label, 0, prediction, false); break;
	case en_ugt: GenerateBranch(node, op_leu, label, 0, prediction, false); break;
	case en_uge: GenerateBranch(node, op_ltu, label, 0, prediction, false); break;
	case en_feq: GenerateBranch(node, op_fne, label, 0, prediction, false); break;
	case en_fne: GenerateBranch(node, op_feq, label, 0, prediction, false); break;
	case en_flt: GenerateBranch(node, op_fge, label, 0, prediction, false); break;
	case en_fle: GenerateBranch(node, op_fgt, label, 0, prediction, false); break;
	case en_fgt: GenerateBranch(node, op_fle, label, 0, prediction, false); break;
	case en_fge: GenerateBranch(node, op_flt, label, 0, prediction, false); break;
	case en_veq: GenerateBranch(node, op_vsne, label, 0, prediction, false); break;
	case en_vne: GenerateBranch(node, op_vseq, label, 0, prediction, false); break;
	case en_vlt: GenerateBranch(node, op_vsge, label, 0, prediction, false); break;
	case en_vle: GenerateBranch(node, op_vsgt, label, 0, prediction, false); break;
	case en_vgt: GenerateBranch(node, op_vsle, label, 0, prediction, false); break;
	case en_vge: GenerateBranch(node, op_vslt, label, 0, prediction, false); break;
	case en_land_safe:
		if (GenerateBranch(node, op_nand, label, 0, prediction, true))
			break;
	case en_land:
		GenerateFalseJump(node->p[0],label,prediction^1);
		GenerateFalseJump(node->p[1],label,prediction^1);
		break;
	case en_lor_safe:
		if (GenerateBranch(node, op_nor, label, 0, prediction,true))
			break;
	case en_lor:
		lab0 = nextlabel++;
		GenerateTrueJump(node->p[0],lab0,prediction);
		GenerateFalseJump(node->p[1],label,prediction^1);
		GenerateLabel(lab0);
		break;
	case en_not:
		GenerateTrueJump(node->p[0],label,prediction);
		break;
	default:
		siz1 = node->GetNaturalSize();
		ap = GenerateExpression(node,am_reg,siz1,1);
		//                        GenerateDiadic(op_tst,siz1,ap,0);
		ReleaseTempRegister(ap);
		//if (ap->mode == am_fpreg) {
		//	GenerateTriadic(op_fseq, 0, makecreg(1), ap, makefpreg(0));
		//	GenerateDiadic(op_bt, 0, makecreg(1), MakeCodeLabel(label));
		//}
		//else
		{
			GenerateDiadic(op_beqz, 0, ap, MakeCodeLabel(label));
			if (false) {
//				if (ap->offset->nodetype==en_icon && ap->offset->i != 0)
//					GenerateMonadic(op_bra, 0, MakeCodeLabel(label));
//				else
				{
					ap1 = MakeBoolean(ap);
					ReleaseTempReg(ap);
					GenerateBranchFalse(ap1, label);
				}
			}
		}
		break;
	}
}

void CodeGenerator::SaveTemporaries(Function *sym, int *sp, int *fsp, int* psp, int* vsp)
{
	if (sym) {
		if (sym->UsesTemps) {
			*sp = TempInvalidate(fsp, psp, vsp);
			//*fsp = TempFPInvalidate();
		}
	}
	else {
		*sp = TempInvalidate(fsp, psp, vsp);
		//*fsp = TempFPInvalidate();
	}
}

void CodeGenerator::RestoreTemporaries(Function *sym, int sp, int fsp, int psp,  int vsp)
{
	if (sym) {
		if (sym->UsesTemps) {
			//TempFPRevalidate(fsp);
			TempRevalidate(sp, fsp, psp, vsp);
		}
	}
	else {
		//TempFPRevalidate(fsp);
		TempRevalidate(sp, fsp, psp, vsp);
	}
}

void CodeGenerator::RestoreRegisterVars(Function* func)
{
	if (!func->prolog) {
		func->RestorePositRegisterVars();
		func->RestoreFPRegisterVars();
		GenerateHint(begin_restore_regvars);
		func->RestoreGPRegisterVars();
		GenerateHint(end_restore_regvars);
	}
}


// Store entire argument list onto stack
//
int CodeGenerator::GenerateInlineArgumentList(Function *sym, ENODE *plist)
{
	Operand *ap;
	TypeArray *ta = nullptr;
	int i, sum;
	OCODE *ip;
	ENODE *p;
	ENODE *pl[100];
	int nn, maxnn;
	struct slit *st;
	char *cp;

	cp = nullptr;
	sum = 0;
	if (sym)
		ta = sym->GetProtoTypes();

	// Capture the parameter list. It is needed in the reverse order.
	for (nn = 0, p = plist; p != NULL; p = p->p[1], nn++) {
		pl[nn] = p->p[0];
	}
	maxnn = nn;
	for (--nn, i = 0; nn >= 0; --nn, i++)
	{
		if (pl[nn]->etype == bt_pointer) {
			if (pl[nn]->tp->btpp == nullptr)
				continue;
			if (pl[nn]->tp->btpp->type == bt_ichar || pl[nn]->tp->btpp->type == bt_iuchar) {
				for (st = strtab; st; st = st->next) {
					if (st->label == pl[nn]->i) {
						cp = st->str;
						break;
					}
				}
				ap = MakeString(cp);
				GenerateMonadic(op_string, 0, ap);
			}
		}
	}
	if (ta)
		delete ta;
	return (sum);
}

// Generate code for a binary expression

Operand* CodeGenerator::GenerateTrinary(ENODE* node, int flags, int size, int op)
{
	Operand* ap1 = nullptr, * ap2 = nullptr, * ap3, * ap4, * ap5;
	bool dup = false;

	if (node->IsFloatType())
	{
		ap3 = GetTempFPRegister();
		if (node->IsEqual(node->p[0], node->p[1]))
			dup = !opt_nocgo;
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size,1);
		if (!dup)
			ap2 = cg.GenerateExpression(node->p[1], am_reg, size,1);
		// Generate a convert operation ?
		if (!dup) {
			if (ap1->fpsize() != ap2->fpsize()) {
				if (ap2->fpsize() == 's')
					GenerateDiadic(op_fcvtsq, 0, ap2, ap2);
			}
		}
		if (dup)
			GenerateTriadic(op, ap1->fpsize(), ap3, ap1, ap1);
		else
			GenerateTriadic(op, ap1->fpsize(), ap3, ap1, ap2);
		ap3->type = ap1->type;
	}
	else if (op == op_vex) {
		ap3 = GetTempRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size,1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size,1);
		GenerateTriadic(op, 0, ap3, ap1, ap2);
	}
	else if (node->IsVectorType()) {
		ap3 = GetTempVectorRegister();
		if (ENODE::IsEqual(node->p[0], node->p[1]) && !opt_nocgo) {
			ap1 = cg.GenerateExpression(node->p[0], am_vreg, size,1);
			ap2 = cg.GenerateExpression(node->vmask, am_vmreg, size,1);
			Generate4adic(op, 0, ap3, ap1, ap1, ap2);
		}
		else {
			ap1 = cg.GenerateExpression(node->p[0], am_vreg, size,1);
			ap2 = cg.GenerateExpression(node->p[1], am_vreg, size,1);
			ap4 = cg.GenerateExpression(node->vmask, am_vmreg, size,1);
			Generate4adic(op, 0, ap3, ap1, ap2, ap4);
			ReleaseTempReg(ap4);
		}
		// Generate a convert operation ?
		//if (fpsize(ap1) != fpsize(ap2)) {
		//	if (fpsize(ap2)=='s')
		//		GenerateDiadic(op_fcvtsq, 0, ap2, ap2);
		//}
	}
	else {
		ap3 = GetTempRegister();
		if (flags & am_bf_assign)
			return (ap3);
		{
			OCODE* ip;

			ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op)->amclass2, size,1);
			// modu/ptrdif does not have an immediate mode
			ip = currentFn->pl.tail;
			ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op)->amclass3, size,1);
			if (Instruction::Get(op)->amclass4) {	// op_ptrdif
				ap4 = cg.GenerateExpression(node->p[2], Instruction::Get(op)->amclass4, size,1);
				Generate4adic(op, 0, ap3, ap1, ap2, ap4);
				if (ap2->mode != ap4->mode) {
					currentFn->pl.tail = ip;
					ap2 = cg.GenerateExpression(node->p[1], am_reg, size,1);
					ap4 = cg.GenerateExpression(node->p[2], am_reg, size,1);
					Generate4adic(op, 0, ap3, ap1, ap2, ap4);
				}
			}
			else {
				if (ap2->mode == am_imm) {
					switch (op) {
					case op_and:
						GenerateTriadic(op, 0, ap3, ap1, MakeImmediate(ap2->offset->i));
						break;
					case op_or:
						GenerateTriadic(op, 0, ap3, ap1, MakeImmediate(ap2->offset->i));
						break;
						// If there is a pointer plus a constant we really wanted an address calc.
					case op_add:
					case op_sub:
						if (ap1->isPtr && ap2->isPtr)
							GenerateTriadic(op, 0, ap3, ap1, ap2);
						else if (ap2->isPtr) {
							GenerateDiadic(cpu.lea_op, 0, ap3, op == op_sub ? compiler.of.MakeNegIndexed(ap2->offset, ap1->preg) : MakeIndexed(ap2->offset, ap1->preg));
							//if (!compiler.os_code) {
							//	switch (ap3->segment) {
							//	case tlsseg:		GenerateTriadic(op_base, 0, ap3, ap3, MakeImmediate(8));	break;
							//	case rodataseg:	GenerateTriadic(op_base, 0, ap3, ap3, MakeImmediate(12));	break;
							//	}
							//}
						}
						else
							GenerateTriadic(op, 0, ap3, ap1, ap2);
						break;
					default:
						GenerateTriadic(op, 0, ap3, ap1, ap2);
					}
				}
				else
					GenerateTriadic(op, 0, ap3, ap1, ap2);
			}
		}
	}
	if (ap2)
		ReleaseTempReg(ap2);
	if (ap1)
		ReleaseTempReg(ap1);
	ap3->MakeLegal(flags, size);
	return (ap3);
}

// Return true if the expression tree has isPascal set anywhere.
// Only needed for indirect function calls.
extern int defaultcc;
bool CodeGenerator::IsPascal(ENODE* ep)
{
	if (ep == nullptr)
		return (defaultcc == 1);
	if (ep->isPascal)
		return (true);
	if (IsPascal(ep->p[0]) || IsPascal(ep->p[1]) || IsPascal(ep->p[2]))
		return (true);
	return (false);
}

int CodeGenerator::GeneratePrepareFunctionCall(ENODE* node, Function* sym, int* sp, int* fsp, int* psp, int* vsp)
{
	int i;
	List* lst, *hlst;
	ENODE* en;
	int64_t sz, sum;
	Operand* ap;
	int64_t offs[100];
	int count;

	if (sym)
		sym->SaveTemporaries(sp, fsp, psp, vsp);
	if (currentFn->HasRegisterParameters())
		if (sym)
			sym->SaveRegisterArguments();
	// Go through the list of arguments looking for aggregates. These will need to
	// be allocated on stack and copied, then a pointer to the stack area pushed.
	// We want the area allocated before pushing other values.
	count = sum = 0;
	hlst = nullptr;
	if (node->p[1]) {
		for (hlst = lst = node->p[1]->ReverseList(node->p[1]); lst; lst = lst->nxt) {
			en = lst->node;
			if (en && en->esize > sizeOfWord) {
				if (en->etype == bt_struct || en->etype == bt_union || en->etype == bt_class) {
					sz = roundWord(en->esize);
					sum += sz;
					offs[count] = sum;
					count++;
				}
			}
		}
	}
	// Allocate stack buffers.
	if (sum > 0)
		GenerateSubtractFrom(makereg(regSP), MakeImmediate(sum, 0));
	count = 0;
	if (hlst)
	for (lst = hlst; lst; lst = lst->nxt) {
		en = lst->node;
		en->stack_offs = offs[count];
		count++;
	}

	i = PushArguments(sym, node->p[1]) + (sum / sizeOfWord);
	// If the symbol is unknown, assume a throw is present
	if (sym) {
		if (sym->DoesThrow)
			currentFn->DoesThrow = true;
	}
	else
		currentFn->DoesThrow = true;
	return (i);
}

void CodeGenerator::GenerateMillicodeCall(Operand* tgt)
{
	GenerateDiadic(op_bsr, 0, makereg(regLR + 1), tgt);
}

bool CodeGenerator::GenerateInlineCall(ENODE* node, Function* sym)
{
	Function* o_fn;
	CSet* mask, * fmask, * pmask;
	int ps;
	OCODE* ip, * pip, *cip, *hip;
	static int instance = 1024;
	int newlabno, oldlab;
	std::map<int, int> labelmap;
	bool code_generated = false;

	o_fn = currentFn;
	mask = save_mask;
	fmask = fpsave_mask;
	pmask = psave_mask;
	currentFn = sym;
	ps = pass;
	// Each function has it's own peeplist. The generated peeplist for an
	// inline function must be appended onto the peeplist of the current
	// function.
	//sym->pl.head = sym->pl.tail = nullptr;
	hip = o_fn->pl.head;
	for (ip = sym->pl.head; ip; ip = pip) {
		if (ip->opcode != op_fnname &&
			ip->opcode != op_rts &&
			ip->opcode != op_rtd &&
			ip->opcode != op_ret) {
			cip = ip->Clone(ip);
			if (cip->opcode == op_label) {
				labelmap[(int)cip->oper1] = 1;
				oldlab = (int)cip->oper1 + instance;
				cip->oper1 = (Operand*)oldlab;
			}
			o_fn->pl.Add(cip);
			code_generated = true;
		}
		pip = ip->fwd;
	}
	// Go through the list and replace old labels with new ones.
	for (ip = hip; ip; ip = ip->fwd) {
		if (Instruction::Get(ip->opcode)->Instruction::IsFlowControl()) {
			if (ip->oper1)
				if (ip->oper1->offset)
					if (ip->oper1->offset->nodetype == en_clabcon) {
						if (labelmap[ip->oper1->offset->i] == 1) {
							ip->oper1->offset->i = ip->oper1->offset->i + instance;
							DataLabels[ip->oper1->offset->i]++;
						}
					}
			if (ip->oper2)
				if (ip->oper2->offset)
					if (ip->oper2->offset->nodetype == en_clabcon) {
						if (labelmap[ip->oper2->offset->i] == 1) {
							ip->oper2->offset->i = ip->oper2->offset->i + instance;
							DataLabels[ip->oper2->offset->i]++;
						}
					}
			if (ip->oper3)
				if (ip->oper3->offset)
					if (ip->oper3->offset->nodetype == en_clabcon) {
						if (labelmap[ip->oper3->offset->i] == 1) {
							ip->oper3->offset->i = ip->oper3->offset->i + instance;
							DataLabels[ip->oper3->offset->i]++;
						}
					}
			if (ip->oper4)
				if (ip->oper4->offset)
					if (ip->oper4->offset->nodetype == en_clabcon) {
						if (labelmap[ip->oper4->offset->i] == 1) {
							ip->oper4->offset->i = ip->oper4->offset->i + instance;
							DataLabels[ip->oper4->offset->i]++;
						}
					}
			}
	}
	//sym->Generate();
	pass = ps;
	currentFn = o_fn;
	//currentFn->pl.tail->fwd = sym->pl.head;
	//currentFn->pl.tail = sym->pl.tail;
	if (node->isAutonew)
		currentFn->hasAutonew = true;
	fpsave_mask = fmask;
	save_mask = mask;
	psave_mask = pmask;
	instance += 1024;
	return (code_generated);
}

Operand* CodeGenerator::GenerateFunctionCall(ENODE* node, int flags, int lab)
{
	Operand* ap, * ap2, * ap3;
	Function* sym;
	Function* o_fn;
	Symbol* s;
	int i;
	int sp = 0;
	int fsp = 0;
	int psp = 0;
	int vsp = 0;
	int ps;
	TypeArray* ta = nullptr;
	CSet* mask, * fmask, * pmask;
	char buf[300];
	Expression exp(stmt);

	sym = nullptr;
	ap = nullptr;

	// Call the function, the function will be called directly by name if the node
	// indicates a name constant. Otherwise the function will be called indirectly
	// via a value loaded into a register.

	GenerateHint(begin_func_call);
	i = 0;
	if (node->p[0]->nodetype == en_nacon || node->p[0]->nodetype == en_cnacon) {
		if (node->p[0])
			s = currentSym = node->sym;
		else
			s = exp.gsearch2(*node->p[0]->sp, bt_int, nullptr, false);
		if (s)
			sym = s->fi;
		/*
				if ((sym->tp->btpp->type==bt_struct || sym->tp->btpp->type==bt_union) && sym->tp->btpp->size > 8) {
							nn = tmpAlloc(sym->tp->btpp->size) + lc_auto + roundWord(sym->tp->btpp->size);
							GenerateMonadic(op_pea,0,MakeIndexed(-nn,regFP));
							i = 1;
					}
	*/
		i += GeneratePrepareFunctionCall(node, sym, &sp, &fsp, &psp, &vsp);

		if (sym && sym->IsInline)
			GenerateInlineCall(node, sym);
		else
			GenerateDirectJump(node, ap, sym, flags, lab);
	}
	else
	{
		/*
			if ((node->p[0]->tp->btpp->type==bt_struct || node->p[0]->tp->btpp->type==bt_union) && node->p[0]->tp->btpp->size > 8) {
						nn = tmpAlloc(node->p[0]->tp->btpp->size) + lc_auto + roundWord(node->p[0]->tp->btpp->size);
						GenerateMonadic(op_pea,0,MakeIndexed(-nn,regFP));
						i = 1;
				}
		 */
		ap = GenerateExpression(node->p[0], am_reg, sizeOfPtr, 0);
		if (ap->offset) {
			if (ap->offset->sym)
				sym = ap->offset->sym->fi;
		}

		i += GeneratePrepareFunctionCall(node, sym, &sp, &fsp, &psp, &vsp);

		ap->mode = am_ind;
		ap->offset = 0;
		if (sym && sym->IsInline)
			GenerateInlineCall(node, sym);
		else
			GenerateIndirectJump(node, ap, sym, flags, lab);
	}

	GenerateInlineArgumentList(sym, node->p[1]);
	PopArguments(sym, i, IsPascal(node));
	if (currentFn->HasRegisterParameters())
		if (sym)
			sym->RestoreRegisterArguments();
	if (sym)
		sym->RestoreTemporaries(sp, fsp, psp, vsp);
	if (ap)
		ReleaseTempRegister(ap);

	// Here it is assumed that the function will return any value in the first
	// argument register. The register file for Thor is unified so it makes no
	// difference as to whether a float type or an integer type is returned.

	if (sym
		&& sym->sym
		&& sym->sym->tp
		&& sym->sym->tp->btpp
		&& sym->sym->tp->btpp->IsVectorType()) {
		GenerateHint(end_func_call);
		if (!(flags & am_novalue))
			return (makevreg(1));
		else
			return (makevreg(0));
	}

	if (sym
		&& sym->sym
		&& sym->sym->tp
		&& sym->sym->tp->btpp
		) {
		if (!(flags & am_novalue)) {
			if (sym->sym->tp->btpp->type != bt_void) {
				ap = makereg(cpu.argregs[0]);
				regs[cpu.argregs[0]].modified = true;
			}
			else
				ap = makereg(regZero);
			ap->isPtr = sym->sym->tp->btpp->type == bt_pointer;
		}
		else {
			GenerateHint(end_func_call);
			return(makereg(regZero));
		}
	}
	// Otherwise returning a int or a void.
	else {
		if (!(flags & am_novalue)) {
			//ap = GetTempRegister();
			ap = makereg(cpu.argregs[0]);
			//GenerateDiadic(cpu.mov_op, 0, ap, makereg(cpu.argregs[0]));
			regs[cpu.argregs[0]].modified = true;
		}
		// If the function has no return value, just return a zero (r0).
		else {
			GenerateHint(end_func_call);
			return(makereg(regZero));
		}
	}
	GenerateHint(end_func_call);
	return (ap);
}

void CodeGenerator::GenerateCoroutineExit(Function* func)
{
	Operand* ap;

	ap = GetTempRegister();
	GenerateLoadConst(MakeStringAsNameConst((char*)MakeConame(*func->sym->mangledName, "first").c_str(), codeseg), ap);
	GenerateStore(ap, MakeIndexedName(MakeConame(*func->sym->mangledName, "target"), regGP), sizeOfWord);
	GenerateLoad(ap, MakeIndexedName(MakeConame(*func->sym->mangledName, "orig_lr"), regGP), sizeOfWord, sizeOfWord);
	GenerateTriadic(op_csrrw, 0, makereg(regZero), ap, MakeImmediate(0x3102));
	ReleaseTempRegister(ap);
	GenerateLoad(makereg(regFP), MakeIndexedName(MakeConame(*func->sym->mangledName, "orig_fp"), regGP), sizeOfWord, sizeOfWord);
	GenerateLoad(makereg(regSP), MakeIndexedName(MakeConame(*func->sym->mangledName, "orig_sp"), regGP), sizeOfWord, sizeOfWord);
}

// Generate a return statement.
//
void CodeGenerator::GenerateReturn(Function* func, Statement* stmt)
{
	Operand* ap, * ap2;
	int nn;
	int cnt, cnt2;
	int64_t toAdd;
	Symbol* p;
	bool isFloat, isPosit, isVector;
	int64_t sz;

	if (func == nullptr)
		throw new C64PException(ERR_NULLPOINTER, 0);

	// Generate the return expression and force the result into r1.
	if (stmt != NULL && stmt->exp != NULL)
	{
		initstack();
		isFloat = func->sym->tp->btpp && func->sym->tp->btpp->IsFloatType();
		isPosit = func->sym->tp->btpp && func->sym->tp->btpp->IsPositType();
		isVector = func->sym->tp->btpp && func->sym->tp->btpp->IsVectorType();
		if (isFloat)
			ap = cg.GenerateExpression(stmt->exp, am_reg, sizeOfFP, 1);
		else if (isPosit)
			ap = cg.GenerateExpression(stmt->exp, am_reg, sizeOfPosit, 1);
		else if (isVector)
			ap = cg.GenerateExpression(stmt->exp, am_vreg, 64, 1);
		else
			ap = cg.GenerateExpression(stmt->exp, am_reg | am_imm, sizeOfWord, 1);
		GenerateMonadic(op_hint, 0, MakeImmediate(2));
		if (ap->mode == am_imm)
			GenerateDiadic(cpu.ldi_op, 0, makereg(cpu.argregs[0]), ap);
		else if (ap->mode == am_reg || ap->mode == am_vreg) {
			if (func->sym->tp->btpp && (func->sym->tp->btpp->type == bt_struct || func->sym->tp->btpp->type == bt_union || func->sym->tp->btpp->type == bt_class)) {
				if ((sz = func->sym->tp->btpp->size) > sizeOfWord) {
					p = func->params.Find("_pHiddenStructPtr", false);
					if (p) {
						if (p->IsRegister)
							GenerateMove(makereg(cpu.argregs[0]), makereg(p->reg));
						else
							GenerateLoad(makereg(cpu.argregs[0]), MakeIndexed(p->value.i, regFP), sizeOfWord, sizeOfWord);
						ap2 = GetTempRegister();
						GenerateLoadConst(MakeImmediate(func->sym->tp->btpp->size), ap2);
						if (cpu.SupportsPush) {
							GenerateMonadic(op_push, 0, ap2);
							GenerateMonadic(op_push, 0, ap);
							GenerateMonadic(op_push, 0, makereg(cpu.argregs[0]));
						}
						else {
							GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(sizeOfWord * 3));
							GenerateStore(makereg(cpu.argregs[0]), MakeIndirect(regSP), sizeOfWord);
							GenerateStore(ap, MakeIndexed(sizeOfWord, regSP), sizeOfWord);
							GenerateStore(ap2, MakeIndexed(sizeOfWord * 2, regSP), sizeOfWord);
						}
						ReleaseTempReg(ap2);
						GenerateCall(MakeStringAsNameConst((char*)"__aacpy", codeseg));
						GenerateMonadic(op_bex, 0, MakeDataLabel(throwlab, regZero));
						if (!func->IsPascal)
							GenerateTriadic(op_add, 0, makereg(regSP), makereg(regSP), MakeImmediate(sizeOfWord * 3));
					}
					else
						throw new C64PException(ERR_MISSING_HIDDEN_STRUCTPTR,0);
				}
				else {
					if (ap->isPtr) {
						if (sz > 4)
							GenerateLoad(makereg(cpu.argregs[0]), MakeIndirect(ap->preg), 8, 8);
						else if (sz > 2)
							GenerateLoad(makereg(cpu.argregs[0]), MakeIndirect(ap->preg), 4, 4);
						else if (sz > 1)
							GenerateLoad(makereg(cpu.argregs[0]), MakeIndirect(ap->preg), 2, 2);
						else
							GenerateLoad(makereg(cpu.argregs[0]), MakeIndirect(ap->preg), 1, 1);
					}
					else
						GenerateMove(makereg(cpu.argregs[0]), ap);
				}
			}
			else {
				if (func->sym->tp->btpp->IsFloatType() || func->sym->tp->btpp->IsPositType())
					cg.GenerateMove(makereg(cpu.argregs[0]), ap);
				else if (func->sym->tp->btpp->IsVectorType())
					cg.GenerateMove(makevreg(cpu.vargregs[0]), ap, makereg(regZero | rt_invert));
				else
					cg.GenerateMove(makereg(cpu.argregs[0]), ap);
			}
		}
		/* I think this code cannot be reached. am_reg checked above
		else if (ap->mode == am_reg) {
			if (isFloat)
				GenerateDiadic(cpu.mov_op, 0, makereg(cpu.argregs[0]), ap);
			else
				GenerateDiadic(cpu.mov_op, 0, makereg(cpu.argregs[0]), ap);
		}
		else if (ap->mode == am_reg) {
			if (isPosit)
				GenerateDiadic(cpu.mov_op, 0, compiler.of.makepreg(cpu.argregs[0]), ap);
			else
				GenerateDiadic(cpu.mov_op, 0, makereg(cpu.argregs[0]), ap);
		}
		*/
		else if (ap->typep == &stddouble) {
			if (isFloat)
				GenerateDiadic(op_ldf, 'd', makereg(cpu.argregs[0]), ap);
			else
				GenerateLoad(makereg(cpu.argregs[0]), ap, sizeOfFPD, sizeOfFPD);
		}
		else {
			if (func->sym->tp->btpp->IsVectorType())
				GenerateLoad(makevreg(cpu.vargregs[0]), ap, sizeOfWord, sizeOfWord, makereg(regZero | rt_invert));
			else
				GenerateLoad(makereg(cpu.argregs[0]), ap, sizeOfWord, sizeOfWord);
		}
		ReleaseTempRegister(ap);
	}

	// Generate the return code only once. Branch to the return code for all returns.
	if (func->retGenerated) {
		GenerateMonadic(op_bra, 0, MakeCodeLabel(retlab));
		return;
	}
	func->retGenerated = true;
	GenerateLabel(retlab);

	if (func->IsCoroutine)
		GenerateCoroutineExit(func);

	func->rcode = func->pl.tail;

	// Unreferenced objects are garbage collected by the system. There's no need
	// to manage a list of them.

	//if (currentFn->UsesNew) {
	//	if (cpu.SupportsPush)
	//		GenerateMonadic(op_push, 0, makereg(regFirstArg));
	//	else {
	//		GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(8));
	//		GenerateDiadic(op_std, 0, makereg(regFirstArg), MakeIndirect(regSP));
	//	}
	//	GenerateDiadic(op_lea, 0, makereg(regFirstArg), MakeIndexed(-sizeOfWord, regFP));
	//	GenerateMonadic(op_call, 0, MakeStringAsNameConst("__AddGarbage"));
	//	GenerateDiadic(op_ldd, 0, makereg(regFirstArg), MakeIndirect(regSP));
	//	GenerateTriadic(op_add, 0, makereg(regSP), makereg(regSP), MakeImmediate(8));
	//}

	// Unlock any semaphores that may have been set
	for (nn = lastsph - 1; nn >= 0; nn--)
		GenerateStore(makereg(0), MakeStringAsNameConst(semaphores[nn], dataseg), 1);

	// Restore fp registers used as register variables.
	//if (fpsave_mask->NumMember()) {
	//	cnt2 = cnt = (fpsave_mask->NumMember() - 1)*sizeOfFP;
	//	fpsave_mask->resetPtr();
	//	for (nn = fpsave_mask->lastMember(); nn >= 1; nn = fpsave_mask->prevMember()) {
	//		GenerateDiadic(op_lf, 'd', makefpreg(nregs - 1 - nn), MakeIndexed(cnt2 - cnt, regSP));
	//		cnt -= sizeOfWord;
	//	}
	//	GenerateTriadic(op_add, 0, makereg(regSP), makereg(regSP), MakeImmediate(cnt2 + sizeOfFP));
	//}
	RestoreRegisterVars(func);
	if (func->IsNocall) {
		if (func->epilog) {
			func->epilog->Generate();
			return;
		}
		return;
	}
	toAdd = 0;
	if (!cpu.SupportsLeave) {
		func->UnlinkStack(0);
		toAdd = func->has_return_block ? compiler.GetReturnBlockSize() : 0;
	}
	if (!func->alstk) {
		// The size of the return block is included in the link instruction, so the
		// unlink instruction will reverse the allocation.
		if (cpu.SupportsLink)
			toAdd = 0;
		else if (cpu.SupportsLeave)
			toAdd = 0;
	}
	//else if (currentFn->IsLeaf)
	//	toAdd = 0;

	if (func->epilog) {
		func->epilog->Generate();
		return;
	}

	// Local variables and the return block must be deallocated before the return instruction.
	// The return address is between these and the parameters. Parameters can be deallocated
	// during the return. For leaf routines, the return address is not present, so it is 
	// safe to combine the de-allocations.
	//if (!currentFn->IsLeaf) {
	//	GenerateTriadic(op_add, 0, makereg(regSP), makereg(regSP), MakeImmediate(toAdd));
	//	toAdd = 0;
	//}

	// If Pascal calling convention remove parameters from stack by adding to stack pointer
	// based on the number of parameters. However if a non-auto register parameter is
	// present, then don't add to the stack pointer for it. (Remove the previous add effect).
	// Also, do not add to the stack pointer for the ellipsis parameter.
	/*
	if (IsPascal) {
		TypeArray *ta;
		int nn;
		ta = GetProtoTypes();
		for (nn = 0; nn < ta->length; nn++) {
			switch (ta->types[nn]) {
			case bt_float:
				if (ta->preg[nn] && (ta->preg[nn] & 0x8000) == 0)
					;
				else
					toAdd += sizeOfFP;
				break;
			case bt_quad:
				if (ta->preg[nn] && (ta->preg[nn] & 0x8000) == 0)
					;
				else
					toAdd += sizeOfFPQ;
				break;
			case bt_double:
				if (ta->preg[nn] && (ta->preg[nn] & 0x8000) == 0)
					;
				else
					toAdd += sizeOfFPD;
				break;
			case bt_posit:
				if (ta->preg[nn] && (ta->preg[nn] & 0x8000) == 0)
					;
				else
					toAdd += sizeOfPosit;
				break;
			case bt_ellipsis:
				break;
			default:
				if (ta->preg[nn] && (ta->preg[nn] & 0x8000) == 0)
					;
				else
					toAdd += sizeOfWord;
			}
		}
	}
	*/
	if (func->IsPascal)
		toAdd += func->arg_space;

	//	if (toAdd != 0)
	//		GenerateTriadic(op_add,0,makereg(regSP),makereg(regSP),MakeImmediate(toAdd));
	// Generate the return instruction. For the Pascal calling convention pop the parameters
	// from the stack.
	if (func->IsInterrupt) {
		//RestoreRegisterSet(sym);
		GenerateInterruptLoad(func);
		GenerateInterruptReturn(func);
		return;
	}

	if (!func->IsInline) {
		if (cpu.SupportsLeave) {
			if (func->arg_space < 32760)
				func->UnlinkStack(toAdd);
			else {
				GenerateMove(makereg(regSP), makereg(regFP));
				GenerateLoad(makereg(regFP), MakeIndirect(regSP), sizeOfWord, sizeOfWord);
				ap = GetTempRegister();
				GenerateLoad(ap, MakeIndexed(2 * sizeOfWord, regFP), sizeOfWord, sizeOfWord);
				GenerateTriadic(op_csrrw, 0, makereg(regZero), ap, MakeImmediate(0x3102));
				ReleaseTempRegister(ap);
				GenerateAddOnto(makereg(regSP), MakeImmediate(toAdd));
			}
		}
		else {
			if (toAdd > 0) {
				cg.GenerateReturnAndDeallocate(toAdd);
				toAdd = 0;
			}
			else
				GenerateReturnInsn();
		}
	}
	else
		GenerateAddOnto(makereg(regSP), MakeImmediate(toAdd));
}


// Generate code for a binary expression

Operand* CodeGenerator::GenerateBinary(ENODE* node, int flags, int size, int op)
{
	Operand* ap1 = nullptr, * ap2 = nullptr, * ap3, * ap4;
	bool dup = false;

	if (node->IsFloatType())
		return (cg.GenerateBinaryFloat(node, flags, size, (e_op)op));
	else if (node->IsPositType())
	{
		ap3 = GetTempPositRegister();
		if (node->IsEqual(node->p[0], node->p[1]))
			dup = !opt_nocgo;
		ap1 = cg.GenerateExpression(node->p[0], am_preg, size, 0);
		if (!dup)
			ap2 = cg.GenerateExpression(node->p[1], am_preg, size, 1);
		// Generate a convert operation ?
		if (!dup) {
			if (ap1->fpsize() != ap2->fpsize()) {
				if (ap2->fpsize() == 's')
					GenerateDiadic(op_fcvtsq, 0, ap2, ap2);
			}
		}
		if (dup)
			GenerateTriadic(op, 0, ap3, ap1, ap1);
		else
			GenerateTriadic(op, 0, ap3, ap1, ap2);
		ap3->type = ap1->type;
	}
	else if (op == op_vex) {
		ap3 = GetTempRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 0);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size, 1);
		GenerateTriadic(op, 0, ap3, ap1, ap2);
	}
	else if (node->IsVectorType()) {
		ap3 = GetTempVectorRegister();
		if (ENODE::IsEqual(node->p[0], node->p[1]) && !opt_nocgo) {
			ap1 = cg.GenerateExpression(node->p[0], am_vreg, size, 0);
			//ap2 = cg.GenerateExpression(node->vmask, am_vmreg, size, 1);
			Generate4adic(op, 0, ap3, ap1, ap1, makevmreg(node->mask) );
		}
		else {
			ap1 = cg.GenerateExpression(node->p[0], am_vreg|am_reg, size, 0);
			ap2 = cg.GenerateExpression(node->p[1], am_vreg|am_reg, size, 1);
			//ap4 = cg.GenerateExpression(node->vmask, am_vmreg, size, 1);
			Generate4adic(op, 0, ap3, ap1, ap2, makevmreg(node->mask));
			//ReleaseTempReg(ap4);
		}
		// Generate a convert operation ?
		//if (fpsize(ap1) != fpsize(ap2)) {
		//	if (fpsize(ap2)=='s')
		//		GenerateDiadic(op_fcvtsq, 0, ap2, ap2);
		//}
	}
	else {
		ap3 = GetTempRegister();
		if (ENODE::IsEqual(node->p[0], node->p[1]) && !opt_nocgo) {
			// Duh, subtract operand from itself, result would be zero.
			if (op == op_sub || op == op_ptrdif || op == op_eor)
				GenerateMove(ap3, makereg(0));
			else {
				ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 0);
				GenerateTriadic(op, 0, ap3, ap1, ap1);
			}
		}
		else {
			ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op)->amclass2, size, 0);
			// modu/ptrdif does not have an immediate mode
			ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op)->amclass3, size, 1);
			if (Instruction::Get(op)->amclass4) {	// op_ptrdif
				ap4 = cg.GenerateExpression(node->p[4], Instruction::Get(op)->amclass4, size, 1);
				Generate4adic(op, 0, ap3, ap1, ap2, ap4);
			}
			else {
				if (ap2->mode == am_imm) {
					switch (op) {
					case op_and:
						GenerateTriadic(op, 0, ap3, ap1, MakeImmediate(ap2->offset->i));
						break;
					case op_or:
						GenerateTriadic(op, 0, ap3, ap1, MakeImmediate(ap2->offset->i));
						break;
						// If there is a pointer plus a constant we really wanted an address calc.
					case op_add:
					case op_sub:
						if (ap1->isPtr && ap2->isPtr)
							GenerateTriadic(op, 0, ap3, ap1, ap2);
						else if (ap2->isPtr) {
							GenerateDiadic(cpu.lea_op, 0, ap3, op == op_sub ? compiler.of.MakeNegIndexed(ap2->offset, ap1->preg) : MakeIndexed(ap2->offset, ap1->preg));
							//if (!compiler.os_code) {
							//	switch (ap3->segment) {
							//	case tlsseg:		GenerateTriadic(op_base, 0, ap3, ap3, MakeImmediate(8));	break;
							//	case rodataseg:	GenerateTriadic(op_base, 0, ap3, ap3, MakeImmediate(12));	break;
							//	}
							//}
						}
						else {
							GenerateTriadic(op, 0, ap3, ap1, ap2);
						}
						break;
					default:
						GenerateTriadic(op, 0, ap3, ap1, ap2);
					}
				}
				else
					GenerateTriadic(op, 0, ap3, ap1, ap2);
			}
		}
	}
	if (ap2)
		ReleaseTempReg(ap2);
	if (ap1)
		ReleaseTempReg(ap1);
	ap3->MakeLegal(flags, size);
	return (ap3);
}

void CodeGenerator::GenerateReturnAndDeallocate(int64_t amt) {
	GenerateTriadic(op_rtd, 0, makereg(regSP), makereg(regSP), MakeImmediate(amt));
}

