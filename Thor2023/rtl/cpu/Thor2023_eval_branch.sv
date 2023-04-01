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
input value_t a;
input value_t b;
output reg takb;

wire [15:0] fco, dfco, fpco;
wire nan;
fpCompare96 u1 (.a(a), .b(b), .o(fpco), .nan(nan), .snan());
DFPCompare96 u2 (.a(a), .b(b), .o(dfco));
assign fco = fdm ? dfco : fpco;

always_comb
case(inst.br.cnd)
EQ:	takb = a==b;
LT: takb = $signed(a) < $signed(b);
LE:	takb = $signed(a) <= $signed(b);
LO:	takb = a < b;
LS:	takb = a <= b;
BC:	takb = ~a[b];
BS:	takb =  a[b];
//ODD:	takb = a[5];
//MI:	takb = a[95];
NE:	takb = a != b;
GE:	takb = $signed(a) >= $signed(b);
GT:	takb = $signed(a) >  $signed(b);
HS:	takb = a >= b;
HI:	takb = a >  b;
//EVEN:	takb = a[13];
RA:	takb = 1'b1;
SR:	takb = 1'b1;
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

endmodule
