// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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

Operand* RiscvCodeGenerator::GetTempFPRegister()
{
	return (::GetTempFPRegister());
}

void RiscvStatementGenerator::GenerateTabularSwitch(Statement* stmt, int64_t minv, int64_t maxv, Operand* ap, bool HasDefcase, int deflbl, int tablabel)
{
	Operand* ap2;

	stmt->tabular = true;
	ap2 = GetTempRegister();
	GenerateTriadic(op_sub, 0, ap, ap, cg.MakeImmediate(minv));
	if (maxv - minv >= 0 && maxv - minv < 64) {
		cg.GenerateLoadConst(cg.MakeImmediate(maxv - minv + 1), ap2);
		GenerateTriadic(op_bgeu, 0, ap, ap2, cg.MakeCodeLabel(HasDefcase ? deflbl : breaklab));
	}
	else {
		cg.GenerateLoadConst(cg.MakeImmediate(maxv - minv + 1), ap2);
		GenerateTriadic(op_sltu, 0, ap2, ap, ap2);
		GenerateDiadic(op_beqz, 0, ap2, cg.MakeCodeLabel(HasDefcase ? deflbl : breaklab));
	}
	ReleaseTempRegister(ap2);
	GenerateTriadic(op_asl, 0, ap, ap, cg.MakeImmediate(2));
	GenerateDiadic(op_ldt, 0, ap, compiler.of.MakeIndexedCodeLabel(tablabel, ap->preg));
	GenerateMonadic(op_jmp, 0, cg.MakeIndirect(ap->preg));
	ReleaseTempRegister(ap);
	GenerateSwitchStatements(stmt);
}

void RiscvStatementGenerator::GenerateNakedTabularSwitch(Statement* stmt, int64_t minv, Operand* ap, int tablabel)
{
	if (minv != 0)
		GenerateTriadic(op_sub, 0, ap, ap, MakeImmediate(minv));
	GenerateTriadic(op_sll, 0, ap, ap, cg.MakeImmediate(2));
	//	GenerateDiadic(cpu.ldo_op, 0, ap, compiler.of.MakeIndexedCodeLabel(tablabel, ap->preg));
	GenerateDiadic(op_ldt, 0, ap, compiler.of.MakeIndexedName((char*)stmt->GenerateSwitchTargetName(tablabel).c_str(), ap->preg)); // MakeIndexedCodeLabel(tablabel, ap->preg));
	GenerateMonadic(op_jmp, 0, cg.MakeIndirect(ap->preg));
	ReleaseTempRegister(ap);
	GenerateSwitchStatements(stmt);
}

Operand* RiscvCodeGenerator::GenExpr(ENODE* node)
{
	Operand* ap1, * ap2, * ap3, * ap4;
	int lab0, lab1;
	int64_t size = sizeOfWord;
	int op;

	lab0 = nextlabel++;
	lab1 = nextlabel++;

	switch (node->nodetype) {
	case en_eq:		op = op_seq;	break;
	case en_ne:		op = op_sne;	break;
	case en_lt:		op = op_slt;	break;
	case en_ult:	op = op_sltu;	break;
	case en_le:		op = op_sle;	break;
	case en_ule:	op = op_sleu;	break;
	case en_gt:		op = op_sgt;	break;
	case en_ugt:	op = op_sgtu;	break;
	case en_ge:		op = op_sge;	break;
	case en_uge:	op = op_sgeu;	break;
	case en_flt:	op = op_fslt;	break;
	case en_fle:	op = op_fsle;	break;
	case en_fgt:	op = op_fsgt;	break;
	case en_fge:	op = op_fsge;	break;
	case en_feq:	op = op_fseq;	break;
	case en_fne:	op = op_fsne;	break;
	case en_veq:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size, 1);
		GenerateTriadic(op_vseq, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vne:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size, 1);
		GenerateTriadic(op_vsne, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vlt:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size, 1);
		GenerateTriadic(op_vslt, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vle:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size, 1);
		GenerateTriadic(op_vsle, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vgt:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size, 1);
		GenerateTriadic(op_vsgt, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_vge:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size, 1);
		GenerateTriadic(op_vsge, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return (ap3);
	case en_land_safe:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm, size, 1);
		GenerateTriadic(op_and, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return(ap3);
	case en_lor_safe:
		size = node->GetNaturalSize();
		ap3 = GetTempVectorRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size, 1);
		GenerateTriadic(op_or, 0, ap3, ap1, ap2);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		return(ap3);
	default:	// en_land, en_lor
		//ap1 = GetTempRegister();
		//ap2 = cg.GenerateExpression(node,am_reg,8);
		//GenerateDiadic(op_redor,0,ap1,ap2);
		//ReleaseTempReg(ap2);
		GenerateFalseJump(node, lab0, 0);
		ap1 = GetTempRegister();
		GenerateDiadic(cpu.ldi_op | op_dot, 0, ap1, MakeImmediate(1));
		GenerateMonadic(op_bra, 0, MakeDataLabel(lab1, regZero));
		GenerateLabel(lab0);
		GenerateDiadic(cpu.ldi_op | op_dot, 0, ap1, MakeImmediate(0));
		GenerateLabel(lab1);
		ap1->isBool = true;
		return (ap1);
	}

	switch (node->nodetype) {
	case en_eq:	return (GenerateEq(node));
	case en_ne:	return (GenerateNe(node));
	case en_lt:	return (GenerateLt(node));
	case en_le:	return (GenerateLe(node));
	case en_gt: return (GenerateGt(node));
	case en_ge:	return (GenerateGe(node));
	case en_ult:	return (GenerateLtu(node));
	case en_ule:	return (GenerateLeu(node));
	case en_ugt:	return (GenerateGtu(node));
	case en_uge:	return (GenerateGeu(node));
	case en_flt:	return (GenerateFlt(node));
	case en_fle:	return (GenerateFle(node));
	case en_fgt:	return (GenerateFgt(node));
	case en_fge:	return (GenerateFge(node));
	case en_feq:	return (GenerateFeq(node));
	case en_fne:	return (GenerateFne(node));
	case en_chk:
		size = node->GetNaturalSize();
		ap4 = GetTempRegister();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], am_reg, size, 1);
		ap3 = cg.GenerateExpression(node->p[2], am_reg | am_imm0, size, 1);
		if (ap3->mode == am_imm) {  // must be a zero
			ap3->mode = am_reg;
			ap3->preg = 0;
		}
		Generate4adic(op_chk, 0, ap4, ap1, ap2, ap3);
		ReleaseTempRegister(ap3);
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		return ap4;
	}
	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 1);
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm | am_imm0, size, 1);
	GenerateTriadic(op, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	ap3->isBool = true;
	return (ap3);
	/*
		GenerateFalseJump(node,lab0,0);
		ap1 = GetTempRegister();
		GenerateDiadic(op_ld,0,ap1,MakeImmediate(1));
		GenerateMonadic(op_bra,0,MakeDataLabel(lab1));
		GenerateLabel(lab0);
		GenerateDiadic(op_ld,0,ap1,MakeImmediate(0));
		GenerateLabel(lab1);
		return ap1;
	*/
}

