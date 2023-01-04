// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_decode_imm.sv
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

import Thor2023_pkg::*;

module Thor2023_decode_imm(ir, ir2, ir3, ir4, imm, inc);
input instruction_t ir;
input instruction_t ir2;
input instruction_t ir3;
input instruction_t ir4;
output value_t imm;
output [4:0] inc;					// How much PC should increment by

always_comb
begin
// Computing immediate constant
case(ir.any.opcode)
R2:
	case(ir.r3.func)
	SLL,SRL,SRA,ROL,ROR: imm = {57'd0,ir[34:28]};
	default:
		if (ir.r3i.imm[13:7]==7'h40)
			imm = 'd0;
		else
			imm = {{57{ir.r3i.imm[13]}},ir.r3i.imm};
	endcase
ADDI,SUBFI,CMPI,SEQI,SNEI,SLTI,SLEI,SGTI,SGEI,MULI,DIVI,LDI:
	imm = {{51{ir.ri.imm[12]}},ir.ri.imm};
ANDI:	// Pad with ones to the left
	imm = {{51{1'b1}},ir.ri.imm};
ORI,XORI,SLTUI,SGTUI,MULUI,DIVUI:	// Pad with zeros to the left
	imm = {{51{1'b0}},ir.ri.imm};
CHKI:	imm = {{106{ir[47]}},ir[47:29],ir[11:9]};
ADDIL,SUBFIL,CMPIL,SEQIL,SNEIL,SLTIL,SLEIL,SGTIL,SGEIL,MULIL,DIVIL,LDIL:
	imm = ir.any.v ? {{103{ir.ril.imm[24]}},ir.rilv.imm} : {{99{ir.ril.imm[28]}},ir.ril.imm};
SLTUIL,SLEUIL,SGTUIL,SGEUIL,MULUIL:
	imm = ir.any.v ? {{103{1'b0}},ir.rilv.imm} : {{99{1'b0}},ir.ril.imm};
ANDIL:	imm = ir.any.v ? {{103{1'b1}},ir.rilv.imm} : {{99{1'b1}},ir.ril.imm};
ORIL,XORIL:	imm = ir.any.v ? {{103{1'b0}},ir.rilv.imm} : {{99{1'b0}},ir.ril.imm};
LDBS,LDBUS,LDWS,LDWUS,LDTS,LDTUS,LDOS,LDOUS:
	imm = {{115{ir.lds.disp[12]}},ir.lds.disp};
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOU,LDV,LDHP,LDHQ:
	imm = ir.any.v ? {{104{ir.ld.disp[23]}},ir.ld.disp} : {{99{ir.ld.disp[28]}},ir.ld.disp};
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDOUX,LDVX,LDHPX,LDHQX:
	imm = 'd0;
STB,STW,STT,STO,STV,STHP,STHC,STPTR:
	imm = ir.any.v ? {{104{ir.st.disp[23]}},ir.st.disp} : {{99{ir.st.disp[28]}},ir.st.disp};
STBX,STWX,STTX,STOX,STVX,STHPX,STHCX,STPTRX:
	imm = 'd0;
LDHS:	imm = {{115{ir.lds.disp[12]}},ir.lds.disp};
STBS,STWS,STTS,STOS,STHS:
	imm = {{115{ir.sts.disp[12]}},ir.sts.disp};
LDSP,STSP:	imm = {{122{1'b0}},ir[15:14],4'h0};
SLLI,SRLI,SRAI:	imm = {122'd0,ir[24:19]};
default:
	imm = 'd0;
endcase

inc <= 5'd5;
if (ir2.any.opcode==OP_PFX0) begin
	imm[95:18] <= {{46{ir2[39]}},ir2[39:8]};
	inc <= 5'd10;
	if (ir3.any.opcode==OP_PFX1) begin
		imm[95:50] <= {{14{ir3[39]}},ir3[39:8]};
		inc <= 5'd15;
		if (ir4.any.opcode==OP_PFX2) begin
			imm[95:82] <= ir4[21:8];
			inc <= 5'd20;
		end
	end
end
else if (ir2.any.opcode==OP_PFX1) begin
	imm[95:50] <= {{14{ir2[39]}},ir2[39:8]};
	inc <= 5'd10;
	if (ir3.any.opcode==OP_PFX2) begin
		imm[95:82] <= ir3[21:8];
		inc <= 5'd15;
	end
end
else if (ir2.any.opcode==OP_PFX2) begin
	imm[95:82] <= ir2[21:8];
	inc <= 5'd10;
end

endmodule
