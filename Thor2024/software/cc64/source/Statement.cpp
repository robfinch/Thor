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

extern TYP stdbyte;
extern int catchdecl;
Statement *ParseCatchStatement();
int iflevel;
int looplevel;
int foreverlevel;
int loopexit;
Statement *currentStmt;
char *llptr;
extern char *lptr;
extern int isidch(char);

OCODE* gHeadif;
int     breaklab;
int     contlab;
int     retlab;
int		throwlab;

int lastsph;
char *semaphores[20];
char last_rem[132];

extern TYP              stdfunc;
int Statement::throwlab = 0;
int Statement::oldthrow = 0;
int Statement::olderthrow = 0;
bool Statement::lc_in_use = false;

void Statement::ResetGenerated()
{
	if (this) {
		generated = false;
		s1->ResetGenerated();
		s2->ResetGenerated();
	}
}

static Symbol *makeint(char *name)
{
	Symbol *sp;
	TYP *tp;

	sp = Symbol::alloc();
	tp = TYP::Make(bt_int, sizeOfInt);
	tp->sname = new std::string("");
	tp->isUnsigned = FALSE;
	tp->isVolatile = FALSE;
	sp->SetName(name);
	sp->storage_class = sc_auto;
	sp->SetType(tp);
	currentFn->sym->lsyms.insert(sp);
	return (sp);
}

// Usually MakeStatement() is called from a more outer statement, so set the
// outer field. It will be overridden later if needed. It is not always
// correct to set outer here.

Statement* Statement::MakeStatement(int typ, int gt) {
	Statement* stmt;
	stmt = compiler.sf.MakeStatement(typ, gt);
	stmt->name = new std::string("");
	stmt->outer = this;
	return (stmt);
};

Statement *Statement::ParseCheckStatement()
{
	Statement *snp;
	snp = MakeStatement(st_check, TRUE);
	if (expression(&(snp->exp),nullptr) == 0)
		error(ERR_EXPREXPECT);
	needpunc(semicolon, 31);
	return snp;
}

Statement *Statement::ParseWhile()
{
	Statement *snp;
	bool got_pap = false;

	currentFn->UsesPredicate = TRUE;
	snp = MakeStatement(st_while, TRUE);
	snp->predreg = iflevel;
	iflevel++;
	looplevel++;
#ifdef THOR
	if ((iflevel > maxPn - 1) && isThor)
		error(ERR_OUTOFPREDS);
#endif
	if (lastst == openpa) {
		got_pap = true;
		NextToken();
	}
//	if (lastst != openpa)
//		error(ERR_EXPREXPECT);
	if (expression(&(snp->exp),nullptr) == 0)
		error(ERR_EXPREXPECT);
	if (got_pap)
		needpunc(closepa, 13);
	if (lastst == kw_do)
		NextToken();
	snp->s1 = snp->Parse();
	// Empty statements return NULL
	iflevel--;
	looplevel--;
	return (snp);
}

Statement *Statement::ParseUntil()
{
	Statement *snp;

	currentFn->UsesPredicate = TRUE;
	snp = MakeStatement(st_until, TRUE);
	snp->predreg = iflevel;
	iflevel++;
	looplevel++;
#ifdef THOR
	if ((iflevel > maxPn - 1) && isThor)
		error(ERR_OUTOFPREDS);
#endif
	if (lastst != openpa)
		error(ERR_EXPREXPECT);
	else {
		NextToken();
		if (expression(&(snp->exp),nullptr) == 0)
			error(ERR_EXPREXPECT);
		needpunc(closepa, 14);
		snp->s1 = snp->Parse();
		// Empty statements return NULL
	}
	iflevel--;
	looplevel--;
	return snp;
}

Statement *Statement::ParseDo()
{
	Statement *snp;

	currentFn->UsesPredicate = TRUE;
	snp = MakeStatement(st_do, TRUE);
	snp->predreg = iflevel;
	iflevel++;
	looplevel++;
	snp->s1 = snp->Parse();
	snp->lptr2 = my_strdup(inpline);
	// Empty statements return NULL
	switch (lastst) {
	case kw_until:	snp->stype = st_dountil; break;
	case kw_loop:	snp->stype = st_doloop; break;
	case kw_while:	snp->stype = st_dowhile; break;
	default:	snp->stype = st_doonce; break;
	}
	if (lastst != kw_while && lastst != kw_until && lastst != kw_loop)
		error(ERR_WHILEXPECT);
	else {
		NextToken();
		if (snp->stype != st_doloop) {
			if (expression(&(snp->exp),nullptr) == 0)
				error(ERR_EXPREXPECT);
		}
		if (lastst != end)
			needpunc(semicolon, 15);
	}
	iflevel--;
	looplevel--;
	return (snp);
}

Statement *Statement::ParseFor()
{
	Statement *snp;

	currentFn->UsesPredicate = TRUE;
	snp = MakeStatement(st_for, TRUE);
	snp->outer = this;
	snp->predreg = iflevel;
	iflevel++;
	looplevel++;
#ifdef THOR
	if ((iflevel > maxPn - 1) && isThor)
		error(ERR_OUTOFPREDS);
#endif
	needpunc(openpa, 16);
	if (expression(&(snp->initExpr),nullptr) == nullptr)
		snp->initExpr = nullptr;
	needpunc(semicolon, 32);
	if (expression(&(snp->exp),nullptr) == NULL)
		snp->exp = (ENODE *)NULL;
	needpunc(semicolon, 17);
	if (expression(&(snp->incrExpr),nullptr) == NULL)
		snp->incrExpr = (ENODE *)NULL;
	needpunc(closepa, 18);
	snp->s1 = snp->Parse();
	iflevel--;
	looplevel--;
	return (snp);
}

// The forever statement tries to detect if there's an infinite loop and a
// warning is output if there is no obvious loop exit.
// Statements that might exit a loop set the loopexit variable true. These
// statements include throw, return, break, and goto. There are other ways
// to exit a loop that aren't easily detectable (exit() or setjmp).

Statement *Statement::ParseForever()
{
	Statement *snp;
	snp = MakeStatement(st_forever, TRUE);
	snp->stype = st_forever;
	foreverlevel = looplevel;
	snp->s1 = snp->Parse();
	if (loopexit == 0)
		error(ERR_INFINITELOOP);
	// Empty statements return NULL
	return (snp);
}


// Firstcall allocates a hidden static variable that tracks the first time
// the firstcall statement is entered.

Statement *Statement::ParseFirstcall()
{
	Statement *snp;
	Symbol *sp;
	int st;

	dfs.puts("<ParseFirstcall>");
	snp = MakeStatement(st_firstcall, TRUE);
	sp = Symbol::alloc();
	//	sp->SetName(*(new std::string(snp->fcname)));
	sp->storage_class = sc_static;
	sp->value.i = nextlabel++;
	sp->tp = &stdbyte;
	st = lastst;
	lastst = kw_firstcall;       // fake out doinit()
	doinit(sp);
	lastst = st;
	// doinit should set realname
	snp->fcname = my_strdup(sp->realname);
	snp->s1 = Statement::Parse();
	dfs.puts("</ParseFirstcall>");
	return snp;
}

// Brackets must always be used around expressions for "if"
// 
// if (<expr>) [then] ...
// elsif (<expr>) [then] ...
// else ...
//

Statement *Statement::ParseIf()
{
	Statement *snp;

	dfs.puts("<ParseIf>");
	NextToken();
	if (lastst == kw_firstcall)
		return (ParseFirstcall());
	currentFn->UsesPredicate = TRUE;
	snp = MakeStatement(st_if, FALSE);
	snp->predreg = iflevel;
	snp->kw = kw_if;
	iflevel++;
	needpunc(openpa, 18);
	if (expression(&(snp->exp),nullptr) == 0)
		error(ERR_EXPREXPECT);
	if (lastst == semicolon) {
		NextToken();
		snp->prediction = (GetIntegerExpression(NULL,nullptr,0).low & 1) | 2;
	}
	needpunc(closepa, 19);
	if (lastst == kw_then)
		NextToken();
	snp->s1 = snp->Parse();
	if (lastst == kw_else) {
		NextToken();
		snp->s2 = snp->Parse();
		snp->s2->kw = kw_else;
	}
	else if (lastst == kw_elsif) {
		snp->s2 = snp->ParseIf();
		snp->s2->kw = kw_elsif;
	}
	else
		snp->s2 = nullptr;
	iflevel--;
	dfs.puts("</ParseIf>");
	return (snp);
}

Statement *Statement::ParseCatch()
{
	Statement *snp;
	Symbol *sp;
	TYP *tp, *tp1, *tp2;
	ENODE *node;
	static char buf[200];
	AutoDeclaration ad;
	Expression exp(cg.stmt);

	snp = MakeStatement(st_catch, TRUE);
	if (lastst != openpa) {
		snp->label = (int64_t *)NULL;
		snp->num = 99999;
		snp->s1 = snp->Parse();
		return snp;
	}
	needpunc(openpa, 33);
	if (lastst == closepa) {
		NextToken();
		snp->label = (int64_t*)NULL;
		snp->num = 99999;
		snp->s1 = snp->Parse();
		return snp;
	}
	if (lastst == ellipsis) {
		NextToken();
		needpunc(closepa, 33);
		snp->label = (int64_t*)NULL;
		snp->num = 99999;
		snp->s1 = snp->Parse();
		return snp;
	}
	catchdecl = TRUE;
	compiler.ad.Parse(nullptr, &snp->ssyms, snp);
	cseg(ofs);
	catchdecl = FALSE;
	needpunc(closepa, 34);

	if ((sp = snp->ssyms.Find(*ad.declid, false)) == NULL)
		sp = makeint((char *)ad.declid->c_str());
	node = makenode(sp->storage_class == sc_static ? en_labcon : en_autocon, NULL, NULL);
	node->bit_offset = sp->tp->bit_offset;
	node->bit_width = sp->tp->bit_width;
	// nameref looks up the symbol using lastid, so we need to back it up and
	// restore it.
	strncpy_s(buf, sizeof(buf), lastid, 199);
	strncpy_s(lastid, sizeof(lastid), ad.declid->c_str(), sizeof(lastid) - 1);
	exp.nameref(&node, FALSE, sp);
	strcpy_s(lastid, sizeof(lastid), buf);
	snp->s1 = Statement::Parse();
	snp->exp = node;	// save name reference
	if (sp->tp->typeno >= bt_last)
		error(ERR_CATCHSTRUCT);
	snp->num = sp->tp->GetHash();
	return snp;
}

