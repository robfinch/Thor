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

static int casevalcmp(const void* a, const void* b)
{
	int64_t aa, bb;
	aa = ((scase*)a)->val;
	bb = ((scase*)b)->val;
	if (aa < bb)
		return -1;
	else if (aa == bb)
		return 0;
	else
		return 1;
}

//
// Generate a switch composed of a series of compare and branch instructions.
// Also called a linear switch.
//
int case_cmp(const void* a, const void* b) {
	Case* aa = (Case*)a;
	Case* bb = (Case*)b;
	if (aa->val < bb->val)
		return -1;
	if (aa->val == bb->val)
		return 0;
	return 1;
}

Operand* StatementGenerator::MakeCodeLabel(int lab) {
	return (cg.MakeCodeLabel(lab));
};

Operand* StatementGenerator::MakeImmediate(int64_t i) {
	return (cg.MakeImmediate(i));
};

Operand* StatementGenerator::MakeIndirect(int i) {
	return (cg.MakeIndirect(i));
};


void StatementGenerator::GenerateCompound(Statement* stmt)
{
	Symbol* sp;
	Statement* os;

	os = cg.stmt;
	cg.stmt = stmt;
	sp = stmt->ssyms.headp;
	while (sp) {
		if (sp->fi)
			;
		else
			if (sp->initexp) {
				initstack();
				ReleaseTempRegister(cg.GenerateExpression(sp->initexp->p[1], am_all, 8, 0));
			}
		sp = sp->nextp;
	}
	// Generate statement will process the entire list of statements in
	// the block.
	stmt->s1->Generate();
	cg.stmt = os;
}


//
// Analyze and generate best switch statement.
//
void StatementGenerator::GenerateSwitch(Statement* stmt)
{
	Operand* ap, * ap1, * ap2, * ap3;
	Statement* st, * defcase;
	int oldbreak;
	int tablabel;
	int numcases, numcasevals, maxcasevals;
	int64_t* bf;
	int64_t nn;
	int64_t mm, kk;
	int64_t minv, maxv;
	int deflbl;
	int curlab;
	oldbreak = breaklab;
	breaklab = nextlabel++;
	bf = (int64_t*)stmt->label;
	struct scase* casetab;
	OCODE* ip;
	bool is_unsigned;

	st = stmt->s1;
	deflbl = 0;
	defcase = nullptr;
	curlab = nextlabel++;

	numcases = stmt->CountSwitchCases();
	numcasevals = stmt->CountSwitchCasevals();
	stmt->GetMinMaxSwitchValue(&minv, &maxv);
	maxcasevals = maxv - minv + 1;
	if (maxcasevals > 1000000) {
		error(ERR_TOOMANYCASECONSTANTS);
		return;
	}
	casetab = new struct scase[maxcasevals + 1];

	// Record case values and labels.
	mm = 0;
	for (st = stmt->s1; st != nullptr; st = st->next)
	{
		if (st->stype == st_default) {
			defcase = st;
			deflbl = (int)st->label;
		}
		else {
			bf = st->casevals;
			if (bf) {
				for (nn = bf[0]; nn >= 1; nn--) {
					st->label = (int64_t*)curlab;
					casetab[mm].label = curlab;
					casetab[mm].val = bf[nn];
					casetab[mm].pass = pass;
					mm++;
				}
			}
			curlab = nextlabel++;
		}
	}
	//
	// check case density
	// If there are enough cases
	// and if the case is dense enough use a computed jump
	if (compiler.sg->IsTabularSwitch((int64_t)numcasevals, minv, maxv, stmt->nkd)) {
		if (deflbl == 0)
			deflbl = nextlabel++;
		// Use last entry for default
		casetab[maxcasevals].label = deflbl;
		casetab[maxcasevals].val = maxv + 1;
		casetab[maxcasevals].pass = pass;
		// Inherit mm from above
		for (kk = minv; kk <= maxv; kk++) {
			for (nn = 0; nn < maxcasevals; nn++) {
				if (casetab[nn].val == kk)
					goto j1;
			}
			// value not found
			casetab[mm].val = kk;
			casetab[mm].label = defcase ? deflbl : breaklab;
			casetab[mm].pass = pass;
			mm++;
		j1:;
		}
		qsort(&casetab[0], maxcasevals + 1, sizeof(struct scase), casevalcmp);
		tablabel = caselit(casetab, maxcasevals + 1);
		initstack();
		ap = cg.GenerateExpression(stmt->exp, am_reg, stmt->exp->GetNaturalSize(), 0);
		is_unsigned = ap->isUnsigned;
		if (stmt->nkd)
			GenerateNakedTabularSwitch(stmt, minv, ap, tablabel);
		else
			GenerateTabularSwitch(stmt, minv, maxv, ap, defcase != nullptr, deflbl, tablabel);
	}
	else {
		GenerateLinearSwitch(stmt);
	}
	breaklab = oldbreak;
	delete[] casetab;
}

