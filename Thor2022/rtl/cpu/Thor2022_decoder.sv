// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_decoder.sv
//
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//                                                                          
// ============================================================================

import Thor2022_pkg::*;

module Thor2022_decoder(ir, xir, xval,mir, mval, deco, distk_depth, rm, dfrm);
input Instruction ir;
input Instruction xir;
input Instruction mir;
input xval;
input mval;
output DecodeOut deco;
input [3:0] distk_depth;
input [2:0] rm;
input [2:0] dfrm;

integer n;
Value imm;
reg [4:0] Ra, Rb, Rc, Rt;
reg rfwr;

always_comb
begin
case(ir.any.opcode)
DJMP:	Ra = 5'd26;
LDSP,STSP:	Ra = 5'd31;
default:	Ra = ir.r3.Ra;
endcase
Rb = ir.r3.Rb;
rfwr = `FALSE;
// Target register
case(ir.any.opcode)
JEQZ,JNEZ:
	Rt = 'd0;
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	Rt = 'd0;
JMP:	Rt = 'd0;
DJMP,BSET:
	Rt = 5'd26;
STSP,
STB,STW,STT,STO,STHC,STHS,STH,STHP,STPTR:
	Rt = 'd0;
STBX,STWX,STTX,STOX,STHCX,STHX,STHPX,STPTRX:
	Rt = 'd0;
EXI8,EXI24,EXI40,EXI56,EXIM:
	Rt = 'd0;
EXI8+1,EXI24+1,EXI40+1,EXI56+1:
	Rt = 'd0;
default:	Rt = ir[13:9];
endcase
// Rc
case(ir.any.opcode)
STSP,
STB,STW,STT,STO,STHC,STH,STHP,STHS,STPTR:
	Rc = ir.st.Rs;
STBX,STWX,STTX,STOX,STHCX,STHX,STHPX,STPTRX:
	Rc = ir.stx.Rs;
STHS:
	Rc = ir.sts.Rs;
BSET:
	Rc = 5'd26;
MTLK:			Rc = ir[13:9];
default:	Rc = ir.r3.Rc;
endcase

deco.Ravec = ir.any.v;
deco.Rtvec = ir.any.v;
case(ir.any.opcode)
SLLI,SRLI,SRAI,
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	deco.Rbvec = 1'b0;
default:
	deco.Rbvec = ir.r3.Tb==1'b1;
endcase
case(ir.any.opcode)
R2,R3:	deco.Rcvec = ir.r3.Tc==2'b01;
BTFLD:	deco.Rcvec = ir.r3.Tc==2'b01;
default:	deco.Rcvec = 1'b0;
endcase

// Cat
case(ir.any.opcode)
CSR:
	deco.lk = ir.csr.regno[3:0];
// Cannot update ca[0] with a branch
JMP,DJMP,BRA:
	deco.lk = {2'b0,ir.jxx.lk};
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	deco.lk = {2'b0,ir.jxx.lk};
default: 	deco.lk = 4'd0;
endcase

case(ir.any.opcode)
BRK:	deco.carfwr = `TRUE;
MTLK:	deco.carfwr = `TRUE;
CSR:
	case (ir.csr.op)
	CSRRW:
		// Cannot update ca[7] this way.
		if (ir.csr.regno[11:4]==8'h10 && ir.csr.regno[11:0] != 12'h107)	// 0x3100 to 0x310F
			deco.carfwr = `TRUE;
		else
			deco.carfwr = `FALSE;
	default:	deco.carfwr = `FALSE;
	endcase
// Cannot update ca[0] with a branch
JMP,DJMP,BRA:
	deco.carfwr = ir.jxx.lk != 2'd0;
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	deco.carfwr = ir.jxx.lk != 2'd0;
default: 	deco.carfwr = `FALSE;
endcase

case(ir.any.opcode)
MTLK:	deco.Cat = {2'd0,ir[15:14]};
CSR:
	case (ir.csr.op)
	CSRRW:
		if (ir.csr.regno[11:4]==8'h10)	// 0x3100 to 0x310F
			deco.Cat = ir.csr.regno[3:0];
		else
			deco.Cat = 4'd0;
	default:	deco.Cat = 4'd0;
	endcase
JMP,DJMP,BRA:
	deco.Cat = {2'b0,ir.jxx.lk};
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	deco.Cat = {2'b0,ir.jxx.lk};
default: 	deco.Cat = 4'd0;
endcase

// Detecting register file update
casez(ir.any.opcode)
R1,F1,DF1,P1:
	case(ir.r1.func)
	default:	rfwr = `TRUE;
	endcase
