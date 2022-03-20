// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_eval_branch.sv
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

import Thor2022_pkg::*;

module Thor2022_eval_branch(inst, a, b, takb);
input Instruction inst;
input Value a;
input Value b;
output reg takb;

wire [15:0] fco, dfco;
fpCompare128 u1 (.a(a), .b(b), .o(fco), .nan(), .snan());
DFPCompare128 u2 (.a(a), .b(b), .o(dfco));

always_comb
case(inst.jxx.cm)
3'd0:
	case(inst.any.opcode)
	JEQ: 	takb = a == b;
	JNE: 	takb = a != b;
	JLT: 	takb = $signed(a) < $signed(b);
	JGE:	takb = $signed(a) >= $signed(b);
	JLE:	takb = $signed(a) <= $signed(b);
	JGT:	takb = $signed(a) > $signed(b);
	JBC:	takb = ~a[b[6:0]];
	JBS:	takb =  a[b[6:0]];
	JBSI:	takb =  a[{inst.jxx.Tb,inst.jxx.Rb}];
	JEQZ:	takb = a == 64'd0;
	JNEZ:	takb = a != 64'd0;
	DJMP:	takb = a != 64'd0;
	MJNEZ:	takb = a != 64'd0;
	default:  takb = 1'b0;
	endcase
3'd1:
	case(inst.any.opcode)
	JEQ:	takb = fco[0];
	JNE:	takb = fco[5];
	JLT:	takb = fco[1];
	JGE:	takb = fco[6];
	JLE:	takb = fco[2];
	JGT:	takb = fco[7];
	JOR:	takb = fco[9];
	JUN:	takb = fco[4];
	JEQZ:	takb = a == 64'd0;
	JNEZ:	takb = a != 64'd0;
	DJMP:	takb = a != 64'd0;
	MJNEZ:	takb = a != 64'd0;
	default:  takb = 1'b0;
	endcase
3'd2:
	case(inst.any.opcode)
	JEQ:	takb = dfco[0];
	JNE:	takb = dfco[5];
	JLT:	takb = dfco[1];
	JGE:	takb = dfco[6];
	JLE:	takb = dfco[2];
	JGT:	takb = dfco[7];
	JOR:	takb = dfco[9];
	JUN:	takb = dfco[4];
	JEQZ:	takb = a == 64'd0;
	JNEZ:	takb = a != 64'd0;
	DJMP:	takb = a != 64'd0;
	MJNEZ:	takb = a != 64'd0;
	default:  takb = 1'b0;
	endcase
3'd3:
	case(inst.any.opcode)
	JEQ: 	takb = a == b;
	JNE: 	takb = a != b;
	JLT: 	takb = $signed(a) < $signed(b);
	JGE:	takb = $signed(a) >= $signed(b);
	JLE:	takb = $signed(a) <= $signed(b);
	JGT:	takb = $signed(a) > $signed(b);
	JBC:	takb = ~a[b[6:0]];
	JBS:	takb =  a[b[6:0]];
	JBSI:	takb =  a[{inst.jxx.Tb,inst.jxx.Rb}];
	JEQZ:	takb = a == 64'd0;
	JNEZ:	takb = a != 64'd0;
	DJMP:	takb = a != 64'd0;
	MJNEZ:	takb = a != 64'd0;
	default:  takb = 1'b0;
	endcase
3'd4:
	case(inst.any.opcode)
	JEQ: 	takb = a == b;
	JNE: 	takb = a != b;
	JLT: 	takb = a < b;
	JGE: 	takb = a >= b;
	JLE:	takb = a <= b;
	JGT:	takb = a > b;
	JBC:	takb = ~a[b[6:0]];
	JBS:	takb =  a[b[6:0]];
	JBSI:	takb =  a[{inst.jxx.Tb,inst.jxx.Rb}];
	JEQZ:	takb = a == 64'd0;
	JNEZ:	takb = a != 64'd0;
	DJMP:	takb = a != 64'd0;
	MJNEZ:	takb = a != 64'd0;
	default:  takb = 1'b0;
	endcase
default:
	begin
	case(inst.any.opcode)
	JEQZ:	takb = a == 64'd0;
	JNEZ:	takb = a != 64'd0;
	DJMP:	takb = a != 64'd0;
	MJNEZ:	takb = a != 64'd0;
	default:	takb = 1'b0;
	endcase
	end
endcase

endmodule