// Generate the case used in an expression.

Operand* StatementGenerator::GenerateCase(ENODE* node, Operand* sw_ap)
{
	Operand* apr, * tmp;
	ENODE* ep, * def;
	int64_t nn, kk;
	int64_t* buf;
	int lab;

	lab = nextlabel++;
	tmp = GetTempRegister();
	def = nullptr;
	for (ep = node; ep; ep = ep->p[0]) {
		if (ep->nodetype == en_case) {
			buf = (int64_t*)ep->p[2];
			if (buf) {
				nn = buf[0];
				for (kk = 1; kk <= nn; kk++)
					cg.GenerateBne(sw_ap, cg.MakeImmediate(buf[kk], 0), lab);
				apr = cg.GenerateExpression(ep->p[1], am_all, ep->p[1]->esize, 1);
				if (apr->mode == am_reg)
					cg.GenerateMove(tmp, apr);
				else if (apr->mode == am_imm)
					cg.GenerateLoadConst(tmp, apr);
				else
					cg.GenerateLoad(apr, tmp, ep->p[1]->esize, ep->p[1]->esize);
				GenerateLabel(lab);
				lab = nextlabel++;
			}
		}
		else if (ep->nodetype == en_default)
			def = ep->p[1];
	}
	if (def) {
		apr = cg.GenerateExpression(def, am_all, def->esize, 1);
		if (apr->mode == am_reg)
			cg.GenerateMove(tmp, apr);
		else if (apr->mode == am_imm)
			cg.GenerateLoadConst(tmp, apr);
		else
			cg.GenerateLoad(apr, tmp, def->esize, def->esize);
	}
	return (tmp);
}


// Generate switch used in an expression.

Operand* StatementGenerator::GenerateSwitch(ENODE* node)
{
	Operand* ap;

	ap = cg.GenerateExpression(node->p[0], am_reg, node->p[0]->esize, 1);
	ap = GenerateCase(node->p[1], ap);
	return (ap);
}

// A binary search approach is used if there are more than two case statements.

