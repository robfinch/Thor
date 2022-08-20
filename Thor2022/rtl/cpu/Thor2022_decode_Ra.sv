// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_decode_Ra.sv
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

import Thor2022_pkg::*;

module Thor2022_decode_Ra(ir, sp_sel, Ra);
input Instruction ir;
input [2:0] sp_sel;
output reg [5:0] Ra;

always_comb
begin
case(ir.any.opcode)
DJMP:	Ra = 6'd40;						// Loop counter implied
LDSP,STSP:	Ra = 6'd31;			// SP reference implied
VM:
	case(ir.vmr2.func)
	MTVL:	Ra = {1'b0,ir.r3.Ra};
	default:	Ra = 'd0;
	endcase
MFLK:			Ra = (ir[15:14]==2'b00) ? 6'd0 : {4'b1010,ir[15:14]};
MOV:			Ra = ir.r3.Ra;
R2:				Ra = ir.r3.Ra;
default:	Ra = {1'b0,ir.r2.Ra};
endcase
if (Ra==6'd31)
	case(sp_sel)
	3'd1:	Ra = 6'd44;
	3'd2:	Ra = 6'd45;
	3'd3:	Ra = 6'd46;
	3'd4:	Ra = 6'd47;
	default:	;
	endcase
end

endmodule
