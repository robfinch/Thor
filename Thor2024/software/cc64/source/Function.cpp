// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2023  Robert Finch, Waterloo
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
extern char irfile[256];
extern int defaultcc;
extern bool isLeaf;
extern CSet* ru, * rru;
extern std::string* UnknownFuncName();

Function::Function()
{
	rmask = CSet::MakeNew();
	fprmask = CSet::MakeNew();
	prmask = CSet::MakeNew();
	NumFixedAutoParms = 0;
}

void Function::GenerateName(bool force)
{
	std::string lbl;
	std::string nme;
	char* p;
	Symbol* sy;
	
	//currentFn = this;
	pl.head = pl.tail = nullptr;
//	for (sy = sym; sy; sym = sy->parentp)
//		nme = nme + "_" + *sym->mangledName;
	nme = *sym->GetFullName();// *sym->mangledName;
	tmpReset();
	//ParseAutoDeclarations();
	lbl += *sym->mangledName;
	switch (syntax) {
	case MOT:
		ofs.printf("\n;{++ %s\n", (char*)nme.c_str());
		break;
	default:
		ofs.printf("\n#{++ %s\n", (char*)nme.c_str());
	}
	lbl = std::string("");
	if (IsCoroutine)
		GenerateCoroutineData();
	cseg(ofs);
	if (sym->storage_class == sc_static)
	{
		//lbl = GetNamespace() + std::string("_");
		//strcpy(lbl,GetNamespace());
		//strcat(lbl,"_");
		//		strcpy(lbl,sp->name);
		lbl += nme;// *sym->mangledName;
		if (sym->tp->type == bt_pointer)
			lbl += "_func";
		else {
			switch (syntax) {
			case MOT:
				lbl = "\n\talign 5\n" + lbl;
				break;
			default:
				lbl = "\n\t.align 5\n" + lbl;
			}
		}
		//			gen_strlab((char *)lbl.c_str());
		GenerateMonadic(op_fnname, 0, MakeStringAsNameConst((char*)nme.c_str(), codeseg));
	}
	//	put_label((unsigned int) sp->value.i);
	else {
		if (sym->storage_class == sc_global || sym->storage_class == sc_auto) {
			//			lbl = "\n\t.global ";
			//			lbl += *sym->mangledName;
			switch (syntax) {
			case MOT:
				lbl = "\n\talign 5\n";
				break;
			default:
				lbl = "\n\t.align 5\n";
			}
			if (!IsInline || force) {
				ofs.printf((char*)lbl.c_str());
				//GenerateMonadic(op_verbatium, 0, MakeStringAsNameConst(my_strdup((char*)lbl.c_str()), codeseg));
				//GenerateMonadic(op_verbatium, 0, MakeStringAsNameConst("\n;{+",codeseg));
				GenerateMonadic(op_fnname, 0, MakeStringAsNameConst((char*)nme.c_str(), codeseg));
				ofs.printf("\n");
			}
			lbl = "public code ";
		}
		else {
			if (!IsInline) {
				lbl = "\n\t.local ";
				lbl += nme;
				ofs.printf((char*)lbl.c_str());
				switch (syntax) {
				case MOT:
					lbl = "\n\talign 5\n";
					break;
				default:
					lbl = "\n\t.align 5\n";
				}
				ofs.printf((char*)lbl.c_str());
				lbl = nme;
				//GenerateMonadic(op_verbatium, 0, MakeStringAsNameConst("\n;{+", codeseg));
				GenerateMonadic(op_fnname, 0, MakeStringAsNameConst((char*)nme.c_str(), codeseg));
				ofs.printf("\n");
			}
		}
		//		strcat(lbl,sp->name);
		lbl = nme;
		if (sym->tp->type == bt_pointer)
			lbl += "_func";
		//gen_strlab(lbl);
	}
	switch (syntax) {
	case MOT:
		ofs.printf("\tsdreg\t%d\n", regGP);
		break;
	default:
		ofs.printf("\t.sdreg\t%d\n", regGP);
	}
	switch (syntax) {
	case MOT:
		ofs.printf("\tsd2reg\t%d\n", regGP1);
		break;
	default:
		ofs.printf("\t.sd2reg\t%d\n", regGP1);
	}
	dfs.printf("B");
	p = my_strdup((char*)lbl.c_str());
	dfs.printf("b");
	if (!IsInline && false)
		GenerateMonadic(op_fnname, 0, MakeStringAsNameConst(p, codeseg));
}

Statement *Function::ParseBody()
{
	std::string lbl;
	char *p;
	OCODE *ip, *ip2;
	int oc;
	int label, lab1;
	char cc = '#';
	Function* ofn;

	ofn = currentFn;
	dfs.printf("<Parse function body>:%s|\n", (char *)sym->name->c_str());

	lbl = std::string("");
	lastst;
	needpunc(begin, 47);

	currentFn = this;
	IsLeaf = TRUE;
	DoesThrow = false;
	doesJAL = false;
	UsesPredicate = FALSE;
	UsesNew = FALSE;
	regmask = 0;
	bregmask = 0;
	dfs.printf("C");
	stmtdepth = 0;
	ZeroMemory(regs, sizeof(regs));
	initRegStack();
	sym->stmt = sym->stmt->ParseCompound(true);
	cg.stmt = sym->stmt;
	currentFn->body = sym->stmt;
	currentFn = ofn;
	if (lastst == kw_catch) {
		int lab1;
		Statement stmt;

		currentFn->hasDefaultCatch = true;
		currentFn->body->next = stmt.ParseCatch();
	}
	dfs.printf("D");
	// Go through the list of symbols associated with the function generating any
	// local functions that are found.
	GenerateLocalFunctions();

	currentFn = this;
	if (!this->Islocal)
		GenerateName(false);
	if (!this->Islocal)
		GenerateBody(false);
	//if (sp->stkspace)
	//ofs.printf("%sSTKSIZE_ EQU %d\r\n", (char *)sp->mangledName->c_str(), sp->stkspace);
	isFuncBody = false;
	dfs.printf("</ParseFunctionBody>\n");
	currentFn = ofn;
	return (sym->stmt);
}

void Function::GenerateBody(bool force_inline)
{
	std::string lbl;
	int oc, label;
	OCODE* ip;
	int insn_cnt;

	currentFn = this;

	while (lc_auto % sizeOfWord)	// round frame size to word
		++lc_auto;
	if (pass == 1)
		stkspace = roundWord(lc_auto);
	if (!IsInline || force_inline) {
		pass = 1;
		if (pl.tail)
			oc = pl.tail->opcode;
		else
			oc = op_remark;
		ip = pl.tail;
		looplevel = 0;
		max_reg_alloc_ptr = 0;
		max_stack_use = compiler.GetReturnBlockSize();
		label = nextlabel;
		Generate();
		if (pass == 1) {
			stkspace += (ArgRegCount/* - regFirstArg*/)*sizeOfWord;
			argbot = -stkspace;
			stkspace += max_stack_use;// GetTempMemSpace();
			tempbot = -stkspace;
		}
		pass = 2;
		pl.tail = ip;
		if (pl.tail)
			pl.tail->fwd = nullptr;
		looplevel = 0;
		//nextlabel = label;
		Generate();
		dfs.putch('E');

		insn_cnt = pl.Count(pl.head);
		if (((insn_cnt < compiler.autoInline) ||
				(insn_cnt < inline_threshold)) && force_inline && !IsPrototype)
			IsInline = true;
		PeepOpt();
		FlushPeep(ofs);
		switch (syntax) {
		case MOT:
			break;
		default:
			ofs.printf("\t.type\t%s,@function\n", (char*)sym->GetFullName()->c_str());
			ofs.printf("\t.size\t%s,$-", (char*)sym->GetFullName()->c_str());
			ofs.printf("%s\n", (char*)sym->GetFullName()->c_str());
		}
		lbl = ".endp ";
		lbl += *sym->GetFullName();
		//ofs.printf(lbl.c_str());
		ofs.printf("\n");
		//		if (sym->storage_class == sc_global) {
		//			ofs.printf("endpublic\r\n\r\n");
		//		}
		if (!IsInline)
			;
		DumpBss(body);
	}
}

void Function::Init()
{
	IsLeaf = isLeaf;
	IsNocall = isNocall;
	IsPascal = isPascal;
	sym->IsKernel = isKernel;
	IsInterrupt = isInterrupt;
	IsTask = isTask;
//	NumParms = nump;
//	numa = numarg;
	IsVirtual = isVirtual;
	IsInline = isInline;

	isPascal = defaultcc==1;
	isKernel = FALSE;
	isOscall = FALSE;
	isInterrupt = FALSE;
	isTask = FALSE;
	isNocall = FALSE;
}

