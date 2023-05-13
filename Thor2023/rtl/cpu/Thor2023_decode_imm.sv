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

module Thor2023_decode_imm(line, imm, reglist, inc, abrt);
input [255:0] line;
output double_value_t imm;
output reg [63:0] reglist;
output reg [7:0] inc;					// How much PC should increment by
output reg abrt;

instruction_t ir;
reg [255:0] line1;
reg [255:0] line2;
wire double_value_t imm16x128, imm16x128b, imm32x128, imm64x128;
fpCvt16To128 ucvt16x128({ir[39:32],ir[30:23]}, imm16x128);
fpCvt16To128 ucvt16x128b(line[23:8], imm16x128b);
fpCvt32To128 ucvt32x128(line[39:8], imm32x128);
fpCvt64To128 ucvt64x128(line[71:8], imm64x128);

reg fp;
reg fpImm;

function fnIsLong;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_Bcc:	fnIsLong = 1'b0;
	OP_LBcc:	fnIsLong = 1'b1;
	OP_DBcc:	fnIsLong = 1'b0;
	OP_PFX:	fnIsLong = 1'b0;
	default:	fnIsLong = ir.any.vec;
	endcase
end
endfunction

always_comb
	ir = line[39:0];

always_comb
case(ir.any.opcode)
OP_FADDI,OP_FCMPI,OP_FMULI,OP_FDIVI:
	fpImm = 1'b1;
default:	fpImm = 1'b0;
endcase

always_comb
case(ir.any.opcode)
OP_FLT2,OP_FMA:
	fp = 1'b1;
default:	fp = 1'b0;
endcase

always_comb
begin
	// Clear vars.
	inc = 'd0;
	imm = 'd0;
	reglist = 'd0;

	// Decode length of instruction.
	case(ir.any.opcode)
	OP_Bcc:	inc = 8'd5;
	OP_LBcc:	inc = 8'd6;
	OP_DBcc:	inc = 8'd5;
	OP_PFX:
		case(ir.any.sz)
		3'd0:	inc = 8'd5;
		3'd1:	inc = 8'd9;
		3'd2:	inc = 8'd17;
		3'd3:	inc = 8'd3;
		3'd5:	inc = 8'd9;
		3'd7:	inc = 8'd5;
		default:	inc = 8'd5;
		endcase
	endcase

	// Computing immediate constant
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		OP_REP:
			imm = {{113{ir[30]}},ir[30:16]};
		default:	;
		endcase
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

	// Look for immediate override postfix.
	line1 = line >> {inc,3'd0};
	if (line1[4:0]==OP_PFX && line1[7:5]==3'd0) begin
		if (fp)
			imm = imm16x128b;
		else
			imm = {{112{line1[23]}},line1[23:8]};
	end
	else if (line1[4:0]==OP_PFX && line1[7:5]==3'd1) begin
		if (fpImm)
			imm = imm32x128;
		else
			imm = {{96{line1[39]}},line1[39:8]};
		inc = inc + 8'd5;
	end
	else if (line1[4:0]==OP_PFX && line1[7:5]==3'd2) begin
		if (fpImm)
			imm = imm64x128;
		else
			imm = {{64{line1[71]}},line1[71:8]};
		inc = inc + 8'd9;
	end
	else if (line1[4:0]==OP_PFX && line1[7:5]==3'd3) begin
		imm = line1[135:8];
		inc = inc + 8'd17;
	end

	// Look for second postfix containing a register list.
	line2 = line >> {inc,3'd0};
	if (line2[4:0]==OP_PFX && line2[7:5]==3'd5) begin
		reglist = line2[71:8];
		inc = inc + 8'd9;
	end

	abrt = |inc[7:6];
end

endmodule