// semi-colon may be omitted if the return is the last statement in a block
// statement.
// 
// return <expr>;

Statement *Statement::ParseReturn()
{
	Statement *snp;

	loopexit = TRUE;
	snp = MakeStatement(st_return, TRUE);
	expression(&(snp->exp),nullptr);
	if (lastst != end)
		needpunc(semicolon, 37);
	return (snp);
}

Statement *Statement::ParseThrow()
{
	Statement *snp;
	TYP *tp;

	currentFn->DoesThrow = TRUE;
	loopexit = TRUE;
	snp = MakeStatement(st_throw, TRUE);
	tp = expression(&(snp->exp),nullptr);
	snp->num = tp->GetHash();
	if (lastst != end)
		needpunc(semicolon, 38);
	if (looplevel == foreverlevel)
		loopexit = TRUE;
	return (snp);
}

Statement *Statement::ParseBreak()
{
	Statement *snp;
	TYP* tp;

	snp = MakeStatement(st_break, TRUE);
	if (lastst != semicolon) {
		currentFn->DoesThrow = TRUE;
		loopexit = TRUE;
		snp = MakeStatement(st_throw, TRUE);
		tp = expression(&(snp->exp),nullptr);
		snp->num = tp->GetHash();
		if (lastst != end)
			needpunc(semicolon, 38);
		if (looplevel == foreverlevel)
			loopexit = TRUE;
		return (snp);
	}
	needpunc(semicolon, 39);
	if (looplevel == foreverlevel)
		loopexit = TRUE;
	return (snp);
}

// if "continue" is the last statement in a block a semicolon is not required.
// 
// continue;

Statement *Statement::ParseContinue()
{
	Statement *snp;

	snp = MakeStatement(st_continue, TRUE);
	if (lastst == id) {
		snp->label = (int64_t*)stringlit(lastid);
		NextToken();
	}
	if (lastst != end)
		needpunc(semicolon, 40);
	else if (lastst == semicolon)
		NextToken();
	return (snp);
}

// "stop" activates the low power stop mode of the processor. It accepts an
// integer to be passed to the stop instruction.
// 
// stop <integer expr>;
//
Statement *Statement::ParseStop()
{
	Statement *snp;

	snp = MakeStatement(st_stop, TRUE);
	snp->num = (int)GetIntegerExpression(NULL,nullptr,0).low;
	if (lastst != end)
		needpunc(semicolon, 43);
	return snp;
}

Statement *Statement::ParseAsm()
{
	static char buf[4000];
	static char buf2[50];
	int nn;
	bool first = true;
	Symbol* sp, * thead, * firsts;
	int sn, lo, tn;
	char* p;

	Statement *snp;
	snp = MakeStatement(st_asm, FALSE);
	while (my_isspace(lastch))
		getch();
	NextToken();
	if (lastst == kw_leafs) {
		currentFn->IsLeaf = FALSE;
		while (my_isspace(lastch))
			getch();
		NextToken();
	}
	if (lastst != begin)
		error(ERR_PUNCT);
	nn = 0;
	do {
		// skip over leading spaces on the line
		getch();
		while (isspace(lastch)) getch();
		if (lastch == '}')
			break;
		if (lastch == '\r' || lastch == '\n')
			continue;
		if (nn < 3500) buf[nn++] = '\n';
		if (nn < 3500) buf[nn++] = '\t';
		if (nn < 3500) buf[nn++] = '\t';
		if (nn < 3500) buf[nn++] = '\t';
		if (nn < 3500) buf[nn++] = lastch;
		while (lastch != '\n') {
			getch();
			if (lastch == '}')
				goto j1;
			if (lastch == '\r' || lastch == '\n')
				break;
			if (nn < 3500) buf[nn++] = lastch;
		}
	} while (lastch != -1 && nn < 3500);
j1:
	if (nn >= 3500)
		error(ERR_ASMTOOLONG);
	buf[nn] = '\0';
	snp->label = (int64_t*)allocx(4000);
	strncpy_s((char*)snp->label, sizeof(snp->label), buf, 4000);
	return (snp);
}

Statement *Statement::ParseTry()
{
	Statement *snp;
	Statement *hd, *tl;

	hd = (Statement *)NULL;
	tl = (Statement *)NULL;
	snp = MakeStatement(st_try, TRUE);
	snp->s1 = snp->Parse();
	if (lastst != kw_catch)
		error(ERR_CATCHEXPECT);
	while (lastst == kw_catch) {
		if (hd == NULL) {
			hd = tl = snp->ParseCatch();
			if (hd)
				hd->outer = snp;
		}
		else {
			tl->next = snp->ParseCatch();
			if (tl->next != NULL) {
				tl = tl->next;
			}
		}
		if (tl == (Statement *)NULL) break;	// end of file in try
		tl->next = (Statement *)NULL;
	}
	snp->s2 = hd;
	return (snp);
}

Statement* Statement::ParseExpression(ENODE** node, Symbol* symi)
{
	Statement* snp;
	Expression exp(cg.stmt);

	dfs.printf("<ParseExpression>\n");
	snp = MakeStatement(st_expr, FALSE);
	if (exp.ParseExpression(node, symi) == NULL) {
		error(ERR_EXPREXPECT);
		NextToken();
	}
	snp->exp = *node;
	if (lastst != end)
		needpunc(semicolon, 44);
	dfs.printf("</ParseExpression>\n");
	return (snp);
}

Statement *Statement::ParseExpression()
{
	ENODE* node;

	return (ParseExpression(&node, nullptr));
}

// Parse a compound statement. Compound statements begin with either the
// keyword "begin" or a starting parenthesis '{' and end with the keyword
// "end" or a closing parentheis '}'. Variables may be declared at the top
// of the compound statment and they will be local to the statement.
//
// {
//	 integer a, b, c;
// ...

Statement *Statement::ParseCompound(bool assign_cf)
{
	Statement *snp;
	Statement *head, *tail;
	Function* fn;
	Statement* os;

	fn = currentFn;
	tail = nullptr;
	snp = MakeStatement(st_compound, false);
	snp->outer = this;
	os = cg.stmt;
	cg.stmt = snp;
	if (assign_cf) {
		snp->fi = currentFn;
		snp->fi->body = snp;
	}
	head = 0;
	if (lastst == colon) {
		NextToken();
		TRACE(printf("Compound <%s>\r\n", lastid);)
			if (strcmp(lastid, "clockbug") == 0)
				printf("clockbug\r\n");
		if (lastst == id) {
			snp->name = new std::string(lastid);
			snp->label = (int64_t*)stringlit(lastid);
		}
		NextToken();
	}
	snp->ssyms.ownerp = currentFn->sym;
	compiler.ad.Parse(currentFn->sym, &snp->ssyms, snp);
	//ad.Parse(nullptr, &snp->ssyms);
	cseg(ofs);
	// Add the first statement at the head of the list.
	if (lastst == kw_prolog) {
		NextToken();
		currentFn->prolog = snp->prolog = snp->Parse();
	}
	if (lastst == kw_epilog) {
		NextToken();
		currentFn->epilog = snp->epilog = snp->Parse();
	}
	if (lastst == kw_prolog) {
		NextToken();
		currentFn->prolog = snp->prolog = snp->Parse();
	}
	if (lastst != end) {
		head = tail = snp->Parse();
		head->outer = snp;
	}
	//else {
	//       head = tail = NewStatement(st_empty,1);
	//	if (head)
	//		head->outer = snp;
	//}
	// Add remaining statements onto the tail of the list.
	while (lastst != end) {
		if (lastst == kw_prolog) {
			NextToken();
			currentFn->prolog = snp->prolog = snp->Parse();
		}
		else if (lastst == kw_epilog) {
			NextToken();
			currentFn->epilog = snp->epilog = snp->Parse();
		}
		else
		{
			if (tail) {
				tail->iexp = compiler.ad.Parse(currentFn->sym, &snp->ssyms, snp);
				//tail->iexp = ad.Parse(nullptr, &snp->ssyms);
				snp->ssyms.ownerp = currentFn->sym;
			}
			tail->next = snp->Parse();
			if (tail->next != nullptr) {
				tail = tail->next;
			}
			tail->outer = snp;
		}
	}
	NextToken();
	snp->s1 = head;
	if (fn)
		currentFn = fn;
	cg.stmt = os;
	return (snp);
}

// parse a label. Labels are identifiers that end with a colon and may be the
// target of a goto statement.
//
// this_label:

Statement *Statement::ParseLabel(bool pt)
{
	Statement *snp;
	Symbol *sp;

	snp = MakeStatement(st_label, FALSE);
	if ((sp = currentFn->sym->lsyms.Find(lastid, false, bt_label)) == NULL) {
		sp = Symbol::alloc();
		sp->SetName(*(new std::string(lastid)));
		sp->storage_class = sc_label;
		sp->tp = TYP::Make(bt_label, 0);
		sp->value.i = nextlabel++;
		currentFn->sym->lsyms.insert(sp);
	}
	else {
		if (sp->storage_class != sc_ulabel)
			error(ERR_LABEL);
		else
			sp->storage_class = sc_label;
	}
	NextToken();       /* get past id */
	if (pt) {
		needpunc(colon, 45);
	}
	if (sp->storage_class == sc_label) {
		snp->label = (int64_t *)sp->value.i;
		snp->next = (Statement *)NULL;
		return (snp);
	}
	return (0);
}

// "goto" transfers the processing to a specific location.