void Function::DoFuncptrAssign(Function *sp)
{
	ENODE* node, * ep1, * ep2;
	TYP* tp1, * tp2;
	Expression exp(cg.stmt);
	e_node op;
	Symbol* asym;

	NextToken();
	ep1 = nullptr;
	tp1 = TYP::Make(bt_pointer, sizeOfPtr);
	tp1->btpp = TYP::Make(bt_func, sizeOfWord);
	asym = nullptr;
	exp.nameref2(sp->sym->name->c_str(), &ep1, en_ref, FALSE, nullptr, nullptr, sp->sym);
	exp.CondDeref(&ep1, sp->sym->tp);

	op = en_assign;
	ep2 = nullptr;
	tp2 = exp.ParseAssignOps(&ep2, sp->sym);
	if (tp2 == nullptr || !IsLValue(ep1))
		error(ERR_LVALUE);
	else {
		tp1 = forcefit(&ep2, tp2, &ep1, tp1, false, true);
		ep1 = makenode(op, ep1, ep2);
		ep1->tp = tp1;
	}
	// Move vars with initialization data over to the data segment.
	if (ep1->segment == bssseg)
		ep1->segment = dataseg;
//	if (sp->sym->initexp)
		sp->sym->initexp = makenode(en_void, sp->sym->initexp, ep1);
//		sp->sym->initexp->p[0] = ep1;
//	else
//		sp->sym->initexp = ep1;
	doinit(sp->sym);
}

/*
*      funcbody starts with the current symbol being either
*      the first parameter id or the begin for the local
*      block. If begin is the current symbol then funcbody
*      assumes that the function has no parameters.
*/
int Function::Parse(bool local)
{
	Function *osp, *sp;
	int nump, numar, ellipos;
	std::string nme;

	currentFn = this;
	currentSym = this->sym;
	Islocal = local;
	sp = this;
	dfs.puts("<ParseFunction>\n");
	isFuncBody = true;
	if (this == nullptr) {
		fatal("Compiler error: Function::Parse: Symbol is NULL\r\n");
	}
	dfs.printf("***********************************\n");
	dfs.printf("***********************************\n");
	dfs.printf("***********************************\n");
	if (sym->parent)
		dfs.printf("Parent: %s\n", (char *)sym->GetParentPtr()->name->c_str());
	dfs.printf("Parsing function: %s\n", (char *)sym->name->c_str());
	dfs.printf("***********************************\n");
	dfs.printf("***********************************\n");
	dfs.printf("***********************************\n");
	stkname = ::stkname;
	sp_init = ::sp_init;
	DoesContextSave = ::DoesContextSave;
	if (verbose) printf("Parsing function: %s\r\n", (char *)sym->name->c_str());
	nump = nparms;
	iflevel = 0;
	looplevel = 0;
	foreverlevel = 0;
	// There could be unnamed parameters in a function prototype.
	dfs.printf("A");
	// declare parameters
	// Building a parameter list here allows both styles of parameter
	// declarations. the original 'C' style is parsed here. Originally the
	// parameter types appeared as list after the parenthesis and before the
	// function body.
	//if (NumParms == -1)
		nump = sp->NumParms;
		sp->BuildParameterList(&nump, &numar, &ellipos);
		if (ellipos >= 0)
			sp->NumFixedAutoParms = ellipos + 1;
		else
			sp->NumFixedAutoParms = nump;
	dfs.printf("B");
	sym->mangledName = BuildSignature(1);  // build against parameters

											  // If the symbol has a parent then it must be a class
											  // method. Search the parent table(s) for matching
											  // signatures.
	osp = this;
	nme = *sym->name;
	if (sym->parentp) {
		Function *sp2 = nullptr;
		Symbol* sp3;
		dfs.printf("Parent Class:%s|", (char *)sym->parentp->name->c_str());
		sp3 = sym->parentp->Find(nme);
		if (sp3)
			sp2 = sp3->fi;
		if (sp2) {
			dfs.printf("Found at least inexact match");
			sp2 = FindExactMatch(TABLE::matchno);
		}
		if (sp2 == nullptr)
			error(ERR_METHOD_NOTFOUND);
		else
			sp = sp2;
		PrintParameterTypes();
	}
	else {
		if (gsyms[0].Find(nme)) {
			sp = TABLE::match[TABLE::matchno - 1]->fi;
		}
	}
	dfs.printf("C");

	if (sp && sp != osp) {
		dfs.printf("Function::Parse: sp changed\n");
		params.CopyTo(&sp->params);
		proto.CopyTo(&sp->proto);
		sp->derivitives = derivitives;
		sp->sym->mangledName = sym->mangledName;
		// Should free osp here. It's not needed anymore
		FreeFunction(osp);
	}
	if (lastst == closepa) {
		NextToken();
		while (lastst == kw_attribute)
			Declaration::ParseFunctionAttribute(sp,true);
		//if (lastst == closepa)
		//	NextToken();
		if (lastst == openpa) {
			int np, na;
			Symbol* sp = (Symbol*)Symbol::alloc();
			Function* fn = compiler.ff.MakeFunction(sym->number, sp, false);
			fn->sym->tp = TYP::Copy(&stdfunc);
			fn->sym->tp->btpp = TYP::Copy(&stdint);
			fn->BuildParameterList(&np, &na, &ellipos);
			if (ellipos >= 0)
				fn->NumFixedAutoParms = ellipos + 1;
			else
				fn->NumFixedAutoParms = np;
			if (lastst == closepa) {
				NextToken();
				while (lastst == kw_attribute)
					Declaration::ParseFunctionAttribute(fn,true);
			}
		}
	}
	dfs.printf("D");
	if (sp && sp->sym->tp->type == bt_pointer) {
		if (lastst == assign) {
			DoFuncptrAssign(sp);
		}
		else if (lastst == begin) {
			ENODE* node, *node2;

			node = makesnode(en_cnacon, new std::string(*UnknownFuncName()), new std::string(*UnknownFuncName()), stringlit((char *)UnknownFuncName()->c_str()));
			node2 = makesnode(en_cnacon, new std::string(*UnknownFuncName()), new std::string(*UnknownFuncName()), stringlit((char*)UnknownFuncName()->c_str()));
			node = makenode(en_assign, node, node2);
			sp->sym->initexp = makenode(en_void, nullptr, node);
			doinit(sp->sym);
			goto j2;
		}
		sp->Init();
		return (1);
	}
j2:
	dfs.printf("E");
	if (sp && (lastst == semicolon || lastst == comma)) {	// Function prototype
		dfs.printf("e");
		sp->IsPrototype = 1;
		sp->Init();
		sp->params.MoveTo(&sp->proto);
		goto j1;
	}
	else if (lastst == kw_attribute) {
		while (lastst == kw_attribute) {
			Declaration::ParseFunctionAttribute(sp,true);
		}
		goto j2;
	}
	else if (sp && lastst != begin) {
		dfs.printf("F");
		//			NextToken();
		//			ParameterDeclaration::Parse(2);
		nump = sp->NumParms;
		sp->BuildParameterList(&nump, &numar, &ellipos);
		if (ellipos >= 0)
			sp->NumFixedAutoParms = ellipos + 1;
		else
			sp->NumFixedAutoParms = nump;
		// for old-style parameter list
		//needpunc(closepa);
		if (lastst == semicolon) {
			sp->IsPrototype = 1;
			sp->Init();
		}
		// Check for end of function parameter list.
		else if (funcdecl == 2 && lastst == closepa) {
			;
		}
		else if (lastst == assign)
			DoFuncptrAssign(sp);
		else {
			sp->numa = numa;
			sp->NumParms = nump;
			sp->Init();
			sp->sym->stmt = sp->ParseBody();
			Summary(sp->sym->stmt);
		}
	}
	//                error(ERR_BLOCK);
	else {
		dfs.printf("G");
		if (sp) {
			Statement* existing_stmt;

			sp->Init();
			// Parsing declarations sets the storage class to extern when it really
			// should be global if there is a function body.
			if (sp->sym->storage_class == sc_external)
				sp->sym->storage_class = sc_global;
			existing_stmt = sp->body;
			sp->sym->stmt = sp->ParseBody();
			if (existing_stmt)
				existing_stmt->ssyms.AddTo(&sp->sym->stmt->ssyms);
			sp->body = sp->sym->stmt;
			Summary(sp->sym->stmt);
		}
	}
j1:
	dfs.printf("F");
	dfs.puts("</ParseFunction>\n");
	return (0);
}

/*
void Function::StackGPRs()
{
	int nn;

	GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(31 * sizeOfWord));
	for (nn = 1; nn < 31; nn = nn + 1) {
		GenerateDiadic(op_sto, 0, makereg(nn), MakeIndexed((nn - 1) * sizeOfWord, regSP));
	}
	// Get usp
	GenerateTriadic(op_csrrw, 0, makereg(2), MakeImmediate(0x00), makereg(regZero));
	GenerateDiadic(op_sto, 0, makereg(2), MakeIndexed(30 * sizeOfWord, regSP));
}
*/

