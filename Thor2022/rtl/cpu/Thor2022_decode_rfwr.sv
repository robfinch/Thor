// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_decode_rfwr.sv
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

module Thor2022_decode_rfwr(ir, rfwr);
input Instruction ir;
output reg rfwr;

always_comb
begin
rfwr = 1'b0;

// Detecting register file update
casez(ir.any.opcode)
R1,F1,DF1,P1:
	case(ir.r1.func)
	default:	rfwr = 1'b1;
	endcase
R2,F2,DF2,P2:
	case(ir.r3.func)
	default:	rfwr = 1'b1;
	endcase
R3,F3,DF3,P3:
	case(ir.r3.func)
	default:	rfwr = 1'b1;
	endcase
VM:
	case(ir.vmr2.func)
	MFVM,MFVL,MTVM,
	VMADD,VMAND,VMCNTPOP,VMFILL,VMFIRST,VMLAST,
	VMOR,VMSLL,VMSRL,VMSUB,VMXOR:
		rfwr = 1'b1;
	default:	rfwr = 1'b0;
	endcase
OSR2:
	case(ir.r3.func)
	POPQ:			rfwr = 1'b1;
	PEEKQ:		rfwr = 1'b1;
	STATQ:		rfwr = 1'b1;
	LDPTG:		rfwr = 1'b1;
	RGNRW:		rfwr = 1'b1;
	TLBRW:		rfwr = 1'b1;
	default:	rfwr = 1'b0;
	endcase
BTFLD:
	case(ir.r3.func)
	BFALIGN,BFFFO,BFEXTU,BFEXT,
	ANDM,BFSET,BFCHG,BFCLR:
		rfwr = 1'b1;
	default:	rfwr = 1'b0;
	endcase
CSR:	rfwr = 1'b1;
MFLK:	rfwr = 1'b1;
ADDI,SUBFI,CMPI,MULI,DIVI,MULUI,LDI:
	rfwr = 1'b1;
ANDI,ORI,XORI:		rfwr = 1'b1;
SEQI,SNEI,SLTI,SLEI,SGTI,SGEI:		rfwr = 1'b1;
ADDIL,SUBFIL,CMPIL,MULIL,DIVIL,MULUIL,LDIL:
	rfwr = 1'b1;
ANDIL,ORIL,XORIL:	rfwr = 1'b1;
SEQIL,SNEIL,SLTIL,SLEIL,SGTIL,SGEIL:		rfwr = 1'b1;
LDSP,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDHS,LDHR,LDOU,LDV:
	rfwr = 1'b1;
LDBS,LDBUS,LDWS,LDWUS,LDTS,LDTUS,LDOS,LDOUS:
	rfwr = 1'b1;
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDHRX,LDOUX,LDVX:
	rfwr = 1'b1;
LDHP,LDHPX,LDHQ,LDHQX:	rfwr = 1'b1;
ADD2R,SUB2R,AND2R,OR2R,XOR2R,CMP2R,SLT2R,SGE2R,SGEU2R,SLTU2R,SEQ2R,SNE2R:
	rfwr = 1'b1;
SLLR2,SRLR2,SRAR2,ROLR2,RORR2:
	rfwr = 1'b1;
SLLI,SRLI,SRAI:
	rfwr = 1'b1;
BSET:
	rfwr = 1'b1;
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	rfwr = ir.jxx.lk!=2'b00;
JMP,DJMP,BRA:
	rfwr = ir.jmp.lk!=2'b00;
MTLK:	rfwr = 1'b1;
default:	rfwr = 1'b0;
endcase
end

endmodule
