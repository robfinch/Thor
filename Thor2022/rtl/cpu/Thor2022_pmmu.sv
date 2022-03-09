// ============================================================================
//        __
//   \\__/ o\    (C) 2007-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_pmmu.v
//  - 64 bit CPU paged memory management unit
//	- 512 entry TLB, 8 way associative
//  - variable page table depth
//	- address short-cutting for larger page sizes (8MB)
//  - hardware clearing of access bit
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//
// ============================================================================
//
`ifndef TRUE
`define TRUE    1'b1
`define FALSE   1'b0
`endif

typedef struct packed
{
	logic [15:0] sharecount;
	logic [15:0] padpageno;
	logic [31:0] pageno;
	logic [31:0] refcount;
	logic [7:0] asid;
	logic g;
	logic v;
	logic [1:0] pad;
	logic sc;
	logic sw;
	logic sr;
	logic sx;
	logic [7:0] pl;
	logic d;
	logic u;
	logic s;
	logic a;
	logic c;
	logic w;
	logic r;
	logic x;
} PTE;

module Thor2022_pmmu
#(
parameter
	AMSB = 31,
	pAssociativity = 8,		// number of ways (parallel compares)
	pTLB_size = 64,
	S_WAIT_MISS = 0,
	S_WR_PTL0L = 1,
	S_WR_PTL0H = 2,
	S_RD_PTL0L = 3,
	S_RD_PTL0H = 4,
	S_RD_PTL1L = 5,
	S_RD_PTL1H = 6,
	S_RD_PTL2 = 7,
	S_RD_PTL3 = 8,
	S_RD_PTL4 = 9,
	S_RD_PTL5 = 10,
	S_RD_PTL5_ACK = 11,
	S_RD_PTL = 12,
	S_WR_PTL = 13
)
(
// syscon
input rst_i,
input clk_i,

input age_tick_i,			// indicates when to age reference counts

// master
output reg m_cyc_o,		// valid memory address
output reg m_lock_o,	// lock the bus
input      m_ack_i,		// acknowledge from memory system
output reg m_we_o,		// write enable output
output reg [15:0] m_sel_o,	// lane selects (always all active)
output reg [AMSB:0] m_adr_o,
input      [127:0] m_dat_i,	// data input from memory
output reg [127:0] m_dat_o,	// data to memory

// Translation request / control
input invalidate,		// invalidate a specific entry
input invalidate_all,	// causes all entries to be invalidated
input [47:0] pta,		// page directory/table address register
output reg page_fault,

input [7:0] asid_i,
input [7:0] pl_i,
input [1:0] ol_i,		// operating level
input icl_i,				// instruction cache load
input cyc_i,
input we_i,				    // cpu is performing write cycle
input [7:0] sel_i,
input [63:0] vadr_i,	    // virtual address to translate

output reg cyc_o,
output reg we_o,
output reg [7:0] sel_o,
output reg [AMSB:0] padr_o,	// translated address
output reg cac_o,		// cachable
output reg prv_o,		// privilege violation
output reg exv_o,		// execute violation
output reg rdv_o,		// read violation
output reg wrv_o		// write violation
);

integer nn;
reg [8:0] tlb_wa;
reg [8:0] tlb_ra;
reg [8:0] tlb_ua;
reg [AMSB:0] tmpadr;
reg pv_o;
reg v_o;
reg r_o;
reg w_o;
reg x_o;
reg c_o;
reg a_o;
reg [2:0] nnx;
PTE pte;				// holding place for data
reg [AMSB-4:0] pte_adr;
reg [3:0] state;
reg [3:0] stkstate;
reg [2:0] cnt;	// tlb replacement counter
reg [2:0] whichSet;		// which set to update
reg dbit;				// temp dirty bit
reg miss;
reg proc;
reg [63:0] miss_adr;
wire pta_changed;
assign ack_o = !miss||page_fault;
wire pgen = pta[11];

