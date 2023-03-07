// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_icach_ex.sv
//	- instruction cache 32kB, 8kB 4 way
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
// 6463 LUTs / 11244 FFs / 8 BRAMs   16kB cache                                                                       
// 6938 LUTs / 11469 FFs / 15 BRAMs  32kB cache                                                                         
// ============================================================================

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_icache_ex(rst,clk,state,snoop_adr,snoop_v,invall,invline,
	asid_i, ip,ip_o,ihit,ihite,ihito,ic_line_hi_o,ic_line_lo_o,ic_valid,ic_tage,ic_tago,
	ic_line_i,ic_wway,wr_ic1,wr_ic2,icache_wre,icache_wro);
input rst;
input clk;
input [6:0] state;
input address_t snoop_adr;
input snoop_v;
input invall;
input invline;
input asid_t asid_i;
input code_address_t ip;
output code_address_t ip_o;
output reg ihit;
output reg ihite;
output reg ihito;
output ICacheLine ic_line_hi_o;
output ICacheLine ic_line_lo_o;
output reg ic_valid;
output reg [$bits(address_t)-1:6] ic_tage;
output reg [$bits(address_t)-1:6] ic_tago;
input ICacheLine ic_line_i;
input [1:0] ic_wway;
input wr_ic1;
input wr_ic2;
output reg icache_wre;
output reg icache_wro;

parameter FALSE = 1'b0;
parameter WAYS = 4;
parameter LINES = 64;
parameter LOBIT = 7;
parameter HIBIT = 12;
parameter TAGBIT = 13;
integer n;

ICacheLine ic_eline, ic_oline;
reg [1:0] ic_rwaye,ic_rwayo,ic_wway;
always_comb icache_wre = wr_ic2 && !ic_line_i.vadr[6];
always_comb icache_wro = wr_ic2 &&  ic_line_i.vadr[6];
code_address_t ip2,ip3;
cache_tag_t [3:0] victage;
cache_tag_t [3:0] victago;
cache_tag_t [3:0] pictage;
cache_tag_t [3:0] pictago;
reg [LINES-1:0] valide [0:3];
reg [LINES-1:0] valido [0:3];
wire [1:0] snoop_waye, snoop_wayo;
cache_tag_ex_t ptags0e [0:LINES-1];
cache_tag_ex_t ptags1e [0:LINES-1];
cache_tag_ex_t ptags2e [0:LINES-1];
cache_tag_ex_t ptags3e [0:LINES-1];
cache_tag_ex_t ptags0o [0:LINES-1];
cache_tag_ex_t ptags1o [0:LINES-1];
cache_tag_ex_t ptags2o [0:LINES-1];
cache_tag_ex_t ptags3o [0:LINES-1];

wire ihit1e, ihit1o;
reg ihit2e, ihit2o;
wire ihit2;
reg ihit3;
wire valid2e, valid2o;
reg ic_valide, ic_valido;
cache_tag_ex_t ic_tag2e, ic_tag2o;
cache_tag_ex_t ic_tag3e, ic_tag3o;

always_ff @(posedge clk)
	ip2 <= ip;
always_ff @(posedge clk)
	ip3 <= ip2;
// line up ihit output with cache line output.
always_ff @(posedge clk)
	ihit3 <= ihit2;
always_ff @(posedge clk)
	ihit2e <= ihit1e;
always_ff @(posedge clk)
	ihit2o <= ihit1o;
