// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_biu.sv
//	- bus interface unit
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

import Thor2022_pkg::*;
import Thor2022_tlbpkg::*;
import Thor2022_mmupkg::*;

module Thor2022_biu(rst,clk,tlbclk,UserMode,MUserMode,omode,ASID,bounds_chk,pe,
	ip,ihit,ifStall,ic_line,
	fifoToCtrl_i,fifoToCtrl_full_o,fifoFromCtrl_o,fifoFromCtrl_rd,fifoFromCtrl_empty,fifoFromCtrl_v,
	bok_i, bte_o, cti_o, vpa_o, vda_o, cyc_o, stb_o, ack_i, we_o, sel_o, adr_o,
	dat_i, dat_o, sr_o, cr_o, rb_i, dce, keys, arange, pta);
parameter AWID=32;
input rst;
input clk;
input tlbclk;
input UserMode;
input MUserMode;
input [1:0] omode;
input [7:0] ASID;
input bounds_chk;
input pe;									// protected mode enable
input Address ip;
output reg ihit;
input ifStall;
output [pL1ICacheLineSize-1:0] ic_line;
// Fifo controls
input MemoryRequest fifoToCtrl_i;
output fifoToCtrl_full_o;
output MemoryResponse fifoFromCtrl_o;
input fifoFromCtrl_rd;
output fifoFromCtrl_empty;
output fifoFromCtrl_v;
// Bus controls
input bok_i;
output reg [1:0] bte_o;
output reg [2:0] cti_o;
output reg vpa_o;
output reg vda_o;
output reg cyc_o;
output reg stb_o;
input ack_i;
output reg we_o;
output reg [15:0] sel_o;
output Address adr_o;
input [127:0] dat_i;
output reg [127:0] dat_o;
output reg sr_o;
output reg cr_o;
input rb_i;

output reg dce;							// data cache enable
input [19:0] keys [0:7];
input [2:0] arange;
input Address pta;

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
parameter HIGH = 1'b1;
parameter LOW = 1'b0;

parameter IO_KEY_ADR	= 16'hFF88;

parameter MEMORY_INIT = 7'd0;
parameter MEMORY1 = 7'd1;
parameter MEMORY2 = 7'd2;
parameter MEMORY3 = 7'd3;
parameter MEMORY4 = 7'd4;
parameter MEMORY5 = 7'd5;
parameter MEMORY6 = 7'd6;
parameter MEMORY7 = 7'd7;
parameter MEMORY8 = 7'd8;
parameter MEMORY9 = 7'd9;
parameter MEMORY10 = 7'd10;
parameter MEMORY11 = 7'd11;
parameter MEMORY12 = 7'd12;
parameter MEMORY13 = 7'd13;
parameter DATA_ALIGN = 7'd14;
parameter MEMORY_KEYCHK1 = 7'd15;
parameter MEMORY_KEYCHK2 = 7'd16;
parameter KEYCHK_ERR = 7'd17;
parameter TLB1 = 7'd21;
parameter TLB2 = 7'd22;
parameter TLB3 = 7'd23;
parameter IFETCH0 = 7'd30;
parameter IFETCH1 = 7'd31;
parameter IFETCH2 = 7'd32;
parameter IFETCH3 = 7'd33;
parameter IFETCH4 = 7'd34;
parameter IFETCH5 = 7'd35;
parameter IFETCH6 = 7'd36;
parameter IFETCH1a = 7'd37;
parameter IFETCH1b = 7'd38;
parameter IFETCH3a = 7'd39;
parameter DFETCH2 = 7'd42;
parameter DFETCH3 = 7'd43;
parameter DFETCH4 = 7'd44;
parameter DFETCH5 = 7'd45;
parameter DFETCH6 = 7'd46;
parameter DFETCH7 = 7'd47;
parameter KYLD = 7'd51;
parameter KYLD2 = 7'd52;
parameter KYLD3 = 7'd53;
parameter KYLD4 = 7'd54;
parameter KYLD5 = 7'd55;
parameter KYLD6 = 7'd56;
parameter KYLD7 = 7'd57;
parameter MEMORY1a = 7'd60;
parameter MFSEL1 = 7'd61;
parameter MEMORY5a = 7'd62;
parameter MEMORY11a = 7'd63;
parameter PFETCH1 = 7'd64;
parameter PFETCH2 = 7'd65;
parameter PFETCH3 = 7'd66;
parameter PFETCH4 = 7'd67;
parameter PFETCH5 = 7'd68;
parameter PFETCH6 = 7'd69;
parameter PFETCH7 = 7'd70;
parameter PFETCH8 = 7'd71;
parameter PFETCH9 = 7'd72;

integer m,n,k;
genvar g;

reg [5:0] shr_ma;

reg [6:0] state;
// States for hardware routine stack, three deep.
reg [6:0] stk_state1, stk_state2, stk_state3;
reg [1:0] waycnt;
reg iaccess;
reg daccess;
reg [4:0] icnt;
reg [4:0] dcnt;
Address iadr;
reg keyViolation = 1'b0;
reg xlaten;

MemoryRequest memreq,imemreq;
reg memreq_rd = 0;
MemoryResponse memresp;
reg zero_data = 0;
Value movdat;

reg [4:0] seg;
Address ea;
Address afilt;

always_comb
	afilt.offs = (memreq.func==MR_MOVST) ? memreq.dat : memreq.adr;

always_comb
 	ea.offs = {afilt.offs >> shr_ma};	// Keep same selector

reg [7:0] ealow;

