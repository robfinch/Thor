// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_decode_Rt.sv
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

module Thor2024_decode_Rt(isn, Rt);
input [63:0] isn;
output [6:0] Rt;

// 00 to 31		GPRs
// 32 to 47		PRs
// 48 to 50		LRs
// 64 to 95		FPRs
// 96 to 127	VRs

always_comb
begin
	Rt = 'd0;
casez(isn[6:0])
OP_PRFILL:	Rt = {3'b010,isn[10:7]};
OP_ADDI,OP_SUBFI,OP_CMPI,
OP_ANDI,OP_ORI,OP_EORI,
OP_MULI,OP_DIVI,OP_MULUI,OP_DIVUI:
	casez(ir[31:29])
	3'b00?:	Rt = {2'b00,isn[11:7]};
	default:	Rt = {2'b11,isn[11:7]};
	endcase
OP_CHK:
	Rt = 'd0;
OP_R2V:
	case(isn[25:22])
	OP_V2BITS:	Rt = {2'b00,isn[11:7]};
	OP_V2BITSPR:	Rt = {3'b010,isn[10:7]};
	OP_VEINS:	Rt = {2'b10,isn[11:7]};
	OP_VEX:	Rt = {2'b00,isn[11:7]};
	OP_VGIDX:	Rt = {2'b10,isn[11:7]};
	OP_VSHLV,OP_VSHLVI: Rt = {2'b10,isn[11:7]};
	OP_VSHRV,OP_VSHRVI: Rt = {2'b10,isn[11:7]};
	default:	Rt = 'd0;
	endcase
OP_R2S:
	case(isn[31:29])
	3'b00?:	Rt = {2'b00,isn[11:7]};
	default:	Rt = {2'b10,isn[11:7]};
	endcase
OP_R1:
	case(isn[31:29])
	3'b00?:	Rt = {2'b00,isn[11:7]};
	default:	Rt = {2'b10,isn[11:7]};
	endcase
OP_R2L,OP_R2P,OP_R2M,OP_R2C,OP_R2S:
	casez(isn[31:29])
	3'b00?:	Rt = {2'b00,isn[11:7]};
	default:	Rt = {2'b11,isn[11:7]};
	endcase
	// Pretty much ignores the Fmt3 field.
OP_R2V:
	case(isn[25:22])
	OP_V2BITS:	Rt = {2'b00,isn[11:7]};
	OP_V2BITSP:	Rt = {3'b010,isn[10:7]};
	OP_BITS2V:	Rt = {2'b11,isn[11:7]};
	OP_VEINS:		Rt = {2'b11,isn[11:7]};
	OP_VEX:			Rt = {2'b00,isn[11:7]};
	OP_VGIDX:		Rt = {2'b11,isn[11:7]};
	OP_VSHLV:		Rt = {2'b11,isn[11:7]};
	OP_VSHRV:		Rt = {2'b11,isn[11:7]};
	OP_VSHLVI:	Rt = {2'b11,isn[11:7]};
	OP_VSHRVI:	Rt = {2'b11,isn[11:7]};
	default:	Rt = 'd0;
	endcase
OP_MOV:
	Rt = {isn[18:17],isn[11:7]};
OP_R3:
	casez(isn[63:61])
	3'b00?:	Rt = {2'b00,isn[11:7]};		// Rn
	default:	Rt = {2'b11,isn[11:7]};	// Vn
	endcase
OP_ASL,OP_LSR,OP_ASR,OP_ROL,OP_ROR:
	casez(isn[31:29])
	3'b00?:	Rt = {2'b00,isn[11:7]};		// Rn
	default:	Rt = {2'b11,isn[11:7]};	// Vn
	endcase
OP_FLT2:
	case(isn[25:22])
	OP_FSCALEB,OP_FMIN,OP_FMAX,OP_FADD,OP_FSUB,OP_FMUL,OP_FDIV,
	OP_FNEXT,OP_FREM:
		Rt = {2'b10,isn[11:7]};					// Fn
	OP_FCMP:	Rt = {2'b00,isn[11:7]};	// Rn
	OP_FSEQ,OP_FSNE,OP_FSLT,OP_FSLE:
		Rt = {2'b010,isn[10:7]};				// PRn
	default:	Rt = 'd0;
	endcase
OP_FLT2I:
	case(isn[55:52])
	OP_FADDI,OP_FSUBI,OP_FMINI,OP_FMAXI,OP_FMULI,OP_FDIVI,
	OP_FREMI:
		Rt = {2'b10,isn[11:7]};					// Fn
	OP_FCMPI:	Rt = {2'b00,isn[11:7]};	// Rn
	OP_FSEQI,OP_FSNEI,OP_FSLTI,OP_FSLEI,OP_FSGTI,OP_FSGEI:
		Rt = {3'b010,isn[10:7]};				// PRn
	default:	Rt = 'd0;
	endcase
OP_BRK:	Rt = 'd0;
OP_BEQ,OP_BNE,OP_BGL,OP_BSR,
OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS,OP_BBCI,OP_BBSI:
	case({isn[7],isn[9:8]})
	3'b101:	Rt = 7'd48;
	3'b110:	Rt = 7'd49;
	3'b111:	Rt = 7'd50;
	default:	Rt = 'd0;
	endcase
OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDOU,
OP_LDH:
	casez(isn[31:30])
	2'b0?:	Rt = {2'b00,isn[11:7]};						// Rn
	default:	Rt = {2'b11,isn[11:7]};					// Vn
	endcase
OP_FLDH,OP_FLDS,OP_FLDD,OP_FLDQ:
	casez(isn[31:30])
	2'b0?: Rt = {2'b10,isn[11:7]};						// Fn
	default: Rt = {2'b11,isn[11:7]};					// Vn
	endcase
OP_LDX:
	case(isn[58:53])
	OP_LDBX,OP_LDBUX,OP_LDWX,OP_LDWUX,OP_LDTX,OP_LDTUX,
	OP_LDOX,OP_LDOUX,OP_LDHX:
		casez(isn[63:62])
		2'b0?: Rt = {2'b00,isn[11:7]};					// Rn
		default:	Rt = {2'b11,isn[11:7]};				// Vn
		endcase
	OP_FLDHX,OP_FLDSX,OP_FLDDX,OP_FLDQX:
		casez(isn[63:62])
		2'b0?: Rt = {2'b10,isn[11:7]};					// Fn
		default:	Rt = {2'b11,isn[11:7]};				// Vn
		endcase
	OP_AMOADD,OP_AMOAND,OP_AMOOR,OP_AMOEOR,OP_AMOMIN,OP_AMOMAX,
	OP_AMOMINU,OP_AMOMAXU,OP_AMOSWAP:
		Rt = {2'b00,isn[11:7]};
	default:	Rt = 'd0;
	endcase
OP_STX,
OP_STB,OP_STW,OP_STT,OP_STO,OP_STH,
OP_FSTH,OP_FSTS,OP_FSTD,OP_FSTQ,
OP_CACHE:
	Rt = 'd0;
OP_JSR:
	case(isn[8:7])
	2'b00:	Rt = 'd0;		// JMP
	2'b01:	Rt = 7'd48;
	2'b10:	Rt = 7'd49;
	2'b11:	Rt = 7'd50;
	endcase
OP_RTx:
	case(isn[10:9])
	2'b00:	Rt = 'd0;		// RTS
	2'b01:	Rt = 'd0;		// RTE
	2'b10:	Rt = 7'd31;	// RTD
	default:	Rt = 'd0;
	endcase
OP_BCMP,OP_BFND:
	Rt = {3'b010,isn[10:7]};
OP_PFI:
	Rt = {2'b00,isn[11:7]};
// Modifiers
OP_REP,OP_ATOM,OP_PRED,OP_REGS,OP_ROUND:
	Rt = 'd0;
OP_PFX0,OP_PFX1,OP_PFX2,OP_NOP:
	Rt = 'd0;
OP_EX:
	Rt = 'd0;
OP_FENCE:
	Rt = 'd0;
default:
	Rt = 'd0;
endcase
end

endmodule