Statement *Statement::ParseGoto()
{
	Statement *snp;
	Symbol *sp;

	NextToken();
	loopexit = TRUE;
	if (lastst != id) {
		error(ERR_IDEXPECT);
		return ((Statement *)NULL);
	}
	snp = MakeStatement(st_goto, FALSE);
	if ((sp = currentFn->sym->lsyms.Find(lastid, false, bt_label)) == NULL) {
		sp = Symbol::alloc();
		sp->SetName(*(new std::string(lastid)));
		sp->value.i = nextlabel++;
		sp->storage_class = sc_ulabel;
		sp->tp = TYP::Make(bt_label, sizeOfWord);
		currentFn->sym->lsyms.insert(sp);
	}
	NextToken();       /* get past label name */
	if (lastst != end)
		needpunc(semicolon, 46);
	if (sp->storage_class != sc_label && sp->storage_class != sc_ulabel)
		error(ERR_LABEL);
	else {
		snp->stype = st_goto;
		snp->label = (int64_t *)sp->value.i;
		snp->next = (Statement *)NULL;
		return (snp);
	}
	return ((Statement *)NULL);
}

Statement* Statement::ParseYield()
{
	Statement* snp;
	Symbol* sp;
	ENODE* ep;
	Expression exp(cg.stmt);

	snp = MakeStatement(st_yield, TRUE);
	expression(&(snp->exp), nullptr);
	if (lastst != end)
		needpunc(semicolon, 37);
	return (snp);
}

Statement *Statement::Parse(ENODE** node, Symbol* symi, bool* has_label)
{
	Statement *snp = nullptr;
	int64_t* bf = nullptr;

	dfs.puts("<Parse>");
	*node = makeinode(en_icon, 0);
	(*node)->tp = &stdint;
j1:
	switch (lastst) {
	case semicolon:
		snp = MakeStatement(st_empty, 1);
		break;
	case begin:
		NextToken();
		stmtdepth++;
		snp = ParseCompound(false);
		stmtdepth--;
		return snp;
	case end:
		return (snp);
	case kw_check:
		snp = ParseCheckStatement();
		break;
		/*
		case kw_prolog:
		snp = NewStatement(st_empty,1);
		currentFn->prolog = Statement::Parse(); break;
		case kw_epilog:
		snp = NewStatement(st_empty,1);
		currentFn->epilog = Statement::Parse(); break;
		*/
	case kw_if: snp = ParseIf(); break;
	case kw_while: snp = ParseWhile(); break;
	case kw_until: snp = ParseUntil(); break;
	case kw_for:   snp = ParseFor();   break;
	case kw_forever: snp = ParseForever(); break;
	case kw_firstcall: snp = ParseFirstcall(); break;
	case kw_return: snp = ParseReturn(); break;
	case kw_break: snp = ParseBreak(); break;
	case kw_goto: snp = ParseGoto(); break;
	case kw_yield: snp = ParseYield(); break;
	case kw_continue: snp = ParseContinue(); break;
	case kw_do:
	case kw_loop: snp = ParseDo(); break;
	case kw_switch: snp = ParseSwitch(); break;
	case kw_fallthru: NextToken(); goto j1;
	case kw_case:	snp = ParseCase(); break;// bf = GetCasevals(); goto j1;
	case kw_default: snp = ParseDefault(); break;
	case kw_try: snp = ParseTry(); break;
	case kw_throw: snp = ParseThrow(); break;
	case kw_stop: snp = ParseStop(); break;
	case kw_asm: snp = ParseAsm(); break;
	case colon:	snp = ParseLabel(false); goto j1;
	case id:
		SkipSpaces();
		if (lastch == ':') {
			snp = ParseLabel(true);
			if (has_label)
				*has_label = true;
			goto j1;
		}
		// else fall through to parse expression
	default:
		snp = ParseExpression(node, symi);
		break;
	}
	if (snp != NULL) {
		snp->next = (Statement *)NULL;
		//snp->casevals = bf;
		bf = nullptr;
	}
	dfs.puts("</Parse>");
	return (snp);
}

Statement* Statement::Parse(bool* has_label)
{
	ENODE* node;

	return (Parse(&node, nullptr, has_label));
}


//=============================================================================
//=============================================================================
// O P T I M I Z A T I O N
//=============================================================================
//=============================================================================

/*
*      repcse will scan through a block of statements replacing the
*      optimized expressions with their temporary references.
*/
void Statement::repcse()
{
	Statement *block = this;

	if (this == nullptr)
		return;
	while (block != NULL) {
		switch (block->stype) {
		case st_compound:
			block->prolog->repcse();
			block->repcse_compound();
			block->epilog->repcse();
			break;
		case st_break:
			if (block->exp)
				block->exp->repexpr();
			break;
		case st_yield:
		case st_return:
		case st_throw:
			block->exp->repexpr();
			break;
		case st_check:
			block->exp->repexpr();
			break;
		case st_expr:
			block->exp->repexpr();
			break;
		case st_while:
		case st_until:
		case st_dowhile:
		case st_dountil:
			block->exp->repexpr();
		case st_do:
		case st_doloop:
		case st_forever:
			block->s1->repcse();
			block->s2->repcse();
			break;
		case st_for:
			block->initExpr->repexpr();
			block->exp->repexpr();
			block->s1->repcse();
			block->incrExpr->repexpr();
			break;
		case st_if:
			block->exp->repexpr();
			block->s1->repcse();
			block->s2->repcse();
			break;
		case st_switch:
			block->exp->repexpr();
			block->s1->repcse();
			break;
		case st_try:
		case st_catch:
		case st_case:
		case st_default:
		case st_firstcall:
			block->s1->repcse();
			break;
		}
		block = block->next;
	}
}

void Statement::repcse_compound()
{
	Symbol *sp;

	sp = ssyms.headp;
	while (sp) {
		if (sp->initexp) {
			sp->initexp->repexpr();
		}
		sp = sp->nextp;
	}
	s1->repcse();
}

void Statement::scan_compound()
{
	Symbol *sp;

	sp = ssyms.headp;
	while (sp) {
		if (sp->initexp) {
			opt_const(&sp->initexp);
			sp->initexp->scanexpr(0);
		}
		sp = sp->nextp;
	}
	s1->scan();
}


//      scan will gather all optimizable expressions into the expression
//      list for a block of statements.

void Statement::scan()
{
	Statement *block = this;

	dfs.printf("<Statement__Scan>");
	if (this == nullptr)
		return;
	loop_active = 1;
	while (block != NULL) {
		dfs.printf("B");
		switch (block->stype) {
		case st_compound:
			dfs.printf("C\n");
			block->prolog->scan();
			block->scan_compound();
			block->epilog->scan();
			dfs.printf("c");
			break;
		case st_check:
		case st_return:
		case st_yield:
		case st_throw:
		case st_expr:
			dfs.printf("E");
			opt_const(&block->exp);
			block->exp->scanexpr(0);
			dfs.printf("e");
			break;
		case st_dowhile:
			dfs.printf("{do}");
			loop_active++;
			opt_const(&block->exp);
			block->exp->scanexpr(0);
			block->s1->scan();
			loop_active--;
			dfs.printf("{/do}");
			break;
		case st_while:
		case st_until:
		case st_dountil:
			loop_active++;
			opt_const(&block->exp);
			block->exp->scanexpr(0);
			block->s1->scan();
			loop_active--;
			break;
		case st_do:
		case st_doloop:
		case st_forever:
			loop_active++;
			block->s1->scan();
			loop_active--;
			break;
		case st_for:
			loop_active++;
			opt_const(&block->initExpr);
			block->initExpr->scanexpr(0);
			opt_const(&block->exp);
			block->exp->scanexpr(0);
			block->s1->scan();
			opt_const(&block->incrExpr);
			block->incrExpr->scanexpr(0);
			loop_active--;
			break;
		case st_if:
			dfs.printf("{if}");
			opt_const(&block->exp);
			block->exp->scanexpr(0);
			block->s1->scan();
			block->s2->scan();
			dfs.printf("{/if}");
			break;
		case st_switch:
			opt_const(&block->exp);
			block->exp->scanexpr(0);
			block->s1->scan();
			break;
		case st_firstcall:
		case st_case:
		case st_default:
			block->s1->scan();
			break;
			//case st_spinlock:
			//        scan(block->s1);
			//        scan(block->s2);
			//        break;
			// nothing to process for these statement
		case st_break:
		case st_continue:
		case st_goto:
			break;
		default:;// printf("Uncoded statement in scan():%d\r\n", block->stype);
		}
		block = block->next;
	}
	dfs.printf("</Statement__Scan>");
}

void Statement::update()
{
	Statement *block = this;

	while (block != NULL) {
		switch (block->stype) {
		case st_compound:
			block->prolog->update();
			block->update_compound();
			block->epilog->update();
			break;
		case st_yield:
		case st_return:
		case st_throw:
			block->exp->update();
			break;
		case st_check:
			block->exp->update();
			break;
		case st_expr:
			block->exp->update();
			break;
		case st_while:
		case st_until:
		case st_dowhile:
		case st_dountil:
			block->exp->update();
		case st_do:
		case st_doloop:
		case st_forever:
			block->s1->update();
			block->s2->update();
			break;
		case st_for:
			block->initExpr->update();
			block->exp->update();
			block->s1->update();
			block->incrExpr->update();
			break;
		case st_if:
			block->exp->update();
			block->s1->update();
			block->s2->update();
			break;
		case st_switch:
			block->exp->update();
			block->s1->update();
			break;
		case st_try:
		case st_catch:
		case st_case:
		case st_default:
		case st_firstcall:
			block->s1->update();
			break;
		}
		block = block->next;
	}
}

void Statement::update_compound()
{
	Symbol *sp;

	sp = ssyms.headp;
	while (sp) {
		if (sp->initexp) {
			sp->initexp->update();
		}
		sp = sp->GetNextPtr();
	}
	s1->update();
}


//=============================================================================
//=============================================================================
// C O D E   G E N E R A T I O N
//=============================================================================
//=============================================================================

