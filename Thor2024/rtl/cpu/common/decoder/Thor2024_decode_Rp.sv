// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
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

import Thor2024pkg::*;

module Thor2024_decode_Rp(instr, Rp);
input instruction_t instr;
output regspec_t Rp;

function regspec_t fnRp;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnRp = {3'b100,ir[36:34]};
		FN_CMP:	fnRp = {3'b100,ir[36:34]};
		FN_MUL:	fnRp = {3'b100,ir[36:34]};
		FN_DIV:	fnRp = {3'b100,ir[36:34]};
		FN_SUB:	fnRp = {3'b100,ir[36:34]};
		FN_MULU: fnRp = {3'b100,ir[36:34]};
		FN_DIVU:	fnRp = {3'b100,ir[36:34]};
		FN_MULH:	fnRp = {3'b100,ir[36:34]};
		FN_MOD:	fnRp = {3'b100,ir[36:34]};
		FN_MULUH:	fnRp = {3'b100,ir[36:34]};
		FN_MODU:	fnRp = {3'b100,ir[36:34]};
		FN_AND:	fnRp = {3'b100,ir[36:34]};
		FN_OR:	fnRp = {3'b100,ir[36:34]};
		FN_EOR:	fnRp = {3'b100,ir[36:34]};
		FN_ANDC:	fnRp = {3'b100,ir[36:34]};
		FN_NAND:	fnRp = {3'b100,ir[36:34]};
		FN_NOR:	fnRp = {3'b100,ir[36:34]};
		FN_ENOR:	fnRp = {3'b100,ir[36:34]};
		FN_ORC:	fnRp = {3'b100,ir[36:34]};
		FN_SEQ:	fnRp = {3'b100,ir[36:34]};
		FN_SNE:	fnRp = {3'b100,ir[36:34]};
		FN_SLT:	fnRp = {3'b100,ir[36:34]};
		FN_SLE:	fnRp = {3'b100,ir[36:34]};
		FN_SLTU:	fnRp = {3'b100,ir[36:34]};
		FN_SLEU:	fnRp = {3'b100,ir[36:34]};
		default:	fnRp = 6'd46;
		endcase
	OP_JSR:	fnRp = {3'b100,ir[37:35]};
	OP_RTD:	fnRp = {3'b100,ir[37:35]};
	OP_JSR,
	OP_ADDI,OP_SUBFI,OP_CMPI,OP_MULI,OP_DIVI,OP_SLTI,
	OP_MULUI,OP_DIVUI,
	OP_ANDI,OP_ORI,OP_EORI:
		fnRp = {3'b100,ir[37:35]};
	OP_MOV:
		fnRp = {3'b100,ir[36:34]};
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,
	OP_LDX:
		fnRp = {3'b100,ir[37:35]};
	default:
		fnRp = 6'd46;
	endcase
end
endfunction

assign Rp = fnRp(instr);

endmodule

