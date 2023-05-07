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
// 238 LUTs
// ============================================================================

import Thor2023Pkg::*;

module Thor2023_decode_imm(ir, ir2, ir3, ir4, ir5, imm, inc);
input instruction_t ir;
input instruction_t ir2;
input instruction_t ir3;
input instruction_t ir4;
input instruction_t ir5;
output double_value_t imm;
output reg [4:0] inc;					// How much PC should increment by

wire double_value_t imm16x128, imm32x128, imm64x128;
fpCvt16To128 ucvt16x128({ir[39:32],ir[30:23]}, imm16x128);
fpCvt32To128 ucvt32x128(ir2[39:8], imm32x128);
fpCvt64To128 ucvt64x128({ir3[39:8],ir2[39:8]}, imm64x128);

reg fpAddi;
always_comb
case(ir.any.opcode)
OP_FADDI,OP_FCMPI,OP_FMULI,OP_FDIVI:
	fpAddi = 1'b1;
default:	fpAddi = 1'b0;
endcase

always_comb
begin
// Computing immediate constant
case(ir.any.opcode)
OP_SHIFT:
	case(ir.r2.func)
	OP_ASLI,OP_LSRI,OP_LSLI,OP_ASRI,OP_ROLI,OP_RORI:
		imm = ir.r2.Rb[6:0];
	default:	imm = 'd0;
	endcase
OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI:
	imm = {{113{ir.ri.immhi[6]}},ir.ri.immhi,ir.ri.immlo};
OP_ANDI:	// Pad with ones to the left
	imm = {{113{1'b1}},ir.ri.immhi,ir.ri.immlo};
OP_ORI,OP_EORI:	// Pad with zeros to the left
	imm = {{113{1'b0}},ir.ri.immhi,ir.ri.immlo};
OP_LOAD,OP_LOADZ,OP_STORE:
	imm = {{115{ir.ls.Disphi[5]}},ir.ls.Disphi,ir.ls.Displo};
OP_FADDI,OP_FCMPI,OP_FMULI,OP_FDIVI:
	imm = imm16x128;
default:
	imm = 'd0;
endcase

inc = 5'd5;
if (ir2.any.opcode==OP_PFX && ir2.any.sz==3'd0) begin
	if (fpAddi)
		imm = imm32x128;
	else
		imm = {{96{ir2[39]}},ir2[39:8]};
	inc = 5'd10;
	if (ir3.any.opcode==OP_PFX && ir3.any.sz==3'd1) begin
		if (fpAddi)
			imm = imm64x128;
		else
			imm[127:32] = {{64{ir3[39]}},ir3[39:8]};
		inc = 5'd15;
		if (ir4.any.opcode==OP_PFX && ir4.any.sz==3'd2) begin
			if (fpAddi)
				imm = {ir5[39:8],ir4[39:8],ir3[39:8],ir2[39:8]};
			else
				imm[127:64] = {ir5[39:8],ir4[39:8]};
			inc = 5'd20;
		end
	end
end
else if (ir2.any.opcode==OP_PFX && ir2.any.sz==3'd1) begin
	imm = {{64{ir2[39]}},ir2[39:8],32'd0};
	inc = 5'd10;
	if (ir3.any.opcode==OP_PFX && ir3.any.sz==3'd2) begin
		imm[127:64] = {{32{ir3[39]}},ir3[39:8]};
		inc = 5'd15;
	end
end
else if (ir2.any.opcode==OP_PFX && ir2.any.sz==3'd2) begin
	imm = {{32{ir2[39]}},ir2[39:8],64'd0};
	inc = 5'd10;
end
end

endmodule
