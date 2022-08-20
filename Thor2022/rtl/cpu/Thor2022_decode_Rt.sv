// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_decode_Rt.sv
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

module Thor2022_decode_Rt(ir, sp_sel, Rt);
input Instruction ir;
input [2:0] sp_sel;
output reg [5:0] Rt;

always_comb
begin
case(ir.any.opcode)
JEQZ,JNEZ:
	Rt = 'd0;
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	Rt = (ir.jxx.lk==2'd0) ? 6'd0 : {4'b1010,ir.jxx.lk};
JMP,BRA:	 Rt = (ir.jmp.lk==2'd0) ? 6'd0 : {4'b1010,ir.jmp.lk};
DJMP,BSET:
	Rt = 6'd40;
STSP,
STB,STW,STT,STO,STHC,STHS,STV,STHP,STPTR:
	Rt = 'd0;
STBX,STWX,STTX,STOX,STHCX,STVX,STHPX,STPTRX:
	Rt = 'd0;
EXI8,EXI24,EXI40,EXI56,EXIM:
	Rt = 'd0;
EXI8+1,EXI24+1,EXI40+1,EXI56+1:
	Rt = 'd0;
RTS:
	Rt = 'd0;
VM:
	case(ir.vmr2.func)
	MTLC:	Rt = 6'd40;
	MFVL,VMCNTPOP,VMFIRST,VMLAST:
		Rt = ir[14:9];
	default:	Rt = {3'b100,ir[11:9]};
	endcase
MOV:			Rt = ir.r3.Rt;
MTLK:			Rt = (ir[15:14]==2'b00) ? 6'd0 : {4'b1010,ir[15:14]};
R2:				Rt = ir.r3.Rt;
default:	Rt = {1'b0,ir[13:9]};
endcase
if (Rt==6'd31)
	case(sp_sel)
	3'd1:	Rt = 6'd44;
	3'd2:	Rt = 6'd45;
	3'd3:	Rt = 6'd46;
	3'd4:	Rt = 6'd47;
	default:	;
	endcase
end

endmodule
