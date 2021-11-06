// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2021  Robert Finch, Waterloo
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
//
module bootrom128(rst_i, clk_i, cs_i, cti_i, bok_o, cyc_i, stb_i, ack_o, adr_i, dat_o);
parameter WID=128;
parameter BLEN = 3'b100;
//parameter FNAME = "c:\\cores5\\FT64\\trunk\\software\\boot\\boottc.ve0";
input rst_i;
input clk_i;
input [2:0] cti_i;
output reg bok_o;
input cs_i;
input cyc_i;
input stb_i;
output reg ack_o;
input [17:0] adr_i;
output [WID-1:0] dat_o;
reg [WID-1:0] dat_o = 128'd0;

integer n;

reg [WID-1:0] rommem [0:13311]; // 208k
reg [13:0] radr;

initial begin
`include "d:\\cores2021\\any1\\v3\\software\\boot\\any1_rom.ve0";
//`include "d:\\cores2020\\rtf64\\v2\\software\\examples\\fibonacci.ve0";
end

reg cs;
always_comb
	cs = cs_i && cyc_i && stb_i;
always_comb
	bok_o = cs;

ack_gen #(
	.READ_STAGES(1),
	.WRITE_STAGES(1),
	.REGISTER_OUTPUT(1)
) ag1
(
	.clk_i(clk_i),
	.ce_i(1'b1),
	.i(cs),
	.we_i(1'b0),
	.o(ack_o),
	.rid_i(0),
	.wid_i(0),
	.rid_o(),
	.wid_o()
);

reg [2:0] cnt;
reg [13:0] ctr;
wire pe_cs;
edge_det u1(.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(cs), .pe(pe_cs), .ne(), .ee() );

always @(posedge clk_i)
if (rst_i)
	ctr <= 14'd0;
else begin
	if (pe_cs) begin
		if (cti_i==3'b000)
			ctr <= adr_i[17:4];
		else
	    ctr <= adr_i[17:4] + 2'd1;
  end
	else if (cs && cnt < BLEN && cti_i != 3'b000)
		ctr <= ctr + 2'd1;
end

always @(posedge clk_i)
if (rst_i)
	cnt <= 3'd0;
else begin
	if (pe_cs)
		cnt <= 3'b0;
	else if (cs && cnt < BLEN && cti_i != 3'b000)
		cnt <= cnt + 3'd1;
end

always @(posedge clk_i)
if (rst_i)
	radr <= 14'd0;
else
	radr <= pe_cs ? adr_i[17:4] : ctr;

//assign dat_o = cs ? {smemH[radr],smemG[radr],smemF[radr],smemE[radr],
//				smemD[radr],smemC[radr],smemB[radr],smemA[radr]} : 64'd0;

reg [WID-1:0] dat = 128'd0;
always @(posedge clk_i)
	dat <= rommem[radr];
always @(posedge clk_i)
if (cs)
	dat_o <= dat;
else
	dat_o <= 128'd0;

endmodule
