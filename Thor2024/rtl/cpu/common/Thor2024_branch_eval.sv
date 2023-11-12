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
	case(instr.any.opcode)
	OP_DBRA:	takb = a!='d0;
	OP_BccU:	// integer unsigned branches
		case(instr.br.fn)
		EQ:	takb = a==b;
		NE:	takb = a!=b;
		LT:	takb = a < b;
		LE:	takb = a <= b;
		GT:	takb = a > b;
		GE:	takb = a >= b;
		BC:	takb = ~a[b[5:0]];
		BS:	takb = a[b[5:0]];
		BCI: takb = ~a[instr.br.Rb];
		BSI: takb = a[instr.br.Rb];
		default:	takb = 1'b0;
		endcase	
	OP_Bcc:	// integer signed branches
		case(instr.br.fn)
		EQ:	takb = a==b;
		NE:	takb = a!=b;
		LT:	takb = $signed(a) < $signed(b);
		LE:	takb = $signed(a) <= $signed(b);
		GT:	takb = $signed(a) > $signed(b);
		GE:	takb = $signed(a) >= $signed(b);
		BC:	takb = ~a[b[5:0]];
		BS:	takb = a[b[5:0]];
		BCI: takb = ~a[instr.br.Rb];
		BSI: takb = a[instr.br.Rb];
		default:	takb = 1'b0;
		endcase	
	OP_FBccD:
		case(instr.fbr.fn)
		FEQ:	takb = fcmpo[0];
		FNE:	takb = ~fcmpo[0];
		FLT:	takb = fcmpo[1];
		FLE:	takb = fcmpo[2];
		FGT: takb = ~fcmpo[2];
		FGE: takb = ~fcmpo[1];
		FULT: takb = fcmpo[1] | fcmp_nan;
		FULE: takb = fcmpo[2] | fcmp_nan;
		FUGT: takb = ~fcmpo[2] | fcmp_nan;
		FUGE: takb = ~fcmpo[1] | fcmp_nan;
		FORD: takb = ~fcmp_nan;
		FUN:	takb = fcmp_nan;
		default:	takb = 1'b0;
		endcase	
	default:	takb = 1'b0;
	endcase

endmodule
