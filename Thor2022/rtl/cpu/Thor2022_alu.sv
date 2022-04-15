// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_alu.sv
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

module Thor2022_alu(clk, ir, ip, ilen, xa, xb, xc, imm, pn, ca, lr, asid, ptbr,
	csr_res, ilvl, res, carry_res, cares);
input clk;
input Instruction ir;
input CodeAddress ip;
input [3:0] ilen;
input Value xa;
input Value xb;
input Value xc;
input Value imm;
input Value pn;
input CodeAddress ca;
input CodeAddress lr;
input [9:0] asid;
input [63:0] ptbr;
input Value csr_res;
input [2:0] ilvl;
output Value res;
output Value carry_res;
output CodeAddress cares;

Value res2;

wire [127:0] cmpo, cmpio;
Thor2022_compare ucmp1
(
	.a(xa),
	.b(xb),
	.o(cmpo)
);

Thor2022_compare ucmp2
(
	.a(xa),
	.b(imm),
	.o(cmpio)
);

wire [15:0] hash;
Thor2022_ipt_hash uhash1
(
	.clk(clk),
	.asid(asid),
	.adr(xa),
//	.mask(ptbr[127:96]),
	.mask(32'hFFFFF),
	.hash(hash)
);

wire [7:0] cntlz_out;
cntlz128 uclz(ir.r1.func[0] ? ~xa : xa, cntlz_out);

//wire [255:0] sllrho = {128'd0,xa[127:0]|pn[127:0]} << {xb[4:0],4'h0};
//wire [255:0] srlrho = {pn[127:0]|xa[127:0],128'd0} >> {xb[4:0],4'h0};
//wire [255:0] sraho = {{128{xa[127]}},xa[127:0],128'd0} >> {xb[4:0],4'h0};
reg [$bits(Value)-1:0] zeros = 'd0;
wire [$bits(Value)*2-1:0] sllio = {'d0,xa[$bits(Value)-1:0]|pn[$bits(Value)-1:0]} << imm[6:0];
wire [$bits(Value)*2-1:0] srlio = {pn[$bits(Value)-1:0]|xa[$bits(Value)-1:0],zeros} >> imm[6:0];
wire [$bits(Value)*2-1:0] sraio = {{$bits(Value){xa[$bits(Value)-1]}},xa[$bits(Value)-1:0],zeros} >> imm[6:0];
wire [$bits(Value)*2-1:0] sllro = {'d0,xa[$bits(Value)-1:0]|pn[$bits(Value)-1:0]} << xb[6:0];
wire [$bits(Value)*2-1:0] srlro = {pn[$bits(Value)-1:0]|xa[$bits(Value)-1:0],zeros} >> xb[6:0];
wire [$bits(Value)*2-1:0] sraro = {{$bits(Value){xa[$bits(Value)-1]}},xa[$bits(Value)-1:0],zeros} >> xb[6:0];

Thor2022_bitfield ubf
(
	.ir(ir),
	.a(xa),
	.b(xb),
	.c(xc),
	.o(bf_out)
);

Thor2022_crypto ucrypto
(
	.ir(ir),
	.m(xmaskbit),
	.z(xzbit),
	.a(xa[63:0]),
	.b(xb[63:0]),
	.c(xc[63:0]),
	.t(),
	.o(crypto_res)
);

Value mux_out;
integer n2;
always_comb
  for (n2 = 0; n2 < $bits(Value); n2 = n2 + 1)
    mux_out[n2] = xa[n2] ? xb[n2] : xc[n2];

always_comb
case(ir.any.opcode)
R1:
	case(ir.r1.func)
	CNTLZ:	res2 = {121'd0,cntlz_out};
	CNTLO:	res2 = {121'd0,cntlz_out};
	PTGHASH:	res2 = hash;
	NOT:		res2 = |xa ? 'd0 : 128'd1;
	SEI:		res2 = ilvl;
	default:	res2 = 'd0;
	endcase
R2:
	case(ir.r3.func)
	ADD:	res2 = xa + xb + (xc|pn);
	SUB:	res2 = xa - xb - pn;
	CMP:	res2 = cmpo;
	AND:	res2 = xa & xb & xc;
	OR:		res2 = xa | xb | xc;
	XOR:	res2 = xa ^ xb ^ xc;
	SLL:	res2 = sllio[$bits(Value)-1:0];
	SRL:	res2 = srlio[$bits(Value)*2-1:$bits(Value)];
	SRA:	res2 = sraio[$bits(Value)*2-1:$bits(Value)];
	ROL:	res2 = sllio[$bits(Value)-1:0]|sllro[$bits(Value)*2-1:$bits(Value)];
	ROR:	res2 = srlio[$bits(Value)*2-1:$bits(Value)]|srlro[$bits(Value)-1:0];
	MUX:	res2 = mux_out;
	SLT:	res2 = ($signed(xa) < $signed(xb)) ? xc : 'd0;
	SGE:	res2 = ($signed(xa) >= $signed(xb)) ? xc : 'd0;
	SLTU:	res2 = (xa < xb) ? xc : 'd0;
	SGEU:	res2 = (xa >= xb) ? xc : 'd0;
	SEQ:	res2 = (xa == xb) ? xc : 'd0;
	SNE:	res2 = (xa != xb) ? xc : 'd0;
//	PTENDX:	res2 = pte_found ? pte_en : -128'd1;
	default:
		begin
			res2 = 'd0;
		end
	endcase
VM:
	case(ir.vmr2.func)
	MTVM:			res2 = xa;
	default:	res2 = 'd0;
	endcase
OSR2:
	case(ir.r3.func)
	default:	res2 = 'd0;
	endcase
CSR:		res2 = csr_res;
MFLK:		begin res2 = ca.offs; $display("%d MFLK: %h", $time, ca.offs); end
BTFLD:	res2 = bf_out;
ADD2R:				res2 = xa + xb + pn;
SUB2R:				res2 = xa - xb - pn;
AND2R:				res2 = xa & xb;
OR2R:					res2 = xa | xb | pn;
XOR2R:				res2 = xa ^ xb ^ pn;
SEQ2R:				res2 = xa == xb;
SNE2R:				res2 = xa != xb;
SLT2R:				res2 = $signed(xa) < $signed(xb);
SLTU2R:				res2 = xa < xb;
SGEU2R:				res2 = xa >= xb;
SGE2R:				res2 = $signed(xa) >= $signed(xb);
CMP2R:				res2 = cmpo;
ADDI,ADDIL:		res2 = xa + imm + pn;
SUBFI,SUBFIL:	res2 = imm - xa - pn;
ANDI,ANDIL:		res2 = xa & imm;
ORI,ORIL:			res2 = xa | imm | pn;
XORI,XORIL:		res2 = xa ^ imm ^ pn;
SLLR2:				res2 = sllro[$bits(Value)-1:0];
SRLR2:				res2 = srlro[$bits(Value)*2-1:$bits(Value)];
SRAR2:				res2 = sraro[$bits(Value)*2-1:$bits(Value)];
ROLR2:				res2 = sllro[$bits(Value)-1:0]|sllro[$bits(Value)*2-1:$bits(Value)];
RORR2:				res2 = srlro[$bits(Value)-1:0]|srlro[$bits(Value)*2-1:$bits(Value)];
SLLI:					res2 = sllio[$bits(Value)-1:0];
SRLI:					res2 = srlio[$bits(Value)*2-1:$bits(Value)];
SRAI:					res2 = sraio[$bits(Value)*2-1:$bits(Value)];
//SLLHR2:				res2 = sllrho[127:0];// + xc;
CMPI,CMPIL:		res2 = cmpio;//$signed(xa) < $signed(imm) ? -128'd1 : xa==imm ? 'd0 : 128'd1;
//CMPUI,CMPUIL:	res2 = xa < imm ? -128'd1 : xa==imm ? 'd0 : 128'd1;
SEQI,SEQIL:		res2 = xa == imm;
SNEI,SNEIL:		res2 = xa != imm;
SLTI,SLTIL:		res2 = $signed(xa) < $signed(imm);
SLEI,SLEIL:		res2 = $signed(xa) <= $signed(imm);
SGTI,SGTIL:		res2 = $signed(xa) > $signed(imm);
SGEI,SGEIL:		res2 = $signed(xa) >= $signed(imm);
SLTUI,SLTUIL:	res2 = xa < imm;
SLEUIL:				res2 = xa <= imm;
SGTUIL:				res2 = xa > imm;
SGEUIL:				res2 = xa >= imm;
DJMP:					res2 = xa - 2'd1;
//STSET:				res2 = xc - 2'd1;
//LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOU,LDH,LDHR,LDHS,
//LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDOUX,LDHX:
//							mc_res = memresp.res;
BSET:							
	case(ir[31:29])
	3'd0:	res2 = xa + 4'd1;
	3'd1:	res2 = xa + 4'd2;
	3'd2:	res2 = xa + 4'd4;
	3'd3:	res2 = xa + 4'd8;
	3'd4:	res2 = xa - 4'd1;
	3'd5:	res2 = xa - 4'd2;
	3'd6:	res2 = xa - 4'd4;
	3'd7:	res2 = xa - 4'd8;
	endcase
STMOV:							
	case(ir[43:41])
	3'd0:	res2 = xc + 4'd1;
	3'd1:	res2 = xc + 4'd2;
	3'd2:	res2 = xc + 4'd4;
	3'd3:	res2 = xc + 4'd8;
	3'd4:	res2 = xc - 4'd1;
	3'd5:	res2 = xc - 4'd2;
	3'd6:	res2 = xc - 4'd4;
	3'd7:	res2 = xc - 4'd8;
	endcase
default:			res2 = 64'd0;
endcase

always_comb
	res = res2|crypto_res;

always_comb
case(ir.any.opcode)
MTLK:	cares <= xc;
JMP,DJMP,BRA:	cares <= ip + ilen;
default:	cares <= lr;
endcase

always_comb
case(ir.any.opcode)
R2:
	case(ir.r3.func)
	ADD:			carry_res = res2[$bits(Value)];
	SUB:			carry_res = res2[$bits(Value)];
	SLL:			carry_res = sllio[$bits(Value)*2-1:$bits(Value)];
	SRL:			carry_res = srlio[$bits(Value)-1:0];
	SRA:			carry_res = sraio[$bits(Value)-1:0];
	default:	
		begin
			carry_res = 'd0;
		end
	endcase
// (a&b)|(a&~s)|(b&~s)
ADD2R:	carry_res = res2[$bits(Value)];
SUB2R:	carry_res = res2[$bits(Value)];
SLLR2:	carry_res = sllro[$bits(Value)*2-1:$bits(Value)];
SRLR2:	carry_res = srlro[$bits(Value)-1:0];
SRAR2:	carry_res = sraro[$bits(Value)-1:0];
SLLI:		carry_res = sllio[$bits(Value)*2-1:$bits(Value)];
SRLI:		carry_res = srlio[$bits(Value)-1:0];
SRAI:		carry_res = sraio[$bits(Value)-1:0];
default:	
	begin
		carry_res = 'd0;
	end
endcase

endmodule

