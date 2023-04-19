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

extern int     breaklab;
extern int     contlab;
extern int     retlab;
extern int		throwlab;

int64_t* Statement::GetCasevals()
{
	int nn;
	int64_t* bf;
	int64_t buf[257];

	NextToken();
	nn = 0;
	do {
		buf[nn] = GetIntegerExpression((ENODE**)NULL,nullptr,0).low;
		nn++;
		if (lastst != comma)
			break;
		NextToken();
	} while (nn < 256);
	if (nn == 256)
		error(ERR_TOOMANYCASECONSTANTS);
	bf = (int64_t*)xalloc(sizeof(int64_t) * (nn + 1));
	bf[0] = nn;
	for (; nn > 0; nn--)
		bf[nn] = buf[nn - 1];
	needpunc(colon, 35);
	return (bf);
}

Statement *Statement::ParseCase()
{
	Statement *snp;
	Statement *head, *tail;
	int64_t buf[256];
	int nn;
	int64_t *bf;

	snp = MakeStatement(st_case, false);
	snp->s1 = nullptr;
	snp->s2 = nullptr;
	nn = 0;
	bf = GetCasevals();
	snp->casevals = (int64_t *)bf;
	if (lastst != kw_case && lastst != kw_default)
		snp->s1 = Parse();
	snp->s2 = nullptr;
	snp->label = (int64_t*)nextlabel++;
	return (snp);
}

Statement* Statement::ParseDefault()
{
	Statement* snp;

	snp = MakeStatement(st_default, true);
	snp->s2 = nullptr;
	snp->stype = st_default;
	needpunc(colon, 35);
	snp->s1 = Parse();
	snp->label = (int64_t*)nextlabel++;
	return (snp);
}

int Statement::CheckForDuplicateCases()
{
	Statement *head;
	Statement *top, *cur, *def;
	int cnt, cnt2;
	static int64_t buf[1000];
	int ndx;

	ndx = 0;
	head = this;
	cur = top = head;
	for (top = head; top != (Statement *)NULL; top = top->next)
	{
		if (top->casevals) {
			for (cnt = 1; cnt < top->casevals[0] + 1; cnt++) {
				for (cnt2 = 0; cnt2 < ndx; cnt2++)
					if (top->casevals[cnt] == buf[cnt2])
						return (TRUE);
				if (ndx > 999)
					throw new C64PException(ERR_TOOMANYCASECONSTANTS, 1);
				buf[ndx] = top->casevals[cnt];
				ndx++;
			}
		}
	}

	// Check for duplicate default: statement
	def = nullptr;
	for (top = head; top != (Statement *)NULL; top = top->next)
	{
		if (top->stype == st_default && top->s2 && def)
			return (TRUE);
		if (top->stype == st_default && top->s2)
			def = top->s2;
	}
	return (FALSE);
}

// A switch statement is like a compound statement, it is just a list of statements.

Statement *Statement::ParseSwitch()
{
	Statement *snp;
	Statement *head, *tail;
	bool needEnd = true;

	tail = nullptr;
	snp = MakeStatement(st_switch, true);
	snp->nkd = false;
	snp->contains_label = false;
	iflevel++;
	looplevel++;
	needpunc(openpa, 0);
	if (expression(&(snp->exp), nullptr) == NULL)
		error(ERR_EXPREXPECT);
	if (lastst == semicolon) {
		NextToken();
		if (lastst == kw_naked) {
			NextToken();
			snp->nkd = true;
		}
	}
	needpunc(closepa, 0);
	needpunc(begin, 76);
	head = 0;
	while (lastst != end) {
		if (head == nullptr) {
			head = tail = Parse(&snp->contains_label);
			if (head)
				head->outer = snp;
		}
		else {
			tail->next = Parse(&snp->contains_label);
			if (tail->next != nullptr) {
				tail->next->outer = snp;
				tail = tail->next;
			}
		}
		if (tail == nullptr) break;	// end of file in switch
		tail->next = nullptr;
		if (!needEnd)
			break;
	}
	snp->s1 = head;
	needpunc(end, 77);
	if (snp->s1->CheckForDuplicateCases())
		error(ERR_DUPCASE);
	iflevel--;
	looplevel--;
	return (snp);
}