R2,F2,DF2,P2:
	case(ir.r3.func)
	default:	rfwr = `TRUE;
	endcase
R3,F3,DF3,P3:
	case(ir.r3.func)
	default:	rfwr = `TRUE;
	endcase
OSR2:
	case(ir.r3.func)
	POPQ:			rfwr = `TRUE;
	PEEKQ:		rfwr = `TRUE;
	STATQ:		rfwr = `TRUE;
	LDPTG:		rfwr = `TRUE;
	RGNRW:		rfwr = `TRUE;
	TLBRW:		rfwr = `TRUE;
	default:	rfwr = `FALSE;
	endcase
BTFLD:
	case(ir.r3.func)
	BFALIGN,BFFFO,BFEXTU,BFEXT,
	ANDM,BFSET,BFCHG,BFCLR:
		rfwr = `TRUE;
	default:	rfwr = `FALSE;
	endcase
CSR:	rfwr = `TRUE;
MFLK:	rfwr = `TRUE;
ADDI,SUBFI,CMPI,MULI,DIVI,MULUI:
	rfwr = `TRUE;
ANDI,ORI,XORI:		rfwr = `TRUE;
SEQI,SNEI,SLTI,SLEI,SGTI,SGEI:		rfwr = `TRUE;
ADDIL,SUBFIL,CMPIL,MULIL,DIVIL,MULUIL:
	rfwr = `TRUE;
ANDIL,ORIL,XORIL:	rfwr = `TRUE;
SEQIL,SNEIL,SLTIL,SLEIL,SGTIL,SGEIL:		rfwr = `TRUE;
LDSP,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDHS,LDHR,LDOU,LDH:
	rfwr = `TRUE;
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDHRX,LDOUX,LDHX:
	rfwr = `TRUE;
LDHP,LDHPX,LDHQ,LDHQX:	rfwr = `TRUE;
ADD2R,SUB2R,AND2R,OR2R,XOR2R,CMP2R,SLT2R,SGE2R,SGEU2R,SLTU2R,SEQ2R,SNE2R:
	rfwr = `TRUE;
SLLR2,SRLR2,SRAR2,ROLR2,RORR2:
	rfwr = `TRUE;
SLLI,SRLI,SRAI:
	rfwr = `TRUE;
DJMP,BSET:
	rfwr = `TRUE;