void StatementGenerator::GenerateLinearSwitch(Statement* st)
{
	int xitlab;
	int64_t* bf;
	int nn, jj, kk;
	int lo, hi, mid, midlab, deflab;
	Statement* defcase, * stmt;
	Operand* ap, * ap1, * ap2;
	Statement** stmts;
	Statement* ns;
	int64_t* casevals;
	int numcases;
	int defc;
	int64_t stmt_cnt;
	Case* cases;
	bool is_unsigned;

	xitlab = breaklab;

	st->ResetGenerated();

	// Count the number of switch values.
	numcases = st->CountSwitchCasevals();

	// Fill in an array of case values and corresponding statements.
	cases = new Case[numcases];
	jj = 0;
	defcase = nullptr;
	for (stmt = st->s1; stmt != nullptr; stmt = stmt->next) {
		if (stmt->stype == st_default) {
			defcase = stmt;
			cases[jj].first = false;
			cases[jj].done = false;
			cases[jj].label = (int)stmt->label;
			cases[jj].stmt = stmt;
			cases[jj].val = 0;
			jj++;
		}
		else if (stmt->stype == st_case) {
			bf = stmt->casevals;
			if (bf) {
				for (nn = 1; nn <= bf[0]; nn++) {
					cases[jj].first = nn == 1;
					cases[jj].done = false;
					cases[jj].label = (int)stmt->label;
					cases[jj].stmt = stmt;
					cases[jj].val = bf[nn];
					jj++;
				}
			}
		}
	}

	initstack();
	if (st->exp == NULL) {
		error(ERR_BAD_SWITCH_EXPR);
		return;
	}
	ap = cg.GenerateExpression(st->exp, am_reg, st->exp->GetNaturalSize(), 0);
	is_unsigned = ap->isUnsigned;
	//        if( ap->preg != 0 )
	//                GenerateDiadic(op_mov,0,makereg(1),ap);
	//		ReleaseTempRegister(ap);
	if (false && numcases > 5) {
		qsort(&cases[0], numcases, sizeof(Case), case_cmp);
		midlab = nextlabel++;
		deflab = (int)(defcase != nullptr ? defcase->label : /* nextlabel++ :*/ 0);
		ap2 = GetTempRegister();
		GenerateSwitchSearch(st, cases, ap, ap2, midlab, 0, numcases - 1, breaklab, deflab, is_unsigned, st->IsOneHotSwitch());
		if (defcase != nullptr) {
			GenerateLabel(deflab);
			//			defcase->GenMixedSource();
			GenerateDefault(defcase);
		}
		GenerateLabel(breaklab);
		delete[] cases;
		ReleaseTempRegister(ap2);
		return;
	}

	stmt_cnt = 0;
	for (stmt = st->s1; stmt != nullptr; stmt = stmt->next)
		stmt_cnt++;
	for (stmt = st->s1; stmt != nullptr; stmt = stmt->next) {
		stmt->GenMixedSource();
		// Loop through the case to see if one of the case statements has been
		// hit.
		// If the statment matched a case or default statement then the label needs
		// to be generated, and the comparison code output.
		for (kk = 0; kk < jj; kk++)
		{
			if (stmt == cases[kk].stmt)
			{
				if (stmt->stype == st_case) {
					GenerateLabel((int)stmt->label);
					// Establish which label is being branched to.
					// There is no next case after the last case.
					if (kk == jj - 1) {
						if (cases[kk].stmt->stype == st_default)
							nn = xitlab;
						else
							nn = defcase ? (int)defcase->label : xitlab;
					}
					else
						nn = cases[kk + 1].label;
					nn = stmt->FindNextLabel(nn);
					GenerateTriadic(op_bne, 0, ap, MakeImmediate(cases[kk].val), MakeCodeLabel(nn));
					if (stmt->s1 && !stmt->s1->generated) {
						stmt->s1->Generate(2);
						stmt->s1->generated = true;
					}
				}
				else if (stmt->stype == st_default) {
					GenerateLabel((int)cases[kk].label);
					if (stmt->s1 && !stmt->s1->generated) {
						stmt->s1->Generate(2);
						stmt->s1->generated = true;
					}
				}
			}
		}
		if (!stmt->generated) {
			stmt->Generate(2);
			stmt->generated = true;
		}
	}
	ReleaseTempRegister(ap);
	GenerateLabel(breaklab);
	delete[] cases;
}


void StatementGenerator::GenerateSwitchStatements(Statement* st)
{
	Statement* stmt;

	for (stmt = st->s1; stmt; stmt = stmt->next) {
		switch (stmt->stype) {
		case st_case:
			GenerateLabel((int)stmt->label);
			if (stmt->s1) stmt->s1->Generate(2);
			stmt->Generate(2);
			break;
		case st_default:
			GenerateLabel((int)stmt->label);
			if (stmt->s1) stmt->s1->Generate(2);
			stmt->Generate(2);
			break;
		case st_break:
			GenerateMonadic(op_bra, 0, MakeCodeLabel(breaklab));
			break;
		default:
			stmt->Generate(2);
		}
	}
	GenerateLabel(breaklab);
}

