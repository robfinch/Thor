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
import Thor2022_mmupkg::*;

module Thor2022_biu(rst,clk,tlbclk,UserMode,MUserMode,omode,ASID,bounds_chk,pe,
	ip,ihit,ifStall,ic_line,
	fifoToCtrl_i,fifoToCtrl_full_o,fifoFromCtrl_o,fifoFromCtrl_rd,fifoFromCtrl_empty,fifoFromCtrl_v,
	bok_i, bte_o, cti_o, vpa_o, vda_o, cyc_o, stb_o, ack_i, we_o, sel_o, adr_o,
	dat_i, dat_o, sr_o, cr_o, rb_i, dce, keys, arange, ptbr);
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
input Address ptbr;

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
parameter HIGH = 1'b1;
parameter LOW = 1'b0;

parameter IO_KEY_ADR	= 16'hFF88;

integer m,n,k;
genvar g;

reg [5:0] shr_ma;

reg [6:0] state;
// States for hardware routine stack, five deep.
// States go at least 3 deep.
// Memory1
// PT_FETCH <on a tlbmiss>
// READ_PDE/PTE
// 
reg [6:0] stk_state1, stk_state2, stk_state3, stk_state4, stk_state5;

reg xlaten_stk;
reg vpa_stk;
reg vda_stk;
reg [1:0] bte_stk;
reg [2:0] cti_stk;
reg cyc_stk;
reg stb_stk;
reg we_stk;
reg [15:0] sel_stk;
Address adro_stk;
Address dadr_stk;
Address iadr_stk;
reg [127:0] dato_stk;

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

Address ea;
Address afilt;

always_comb
	afilt = (memreq.func==MR_MOVST) ? memreq.dat : memreq.adr;

always_comb
 	ea = afilt >> shr_ma;

reg [7:0] ealow;

reg [1:0] strips;
reg [63:0] sel;
reg [63:0] nsel;
reg [511:0] dati512;
reg [255:0] dat, dati;
wire [127:0] datis;

biu_dati_align uda1
(
	.dati(dati),
	.datis(datis), 
	.amt({1'b0,ealow[3:0],3'b0})
);

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
wire [511:0] stmask;

Thor2022_stmask ustmsk (sel_o, adr_o[5:4], stmask);


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

reg [1:0] ic_rway,ic_wway;
reg icache_wr;
always_comb icache_wr = state==IFETCH3;
reg ic_invline,ic_invall;
Address ipo;
wire [AWID-1:6] ictag [0:511];
wire [512/4-1:0] icvalid [0:3];

reg [639:0] ici;		// Must be a multiple of 128 bits wide for shifting.
wire [AWID-7:0] ic_tag;
reg [2:0] ivcnt;
reg [2:0] vcn;
reg [pL1ICacheLineSize-1:0] ivcache [0:4];
reg [AWID-1:6] ivtag [0:4];
reg [4:0] ivvalid;


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

Thor2022_ictag 
#(
	.LINES(128),
	.WAYS(4),
	.AWID(AWID)
)
uictag1
(
	.clk(tlbclk),
	.wr(icache_wr),
	.ip(ipo),
	.way(waycnt),
	.tag(ictag)
);

Thor2022_ichit
#(
	.LINES(128),
	.WAYS(4),
	.AWID(AWID)
)
uichit1
(
	.clk(tlbclk),
	.ip(ip),
	.tag(ictag),
	.valid(icvalid),
	.ihit(ihit),
	.rway(ic_rway),
	.vtag(ic_tag)
);

Thor2022_icvalid 
#(
	.LINES(128),
	.WAYS(4),
	.AWID(AWID)
)
uicval1
(
	.rst(rst),
	.clk(tlbclk),
	.invce(state==MEMORY4),
	.ip(ipo),
	.adr(adr_o),
	.wr(icache_wr),
	.way(waycnt),
	.invline(ic_invline),
	.invall(ic_invall),
	.valid(icvalid)
);


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
wire [3:0] tlbacr;

