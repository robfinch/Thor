// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_dcache.sv
//	- data cache
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
// 5638 LUTs / 2506 FFs / 18.5 BRAMs                                                                          
// ============================================================================

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_dcache(rst, clk, dce, snoop_adr, snoop_v, update_adr,
	hit, hit_d1, hite, hito, hite_d1, hito_d1,
	dci, adr_i, ack_i,
	memreq, memr, state, wr_dc2, tlbacr,
	ic_invline, ic_invall, dc_invline, dc_invall,
	read_adr, read_adr_delayed, dc_line, dc_line_mod);
input rst;
input clk;
input dce;
input address_t snoop_adr;
input snoop_v;
input address_t update_adr;		// update address
output reg hit;
output reg hit_d1;
output hite;
output reg hite_d1;
output hito;
output reg hito_d1;
input DCacheLine [1:0] dci;
input address_t adr_i;
input ack_i;
input memory_arg_t memreq;
input memory_arg_t memr;
input [6:0] state;
input wr_dc2;
input [3:0] tlbacr;
input ic_invline;
input ic_invall;
input dc_invline;
input dc_invall;
input address_t read_adr;
input address_t read_adr_delayed;
output reg [1023:0] dc_line;
output reg [1:0] dc_line_mod;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Data Cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
reg [3:0] tlbacrd;
always_ff @(posedge clk)
	tlbacrd <= tlbacr;

reg [2:0] dwait;		// wait state counter for dcache
address_t dadr;
DCacheLine dci1,dci2;
DCacheLine dc_eline, dc_oline;
DCacheLine dc_elin, dc_olin;
reg [1023:0] datil;
reg dcachable;
reg [1:0] dc_erway,prev_dc_erway;
reg [1:0] dc_orway,prev_dc_orway;
reg [1:0] snoop_erway, snoop_orway;
wire [1:0] dc_ewway;
wire [1:0] dc_owway;
reg [pL1DCacheWays-1:0] dcache_ewr, dcache_owr;
wire wr_even, wr_odd;
reg dc_invline,dc_invall;

always_ff @(posedge clk)
if (rst) begin
	dci1 <= 'd0;
	dci2 <= 'd0;
end
else begin
	dci1 <= dci[0];
	dci2 <= dci1;
end

wire [16:0] lfsr_o;

lfsr17 #(.WID(17)) ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

sram_257x1024_1r1w udcme
(
	.rst(rst),
	.clk(clk),
	.wr(wr_even),
	.wadr({dc_ewway,update_adr[13:6]+update_adr[5]}),
	.radr({dc_erway,read_adr_delayed[13:6]+read_adr_delayed[5]}),
	.i(dci2),
	.o(dc_eline)
);

sram_257x1024_1r1w udcmo
(
	.rst(rst),
	.clk(clk),
	.wr(wr_odd),
	.wadr({dc_owway,update_adr[13:6]}),
	.radr({dc_orway,read_adr_delayed[13:6]}),
	.i(dci2),
	.o(dc_oline)
);

always_ff @(posedge clk)
	case(read_adr_delayed[5])
	1'b0:	dc_line = {dc_oline.data,dc_eline.data};
	1'b1:	dc_line = {dc_eline.data,dc_oline.data};
	endcase
always_ff @(posedge clk)
	dc_line_mod = {dc_oline.m,dc_eline.m};

wire cache_tag_t [3:0] ptago;
wire cache_tag_t [3:0] vtago;
wire cache_tag_t [3:0] dc_etag;
wire cache_tag_t [3:0] dc_otag;
wire cache_tag_t [3:0] snoop_etag;
wire cache_tag_t [3:0] snoop_otag;
wire [255:0] dc_evalid [0:3];
wire [255:0] dc_ovalid [0:3];
wire [255:0] snoop_evalid [0:3];
wire [255:0] snoop_ovalid [0:3];
wire hito,hite;
wire snoop_hito, snoop_hite;
reg [7:0] vadr2e, snoop_adr2e;
always_comb
	vadr2e <= read_adr[13:6]+read_adr[5];
always_comb
	snoop_adr2e <= snoop_adr[13:6]+snoop_adr[5];

Thor2023_cache_hit #(
	.LINES(256),
	.WAYS(4)
)
udchite
(
	.clk(clk),
	.adr(read_adr),
	.ndx(vadr2e),
	.tag(dc_etag),
	.valid(dc_evalid),
	.hit(hite),
	.rway(dc_erway),
	.victag(),
	.cv()
);

Thor2023_cache_hit #(
	.LINES(256),
	.WAYS(4)
)
udchito
(
	.clk(clk),
	.adr(read_adr),
	.ndx(read_adr[13:6]),
	.tag(dc_otag),
	.valid(dc_ovalid),
	.hit(hito),
	.rway(dc_orway),
	.victag(),
	.cv()
);

Thor2023_cache_hit #(
	.LINES(256),
	.WAYS(4)
)
udchitse
(
	.clk(clk),
	.adr(snoop_adr),
	.ndx(snoop_adr2e),
	.tag(snoop_etag),
	.valid(snoop_evalid),
	.hit(snoop_hite),
	.rway(snoop_erway),
	.victag(),
	.cv()
);

