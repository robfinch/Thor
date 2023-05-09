// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_eval_branch.sv
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

import Thor2023Pkg::*;

module Thor2023_eval_branch(inst, fdm, a, b, takb);
input instruction_t inst;
input fdm;
input double_value_t a;
input double_value_t b;
output reg takb;

wire [15:0] fco, dfco, fpco;
wire nan;
fpCompare128 u1 (.a(a), .b(b), .o(fpco), .nan(nan), .snan());
DFPCompare128 u2 (.a(a), .b(b), .o(dfco));
assign fco = fdm ? dfco : fpco;

always_comb
case(inst.br.cm)
2'd0:
	case(inst.br.cnd)
	EQ:	takb = a==b;
	NE:	takb = a != b;
	LT: takb = $signed(a) < $signed(b);
	LE:	takb = $signed(a) <= $signed(b);
	GE:	takb = $signed(a) >= $signed(b);
	GT:	takb = $signed(a) >  $signed(b);
	BC:	takb = ~a[b];
	BS:	takb =  a[b];
	BCI:	takb = ~a[b];
	BSI:	takb =  a[b];
	LO:	takb = a < b;
	LS:	takb = a <= b;
	HS:	takb = a >= b;
	HI:	takb = a >  b;
	RA:	takb = 1'b1;
	SR:	takb = 1'b1;
	endcase
2'd2:
	case(inst.br.cnd)
	FEQ:	takb = fco[0];
	FNE:	takb = fco[5];
	FLT:	takb = fco[1];
	FGE:	takb = fco[6];
	FLE:	takb = fco[2];
	FGT:	takb = fco[7];
	FORD:	takb = fco[9];
	FUN:	takb = fco[4];
	default:	takb = 1'b1;
	endcase
2'd3:
	case(inst.br.cnd)
	FEQ:	takb = dfco[0];
	FNE:	takb = dfco[5];
	FLT:	takb = dfco[1];
	FGE:	takb = dfco[6];
	FLE:	takb = dfco[2];
	FGT:	takb = dfco[7];
	FORD:	takb = dfco[9];
	FUN:	takb = dfco[4];
	default:	takb = 1'b1;
	endcase
default:	;
endcase

endmodule
