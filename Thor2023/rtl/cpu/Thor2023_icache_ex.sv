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
//  5624 LUTs / 11213 FFs / 8 BRAMs   16kB cache
//  6136 LUTs / 11469 FFs / 15 BRAMs  32kB cache
// 10373 LUTs / 21699 FFs / 15 BRAMs  64kB cache
//
//  7720 LUTs / 14511 FFs / 29 BRAMs  32kB cache + victim cache
// ============================================================================

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_icache_ex(rst,clk,invce,snoop_adr,snoop_v,snoop_cid,invall,invline,
	ip,ip_o,ihit_o,ihit,ihite,ihito,ic_line_hi_o,ic_line_lo_o,ic_valid,ic_tage,ic_tago,
	ic_line_i,wway,wr_ic,icache_wre,icache_wro,
	victim_wr,victim_line
	);
parameter CID = 4'd2;
parameter FALSE = 1'b0;
parameter WAYS = 4;
parameter LINES = 128;
parameter LOBIT = 6;
parameter HIBIT = 12;
parameter TAGBIT = 13;
parameter NVICTIM = 0;
localparam LOG_WAYS = $clog2(WAYS)-1;

input rst;
input clk;
input invce;
input address_t snoop_adr;
input snoop_v;
input [3:0] snoop_cid;
input invall;
input invline;
input code_address_t ip;
output code_address_t ip_o;
output reg ihit_o;
output reg ihit;
output reg ihite;
output reg ihito;
output ICacheLine ic_line_hi_o;
output ICacheLine ic_line_lo_o;
output reg ic_valid;
output reg [$bits(address_t)-1:LOBIT] ic_tage;
output reg [$bits(address_t)-1:LOBIT] ic_tago;
input ICacheLine ic_line_i;
input [LOG_WAYS:0] wway;
input wr_ic;
output reg icache_wre;
output reg icache_wro;
output reg victim_wr;
output ICacheLine victim_line;

integer n, m;
integer g, j;

ICacheLine ic_eline, ic_oline;
reg [1:0] ic_rwaye,ic_rwayo,wway;
always_comb icache_wre = wr_ic && !ic_line_i.vtag[LOBIT];
always_comb icache_wro = wr_ic &&  ic_line_i.vtag[LOBIT];
code_address_t ip2;
cache_tag_ex_t [3:0] victage;
cache_tag_ex_t [3:0] victago;
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
reg [2:0] victim_count, vcne, vcno;
ICacheLine [NVICTIM-1:0] victim_cache;
ICacheLine victim_eline, victim_oline;
ICacheLine victim_cache_eline, victim_cache_oline;
reg icache_wre2;
reg vce,vco;

wire ihit1e, ihit1o;
reg ihit2e, ihit2o;
wire ihit2;
wire valid2e, valid2o;
cache_tag_ex_t ic_tag2e, ic_tag2o;
cache_tag_ex_t ic_tag3e, ic_tag3o;

always_ff @(posedge clk)
	ip2 <= ip;
always_comb
	ihit = ihit1e&ihit1o;
always_ff @(posedge clk)
	ihit2e <= ihit1e;
always_ff @(posedge clk)
	ihit2o <= ihit1o;
always_comb
	// *** The following causes the hit to tend to oscillate between hit
	//     and miss.
	// If cannot cross cache line can match on either odd or even.
	if (FALSE && ip2[5:0] < 6'd54)
		ihit_o <= ip2[LOBIT-1] ? ihit2o : ihit2e;
	// Might span lines, need hit on both even and odd lines
	else
		ihit_o <= ihit2e&ihit2o;
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

assign ip_o = ip2;
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

generate begin : gCacheRam
if (NVICTIM > 0) begin
// 512 wide x 256 deep, 1 cycle read latency.
sram_512x256_1rw1r uicme
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wre),
	.wadr({wway,ic_line_i.vadr[HIBIT:LOBIT]}),
	.radr({ic_rwaye,ip[HIBIT:LOBIT]+ip[LOBIT-1]}),
	.i(ic_line_i.data),
	.o(ic_eline.data),
	.wo(victim_eline.data)
);

