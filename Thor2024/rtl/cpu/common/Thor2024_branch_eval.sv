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
//
import Thor2024pkg::*;

module Thor2024_branch_eval(instr, a, b, takb);
input instruction_t instr;
input value_t a;
input value_t b;
output reg takb;

value_t fcmpo;
wire fcmp_nan;

fpCompare64 ufpcmp1
(
	.a(a),
	.b(b),
	.o(fcmpo),
	.inf(),
	.nan(fcmp_nan),
	.snan()
);

always_comb
	case(instr.br.cm)
	2'd0:	// integer signed branches
		case(instr.any.opcode)
		OP_DBRA: takb = a!='d0;
		OP_BEQ:	takb = a==b;
		OP_BNE:	takb = a!=b;
		OP_BLT:	takb = $signed(a) < $signed(b);
		OP_BLE:	takb = $signed(a) <= $signed(b);
		OP_BGT:	takb = $signed(a) > $signed(b);
		OP_BGE:	takb = $signed(a) >= $signed(b);
		OP_BBC:	takb = ~a[b[5:0]];
		OP_BBS:	takb = a[b[5:0]];
		OP_BBCI: takb = ~a[instr.br.Rb];
		OP_BBSI: takb = a[instr.br.Rb];
		OP_MCB:
			case(instr.mcb.cnd)
			MCB_EQ:	takb = a==b;
			MCB_NE:	takb = a!=b;
			MCB_LT:	takb = $signed(a) < $signed(b);
			MCB_LE:	takb = $signed(a) <= $signed(b);
			MCB_GT:	takb = $signed(a) > $signed(b);
			MCB_GE:	takb = $signed(a) >= $signed(b);
			MCB_BC:	takb = ~a[b[5:0]];
			MCB_BS:	takb = a[b[5:0]];
			endcase
		default:	takb = 1'b0;
		endcase	
	2'd1:	// integer usigned branches
		case(instr.any.opcode)
		OP_BEQ:	takb = a==b;
		OP_BNE:	takb = a!=b;
		OP_BLT:	takb = a < b;
		OP_BLE:	takb = a <= b;
		OP_BGT:	takb = a > b;
		OP_BGE:	takb = a >= b;
		OP_BBC:	takb = ~a[b[5:0]];
		OP_BBS:	takb = a[b[5:0]];
		OP_BBCI: takb = ~a[instr.br.Rb];
		OP_BBSI: takb = a[instr.br.Rb];
		OP_MCB:
			case(instr.mcb.cnd)
			MCB_EQ:	takb = a==b;
			MCB_NE:	takb = a!=b;
			MCB_LT:	takb = a < b;
			MCB_LE:	takb = a <= b;
			MCB_GT:	takb = a > b;
			MCB_GE:	takb = a >= b;
			MCB_BC:	takb = ~a[b[5:0]];
			MCB_BS:	takb = a[b[5:0]];
			endcase
		default:	takb = 1'b0;
		endcase	
	2'd2:
		case(instr.any.opcode)
		OP_BEQ:	takb = fcmpo[0];
		OP_BNE:	takb = ~fcmpo[0];
		OP_BLT:	takb = fcmpo[1];
		OP_BLE:	takb = fcmpo[2];
		OP_BGT: takb = ~fcmpo[2];
		OP_BGE: takb = ~fcmpo[1];
		OP_MCB:
			case(instr.mcb.cnd)
			MCB_EQ:	takb = fcmpo[0];
			MCB_NE:	takb = ~fcmpo[0];
			MCB_LT:	takb = fcmpo[1];
			MCB_LE:	takb = fcmpo[2];
			MCB_GT:	takb = ~fcmpo[2];
			MCB_GE:	takb = ~fcmpo[1];
			MCB_BC:	takb = fcmp_nan;
			MCB_BS:	takb = ~fcmp_nan;
			endcase
		default:	takb = 1'b0;
		endcase	
	default:	takb = 1'b0;
	endcase

endmodule
