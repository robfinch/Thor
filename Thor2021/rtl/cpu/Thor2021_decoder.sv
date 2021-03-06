// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2021_decoder.sv
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

import Thor2021_pkg::*;

module Thor2021_decoder(ir, xir, xval, deco, distk_depth, rm);
input Instruction ir;
input Instruction xir;
input xval;
output DecodeOut deco;
input [2:0] distk_depth;
input [2:0] rm;

integer n;
Value imm;
reg [5:0] Ra, Rb, Rc, Rt;
reg rfwr;

always_comb
begin
case(ir.any.opcode)
DJMP:	Ra = 6'd58;
default:	Ra = ir.r3.Ra;
endcase
Rb = ir.r3.Rb;
rfwr = FALSE;
// Target register
case(ir.any.opcode)
JEQZ,JNEZ,DJEQZ,DJNEZ:
	Rt = 6'd0;
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	Rt = 6'd0;
JMP:	Rt = 6'd0;
DJMP,BSET:
	Rt = 6'd58;
STB,STW,STT,STO,STOC,STOS,STH:
	Rt = 6'd0;
STBX,STWX,STTX,STOX,STOCX,STHX:
	Rt = 6'd0;
EXI7,EXI23,EXI41:
	Rt = 6'd0;
default:	Rt = ir[14:9];
endcase
// Rc
case(ir.any.opcode)
STB,STW,STT,STO,STOC,STH:
	Rc = ir.st.Rs;
STBX,STWX,STTX,STOX,STOCX,STHX:
	Rc = ir.stx.Rs;
STOS:
	Rc = ir.sts.Rs;
BSET:
	Rc = 6'd58;
MTLK:			Rc = ir[14:9];
default:	Rc = ir.r3.Rc;
endcase

deco.Ravec = ir.any.v;
deco.Rtvec = ir.any.v;
deco.Rbvec = ir.r3.Tb==2'b01;
case(ir.any.opcode)
R2,R3:	deco.Rcvec = ir.r3.Tc==2'b01;
BTFLD:	deco.Rcvec = ir.r3.Tc==2'b01;
default:	deco.Rcvec = 1'b0;
endcase

// Cat
case(ir.any.opcode)
CSR:
	deco.lk = ir.csr.regno[4:1];