always_comb
	// *** The following causes the hit to tend to oscillate between hit
	//     and miss.
	// If cannot cross cache line can match on either odd or even.
	if (FALSE && ip2[5:0] < 6'd54)
		ihit <= ip2[LOBIT-1] ? ihit2o : ihit2e;
	// Might span lines, need hit on both even and odd lines
	else
		ihit <= ihit2e&ihit2o;
always_comb
	// *** The following causes the hit to tend to oscillate between hit
	//     and miss.
	// If cannot cross cache line can match on either odd or even.
	// If we do not need the even cache line, mark as a hit.
	if (FALSE && ip2[5:0] < 6'd54)
		ihite <= ip2[LOBIT-1] ? 1'b1 : ihit2e;
	// Might span lines, need hit on both even and odd lines
	else
		ihite <= ihit2e;
always_comb
	// *** The following causes the hit to tend to oscillate between hit
	//     and miss.
	// If cannot cross cache line can match on either odd or even.
	// If we do not need the odd cache line, mark as a hit.
	if (FALSE && ip2[5:0] < 6'd54)
		ihito <= ip2[LOBIT-1] ? ihit2o : 1'b1;
	// Might span lines, need hit on both even and odd lines
	else
		ihito <= ihit2o;

always_ff @(posedge clk)
	ic_valide <= valid2e;
always_ff @(posedge clk)
	ic_valido <= valid2o;
assign ip_o = ip3;
always_ff @(posedge clk)
	ic_tag3o <= ic_tag2o;
always_ff @(posedge clk)
	ic_tago <= ic_tag3o;
always_ff @(posedge clk)
	ic_tag3e <= ic_tag2e;
always_ff @(posedge clk)
	ic_tage <= ic_tag3e;

always_ff @(posedge clk)
	// If cannot cross cache line can match on either odd or even.
	if (FALSE && ip2[5:0] < 6'd54)
		ic_valid <= ip2[LOBIT-1] ? valid2o : valid2e;
	else
		ic_valid <= valid2o & valid2e;

// 512 wide x 256 deep, 1 cycle read latency.
sram_512x256_1r1w uicme
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wre),
	.wadr({ic_wway,ic_line_i.vadr[HIBIT:LOBIT]}),
	.radr({ic_rwaye,ip[HIBIT:LOBIT]+ip[LOBIT-1]}),
	.i(ic_line_i.data),
	.o(ic_eline.data)
);

sram_512x256_1r1w uicmo
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wro),
	.wadr({ic_wway,ic_line_i.vadr[HIBIT:LOBIT]}),
	.radr({ic_rwayo,ip[HIBIT:LOBIT]}),
	.i(ic_line_i.data),
	.o(ic_oline.data)
);

always_comb
	case(ip2[LOBIT-1])
	1'b0:	
		begin
			ic_line_hi_o.v = {2{ihit2o}};
			ic_line_hi_o.vadr = {ip2[$bits(address_t)-1:LOBIT],1'b1,6'd0};
			ic_line_hi_o.data = ic_oline.data;
			
			ic_line_lo_o.v = {2{ihit2e}};
			ic_line_lo_o.vadr = {ip2[$bits(address_t)-1:LOBIT],1'b0,6'd0};
			ic_line_lo_o.data = ic_eline.data;
		end
	1'b1:
		begin
			ic_line_hi_o.v = {2{ihit2e}};
			ic_line_hi_o.vadr = {ip2[$bits(address_t)-1:LOBIT]+1'b1,1'b0,6'd0};
			ic_line_hi_o.data = ic_eline.data;

			ic_line_lo_o.v = {2{ihit2o}};
			ic_line_lo_o.vadr = {ip2[$bits(address_t)-1:LOBIT],1'b1,6'd0};
			ic_line_lo_o.data = ic_oline.data;
		end
	endcase

Thor2023_cache_tag_ex 
#(
	.LINES(LINES),
	.WAYS(WAYS),
	.LOBIT(LOBIT)
)
uictage
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wre),
	.vadr_i(ic_line_i.vadr),
	.padr_i(ic_line_i.padr),
	.way(ic_wway),
	.rclk(clk),
	.ndx(ip[TAGBIT-1:LOBIT]+ip[LOBIT-1]),	// virtual index (same bits as physical address)
	.tag(victage),
	.ptags0(ptags0e),
	.ptags1(ptags1e),
	.ptags2(ptags2e),
	.ptags3(ptags3e)
);