//=============================================================================
//=============================================================================
// C O D E   G E N E R A T I O N
//=============================================================================
//=============================================================================

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

void Statement::GenerateSwitchLo(Case* cases, Operand* ap, Operand* ap2, int lo, int xitlab, int deflab, bool is_unsigned, bool one_hot, bool last_case)
{
	int lab2;
	Operand* ap3;

	lab2 = nextlabel++;
	if (one_hot && cpu.SupportsBBC) {
		ap3 = MakeImmediate(pwrof2(cases[lo].val));
		GenerateTriadic(op_bbc, 0, ap, ap3, MakeCodeLabel(last_case ? ((deflab > 0) ? deflab : xitlab): lab2));
	}
	else if (cases[lo].val >= -32 && cases[lo].val < 32) {
		ap3 = MakeImmediate(cases[lo].val);
		GenerateTriadic(op_bne, 0, ap, ap3, MakeCodeLabel(last_case ? ((deflab > 0) ? deflab : xitlab) : lab2));
	}
	else {
		GenerateDiadic(cpu.ldi_op, 0, ap2, MakeImmediate(cases[lo].val));
		GenerateTriadic(op_bne, 0, ap, ap2, MakeCodeLabel(last_case ? ((deflab > 0) ? deflab : xitlab) : lab2));
	}
	if (opt_size && cases[lo].done) {
		GenerateMonadic(op_bra, 0, MakeCodeLabel(cases[lo].label));
	}
	else {
//		cases[lo].stmt->GenMixedSource();
		if (!cases[lo].done) {
			cases[lo].done = true;
			cases[lo].stmt->GenerateCase();
			GenerateMonadic(op_bra, 0, MakeCodeLabel(xitlab));
		}
	}
	GenerateLabel(lab2);
	cases[lo].done = true;
}

void Statement::GenerateSwitchLop2(Case* cases, Operand* ap, Operand* ap2, int lo, int xitlab, int deflab, bool is_unsigned, bool one_hot)
{
	if (cases[lo + 2].val == cases[lo + 1].val && opt_size) {	// always false
		GenerateDiadic(cpu.ldi_op, 0, ap2, MakeImmediate(cases[lo + 2].val));
		GenerateTriadic(op_beq, 0, ap, ap2, MakeCodeLabel(cases[lo + 1].label));
		GenerateMonadic(op_bra, 0, MakeCodeLabel(deflab > 0 ? deflab : xitlab));
	}
	else {
		if (opt_size) {
			if (one_hot && cpu.SupportsBBS) {
				if (!cases[lo + 2].done && cpu.SupportsBBC) {
					GenerateTriadic(op_bbc, 0, ap, MakeImmediate(pwrof2(cases[lo + 2].val)), MakeCodeLabel(deflab > 0 ? deflab : xitlab));
//					cases[lo + 2].stmt->GenMixedSource();
//					GenerateLabel(cases[lo + 2].label);
					cases[lo + 2].stmt->GenerateCase();
					GenerateMonadic(op_bra, 0, MakeCodeLabel(xitlab));
					cases[lo + 2].done = true;
				}
				else {
					GenerateTriadic(op_bbs, 0, ap, MakeImmediate(pwrof2(cases[lo + 2].val)), MakeCodeLabel(cases[lo + 2].label));
					GenerateMonadic(op_bra, 0, MakeCodeLabel(deflab > 0 ? deflab : xitlab));
				}
			}
			else {
				if (cases[lo + 2].val >= -32 && cases[lo + 2].val < 32) {
					GenerateTriadic(op_beq, 0, ap, MakeImmediate(cases[lo + 2].val), MakeCodeLabel(cases[lo + 2].label));
				}
				else {
					GenerateDiadic(cpu.ldi_op, 0, ap2, MakeImmediate(cases[lo + 2].val));
					GenerateTriadic(op_beq, 0, ap, ap2, MakeCodeLabel(cases[lo + 2].label));
				}
				GenerateMonadic(op_bra, 0, MakeCodeLabel(deflab > 0 ? deflab : xitlab));
			}
		}
		else {
			if (one_hot && cpu.SupportsBBC) {
				GenerateTriadic(op_bbc, 0, ap, MakeImmediate(pwrof2(cases[lo + 2].val)), MakeCodeLabel(deflab > 0 ? deflab : xitlab));
			}
			else {
				GenerateDiadic(cpu.ldi_op, 0, ap2, MakeImmediate(cases[lo + 2].val));
				GenerateTriadic(op_bne, 0, ap, ap2, MakeCodeLabel(deflab > 0 ? deflab : xitlab));
			}
		}
	}
	if (!cases[lo + 2].done) {
		//		cases[lo + 2].stmt->GenMixedSource();
		//		GenerateLabel(cases[lo + 2].label);
		if (!cases[lo + 2].done) {
			cases[lo + 2].done = true;
			cases[lo + 2].stmt->GenerateCase();
			GenerateMonadic(op_bra, 0, MakeCodeLabel(xitlab));
		}
	}
}


