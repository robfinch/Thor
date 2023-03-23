// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_stlb.sv
//	- shared TLB
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
// 4827 LUTs / 3142 FFs / 15 BRAMs  5 way assoc
// 6250 LUTs / 4312 FFs / 27 BRAMs	1024 entries, 8kB pages, 13 channels
// ============================================================================

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_stlb(rst_i, clk_i, clock, al_i, rdy_o, om_i, sys_mode_i,
	stptr_i, rwx_o, cache_o,
	tlbmiss_o, tlbmiss_adr_o, tlbkey_o,
	wbn_req_i, wbn_resp_o, wb_req_o, wb_resp_i, snoop_v, snoop_adr, snoop_cid);
parameter ASSOC = 7;	// MAX assoc = 15
parameter CHANNELS = 9;
parameter RSTIP = 32'hFFFD0000;
localparam LOG_PAGE_SIZE = $clog2(PAGE_SIZE);
localparam LOG_ENTRIES = $clog2(ENTRIES);

parameter IO_ADDR = 32'hFEF00001;
parameter IO_ADDR2 = 32'hFEEF0001;
parameter IO_ADDR_MASK = 32'h00FF0000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd12;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h00;					// 00 = RAM
parameter CFG_CLASS = 8'h05;						// 05 = memory controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'hFF;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

input rst_i;
input clk_i;
input clock;
input [1:0] al_i;
output rdy_o;
input [1:0] om_i;
input sys_mode_i;
input stptr_i;
output reg [2:0] rwx_o;
output reg [3:0] cache_o;
output reg tlbmiss_o;
output address_t tlbmiss_adr_o;
output reg [31:0] tlbkey_o;
input wb_cmd_request128_t [CHANNELS-1:0] wbn_req_i;
output wb_cmd_response128_t [CHANNELS-1:0] wbn_resp_o;
output wb_cmd_request128_t wb_req_o;
input wb_cmd_response128_t wb_resp_i;
output reg snoop_v;
output wb_address_t snoop_adr;
output reg [3:0] snoop_cid;

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

typedef enum logic [3:0] {
	ST_RST = 4'd0,
	ST_RUN = 4'd1,
	ST_AGE1 = 4'd2,
	ST_AGE2 = 4'd3,
	ST_AGE3 = 4'd4,
	ST_AGE4 = 4'd5,
	ST_WRITE_PTE = 4'd6,
	ST_INVALL1 = 4'd7,
	ST_INVALL2 = 4'd8,
	ST_INVALL3 = 4'd9,
	ST_INVALL4 = 4'd10
} tlb_state_t;
tlb_state_t state = ST_RST;

integer n;
integer n1,j1;
integer n2;
integer n3, n4, n5, n7;

reg [2:0] rgn;
reg [3:0] cache;
REGION region;
reg [2:0] rwx;
reg tlben_i;
reg wrtlb_i;
reg [31:0] tlbadr_i;

reg [2:0] rd_tlb;
reg wr_tlb;
reg wrtlb_i;
TLBE tlbdat_i;
TLBE tlbdat_o;
reg [31:0] ctrl_reg;

address_t last_ladr, last_iadr;
address_t adrd;
reg invall;
reg [LOG_ENTRIES-1:0] inv_count;

tlb_count_t master_count;
wb_cmd_request128_t req,req1,wbs_req;
wb_asid_t asid_i;

reg [1:0] al;
reg LRU;
code_address_t rstip = RSTIP;
reg [3:0] randway;
TLBE tentryi [0:ASSOC-1];
TLBE tentryo [0:ASSOC-1];
TLBE tentryo2 [0:ASSOC-1];
reg stptr;
reg xlaten_i;
reg xlatend;
reg we_i;
address_t adr_i;
reg [LOG_ENTRIES-1:0] adr_i_slice [0:ASSOC-1];
address_t iadrd;
reg next_i;
wb_cmd_request128_t wbm_req;
wb_cmd_response128_t wbm_resp;
TLBE [ASSOC-1:0] tlbdato;
TLBE dumped_entry;
wire clk_g = clk_i;

TLBE tlbdat_rst;
TLBE [ASSOC-1:0] tlbdati;
reg [4:0] count;
reg [ASSOC-1:0] tlbwrr;
reg tlbeni;
wire [LOG_ENTRIES-1:0] tlbadri;
reg clock_r;
reg [LOG_ENTRIES-1:0] rcount;
wire pe_clock;

