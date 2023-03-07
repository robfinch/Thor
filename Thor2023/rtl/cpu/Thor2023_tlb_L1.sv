// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_tlb_L1.sv
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
// 2110 LUTs / 940 FFs
// ============================================================================

import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_tlb_L1(rst_i, clk_i, clock, al_i, rdy_o, asid_i, sys_mode_i,
	xlaten_i, we_i,stptr_i,
	next_i,adr_i,padr_o,acr_o,tlben_i,wrtlb_i,tlbadr_i,tlbdat_i,tlbdat_o,
	tlbmiss_o, tlbmiss_adr_o,
	phys_adr, tlbmiss,
	m_cyc_o, m_ack_i, m_adr_o, m_dat_o);
parameter ASSOC = 5;	// MAX assoc = 15
parameter RSTIP = 32'hFFFD0000;
input rst_i;
input clk_i;
input clock;
input [1:0] al_i;
output rdy_o;
input [9:0] asid_i;
input sys_mode_i;
input xlaten_i;
input we_i;
input stptr_i;
input next_i;
input address_t adr_i;
output physical_address_t padr_o;
output reg [3:0] acr_o;
input tlben_i;
input wrtlb_i;
input [31:0] tlbadr_i;
input TLBE tlbdat_i;
output TLBE tlbdat_o;
output reg tlbmiss_o;
output address_t tlbmiss_adr_o;
output reg m_cyc_o;
input m_ack_i;
output address_t m_adr_o;
output reg [127:0] m_dat_o;
output reg [47:0] phys_adr;
output reg tlbmiss;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

integer n,n1,n2;
address_t last_ladr, last_iadr;
reg [47:0] prev_phys_adr;

reg [1:0] al;
reg LRU;
typedef enum logic [3:0] {
	ST_RST = 4'd0,
	ST_RUN = 4'd1,
	ST_AGE1 = 4'd2,
	ST_AGE2 = 4'd3,
	ST_AGE3 = 4'd4,
	ST_AGE4 = 4'd5,
	ST_WRITE_PTE = 4'd6
} tlb_state_t;
tlb_state_t state = ST_RST;

code_address_t rstip = RSTIP;
reg [3:0] randway;
TLBE tentryi [0:ASSOC-1];
TLBE tentryo [0:ASSOC-1];
TLBE tentryo2 [0:ASSOC-1];
reg stptr;
reg xlatend;
address_t adrd;