void RiscvCodeGenerator::GenerateBranchTrue(Operand* ap, int label)
{
	gHeadif = currentFn->pl.tail;
	GenerateDiadic(op_bnez, 0, ap, MakeCodeLabel(label));
}

void RiscvCodeGenerator::GenerateBranchFalse(Operand* ap, int label)
{
	gHeadif = currentFn->pl.tail;
	GenerateDiadic(op_beqz, 0, ap, MakeCodeLabel(label));
}

bool RiscvCodeGenerator::GenerateBranch(ENODE* node, int op, int label, int predreg, unsigned int prediction, bool limit)
{
	int size, sz;
	Operand* ap1, * ap2, * ap3;
	OCODE* ip;

	if ((op == op_nand || op == op_nor || op == op_and || op == op_or) && (node->p[0]->HasCall() || node->p[1]->HasCall()))
		return (false);
	ap3 = GetTempRegister();
	size = node->GetNaturalSize();
	ip = currentFn->pl.tail;
	if (op == op_flt || op == op_fle || op == op_fgt || op == op_fge || op == op_feq || op == op_fne) {
		ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_fcmp)->amclass2, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_fcmp)->amclass3, size, 1);
	}
	else {
		ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op)->amclass2, size, 1);
		ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op)->amclass3, size, 1);
	}
	if (ap1->mode == am_imm) {
		GenerateLoadConst(ap3, ap1);
		ap1 = ap3;
	}
	if (limit && currentFn->pl.Count(ip) > 10) {
		currentFn->pl.tail = ip;
		currentFn->pl.tail->fwd = nullptr;
		return (false);
	}
	/*
	// Optimize CMP to zero and branch into plain branch, this works only for
	// signed relational compares.
	if (ap2->mode == am_imm && ap2->offset->i==0 && (op==op_eq || op==op_ne || op==op_lt || op==op_le || op==op_gt || op==op_ge)) {
			switch(op)
			{
			case op_eq:	op = op_beq; break;
			case op_ne:	op = op_bne; break;
			case op_lt: op = op_blt; break;
			case op_le: op = op_ble; break;
			case op_gt: op = op_bgt; break;
			case op_ge: op = op_bge; break;
			}
			ReleaseTempReg(ap3);
		ReleaseTempReg(ap2);
		ReleaseTempReg(ap1);
		GenerateDiadic(op,0,ap1,MakeCodeLabel(label));
		return;
	}
	*/
	/*
	if (op==op_ltu || op==op_leu || op==op_gtu || op==op_geu)
			GenerateTriadic(op_cmpu,0,ap3,ap1,ap2);
		else if (op==op_flt || op==op_fle || op==op_fgt || op==op_fge || op==op_feq || op==op_fne)
				GenerateTriadic(op_fdcmp,0,ap3,ap1,ap2);
	else
			GenerateTriadic(op_cmp,0,ap3,ap1,ap2);
	*/
	sz = 0;
	switch (op)
	{
	case op_bchk:	break;
	case op_nand:	op = op_bnand; break;
	case op_nor:	op = op_bnor; break;
	case op_and:	op = op_band; break;
	case op_or:	op = op_bor; break;
	case op_eq:	op = op_beq; break;
	case op_ne:	op = op_bne; break;
	case op_lt: op = op_blt; break;
	case op_le: op = op_ble; break;
	case op_gt: op = op_bgt; break;
	case op_ge: op = op_bge; break;
	case op_ltu: op = op_bltu; break;
	case op_leu: op = op_bleu; break;
	case op_gtu: op = op_bgtu; break;
	case op_geu: op = op_bgeu; break;
	case op_feq:	op = op_fbeq; sz = 'd'; break;
	case op_fne:	op = op_fbne; sz = 'd'; break;
	case op_flt:	op = op_fblt; sz = 'd'; break;
	case op_fle:	op = op_fble; sz = 'd'; break;
	case op_fgt:	op = op_fbgt; sz = 'd'; break;
	case op_fge:	op = op_fbge; sz = 'd'; break;
	}

	switch (op) {

	case op_fbne:
		ap3 = GetTempFPRegister();
		GenerateTriadic(op_feq, 0, ap3, ap1, ap2);
		GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fbeq:
		ap3 = GetTempFPRegister();
		GenerateTriadic(op_feq, 0, ap3, ap1, ap2);
		GenerateTriadic(op_beq, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fblt:
		ap3 = GetTempFPRegister();
		GenerateTriadic(op_flt, 0, ap3, ap1, ap2);
		GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fble:
		ap3 = GetTempRegister();
		GenerateTriadic(op_fle, 0, ap3, ap1, ap2);
		GenerateTriadic(op_bne, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fbgt:
		ap3 = GetTempRegister();
		GenerateTriadic(op_fble, 0, ap3, ap1, ap2);
		GenerateTriadic(op_beq, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_fbge:
		ap3 = GetTempRegister();
		GenerateTriadic(op_flt, 0, ap3, ap1, ap2);
		GenerateTriadic(op_beq, 0, ap3, makereg(regZero), MakeCodeLabel(label));
		ReleaseTempReg(ap3);
		break;

	case op_band:	GenerateBand(ap1, ap2, label); break;
	case op_bor:	GenerateBor(ap1, ap2, label);	break;
	case op_bnand:	GenerateBnand(ap1, ap2, label);	break;
	case op_bnor:	GenerateBnor(ap1, ap2, label);	break;
	case op_beq:	GenerateBeq(ap1, ap2, label); break;
	case op_bne:	GenerateBne(ap1, ap2, label); break;
	case op_blt:	GenerateBlt(ap1, ap2, label); break;
	case op_ble:	GenerateBle(ap1, ap2, label); break;
	case op_bgt:	GenerateBgt(ap1, ap2, label); break;
	case op_bge:	GenerateBge(ap1, ap2, label);	break;
	case op_bltu:	GenerateBltu(ap1, ap2, label);	break;
	case op_bleu:	GenerateBleu(ap1, ap2, label);  break;
	case op_bgtu:	GenerateBgtu(ap1, ap2, label);	break;
	case op_bgeu:	GenerateBgeu(ap1, ap2, label);	break;
	}
	ReleaseTempReg(ap2);
	ReleaseTempReg(ap1);
	return (true);
}

void RiscvCodeGenerator::GenerateBand(Operand* ap, Operand* ap2, int lab)
{
	Operand* ap3;

	ap3 = GetTempRegister();
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_and, 0, ap3, ap, ap3);
		GenerateDiadic(op_bnez, 0, ap3, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_and, 0, ap3, ap, ap2);
	GenerateDiadic(op_bnez, 0, ap3, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBor(Operand* ap, Operand* ap2, int lab)
{
	Operand* ap3;

	ap3 = GetTempRegister();
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_or, 0, ap3, ap, ap3);
		GenerateDiadic(op_bnez, 0, ap3, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_or, 0, ap3, ap, ap2);
	GenerateDiadic(op_bnez, 0, ap3, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBnand(Operand* ap, Operand* ap2, int lab)
{
	Operand* ap3;

	ap3 = GetTempRegister();
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_and, 0, ap3, ap, ap3);
		GenerateDiadic(op_beqz, 0, ap3, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_and, 0, ap3, ap, ap2);
	GenerateDiadic(op_beqz, 0, ap3, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBnor(Operand* ap, Operand* ap2, int lab)
{
	Operand* ap3;

	ap3 = GetTempRegister();
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_or, 0, ap3, ap, ap3);
		GenerateDiadic(op_beqz, 0, ap3, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_or, 0, ap3, ap, ap2);
	GenerateDiadic(op_beqz, 0, ap3, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBeq(Operand* ap, Operand* ap2, int lab)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_beq, 0, ap, ap3, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_bne, 0, ap, ap2, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBne(Operand* ap, Operand* ap2, int lab)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_bne, 0, ap, ap3, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_bne, 0, ap, ap2, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBle(Operand* ap, Operand* ap2, int lab)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_bge, 0, ap3, ap, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_bge, 0, ap2, ap, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBge(Operand* ap, Operand* ap2, int lab)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_bge, 0, ap, ap3, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_bge, 0, ap, ap2, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBgeu(Operand* ap, Operand* ap2, int lab)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_bgeu, 0, ap, ap3, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_bgeu, 0, ap, ap2, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBleu(Operand* ap, Operand* ap2, int lab)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_bgeu, 0, ap3, ap, cg.MakeCodeLabel(lab));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_bgeu, 0, ap2, ap, cg.MakeCodeLabel(lab));
}

void RiscvCodeGenerator::GenerateBgt(Operand* ap1, Operand* ap2, int label)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_blt, 0, ap3, ap1, MakeCodeLabel(label));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_blt, 0, ap2, ap1, MakeCodeLabel(label));
}

