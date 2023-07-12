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

module Thor2024_decode_Rt(instr, Rt);
input instruction_t instr;
output regspec_t Rt;

function regspec_t fnRt;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnRt = ir.r2.Rt;
		FN_CMP:	fnRt = ir.r2.Rt;
		FN_MUL:	fnRt = ir.r2.Rt;
		FN_DIV:	fnRt = ir.r2.Rt;
		FN_SUB:	fnRt = ir.r2.Rt;
		FN_MULU: fnRt = ir.r2.Rt;
		FN_DIVU:	fnRt = ir.r2.Rt;
		FN_MULH:	fnRt = ir.r2.Rt;
		FN_MOD:	fnRt = ir.r2.Rt;
		FN_MULUH:	fnRt = ir.r2.Rt;
		FN_MODU:	fnRt = ir.r2.Rt;
		FN_AND:	fnRt = ir.r2.Rt;
		FN_OR:	fnRt = ir.r2.Rt;
		FN_EOR:	fnRt = ir.r2.Rt;
		FN_ANDC:	fnRt = ir.r2.Rt;
		FN_NAND:	fnRt = ir.r2.Rt;
		FN_NOR:	fnRt = ir.r2.Rt;
		FN_ENOR:	fnRt = ir.r2.Rt;
		FN_ORC:	fnRt = ir.r2.Rt;
		FN_SEQ:	fnRt = ir.r2.Rt;
		FN_SNE:	fnRt = ir.r2.Rt;
		FN_SLT:	fnRt = ir.r2.Rt;
		FN_SLE:	fnRt = ir.r2.Rt;
		FN_SLTU:	fnRt = ir.r2.Rt;
		FN_SLEU:	fnRt = ir.r2.Rt;
		default:	fnRt = 'd0;
		endcase
	OP_FLT2:	fnRt = ir.f2.Rt;
	OP_FLT3:	fnRt = ir.f3.Rt;
	OP_BSR:	fnRt = 6'd56 + ir[8:7];
	OP_JSR:	fnRt = 6'd56 + ir[8:7];
	OP_RTD:	fnRt = 6'd62;
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS,OP_BBCI,OP_BBSI:
		fnRt = 6'd56 + ir[7];
	OP_DBRA: fnRt = 6'd55;
	OP_ADDI,OP_SUBFI,OP_CMPI,OP_MULI,OP_DIVI,OP_SLTI,
	OP_MULUI,OP_DIVUI,
	OP_ANDI,OP_ORI,OP_EORI:
		fnRt = ir.ri.Rt;
	OP_SHIFT:
		fnRt = ir.r2.Rt;
	OP_CSR:
		fnRt = ir.csr.Rt;
	OP_MOV:
		fnRt = ir.r2.Rt;
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDA,
	OP_LDX:
		fnRt = ir.ls.Rt;
	default:
		fnRt = 'd0;
	endcase
end
endfunction

assign Rt = fnRt(instr);

endmodule

