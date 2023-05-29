// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2021  Robert Finch, Waterloo
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

extern TABLE tagtable;
extern TYP *head;
extern TYP stdconst;

Symbol* FindEnum(char *txt)
{
  Symbol* sp;

  sp = search(std::string(txt), &tagtable);
  if (sp == nullptr)
    return (nullptr);
  if (sp->tp->type == bt_enum)
    return (sp);
  return (nullptr);
}


void Declaration::ParseEnum(TABLE *table)
{   
	Symbol *sp;
  TYP *tp;
	Float128 amt = Float128::One();
  bool power = false;
  Expression exp;

  if(lastst == id) {
//    if((sp = search(std::string(lastid),&tagtable)) == NULL) {
    if ((sp = exp.gsearch2(std::string(lastid), bt_int, nullptr, false)) == nullptr) {
        sp = Symbol::alloc();
      sp->tp = TYP::Make(bt_enum,2);
      sp->storage_class = sc_type;
      sp->SetName(*(new std::string(lastid)));
      sp->tp->sname = new std::string(*sp->name);
      NextToken();
      if (lastst == openpa) {
        NextToken();
        if (lastst == star) {
          NextToken();
          power = true;
        }
        amt = GetFloatExpression((ENODE**)NULL, nullptr);
        needpunc(closepa, 10);
      }
      if (lastst != begin)
        ;// error(ERR_INCOMPLETE);
      else {
				tagtable.insert(sp);
				NextToken();
				ParseEnumerationList(table,amt,sp,power);
      }
		}
    else
      NextToken();
    head = sp->tp;
  }
  else {
    tp = allocTYP();	// fix here
    tp->type = bt_enum;
		tp->size = 2;
		if (lastst==openpa) {
			NextToken();
      if (lastst == star) {
        NextToken();
        power = true;
      }
      amt = GetFloatExpression((ENODE **)NULL,nullptr);
			needpunc(closepa,10);
		}
    if( lastst != begin)
      error(ERR_INCOMPLETE);
    else {
      NextToken();
      ParseEnumerationList(table,amt,nullptr,power);
    }
    head = tp;
  }
}

void Declaration::ParseEnumerationList(TABLE *table, Float128 amt, Symbol *parent, bool power)
{
	Float128 evalue, temp;
  int64_t i64;
  Symbol *sp;
  if (power)
    evalue = Float128::One();
  else
    evalue = Float128::Zero();
  while(lastst == id) {
    sp = Symbol::alloc();
    sp->SetName(*(new std::string(lastid)));
    sp->storage_class = sc_const;
    sp->tp = &stdenum;
		if (parent)
			sp->parent = parent->id;
		else
			sp->parent = 0;
    table->insert(sp);
    NextToken();
		if (lastst==assign) {
			NextToken();
			sp->f128 = GetFloatExpression((ENODE **)NULL,sp);
		}
    else
      sp->f128 = evalue;
    Float128::FloatToInt(&i64, &sp->f128);
    Float128::Float128ToDouble(&sp->value.f, &sp->f128);
    sp->value.i = i64;
    if(lastst == comma)
      NextToken();
    else if(lastst != end)
      break;
    if (power)
      Float128::Mul(&evalue, &evalue, &amt);
    else
      Float128::Add(&evalue, &evalue, &amt);
  }
  needpunc(end,48);
}