reg [1:0] strips;
reg [63:0] sel;
reg [63:0] nsel;
reg [255:0] dat, dati;
reg [511:0] dati512;
reg [127:0] datis;
always_comb datis = dati >> {ealow[3:0],3'b0};
`ifdef CPU_B64
reg [15:0] sel;
reg [127:0] dat, dati;
wire [63:0] datis = dati >> {ealow[2:0],3'b0};
`endif
`ifdef CPU_B32
reg [7:0] sel;
reg [63:0] dat, dati;
wire [63:0] datis = dati >> {ealow[1:0],3'b0};
`endif

// Build an insert mask for data cache store operations.
reg [639:0] stmask;
reg [127:0] stmask1;
generate begin : gStMask
	for (g = 0; g < 16; g = g + 1)
		always_comb
			stmask1[g*4+3:g*4] <= sel_o[g] ? 8'h00 : 8'hFF;
always_comb stmask <= stmask1 << {adr_o[5:4],7'd0};
`ifdef CPU_B64
	for (g = 0; g < 8; g = g + 1)
		always_comb
			stmask1[g*4+3:g*4] <= sel_o[g] ? 8'h00 : 8'hFF;
always_comb stmask <= stmask1 << {adr_o[5:3],6'd0};
`endif
`ifdef CPU_B32
	for (g = 0; g < 4; g = g + 1)
		always_comb
			stmask1[g*4+3:g*4] <= sel_o[g] ? 8'h00 : 8'hFF;
always_comb stmask <= stmask1 << {adr_o[5:2],5'd0};
`endif
end
endgenerate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// PMA Checker
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg [AWID-4:0] PMA_LB [0:7];
reg [AWID-4:0] PMA_UB [0:7];
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


wire [3:0] ififo_cnt, ofifo_cnt;

wire [16:0] lfsr_o;

lfsr ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

wire fifoToCtrl_empty;
wire fifoToCtrl_v;

wire pev;
edge_det ued1 (.rst(rst), .clk(clk), .ce(1'b1), .i(fifoToCtrl_v), .pe(pev), .ne(), .ee());

/*
any1_mem_fifo #(.WID($bits(MemoryRequest))) uififo1
(
	.clk(clk),
	.rst(rst),
	.wr(fifoToCtrl_i.fifo_wr),
	.rd(memreq_rd & ~pev),
	.din(fifoToCtrl_i),
	.dout(imemreq),
	.ctr(),
	.full(fifoToCtrl_full),
	.empty(fifoToCtrl_empty)
);
assign fifoToCtrl_v = TRUE;
*/

// 236 wide
MemoryRequestFifo uififo1
(
  .clk(clk),      // input wire clk
  .srst(rst),    // input wire srst
  .din(fifoToCtrl_i),      // input wire [197 : 0] din
  .wr_en(fifoToCtrl_i.wr),  // input wire wr_en
  .rd_en(memreq_rd & ~pev),  // input wire rd_en
  .dout(imemreq),    // output wire [197 : 0] dout
  .full(fifoToCtrl_full_o),  // output wire full
  .empty(fifoToCtrl_empty),  // output wire empty
  .valid(fifoToCtrl_v)  // output wire valid
);

/*
bc_fifo16X #(.WID($bits(MemoryRequest))) uififo1
(
	.clk(clk),
	.reset(rst),
	.wr(fifoToCtrl_i.fifo_wr),
	.rd(memreq_rd),
	.di(fifoToCtrl_i),
	.dout(memreq),
	.ctr(ififo_cnt)
);
*/

MemoryResponseFifo uofifo1
(
  .clk(clk),      // input wire clk
  .srst(rst),    // input wire srst
  .din(memresp),      // input wire [197 : 0] din
  .wr_en(memresp.wr),  // input wire wr_en
  .rd_en(fifoFromCtrl_rd),  // input wire rd_en
  .dout(fifoFromCtrl_o),    // output wire [197 : 0] dout
  .full(),    // output wire full
  .empty(fifoFromCtrl_empty),  // output wire empty
  .valid(fifoFromCtrl_v)  // output wire valid
);

/*
bc_fifo16X #(.WID($bits(MemoryResponse))) uififo2
(
	.clk(clk),
	.reset(rst),
	.wr(memresp.fifo_wr),
	.rd(fifoFromCtrl_rd),
	.di(memresp),
	.dout(fifoFromCtrl_o),
	.ctr(ofifo_cnt)
);

assign fifoFromCtrl_empty = ofifo_cnt==4'd0;
*/

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg ic_update;
reg [1:0] ic_rway,ic_wway;
reg icache_wr;
always_comb icache_wr = state==IFETCH3;
reg ic_invline,ic_invall;
reg [1:0] prev_ic_rway = 0;
Address ipo;

reg [639:0] ici;		// Must be a multiple of 128 bits wide for shifting.
reg [AWID-7:0] ic_tag;
reg [AWID-7:0] prev_ic_tag = 0;

// 640 wide x 512 deep
icache_blkmem uicm (
  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(icache_wr),      // input wire [0 : 0] wea
  .addra({waycnt,ipo[12:6]}),  // input wire [8 : 0] addra
  .dina(ici[pL1ICacheLineSize-1:0]),    // input wire [511 : 0] dina
  .clkb(~clk),    // input wire clkb
  .enb(!ifStall),      // input wire enb
  .addrb({ic_rway,ip[12:6]}),  // input wire [8 : 0] addrb
  .doutb(ic_line)  // output wire [511 : 0] doutb
);

reg [AWID-1:6] ictag [0:3] [0:512/4-1];
reg [512/4-1:0] icvalid [0:3];
reg ihit1a;
reg ihit1b;
reg ihit1c;
reg ihit1d;
always_ff @(tlbclk)
begin
  ihit1a = ictag[0][ip[12:6]]==ip[AWID-1:6] && icvalid[0][ip[12:6]]==TRUE;
  ihit1b = ictag[1][ip[12:6]]==ip[AWID-1:6] && icvalid[1][ip[12:6]]==TRUE;
  ihit1c = ictag[2][ip[12:6]]==ip[AWID-1:6] && icvalid[2][ip[12:6]]==TRUE;
  ihit1d = ictag[3][ip[12:6]]==ip[AWID-1:6] && icvalid[3][ip[12:6]]==TRUE;
	ihit = ihit1a|ihit1b|ihit1c|ihit1d;
end

initial begin
  for (n = 0; n < 512/4; n = n + 1) begin
    ictag[0][n] = 32'd1;
    ictag[1][n] = 32'd1;
    ictag[2][n] = 32'd1;
    ictag[3][n] = 32'd1;
  end
end

initial begin
  for (n = 0; n < 512/4; n = n + 1) begin
    icvalid[0][n] = 1'b0;
    icvalid[1][n] = 1'b0;
    icvalid[2][n] = 1'b0;
    icvalid[3][n] = 1'b0;
  end
end

always_comb
begin
  case(1'b1)
  ihit1a: ic_rway <= 2'b00;
  ihit1b: ic_rway <= 2'b01;
  ihit1c: ic_rway <= 2'b10;
  ihit1d: ic_rway <= 2'b11;
  default:  ic_rway <= prev_ic_rway;
  endcase
end

// For victim cache update
always_comb
begin
  case(1'b1)
  ihit1a: ic_tag <= ictag[0][ip[12:6]];
  ihit1b: ic_tag <= ictag[1][ip[12:6]];
  ihit1c: ic_tag <= ictag[2][ip[12:6]];
  ihit1d: ic_tag <= ictag[3][ip[12:6]];
  default:  ic_tag <= prev_ic_tag;
  endcase
end

always_ff @(posedge clk)
	prev_ic_rway <= ic_rway;
always_ff @(posedge clk)
	prev_ic_tag <= ic_tag;

always @(posedge clk)
if (rst) begin
	icvalid[0] <= {512/4{1'b0}};
	icvalid[1] <= {512/4{1'b0}};
	icvalid[2] <= {512/4{1'b0}};
	icvalid[3] <= {512/4{1'b0}};
end
else begin
	if (icache_wr) begin
		icvalid[waycnt][ipo[12:6]] <= 1'b1;
		ictag[waycnt][ipo[12:6]] <= ipo[AWID-1:6];
	end
	// Cache line invalidate
	// Use physical address
	// ToDo: Check for tag match
	else if (state==MEMORY4) begin
		if (ic_invline) begin
			icvalid[0][adr_o[12:6]] <= 1'b0;
			icvalid[1][adr_o[12:6]] <= 1'b0;
			icvalid[2][adr_o[12:6]] <= 1'b0;
			icvalid[3][adr_o[12:6]] <= 1'b0;
		end
		else if (ic_invall) begin
			icvalid[0] <= {512/4{1'b0}};
			icvalid[1] <= {512/4{1'b0}};
			icvalid[2] <= {512/4{1'b0}};
			icvalid[3] <= {512/4{1'b0}};
		end
	end
end


reg [2:0] ivcnt;
reg [2:0] vcn;
reg [pL1ICacheLineSize-1:0] ivcache [0:4];
reg [AWID-1:6] ivtag [0:4];
reg [4:0] ivvalid;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Key Cache
// - the key cache is direct mapped, 64 lines of 512 bits.
// - keys are stored in the low order 20 bits of a 32-bit memory cell
// - 16 keys per 512 bit cache line
// - one cache line is enough to cover 256kB of memory
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

`ifdef SUPPORT_KEYCHK
reg [19:0] io_keys [0:511];
initial begin
	for (n = 0; n < 512; n = n + 1)
		io_keys[n] = 20'h0;
reg [511:0] kyline [0:63];
reg [AWID-19:0] kytag;
reg [63:0] kyv;
reg kyhit;
reg io_adr;
always_comb
	io_adr <= adr_o[31:23]==9'b1111_1111_1;
always_comb
	kyhit <= kytag[adr_o[23:18]]==adr_o[AWID-1:18] && kyv[adr_o[23:18]] || io_adr;
initial begin
	kyv = 64'd0;
	for (n = 0; n < 64; n = n + 1) begin
		kyline[n] = 512'd0;
		kytag[n] = 32'd1;
	end
end
reg [19:0] kyut;
always_comb
	kyut <= io_adr ? io_keys[adr_o[31:23]] : kyline[adr_o[23:18]] >> {adr_o[17:14],5'd0};
`endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Data Cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg [2:0] dwait;		// wait state counter for dcache
Address dadr;
reg [639:0] dci;		// 512 + 120 bit overflow area
wire [639:0] dc_line;
reg [639:0] datil;
reg dcachable;
reg [1:0] dc_rway,dc_wway,prev_dc_rway;
reg dcache_wr;
reg dc_invline,dc_invall;

dcache_blkmem udcb1 (
  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(dcache_wr),      // input wire [0 : 0] wea
  .addra({dc_wway,dadr[12:6]}),  // input wire [8 : 0] addra
  .dina(dci),    // input wire [511 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb({dc_rway,adr_o[12:6]}),  // input wire [8 : 0] addrb
  .doutb(dc_line)  // output wire [511 : 0] doutb
);

reg [AWID-7:0] dctag0 [0:127];
reg [AWID-7:0] dctag1 [0:127];
reg [AWID-7:0] dctag2 [0:127];
reg [AWID-7:0] dctag3 [0:127];
reg [127:0] dcvalid0;
reg [127:0] dcvalid1;
reg [127:0] dcvalid2;
reg [127:0] dcvalid3;
reg dhit1a;
reg dhit1b;
reg dhit1c;
reg dhit1d;
always_comb	//(posedge clk_g)
  dhit1a <= dctag0[adr_o[12:6]]==adr_o[AWID-1:6] && dcvalid0[adr_o[12:6]];
always_comb	//(posedge clk_g)
  dhit1b <= dctag1[adr_o[12:6]]==adr_o[AWID-1:6] && dcvalid1[adr_o[12:6]];
always @*	//(posedge clk_g)
  dhit1c <= dctag2[adr_o[12:6]]==adr_o[AWID-1:6] && dcvalid2[adr_o[12:6]];
always_comb	//(posedge clk_g)
  dhit1d <= dctag3[adr_o[12:6]]==adr_o[AWID-1:6] && dcvalid3[adr_o[12:6]];
wire dhit = dhit1a|dhit1b|dhit1c|dhit1d;
initial begin
  for (n = 0; n < 128; n = n + 1) begin
    dctag0[n] = 32'd1;
    dctag1[n] = 32'd1;
    dctag2[n] = 32'd1;
    dctag3[n] = 32'd1;
  end
end

always_comb
begin
  case(1'b1)
  dhit1a: dc_rway <= 2'b00;
  dhit1b: dc_rway <= 2'b01;
  dhit1c: dc_rway <= 2'b10;
  dhit1d: dc_rway <= 2'b11;
  default:  dc_rway <= prev_dc_rway;
  endcase
end

always_ff @(posedge clk)
	prev_dc_rway <= dc_rway;

// ToDo:
// Add data cache invalidate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// MR_TLB
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg tlben, tlbwr;
wire tlbmiss;
wire tlbrdy;
wire [3:0] tlbacr;
wire [127:0] tlbdato;
reg [63:0] tlb_ia;
reg [127:0] tlb_ib;
reg inext;
TLBEntry tmptlbe;
Address tlbmiss_adr;
Address miss_adr;

Thor2022_tlb utlb (
  .rst_i(rst),
  .clk_i(tlbclk),
  .rdy_o(tlbrdy),
  .asid_i(ASID),
  .sys_mode_i(vpa_o ? ~UserMode : ~MUserMode),
  .xlaten_i(xlaten),
  .we_i(we_o),
  .dadr_i(dadr),
  .next_i(inext),
  .iacc_i(iaccess),
  .dacc_i(daccess),
  .iadr_i(iadr),
  .padr_o(adr_o),
  .acr_o(tlbacr),
  .tlben_i(tlben),
  .wrtlb_i(tlbwr & tlb_ia[31]),
  .tlbadr_i(tlb_ia[15:0]),
  .tlbdat_i(tlb_ib[$bits(TLBEntry)-1:0]),
  .tlbdat_o(tlbdato[$bits(TLBEntry)-1:0]),
  .tlbmiss_o(tlbmiss),
  .tlbmiss_adr_o(tlbmiss_adr)
);

reg [7:0] fault_code;
PTG ptg;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// State Machine
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always @(posedge clk)
if (rst) begin
	dce <= FALSE;
	zero_data <= FALSE;
	dcachable <= TRUE;
  dcvalid0 = 128'd0;
  dcvalid1 = 128'd0;
  dcvalid2 = 128'd0;
  dcvalid3 = 128'd0;
	ivvalid <= 5'h00;
	ivcnt <= 3'd0;
	vcn <= 3'd0;
	for (n = 0; n < 5; n = n + 1) begin
		ivtag[n] <= 32'd1;
		ivcache[n] <= {8{NOP_INSN}};
	end
	shr_ma <= 6'd0;
	tlben <= TRUE;
	iadr <= RSTIP;
	dadr <= RSTIP;	// prevents MR_TLB miss at startup
	tDeactivateBus();
	dat <= 256'd0;
	sr_o <= LOW;
	cr_o <= LOW;
	waycnt <= 2'd0;
	ic_wway <= 2'b00;
	dcache_wr <= FALSE;
	dwait <= 3'd0;
	iaccess <= FALSE;
	daccess <= FALSE;
	ici <= 512'd0;
	dci <= 640'd0;
	ptg <= 'd0;
	memreq_rd <= FALSE;
	memresp.wr <= FALSE;
	memresp.res <= 128'd0;
	memresp.ldcs <= FALSE;
  xlaten <= FALSE;
	goto (MEMORY_INIT);
end
else begin
	inext <= FALSE;
	ic_update <= 1'b0;
//	memreq_rd <= FALSE;
	memresp.wr <= FALSE;
	dcache_wr <= FALSE;
	tlbwr <= FALSE;

	case(state)
	MEMORY_INIT:
		begin
			goto (MEMORY1);
		end
	MEMORY1:
		if (tlbrdy) begin
			iaccess <= FALSE;
			daccess <= FALSE;
		  icnt <= 5'd0;
		  dcnt <= 5'd0;
		  shr_ma <= 6'd0;
		  dcachable <= FALSE;
			if (!ihit && fifoToCtrl_empty) begin
				waycnt <= waycnt + 2'd1;
				// On a miss goto load I$ process unless a hit in the victim cache.
		    iaccess <= TRUE;
				gosub (IFETCH0);
			end
			if (!fifoToCtrl_empty) begin
				memreq_rd <= TRUE;
				gosub (MEMORY1a);
			end
		end

	MEMORY1a:
		if (fifoToCtrl_v) begin
			memreq_rd <= FALSE;
			memreq <= imemreq;
			goto (MEMORY2);
		end

	MEMORY2:
		begin
			strips <= 2'd0;
			memresp.cause <= {8'h00,FLT_NONE};
			memresp.badAddr <= memreq.adr;	// Handy for debugging
			ealow <= ea[7:0];
			// Detect cache controller commands
  		case(memreq.func)
			MR_TLB:
				begin
		    	tlb_ia <= memreq.adr[31:0];
    			tlb_ib <= memreq.dat;
    			tlbwr <= TRUE;
					goto (TLB1);
				end
			MR_LOAD,MR_LOADZ,MR_MOVLD:
				case(memreq.func2)
				MR_LEA:
					begin
						memresp.tid <= memreq.tid;
						memresp.step <= memreq.step;
						memresp.res <= memreq.adr;
				    memresp.cmt <= TRUE;
						memresp.wr <= TRUE;
						memresp.res <= 128'd0;
						goto (MEMORY1);
					end
				MR_LDOO:
					begin
			    	begin
				    	daccess <= TRUE;
	    		  	//tEA(ea);
		      		xlaten <= TRUE;
		      		// Setup proper select lines
				      sel <= 32'hFFFFFFFF;
				  		goto (MEMORY3);
			  		end
					end
				default:
					begin
			    	begin
				    	daccess <= TRUE;
	    		  	//tEA(ea);
		      		xlaten <= TRUE;
		      		// Setup proper select lines
				      sel <= {32'h0,memreq.sel} << ea[3:0];
				  		goto (MEMORY3);
			  		end
					end
				endcase
			M_JALI:
				begin
		    	begin
			    	daccess <= TRUE;
	    		  //tEA(ea);
	      		xlaten <= TRUE;
	      		// Setup proper select lines
			      sel <= {32'h0,memreq.sel} << ea[3:0];
			  		goto (MEMORY3);
		  		end
				end
			MR_CACHE:
				begin
					ic_invline <= memreq.dat[2:0]==3'd1;
					ic_invall	<= memreq.dat[2:0]==3'd2;
					dc_invline <= memreq.dat[5:3]==3'd3;
					dc_invall	<= memreq.dat[5:3]==3'd4;
					memresp.step <= memreq.step;
					if (memreq.dat[5:3]==3'd1)
						dce <= TRUE;
					if (memreq.dat[5:3]==3'd2)
						dce <= FALSE;
			    memresp.cmt <= TRUE;
					memresp.tid <= memreq.tid;
					memresp.wr <= TRUE;
					memresp.res <= 128'd0;
					ret();
				end
			/*
			RTS2:
				begin
					memresp.ret <= TRUE;
		    	daccess <= TRUE;
    		  tEA(ea);
      		xlaten <= TRUE;
      		// Setup proper select lines
		      sel <= {32'h0,memreq.sel} << ea[3:-1];
		  		goto (MEMORY3);
				end
			*/
			MR_STORE,M_CALL:
				begin
			    begin
			    	daccess <= TRUE;
	    		  //tEA(ea);
	      		xlaten <= TRUE;
	      		// Setup proper select lines
			      sel <= zero_data ? 32'h0001 << ea[3:0] : {32'h0,memreq.sel} << ea[3:0];
			      // Shift output data into position
	    		  dat <= zero_data ? 256'd0 : {128'd0,memreq.dat} << {ea[3:0],3'b0};
			  		goto (MEMORY3);
		  		end
				end
			MR_MOVST:
				begin
			    begin
			    	daccess <= TRUE;
	    		  //tEA(ea);
	      		xlaten <= TRUE;
	      		// Setup proper select lines
			      sel <= {16'h0,memreq.sel} << ea[3:0];
			      // Shift output data into position
	    		  dat <= {128'd0,memresp.res} << {ea[3:0],3'b0};
			  		goto (MEMORY3);
		  		end
				end
			default:	ret();	// unknown operation
			endcase
	  end
	// The following two states for MR_TLB translation lookup
	MEMORY3:
		goto (MEMORY4);
`ifdef SUPPORT_KEYCHK
	MEMORY4:
		goto (MEMORY_KEYCHK1);
`else
	MEMORY4:
		goto (MEMORY5);
`endif
`ifdef SUPPORT_KEYCHK
	MEMORY_KEYCHK1:
  	begin
  		if (!kyhit)
  			gosub(KYLD);
			else begin
				goto (KEYCHK_ERR);
				for (n = 0; n < 8; n = n + 1)
					if (kyut == keys[n] || kyut==20'd0)
						goto(MEMORY5);
			end
    	if (memreq.func==MR_CACHE)
      	tPMAEA();
      if (adr_o[31:16]==IO_KEY_ADR) begin
      	memresp.step <= memreq.step;
      	memresp.cause <= {8'h00,FLT_NONE};
      	memresp.cmt <= TRUE;
      	memresp.res <= io_keys[adr_o[12:2]];
      	memresp.wr <= TRUE;
      	if (memreq.func==MR_STORE) begin
      		io_keys[adr_o[12:2]] <= memreq.dat[19:0];
      	end
      	ret();
    	end
  	end
	KEYCHK_ERR:
		begin
			memresp.step <= memreq.step;
	    memresp.cause <= {8'h80,FLT_KEY};	// KEY fault
	    memresp.cmt <= TRUE;
			memresp.tid <= memreq.tid;
		  memresp.badAddr <= ea;
		  memresp.wr <= TRUE;
			memresp.res <= 128'd0;
		  ret();
		end
`endif

	MEMORY5:		// Allow time for lookup
		goto (MEMORY5a);

	MEMORY5a:
	  begin
	    dwait <= 3'd0;
	    goto (MEMORY6);
	  	if (tlbmiss) begin
	  		tDeactivateBus();
	  		fault_code <= FLT_DPF;
	  		miss_adr <= tlbmiss_adr;
	  		goto (PFETCH1);
	  	end
	    else if (memreq.func != MR_CACHE) begin
	    	vda_o <= HIGH;
	      cyc_o <= HIGH;
	      stb_o <= HIGH;
	      for (n = 0; n < 16; n = n + 1)
	      	sel_o[n] <= sel[n];
	      if (memreq.func==MR_LOAD && memreq.func2==MR_LDOO)
	      	sel_o <= 16'hFFFF;
//	      sel_o <= sel[15:0];
	      dat_o <= dat[127:0];
	      case(memreq.func)
	      MR_LOAD,MR_LOADZ,MR_MOVLD,M_JALI://,RTS2:
	      	begin
	     			sr_o <= memreq.func2==MR_LDOR;
	     			if (tlbacr[1]) begin
	  	    		if (dhit & tlbacr[3]) begin
	  	    			tDeactivateBus();
	      				sr_o <= LOW;
		      		end
	      		end
	      		else
	      			tReadViolation(ea);
	      	end
	      MR_STORE,MR_MOVST,M_CALL:
	      	begin
      			cr_o <= memreq.func2==MR_STOC;
	      		if (tlbacr[2])
		      		we_o <= HIGH;
		      	else
		      		tWriteViolation(ea);
	      	end
	      default:  ;
	      endcase
	    end
	  end

	MEMORY6:
	  begin
	  	case(1'b1)
	    ic_invline:	ret();
	    ic_invall:	ret();
	    dc_invline:	ret();
	    dc_invall:	ret();
	    dce & dhit & tlbacr[3]:
		    begin
		    	datil <= dc_line;
		  		if (memreq.func==MR_STORE || memreq.func==MR_MOVST || memreq.func==M_CALL) begin
		  			if (ack_i) begin
			  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
			  			dc_wway <= dc_rway;
		  				dcache_wr <= TRUE;
				      goto (MEMORY7);
				      stb_o <= LOW;
				      if (sel[31:16]==1'h0)
				      	tDeactivateBus();
				    end
		  		end
		    	else begin
		    		dwait <= dwait + 2'd1;
		    		if (dwait==3'd2)
			      	goto (MEMORY7);
			    end
	  		end
	    default:
		    if (ack_i) begin
		      goto (MEMORY7);
		      stb_o <= LOW;
		      dati <= dat_i;
		      dati512 <= {dat_i,dati512[511:128]};
		      if (sel[31:16]==1'h0) begin
		      	tDeactivateBus();
		      end
		    end
	  	endcase
	  end

	MEMORY7:
		begin
		  if (~ack_i) begin
	      case(memreq.func)
	      MR_LOAD,MR_LOADZ,MR_MOVLD,M_JALI://,RTS2:
	      	begin
				    if (|sel[31:16] && !(dce && dhit && tlbacr[3]))
			  	    goto (MEMORY8);
			  	  else begin
	      			tDeactivateBus();
			        goto (DATA_ALIGN);
			      end
	      		if (dce & dhit & tlbacr[3]) begin
	      			dati <= datil >> {adr_o[5:3],6'b0};
	      			dati512 <= datil;
	      			tDeactivateBus();
			        goto (DATA_ALIGN);
			      end
	      	end
		    MR_STORE,MR_MOVST,M_CALL:
		    	begin
				    if (|sel[31:16])
	  			    goto (MEMORY8);
	  			  else begin
			    		if (memreq.func2==MR_STPTR) begin	// STPTR
					    	if (~|ea[AWID-5:0]) begin
					  			memresp.step <= memreq.step;
					    	 	memresp.cmt <= TRUE;
		  						memresp.tid <= memreq.tid;
		  						memresp.wr <= TRUE;
									memresp.res <= {127'd0,rb_i};
						    	ret();
					    	end
					    	else begin
					    		shr_ma <= shr_ma + 4'd9;
					    		zero_data <= TRUE;
					    		goto (MEMORY2);
					    	end
			    		end
			    		else begin
				  			memresp.step <= memreq.step;
					    	memresp.cmt <= TRUE;
				  			memresp.tid <= memreq.tid;
				  			memresp.wr <= TRUE;
								memresp.res <= {127'd0,rb_i};
					    	ret();
				      end
			    	end
		    	end
	      default:
			    if (|sel[31:16])
			      goto (MEMORY8);
			    else
	        	goto (DATA_ALIGN);
	      endcase
		  end
	  end

	MEMORY8:
	  begin
      if (memreq.func==MR_LOAD && memreq.func2==MR_LDOO) begin
       	if (strips != 2'd3) begin
      		strips <= strips + 2'd1;
	    		goto (MEMORY3);
	    	end
	    	else
	    		goto(DATA_ALIGN);
      end
      else
	    	goto (MEMORY9);
	    xlaten <= TRUE;
	    dadr <= {dadr[AWID-1:4] + 2'd1,4'd0};
	    //tEA({ea[AWID-1:4] + 2'd1,4'd0});
	  end
  
	// Wait a couple of clocks for MR_TLB lookup
	MEMORY9:
		begin
	  	goto (MEMORY10);
		end
`ifdef SUPPORT_KEYCHK
	MEMORY10:
		begin
		  goto (MEMORY_KEYCHK2);
		end
 
	MEMORY_KEYCHK2:
  	begin
  		if (!kyhit)
  			gosub(KYLD);
			else begin
				goto (KEYCHK_ERR);
				for (n = 0; n < 8; n = n + 1)
					if (kyut == keys[n] || kyut==20'd0)
						goto(MEMORY11);
			end
    	if (memreq.func==MR_CACHE)
      	tPMAEA();
  	end
`else
	MEMORY10:
	  goto (MEMORY11);
`endif

	MEMORY11:		// Allow time for lookup
		goto (MEMORY11a);

	MEMORY11a:
	  begin
	    xlaten <= FALSE;
	    dwait <= 3'd0;
	//    dadr <= adr_o;
	    goto (MEMORY12);
	  	if (tlbmiss) begin
	  		tDeactivateBus();
	  		fault_code <= FLT_DPF;
	  		miss_adr <= tlbmiss_adr;
	  		goto (PFETCH1);
	  	end
			else begin
				if (dhit && (memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==MR_MOVLD || memreq.func==M_JALI/*|| memreq.func==RTS2*/) && dce && tlbacr[3])
		 			tDeactivateBus();
				else begin
	      	stb_o <= HIGH;
		      for (n = 0; n < 16; n = n + 1)
		      	sel_o[n] <= sel[n+16];
//	      	sel_o <= sel[31:16];
	      	dat_o <= dat[255:128];
	    	end
	    end
	  end

	MEMORY12:
	  if (dhit & dce & tlbacr[3]) begin
	    tDeactivateBus();
	  	datil <= dc_line;
			if (memreq.func==MR_STORE || memreq.func==MR_MOVST || memreq.func==M_CALL) begin
				if (ack_i) begin
	  			dci <= (dc_line & stmask) | ((dat << {adr_o[5:4],7'b0}) & ~stmask);
	  			dc_wway <= dc_rway;
	  			dcache_wr <= TRUE;
		      goto (MEMORY13);
		      stb_o <= LOW;
		    end
			end
	  	else begin
	    	dwait <= dwait + 2'd1;
	    	if (dwait==3'd2)
	      	goto (MEMORY13);
	    end
		end
	  else if (ack_i) begin
	    goto (MEMORY13);
	    dati[255:128] <= dat_i;
	    tDeactivateBus();
	  end

	MEMORY13:
	  if (~ack_i) begin
	    begin
	      case(memreq.func)
	      MR_LOAD,MR_LOADZ,MR_MOVLD,M_JALI://,RTS2:
	      	begin
	      		if (dhit & dce & tlbacr[3])
	      			dati <= datil >> {adr_o[5:3],6'b0};
		        goto (DATA_ALIGN);
	      	end
		    MR_STORE,MR_MOVST,M_CALL:
		    	begin
		    		if (memreq.func2==MR_STPTR) begin	// STPTR
				    	if (~|ea[AWID-5:0]) begin
				  			memresp.step <= memreq.step;
				    	 	memresp.cmt <= TRUE;
				  			memresp.tid <= memreq.tid;
				  			memresp.wr <= TRUE;
								memresp.res <= {127'd0,rb_i};
					    	ret();
				    	end
				    	else begin
				    		shr_ma <= shr_ma + 4'd9;
				    		zero_data <= TRUE;
				    		goto (MEMORY2);
				    	end
		    		end
		    		else begin
			  			memresp.step <= memreq.step;
			    	 	memresp.cmt <= TRUE;
			  			memresp.tid <= memreq.tid;
			  			memresp.wr <= TRUE;
							memresp.res <= {127'd0,rb_i};
			    	ret();
			      end
		    	end
	      default:
	        goto (DATA_ALIGN);
	      endcase
	    end
	  end

	DATA_ALIGN:
	  begin
	  	tDeactivateBus();
	  	if ((memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==M_JALI || memreq.func==MR_MOVLD/*|| memreq.func==RTS2*/) & ~dhit & dcachable & tlbacr[3] & dce)
	  		goto (DFETCH2);
	  	else if (memreq.func==MR_MOVLD) begin
	  		memreq.func <= MR_MOVST;
	  		goto (MEMORY2);
	  	end
	  	else
	    	ret();
			memresp.step <= memreq.step;
	    memresp.cmt <= TRUE;
			memresp.tid <= memreq.tid;
			memresp.wr <= TRUE;
			sr_o <= LOW;
	    case(memreq.func)
	    MR_LOAD,MR_MOVLD:
	    	begin
		    	case(memreq.func2)
		    	MR_LDB:	begin memresp.res <= {{120{datis[7]}},datis[7:0]}; end
		    	MR_LDW:	begin memresp.res <= {{112{datis[15]}},datis[15:0]}; end
		    	MR_LDT:	begin memresp.res <= {{96{datis[31]}},datis[31:0]}; end
		    	MR_LDO:	begin memresp.res <= {{64{datis[63]}},datis[63:0]}; end
		    	MR_LDH:	begin memresp.res <= datis[127:0]; end
		    	MR_LDOR:	begin memresp.res <= {{64{datis[63]}},datis[63:0]}; end
		    	MR_LDOB:	begin memresp.res <= {{64{datis[63]}},datis[63:0]}; end
		    	MR_LDOO:	begin memresp.res <= dati512; end
		    	default:	memresp.res <= 256'h0;
		    	endcase
	    	end
	    MR_LOADZ:
	    	begin
		    	case(memreq.func2)
		    	MR_LDB:	begin memresp.res <= {120'd0,datis[7:0]}; end
		    	MR_LDW:	begin memresp.res <= {112'd0,datis[15:0]}; end
		    	MR_LDT:	begin memresp.res <= {96'd0,datis[31:0]}; end
		    	MR_LDO:	begin memresp.res <= {64'd0,datis[63:0]}; end
		    	MR_LDH:	begin memresp.res <= datis[127:0]; end
		    	MR_LDOR:	begin memresp.res <= {64'd0,datis[63:0]}; end
		    	MR_LDOB:	begin memresp.res <= {64'd0,datis[63:0]}; end
		    	MR_LDOO:	begin memresp.res <= dati512; end
		    	default:	memresp.res <= 128'h0;
		    	endcase
	    	end
	    M_JALI:
	    	begin
		    	case(memreq.func)
		    	MR_LDB:	begin memresp.res <= {{56{datis[7]}},datis[7:0]}; end
		    	MR_LDW:	begin memresp.res <= {{48{datis[15]}},datis[15:0]}; end
		    	MR_LDT:	begin memresp.res <= {{32{datis[31]}},datis[31:0]}; end
		    	MR_LDO:	begin memresp.res <= datis[63:0]; end
		    	default:	memresp.res <= 128'h0;
		    	endcase
		    end
//    	RTS2:	begin memresp.res <= datis[63:0]; memresp.ret <= TRUE; end
	    default:  ;
	    endcase
	  end

	// Complete TLB access cycle
	TLB1:
		goto (TLB2);	// Give time for MR_TLB to process
	TLB2:
		goto (TLB3);	// Give time for MR_TLB to process
	TLB3:
		begin
			memresp.step <= memreq.step;
	    memresp.res <= tlbdato;
	    memresp.cmt <= TRUE;
			memresp.tid <= memreq.tid;
			memresp.wr <= TRUE;
	   	ret();
		end

	// Use ipo to hold onto the original ip value. The ip value might
	// change during a cache load due to a branch. We also want the start
	// of the cache line identified as the access will span into the next
	// cache line.
	IFETCH0:
		begin
			ipo <= {ip[$bits(Address)-1:6],6'b0};
			iadr <= {ip[$bits(Address)-1:6],6'b0};
			goto (IFETCH1);
			for (n = 0; n < 5; n = n + 1) begin
				if (ivtag[n]==ip[AWID-1:6] && ivvalid[n]) begin
					vcn <= n;
		    	goto (IFETCH4);
	    	end
			end
		end
	// Hardware subroutine to fetch instruction cache line
	IFETCH1:
	  if (!ack_i) begin
	  	// Cache miss, select an entry in the victim cache to
	  	// update.
			ivcnt <= ivcnt + 2'd1;
			if (ivcnt>=3'd4)
				ivcnt <= 3'd0;
			ivcache[ivcnt] <= ic_line;
			ivtag[ivcnt] <= ic_tag;
			ivvalid[ivcnt] <= TRUE;
	  	vpa_o <= HIGH;
	  	bte_o <= 2'b00;
	  	cti_o <= 3'b001;	// constant address burst cycle
	    cyc_o <= HIGH;
			stb_o <= HIGH;
	    sel_o <= 16'hFFFF;
  		goto (IFETCH2);
	  end
	IFETCH2:
	  begin
	  	stb_o <= HIGH;
	  	if (tlbmiss) begin
	  		tDeactivateBus();
	  		fault_code <= FLT_CPF;
	  		miss_adr <= tlbmiss_adr;
	  		goto (PFETCH1);
	  	end
	    else if (ack_i) begin
	      ici <= {dat_i,ici[639:128]};	// shift in the data
	      icnt <= icnt + 4'd4;					// increment word count
	      if (icnt[4:2]==3'd4) begin		// Are we done?
	      	tDeactivateBus();
	      	iaccess <= FALSE;
	      	goto (IFETCH3);
	    	end
	    	else if (!bok_i) begin				// burst mode supported?
	    		cti_o <= 3'b000;						// no, use normal cycles
	    		goto (IFETCH6);
	    	end
	    end
	    /*
		  // PMA Check
		  // Abort cycle that has already started.
		  for (n = 0; n < 8; n = n + 1)
		    if (adr_o[31:4] >= PMA_LB[n] && adr_o[31:4] <= PMA_UB[n]) begin
		      if (!PMA_AT[n][0]) begin
		        //memresp.cause <= 16'h803D;
		        tDeactivateBus();
		    	end
		    end
			*/
		end
	IFETCH3:
		begin
		  ic_wway <= waycnt;
		  xlaten <= FALSE;
		  ret();
		end
	IFETCH3a:
		begin
			ret();
		end
	
	IFETCH4:
		goto (IFETCH5);		// delay for block ram read
	IFETCH5:
		begin
			ici <= {96'd0,ivcache[vcn]};
			ivcache[vcn] <= ic_line;
			ivtag[vcn] <= ic_tag;
			ivvalid[vcn] <= `VAL;
			goto (IFETCH3);
		end

	IFETCH6:
		begin
			stb_o <= LOW;
			if (!ack_i)	begin							// wait till consumer ready
				inext <= TRUE;
				goto (IFETCH2);
			end
		end

	DFETCH2:
	  begin
	    goto(DFETCH3);
	  end
	DFETCH3:
	  begin
	 		xlaten <= FALSE;
		  begin
	  		goto (DFETCH4);
		  	if (tlbmiss) begin
		  		tDeactivateBus();
		  		fault_code <= FLT_DPF;
		  		miss_adr <= tlbmiss_adr;
		  		goto (PFETCH1);
		  	end
			  // First time in, set to miss address, after that increment
	      dadr <= {adr_o[AWID-1:6],6'h0};
		  end
	  end

	// Initiate burst access
	DFETCH4:
	  if (!ack_i) begin
	  	vda_o <= HIGH;
	  	bte_o <= 2'b00;
	  	cti_o <= 3'b001;	// constant address burst cycle
	    cyc_o <= HIGH;
			stb_o <= HIGH;
	    sel_o <= 16'hFFFF;
	    goto (DFETCH5);
	  end

	// Sustain burst access
	DFETCH5:
	  begin
	  	daccess <= FALSE;
	  	stb_o <= HIGH;
	    if (ack_i) begin
	    	dcnt <= dcnt + 4'd4;
	      dci <= {dat_i,dci[639:128]};
	      if (dcnt[4:2]==3'd4) begin		// Are we done?
	      	tDeactivateBus();
	      	goto (DFETCH7);
	    	end
	    	if (!bok_i) begin							// burst mode supported?
	    		cti_o <= 3'b000;						// no, use normal cycles
	    		goto (DFETCH6);
	    	end
	    end
	  end
  
  // Increment address and bounce back for another read.
  DFETCH6:
		begin
			stb_o <= LOW;
			if (!ack_i)	begin							// wait till consumer ready
				inext <= TRUE;
				goto (DFETCH5);
			end
		end

	// Trgger a data cache update. The data cache line is in dci. The only thing
	// left to do is update the tag and valid status.
	DFETCH7:
	  begin
    	dcache_wr <= TRUE;
    	dc_wway <= lfsr_o[1:0];
    	case(lfsr_o[1:0])
    	2'd0:	dctag0[dadr[12:6]] <= dadr[AWID-1:6];
    	2'd1:	dctag1[dadr[12:6]] <= dadr[AWID-1:6];
    	2'd2:	dctag2[dadr[12:6]] <= dadr[AWID-1:6];
    	2'd3:	dctag3[dadr[12:6]] <= dadr[AWID-1:6];
    	endcase
    	case(lfsr_o[1:0])
    	2'd0:	dcvalid0[dadr[12:6]] <= 1'b1;
    	2'd1:	dcvalid1[dadr[12:6]] <= 1'b1;
    	2'd2:	dcvalid2[dadr[12:6]] <= 1'b1;
    	2'd3:	dcvalid3[dadr[12:6]] <= 1'b1;
    	endcase
    	ret();
	  end

	// Hardware subroutine to load keys.
`ifdef SUPPORT_KEYCHK
	KYLD:
	  begin
	    //tEA(keytbl);
			goto (KYLD2);
	  end
	KYLD2:
		goto (KYLD3);

	KYLD3:
	  begin
	 		xlaten <= FALSE;
		  begin
	  		goto (KYLD4);
		  	if (tlbmiss) begin
		  		tDeactivateBus();
		  		fault_code <= FLT_DPF;
		  		miss_adr <= tlbmiss_adr;
		  		goto (PFETCH1);
		  	end
				else
				  // First time in, set to miss address, after that increment
				  daccess <= TRUE;
	      dadr <= {adr_o[AWID-1:5],6'h0};
		  end
	  end

	KYLD4:
	  if (!ack_i) begin
	  	vda_o <= HIGH;
	  	bte_o <= 2'b00;
	  	cti_o <= 3'b001;
	    cyc_o <= HIGH;
			stb_o <= HIGH;
	    sel_o <= 16'hFFFF;
	    goto (KYLD5);
	  end

	KYLD5:
	  begin
	  	stb_o <= HIGH;
	    if (ack_i) begin
	    	dcnt <= dcnt + 4'd4;
	      dci <= {dat_i,dci[511:128]};
	      if (dcnt[4:2]==3'd3) begin		// Are we done?
	      	tDeactivateBus();
	      	goto (KYLD7);
	    	end
	    	if (!bok_i) begin							// burst mode supported?
	    		cti_o <= 3'b000;						// no, use normal cycles
	    		goto (KYLD6);
	    	end
	    end
	  end

	KYLD6:
		begin
			stb_o <= LOW;
			if (!ack_i)	begin							// wait till consumer ready
				inext <= TRUE;
				goto (KYLD5);
			end
		end

	KYLD7:
	  begin
	  	kytag[dadr[11:6]] <= dadr[AWID-1:6];
	  	kyline[dadr[11:6]] <= dci;
	  	kyv[dadr[11:6]] <= 1'b1;
	  	ret();
	  end
`endif

	PFETCH1:
	  begin
	    dadr <= pta + {fnHash(ASID,miss_adr),7'h0};
			goto (PFETCH2);
	  end
	PFETCH2:
		goto (PFETCH3);

	PFETCH3:
		begin
	 		xlaten <= FALSE;
			daccess <= TRUE;
			iaccess <= FALSE;
			dcnt <= 'd0;
	  	vpa_o <= HIGH;
	  	bte_o <= 2'b00;
	  	cti_o <= 3'b001;	// constant address burst cycle
	    cyc_o <= HIGH;
			stb_o <= HIGH;
	    sel_o <= 16'hFFFF;
  		goto (PFETCH4);
		end
	PFETCH4:
		begin
  		stb_o <= HIGH;
	    if (ack_i) begin
	      ptg <= {dat_i,ptg[1023:128]};	// shift in the data
	      dcnt <= dcnt + 4'd4;					// increment word count
	      if (dcnt[4:2]==3'd7) begin		// Are we done?
	      	tDeactivateBus();
	      	daccess <= FALSE;
	      	goto (PFETCH6);
	    	end
	    	else if (!bok_i) begin				// burst mode supported?
	    		cti_o <= 3'b000;						// no, use normal cycles
	    		goto (PFETCH5);
	    	end
	    end
  	end
  // Increment address and bounce back for another read.
  PFETCH5:
		begin
			stb_o <= LOW;
			if (!ack_i)	begin							// wait till consumer ready
				inext <= TRUE;
				goto (PFETCH4);
			end
		end
	PFETCH6:
		begin
			dadr <= pta + {ptg.link,7'h0};
	 		xlaten <= FALSE;
	    if (ptg.link=='d0)
	    	tPageFault(fault_code,miss_adr);
	    else
	    	goto (PFETCH2);
			for (k = 0; k < 6; k = k + 1) begin
				if (ptg.ptes[k].vpn==miss_adr[31:12] && (ptg.ptes[k].g || ptg.ptes[n].asid==ASID) && ptg.ptes[k].v) begin
					tmptlbe.asid <= ASID;
					tmptlbe.vpn <= miss_adr[31:12];
					tmptlbe.ppn <= ptg.ptes[k].ppn;
					tmptlbe.g <= ptg.ptes[k].g;
					tmptlbe.sc <= ptg.ptes[k].sc;
					tmptlbe.sr <= ptg.ptes[k].sr;
					tmptlbe.sw <= ptg.ptes[k].sw;
					tmptlbe.sx <= ptg.ptes[k].sx;
					tmptlbe.d <= ptg.ptes[k].d;
					tmptlbe.u <= ptg.ptes[k].u;
					tmptlbe.s <= ptg.ptes[k].s;
					tmptlbe.a <= 1'b1;
					tmptlbe.c <= ptg.ptes[k].c;
					tmptlbe.r <= ptg.ptes[k].r;
					tmptlbe.w <= ptg.ptes[k].w;
					tmptlbe.x <= ptg.ptes[k].x;
					tmptlbe.pl <= ptg.ptes[k].pl;
					tmptlbe.v <= 1'b1;
					goto (PFETCH7);
				end					
			end
		end
	PFETCH7:
		begin
			tlbwr <= 1'b1;
			tlb_ia[63] <= 1'b1;	// write to tlb
			tlb_ia[15] <= 1'b1;	// write a random way
			tlb_ia[9:0] <= miss_adr[21:12];
			tlb_ib <= tmptlbe;
			goto (PFETCH8);
		end
	// Delay a couple of cycles to allow TLB update
	PFETCH8:
		begin
			tlbwr <= 1'b0;
			goto (PFETCH9);
		end
	PFETCH9:
		ret();

	default:
		goto (MEMORY1);
	endcase
end

task tPageFault;
input [7:0] typ;
input Address ba;
begin
	memresp.step <= memreq.step;
	memresp.cmt <= TRUE;
  memresp.cause <= 16'h8000|typ;
	memresp.tid <= memreq.tid;
  memresp.badAddr <= ba;
  memresp.wr <= TRUE;
	memresp.res <= 128'd0;
	tDeactivateBus();
	goto (MEMORY1);
end
endtask

task tWriteViolation;
input Address ba;
begin
	memresp.step <= memreq.step;
	memresp.cmt <= TRUE;
  memresp.cause <= 16'h8000|FLT_WRV;
	memresp.tid <= memreq.tid;
  memresp.badAddr <= ba;
  memresp.wr <= TRUE;
	memresp.res <= 128'd0;
	tDeactivateBus();
	goto (MEMORY1);
end
endtask

task tReadViolation;
input Address ba;
begin
	memresp.step <= memreq.step;
	memresp.cmt <= TRUE;
  memresp.cause <= 16'h8000|FLT_RDV;
	memresp.tid <= memreq.tid;
  memresp.badAddr <= ba;
  memresp.wr <= TRUE;
	memresp.res <= 128'd0;
	tDeactivateBus();
	goto (MEMORY1);
end
endtask

/*
task tEA;
input Address iea;
begin
  if ((memreq.func==MR_STORE || memreq.func==MR_MOVST || memreq.func==M_CALL) && !ea_acr.w)
  	tWriteViolation(iea);
  else if ((memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==MR_MOVLD || memreq.func==M_JALI || memreq.func==RTS2) && !ea_acr.r)
  	tReadViolation(iea);
//	if (iea[AWID-1:24]=={AWID-24{1'b1}})
//		dadr <= iea;
//	else
		dadr <= iea;
	dcachable <= ea_acr.c;
end
endtask
*/

task tPMAEA;
begin
  if (keyViolation && omode == 2'd0)
    memresp.cause <= {8'h80,FLT_KEY};
  // PMA Check
  for (n = 0; n < 8; n = n + 1)
    if (adr_o[31:4] >= PMA_LB[n] && adr_o[31:4] <= PMA_UB[n]) begin
      if (((memreq.func==MR_STORE || memreq.func==MR_MOVST) && !PMA_AT[n][1]) || ((memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==MR_MOVLD || memreq.func==M_JALI /*|| memreq.func==RTS2*/) && !PMA_AT[n][2]))
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

task tDeactivateBus;
begin
	vpa_o <= LOW;			//
	vda_o <= LOW;
	cti_o <= 3'b000;	// Normal cycles again
	cyc_o <= LOW;
	stb_o <= LOW;
	we_o <= LOW;
	sel_o <= 16'h0000;
  xlaten <= FALSE;
end
endtask

task goto;
input [5:0] nst;
begin
	state <= nst;
end
endtask

task gosub;
input [5:0] nst;
begin
	stk_state1 <= state;
	stk_state2 <= stk_state1;
	stk_state3 <= stk_state2;
	state <= nst;
end
endtask

task ret;
begin
	state <= stk_state1;
	stk_state1 <= stk_state2;
	stk_state2 <= stk_state3;
end
endtask

endmodule
