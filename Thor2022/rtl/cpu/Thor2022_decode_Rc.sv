// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_decode_Rc.sv
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

module Thor2022_decode_Rc(ir, sp_sel, Rc);
input Instruction ir;
input [2:0] sp_sel;
output reg [5:0] Rc;

reg frc;

always_comb
begin
frc = 1'b0;
case(ir.any.opcode)
R2:	Rc = ir.r3.Rc;
STBS,STWS,STTS,STOS,
STSP,
STB,STW,STT,STO,STHC,STV,STHP,STPTR:
	Rc = {1'b0,ir.st.Rs};
STBX,STWX,STTX,STOX,STHCX,STVX,STHPX,STPTRX:
	Rc = {1'b0,ir.stx.Rs};
STHS:
	Rc = {1'b0,ir.sts.Rs};
BSET:
	Rc = 6'd42;
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
begin
	frc = 1'b1;
	case(ir.jxx.Rc)
	6'd29:	Rc = 6'd41;
	6'd30:	Rc = 6'd42;
	default:	Rc = {1'b0,ir.jxx.Rc};
	endcase
end
JMP,DJMP:
begin
	frc = 1'b1;
	case(ir.jmp.Rc)
	6'd29:	Rc = 6'd41;
	6'd30:	Rc = 6'd42;
	default:	Rc = {1'b0,ir.jmp.Rc};
	endcase
end
BEQZ,BNEZ:
begin
	frc = 1'b1;
	Rc = 6'd31;
end
RTS:
	Rc = (ir[10:9]==2'd0) ? 6'd0 : {4'b1010,ir[10:9]};
MTLK:			Rc = {1'b0,ir[13:9]};
default:	Rc = {1'b0,ir.r3.Rc};
endcase
if (Rc==6'd31 && !frc)
	case(sp_sel)
	3'd1:	Rc = 6'd44;
	3'd2:	Rc = 6'd45;
	3'd3:	Rc = 6'd46;
	3'd4:	Rc = 6'd47;
	default:	;
	endcase
end

endmodule
