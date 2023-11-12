// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_decode_imm.sv
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
// 238 LUTs
// ============================================================================

import Thor2024pkg::*;

module Thor2024_decode_imm(ins, imma, immb, immc);
parameter WID=32;
input instruction_t [4:0] ins;
output reg [63:0] imma;
output reg [63:0] immb;
output reg [63:0] immc;

wire [63:0] imm32x64a;
wire [63:0] imm32x64b;
wire [63:0] imm32x64c;
reg [2:0] ndx;
reg flt;

fpCvt32To64 ucvt32x64a(imma[31:0], imm32x64a);
fpCvt32To64 ucvt32x64b(immb[31:0], imm32x64b);
fpCvt32To64 ucvt32x64C(immc[31:0], imm32x64c);

always_comb
begin
	flt = 'd0;
	imma = 'd0;
	immb = 'd0;
	immc = 'd0;
	case(ins[0].any.opcode)
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI,OP_SLTI:
		immb = {{48{ins[0][34]}},ins[0][34:19]};
	OP_ANDI:	immb = {48'hFFFFFFFFFFFF,ins[0][34:19]};
	OP_ORI,OP_EORI:
		immb = {48'h0000,ins[0][34:19]};
	OP_CSR:	immb = {50'd0,ins[0][32:19]};
	OP_RTD:	immb = {{16{ins[0][34]}},ins[0][34:19]};
	OP_JSR: immb = {{48{ins[0][34]}},ins[0][34:19]};
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDA,OP_CACHE,
	OP_STB,OP_STW,OP_STT,OP_STO:
		immb = {{48{ins[0][34]}},ins[0][34:19]};
	OP_FENCE:
		immb = {48'h0,ins[0][23:8]};
	default:
		immb = 'd0;
	endcase
	ndx = 1;
	flt = ins[0].any.opcode==OP_FLT2 || ins[0].any.opcode==OP_FLT3;
	if (ins[ndx].any.opcode==OP_PFXA) begin
		imma = {{31{ins[ndx][39]}},ins[ndx][39:7]};
		if (flt)
			imma = imm32x64a;
		ndx = ndx + 1;
		if (ins[ndx].any.opcode==OP_PFXA) begin
			imma[63:33] = {ins[ndx][37:7]};
			ndx = ndx + 1;
		end
	end
	if (ins[ndx].any.opcode==OP_PFXB) begin
		immb = {{31{ins[ndx][39]}},ins[ndx][39:7]};
		if (flt)
			immb = imm32x64b;
		ndx = ndx + 1;
		if (ins[ndx].any.opcode==OP_PFXB) begin
			immb[63:33] = {ins[ndx][37:7]};
			ndx = ndx + 1;
		end
	end
	if (ins[ndx].any.opcode==OP_PFXC) begin
		immc = {{31{ins[ndx][39]}},ins[ndx][39:7]};
		if (flt)
			immc = imm32x64c;
		ndx = ndx + 1;
		if (ins[ndx].any.opcode==OP_PFXC) begin
			immc[63:33] = {ins[ndx][37:7]};
			ndx = ndx + 1;
		end
	end
end

endmodule