default:	rfwr = `FALSE;
endcase

// Computing immediate constant
case(ir.any.opcode)
R2:
	case(ir.r3.func)
	SLL,SRL,SRA,ROL,ROR: imm = {120'd0,ir[35:29]};
	default:	imm = 'd0;
	endcase
ADDI,SUBFI,CMPI,SEQI,SNEI,SLTI,SLEI,SGTI,SGEI,MULI,DIVI:
	imm = {{115{ir.ri.imm[12]}},ir.ri.imm};
ANDI:	// Pad with ones to the left
	imm = {{115{1'b1}},ir.ri.imm};
ORI,XORI,SLTUI,SGTUI,MULUI,DIVUI:	// Pad with zeros to the left
	imm = {{115{1'b0}},ir.ri.imm};
CHKI:	imm = {{106{ir[47]}},ir[47:29],ir[11:9]};
ADDIL,SUBFIL,CMPIL,SEQIL,SNEIL,SLTIL,SLEIL,SGTIL,SGEIL,MULIL,DIVIL:
	imm = ir.any.v ? {{103{ir.ril.imm[24]}},ir.rilv.imm} : {{99{ir.ril.imm[28]}},ir.ril.imm};
SLTUIL,SLEUIL,SGTUIL,SGEUIL,MULUIL:
	imm = ir.any.v ? {{103{1'b0}},ir.rilv.imm} : {{99{1'b0}},ir.ril.imm};
ANDIL:	imm = ir.any.v ? {{103{1'b1}},ir.rilv.imm} : {{99{1'b1}},ir.ril.imm};
ORIL,XORIL:	imm = ir.any.v ? {{103{1'b0}},ir.rilv.imm} : {{99{1'b0}},ir.ril.imm};
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOU,LDH,LDHP,LDHQ:
	imm = ir.any.v ? {{104{ir.ld.disp[23]}},ir.ld.disp} : {{99{ir.ld.disp[28]}},ir.ld.disp};
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDOUX,LDHX,LDHPX,LDHQX:
	imm = 'd0;
STB,STW,STT,STO,STH,STHP,STHC,STPTR:
	imm = ir.any.v ? {{104{ir.st.disp[23]}},ir.st.disp} : {{99{ir.st.disp[28]}},ir.st.disp};
STBX,STWX,STTX,STOX,STHX,STHPX,STHCX,STPTRX:
	imm = 'd0;
LDHS:	imm = {{115{ir.lds.disp[12]}},ir.lds.disp};
STHS:	imm = {{115{ir.sts.disp[12]}},ir.sts.disp};
LDSP,STSP:	imm = {{122{1'b0}},ir[15:14],4'h0};
SLLI,SRLI,SRAI:	imm = {122'd0,ir[24:19]};
default:
	imm = 'd0;
endcase
if (xval)
	case(xir.any.opcode)
	EXI8:		imm = {{96{xir[15]}},xir[15:9],xir[0],imm[23:0]};
	EXI8+1:	imm = {{96{xir[15]}},xir[15:9],xir[0],imm[23:0]};
	EXI24:	imm = {{80{xir[31]}},xir[31:9],xir[0],imm[23:0]};
	EXI24+1:imm = {{80{xir[31]}},xir[31:9],xir[0],imm[23:0]};
	EXI40:	imm = {{64{xir[47]}},xir[47:9],xir[0],imm[23:0]};
	EXI40+1:imm = {{64{xir[47]}},xir[47:9],xir[0],imm[23:0]};
	EXI56:	imm = {{48{xir[63]}},xir[63:9],xir[0],imm[23:0]};
	EXI56+1:imm = {{48{xir[63]}},xir[63:9],xir[0],imm[23:0]};
	default:	;	
	endcase
/*
if (mval)
	case(mir.any.opcode)
	EXIM:		imm = {mir[56:9],imm[79:0]};
	default:	;	
	endcase
*/
case(ir.any.opcode)
ADDIL,SUBFIL,CMPIL,SEQIL,SNEIL,SLTIL,SLEIL,SGTIL,SGEIL,SLTUIL,SLEUIL,SGTUIL,SGEUIL,MULIL,DIVIL,MULUIL:
	deco.ril = `TRUE;
ANDIL,ORIL,XORIL:
	deco.ril = `TRUE;
default:	deco.ril = `FALSE;
endcase

case(ir.any.opcode)
EXI8:		deco.isExi = `TRUE;
EXI8+1:	deco.isExi = `TRUE;
EXI24:	deco.isExi = `TRUE;
EXI24+1:deco.isExi = `TRUE;
EXI40:	deco.isExi = `TRUE;
EXI40+1:deco.isExi = `TRUE;
EXI56:	deco.isExi = `TRUE;
EXI56+1:deco.isExi = `TRUE;
EXIM:		deco.isExi = `TRUE;
default:	deco.isExi = `FALSE;
endcase

deco.rfwr = rfwr;
deco.Ra = Ra;
deco.Rb = Rb;
deco.Rc = Rc;
deco.Rt = Rt;
deco.is_vector = ir.any.v;
deco.imm = imm;

case(ir.any.opcode)
R2,R3,BTFLD:	deco.Tb = ir.r3.Tb;
ADD2R,SUB2R,AND2R,OR2R,XOR2R,CMP2R,SLT2R,SGE2R,SLTU2R,SGEU2R,SEQ2R,SNE2R:
	deco.Tb = ir[24];
SLLR2,SRLR2,SRAR2,ROLR2,RORR2:
	deco.Tb = ir[24];
SLLI,SRLI,SRAI,
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	deco.Tb = 1'b0;
JMP,DJMP:	deco.Tb = 1'b0;
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDHRX,LDHPX,LDOUX,LDHX,LDHQX:
	deco.Tb = ir.r3.Tb;
STBX,STWX,STTX,STOX,STHCX,STHX,STHPX,STPTRX:
	deco.Tb = ir.r3.Tb;
default:	deco.Tb = 1'b0;
endcase
case(ir.any.opcode)
R2,R3:	deco.Tc = ir.r3.Tc;
BTFLD:	deco.Tc = ir.r3.Tc;
default:	deco.Tc = 1'b0;
endcase

case(ir.any.opcode)
R2:
	case(ir.r3.func)
	MUL,MULH:	deco.mul = `TRUE;
	default:	deco.mul = `FALSE;
	endcase