void RiscvCodeGenerator::GenerateBgtu(Operand* ap1, Operand* ap2, int label)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_bltu, 0, ap3, ap1, MakeCodeLabel(label));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_bltu, 0, ap2, ap1, MakeCodeLabel(label));
}

void RiscvCodeGenerator::GenerateBlt(Operand* ap1, Operand* ap2, int label)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_blt, 0, ap1, ap3, MakeCodeLabel(label));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_blt, 0, ap1, ap2, MakeCodeLabel(label));
}

void RiscvCodeGenerator::GenerateBltu(Operand* ap1, Operand* ap2, int label)
{
	if (ap2->mode == am_imm) {
		Operand* ap3 = GetTempRegister();
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_bltu, 0, ap1, ap3, MakeCodeLabel(label));
		ReleaseTempRegister(ap3);
		return;
	}
	GenerateTriadic(op_bltu, 0, ap1, ap2, MakeCodeLabel(label));
}

Operand* RiscvCodeGenerator::GenerateEq(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_xor)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_xor)->amclass3, node->p[1]->GetNaturalSize(), 1);
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_xor, 0, ap3, ap1, ap3);
		GenerateTriadic(op_sltu, 0, ap3, ap3, MakeImmediate(1));
	}
	else {
		GenerateTriadic(op_xor, 0, ap3, ap1, ap2);
		GenerateTriadic(op_sltu, 0, ap3, ap3, MakeImmediate(1));
	}
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateNe(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_xor)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_xor)->amclass3, node->p[1]->GetNaturalSize(), 1);
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_xor, 0, ap3, ap1, ap3);
		GenerateTriadic(op_xor, 0, ap3, ap3, MakeImmediate(1));
		GenerateTriadic(op_sltu, 0, ap3, ap3, MakeImmediate(1));
	}
	else {
		GenerateTriadic(op_xor, 0, ap3, ap1, ap2);
		GenerateTriadic(op_xor, 0, ap3, ap3, MakeImmediate(1));
		GenerateTriadic(op_sltu, 0, ap3, ap3, MakeImmediate(1));
	}
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateLt(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_slt)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_slt)->amclass3, node->p[1]->GetNaturalSize(), 1);
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_slt, 0, ap3, ap1, ap3);
	}
	else
		GenerateTriadic(op_slt, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateLtu(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_sltu)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_sltu)->amclass3, node->p[1]->GetNaturalSize(), 1);
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_sltu, 0, ap3, ap1, ap3);
	}
	else
		GenerateTriadic(op_sltu, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateGt(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_slt)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_slt)->amclass3, node->p[1]->GetNaturalSize(), 1);
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_slt, 0, ap3, ap3, ap1);
	}
	else
		GenerateTriadic(op_slt, 0, ap3, ap2, ap1);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateGtu(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;
	int size;

	size = node->GetNaturalSize();
	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_sltu)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_sltu)->amclass3, node->p[1]->GetNaturalSize(), 1);
	if (ap2->mode == am_imm) {
		cg.GenerateLoadConst(ap2, ap3);
		GenerateTriadic(op_sltu, 0, ap3, ap3, ap1);
	}
	else
		GenerateTriadic(op_sltu, 0, ap3, ap2, ap1);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateLe(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = GenerateLt(node);
	ap2 = GenerateEq(node);
	GenerateTriadic(op_or, 0, ap3, ap2, ap1);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateLeu(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = GenerateLtu(node);
	ap2 = GenerateEq(node);
	GenerateTriadic(op_or, 0, ap3, ap2, ap1);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateGe(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = GenerateGt(node);
	ap2 = GenerateEq(node);
	GenerateTriadic(op_or, 0, ap3, ap2, ap1);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateGeu(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = GenerateGtu(node);
	ap2 = GenerateEq(node);
	GenerateTriadic(op_or, 0, ap3, ap2, ap1);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateFeq(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_feq)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_feq)->amclass3, node->p[1]->GetNaturalSize(), 1);
	GenerateTriadic(op_feq, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateFne(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_feq)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_feq)->amclass3, node->p[1]->GetNaturalSize(), 1);
	GenerateTriadic(op_feq, 0, ap3, ap1, ap2);
	GenerateTriadic(op_xor, 0, ap3, ap3, MakeImmediate(1));
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateFlt(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_flt)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_flt)->amclass3, node->p[1]->GetNaturalSize(), 1);
	GenerateTriadic(op_flt, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateFle(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_fle)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_fle)->amclass3, node->p[1]->GetNaturalSize(), 1);
	GenerateTriadic(op_fle, 0, ap3, ap1, ap2);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateFgt(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_fle)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_fle)->amclass3, node->p[1]->GetNaturalSize(), 1);
	GenerateTriadic(op_fle, 0, ap3, ap1, ap2);
	GenerateTriadic(op_xor, 0, ap3, ap3, MakeImmediate(1));
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

