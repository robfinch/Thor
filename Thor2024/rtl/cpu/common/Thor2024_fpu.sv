// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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

import Thor2024pkg::*;

module Thor2024_fpu(rst, clk, ir, rm, a, b, c, t, i, p, o, done);
input rst;
input clk;
input instruction_t ir;
input [2:0] rm;
input value_t a;
input value_t b;
input value_t c;
input value_t t;
input value_t i;
input value_t p;
output value_t o;
output reg done;

reg [11:0] cnt;
reg sincos_done;
value_t fmao1, fmao2, fmao3, fmao4, fmao5, fmao6, fmao7;

// A change in arguments is used to load the divider.
change_det #(.WID($bits(double_value_t))) uargcd0 (
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.i({a,b}),
	.cd(cd_args)
);

value_t sino, coso;

fpSincos64 usincos1
(
	.rst(rst),
	.clk(clk),
	.rm(rm),
	.ld(cd_args),
	.a(a),
	.sin(sino),
	.cos(coso)
);

reg fmaop, fma_done;
value_t fmac;
value_t fmab;
value_t fmao;

always_comb
	if (ir.f3.func==FN_FMS || ir.f3.func==FN_FNMS)
		fmaop = 1'b1;
	else
		fmaop = 1'b0;

always_comb
	if (ir.f2.func==FN_FADD || ir.f2.func==FN_FSUB)
		fmab <= 64'h3FF0000000000000;	// 1,0
	else
		fmab <= b;

always_comb
	if (ir.f2.func==FN_FMUL || ir.f2.func==FN_FDIV)
		fmac = 'd0;
	else
		fmac = c;

fpFMA64nrCombo ufma1
(
	.op(fmaop),
	.rm(rm),
	.a(a),
	.b(fmab),
	.c(fmac),
	.o(fmao1),
	.inf(),
	.zero(),
	.overflow(),
	.underflow(),
	.inexact()
);

// Retiming pipeline
always_ff @(posedge clk, posedge rst)
if (rst) begin
	fmao2 <= 'd0;
	fmao3 <= 'd0;
	fmao4 <= 'd0;
	fmao5 <= 'd0;
	fmao6 <= 'd0;
	fmao7 <= 'd0;
	fmao <= 'd0;
end
else begin
	fmao2 <= fmao1;
	fmao3 <= fmao2;
	fmao4 <= fmao3;
	fmao5 <= fmao4;
	fmao6 <= fmao5;
	fmao7 <= fmao6;
	fmao <= fmao7;
end

always_ff @(posedge clk)
if (rst) begin
	cnt <= 'd0;
	sincos_done <= 1'b0;
end
else begin
	if (cd_args)
		cnt <= 'd0;
	else
		cnt <= cnt + 2'd1;
	sincos_done <= cnt==12'd64;
	fma_done <= cnt==12'h8;
end

always_comb
	case(ir.any.opcode)
	OP_FLT2:
		case(ir.f2.func)
		FN_FLT1:
			case(ir.f1.func)
			FN_SIN:	o = sino;
			FN_COS:	o = coso;
			default:	o = 'd0;
			endcase
		FN_FADD,FN_FSUB,FN_FMUL:
			o = fmao;
		default:	o = 'd0;
		endcase
	OP_FLT3:
		case(ir.f3.func)
		FN_FMA,FN_FMS,FN_FNMA,FN_FNMS:
			o = fmao;
		default:	o = 'd0;
		endcase
	default:	o = 'd0;
	endcase
		
always_comb
	case(ir.any.opcode)
	OP_FLT2:
		case(ir.f2.func)
		FN_FLT1:
			case(ir.f1.func)
			FN_SIN:	done = sincos_done;
			FN_COS:	done = sincos_done;
			default:	done = 1'b1;
			endcase
		FN_FADD,FN_FSUB,FN_FMUL:
			done = fma_done;
		default:	done = 1'b1;
		endcase
	OP_FLT3:
		case(ir.f3.func)
		FN_FMA,FN_FMS,FN_FNMA,FN_FNMS:
			done = fma_done;
		default:	done = 1'b1;
		endcase
	default:	done = 1'b1;
	endcase

endmodule