MULI,MULIL:	deco.mul = `TRUE;
MULUI,MULUIL:	deco.mul = `TRUE;
default:	deco.mul = `FALSE;
endcase

case(ir.any.opcode)
R2:
	case(ir.r3.func)
	DIV,DIVU:	deco.div = `TRUE;
	default:	deco.div = `FALSE;
	endcase
DIVI,DIVIL:	deco.div = `TRUE;
//DIVUI,DIVUIL:	deco.div = `TRUE;
default:	deco.div = `FALSE;
endcase

case(ir.any.opcode)
F1,F2,F3:	deco.float = `TRUE;
default:	deco.float = `FALSE;
endcase

case(ir.any.opcode)
ADDI,ADDIL:	deco.addi = `TRUE;
default:	deco.addi = `FALSE;
endcase

case(ir.any.opcode)
LDSP,
CACHE,CACHEX,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDHS,LDHR,
LDOU,LDOUX,LDH,LDHX,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDHRX:
	deco.ld = `TRUE;
default:	deco.ld = `FALSE;
endcase

case(ir.any.opcode)
LDBU,LDWU,LDTU,LDOU,
LDBUX,LDWUX,LDTUX,LDOUX:
	deco.ldz = `TRUE;
default:	deco.ldz = `FALSE;
endcase

case(ir.any.opcode)
CACHE,LDSP,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDHS,LDHR,LDOU,LDH:
	deco.loadr = `TRUE;
default:	deco.loadr = `FALSE;
endcase

case(ir.any.opcode)
CACHEX,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDHRX,LDOUX,LDHX:
	deco.loadn = `TRUE;
default:	deco.loadn = `FALSE;
endcase


case(ir.any.opcode)
STSP,
STB,STW,STT,STO,STHS,STHC,STH,STHP,STPTR,
STBX,STWX,STTX,STOX,STHCX,STHX,STHPX,STPTRX:
	deco.st = `TRUE;
default:	deco.st = `FALSE;
endcase

case(ir.any.opcode)
STSP,
STB,STW,STT,STO,STHC,STHS,STH,STHP,STPTR:
	deco.storer = `TRUE;
default:	deco.storer = `FALSE;
endcase

case(ir.any.opcode)
STBX,STWX,STTX,STHCX,STOX,STHX,STHPX,STPTRX:
	deco.storen = `TRUE;
default:	deco.storen = `FALSE;
endcase

deco.ldoo = ir.any.opcode==LDOO || ir.any.opcode==LDOOX;
deco.stoo = ir.any.opcode==STOO || ir.any.opcode==STOOX;

case(ir.any.opcode)
LDB,LDBU,STB:	deco.memsz = byt;
LDW,LDWU,STW:	deco.memsz = wyde;
LDT,LDTU,STT:	deco.memsz = tetra;
LDBX,LDBUX,STBX:	deco.memsz = byt;
LDWX,LDWUX,STWX:	deco.memsz = wyde;
LDTX,LDTUX,STTX:	deco.memsz = tetra;
LDHS,LDOO,LDOOX,LDH,LDHX,LDSP:	deco.memsz = hexi;
STHS,STOOX,STH,STHC,STHX,STHCX,STSP:	deco.memsz = hexi;
LDHP,LDHPX,STHP,STHPX: deco.memsz = hexipair;
STPTR,STPTRX:	deco.memsz = ptr;
default:	deco.memsz = octa;
endcase

case(ir.any.opcode)
JMP,DJMP:	deco.jmp = `TRUE;
default: 	deco.jmp = `FALSE;
endcase
case(ir.any.opcode)
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	deco.jxx = `TRUE;
default: 	deco.jxx = `FALSE;
endcase

case(ir.any.opcode)
DJMP:	deco.dj = `TRUE;
default: 	deco.dj = `FALSE;
endcase

deco.rts = ir.any.opcode==RTS;

// Detect multi-cycle operations
case(ir.any.opcode)
R2,R3:
	case(ir.r3.func)
	MUL,MULH:	deco.multi_cycle = `TRUE;
	DIV:			deco.multi_cycle = `TRUE;
	default:	deco.multi_cycle = `FALSE;
	endcase
OSR2:
	case(ir.r3.func)
	TLBRW:		deco.multi_cycle = `TRUE;
	RGNRW:		deco.multi_cycle = `TRUE;
	MTSEL:		deco.multi_cycle = `TRUE;
	default:	deco.multi_cycle = `FALSE;
	endcase