Operand* RiscvCodeGenerator::GenerateFge(ENODE* node)
{
	Operand* ap1, * ap2, * ap3;

	ap3 = GetTempRegister();
	ap1 = cg.GenerateExpression(node->p[0], Instruction::Get(op_flt)->amclass2, node->p[0]->GetNaturalSize(), 1);
	ap2 = cg.GenerateExpression(node->p[1], Instruction::Get(op_flt)->amclass3, node->p[1]->GetNaturalSize(), 1);
	GenerateTriadic(op_flt, 0, ap3, ap1, ap2);
	GenerateTriadic(op_xor, 0, ap3, ap3, MakeImmediate(1));
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	return (ap3);
}

// Convert a value to a Boolean.
Operand* RiscvCodeGenerator::MakeBoolean(Operand* ap)
{
	Operand* ap1;
	OCODE* ip;

	ap1 = GetTempRegister();
	ip = currentFn->pl.tail;
	if (ip->opcode & 0x8000)
		return (ap1);
	GenerateTriadic(op_sltu, 0, ap1, ap, MakeImmediate(1));
	GenerateTriadic(op_xor, 0, ap1, ap1, MakeImmediate(1));
	ap1->isBool = true;
	return (ap1);
}

//
// Generate a jump to label if the node passed evaluates to
// a true condition.
//
void RiscvCodeGenerator::GenerateTrueJump(ENODE* node, int label, unsigned int prediction)
{
	Operand* ap1, * ap2;
	int lab0;
	int siz1;

	if (node == 0)
		return;
	switch (node->nodetype)
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
		ap1 = GenerateExpression(node, am_reg, siz1, 1);
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


// Generate code to execute a jump to label if the expression
// passed is false.
//
void RiscvCodeGenerator::GenerateFalseJump(ENODE* node, int label, unsigned int prediction)
{
	Operand* ap, * ap1;
	int siz1;
	int lab0;

	if (node == (ENODE*)NULL)
		return;
	switch (node->nodetype)
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
		GenerateFalseJump(node->p[0], label, prediction ^ 1);
		GenerateFalseJump(node->p[1], label, prediction ^ 1);
		break;
	case en_lor_safe:
		if (GenerateBranch(node, op_nor, label, 0, prediction, true))
			break;
	case en_lor:
		lab0 = nextlabel++;
		GenerateTrueJump(node->p[0], lab0, prediction);
		GenerateFalseJump(node->p[1], label, prediction ^ 1);
		GenerateLabel(lab0);
		break;
	case en_not:
		GenerateTrueJump(node->p[0], label, prediction);
		break;
	default:
		siz1 = node->GetNaturalSize();
		ap = GenerateExpression(node, am_reg, siz1, 1);
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

void RiscvCodeGenerator::GenerateCall(Operand* tgt)
{
	GenerateDiadic(op_jal, 0, makereg(regLR), tgt);
}

void RiscvCodeGenerator::GenerateLocalCall(Operand* tgt)
{
	GenerateDiadic(op_jal, 0, makereg(regLR), tgt);
}

void RiscvCodeGenerator::GenerateMillicodeCall(Operand* tgt) {
	currentFn->doesJAL = true;
	currentFn->IsLeaf = false;
	GenerateDiadic(op_jal, 0, makereg(regLR), tgt);
};

void RiscvCodeGenerator::GenerateDirectJump(ENODE* node, Operand* ap, Function* sym, int flags, int lab)
{
	char buf[500];

	if (sym && sym->IsLeaf) {
		sprintf_s(buf, sizeof(buf), "%s_ip", sym->sym->name->c_str());
		if (flags & am_jmp)
			GenerateMonadic(sym->sym->storage_class == sc_static ? op_bra : op_bra, 0, MakeDirect(node->p[0]));
		else
			GenerateDiadic(sym->sym->storage_class == sc_static ? op_jal : op_jal, 0, makereg(regLR), MakeDirect(node->p[0]));
		currentFn->doesJAL = true;
	}
	else if (sym) {
		if (flags & am_jmp)
			GenerateMonadic(sym->sym->storage_class == sc_static ? op_bra : op_bra, 0, MakeDirect(node->p[0]));
		else
			GenerateDiadic(sym->sym->storage_class == sc_static ? op_jal : op_jal, 0, makereg(regLR), MakeDirect(node->p[0]));
		currentFn->doesJAL = true;
	}
	else {
		if (flags & am_jmp)
			GenerateMonadic(op_bra, 0, MakeDirect(node->p[0]));
		else
			GenerateDiadic(op_jal, 0, makereg(regLR), MakeDirect(node->p[0]));
		currentFn->doesJAL = true;
	}
	GenerateMonadic(op_bex, 0, MakeDataLabel(throwlab, regZero));
	if (lab)
		GenerateLabel(lab);
//	LinkAutonew(node);
}

void RiscvCodeGenerator::GenerateIndirectJump(ENODE* node, Operand* ap, Function* sym, int flags, int lab)
{
	Operand* ap1;

	ap->MakeLegal(am_reg, sizeOfWord);
	GenerateDiadic(op_ld, 0, ap, MakeIndirect(ap->preg));
	if (sym && sym->IsLeaf) {
		if (flags & am_jmp)
			GenerateMonadic(op_jmp, 0, makereg(ap->preg));
		else
			GenerateDiadic(op_jal, 0, makereg(regLR), makereg(ap->preg));
		currentFn->doesJAL = true;
	}
	else {
		if (flags & am_jmp)
			GenerateMonadic(op_jmp, 0, makereg(ap->preg));
		else
			GenerateDiadic(op_jal, 0, makereg(regLR), makereg(ap->preg));
		currentFn->doesJAL = true;
	}
	GenerateMonadic(op_bex, 0, MakeDataLabel(throwlab, regZero));
	if (lab)
		GenerateLabel(lab);
//	LinkAutonew(node);
}

void RiscvCodeGenerator::GenerateReturnAndDeallocate(int64_t amt)
{
	GenerateAddOnto(makereg(regSP), MakeImmediate(amt));
	GenerateDiadic(op_jal, 0, makereg(regZero), makereg(regLR));
}

void RiscvCodeGenerator::GenerateReturnInsn()
{
	GenerateDiadic(op_jal, 0, makereg(regZero), makereg(regLR));
}

void RiscvCodeGenerator::GenerateInterruptReturn(Function* func)
{
	switch (func->operating_mode) {
	case 0: GenerateZeradic(op_uret); break;
	case 1: GenerateZeradic(op_sret); break;
	case 2: GenerateZeradic(op_hret); break;
	case 3: GenerateZeradic(op_mret); break;
	}
}

void RiscvCodeGenerator::GenerateInterruptSave(Function* func)
{
	int nn, kk;
	int64_t tsm = func->int_save_mask;

	nn = popcnt(tsm);
	// Allocate storage for registers on stack
	GenerateSubtractFrom(makereg(regSP), MakeImmediate(nn * sizeOfWord));
	for (kk = nn = 0; nn < cpu.nregs; nn++) {
		if (tsm & 1) {
			GenerateStore(makereg(nn), MakeIndexed(kk * sizeOfWord, regSP), sizeOfWord);
			kk++;
		}
		tsm = tsm >> 1;
	}
	if (sp_init) {
		GenerateLoadConst(MakeImmediate(sp_init), makereg(regSP));
	}
	/*
	if (stkname) {
		GenerateDiadic(op_lea, 0, makereg(SP), MakeStringAsNameConst(stkname,dataseg));
		GenerateTriadic(op_ori, 0, makereg(SP), makereg(SP), MakeImmediate(0xFFFFF00000000000LL));
	}
	*/
}

void RiscvCodeGenerator::GenerateInterruptLoad(Function* func)
{
	int nn, kk;
	int64_t tsm = func->int_save_mask;

	nn = popcnt(tsm);
	for (kk = nn = 0; nn < cpu.nregs; nn++) {
		if (tsm & 1) {
			GenerateLoad(makereg(nn), MakeIndexed(kk * sizeOfWord, regSP), sizeOfWord, sizeOfWord);
			kk++;
		}
		tsm = tsm >> 1;
	}
	// Deallocate stack storage
	GenerateAddOnto(makereg(regSP), MakeImmediate(kk * sizeOfWord));
}

void RiscvCodeGenerator::GenerateLoadAddress(Operand* ap3, Operand* ap1)
{
	GenerateDiadic(op_la, 0, ap3, ap1);
}

void RiscvCodeGenerator::GenerateLoadFloat(Operand* ap3, Operand* ap1, int ssize, int size, Operand* mask)
{
	if (ap3->typep == &stdflt) {
		GenerateTriadic(op_flw, 0, ap3, ap1, mask);
	}
	else if (ap3->typep == &stddouble) {
		GenerateTriadic(op_fld, 0, ap3, ap1, mask);
	}
	else if (ap3->typep == &stdquad) {
		GenerateTriadic(op_flq, 0, ap3, ap1, mask);
	}
	else if (ap3->typep == &stdsingle) {
		GenerateTriadic(op_flw, 0, ap3, ap1, mask);
	}
	//	else
	//		throw C64PException(ERR_UNKNOWN_FLOAT_TYPE, 0);
}

void RiscvCodeGenerator::GenerateLoad(Operand* ap3, Operand* ap1, int ssize, int size, Operand* mask)
{
	if (ap3->typep == &stdposit) {
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
	else if (ap3->typep == &stdvector) {
		GenerateTriadic(op_loadv, 0, ap3, ap1, mask);
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
		case 1:	GenerateTriadic(op_lbu, 0, ap3, ap1, mask); break;
		case 2:	GenerateTriadic(op_lhu, 0, ap3, ap1, mask); break;
		case 4:	GenerateTriadic(op_lwu, 0, ap3, ap1, mask); break;
		case 8: GenerateTriadic(op_ld, 0, ap3, ap1, mask); break;
		}
	}
	else {
		switch (size) {
		case 0: GenerateTriadic(op_load, 0, ap3, ap1, mask); break;
		case 1:	GenerateTriadic(op_lb, 0, ap3, ap1, mask); break;
		case 2:	GenerateTriadic(op_lh, 0, ap3, ap1, mask); break;
		case 4:	GenerateTriadic(op_lw, 0, ap3, ap1, mask); break;
		case 8:	GenerateTriadic(op_ld, 0, ap3, ap1, mask); break;
		}
	}
	ap3->memref = true;
	ap3->memop = ap1->Clone();
}

void RiscvCodeGenerator::GenerateStore(Operand* ap1, Operand* ap3, int size, Operand* mask)
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
	if (ap3->typep == &stdposit) {
		GenerateTriadic(op_sto, 0, ap1, ap3, mask);
	}
	else if (ap1->typep == &stdvector)
		GenerateTriadic(op_sv, 0, ap1, ap3, mask);
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
		case 1: GenerateTriadic(op_sb, 0, ap1, ap3, mask); break;
		case 2: GenerateTriadic(op_sh, 0, ap1, ap3, mask); break;
		case 4: GenerateTriadic(op_sw, 0, ap1, ap3, mask); break;
		case 8:	GenerateTriadic(op_sd, 0, ap1, ap3, mask); break;
		default:
			;
		}
	}
}

