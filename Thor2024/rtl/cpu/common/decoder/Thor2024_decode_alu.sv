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

module Thor2024_decode_alu(instr, alu);
input instruction_t instr;
output regspec_t alu;

function fnIsAlu;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_SYS:	fnIsAlu = 1'b0;
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnIsAlu = 1'b1;
		FN_CMP:	fnIsAlu = 1'b1;
		FN_MUL:	fnIsAlu = 1'b1;
		FN_DIV:	fnIsAlu = 1'b1;
		FN_SUB:	fnIsAlu = 1'b1;
		FN_MULU: fnIsAlu = 1'b1;
		FN_DIVU: fnIsAlu = 1'b1;
		FN_AND:	fnIsAlu = 1'b1;
		FN_OR:	fnIsAlu = 1'b1;
		FN_EOR:	fnIsAlu = 1'b1;
		FN_ANDC:	fnIsAlu = 1'b1;
		FN_NAND:	fnIsAlu = 1'b1;
		FN_NOR:	fnIsAlu = 1'b1;
		FN_ENOR:	fnIsAlu = 1'b1;
		FN_ORC:	fnIsAlu = 1'b1;
		FN_SEQ:	fnIsAlu = 1'b1;
		FN_SNE:	fnIsAlu = 1'b1;
		FN_SLT:	fnIsAlu = 1'b1;
		FN_SLE:	fnIsAlu = 1'b1;
		FN_SLTU:	fnIsAlu = 1'b1;
		FN_SLEU:	fnIsAlu = 1'b1;
		default:	fnIsAlu = 1'b0;
		endcase
	OP_ADDI:	fnIsAlu = 1'b1;
	OP_SUBFI:	fnIsAlu = 1'b1;
	OP_CMPI:	fnIsAlu = 1'b1;
	OP_MULI:	fnIsAlu = 1'b1;
	OP_DIVI:	fnIsAlu = 1'b1;
	OP_ANDI:	fnIsAlu = 1'b1;
	OP_ORI:		fnIsAlu = 1'b1;
	OP_EORI:	fnIsAlu = 1'b1;
	OP_SLTI:	fnIsAlu = 1'b1;
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO:
		fnIsAlu = 1'b1;
	OP_LDX:
		fnIsAlu = 1'b1;
	OP_STB,OP_STW,OP_STT,OP_STO:
		fnIsAlu = 1'b1;
	OP_STX:
		fnIsAlu = 1'b1;
	default:	fnIsAlu = 1'b0;
	endcase
end
endfunction

assign alu = fnIsAlu(instr);

endmodule