MULI,MULIL:		deco.multi_cycle = `TRUE;
DIVI,DIVIL:		deco.multi_cycle = `TRUE;
CACHE,CACHEX:	deco.multi_cycle = `TRUE;
LDB,LDBU,STB:	deco.multi_cycle = `TRUE;
LDW,LDWU,STW:	deco.multi_cycle = `TRUE;
LDT,LDTU,STT: deco.multi_cycle = `TRUE;
LDO,LDHS,LDHR,LDOU:		deco.multi_cycle = `TRUE;
LDH,LDSP:					deco.multi_cycle = `TRUE;
LDBX,LDBUX,STBX:	deco.multi_cycle = `TRUE;
LDWX,LDWUX,STWX:	deco.multi_cycle = `TRUE;
LDTX,LDTUX,STT:		deco.multi_cycle = `TRUE;
LDOX,LDHRX,LDOUX:				deco.multi_cycle = `TRUE;
LDHX:					deco.multi_cycle = `TRUE;
STO,STHS,STHC,STHX,STH,STHP,STPTR,STSP:		deco.multi_cycle = `TRUE;
STOX,STHPX,STHCX,STPTRX:		deco.multi_cycle = `TRUE;
STMOV,STFND,STCMP,BSET:			deco.multi_cycle = `TRUE;
default:	deco.multi_cycle = `FALSE;
endcase

deco.mul = `FALSE;
deco.mulu = `FALSE;
deco.mulsu = `FALSE;
deco.muli = `FALSE;
deco.mului = `FALSE;
deco.mulsui = `FALSE;
deco.mulfi = `FALSE;
deco.mulf = `FALSE;
case(ir.any.opcode)
R2:
	case(ir.r3.func)
	MUL,MULH:			deco.mul = `TRUE;
	MULU,MULUH:		deco.mulu = `TRUE;
	MULSU,MULSUH:	deco.mulsu = `TRUE;
	MULF:					deco.mulf = `TRUE;
	default:	;
	endcase
MULI,MULIL:		deco.muli = `TRUE;
MULUI,MULUIL:	deco.mului = `TRUE;
MULFI:				deco.mulfi = `TRUE;
default:	;
endcase
deco.mulall = deco.mul|deco.mulu|deco.mulsu|deco.muli|deco.mului|deco.mulsui|deco.mulf;
deco.mulalli = deco.muli|deco.mului|deco.mulsui|deco.mulfi;

deco.div = `FALSE;
deco.divu = `FALSE;
deco.divsu = `FALSE;
deco.divi = `FALSE;
deco.divui = `FALSE;
deco.divsui = `FALSE;
case(ir.any.opcode)
R2:
	case(ir.r3.func)
	DIV:	deco.div = `TRUE;
	DIVU:	deco.divu = `TRUE;
	DIVSU:	deco.divsu = `TRUE;
	endcase
DIVI,DIVIL:	deco.divi = `TRUE;
endcase
deco.divall = deco.div|deco.divu|deco.divsu|deco.divi|deco.divui|deco.divsui;
deco.divalli = deco.divi|deco.divui|deco.divsui;

