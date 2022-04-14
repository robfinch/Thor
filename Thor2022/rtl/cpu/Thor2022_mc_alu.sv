// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_mc_alu.sv
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

module Thor2022_mc_alu(rst, clk, clk2x, state, ir, dec, xa, xb, xc, imm, pn, res, carry_res,
	multovf, dvByZr, dvd_done, dfmul_done);
input rst;
input clk;
input clk2x;
input [5:0] state;
input Instruction ir;
input DecodeOut dec;
input Value xa;
input Value xb;
input Value xc;
input Value imm;
input Value pn;
output Value res;
output Value carry_res;
output multovf;
output dvByZr;
output dvd_done;
output dfmul_done;

parameter MUL1 = 6'd5;
parameter MUL9 = 6'd14;

wire [$bits(Value)*2-1:0] mul_prod1;
reg [$bits(Value)*2-1:0] mul_prod;
wire [$bits(Value)*2-1:0] mul_prod2561;
reg [$bits(Value)*2-1:0] mul_prod256='d0;
wire [39:0] mulf_prod;
reg mul_sign;
Value aa, bb;

// 18 stage pipeline
mult128x128 umul1
(
	.clk(clk),
	.ce(1'b1),
	.a(aa),
	.b(bb),
	.o(mul_prod2561)
);
assign multovf = ((dec.mulu|dec.mului) ? mul_prod256[$bits(Value)*2-1:$bits(Value)] != 'd0 : mul_prod256[$bits(Value)*2-1:$bits(Value)] != {$bits(Value){mul_prod256[$bits(Value)-1]}});

// 3 stage pipeline
mult24x16 umulf
(
  .clk(clk),
  .ce(1'b1),
  .a(aa[23:0]),
  .b(bb[15:0]),
  .o(mulf_prod)
);

wire [127:0] qo, ro;
wire dvd_done;
wire dvByZr;

Thor2022_divider #(.WID($bits(Value))) udiv
(
  .rst(rst),
  .clk(clk2x),
  .ld(state==DIV1),
  .abort(1'b0),
  .ss(dec.div),
  .su(dec.divsu),
  .isDivi(dec.divi),
  .a(xa),
  .b(xb),
  .imm(imm),
  .qo(qo),
  .ro(ro),
  .dvByZr(dvByZr),
  .done(dvd_done),
  .idle()
);

wire [$bits(Value)-1:0] dfmulo;
wire dfmul_done;
wire [$bits(Value)-1:0] dfaso;

`ifdef SUPPORT_FLOAT
// takes about 30 clocks (32 to be safe)
DFPAddsub128nr udfa1
(
	.clk(clk),
	.ce(1'b1),
	.rm(xdfrm),
	.op(ir.r3.func==DFSUB),
	.a(xa),
	.b(xb),
	.o(dfaso)
);

DFPMultiply128nr udfmul1
(
	.clk(clk),
	.ce(1'b1),
	.ld(state==DF1),
	.a(xa),
	.b(xb),
	.o(dfmulo),
	.rm(xdfrm),
	.sign_exe(),
	.inf(),
	.overflow(),
	.underflow(),
	.done(dfmul_done)
);
`endif

always_comb
case(ir.any.opcode)
R2:
	case(ir.r3.func)
	MUL:	res = mul_prod256[$bits(Value)-1:0] + xc + pn;
	MULH:	res = mul_prod256[$bits(Value)*2-1:$bits(Value)];
	MULU:	res = mul_prod256[$bits(Value)-1:0] + xc + pn;
	MULUH:	res = mul_prod256[$bits(Value)*2-1:$bits(Value)];
	MULSU:res = mul_prod256[$bits(Value)-1:0] + xc + pn;
	MULF:	res = mul_prod256[$bits(Value)-1:0] + xc + pn;
	DIV:	res = qo;
	DIVU:	res = qo;
	DIVSU:	res = qo;
	default:
		begin
			res = 'd0;
		end
	endcase
DF2:
	case(ir.r3.func)
	DFADD,DFSUB:	res = dfaso;
	default:	res = 'd0;
	endcase
MULI,MULIL:		res = mul_prod256[$bits(Value)-1:0] + pn;
MULUI,MULUIL:	res = mul_prod256[$bits(Value)-1:0] + pn;
MULFI:				res = mul_prod256[$bits(Value)-1:0] + pn;
DIVI,DIVIL:		res = qo;
default:			res = 'd0;
endcase

always_comb
case(ir.any.opcode)
R2:
	case(ir.r3.func)
	MUL:			carry_res = mul_prod[$bits(Value)*2-1:$bits(Value)];
	MULU:			carry_res = mul_prod[$bits(Value)*2-1:$bits(Value)];
	MULSU:		carry_res = mul_prod[$bits(Value)*2-1:$bits(Value)];
	MULF:			carry_res = mul_prod[$bits(Value)*2-1:$bits(Value)];
	default:	
		begin
			carry_res = 'd0;
		end
	endcase
MULI,MULIL:		carry_res = mul_prod[$bits(Value)*2-1:$bits(Value)];
MULUI,MULUIL:	carry_res = mul_prod[$bits(Value)*2-1:$bits(Value)];
MULFI:	carry_res = mul_prod[$bits(Value)*2-1:$bits(Value)];
default:	
	begin
		carry_res = 'd0;
	end
endcase

always_ff @(posedge clk)
begin
case(state)
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Step1: setup operands and capture sign
MUL1:
  begin
    if (dec.mul) mul_sign <= xa[$bits(Value)-1] ^ xb[$bits(Value)-1];
    else if (dec.muli) mul_sign <= xa[$bits(Value)-1] ^ imm[$bits(Value)-1];
    else if (dec.mulsu) mul_sign <= xa[$bits(Value)-1];
    else if (dec.mulsui) mul_sign <= xa[$bits(Value)-1];
    else mul_sign <= 1'b0;  // MULU, MULUI
    if (dec.mul) aa <= fnAbs(xa);
    else if (dec.muli) aa <= fnAbs(xa);
    else if (dec.mulsu) aa <= fnAbs(xa);
    else if (dec.mulsui) aa <= fnAbs(xa);
    else aa <= xa;
    if (dec.mul) bb <= fnAbs(xb);
    else if (dec.muli) bb <= fnAbs(imm);
    else if (dec.mulsu) bb <= xb;
    else if (dec.mulsui) bb <= imm;
    else if (dec.mulu|dec.mulf) bb <= xb;
    else bb <= imm; // MULUI
  end
MUL9:
  begin
//    mul_prod <= (xMulf|xMulfi) ? mulf_prod : mul_sign ? -mul_prod1 : mul_prod1;
    mul_prod256 <= (dec.mulf|dec.mulfi) ? mulf_prod : mul_sign ? -mul_prod2561 : mul_prod2561;
    //upd_rf <= `TRUE;
  end
endcase
end

endmodule