Operand *Statement::MakeDataLabel(int lab, int ndxreg) { return (cg.MakeDataLabel(lab,ndxreg)); };
Operand *Statement::MakeCodeLabel(int lab) { return (cg.MakeCodeLabel(lab)); };
Operand *Statement::MakeStringAsNameConst(char *s, e_sg seg) { return (cg.MakeStringAsNameConst(s, seg)); };
Operand *Statement::MakeString(char *s) { return (cg.MakeString(s)); };
Operand *Statement::MakeImmediate(int64_t i) { return (cg.MakeImmediate(i)); };
Operand *Statement::MakeIndirect(int i) { return (cg.MakeIndirect(i)); };
Operand *Statement::MakeIndexed(int64_t o, int i) { return (cg.MakeIndexed(o, i)); };
Operand *Statement::MakeDoubleIndexed(int i, int j, int scale) { return (cg.MakeDoubleIndexed(i, j, scale)); };
Operand *Statement::MakeDirect(ENODE *node) { return (cg.MakeDirect(node)); };
Operand *Statement::MakeIndexed(ENODE *node, int rg) { return (cg.MakeIndexed(node, rg)); };
Operand* Statement::MakeIndexedName(std::string nme, int rg) { return (cg.MakeIndexedName(nme, rg)); };

void Statement::GenStore(Operand *ap1, Operand *ap3, int size) { cg.GenerateStore(ap1, ap3, size); }

void Statement::GenMixedSource()
{
	std::string str(" ");

	if (mixedSource) {
		if (lptr) {
			rtrim(lptr);
			str += std::string(lptr);
			if (strcmp(lptr, last_rem) != 0) {
				GenerateMonadic(op_remark, 0, cg.MakeStringAsNameConst((char *)str.c_str(), codeseg));
				strncpy_s(last_rem, 131, lptr, 130);
				last_rem[131] = '\0';
			}
		}
	}
}

void Statement::GenMixedSource2()
{
	if (mixedSource) {
		if (lptr2) {
			rtrim(lptr2);
			if (strcmp(lptr2, last_rem) != 0) {
				GenerateMonadic(op_remark, 0, cg.MakeStringAsNameConst(lptr2, codeseg));
				strncpy_s(last_rem, 131, lptr2, 130);
				last_rem[131] = '\0';
			}
		}
	}
}

// For loops the loop inversion optimization is applied.
// Basically:
// while(x) {
// ...code
// }
// Gets translated to:
// if (x) {
//   do {
//   ...code
//   } while(x);
// }
// Placing the conditional test at the end of the loop
// removes a branch instruction from every iteration.

void Statement::GenerateWhile()
{
	int lab1, lab2;
	OCODE *loophead;

	initstack();
	lab1 = contlab;
	lab2 = breaklab;
	contlab = nextlabel++;
	breaklab = nextlabel++;
	loophead = currentFn->pl.tail;
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	if (!opt_nocgo && !opt_size)
		cg.GenerateFalseJump(exp, breaklab, 2);
	GenerateLabel(contlab);
	if (s1 != NULL)
	{
		looplevel++;
		if (opt_nocgo|opt_size) {
			initstack();
			cg.GenerateFalseJump(exp, breaklab, 2);
		}
		if (compiler.ipoll)
			GenerateZeradic(op_pfi);
		s1->Generate();
		looplevel--;
		if (!opt_nocgo && !opt_size) {
			initstack();
			cg.GenerateTrueJump(exp, contlab, 2);
		}
		else
			GenerateMonadic(op_bra, 0, cg.MakeCodeLabel(contlab));
	}
	else
	{
		initstack();
		cg.GenerateTrueJump(exp, contlab, prediction);
	}
	GenerateLabel(breaklab);
	currentFn->pl.OptLoopInvariants(loophead);
	breaklab = lab2;
	contlab = lab1;
}

void Statement::GenerateUntil()
{
	int lab1, lab2;
	OCODE *loophead;

	initstack();
	lab1 = contlab;
	lab2 = breaklab;
	contlab = nextlabel++;
	breaklab = nextlabel++;
	loophead = currentFn->pl.tail;
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	if (!opt_nocgo && !opt_size)
		cg.GenerateTrueJump(exp, breaklab, 2);
	GenerateLabel(contlab);
	if (s1 != NULL)
	{
		looplevel++;
		if (opt_nocgo) {
			initstack();
			cg.GenerateTrueJump(exp, breaklab, 2);
		}
		if (compiler.ipoll)
			GenerateZeradic(op_pfi);
		s1->Generate();
		looplevel--;
		if (!opt_nocgo && !opt_size) {
			initstack();
			cg.GenerateFalseJump(exp, contlab, 2);
		}
		else
			GenerateMonadic(op_bra, 0, cg.MakeCodeLabel(contlab));
	}
	else
	{
		initstack();
		cg.GenerateFalseJump(exp, contlab, prediction);
	}
	currentFn->pl.OptLoopInvariants(loophead);
	GenerateLabel(breaklab);
	breaklab = lab2;
	contlab = lab1;
}

bool Statement::IsDecByOne()
{
	if (incrExpr->pfl->nodetype != en_assub)
		return (false);
	if (incrExpr->pfl->p[1]->nodetype != en_icon)
		return (false);
	if (incrExpr->pfl->p[1]->i != 1)
		return (false);
	return (true);
}

bool Statement::IsNEZeroTest()
{
	if (exp->nodetype != en_ne)
		return (false);
	if (exp->p[1]->nodetype != en_icon)
		return (false);
	if (exp->p[1]->i != 0)
		return (false);
	return (true);
}

bool Statement::IsInitNonZero()
{
	if (initExpr->p[1]->nodetype != en_icon)
		return (false);
	if (initExpr->p[1]->i == 0)
		return (false);
	return (true);
}

bool Statement::FindLoopVar(int64_t i)
{
	if (s1)
		if (s1->FindLoopVar(i))
			return (true);
	if (s2)
		if (s2->FindLoopVar(i))
			return (true);
	if (initExpr)
		if (initExpr->FindLoopVar(i))
			return (true);
	if (exp)
		if (exp->FindLoopVar(i))
			return (true);
	if (incrExpr)
		if (incrExpr->FindLoopVar(i))
			return (true);
	return (false);
}

void Statement::GenerateCountedLoop()
{
	int old_break, old_cont, exit_label, loop_label;
	OCODE* loophead;
	Operand* ap;

	old_break = breaklab;
	old_cont = contlab;
	loop_label = nextlabel++;
	exit_label = nextlabel++;
	contlab = nextlabel++;
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	initstack();
	if (initExpr != NULL) {
		ap = cg.GenerateExpression(initExpr, am_reg, initExpr->GetNaturalSize(), 0);
		GenerateMonadic(op_mtlc, 0, ap);
		ReleaseTempRegister(ap);
	}
	loophead = currentFn->pl.tail;
	GenerateLabel(loop_label);
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	if (s1 != NULL)
	{
		breaklab = exit_label;
		looplevel++;
		s1->Generate();
		looplevel--;
	}
	GenerateLabel(contlab);
	GenerateMonadic(op_dbra, 0, cg.MakeCodeLabel(loop_label));
	if (!opt_nocgo)
		currentFn->pl.OptLoopInvariants(loophead);
	breaklab = old_break;
	contlab = old_cont;
	GenerateLabel(exit_label);
}

void Statement::GenerateFor()
{
	int old_break, old_cont, exit_label, loop_label;
	OCODE* loophead;

	old_break = breaklab;
	old_cont = contlab;
	loop_label = nextlabel++;
	exit_label = nextlabel++;
	contlab = nextlabel++;
	// Disabled for now until loop counter is saved and restored at
	// function entry / exit.
	if (false && !lc_in_use) {
		if (initExpr->nodetype == en_assign) {
			if (initExpr->p[0]->nodetype == en_regvar) {
				if (IsDecByOne() && IsNEZeroTest() && IsInitNonZero()) {
					if (!s1->FindLoopVar(initExpr->p[0]->rg)) {
						lc_in_use = true;
						currentFn->UsesLoopCounter = true;
						GenerateCountedLoop();
						lc_in_use = false;
						return;
					}
				}
			}
		}
	}
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	initstack();
	if (initExpr != NULL)
		ReleaseTempRegister(cg.GenerateExpression(initExpr, am_all | am_novalue
			, initExpr->GetNaturalSize(), 0));
	loophead = currentFn->pl.tail;
	if (!opt_nocgo && !opt_size) {
		if (exp != NULL) {
			initstack();
			cg.GenerateFalseJump(exp, exit_label, 2);
		}
	}
	GenerateLabel(loop_label);
	if (opt_nocgo||opt_size) {
		if (exp != NULL) {
			initstack();
			cg.GenerateFalseJump(exp, exit_label, 2);
		}
	}
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	if (s1 != NULL)
	{
		breaklab = exit_label;
		looplevel++;
		s1->Generate();
		looplevel--;
	}
	GenerateLabel(contlab);
	if (incrExpr != NULL) {
		initstack();
		ReleaseTempRegister(cg.GenerateExpression(incrExpr, am_all | am_novalue, incrExpr->GetNaturalSize(),0));
	}
	if (opt_nocgo||opt_size)
		GenerateMonadic(op_bra, 0, cg.MakeCodeLabel(loop_label));
	else {
		initstack();
		cg.GenerateTrueJump(exp, loop_label, 2);
	}
	if (!opt_nocgo)
		currentFn->pl.OptLoopInvariants(loophead);
	breaklab = old_break;
	contlab = old_cont;
	GenerateLabel(exit_label);
}


void Statement::GenerateForever()
{
	int old_break, old_cont, exit_label, loop_label;
	OCODE *loophead;

	old_break = breaklab;
	old_cont = contlab;
	loop_label = nextlabel++;
	exit_label = nextlabel++;
	contlab = loop_label;
	loophead = currentFn->pl.tail;
	GenerateLabel(loop_label);
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	if (s1 != NULL)
	{
		breaklab = exit_label;
		looplevel++;
		if (compiler.ipoll)
			GenerateZeradic(op_pfi);
		s1->Generate();
		looplevel--;
	}
	GenerateMonadic(op_bra, 0, cg.MakeCodeLabel(loop_label));
	currentFn->pl.OptLoopInvariants(loophead);
	breaklab = old_break;
	contlab = old_cont;
	GenerateLabel(exit_label);
}