// Push temporaries on the stack.

void Function::SaveGPRegisterVars()
{
	int cnt;
	int nn;
	char buf[100];

	if (rmask) {
		if (rmask->NumMember()) {
			cnt = 0;
			cg.GenerateSubtractFrom(makereg(regSP), cg.MakeImmediate(rmask->NumMember() * 8));
			rmask->resetPtr();
			if (rmask->NumMember() == 1)
				cg.GenerateStore(makereg(cpu.saved_regs[0]), MakeIndirect(regSP), sizeOfWord);
			else if (rmask->NumMember() == 2) {
				cg.GenerateStore(makereg(cpu.saved_regs[0]), MakeIndirect(regSP), sizeOfWord);
				cg.GenerateStore(makereg(cpu.saved_regs[1]), MakeIndexed(16,regSP), sizeOfWord);
			}
			else {
				sprintf_s(buf, sizeof(buf), "__store_s0s%d", rmask->NumMember());
				cg.GenerateLocalCall(MakeStringAsNameConst(buf, codeseg));
			}
			/*
			for (nn = rmask->lastMember(); nn >= 0; nn = rmask->prevMember()) {
				cg.GenerateStore(makereg(nregs - 1 - nn), MakeIndexed(cnt, regSP), sizeOfWord);
				//GenerateDiadic(cpu.sto_op, 0, makereg(nregs - 1 - nn), MakeIndexed(cnt, regSP));
				cnt += sizeOfWord;
			}
			*/
		}
	}
}

void Function::SaveFPRegisterVars()
{
	int cnt;
	int nn;

	if (fprmask) {
		if (fprmask->NumMember()) {
			cnt = 0;
			GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), cg.MakeImmediate(fprmask->NumMember() * 8));
			fprmask->resetPtr();
			for (nn = fprmask->lastMember(); nn >= 0; nn = fprmask->prevMember()) {
				cg.GenerateStore(makereg(nregs - 1 - nn), MakeIndexed(cnt, regSP), sizeOfWord);
//				GenerateDiadic(op_sto, 0, makereg(nregs - 1 - nn), MakeIndexed(cnt, regSP));
				cnt += sizeOfWord;
			}
		}
	}
}

void Function::SavePositRegisterVars()
{
	int cnt;
	int nn;

	if (prmask) {	// optimization may be off
		if (prmask->NumMember()) {
			cnt = 0;
			GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), cg.MakeImmediate(prmask->NumMember() * 8));
			prmask->resetPtr();
			for (nn = prmask->lastMember(); nn >= 0; nn = prmask->prevMember()) {
				GenerateDiadic(op_psto, ' ', makefpreg(nregs - 1 - nn), MakeIndexed(cnt, regSP));
				cnt += sizeOfWord;
			}
		}
	}
}

void Function::SaveRegisterVars()
{
	if (!prolog) {
		SaveGPRegisterVars();
		SaveFPRegisterVars();
		SavePositRegisterVars();
	}
}


// Saves any registers used as parameters in the calling function.

void Function::SaveRegisterArguments()
{
	TypeArray *ta;
	int count;

	if (this == nullptr)
		return;
	ta = GetProtoTypes();
	if (ta) {
		int nn;
		if (!cpu.SupportsPush) {
			for (count = nn = 0; nn < ta->length; nn++)
				if (ta->preg[nn]) {
					count++;
					if (ta->types[nn] == bt_quad)
						count++;
				}
			cg.GenerateSubtractFrom(makereg(regSP), makereg(regSP), count * sizeOfWord);
			for (count = nn = 0; nn < ta->length; nn++) {
				if (ta->preg[nn]) {
					switch (ta->types[nn]) {
					case bt_quad:	GenerateDiadic(op_stf, 'q', makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count*sizeOfWord, regSP)); count += 2; break;
					case bt_float:	GenerateDiadic(op_stf, 's', makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count*sizeOfWord, regSP)); count += 1; break;
					case bt_double:	GenerateDiadic(op_stf, 'd', makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count*sizeOfWord, regSP)); count += 1; break;
					case bt_posit:	GenerateDiadic(op_stf, 'd', makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count * sizeOfWord, regSP)); count += 1; break;
					default:	cg.GenerateStore(makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count*sizeOfWord, regSP), sizeOfWord); count += 1; break;
					}
				}
			}
		}
		else {
			for (count = nn = 0; nn < ta->length; nn++) {
				if (ta->preg[nn]) {
					switch (ta->types[nn]) {
					case bt_quad:	GenerateMonadic(op_pushf, 'q', makereg(ta->preg[nn] & 0x7fff)); break;
					case bt_float:	GenerateMonadic(op_pushf, 's', makereg(ta->preg[nn] & 0x7fff)); break;
					case bt_double:	GenerateMonadic(op_pushf, 'd', makereg(ta->preg[nn] & 0x7fff)); break;
					case bt_posit:	GenerateMonadic(op_push, ' ', makereg(ta->preg[nn] & 0x7fff)); break;
					default:	GenerateMonadic(op_push, 0, makereg(ta->preg[nn] & 0x7fff)); break;
					}
				}
			}
		}
	}
}


void Function::RestoreRegisterArguments()
{
	TypeArray *ta;
	int count;

	if (this == nullptr)
		return;
	ta = GetProtoTypes();
	if (ta) {
		int nn;
		for (count = nn = 0; nn < ta->length; nn++)
			if (ta->preg[nn]) {
				count++;
				if (ta->types[nn] == bt_quad)
					count++;
			}
		GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), cg.MakeImmediate(count * sizeOfWord));
		for (count = nn = 0; nn < ta->length; nn++) {
			if (ta->preg[nn]) {
				switch (ta->types[nn]) {
				case bt_quad:	GenerateDiadic(op_ldf, 'q', makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count*sizeOfWord, regSP)); count += 2; break;
				case bt_float:	GenerateDiadic(op_ldf, 's', makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count*sizeOfWord, regSP)); count += 1; break;
				case bt_double:	GenerateDiadic(op_ldf, 'd', makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count*sizeOfWord, regSP)); count += 1; break;
				case bt_posit:	GenerateDiadic(op_ldf, ' ', makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count * sizeOfWord, regSP)); count += 1; break;
				default:	cg.GenerateLoad(makereg(ta->preg[nn] & 0x7fff), MakeIndexed(count*sizeOfWord, regSP), sizeOfWord, sizeOfWord); count += 1; break;
				}
			}
		}
	}
}


int Function::RestoreGPRegisterVars()
{
	int cnt2 = 0, cnt;
	int nn;
	int64_t mask;
	char buf[100];

	if (save_mask == nullptr)
		return (0);
	if (save_mask->NumMember()) {
		if (cpu.SupportsLDM && save_mask->NumMember() > 2) {
			mask = 0;
			for (nn = 0; nn < 64; nn++)
				if (save_mask->isMember(nn))
					mask = mask | (1LL << (nn-1));
			//GenerateMonadic(op_reglist, 0, cg.MakeImmediate(mask, 16));
			GenerateDiadic(op_ldm, 0, cg.MakeIndirect(regSP), cg.MakeImmediate(mask, 16));
		}
		else {
			cnt2 = cnt = save_mask->NumMember() * sizeOfWord;
			cnt = 0;
			save_mask->resetPtr();
			if (save_mask->NumMember() == 1)
				cg.GenerateLoad(makereg(cpu.saved_regs[0]), MakeIndirect(regSP), sizeOfWord, sizeOfWord);
			else if (save_mask->NumMember() == 2) {
				cg.GenerateLoad(makereg(cpu.saved_regs[0]), MakeIndirect(regSP), sizeOfWord, sizeOfWord);
				cg.GenerateLoad(makereg(cpu.saved_regs[1]), MakeIndexed(sizeOfWord,regSP), sizeOfWord, sizeOfWord);
			}
			else {
				sprintf_s(buf, sizeof(buf), "__load_s0s%d", save_mask->NumMember() - 1);
				GenerateDiadic(op_bsr, 0, makereg(regLR + 1), MakeStringAsNameConst(buf, codeseg));
			}
			/*
			for (nn = save_mask->nextMember(); nn >= 0; nn = save_mask->nextMember()) {
				cg.GenerateLoad(makereg(nn), MakeIndexed(cnt, regSP), sizeOfWord, sizeOfWord);
				cnt += sizeOfWord;
			}
			*/
		}
	}
	return (cnt2);
}

