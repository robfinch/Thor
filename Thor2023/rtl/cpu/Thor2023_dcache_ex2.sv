// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_dcache_ex2.sv
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
// 3595 LUTs / 3106 FFs / 15 BRAMs   
// ============================================================================

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_dcache_ex2(rst, clk, dce, snoop_adr, snoop_v, update_adr,
	hit, hit_d1, hite, hito, hite_d1, hito_d1,
	line_i, line_hi_o, line_lo_o, sel_i, adr_i, ack_i,
	memreq, memr, state, wr_dc2, tlbacr,
	ic_invline, ic_invall, dc_invline, dc_invall,
	read_adr, read_adr_delayed);
input rst;
input clk;
input dce;
input address_t snoop_adr;
input snoop_v;
input address_t update_adr;		// update address
output reg hit;
output reg hit_d1;
output reg hite;
output reg hite_d1;
output reg hito;
output reg hito_d1;
input DCacheLine line_i;
output DCacheLine line_hi_o;
output DCacheLine line_lo_o;
input [15:0] sel_i;
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

parameter WAYS = 4;
parameter LINES = 64;
parameter LOBIT = 7;
parameter HIBIT = 12;
parameter TAGBIT = 13;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Data Cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
typedef logic [$bits(Thor2023Pkg::address_t)-1:TAGBIT] cache_tag_t;
typedef struct packed
{
	logic v;
	logic m;
	cache_tag_t tag;
	logic [511:0] data;
} cache_line_t;

integer k;

reg span;										// data spans cache line
reg [3:0] tlbacrd;
always_ff @(posedge clk)
	tlbacrd <= tlbacr;
cache_line_t cline_in;
reg swap;
reg [LINES-1:0] valide [0:WAYS-1];
reg [LINES-1:0] valido [0:WAYS-1];
reg [WAYS-1:0] evalid, ovalid;
reg [WAYS-1:0] hite1, hito1;
cache_tag_t [WAYS-1:0] eptags;
cache_tag_t [WAYS-1:0] optags;
DCacheLine eline, oline;
cache_line_t [WAYS-1:0] elines, olines;
wire [1:0] dc_ewway;
wire [1:0] dc_owway;
reg [pL1DCacheWays-1:0] dcache_ewr, dcache_owr;
wire wr_even, wr_odd;
reg dc_invline,dc_invall;
reg [HIBIT:LOBIT] vndxe, vndxo, snoop_adr2e;

wire [16:0] lfsr_o;

lfsr17 #(.WID(17)) ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

always_comb
	casez(adr_i[5:0])
	6'd49:	span = sel_i==16'hFFFF;
	6'd50:	span = sel_i==16'hFFFF;
	6'd51:	span = sel_i==16'hFFFF;
	6'd52:	span = sel_i==16'hFFFF;
	6'd53:	span = sel_i >16'h0FFF;
	6'd54:	span = sel_i >16'h0FFF;
	6'd55:	span = sel_i >16'h0FFF;
	6'd56:	span = sel_i >16'h0FFF;
	6'd57:	span = sel_i >16'h00FF;
	6'd58:	span = sel_i >16'h00FF;
	6'd59:	span = sel_i >16'h00FF;
	6'd60:	span = sel_i >16'h00FF;
	6'd61:	span = sel_i >16'h00FF;
	6'd62:	span = sel_i >16'h00FF;
	6'd63:	span = sel_i >16'h00FF;
	default:	span = 1'b0;
	endcase

always_comb
	vndxe <= read_adr[HIBIT:LOBIT]+read_adr[LOBIT-1];
always_comb
	vndxo <= read_adr[HIBIT:LOBIT];
always_comb
begin
	cline_in.v <= 1'b1;
	cline_in.m <= 1'b0;
	cline_in.tag <= line_i.vtag;
	cline_in.data <= line_i.data;
end

