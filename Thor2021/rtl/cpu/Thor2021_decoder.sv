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
Ra = ir.r3.Ra;
Rb = ir.r3.Rb;
rfwr = FALSE;
// Target register
case(ir.any.opcode)
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	Rt = 6'd0;
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	Rt = 6'd0;
JMP,DJMP:			Rt = 6'd0;
STB,STW,STT,STO,STOC,STOS:
	Rt = 6'd0;
STBX,STWX,STTX,STOX,STOCX:
	Rt = 6'd0;
default:	Rt = ir[14:9];
endcase
// Rc
case(ir.any.opcode)
STB,STW,STT,STO,STOC,
STBX,STWX,STTX,STOX,STOCX,
STOS:
	Rc = ir.st.Rs;
default:	Rc = ir.r3.Rc;
endcase

deco.Ravec = ir.any.v;
deco.Rtvec = ir.any.v;
deco.Rbvec = ir.r3.Tb==2'b01;
deco.Rcvec = ir.r3.Tc==2'b01;

// Cat
case(ir.any.opcode)
CSR:
	deco.lk = ir.csr.regno[4:1];
// Cannot update ca[0] with a branch
JMP,DJMP:
	deco.lk = {2'b0,ir.jxx.lk};
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.lk = {2'b0,ir.jxx.lk};
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	deco.lk = {2'b0,ir.jxx.lk};
default: 	deco.lk = 4'd0;
endcase

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
ADDI,SUBFI,CMPI:	rfwr = TRUE;
ANDI,ORI,XORI:		rfwr = TRUE;
SEQI,SNEI,SLTI,SGTI:		rfwr = TRUE;
ADDIL,CMPIL:			rfwr = TRUE;
ANDIL,ORIL,XORIL:	rfwr = TRUE;
SEQIL,SNEIL,SLTIL,SGTIL:		rfwr = TRUE;
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOS:
	rfwr = TRUE;
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX:
	rfwr = TRUE;
LEA,LEAX:	rfwr = TRUE;
default:	rfwr = FALSE;
endcase

// Computing immediate constant
case(ir.any.opcode)
ADDI,SUBFI,CMPI,SEQI,SNEI,SLTI,SGTI:
	begin
		imm = {{53{ir.ri.imm[10]}},ir.ri.imm};
	end
ANDI:	// Pad with ones to the left
	begin
		imm = {{53{1'b1}},ir.ri.imm};
	end
ORI,XORI,SLTUI,SGTUI:	// Pad with zeros to the left
	begin
		imm = {{53{1'b0}},ir.ri.imm};
	end
CHKI:	imm = {{42{ir[47]}},ir[47:29],ir[11:9]};
ADDIL,CMPIL,SEQIL,SNEIL,SLTIL,SGTIL,MULIL,DIVIL:
	imm = {{41{ir.ril.imm[22]}},ir.ril.imm};
ANDIL:	imm = {{41{1'b1}},ir.ril.imm};
ORIL,XORIL:	imm = {{41{1'b0}},ir.ril.imm};
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO:
	imm = {{40{ir.ld.disp[23]}},ir.ld.disp};
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX:
	imm = {{56{ir.ldx.disp[7]}},ir.ldx.disp};
STB,STW,STT,STO:
	imm = {{40{ir.st.disp[23]}},ir.st.disp};
STBX,STWX,STTX,STOX:
	imm = {{56{ir.stx.disp[7]}},ir.stx.disp};
LDOS:	imm = {{56{ir.sts.disp[7]}},ir.lds.disp};
STOS:	imm = {{56{ir.sts.disp[7]}},ir.sts.disp};
default:
	imm = 64'd0;
endcase
casez(xir.any.opcode)
EXI7:		imm = {{34{xir[15]}},xir[15:9],imm[22:0]};
EXI23:	imm = {{18{xir[31]}},xir[31:9],imm[22:0]};
EXI41:	imm = {xir[47:9],xir[1:0],imm[22:0]};
endcase

case(ir.any.opcode)
ADDIL,CMPIL,SEQIL,SNEIL,SLTIL,SGTIL,MULIL,DIVIL:
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
ADD2R,AND2R,OR2R,XOR2R:
	deco.Tb = {1'b0,ir[27]};
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.Tb = ir.r3.Tb;
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	deco.Tb = ir.r3.Tb;
JMP,DJMP:	deco.Tb = 2'b00;
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX:
	deco.Tb = ir.r3.Tb;
STBX,STWX,STTX,STOX:
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
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDORX:
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
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOS,LDOR:
	deco.loadr = TRUE;
default:	deco.loadr = FALSE;
endcase

case(ir.any.opcode)
CACHEX,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDORX:
	deco.loadn = TRUE;
default:	deco.loadn = FALSE;
endcase


case(ir.any.opcode)
STB,STW,STT,STO,STOS,STOC,
STBX,STWX,STTX,STOX,STOCX:
	deco.st = TRUE;
default:	deco.st = FALSE;
endcase

case(ir.any.opcode)
STB,STW,STT,STO,STOC,STOS:
	deco.storer = TRUE;
default:	deco.storer = FALSE;
endcase

case(ir.any.opcode)
STBX,STWX,STTX,STOCX,STOX:
	deco.storen = TRUE;
default:	deco.storen = FALSE;
endcase

case(ir.any.opcode)
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDORX:
	deco.scale = ir.ldx.Sc;
STBX,STWX,STTX,STOCX,STOX:
	deco.scale = ir.stx.Sc;
default:	deco.scale = 3'd0;
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
LDB,LDBU:	deco.seg = ir.ld.seg;
LDW,LDWU:	deco.seg = ir.ld.seg;
LDT,LDTU:	deco.seg = ir.ld.seg;
LDO:			deco.seg = ir.ld.seg;
LDOS:			deco.seg = ir.lds.seg;
LDBX,LDBUX:	deco.seg = ir.ldx.seg;
LDWX,LDWUX:	deco.seg = ir.ldx.seg;
LDTX,LDTUX:	deco.seg = ir.ldx.seg;
LDOX:			deco.seg = ir.ldx.seg;
STB:			deco.seg = ir.st.seg;
STW:			deco.seg = ir.st.seg;
STT:			deco.seg = ir.st.seg;
STO:			deco.seg = ir.st.seg;
STOS:			deco.seg = ir.sts.seg;
STBX:			deco.seg = ir.stx.seg;
STWX:			deco.seg = ir.stx.seg;
STTX:			deco.seg = ir.stx.seg;
STOX:			deco.seg = ir.stx.seg;
default:	deco.seg = 3'd0;
endcase

case(ir.any.opcode)
JMP,DJMP:	deco.jmp = TRUE;
default: 	deco.jmp = FALSE;
endcase
case(ir.any.opcode)
JBC,JBS,JEQ,JNE,JLT,JGE,JLE,JGT,JLTU,JGEU,JLEU,JGTU:
	deco.jxx = TRUE;
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	deco.jxx = TRUE;
default: 	deco.jxx = FALSE;
endcase

case(ir.any.opcode)
DJMP,
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU:
	deco.dj = TRUE;
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
LDO,LDOS,LDOR:		deco.multi_cycle = TRUE;
LDBX,LDBUX,STBX:	deco.multi_cycle = TRUE;
LDWX,LDWUX,STWX:	deco.multi_cycle = TRUE;
LDTX,LDTUX,STT:		deco.multi_cycle = TRUE;
LDOX,LDORX:		deco.multi_cycle = TRUE;
STO,STOS,STOC:		deco.multi_cycle = TRUE;
STOX,STOCX:		deco.multi_cycle = TRUE;
LEA,LEAX:		deco.multi_cycle = TRUE;
STMOV,STFND,STCMP,STSET:			deco.multi_cycle = TRUE;
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
	case(ir.r3.func)
	MUL,MULH:			deco.mul = TRUE;
	MULU,MULUH:		deco.mulu = TRUE;
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
if (deco.jxx)
	deco.jmptgt = {{44{ir.jxx.Tgthi[15]}},ir.jxx.Tgthi,ir.jxx.Tgtlo,1'b0};
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
DJBC,DJBS,DJEQ,DJNE,DJLT,DJGE,DJLE,DJGT,DJLTU,DJGEU,DJLEU,DJGTU,
DJMP:	deco.wrlc = TRUE;
VM:
	case(ir.vmr2.func)
	MTLC:	deco.wrlc = FALSE;	// MTLC will update LC in Thor2021io.sv
	default:	deco.wrlc = FALSE;
	endcase
STSET:	deco.wrlc = TRUE;
default:
	deco.wrlc = FALSE;
endcase

case(ir.any.opcode)
R2,R3:
	deco.Rvm = ir.r3.m;
ADD2R,AND2R,OR2R,XOR2R:
	deco.Rvm = ir.any[31:29];
default:
	if (deco.ril)
		deco.Rvm = ir.ril.m;
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
ADD2R,AND2R,OR2R,XOR2R:
	deco.Rz = ir.any[28];
default:
	if (deco.ril)
		deco.Rz = ir.ril.z;
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

deco.mem = deco.ld|deco.loadr|deco.storer|deco.loadn|deco.storen|deco.lear|deco.lean|deco.tlb;
deco.load = deco.ld|deco.loadr|deco.loadn|deco.lear|deco.lean|deco.tlb;
deco.stset = ir.any.opcode==STSET;
deco.stmov = ir.any.opcode==STMOV;
deco.stfnd = ir.any.opcode==STFND;
deco.stcmp = ir.any.opcode==STCMP;

end

endmodule
