// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_icache.sv
//	- instruction cache 64kB, 16kB 4 way
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
// 7648 LUTs / 2547 FFs / 15 BRAMs                                                                          
// ============================================================================

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_icache(rst,clk,state,snoop_asid,snoop_adr,snoop_v,
	asid_i, ip,ip_o,ihit,ihite,ihito,ic_line_hi_o,ic_line_lo_o,ic_valid,ic_tage,ic_tago,
	ic_line_i,ic_wway,wr_ic1,wr_ic2,icache_wre,icache_wro);
input rst;
input clk;
input [6:0] state;
input asid_t snoop_asid;
input address_t snoop_adr;
input snoop_v;
input asid_t asid_i;
input code_address_t ip;
output code_address_t ip_o;
output reg ihit;
output reg ihite;
output reg ihito;
output ICacheLine ic_line_hi_o;
output ICacheLine ic_line_lo_o;
output reg ic_valid;
output reg [$bits(address_t)-1:7] ic_tage;
output reg [$bits(address_t)-1:7] ic_tago;
input ICacheLine ic_line_i;
input [1:0] ic_wway;
input wr_ic1;
input wr_ic2;
output reg icache_wre;
output reg icache_wro;

parameter FALSE = 1'b0;

ICacheLine ic_eline, ic_oline;
reg [1:0] ic_rwaye,ic_rwayo,ic_wway;
always_comb icache_wre = wr_ic2 && !ic_line_i.adr[5];
always_comb icache_wro = wr_ic2 &&  ic_line_i.adr[5];
reg ic_invline,ic_invall;
code_address_t ip2,ip3;
cache_tag_t [3:0] victage;
cache_tag_t [3:0] victago;
cache_tag_t [3:0] pictage;
cache_tag_t [3:0] pictago;
wire [1024/4-1:0] icvalide [0:3];
wire [1024/4-1:0] icvalido [0:3];
wire [1:0] snoop_waye, snoop_wayo;

wire ihit2;
reg ihit3;
wire ic_valid2e, ic_valid2o;
reg ic_valide, ic_valido;
reg ic_valid3e, ic_valid3o;
cache_tag_t ic_tag2e, ic_tag2o;
cache_tag_t ic_tag3e, ic_tag3o;

always_ff @(posedge clk)
	ip2 <= ip;
always_ff @(posedge clk)
	ip3 <= ip2;
// line up ihit output with cache line output.
always_ff @(posedge clk)
	ihit3 <= ihit2;
always_comb
	// *** The following causes the hit to tend to oscillate between hit
	//     and miss.
	// If cannot cross cache line can match on either odd or even.
	if (FALSE && ip2[4:0] < 5'd22)
		ihit <= ip2[5] ? ihit2o : ihit2e;
	// Might span lines, need hit on both even and odd lines
	else
		ihit <= ihit2e&ihit2o;
always_comb
	// *** The following causes the hit to tend to oscillate between hit
	//     and miss.
	// If cannot cross cache line can match on either odd or even.
	// If we do not need the even cache line, mark as a hit.
	if (FALSE && ip2[4:0] < 6'd22)
		ihite <= ip2[5] ? 1'b1 : ihit2e;
	// Might span lines, need hit on both even and odd lines
	else
		ihite <= ihit2e;
always_comb
	// *** The following causes the hit to tend to oscillate between hit
	//     and miss.
	// If cannot cross cache line can match on either odd or even.
	// If we do not need the odd cache line, mark as a hit.
	if (FALSE && ip2[4:0] < 5'd22)
		ihito <= ip2[5] ? ihit2o : 1'b1;
	// Might span lines, need hit on both even and odd lines
	else
		ihito <= ihit2o;

always_ff @(posedge clk)
	ic_valid3e <= ic_valid2e;
always_ff @(posedge clk)
	ic_valid3o <= ic_valid2o;
always_ff @(posedge clk)
	ic_valide <= ic_valid2e;
always_ff @(posedge clk)
	ic_valido <= ic_valid2o;
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
	if (FALSE && ip2[4:0] < 5'd22)
		ic_valid <= ip2[5] ? ic_valid2o : ic_valid2e;
	else
		ic_valid <= ic_valid2o & ic_valid2e;

// 256 wide x 1024 deep, 1 cycle read latency.
sram_256x1024_1r1w uicme
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wre),
	.wadr({ic_wway,ic_line_i.adr[13:6]}),//+upd_adr[5]}),
	.radr({ic_rwaye,ip2[13:6]+ip2[5]}),
	.i(ic_line_i.data),
	.o(ic_eline.data)
);

sram_256x1024_1r1w uicmo
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wro),
	.wadr({ic_wway,ic_line_i.adr[13:6]}),
	.radr({ic_rwayo,ip2[13:6]}),
	.i(ic_line_i.data),
	.o(ic_oline.data)
);