void Statement::GenerateIf()
{
	int lab1, lab2;
	ENODE *ep, *node;
	int size, siz1;
	Operand *ap1, *ap2, *ap3;
	OCODE* headif;

	lab1 = nextlabel++;     // else label
	lab2 = nextlabel++;     // exit label
	initstack();            // clear temps
	ep = node = exp;

	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	if (ep == nullptr)
		return;

	// Note the compiler makes two passes at code generation. During the first pass
	// the node type is set to en_bchk and the node pointers are manipulated. So for
	// the second pass this does not need to be done again.
	/*
	if (ep->nodetype == en_bchk) {
	size = GetNaturalSize(node);
	ap1 = GenerateExpression(node->p[0], am_reg, size);
	ap2 = GenerateExpression(node->p[1], am_reg, size);
	ap3 = GenerateExpression(node->p[2], am_reg|am_imm0, size);
	if (ap3->mode == am_imm) {
	ReleaseTempReg(ap3);
	ap3 = makereg(0);
	}
	Generate4adic(op_bchk, 0, ap1, ap3, ap2, MakeDataLabel(lab1));	// the nodes are processed in reversed order
	ReleaseTempRegister(ap3);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	}
	else if (!opt_nocgo && ep->nodetype==en_lor && ep->p[0]->nodetype == en_lt && ep->p[1]->nodetype == en_ge && equalnode(ep->p[0]->p[0], ep->p[1]->p[0])) {
	ep->nodetype = en_bchk;
	if (ep->p[0])
	ep->p[2] = ep->p[0]->p[1];
	else
	ep->p[2] = NULL;
	ep->p[1] = ep->p[1]->p[1];
	ep->p[0] = ep->p[0]->p[0];
	size = GetNaturalSize(node);
	ap1 = GenerateExpression(node->p[0], am_reg, size);
	ap2 = GenerateExpression(node->p[1], am_reg, size);
	ap3 = GenerateExpression(node->p[2], am_reg, size);
	Generate4adic(op_bchk, 0, ap1, ap2, ap3, MakeDataLabel(lab1));
	ReleaseTempRegister(ap3);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
	}
	else
	*/
	// Check for bbc optimization
	/*
	if (!opt_nocgo && ep->nodetype == en_and && ep->p[1]->nodetype == en_icon && pwrof2(ep->p[1]->i) >= 0) {
		size = node->GetNaturalSize();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, size);
		GenerateTriadic(op_bbc, 0, ap1, MakeImmediate(pwrof2(ep->p[1]->i)), MakeDataLabel(lab1, regZero));
		ReleaseTempRegister(ap1);
	}
	else 
	*/
	gHeadif = nullptr;
	if (!opt_nocgo && ep->nodetype == en_lor_safe) {
		/*
		OCODE *ip1 = currentFn->pl.tail;
		OCODE *ip2;
		int len;
		ap3 = GetTempRegister();
		siz1 = node->GetNaturalSize();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, siz1);
		len = currentFn->pl.Count(ip1);
		if (len < 6) {
			ip2 = currentFn->pl.tail;
			ap2 = cg.GenerateExpression(node->p[1], am_reg, siz1);
			len = currentFn->pl.Count(ip2);
			if (len < 6) {
				GenerateTriadic(op_or, 0, ap3, ap1, ap2);
				GenerateTriadic(op_beq, 0, ap3, makereg(0), MakeDataLabel(lab1));
				ReleaseTempReg(ap2);
				ReleaseTempReg(ap1);
				ReleaseTempReg(ap3);
				goto j1;
			}
			ReleaseTempReg(ap2);
		}
		ReleaseTempReg(ap1);
		ReleaseTempReg(ap3);
		currentFn->pl.tail = ip1;
		if (ip1)
			currentFn->pl.tail->fwd = nullptr;
			*/
		cg.GenerateFalseJump(exp, lab1, prediction);
	}
	else if (!opt_nocgo && ep->nodetype == en_land_safe) {
		/*
		OCODE *ip1 = currentFn->pl.tail;
		OCODE *ip2;
		int len;
		ap3 = GetTempRegister();
		siz1 = node->GetNaturalSize();
		ap1 = cg.GenerateExpression(node->p[0], am_reg, siz1);
		len = currentFn->pl.Count(ip1);
		if (len < 6) {
			ip2 = currentFn->pl.tail;
			ap2 = cg.GenerateExpression(node->p[1], am_reg, siz1);
			len = currentFn->pl.Count(ip2);
			if (len < 6) {
				if (!ap1->isBool)
					GenerateDiadic(op_redor, 0, ap1, ap1);
				if (!ap2->isBool)
					GenerateDiadic(op_redor, 0, ap2, ap2);
				GenerateTriadic(op_and, 0, ap3, ap1, ap2);
				GenerateTriadic(op_beq, 0, ap3, makereg(0), MakeDataLabel(lab1));
				ReleaseTempReg(ap2);
				ReleaseTempReg(ap1);
				ReleaseTempReg(ap3);
				goto j1;
			}
			ReleaseTempReg(ap2);
		}
		ReleaseTempReg(ap1);
		ReleaseTempReg(ap3);
		currentFn->pl.tail = ip1;
		if (ip1)
			currentFn->pl.tail->fwd = nullptr;
			*/
		cg.GenerateFalseJump(exp, lab1, prediction);
	}
	else
		cg.GenerateFalseJump(exp, lab1, prediction);
j1:
	headif = gHeadif;
	initstack();
	s1->Generate();
	if (s2 != 0)             /* else part exists */
	{
		GenerateDiadic(op_bra, 0, MakeCodeLabel(lab2), 0);
		if (mixedSource)
			GenerateMonadic(op_remark, 0, MakeStringAsNameConst((char *)"; else",codeseg));
		GenerateLabel(lab1);
		s2->Generate();
		GenerateLabel(lab2);
	}
	else {
		GenerateLabel(lab1);
		currentFn->pl.OptIf(headif);
	}
}

void Statement::GenerateDoOnce()
{
	int oldcont, oldbreak;
	OCODE *loophead;

	oldcont = contlab;
	oldbreak = breaklab;
	contlab = nextlabel++;
	breaklab = nextlabel++;
	loophead = currentFn->pl.tail;
	GenerateLabel(contlab);
	looplevel++;
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	s1->Generate();
	looplevel--;
	GenerateLabel(breaklab);
	currentFn->pl.OptLoopInvariants(loophead);
	breaklab = oldbreak;
	contlab = oldcont;
}

void Statement::GenerateDoWhile()
{
	int oldcont, oldbreak;
	OCODE *loophead;

	oldcont = contlab;
	oldbreak = breaklab;
	contlab = nextlabel++;
	breaklab = nextlabel++;
	loophead = currentFn->pl.tail;
	GenerateLabel(contlab);
	looplevel++;
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	s1->Generate();
	looplevel--;
	initstack();
	GenMixedSource2();
	cg.GenerateTrueJump(exp, contlab, 3);
	GenerateLabel(breaklab);
	currentFn->pl.OptLoopInvariants(loophead);
	breaklab = oldbreak;
	contlab = oldcont;
}

void Statement::GenerateDoUntil()
{
	int oldcont, oldbreak;
	OCODE *loophead;

	oldcont = contlab;
	oldbreak = breaklab;
	contlab = nextlabel++;
	breaklab = nextlabel++;
	loophead = currentFn->pl.tail;
	GenerateLabel(contlab);
	looplevel++;
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	s1->Generate();
	looplevel--;
	initstack();
	GenMixedSource2();
	cg.GenerateFalseJump(exp, contlab, 3);
	GenerateLabel(breaklab);
	currentFn->pl.OptLoopInvariants(loophead);
	breaklab = oldbreak;
	contlab = oldcont;
}

void Statement::GenerateDoLoop()
{
	int oldcont, oldbreak;
	OCODE *loophead;

	oldcont = contlab;
	oldbreak = breaklab;
	contlab = nextlabel++;
	breaklab = nextlabel++;
	loophead = currentFn->pl.tail;
	GenerateLabel(contlab);
	looplevel++;
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	s1->Generate();
	looplevel--;
	GenMixedSource2();
	GenerateMonadic(op_bra, 0, MakeCodeLabel(contlab));
	GenerateLabel(breaklab);
	currentFn->pl.OptLoopInvariants(loophead);
	breaklab = oldbreak;
	contlab = oldcont;
}


/*
*      generate a call to a library routine.
*/
//void call_library(char *lib_name)
//{    
//	SYM     *sp;
//    sp = gsearch(lib_name);
//    if( sp == NULL )
//    {
//		++global_flag;
//		sp = Symbol::alloc();
//		sp->tp = &stdfunc;
//		sp->name = lib_name;
//		sp->storage_class = sc_external;
//		insert(sp,&gsyms);
//		--global_flag;
//    }
//    GenerateDiadic(op_call,0,make_strlab(lib_name),NULL);
//}

void Statement::GenerateTry()
{
	int lab1, curlab;
	Operand *a, *ap;
	ENODE *node;
	Statement *stmt;
	char buf[200];

	lab1 = nextlabel++;
	olderthrow = oldthrow;
	oldthrow = throwlab;
	throwlab = nextlabel++;

	if (currentFn->tryCount == 0) {
		oldthrow = currentFn->defCatchLabel;
		//sprintf_s(buf, sizeof(buf), "#.C%05lld", (int64_t)throwlab);
		//currentFn->defCatchLabelPatchPoint->oper2 = MakeStringAsNameConst(buf, codeseg);
	}
	currentFn->tryCount++;
	initstack();
	ap = GetTempRegister();
//	GenerateDiadic(op_sei, 0, ap2, MakeImmediate((int64_t)15));
//	GenerateDiadic(op_ldo, 0, ap, MakeIndexed((int64_t)16,regFP));	// Get current handler
//	GenerateMonadic(op_push, 0, ap);	// stack it
	sprintf_s(buf, sizeof(buf), ".C%05lld", (int64_t)throwlab);
	DataLabels[throwlab]++;
	GenerateDiadic(cpu.ldi_op, 0, ap, MakeStringAsNameConst(buf, codeseg));
	if (currentFn->IsFar)
		GenerateMonadic(op_di, 0, MakeImmediate(2));
	GenerateDiadic(cpu.sto_op, 0, ap, MakeIndexed(32, regFP));	// Set current handler
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	ReleaseTempRegister(ap);
	s1->Generate();
	GenerateCatch(0, oldthrow, olderthrow);
	throwlab = oldthrow;
	oldthrow = olderthrow;
}