// Cannot update ca[0] with a branch
JMP,DJMP,JEQZ,JNEZ,DJEQZ,DJNEZ:
	deco.lk = {2'b0,ir.jxx.lk};
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.lk = {2'b0,ir.jxx.lk};
default: 	deco.lk = 4'd0;
endcase

case(ir.any.opcode)
BRK:	deco.carfwr = TRUE;
MTLK:	deco.carfwr = TRUE;
CSR:
	case (ir.csr.op)
	CSRRW:
		// Cannot update ca[7] this way.
		if (ir.csr.regno[11:4]==8'h10 && ir.csr.regno[11:1] != 11'h87)	// 0x3100 to 0x310F
			deco.carfwr = TRUE;
		else
			deco.carfwr = FALSE;
	default:	deco.carfwr = FALSE;
	endcase
// Cannot update ca[0] with a branch
JMP,DJMP,JEQZ,JNEZ,DJEQZ,DJNEZ:
	deco.carfwr = ir.jxx.lk != 2'd0;
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.carfwr = ir.jxx.lk != 2'd0;
default: 	deco.carfwr = FALSE;
endcase

case(ir.any.opcode)
MTLK:	deco.Cat = {2'd0,ir[15],~ir[15]};
CSR:
	case (ir.csr.op)
	CSRRW:
		if (ir.csr.regno[11:4]==8'h10 || ir.csr.regno[11:4]==8'h11)	// 0x3100 to 0x311F
			deco.Cat = ir.csr.regno[4:1];
		else
			deco.Cat = 4'd0;
	default:	deco.Cat = 4'd0;
	endcase
JMP,DJMP,JEQZ,JNEZ,DJEQZ,DJNEZ:
	deco.Cat = {2'b0,ir.jxx.lk};
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.Cat = {2'b0,ir.jxx.lk};
default: 	deco.Cat = 4'd0;
endcase

// Detecting register file update
casez(ir.any.opcode)
R1,F1,DF1,P1:
	case(ir.r1.func)
	default:	rfwr = TRUE;
	endcase
R2,F2,DF2,P2:
	case(ir.r3.func)
	default:	rfwr = TRUE;
	endcase
R3,F3,DF3,P3:
	case(ir.r3.func)
	default:	rfwr = TRUE;
	endcase
BTFLD:
	case(ir.r3.func)
	BFALIGN,BFFFO,BFEXTU,BFEXT,
	ANDM,BFSET,BFCHG,BFCLR:
		rfwr = TRUE;
	default:	rfwr = FALSE;
	endcase
CSR:	rfwr = TRUE;
MFLK:	rfwr = TRUE;
ADDI,SUBFI,CMPI,CMPUI,MULI,DIVI,MULUI:
	rfwr = TRUE;
ANDI,ORI,XORI:		rfwr = TRUE;
SEQI,SNEI,SLTI,SGTI:		rfwr = TRUE;
ADDIL,SUBFIL,CMPIL,CMPUIL,MULIL,DIVIL,MULUIL:
	rfwr = TRUE;
ANDIL,ORIL,XORIL:	rfwr = TRUE;
SEQIL,SNEIL,SLTIL,SGTIL:		rfwr = TRUE;
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOS,LDOR,LDOU,LDH:
	rfwr = TRUE;
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDORX,LDOUX,LDHX:
	rfwr = TRUE;
LEA,LEAX:	rfwr = TRUE;
ADD2R,AND2R,OR2R,XOR2R,SLT2R:
	rfwr = TRUE;
DJMP,BSET:
	rfwr = TRUE;
default:	rfwr = FALSE;
endcase

// Computing immediate constant
case(ir.any.opcode)
ADDI,SUBFI,CMPI,SEQI,SNEI,SLTI,SGTI,MULI,DIVI:
	imm = {{53{ir.ri.imm[10]}},ir.ri.imm};
ANDI:	// Pad with ones to the left
	imm = {{53{1'b1}},ir.ri.imm};
CMPUI,ORI,XORI,SLTUI,SGTUI,MULUI,DIVUI:	// Pad with zeros to the left
	imm = {{53{1'b0}},ir.ri.imm};
CHKI:	imm = {{42{ir[47]}},ir[47:29],ir[11:9]};
ADDIL,SUBFIL,CMPIL,SEQIL,SNEIL,SLTIL,SGTIL,MULIL,DIVIL:
	imm = ir.any.v ? {{41{ir.ril.imm[22]}},ir.rilv.imm} : {{37{ir.ril.imm[26]}},ir.ril.imm};
CMPUIL,SLTUIL,SGTUIL,MULUIL:
	imm = ir.any.v ? {{41{1'b0}},ir.rilv.imm} : {{37{1'b0}},ir.ril.imm};
ANDIL:	imm = ir.any.v ? {{41{1'b1}},ir.rilv.imm} : {{37{1'b1}},ir.ril.imm};
ORIL,XORIL:	imm = ir.any.v ? {{41{1'b0}},ir.rilv.imm} : {{37{1'b0}},ir.ril.imm};
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOU,LDH,LEA:
	imm = {{40{ir.ld.disp[23]}},ir.ld.disp};
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDOUX,LDHX,LEAX:
	imm = {{56{ir.ldx.disp[7]}},ir.ldx.disp};
STB,STW,STT,STO,STH:
	imm = {{40{ir.st.disp[23]}},ir.st.disp};
STBX,STWX,STTX,STOX,STHX:
	imm = {{56{ir.stx.disp[7]}},ir.stx.disp};
LDOS:	imm = {{56{ir.lds.disp[7]}},ir.lds.disp};
STOS:	imm = {{56{ir.sts.disp[7]}},ir.sts.disp};
default:
	imm = 64'd0;
endcase
if (xval)
	casez(xir.any.opcode)
	EXI7:		imm = {{34{xir[15]}},xir[15:9],imm[22:0]};
	EXI23:	imm = {{18{xir[31]}},xir[31:9],imm[22:0]};
	EXI41:	imm = {xir[47:9],xir[1:0],imm[22:0]};
	endcase

case(ir.any.opcode)
ADDIL,SUBFIL,CMPIL,SEQIL,SNEIL,SLTIL,SGTIL,SLTUIL,SGTUIL,MULIL,DIVIL,MULUIL:
	deco.ril = TRUE;
ANDIL,ORIL,XORIL:
	deco.ril = TRUE;
default:	deco.ril = FALSE;
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
ADD2R,AND2R,OR2R,XOR2R,SLT2R:
	deco.Tb = {1'b0,ir[27]};
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.Tb = ir.r3.Tb;
JMP,DJMP:	deco.Tb = 2'b00;
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDORX,LEAX,LDOUX,LDHX:
	deco.Tb = ir.r3.Tb;
STBX,STWX,STTX,STOX,STOCX,STHX:
	deco.Tb = ir.r3.Tb;
default:	deco.Tb = 2'b00;
endcase
case(ir.any.opcode)
R2,R3:	deco.Tc = ir.r3.Tc;
BTFLD:	deco.Tc = ir.r3.Tc;
default:	deco.Tc = 2'b00;
endcase

case(ir.any.opcode)
R2:
	case(ir.r3.func)
	MUL,MULH:	deco.mul = TRUE;
	default:	deco.mul = FALSE;
	endcase
MULI,MULIL:	deco.mul = TRUE;
MULUI,MULUIL:	deco.mul = TRUE;
default:	deco.mul = FALSE;
endcase

case(ir.any.opcode)
R2:
	case(ir.r3.func)
	DIV,DIVU:	deco.div = TRUE;
	default:	deco.div = FALSE;
	endcase
DIVI,DIVIL:	deco.div = TRUE;
//DIVUI,DIVUIL:	deco.div = TRUE;
default:	deco.div = FALSE;
endcase

case(ir.any.opcode)
F1,F2,F3:	deco.float = TRUE;
default:	deco.float = FALSE;
endcase

case(ir.any.opcode)
ADDI,ADDIL:	deco.addi = TRUE;
default:	deco.addi = FALSE;
endcase

case(ir.any.opcode)
CACHE,CACHEX,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOS,LDOR,
LDOU,LDOUX,LDH,LDHX,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDORX:
	deco.ld = TRUE;
default:	deco.ld = FALSE;
endcase

case(ir.any.opcode)
LDBU,LDWU,LDTU,LDOU,
LDBUX,LDWUX,LDTUX,LDOUX:
	deco.ldz = TRUE;
default:	deco.ldz = FALSE;
endcase

case(ir.any.opcode)
CACHE,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOS,LDOR,LDOU,LDH:
	deco.loadr = TRUE;
default:	deco.loadr = FALSE;
endcase

case(ir.any.opcode)
CACHEX,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDORX,LDOUX,LDHX:
	deco.loadn = TRUE;
default:	deco.loadn = FALSE;
endcase


case(ir.any.opcode)
STB,STW,STT,STO,STOS,STOC,STH,
STBX,STWX,STTX,STOX,STOCX,STHX:
	deco.st = TRUE;
default:	deco.st = FALSE;
endcase

case(ir.any.opcode)
STB,STW,STT,STO,STOC,STOS,STH:
	deco.storer = TRUE;
default:	deco.storer = FALSE;
endcase

case(ir.any.opcode)
STBX,STWX,STTX,STOCX,STOX,STHX:
	deco.storen = TRUE;
default:	deco.storen = FALSE;
endcase

deco.ldoo = ir.any.opcode==LDOO || ir.any.opcode==LDOOX;
deco.stoo = ir.any.opcode==STOO || ir.any.opcode==STOOX;

case(ir.any.opcode)
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDORX,LEAX,LDOUX,LDHX:
	deco.scale = ir.ldx.Sc;
STBX,STWX,STTX,STOCX,STOX,STHX:
	deco.scale = ir.stx.Sc;
default:	deco.scale = 3'd0;
endcase

case(ir.any.opcode)
LDB,LDBU,STB:	deco.memsz = byt;
LDW,LDWU,STW:	deco.memsz = wyde;
LDT,LDTU,STT:	deco.memsz = tetra;
LDBX,LDBUX,STBX:	deco.memsz = byt;
LDWX,LDWUX,STWX:	deco.memsz = wyde;
LDTX,LDTUX,STTX:	deco.memsz = tetra;
LDOO,LDOOX,LDH,LDHX:	deco.memsz = hexi;
STOO,STOOX,STH,STHX:	deco.memsz = hexi;
default:	deco.memsz = octa;
endcase

case(ir.any.opcode)
LDB,LDBU:	deco.seg = ir.ld.seg;
LDW,LDWU:	deco.seg = ir.ld.seg;
LDT,LDTU:	deco.seg = ir.ld.seg;
LDO,LDOU:	deco.seg = ir.ld.seg;
LDH:			deco.seg = ir.ld.seg;
LDOO:			deco.seg = ir.ld.seg;
LDOR:			deco.seg = ir.ld.seg;
LDOS:			deco.seg = ir.lds.seg;
LDBX,LDBUX:	deco.seg = ir.ldx.seg;
LDWX,LDWUX:	deco.seg = ir.ldx.seg;
LDTX,LDTUX:	deco.seg = ir.ldx.seg;
LDOX,LDOUX:	deco.seg = ir.ldx.seg;
LDHX:			deco.seg = ir.ldx.seg;
LDORX:		deco.seg = ir.ldx.seg;
STB:			deco.seg = ir.st.seg;
STW:			deco.seg = ir.st.seg;
STT:			deco.seg = ir.st.seg;
STO:			deco.seg = ir.st.seg;
STH:			deco.seg = ir.st.seg;
STOC:			deco.seg = ir.st.seg;
STOS:			deco.seg = ir.sts.seg;
STBX:			deco.seg = ir.stx.seg;
STWX:			deco.seg = ir.stx.seg;
STTX:			deco.seg = ir.stx.seg;
STOX:			deco.seg = ir.stx.seg;
STOCX:		deco.seg = ir.stx.seg;
STHX:			deco.seg = ir.stx.seg;
default:	deco.seg = 3'd0;
endcase

case(ir.any.opcode)
JMP,DJMP:	deco.jmp = TRUE;
default: 	deco.jmp = FALSE;
endcase
case(ir.any.opcode)
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.jxx = TRUE;
default: 	deco.jxx = FALSE;
endcase

case(ir.any.opcode)
DJMP:	deco.dj = TRUE;
default: 	deco.dj = FALSE;
endcase

deco.rts = ir.any.opcode==RTS;

// Detect multi-cycle operations
case(ir.any.opcode)
R2,R3:
	case(ir.r3.func)
	MUL,MULH:	deco.multi_cycle = TRUE;
	DIV:			deco.multi_cycle = TRUE;
	default:	deco.multi_cycle = FALSE;
	endcase
OSR2:
	case(ir.r3.func)
	TLBRW:		deco.multi_cycle = TRUE;
	MTSEL:		deco.multi_cycle = TRUE;
	default:	deco.multi_cycle = FALSE;
	endcase
MULI,MULIL:		deco.multi_cycle = TRUE;
DIVI,DIVIL:		deco.multi_cycle = TRUE;
CACHE,CACHEX:	deco.multi_cycle = TRUE;
LDB,LDBU,STB:	deco.multi_cycle = TRUE;
LDW,LDWU,STW:	deco.multi_cycle = TRUE;
LDT,LDTU,STT: deco.multi_cycle = TRUE;
LDO,LDOS,LDOR,LDOU:		deco.multi_cycle = TRUE;
LDH:					deco.multi_cycle = TRUE;
LDBX,LDBUX,STBX:	deco.multi_cycle = TRUE;
LDWX,LDWUX,STWX:	deco.multi_cycle = TRUE;
LDTX,LDTUX,STT:		deco.multi_cycle = TRUE;
LDOX,LDORX,LDOUX:				deco.multi_cycle = TRUE;
LDHX:					deco.multi_cycle = TRUE;
STO,STOS,STOC,STHX,STH:		deco.multi_cycle = TRUE;
STOX,STOCX:		deco.multi_cycle = TRUE;
STMOV,STFND,STCMP,BSET:			deco.multi_cycle = TRUE;
default:	deco.multi_cycle = FALSE;
endcase

deco.mul = FALSE;
deco.mulu = FALSE;
deco.mulsu = FALSE;
deco.muli = FALSE;
deco.mului = FALSE;
deco.mulsui = FALSE;
deco.mulfi = FALSE;
deco.mulf = FALSE;
case(ir.any.opcode)
R2:
	case(ir.r3.func)
	MUL,MULH:			deco.mul = TRUE;
	MULU,MULUH:		deco.mulu = TRUE;
	MULSU,MULSUH:	deco.mulsu = TRUE;
	MULF:					deco.mulf = TRUE;
	default:	;
	endcase
MULI,MULIL:		deco.muli = TRUE;
MULUI,MULUIL:	deco.mului = TRUE;
MULFI:				deco.mulfi = TRUE;
default:	;
endcase
deco.mulall = deco.mul|deco.mulu|deco.mulsu|deco.muli|deco.mului|deco.mulsui|deco.mulf;
deco.mulalli = deco.muli|deco.mului|deco.mulsui|deco.mulfi;

deco.div = FALSE;
deco.divu = FALSE;
deco.divsu = FALSE;
deco.divi = FALSE;
deco.divui = FALSE;
deco.divsui = FALSE;
case(ir.any.opcode)
R2:
	case(ir.r3.func)
	DIV:	deco.div = TRUE;
	DIVU:	deco.divu = TRUE;
	DIVSU:	deco.divsu = TRUE;
	endcase
DIVI,DIVIL:	deco.divi = TRUE;
endcase
deco.divall = deco.div|deco.divu|deco.divsu|deco.divi|deco.divui|deco.divsui;
deco.divalli = deco.divi|deco.divui|deco.divsui;

deco.is_cbranch = ir.jxx.Ca==3'd7 && (ir.any.opcode[7:4]==4'h2 || ir.any.opcode[7:4]==4'h3);
deco.jxz = ir.any.opcode==JEQZ || ir.any.opcode==JNEZ || ir.any.opcode==DJEQZ || ir.any.opcode==DJNEZ;
if (deco.jxx)
	deco.jmptgt = {{44{ir.jxx.Tgthi[15]}},ir.jxx.Tgthi,ir.jxx.Tgtlo,1'b0};
else if (deco.jxz)
	deco.jmptgt = {{51{ir[28]}},ir[28:21],ir[14:11],1'b0};
else
	deco.jmptgt = {{30{ir.jmp.Tgthi[15]}},ir.jmp.Tgthi,ir.jmp.Tgtlo,1'b0};
	
deco.csr = ir.any.opcode==CSR;
deco.rti = ir.any.opcode==OSR2 && ir.r3.func==RTI;
deco.rex = ir.any.opcode==OSR2 && ir.r3.func==REX;
deco.sync = ir.any.opcode==CSR || ir.any.opcode==SYNC;
deco.tlb = ir.any.opcode==OSR2 && ir.r3.func==TLBRW;
deco.mtlc = ir.any.opcode==VM && ir.vmr2.func==MTLC;
deco.mfsel = ir.any.opcode==OSR2 && ir.r3.func==MFSEL;
deco.mtsel = ir.any.opcode==OSR2 && ir.r3.func==MTSEL;
deco.lear = ir.any.opcode==LEA;
deco.lean = ir.any.opcode==LEAX;

case(ir.any.opcode)
R2,R3:
	deco.Rvm = ir.r3.m;
ADD2R,AND2R,OR2R,XOR2R,SLT2R:
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
ADD2R,AND2R,OR2R,XOR2R,SLT2R:
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
	MTVM:	deco.vmrfwr = TRUE;
	default:	deco.vmrfwr = FALSE;
	endcase
default:	deco.vmrfwr = FALSE;
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
deco.flowchg = deco.rti || deco.rex || deco.jmp || deco.jxx || deco.jxz || deco.rts;

if (deco.mflk)
	deco.Ca = {2'd0,ir[15],~ir[15]};
else if (deco.jxx)
	deco.Ca = {1'd0,ir.jxx.Ca};
else if (deco.rts)
	deco.Ca = {2'd0,ir.rts.lk};
else if (deco.jmp)
	deco.Ca = {1'd0,ir.jmp.Ca};
else
	deco.Ca = 4'h0;

case(ir.any.opcode)
BRK:	deco.Ct = 4'h8 + distk_depth;
MTLK:	deco.Ct = {2'd0,ir[15],~ir[15]};
CSR:
	case (ir.csr.op)
	CSRRW:	deco.Ct = ir.csr.regno[4:1];
	default:	deco.Ct = 4'h8 + distk_depth;
	endcase
// Cannot update ca[0] with a branch
JMP,DJMP,JEQZ,JNEZ,DJEQZ,DJNEZ:
	deco.Ct = {2'd0,ir.jxx.lk};
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
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
	ADD:			deco.rm = ir[31:29]==3'd7 ? rm : ir[31:29];
	default:	deco.rm = rm;
	endcase
default:	deco.rm = rm;
endcase

end
endmodule
