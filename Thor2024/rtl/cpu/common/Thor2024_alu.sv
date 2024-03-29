// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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

import const_pkg::*;
import Thor2024pkg::*;

module Thor2024_alu(rst, clk, clk2x, ld, ir, div, a, b, c, i, t, p, csr,
	o, mul_done, div_done, div_dbz);
input rst;
input clk;
input clk2x;
input ld;
input instruction_t ir;
input div;
input value_t a;
input value_t b;
input value_t c;
input value_t t;
input value_t i;
input value_t p;
input value_t csr;
output value_t o;
output reg mul_done;
output div_done;
output div_dbz;

wire cd_args;
reg [3:0] mul_cnt;
double_value_t prod, prod1, prod2;
double_value_t produ, produ1, produ2;
reg [191:0] shl, shr, asr;
value_t div_q, div_r;
value_t cmpo;
value_t bus;
value_t blendo;
always_comb
	shl = {64'd0,a,{64{ir[33]}}} << (ir[32] ? ir[24:19] : b[5:0]);
always_comb
	shr = {{64{ir[33]}},a,64'd0} >> (ir[32] ? ir[24:19] : b[5:0]);
always_comb
	asr = {{64{a[63]}},a,64'd0} >> (ir[32] ? ir[24:19] : b[5:0]);

always_ff @(posedge clk)
begin
	prod2 <= $signed(a) * $signed(b);
	prod1 <= prod2;
	prod <= prod1;
end
always_ff @(posedge clk)
begin
	produ2 <= a * b;
	produ1 <= produ2;
	produ <= produ1;
end

always_ff @(posedge clk)
begin
	mul_cnt <= {mul_cnt[2:0],1'b1};
	if (ld)
		mul_cnt <= 'd0;
	mul_done <= mul_cnt[3];
end

Thor2024_cmp ualu_cmp(a, b, cmpo);

Thor2024_divider udiv0(
	.rst(rst),
	.clk(clk2x),
	.ld(ld),
	.sgn(div),
	.sgnus(1'b0),
	.a(a),
	.b(b),
	.qo(div_q),
	.ro(div_r),
	.dvByZr(div_dbz),
	.done(div_done),
	.idle()
);

Thor2024_blend ublend0
(
	.a(c),
	.c0(a),
	.c1(b),
	.o(blendo)
);

always_comb
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	bus = a + b;
		FN_SUB:	bus = a - b;
		FN_CMP:	bus = cmpo;
		FN_MUL:	bus = prod[63:0];
		FN_MULU:	bus = produ[63:0];
		FN_MULH:	bus = prod[127:64];
		FN_MULUH:	bus = produ[127:64];
		FN_DIV: bus = div_q;
		FN_MOD: bus = div_r;
		FN_DIVU: bus = div_q;
		FN_MODU: bus = div_r;
		FN_AND:	bus = a & b;
		FN_OR:	bus = a | b;
		FN_EOR:	bus = a ^ b;
		FN_ANDC:	bus = a & ~b;
		FN_NAND:	bus = ~(a & b);
		FN_NOR:	bus = ~(a | b);
		FN_ENOR:	bus = ~(a ^ b);
		FN_ORC:	bus = a | ~b;
		FN_SEQ:	bus = a == b;
		FN_SNE:	bus = a != b;
		FN_SLT:	bus = $signed(a) < $signed(b);
		FN_SLE:	bus = $signed(a) <= $signed(b);
		FN_SLTU:	bus = a < b;
		FN_SLEU:	bus = a <= b;
		default:	bus = {2{32'hDEADBEEF}};
		endcase
	OP_CSR:		bus = csr;
	OP_ADDI:	bus = a + b;
	OP_CMPI:	bus = cmpo;
	OP_MULI:	bus = prod[63:0];
	OP_MULUI:	bus = produ[63:0];
	OP_DIVI:	bus = div_q;
	OP_DIVUI:	bus = div_q;
	OP_ANDI:	bus = a & b;
	OP_ORI:		bus = a | b;
	OP_EORI:	bus = a ^ b;
	OP_SLTI:	bus = $signed(a) < $signed(b);
	OP_SHIFT:
		case(ir.shifti.func)
		OP_ASL:	bus = shl[127:64];
		OP_LSR:	bus = shr[127:64];
		OP_ROL:	bus = shl[127:64]|shl[191:128];
		OP_ROR:	bus = shr[127:64]|shr[63:0];
		OP_ASR:	bus = asr[127:64];
		OP_ASLI:	bus = shl[127:64];
		OP_LSRI:	bus = shr[127:64];
		OP_ROLI:	bus = shl[127:64]|shl[191:128];
		OP_RORI:	bus = shr[127:64]|shr[63:0];
		OP_ASRI:	bus = asr[127:64];
		default:	bus = {2{32'hDEADBEEF}};
		endcase
	OP_MOV:		bus = a;
	OP_LDB:		bus = a + b;
	OP_LDBU:	bus = a + b;
	OP_LDW:		bus = a + b;
	OP_LDWU:	bus = a + b;
	OP_LDT:		bus = a + b;
	OP_LDTU:	bus = a + b;
	OP_LDO:		bus = a + b;
	OP_LDA:		bus = a + b;
	OP_STB:		bus = a + b;
	OP_STW:		bus = a + b;
	OP_STT:		bus = a + b;
	OP_STO:		bus = a + b;
	OP_LDX:	bus = a + (b << ir[26:25]) + i;
	OP_STX:	bus = a + (b << ir[26:25]) + i;
	OP_BLEND:	bus = blendo;
	OP_NOP:		bus = 0;
	OP_PFXA:	bus = 0;
	OP_PFXB:	bus = 0;
	OP_PFXC:	bus = 0;
	default:	bus = {2{32'hDEADBEEF}};
	endcase

always_comb
	if (p[0])
		o = bus;
	else
		o = t;

endmodule
