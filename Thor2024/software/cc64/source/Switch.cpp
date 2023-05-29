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
	Statement *head, *tail, *os;
	bool needEnd = false;

	os = cg.stmt;
	tail = nullptr;
	snp = MakeStatement(st_switch, true);
	snp->outer = this;
	snp->nkd = false;
	snp->contains_label = false;
	cg.stmt = snp;
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
	if (lastst == begin) {
		needEnd = true;
		NextToken();
		stmtdepth++;
	}
	//snp->s1 = ParseCompound(false);
	
	head = 0;
	if (!needEnd)
		snp->s1 = snp->Parse(&snp->contains_label);
	else {
		while (lastst != end) {
			if (head == nullptr) {
				head = tail = snp->Parse(&snp->contains_label);
				head->outer = snp;
			}
			else {
				tail->next = snp->Parse(&snp->contains_label);
				if (tail->next != nullptr) {
					tail = tail->next;
				}
				tail->outer = snp;
			}
			if (tail == nullptr) break;	// end of file in switch
			tail->next = nullptr;
			if (!needEnd)
				break;
		}
		snp->s1 = head;
		needpunc(end, 77);
		stmtdepth--;
	}

	if (snp->s1->CheckForDuplicateCases())
		error(ERR_DUPCASE);
	iflevel--;
	looplevel--;
	cg.stmt = os;
	return (snp);
}


//=============================================================================
//=============================================================================
// C O D E   G E N E R A T I O N
//=============================================================================
//=============================================================================

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


// Used by the statement generator.

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

// Dead code - all statements are generated with a switch
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

// Compute if the switch should be tabular
// The switch is tabular if the value density is greater than 33%.

bool StatementGenerator::IsTabularSwitch(int64_t numcases, int64_t minv, int64_t maxv, bool nkd)
{
	return (numcases * 100 / max((maxv - minv), 1) > compiler.table_density && (maxv - minv) > (nkd ? 6 : 10));
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


