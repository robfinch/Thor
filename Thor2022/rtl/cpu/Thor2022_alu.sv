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


module Thor2022_alu(clk, xa, xb, imm, asid, ptbr);
input clk;
input Value xa;
input Value xb;
input Value imm;

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
	.mask(ptbr[127:96]),
	.hash(hash)
);

wire [7:0] cntlz_out;
cntlz128 uclz(xir.r1.func[0] ? ~xa : xa, cntlz_out);

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
	.clk(clk_g),
	.ce(1'b1),
	.a(aa),
	.b(bb),
	.o(mul_prod2561)
);
wire multovf = ((reb[exec].dec.mulu|reb[exec].dec.mului) ? mul_prod256[$bits(Value)*2-1:$bits(Value)] != 'd0 : mul_prod256[$bits(Value)*2-1:$bits(Value)] != {$bits(Value){mul_prod256[$bits(Value)-1]}});

endmodule