void StatementGenerator::GenerateDefault(Statement* stmt)
{
	if (stmt == nullptr)
		return;

	stmt->GenMixedSource();
	// Still need to generate the label for the benefit of a tabular switch
	// even if there is no code.
	GenerateLabel((int)stmt->label);
	if (stmt->s1 != nullptr)
		stmt->s1->Generate();
	for (stmt = stmt->next; stmt; stmt = stmt->next) {
		if (stmt->stype == st_case || stmt->stype == st_default)
			break;
		stmt->Generate(2);
	}
}

void StatementGenerator::GenerateSwitchLo(Statement* stmt, Case* cases, Operand* ap, Operand* ap2, int lo, int xitlab, int deflab, bool is_unsigned, bool one_hot, bool last_case)
{
	int lab2;
	Operand* ap3;

	lab2 = nextlabel++;
	if (one_hot && cpu.SupportsBBC) {
		ap3 = MakeImmediate(pwrof2(cases[lo].val));
		GenerateTriadic(op_bbc, 0, ap, ap3, MakeCodeLabel(last_case ? ((deflab > 0) ? deflab : xitlab) : lab2));
	}
	else
		cg.GenerateBne(ap, MakeImmediate(cases[lo].val), last_case ? ((deflab > 0) ? deflab : xitlab) : lab2);

	if (opt_size && cases[lo].done)
		GenerateMonadic(op_bra, 0, MakeCodeLabel(cases[lo].label));
	else {
		if (!cases[lo].done) {
			cases[lo].done = true;
			cases[lo].stmt->GenerateCase();
			GenerateMonadic(op_bra, 0, MakeCodeLabel(xitlab));
		}
	}
	GenerateLabel(lab2);
	cases[lo].done = true;
}


void StatementGenerator::GenerateSwitchSearch(Statement* stmt, Case* cases, Operand* ap, Operand* ap2, int midlab, int lo, int hi, int xitlab, int deflab, bool is_unsigned, bool one_hot)
{
	int hilab, lolab;
	int mid;
	Operand* ap3, * ap4;

	// Less than three cases left, use linear search
	if (hi - lo < 3) {
		GenerateLabel(midlab);
		GenerateSwitchLo(stmt, cases, ap, ap2, lo, xitlab, deflab, is_unsigned, one_hot, lo >= hi);
		if (hi - lo > 0)
			GenerateSwitchLo(stmt, cases, ap, ap2, lo + 1, xitlab, deflab, is_unsigned, one_hot, lo + 1 >= hi);
		if (hi - lo > 1)
			GenerateSwitchLo(stmt, cases, ap, ap2, lo + 2, xitlab, deflab, is_unsigned, one_hot, true);
		return;
	}
	hilab = nextlabel++;
	lolab = nextlabel++;
	mid = ((lo + hi) >> 1);
	GenerateLabel(midlab);
	ap3 = cg.MakeImmediate(cases[mid].val);
	if (is_unsigned) {
		cg.GenerateBgtu(ap, ap3, hilab);
		cg.GenerateBltu(ap, ap3, lolab);
	}
	else {
		cg.GenerateBgt(ap, ap3, hilab);
		cg.GenerateBlt(ap, ap3, lolab);
	}
	//	GenerateLabel(cases[mid].label);
	//	cases[mid].stmt->GenMixedSource();
	cases[mid].done = true;
	cases[mid].stmt->GenerateCase();
	GenerateMonadic(op_bra, 0, MakeCodeLabel(xitlab));
	GenerateSwitchSearch(stmt, cases, ap, ap2, hilab, mid, hi, xitlab, deflab, is_unsigned, one_hot);
	GenerateSwitchSearch(stmt, cases, ap, ap2, lolab, lo, mid, xitlab, deflab, is_unsigned, one_hot);
}