reg [2:0] dwait;		// wait state counter for dcache
Address dadr;
reg [511:0] dci;		// 512 + 120 bit overflow area
wire [511:0] dc_eline, dc_oline;
reg [1023:0] dc_line;
reg [511:0] datil;
reg dcachable;
reg [1:0] dc_erway,prev_dc_erway;
reg [1:0] dc_orway,prev_dc_orway;
wire [1:0] dc_ewway;
wire [1:0] dc_owway;
reg dcache_ewr, dcache_owr;
reg dc_invline,dc_invall;

dcache_blkmem udcb1e (
  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(dcache_ewr),      // input wire [0 : 0] wea
  .addra({dc_ewway,dadr[13:7]}),  // input wire [8 : 0] addra
  .dina(dci),    // input wire [511 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb({dc_erway,adr_o[13:7]+adr_o[6]}),  // input wire [8 : 0] addrb
  .doutb(dc_eline)  // output wire [511 : 0] doutb
);

dcache_blkmem udcb1o (
  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(dcache_owr),      // input wire [0 : 0] wea
  .addra({dc_owway,dadr[13:7]}),  // input wire [8 : 0] addra
  .dina(dci),    // input wire [511 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb({dc_orway,adr_o[13:7]}),  // input wire [8 : 0] addrb
  .doutb(dc_oline)  // output wire [511 : 0] doutb
);

always_comb
	case(adr_o[6])
	1'b0:	dc_line = {dc_oline,dc_eline};
	1'b1:	dc_line = {dc_eline,dc_oline};
	endcase

wire [AWID-7:0] dc_etag [511:0];
wire [127:0] dc_evalid [0:3];
wire [3:0] dhit1e;
wire [AWID-7:0] dc_otag [511:0];
wire [127:0] dc_ovalid [0:3];
wire [3:0] dhit1o;

Thor2022_dchit udchite
(
	.clk(clk),
	.tags(dc_etag),
	.ndx(adr_o[13:7]+adr_o[6]),
	.adr(adr_o),
	.valid(dc_evalid),
	.hits(dhit1e),
	.hit(dhite),
	.rway(dc_erway)
);

Thor2022_dchit udchito
(
	.clk(clk),
	.tags(dc_otag),
	.ndx(adr_o[13:7]),
	.adr(adr_o),
	.valid(dc_ovalid),
	.hits(dhit1o),
	.hit(dhito),
	.rway(dc_orway)
);

reg dhit;
always_comb
	dhit = (dhite & dhito) || (adr_o[6] ? (dhito && adr_o[5:4] != 2'b11) : (dhite && adr_o[5:4] != 2'b11));

Thor2022_dctag
#(
	.LINES(128),
	.WAYS(4),
	.AWID(AWID)
)
udcotag
(
	.clk(clk),
	.wr(state==DFETCH7 && dadr[6]),
	.adr(dadr),
	.way(lfsr_o[1:0]),
	.tag(dc_otag)
);

Thor2022_dctag
#(
	.LINES(128),
	.WAYS(4),
	.AWID(AWID)
)
udcetag
(
	.clk(clk),
	.wr(state==DFETCH7 && ~dadr[6]),
	.adr(dadr),
	.way(lfsr_o[1:0]),
	.tag(dc_etag)
);

Thor2022_dcvalid
#(
	.LINES(128),
	.WAYS(4),
	.AWID(AWID)
)
udcovalid
(
	.rst(rst),
	.clk(clk),
	.invce(state==MEMORY4 && adr_o[6]),
	.dadr(dadr),
	.adr(adr_o),
	.wr(state==DFETCH7 && dadr[6]),
	.way(lfsr_o[1:0]),
	.invline(dc_invline),
	.invall(dc_invall),
	.valid(dc_ovalid)
);

Thor2022_dcvalid
#(
	.LINES(128),
	.WAYS(4),
	.AWID(AWID)
)
udcevalid
(
	.rst(rst),
	.clk(clk),
	.invce(state==MEMORY4 && ~adr_o[6]),
	.dadr(dadr),
	.adr(adr_o),
	.wr(state==DFETCH7 && ~dadr[6]),
	.way(lfsr_o[1:0]),
	.invline(dc_invline),
	.invall(dc_invall),
	.valid(dc_evalid)
);