wire [AMSB:0] tlb_pte_adr [pAssociativity-1:0];
wire [pAssociativity-1:0] tlb_d;
wire [ 6: 0] tlb_flags [pAssociativity-1:0];
wire [ 7: 0] tlb_pl [pAssociativity-1:0];
wire [ 7: 0] tlb_asid [pAssociativity-1:0];
wire [31: 0] tlb_refcount [pAssociativity-1:0];
wire [15: 0] tlb_sharecount [pAssociativity-1:0];
wire tlb_g [pAssociativity-1:0];
wire [63:18] tlb_vadr  [pAssociativity-1:0];
wire [31:0] tlb_tadr  [pAssociativity-1:0];

//wire wr_tlb = state==S_WR_PTL0;
reg wr_tlb;
always @(posedge clk_i)
	cyc_o <= cyc_i & v_o & ~pv_o;
always @(posedge clk_i)
	we_o <= we_i & v_o & ~pv_o & w_o;
always @(posedge clk_i)
	sel_o <= sel_i & {8{~pv_o}};
always @(posedge clk_i)
	prv_o <= pv_o & v_o && ol_i!=2'b00;
always @(posedge clk_i)
	exv_o <= icl_i & v_o & ~x_o && ol_i!=2'b00;
always @(posedge clk_i)
	rdv_o <= ~icl_i & v_o & ~r_o && ol_i!=2'b00;
always @(posedge clk_i)
	wrv_o <= ~icl_i & v_o & ~w_o && ol_i!=2'b00;
always @(posedge clk_i)
	cac_o <= c_o & v_o;

genvar g;
generate
	for (g = 0; g < pAssociativity; g = g + 1)
	begin : genTLB
		ram_ar1w1r #(46,pTLB_size) tlbVadr
		(
			.clk(clk_i),
			.ce(whichSet==g),
			.we(wr_tlb),
			.wa(miss_adr[17:12]),
			.ra(vadr_i[17:12]),
			.i(miss_adr[63:18]),
			.o(tlb_vadr[g])
		);
		ram_ar1w1r #(AMSB+1,pTLB_size) tlbPteAdr
		(
			.clk(clk_i),
			.ce(whichSet==g),
			.we(wr_tlb),
			.wa(miss_adr[17:12]),
			.ra(vadr_i[17:12]),
			.i(pte_adr),
			.o(tlb_pte_adr[g])
		);
		ram_ar1w1r #( 7,pTLB_size) tlbFlag
		(
			.clk(clk_i),
			.ce(whichSet==g),
			.we(wr_tlb),
			.wa(miss_adr[17:12]),
			.ra(vadr_i[17:12]),
			.i(pte[6:0]),
			.o(tlb_flags[g])
		);
		ram_ar1w1r #(8,pTLB_size) tlbPL
    (
      .clk(clk_i),
      .ce(whichSet==g),
      .we(wr_tlb),
      .wa(miss_adr[17:12]),
      .ra(vadr_i[17:12]),
      .i(pte.pl),
      .o(tlb_pl[g])
    );
		ram_ar1w1r #( 1,pTLB_size) tlbG
		(
			.clk(clk_i),
			.ce(whichSet==g),
			.we(wr_tlb),
			.wa(miss_adr[17:12]),
			.ra(vadr_i[17:12]),
			.i(pte.g),
			.o(tlb_g[g])
		);
		ram_ar1w1r #(8,pTLB_size) tlbASID
    (
      .clk(clk_i),
      .ce(whichSet==g),
      .we(wr_tlb),
      .wa(miss_adr[17:12]),
      .ra(vadr_i[17:12]),
      .i(pte.asid),
      .o(tlb_asid[g])
    );
    /*
		ram_ar1w1r #(32,pTLB_size) tlbRefCount
    (
      .clk(clk_i),
      .ce(whichSet==g),
      .we(wr_tlb),
      .wa(miss_adr[17:12]),
      .ra(vadr_i[17:12]),
      .i(pte.refcount),
      .o(tlb_refcount[g])
    );
    */
		ram_ar1w1r #(32,pTLB_size) tlbRefCount
		(
			.clk(clk_i),
			.ce(wr_tlb?whichSet==g:nnx==g),
			.we(wr_tlb||state==S_WAIT_MISS && !miss && cyc_i),
			.wa(wr_tlb?miss_adr[17:12]:vadr_i[17:12]),
			.ra(vadr_i[17:12]),
			.i(pte.refcount),
			.o(tlb_refcount[g])
		);
		ram_ar1w1r #(16,pTLB_size) tlbShareCount
    (
      .clk(clk_i),
      .ce(whichSet==g),
      .we(wr_tlb),
      .wa(miss_adr[17:12]),
      .ra(vadr_i[17:12]),
      .i(pte.sharecount),
      .o(tlb_sharecount[g])
    );
		ram_ar1w1r #(32,pTLB_size) tlbTadr
		(
			.clk(clk_i),
			.ce(whichSet==g),
			.we(wr_tlb),
			.wa(miss_adr[17:12]),
			.ra(vadr_i[17:12]),
			.i(pte.pageno),
			.o(tlb_tadr[g])
		);
		ram_ar1w1r #( 1,pTLB_size) tlbD    
		(
			.clk(clk_i),
			.ce(wr_tlb?whichSet==g:nnx==g),
			.we(wr_tlb||state==S_WAIT_MISS && wr && !miss && cyc_i),
			.wa(wr_tlb?miss_adr[17:12]:vadr_i[17:12]),
			.ra(vadr_i[17:12]),
			.i(!wr_tlb),
			.o(tlb_d[g])
		);
	end
