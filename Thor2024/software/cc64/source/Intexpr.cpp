// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2022  Robert Finch, Waterloo
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

Int128 GetIntegerExpression(ENODE **pnode, Symbol* symi, int opt=0)       /* simple integer value */
{ 
	TYP *tp;
	ENODE *node, *n2, *n3;
	Expression exp(cg.stmt);

	if (opt)
		tp = exp.ParseNonAssignExpression(&node, symi);
	else
		tp = exp.ParseNonCommaExpression(&node, symi);
	if (node==NULL) {
		error(ERR_SYNTAX);
		return (*Int128::Zero());
	}
	// Do constant optimizations to reduce a set of constants to a single constant.
	// Otherwise some codes won't compile without errors.
	opt_const_unchecked(&node);	// This should reduce to a single integer expression
	if (node==NULL) {
		fatal("Compiler Error: GetIntegerExpression: node is NULL");
		return (*Int128::Zero());
	}
	//if (node->nodetype == en_assign)
	//	n2 = node->p[1];
	//else
		n2 = node;
	if (n2->nodetype == en_add) {
		if (n2->p[0]->nodetype == en_labcon && n2->p[1]->nodetype == en_icon) {
			if (pnode)
				*pnode = n2;
			return (Int128(n2->i));
		}
		if (n2->p[0]->nodetype == en_icon && n2->p[1]->nodetype == en_labcon) {
			if (pnode)
				*pnode = n2;
			return (Int128(n2->i));
		}

	}
	if (n2->nodetype != en_icon && n2->nodetype != en_cnacon && n2->nodetype != en_labcon) {
		// A type case is represented by a tempref node associated with a value.
		// There may be an integer typecast to another value that can be used.
		if (n2->nodetype == en_void || n2->nodetype == en_cast) {
			if (n2->p[0]->nodetype == en_type) {
				if (n2->p[1]->nodetype == en_icon) {
					if (pnode)
						*pnode = n2;
					//return (Int128(n2->p[1]->i));
					return (n2->p[1]->i128);
				}
			}
		}
//    printf("\r\nnode:%d \r\n", node->nodetype);
		error(ERR_INT_CONST);
		return (*Int128::Zero());
	}
	if (pnode)
		*pnode = n2;
	//return (Int128(n2->i));
	return (n2->i128);
}

Float128 *GetFloatExpression(ENODE **pnode, Symbol* symi)
{ 
	TYP *tp;
	ENODE *node;
	Float128 *flt;
	Expression exp(cg.stmt);

	flt = (Float128 *)allocx(sizeof(Float128));
	tp = exp.ParseNonCommaExpression(&node, symi);
	if (node==NULL) {
		error(ERR_SYNTAX);
		return 0;
	}
	opt_const_unchecked(&node);
	if (node==NULL) {
		fatal("Compiler Error: GetFloatExpression: node is NULL");
		return 0;
	}
	if (node->nodetype != en_fcon) {
		if (node->nodetype==en_uminus) {
			if (node->p[0]->nodetype != en_fcon) {
				printf("\r\nnode:%d \r\n", node->nodetype);
				error(ERR_INT_CONST);
				return (0);
			}
			Float128::Assign(flt, &node->p[0]->f128);
			flt->sign = !flt->sign;
			if (pnode)
				*pnode = node;
			return (flt);
		}
		if (node->nodetype == en_icon) {
			Float128::IntToFloat(flt, node->i);
			node->f128 = flt;
		}
	}
	if (pnode)
		*pnode = node;
	return (&node->f128);
}

Posit64 GetPositExpression(ENODE** pnode, Symbol* symi)
{
	TYP* tp;
	ENODE* node;
	Posit64 flt;
	Expression exp(cg.stmt);

	tp = exp.ParseNonCommaExpression(&node, symi);
	if (node == NULL) {
		error(ERR_SYNTAX);
		return 0;
	}
	opt_const_unchecked(&node);
	if (node == NULL) {
		fatal("Compiler Error: GetFloatExpression: node is NULL");
		return 0;
	}
	if (node->nodetype != en_pcon) {
		if (node->nodetype == en_uminus) {
			if (node->p[0]->nodetype != en_pcon) {
				printf("\r\nnode:%d \r\n", node->nodetype);
				error(ERR_INT_CONST);
				return (0);
			}
			flt = node->p[0]->posit;
			flt.val = -flt.val;
			if (pnode)
				*pnode = node;
			return (flt);
		}
	}
	if (pnode)
		*pnode = node;
	return (node->posit);
}

Int128 GetConstExpression(ENODE **pnode, Symbol* symi)       /* simple integer value */
{
	TYP *tp;
	ENODE *node;
	Float128 *flt;
	Expression exp(cg.stmt);
	Int128 tmp128;

	tp = exp.ParseNonCommaExpression(&node, symi);
	if (node == NULL) {
		error(ERR_SYNTAX);
		return (*Int128::Zero());
	}
	opt_const_unchecked(&node);
	if (node == NULL) {
		fatal("Compiler Error: GetConstExpression: node is NULL");
		return (*Int128::Zero());
	}
	switch (node->nodetype)
	{
	case en_uminus:
		switch (node->p[0]->nodetype) {
		case en_icon:
			if (pnode)
				*pnode = node;
			tmp128 = node->i128;
			Int128::Sub(&tmp128, Int128::Zero(), &tmp128);
			return (tmp128);
			//return (-node->i);
		case en_fcon:
			flt = (Float128 *)allocx(sizeof(Float128));
			Float128::Assign(flt, &node->p[0]->f128);
			flt->sign = !flt->sign;
			if (pnode)
				*pnode = node;
			return (Int128((int64_t)flt));
		default:
			error(ERR_CONST);
			return (*Int128::Zero());
		}
		break;
	case en_fcon:
		if (pnode)
			*pnode = node;
		return (Int128((int64_t)&node->f128));
	case en_pcon:
		if (pnode)
			*pnode = node;
		return (Int128(node->posit.val));
	case en_icon:
		if (pnode)
			*pnode = node;
		return (node->i128);
	case en_cnacon:
		if (pnode)
			*pnode = node;
		return (Int128(node->i));
	default:
		if (pnode)
			*pnode = node;
		//error(ERR_CONST);
		return (*Int128::Zero());
	}
	error(ERR_CONST);
	return (*Int128::Zero());
}
