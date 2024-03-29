// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_agen.sv
//	- bus interface unit
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

module Thor2023_agen (ir, a, b, c, imm, pc, adr, nxt_adr, cause);
parameter PCREG = 6'd53;
input instruction_t ir;
input double_value_t a;
input double_value_t b;
input double_value_t c;
input double_value_t imm;
input address_t pc;
output address_t adr;
output address_t nxt_adr;
output cause_code_t cause;

reg [4:0] sc;

always_comb
	case(ir.ls.sz)
	PRC8:		sc = 5'd1;
	PRC16:	sc = 5'd2;
	PRC32:	sc = 5'd4;
	PRC64:	sc = 5'd8;
	PRC128:	sc = 5'd16;
	PRCNDX:
		case(ir[11:9])
		PRC8:		sc = 5'd1;
		PRC16:	sc = 5'd2;
		PRC32:	sc = 5'd4;
		PRC64:	sc = 5'd8;
		PRC128:	sc = 5'd16;
		default:	sc = 5'd8;
		endcase
	default:
		case(ir[11:9])
		PRC8:		sc = 5'd1;
		PRC16:	sc = 5'd2;
		PRC32:	sc = 5'd4;
		PRC64:	sc = 5'd8;
		PRC128:	sc = 5'd16;
		default:	sc = 5'd8;
		endcase
	endcase

always_comb
begin
	cause = FLT_NONE;
	case(ir.any.opcode)
	OP_R2:	// JSR Rt,Ra,Rb
		begin
			if (ir.jsr.Ra.num==PCREG)
				adr = a + (b * sc) + 4'd5;
			else
				adr = a + (b * sc);
		end
	OP_JSR:
		if (ir.jsr.Ra.sign) begin
			adr = pc + (a * sc);
			if (a * sc > imm)
				cause = FLT_TBL;
		end
		else
			adr = (a * sc) + imm;
	default:
		if (ir.ls.sz==PRCNDX)
			adr = b + (ir.lsn.Sc ? c * sc : c) + imm;
		else
			adr = b + imm;
	endcase
end

always_comb
	nxt_adr = {adr[$bits(address_t)-1:6] + 2'd1,6'd0};

endmodule
