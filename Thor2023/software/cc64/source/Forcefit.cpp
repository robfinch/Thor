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

// ----------------------------------------------------------------------------
// forcefit will coerce the nodes passed into compatible
// types and return the type of the resulting expression.
//
// Generally if the promote flag is set then the whichever type is larger
// is returned. Code is emitted to convert the shorter type to the longer type.
// Unless... a explicit typecast is taking place. The typecast using the
// typecast operator OR an assignment is taking place.
// ----------------------------------------------------------------------------
TYP *forcefit(ENODE **srcnode, TYP *srctp, ENODE **dstnode, TYP *dsttp, bool promote, bool typecast)
{
	ENODE *n2;
	int nt, typ;
	bool fc;
	bool *fcd = &fc;

	*fcd = false;
	if (dsttp == nullptr || srctp == nullptr) {
		error(ERR_NULLPOINTER);
		return (&stdint);
	};
	if (dstnode)
		n2 = *dstnode;
	else
		n2 = (ENODE *)NULL;
	if (typecast) {
		switch (dsttp->type) {
		case bt_void:
			return (srctp);
		case bt_bit:
			return (dsttp);
			break;
		case bt_byte:
		case bt_ubyte:
			switch (srctp->type) {
			case bt_ubyte: return (dsttp);
			case bt_byte:	 return (dsttp);
			case bt_iuchar:
			case bt_uchar: return (dsttp);
			case bt_ichar:
			case bt_char:  return (dsttp);
				// value will be truncated
			case bt_short:
			case bt_ushort:	return (dsttp);
			case bt_exception:
			case bt_int:
			case bt_uint:
			case bt_long:
			case bt_ulong:	return (dsttp);
			case bt_ubitfield:
			case bt_bitfield: goto j1;
			case bt_float:	nt = en_d2i; break;
			case bt_double: nt = en_d2i; break;
			case bt_posit:  nt = en_p2i; break;
			default: 
				goto j1;
			}
			if (fcd) *fcd = true;
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = 8;
			return (dsttp);

		case bt_ichar:
		case bt_char:
			switch (srctp->type) {
			case bt_ubyte: nt = en_ubyt2octa; break;
			case bt_byte:	nt = en_byt2octa; break;
			case bt_iuchar:
			case bt_uchar: return (dsttp);
			case bt_ichar:
			case bt_char:  return (dsttp);
				// value will be truncated
			case bt_short:
			case bt_ushort:	return (dsttp);
			case bt_int:
			case bt_uint:	return (dsttp);
			case bt_exception:
			case bt_long:
			case bt_ulong:	return (dsttp);
			case bt_ubitfield:
			case bt_bitfield: goto j1;
			case bt_float:	nt = en_d2i; break;
			case bt_double: nt = en_d2i; break;
			case bt_posit:  nt = en_p2i; break;
			default: 
				goto j1;
			}
			if (fcd) *fcd = true;
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = 8;
			return (dsttp);

		case bt_iuchar:
		case bt_uchar:
			switch (srctp->type) {
			case bt_ubyte: nt = en_ubyt2octa; break;
			case bt_byte:	nt = en_byt2octa; break;
			case bt_iuchar:
			case bt_uchar: return (dsttp);
			case bt_ichar:
			case bt_char:
				if (fcd) *fcd = true;
				//*srcnode = makenode(en_wyde2hexi, *srcnode, nullptr);
				//(*dstnode)->esize = (*dstnode)->p[1]->esize;
				return (dsttp);
			// value will be truncated
			case bt_short:
			case bt_ushort:	return (dsttp);
			case bt_int:
			case bt_uint:	return (dsttp);
			case bt_exception:
			case bt_long:
			case bt_ulong:	return (dsttp);
			case bt_ubitfield:
			case bt_bitfield: goto j1;
			case bt_float:	*srcnode = makenode(en_d2i, *srcnode, nullptr); 
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_double: *srcnode = makenode(en_d2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_posit:  *srcnode = makenode(en_p2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			default:
				goto j1;
			}
			if (fcd) *fcd = true;
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = 8;
			return (dsttp);

		case bt_short:
			switch (srctp->type) {
			case bt_ubyte:	*srcnode = makenode(en_ubyt2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_byte:		*srcnode = makenode(en_byt2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_iuchar:
			case bt_uchar:	*srcnode = makenode(en_uwyde2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_ichar:
			case bt_char:		*srcnode = makenode(en_wyde2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_short:
			case bt_ushort:	return (dsttp);
			case bt_int:
			case bt_uint:	return (dsttp);
			case bt_exception:
			// value will be truncated
			case bt_long:
			case bt_ulong :	return (dsttp);
			case bt_ubitfield:
			case bt_bitfield: goto j1;
			case bt_float:	*srcnode = makenode(en_d2i, *srcnode, nullptr); 
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_double: *srcnode = makenode(en_d2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_posit:  *srcnode = makenode(en_p2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			default:
				goto j1;
			}
			if (fcd) *fcd = true;
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = 8;
			return (dsttp);

		case bt_ushort:
			switch (srctp->type) {
			case bt_ubyte:	*srcnode = makenode(en_ubyt2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_byte:		*srcnode = makenode(en_byt2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_iuchar:
			case bt_uchar:	*srcnode = makenode(en_uwyde2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_ichar:
			case bt_char:		*srcnode = makenode(en_wyde2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_short:
			case bt_ushort:	return (dsttp);
			case bt_int:
			case bt_uint:	return (dsttp);
			case bt_exception:
				// value will be truncated
			case bt_long:
			case bt_ulong:	return (dsttp);
			case bt_ubitfield:
			case bt_bitfield: goto j1;
			case bt_float:	*srcnode = makenode(en_d2i, *srcnode, nullptr); 
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_double: *srcnode = makenode(en_d2i, *srcnode, nullptr); 
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_posit:  *srcnode = makenode(en_p2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			default:
				goto j1;
			}
			if (fcd) *fcd = true;
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = 8;
			return (dsttp);

		case bt_int:
			switch (srctp->type) {
			case bt_ubyte:	*srcnode = makenode(en_ubyt2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_byte:		*srcnode = makenode(en_byt2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_iuchar:
			case bt_uchar:	*srcnode = makenode(en_uwyde2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_ichar:
			case bt_char:		*srcnode = makenode(en_wyde2octa, *srcnode, nullptr);
				return (dsttp);
			case bt_short:
				*srcnode = makenode(en_tetra2octa, *srcnode, nullptr);
				return (dsttp);
			case bt_ushort:
				*srcnode = makenode(en_utetra2octa, *srcnode, nullptr);
				return (dsttp);
			case bt_int:
			case bt_uint:	return (dsttp);
			case bt_exception:
				// value will be truncated
			case bt_long:
			case bt_ulong:	return (dsttp);
			case bt_ubitfield:
			case bt_bitfield: goto j1;
			case bt_float:	*srcnode = makenode(en_d2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_double: *srcnode = makenode(en_d2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_quad: *srcnode = makenode(en_q2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_posit:  *srcnode = makenode(en_p2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			default:
				goto j1;
			}
			if (fcd) *fcd = true;
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = 8;
			return (dsttp);

		case bt_uint:
			switch (srctp->type) {
			case bt_ubyte:	*srcnode = makenode(en_ubyt2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_byte:		*srcnode = makenode(en_byt2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_iuchar:
			case bt_uchar:	*srcnode = makenode(en_uwyde2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_ichar:
			case bt_char:		*srcnode = makenode(en_wyde2octa, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_short:
			case bt_ushort:	return (dsttp);
			case bt_int:
			case bt_uint:	return (dsttp);
			case bt_exception:
				// value will be truncated
			case bt_long:
			case bt_ulong:	return (dsttp);
			case bt_ubitfield:
			case bt_bitfield: goto j1;
			case bt_float:	*srcnode = makenode(en_d2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_double: *srcnode = makenode(en_d2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_quad: *srcnode = makenode(en_q2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_posit:  *srcnode = makenode(en_p2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			default: 
				goto j1;
			}
			if (fcd) *fcd = true;
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = 8;
			return (dsttp);

		case bt_ulong:
		case bt_long:
			switch (srctp->type) {
			case bt_ubyte:	*srcnode = makenode(en_ubyt2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_byte:		*srcnode = makenode(en_byt2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_iuchar:
			case bt_uchar:	*srcnode = makenode(en_uwyde2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_ichar:
			case bt_char:		*srcnode = makenode(en_wyde2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_short:	*srcnode = makenode(en_tetra2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_ushort:	*srcnode = makenode(en_utetra2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_int:	*srcnode = makenode(en_octa2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_uint:	*srcnode = makenode(en_uocta2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_exception:
			case bt_long: return (dsttp);// *dstnode = *srcnode; return (dsttp);
			case bt_ulong: return (dsttp);// *dstnode = *srcnode; return (dsttp);
			case bt_pointer:	return (dsttp);
			case bt_ubitfield:
			case bt_bitfield: goto j1;
			case bt_float:	*srcnode = makenode(en_d2i, *srcnode, nullptr); (*srcnode)->tp = dsttp; 
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_double: *srcnode = makenode(en_d2i, *srcnode, nullptr); (*srcnode)->tp = dsttp;
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_quad: *srcnode = makenode(en_q2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_posit:  *srcnode = makenode(en_p2i, *srcnode, nullptr); (*srcnode)->tp = dsttp;
				return (dsttp);
			default:	
				goto j1;
			}
			if (fcd) *fcd = true;
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = 8;
			return (dsttp);

		case bt_pointer:
			switch (srctp->type) {
			case bt_byte:		*srcnode = makenode(en_byt2hexi, *srcnode, nullptr); 
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_ubyte:	*srcnode = makenode(en_ubyt2hexi, *srcnode, nullptr); 
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_char:		*srcnode = makenode(en_wyde2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_ichar:	*srcnode = makenode(en_wyde2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_uchar:	*srcnode = makenode(en_uwyde2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_iuchar: *srcnode = makenode(en_uwyde2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_short:	*srcnode = makenode(en_tetra2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_ushort:	*srcnode = makenode(en_utetra2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_int:	*srcnode = makenode(en_octa2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_uint:	*srcnode = makenode(en_uocta2hexi, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_exception:
			case bt_long:		return (dsttp);
			case bt_ulong:	return (dsttp);
			case bt_pointer:
				if (dsttp->btpp)
					typ = dsttp->btpp->type;
				/**dstnode = *srcnode;*/
				return (dsttp);
			case bt_ubitfield:
			case bt_bitfield: goto j1;
			case bt_float:	*srcnode = makenode(en_d2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_double: *srcnode = makenode(en_d2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_posit:  *srcnode = makenode(en_p2i, *srcnode, nullptr);
				if (fcd) *fcd = true;
				return (dsttp);
			case bt_func:
			case bt_ifunc:	return (dsttp);
			// void source inherits destination type.
			case bt_void:		return (dsttp);
			default:	
				goto j1;
			}
			if (fcd) *fcd = true;
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = sizeOfPtr;
			return (dsttp);

		case bt_float:
			switch (srctp->type) {
			case bt_byte:		*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_ubyte:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_char:		*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_uchar:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_ichar:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_iuchar: *srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_short:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_ushort: *srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_int:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_uint: *srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_exception:
			case bt_long:		*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_ulong:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_pointer:	return (dsttp);
			case bt_float:	return (dsttp);
			case bt_double: return(dsttp);	// convert double to single
			case bt_posit:	*srcnode = makenode(en_p2d, *srcnode, nullptr); return (dsttp);
			default:	
				goto j1;
			}
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = sizeOfFPD;
			return (dsttp);
		case bt_double:
			switch (srctp->type) {
			case bt_byte:		*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_ubyte:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_char:		*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_uchar:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_ichar:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_iuchar: *srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_short:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_ushort: *srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_int:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_uint: *srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_exception:
			case bt_long:		*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_ulong:	*srcnode = makenode(en_i2d, *srcnode, nullptr); return (dsttp);
			case bt_pointer:return (dsttp);
			case bt_float:	return (dsttp);
			case bt_double: return(dsttp);
			case bt_posit:	*srcnode = makenode(en_p2d, *srcnode, nullptr); return (dsttp);
			default:
				goto j1;
			}
			*dstnode = makenode(nt, *srcnode, *dstnode);
			(*dstnode)->esize = sizeOfFPD;
			return (dsttp);
			//case bt_double:
		//	return (dsttp);
		}
	}
j1:
	switch (srctp->type) {
	case bt_int:
		if (!(*srcnode)->IsRefType()) {
			*srcnode = makenode(en_octa2hexi, *srcnode, nullptr);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->tp = srctp;
		}
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_uint:
		if (!(*srcnode)->IsRefType()) {
			*srcnode = makenode(en_uocta2hexi, *srcnode, nullptr);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
		}
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_short:
		if (!(*srcnode)->IsRefType()) {
			*srcnode = makenode(en_tetra2hexi, *srcnode, nullptr);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
		}
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_ushort:
		if (!(*srcnode)->IsRefType()) {
			*srcnode = makenode(en_utetra2hexi, *srcnode, nullptr);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
		}
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_byte:
		if (!(*srcnode)->IsRefType()) {
			*srcnode = makenode(en_byt2hexi, *srcnode, nullptr);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
		}
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_ubyte:
		if (!(*srcnode)->IsRefType()) {
			*srcnode = makenode(en_ubyt2hexi, *srcnode, nullptr);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
		}
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_ichar:
		if (!(*srcnode)->IsRefType()) {
			*srcnode = makenode(en_wyde2hexi, *srcnode, nullptr);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
		}
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_iuchar:
		if (!(*srcnode)->IsRefType()) {
			*srcnode = makenode(en_uwyde2hexi, *srcnode, nullptr);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
		}
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_char:
		if (srctp->type == dsttp->type)
			return (&stdchar);
		if (!(*srcnode)->IsRefType()) {
			*srcnode = makenode(en_wyde2hexi, *srcnode, nullptr);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
		}
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_uchar:
		if (!(*srcnode)->IsRefType())
			*srcnode = makenode(en_uwyde2hexi, *srcnode, nullptr);
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_long:
	case bt_ulong:
		if (dsttp->IsFloatType()) {
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stddouble);
		}
		if (dsttp->IsPositType()) {
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return &stdlong;
	case bt_bitfield:
	case bt_ubitfield:
	case bt_exception:
		switch (dsttp->type) {
		case bt_long:	return &stdlong;
		case bt_ulong:	return &stdulong;
		case bt_short:	return &stdlong;
		case bt_ushort:	return &stdulong;
		case bt_int:	return &stdlong;
		case bt_uint:	return &stdulong;
		case bt_ichar:
		case bt_char:	return &stdlong;
		case bt_iuchar:
		case bt_uchar:	return &stdulong;
		case bt_byte:	return &stdlong;
		case bt_ubyte:	return &stdulong;
		case bt_enum:	return &stdlong;
			// If we have a pointer involved we likely want a pointer result.
		case bt_pointer:return (dsttp);
		case bt_float:
		case bt_double:
			*srcnode = makenode(en_i2d, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8; return (dsttp);
		case bt_quad:
			*srcnode = makenode(en_i2q, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 16; return (dsttp);
		case bt_exception:	return &stdexception;
		case bt_vector:	return (dsttp);
		case bt_union:	return (dsttp);
		case bt_struct:
		case bt_class:
			error(ERR_MISMATCH);
			return (dsttp);
		case bt_posit:
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return (srctp);

	case bt_enum:
		switch (dsttp->type) {
		case bt_long:	/**srcnode = makenode(en_wyde2octa, *srcnode, *dstnode);*/ (*srcnode)->esize = 16; return &stdlong;
		case bt_ulong:	/**srcnode = makenode(en_wyde2hexi, *srcnode, *dstnode);*/ (*srcnode)->esize = 16; return &stdulong;
		case bt_short:	/**srcnode = makenode(en_wyde2octa, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stdint;
		case bt_ushort:	/**srcnode = makenode(en_wyde2hexi, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stduint;
		case bt_int:	/**srcnode = makenode(en_wyde2octa, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stdint;
		case bt_uint:	/**srcnode = makenode(en_wyde2hexi, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stduint;
		case bt_ichar:
		case bt_char:	/**srcnode = makenode(en_wyde2octa, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stdint;
		case bt_iuchar:
		case bt_uchar:	/**srcnode = makenode(en_wyde2hexi, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stduint;
		case bt_byte:	/**srcnode = makenode(en_wyde2octa, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stdint;
		case bt_ubyte:	/**srcnode = makenode(en_wyde2hexi, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stduint;
		case bt_enum:	/**srcnode = makenode(en_wyde2octa, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stdint;
		case bt_pointer:/**srcnode = makenode(en_wyde2hexi, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return dsttp;
		case bt_exception:	/**srcnode = makenode(en_wyde2hexi, *srcnode, *dstnode);*/ (*srcnode)->esize = 8; return &stdexception;
		case bt_float:
		case bt_double:
			if (typecast) {
				*dstnode = makenode(en_i2d, *srcnode, *dstnode); (*dstnode)->esize = 8;	return (dsttp);
			}
			else {
				*srcnode = makenode(en_i2d, *srcnode, *dstnode); (*srcnode)->esize = 8;	return (dsttp);
			}
		case bt_quad:
			if (typecast) {
				*dstnode = makenode(en_i2q, *srcnode, *dstnode); (*dstnode)->esize = 16; return (dsttp);
			}
			else {
				*srcnode = makenode(en_i2q, *srcnode, *dstnode); (*srcnode)->esize = 16; return (dsttp);
			}
		case bt_vector:	return (dsttp);
		case bt_union:	return (dsttp);
		case bt_struct:
		case bt_class:
			error(ERR_MISMATCH);
			return (dsttp);
		case bt_posit:
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return srctp;

	case bt_pointer:
		switch (dsttp->type)
		{
		case bt_byte:
		case bt_ubyte:
		case bt_ichar:
		case bt_char:
		case bt_iuchar:
		case bt_uchar:
		case bt_short:
		case bt_ushort:
		case bt_int:
		case bt_uint:
		case bt_long:
		case bt_ulong:
			return (srctp);
		case bt_pointer:
			typ = dsttp->btpp->type;
			return (srctp);
			// pointer to function was really desired.
		case bt_func:
		case bt_ifunc:
			return (srctp);
		case bt_struct:
			if ((*dstnode)->nodetype == en_list || (*dstnode)->nodetype == en_end_aggregate)
				return (srctp);
			break;
		case bt_posit:
			*srcnode = makenode(en_i2p, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			(*srcnode)->esize = 8;
			return (&stdposit);
		}
		return (srctp);

	case bt_float:
		switch (dsttp->type) {
		case bt_byte:
		case bt_ubyte:
		case bt_ichar:
		case bt_char:
		case bt_iuchar:
		case bt_uchar:
		case bt_short:
		case bt_ushort:
		case bt_int:
		case bt_uint:
		case bt_long:
		case bt_ulong:	
		case bt_exception:
		case bt_enum:
			if (typecast) {
				*srcnode = makenode(en_d2i, *srcnode, *dstnode);
				(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
				return (dsttp);
			}
			else {
				*dstnode = makenode(en_i2d, *dstnode, *srcnode);
				return (srctp);
			}
		case bt_pointer: return(dsttp);
		case bt_double:	
			return (dsttp);
		case bt_quad:	*srcnode = makenode(en_d2q, *srcnode, *dstnode); return (dsttp);
		case bt_vector:	return (dsttp);
		case bt_union:	return (dsttp);
		case bt_struct:
		case bt_class:
			error(ERR_MISMATCH);
			return (dsttp);
		}
		return srctp;

	case bt_double:
		switch (dsttp->type) {
		case bt_byte:
		case bt_ubyte:
		case bt_ichar:
		case bt_char:
		case bt_iuchar:
		case bt_uchar:
		case bt_short:
		case bt_ushort:
		case bt_int:
		case bt_uint:
		case bt_long:
		case bt_ulong:
		case bt_exception:
		case bt_enum:
			if (typecast) {
				*dstnode = makenode(en_d2i, *srcnode, *dstnode);
				return (dsttp);
			}
			else {
				*dstnode = makenode(en_i2d, *dstnode, *srcnode);
				return (srctp);
			}
		case bt_pointer: return(dsttp);
		case bt_double:	return (dsttp);
		case bt_quad:	*srcnode = makenode(en_d2q, *srcnode, *dstnode);
			(*srcnode)->constflag = (*srcnode)->p[0]->constflag;
			return (dsttp);
		case bt_vector:	return (dsttp);
		case bt_union:	return (dsttp);
		case bt_struct:
		case bt_class:
			error(ERR_MISMATCH);
			return (dsttp);
		}
		return srctp;

	case bt_quad:
		switch (dsttp->type) {
		case bt_byte:
		case bt_ubyte:
		case bt_ichar:
		case bt_char:
		case bt_iuchar:
		case bt_uchar:
		case bt_short:
		case bt_ushort:
		case bt_int:
		case bt_uint:
		case bt_long:
		case bt_ulong:
		case bt_exception:
		case bt_enum:	*dstnode = makenode(en_i2q, *dstnode, *srcnode); return (srctp);
		case bt_pointer: return(dsttp);
		case bt_double:	*dstnode = makenode(en_d2q, *dstnode, *srcnode); return (srctp);
		case bt_quad:	return (dsttp);
		case bt_vector:	return (dsttp);
		case bt_union:	return (dsttp);
		case bt_struct:
		case bt_class:
			error(ERR_MISMATCH);
			return (dsttp);
		}
		return srctp;
	
	case bt_posit:
		return srctp;

	case bt_array:
	case bt_class:
	case bt_struct:
	case bt_union:
		//if (dsttp->isArray) {
		//	SYM *srcfirst, *srcthead;
		//	SYM *dstfirst, *dstthead;
		//	srcfirst = srcthead = SYM::GetPtr(srctp->lst.GetHead());
		//	dstfirst = dstthead = SYM::GetPtr(dsttp->lst.GetHead());
		//	while (srcthead && dstthead) {
		//		if (srcthead->tp->IsAggregateType()) {
		//			forcefit()
		//		}
		//		srcthead = SYM::GetPtr(srcthead->next);
		//		dstthead = SYM::GetPtr(dstthead->next);
		//	}
		//	for (tp = srctp->lst.)
		//	if (srctp->btpp->IsScalar()) {

		//	}
		//}
		if (dsttp->size > srctp->size || typecast)
			return (dsttp);
		return (srctp);
		// Really working with pointers to functions.
	case bt_func:
	case bt_ifunc:
		return srctp;
	case bt_void:
		return (dsttp);
	case bt_vector:
		return (dsttp);
	}
	error(ERR_MISMATCH);
	return srctp;
}