void Statement::GenerateSwitchSearch(Case *cases, Operand* ap, Operand* ap2, int midlab, int lo, int hi, int xitlab, int deflab, bool is_unsigned, bool one_hot)
{
	int hilab, lolab;
	int mid;
	Operand* ap3, * ap4;

	// Less than three cases left, use linear search
	if (hi - lo < 3) {
		GenerateLabel(midlab);
		GenerateSwitchLo(cases, ap, ap2, lo, xitlab, deflab, is_unsigned, one_hot, lo>=hi);
		if (hi-lo > 0)
			GenerateSwitchLo(cases, ap, ap2, lo + 1, xitlab, deflab, is_unsigned, one_hot, lo+1>=hi);
		if (hi-lo > 1)
			GenerateSwitchLo(cases, ap, ap2, lo + 2, xitlab, deflab, is_unsigned, one_hot, true);
		return;
	}
	hilab = nextlabel++;
	lolab = nextlabel++;
	mid = ((lo + hi) >> 1);
	GenerateLabel(midlab);
	if (cases[mid].val >= -32 && cases[mid].val < 32) {
		ap3 = MakeImmediate(cases[mid].val);
		GenerateTriadic(is_unsigned ? op_bgtu : op_bgt, 0, ap, ap3, MakeCodeLabel(hilab));
		GenerateTriadic(is_unsigned ? op_bltu : op_blt, 0, ap, ap3, MakeCodeLabel(lolab));
	}
	else {
		GenerateDiadic(cpu.ldi_op, 0, ap2, MakeImmediate(cases[mid].val));
		GenerateTriadic(is_unsigned ? op_bgtu : op_bgt, 0, ap, ap2, MakeCodeLabel(hilab));
		GenerateTriadic(is_unsigned ? op_bltu : op_blt, 0, ap, ap2, MakeCodeLabel(lolab));
	}
//	GenerateLabel(cases[mid].label);
//	cases[mid].stmt->GenMixedSource();
	cases[mid].done = true;
	cases[mid].stmt->GenerateCase();
	GenerateMonadic(op_bra, 0, MakeCodeLabel(xitlab));
	GenerateSwitchSearch(cases, ap, ap2, hilab, mid, hi, xitlab, deflab, is_unsigned, one_hot);
	GenerateSwitchSearch(cases, ap, ap2, lolab, lo, mid, xitlab, deflab, is_unsigned, one_hot);
}

// Count the number of switch values. There may be more than one value per case.

int Statement::CountSwitchCasevals()
{
	int numcases;
	Statement* stmt;
	int64_t* bf;

	numcases = 0;
	for (stmt = s1; stmt != nullptr; stmt = stmt->next) {
		if (stmt->s2)
			;
		else {
			if (stmt->stype == st_case) {
				bf = (int64_t*)stmt->casevals;
				if (bf != nullptr)
					numcases = numcases + bf[0];
			}
			else if (stmt->stype == st_default)
				numcases++;
		}
	}
	return (numcases);
}