// Restore fp registers used as register variables.
int Function::RestoreFPRegisterVars()
{
	int cnt2 = 0, cnt;
	int nn;

	if (fpsave_mask == nullptr)
		return (0);
	if (fpsave_mask->NumMember()) {
		cnt2 = cnt = (fpsave_mask->NumMember() - 1)*sizeOfWord;
		fpsave_mask->resetPtr();
		for (nn = fpsave_mask->nextMember(); nn >= 1; nn = fpsave_mask->nextMember()) {
			GenerateDiadic(op_fldo, 0, makefpreg(nn), MakeIndexed(cnt2 - cnt, regSP));
			cnt -= sizeOfWord;
		}
		GenerateTriadic(op_add, 0, makereg(regSP), makereg(regSP), MakeImmediate(cnt2 + sizeOfFP));
	}
	return (cnt2);
}

int Function::RestorePositRegisterVars()
{
	int cnt2 = 0, cnt;
	int nn;

	if (psave_mask == nullptr)
		return (0);
	if (psave_mask->NumMember()) {
		cnt2 = cnt = (psave_mask->NumMember() - 1) * sizeOfWord;
		psave_mask->resetPtr();
		for (nn = psave_mask->nextMember(); nn >= 1; nn = psave_mask->nextMember()) {
			GenerateDiadic(op_pldo, 0, compiler.of.makepreg(nn), MakeIndexed(cnt2 - cnt, regSP));
			cnt -= sizeOfWord;
		}
		GenerateTriadic(op_add, 0, makereg(regSP), makereg(regSP), MakeImmediate(cnt2 + sizeOfFP));
	}
	return (cnt2);
}

void Function::RestoreRegisterVars()
{
	if (!prolog) {
		RestorePositRegisterVars();
		RestoreFPRegisterVars();
		cg.GenerateHint(begin_restore_regvars);
		RestoreGPRegisterVars();
		cg.GenerateHint(end_restore_regvars);
	}
}

void Function::SaveTemporaries(int *sp, int *fsp, int* psp, int* vsp)
{
	if (this) {
		if (UsesTemps) {
			*sp = TempInvalidate(fsp, psp, vsp);
			//*fsp = TempFPInvalidate();
		}
	}
	else {
		*sp = TempInvalidate(fsp, psp, vsp);
		//*fsp = TempFPInvalidate();
	}
}

void Function::RestoreTemporaries(int sp, int fsp, int psp, int vsp)
{
	if (this) {
		if (UsesTemps) {
			//TempFPRevalidate(fsp);
			TempRevalidate(sp, fsp, psp, vsp);
		}
	}
	else {
		//TempFPRevalidate(fsp);
		TempRevalidate(sp, fsp, psp, vsp);
	}
}


// Unlink the stack

void Function::UnlinkStack(int64_t amt)
{
	Operand* ap;
	/* auto news are garbage collected
	if (hasAutonew) {
		GenerateMonadic(op_call, 0, MakeStringAsNameConst("__autodel",codeseg));
		GenerateMonadic(op_bex, 0, MakeDataLabel(throwlab));
	}
	*/
	if (!cpu.SupportsLeave)
		GenerateMonadic(op_hint, 0, MakeImmediate(begin_stack_unlink));
	if (cpu.SupportsLeave) {
	}
	else if (!IsLeaf) {
//		if (doesJAL) {	// ??? Not a leaf, so it must be transferring control
			if (alstk) {
				cg.GenerateLoad(makereg(regLR), MakeIndexed(2 * sizeOfWord, regFP), sizeOfWord, sizeOfWord);
				//GenerateTriadic(op_csrrw, 0, makereg(regZero), ap, MakeImmediate(0x3102));
				if (IsFar) {
					ap = GetTempRegister();
					cg.GenerateLoad(ap, MakeIndexed(3 * sizeOfWord, regFP), sizeOfWord, sizeOfWord);
					GenerateTriadic(op_csrrw, 0, makereg(regZero), ap, MakeImmediate(0x3103));
					ReleaseTempRegister(ap);
				}
				cg.GenerateMove(makereg(regSP), makereg(regFP));
				cg.GenerateLoad(makereg(regFP), MakeIndirect(regSP), sizeOfWord, sizeOfWord);
			}
//		}
	}
	// Else leaf routine, reverse any stack allocation but do not pop link register
	else {
		if (alstk) {
			cg.GenerateMove(makereg(regSP), makereg(regFP));
			cg.GenerateLoad(makereg(regFP), MakeIndirect(regSP), sizeOfWord, sizeOfWord);
		}
	}
	cg.GenerateUnlink(amt);
	/*
	if (cpu.SupportsLeave) {
	}
	else if (!IsLeaf && doesJAL) {
		if (alstk) {
			cg.GenerateLoad(makereg(regLR), MakeIndexed(2 * sizeOfWord, regFP), sizeOfWord, sizeOfWord);
			//GenerateTriadic(op_csrrw, 0, makereg(regZero), ap, MakeImmediate(0x3102));
			if (IsFar) {
				ap = GetTempRegister();
				cg.GenerateLoad(ap, MakeIndexed(3 * sizeOfWord, regFP), sizeOfWord, sizeOfWord);
				GenerateTriadic(op_csrrw, 0, makereg(regZero), ap, MakeImmediate(0x3103));
				ReleaseTempRegister(ap);
			}
			cg.GenerateMove(makereg(regSP), makereg(regFP));
			cg.GenerateLoad(makereg(regFP), MakeIndirect(regSP), sizeOfWord, sizeOfWord);
		}
	}
	//	GenerateTriadic(op_add,0,makereg(regSP),makereg(regSP),MakeImmediate(3*sizeOfWord));
	*/
	if (!cpu.SupportsLeave)
		GenerateMonadic(op_hint, 0, MakeImmediate(end_stack_unlink));
}

int64_t Function::SizeofReturnBlock()
{
	return (Compiler::GetReturnBlockSize());
	return ((int64_t)(IsLeaf ? 1 : doesJAL ? 2 : 1));
}

// For a leaf routine don't bother to store the link register.
void Function::SetupReturnBlock()
{
	Operand *ap, *ap1;
	int n;
	char buf[300];
	
	alstk = false;
	if (!cpu.SupportsEnter)
		GenerateMonadic(op_hint,0,MakeImmediate(begin_return_block));
	if (cpu.SupportsEnter)
	{
		if (stkspace < 32767) {
			GenerateMonadic(op_enter, 0, MakeImmediate(-tempbot));
			//			GenerateMonadic(op_link, 0, MakeImmediate(stkspace));
						//spAdjust = pl.tail;
			alstk = true;
		}
		else {
			GenerateMonadic(op_enter, 0, MakeImmediate(32760));
			GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(-tempbot - 32760));
			//GenerateMonadic(op_link, 0, MakeImmediate(SizeofReturnBlock() * sizeOfWord));
			alstk = true;
		}
	}
	else if (cpu.SupportsLink) {
		if (stkspace < 32767 - Compiler::GetReturnBlockSize()) {
			GenerateMonadic(op_link, 0, MakeImmediate(Compiler::GetReturnBlockSize() + stkspace));
//			GenerateMonadic(op_link, 0, MakeImmediate(stkspace));
			//spAdjust = pl.tail;
			alstk = true;
		}
		else {
			GenerateMonadic(op_link, 0, MakeImmediate(32760));
			GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(Compiler::GetReturnBlockSize() + stkspace - 32760));
			//GenerateMonadic(op_link, 0, MakeImmediate(SizeofReturnBlock() * sizeOfWord));
			alstk = true;
		}
	}
	else {
		GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(Compiler::GetReturnBlockSize()));
		cg.GenerateStore(makereg(regFP), MakeIndirect(regSP), sizeOfWord);
		cg.GenerateMove(makereg(regFP), makereg(regSP));
		cg.GenerateStore(makereg(regLR), MakeIndexed(sizeOfWord * 2, regFP), sizeOfWord);	// Store link register on stack
		GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(stkspace));
		alstk = true;
		has_return_block = true;
	}
	// Put this marker here so that storing the link register relative to the
	// frame pointer counts as a frame pointer reference.
	if (!cpu.SupportsEnter)
		GenerateMonadic(op_hint, 0, MakeImmediate(end_return_block));
	//	GenerateTriadic(op_stdp, 0, makereg(regFP), makereg(regZero), MakeIndirect(regSP));
	n = 0;
	if (!currentFn->IsLeaf && doesJAL) {
		n |= 2;
		/*
		if (alstk) {
			GenerateDiadic(op_sto, 0, makereg(regLR), MakeIndexed(1 * sizeOfWord + stkspace, regSP));
		}
		else
		*/
		if (!cpu.SupportsEnter) {
			//if (IsFar)
			//	GenerateMonadic(op_di, 0, MakeImmediate(2));
			//ap = GetTempRegister();
			//GenerateTriadic(op_csrrd, 0, ap, makereg(regZero), MakeImmediate(0x3102));
			//GenerateDiadic(op_mflk, 0, makereg(regLR), ap);
			//cg.GenerateStore(makereg(regLR), MakeIndexed(2 * sizeOfWord, regFP), sizeOfWord);
			//ReleaseTempRegister(ap);
			if (IsFar) {
				ap = GetTempRegister();
				GenerateTriadic(op_csrrd, 0, ap, makereg(regZero), MakeImmediate(0x3103));
				cg.GenerateStore(ap, MakeIndexed(3 * sizeOfWord, regFP), sizeOfWord);
				ReleaseTempRegister(ap);
			}
		}
	}
	/*
	switch (n) {
	case 0:	break;
	case 1:	GenerateDiadic(op_std, 0, makereg(regXLR), MakeIndexed(2 * sizeOfWord, regSP)); break;
	case 2:	GenerateDiadic(op_std, 0, makereg(regLR), MakeIndexed(3 * sizeOfWord, regSP)); break;
	case 3:	GenerateTriadic(op_stdp, 0, makereg(regXLR), makereg(regLR), MakeIndexed(2 * sizeOfWord, regSP)); break;
	}
	*/
	retlab = nextlabel++;
	ap = MakeDataLabel(retlab, regZero);
	ap->mode = am_imm;
	//if (!cpu.SupportsLink)
	//	GenerateDiadic(op_mov, 0, makereg(regFP), makereg(regSP));
	//if (!alstk) {
	//	GenerateTriadic(op_sub, 0, makereg(regSP), makereg(regSP), MakeImmediate(stkspace));
		//spAdjust = pl.tail;