Thor2022_dcache_wr udcwre
(
	.clk(clk),
	.state(state),
	.ack(ack_i),
	.func(memreq.func),
	.dce(dce),
	.hit(dhit),
	.inv(ic_invline|ic_invall|dc_invline|dc_invall),
	.acr(tlbacr),
	.eaeo(~ealow[6]),
	.daeo(dadr[6]),
	.wr(dcache_ewr)
);

Thor2022_dcache_wr udcwro
(
	.clk(clk),
	.state(state),
	.ack(ack_i),
	.func(memreq.func),
	.dce(dce),
	.hit(dhit),
	.inv(ic_invline|ic_invall|dc_invline|dc_invall),
	.acr(tlbacr),
	.eaeo(ealow[6]),
	.daeo(~dadr[6]),
	.wr(dcache_owr)
);

Thor2022_dcache_way udcwaye
(
	.clk(clk),
	.state(state),
	.ack(ack_i),
	.func(memreq.func),
	.dce(dce),
	.hit(dhit),
	.inv(ic_invline|ic_invall|dc_invline|dc_invall),
	.acr(tlbacr),
	.eaeo(~ealow[6]),
	.daeo(dadr[6]),
	.lfsr(lfsr_o[1:0]),
	.rway(dc_erway),
	.wway(dc_ewway)
);