endgenerate

reg [pAssociativity*pTLB_size-1:0] tlb_v;	// valid

// The following reg allows detection of when the page table address changes
change_det #(48) u1
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.i(pta),
	.cd(pta_changed)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// PMA Checker
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg [AMSB-4:0] PMA_LB [0:7];
reg [AMSB-4:0] PMA_UB [0:7];
reg [15:0] PMA_AT [0:7];

initial begin
  PMA_LB[7] = 28'hFFFC000;
  PMA_UB[7] = 28'hFFFFFFF;
  PMA_AT[7] = 16'h000D;       // rom, byte addressable, cache-read-execute
  PMA_LB[6] = 28'hFFD0000;
  PMA_UB[6] = 28'hFFD1FFF;
  PMA_AT[6] = 16'h0206;       // io, (screen) byte addressable, read-write
  PMA_LB[5] = 28'hFFD2000;
  PMA_UB[5] = 28'hFFDFFFF;
  PMA_AT[5] = 16'h0206;       // io, byte addressable, read-write
  PMA_LB[4] = 28'hFFFFFFF;
  PMA_UB[4] = 28'hFFFFFFF;
  PMA_AT[4] = 16'hFF00;       // vacant
  PMA_LB[3] = 28'hFFFFFFF;
  PMA_UB[3] = 28'hFFFFFFF;
  PMA_AT[3] = 16'hFF00;       // vacant
  PMA_LB[2] = 28'hFFFFFFF;
  PMA_UB[2] = 28'hFFFFFFF;
  PMA_AT[2] = 16'hFF00;       // vacant
  PMA_LB[1] = 28'h1000000;
  PMA_UB[1] = 28'hFFCFFFF;
  PMA_AT[1] = 16'hFF00;       // vacant
  PMA_LB[0] = 28'h0000000;
  PMA_UB[0] = 28'h0FFFFFF;
  PMA_AT[0] = 16'h010F;       // ram, byte addressable, cache-read-write-execute
end

/*
task tPMAEA;
begin
  if (keyViolation && omode == 2'd0)
    memresp.cause <= {8'h80,FLT_KEY};
  // PMA Check
  for (n = 0; n < 8; n = n + 1)
    if (adr_o[31:4] >= PMA_LB[n] && adr_o[31:4] <= PMA_UB[n]) begin
      if (((memreq.func==MR_STORE || memreq.func==MR_MOVST) && !PMA_AT[n][1]) || ((memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==MR_MOVLD || memreq.func==M_JALI) && !PMA_AT[n][2]))
		    memresp.cause <= {8'h80,FLT_PMA};
		  dcachable <= dcachable & PMA_AT[n][3];
    end
end
endtask

task tPMAIP;
begin
  // PMA Check
  // Abort cycle that has already started.
  for (n = 0; n < 8; n = n + 1)
    if (adr_o[31:4] >= PMA_LB[n] && adr_o[31:4] <= PMA_UB[n]) begin
      if (!PMA_AT[n][0]) begin
        memresp.cause <= {8'h80,FLT_PMA};
        tDeactivateBus();
    	end
    end
end
endtask
*/

