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

static void opt0(ENODE** node);
static void fold_const(ENODE **node);
extern int NumericLiteral(ENODE*);
static bool CheckIMatch(ENODE*);
extern ENODE* makei128node(int nt, Int128 v1);
static bool ooptimized = false;

/*
 *      dooper will execute a constant operation in a node and
 *      modify the node to be the result of the operation.
 */
void dooper(ENODE *node)
{
	ENODE *ep;
	Int128 rm;
	bool r, s;
//	ENODE* orig = node->Clone();

//	s = CheckIMatch(node);
	ooptimized = true;
  ep = node;
	switch (ep->nodetype) {
	case en_abs:
		ep->nodetype = en_icon;
		ep->i = (ep->p[0]->i >= 0) ? ep->p[0]->i : -ep->p[0]->i;
		if (Int128::IsGE(&ep->p[0]->i128, Int128::Zero()))
			Int128::Assign(&ep->i128, &ep->p[0]->i128);
		else
			Int128::Sub(&ep->i128, Int128::Zero(), &ep->p[0]->i128);
		break;
	case en_add:
		if (ep->p[0]->nodetype == en_icon) {
			ep->nodetype = en_icon;
			ep->i = ep->p[0]->i + ep->p[1]->i;
			Int128::Add(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		}
		if (ep->p[0]->nodetype == en_pcon) {
			ep->nodetype = en_pcon;
			ep->posit.Add(ep->p[0]->posit, ep->p[1]->posit);
		}
		break;
	case en_ptrdif:
		ep->nodetype = en_icon;
		ep->i = (ep->p[0]->i - ep->p[1]->i) >> ep->p[4]->i;
		Int128::Sub(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		Int128::Shr(&ep->i128, &ep->i128, ep->p[4]->i);
		break;
	case en_sub:
		if (ep->p[0]->nodetype == en_icon) {
			ep->nodetype = en_icon;
			ep->i = ep->p[0]->i - ep->p[1]->i;
			Int128::Sub(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		}
		if (ep->p[0]->nodetype == en_pcon) {
			ep->nodetype = en_pcon;
			ep->posit.Sub(ep->p[0]->posit, ep->p[1]->posit);
		}
		break;
	case en_mul:
	case en_mulu:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i * ep->p[1]->i;
		Int128::Mul(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		break;
	case en_mulf:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i * ep->p[1]->i;
		Int128::Mul(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		break;
	case en_div:
	case en_udiv:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i / ep->p[1]->i;
		Int128::Div(&ep->i128, &rm, &ep->p[0]->i128, &ep->p[1]->i128);
		break;

	case en_i2d:
		ep->nodetype = en_fcon;
		ep->f = (double)ep->p[0]->i;
		ep->tp = &stddouble;// ep->p[0]->tp;
		Float128::IntToFloat(&ep->f128, ep->p[0]->i);
		//ep->i = quadlit(&ep->f128);
		ep->i = NumericLiteral(ep);
		ep->SetType(ep->tp);
		break;
	case en_i2p:
		ep->nodetype = en_pcon;
		ep->f = (double)ep->p[0]->i;
		ep->tp = &stdposit;// ep->p[0]->tp;
		ep->posit.IntToPosit(ep->p[0]->i);
		ep->SetType(ep->tp);
		break;

	case en_fadd:
		ep->nodetype = en_fcon;
		ep->f = ep->p[0]->f + ep->p[1]->f;
		ep->tp = ep->p[0]->tp;
		Float128::Add(&ep->f128, &ep->p[0]->f128, &ep->p[1]->f128);
		//ep->i = quadlit(&ep->f128);
		ep->i = NumericLiteral(ep);
		ep->SetType(ep->tp);
		break;
	case en_fsub:
		ep->nodetype = en_fcon;
		ep->f = ep->p[0]->f - ep->p[1]->f;
		ep->tp = ep->p[0]->tp;
		Float128::Sub(&ep->f128, &ep->p[0]->f128, &ep->p[1]->f128);
		ep->i = NumericLiteral(ep);
		//ep->i = quadlit(&ep->f128);
		ep->SetType(ep->tp);
		break;
	case en_fmul:
		ep->nodetype = en_fcon;
		ep->f = ep->p[0]->f * ep->p[1]->f;
		ep->tp = ep->p[0]->tp;
		Float128::Mul(&ep->f128, &ep->p[0]->f128, &ep->p[1]->f128);
		ep->i = NumericLiteral(ep);
		//		ep->i = quadlit(&ep->f128);
		ep->SetType(ep->tp);
		break;
	case en_fdiv:
		ep->nodetype = en_fcon;
		ep->f = ep->p[0]->f / ep->p[1]->f;
		ep->tp = ep->p[0]->tp;
		Float128::Div(&ep->f128, &ep->p[0]->f128, &ep->p[1]->f128);
		ep->i = NumericLiteral(ep);
		//		ep->i = quadlit(&ep->f128);
		ep->SetType(ep->tp);
		break;

	case en_padd:
		ep->nodetype = en_pcon;
		ep->tp = ep->p[0]->tp;
		ep->posit.Add(ep->p[0]->posit, ep->p[1]->posit);
		break;
	case en_psub:
		ep->nodetype = en_pcon;
		ep->tp = ep->p[0]->tp;
		ep->posit.Sub(ep->p[0]->posit, ep->p[1]->posit);
		break;
	case en_pmul:
		ep->nodetype = en_pcon;
		ep->tp = ep->p[0]->tp;
		ep->posit.Multiply(ep->p[0]->posit, ep->p[1]->posit);
		break;
	case en_pdiv:
		ep->nodetype = en_pcon;
		ep->tp = ep->p[0]->tp;
		ep->posit.Divide(ep->p[0]->posit, ep->p[1]->posit);
		break;

	case en_asl:
	case en_shl:
	case en_shlu:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i << ep->p[1]->i;
		Int128::Shl(&ep->i128, &ep->p[0]->i128, ep->p[1]->i);
		ep->p[0] = nullptr;
		ep->p[1] = nullptr;
		break;
	case en_asr:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i >> ep->p[1]->i;
		Int128::Shr(&ep->i128, &ep->p[0]->i128, ep->p[1]->i);
		break;
	case en_shr:
		ep->nodetype = en_icon;
		ep->i = (unsigned)ep->p[0]->i >> (unsigned)ep->p[1]->i;
		Int128::Lsr(&ep->i128, &ep->p[0]->i128, ep->p[1]->i);
		break;
	case en_shru:
		ep->nodetype = en_icon;
		ep->i = (unsigned)ep->p[0]->i >> (unsigned)ep->p[1]->i;
		Int128::Lsr(&ep->i128, &ep->p[0]->i128, ep->p[1]->i);
		break;

	case en_and:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i & ep->p[1]->i;
		Int128::BitAnd(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		break;
	case en_or:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i | ep->p[1]->i;
		if (ep->p[0]->i == 0xFFFC0 || ep->p[1]->i == 0xFFFC0)
			printf("Hi");
		Int128::BitOr(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		ep->p[0] = nullptr;
		ep->p[1] = nullptr;
		break;
	case en_xor:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i ^ ep->p[1]->i;
		Int128::BitXor(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		break;
	case en_land_safe:
	case en_land:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i && ep->p[1]->i;
		Int128::LogAnd(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		break;
	case en_lor_safe:
	case en_lor:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i || ep->p[1]->i;
		Int128::LogOr(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
		break;

	case en_ult:
		ep->nodetype = en_icon;
		ep->i = (unsigned)ep->p[0]->i < (unsigned)ep->p[1]->i;
		if (Int128::IsULT(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;
	case en_ule:
		ep->nodetype = en_icon;
		ep->i = (unsigned)ep->p[0]->i <= (unsigned)ep->p[1]->i;
		if (Int128::IsULE(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;
	case en_ugt:
		ep->nodetype = en_icon;
		ep->i = (unsigned)ep->p[0]->i > (unsigned)ep->p[1]->i;
		if (Int128::IsUGT(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;
	case en_uge:
		ep->nodetype = en_icon;
		ep->i = (unsigned)ep->p[0]->i >= (unsigned)ep->p[1]->i;
		if (Int128::IsUGE(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;
	case en_lt:
		ep->nodetype = en_icon;
		ep->i = (signed)ep->p[0]->i < (signed)ep->p[1]->i;
		if (Int128::IsLT(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;
	case en_le:
		ep->nodetype = en_icon;
		ep->i = (signed)ep->p[0]->i <= (signed)ep->p[1]->i;
		if (Int128::IsLE(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;
	case en_gt:
		ep->nodetype = en_icon;
		ep->i = (signed)ep->p[0]->i > (signed)ep->p[1]->i;
		if (Int128::IsGT(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;
	case en_ge:
		ep->nodetype = en_icon;
		ep->i = (signed)ep->p[0]->i >= (signed)ep->p[1]->i;
		if (Int128::IsGE(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;
	case en_eq:
		ep->nodetype = en_icon;
		ep->i = (signed)ep->p[0]->i == (signed)ep->p[1]->i;
		if (Int128::IsEQ(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;
	case en_ne:
		ep->nodetype = en_icon;
		ep->i = (signed)ep->p[0]->i != (signed)ep->p[1]->i;
		if (!Int128::IsEQ(&ep->p[0]->i128, &ep->p[1]->i128))
			Int128::Assign(&ep->i128, Int128::One());
		else
			Int128::Assign(&ep->i128, Int128::Zero());
		break;

	case en_feq:
		ep->nodetype = en_icon;
		ep->i = Float128::IsEqual(&ep->p[0]->f128, &ep->p[1]->f128);
		ep->i128 = Int128::Convert(ep->i);
		break;
	case en_fne:
		ep->nodetype = en_icon;
		ep->i = !Float128::IsEqual(&ep->p[0]->f128, &ep->p[1]->f128);
		ep->i128 = Int128::Convert(ep->i);
		break;
	case en_flt:
		ep->nodetype = en_icon;
		//		ep->i = ep->p[0]->f < ep->p[1]->f;
		ep->i = Float128::IsLessThan(&ep->p[0]->f128, &ep->p[1]->f128);
		ep->i128 = Int128::Convert(ep->i);
		break;
	case en_fle:
		ep->nodetype = en_icon;
		ep->i = Float128::IsLessThan(&ep->p[0]->f128, &ep->p[1]->f128)
			|| Float128::IsEqual(&ep->p[0]->f128, &ep->p[1]->f128);
		ep->i128 = Int128::Convert(ep->i);
		break;
	case en_fgt:
		ep->nodetype = en_icon;
		ep->i = Float128::IsLessThan(&ep->p[1]->f128, &ep->p[0]->f128);
		ep->i128 = Int128::Convert(ep->i);
		break;
	case en_fge:
		ep->nodetype = en_icon;
		ep->i = Float128::IsLessThan(&ep->p[1]->f128, &ep->p[0]->f128)
			|| Float128::IsEqual(&ep->p[0]->f128, &ep->p[1]->f128);
		ep->i128 = Int128::Convert(ep->i);
		break;

	case en_safe_cond:
	case en_cond:
		ep->nodetype = ep->p[1]->p[0]->nodetype;
		ep->i = ep->p[0]->i ? ep->p[1]->p[0]->i : ep->p[1]->p[1]->i;
		if (ep->p[0]->i)
			Int128::Assign(&ep->i128, &ep->p[1]->p[0]->i128);
		else
			Int128::Assign(&ep->i128, &ep->p[1]->p[1]->i128);
		ep->sp = ep->p[0]->i ? ep->p[1]->p[0]->sp : ep->p[1]->p[1]->sp;
		break;

	case en_sxb:
		ep->nodetype = en_icon;
		ep->i = (ep->p[0]->i & 0x80LL) ? ep->p[0]->i | 0xffffffffffffff00LL : ep->p[0]->i;
		ep->i128 = Int128(ep->p[0]->i);
		if (ep->p[0]->i & 0x100LL) {
			ep->i128.high = 0xffffffffffffffffLL;
			ep->i128.low = ep->p[0]->i;
			ep->i128.low |= 0xffffffffffffff00LL;
		}
		break;
	case en_sxc:
		ep->nodetype = en_icon;
		ep->i = (ep->p[0]->i & 0x8000LL) ? ep->p[0]->i | 0xffffffffffff0000LL : ep->p[0]->i;
		ep->i128 = Int128(ep->p[0]->i);
		if (ep->p[0]->i & 0x8000LL) {
			ep->i128.high = 0xffffffffffffffffLL;
			ep->i128.low = ep->p[0]->i;
			ep->i128.low |= 0xffffffffffff0000LL;
		}
		break;
	case en_sxh:
		ep->nodetype = en_icon;
		ep->i = (ep->p[0]->i & 0x80000000LL) ? ep->p[0]->i | 0xffffffff00000000LL : ep->p[0]->i;
		ep->i128 = Int128(ep->p[0]->i);
		if (ep->p[0]->i & 0x80000000LL) {
			ep->i128.high = 0xffffffffffffffffLL;
			ep->i128.low = ep->p[0]->i;
			ep->i128.low |= 0xffffffff00000000LL;
		}
		break;

	case en_zxb:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i & 0xffLL;
		ep->i128 = Int128(ep->p[0]->i);
		ep->i128.high = 0;
		ep->i128.low &= 0xffLL;
		break;
	case en_zxc:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i & 0xffffLL;
		ep->i128 = Int128(ep->p[0]->i);
		ep->i128.high = 0;
		ep->i128.low &= 0xffffLL;
		break;
	case en_zxh:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i & 0xffffffffLL;
		ep->i128 = Int128(ep->p[0]->i);
		ep->i128.high = 0;
		ep->i128.low &= 0xffffffffLL;
		break;

	case en_isnullptr:
		ep->nodetype = en_icon;
		ep->i = ep->p[0]->i == 0 || ep->p[0]->i == 0xFFF0100000000000LL;
		ep->i128.low = 0;
		ep->i128.high = 0;
		if (Int128::IsEQ(&ep->p[0]->i128, Int128::Zero()))
			ep->i128.low = 1;
		break;
	}

	//r = CheckIMatch(node);
	//if (!r)
	//	printf("hi");
}

/*
 *      return which power of two i is or -1.
 */
int pwrof2(int64_t i)
{       
	int p;
	int64_t q;

    q = 1;
    p = 0;
    while( q > 0 )
    {
		if( q == i )
			return (p);
		q <<= 1LL;
		++p;
    }
    return (-1);
}

/*
 *      make a mod mask for a power of two.
 */
int mod_mask(int i)
{   
	int m;
    m = 0;
    while( i-- )
        m = (m << 1) | 1;
    return (m);
}

static void Opt0_addsub(ENODE** node)
{
	ENODE* ep;

	ep = *node;
	if (ep == (ENODE*)NULL)
		return;
	opt0(&(ep->p[0]));
	opt0(&(ep->p[1]));
	if (ep->p[0]->nodetype == en_icon) {
		if (ep->p[1]->nodetype == en_icon) {
			dooper(*node);
			return;
		}
		if (ep->p[0]->i == 0) {
			if (ep->nodetype == en_sub)
			{
				ep->p[0] = ep->p[1];
				ep->nodetype = en_uminus;
			}
			else
				*node = ep->p[1];
			return;
		}
		if (ep->p[0]->nodetype == en_pcon) {
			if (ep->p[1]->nodetype == en_pcon) {
				dooper(*node);
				return;
			}
		}
		// Place the constant node second in the add to allow
		// use of immediate mode instructions.
		if (ep->nodetype == en_add)
			swap_nodes(ep);
	}
	// Add or subtract of zero gets eliminated.
	else if (ep->p[1]->nodetype == en_icon) {
		if (ep->p[1]->i == 0) {
			*node = ep->p[0];
			return;
		}
	}
	return;
}

static void Opt0_multiply(ENODE** node)
{
	ENODE* ep;
	Int128 val;
	Int128 sc;

	ep = *node;
	if (ep == (ENODE*)NULL)
		return;
	opt0(&(ep->p[0]));
	opt0(&(ep->p[1]));
	if (ep->p[0]->nodetype == en_icon) {
		if (ep->p[1]->nodetype == en_icon) {
			dooper(*node);
			return;
		}
		if (ep->p[1]->nodetype == en_fcon) {
			ep->nodetype = en_icon;
			ep->i = ep->p[0]->i * ep->p[1]->f;
			//Int128::Mul(&ep->i128, &ep->p[0]->i128, &ep->p[1]->i128);
			return;
		}
		val = ep->p[0]->i128;
		if (Int128::IsEQ(&val, Int128::Zero())) {
			*node = ep->p[0];
			return;
		}
		if (Int128::IsEQ(&val, Int128::One())) {
			*node = ep->p[1];
			ooptimized++;
			return;
		}
		sc = val.pwrof2();
		if (!(sc.high == -1 && sc.low == -1))
		{
			swap_nodes(ep);
			ep->p[1]->i = sc.low;
			ep->p[1]->i128 = sc;
			ep->nodetype = en_shl;
			ooptimized++;
			return;
		}
		// Place constant as oper2
		swap_nodes(ep);
	}
	else if (ep->p[1]->nodetype == en_icon) {
		val = ep->p[1]->i128;
		if (Int128::IsEQ(&val, Int128::Zero())) {
			*node = ep->p[1];
			ooptimized++;
			return;
		}
		if (Int128::IsEQ(&val, Int128::One())) {
			*node = ep->p[0];
			ooptimized++;
			return;
		}
		sc = val.pwrof2();
		if (!(sc.high == -1 && sc.low == -1))
		{
			ep->p[1]->i = sc.low;
			ep->p[1]->i128 = sc;
			ep->nodetype = en_shl;
			ooptimized++;
			return;
		}
	}
}

static void Opt0_logic(ENODE** node)
{
	ENODE* ep;

	ep = *node;
	if (ep == (ENODE*)NULL)
		return;
	opt0(&(ep->p[0]));
	opt0(&(ep->p[1]));
	if (ep->p[0]->nodetype == en_icon &&
		ep->p[1]->nodetype == en_icon)
		dooper(*node);
	else if (ep->p[0]->nodetype == en_icon) {
		swap_nodes(ep);
		ooptimized++;
	}
}

static void Opt0_shift(ENODE** node)
{
	ENODE* ep;

	ep = *node;
	if (ep == (ENODE*)NULL)
		return;
	opt0(&(ep->p[0]));
	opt0(&(ep->p[1]));
	if (ep->p[0]->nodetype == en_icon &&
		ep->p[1]->nodetype == en_icon)
		dooper(*node);
	// Shift by zero....
	else if (ep->p[1]->nodetype == en_icon) {
		if (Int128::IsEQ(&ep->p[1]->i128, Int128::Zero())) {
			*node = ep->p[0];
			ooptimized++;
			return;
		}
	}
}

static void Opt0_releq(ENODE** node)
{
	ENODE* ep;

	ep = *node;
	if (ep == (ENODE*)NULL)
		return;
	opt0(&(ep->p[0]));
	opt0(&(ep->p[1]));
	if (ep->p[0]->nodetype == en_icon &&
		ep->p[1]->nodetype == en_icon)
		dooper(*node);
	else if (ep->p[0]->nodetype == en_icon) {
		swap_nodes(ep);
		ooptimized++;
	}
}

static void Opt0_relop(ENODE** node)
{
	ENODE* ep;

	ep = *node;
	if (ep == (ENODE*)NULL)
		return;
	opt0(&(ep->p[0]));
	opt0(&(ep->p[1]));
	if (ep->p[0]->nodetype == en_icon &&
		ep->p[1]->nodetype == en_icon)
		dooper(*node);
}

/*
 *      opt0 - delete useless expressions and combine constants.
 *
 *      opt0 will delete expressions such as x + 0, x - 0, x * 0,
 *      x * 1, 0 / x, x / 1, x mod 0, etc from the tree pointed to
 *      by node and combine obvious constant operations. It cannot
 *      combine name and label constants but will combine icon type
 *      nodes.
 */
static void opt0(ENODE **node)
{
	ENODE *ep;
  int sc;
	int64_t val;

  ep = *node;
  if( ep == (ENODE *)NULL )
    return;
  switch( (*node)->nodetype ) {
  case en_ref:
	case en_ccwp:
	case en_cucwp:
	case en_ccl:
	case en_cuclp:
		opt0(&((*node)->p[0]));
		return;
	case en_cubw:	case en_cubl:
	case en_cucw: case en_cucl:
	case en_cuhw: case en_cuhl:
	case en_cubu:
	case en_cucu:
	case en_cuhu:
	case en_cbu:
	case en_ccu:
	case en_chu:
	case en_cbc:
	case en_cbh:
	case en_cbw:
	case en_cbl:
	case en_cch:
	case en_ccw:
	case en_chw:
	case en_cwl:
    opt0( &(ep->p[0]));
		if (ep->p[0]->nodetype == en_icon) {
			ep->nodetype = en_icon;
			ep->i = ep->p[0]->i;
			ep->i128 = ep->p[0]->i128;
			ooptimized++;
		}
    return;
	case en_sxb:
	case en_sxc:
	case en_sxh:
	case en_zxb: case en_zxc: case en_zxh:
	case en_abs:
    opt0( &(ep->p[0]));
    if( ep->p[0]->nodetype == en_icon )
			dooper(*node);
		return;
	case en_compl:
    opt0( &(ep->p[0]));
    if( ep->p[0]->nodetype == en_icon )
    {
      ep->nodetype = en_icon;
      ep->i = ~ep->p[0]->i;
			ep->i128.low = ~ep->p[0]->i128.low;
			ep->i128.high = ~ep->p[0]->i128.high;
			ooptimized++;
		}
    return;
	case en_not:
    opt0( &(ep->p[0]));
    if( ep->p[0]->nodetype == en_icon )
    {
      ep->nodetype = en_icon;
      ep->i = !ep->p[0]->i;
			ep->i128 = Int128::IsEQ(&ep->p[0]->i128, Int128::Zero()) ? Int128(1) : Int128(0);
			ooptimized++;
		}
    return;
  case en_uminus:
    opt0( &(ep->p[0]));
    if( ep->p[0]->nodetype == en_icon )
    {
      ep->nodetype = en_icon;
      ep->i = -ep->p[0]->i;
			Int128::Sub(&ep->i128, Int128::Zero(), &ep->p[0]->i128);
			ooptimized++;
		}
    return;
            case en_tempref:
                    opt0( &(ep->p[0]));
                    if( ep->p[0] && ep->p[0]->nodetype == en_icon )
                    {
                        ep->nodetype = en_icon;
                        ep->i = ep->p[0]->i;
												ep->i128 = ep->p[0]->i128;
												ooptimized++;
										}
										else if (ep->constflag) {
											ep->nodetype = en_icon;
											ooptimized++;
										}
                    return;
            case en_tempfpref:
              opt0( &(ep->p[0]));
              if( ep->p[0] && ep->p[0]->nodetype == en_fcon )
              {
                ep->nodetype = en_fcon;
                ep->f = ep->p[0]->f;
								Float128::Assign(&ep->f128,&ep->p[0]->f128);
								ooptimized++;
							}
              return;
						case en_temppref:
							opt0(&(ep->p[0]));
							if (ep->p[0] && ep->p[0]->nodetype == en_pcon)
							{
								ep->nodetype = en_pcon;
								ep->posit = ep->p[0]->posit;
								ooptimized++;
							}
							return;
						case en_vadd:
						case en_vsub:
            case en_add:
            case en_sub:
							Opt0_addsub(node);
							return;
							/*
              opt0(&(ep->p[0]));
              opt0(&(ep->p[1]));
              if(ep->p[0]->nodetype == en_icon) {
                if(ep->p[1]->nodetype == en_icon) {
                  dooper(*node);
                  return;
                }
                if( ep->p[0]->i == 0 ) {
									if( ep->nodetype == en_sub )
									{
										ep->p[0] = ep->p[1];
										ep->nodetype = en_uminus;
									}
									else
										*node = ep->p[1];
								return;
              }
								if (ep->p[0]->nodetype == en_pcon) {
									if (ep->p[1]->nodetype == en_pcon) {
										dooper(*node);
										return;
									}
								}
						// Place the constant node second in the add to allow
						// use of immediate mode instructions.
						if (ep->nodetype==en_add)
							swap_nodes(ep);
                    }
					// Add or subtract of zero gets eliminated.
                    else if( ep->p[1]->nodetype == en_icon ) {
                        if( ep->p[1]->i == 0 ) {
                            *node = ep->p[0];
                            return;
                        }
                    }
                    return;
										*/
						case en_ptrdif:
							opt0(&(ep->p[0]));
							opt0(&(ep->p[1]));
							opt0(&(ep->p[4]));
							if (ep->p[0]->nodetype == en_icon) {
								if (ep->p[1]->nodetype == en_icon && ep->p[4]->nodetype == en_icon) {
									dooper(*node);
									return;
								}
							}
							break;
						case en_i2p:
						case en_i2d:
				opt0(&(ep->p[0]));
				if (ep->p[0]->nodetype == en_icon) {
					dooper(*node);
					return;
				}
				break;
			case en_d2i:
				opt0(&(ep->p[0]));
				if (ep->p[0]->nodetype == en_fcon) {
					ep->i = (long)ep->p[0]->f;
					ep->i128 = Int128::Convert(ep->i);
					ep->nodetype = en_icon;
					ooptimized++;
					return;
				}
				break;
			case en_fadd:
			case en_fsub:
				opt0(&(ep->p[0]));
				opt0(&(ep->p[1]));
				if (ep->p[0]->nodetype == en_fcon) {
					if (ep->p[1]->nodetype == en_fcon) {
						dooper(*node);
						return;
					}
				}
				break;
			case en_fmul:
				opt0(&(ep->p[0]));
				opt0(&(ep->p[1]));
				if (ep->p[0]->nodetype == en_fcon) {
					if (ep->p[1]->nodetype == en_fcon) {
						dooper(*node);
						return;
					}
					//else if (ep->p[1]->nodetype == en_icon) {
					//	ep->nodetype = en_fcon;
					//	ep->f = ep->p[0]->f * ep->p[1]->i;
					//	return;
					//}
				}
				//else if (ep->p[0]->nodetype == en_icon) {
				//	if (ep->p[1]->nodetype == en_fcon) {
				//		ep->nodetype = en_fcon;
				//		ep->f = ep->p[0]->i * ep->p[1]->f;
				//		return;
				//	}
				//}
				break;
			case en_fdiv:
				opt0(&(ep->p[0]));
				opt0(&(ep->p[1]));
				if (ep->p[0]->nodetype == en_fcon) {
					if (ep->p[1]->nodetype == en_fcon) {
						dooper(*node);
						return;
					}
					//else if (ep->p[1]->nodetype == en_icon) {
					//	ep->nodetype = en_fcon;
					//	ep->f = ep->p[0]->f / ep->p[1]->i;
					//	return;
					//}
				}
				break;

			case en_padd:
			case en_psub:
				opt0(&(ep->p[0]));
				opt0(&(ep->p[1]));
				if (ep->p[0]->nodetype == en_pcon) {
					if (ep->p[1]->nodetype == en_pcon) {
						dooper(*node);
						return;
					}
				}
				break;
			case en_pmul:
				opt0(&(ep->p[0]));
				opt0(&(ep->p[1]));
				if (ep->p[0]->nodetype == en_pcon) {
					if (ep->p[1]->nodetype == en_pcon) {
						dooper(*node);
						return;
					}
				}
				break;
			case en_pdiv:
				opt0(&(ep->p[0]));
				opt0(&(ep->p[1]));
				if (ep->p[0]->nodetype == en_pcon) {
					if (ep->p[1]->nodetype == en_pcon) {
						dooper(*node);
						return;
					}
				}
				break;

			case en_isnullptr:
				opt0(&(ep->p[0]));
				if (ep->p[0]->nodetype == en_icon)
					dooper(*node);
				return;
			case en_wydendx:
			case en_bytendx:
				opt0(&(ep->p[0]));
				opt0(&(ep->p[1]));
				return;
			case en_mulf:		Opt0_multiply(node); break;
			case en_vmul:		Opt0_multiply(node); break;
			case en_vmuls:	Opt0_multiply(node); break;
      case en_mul:		Opt0_multiply(node); break;
			case en_mulu:		Opt0_multiply(node); break;
      case en_div:
			case en_udiv:
        opt0(&(ep->p[0]));
        opt0(&(ep->p[1]));
        if( ep->p[0]->nodetype == en_icon ) {
          if( ep->p[1]->nodetype == en_icon ) {
            dooper(*node);
            return;
          }
          if( ep->p[0]->i == 0 ) {    /* 0/x */
						*node = ep->p[0];
						ooptimized++;
						return;
          }
        }
        else if( ep->p[1]->nodetype == en_icon ) {
          val = ep->p[1]->i;
          if( val == 1 ) {        /* x/1 */
            *node = ep->p[0];
						ooptimized++;
						return;
          }
          sc = pwrof2(val);
          if( sc != -1 )
          {
            ep->p[1]->i = sc;
						ep->p[1]->i128.low = sc;
						ep->p[1]->i128.high = 0;
						if ((*node)->nodetype == en_udiv)
							ep->nodetype = en_shru;
						else
							ep->nodetype = en_shr;// ep->p[0]->isUnsigned ? en_shru : en_shr;???B
						ooptimized++;
					}
        }
        break;
            case en_mod:
                    opt0(&(ep->p[0]));
                    opt0(&(ep->p[1]));
                    if( ep->p[1]->nodetype == en_icon )
                            {
                            if( ep->p[0]->nodetype == en_icon )
                                    {
                                    dooper(*node);
                                    return;
                                    }
                            sc = pwrof2(ep->p[1]->i);
                            if( sc != -1 )
                                    {
                                    ep->p[1]->i = mod_mask(sc);
																		ep->p[1]->i128 = Int128(mod_mask(sc));
                                    ep->nodetype = en_and;
																		ooptimized++;
														}
                            }
                    break;
	case en_fieldref:
		opt0(&(ep->p[0]));
		opt0(&(ep->bit_offset));
		opt0(&(ep->bit_width));
		break;
	case en_bitoffset:
	case en_ext:
	case en_extu:
		opt0(&(ep->p[0]));
		opt0(&(ep->p[1]));
		opt0(&(ep->p[2]));
		break;

	case en_and:	Opt0_logic(node); break;
	case en_xor:	Opt0_logic(node); break;
	case en_or:		Opt0_logic(node); break;

	case en_shr:	Opt0_shift(node); break;
	case en_shru:	Opt0_shift(node); break;
	case en_asr:	Opt0_shift(node); break;
	case en_asl:	Opt0_shift(node); break;
	case en_shl:	Opt0_shift(node); break;
	case en_shlu:	Opt0_shift(node); break;
	case en_rol:	Opt0_shift(node); break;
	case en_ror:	Opt0_shift(node); break;

	case en_land_safe:	Opt0_logic(node); break;
  case en_land:				Opt0_logic(node); break;
	case en_lor_safe:		Opt0_logic(node); break;
  case en_lor:				Opt0_logic(node); break;

	case en_ult:	Opt0_relop(node); break;
	case en_ule:	Opt0_relop(node); break;
	case en_ugt:	Opt0_relop(node); break;
	case en_uge:	Opt0_relop(node); break;
	case en_lt:		Opt0_relop(node); break;
	case en_le:		Opt0_relop(node); break;
	case en_gt:		Opt0_relop(node); break;
	case en_ge:		Opt0_relop(node); break;
	case en_eq:		Opt0_releq(node); break;
	case en_ne:		Opt0_releq(node); break;

	case en_feq:
	case en_fne:
	case en_flt:
	case en_fle:
	case en_fgt:
	case en_fge:
		opt0(&(ep->p[0]));
		opt0(&(ep->p[1]));
		if (ep->p[0]->nodetype == en_fcon && ep->p[1]->nodetype == en_fcon)
			dooper(*node);
		break;
                case en_veq:    case en_vne:
                case en_vlt:    case en_vle:
                case en_vgt:    case en_vge:
                    opt0(&(ep->p[0]));
                    opt0(&(ep->p[1]));
                    break;
								case en_safe_cond:
			case en_cond:
                    opt0(&(ep->p[0]));
					opt0(&(ep->p[1]->p[0]));
					opt0(&(ep->p[1]->p[1]));
					if ((ep->p[0]->nodetype==en_icon||ep->p[0]->nodetype==en_cnacon) &&
						 (ep->p[1]->p[0]->nodetype==en_icon || ep->p[1]->p[0]->nodetype==en_cnacon) &&
						 (ep->p[1]->p[1]->nodetype==en_icon || ep->p[1]->p[1]->nodetype==en_cnacon))
						dooper(*node);
					break;
            case en_chk:
                    opt0(&(ep->p[0]));
					opt0(&(ep->p[1]));
					opt0(&(ep->p[2]));
					break;
  case en_asand:  case en_asor:
  case en_asadd:  case en_assub:
  case en_asmul:  case en_asdiv:
  case en_asmod:  case en_asrsh:
  case en_aslsh:  
  case en_fcall:
    opt0(&(ep->p[0]));
    opt0(&(ep->p[1]));
    break;
  case en_assign:
    opt0(&(ep->p[0]));
    opt0(&(ep->p[1]));
    break;
	case en_void:
		opt0(&(ep->p[0]));
		opt0(&(ep->p[1]));
		break;
	// en_tempref comes from typecasting
	// The value for a cast is really ep->p[1]
	// The type of the cast is from ep->p[0]
	case en_cast:
		opt0(&(ep->p[0]));
		opt0(&(ep->p[1]));
		if (ep->p[0]->nodetype == en_tempref) {
			//(*node)->nodetype = ep->p[1]->nodetype;
			*node = ep->p[1];
			(*node)->tp = ep->p[0]->tp;
			(*node)->nodetype = ep->p[0]->nodetype;
			ooptimized++;
		}
		break;
	case en_addrof:
		opt0(&(ep->p[0]));
		break;
	case en_list:
		for (ep = ep->p[2]; ep; ep = ep->p[2])
			opt0(&(ep->p[0]));
		break;
	}
}

/*
 *      xfold will remove constant nodes and return the values to
 *      the calling routines.
 */
static Int128 xfold(ENODE *node)
{
	int64_t i;
	Int128 i128, p0, p1;

  if( node == nullptr )
    return (0);
  switch( node->nodetype )
  {
  case en_icon:
		i128 = node->i128;
    node->i = 0;
		node->i128 = *Int128::Zero();
    return (i128);
	case en_pcon:
		i128 = Int128(node->posit.val);
		node->posit.val = 0;
		return i128;
	case en_pregvar:
		if (node->rg == regZero) {
			i128 = *Int128::Zero();
			node->posit = 0;
			return (i128);
		}
		return (*Int128::Zero());
	case en_regvar:
		if (node->rg == regZero) {
			i128 = *Int128::Zero();
			node->i = 0;
			return (i128);
		}
		return (0);
	case en_sxb: case en_sxc: case en_sxh:
	case en_zxb: case en_zxc: case en_zxh:
	case en_abs:
	case en_isnullptr:
		return (*Int128::Zero());
		return xfold(node->p[0]);
  case en_add:
		p0 = xfold(node->p[0]);
		p1 = xfold(node->p[1]);
		Int128::Add(&i128, &p0, &p1);
    return i128;
  case en_sub:
		p0 = xfold(node->p[0]);
		p1 = xfold(node->p[1]);
		Int128::Sub(&i128, &p0, &p1);
		return i128;
	case en_mulf:
  case en_mul:
	case en_mulu:
//		return (0);
		if (node->p[0]->nodetype == en_icon) {
			p0 = node->p[0]->i128;
			p1 = xfold(node->p[1]);
			Int128::Mul(&i128, &p0, &p1);
			return (i128);
		}
		else if (node->p[1]->nodetype == en_icon) {
			p0 = xfold(node->p[0]);
			p1 = node->p[1]->i128;
			Int128::Mul(&i128, &p0, &p1);
			return (i128);
		}
    else
			return (*Int128::Zero());
	case en_asl:
	case en_shl:
	case en_shlu:
		if (node->p[0]->nodetype == en_icon) {
			p0 = node->p[0]->i128;
			p1 = xfold(node->p[1]);
			Int128::Shl(&i128, &p0, p1.low);
			return (i128);
//			return xfold(node->p[1]) << node->p[0]->i;
		}
		else if (node->p[1]->nodetype == en_icon) {
			p0 = xfold(node->p[0]);
			p1 = node->p[1]->i128;
			Int128::Shl(&i128, &p0, p1.low);
			return (i128);
			//			return xfold(node->p[0]) << node->p[1]->i;
		}
    else
			return *Int128::Zero();
  case en_uminus:
		p0 = xfold(node->p[0]);
		Int128::Sub(&i128, Int128::Zero(), &p0);
    return (i128);
	case en_ext:
	case en_extu:
		fold_const(&node->p[0]);
		fold_const(&node->p[1]);
		fold_const(&node->p[2]);
		return *Int128::Zero();
	case en_shr:    case en_div:	case en_udiv:	case en_shru: case en_asr:
	case en_mod:    case en_asadd:	case en_bytendx:	case en_wydendx:
  case en_assub:  case en_asmul:
  case en_asdiv:  case en_asmod:
	case en_and:    case en_land:	case en_land_safe:
	case en_lor:	case en_lor_safe:
  case en_xor:    case en_asand:
	case en_asor:   case en_void:		case en_cast:
  case en_fcall:  case en_assign:
          fold_const(&node->p[0]);
          fold_const(&node->p[1]);
          return *Int128::Zero();
	case en_ref:
  case en_compl:
  case en_not:
		fold_const(&node->p[0]);
		return *Int128::Zero();
	case en_or:
		if (node->p[0]->nodetype == en_icon) {
			p0 = node->p[0]->i128;
			p1 = xfold(node->p[1]);
			Int128::BitOr(&i128, &p0, &p1);
			return (i128);
			//			return xfold(node->p[1]) << node->p[0]->i;
		}
		else if (node->p[1]->nodetype == en_icon) {
			p0 = xfold(node->p[0]);
			p1 = node->p[1]->i128;
			Int128::BitOr(&i128, &p0, &p1);
			return (i128);
			//			return xfold(node->p[0]) << node->p[1]->i;
		}
		else
			return *Int128::Zero();
  }
  return *Int128::Zero();
}

/*
 *      reorganize an expression for optimal constant grouping.
 */
static void fold_const(ENODE **node)
{       
	ENODE *ep;
  int64_t i;
	Int128 i128, p0, p1;

  ep = *node;
  if(ep == nullptr)
    return;
  if(ep->nodetype == en_add)
  {
		if(ep->p[0]->nodetype == en_icon)
		{
			p1 = xfold(ep->p[1]);
			Int128::Add(&ep->p[0]->i128, &ep->p[0]->i128, &p1);
			return;
		}
		else if( ep->p[1]->nodetype == en_icon )
		{
			p0 = xfold(ep->p[0]);
			Int128::Add(&ep->p[1]->i128, &p0, &ep->p[1]->i128);
			return;
		}
  }
  else if (ep->nodetype == en_sub)
  {
		if (ep->p[0]->nodetype == en_icon)
		{
			p1 = xfold(ep->p[1]);
			Int128::Sub(&ep->p[0]->i128, &ep->p[0]->i128, &p1);
			return;
		}
		else if (ep->p[1]->nodetype == en_icon)
		{
			p0 = xfold(ep->p[0]);
			Int128::Sub(&ep->p[1]->i128, &p0, &ep->p[1]->i128);
			return;
		}
  }
	else if (ep->nodetype == en_or)
	{
		if (ep->p[0]->nodetype == en_icon)
		{
			p1 = xfold(ep->p[1]);
			Int128::BitOr(&ep->p[0]->i128, &ep->p[0]->i128, &p1);
			return;
		}
		else if (ep->p[1]->nodetype == en_icon)
		{
			p0 = xfold(ep->p[0]);
			Int128::BitOr(&ep->p[1]->i128, &p0, &ep->p[1]->i128);
			return;
		}
	}
	i128 = xfold(ep);
  if(!Int128::IsEQ(&i128, Int128::Zero()))
  {
		ep = makei128node(en_icon,i128);
		ep->etype = (*node)->etype;
		ep->tp = (*node)->tp;
		ep = makenode(en_add,ep,*node);
		ep->etype = (*node)->etype;
		ep->tp = (*node)->tp;
		*node = ep;
  }
}

// Debug routines
static bool IMatches(ENODE* node)
{
	if (node->i == node->i128.low)
		return (true);
	return (false);
}

static bool CheckIMatch(ENODE* node)
{
	bool r0, r1, r2, r3, r4;

	if (node->nodetype == en_icon) {
		return (IMatches(node));
	}
	r0 = true;
	r1 = true;
	r2 = true;
	r3 = true;
	if (node->p[0])
		r0 = CheckIMatch(node->p[0]);
	if (node->p[1])
		r1 = CheckIMatch(node->p[1]);
	if (node->p[2])
		r2 = CheckIMatch(node->p[2]);
	if (node->p[3])
		r3 = CheckIMatch(node->p[3]);
	return (r0 & r1 & r2 & r3);
}

void opt_const_unchecked(ENODE **node)
{
	//bool r;
	//bool s = CheckIMatch(*node);

	dfs.printf("<OptConst2>");
	opt0(node);
	fold_const(node);
	do {
		ooptimized = false;
		opt0(node);
	} while (ooptimized);
	dfs.printf("</OptConst2>");

	//r = CheckIMatch(*node);
	//if (!r)
	//	printf("Ji");
}

//
//      apply all constant optimizations.
//
void opt_const(ENODE **node)
{
	//bool r;
	//bool s = CheckIMatch(*node);

	dfs.printf("<OptConst>");
    if (opt_noexpr==FALSE) {
    	opt0(node);
//    	fold_const(node);
			do {
				ooptimized = false;
				opt0(node);
			} while (ooptimized);
		}
	dfs.printf("</OptConst>");

	//r = CheckIMatch(*node);
	//if (!r)
	//	printf("Ji");
}