Thor2022_dcache_way udcwayo
(
	.clk(clk),
	.state(state),
	.ack(ack_i),
	.func(memreq.func),
	.dce(dce),
	.hit(dhit),
	.inv(ic_invline|ic_invall|dc_invline|dc_invall),
	.acr(tlbacr),
	.eaeo(ealow[6]),
	.daeo(~dadr[6]),
	.lfsr(lfsr_o[1:0]),
	.rway(dc_orway),
	.wway(dc_owway)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// TLB
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

PTE tmptlbe;
reg [5:0] ipt_miss_count;
reg tlben, tlbwr;
wire tlbmiss;
wire tlbrdy;
PTE tlbdato;
reg [31:0] tlb_ia;
PTE tlb_ib;
reg inext;
VirtualAddress tlbmiss_adr;
VirtualAddress miss_adr;
reg wr_ptg;

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
  .tlbdat_i(tlb_ib),
  .tlbdat_o(tlbdato),
  .tlbmiss_o(tlbmiss),
  .tlbmiss_adr_o(tlbmiss_adr)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// IPT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

reg [7:0] fault_code;
PTG ptg;
PTE tmptlbe2;
reg pte_found;
wire [15:0] hash;

Thor2022_ipt_hash uhash
(
	.asid(ASID),
	.adr(miss_adr),
	.hash(hash)
);

Thor2022_ptg_search uptgs
(
	.ptg(ptg),
	.asid(ASID),
	.miss_adr(miss_adr),
	.pte(tmptlbe2),
	.found(pte_found)
);

integer j;
reg [9:0] square_table [0:15];
initial begin
	for (j = 0; j < 16; j = j + 1)
		square_table[j] = j * j;
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// PT
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Page table vars
reg [2:0] dep;
reg [8:0] adr_slice;
PDE pde;
reg wr_pte;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// State Machine
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always_ff @(posedge clk)
if (rst) begin
	dce <= FALSE;
	zero_data <= FALSE;
	dcachable <= TRUE;
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
	dwait <= 3'd0;
	iaccess <= FALSE;
	daccess <= FALSE;
	ici <= 512'd0;
	dci <= 512'd0;
	ptg <= 'd0;
	memreq_rd <= FALSE;
	memresp <= 'd0;
  xlaten <= FALSE;
  tmptlbe <= 'd0;
  wr_pte <= 1'b0;
  wr_ptg <= 1'b0;
	goto (MEMORY_INIT);
end
else begin
	inext <= FALSE;
//	memreq_rd <= FALSE;
	memresp.wr <= FALSE;
	tlbwr <= FALSE;

	case(state)
	MEMORY_INIT:
		begin
			goto (MEMORY_IDLE);
		end

	MEMORY_IDLE:
		tMemoryIdle();

	MEMORY1:
		if (fifoToCtrl_v) begin
			memreq_rd <= FALSE;
			memreq <= imemreq;
			goto (MEMORY_DISPATCH);
		end

	MEMORY_DISPATCH:
		tMemoryDispatch();
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
		tKeyCheck(MEMORY5);
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
		goto (MEMORY_ACTIVATE_LO);

	MEMORY_ACTIVATE_LO:
		tMemoryActivateLo();

	MEMORY_ACKLO:
		tMemoryAckLo();

	MEMORY_NACKLO:
		tMemoryNackLo();

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
	    tEA({ea[AWID-1:4] + 2'd1,4'd0});
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
		tKeyCheck(MEMORY11);
`else
	MEMORY10:
	  goto (MEMORY11);
`endif

	MEMORY11:		// Allow time for lookup
		goto (MEMORY_ACTIVATE_HI);

	MEMORY_ACTIVATE_HI:
		tMemoryActivateHi();

	MEMORY_ACKHI:
		tMemoryAckHi();

	MEMORY13:
		tMemoryNackHi();

	DATA_ALIGN:
		tDataAlign();

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Complete TLB access cycle
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	TLB1:
		goto (TLB2);	// Give time for MR_TLB to process
	TLB2:
		goto (TLB3);	// Give time for MR_TLB to process
	TLB3:
		begin
			memresp.step <= memreq.step;
	    memresp.res <= {432'd0,tlbdato};
	    memresp.cmt <= TRUE;
			memresp.tid <= memreq.tid;
			memresp.wr <= TRUE;
	   	ret();
		end

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Hardware subroutine to load an instruction cache line.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
	  		tPushBus();
	  		tDeactivateBus();
	  		fault_code <= FLT_CPF;
	  		miss_adr <= tlbmiss_adr;
	  		gosub (ptbr[0] ? PT_FETCH1 : IPT_FETCH1);
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

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
		  		tPushBus();
		  		tDeactivateBus();
		  		fault_code <= FLT_DPF;
		  		miss_adr <= tlbmiss_adr;
		  		gosub (ptbr[0] ? PT_FETCH1 : IPT_FETCH1);
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
	      dci <= {dat_i,dci[511:128]};
	      if (dcnt[4:2]==3'd3) begin		// Are we done?
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
			xlaten <= xlaten_stk;
    	goto (DFETCH8);
	  end
	DFETCH8:
		goto (DFETCH9);
	DFETCH9:
		begin
			goto (DFETCH2);
			if (dhit) begin
				tPopBus();
				ret();
			end
			// If got a hit on the even address, the odd one must be missing
			else if (dhite)
				dadr <= {ea[AWID-1:7],1'b1,6'h0};
			// Otherwise the even one must be missing
			else
				dadr <= {ea[AWID-1:6]+ea[6],6'h0};
		end

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Hardware subroutine to load keys.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
`ifdef SUPPORT_KEYCHK
	KYLD:
	  begin
	    tEA(keytbl);
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
		  		tPushBus();
		  		tDeactivateBus();
		  		fault_code <= FLT_DPF;
		  		miss_adr <= tlbmiss_adr;
		  		gosub (ptbr[0] ? PT_FETCH1 : IPT_FETCH1);
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

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Hardware subroutine to find an address translation and update the TLB.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// 
	IPT_FETCH1:
		begin
			// Open addressing with quadratic probing
//			dadr <= ptbr + {ptg.link,7'h0};
			dadr <= ptbr + ({(hash + square_table[ipt_miss_count]) & 16'hFFFF,6'h0});//ptbr + {ptg.link,7'h0};
	 		xlaten <= FALSE;
	 		wr_ptg <= 1'b0;
	    if (ipt_miss_count==6'd12)
	    	tPageFault(fault_code,miss_adr);
	    else
	    	gosub (IPT_RW_PTG2);
	    if (pte_found) begin
	    	tlb_ib <= tmptlbe2;
	    	goto (IPT_FETCH2);
	    end
		end
	IPT_FETCH2:
		begin
			tlbwr <= 1'b1;
			tlb_ia <= 'd0;
			tlb_ia[31] <= 1'b1;	// write to tlb
			tlb_ia[15] <= 1'b1;	// write a random way
			tlb_ia[13:10] <= 4'h0;
			tlb_ia[9:0] <= miss_adr[21:12];
			tlb_ib <= tmptlbe;
			tlb_ib.a <= 1'b1;
			wr_ptg <= 1'b1;
			call (IPT_RW_PTG2,IPT_FETCH3);
		end
	// Delay a couple of cycles to allow TLB update
	IPT_FETCH3:
		begin
			tlbwr <= 1'b0;
			wr_ptg <= 1'b0;
			if (fault_code==FLT_DPF) begin
				xlaten <= xlaten_stk;
				dadr <= dadr_stk;
				goto (IPT_FETCH4);
			end
			else begin
				xlaten <= xlaten_stk;
				iadr <= iadr_stk;
			  if (!ack_i)
		  		goto (IPT_FETCH4);
			end	
		end
	IPT_FETCH4:
		goto (IPT_FETCH5);
	IPT_FETCH5:
		begin
			// Restore the bus state, it should not miss now.
			tPopBus();
			ret();
		end

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Hardware subroutine to read / write a page table group.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	IPT_RW_PTG2:
		begin
			ipt_miss_count <= ipt_miss_count + 2'd1;
			goto (IPT_RW_PTG3);
		end

	IPT_RW_PTG3:	//FETCH3:
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
	    we_o <= wr_ptg;
	    dat_o <= ptg[127:0];
  		goto (IPT_RW_PTG4);
		end
	IPT_RW_PTG4:
		begin
  		stb_o <= HIGH;
	    if (ack_i) begin
	    	if (wr_ptg) begin
	    		ptg <= {ptg[127:0],ptg[511:128]};
	    		dat_o <= ptg[255:128];
	    	end
	    	else
	      	ptg <= {dat_i,ptg[$bits(ptg)-1:128]};	// shift in the data
	      dcnt <= dcnt + 4'd4;					// increment word count
	      if (dcnt[4:2]==Thor2022_mmupkg::PtgSize/128-1) begin		// Are we done?
	      	tDeactivateBus();
	      	daccess <= FALSE;
	      	ret();
	      	//goto (IPT_FETCH6);
	    	end
	    	else if (!bok_i) begin				// burst mode supported?
	    		cti_o <= 3'b000;						// no, use normal cycles
	    		goto (IPT_RW_PTG5);
	    	end
	    end
  	end
  // Increment address and bounce back for another read.
  IPT_RW_PTG5:
		begin
			stb_o <= LOW;
			if (!ack_i)	begin							// wait till consumer ready
				inext <= TRUE;
				goto (IPT_RW_PTG4);
			end
		end

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Hardware subroutine to find an address translation and update the TLB.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	PT_FETCH1:
		begin
			dep <= ptbr[10:8];
			wr_pte <= 1'b0;
	  	case(ptbr[8:6])
	  	3'd0:	begin pde <= ptbr[31:12]; 	adr_slice <= {miss_adr[19:12],1'b0}; call (PT_RW_PTE1, PT_FETCH3); end
	  	3'd1: begin pde <= ptbr[31:12];	adr_slice <= miss_adr[28:20]; call (PT_READ_PDE1, PT_FETCH2); dep <= ptbr[10:8] - 2'd1; end // 9 bits
	  	3'd2:	begin pde <= ptbr[31:12];	adr_slice <= miss_adr[31:29]; call (PT_READ_PDE1, PT_FETCH2); dep <= ptbr[10:8] - 2'd1; end // 9 bits
//	  	3'd3:	begin pde <= ptbr[31:12];	adr_slice <= miss_adr[46:38]; call (PT_READ_PDE1, PT_FETCH2); dep <= ptbr[10:8] - 2'd1; end // 9 bits
//	  	3'd4:	begin pde <= ptbr[31:12];	adr_slice <= miss_adr[55:47]; call (PT_READ_PDE1, PT_FETCH2); dep <= ptbr[10:8] - 2'd1; end // 9 bits
	  	default:	ret();
	  	endcase
		end
	PT_FETCH2:
	  begin
	  	case(dep)
	  	3'd0:	begin adr_slice <= {miss_adr[19:12],1'b0}; call (PT_RW_PTE1, PT_FETCH3); end
	  	3'd1: begin adr_slice <= miss_adr[28:20]; gosub (PT_READ_PDE1); dep <= dep - 2'd1; end // 9 bits
	  	3'd2:	begin adr_slice <= miss_adr[31:29]; gosub (PT_READ_PDE1); dep <= dep - 2'd1; end // 9 bits
//	  	3'd3:	begin adr_slice <= miss_adr[46:38]; gosub (PT_READ_PDE1); dep <= dep - 2'd1; end // 9 bits
	  	default:	ret();
	  	endcase
	  end
	PT_FETCH3:
		begin
			tlbwr <= 1'b1;
			tlb_ia <= 'd0;
			tlb_ia[31] <= 1'b1;	// write to tlb
			tlb_ia[15] <= 1'b1;	// write a random way
			tlb_ia[13:10] <= 4'h0;
			tlb_ia[9:0] <= miss_adr[21:12];
			tlb_ib <= tmptlbe;
			tlb_ib.a <= 1'b1;
			wr_pte <= 1'b1;
			call (PT_RW_PTE1,PT_FETCH4);
		end
	PT_FETCH4:
		begin
			tlbwr <= 1'b0;
			wr_pte <= 1'b0;
			if (fault_code==FLT_DPF) begin
				xlaten <= xlaten_stk;
				dadr <= dadr_stk;
				goto (PT_FETCH5);
			end
			else begin
				xlaten <= xlaten_stk;
				iadr <= iadr_stk;
			  if (!ack_i)
		  		goto (PT_FETCH5);
			end	
		end
	// Delay a couple of cycles to allow TLB update
	PT_FETCH5:
		begin
			goto (PT_FETCH6);
		end
	PT_FETCH6:
		begin
			// Restore the bus state, it should not miss now.
			tPopBus();
			ret();
		end

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Hardware subroutine to read a PDE.
	// If the PDE is not valid then a page fault occurs.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	PT_READ_PDE1:
		begin
	 		xlaten <= FALSE;
			daccess <= TRUE;
			iaccess <= FALSE;
			dadr <= {pde[19:0],adr_slice[8:1],4'h0};
			goto (PT_READ_PDE2);
		end
	PT_READ_PDE2:
		goto (PT_READ_PDE3);
	PT_READ_PDE3:
		if (!ack_i) begin
	  	vda_o <= HIGH;
	  	bte_o <= 2'b00;
	  	cti_o <= 3'b001;	// constant address burst cycle
	    cyc_o <= HIGH;
			stb_o <= HIGH;
	    sel_o <= 16'hFFFF;
	    goto (PT_READ_PDE4);
		end
	PT_READ_PDE4:
		if (ack_i) begin
			tDeactivateBus();
			pde <= adr_slice[0] ? dat_i[127:64] : dat_i[63:0];
			goto(PT_READ_PDE5);
		end
	PT_READ_PDE5:
		begin
			if (pde.v)
				ret();
			else
				tPageFault(fault_code,miss_adr);
		end

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Hardware subroutine to read a PDE.
	// If the PDE is not valid then a page fault occurs.
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	PT_RW_PTE1:
		begin
	 		xlaten <= FALSE;
			daccess <= TRUE;
			iaccess <= FALSE;
			dadr <= {pde[19:0],adr_slice[8:1],4'h0};
			goto (PT_RW_PTE2);
		end
	PT_RW_PTE2:
		goto (PT_RW_PTE3);
	PT_RW_PTE3:
		if (!ack_i) begin
			vda_o <= HIGH;
	  	bte_o <= 2'b00;
	  	cti_o <= 3'b001;	// constant address burst cycle
	    cyc_o <= HIGH;
			stb_o <= HIGH;
			we_o <= wr_pte;
	    sel_o <= 16'hFFFF;
	    dat_o <= tmptlbe;
	    goto (PT_RW_PTE4);
		end
	PT_RW_PTE4:
		if (ack_i) begin
			tDeactivateBus();
			if (!wr_pte)
				tmptlbe <= dat_i;
			goto (PT_RW_PTE5);
		end
	PT_RW_PTE5:
		begin
			if (tmptlbe.v)
				ret();
			else
				tPageFault(fault_code,miss_adr);
		end

	default:
		goto (MEMORY_IDLE);
	endcase
end

task tMemoryIdle;
begin
	ipt_miss_count <= 'd0;
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
			gosub (MEMORY1);
		end
	end
end
endtask

task tMemoryDispatch;
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
			tlb_ib <= memreq.dat[$bits(PTE)-1:0];
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
				ret();
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
  		  	tEA(ea);
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
  		  tEA(ea);
    		xlaten <= TRUE;
    		// Setup proper select lines
	      sel <= {32'h0,memreq.sel} << ea[3:0];
	  		goto (MEMORY3);
  		end
		end
	MR_CACHE:
		begin
			ic_invline <= memreq.dat[1:0]==3'd1;
			ic_invall	<= memreq.dat[1:0]==3'd2;
			dc_invline <= memreq.dat[4:2]==3'd3;
			dc_invall	<= memreq.dat[4:2]==3'd4;
			memresp.step <= memreq.step;
			if (memreq.dat[4:2]==3'd1)
				dce <= TRUE;
			if (memreq.dat[4:2]==3'd2)
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
  		  tEA(ea);
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
  		  tEA(ea);
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
endtask

task tMemoryActivateLo;
begin
  dwait <= 3'd0;
  goto (MEMORY_ACKLO);
	if (tlbmiss) begin
		tPushBus();
		tDeactivateBus();
		fault_code <= FLT_DPF;
		miss_adr <= tlbmiss_adr;
 		gosub (ptbr[0] ? PT_FETCH1 : IPT_FETCH1);
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
   			if (tlbacr[2]) begin
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
    		if (tlbacr[1])
      		we_o <= HIGH;
      	else
      		tWriteViolation(ea);
    	end
    default:
    	tDeactivateBus();
    endcase
  end
end
endtask

task tMemoryAckLo;
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
  				if (ealow[6])
		  			dci <= (dc_oline & ~stmask) | ((dat << {adr_o[5:4],7'b0}) & stmask);
  				else
		  			dci <= (dc_eline & ~stmask) | ((dat << {adr_o[5:4],7'b0}) & stmask);
  			  goto (MEMORY_NACKLO);
		      stb_o <= LOW;
		      if (sel[31:16]==1'h0)
		      	tDeactivateBus();
		    end
  		end
    	else begin
    		dwait <= dwait + 2'd1;
    		if (dwait==3'd2)
	      	goto (MEMORY_NACKLO);
	    end
		end
  default:
    if (ack_i) begin
      goto (MEMORY_NACKLO);
      stb_o <= LOW;
      dati <= {128'd0,dat_i};
      dati512 <= {dat_i,dati512[511:128]};
      if (sel[31:16]==1'h0) begin
      	tDeactivateBus();
      end
    end
	endcase
end
endtask

task tMemoryNackLo;
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
			    		goto (MEMORY_DISPATCH);
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
endtask

task tMemoryActivateHi;
begin
  xlaten <= FALSE;
  dwait <= 3'd0;
//    dadr <= adr_o;
  goto (MEMORY_ACKHI);
	if (tlbmiss) begin
		tPushBus();
		tDeactivateBus();
		fault_code <= FLT_DPF;
		miss_adr <= tlbmiss_adr;
 		gosub (ptbr[0] ? PT_FETCH1 : IPT_FETCH1);
	end
	else begin
		if (dhit && (memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==MR_MOVLD || memreq.func==M_JALI/*|| memreq.func==RTS2*/) && dce && tlbacr[3])
 			tDeactivateBus();
		else begin
    	vda_o <= HIGH;
			cyc_o <= HIGH;
    	stb_o <= HIGH;
      for (n = 0; n < 16; n = n + 1)
      	sel_o[n] <= sel[n+16];
//	      	sel_o <= sel[31:16];
    	dat_o <= dat[255:128];
    	if (memreq.func==MR_STORE) begin
    		if (tlbacr[1])
      		we_o <= HIGH;
      	else
      		tWriteViolation(ea);
      end
  	end
  end
end
endtask

task tMemoryAckHi;
begin
  if (dhit & dce & tlbacr[3]) begin
    tDeactivateBus();
  	datil <= dc_line;
		if (memreq.func==MR_STORE || memreq.func==MR_MOVST || memreq.func==M_CALL) begin
			if (ack_i) begin
				if (ealow[6])
  				dci <= (dc_eline & ~stmask) | ((dat << {adr_o[5:4],7'b0}) & stmask);
				else
  				dci <= (dc_oline & ~stmask) | ((dat << {adr_o[5:4],7'b0}) & stmask);
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
end
endtask

task tMemoryNackHi;
begin
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
			    		goto (MEMORY_DISPATCH);
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
end
endtask

task tDataAlign;
begin
	tDeactivateBus();
	if ((memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==M_JALI || memreq.func==MR_MOVLD/*|| memreq.func==RTS2*/) & ~dhit & dcachable & tlbacr[3] & dce)
		goto (DFETCH2);
	else if (memreq.func==MR_MOVLD) begin
		memreq.func <= MR_MOVST;
		goto (MEMORY_DISPATCH);
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
endtask

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
	goto (MEMORY_IDLE);
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
	goto (MEMORY_IDLE);
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
	goto (MEMORY_IDLE);
end
endtask

`ifdef SUPPORT_KEYCHK
task tKeyCheck;
input [6:0] nst;
begin
	if (!kyhit)
		gosub(KYLD);
	else begin
		goto (KEYCHK_ERR);
		for (n = 0; n < 8; n = n + 1)
			if (kyut == keys[n] || kyut==20'd0)
				goto(nst);
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
endtask
`endif

task tEA;
input Address iea;
begin
/*
  if ((memreq.func==MR_STORE || memreq.func==MR_MOVST || memreq.func==M_CALL) && !ea_acr.w)
  	tWriteViolation(iea);
  else if ((memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==MR_MOVLD || memreq.func==M_JALI || memreq.func==RTS2) && !ea_acr.r)
  	tReadViolation(iea);
//	if (iea[AWID-1:24]=={AWID-24{1'b1}})
//		dadr <= iea;
//	else
*/
		dadr <= iea;
//	dcachable <= ea_acr.c;
end
endtask


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

task tPushBus;
begin
	xlaten_stk <= xlaten;
	vpa_stk <= vpa_o;
	vda_stk <= vda_o;
	bte_stk <= bte_o;
	cti_stk <= cti_o;
	cyc_stk <= cyc_o;
	stb_stk <= stb_o;
	we_stk <= we_o;
	sel_stk <= sel_o;
	dadr_stk <= dadr;
	iadr_stk <= iadr;
	dato_stk <= dat_o;
end
endtask

task tPopBus;
begin
	xlaten <= xlaten_stk;
	vpa_o <= vpa_stk;
	vda_o <= vda_stk;
	bte_o <= bte_stk;
	cti_o <= cti_stk;
	cyc_o <= cyc_stk;
	stb_o <= stb_stk;
	we_o <= we_stk;
	sel_o <= sel_stk;
//	dadr <= dadr_stk;
//	iadr <= iadr_stk;
	dat_o <= dato_stk;
end
endtask

task goto;
input [6:0] nst;
begin
	state <= nst;
end
endtask

task call;
input [6:0] nst;
input [6:0] rst;
begin
	goto(nst);
	stk_state1 <= rst;
	stk_state2 <= stk_state1;
	stk_state3 <= stk_state2;
	stk_state4 <= stk_state3;
	stk_state5 <= stk_state4;
end
endtask

task gosub;
input [6:0] nst;
begin
	stk_state1 <= state;
	stk_state2 <= stk_state1;
	stk_state3 <= stk_state2;
	stk_state4 <= stk_state3;
	stk_state5 <= stk_state4;
	state <= nst;
end
endtask

task ret;
begin
	state <= stk_state1;
	stk_state1 <= stk_state2;
	stk_state2 <= stk_state3;
	stk_state3 <= stk_state4;
	stk_state4 <= stk_state5;
end
endtask

endmodule

module biu_dati_align(dati, datis, amt);
input [255:0] dati;
output reg [127:0] datis;
input [7:0] amt;

reg [255:0] shift1;
reg [255:0] shift2;
reg [255:0] shift3;
reg [255:0] shift4;
always_comb
begin
	shift1 = dati >> {amt[7:6],6'd0};
	shift2 = shift1 >> {amt[5:4],4'd0};
	shift3 = shift2 >> {amt[3:2],2'd0};
	shift4 = shift3 >> amt[1:0];
	datis = shift4[127:0];
end

endmodule