assign pte_i = m_dat_i;
wire pte_valid_i = pte_i.r|pte_i.w|pte_i.x;

// This must be fast !!!
// Lookup the virtual address in the tlb
// Translate the address
// I/O and system BIOS addresses are not mapped
// Cxxx_xxxx_xxxx_xxxx to FFFF_FFFF_FFFF_FFFF not mapped (kernel segment)
// 0000_0000_0000_0000 to 0000_0000_0000_xxxx not mapped (kernel data segement)
always @(posedge clk_i)
begin
	miss <= 1'b1;
	nnx <= pAssociativity;
	a_o <= 1'b1;
	c_o <= 1'b1;
	r_o <= 1'b1;
	x_o <= 1'b1;
	w_o <= 1'b1;
	v_o <= 1'b0;
	pv_o <= 1'b0;
	padr_o[12: 0] <= vadr_i[12: 0];
	padr_o[47:13] <= vadr_i[47:13];
	begin
		if (!pgen) begin
			miss <= 1'b0;
			v_o <= 1'b1;
			c_o <= 1'b0;
		  for (nn = 0; nn < 8; nn = nn + 1)
    		if (vadr_i[AMSB:4] >= PMA_LB[nn] && vadr_i[AMSB:4] <= PMA_UB[nn]) begin
    			c_o <= PMA_AT[nn][3];
    		end
		end
		else
		for (nn = 0; nn < pAssociativity; nn = nn + 1)
			if (tlb_v[{nn,vadr_i[17:12]}] && vadr_i[63:18]==tlb_vadr[nn]) begin
			    if (tlb_flags[nn][5])
				    padr_o[47:12] <= {tlb_tadr[nn][35:12],vadr_i[23:12]};
			    else
				    padr_o[47:12] <= tlb_tadr[nn];
				miss <= 1'b0;
				nnx <= nn;
				a_o <= tlb_flags[nn][4];
				c_o <= tlb_flags[nn][3];
				r_o <= tlb_flags[nn][2];
				w_o <= tlb_flags[nn][1];
				x_o <= tlb_flags[nn][0];
				v_o <= tlb_flags[nn][2]|tlb_flags[nn][1]|tlb_flags[nn][0];
				pv_o <= (cyc_i & icl_i) ? pl != tlb_pl[nn] && pl!=8'h00 : pl > tlb_pl[nn];
			end
	end
end