int Statement::CountSwitchCases()
{
	int numcases;
	Statement* stmt;

	numcases = 0;
	for (stmt = s1; stmt != nullptr; stmt = stmt->next) {
		if (stmt->s2)
			;
		else {
			if (stmt->stype == st_case || stmt->stype == st_default) {
				numcases++;
			}
		}
	}
	return (numcases);
}

bool Statement::IsOneHotSwitch()
{
	Statement* stmt;
	int64_t* bf;
	int nn;

	for (stmt = s1; stmt != nullptr; stmt = stmt->next) {
		if (stmt->s2)
			;
		else {
			if (stmt->stype == st_case) {
				bf = (int64_t*)stmt->casevals;
				if (bf != nullptr) {
					for (nn = bf[0]; nn >= 1; nn--) {
						if (pwrof2(bf[nn]) < 0)
							return (false);
					}
				}
			}
		}
	}
	return (true);
}

int Statement::FindNextLabel(int nn)
{
	Statement* stmt, *ps;

	if (s1 == nullptr) {
		// Skip over statements as long as they are cases or default.
		for (stmt = next; stmt && (stmt->stype == st_case || stmt->stype == st_default); stmt = stmt->next) {
			ps = stmt;
			if (stmt->s1 != nullptr)
				break;
		}
		// Find the next case after the list of cases.
		if (stmt) {
			for (stmt = stmt->next; stmt; stmt = stmt->next)
				if (stmt->stype == st_case || stmt->stype == st_default)
					break;
			if (stmt)
				nn = (int)stmt->label;
		}
	}
	return (nn);
}

// A binary search approach is used if there are more than two case statements.

void Statement::GenerateLinearSwitch()
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

	ResetGenerated();

	// Count the number of switch values.
	numcases = CountSwitchCasevals();

	// Fill in an array of case values and corresponding statements.
	cases = new Case [numcases];
	jj = 0;
	defcase = nullptr;
	for (stmt = s1; stmt != nullptr; stmt = stmt->next) {
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
					cases[jj].first = nn==1;
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
	if (exp == NULL) {
		error(ERR_BAD_SWITCH_EXPR);
		return;
	}
	ap = cg.GenerateExpression(exp, am_reg, exp->GetNaturalSize(), 0);
	is_unsigned = ap->isUnsigned;
	//        if( ap->preg != 0 )
	//                GenerateDiadic(op_mov,0,makereg(1),ap);
	//		ReleaseTempRegister(ap);
	if (false && numcases > 5) {
		qsort(&cases[0], numcases, sizeof(Case), case_cmp);
		midlab = nextlabel++;
		deflab = (int)(defcase != nullptr ? defcase->label: /* nextlabel++ :*/ 0);
		ap2 = GetTempRegister();
		GenerateSwitchSearch(cases, ap, ap2, midlab, 0, numcases - 1, breaklab, deflab, is_unsigned, IsOneHotSwitch());
		if (defcase != nullptr) {
			GenerateLabel(deflab);
//			defcase->GenMixedSource();
			defcase->GenerateDefault();
		}
		GenerateLabel(breaklab);
		delete[] cases;
		ReleaseTempRegister(ap2);
		return;
	}

	stmt_cnt = 0;
	for (stmt = this->s1; stmt != nullptr; stmt = stmt->next)
		stmt_cnt++;
	for (stmt = this->s1; stmt != nullptr; stmt = stmt->next) {
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
					if (!stmt->s1->generated) {
						stmt->s1->Generate(2);
						stmt->s1->generated = true;
					}
				}
				else if (stmt->stype == st_default) {
					GenerateLabel((int)cases[kk].label);
					if (!stmt->s1->generated) {
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


// Generate case for a switch statement.
//
void Statement::GenerateCase()
{
	Statement *stmt = this;
	if (this == nullptr)
		return;

	// Still need to generate the label for the benefit of a tabular switch
	// even if there is no code.
	if (true || !generated) {
		stmt->GenMixedSource();
		GenerateLabel((int)stmt->label);
		s1->Generate();
		for (stmt = next; stmt; stmt = stmt->next) {
			if (stmt->stype == st_case || stmt->stype == st_default)
				break;
			stmt->Generate();
		}
		//generated = true;
		GenerateMonadic(op_bra, 0, MakeCodeLabel(breaklab));
	}
}

Operand* CodeGenerator::GenerateCase(ENODE* node, Operand* sw_ap)
{
	Operand* apr, *tmp;
	ENODE* ep, *def;
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
					GenerateTriadic(op_bne, 0, sw_ap, MakeImmediate(buf[kk], 0), MakeCodeLabel(lab));
				apr = GenerateExpression(ep->p[1], am_all, ep->p[1]->esize, 1);
				GenerateDiadic(op_mov, 0, tmp, apr);
				GenerateLabel(lab);
				lab = nextlabel++;
			}
		}
		else if (ep->nodetype == en_default)
			def = ep->p[1];
	}
	if (def) {
		apr = GenerateExpression(def, am_all, def->esize, 1);
		GenerateDiadic(op_mov, 0, tmp, apr);
	}
	return (tmp);
}