//	}
	// Store the catch handler address at 16[$FP]
	if (exceptions) {
		ap = GetTempRegister();
		sprintf_s(buf, sizeof(buf), ".%05lld", defCatchLabel);
		DataLabels[defCatchLabel]++;
		defCatchLabelPatchPoint = currentFn->pl.tail;
		GenerateDiadic(cpu.ldi_op, 0, ap, MakeStringAsNameConst(buf, codeseg));
		if (IsFar)
			GenerateMonadic(op_di, 0, MakeImmediate(2));
		cg.GenerateStore(ap, MakeIndexed((int64_t)32, regFP), sizeOfWord);
		ReleaseTempRegister(ap);
		if (IsFar) {
			ap = GetTempRegister();
			GenerateTriadic(op_csrrd, 0, ap, makereg(regZero), MakeImmediate(0x311F));	// CS
			cg.GenerateStore(ap, MakeIndexed((int64_t)40, regFP), sizeOfWord);
			ReleaseTempRegister(ap);
		}
//		GenerateDiadic(cpu.mov_op, 0, makereg(regAFP), makereg(regFP));
		GenerateMonadic(op_bex, 0, cg.MakeCodeLabel(currentFn->defCatchLabel));
	}
	tryCount = 0;
}

void Function::GenerateCoroutineData()
{
	std::string str;

	seg(ofs, dataseg, 8);
	str = MakeConame(*sym->mangledName, "target");
	gen_strlab(ofs,(char *)str.c_str());
	ofs.printf("\t.8byte\t%s\n", (char*)MakeConame(*sym->mangledName, "first").c_str());
	str = MakeConame(*sym->mangledName, "orig_lr");
	gen_strlab(ofs, (char*)str.c_str());
	ofs.printf("\t.8byte\t0\n");
	str = MakeConame(*sym->mangledName, "orig_fp");
	gen_strlab(ofs, (char*)str.c_str());
	ofs.printf("\t.8byte\t0\n");
	str = MakeConame(*sym->mangledName, "orig_sp");
	gen_strlab(ofs, (char*)str.c_str());
	ofs.printf("\t.8byte\t0\n");
	str = MakeConame(*sym->mangledName, "fp_save");
	gen_strlab(ofs, (char*)str.c_str());
	ofs.printf("\t.8byte\t0\n");
	str = MakeConame(*sym->mangledName, "sp_save");
	gen_strlab(ofs, (char*)str.c_str());
	ofs.printf("\t.8byte\t0\n");
	seg(ofs, codeseg, 16);
}

// Generate the entry code for a coroutine

void Function::GenerateCoroutineEntry()
{
	Operand* ap, * ap2, * ap3, * ap4;
	ENODE* node;

	cg.GenerateLoadConst(MakeStringAsNameConst((char *)"_start_data", dataseg), makereg(regGP));
	ap = GetTempRegister();
	cg.GenerateLoad(ap, cg.MakeIndexedName(MakeConame(*sym->mangledName, "target"), regGP), sizeOfWord, sizeOfWord);
	GenerateTriadic(op_csrrw, 0, makereg(regZero), ap, MakeImmediate(0x3108));
	ReleaseTempRegister(ap);
	GenerateMonadic(op_jmp, 0, MakeIndirect(136));	// CA4
	GenerateStrLabel(my_strdup((char*)MakeConame(*sym->mangledName, "first").c_str()));
	ap = GetTempRegister();
	GenerateTriadic(op_csrrw, 0, ap, makereg(regZero), MakeImmediate(0x3102));
	cg.GenerateStore(ap, cg.MakeIndexedName(MakeConame(*sym->mangledName, "orig_lr").c_str(), regGP), sizeOfWord);
	ReleaseTempRegister(ap);
	cg.GenerateStore(makereg(regFP), cg.MakeIndexedName(MakeConame(*sym->mangledName, "orig_fp").c_str(), regGP), sizeOfWord);
	cg.GenerateStore(makereg(regSP), cg.MakeIndexedName(MakeConame(*sym->mangledName, "orig_sp").c_str(), regGP), sizeOfWord);
	node = (ENODE*)sp_init;
	opt_const(&node);
	initstack();
	ap = cg.GenerateExpression(node, am_reg, sizeOfWord, 0);
}

// Generate a function body.
//
void Function::Generate()
{
	int defcatch;
	Statement* stmt = this->body;// sym->stmt;
	int lab0;
	int o_throwlab, o_retlab, o_contlab, o_breaklab;
	OCODE* ip;
	OCODE* ip2;
	bool doCatch = true;
	int n, nn;
	int sp, bp, gp, gp1;
	bool o_retgen;
	Operand* ap;
	ENODE* node;
	extern bool first_dataseg;
	first_dataseg = true;

	if (opt_vreg)
		cpu.SetVirtualRegisters();
	o_throwlab = throwlab;
	o_retlab = retlab;
	o_contlab = contlab;
	o_breaklab = breaklab;
	o_retgen = retGenerated;

	retGenerated = false;
	throwlab = retlab = contlab = breaklab = -1;
	lastsph = 0;
	memset(semaphores, 0, sizeof(semaphores));
	throwlab = nextlabel++;
	defcatch = nextlabel++;
	lab0 = nextlabel++;
	defCatchLabel = nextlabel++;

	if (IsCoroutine)
		GenerateCoroutineEntry();

	while (lc_auto % sizeOfWord)	// round frame size to word
		++lc_auto;

	if (currentFn->csetbl == nullptr) {
		currentFn->csetbl = new CSETable;
	}
	if (pass == 1)
		currentFn->csetbl->Clear();

	// The prolog code can't be optimized because it'll run *before* any variables
	// assigned to registers are available. About all we can do here is constant
	// optimizations.
	if (prolog) {
		prolog->scan();
		prolog->Generate();
	}
	if (IsInterrupt)
		cg.GenerateInterruptSave(this);

	// Setup the return block.
	if (!IsNocall && !prolog)
		SetupReturnBlock();
	stmt->CheckReferences(&sp, &bp, &gp, &gp1);
	//	if (!IsInline)
	GenerateMonadic(op_hint, 0, MakeImmediate(start_funcbody));
	if (gp != 0) {
		Operand* ap = GetTempRegister();
		//cg.GenerateLoadConst(MakeStringAsNameConst("__data_base", dataseg), ap);
		cg.GenerateLoadAddress(makereg(regGP), MakeStringAsNameConst((char *)"_start_bss", dataseg));
		//GenerateTriadic(op_base, 0, makereg(regGP), makereg(regGP), ap);
		ReleaseTempRegister(ap);
	}
	// Compiler now uses global pointer one addressing for the rodataseg
	if (gp1 != 0) {
		Operand* ap = GetTempRegister();
		//cg.GenerateLoadConst(MakeStringAsNameConst("__rodata_base", dataseg), ap);
		cg.GenerateLoadAddress(makereg(regGP1), MakeStringAsNameConst((char*)currentFn->sym->name->c_str(), codeseg));
		//cg.GenerateLoadAddress(makereg(regGP1), MakeStringAsNameConst((char *)"_start_rodata", dataseg));
		//if (!compiler.os_code)
		//GenerateTriadic(op_base, 0, makereg(regGP1), makereg(regGP1), ap);
		ReleaseTempRegister(ap);
	}

	if (optimize)
		currentFn->csetbl->Optimize(stmt);
	if (prolog) {
		fpsave_mask = 0;
		save_mask = 0;
		psave_mask = 0;
	}
	else {
		fpsave_mask = ::fpsave_mask;// CSet::MakeNew();
		save_mask = ::save_mask;// CSet::MakeNew();
		psave_mask = ::psave_mask;// CSet::MakeNew();
	}
	stmt->Generate();
	//for (ip2 = pl.head; ip2; ip2 = ip2->fwd)
	//	if (ip2->opcode == op_not)
	//		printf("hi");
	/*
	if (exceptions) {
		ip = pl.tail;
		GenerateMonadic(op_bra, 0, MakeDataLabel(lab0, regZero));
		doCatch = GenDefaultCatch();
		GenerateLabel(lab0);
		if (!doCatch) {
			pl.tail = ip;
			if (pl.tail)
				pl.tail->fwd = nullptr;
		}
	}
*/
//	if (!IsInline)
		cg.GenerateReturn(this,nullptr);

	// Inline code needs to branch around the default exception handler.
	if (exceptions && sym->IsInline)
		GenerateMonadic(op_bra,0,MakeCodeLabel(lab0));
	// Generate code for the hidden default catch
	if (exceptions && !IsNocall)
		GenerateDefaultCatch();
	if (exceptions && sym->IsInline)
		GenerateLabel(lab0);

	dfs.puts("<StaticRegs>");
	dfs.puts("====== Statically Assigned Registers =======\n");
	for (n = 0; n < nregs; n++) {
		if (regs[n].assigned && !regs[n].modified) {
			dfs.printf((char *)"r%d %c ", n, regs[n].isConst ? 'C' : 'V');
			dfs.printf("=%d\n", regs[n].val);
		}
	}
	dfs.puts("</StaticRegs>");
	currentFn->pl.Dump((char *)"===== Peeplist After Generate Pass %d =====\n");
	retGenerated = o_retgen;
	throwlab = o_throwlab;
	retlab = o_retlab;
	contlab = o_contlab;
	breaklab = o_breaklab;
}