deco.jxz = ir.any.opcode==JEQZ || ir.any.opcode==JNEZ;
deco.bra = ir.any.opcode==BRA;
if (deco.bra)
	deco.jmptgt = {{109{ir[28]}},ir[28:11],1'b0};
else if (deco.jxx)
	deco.jmptgt = {{107{ir.jxx.Tgthi[20]}},ir.jxx.Tgthi,1'b0};
else if (deco.jxz)
	deco.jmptgt = {{112{ir[28]}},ir[28:19],ir[13:9],1'b0};
else
	deco.jmptgt = {{94{ir.jmp.Tgthi[15]}},ir.jmp.Tgthi,ir.jmp.Tgtlo,1'b0};
	
deco.is_cbranch = deco.jxx | deco.jxz;
deco.csr = ir.any.opcode==CSR;
deco.rti = ir.any.opcode==OSR2 && ir.r3.func==RTI;
deco.sei = ir.any.opcode==R1 && ir.r3.func==SEI;
deco.rex = ir.any.opcode==OSR2 && ir.r3.func==REX;
deco.sync = ir.any.opcode==CSR || ir.any.opcode==SYNC;
deco.tlb = ir.any.opcode==OSR2 && ir.r3.func==TLBRW;
deco.rgn = ir.any.opcode==OSR2 && ir.r3.func==RGNRW;
deco.ptg = ir.any.opcode==OSR2 && (ir.r3.func==LDPTG || ir.r3.func==STPTG);
deco.mtlc = ir.any.opcode==VM && ir.vmr2.func==MTLC;
deco.mfsel = ir.any.opcode==OSR2 && ir.r3.func==MFSEL;
deco.mtsel = ir.any.opcode==OSR2 && ir.r3.func==MTSEL;

case(ir.any.opcode)
R2,R3:
	deco.Rvm = ir.r3.m;
ADD2R,SUB2R,AND2R,OR2R,XOR2R,CMP2R,SLT2R:
	deco.Rvm = ir.any[31:29];
default:
	if (deco.ril & ir.any.v)
		deco.Rvm = ir.rilv.m;
	else if (deco.loadn)
		deco.Rvm = ir.ldx.m;
	else if (deco.storen)
		deco.Rvm = ir.stx.m;
	else
		deco.Rvm = 3'd0;
endcase

case(ir.any.opcode)
R2,R3:
	deco.Rz = ir.r3.z;
ADD2R,SUB2R,AND2R,OR2R,XOR2R,CMP2R,SLT2R:
	deco.Rz = ir.any[28];
default:
	if (deco.ril & ir.any.v)
		deco.Rz = ir.rilv.z;
	else if (deco.loadn)
		deco.Rz = ir.ldx.z;
	else if (deco.storen)
		deco.Rz = ir.stx.z;
	else
		deco.Rz = 1'b0;
endcase

case(ir.any.opcode)
VM:
	case(ir.vmr2.func)
	MTVM:	deco.vmrfwr = `TRUE;
	default:	deco.vmrfwr = `FALSE;
	endcase
default:	deco.vmrfwr = `FALSE;
endcase

deco.mem = deco.ld|deco.loadr|deco.storer|deco.loadn|deco.storen|deco.tlb;
deco.load = deco.ld|deco.loadr|deco.loadn|deco.tlb|deco.ldoo;
deco.stset = ir.any.opcode==BSET;
deco.stmov = ir.any.opcode==STMOV;
deco.stfnd = ir.any.opcode==STFND;
deco.stcmp = ir.any.opcode==STCMP;
deco.mflk = ir.any.opcode==MFLK;
deco.mtlk = ir.any.opcode==MTLK;
deco.enter = ir.any.opcode==ENTER;
deco.push = ir.any.opcode==PUSH || ir.any.opcode==PUSH4R;
deco.flowchg = deco.rti || deco.rex || deco.jmp || deco.bra || deco.jxx || deco.jxz || deco.rts;
deco.store = deco.storer|deco.storen|deco.stset|deco.stmov|deco.stfnd|deco.stcmp;

if (deco.mflk)
	deco.Ca = {2'd0,ir[15:14]};
else if (deco.jxx)
	deco.Ca = {1'd0,ir.jxx.Ca};
else if (deco.jxz|deco.bra)
	deco.Ca = {1'd0,ir[31:29]};
else if (deco.rts)
	deco.Ca = {2'd0,ir.rts.lk};
else if (deco.jmp)
	deco.Ca = {1'd0,ir.jmp.Ca};
else
	deco.Ca = 4'h0;

case(ir.any.opcode)
BRK:	deco.Ct = 4'h8 + distk_depth;
MTLK:	deco.Ct = {2'd0,ir[15:14]};
CSR:
	case (ir.csr.op)
	CSRRW:	deco.Ct = ir.csr.regno[3:0];
	default:	deco.Ct = 4'h8 + distk_depth;
	endcase
// Cannot update ca[0] with a branch
JMP,DJMP,BRA:
	deco.Ct = {2'd0,ir.jxx.lk};
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	deco.Ct = {2'd0,ir.jxx.lk};
default:
	if (deco.rex)
		deco.Ct = 4'd6;
	else if (deco.rti)
		deco.Ct = 4'h7 + distk_depth;
	else
 		deco.Ct = 4'h8 + distk_depth;
endcase

deco.mjnez = ir.any.opcode==MJNEZ;

case(ir.any.opcode)
DF2:
	case(ir.r3.func)
	DFADD,DFSUB:	deco.dfrm = ir[31:29]==3'd7 ? dfrm : ir[31:29];
	DFMUL,DFDIV:	deco.dfrm = ir[31:29]==3'd7 ? dfrm : ir[31:29];
	default:	deco.dfrm = dfrm;
	endcase
default:	deco.dfrm = dfrm;
endcase

deco.isDF = ir.any.opcode==DF2;

end
endmodule