/*
(* ram_style="distributed" *)
reg [4*$bits(cache_line_t):0] ecmem [0:LINES-1];
(* ram_style="distributed" *)
reg [4*$bits(cache_tag_t):0] etmem [0:LINES-1];
(* ram_style="distributed" *)
reg [4*$bits(cache_line_t):0] ocmem [0:LINES-1];
(* ram_style="distributed" *)
reg [4*$bits(cache_tag_t):0] otmem [0:LINES-1];

always_ff @(posedge clk)
begin
	if (wr_even && dc_ewway==0)
		ecmem[update_adr[HIBIT:LOBIT]][$bits(cache_line_t)-1:0] <= cline_in;
	if (wr_even && dc_ewway==1)
		ecmem[update_adr[HIBIT:LOBIT]][2*$bits(cache_line_t)-1:$bits(cache_line_t)] <= cline_in;
	if (wr_even && dc_ewway==2)
		ecmem[update_adr[HIBIT:LOBIT]][3*$bits(cache_line_t)-1:2*$bits(cache_line_t)] <= cline_in;
	if (wr_even && dc_ewway==3)
		ecmem[update_adr[HIBIT:LOBIT]][4*$bits(cache_line_t)-1:3*$bits(cache_line_t)] <= cline_in;
end

always_comb
begin
	elines[0] = ecmem[vndxe][$bits(cache_line_t)-1:0];
	elines[1] = ecmem[vndxe][2*$bits(cache_line_t)-1:$bits(cache_line_t)];
	elines[2] = ecmem[vndxe][3*$bits(cache_line_t)-1:2*$bits(cache_line_t)];
	elines[3] = ecmem[vndxe][4*$bits(cache_line_t)-1:3*$bits(cache_line_t)];
end

always_ff @(posedge clk)
begin
	if (wr_even && dc_ewway==0)
		etmem[update_adr[HIBIT:LOBIT]][$bits(cache_tag_t)-1:0] <= line_i.ptag[$bits(address_t)-1:TAGBIT];
	if (wr_even && dc_ewway==1)
		etmem[update_adr[HIBIT:LOBIT]][2*$bits(cache_tag_t)-1:$bits(cache_tag_t)] <= line_i.ptag[$bits(address_t)-1:TAGBIT];
	if (wr_even && dc_ewway==2)
		etmem[update_adr[HIBIT:LOBIT]][3*$bits(cache_tag_t)-1:2*$bits(cache_tag_t)] <= line_i.ptag[$bits(address_t)-1:TAGBIT];
	if (wr_even && dc_ewway==3)
		etmem[update_adr[HIBIT:LOBIT]][4*$bits(cache_tag_t)-1:3*$bits(cache_tag_t)] <= line_i.ptag[$bits(address_t)-1:TAGBIT];
end

always_comb
begin
	eptags[0] = etmem[vndxe][$bits(cache_tag_t)-1:0];
	eptags[1] = etmem[vndxe][2*$bits(cache_tag_t)-1:$bits(cache_tag_t)];
	eptags[2] = etmem[vndxe][3*$bits(cache_tag_t)-1:2*$bits(cache_tag_t)];
	eptags[3] = etmem[vndxe][4*$bits(cache_tag_t)-1:3*$bits(cache_tag_t)];
end
*/
genvar g;
generate begin : gDcacheRAM
for (g = 0; g < WAYS; g = g + 1) begin : gFor
	sram_1r1w 
	#(
		.WID($bits(cache_line_t)),
		.DEP(LINES)
	)
	udcme
	(
		.rst(rst),
		.clk(clk),
		.wr(wr_even && dc_ewway==g),
		.wadr(update_adr[HIBIT:LOBIT]),
		.radr(vndxe),
		.i(cline_in),
		.o(elines[g])
	);

	sram_1r1w 
	#(
		.WID($bits(cache_tag_t)),
		.DEP(LINES)
	)
	udcte
	(
		.rst(rst),
		.clk(clk),
		.wr(wr_even && dc_ewway==g),
		.wadr(update_adr[HIBIT:LOBIT]),
		.radr(snoop_adr[HIBIT:LOBIT]),
		.i(line_i.ptag),
		.o(eptags[g])
	);

	sram_1r1w 
	#(
		.WID($bits(cache_line_t)),
		.DEP(LINES)
	)
	udcmo
	(
		.rst(rst),
		.clk(clk),
		.wr(wr_odd && dc_owway==g),
		.wadr(update_adr[HIBIT:LOBIT]),
		.radr(vndxo),
		.i(cline_in),
		.o(olines[g])
	);
	sram_1r1w 
	#(
		.WID($bits(cache_tag_t)),
		.DEP(LINES)
	)
	udcto
	(
		.rst(rst),
		.clk(clk),
		.wr(wr_odd && dc_owway==g),
		.wadr(update_adr[HIBIT:LOBIT]),
		.radr(snoop_adr[HIBIT:LOBIT]),
		.i(line_i.ptag),
		.o(optags[g])
	);

end
end
endgenerate


always_comb
casez (hite1)
4'b1???:
	begin
		eline.v = evalid[3];
		eline.ptag = eptags[3];
		eline.m = elines[3].m;
		eline.vtag = elines[3].tag;
		eline.data = elines[3].data;
	end
4'b01??:
	begin
		eline.v = evalid[2];
		eline.ptag = eptags[2];
		eline.m = elines[2].m;
		eline.vtag = elines[2].tag;
		eline.data = elines[2].data;
	end
4'b001?:
	begin
		eline.v = evalid[1];
		eline.ptag = eptags[1];
		eline.m = elines[1].m;
		eline.vtag = elines[1].tag;
		eline.data = elines[1].data;
	end
4'b0001:
	begin
		eline.v = evalid[0];
		eline.ptag = eptags[0];
		eline.m = elines[0].m;
		eline.vtag = elines[0].tag;
		eline.data = elines[0].data;
	end