// Get catch handler address for next higher catch and force a return to the 
// catch handler. This code jumps to the normal return code so the stack can
// be unwound. But the return address is also set to point to the next higher
// catch handler, so control is transferred there.

void Function::GenerateDefaultCatch()
{
	if (!isNocall) {
		initstack();
		if (!hasDefaultCatch)
			GenerateLabel(defCatchLabel);
		GenerateDiadic(op_jsr, 0, makereg(regLR+1), MakeStringAsNameConst((char *)"_DEFCAT", codeseg));
		GenerateMonadic(op_bra, 0, MakeCodeLabel(retlab));										// And execute return code
		//GenerateDiadic(cpu.ldo_op, 0, ap, MakeIndexed((int64_t)0, regFP));				// Get previous frame pointer
		//GenerateDiadic(cpu.ldo_op, 0, ap2, MakeIndexed((int64_t)32, ap->preg));		// Get previous handler address
		//GenerateDiadic(cpu.sto_op, 0, ap2, MakeIndexed((int64_t)16, regFP));				// move it to return address loc
		//if (IsFar||true) {
		//	GenerateDiadic(cpu.ldo_op, 0, ap2, MakeIndexed((int64_t)40, ap->preg));		// Get previous handler address base
		//	GenerateDiadic(cpu.sto_op, 0, ap2, MakeIndexed((int64_t)24, regFP));				// move it to return address loc base
		//}
	}
}


// Get the parameter types into an array of short integers.
// Only the first 20 parameters are processed.
//
TypeArray *Function::GetParameterTypes()
{
	TypeArray *i16;
	Symbol *sp;
	int nn;

	if (this == nullptr)
		return (nullptr);
	//	printf("Enter GetParameterTypes()\r\n");
	i16 = new TypeArray();
	i16->Clear();
	sp = params.headp;
	for (nn = 0; sp; nn++) {
		i16->Add(sp->tp, (__int16)(sp->IsRegister ? sp->reg : 0));
		sp = sp->nextp;
	}
	//	printf("Leave GetParameterTypes()\r\n");
	return i16;
}

TypeArray *Function::GetProtoTypes()
{
	TypeArray *i16;
	Symbol *sp;
	int nn;

	//	printf("Enter GetParameterTypes()\r\n");
	nn = 0;
	i16 = new TypeArray();
	i16->Clear();
	if (this == nullptr)
		return (i16);
	sp = proto.headp;
	// If there's no prototype try for a parameter list.
	if (sp == nullptr)
		return (GetParameterTypes());
	for (nn = 0; sp; nn++) {
		i16->Add(sp->tp, (__int16)sp->IsRegister ? sp->reg : 0);
		sp = sp->GetNextPtr();
	}
	//	printf("Leave GetParameterTypes()\r\n");
	return i16;
}

void Function::PrintParameterTypes()
{
	TypeArray *ta = GetParameterTypes();
	dfs.printf("Parameter types(%s)\n", (char *)sym->name->c_str());
	ta->Print();
	if (ta)
		delete[] ta;
	ta = GetProtoTypes();
	dfs.printf("Proto types(%s)\n", (char *)sym->name->c_str());
	ta->Print();
	if (ta)
		delete ta;
}

// Build a function signature string including
// the return type, base classes, and any parameters.

std::string *Function::BuildSignature(int opt)
{
	std::string *str;
	std::string *nh;

	dfs.printf("<BuildSignature>");
	if (this == nullptr) {
	}
	if (mangledNames) {
		str = new std::string("_Z");		// 'C' likes this
		dfs.printf("A");
		nh = sym->GetNameHash();
		dfs.printf("B");
		str->append(*nh);
		dfs.printf("C");
		delete nh;
		dfs.printf("D");
		if (sym->name > (std::string *)0x15)
			str->append(*sym->name);
		if (opt) {
			dfs.printf("E");
			str->append(*GetParameterTypes()->BuildSignature());
		}
		else {
			dfs.printf("F");
			str->append(*GetProtoTypes()->BuildSignature());
		}
	}
	else {
		str = new std::string("");
		if (this != nullptr)
			if (sym != nullptr)
				if (sym->name != nullptr)
					str->append(*sym->name);
	}
	dfs.printf(":%s</BuildSignature>", (char *)str->c_str());
	return str;
}

// Check if the passed parameter list matches the one in the
// symbol.
// Allows a null pointer to be passed indicating no parameters

bool Function::ProtoTypesMatch(TypeArray *ta)
{
	TypeArray *tb;

	tb = GetProtoTypes();
	if (tb->IsEqual(ta)) {
		delete tb;
		return true;
	}
	delete tb;
	return false;
}

bool Function::ParameterTypesMatch(TypeArray *ta)
{
	TypeArray *tb;

	tb = GetProtoTypes();
	if (tb->IsEqual(ta)) {
		delete tb;
		return true;
	}
	delete tb;
	return false;
}

// Check if the parameter type list of two different symbols
// match.

bool Function::ProtoTypesMatch(Function *sym)
{
	TypeArray *ta;
	bool ret;

	ta = sym->GetProtoTypes();
	ret = ProtoTypesMatch(ta);
	delete ta;
	return (ret);
}

bool Function::ParameterTypesMatch(Function *sym)
{
	TypeArray *ta;
	bool ret;

	ta = GetProtoTypes();
	ret = sym->ParameterTypesMatch(ta);
	delete ta;
	return (ret);
}

// First check the return type because it's simple to do.
// Then check the parameters.

bool Function::CheckSignatureMatch(Function *a, Function *b) const
{
	std::string ta, tb;

	//	if (a->tp->typeno != b->tp->typeno)
	//		return false;

	ta = a->BuildSignature()->substr(5);
	tb = b->BuildSignature()->substr(5);
	return (ta.compare(tb) == 0);
}


void Function::CheckParameterListMatch(Function *s1, Function *s2)
{
	if (!TYP::IsSameType(s1->parms->tp, s2->parms->tp, false))
		error(ERR_PARMLIST_MISMATCH);
}


// Parameters:
//    mm = number of entries to search (typically the value 
//         TABLE::matchno teh number of matches found

Function *Function::FindExactMatch(int mm)
{
	Function *sp1;
	int nn;
	TypeArray *ta, *tb;

	sp1 = nullptr;
	for (nn = 0; nn < mm; nn++) {
		dfs.printf("%d", nn);
		sp1 = TABLE::match[nn]->fi;
		// Matches sp1 prototype list against this's parameter list
		ta = sp1->GetProtoTypes();
		tb = GetParameterTypes();
		if (ta->IsEqual(tb)) {
			delete ta;
			delete tb;
			return (sp1);
		}
		delete ta;
		delete tb;
	}
	return (nullptr);
}

// Lookup the exactly matching method from the results returned by a
// find operation. Find might return multiple values if there are 
// overloaded functions.