Operand* CodeGenerator::GenerateSwitch(ENODE* node)
{
	Operand* ap;

	ap = GenerateExpression(node->p[0], am_reg, node->p[0]->esize, 1);
	ap = GenerateCase(node->p[1], ap);
	return (ap);
}

void Statement::GenerateDefault()
{
	Statement* stmt = this;

	if (this) {
		stmt->GenMixedSource();
		// Still need to generate the label for the benefit of a tabular switch
		// even if there is no code.
		GenerateLabel((int)stmt->label);
		if (s1 != nullptr)
			s1->Generate();
		for (stmt = next; stmt; stmt = stmt->next) {
			if (stmt->stype == st_case || stmt->stype == st_default)
				break;
			stmt->Generate();
		}
	}
}

static int casevalcmp(const void *a, const void *b)
{
	int64_t aa, bb;
	aa = ((scase *)a)->val;
	bb = ((scase *)b)->val;
	if (aa < bb)
		return -1;
	else if (aa == bb)
		return 0;
	else
		return 1;
}

// Compute if the switch should be tabular
// The switch is tabular if the value density is greater than 33%.

bool Statement::IsTabularSwitch(int64_t numcases, int64_t minv, int64_t maxv, bool nkd)
{
	return (numcases * 100 / max((maxv - minv), 1) > 33 && (maxv - minv) > (nkd ? 6 : 10));
}

void Statement::GenerateSwitchStatements()
{
	Statement* stmt;

	for (stmt = s1; stmt; stmt = stmt->next) {
		if (stmt->stype == st_case) {
			GenerateStrLabel(my_strdup((char*)GenerateSwitchTargetName((int)stmt->label).c_str()));
		}
		else if (stmt->stype == st_default) {
			GenerateStrLabel(my_strdup((char*)GenerateSwitchTargetName((int)stmt->label).c_str()));
		}
		if (stmt->s1) stmt->s1->Generate(2);
		stmt->Generate(2);
	}
	GenerateStrLabel(my_strdup((char*)GenerateSwitchTargetName(breaklab).c_str()));
}

std::string Statement::GenerateSwitchTargetName(int labno)
{
	std::string nm(*currentFn->sym->GetFullName());
	char buf[50];

	_itoa_s(labno, buf, sizeof(buf), 10);
	nm.append("_");
	nm.append(buf);
	return (nm);
}