endcase

always_comb
casez (hito1)
4'b1???:
	begin
		oline.v = ovalid[3];
		oline.ptag = optags[3];
		oline.m = olines[3].m;
		oline.vtag = olines[3].tag;
		oline.data = olines[3].data;
	end
4'b01??:
	begin
		oline.v = ovalid[2];
		oline.ptag = optags[2];
		oline.m = olines[2].m;
		oline.vtag = olines[2].tag;
		oline.data = olines[2].data;
	end
4'b001?:
	begin
		oline.v = ovalid[1];
		oline.ptag = optags[1];
		oline.m = olines[1].m;
		oline.vtag = olines[1].tag;
		oline.data = olines[1].data;
	end
4'b0001:
	begin
		oline.v = ovalid[0];
		oline.ptag = optags[0];
		oline.m = olines[0].m;
		oline.vtag = olines[0].tag;
		oline.data = olines[0].data;
	end
endcase

always_ff @(posedge clk)
	swap <= read_adr[LOBIT];

always_comb
	case(swap)
	1'b0:	
		begin
			line_hi_o = oline;
			line_lo_o = eline;
		end
	1'b1:
		begin
			line_hi_o = eline;
			line_lo_o = oline;
		end
	endcase

always_comb
	snoop_adr2e <= snoop_adr[HIBIT:LOBIT]+snoop_adr[LOBIT-1];

integer ks;

always_comb
begin
	for (k = 0; k < WAYS; k = k + 1) begin
	  hite1[k] = elines[k[1:0]].tag==read_adr[$bits(address_t)-1:TAGBIT] && 
	  					 elines[k[1:0]].v==1'b1;
	  hito1[k] = olines[k[1:0]].tag==read_adr[$bits(address_t)-1:TAGBIT] && 
	  					 olines[k[1:0]].v==1'b1;
	end
end


always_ff @(posedge clk)
	hite <= |hite1;
always_ff @(posedge clk)
	hito <= |hito1;
always_ff @(posedge clk)
	hit <= (|hite1 & |hito1);// || (adr_i[LOBIT-1] ? (hito && read_adr_delayed[4:0] < 5'd23) : (hite && read_adr_delayed[4:0] < 5'd23));
always_ff @(posedge clk)
	hit_d1 <= hit;
always_ff @(posedge clk)
	hite_d1 <= hite;
always_ff @(posedge clk)
	hito_d1 <= hito;

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
	.eaeo(~memr.adr[LOBIT]),
	.daeo(~update_adr[LOBIT]),
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
	.eaeo(memr.adr[LOBIT]),
	.daeo(update_adr[LOBIT]),
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
	.eaeo(~memr.adr[LOBIT]),
	.daeo(~adr_i[LOBIT]),
	.lfsr(lfsr_o[1:0]),
	.rway(),
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
	.eaeo(memr.adr[LOBIT]),
	.daeo(adr_i[LOBIT]),
	.lfsr(lfsr_o[1:0]),
	.rway(),
	.wway(dc_owway)
);

integer n, m;
integer k;

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
	for (k = 0; k < WAYS; k = k + 1) begin
		valide[k] <= 'd0;
		valido[k] <= 'd0;
	end
end
else begin
	if (wr_dc2 & ~update_adr[LOBIT])
		valide[dc_ewway][line_i.vtag[HIBIT:LOBIT]] <= 1'b1;
	else if (invce) begin
		for (k = 0; k < WAYS; k = k + 1) begin
			if (dc_invline)
				valide[k][line_i.vtag[HIBIT:LOBIT]] <= 1'b0;
			else if (dc_invall)
				valide[k] <= 'd0;
		end
	end
	if (wr_dc2 & update_adr[LOBIT])
		valido[dc_owway][line_i.vtag[HIBIT:LOBIT]] <= 1'b1;
	else if (invce) begin
		for (k = 0; k < WAYS; k = k + 1) begin
			if (dc_invline)
				valido[k][line_i.vtag[HIBIT:LOBIT]] <= 1'b0;
			else if (dc_invall)
				valido[k] <= 'd0;
		end
	end
	// Two different virtual addresses pointing to the same physical address will
	// end up in the same set as long as the cache is smaller than a memory page
	// in size. So, there is no need to compare every physical address, just every
	// address in a set will do.
	if (snoop_v) begin
		for (k = 0; k < WAYS; k = k + 1) begin
			if (snoop_adr[$bits(address_t)-1:TAGBIT]==eptags[k])
				valide[k][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
			if (snoop_adr[$bits(address_t)-1:TAGBIT]==optags[k])
				valido[k][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		end
	end
	for (k = 0; k < WAYS; k = k + 1) begin
		evalid[k] = valide[k][vndxe];
		ovalid[k] = valido[k][vndxo];
	end
end


endmodule