Thor2023_cache_hit #(
	.LINES(256),
	.WAYS(4)
)
udchitso
(
	.clk(clk),
	.adr(snoop_adr),
	.ndx(snoop_adr[13:6]),
	.tag(snoop_otag),
	.valid(snoop_ovalid),
	.hit(snoop_hito),
	.rway(snoop_orway),
	.victag(),
	.cv()
);

always_ff @(posedge clk)
	hit = (hite & hito) || (adr_i[5] ? (hito && read_adr_delayed[4:0] < 5'd23) : (hite && read_adr_delayed[4:0] < 5'd23));
always_ff @(posedge clk)
	hit_d1 <= hit;
always_ff @(posedge clk)
	hite_d1 <= hite;
always_ff @(posedge clk)
	hito_d1 <= hito;

Thor2023_cache_tag 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uctage
(
	.rst(rst),
	.clk(clk),
	.wr(wr_dc2 && update_adr[5]),
	.adr_i(read_adr_delayed),
	.way(lfsr_o[1:0]),
	.rclk(clk),
	.ndx(read_adr_delayed[13:6]),
	.tag(vtago)
);

Thor2023_cache_tag 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uctago
(
	.rst(rst),
	.clk(clk),
	.wr(wr_dc2 && ~update_adr[5]),
	.adr_i(read_adr_delayed),
	.way(lfsr_o[1:0]),
	.rclk(clk),
	.ndx(read_adr_delayed[13:6]+read_adr_delayed[5]),
	.tag(vtage)
);

Thor2023_cache_tag 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uctagse
(
	.rst(rst),
	.clk(clk),
	.wr(wr_dc2 && update_adr[5]),
	.adr_i(update_adr),
	.way(lfsr_o[1:0]),
	.rclk(clk),
	.ndx(snoop_adr[13:6]),
	.tag(ptago)
);

Thor2023_cache_tag 
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
uctagso
(
	.rst(rst),
	.clk(clk),
	.wr(wr_dc2 && ~update_adr[5]),
	.adr_i(update_adr),
	.way(lfsr_o[1:0]),
	.rclk(clk),
	.ndx(snoop_adr[13:6]+snoop_adr[5]),
	.tag(ptage)
);

Thor2023_cache_valid
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
udcovalid
(
	.rst(rst),
	.clk(clk),
	.invce(state==MEMORY4 && adr_i[5]),
	.adr(adr_i),
	.inv_adr(update_adr),
	.wr(wr_dc2 && update_adr[5]),
	.way(lfsr_o[1:0]),
	.invline(dc_invline),
	.invall(dc_invall),
	.valid(dc_ovalid),
	.snoop_adr(snoop_adr),
	.snoop_way(snoop_orway),
	.snoop_hit(snoop_v & snoop_hito)
);

Thor2023_cache_valid
#(
	.LINES(256),
	.WAYS(4),
	.LOBIT(6)
)
udcevalid
(
	.rst(rst),
	.clk(clk),
	.invce(state==MEMORY4 && ~adr_i[5]),
	.adr(adr_i),
	.inv_adr(update_adr),
	.wr(wr_dc2 && ~update_adr[5]),
	.way(lfsr_o[1:0]),
	.invline(dc_invline),
	.invall(dc_invall),
	.valid(dc_evalid),
	.snoop_adr(snoop_adr),
	.snoop_way(snoop_erway),
	.snoop_hit(snoop_v & snoop_hite)
);

Thor2023_dcache_wr udcwre
(
	.clk(clk),
	.state(state),
	.wr_dc(wr_dc2),
	.ack(ack_i),
	.func(memreq.func),
	.dce(dce),
	.hit(|memr.hit),
	.hit2(memr.dchit),
	.inv(ic_invline|ic_invall|dc_invline|dc_invall),
	.acr(memr.acr),
	.eaeo(~memr.adr[5]),
	.daeo(~update_adr[5]),
	.wr(wr_even)
);

Thor2023_dcache_wr udcwro
(
	.clk(clk),
	.state(state),
	.wr_dc(wr_dc2),
	.ack(ack_i),
	.func(memreq.func),
	.dce(dce),
	.hit(|memr.hit),
	.hit2(memr.dchit),
	.inv(ic_invline|ic_invall|dc_invline|dc_invall),
	.acr(memr.acr),
	.eaeo(memr.adr[5]),
	.daeo(update_adr[5]),
	.wr(wr_odd)
);

Thor2023_dcache_way udcwaye
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.wr_dc(wr_dc2),
	.ack(ack_i),
	.func(memreq.func),
	.dce(dce),
	.hit(dhit),
	.inv(ic_invline|ic_invall|dc_invline|dc_invall),
	.acr(tlbacr),
	.eaeo(~memr.adr[5]),
	.daeo(~adr_i[5]),
	.lfsr(lfsr_o[1:0]),
	.rway(dc_erway),
	.wway(dc_ewway)
);

Thor2023_dcache_way udcwayo
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.wr_dc(wr_dc2),
	.ack(ack_i),
	.func(memreq.func),
	.dce(dce),
	.hit(dhit),
	.inv(ic_invline|ic_invall|dc_invline|dc_invall),
	.acr(tlbacr),
	.eaeo(memr.adr[5]),
	.daeo(adr_i[5]),
	.lfsr(lfsr_o[1:0]),
	.rway(dc_orway),
	.wway(dc_owway)
);

endmodule