void RiscvCodeGenerator::GenerateLoadConst(Operand* ap1, Operand* ap2)
{
	Operand* ap3;

	if (ap1->isPtr) {
		ap3 = ap1->Clone();
		ap3->mode = am_direct;
		GenerateLoadAddress(ap2, ap3);
		//if (!compiler.os_code) {
		//	switch (ap1->segment) {
		//	case tlsseg:		GenerateTriadic(op_base, 0, ap2, ap2, MakeImmediate(8));	break;
		//	case rodataseg:	GenerateTriadic(op_base, 0, ap2, ap2, MakeImmediate(12));	break;
		//	}
		//}
	}
	else {
		OCODE* ip = nullptr;
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
				if (!ap1->offset->i128.IsNBit(12)) {
					if (((ap1->offset->i >> 11) & 1)==1)
						ip = GenerateDiadic(op_lui, 0, ap2, MakeImmediate((ap1->offset->i >> 12)+1));
					else
						ip = GenerateDiadic(op_lui, 0, ap2, MakeImmediate(ap1->offset->i >> 12));
					GenerateAddOnto(ap2, MakeImmediate(ap1->offset->i & 0xfffLL));
				}
				else
					GenerateTriadic(op_add, 0, ap2, makereg(regZero), MakeImmediate(ap1->offset->i128.low & 0xffffLL));
			}
		}
		if (ip)
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