void Statement::GenerateThrow()
{
	Operand *ap;

	if (exp != NULL)
	{
		if (compiler.ipoll)
			GenerateZeradic(op_pfi);
		initstack();
		ap = cg.GenerateExpression(exp, am_all, 8, 0);
		if (ap->mode == am_imm)
			GenerateDiadic(cpu.ldi_op, 0, makereg(cpu.argregs[0]), ap);
		else if (ap->mode != am_reg)
			GenerateDiadic(cpu.ldo_op, 0, makereg(cpu.argregs[0]), ap);
		else if (ap->preg != 1)
			GenerateDiadic(cpu.mov_op, 0, makereg(cpu.argregs[0]), ap);
		ReleaseTempRegister(ap);
		// If a system exception is desired create an appropriate BRK instruction.
		if (num == bt_exception) {
			if (ap->mode != am_imm)
				error(ERR_INT0255);
			else {
				if (ap->offset->i < 0 || ap->offset->i > 255)
					error(ERR_INT0255);
				else
					GenerateMonadic(op_brk, 0, ap);
			}
			return;
		}
		GenerateDiadic(cpu.ldi_op, 0, makereg(cpu.argregs[1]), MakeImmediate(num));
	}
	// Jump to handler address.
	//GenerateMonadic(op_brk, 0, MakeImmediate(239));
	ap = GetTempRegister();
	GenerateMonadic(op_bra, 0, MakeCodeLabel(throwlab));
	ReleaseTempRegister(ap);
}

void Statement::GenerateCatch(int opt, int oldthrow, int olderthrow)
{
	int lab1, lab2, curlab;
	Operand* a, * ap2, * ap;
	ENODE* node;
	Statement* stmt;
	char buf[200];

	lab1 = nextlabel++;

	// Restore previous handler
	ap = GetTempRegister();
	sprintf_s(buf, sizeof(buf), ".C%05lld", (int64_t)oldthrow);
	DataLabels[oldthrow]++;
	GenerateDiadic(cpu.ldi_op, 0, ap, MakeStringAsNameConst(buf, codeseg));
	if (currentFn->IsFar)
		GenerateMonadic(op_di, 0, MakeImmediate(2));
	GenerateDiadic(cpu.sto_op, 0, ap, MakeIndexed((int64_t)32, regFP));	// Restore handler
	ReleaseTempRegister(ap);
	// Branch around the catch handlers
	if (opt == 0) {
		GenerateMonadic(op_bra, 0, MakeCodeLabel(lab1));
		GenerateLabel(throwlab);
	}
	else {
		if (currentFn->IsInline) {
			GenerateMonadic(op_bra, 0, MakeCodeLabel(lab1));
		}
		GenerateLabel(currentFn->defCatchLabel);
	}
	// Generate catch statements
	// $a0 holds the value to be assigned to the catch variable
	// $a1 holds the type number
	for (stmt = opt ? this : s2; stmt; stmt = stmt->next) {
		stmt->GenMixedSource();
		curlab = nextlabel++;
		if (stmt->num != 99999) {
			GenerateTriadic(op_bne, 0, makereg(cpu.argregs[1]), MakeImmediate(stmt->num), MakeCodeLabel(curlab));
		}
		// move the throw expression result in '$a0' into the catch variable.
		node = stmt->exp;
		if (node) {
			ap2 = cg.GenerateExpression(node, am_reg | am_mem, node->GetNaturalSize(), 0);
			if (ap2->mode == am_reg)
				GenerateDiadic(cpu.mov_op, 0, ap2, makereg(cpu.argregs[0]));
			else
				GenStore(makereg(cpu.argregs[0]), ap2, node->GetNaturalSize());
			ReleaseTempRegister(ap2);
		}
		if (compiler.ipoll)
			GenerateZeradic(op_pfi);
		stmt->s1->Generate();
		if (stmt->num == 99999 && opt==1)
			currentFn->GenerateDefaultCatch();
		else
			GenerateMonadic(op_bra, 0, MakeCodeLabel(opt ? retlab : lab1));
		GenerateLabel(curlab);
	}
	// Here the none of the catch handlers could process the throw. Move to the next
	// level of handlers.
	throwlab = oldthrow;
	lab2 = nextlabel++;
	if (opt == 0)
		GenerateMonadic(op_bra, 0, MakeCodeLabel(throwlab));
	GenerateLabel(lab1);
	if (opt) {
		currentFn->GenerateDefaultCatch();
	}
}

void Statement::GenerateCheck()
{
	Operand *ap1, *ap2, *ap3;
	ENODE *node, *ep;
	int size;

	initstack();
	ep = node = exp;
	if (ep->p[0]->nodetype == en_lt && ep->p[1]->nodetype == en_ge && ENODE::IsEqual(ep->p[0]->p[0], ep->p[1]->p[0])) {
		ep->nodetype = en_chk;
		if (ep->p[0])
			ep->p[2] = ep->p[0]->p[1];
		else
			ep->p[2] = NULL;
		ep->p[1] = ep->p[1]->p[1];
		ep->p[0] = ep->p[0]->p[0];
	}
	else if (ep->p[0]->nodetype == en_ge && ep->p[1]->nodetype == en_lt && ENODE::IsEqual(ep->p[0]->p[0], ep->p[1]->p[0])) {
		ep->nodetype = en_chk;
		if (ep->p[1])
			ep->p[2] = ep->p[1]->p[1];
		else
			ep->p[2] = NULL;
		ep->p[1] = ep->p[0]->p[1];
		ep->p[0] = ep->p[0]->p[0];
	}
	if (ep->nodetype != en_chk) {
		/*
		printf("ep->p[0]->p[0]->i %d\r\n", ep->p[0]->p[0]->i);
		printf("ep->p[1]->p[0]->i %d\r\n", ep->p[1]->p[0]->i);
		printf("ep->p[0]->p[0]->nt: %d\r\n", ep->p[0]->p[0]->nodetype);
		printf("ep->p[1]->p[0]->nt: %d\r\n", ep->p[1]->p[0]->nodetype);
		printf("ep->p[0]->nodetype=%s ",ep->p[0]->nodetype==en_lt ? "en_lt" : ep->p[0]->nodetype==en_ge ? "en_ge" : "en_??");
		printf("ep->p[1]->nodetype=%s\r\n",ep->p[1]->nodetype==en_lt ? "en_lt" : ep->p[1]->nodetype==en_ge ? "en_ge" : "en_??");
		printf("equalnode:%d\r\n",equalnode(ep->p[0]->p[0],ep->p[1]->p[0]));
		*/
		error(ERR_CHECK);
		return;
	}
	size = node->GetNaturalSize();
	ap1 = cg.GenerateExpression(node->p[0], am_reg, size, 0);
	ap2 = cg.GenerateExpression(node->p[1], am_reg | am_imm0, size, 1);
	ap3 = cg.GenerateExpression(node->p[2], am_reg | am_imm, size, 1);
	if (ap2->mode == am_imm) {
		ap2->mode = am_reg;
		ap2->preg = 0;
	}
	GenerateTriadic(ap3->mode == am_imm ? op_chki : op_chk, 0, ap1, ap2, ap3);
	ReleaseTempRegister(ap3);
	ReleaseTempRegister(ap2);
	ReleaseTempRegister(ap1);
}

void Statement::GenerateYield()
{
	int lab1;
	Operand* ap1, * ap;
	ENODE* node = exp;
	Function* sym;
	Symbol* s;
	Expression sexp(cg.stmt);
	int i;
	int sp = 0;
	int fsp = 0;
	int psp = 0;
	int vsp = 0;

	sym = nullptr;
	lab1 = nextlabel++;
	ap1 = GetTempRegister();
	cg.GenerateLoadConst(MakeCodeLabel(lab1), ap1);
	GenStore(ap1,MakeIndexedName(MakeConame(*currentFn->sym->mangledName,"target"), regGP),sizeOfWord);
	ReleaseTempRegister(ap1);
	if (node->p[0]->nodetype == en_nacon || node->p[0]->nodetype == en_cnacon) {
		if (node->p[2])
			currentSym = node->p[2]->sym;
		s = sexp.gsearch2(*node->p[0]->sp,bt_int, nullptr, false);
		sym = s->fi;
		i = 0;
		sym->SaveTemporaries(&sp, &fsp, &psp, &vsp);
		if (currentFn->HasRegisterParameters())
			sym->SaveRegisterArguments();
		// If the symbol is unknown, assume a throw is present
		if (sym) {
			if (sym->DoesThrow)
				currentFn->DoesThrow = true;
		}
		else
			currentFn->DoesThrow = true;
		GenStore(makereg(regFP), MakeIndexedName(MakeConame(*currentFn->sym->mangledName, "fp_save"), regGP), sizeOfWord);
		GenStore(makereg(regSP), MakeIndexedName(MakeConame(*currentFn->sym->mangledName, "sp_save"), regGP), sizeOfWord);
		GenerateMonadic(op_jmp, 0, MakeDirect(node->p[0]));
	}
	else {
		i = 0;
		ap = cg.GenerateExpression(node->p[0], am_reg, sizeOfWord, 0);
		if (ap->offset) {
			if (ap->offset->sym)
				sym = ap->offset->sym->fi;
		}
		sym->SaveTemporaries(&sp, &fsp, &psp, &vsp);
		if (currentFn->HasRegisterParameters())
			sym->SaveRegisterArguments();
		// If the symbol is unknown, assume a throw is present
		if (sym) {
			if (sym->DoesThrow)
				currentFn->DoesThrow = true;
		}
		else
			currentFn->DoesThrow = true;
		GenStore(makereg(regFP), MakeIndexedName(MakeConame(*currentFn->sym->mangledName, "fp_save"), regGP), sizeOfWord);
		GenStore(makereg(regSP), MakeIndexedName(MakeConame(*currentFn->sym->mangledName, "sp_save"), regGP), sizeOfWord);
		GenerateMonadic(op_jmp, 0, cg.MakeStringAsNameConst((char*)exp->msp->c_str(), codeseg));
	}
	GenerateMonadic(op_bex, 0, MakeDataLabel(throwlab, regZero));
	if (lab1)
		GenerateLabel(lab1);
	cg.GenerateLoad(makereg(regFP), MakeIndexedName(MakeConame(*currentFn->sym->mangledName, "fp_save"), regGP), sizeOfWord, sizeOfWord);
	cg.GenerateLoad(makereg(regSP), MakeIndexedName(MakeConame(*currentFn->sym->mangledName, "sp_save"), regGP), sizeOfWord, sizeOfWord);
	if (currentFn->HasRegisterParameters())
		if (sym)
			sym->RestoreRegisterArguments();
	if (sym)
		sym->RestoreTemporaries(sp, fsp, psp, vsp);
}

