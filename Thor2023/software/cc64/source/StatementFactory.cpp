#include "stdafx.h"

Statement* StatementFactory::MakeStatement(int typ, int gt) {
	static int number = 1;
	Statement* s = (Statement*)xalloc(sizeof(Statement));
	ZeroMemory(s, sizeof(Statement));
	s->number = number++;
	s->stype = (e_stmt)typ;
	s->predreg = -1;
	s->lptr = my_strdup(inpline);
	s->prediction = 0;
	s->depth = stmtdepth;
	//memset(s->ssyms,0,sizeof(s->ssyms));
	if (gt) NextToken();
	return s;
};