sram_512x256_1rw1r uicmo
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wro),
	.wadr({wway,ic_line_i.vadr[HIBIT:LOBIT]}),
	.radr({ic_rwayo,ip[HIBIT:LOBIT]}),
	.i(ic_line_i.data),
	.o(ic_oline.data),
	.wo(victim_oline.data)
);
end
else begin
sram_1r1w
#(
	.WID(ICacheLineWidth),
	.DEP(LINES*WAYS)
)
uicme
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wre),
	.wadr({wway,ic_line_i.vtag[HIBIT:LOBIT]}),
	.radr({ic_rwaye,ip[HIBIT:LOBIT]+ip[LOBIT-1]}),
	.i(ic_line_i.data),
	.o(ic_eline.data)
);

sram_1r1w
#(
	.WID(ICacheLineWidth),
	.DEP(LINES*WAYS)
)
uicmo
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wro),
	.wadr({wway,ic_line_i.vtag[HIBIT:LOBIT]}),
	.radr({ic_rwayo,ip[HIBIT:LOBIT]}),
	.i(ic_line_i.data),
	.o(ic_oline.data)
);
end
end
endgenerate

always_ff @(posedge clk)
	icache_wre2 <= icache_wre;

// Address of the victim line is the address of the update line.
// Write the victim cache if updating the cache and the victim line is valid.
always_ff @(posedge clk)
if ((icache_wre|icache_wro) && NVICTIM > 0) begin
	victim_line.vtag <= ic_line_i.vtag;
	victim_line.ptag <= ic_line_i.ptag;
	if (icache_wre) begin
		victim_line.v <= {4{valide[{wway,ic_line_i.vtag[HIBIT:LOBIT]}]}};
		victim_wr <= valide[{wway,ic_line_i.vtag[HIBIT:LOBIT]}];
	end
	else begin
		victim_line.v <= {4{valido[{wway,ic_line_i.vtag[HIBIT:LOBIT]}]}};
		victim_wr <= valido[{wway,ic_line_i.vtag[HIBIT:LOBIT]}];
	end
end
else
	victim_wr <= 'd0;

// Victim data comes from old data in the line that is being updated.
always_ff @(posedge clk)
if (NVICTIM > 0) begin
	if (icache_wre2)
		victim_line.data <= victim_eline.data;
	else
		victim_line.data <= victim_oline.data;
end

