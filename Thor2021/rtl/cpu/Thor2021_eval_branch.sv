// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2021_eval_branch.sv
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

module Thor2021_eval_branch(inst, a, b, takb);
input Instruction inst;
input Value a;
input Value b;
output reg takb;

always_comb
case(inst.br.opcode)
JEQ: 	takb = a == b;
JNE: 	takb = a != b;
JLT: 	takb = $signed(a) < $signed(b);
JGE:	takb = $signed(a) >= $signed(b);
JLE:	takb = $signed(a) <= $signed(b);
JGT:	takb = $signed(a) > $signed(b);
JLTU: takb = a < b;
JGEU: takb = a >= b;
JLEU:	takb = a <= b;
JGTU:	takb = a > b;
JBC:	takb = ~a[b[5:0]];
JBS:	takb =  a[b[5:0]];
JEQZ:	takb = a == 64'd0;
JNEZ:	takb = a != 64'd0;
DJEQ:	takb = a == b;
DJNE:	takb = a != b;
DJLT:	takb = $signed(a) < $signed(b);
DJGE:	takb = $signed(a) >= $signed(b);
DJLE:	takb = $signed(a) <= $signed(b);
DJGT:	takb = $signed(a) > $signed(b);
DJLTU: 	takb = a < b;
DJGEU: 	takb = a >= b;
DJLEU:	takb = a <= b;
DJGTU:takb = a > b;
DJBC:	takb = ~a[b[5:0]];
DJBS:	takb =  a[b[5:0]];
DJEQZ:	takb = a == 64'd0;
DJNEZ:	takb = a != 64'd0;
default:  takb = 1'b0;
endcase

endmodule