void Statement::GenerateTabularSwitch(int64_t minv, int64_t maxv, Operand* ap, bool HasDefcase, int deflbl, int tablabel)
{
	Operand* ap2;
	Statement* stmt;

	ap2 = GetTempRegister();
	GenerateTriadic(op_sub, 0, ap, ap, MakeImmediate(minv));
	if (maxv - minv >= 0 && maxv - minv < 64)
		GenerateTriadic(op_bgeu, 0, ap, MakeImmediate(maxv - minv + 1), cg.MakeStringAsNameConst((char*)GenerateSwitchTargetName(HasDefcase ? deflbl : breaklab).c_str(),codeseg)); //MakeCodeLabel(HasDefcase ? deflbl : breaklab));
	else {
		GenerateTriadic(op_sltu, 0, ap2, ap, MakeImmediate(maxv - minv - 1));
		GenerateDiadic(op_beqz, 0, ap2, cg.MakeStringAsNameConst((char *)GenerateSwitchTargetName(HasDefcase ? deflbl : breaklab).c_str(),codeseg)); // MakeCodeLabel(HasDefcase ? deflbl : breaklab));
	}
	ReleaseTempRegister(ap2);
	GenerateTriadic(op_asl, 0, ap, ap, MakeImmediate(2));
	GenerateDiadic(op_ldt, 0, ap, compiler.of.MakeIndexedName((char*)GenerateSwitchTargetName(tablabel).c_str(), ap->preg)); // MakeIndexedCodeLabel(tablabel, ap->preg));
	GenerateMonadic(op_jmp, 0, MakeIndirect(ap->preg));
	//GenerateMonadic(op_bra, 0, MakeCodeLabel(defcase ? deflbl : breaklab));
	ReleaseTempRegister(ap);
	GenerateSwitchStatements();
}

void Statement::GenerateNakedTabularSwitch(int64_t minv, Operand* ap, int tablabel)
{
	if (minv != 0)
		GenerateTriadic(op_sub, 0, ap, ap, MakeImmediate(minv));
	Generate4adic(op_sllp, 0, ap, makereg(regZero), ap, MakeImmediate(3));
	GenerateDiadic(cpu.ldo_op, 0, ap, compiler.of.MakeIndexedCodeLabel(tablabel, ap->preg));
	GenerateMonadic(op_jmp, 0, MakeIndirect(ap->preg));
	ReleaseTempRegister(ap);
	GenerateSwitchStatements();
}

void Statement::GetMinMaxSwitchValue(int64_t* minv, int64_t* maxv)
{
	Statement* st;
	int64_t* bf;
	int nn;

	*minv = 0x7FFFFFFFFFFFFFFFLL;
	*maxv = 0LL;
	for (st = s1; st != (Statement*)NULL; st = st->next)
	{
		if (st->s2) {
			;
		}
		else {
			bf = st->casevals;
			if (bf) {
				for (nn = bf[0]; nn >= 1; nn--) {
					*minv = min(bf[nn], *minv);
					*maxv = max(bf[nn], *maxv);
				}
			}
		}
	}
}


//
// Analyze and generate best switch statement.
//
void Statement::GenerateSwitch()
{
	Operand *ap, *ap1, *ap2, *ap3;
	Statement *st, *defcase;
	int oldbreak;
	int tablabel;
	int numcases, numcasevals, maxcasevals;
	int64_t *bf;
	int64_t nn;
	int64_t mm, kk;
	int64_t minv, maxv;
	int deflbl;
	int curlab;
	oldbreak = breaklab;
	breaklab = nextlabel++;
	bf = (int64_t *)label;
	struct scase* casetab;
	OCODE* ip;
	bool is_unsigned;

	st = s1;
	deflbl = 0;
	defcase = nullptr;
	curlab = nextlabel++;

	numcases = CountSwitchCases();
	numcasevals = CountSwitchCasevals();
	GetMinMaxSwitchValue(&minv, &maxv);
	maxcasevals = maxv - minv + 1;
	if (maxcasevals > 1000000) {
		error(ERR_TOOMANYCASECONSTANTS);
		return;
	}
	casetab = new struct scase[maxcasevals + 1];

	// Record case values and labels.
	mm = 0;
	for (st = s1; st != nullptr; st = st->next)
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
	if (IsTabularSwitch((int64_t)numcasevals, minv, maxv, nkd)) {
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
		qsort(&casetab[0], maxcasevals+1, sizeof(struct scase), casevalcmp);
		tablabel = caselit(casetab, maxcasevals+1);
		initstack();
		ap = cg.GenerateExpression(exp, am_reg, exp->GetNaturalSize(), 0);
		is_unsigned = ap->isUnsigned;
		if (nkd)
			GenerateNakedTabularSwitch(minv, ap, tablabel);
		else
			GenerateTabularSwitch(minv, maxv, ap, defcase != nullptr, deflbl, tablabel);
	}
	else {
		GenerateLinearSwitch();
	}
	breaklab = oldbreak;
	delete[] casetab;
}