// The same as generating a compound statement but leaves out the generation of
// the prolog and epilog clauses.
void Statement::GenerateFuncBody()
{
	Symbol *sp;

	sp = ssyms.headp;
	while (sp) {
		if (sp->fi)
			;
		else if (sp->initexp) {
			initstack();
			ReleaseTempRegister(cg.GenerateExpression(sp->initexp->p[1], am_all, sizeOfWord, 0));
		}
		sp = sp->nextp;
	}
	// Generate statement will process the entire list of statements in
	// the block.
	s1->Generate();
}

bool Statement::Generate(int opt)
{
	Operand *ap;
	Statement *stmt;
	Symbol* sp;
	ENODE* ep1;

	for (stmt = this; stmt != NULL; stmt = stmt->next)
	{
		/*
		for (ep1 = stmt->iexp; ep1; ep1 = ep1->p[2]) {
			initstack();
			ReleaseTempRegister(cg.GenerateExpression(ep1->p[3], am_all, 8));
		}
		*/
		/*
		for (sp = SYM::GetPtr(stmt->lst.GetHead()); sp; sp = sp->GetNextPtr()) {
			if (sp->initexp) {
				initstack();
				ReleaseTempRegister(cg.GenerateExpression(sp->initexp, am_all, 8));
			}
		}*/
		stmt->GenMixedSource();
		switch (stmt->stype)
		{
		case st_funcbody:
			stmt->GenerateFuncBody();
			break;
		case st_compound:
			compiler.sg->GenerateCompound(stmt);
			break;
		case st_try:
			stmt->GenerateTry();
			break;
		case st_throw:
			stmt->GenerateThrow();
			break;
		case st_catch:
			stmt->GenerateCatch(1, throwlab, oldthrow);
			break;
		case st_stop:
			stmt->GenerateStop();
			break;
		case st_asm:
			stmt->GenerateAsm();
			break;
		case st_label:
			GenerateLabel((int64_t)stmt->label);
			break;
		case st_goto:
			GenerateMonadic(op_bra, 0, MakeCodeLabel((int64_t)stmt->label));
			break;
		case st_yield:
			stmt->GenerateYield();
			break;
			//case st_critical:
			//                    GenerateCritical(stmt);
			//                    break;
		case st_check:
			stmt->GenerateCheck();
			break;
		case st_expr:
			if (stmt->exp) {
				initstack();
				ap = cg.GenerateExpression(stmt->exp, am_all | am_novalue,
					stmt->exp->GetNaturalSize(), 0);
				ReleaseTempRegister(ap);
				tmpFreeAll();
			}
			break;
		case st_return:
			cg.GenerateReturn(currentFn,stmt);
			break;
		case st_if:
			stmt->GenerateIf();
			break;
		case st_do:
		case st_dowhile:
			stmt->GenerateDoWhile();
			break;
		case st_dountil:
			stmt->GenerateDoUntil();
			break;
		case st_doloop:
			stmt->GenerateForever();
			break;
		case st_doonce:
			stmt->GenerateDoOnce();
			break;
		case st_while:
			stmt->GenerateWhile();
			break;
		case st_until:
			stmt->GenerateUntil();
			break;
		case st_for:
			stmt->GenerateFor();
			break;
		case st_forever:
			stmt->GenerateForever();
			break;
		case st_firstcall:
			stmt->GenerateFirstcall();
			break;
		case st_continue:
			if (contlab == -1)
				error(ERR_NOT_IN_LOOP);
			GenerateDiadic(op_bra, 0, MakeCodeLabel(contlab), 0);
			break;
		case st_break:
			if (breaklab == -1)
				error(ERR_NOT_IN_LOOP);
			//(char*)GenerateSwitchTargetName(tablabel).c_str()
			if (opt==3)
				GenerateMonadic(op_bra, 0, cg.MakeStringAsNameConst((char*)GenerateSwitchTargetName(breaklab).c_str(),codeseg));
			else
				GenerateDiadic(op_bra, 0, MakeCodeLabel(breaklab), 0);
			break;
		case st_switch:
			compiler.sg->GenerateSwitch(stmt);
			break;
		case st_case:
			if (opt)
				return (true);
			stmt->GenerateCase();
			break;
		case st_default:
			if (opt)
				return (true);
			StatementGenerator::GenerateDefault(stmt);
			break;
		case st_empty:
			break;
		default:
			printf("DIAG - unknown statement.\n");
			break;
		}
		// Break after one statement generated.
		if (opt >= 2)
			break;
	}
	return (false);
}

void Statement::GenerateStop()
{
	GenerateMonadic(op_stop, 0, MakeImmediate(num));
}

void Statement::GenerateAsm()
{
	char buf2[50];
	Symbol* thead, * firsts;
	int64_t tn, lo, bn, ll, i, j;
	char* p;
	char* buf = (char*)label;

	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	ll = strlen(buf);
	thead = firsts = currentFn->params.headp;
	while (thead) {
		p = &buf[-1];
		while (p = strstr(p+1, &thead->name->c_str()[1])) {
			if (!isidch(p[-1])) {
				bn = p - buf;
				if (!isidch(p[tn = thead->name->length()])) {
					tn--;
					if (thead->IsParameter) {
						if (thead->IsRegister)
							sprintf_s(buf2, sizeof(buf2), "x%I64d", thead->reg);
						else
							sprintf_s(buf2, sizeof(buf2), "%I64d[$fp]", thead->value.i + currentFn->SizeofReturnBlock() * sizeOfWord);
						lo = strlen(buf2);
						
						if (lo==tn)
							memcpy(p, buf2, lo);
						else if (lo > tn) {
							for (i = strlen(&p[tn])+1; i >= 0; i--)
								p[lo + i] = p[tn + i];
							memcpy(p, buf2, lo);
						}
						else {
							for (i = 0; p[lo + i]; i++)
								p[tn + i] = p[lo + i];
							p[tn + i] = p[lo + i];
							memcpy(p, buf2, lo);
						}
						
					}
				}
			}
		}
		thead = thead->GetNextPtr();
		if (thead == firsts) {
			dfs.printf("Circular list.\n");
			throw new C64PException(ERR_CIRCULAR_LIST, 1);
		}
	}

	GenerateMonadic(op_asm, 0, MakeStringAsNameConst((char *)buf,codeseg));
}

void Statement::GenerateFirstcall()
{
	int     lab1, lab2;
	Operand *ap1, *ap2;

	lab1 = contlab;
	lab2 = breaklab;
	contlab = nextlabel++;
	if (compiler.ipoll)
		GenerateZeradic(op_pfi);
	if (s1 != NULL)
	{
		initstack();
		breaklab = nextlabel++;
		ap1 = GetTempRegister();
		ap2 = GetTempRegister();
		GenerateDiadic(op_ldp, 0, ap1, MakeStringAsNameConst(fcname,dataseg));
		GenerateTriadic(op_seq, 0, ap2, ap1, makereg(0));
		GenerateDiadic(op_bne, 0, ap2, MakeCodeLabel(breaklab));
		ReleaseTempRegister(ap2);
		ReleaseTempRegister(ap1);
		GenerateDiadic(op_stp, 0, makereg(regZero), MakeStringAsNameConst(fcname,dataseg));
		s1->Generate();
		GenerateLabel(breaklab);
		breaklab = lab2;
	}
	contlab = lab1;
}

void Statement::Dump()
{
	Statement *block = this;

	dfs.printf("Statement\n");
	while (block != NULL) {
		switch (block->stype) {
		case st_compound:
			block->prolog->Dump();
			block->DumpCompound();
			block->epilog->Dump();
			break;
		case st_return:
		case st_throw:
			block->exp->Dump(0);
			break;
		case st_check:
			block->exp->Dump(0);
			break;
		case st_expr:
			dfs.printf("st_expr\n");
			block->exp->Dump(0);
			break;
		case st_while:
		case st_until:
		case st_dowhile:
		case st_dountil:
			block->exp->Dump(0);
		case st_do:
		case st_doloop:
		case st_forever:
			block->s1->Dump();
			block->s2->Dump();
			break;
		case st_for:
			block->initExpr->Dump(0);
			block->exp->Dump(0);
			block->s1->Dump();
			block->incrExpr->Dump(0);
			break;
		case st_if:
			block->exp->Dump(0);
			block->s1->Dump();
			block->s2->Dump();
			break;
		case st_switch:
			block->exp->Dump(0);
			block->s1->Dump();
			break;
		case st_try:
		case st_catch:
		case st_case:
		case st_default:
		case st_firstcall:
			block->s1->Dump();
			break;
		}
		block = block->next;
	}
}

void Statement::DumpCompound()
{
	Symbol *sp;

	sp = ssyms.headp;
	while (sp) {
		if (sp->initexp) {
			sp->initexp->Dump();
		}
		sp = sp->nextp;
	}
	s1->Dump();
}

void Statement::CheckCompoundReferences(int* psp, int* pbp, int* pgp, int* pgp1)
{
	Symbol* spp;
	int sp, bp, gp, gp1;

	spp = ssyms.headp;
	while (spp) {
		if (spp->initexp) {
			spp->initexp->ResetSegmentCount();
			spp->initexp->CountSegments();
			*psp += exp->segcount[dataseg];
			*pbp += exp->segcount[dataseg];
			*pgp += exp->segcount[dataseg];
			*pgp1 += exp->segcount[rodataseg];
		}
		spp = spp->nextp;
	}
	s1->CheckReferences(&sp, &bp, &gp, &gp1);
	*psp += sp;
	*pbp += bp;
	*pgp += gp;
	*pgp1 += gp1;
}