PTE pte_reg;
reg [95:0] vpn_reg;
reg [31:0] ctrl_req;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

assign wbs_req = wb_req_o;

wire acko;
reg cs_config, cs_stlbq, cs_rgnq;
wire cs_stlb, cs_rgn;
wire [127:0] cfg_out;
reg [127:0] dato;

always_ff @(posedge clk_i)
	cs_config <= wbs_req.cyc && wbs_req.stb &&
		wbs_req.padr[31:28]==4'hD &&
		wbs_req.padr[27:20]==CFG_BUS &&
		wbs_req.padr[19:15]==CFG_DEVICE &&
		wbs_req.padr[14:12]==CFG_FUNC;

always_comb
	cs_stlbq <= cs_stlb && wbs_req.cyc && wbs_req.stb;
always_comb
	cs_rgnq <= cs_rgn && wbs_req.cyc && wbs_req.stb;


ack_gen #(
	.READ_STAGES(1),
	.WRITE_STAGES(0),
	.REGISTER_OUTPUT(1)
) uag1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.ce_i(1'b1),
	.rid_i('d0),
	.wid_i('d0),
	.i((cs_config|cs_stlbq|cs_rgnq) & ~wbs_req.we),
	.we_i((cs_config|cs_stlbq|cs_rgnq) & wbs_req.we),
	.o(acko),
	.rid_o(),
	.wid_o()
);

pci128_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
	.CFG_BAR1(IO_ADDR2),
	.CFG_BAR1_MASK(IO_ADDR_MASK),
	.CFG_SUBSYSTEM_VENDOR_ID(CFG_SUBSYSTEM_VENDOR_ID),
	.CFG_SUBSYSTEM_ID(CFG_SUBSYSTEM_ID),
	.CFG_ROM_ADDR(CFG_ROM_ADDR),
	.CFG_REVISION_ID(CFG_REVISION_ID),
	.CFG_PROGIF(CFG_PROGIF),
	.CFG_SUBCLASS(CFG_SUBCLASS),
	.CFG_CLASS(CFG_CLASS),
	.CFG_CACHE_LINE_SIZE(CFG_CACHE_LINE_SIZE),
	.CFG_MIN_GRANT(CFG_MIN_GRANT),
	.CFG_MAX_LATENCY(CFG_MAX_LATENCY),
	.CFG_IRQ_LINE(CFG_IRQ_LINE)
)
upci
(
	.rst_i(rst_i),
	.clk_i(clk_g),
	.irq_i(1'b0),
	.irq_o(),
	.cs_config_i(cs_config),
	.we_i(wbs_req.we),
	.sel_i(wbs_req.sel),
	.adr_i(wbs_req.padr),
	.dat_i(wbs_req.data1),
	.dat_o(cfg_out),
	.cs_bar0_o(cs_stlb),
	.cs_bar1_o(cs_rgn),
	.cs_bar2_o(),
	.irq_en_o()
);

always_ff @(posedge clk_g)
if (rst_i) begin
	pte_reg <= 'd0;
	pmt_reg <= 'd0;
	pte_adr <= 'd0;
	pmt_adr <= 'd0;
	ctrl_reg <= 'd0;
	rd_tlb <= 'b0;
	wr_tlb <= 1'b0;
	wrtlb_i <= 1'b0;
	tlben_i <= 1'b0;
end
else begin
	tlben_i <= |rd_tlb;
	rd_tlb <= {rd_tlb[1:0],1'b0};
	wr_tlb <= 1'b0;
	wrtlb_i <= 1'b0;
	if (cs_stlbq & wbs_req.we) begin
		case(wbs_req.padr[5:4])
		2'd0:	
			begin
				pte_reg <= wbs_req.data1;
				vpn_reg <= wbs_req.data2;
				wr_tlb <= 1'b1;
			end
		2'd1:	;
		2'd2:	;
		2'd3:	
			case(wbs_req.sel)
			16'h000F:	ctrl_reg <= wbs_req.data1[31:0];
			16'hFF00:
				begin
					rd_tlb <= {2'b00,wbs_req.data1[64]};
				end
			endcase
		endcase
	end
	if (wr_tlb) begin
		tlben_i <= 1'b1;
		wrtlb_i <= 1'b1;
		tlbdat_i.count <= master_count;
		tlbdat_i.pte <= pte_reg;
		tlbdat_i.pte_adr = pte_adr;
		tlbadr_i <= ctrl_reg;
	end
	if (rd_tlb[0])
		tlbadr_i <= ctrl_reg;
	if (rd_tlb[2]) begin
		pte_reg <= tlbdato[ctrl_reg[3:0]].pte;
		vpn_reg <= tlbdato[ctrl_reg[3:0]].vpn;
	end
end

always_ff @(posedge clk_g)
if (rst_i)
	dato <= 'd0;
else begin
	if (cs_config)
		dato <= cfg_out;
	else if (cs_stlbq)
		case(wbs_req.padr[5:4])
		2'd0:	dato <= pte_reg;
		2'd1:	dato <= pmt_reg;
		2'd2:	dato <= {pmt_adr,pte_adr};
		2'd3:	dato <= ctrl_reg;
		endcase
	else if (cs_rgnq)
		dato <= rgn_dato;
	else
		dato <= 'd0;
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Thor2023_stlb_active_region urgn
(
	.rst(rst_i),
	.clk(clk_i),
	.cs_rgn(cs_rgnq),
	.rgn(rgn),
	.wbs_req(wb_req_o),
	.dato(rgn_dato),
	.region_num(),
	.region(region),
	.sel(),
	.err()
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Arbitrate incoming requests.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg rr_ce;
reg [CHANNELS-1:0] rr_active;
reg [CHANNELS-1:0] rr_req;
wire [CHANNELS-1:0] rr_sel;
wire ne_ack;

edge_det uedack
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.i(wb_resp_i.ack|wb_resp_i.err|wb_resp_i.rty),
	.pe(),
	.ne(ne_ack),
	.ee()
);

// Arbit when there is no request pending or at the end of a request.
always_comb
	rr_ce = ne_ack| ~|(rr_req & ~rr_active);
always_comb
	for (n5 = 0; n5 < CHANNELS; n5 = n5 + 1)
		if (n5==CHANNELS-1)
			rr_req[n5] = wbm_req.cyc;
		else
			rr_req[n5] = wbn_req_i[n5].cyc;
always_comb
begin
	req = 'd0;
	for (n5 = 0; n5 < CHANNELS; n5 = n5 + 1)
		if (rr_sel[n5])	begin // should be one hot
			if (n5==CHANNELS-1)
				req = wbm_req;
			else
				req = wbn_req_i[n5];
		end
end
always_comb
begin
	wbm_resp = 'd0;
	wbn_resp_o = 'd0;
	if (wb_resp_i.tid[7:4]==CHANNELS-1) begin
		if (cs_config|cs_stlbq) begin
			wbm_resp.cid = wb_req_o.cid;
			wbm_resp.tid = wb_req_o.tid;
			wbm_resp.stall = 1'b0;
			wbm_resp.next = 1'b0;
			wbm_resp.ack = acko;
			wbm_resp.err = 1'b0;
			wbm_resp.rty = 1'b0;
			wbm_resp.pri = 4'd7;
			wbm_resp.dat = dato;
			wbm_resp.adr = wb_req_o.padr;
		end
		else begin
			wbm_resp = wb_resp_i;
			wbm_resp.adr = wb_req_o.padr;
		end
	end
	else begin
		wbn_resp_o[wb_resp_i.tid[7:4]] = wb_resp_i;
		wbn_resp_o[wb_resp_i.tid[7:4]].adr = wb_req_o.padr;
	end
end
always_comb
	xlaten_i = req.cyc;
always_comb
	we_i = req.we;
always_comb
	asid_i = req.asid;
always_comb
	adr_i = req.vadr;
always_comb
	next_i = wb_resp_i.next;
always_ff @(posedge clk_i)
if (rst_i)
	rr_active <= 'd0;
else begin
	rr_active <= rr_active | rr_sel;
	if (wb_resp_i.ack|wb_resp_i.rty|wb_resp_i.err)
		rr_active[wb_resp_i.tid[7:4]] <= 1'b0;
end
wire cache_type = wb_req_o.cache;

wire non_cacheable =
	cache_type==NC_NB ||
	cache_type==NON_CACHEABLE
	;
always_comb
	snoop_v = (wb_req_o.we|non_cacheable|~rwx_o[3]) & wb_req_o.cyc;
always_comb
	snoop_adr = wb_req_o.padr;
always_comb
	snoop_cid = (non_cacheable|~rwx_o[3]) ? 4'd15 : wb_req_o.tid[7:4];

roundRobin
#(
	.N(CHANNELS)
) 
urr1
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(rr_ce),
	.req(rr_req),
	.lock('d0),
	.sel(rr_sel),
	.sel_enc()
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [ASSOC-1:0] wr;
reg wed;
reg [3:0] hit;
reg [ASSOC-1:0] wrtlb, next_wrtlb;
genvar g1;
generate begin : gWrtlb
	for (g1 = 0; g1 < ASSOC; g1 = g1 + 1) begin : gFor
		always_comb begin
			next_wrtlb[g1] <= 'd0;
			if (state==ST_RUN) begin
				if (LRU && tlbadr_i[3:0]!=ASSOC-1) begin
					if (g1==ASSOC-2)
						next_wrtlb[g1] <= wrtlb_i;
				end
				else begin
					if (tlbadr_i[3:0]==ASSOC-1) begin
						if (g1==ASSOC-1)
		 					next_wrtlb[g1] <= wrtlb_i;
		 			end
					else if (g1 < ASSOC-1)
		 				next_wrtlb[g1] <= (al==2'b10 ? randway==g1 : tlbadr_i[3:0]==g1) && wrtlb_i;
	 			end
 			end
 		end
 	end
end
endgenerate

// TLB RAM has a 1 cycle lookup latency.
// These signals need to be matched
always_ff @(posedge clk_g)
	xlatend <= xlaten_i;

always_comb
	tlbdat_o <= tlbdato[tlbadr_i[3:0]];

always_ff @(posedge clk_g)
begin
	al <= al_i;
	LRU <= al_i==2'b01;
end

wire [ASSOC-1:0] wrtlbd;
ft_delay #(.WID(ASSOC), .DEP(3)) udlyw (.clk(clk_g), .ce(1'b1), .i(wrtlb), .o(wrtlbd));

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

always_ff @(posedge clk_g)
	adrd <= adr_i;

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

edge_det edclk (.rst(rst_i), .clk(clk_g), .ce(1'b1), .i(clock), .pe(pe_clock), .ne(), .ee());

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i) begin
	state <= ST_RST;
	master_count <= 6'd1;
	tlbeni <= 1'b1;		// forces ready low
	tlbwrr <= 'd0;
	count <= 'd0;		// Map only last 256kB
	clock_r <= 1'b0;
	wbm_req <= 'd0;
end
else begin
tlbeni  <= 1'b0;
tlbwrr <= 'd0;
if (pe_clock)
	clock_r <= 1'b1;
case(state)
	
// Setup the last 256kB/16 pages of memory to point to the ROM BIOS.
ST_RST:
	begin
		master_count <= 6'd1;
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
				tlbdat_rst.count <= 6'd1;
				tlbdat_rst.asid <= 'd0;
				//tlbdat_rst.pte.g <= 1'b1;
				tlbdat_rst.pte.m <= 1'b1;
				tlbdat_rst.pte.rwx <= 3'd7;
				//tlbdat_rst.pte.c <= 1'b1;
				// FFFC0000
				// 1111_1111_1111_1100_00 00_0000_0000_0000
				tlbdat_rst.vpn <= 8'hFF;
				tlbdat_rst.pte.ppn <= {14'h3FFF,count[3:0]};
				tlbdat_rst.pmte.cache <= wishbone_pkg::CACHEABLE;
				//tlbdat_rst.ppnx <= 12'h000;
				rcount <= {6'h3F,count[3:0]};
			end // Map 16MB ROM/IO area
		1'b1: begin state <= ST_RUN; tlbwrr[ASSOC-1] <= 1'd1; end
		default:	;
		endcase
		count <= count + 2'd1;
		invall <= 'd0;
		inv_count <= ENTRIES-1;
	end
ST_RUN:
	begin
		if (invall && inv_count==ENTRIES-1) begin
			inv_count <= 'd0;
			invall <= 'd0;
			// Master count never hits zero.
			master_count <= master_count + 2'd1;
			if (master_count == 6'd63)
				master_count <= 6'd1;
		end
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
		else if (inv_count != ENTRIES-1) begin
			wrtlb <= 'd0;
			inv_count <= inv_count + 2'd1;
			state <= ST_INVALL1;
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
		wbm_req.cyc <= 1'b1;
		wbm_req.padr <= dumped_entry.pte_adr;
		wbm_req.sel <= 16'hFFFF;
		wbm_req.data1 <= dumped_entry;
		wbm_req.data1[55] <= 1'b0;	// modified bit
		if (wbm_resp.ack|wbm_resp.err|wbm_resp.rty) begin
			wbm_req.cyc <= 1'b0;
			state <= ST_RUN;
		end
	end
	else
		state <= ST_RUN;
ST_INVALL1:
	begin
		tlbeni <= 1'b1;
		state <= ST_INVALL2;
	end
ST_INVALL2:
	begin
		tlbeni <= 1'b1;
		state <= ST_INVALL3;
	end
ST_INVALL3:
	begin
		tlbeni <= 1'b1;
		state <= ST_INVALL4;
	end
ST_INVALL4:
	begin
		tlbeni <= 1'b1;
		for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
			if (tlbdato[n2].count!=master_count)
				tlbwrr[n2] <= 1'b1;
		end
		state <= ST_RUN;
	end
default:
	state <= ST_RUN;
endcase
end
assign rdy_o = ~tlbeni;

Thor2023_stlb_ad_state_machine
#(
	.ENTRIES(ENTRIES),
	.PAGE_SIZE(PAGE_SIZE),
	.ASSOC(ASSOC)
)
usm2
(
	.rst(rst_i),
	.clk(clk_g),
	.state(state),
	.rcount(rcount),
	.tlbadr_i(tlbadr_i),
	.tlbadro(tlbadri), 
	.tlbdat_rst(tlbdat_rst),
	.tlbdat_i(tlbdat_i),
	.tlbdati(tlbdato),
	.tlbdato(tlbdati),
	.master_count(master_count),
	.inv_count(inv_count)
);

// Dirty / Accessed bit write logic
always_ff @(posedge clk_g)
  wed <= we_i;
always_ff @(posedge clk_g)
	stptr <= stptr_i;

always_ff @(posedge clk_g)
begin
	wr <= 'd0;
  if (ne_xlat) begin
  	for (n1 = 0; n1 < ASSOC; n1 = n1 + 1) begin
  		if (hit==n1) begin
  			if (LRU && n1 < 4) begin
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

always_comb
for (n7 = 0; n7 < ASSOC; n7 = n7 + 1)
	case(n7)
	default:	adr_i_slice[n7] = adr_i[LOG_PAGE_SIZE+LOG_ENTRIES-1:LOG_PAGE_SIZE];
	ASSOC-2,ASSOC-3: adr_i_slice[n7] = adr_i[$bits(address_t)-1:LOG_ENTRIES+LOG_PAGE_SIZE];
	endcase
	
genvar g;
generate begin : gTlbRAM
for (g = 0; g < ASSOC; g = g + 1) begin : gLvls
	Thor2023_TLBRam
	# (
		.ENTRIES(ENTRIES),
		.WIDTH($bits(TLBE))
	)
	u1 (
	  .clka(clk_g),
	  .ena(tlben_i|tlbeni),
	  .wea(wrtlb[g]|tlbwrr[g]),
	  .addra(tlbadri),
	  .dina(tlbdati[g]),
	  .douta(tlbdato[g]),
	  .clkb(clk_g),
	  .enb(xlaten_i),
	  .web(wr[g]),
	  .addrb(adr_i_slice[g]),
	  .dinb(tentryi[g]),
	  .doutb(tentryo[g])
	);
end
end
endgenerate

// Pipeline delay req.
always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	req1 <= 'd0;
else
	req1 <= req;

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i) begin
	wb_req_o <= req1;
	wb_req_o.padr <= 'd0;
  wb_req_o.padr[LOG_PAGE_SIZE-1:0] <= rstip[LOG_PAGE_SIZE-1:0];
  wb_req_o.padr[$bits(address_t)-1:LOG_PAGE_SIZE] <= rstip[$bits(address_t)-1:LOG_PAGE_SIZE];
  hit <= 4'd15;
  tlbmiss_o <= FALSE;
	tlbmiss_adr_o <= 'd0;
	tlbkey_o <= 32'hFFFFFFFF;
  rwx <= 3'd7;
  rgn <= 3'd7;	// select default ROM region
  cache <= wishbone_pkg::CACHEABLE;
end
else begin
  rgn <= 3'd7;	// select default ROM region
	wb_req_o <= req1;
 	wb_req_o.padr <= wb_req_o.padr;
  if (pe_xlat) begin
  	hit <= 4'd15;
  end
	if (next_i)
		wb_req_o.padr <= wb_req_o.padr + 6'd16;
  else begin
		if (!xlatend) begin
	    tlbmiss_o <= FALSE;
	  	wb_req_o.padr <= {16'h0000,iadrd[31:0]};
	    rwx <= 4'hF;
		end
		else begin
			tlbmiss_o <= dl[4] & ~cd_adr;
			tlbmiss_adr_o <= adrd;
			hit <= 4'd15;
			rwx <= 4'h0;
			for (n = 0; n < ASSOC; n = n + 1) begin
				tentryo2[n] <= tentryo[n];
				if (tentryo[n].count==master_count) begin
					if (tentryo[n].asid[11:0]==asid_i[11:0] || tentryo[n].g) begin
						if (tentryo[n].pte.v) begin
							case(tentryo[n].pte.lvl)
							3'd0:
								if (tentryo[n].vpn[$bits(address_t)-1-LOG_PAGE_SIZE-LOG_ENTRIES:0]==
									{{2{&iadrd[31:28]}},iadrd[$bits(address_t)-1:LOG_PAGE_SIZE+LOG_ENTRIES]}) begin
									wb_req_o.padr[LOG_PAGE_SIZE-1:0] <= iadrd[LOG_PAGE_SIZE-1:0];
									wb_req_o.padr[$bits(address_t)-1:LOG_PAGE_SIZE] <= tentryo[n].pte.ppn[$bits(address_t)-LOG_PAGE_SIZE-1:0];
									//wb_req_o.adr[47:32] <= {16{&tentryo[n].pte.ppn[15:12]}};
//									rwx <= {tentryo[n].pte.ppn < 18'h01FFF || tentryo[n].pte.ppn > 18'h3FFF0,tentryo[n].pte.rwx};
									rwx <= tentryo[n].pte.rwx[om_i];
									cache <= tentryo[n].pmte.cache;
									tlbmiss_o <= FALSE;
								  rgn <= tentryo[n].pte.rgn;
									hit <= n;
								end
							3'd1:
								begin
									wb_req_o.padr[LOG_ENTRIES+LOG_PAGE_SIZE-1:0] <= iadrd[LOG_ENTRIES+LOG_PAGE_SIZE-1:0];
									wb_req_o.padr[$bits(address_t)-1:LOG_ENTRIES+LOG_PAGE_SIZE] <= tentryo[n].pte.ppn[$bits(address_t)-LOG_PAGE_SIZE-1:LOG_ENTRIES];
									//wb_req_o.adr[47:32] <= {16{&tentryo[n].pte.ppn[15:12]}};
//									rwx <= {tentryo[n].pte.ppn < 18'h01FFF || tentryo[n].pte.ppn > 18'h3FFF0,tentryo[n].pte.rwx};
									rwx <= tentryo[n].pte.rwx[om_i];
									cache <= tentryo[n].pmte.cache;
									tlbmiss_o <= FALSE;
								  rgn <= tentryo[n].pte.rgn;
									hit <= n;
								end
							default:	;
							endcase
						end
					end
				end				
			end
		end
	end
end

always_comb
	rwx_o = |rwx ? rwx : region.at[om_i].rwx;

// Cache-ability output. Region takes precedence.
always_comb
	case(wb_cache_t'(region.at[om_i].cache))
	NC_NB:					cache_o = NC_NB;
	NON_CACHEABLE:	cache_o = NON_CACHEABLE;
	CACHEABLE_NB:
		case(wb_cache_t'(cache))
		NC_NB:					cache_o = NC_NB;
		NON_CACHEABLE:	cache_o = NON_CACHEABLE;
		CACHEABLE_NB:		cache_o = CACHEABLE_NB;
		CACHEABLE:			cache_o = CACHEABLE_NB;
		default:				cache_o = cache;
		endcase
	CACHEABLE:
		case(wb_cache_t'(cache))
		NC_NB:					cache_o = NC_NB;
		NON_CACHEABLE:	cache_o = NON_CACHEABLE;
		CACHEABLE_NB:		cache_o = CACHEABLE_NB;
		default:				cache_o = cache;
		endcase
	WT_NO_ALLOCATE,WT_READ_ALLOCATE,WT_WRITE_ALLOCATE,WT_READWRITE_ALLOCATE,
	WB_NO_ALLOCATE,WB_READ_ALLOCATE,WB_WRITE_ALLOCATE,WB_READWRITE_ALLOCATE:
		case(wb_cache_t'(cache))
		NC_NB:					cache_o = NC_NB;
		NON_CACHEABLE:	cache_o = NON_CACHEABLE;
		default:				cache_o = region.at[om_i].cache;
		endcase
	default:	cache_o = NC_NB;
	endcase

endmodule
