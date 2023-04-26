// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2023  Robert Finch, Waterloo
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

void CPU::SetRealRegisters()
{
	int n;

	regSP = 63;
	regFP = 62;
	regLR = 56;
	regGP = 61;
	regTP = 26;
	regCLP = 25;                // class pointer
	regPP = 24;					// program pointer
	regZero = 0;
	regXoffs = 10;
	nregs = 64;
	for (n = 0; n < nregs; n++) {
		regs[n].number = n;
		regs[n].assigned = false;
		regs[n].isConst = false;
		regs[n].modified = false;
		regs[n].offset = nullptr;
		regs[n].IsArg = false;
		regs[n].isGP = (n < 32);
		regs[n].isFP = (n >= 32 && n < 64);
		regs[n].isPosit = (n >= 64 && n < 96);

		vregs[n].number = n;
		vregs[n].assigned = false;
		vregs[n].isConst = false;
		vregs[n].modified = false;
		vregs[n].offset = nullptr;
		vregs[n].IsArg = false;
	}
	MachineReg::MarkColorable();
}

void CPU::SetVirtualRegisters()
{
	int n;

	regSP = 1023;
	regFP = 1022;
	regLR = 1021;
	regGP = 1019;
	regTP = 1018;
	regCLP = 1017;              // class pointer
	regPP = 1016;				// program pointer
	regAsm = 1015;
	regXoffs = 1014;
	regZero = 0;
	nregs = 1024;
	for (n = 0; n < nregs; n++) {
		regs[n].number = n;
		regs[n].assigned = false;
		regs[n].isConst = false;
		regs[n].modified = false;
		regs[n].offset = nullptr;
		regs[n].IsArg = false;

		vregs[n].number = n;
		vregs[n].assigned = false;
		vregs[n].isConst = false;
		vregs[n].modified = false;
		vregs[n].offset = nullptr;
		vregs[n].IsArg = false;
	}
	MachineReg::MarkColorable();
}