reg [ASSOC-1:0] wr;
reg wed;
reg [3:0] hit;
reg [ASSOC-1:0] wrtlb, next_wrtlb;
genvar g1;
generate begin : gWrtlb
	for (g1 = 0; g1 < ASSOC; g1 = g1 + 1)
		always_comb begin
			next_wrtlb[g1] <= 'd0;
			if (state==ST_RUN) begin
				if (LRU && tlbadr_i[2:0]!=ASSOC-1) begin
					if (g1==ASSOC-2)
						next_wrtlb[g1] <= wrtlb_i;
				end
				else begin
					if (tlbadr_i[2:0]==ASSOC-1) begin
						if (g1==ASSOC-1)
		 					next_wrtlb[g1] <= wrtlb_i;
		 			end
					else if (g1 < ASSOC-1)
		 				next_wrtlb[g1] <= (al==2'b10 ? randway==g1 : tlbadr_i[2:0]==g1) && wrtlb_i;
	 			end
 			end
 		end
end
endgenerate

TLBE tlbdato [0:ASSOC-1];
TLBE dumped_entry;
wire clk_g = clk_i;

// TLB RAM has a 1 cycle lookup latency.
// These signals need to be matched
always_ff @(posedge clk_g)
	xlatend <= xlaten_i;
always_ff @(posedge clk_g)
	adrd <= adr_i;

always_comb
	tlbdat_o <= tlbdato[tlbadr_i[2:0]];

always_ff @(posedge clk_g)
begin
	al <= al_i;
	LRU <= al_i==2'b01;
end

wire [ASSOC-1:0] wrtlbd;
ft_delay #(.WID(ASSOC), .DEP(3)) udlyw (.clk(clk_g), .ce(1'b1), .i(wrtlb), .o(wrtlbd));

integer n3, n4;
always_ff @(posedge clk_g)
begin
	dumped_entry <= 'd0;
	for (n3 = 0; n3 < ASSOC; n3 = n3 + 1)
		if (wrtlbd[n3]) begin
			dumped_entry <= tlbdato[n3];
		end
end

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

// Detect a change in the page number
wire cd_adr;
change_det #(.WID($bits(address_t)-16)) ucd1 (
	.rst(rst_i),
	.clk(clk_g),
	.ce(1'b1),
	.i(adr_i[$bits(address_t)-1:16]),
	.cd(cd_adr)
);

reg [5:0] dl;
always_ff @(posedge clk_g)
	if (cd_adr)
		dl <= 6'd0;
	else
		dl <= {dl[4:0],1'b1};

TLBE tlbdat_rst;
TLBE [ASSOC-1:0] tlbdati;
TLBE tlbdati_r;
reg [9:0] tlbadri_r;
reg [4:0] count;
reg [ASSOC-1:0] tlbwrr;
reg [ASSOC-1:0] tlbwr_r;
reg tlbeni;
reg [9:0] tlbadri;
reg clock_r;

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i) begin
	randway <= 'd0;
end
else begin
	if (!wrtlb_i) begin
		randway <= randway + 2'd1;
		if (randway==ASSOC-2)
			randway <= 'd0;
	end
end

reg [9:0] rcount;
wire pe_clock;
edge_det edclk (.rst(rst_i), .clk(clk_g), .ce(1'b1), .i(clock), .pe(pe_clock), .ne(), .ee());

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i) begin
	state <= ST_RST;
	tlbeni <= 1'b1;		// forces ready low
	tlbwrr <= 'd0;
	count <= 'd0;		// Map only last 256kB
	clock_r <= 1'b0;
	m_cyc_o <= 1'b0;
	m_dat_o <= 'd0;
end
else begin
tlbeni  <= 1'b0;
tlbwrr <= 'd0;
if (pe_clock)
	clock_r <= 1'b1;
case(state)
	
// Setup the last 256kB/32 pages of memory to point to the ROM BIOS.
ST_RST:
	begin
		tlbeni <= 1'b1;
		tlbwrr <= 'd0;
		case(count[4])
//		13'b000: begin tlbwr0r <= 1'b1; tlbdat_rst <= {8'h00,8'hEF,14'h0,count[11:10],12'h000,8'h00,count[11:0]};	end // Map 16MB RAM area
//		13'b001: begin tlbwr1r <= 1'b1; tlbdat_rst <= {8'h00,8'hEF,14'h1,count[11:10],12'h000,8'h00,count[11:0]};	end // Map 16MB RAM area
//		13'b010: begin tlbwr2r <= 1'b1; tlbdat_rst <= {8'h00,8'hEF,14'h2,count[11:10],12'h000,8'h00,count[11:0]};	end // Map 16MB RAM area
		1'b0:
			begin
				tlbwrr[ASSOC-1] <= 1'b1; 
				tlbdat_rst <= 'd0;
				tlbdat_rst.asid <= 'd0;
				//tlbdat_rst.pte.g <= 1'b1;
				tlbdat_rst.pte.m <= 1'b1;
				tlbdat_rst.pte.rwx <= 3'd7;
				//tlbdat_rst.pte.c <= 1'b1;
				// FFFC0000
				// 1111_1111_1111_1100_00 00_0000_0000_0000
				tlbdat_rst.vpn <= 8'hFF;
				tlbdat_rst.pte.ppn <= {14'h3FFF,count[3:0]};
				//tlbdat_rst.ppnx <= 12'h000;
				rcount <= {6'h3F,count[3:0]};
			end // Map 16MB ROM/IO area
		1'b1: begin state <= ST_RUN; tlbwrr[ASSOC-1] <= 1'd1; end
		default:	;
		endcase
		count <= count + 2'd1;
	end
ST_RUN:
	begin
		wrtlb <= next_wrtlb;
		if (|next_wrtlb) begin
			;
		end
		else if (dumped_entry.pte.m && |dumped_entry.pte_adr) begin
			wrtlb <= 'd0;
			state <= ST_WRITE_PTE;
		end
		else if (clock_r) begin
			wrtlb <= 'd0;
			rcount <= rcount + 2'd1;
			clock_r <= 1'b0;
			state <= ST_AGE1;
		end
	end
ST_AGE1:
	begin
		tlbeni <= 1'b1;
		state <= ST_AGE2;
	end
ST_AGE2:
	begin
		tlbeni <= 1'b1;
		state <= ST_AGE3;
	end
ST_AGE3:
	begin
		tlbeni <= 1'b1;
		state <= ST_AGE4;
	end
ST_AGE4:
	begin
		tlbeni <= 1'b1;
		tlbwrr <= {ASSOC{1'b1}};
		state <= ST_RUN;
	end
ST_WRITE_PTE:
	if (|dumped_entry.pte_adr) begin
		m_cyc_o <= 1'b1;
		m_adr_o <= dumped_entry.pte_adr;
		m_dat_o <= dumped_entry;
		m_dat_o[55] <= 1'b0;	// modified bit
		if (m_ack_i) begin
			m_cyc_o <= 1'b0;
			state <= ST_RUN;
		end
	end
	else
		state <= ST_RUN;
default:
	state <= ST_RUN;
endcase
end
assign rdy_o = ~tlbeni;

integer n2;
always_ff @(posedge clk_g)
begin
	case(state)
	ST_RST:	
		begin
			tlbwr_r <= 'd0;
			tlbadri_r <= 'd0;
			tlbdati_r <= 'd0;
			tlbadri <= rcount;
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdati[n2] <= tlbdat_rst;
			end
		end
	ST_RUN:
		begin
			tlbadri <= tlbadr_i[15:5];
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdati[n2] <= tlbdat_i;
			end
			tlbwr_r <= next_wrtlb;
			tlbadri_r <= tlbadr_i[14:5];
			tlbdati_r <= tlbdat_i;
		end
	ST_AGE1,ST_AGE2,ST_AGE3:
		begin
			tlbadri <= rcount;
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdati[n2] <= tlbdat_i;
			end
		end
	ST_AGE4:
		begin
			tlbadri <= rcount;
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdati[n2] <= tlbdato[n2];
			end
		end
	default:
		begin
			tlbadri <= tlbadr_i[14:5];
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdati[n2] <= tlbdat_i;
			end
		end
	endcase
	if (tlbdati[4].pte.ppn=='d0 && tlbdati[4].vpn != 'd0) begin
		$display("PPN zero");
	end
end

// Dirty / Accessed bit write logic
always_ff @(posedge clk_g)
  wed <= we_i;
always_ff @(posedge clk_g)
	stptr <= stptr_i;

integer n1,j1;
always_ff @(posedge clk_g)
begin
	wr <= 'd0;
  if (ne_xlat) begin
  	for (n1 = 0; n1 < ASSOC; n1 = n1 + 1) begin
  		if (hit==n1) begin
  			if (LRU && n1 < ASSOC-1) begin
	  			wr <= {ASSOC{1'b1}};
  				for (j1 = 1; j1 < ASSOC; j1 = j1 + 1) begin
  					if (j1 <= n1)
  						tentryi[j1] <= tentryo2[j1-1];
  					else
  						tentryi[j1] <= tentryo2[j1];
  				end
	  			tentryi[0] <= tentryo2[n1];
	  			if (wed) begin
	  				tentryi[0].pte.m <= 1'b1;
	  			end
	  			//tentryi[0].a <= 1'b1;
//					if (stptr)
//						tentryo[0].cards[(tentryo[n1].vpn >> ({tentryo[n1].lvl-2'd1,3'd0} + 2'd3)) & 5'h1F] <= 1'b1;
  			end
  			else begin
	  			tentryi[n1] <= tentryo2[n1];
	  			if (wed) begin
	  				tentryi[n1].pte.m <= 1'b1;
	  			end
	  			//tentryi[n1].a <= 1'b1;
//					if (stptr)
//						tentryo[n1].cards[(tentryo[n1].vpn >> ({tentryo[n1].lvl-2'd1,3'd0} + 2'd3)) & 5'h1F] <= 1'b1;
	  			wr[n1] <= 1'b1;
  			end
  		end
  	end
  end
end

genvar g;
generate begin : gTlbRAM
for (g = 0; g < ASSOC; g = g + 1) begin : gLvls
	Thor2023_TLBRam_L1 u1 (
	  .clka(clk_g),    // input wire clka
	  .ena(tlben_i|tlbeni),      // input wire ena
	  .wea(wrtlb[g]|tlbwrr[g]),      // input wire [0 : 0] wea
	  .addra(tlbadri),  // input wire [9 : 0] addra
	  .dina(tlbdati[g]),    // input wire [63 : 0] dina
	  .douta(tlbdato[g]),  // output wire [63 : 0] douta
	  .clkb(clk_g),    // input wire clkb
	  .enb(xlaten_i),      // input wire enb
	  .web(wr[g]),      // input wire [0 : 0] web
	  .addrb(adr_i[21:16]),  // input wire [9 : 0] addrb
	  .dinb(tentryi[g]),    // input wire [63 : 0] dinb
	  .doutb(tentryo[g])  // output wire [63 : 0] doutb
	);
end
end
endgenerate

always_ff @(posedge clk_g)
if (rst_i)
	prev_phys_adr <= 'd0;
else begin
	if (cd_adr)
		prev_phys_adr <= phys_adr;
end

function fnEntryMatch;
input [3:0] nn;
begin
	fnEntryMatch = 
		(tentryo[nn].asid[7:0]==asid_i[7:0] || tentryo[nn].g) &&
		(|tentryo[nn].pte.rwx) &&
		(tentryo[nn].vpn==adrd[31:22])
		;
end
endfunction

always_comb
begin
	phys_adr <= 'd0;
	for (n1 = 0; n1 < ASSOC; n1 = n1 + 1) begin
		if (!cd_adr)
			phys_adr <= prev_phys_adr;
		else if (fnEntryMatch(n1)) begin
	  	phys_adr[15:0] <= adrd[15:0];
			phys_adr[31:16] <= tentryo[n1].pte.ppn[15:0];
			phys_adr[47:32] <= {16{&tentryo[n1].pte.ppn[15:12]}};
		end
	end
end

always_comb
begin
	if (!xlatend)
    tlbmiss <= FALSE;
  else begin
		tlbmiss <= cd_adr;
		for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
			if (fnEntryMatch(n2))
				tlbmiss <= FALSE;
		end
  end
end

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i) begin
	padr_o <= 'd0;
  padr_o[15:0] <= rstip[15:0];
  padr_o[$bits(address_t)-1:16] <= rstip[$bits(address_t)-1:16];
  hit <= 4'd15;
  tlbmiss_o <= FALSE;
	tlbmiss_adr_o <= 'd0;
  acr_o <= 4'hF;
end
else begin
 	padr_o <= padr_o;
 	tlbmiss_o <= FALSE;
  if (pe_xlat) begin
  	hit <= 4'd15;
  end
	if (next_i)
		padr_o <= padr_o + 6'd32;
  else begin
		if (!xlatend) begin
	  	padr_o <= {16'h0000,adr_i[31:0]};
	    acr_o <= 4'hF;
		end
		else begin
			tlbmiss_adr_o <= adr_i;
			hit <= 4'd15;
			acr_o <= 4'h0;
			padr_o <= phys_adr;
			tlbmiss_o <= tlbmiss;
			for (n = 0; n < ASSOC; n = n + 1) begin
				tentryo2[n] <= tentryo[n];
				if (fnEntryMatch(n)) begin
					acr_o <= {tentryo[n].pte.ppn < 18'h01FFF || tentryo[n].pte.ppn > 18'h3FFF0,tentryo[n].pte.rwx};
					hit <= n;
				end				
			end
		end
	end
end

endmodule