Thor2023_cache_tag_ex 
#(
	.LINES(LINES),
	.WAYS(WAYS),
	.LOBIT(LOBIT)
)
uictago
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wro),
	.vadr_i(ic_line_i.vadr),
	.padr_i(ic_line_i.padr),
	.way(ic_wway),
	.rclk(clk),
	.ndx(ip[TAGBIT-1:LOBIT]),		// virtual index (same bits as physical address)
	.tag(victago),
	.ptags0(ptags0o),
	.ptags1(ptags1o),
	.ptags2(ptags2o),
	.ptags3(ptags3o)
);

Thor2023_cache_hit
#(
	.LINES(LINES),
	.WAYS(WAYS)
)
uichite
(
	.clk(clk),
	.adr(ip),
	.ndx(ip[TAGBIT-1:LOBIT]+ip[LOBIT-1]),
	.tag(victage),
	.valid(valide),
	.hit(ihit1e),
	.rway(ic_rwaye),
	.victag(ic_tag2e),
	.cv(valid2e)
);

Thor2023_cache_hit
#(
	.LINES(LINES),
	.WAYS(WAYS)
)
uichito
(
	.clk(clk),
	.adr(ip),
	.ndx(ip[TAGBIT-1:LOBIT]),
	.tag(victago),
	.valid(valido),
	.hit(ihit1o),
	.rway(ic_rwayo),
	.victag(ic_tag2o),
	.cv(valid2o)
);

integer n, m;
integer g, j;

initial begin
for (m = 0; m < WAYS; m = m + 1) begin
  for (n = 0; n < LINES; n = n + 1) begin
    valide[m][n] = 1'b0;
    valido[m][n] = 1'b0;
  end
end
end

wire invce = state==MEMORY4;

always_ff @(posedge clk, posedge rst)
if (rst) begin
	for (g = 0; g < WAYS; g = g + 1) begin
		valide[g] <= 'd0;
		valido[g] <= 'd0;
	end
end
else begin
	if (icache_wre)
		valide[ic_wway][ic_line_i.vadr[HIBIT:LOBIT]] <= 1'b1;
	else if (invce) begin
		for (g = 0; g < WAYS; g = g + 1) begin
			if (invline)
				valide[g][ic_line_i.vadr[HIBIT:LOBIT]] <= 1'b0;
			else if (invall)
				valide[g] <= 'd0;
		end
	end
	if (icache_wro)
		valido[ic_wway][ic_line_i.vadr[HIBIT:LOBIT]] <= 1'b1;
	else if (invce) begin
		for (g = 0; g < WAYS; g = g + 1) begin
			if (invline)
				valido[g][ic_line_i.vadr[HIBIT:LOBIT]] <= 1'b0;
			else if (invall)
				valido[g] <= 'd0;
		end
	end
	for (j = 0; j < LINES; j = j + 1) begin
		if (snoop_v && snoop_adr[$bits(address_t)-1:TAGBIT]==ptags0e[j])
			valide[0][j] <= 1'b0;
		if (snoop_v && snoop_adr[$bits(address_t)-1:TAGBIT]==ptags1e[j])
			valide[1][j] <= 1'b0;
		if (snoop_v && snoop_adr[$bits(address_t)-1:TAGBIT]==ptags2e[j])
			valide[2][j] <= 1'b0;
		if (snoop_v && snoop_adr[$bits(address_t)-1:TAGBIT]==ptags3e[j])
			valide[3][j] <= 1'b0;
	end
	for (j = 0; j < LINES; j = j + 1) begin
		if (snoop_v && snoop_adr[$bits(address_t)-1:TAGBIT]==ptags0o[j])
			valido[0][j] <= 1'b0;
		if (snoop_v && snoop_adr[$bits(address_t)-1:TAGBIT]==ptags1o[j])
			valido[1][j] <= 1'b0;
		if (snoop_v && snoop_adr[$bits(address_t)-1:TAGBIT]==ptags2o[j])
			valido[2][j] <= 1'b0;
		if (snoop_v && snoop_adr[$bits(address_t)-1:TAGBIT]==ptags3o[j])
			valido[3][j] <= 1'b0;
	end
end

endmodule