Function *Function::FindExactMatch(int mm, std::string name, int rettype, TypeArray *typearray)
{
	Function *sp1;
	int nn;
	TypeArray *ta;

	sp1 = nullptr;
	for (nn = 0; nn < mm; nn++) {
		if (TABLE::match[nn] != nullptr) {
			sp1 = TABLE::match[nn]->fi;
			ta = sp1->GetProtoTypes();
			if (ta->IsEqual(typearray)) {
				delete ta;
				return sp1;
			}
			delete ta;
		}
	}
	return (nullptr);
}

int Function::BPLAssignReg(Symbol* sp1, int reg, bool* noParmOffset)
{
	if (reg >= cpu.NumArgRegs)
		sp1->IsRegister = false;
	if (sp1->IsRegister && sp1->tp->size < 11) {
		sp1->reg = sp1->IsAuto ? cpu.argregs[reg] | 0x8000 : cpu.argregs[reg];
		if ((cpu.argregs[reg] & 0x8000) == 0) {
			*noParmOffset = true;
			sp1->value.i = -1;
		}
		reg++;
	}
	else
		sp1->IsRegister = false;
	return (reg);
}

// As far as I can tell the numa parameter is not used. It is dead code.

void Function::BuildParameterList(int *num, int *numa, int* ellipos)
{
	int64_t poffset;
	int i, reg, fpreg, preg;
	Symbol *sp1;
	int onp;
	int np;
	bool noParmOffset = false;
	Stringx oldnames[MAX_PARMS];
	int old_nparms;
	ParameterDeclaration pd;
	Symbol* sy;

	dfs.printf("<BuildParameterList>");
	if (this->hasParameters) {
		dfs.printf("Function parameter list already processed.");
//		params = 
			*pd.Parse(1, true, this);
		return;
	}
	this->hasParameters = true;
	if (opt_vreg)
		cpu.SetVirtualRegisters();
	poffset = 0;// compiler.GetReturnBlockSize();
				//	sp->parms = (SYM *)NULL;
	old_nparms = nparms;
	for (np = 0; np < nparms; np++)
		oldnames[np] = names[np];
	onp = nparms;
	nparms = 0;
	reg = 0;
	fpreg = 0;//regFirstArg;
	preg = 0;// regFirstArg;
	// Parameters will be inserted into the symbol's parameter list when
	// declarations are processed.
	//if (strcmp(sym->name->c_str(), "__Skip") == 0)
	//	printf("hello");
	params = *pd.ParameterDeclaration::Parse(1, false, this);
	for (np = 0, sy = params.headp; sy; sy = sy->nextp, np++)
		;
	*num += np;
	*numa = 0;
	*ellipos = -1;
	if (pd.ellip >= 0)
		*ellipos = pd.ellip;
	dfs.printf("B");
	nparms = onp;
	this->NumParms = *num;
	for (i = 0; i < np && i < MAX_PARMS; ++i) {
		if ((sp1 = params.Find(names[i].str, false)) == NULL) {
			dfs.printf("C");
			sp1 = makeint2(names[i].str);
			//			lsyms.insert(sp1);
		}
		// Set the alignment of the parameter
		if (sp1->tp->type == bt_vector)
			poffset = roundQuadWord(poffset);
		else
			poffset = roundWord(poffset);
		sp1->parmno = i;
		sp1->parent = sym->parent;
		sp1->IsParameter = true;
		sp1->value.i = poffset;

		noParmOffset = false;
		if (sp1->tp->IsFloatType())
			reg = BPLAssignReg(sp1, reg, &noParmOffset);
		else if (sp1->tp->IsPositType())
			reg = BPLAssignReg(sp1, reg, &noParmOffset);
		else
			reg = BPLAssignReg(sp1, reg, &noParmOffset);
		if (sp1->tp->type == bt_vector && !sp1->IsRegister)
			*numa += 4;
		else if (!sp1->IsRegister)// && !sp1->IsInline)
			*numa += 1;
		// Increment stack offset.
		// Check for aggregate types passed as parameters. Structs
		// and unions use the type size. There could also be arrays
		// passed.
		if (!noParmOffset) {
			if (sp1->tp->type == bt_vector)
				poffset += roundQuadWord(64);
			else
				poffset += roundWord(sp1->tp->size);
		}
		if (roundWord(sp1->tp->size) > sizeOfWord && !sp1->tp->IsVectorType())
			IsLeaf = FALSE;
		sp1->storage_class = sc_auto;
	}
	// Process extra hidden parameter
	// ToDo: verify that the hidden parameter is required here.
	// It is generated while processing expressions. It may not be needed
	// here.
	if (sym->tp) {
		if (sym->tp->btpp) {
			if (sym->tp->btpp->type == bt_struct || sym->tp->btpp->type == bt_union || sym->tp->btpp->type == bt_class) {
				if (sym->tp->btpp->size > sizeOfWord) {
					sp1 = makeStructPtr("_pHiddenStructPtr");
					sp1->parmno = i;
					sp1->IsParameter = true;
					sp1->parent = sym->parent;
					sp1->value.i = poffset;
					poffset += sizeOfWord;
					sp1->storage_class = sc_register;
					sp1->IsAuto = false;
					sp1->next = 0;
					sp1->IsRegister = true;
					reg = BPLAssignReg(sp1, reg, &noParmOffset);
					// record parameter list
					params.insert(sp1);
					//		nparms++;
					if (!sp1->IsRegister)
						*numa += 1;
					*num = *num + 1;
				}
			}
		}
	}
	arg_space = poffset;
	nparms = old_nparms;
	for (np = 0; np < nparms; np++)
		names[np] = oldnames[np];
	dfs.printf("</BuildParameterList>\n");
}

void Function::AddParameters(Symbol *list)
{
	Symbol *nxt;

	while (list) {
		nxt = list->GetNextPtr();
		params.insert(Symbol::Copy(list));
		list = nxt;
	}

}

void Function::AddProto(Symbol *list)
{
	Symbol *nxt;

	while (list) {
		nxt = list->GetNextPtr();
		proto.insert(Symbol::Copy(list));	// will clear next
		list = nxt;
	}
}

void Function::AddProto(TypeArray *ta)
{
	Symbol *sym;
	int nn;
	char buf[20];

	for (nn = 0; nn < ta->length; nn++) {
		sym = Symbol::alloc();
		sprintf_s(buf, sizeof(buf), "_p%d", nn);
		sym->SetName(std::string(buf));
		sym->tp = TYP::Make(ta->types[nn], TYP::GetSize(ta->types[nn]));
		sym->tp->type = (e_bt)TYP::GetBasicType(ta->types[nn]);
		sym->IsRegister = ta->preg[nn] != 0;
		sym->reg = ta->preg[nn];
		proto.insert(sym);
	}
}

void Function::AddDerived()
{
	DerivedMethod *mthd;

	dfs.puts("<AddDerived>");
	mthd = (DerivedMethod *)allocx(sizeof(DerivedMethod));
	dfs.printf("A");
	if (sym->tp == nullptr)
		dfs.printf("Nullptr");
	if (sym->GetParentPtr() == nullptr)
		throw C64PException(ERR_NULLPOINTER, 10);
	mthd->typeno = sym->GetParentPtr()->tp->typeno;
	dfs.printf("B");
	mthd->name = BuildSignature();

	dfs.printf("C");
	if (derivitives) {
		dfs.printf("D");
		mthd->next = derivitives;
	}
	derivitives = mthd;
	dfs.puts("</AddDerived>");
}

bool Function::HasRegisterParameters()
{
	int nn;

	TypeArray *ta = GetParameterTypes();
	for (nn = 0; nn < ta->length; nn++) {
		if (ta->preg[nn] & 0x8000) {
			delete[] ta;
			return (true);
		}
	}
	delete[] ta;
	return (false);
}


void Function::CheckForUndefinedLabels()
{
	Symbol *head = sym->lsyms.headp;

	while (head != 0) {
		if (head->storage_class == sc_ulabel)
			lfs.printf("*** UNDEFINED LABEL - %s\n", (char *)head->name->c_str());
		head = head->nextp;
	}
}

// Go through the list of symbols associated with the function generating any
// local functions that are found.

static CSet genfi;

void Function::GenerateLocalFunctions()
{
	Symbol* symb;
	Statement* stmt2;
	std::string nm;
	bool inline_flag;

	if (!Islocal)
		genfi.clear();
	for (stmt2 = body; stmt2; stmt2 = stmt2->next) {
		if (stmt2->stype == st_compound) {
			for (symb = stmt2->ssyms.headp; symb; symb = symb->nextp) {
				if (symb->fi)
					if (symb->fi->Islocal && !genfi.isMember(symb->fi->number)) {
						symb->fi->GenerateName(true);
						inline_flag = symb->fi->IsInline;
						symb->fi->IsInline = false;
						symb->fi->GenerateBody(true);
						symb->fi->IsInline = inline_flag;
						genfi.add(symb->fi->number);
					}
			}
		}
	}
}

