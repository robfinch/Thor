// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
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

module Thor2021_decoder(ir, xir, deco);
input Instruction ir;
input Instruction xir;
output DecodeOut deco;

integer n;
Value imm;
reg [5:0] Ra, Rb, Rc, Rt;
reg rfwr;

always_comb
begin
Ra = ir[20:15];
Rb = ir[26:21];
rfwr = FALSE;
// Target register
case(ir.any.opcode)
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	Rt = {4'd0,Rt[10:9]};
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	Rt = {4'd0,Rt[10:9]};
JMP,DJMP:			Rt = {4'd0,Rt[10:9]};
default:	Rt = ir[14:9];
endcase
// Rc
case(ir.any.opcode)
STB,STW,STT,STO,STOC,
STBX,STWX,STTX,STOX,STOCX,
STOS:
	Rc = ir[14:9];
default:	Rc = ir[34:29];
endcase

// Cat
case(ir.any.opcode)
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
JMP,DJMP:
	deco.carfwr = ir.jxx.lk != 2'd0;
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.carfwr = ir.jxx.lk != 2'd0;
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	deco.carfwr = ir.jxx.lk != 2'd0;
default: 	deco.carfwr = FALSE;
endcase

case(ir.any.opcode)
CSR:
	case (ir.csr.op)
	CSRRW:
		if (ir.csr.regno[11:4]==8'h10)	// 0x3100 to 0x310F
			deco.Cat = ir.csr.regno[3:1];
		else
			deco.Cat = 3'd0;
	default:	deco.Cat = 3'd0;
	endcase
JMP,DJMP:
	deco.Cat = {1'b0,ir.jxx.lk};
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.Cat = {1'b0,ir.jxx.lk};
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	deco.Cat = {1'b0,ir.jxx.lk};
default: 	deco.Cat = 3'd0;
endcase

// Detecting register file update
casez(ir.any.opcode)
R1,F1,DF1,P1:
	case(ir.r1.func)
	default:	rfwr = TRUE;
	endcase
R2,F2,DF2,P2:
	case(ir.r2.func)
	default:	rfwr = TRUE;
	endcase
R3,F3,DF3,P3:
	case(ir.r3.func)
	default:	rfwr = TRUE;
	endcase
ADDI,SUBFI,CMPI:	rfwr = TRUE;
ANDI,ORI,XORI:		rfwr = TRUE;
SEQI,SNEI,SLTI:		rfwr = TRUE;
ADDIL,CMPIL:			rfwr = TRUE;
ANDIL,ORIL,XORIL:	rfwr = TRUE;
default:	rfwr = FALSE;
endcase
// Computing immediate constant
case(ir.any.opcode)
ADDI,SUBFI,CMPI,SEQI,SNEI,SLTI:
	begin
		imm = {{53{ir.ri.imm[10]}},ir.ri.imm};
	end
ANDI:	// Pad with ones to the right and left
	begin
		imm = {{53{1'b1}},ir.ri.imm};
	end
ORI,XORI:	// Pad with zeros to the right and left
	begin
		imm = {{53{1'b0}},ir.ri.imm};
	end
CHKI:	imm = {{42{ir[47]}},ir[47:29],ir[11:9]};
ADDIL,CMPIL,SEQIL,SNEIL,SLTIL:
	imm = {{41{ir[43]}},ir[43:21]};
ANDIL:	imm = {{41{1'b1}},ir[43:21]};
ORIL,XORIL:	imm = {{41{1'b0}},ir[43:21]};
default:
	imm = 64'd0;
endcase
casez(xir.any.opcode)
EXI7:		imm = {34{xir[15]}},xir[15:9],ir[43:21]};
EXI23:	imm = {18{xir[31]}},xir[31:9],ir[43:21]};
EXI41:	imm = {xir[47:9],ir[43:21],xir[1:0]};
default;	;
endcase
deco.rfwr = rfwr;
deco.Ra = Ra;
deco.Rb = Rb;
deco.Rc = Rc;
deco.Rt = Rt;
deco.is_vector = ir[8];
deco.imm = imm;

case(ir.any.opcode)
R2,R3:	deco.Tb = ir[28:27];
ADD2R,AND2R,OR2R,XOR2R:
	deco.Tb = {1'b0,ir[27]};
default:	deco.Tb = 2'b00;
endcase
case(ir.any.opcode)
R2,R3:	deco.Tc = ir[36:35];
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
end

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
default;	deco.float = FALSE;
endcase

case(ir.any.opcode)
ADDI,ADDIL:	deco.addi = TRUE;
default:	deco.addi = FALSE;
endcase

case(ir.any.opcode)
CACHE,CACHEX,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOS,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX:
	deco.ld = TRUE;
default:	deco.ld = FALSE;
endcase

case(ir.any.opcode)
LDBU,LDWU,LDTU,
LDBUX,LDWUX,LDTUX:
	deco.ldz = TRUE;
default:	deco.ldz = FALSE;
endcase

case(ir.any.opcode)
CACHE,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOS:
	deco.loadr = TRUE;
default:	deco.loadr = FALSE;
endcase

case(ir.any.opcode)
CACHEX,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX:
	deco.loadn = TRUE;
default:	deco.loadn = FALSE;
endcase


case(ir.any.opcode)
STB,STW,STT,STO,STOS,
STBX,STWX,STTX,STOX:
	deco.st = TRUE;
default:	deco.st = FALSE;
endcase

case(ir.any.opcode)
STB,STW,STT,STO,STOS:
	deco.storer = TRUE;
default:	deco.storer = FALSE;
endcase

case(ir.any.opcode)
STBX,STWX,STTX,STOX:
	deco.storen = TRUE;
default:	deco.storen = FALSE;
endcase

case(ir.any.opcode)
LDB,LDBU,STB:	deco.memsz = byt;
LDW,LDWU,STW:	deco.memsz = wyde;
LDT,LDTU,STT:	deco.memsz = tetra;
LDBX,LDBUX,STBX:	deco.memsz = byt;
LDWX,LDWUX,STWX:	deco.memsz = wyde;
LDTX,LDTUX,STT:		deco.memsz = tetra;
default:	deco.memsz = octa;
endcase


case(ir.any.opcode)
JMP,DJMP:	deco.jmp = TRUE;
default: 	deco.jmp = FALSE;;
endcase
case(ir.any.opcode)
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.jxx = TRUE;
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	deco.jxx = TRUE;
default: 	deco.jxx = FALSE;;
endcase

case(ir.any.opcode)
DJMP:	deco.dj = TRUE;
default: 	deco.dj = FALSE;;
endcase
case(ir.any.opcode)
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	deco.dj = TRUE;
default: 	deco.dj = FALSE;;
endcase

deco.rts = ir.any.opcode==RTS;

// Detect multi-cycle operations
case(ir.any.opcode)
R2:
	case(ir.r2.func)
	MUL,MULH:	deco.multi_cycle = TRUE;
	DIV:			deco.multi_cycle = TRUE;
	default:	deco.multi_cycle = FALSE;
	endcase
MULI,MULIL:		deco.multi_cycle = TRUE;
DIVI,DIVIL:		deco.multi_cycle = TRUE;
JMP,DJMP:			deco.multi_cycle = TRUE;
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.multi_cycle = TRUE;
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	deco.multi_cycle = TRUE;
RTS:	deco.multi_cycle = TRUE;
CACHE,CACHEX:	deco.multi_cycle = TRUE;
LDB,LDBU,STB:	deco.multi_cycle = TRUE;
LDW,LDWU,STW:	deco.multi_cycle = TRUE;
LDT,LDTU,STT: deco.multi_cycle = TRUE;
LDBX,LDBUX,STBX:	deco.multi_cycle = TRUE;
LDWX,LDWUX,STWX:	deco.multi_cycle = TRUE;
LDTX,LDTUX,STT:		deco.multi_cycle = TRUE;
default:	deco.multi_cycle = FALSE;
endcase

deco.mul = FALSE;
deco.mulu = FALSE;
deco.mulsu = FALSE;
deco.muli = FALSE;
deco.mului = FALSE;
deco.mulsui = FALSE;
case(ir.any.opcode)
R2:
	case(ir.r2.func)
	MUL,MULH:			deco.mul = TRUE;
	MULU,MULUH		deco.mulu = TRUE;
	MULSU,MULSUH:	deco.mulsu = TRUE;
	default:	;
	endcase
MULI,MULIL:		deco.muli = TRUE;
MULUI,MULUIL:	deco.mului = TRUE;
default:	;
endcase
deco.mulall = deco.mul|deco.mulu|deco.mulsu|deco.muli|deco.mului|deco.mulsui;
deco.mulalli = deco.muli|deco.mului|deco.mulsui;

deco.div = FALSE;
deco.divu = FALSE;
deco.divsu = FALSE;
deco.divi = FALSE;
deco.divui = FALSE;
deco.divsui = FALSE;
case(ir.any.opcode)
R2:
	case(ir.r2.func)
	DIV:	deco.div = TRUE;
	DIVU:	deco.divu = TRUE;
	DIVSU:	deco.divsu = TRUE;
	endcase
DIVI,DIVIL:	deco.divi = TRUE;
endcase
deco.divall = deco.div|deco.divu|deco.divsu|deco.divi|deco.divui|deco.divsui;
deco.divalli = deco.divi|deco.divui|deco.divsui;

deco.is_cbranch = ir.jxx.ca==3'd7 && ir.any.opcode[7:4]==4'h2 || ir.any.opcode[7:4]==4'h3;
if (deco.jxx)
	deco.jmptgt = {{44{ir.jxx.Tgthi[15]}},ir.jxx.Tgthi,ir.jxx.Tgtlo,1'b0};
else
	deco.jmptgt = {{30{ir.jmp.Tgthi[15]}},ir.jmp.Tgthi,ir.jmp.Tgtlo,1'b0};
end

endmodule