// push the operand expression onto the stack.
// Structure variables are represented as an address in a register and arrive
// here as autocon nodes if on the stack. If the variable size is greater than
// 8 we assume a structure variable and we assume we have the address in a reg.
// Returns: number of stack words pushed.
//
int RiscvCodeGenerator::PushArgument(ENODE* ep, int regno, int stkoffs, bool* isFloat, int* push_count, bool large_argcount)
{
	Operand* ap, * ap1, * ap2, * ap3;
	int nn = 0;
	int sz;

	*isFloat = false;
	*push_count = 0;
	if (ep == nullptr) {
		return (0);
	}
	switch (ep->etype) {
	case bt_quad:	sz = sizeOfFPQ; break;
	case bt_double:	sz = sizeOfFPD; break;
	case bt_float:	sz = sizeOfFPD; break;
	case bt_posit:	sz = sizeOfPosit; break;
	default:	sz = sizeOfWord; break;
	}
	if (ep->tp) {
		if (ep->tp->IsFloatType())
			ap = cg.GenerateExpression(ep, am_reg, sizeOfFPQ, 1);
		else if (ep->tp->IsPositType())
			ap = cg.GenerateExpression(ep, am_preg, sizeOfPosit, 1);
		else
			ap = cg.GenerateExpression(ep, am_reg | am_imm, ep->GetNaturalSize(), 1);
	}
	else if (ep->etype == bt_quad)
		ap = cg.GenerateExpression(ep, am_reg, sz, 1);
	else if (ep->etype == bt_double)
		ap = cg.GenerateExpression(ep, am_reg, sz, 1);
	else if (ep->etype == bt_float)
		ap = cg.GenerateExpression(ep, am_reg, sz, 1);
	else if (ep->etype == bt_posit)
		ap = cg.GenerateExpression(ep, am_reg, sz, 1);
	else
		ap = cg.GenerateExpression(ep, am_reg | am_imm, ep->GetNaturalSize(), 1);
	switch (ap->mode) {
	case am_fpreg:
		*isFloat = true;
	case am_preg:
	case am_reg:
	case am_imm:
		/*
						nn = roundWord(ep->esize);
						if (nn > 8) {// && (ep->tp->type==bt_struct || ep->tp->type==bt_union)) {           // structure or array ?
								ap2 = GetTempRegister();
								GenerateTriadic(op_subui,0,makereg(regSP),makereg(regSP),MakeImmediate(nn));
								GenerateDiadic(op_mov, 0, ap2, makereg(regSP));
								GenerateMonadic(op_push,0,MakeImmediate(ep->esize));
								GenerateMonadic(op_push,0,ap);
								GenerateMonadic(op_push,0,ap2);
								GenerateMonadic(op_bsr,0,MakeStringAsNameConst("memcpy_"));
								GenerateTriadic(op_addui,0,makereg(regSP),makereg(regSP),MakeImmediate(24));
								GenerateMonadic(op_push,0,ap2);
								ReleaseTempReg(ap2);
								nn = nn >> 3;
						}
						else {
		*/
		if (regno) {
			GenerateMonadic(op_hint, 0, MakeImmediate(1));
			if (ap->mode == am_imm) {
				GenerateDiadic(cpu.ldi_op, 0, makereg(regno & 0x7fff), ap);
				if (regno & 0x8000) {
					GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(sizeOfWord));
					nn = 1;
				}
			}
			else if (ap->mode == am_fpreg) {
				*isFloat = true;
				GenerateDiadic(cpu.mov_op, 0, makefpreg(regno & 0x7fff), ap);
				if (regno & 0x8000) {
					GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(sz));
					nn = sz / sizeOfWord;
				}
			}
			else {
				//ap->preg = regno & 0x7fff;
				GenerateDiadic(cpu.mov_op, 0, makereg(regno & 0x7fff), ap);
				if (regno & 0x8000) {
					GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(sizeOfWord));
					nn = 1;
				}
			}
		}
		else {
			if (cpu.SupportsPush && !large_argcount) {
				if (ap->mode == am_imm) {	// must have been a zero
					if (ap->offset->i == 0)
						GenerateMonadic(op_push, 0, makereg(regZero));
					else {
						ap3 = GetTempRegister();
						GenerateLoadConst(ap, ap3);
						GenerateMonadic(op_push, 0, ap3);
						ReleaseTempReg(ap3);
					}
					nn = 1;
					*push_count = 1;
				}
				else {
					if (ap->typep == &stddouble)
					{
						*isFloat = true;
						GenerateMonadic(op_push, 0, ap);
						nn = sz / sizeOfWord;
						nn = 1;
						*push_count = 1;
					}
					else {
						regs[ap->preg].IsArg = true;
						GenerateMonadic(op_push, 0, ap);
						nn = 1;
						*push_count = 1;
					}
				}
			}
			else {
				if (ap->mode == am_imm) {	// must have been a zero
					ap3 = nullptr;
					if (ap->offset->i != 0) {
						ap3 = GetTempRegister();
						regs[ap3->preg].IsArg = true;
						GenerateLoadConst(ap, ap3);
						cg.GenerateStore(ap3, MakeIndexed(stkoffs, regSP), sizeOfWord);
						ReleaseTempReg(ap3);
					}
					else {
						cg.GenerateStore(makereg(0), MakeIndexed(stkoffs, regSP), sizeOfWord);
					}
					nn = 1;
				}
				else {
					// For aggregate types larger than the word size, a pointer to a buffer
					// is pushed instead of the actual value. The buffer will have been 
					// allocated by the caller.
					// What needs to be done is copy the aggregate to the buffer then push
					// the buffer address.
					if (ap->tp->IsAggregateType() && ap->tp->size > sizeOfWord) {
						ap2 = GetTempRegister();
						GenerateDiadic(op_lea, 0, ap2, MakeIndexed(ep->stack_offs, regSP));	// push target
						cg.GenerateStore(ap2, MakeIndexed(sizeOfWord, regSP), sizeOfWord);
						ReleaseTempRegister(ap2);
						cg.GenerateStore(ap, MakeIndexed((int64_t)0, regSP), sizeOfWord);		// and source
						ap3 = GetTempRegister();
						GenerateLoadConst(MakeImmediate(ap->tp->size), ap3);								// and size
						cg.GenerateStore(ap3, MakeImmediate(ap->tp->size), sizeOfWord);
						ReleaseTempRegister(ap3);
						GenerateMonadic(op_bsr, 0, MakeStringAsNameConst((char*)"__aacpy", codeseg));	// call copy helper
						ap1 = GetTempRegister();
						GenerateLoadConst(MakeImmediate(ep->stack_offs), ap1);							// and size
						cg.GenerateStore(ap1, MakeIndexed(stkoffs, regSP), sizeOfWord);
						ReleaseTempRegister(ap1);
					}
					else if (ap->tp->IsFloatType()) {
						*isFloat = true;
						cg.GenerateStore(ap, MakeIndexed(stkoffs, regSP), sizeOfWord);
						nn = 1;// sz / sizeOfWord;
					}
					else if (ap->type == bt_posit) {
						cg.GenerateStore(ap, MakeIndexed(stkoffs, regSP), sizeOfWord);
						nn = 1;
					}
					else if (ap->type == bt_vector) {
						cg.GenerateStore(ap, MakeIndexed(stkoffs, regSP), sizeOfWord);
						nn = 4;
					}
					else {
						regs[ap->preg].IsArg = true;
						cg.GenerateStore(ap, MakeIndexed(stkoffs, regSP), sizeOfWord);
						nn = 1;
					}
				}
			}
		}
		//        }
		break;
	}
	ReleaseTempReg(ap);
	return (nn);
}