void Function::Summary(Statement *stmt)
{
	Symbol* symb;

	dfs.printf("<FuncSummary>\n");
	irfs.printf("\nFunction:%s\n", (char *)this->sym->name->c_str());
	nl(ofs);
	CheckForUndefinedLabels();
	lc_auto = 0;
	lfs.printf("\n\n*** local symbol table ***\n\n");
	ListTable(&sym->lsyms, 0);
	if (sym->fi)
		if (sym->fi->body)
			ListTable(&sym->fi->body->ssyms, 0);
	// Should recurse into all the compound statements
	lfs.printf("\n\n*** symbols by compound statement ***\n\n");
	if (sym->fi)
		ListCompound(sym->fi->body);

	if (stmt == NULL)
		dfs.printf("DIAG: null statement in Function::Summary.\r\n");
	else {
		if (stmt->stype == st_compound)
			stmt->ListCompoundVars();
		//stmt->storeHex(irfs);
	}
	lfs.printf("\n\n\n");
	//    ReleaseLocalMemory();        // release local symbols
	isPascal = defaultcc==1;
	isKernel = FALSE;
	isOscall = FALSE;
	isInterrupt = FALSE;
	isNocall = FALSE;
	if (!this->Islocal)
		switch (syntax) {
		case MOT:
			ofs.printf(";--}\n");
			break;
		default:
			ofs.printf("#--}\n");
		}
	/*
	for (symb = sym->lsyms.headp; symb; symb = symb->nextp) {
		if (symb->fi)
			if (symb->fi->Islocal)
				symb->fi->ParseBody();
	}
	*/
	dfs.printf("</FuncSummary>\n");
}

//=============================================================================
//=============================================================================
// C O D E   G E N E R A T I O N
//=============================================================================
//=============================================================================

Operand *Function::MakeDataLabel(int lab, int ndxreg) { return (compiler.of.MakeDataLabel(lab, ndxreg)); }
Operand *Function::MakeCodeLabel(int lab) { return (compiler.of.MakeCodeLabel(lab)); }
Operand *Function::MakeString(char *s) { return (compiler.of.MakeString(s)); }
Operand *Function::MakeImmediate(int64_t i) { return (compiler.of.MakeImmediate(i)); }
Operand *Function::MakeIndirect(int i) { return (compiler.of.MakeIndirect(i)); }
Operand *Function::MakeDoubleIndexed(int i, int j, int scale) { return (compiler.of.MakeDoubleIndexed(i, j, scale)); }
Operand *Function::MakeDirect(ENODE *node) { return (compiler.of.MakeDirect(node)); }
Operand *Function::MakeStringAsNameConst(char *s, e_sg seg) { return (compiler.of.MakeStringAsNameConst(s, seg)); }
Operand *Function::MakeIndexed(int64_t o, int i) { return (cg.MakeIndexed(o, i)); }
Operand *Function::MakeIndexed(ENODE *node, int rg) { return (cg.MakeIndexed(node, rg)); }
void Function::GenLoad(Operand *ap3, Operand *ap1, int ssize, int size) { cg.GenerateLoad(ap3, ap1, ssize, size); }


// When going to insert a class method, check the base classes to see if it's
// a virtual function override. If it's an override, then add the method to
// the list of overrides for the virtual function.

void Function::InsertMethod()
{
	int nn;
	Symbol *sy;
	std::string name;

	name = *sym->name;
	dfs.printf((char *)"<InsertMethod>%s type %d ", (char *)sym->name->c_str(), sym->tp->type);
	// If there is no parent, then it must be a global.
	if (sym->parentp == nullptr) {
		gsyms[0].insert(sym);
	}
	else {
		sym->parentp->tp->lst.insert(sym);
		nn = sym->parentp->tp->lst.FindRising(*sym->name);
		sy = sym->FindRisingMatch(true);
		if (sy) {
			dfs.puts("Found in a base class:");
			if (sy->fi->IsVirtual) {
				dfs.printf("Found virtual:");
				sy->fi->AddDerived();
			}
		}
	}
	dfs.printf("</InsertMethod>\n");
}

void Function::InsertAuto(Symbol* var)
{
	int nn;
	Symbol* sy;
	std::string name;

	name = *sym->name;
	dfs.printf((char*)"<InsertAuto>%s type %d ", (char*)var->name->c_str(), var->tp->type);
	body->ssyms.insert(var);
	nn = body->ssyms.FindRising(*sym->name);
	sy = sym->FindRisingMatch(true);
	if (sy) {
		dfs.puts("Found in a base class:");
		if (sy->fi->IsVirtual) {
			dfs.printf("Found virtual:");
			sy->fi->AddDerived();
		}
	}
	dfs.printf("</InsertAuto>\n");
}

void Function::CreateVars()
{
	BasicBlock *b;
	int nn;
	int num;

	varlist = nullptr;
	Var::nvar = 0;
	for (b = RootBlock; b; b = b->next) {
		b->LiveOut->resetPtr();
		for (nn = 0; nn < b->LiveOut->NumMember(); nn++) {
			num = b->LiveOut->nextMember();
			Var::Find(num);	// find will create the var if not found
		}
		//for (nn = 0; nn < b->LiveIn->NumMember(); nn++) {
		//	num = b->LiveIn->nextMember();
		//	Var::Find(num);	// find will create the var if not found
		//}
	}
}


void Function::ComputeLiveVars()
{
	BasicBlock *b;
	bool changed;
	int iter;
	int changes;

	changed = false;
	for (iter = 0; (iter == 0 || changed) && iter < 10000; iter++) {
		changes = 0;
		changed = false;
		for (b = LastBlock; b; b = b->prev) {
			b->ComputeLiveVars();
			if (b->changed) {
				changes++;
				changed = true;
			}
		}
	}
}

void Function::DumpLiveVars()
{
	BasicBlock *b;
	int nn;
	int lomax, limax;

	lomax = limax = 0;
	for (b = RootBlock; b; b = b->next) {
		lomax = max(lomax, b->LiveOut->NumMember());
		limax = max(limax, b->LiveIn->NumMember());
	}

	dfs.printf("<table style=\"width:100%\">\n");
	//dfs.printf("<LiveVarTable>\n");
	for (b = RootBlock; b; b = b->next) {
		b->LiveIn->resetPtr();
		b->LiveOut->resetPtr();
		dfs.printf("<tr><td>%d: </td>", b->num);
		for (nn = 0; nn < b->LiveIn->NumMember(); nn++)
			dfs.printf("<td>vi%d </td>", b->LiveIn->nextMember());
		for (; nn < limax; nn++)
			dfs.printf("<td></td>");
		dfs.printf("<td> || </td>");
		for (nn = 0; nn < b->LiveOut->NumMember(); nn++)
			dfs.printf("<td>vo%d </td>", b->LiveOut->nextMember());
		for (; nn < lomax; nn++)
			dfs.printf("<td></td>");
		dfs.printf("</tr>\n");
	}
	//dfs.printf("</LiveVarTable>\n");
	dfs.printf("</table>\n");
}


void Function::storeHex(txtoStream& ofs)
{

}

void Function::RemoveDuplicates()
{
	int n;

	n = compiler.funcnum - 1;
	if (n < 1)
		return;
	//if (compiler.functionTable[n].sym->name.compare(compiler.functionTable[n - 1].sym->name) == 0) {

	//}
}


void Function::DumpBss(Statement* stmt)
{
	Symbol* sym;
	static int level = 0;

	seg(ofs, bssseg, 14);
	if (level == 0) {
		int nn;

		sym = nullptr;
		for (nn = 0; nn < compiler.symnum; nn++) {
			if (compiler.symbolTable[nn].storage_class == sc_global) {
				if (compiler.symbolTable[nn].segment == bssseg || compiler.symbolTable[nn].segment == noseg) {
					sym = &compiler.symbolTable[nn];
					if (sym && sym->data_string.length() > 0)
						sym->bss_string = "";
					if (sym)
						ofs.write(sym->bss_string.c_str());
				}
			}
		}
	}
	level++;
	for (; stmt; stmt = stmt->next) {
		for (sym = stmt->ssyms.headp; sym; sym = sym->nextp) {
			if (sym->fi)
				continue;
			if (sym->data_string.length() > 0)
				sym->bss_string = "";
			if (sym->bss_string.length() > 0) {
				ofs.write(sym->bss_string.c_str());
				sym->bss_string = "";
			}
		}
		if (stmt->s1 && stmt->s1->stype == st_compound) {
			DumpBss(stmt->s1);
		}
		if (stmt->s2 && stmt->s2->stype == st_compound) {
			DumpBss(stmt->s2);
		}
	}
	level--;
}