reg age_tick_r;
wire pe_age_rtick;
edge_det ued1(.clk(clk_i), .ce(1'b1), .i(age_tick), .pe(pe_age_tick), .ne(), .ee());

// The following state machine loads the tlb buffer on a
// miss.
always @(posedge clk_i)
if (rst_i) begin
	nack();
	wr_tlb <= 1'b0;
	m_adr_o <= 1'b0;
	goto(S_WAIT_MISS);
	dbit  <= 1'b0;
	whichSet <= 1'b0;
	for (nn = 0; nn < pAssociativity * pTLB_size; nn = nn + 1)
		tlb_v[nn] <= 1'b0;		// all entries are invalid on reset
  page_fault <= `FALSE;
  age_tick_r <= 1'b0;
end
else begin
	wr_tlb <= 1'b0;

	// page fault pulses
	page_fault <= `FALSE;

	if (pe_age_tick)
		age_tick_r <= 1'b1;

	// changing the address of the page table invalidates all entries
	if (invalidate_all)
		for (nn = 0; nn < pAssociativity * pTLB_size; nn = nn + 1)
			tlb_v[nn] <= 1'b0;

	// handle invalidate command
	if (invalidate)
		for (nn = 0; nn < pAssociativity; nn = nn + 1)
			if (vadr_i[63:19]==tlb_vadr[nn] && (tlb_g[nn] || tlb_asid[nn]==asid_i))
				tlb_v[{nn,vadr_i[18:13]}] <= 1'b0;

	case (state)	// synopsys full_case parallel_case

	// Wait for a miss to occur. then initiate bus cycle
	// Output either the page directory address
	// or the page table address, depending on the
	// size of the app.
	S_WAIT_MISS:
		begin
			goto(S_WAIT_MISS);
			dbit <= we_i;
			proc <= `FALSE;

			if (miss) begin
			  proc <= `TRUE;
				miss_adr <= vadr_i;
				// try and pick an empty tlb entry
				whichSet <= cnt;
				for (nn = 0; nn < pAssociativity; nn = nn + 1)
					if (!tlb_v[{nn,vadr_i[18:13]}])
						whichSet <= nn;
				goto(S_RD_PTL5);
			end
			// If there's a write cycle, check to see if the
			// dirty bit is set. If the dirty bit hasn't been
			// set yet, then set it and write the dirty status
			// to memory.
			else if (cyc_i && we_i && !tlb_d[nnx]) begin
				miss_adr <= vadr_i;
				whichSet <= nnx;
				goto(S_RD_PTL5);
			end
			else if (age_tick_r) begin
				age_tick_r <= 1'b0;
				tlb_wa <= tlb_ua + 3'd1;
				tlb_ra <= tlb_ua + 3'd1;
				tlb_ua <= tlb_ua + 3'd1;
				goto(S_AGE);
			end
			else begin
				tlb_wa <= {nnx,vadr_i[18:13]};
				tlb_ra <= {nnx,vadr_i[18:13]};
				goto(S_COUNT);
			end
		end

	S_RD_PTL5:
		if (~m_ack_i & ~m_cyc_o) begin
			tlb_ra <= {whichSet,miss_adr[17:12]};
			tlb_wa <= {whichSet,miss_adr[17:12]};
			m_cyc_o <= 1'b1;
			m_sel_o <= 16'hFFFF;
			m_lock_o <= 1'b0;
			m_we_o  <= 1'b0;
			case(pta[10:8])
			3'd0:	state <= S_RD_PTL1;
			3'd1:	state <= S_RD_PTL2;
			3'd2:	state <= S_RD_PTL3;
			3'd3:	state <= S_RD_PTL4;
			3'd4:	state <= S_RD_PTL5_ACK;
			3'd5:	;
			default:	;
			endcase
			// Set page table address for lookup
			case(pta[10:8])
			3'b000:	m_adr_o <= {pta[47:16],miss_adr[23:12],4'h0};	// 16MB translations
			3'b001:	m_adr_o <= {pta[47:16],miss_adr[35:24],4'h0};	// 64GB translations
			3'b010:	m_adr_o <= {pta[47:16],miss_adr[47:36],4'h0};	// 256TB translations
			3'b011:	m_adr_o <= {pta[47:16],miss_adr[59:48],4'h0};	// 4XB translations
			3'b100:	m_adr_o <= {pta[47:16],miss_adr[71:60],4'h0};	//     translations
			3'b101:	;//m_adr_o <= {pta[47:16],miss_adr[83:72],4'h0};	//  translations
			3'b110:	;//m_adr_o <= {pta[47:16],miss_adr[95:84],4'h0};	//  translations
			3'b111:	;//m_adr_o <= {pta[47:16],miss_adr[107:96],4'h0};	//  translations
			default:	;
			endcase
		end
	// Wait for ack from system
	// Setup to access page table
	// If app uses a page directory, now address the page table
	S_RD_PTL5_ACK:
		if (m_ack_i) begin
			nack();
			if (pte_valid_i) begin	// pte valid bit
				tmpadr <= {pte_i.pageno,miss_adr[71:60],4'h0};
				call(S_RD_PTL,S_RD_PTL4);
			end
			else begin
				if (clock) begin
					clock_adr[83:72] <= clock_adr[83:72] + 4'h1;
					clock_adr[67:0] <= 'h0;
					goto (S_WAIT_MISS);
				end
				else
		  	  raise_page_fault();
				// not a valid translation
				// OS messed up ?
			end
		end

	// Wait for ack from system
	// Setup to access page table
	// If app uses a page directory, now address the page table
	S_RD_PTL4:
		if (m_ack_i) begin
			nack();
			if (pte_valid_i) begin	// pte valid bit
				tmpadr <= {pte_i.pageno,miss_adr[59:48],4'b0};
				call(S_RD_PTL,S_RD_PTL3);
			end
			else begin
				if (clock) begin
					clock_adr[83:60] <= clock_adr[83:60] + 4'h1;
					clock_adr[59:0] <= 'h0;
					goto (S_WAIT_MISS);
				end
				else
		  	  raise_page_fault();
		  end
		end

	// Wait for ack from system
	// Setup to access page table
	// If app uses a page directory, now address the page table
	S_RD_PTL3:
		if (m_ack_i) begin
			nack();
			if (pte_valid_i) begin	// pte valid bit
				tmpadr <= {pte_i.pageno,miss_adr[47:36],4'b0};
				call(S_RD_PTL,S_RD_PTL2);
			end
			else begin
				if (clock) begin
					clock_adr[83:48] <= clock_adr[83:48] + 4'h1;
					clock_adr[47:0] <= 'h0;
					goto (S_WAIT_MISS);
				end
				else
		  	  raise_page_fault();
		  end
		end

	// Wait for ack from system
	// Setup to access page table
	// If app uses a page directory, now address the page table
	S_RD_PTL2:
		if (m_ack_i) begin
			nack();
			if (pte_valid_i) begin	// pte valid bit
				tmpadr <= {pte_i.pageno,miss_adr[35:24],4'b0};
				call(S_RD_PTL,S_RD_PTL1);
			end
			else begin
				if (clock) begin
					clock_adr[83:36] <= clock_adr[83:36] + 4'h1;
					clock_adr[35:0] <= 'h0;
					goto (S_WAIT_MISS);
				end
				else
		  	  raise_page_fault();
		  end
		end

	// Wait for ack from system
	// Setup to access page table
	// If app uses a page directory, now address the page table
	S_RD_PTL1:
		if (m_ack_i) begin
			nack();
			if (pte_valid_i) begin	// pte valid bit
		    // Shortcut 16MiB page ?
		    if (pte_i.s) begin
	        pte <= pte_i;
    			m_dat_o <= pte_i|{dbit,2'b00,~clock,4'b0};
    			m_dat_o[4] <= ~clock;
					call(S_WR_PTL,S_WR_PTL0);
		    end
		    else begin
			    tmpadr <= {pte_i.pageno,miss_adr[23:12],4'b0};
					call(S_RD_PTL,S_RD_PTL0);
				end
			end
			else begin
				if (clock) begin
					clock_adr[83:24] <= clock_adr[83:24] + 4'h1;
					clock_adr[23:0] <= 4'h0;
					goto (S_WAIT_MISS);
				end
				else
		  	  raise_page_fault();
		  end
		end

	//---------------------------------------------------
	// This section of the state machine performs a
	// read then write of a PTE
	//---------------------------------------------------
	// Perform a read cycle of page table level 0 entry
	S_RD_PTL0:
  	// The tlb has been updated so the page must have been accessed
    // set the accessed bit for the page table entry
    // Also set dirty bit if a write access.
		if (m_ack_i) begin
			nack();
			tlb_wr <= 1'b1;
			pte_adr <= m_adr_o[AMSB:4];
			m_dat_o <= pte_i|{dbit,2'b00,1'b1,4'b0};	// This line will only set bits
			pte <= pte_i|{dbit,2'b00,1'b1,4'b0};
			// If the tlb entry is already marked dirty don't bother with updating
			// the pte in memory. Only write on a new dirty status.
			if (tlb_d[tlb_ra[8:6]])
				goto(S_WAIT_MISS);
			else
				call(S_WR_PTL,S_WR_PTL0);
		end

	S_WR_PTL0:
		if (m_ack_i) begin
			tlb_wr <= 1'b1;
			nack();
			tlb_v[tlb_wa] <= |pte[2:0];
			if (~|pte[2:0])
		    raise_page_fault();
			goto(S_WAIT_MISS);
		end

	//---------------------------------------------------
	// Take care of reference counting and aging.
	//---------------------------------------------------

	S_COUNT:
		begin
			pte[6:0] <= tlb_flags[tlb_ra[8:6]];
			pte[7] <= tlb_d[tlb_ra[8:6]];
			pte[15:8] <= tlb_pl[tlb_ra[8:6]];
			pte[23] <= tlb_g[tlb_ra[8:6]];
			pte[31:24] <= tlb_asid[tlb_ra[8:6]];
			pte[63:32] <= {tlb_refcount[tlb_ra[8:6]][63:42] + 4'd1,tlb_refcount[tlb_ra[8:6]][41:32]};
			pte[127:64] <= tlb_tadr[tlb_ra[8:6]];
			tlb_wr <= 1'b1;
			goto(S_WAIT_MISS);
		end

	S_AGE:
		begin
			pte[6:0] <= tlb_flags[tlb_ra[8:6]];
			pte[7] <= tlb_d[tlb_ra[8:6]];
			pte[15:8] <= tlb_pl[tlb_ra[8:6]];
			pte[23] <= tlb_g[tlb_ra[8:6]];
			pte[31:24] <= tlb_asid[tlb_ra[8:6]];
			pte[63:32] <= {1'b0,tlb_refcount[tlb_ra[8:6]][63:33]};
			pte[127:64] <= tlb_tadr[tlb_ra[8:6]];
			tlb_wr <= 1'b1;
			goto(S_WAIT_MISS);
		end

	//---------------------------------------------------
	// Subroutine: initiate read cycle
	//---------------------------------------------------
	S_RD_PTL:
		if (~m_ack_i & ~m_cyc_o) begin
			m_cyc_o <= 1'b1;
			m_sel_o <= 16'hFFFF;
			m_lock_o <= 1'b0;
			m_we_o  <= 1'b0;
			m_adr_o <= tmpadr;
			xreturn();
		end

	//---------------------------------------------------
	// Subroutine: initiate write cycle
	//---------------------------------------------------
	S_WR_PTL:
		if (~m_ack_i & ~m_cyc_o) begin
			m_cyc_o <= 1'b1;
			m_sel_o <= 16'hFFFF;
			m_lock_o <= 1'b0;
			m_we_o  <= 1'b1;
			// Address comes from a previous read address
//			m_adr_o <= tmpadr;
			xreturn();
		end

	//---------------------------------------------------
	// This state can't happen without a hardware error
	//---------------------------------------------------
	default:
		begin
			nack();
			goto(S_WAIT_MISS);
		end

	endcase
end


// This counter is used to select the tlb entry that gets
// replaced when a new entry is entered into the buffer.
// It just increments every time an entry is updated. 
always @(posedge clk_i)
if (rst_i)
	cnt <= 0;
else if (state==S_WAIT_MISS && miss) begin
	if (cnt == pAssociativity-1)
		cnt <= 0;
	else
		cnt <= cnt + 1;
end

task nack;
begin
	m_cyc_o <= 1'b0;
	m_sel_o <= 8'h00;
	m_lock_o <= 1'b0;
	m_we_o  <= 1'b0;
end
endtask

task raise_page_fault;
begin
	nack();
  if (proc)
    page_fault <= `TRUE;
  proc <= `FALSE;
  state <= S_WAIT_MISS;
end
endtask

task goto;
input [3:0] nst;
begin
	state <= nst;
end
endtask

task call;
input [3:0] nst;
input [3:0] rst;
begin
	goto(nst);
	stkstate <= rst;
end
endtask

task xreturn;
begin
	state <= stkstate;
end
endtask

endmodule