// Store entire argument list onto stack
// large_arg_count is used only if push is supported. It is less expensive to
// use a push instruction rather than subtracting from the sp and using stores
// if there are only a small number of arguments (<3).
//
int RiscvCodeGenerator::PushArguments(Function* sym, ENODE* plist)
{
	TypeArray* ta = nullptr;
	int i, sum;
	OCODE* ip;
	ENODE* p;
	ENODE* pl[100];
	int nn, maxnn, kk, pc;
	int push_count;
	bool isFloat = false;
	bool sumFloat;
	bool o_supportsPush;
	bool large_argcount = false;
	Symbol** sy = nullptr;
	int64_t stkoffs;
	int regno;

	sum = 0;
	push_count = 0;
	if (sym)
		ta = sym->GetProtoTypes();

	sumFloat = false;
	ip = currentFn->pl.tail;

	// Allocate stack space for arguments.
	if (sym) {
		if (sym->arg_space > 0)
			GenerateSubtractFrom(makereg(regSP), MakeImmediate(sym->arg_space));
		sy = sym->params.GetParameters();
	}

	// Capture the parameter list. It is needed in the reverse order.
	for (nn = 0, p = plist; p != NULL; p = p->p[1], nn++) {
		pl[nn] = p->p[0];
	}
	// ToDo: fix order of push instructions, they are coming out in the reverse order
	// to what is needed. So always use store instructions for now.
	if (nn > 4)
		large_argcount = true;
	large_argcount = true;	// disable for now
	maxnn = nn;
	for (nn = large_argcount ? nn - 1 : 0, i = 0; large_argcount ? nn >= 0 : nn < maxnn; large_argcount ? nn-- : nn++, i++)
	{
		if (pl[nn]->etype == bt_pointer) {
			if (pl[nn]->tp->btpp == nullptr) {
				sum++;
				continue;
			}
			if (pl[nn]->tp->btpp->type == bt_ichar || pl[nn]->tp->btpp->type == bt_iuchar)
				continue;
		}
		//		sum += GeneratePushParameter(pl[nn],ta ? ta->preg[ta->length - i - 1] : 0,sum*8);
// Variable argument list functions may cause the type array values to be
// exhausted before all the parameters are pushed. So, we check the parm number.
		if (pl[nn]->etype == bt_none) {	// was there an empty parameter?
			if (sy != nullptr) {
				if (sy[nn]) {
					sum += PushArgument(sy[nn]->defval, ta ? (i < ta->length ? ta->preg[i] : 0) : 0, sy[nn] ? sy[nn]->value.i : sum * sizeOfWord, &isFloat, &pc, large_argcount);
					push_count += pc;
				}
				else {
					error(ERR_MISSING_PARM);
				}
			}
		}
		else {
			if (sy != nullptr) {
				if (sy[nn]) {
					regno = ta ? (i < ta->length ? ta->preg[i] : 0) : 0;
					stkoffs = sy[nn] ? sy[nn]->value.i : sum * sizeOfWord;
					sum += PushArgument(pl[nn], regno, stkoffs, &isFloat, &pc, large_argcount);
					push_count += pc;
				}
				else {
					error(ERR_MISSING_PARM);
				}
			}
			else {
				sum += PushArgument(pl[nn], ta ? (i < ta->length ? ta->preg[i] : 0) : 0, sum * sizeOfWord, &isFloat, &pc, large_argcount);
				push_count += pc;
			}
		}
		sumFloat |= isFloat;
		//		plist = plist->p[1];
	}
	/*
	if (sum == 0 || !large_argcount)
		ip->fwd->MarkRemove();
	else
		ip->fwd->oper3 = MakeImmediate(sum*sizeOfWord);
	*/
	/*
	if (!sumFloat) {
		o_supportsPush = cpu.SupportsPush;
		cpu.SupportsPush = false;
		currentFn->pl.tail = ip;
		currentFn->pl.tail->fwd = nullptr;
		i = maxnn-1;
		for (nn = 0; nn < maxnn; nn++, i--) {
			if (pl[nn]->etype == bt_pointer)
				if (pl[nn]->tp->btpp->type == bt_ichar || pl[nn]->tp->btpp->type == bt_iuchar)
					continue;
			if (pl[nn]->etype == bt_none) {	// was there an empty parameter?
				if (sy == nullptr && sym)
					sy = sym->params.GetParameters();
				if (sy)
					PushArgument(sy[nn]->defval, ta ? (i < ta->length ? ta->preg[i] : 0) : 0, sum * sizeOfWord, &isFloat);
			}
			else
				PushArgument(pl[nn], ta ? (i < ta->length ? ta->preg[i] : 0) : 0, sum * 8, &isFloat);
		}
		cpu.SupportsPush = o_supportsPush;
	}
	*/
	if (ta)
		delete ta;
	if (sy)
		delete[] sy;
	return (sum);
}

// Pop parameters off the stack

void RiscvCodeGenerator::PopArguments(Function* fnc, int howMany, bool isPascal)
{
	if (howMany != 0) {
		if (fnc) {
			if (!fnc->IsPascal)
				GenerateAddOnto(makereg(regSP), MakeImmediate(fnc->arg_space));
			else if (howMany - fnc->NumFixedAutoParms > 0)
				GenerateAddOnto(makereg(regSP), MakeImmediate(fnc->arg_space - (fnc->NumFixedAutoParms * sizeOfWord)));
		}
		else {
			error(ERR_UNKNOWN_FN);
			if (!isPascal)
				GenerateAddOnto(makereg(regSP), MakeImmediate(howMany * sizeOfWord));
		}
	}
}


