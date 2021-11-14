// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2021_tlb.sv
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

import Thor2021_pkg::*;

module Thor2021_TLB(rst_i, clk_i, rdy_o, asid_i, umode_i,xlaten_i,we_i,ladr_i,next_i,iacc_i,dacc_i,iadr_i,padr_o,acr_o,tlben_i,wrtlb_i,tlbadr_i,tlbdat_i,tlbdat_o,tlbmiss_o);
parameter AWID=32;
parameter RSTIP = {64'hFF000007_FFFD0000};
input rst_i;
input clk_i;
output rdy_o;
input [7:0] asid_i;
input umode_i;
input xlaten_i;
input we_i;
input Address ladr_i;
input next_i;
input iacc_i;
input dacc_i;
input Address iadr_i;
output Address padr_o;
output reg [3:0] acr_o;
input tlben_i;
input wrtlb_i;
input [15:0] tlbadr_i;
input [63:0] tlbdat_i;
output reg [63:0] tlbdat_o;
output reg tlbmiss_o;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

Address adr_i;
Address last_ladr, last_iadr;

reg [2:0] state;
parameter ST_RST = 3'd0;
parameter ST_RUN = 3'd1;

wire [AWID-1:0] rstip = RSTIP;
reg [1:0] randway;
TLBEntry tadri0, tadri1, tadri2, tadri3;
reg wr0,wr1,wr2,wr3, wed;
reg hit0,hit1,hit2,hit3;
wire wrtlb1 = (tlbadr_i[15] ? randway==2'd0 : tlbadr_i[11:10]==2'd0) && wrtlb_i;
wire wrtlb2 = (tlbadr_i[15] ? randway==2'd1 : tlbadr_i[11:10]==2'd1) && wrtlb_i;
wire wrtlb3 = (tlbadr_i[15] ? randway==2'd2 : tlbadr_i[11:10]==2'd2) && wrtlb_i;
wire wrtlb4 = tlbadr_i[11:10]==2'd3 && wrtlb_i;
wire [63:0] tlbdato1,tlbdato2,tlbdato3,tlbdato4;
TLBEntry tadr0, tadr1, tadr2, tadr3;
wire clk_g = clk_i;
always @*
case(tlbadr_i[11:10])
2'd0: tlbdat_o <= tlbdato1;
2'd1: tlbdat_o <= tlbdato2;
2'd2: tlbdat_o <= tlbdato3;
2'd3: tlbdat_o <= tlbdato4;
endcase

wire pe_xlat, ne_xlat;
edge_det u5 (
  .rst(rst_i),
  .clk(clk_g),
  .ce(1'b1),
  .i(xlaten_i),
  .pe(pe_xlat),
  .ne(ne_xlat),
  .ee()
);

wire cd_ladr, cd_iadr;
change_det #(.WID($bits(Address))) ucd1 (
	.rst(rst_i),
	.clk(clk_g),
	.ce(1'b1),
	.i(ladr_i),
	.cd(cd_ladr)
);

change_det #(.WID($bits(Address))) ucd2 (
	.rst(rst_i),
	.clk(clk_g),
	.ce(1'b1),
	.i(iadr_i),
	.cd(cd_iadr)
);

reg [5:0] dll, dli;
always_ff @(posedge clk_g)
	if (cd_ladr)
		dll <= 6'd0;
	else
		dll <= {dll[4:0],1'b1};
always_ff @(posedge clk_g)
	if (cd_iadr)
		dli <= 6'd0;
	else
		dli <= {dli[4:0],1'b1};

TLBEntry tlbdat_rst;
reg [63:0] tlbdati;
reg [12:0] count;
reg tlbwr0r, tlbwr1r, tlbwr2r, tlbwr3r;
reg tlbeni;
reg [9:0] tlbadri;

always @(posedge clk_g)
if (rst_i) begin
	randway <= 2'd0;
end
else begin
	if (!wrtlb_i) begin
		randway <= randway + 2'd1;
		if (randway==2'd2)
			randway <= 2'd0;
	end
end

reg [9:0] rcount;
always @(posedge clk_g)
if (rst_i) begin
	state <= 3'b001;
	tlbeni <= 1'b1;		// forces ready low
	tlbwr0r <= 1'b0;
	tlbwr1r <= 1'b0;
	tlbwr2r <= 1'b0;
	tlbwr3r <= 1'b0;
	count <= 13'h0FC0;	// Map only last 256kB
end
else begin
case(state)
3'b001:
	begin
		tlbeni <= 1'b1;
		tlbwr0r <= 1'b0;
		tlbwr1r <= 1'b0;
		tlbwr2r <= 1'b0;
		tlbwr3r <= 1'b0;
		casez(count[12:10])
//		13'b000: begin tlbwr0r <= 1'b1; tlbdat_rst <= {8'h00,8'hEF,14'h0,count[11:10],12'h000,8'h00,count[11:0]};	end // Map 16MB RAM area
//		13'b001: begin tlbwr1r <= 1'b1; tlbdat_rst <= {8'h00,8'hEF,14'h1,count[11:10],12'h000,8'h00,count[11:0]};	end // Map 16MB RAM area
//		13'b010: begin tlbwr2r <= 1'b1; tlbdat_rst <= {8'h00,8'hEF,14'h2,count[11:10],12'h000,8'h00,count[11:0]};	end // Map 16MB RAM area
		13'b011:
			begin
				tlbwr3r <= 1'b1; 
				tlbdat_rst.ASID = 8'h00;
				tlbdat_rst.G = 1'b1;
				tlbdat_rst.D = 1'b1;
				tlbdat_rst.A = 1'b1;
				tlbdat_rst.U = 1'b0;
				tlbdat_rst.C = 1'b1;
				tlbdat_rst.R = 1'b1;
				tlbdat_rst.W = 1'b1;
				tlbdat_rst.X = 1'b1;
				tlbdat_rst.vpn = {20'h3FF};
				tlbdat_rst.ppn = {16'h03FF,count[9:0]};
				rcount <= count[9:0];
			end // Map 16MB ROM/IO area
		13'b1??: begin state <= 3'b010; tlbwr0r <= 1'b0; tlbwr1r <= 1'b0; tlbwr2r <= 1'b0; tlbwr3r <= 1'b0; end
		endcase
		count <= count + 2'd1;
	end
3'b010:	
	begin
		tlbeni  <= 1'b0;
		tlbwr0r <= 1'b0;
		tlbwr1r <= 1'b0;
		tlbwr2r <= 1'b0;
		tlbwr3r <= 1'b0;
	end
endcase
end
assign rdy_o = ~tlbeni;

always_comb
	tlbdati = state[0] ? tlbdat_rst : tlbdat_i;
always_comb
	tlbadri = state[0] ? rcount : tlbadr_i;
always_comb
	adr_i = iacc_i ? iadr_i : ladr_i;

// Dirty / Accessed bit write logic
always @(posedge clk_g)
  wed <= we_i;
always @(posedge clk_g)
begin
  wr0 <= 1'b0;
  wr1 <= 1'b0;
  wr2 <= 1'b0;
  wr3 <= 1'b0;
  if (ne_xlat) begin
    if (hit0) begin
    	tadri0 <= tadr0;
    	tadri0.D <= wed;
    	tadri0.A <= 1'b1;
      wr0 <= 1'b1;
    end
    if (hit1) begin
    	tadri1 <= tadr1;
    	tadri1.D <= wed;
    	tadri1.A <= 1'b1;
      wr1 <= 1'b1;
    end
    if (hit2) begin
    	tadri2 <= tadr2;
    	tadri2.D <= wed;
    	tadri2.A <= 1'b1;
      wr2 <= 1'b1;
    end
    if (hit3) begin
    	tadri3 <= tadr3;
    	tadri3.D <= wed;
    	tadri3.A <= 1'b1;
      wr3 <= 1'b1;
    end
  end
end

TLBRam u1 (
  .clka(clk_g),    // input wire clka
  .ena(tlben_i|tlbeni),      // input wire ena
  .wea(wrtlb1|tlbwr0r),      // input wire [0 : 0] wea
  .addra(tlbadri),  // input wire [9 : 0] addra
  .dina(tlbdati),    // input wire [63 : 0] dina
  .douta(tlbdato1),  // output wire [63 : 0] douta
  .clkb(clk_g),    // input wire clkb
  .enb(xlaten_i),      // input wire enb
  .web(wr0),      // input wire [0 : 0] web
  .addrb(adr_i[21:12]),  // input wire [9 : 0] addrb
  .dinb(tadr0i),    // input wire [63 : 0] dinb
  .doutb(tadr0)  // output wire [63 : 0] doutb
);

TLBRam u2 (
  .clka(clk_g),    // input wire clka
  .ena(tlben_i|tlbeni),      // input wire ena
  .wea(wrtlb2|tlbwr1r),      // input wire [0 : 0] wea
  .addra(tlbadri),  // input wire [9 : 0] addra
  .dina(tlbdati),    // input wire [63 : 0] dina
  .douta(tlbdato2),  // output wire [63 : 0] douta
  .clkb(clk_g),    // input wire clkb
  .enb(xlaten_i),      // input wire enb
  .web(wr1),      // input wire [0 : 0] web
  .addrb(adr_i[21:12]),  // input wire [9 : 0] addrb
  .dinb(tadr1i),    // input wire [63 : 0] dinb
  .doutb(tadr1)  // output wire [63 : 0] doutb
);

TLBRam u3 (
  .clka(clk_g),    // input wire clka
  .ena(tlben_i|tlbeni),      // input wire ena
  .wea(wrtlb3|tlbwr2r),      // input wire [0 : 0] wea
  .addra(tlbadri),  // input wire [9 : 0] addra
  .dina(tlbdati),    // input wire [63 : 0] dina
  .douta(tlbdato3),  // output wire [63 : 0] douta
  .clkb(clk_g),    // input wire clkb
  .enb(xlaten_i),      // input wire enb
  .web(wr2),      // input wire [0 : 0] web
  .addrb(adr_i[21:12]),  // input wire [9 : 0] addrb
  .dinb(tadr2i),    // input wire [63 : 0] dinb
  .doutb(tadr2)  // output wire [63 : 0] doutb
);

TLBRam u4 (
  .clka(clk_g),    // input wire clka
  .ena(tlben_i|tlbeni),      // input wire ena
  .wea(wrtlb4|tlbwr3r),      // input wire [0 : 0] wea
  .addra(tlbadri),  // input wire [9 : 0] addra
  .dina(tlbdati),    // input wire [63 : 0] dina
  .douta(tlbdato4),  // output wire [63 : 0] douta
  .clkb(clk_g),    // input wire clkb
  .enb(xlaten_i),      // input wire enb
  .web(wr3),      // input wire [0 : 0] web
  .addrb(adr_i[21:12]),  // input wire [9 : 0] addrb
  .dinb(tadr3i),    // input wire [63 : 0] dinb
  .doutb(tadr3)  // output wire [63 : 0] doutb
);

always @(posedge clk_g)
if (rst_i) begin
  padr_o[11:0] <= rstip[11:0];
  padr_o[AWID-1:12] <= rstip[AWID-1:12];
  hit0 <= 1'b0;
  hit1 <= 1'b0;
  hit2 <= 1'b0;
  hit3 <= 1'b0;
end
else begin
  if (pe_xlat) begin
    hit0 <= 1'b0;
    hit1 <= 1'b0;
    hit2 <= 1'b0;
    hit3 <= 1'b0;
  end
	if (next_i)
		padr_o <= padr_o + 6'd32;
  else if (iacc_i) begin
  	padr_o[11:0] <= iadr_i[11:0];
//	  if (adr_i[AWID-1:24]=={AWID-24{1'b1}}) begin
//	    tlbmiss_o <= FALSE;
//	    padr_o[31:14] <= adr_i[31:14];
//	    acr_o <= 4'b1111;
//	  end
//	  else
		if (!xlaten_i) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= iadr_i[31:12];
	    acr_o <= 4'h15;
	    hit0 <= 1'b1;
		end
	  else if (tadr0.vpn==iadr_i[31:22] && (tadr0.ASID==asid_i || tadr0.G)) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= tadr0.ppn;
	    acr_o <= {tadr0.C,tadr0.R,tadr0.W,tadr0.X};
	    hit0 <= 1'b1;
	  end
	  else if (tadr1.vpn==iadr_i[31:22] && (tadr1.ASID==asid_i || tadr1.G)) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= tadr1.ppn;
	    acr_o <= {tadr1.C,tadr1.R,tadr1.W,tadr1.X};
	    hit1 <= 1'b1;
	  end
	  else if (tadr2.vpn==iadr_i[31:22] && (tadr2.ASID==asid_i || tadr2.G)) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= tadr2.ppn;
	    acr_o <= {tadr2.C,tadr2.R,tadr2.W,tadr2.X};;
	    hit2 <= 1'b1;
	  end
	  else if (tadr3.vpn==iadr_i[31:22] && (tadr3.ASID==asid_i || tadr3.G)) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= tadr3.ppn;
	    acr_o <= {tadr3.C,tadr3.R,tadr3.W,tadr3.X};
	    hit3 <= 1'b1;
	  end
	  else begin
	  	padr_o[31:0] <= 32'h00000000;
	    tlbmiss_o <= dli[4] & ~cd_iadr;
	  end
  end
  else if (dacc_i) begin
    padr_o[11:0] <= ladr_i[11:0];
//	  if (adr_i[AWID-1:24]=={AWID-24{1'b1}}) begin
//	    tlbmiss_o <= FALSE;
//	    padr_o[31:14] <= ladr_i[31:14];
//	    acr_o <= 4'b1111;
//	  end
//	  else
		if (!xlaten_i) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= ladr_i[31:12];
	    acr_o <= 4'h15;
	    hit0 <= 1'b1;
		end
	  else if (tadr0.vpn==ladr_i[31:22] && (tadr0.ASID==asid_i || tadr0.G)) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= tadr0.ppn;
	    acr_o <= {tadr0.C,tadr0.R,tadr0.W,tadr0.X};
	    hit0 <= 1'b1;
	  end
	  else if (tadr1.vpn==ladr_i[31:22] && (tadr1.ASID==asid_i || tadr1.G)) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= tadr1.ppn;
	    acr_o <= {tadr1.C,tadr1.R,tadr1.W,tadr1.X};
	    hit1 <= 1'b1;
	  end
	  else if (tadr2.vpn==ladr_i[31:22] && (tadr2.ASID==asid_i || tadr2.G)) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= tadr2.ppn;
	    acr_o <= {tadr2.C,tadr2.R,tadr2.W,tadr2.X};;
	    hit2 <= 1'b1;
	  end
	  else if (tadr3.vpn==ladr_i[31:22] && (tadr3.ASID==asid_i || tadr3.G)) begin
	    tlbmiss_o <= FALSE;
	    padr_o[31:12] <= tadr3.ppn;
	    acr_o <= {tadr3.C,tadr3.R,tadr3.W,tadr3.X};
	    hit3 <= 1'b1;
	  end
	  else begin
	  	padr_o <= 32'h0;
	    tlbmiss_o <= dll[4] & ~cd_ladr;
	  end
  end
  else
  	padr_o <= padr_o;
end

endmodule