void Statement::CheckReferences(int* psp, int* pbp, int* pgp, int* pgp1)
{
	int sp, bp, gp, gp1;
	*psp = 0;
	*pbp = 0;
	*pgp = 0;
	*pgp1 = 0;
	Statement* block = this;

	dfs.printf("Statement\n");
	while (block != NULL) {
		switch (block->stype) {
		case st_compound:
			block->prolog->CheckReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			block->CheckCompoundReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			block->epilog->CheckReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			break;
		case st_return:
		case st_throw:
			block->exp->ResetSegmentCount();
			block->exp->CountSegments();
			*psp += exp->segcount[dataseg];
			*pbp += exp->segcount[dataseg];
			*pgp += exp->segcount[dataseg];
			*pgp1 += exp->segcount[rodataseg];
			break;
		case st_check:
			block->exp->ResetSegmentCount();
			block->exp->CountSegments();
			*psp += exp->segcount[dataseg];
			*pbp += exp->segcount[dataseg];
			*pgp += exp->segcount[dataseg];
			*pgp1 += exp->segcount[rodataseg];
			break;
		case st_expr:
			block->exp->ResetSegmentCount();
			block->exp->CountSegments();
			*psp += exp->segcount[dataseg];
			*pbp += exp->segcount[dataseg];
			*pgp += exp->segcount[dataseg];
			*pgp1 += exp->segcount[rodataseg];
			break;
		case st_while:
		case st_until:
		case st_dowhile:
		case st_dountil:
			block->exp->ResetSegmentCount();
			block->exp->CountSegments();
			*psp += exp->segcount[dataseg];
			*pbp += exp->segcount[dataseg];
			*pgp += exp->segcount[dataseg];
			*pgp1 += exp->segcount[rodataseg];
		case st_do:
		case st_doloop:
		case st_forever:
			block->s1->CheckReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			block->s2->CheckReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			break;
		case st_for:
			block->initExpr->Dump();
			block->initExpr->ResetSegmentCount();
			block->initExpr->CountSegments();
			*psp += initExpr->segcount[dataseg];
			*pbp += initExpr->segcount[dataseg];
			*pgp += initExpr->segcount[dataseg];
			*pgp1 += initExpr->segcount[rodataseg];
			block->exp->ResetSegmentCount();
			block->exp->CountSegments();
			*psp += exp->segcount[dataseg];
			*pbp += exp->segcount[dataseg];
			*pgp += exp->segcount[dataseg];
			*pgp1 += exp->segcount[rodataseg];
			block->s1->CheckReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			block->incrExpr->Dump();
			break;
		case st_if:
			block->exp->ResetSegmentCount();
			block->exp->CountSegments();
			*psp += exp->segcount[dataseg];
			*pbp += exp->segcount[dataseg];
			*pgp += exp->segcount[dataseg];
			*pgp1 += exp->segcount[rodataseg];
			block->s1->CheckReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			block->s2->CheckReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			break;
		case st_switch:
			block->exp->ResetSegmentCount();
			block->exp->CountSegments();
			*psp += exp->segcount[dataseg];
			*pbp += exp->segcount[dataseg];
			*pgp += exp->segcount[dataseg];
			*pgp1 += exp->segcount[rodataseg];
			block->s1->CheckReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			break;
		case st_try:
		case st_catch:
		case st_case:
		case st_default:
		case st_firstcall:
			block->s1->CheckReferences(&sp, &bp, &gp, &gp1);
			*psp += sp;
			*pbp += bp;
			*pgp += gp;
			*pgp1 += gp1;
			break;
		}
		block = block->next;
	}
}

//=============================================================================
//=============================================================================
// D E B U G G I N G
//=============================================================================
//=============================================================================

// Recursively list the vars contained in compound statements.

void Statement::ListCompoundVars()
{
	Statement* ss1;

	ListTable(&ssyms, 0);
	for (ss1 = s1; ss1; ss1 = ss1->next) {
		if (ss1->stype == st_compound)
			ss1->ListCompoundVars();
		if (ss1->s1) {
			if (ss1->s1->stype == st_compound)
				ss1->s1->ListCompoundVars();
		}
		if (ss1->stype != st_default && ss1->s2) {
			if (ss1->s2->stype == st_compound)
				ss1->s2->ListCompoundVars();
		}
	}
}

void Statement::storeHexDo(txtoStream& fs, e_stmt st)
{
	fs.printf("%02X:", st);
	if (s1)
		s1->storeHex(fs);
	if (exp)
		exp->storeHex(fs);
	fs.printf(":\n");
}

void Statement::storeHexWhile(txtoStream& fs, e_stmt st)
{
	fs.printf("%02X:", st);
	if (exp)
		exp->storeHex(fs);
	fs.printf(":\n");
	if (s1)
		s1->storeHex(fs);
}

void Statement::storeHexFor(txtoStream& fs)
{
	fs.printf("%02X:", st_for);
	if (initExpr)
		initExpr->storeHex(fs);
	fs.printf(":");
	if (exp)
		exp->storeHex(fs);
	fs.printf(":");
	if (incrExpr)
		incrExpr->storeHex(fs);
	fs.printf(":");
	if (s1)
		s1->storeHex(fs);
}

void Statement::storeHexForever(txtoStream& fs)
{
	fs.printf("%02X:", st_forever);
	if (s1)
		s1->storeHex(fs);
}

void Statement::storeHexSwitch(txtoStream& fs)
{
	Statement* st;
	int64_t* bf;
	int nn;

	fs.printf("%02X:", st_switch);
	if (exp)
		exp->storeHex(fs);
	fs.printf(":");
	for (st = s1; st != (Statement*)NULL; st = st->next)
	{
		if (st->s2) {
			fs.printf("%02X:", st_default);
			s2->storeHex(fs);
		}
		else {
			fs.printf("%02X:", st_case);
			bf = st->casevals;
			if (bf) {
				fs.printf("%02X:", bf[0]);
				for (nn = bf[0]; nn >= 1; nn--) {
					fs.printf("%02X", bf[nn]);
					if (nn > 1)
						fs.printf(",");
					else
						fs.printf(":");
				}
			}
			if (s1)
				s1->storeHex(fs);
		}
	}
}

void Statement::storeWhile(txtoStream& fs)
{
	fs.printf("while(");
	if (exp)
		exp->store(fs);
	fs.printf(")\n");
	if (s1)
		s1->storeHex(fs);
}

void Statement::storeHexIf(txtoStream& fs)
{
	fs.printf("%02X:", st_if);
	exp->storeHex(fs);
	if (prediction >= 2)
		fs.printf(";%d", (int)prediction);
	fs.printf(":\n");
	s1->storeHex(fs);
	if (s2) {
		if (s2->kw == kw_else)
			fs.printf("%02X:", st_else);
		else if (s2->kw == kw_elsif) {
			fs.printf("%02X:", st_elsif);
			s2->exp->storeHex(fs);
			if (s2->prediction >= 2)
				fs.printf(";%d", (int)s2->prediction);
			fs.printf(":\n");
		}
		s2->storeHex(fs);
	}
}

void Statement::storeIf(txtoStream& fs)
{
	fs.printf("if(");
	exp->store(fs);
	if (prediction >= 2)
		fs.printf(";%d", (int)prediction);
	fs.printf(")\n");
	s1->store(fs);
	if (s2) {
		if (s2->kw == kw_else)
			fs.printf("else\n");
		else if (s2->kw == kw_elsif) {
			fs.printf("elsif(");
			s2->exp->store(fs);
			if (s2->prediction >= 2)
				fs.printf(";%d", (int)s2->prediction);
			fs.printf(")\n");
		}
		s2->storeHex(fs);
	}
}

void Statement::storeHexCompound(txtoStream& fs)
{
	Statement* sp;

	fs.printf("%02X:", st_compound);
	for (sp = s1; sp; sp = sp->next) {
		sp->storeHex(fs);
	}
}

void Statement::storeCompound(txtoStream& fs)
{
	Statement* sp;

	for (sp = s1; sp; sp = sp->next) {
		sp->store(fs);
	}
}

void Statement::storeHex(txtoStream& fs)
{
	if (this == nullptr)
		return;
	switch (stype) {
	case st_compound:
		storeHexCompound(fs);
		break;
	case st_label:
		fs.printf("%02X:", st_label);
		fs.printf("%02X:", (int64_t)label);
		fs.printf(";");
		break;
	case st_goto:
		fs.printf("%02X:", st_goto);
		fs.printf("%02X:", (int64_t)label);
		fs.printf(";");
		break;
	case st_do:
	case st_dowhile:
	case st_dountil:
	case st_doonce:
		storeHexDo(fs, stype);
		break;
	case st_while:
	case st_until:
		storeHexWhile(fs, stype);
		break;
	case st_for:
		storeHexFor(fs);
		break;
	case st_forever:
		storeHexForever(fs);
		break;
	case st_break:
	case st_continue:
		fs.printf("%02X;", stype);
		break;
	case st_if:
		storeHexIf(fs);
		break;
	case st_return:
		fs.printf("%02X:", st_return);
		if (exp) {
			fs.printf("%02X:", st_expr);
			exp->storeHex(fs);
		}
		fs.printf(";\n");
		break;
	case st_switch:
		storeHexSwitch(fs);
		break;
	case st_expr:
		fs.printf("%02X:", st_expr);
		exp->storeHex(fs);
		fs.printf(";\n");
		break;
	}
}

void Statement::store(txtoStream& fs)
{
	switch (stype) {
	case st_compound:
		storeCompound(fs);
		break;
	case st_while:
		storeWhile(fs);
		break;
	case st_if:
		storeIf(fs);
		break;
	case st_return:
		fs.printf("return(");
		if (exp)
			exp->store(fs);
		fs.printf(");\n");
		break;
	case st_expr:
		exp->store(fs);
		break;
	}
}