always_comb
	case(ip2[5])
	1'b0:	
		begin
			ic_line_hi_o.v = {2{ihit2o}};
			ic_line_hi_o.asid = ic_tag2o[`TAG_ASID];
			ic_line_hi_o.adr = {ip2[$bits(address_t)-1:6],1'b1,5'd0};
			ic_line_hi_o.data = ic_oline.data;
			
			ic_line_lo_o.v = {2{ihit2e}};
			ic_line_lo_o.asid = ic_tag2e[`TAG_ASID];
			ic_line_lo_o.adr = {ip2[$bits(address_t)-1:6],1'b0,5'd0};
			ic_line_lo_o.adr = ip2[13:6]+ip2[5];
			ic_line_lo_o.data = ic_eline.data;
		end
	1'b1:
		begin
			ic_line_hi_o.v = {2{ihit2e}};
			ic_line_hi_o.asid = ic_tag2e[`TAG_ASID];
			ic_line_hi_o.adr = {ip2[$bits(address_t)-1:6]+1'b1,1'b0,5'd0};
			ic_line_hi_o.adr = ip2[13:6]+ip2[5];
			ic_line_hi_o.data = ic_eline.data;

			ic_line_lo_o.v = {2{ihit2o}};
			ic_line_lo_o.asid = ic_tag2o[`TAG_ASID];
			ic_line_lo_o.adr = {ip2[$bits(address_t)-1:6],1'b1,5'd0};
			ic_line_lo_o.data = ic_oline.data;
		end
	endcase

Thor2023_cache_tag 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uictage
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wre),
	.asid_i(ic_line_i.asid),
	.adr_i(ic_line_i.adr),
	.way(ic_wway),
	.rclk(clk),
	.ndx(ip[13:6]+ip[5]),	// virtual index (same bits as physical address)
	.tag(victage)
);

Thor2023_cache_tag 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uictago
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wro),
	.asid_i(ic_line_i.asid),
	.adr_i(ic_line_i.adr),
	.way(ic_wway),
	.rclk(clk),
	.ndx(ip[13:6]),		// virtual index (same bits as physical address)
	.tag(victago)
);

Thor2023_cache_tag 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uictagse
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wre),
	.asid_i(ic_line_i.asid),
	.adr_i(ic_line_i.adr),
	.way(ic_wway),
	.rclk(clk),
	.ndx(snoop_adr[13:6]+snoop_adr[5]),
	.tag(pictage)
);

Thor2023_cache_tag 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uictagso
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wro),
	.asid_i(ic_line_i.asid),
	.adr_i(ic_line_i.adr),
	.way(ic_wway),
	.rclk(clk),
	.ndx(snoop_adr[13:6]),
	.tag(pictago)
);

Thor2023_cache_hit
#(
	.LINES(256),
	.WAYS(4)
)
uichite
(
	.clk(clk),
	.asid(asid_i),
	.adr(ip),
	.ndx(ip[13:6]+ip[5]),
	.tag(victage),
	.valid(icvalide),
	.hit(ihit2e),
	.rway(ic_rwaye),
	.victag(ic_tag2e),
	.cv(ic_valid2e)
);

Thor2023_cache_hit
#(
	.LINES(256),
	.WAYS(4)
)
uichito
(
	.clk(clk),
	.asid(asid_i),
	.adr(ip),
	.ndx(ip[13:6]),
	.tag(victago),
	.valid(icvalido),
	.hit(ihit2o),
	.rway(ic_rwayo),
	.victag(ic_tag2o),
	.cv(ic_valid2o)
);

Thor2023_cache_hit
#(
	.LINES(256),
	.WAYS(4)
)
uichitse
(
	.clk(clk),
	.asid(snoop_asid),
	.adr(snoop_adr),
	.ndx(snoop_adr[13:6]+snoop_adr[5]),
	.hit(snoop_hite),
	.rway(snoop_waye),
	.tag(pictage),
	.valid(icvalide),
	.victag(),
	.cv()
);

Thor2023_cache_hit
#(
	.LINES(256),
	.WAYS(4)
)
uichitso
(
	.clk(clk),
	.asid(snoop_asid),
	.adr(snoop_adr),
	.ndx(snoop_adr[13:6]),
	.hit(snoop_hito),
	.rway(snoop_wayo),
	.tag(pictago),
	.valid(icvalido),
	.victag(),
	.cv()
);

Thor2023_cache_valid 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uicvale
(
	.rst(rst),
	.clk(clk),
	.invce(state==MEMORY4),
	.snoop_adr(snoop_adr),
	.snoop_hit(snoop_hite & snoop_v),
	.snoop_way(snoop_waye),
	.adr(ic_line_i.adr),
	.inv_adr(ic_line_i.adr),
	.wr(icache_wre),
	.way(ic_wway),
	.invline(ic_invline),
	.invall(ic_invall),
	.valid(icvalide)
);

Thor2023_cache_valid 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uicvalo
(
	.rst(rst),
	.clk(clk),
	.invce(state==MEMORY4),
	.snoop_adr(snoop_adr),
	.snoop_hit(snoop_hito & snoop_v),
	.snoop_way(snoop_wayo),
	.adr(ic_line_i.adr),
	.inv_adr(ic_line_i.adr),
	.wr(icache_wro),
	.way(ic_wway),
	.invline(ic_invline),
	.invall(ic_invall),
	.valid(icvalido)
);

endmodule