// Search the victim cache for the requested cache line.
always_comb
begin
	vcne = NVICTIM;
	vcno = NVICTIM;
	for (n = 0; n < NVICTIM; n = n + 1) begin
		if (victim_cache[n].vadr[$bits(address_t)-1:LOBIT-1]=={ip[$bits(address_t)-1:LOBIT]+ip[LOBIT-1],1'b0} && victim_cache[n].v==4'hF)
			vcne = n;
		if (victim_cache[n].vadr[$bits(address_t)-1:LOBIT-1]=={ip[$bits(address_t)-1:LOBIT],1'b1} && victim_cache[n].v==4'hF)
			vcno = n;
	end
end
always_ff @(posedge clk)
	vce <= vcne < NVICTIM;
always_ff @(posedge clk)
	vco <= vcno < NVICTIM;
always_ff @(posedge clk)
	victim_cache_eline <= victim_cache[vce];
always_ff @(posedge clk)
	victim_cache_oline <= victim_cache[vco];

always_comb
	case(ip2[LOBIT-1])
	1'b0:	
		begin
			if (vco) begin
				ic_line_hi_o = victim_cache_oline;
				ic_line_hi_o.v = 4'hF;
			end
			else begin
				ic_line_hi_o = 'd0;
				ic_line_hi_o.v = {4{ihit2o}};
				ic_line_hi_o.vtag = {ip2[$bits(address_t)-1:LOBIT],1'b1};
				ic_line_hi_o.data = ic_oline.data;
			end
			if (vce) begin
				ic_line_lo_o = victim_cache_eline;
				ic_line_lo_o.v = 4'hF;
			end
			else begin
				ic_line_lo_o = 'd0;
				ic_line_lo_o.v = {4{ihit2e}};
				ic_line_lo_o.vtag = {ip2[$bits(address_t)-1:LOBIT],1'b0};
				ic_line_lo_o.data = ic_eline.data;
			end
		end
	1'b1:
		begin
			if (vce) begin
				ic_line_hi_o.v = 4'hF;
				ic_line_hi_o = victim_cache_eline;
			end
			else begin
				ic_line_hi_o = 'd0;
				ic_line_hi_o.v = {4{ihit2e}};
				ic_line_hi_o.vtag = {ip2[$bits(address_t)-1:LOBIT]+1'b1,1'b0};
				ic_line_hi_o.data = ic_eline.data;
			end
			if (vco) begin
				ic_line_lo_o = victim_cache_oline;
				ic_line_lo_o.v = 4'hF;
			end
			else begin
				ic_line_lo_o = 'd0;
				ic_line_lo_o.v = {4{ihit2o}};
				ic_line_lo_o.vtag = {ip2[$bits(address_t)-1:LOBIT],1'b1};
				ic_line_lo_o.data = ic_oline.data;
			end
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
	.vadr_i({ic_line_i.vtag,{ICacheTagLoBit{1'b0}}}),
	.padr_i({ic_line_i.ptag,{ICacheTagLoBit{1'b0}}}),
	.way(wway),
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
	.vadr_i({ic_line_i.vtag,{ICacheTagLoBit{1'b0}}}),
	.padr_i({ic_line_i.ptag,{ICacheTagLoBit{1'b0}}}),
	.way(wway),
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

initial begin
for (m = 0; m < WAYS; m = m + 1) begin
  for (n = 0; n < LINES; n = n + 1) begin
    valide[m][n] = 1'b0;
    valido[m][n] = 1'b0;
  end
end
end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	victim_count <= 'd0;
	for (g = 0; g < WAYS; g = g + 1) begin
		valide[g] <= 'd0;
		valido[g] <= 'd0;
	end
end
else begin
	if (victim_wr) begin
		victim_count <= victim_count + 2'd1;
		if (victim_count>=NVICTIM-1)
			victim_count <= 3'd0;
		victim_cache[victim_count] <= victim_line;
	end
	if (icache_wre)
		valide[wway][ic_line_i.vtag[HIBIT:LOBIT]] <= 1'b1;
	else if (invce) begin
		for (g = 0; g < WAYS; g = g + 1) begin
			if (invline)
				valide[g][ic_line_i.vtag[HIBIT:LOBIT]] <= 1'b0;
			else if (invall)
				valide[g] <= 'd0;
		end
	end
	if (icache_wro)
		valido[wway][ic_line_i.vtag[HIBIT:LOBIT]] <= 1'b1;
	else if (invce) begin
		for (g = 0; g < WAYS; g = g + 1) begin
			if (invline)
				valido[g][ic_line_i.vtag[HIBIT:LOBIT]] <= 1'b0;
			else if (invall)
				valido[g] <= 'd0;
		end
	end
	// Two different virtual addresses pointing to the same physical address will
	// end up in the same set as long as the cache is smaller than a memory page
	// in size. So, there is no need to compare every physical address, just every
	// address in a set will do.
	if (snoop_v && snoop_cid != CID) begin
		if (snoop_adr[$bits(address_t)-1:TAGBIT]==ptags0e[snoop_adr[HIBIT:LOBIT]])
			valide[0][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(address_t)-1:TAGBIT]==ptags1e[snoop_adr[HIBIT:LOBIT]])
			valide[1][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(address_t)-1:TAGBIT]==ptags2e[snoop_adr[HIBIT:LOBIT]])
			valide[2][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(address_t)-1:TAGBIT]==ptags3e[snoop_adr[HIBIT:LOBIT]])
			valide[3][snoop_adr[HIBIT:LOBIT]] <= 1'b0;

		if (snoop_adr[$bits(address_t)-1:TAGBIT]==ptags0o[snoop_adr[HIBIT:LOBIT]])
			valido[0][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(address_t)-1:TAGBIT]==ptags1o[snoop_adr[HIBIT:LOBIT]])
			valido[1][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(address_t)-1:TAGBIT]==ptags2o[snoop_adr[HIBIT:LOBIT]])
			valido[2][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(address_t)-1:TAGBIT]==ptags3o[snoop_adr[HIBIT:LOBIT]])
			valido[3][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
	// Invalidate victim cache entries matching the snoop address
		for (g = 0; g < NVICTIM; g = g + 1) begin
			if (snoop_adr[$bits(address_t)-1:LOBIT]==victim_cache[g].padr[$bits(address_t)-1:LOBIT])
				victim_cache[g].v <= 4'h0;
		end
	end
end

endmodule
