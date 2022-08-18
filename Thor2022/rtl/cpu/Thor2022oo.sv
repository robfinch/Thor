// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022oo.sv
//
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

import const_pkg::*;
import Thor2022_pkg::*;

(* keep_hierarchy="yes" *)
module Thor2022oo(hartid_i, rst_i, clk_i, clk2x_i, clk2d_i, wc_clk_i, clock,
		nmi_i, irq_i, icause_i,
		vpa_o, vda_o, bte_o, cti_o, bok_i, cyc_o, stb_o, lock_o, ack_i,
    err_i, we_o, sel_o, adr_o, dat_i, dat_o, cr_o, sr_o, rb_i, state_o, trigger_o, wcause);
input [63:0] hartid_i;
input rst_i;
input clk_i;
input clk2x_i;
input clk2d_i;
input wc_clk_i;
input clock;					// MMU clock algorithm
input nmi_i;
(* MARK_DEBUG="TRUE" *)
input [2:0] irq_i;
(* MARK_DEBUG="TRUE" *)
input [8:0] icause_i;
output vpa_o;
output vda_o;
output [1:0] bte_o;
output [2:0] cti_o;
input bok_i;
output cyc_o;
output stb_o;
output reg lock_o;
input ack_i;
input err_i;
output we_o;
output [15:0] sel_o;
output [31:0] adr_o;
input [127:0] dat_i;
output [127:0] dat_o;
output cr_o;
output sr_o;
input rb_i;
output [5:0] state_o;
output reg trigger_o;
output reg [15:0] wcause;

wire clk_g;

reg [5:0] state, state1, state2;
parameter RUN = 6'd1;
parameter RESTART1 = 6'd2;
parameter RESTART2 = 6'd3;
parameter WAIT_MEM1 = 6'd4;
parameter MUL1 = 6'd5;
parameter DIV1 = 6'd6;
parameter INVnRUN = 6'd7;
parameter DELAY1 = 6'd8;
parameter DELAY2 = 6'd9;
parameter DELAY3 = 6'd10;
parameter DELAY4 = 6'd11; 
parameter WAIT_MEM2 = 6'd12;
parameter INVnRUN2 = 6'd13;
parameter MUL9 = 6'd14;
parameter DELAY5 = 6'd15; 
parameter DELAY6 = 6'd16;
parameter DELAYN = 6'd17;
parameter IFETCH = 6'd20;
parameter DECODE = 6'd21;
parameter EXECUTE = 6'd22;
parameter MEMORY = 6'd23;
parameter WRITEBACK = 6'd24;
parameter SYNC = 6'd25;
parameter MUL2 = 6'd26;
parameter DIV2 = 6'd27;
parameter DF1 = 6'd28;
parameter DFMUL2 = 6'd29;

// REB states
parameter EMPTY = 3'd0;
parameter FETCHED = 3'd1;
parameter DECODED = 3'd2;
parameter OUT = 3'd3;
parameter EXECUTED = 3'd4;
parameter RETIRED = 3'd7;

typedef logic [2:0] SSrcId;
DecodeOut deco, xd, md, wd;
DecodeOut deco1;
reg stalled, stalled1, pstall;
SSrcId exec, exec2, mc_exec2;
SSrcId dec,dec1,prev_dec;
SSrcId oldest;

reg [2:0] sp_sel;			// stack pointer selector
reg fetch2 = 1'b0;
reg [63:0] key = 64'd0;
reg [5:0] rst_cnt;
reg [4:0] dicnt;
wire di = |dicnt;
wire [1:0] omode;
wire [1:0] memmode;
wire UserMode, SupervisorMode, HypervisorMode, MachineMode;
wire MUserMode;
reg gie;
Value carry_reg [0:3];
sReorderEntry [7:0] reb;
reg [5:0] sns [0:7];
SSrcId head0, head1, head2;
reg [5:0] Ra;
reg [5:0] Rb;
reg [5:0] Rc;
reg [5:0] Rt;
reg [1:0] Tb;
reg [1:0] Tc;
reg [2:0] Rvm;
reg [3:0] Ca;
reg [3:0] Ct;

reg [5:0] commit0_tgt, commit1_tgt;
reg commit0_wr, commit1_wr;
reg commit0_wrv, commit1_wrv;
VecValue commit0_bus,commit1_bus;
reg [2:0] commit0_src, commit1_src;
reg [1:0] commit_cnt;
reg [63:0] commit0_m, commit1_m;
reg commit0_z, commit1_z;
always_comb head2 = 3'd7;

reg rfwr0, rfwr1, rfwr2;
reg vrfwr0;
reg rfwr0t2;
always_comb rfwr0 = reb[head0].dec.rfwr && !reb[head0].dec.Rtvec && reb[head0].executed && reb[head0].v && head0 != 3'd7;
always_comb vrfwr0 = reb[head0].dec.rfwr && reb[head0].dec.Rtvec && reb[head0].executed && reb[head0].v && head0 != 3'd7;
//always_comb rfwr1 = ((reb[head1].dec.rfwr && reb[head1].executed && reb[head1].v && head1 != 3'd7) || reb[head0].dec.Rt2 != 'd0) && rfwr0;
//always_comb rfwr2 = reb[head2].dec.rfwr && reb[head2].executed && reb[head2].v && head2 != 3'd7 && rfwr0 && rfwr1;
always_comb//ff @(posedge clk_g)
	commit0_src = head0;
always_comb//_ff @(posedge clk_g)
	commit0_tgt = reb[head0].dec.Rt;
always_comb//_ff @(posedge clk_g)
	commit0_bus = reb[head0].res;
always_comb//_ff @(posedge clk_g)
	commit0_wr = rfwr0;
always_comb//_ff @(posedge clk_g)
	commit0_wrv = vrfwr0;
always_comb//_ff @(posedge clk_g)
	commit0_m = reb[head0].vmask;
always_comb//_ff @(posedge clk_g)
	commit0_z = reb[head0].zbit;

always_comb//_ff @(posedge clk_g)
	commit1_src = 3'd7;
always_comb//_ff @(posedge clk_g)
	commit1_tgt = 6'd0;
always_comb//_ff @(posedge clk_g)
	commit1_bus = 64'd0;
always_comb//_ff @(posedge clk_g)
	commit1_wr = 1'b0;
always_comb//_ff @(posedge clk_g)
	commit1_wrv = 1'b0;
always_comb//_ff @(posedge clk_g)
	commit1_m = 64'd0;
always_comb//_ff @(posedge clk_g)
	commit1_z = 1'b0;
/*
always_ff @(posedge clk_g)
if (head0 != 3'd7)
case({rfwr2,rfwr1,rfwr0})
3'd0:	begin commit0_src = head0; commit1_src = 3'd7; end
3'd1:	begin commit0_src = head0; commit1_src = 3'd7; end
3'd2:	begin commit0_src = head1; commit1_src = 3'd7; end
3'd3:	begin commit0_src = head0; commit1_src = |reb[head0].dec.Rt2 ? head0 : head1; end
3'd4:	begin commit0_src = head2; commit1_src = 3'd7; end
3'd5:	begin commit0_src = head0; commit1_src = head2; end
3'd6:	begin commit0_src = head1; commit1_src = head2; end
3'd7:	begin commit0_src = head0; commit1_src = |reb[head0].dec.Rt2 ? head0 : head1; end
endcase
always_ff @(posedge clk_g)
if (head0 != 3'd7)
case({rfwr2,rfwr1,rfwr0})
3'd0:	begin commit0_tgt = 'd0; commit1_tgt = 'd0; end
3'd1:	begin commit0_tgt = reb[head0].dec.Rt; commit1_tgt = 'd0; end
3'd2:	begin commit0_tgt = reb[head1].dec.Rt; commit1_tgt = 'd0; end
3'd3: begin commit0_tgt = reb[head0].dec.Rt; commit1_tgt = |reb[head0].dec.Rt2 ? reb[head0].dec.Rt2 : reb[head1].dec.Rt; end
3'd4: begin commit0_tgt = reb[head2].dec.Rt; commit1_tgt = 'd0; end
3'd5: begin commit0_tgt = reb[head0].dec.Rt; commit1_tgt = reb[head2].dec.Rt; end
3'd6: begin commit0_tgt = reb[head1].dec.Rt; commit1_tgt = reb[head2].dec.Rt; end
3'd7: begin commit0_tgt = reb[head0].dec.Rt; commit1_tgt = |reb[head0].dec.Rt2 ? reb[head0].dec.Rt2 : reb[head1].dec.Rt; end
endcase
always_ff @(posedge clk_g)
if (head0 != 3'd7)
case({rfwr2,rfwr1,rfwr0})
3'd0:	begin commit0_bus = 'd0; commit1_bus = 'd0; end
3'd1:	begin commit0_bus = reb[head0].res[$bits(Value)-1:0]; commit1_bus = 'd0; end
3'd2:	begin commit0_bus = reb[head1].res[$bits(Value)-1:0]; commit1_bus = 'd0; end
3'd3:	begin commit0_bus = reb[head0].res[$bits(Value)-1:0]; commit1_bus = |reb[head0].dec.Rt2 ? reb[head0].res_t2[$bits(Value)-1:0] : reb[head1].res[$bits(Value)-1:0]; end
3'd4:	begin commit0_bus = reb[head2].res[$bits(Value)-1:0]; commit1_bus = 'd0; end
3'd5:	begin commit0_bus = reb[head0].res[$bits(Value)-1:0]; commit1_bus = reb[head2].res[$bits(Value)-1:0]; end
3'd6:	begin commit0_bus = reb[head1].res[$bits(Value)-1:0]; commit1_bus = reb[head2].res[$bits(Value)-1:0]; end
3'd7:	begin commit0_bus = reb[head0].res[$bits(Value)-1:0]; commit1_bus = |reb[head0].dec.Rt2 ? reb[head0].res_t2[$bits(Value)-1:0] : reb[head1].res[$bits(Value)-1:0]; end
endcase
always_ff @(posedge clk_g)
if (head0 != 3'd7)
case({rfwr2,rfwr1,rfwr0})
3'd0:	begin commit0_wr = 1'b0; commit1_wr = 1'b0; end
3'd1:	begin commit0_wr = 1'b1; commit1_wr = 1'b0; end
3'd2:	begin commit0_wr = 1'b1; commit1_wr = 1'b0; end
3'd3: begin commit0_wr = 1'b1; commit1_wr = 1'b1; end
3'd4:	begin commit0_wr = 1'b1; commit1_wr = 1'b0; end
3'd5: begin commit0_wr = 1'b1; commit1_wr = 1'b1; end
3'd6: begin commit0_wr = 1'b1; commit1_wr = 1'b1; end
3'd7: begin commit0_wr = 1'b1; commit1_wr = 1'b1; end
endcase
// The following instructions do not update the register file and they are not
// oddball instructions, so they may be retired. Oddball type instructions 
// allow only single commit.
reg commit1;
always_ff @(posedge clk_g)
	commit1 = reb[commit1_src].executed && (
						reb[commit1_src].dec.st||	// A store
						(reb[commit1_src].dec.jmp && reb[commit1_src].dec.lk==2'b00) ||	// Branches that do not update the ca register file.
						(reb[commit1_src].dec.jxx && reb[commit1_src].dec.lk==2'b00) ||
						(reb[commit1_src].dec.jxz && reb[commit1_src].dec.lk==2'b00)
						)
						;
*/
always_comb
	commit_cnt = 2'd1;
/*
	if (rfwr1 && rfwr0 && ~|reb[head0].dec.Rt2)
		commit_cnt = 2'd2;
	else if (commit1 & rfwr0)
		commit_cnt = 2'd2;
	else
		commit_cnt = 2'd1;
*/
//Value regfile [0:31];
Value rfoa, rfob, rfoc, rfot, rfop, rfom;
Value rfoa1, rfob1, rfoc1, rfot1, rfop1, rfom1;
reg rfoa_v, rfob_v, rfoc_v, rfot_v, rfom_v;
reg rfoa_v1, rfob_v1, rfoc_v1, rfot_v1, rfom_v1;

Thor2022_gp_regfile ugprs
(
	.rst(rst_i),
	.clk(clk_g),
	.wr0(commit0_wr),
	.wr1(commit1_wr),
	.wa0(commit0_tgt),
	.wa1(commit1_tgt),
	.i0(commit0_bus[0]),
	.i1(commit1_bus[0]),
	.ip0(reb[regfetch0].ip),
	.ip1(reb[regfetch1].ip),
	.ra0(stalled ? reb[oldest].dec.Ra : reb[regfetch0].dec.Ra),
	.ra1(stalled ? reb[oldest].dec.Rb : reb[regfetch0].dec.Rb),
	.ra2(stalled ? reb[oldest].dec.Rc : reb[regfetch0].dec.Rc),
	.ra3(stalled ? reb[oldest].dec.Rt : reb[regfetch0].dec.Rt),
	.ra4(reb[regfetch1].dec.Ra),
	.ra5(reb[regfetch1].dec.Rb),
	.ra6(reb[regfetch1].dec.Rc),
	.ra7(reb[regfetch1].dec.Rt),
	.ra8({3'b100,reb[regfetch0].dec.Rvm}),
	.ra9({3'b100,reb[regfetch1].dec.Rvm}),
	.o0(rfoa),
	.o1(rfob),
	.o2(rfoc),
	.o3(rfot),
	.o4(rfoa1),
	.o5(rfob1),
	.o6(rfoc1),
	.o7(rfot1),
	.o8(rfom),
	.o9(rfom1)
);

MemoryRequest storeHistory [0:1023];
MemoryResponse loadHistory [0:1023];
reg [9:0] shndx;
reg [9:0] ldndx;

wire [5:0] regfile_src [0:NREGS-1];
wire [5:0] next_regfile_src [0:NREGS-1];
Value r58;
reg [127:0] preg [0:7];
reg [15:0] cio;
reg [7:0] delay_cnt;
Value sp, t0;
CodeAddress eip_regfile [0:7];
SrcId [15:0] eip_src;
(* ram_style="block" *)
Value vregfile [0:31][0:63];
/*
Thor2022_vm_regfile uvmrf1
(
	.clk(clk_g),
	.wr0, wr1, wa0, wa1, i0, i1,
	ra0, ra1, ra2, ra3, o0, o1, o2, o3);
*/
wire ipage_fault;
reg clr_ipage_fault = 1'b0;
wire itlbmiss;
reg clr_itlbmiss = 1'b0;
reg wackr;
reg mc_busy;
wire [NREGS-1:0] livetarget;
wire [NREGS-1:0] livetarget2;
wire [NREGS-1:0] reb_latestID [0:7];
wire [NREGS-1:0] reb_latestID2 [0:7];
SSrcId MaxSrcId = 5'h07;
wire [NREGS-1:0] regfile_valid;
wire [NREGS-1:0] next_regfile_valid;
reg branchmiss,clr_branchmiss;


Thor2022_regfile_src urfs1
(
	.rst(rst_i),
	.clk(clk_g),
	.head0(head0),
	.commit0_id(commit0_src),
	.commit0_wr(commit0_wr),
	.commit0_tgt(commit0_tgt),
	.commit1_wr(commit1_wr),
	.commit1_tgt(commit1_tgt),
	.branchmiss(branchmiss),
	.reb(reb),
	.latestID(reb_latestID),
	.livetarget(livetarget),
	.latestID2(reb_latestID2),
	.livetarget2(livetarget2),
	.decbus0(reb[regfetch0].dec),
	.decbus1(reb[regfetch1].dec),
	.dec0(regfetch0),
//	.decbus0(deco),
//	.decbus1(deco1),
//	.dec0(dec),
	.dec1(5'd7),//dec1),
	.regfile_valid(regfile_valid),
	.next_regfile_src(next_regfile_src),
	.regfile_src(regfile_src)
);

Thor2022_regfile_valid urfv1
(
	.rst(rst_i),
	.clk(clk_g),
	.commit0_id(commit0_src),
	.commit0_wr(commit0_wr),
	.commit0_tgt(commit0_tgt),
	.commit1_id(commit1_src),
	.commit1_wr(commit1_wr),
	.commit1_tgt(commit1_tgt),
	.branchmiss(branchmiss),
	.reb(reb),
	.latestID(reb_latestID),
	.livetarget(livetarget),
	.decbus0(reb[regfetch0]),
	.decbus1(reb[regfetch1]),
	.dec0(regfetch0),
//	.decbus0(deco),
//	.decbus1(deco1),
//	.dec0(dec),
	.dec1(5'd7),
	.regfile_src(regfile_src),
	.next_regfile_valid(next_regfile_valid),
	.regfile_valid(regfile_valid)
);

integer n1;
initial begin
	for (n1 = 0; n1 < 32; n1 = n1 + 1) begin
//		regfile[n1] <= 'd0;
	end
	for (n1 = 0; n1 < 8; n1 = n1 + 1) begin
		preg[n1] <= 'd0;
		eip_regfile[n1].offs <= 'd0;
		eip_regfile[n1].micro_ip <= 'd0;
	end
end

reg advance_w;
VecValue vroa, vrob, vroc, vrot;
VecValue vroa1, vrob1, vroc1, vrot1;
Value wres2;
wire wrvrf;
reg first_flag, done_flag;

reg [2:0] prev_fetch0;
wire [2:0] next_fetch0, next_fetch1;
wire [2:0] next_decompress0, next_decompress1;
wire [2:0] next_dec0, next_dec1;
wire [2:0] next_exec;
wire [2:0] next_head0, next_head1;
reg [2:0] decompress0, decompress1;
reg [2:0] regfetch0, next_regfetch0;
reg [2:0] regfetch1, next_regfetch1;
SSrcId fetch0, fetch1;

// Instruction fetch stage vars
reg ival;
Instruction insn0, insn1;
Instruction micro_ir,micro_ir1;
(* MARK_DEBUG="TRUE" *)
CodeAddress ip, prev_ip;
reg [6:0] micro_ip;
CodeAddress rts_stack[0:31];
reg [4:0] rts_sp;
wire ipredict_taken;
wire ihit;
wire [pL1ICacheLineSize-1:0] ic_line;
wire [3:0] ilen0, ilen1;
wire btb_hit;
CodeAddress btb_tgt;
CodeAddress next_ip;
wire run;
reg [2:0] pfx_cnt;		// prefix counter
reg [7:0] istep;


// Decode stage vars
reg dval;
Instruction ir;
CodeAddress dip;
reg [2:0] cioreg;
reg dpfx;
reg [3:0] dlen;
reg dpredict_taken;
reg Rz;
always_comb Ra = deco.Ra;
always_comb Rb = deco.Rb;
always_comb Rc = deco.Rc;
always_comb Rt = deco.Rt;
always_comb Rvm = deco.Rvm;
always_comb Rz = deco.Rz;
always_comb Tb = deco.Tb;
always_comb Tc = deco.Tc;
always_comb Ct = deco.Ct;
reg [3:0] distk_depth;
reg [7:0] dstep;
reg zbit;

wire dAddi = deco.addi;
wire dld = deco.ld;
wire dst = deco.st;

Address rfoca;
reg [7:0] wstep;

Thor2022_vec_regfile uvecrf
(
	.clk(clk_g),
	.wr0(commit0_wrv),
	.wr1(commit1_wrv),
	.wa0(commit0_tgt),
	.wa1(commit1_tgt),
	.m0(commit0_m),
	.m1(commit1_m),
	.z0(commit0_z),
	.z1(commit1_z),
	.i0(commit0_bus),
	.i1(commit1_bus),
	.ra0(stalled ? reb[oldest].dec.Ra : reb[dec].dec.Ra),
	.ra1(stalled ? reb[oldest].dec.Rb : reb[dec].dec.Rb),
	.ra2(stalled ? reb[oldest].dec.Rc : reb[dec].dec.Rc),
	.ra3(stalled ? reb[oldest].dec.Rt : reb[dec].dec.Rt),
	.ra4(reb[dec1].dec.Ra),
	.ra5(reb[dec1].dec.Rb),
	.ra6(reb[dec1].dec.Rc),
	.ra7(reb[dec1].dec.Rt),
	.o0(vroa),
	.o1(vrob),
	.o2(vroc),
	.o3(vrot),
	.o4(vroa1),
	.o5(vrob1),
	.o6(vroc1),
	.o7(vrot1)
);

// Execute stage vars
reg xval;
Address xbadAddr;
Instruction xir;
CodeAddress xip;
reg [3:0] xlen;
reg [4:0] tRt;
reg [2:0] xistk_depth;
reg [2:0] xcioreg;
reg [1:0] xcio;
Value pn;
CodeAddress xca;
CodeAddress xcares;
reg xmaskbit;
reg xzbit;
reg [2:0] xSc;
wire takb;
reg xpredict_taken;
reg xPredictableBranch;
reg xTlb, xRgn, xPtg;
reg xMfsel,xMtsel;
MemoryRequest memreq;
(* MARK_DEBUG="TRUE" *)
MemoryResponse memresp;
reg [7:0] last_memresp_tid;
reg memresp_fifo_rd;
wire memresp_fifo_empty;
wire memresp_fifo_v;
reg [7:0] tid;
VecValue res,res2,exres2,mcres2;
VecValue vres;
VecValue crypto_res, res_t2;
CodeAddress cares, cares2;
reg ld_vtmp;
reg [7:0] xstep;
reg [2:0] xrm,xdfrm;

// Memory
reg mval;
Instruction mir;
CodeAddress mip;
Address mbadAddr;
CodeAddress mca;
CodeAddress mcares;
reg mrfwr, m512, m256;
reg mvmrfwr;
reg [2:0] mistk_depth;
reg [2:0] mcioreg;
reg [1:0] mcio;
reg mStset,mStmov,mStfnd,mStcmp;
Value ma;
Value mres, mres_t2;
reg [511:0] mres512;
reg [7:0] mstep;
reg mzbit;
reg mmaskbit;
CodeAddress mJmptgt;

// Writeback stage vars
reg wval;
Instruction wir;
CodeAddress wip;
Address wbadAddr;
CodeAddress wlk;
CodeAddress wca;
CodeAddress wcares;
reg wrfwr, w512, w256;
reg wvmrfwr;
reg [2:0] wistk_depth;
reg [2:0] wcioreg;
reg [1:0] wcio;
reg wStset,wStmov,wStfnd,wStcmp;
Value wa;
Value wres, wres_t2;
reg [511:0] wres512;
reg wzbit;
reg wmaskbit;
Address wJmptgt;

// Trailer stage vars
reg advance_t;
reg tSync;
reg uSync,vSync;

// CSRs
reg [63:0] cr0;
wire pe = cr0[0];				// protected mode enable
wire dce;     					// data cache enable
wire bpe = cr0[32];     // branch prediction enable
wire btbe	= cr0[33];		// branch target buffer enable
wire [2:0] cr0_mo = cr0[38:36];	// memory ordering
Value scratch [0:3];
reg [127:0] ptbr;
Address artbr;
reg [63:0] tick;
reg [63:0] wc_time;			// wall-clock time
reg [63:0] mtimecmp;
reg [63:0] tvec [0:3];
reg [15:0] cause [0:3];
Address badaddr [0:3];
reg [63:0] mexrout;
reg [5:0] estep;
Value vtmp;							// temporary register used in processing vectors
Value new_vtmp;
reg [3:0] istk_depth;		// range: 0 to 8
reg [63:0] pmStack;
wire [2:0] ilvl = pmStack[3:1];
reg [63:0] plStack;
Address dbad [0:3];
reg [63:0] dbcr;
reg [31:0] status [0:3];
wire mprv = status[3][17];
wire uie = status[3][0];
wire sie = status[3][1];
wire hie = status[3][2];
wire mie = status[3][3];
wire die = status[3][4];
reg [11:0] asid;
Value gdt;
Address tcbptr;
reg [127:0] keys2 [0:1];
reg [23:0] keys [0:7];
always_comb
begin
	keys[0] = keys2[0][31:0];
	keys[1] = keys2[0][63:32];
	keys[2] = keys2[0][95:64];
	keys[3] = keys2[0][127:96];
	keys[4] = keys2[1][31:0];
	keys[5] = keys2[1][63:32];
	keys[6] = keys2[1][95:64];
	keys[7] = keys2[1][127:96];
end
reg [7:0] vl;
Value sema;
reg [2:0] rm, dfrm;

assign omode = pmStack[7:6];
assign MachineMode = omode==2'b11;
assign HypervisorMode = omode==2'b10;
assign SupervisorMode = omode==2'b01;
assign UserMode = omode==2'b00;
assign memmode = mprv ? pmStack[15:14] : omode;
wire MMachineMode = memmode==2'b11;
assign MUserMode = memmode==2'b00;
reg [39:0] btb_hit_count;
reg [39:0] cbranch_count;
reg [39:0] cbranch_miss;
reg [39:0] rts_pcount;
reg [39:0] ret_match_count;
reg [39:0] retired_count;

Value bf_out;

function fnArgsValid;
input [2:0] kk;
fnArgsValid = (reb[kk].iav && reb[kk].ibv && reb[kk].icv);
endfunction

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Decode stage combinational logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Instruction dxir, dmir, dxir1, dmir1;
reg dxval, dmval, dxval1, dmval1;
integer k2;
always_comb
begin
	dxir = NOP;
	dmir = NOP;
	dxval = FALSE;
	dmval = FALSE;
	dxir1 = NOP;
	dmir1 = NOP;
	dxval1 = FALSE;
	dmval1 = FALSE;
	for (k2 = 0; k2 < REB_ENTRIES; k2 = k2 + 1) begin
		if (sns[k2] == sns[dec] - 1) begin
			dxir = reb[k2].ir;
			dxval = reb[k2].v;
		end
		if (sns[k2] == sns[dec] - 2) begin
			dmir = reb[k2].ir;
			dmval = reb[k2].v;
		end
		if (sns[k2]==sns[dec1] - 1) begin
			dxir1 = reb[k2].ir;
			dxval1 = reb[k2].v;
		end
		if (sns[k2] == sns[dec1] - 2) begin
			dmir1 = reb[k2].ir;
			dmval1 = reb[k2].v;
		end
	end
end

Thor2022_decoder udec0 (
	.ir(reb[dec].ir),
	.xir(dxir),
	.xval(dxval),
	.mir(dmir),
	.sp_sel(sp_sel),
	.mval(dmval),
	.deco(deco),
	.distk_depth(distk_depth),
	.rm(rm),
	.dfrm(dfrm)
);

Thor2022_decoder udec1 (
	.ir(reb[dec1].ir),
	.xir(dxir1),
	.xval(dxval1),
	.mir(dmir1),
	.sp_sel(sp_sel),
	.mval(dmval1),
	.deco(deco1),
	.distk_depth(distk_depth),
	.rm(rm),
	.dfrm(dfrm)
);

/*
always_comb
	if (cioreg==3'd0 || ~cio[1])
		rfop = 'd0;
	else if (reb[head0].v && reb[head0].cioreg==cioreg && reb[head0].executed && reb[head0].cio[0])
		rfop = reb[head0].res_t2;
	else
		rfop = preg[cioreg];
*/
always_comb
	rfoa_v = next_regfile_valid[reb[regfetch0].dec.Ra] || Source1Valid(reb[regfetch0].ir);
always_comb
	rfob_v = next_regfile_valid[reb[regfetch0].dec.Rb] || Source2Valid(reb[regfetch0].ir);
always_comb
	rfoc_v = next_regfile_valid[reb[regfetch0].dec.Rc] || Source3Valid(reb[regfetch0].ir);
always_comb
	rfot_v = next_regfile_valid[reb[regfetch0].dec.Rt] || SourceTValid(reb[regfetch0].ir);
always_comb
	rfom_v = next_regfile_valid[reb[regfetch0].dec.Rvm] || SourceMValid(reb[regfetch0].ir);
/*
always_comb
	rfoa_v1 = (reb[head0].dec.Rt==deco1.Ra && reb[head0].v && reb[head0].executed && reb[head0].dec.rfwr) || regfile_src[deco1.Ra]==5'd31 || Source1Valid(reb[dec1].ir);
always_comb
	rfob_v1 = (reb[head0].dec.Rt==deco1.Rb && reb[head0].v && reb[head0].executed && reb[head0].dec.rfwr) || regfile_src[deco1.Rb]==5'd31 || Source2Valid(reb[dec1].ir);
always_comb
	rfoc_v1 = (reb[head0].dec.Rt==deco1.Rc && reb[head0].v && reb[head0].executed && reb[head0].dec.rfwr) || regfile_src[deco1.Rc]==5'd31 || Source3Valid(reb[dec1].ir);
*/
always_comb
	zbit = deco.Rz;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Branch miss logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

integer n,j,k;
CodeAddress branchmiss_adr;
SSrcId missid;
wire [7:0] stomp;
reg dec_miss;
reg exec_miss;
reg djxxa_miss;
reg djxxr_miss;
reg jxx_miss;
reg jxz_miss;
reg mjnez_miss;
reg rts_miss;
reg ret_match;

always_comb
	djxxa_miss = (reb[dec].ir.jxx.Rc=='d0 && reb[dec].dec.jxx && dpredict_taken && bpe) && (ip.offs != reb[dec].dec.jmptgt) && reb[dec].v;
always_comb
	djxxr_miss = (reb[dec].ir.jxx.Rc==6'd31 && reb[dec].dec.jxx && dpredict_taken && bpe) && (ip.offs != reb[dec].ip.offs + reb[dec].dec.jmptgt) && reb[dec].v;
always_comb
	jxx_miss = ((reb[exec].predict_taken && !takb && reb[exec].predictable_branch) ||
						((!reb[exec].predict_taken && takb) || !reb[exec].predictable_branch) ||
						(takb && !bpe)) &&
						reb[exec].dec.jxx && reb[exec].v && !reb[exec].executed && reb[exec].rfetched
						;
//always_comb
//	jxx_miss = reb[exec].dec.jxx && takb && reb[exec].v && !reb[exec].executed;
always_comb
	jxz_miss = ((reb[exec].predict_taken && !takb && reb[exec].predictable_branch) ||
						((!reb[exec].predict_taken && takb) || !reb[exec].predictable_branch) ||
						(takb && !bpe)) &&
						reb[exec].dec.jxz && reb[exec].v && !reb[exec].executed && reb[exec].rfetched
						;
//	jxz_miss = reb[exec].dec.jxz && takb && reb[exec].v && !reb[exec].executed;
always_comb
	mjnez_miss = reb[exec].dec.mjnez && takb && reb[exec].v && !reb[exec].executed;
always_comb
	rts_miss = (reb[exec].dec.rts && reb[exec].ir.rts.lk != 2'b00) && !reb[exec].executed && !ret_match;

always_comb
	dec_miss = djxxa_miss | djxxr_miss;
always_comb
	exec_miss = jxx_miss | jxz_miss | mjnez_miss | rts_miss; //reb[exec].dec.jmp | reb[exec].dec.bra |
always_ff @(posedge clk_g)
if (dec_miss || exec_miss)
	missid <= exec_miss ? exec : dec;	// exec miss takes precedence
reg branchmiss1;
always_ff @(posedge clk_g)
if (rst_i)
	branchmiss1 <= 1'b0;
else begin
	if (dec_miss || exec_miss)
		branchmiss1 <= #1 1'b1;
	else if (clr_branchmiss)
		branchmiss1 <= #1 1'b0;
end
always_comb
	branchmiss = branchmiss1 & !clr_branchmiss;

Thor2022_stomp ustmp1
(
	.branchmiss(branchmiss),
	.missid(missid),
	.sns(sns),
	.stomp(stomp)
);

Thor2022_livetarget ult1
(
	.reb(reb),
	.stomp(stomp),
	.sns(sns),
	.missid(missid),
	.livetarget(livetarget),
	.livetarget2(livetarget2),
	.latestID(reb_latestID),
	.latestID2(reb_latestID2)
);

// Detect oldest instruction. Used during writeback.

always @*
begin
	oldest = 0;
	for (n = 0; n < REB_ENTRIES; n = n + 1)
		if (sns[n] < sns[oldest] && reb[n].v)
			oldest = n;
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute stage combinational logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire [NLANES-1:0] multovf;
wire [NLANES-1:0] dvd_done;
wire [NLANES-1:0] dfmul_done;
wire [NLANES-1:0] dvByZr;
wire [2:0] pte_en;
wire pte_found;
reg [511:0] ptg;
wire [127:0] pte;
always_comb
	ptg = reb[exec].ic;

/*
Thor2022_ptg_search uptgs1
(
	.ptg(ptg),
	.asid(asid),
	.miss_adr(xa),
	.pte(pte),
	.found(pte_found),
	.entry_num(pte_en)
);
*/
Thor2022_eval_branch ube (
	.inst(reb[exec].ir),
	.a(reb[exec].ia[0]),
	.b(reb[exec].ib[0]),
	.takb(takb)
);

reg aqe_wr;
reg aqe_rd;
wire aqe_full;
wire [4:0] aqe_qcnt;
AQE aqe_dat, aqe_dato;

VecValue mc_res, mc_res_t2;
always_comb
	pn = 'd0;//reb[exec].pn;

always_comb
begin
	aqe_dat.tid = 'd0;
	aqe_dat.ndx = exec;
	aqe_dat.ir = reb[exec].ir;
	aqe_dat.dec = reb[exec].dec;
	aqe_dat.a = reb[exec].ia;
	aqe_dat.b = reb[exec].ib;
	aqe_dat.c = reb[exec].ic;
	aqe_dat.i = reb[exec].dec.imm;
end

Thor2022_fifo #(.WID($bits(AQE))) uaqefifo
(
	.rst(rst_i),
	.clk(clk_g),
	.wr(aqe_wr),
	.di(aqe_dat),
	.rd(aqe_rd),
	.dout(aqe_dato),
	.cnt(aqe_qcnt),
	.full(aqe_full)
);

Value csr_res;
always_comb
	tReadCSR (csr_res, reb[exec].ir.csr.regno);

genvar g;
generate
	for (g = 0; g < NLANES; g = g + 1) begin
Thor2022_alu ualu1
(
	.clk(clk_g),
	.m(reb[exec].is_vec ? reb[exec].vmask[g] : 1'b1),
	.z(reb[exec].zbit),
	.ir(reb[exec].ir),
	.ip(reb[exec].ip),
	.ilen(reb[exec].ilen),
	.xa(reb[exec].ia[g]),
	.xb(reb[exec].ib[g]),
	.xc(reb[exec].ic[g]),
	.t(reb[exec].it[g]),
	.imm(reb[exec].dec.imm),
	.ca(reb[exec].ca),
//	.lr(regfile[1]),
	.lr('d0),
	.asid(asid),
	.ptbr(ptbr),
	.csr_res(csr_res),
	.ilvl(ilvl),
	.res(res[g]),
	.res_t2(res_t2[g]),
	.cares(cares)
);

Thor2022_mc_alu umcalu1
(
	.rst(rst_i),
	.clk(clk_g),
	.clk2x(clk2x_i),
	.state(state),
	.ir(aqe_dato.ir),
	.dec(aqe_dato.dec),
	.xa(aqe_dato.a[g]),
	.xb(aqe_dato.b[g]),
	.xc(aqe_dato.c[g]),
	.imm(aqe_dato.i),
	.res(mc_res[g]),
	.res_t2(mc_res_t2[g]),
	.multovf(multovf[g]),
	.dvByZr(dvByZr[g]),
	.dvd_done(dvd_done[g]),
	.dfmul_done(dfmul_done[g])
);
end
endgenerate

Thor2022_valu64 uvalu1
(
	.ir(reb[exec].ir),
	.m(reb[exec].vmask),
	.z(reb[exec].zbit),
	.xa(reb[exec].ia),
	.xb(reb[exec].ib),
	.xc(reb[exec].ic),
	.t(reb[exec].it),
	.res(vres)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction fetch combo logic.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire sig1 = ihit && !reb[fetch0].v && !branchmiss && fetch0 != prev_fetch0 && !fnIsRepInsn(ip);

Thor2022_inslength uil(insn0, ilen0);
Thor2022_inslength ui2(insn1, ilen1);

always_comb
begin
	if (branchmiss)
		next_ip = branchmiss_adr;
	else if (sig1) begin
		next_ip.micro_ip = 7'd0;
		if (fetch0 != fetch1 && fetch2) begin	// always false for now
			next_ip.offs = ip.offs + ilen0 + ilen1;
 		end
 		else begin
			next_ip.offs = ip.offs + ilen0;
 		end
	end
	else begin
		next_ip.micro_ip = 7'd0;
		next_ip.offs = ip.offs;
	end
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Predictors
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Detect if the return address was successfully predicted.

integer n3;
always_comb
begin
	ret_match = 1'b0;
	for (n3 = 0; n3 < REB_ENTRIES; n3 = n3 + 1)
		if (sns[n3]==sns[exec]+1)
			if (reb[n3].ip==reb[exec].ic[0])
				ret_match = 1'b1;
end

Thor2022_BTB_x1 ubtb
(
	.rst(rst_i),
	.clk(clk_g),
	.wr(reb[head0].v && reb[head0].dec.flowchg),
	.wip(reb[head0].ip),
	.wtgt(reb[head0].jmptgt),
	.takb(reb[head0].takb),
	.rclk(~clk_g),
	.ip(ip),
	.tgt(btb_tgt),
	.hit(btb_hit),
	.nip(next_ip)
);

`ifdef NOT_DEFINED
CodeAddress [1:0] ipx;
wire [1:0] ipredict_taken;
always_comb
	ipx[0] = ip;
always_comb
	ipx[1] = ip + ilen0;

gselectPredictor ubp1
(
	.rst(rst_i),
	.clk(clk_g),
	.clk2x(clk2x_i),
	.clk4x(clk4x_i),
	.en(bpe),
	.xisBranch(),
	.xip(),
	.takb(),
	.ip(ipx),
	.predict_taken(ipredict_taken)
);
`endif

Thor2022_gselectPredictor ubp
(
	.rst(rst_i),
	.clk(clk_g),
	.en(bpe),
	.xisBranch(reb[exec].dec.jxx|reb[exec].dec.jxz),
	.xip(xip.offs),
	.takb(takb),
	.ip(ip.offs),
	.predict_taken(ipredict_taken)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire memreq_wack;
wire memreq_full;
Thor2022_biu ubiu
(
	.rst(rst_i),
	.clk(clk_g),
	.tlbclk(clk2x_i),
	.clock(clock),
	.UserMode(UserMode),
	.MUserMode(MUserMode),
	.omode(omode),
	.ASID(asid),
	.bounds_chk(),
	.pe(pe),
	.ip(ip.offs),
	.ihit(ihit),
	.ifStall(!run),
	.ic_line(ic_line),
	.fifoToCtrl_i(memreq),
	.fifoToCtrl_full_o(memreq_full),
	.fifoToCtrl_wack(memreq_wack),
	.fifoFromCtrl_o(memresp),
	.fifoFromCtrl_rd(memresp_fifo_rd),
	.fifoFromCtrl_empty(memresp_fifo_empty),
	.fifoFromCtrl_v(memresp_fifo_v),
	.bok_i(bok_i),
	.bte_o(bte_o),
	.cti_o(cti_o),
	.vpa_o(vpa_o),
	.vda_o(vda_o),
	.cyc_o(cyc_o),
	.stb_o(stb_o),
	.ack_i(ack_i),
	.we_o(we_o),
	.sel_o(sel_o),
	.adr_o(adr_o),
	.dat_i(dat_i),
	.dat_o(dat_o),
	.sr_o(sr_o),
	.cr_o(cr_o),
	.rb_i(rb_i),
	.dce(dce),
	.keys(keys),
	.arange(),
	.ptbr(ptbr),
	.ipage_fault(ipage_fault),
	.clr_ipage_fault(clr_ipage_fault),
	.itlbmiss(itlbmiss),
	.clr_itlbmiss(clr_itlbmiss)
);

CodeAddress ip1;
always_comb
	ip1.offs = ip.offs + ilen0;

always_comb
begin
	insn0 = ic_line >> {ip.offs[5:1],4'd0};
end
always_comb
begin
	insn1 = insn0 >> {ip1.offs[5:1],4'd0};
end

Address siea;
always_comb
	siea = reb[exec].ia[0] + reb[exec].ib;

assign wrvrf = wrfwr && wd.Rtvec && (wmaskbit||wzbit);
assign wres2 = wzbit ? 64'd0 : wres;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Timers
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always @(posedge clk_g)
if (rst_i)
	tick <= 64'd0;
else
	tick <= tick + 2'd1;

reg ld_time;
reg wc_time_irq;
reg [63:0] wc_time_dat;
reg clr_wc_time_irq;
always @(posedge wc_clk_i)
if (rst_i) begin
	wc_time <= 1'd0;
	wc_time_irq <= 1'b0;
end
else begin
	if (|ld_time)
		wc_time <= wc_time_dat;
	else begin
		wc_time[31:0] <= wc_time[31:0] + 2'd1;
		if (wc_time[31:0]==32'd99999999) begin
			wc_time[31:0] <= 32'd0;
			wc_time[63:32] <= wc_time[63:32] + 2'd1;
		end
	end
	if (mtimecmp==wc_time)
		wc_time_irq <= 1'b1;
	if (clr_wc_time_irq)
		wc_time_irq <= 1'b0;
end

wire pe_nmi;
reg nmif;
edge_det u17 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(nmi_i), .pe(pe_nmi), .ne(), .ee() );

reg wfi;
reg set_wfi = 1'b0;
always @(posedge wc_clk_i)
if (rst_i)
	wfi <= 1'b0;
else begin
	if (|irq_i|pe_nmi)
		wfi <= 1'b0;
	else if (set_wfi)
		wfi <= 1'b1;
end

BUFGCE u11 (.CE(!wfi), .I(clk_i), .O(clk_g));
//assign clk_g = clk_i;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Left over from in-order core, to be removed.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire stall_i = !ihit;
assign run = ihit;
always_comb advance_t = !stall_i && (state==RUN);
always_comb	advance_w = advance_t;

reg [3:0] xx;	// debug marker

// =============================================================================
// Scheduling Logic
// =============================================================================

Thor2022_schedule usch1
(
	.clk(clk_g),
	.reb(reb),
	.sns(sns),
	.stomp(stomp),
	.fetch0(fetch0),
	.next_fetch0(next_fetch0),
	.next_fetch1(next_fetch1),
	.next_decompress0(next_decompress0),
	.next_decompress1(next_decompress1),
	.next_decode0(next_dec0),
	.next_decode1(next_dec1),
	.next_regfetch0(next_regfetch0),
	.next_regfetch1(next_regfetch1),
	.next_execute(next_exec),
	.next_retire0(next_head0),
	.next_retire1(next_head1)
);

// =============================================================================
// =============================================================================

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Pipeline
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [5:0] mstate;
always_ff @(posedge clk_g)
if (rst_i) begin
	tReset();
	goto (RESTART1);
	mstate <= RESTART1;
end
else begin
	tOnce();
	tWriteback();
	tInsnFetch();
	tDecompress0();
//	tDecompress1();
	tDecode();
	tRegfetch();
	tExecute();
	tSyncTrailer();
	tArithStateMachine();
	tMemStateMachine();
	tArgCheck();
	tMemHist();
//	tStalled();
//	pstall <= (commit0_tgt==deco.Ra && commit0_wr);
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Support tasks
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
integer n6;

task tReset;
begin
	pstall <= 1'b0;
	stalled <= 1'b0;
	stalled1 <= 1'b0;
	ld_time <= FALSE;
	wval <= INV;
	xval <= INV;
	mval <= INV;
	dval <= INV;
	ival <= INV;
	ir <= NOP_INSN;
	xSc <= 3'd0;
	xPredictableBranch <= FALSE;
	tid <= 8'h00;
	memreq.tid <= 8'h00;
	memreq.step <= 6'd0;
	memreq.count <= 6'd0;
	memreq.wr <= 1'b0;
	memreq.func <= 'd0;
	memreq.func2 <= 'd0;
	memreq.adr <= 'h0;
	memreq.dat <= 'd0;
	memreq.sz <= 'h0;
	dpfx <= FALSE;
	pfx_cnt <= 3'd0;
//	cr0 <= 64'h300000001;
	cr0 <= 64'h100000001;
	ptbr <= 'd0;
	rst_cnt <= 6'd0;
	tSync <= 1'b0;
	uSync <= 1'b0;
	vSync <= 1'b0;
	memresp_fifo_rd <= FALSE;
	gdt <= 64'hFFFFFFFFFFFFFFC0;	// startup table (bit 75 to 12)
	ip.micro_ip <= 'd0;
	ip.offs <= 32'hFFFD0000;
	gie <= FALSE;
	pmStack <= 64'hcececececececece;	// Machine mode, irq level 7, ints disabled
	plStack <= 64'hffffffffffffffff;	// PL = 255
	sp_sel <= 3'd3;
	asid <= 'h0;
	istk_depth <= 4'd1;
	wcause <= 16'h0000;
	micro_ip <= 6'd0;
	m512 <= FALSE;
	m256 <= FALSE;
	w512 <= FALSE;
	w256 <= FALSE;
	cio <= 16'h0000;
	xcio <= 2'd0;
	mcio <= 2'd0;
	wcio <= 2'd0;
	rm <= 'd0;
	dfrm <= 'd0;
	clr_ipage_fault <= 1'b1;
	wackr <= 1'd1;
	dicnt <= 'd0;
	xd <= 'd0;
	md <= 'd0;
	wd <= 'd0;
	for (n6 = 0; n6 < 8; n6 = n6 + 1) begin
		reb[n6] <= 'd0;
		reb[n6].v <= 1'b1;
		reb[n6].executed <= 1'b1;
		reb[n6].cause <= 16'h0000;
		reb[n6].ir <= NOP;
		reb[n6].iav <= 1'b1;
		reb[n6].ibv <= 1'b1;
		reb[n6].icv <= 1'b1;
		reb[n6].lkv <= 1'b1;
		reb[n6].vmv <= 1'b1;
		sns[n6] <= 6'd63-n6;//FFFFFFFFFFFF;
	end
	//sns[0] <= 32'hFFFFFFFF;
	for (n6 = 0; n6 < 16; n6 = n6 + 1)
		eip_src[n6] <= 6'd31;
	head0 <= 'd0;
	fetch0 <= 'd0;
	fetch1 <= 'd0;
	exec <= 'd0;
	dec <= 'd0;
	mc_busy <= 'd0;
	clr_branchmiss <= 1'b0;
	branchmiss_adr.offs <= 32'hFFFD0000;
	branchmiss_adr.micro_ip <= 8'h00;
	cbranch_count <= 'd0;
	cbranch_miss <= 'd0;
	btb_hit_count <= 'd0;
	rts_pcount <= 'd0;
	rts_sp <= 'd0;
	ret_match_count <= 'd0;
	aqe_wr <= 1'b0;
	aqe_rd <= 1'b0;
	retired_count <= 'd0;
	prev_fetch0 <= 3'd7;
	prev_ip <= 'd0;
	shndx <= 'd0;
	ldndx <= 'd0;
	for (n6 = 0; n6 < 1024; n6 = n6 + 1) begin
		storeHistory[n6] <= 'd0;
		loadHistory[n6] <= 'd0;
	end
	last_memresp_tid <= 'd0;
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Once per clock operations.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tOnce;
begin
	xx <= 4'h0;
	memreq.wr <= FALSE;
	aqe_wr <= FALSE;
	aqe_rd <= FALSE;
	if (ld_time==TRUE && wc_time_dat==wc_time)
		ld_time <= FALSE;
	if (clr_wc_time_irq && !wc_time_irq)
		clr_wc_time_irq <= FALSE;
	clr_ipage_fault <= 1'b0;
	clr_branchmiss <= 1'b0;
	stalled1 <= stalled;
end
endtask

reg mcflag;
task tArithStateMachine;
begin
case (state)
RESTART1:
	begin
		goto (RESTART2);
	end
RESTART2:
	begin
		rst_cnt <= 6'd0;
		goto (RUN);
	end
RUN:
	begin
		if (|aqe_qcnt) begin
		  if (aqe_dato.dec.mulall) begin
		    goto(MUL1);
		  end
		  else if (aqe_dato.dec.divall) begin
		    goto(DIV1);
		  end
		  else if (aqe_dato.dec.isDF) begin
		  	goto(DF1);
		  end
		end
	end	// RUN

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Invalidate the xir and switch back to the run state.
// The xir is invalidated to prevent the instruction from executing again.
// Broadcast result on common data bus.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
INVnRUN:
  begin
  	reb[aqe_dato.ndx].executed <= reb[aqe_dato.ndx].v & !stomp[aqe_dato.ndx];
		reb[aqe_dato.ndx].out <= 1'b0;	
  	reb[aqe_dato.ndx].res <= mc_res;
  	reb[aqe_dato.ndx].res_t2 <= mc_res_t2;
		tArgUpdate(aqe_dato.ndx,mc_res);
  	aqe_rd <= 1'b1;
  	mcflag <= 1'b1;
  	mc_busy <= FALSE;
    goto(RUN);
  end
INVnRUN2:
  begin
    //inv_x();
		xx <= 4'd7;
    goto(RUN);
  end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Step1: setup operands and capture sign
MUL1:
  begin
    delay_cnt <= (aqe_dato.dec.mulf|aqe_dato.dec.mulfi) ? 8'd3 : 8'd18;	// Multiplier has 18 stages
	// Now wait for the six stage pipeline to finish
    goto (MUL2);
  end
MUL2:
  call(DELAYN,MUL9);
MUL9:
  begin
    //upd_rf <= `TRUE;
    goto(INVnRUN);
    if (multovf[0] & mexrout[5]) begin
      ex_fault(aqe_dato.ndx,FLT_OFL);
    end
  end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DIV1:
	goto (DIV2);
DIV2:
  if (dvd_done[0]) begin
    //upd_rf <= `TRUE;
    goto(INVnRUN);
    if (dvByZr[0] & mexrout[3]) begin
      ex_fault(aqe_dato.ndx,FLT_DBZ);
    end
  end
/*
FLOAT1:
  if (fpdone) begin
	  //upd_rf <= `TRUE;
	  inv_x();
	  goto(RUN);
	  if (fpstatus[9]) begin  // GX status bit
	      ex_fault(FLT_FLT);
	  end
  end
*/
DF1:
	begin
		case(xir.r3.func)
		DFADD,DFSUB:	begin delay_cnt <= 8'd40; goto (MUL2); end
		DFMUL:	goto (DFMUL2);
		default:	begin delay_cnt <= 8'd1; goto (MUL2); end
		endcase
	end
DFMUL2:
	if (dfmul_done[0])
		goto (INVnRUN);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DELAYN:
	begin
		delay_cnt <= delay_cnt - 2'd1;
		if (delay_cnt==8'd0)
			sreturn();
	end
DELAY6:	goto(DELAY5);
DELAY5:	goto(DELAY4);
DELAY4:	goto(DELAY3);
DELAY3:	goto(DELAY2);
DELAY2:	goto(DELAY1);
DELAY1:	sreturn();

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// If the state machine goes to an invalid state, restart.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
default:
	goto (RESTART1);	
endcase
end
endtask

task tMemStateMachine;
begin
case (mstate)
RESTART1:
	begin
		tReset();
		mstate <= RESTART2;
	end
RESTART2:
	begin
		rst_cnt <= 6'd0;
		mstate <= RUN;
	end
RUN:
	begin
		if (memreq_wack|wackr) begin
			wackr <= 1'b1;
		end
		if (!memresp_fifo_empty) begin
			memresp_fifo_rd <= TRUE;
			mstate <= WAIT_MEM2;
		end
	end	// RUN

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Wait for a response from the BIU.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
WAIT_MEM1:
	begin
		if (memreq_wack|wackr) begin
			wackr <= 1'b1;
			if (!memresp_fifo_empty) begin
				memresp_fifo_rd <= TRUE;
				mstate <= WAIT_MEM2;
			end
		end
	end
WAIT_MEM2:
	begin
		//wackr <= 1'b0;
		mcflag <= 1'b0;
		if ((memresp_fifo_v && !memresp_fifo_empty) || (memresp.tid==memreq.tid && memresp.tid != last_memresp_tid))
		begin
			last_memresp_tid <= memresp.tid;
			mc_exec2 <= memresp.tid[2:0];
			mcres2 <= memresp.res;
			if (memresp.func==MR_LOAD||memresp.func==MR_LOADZ) begin
				loadHistory[ldndx] <= memresp;
				ldndx <= ldndx + 2'd1;
			end
			mcflag <= 1'b1;
			if (mStset|mStmov)
				reb[memresp.tid[2:0]].dec.rfwr <= TRUE;
			if (reb[memresp.tid[2:0]].out) begin
				reb[memresp.tid[2:0]].res <= memresp.res;
				tArgUpdate(memresp.tid[2:0],memresp.res);
				if (|memresp.cause) begin
					if (~|reb[memresp.tid[2:0]].cause)
						reb[memresp.tid[2:0]].istk_depth <= reb[memresp.tid[2:0]].istk_depth + 2'd1;
					reb[memresp.tid[2:0]].cause <= memresp.cause;
					reb[memresp.tid[2:0]].badAddr <= memresp.badAddr;
				end
				// ToDo: handle vector stores
				reb[memresp.tid[2:0]].executed <= reb[memresp.tid[2:0]].v & !stomp[memresp.tid[2:0]];
				reb[memresp.tid[2:0]].out <= 1'b0;
//			 	mc_busy <= FALSE;
			end
		end
		else begin
//			mstate <= RUN;
//			memresp_fifo_rd <= FALSE;
		end
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// If the state machine goes to an invalid state, restart.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
default:
	mstate <= RESTART1;	
endcase
	if (mcflag) begin
		mcflag <= 1'b0;
//		tArgUpdate(mc_exec2,mcres2);
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Increment / Decrement amount for block instructions.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function [10:0] fnIamt;
input [3:0] cd;
case(cd)
4'd0:	fnIamt = 11'd0;
4'd1:	fnIamt = 11'd1;
4'd2:	fnIamt = 11'd2;
4'd3:	fnIamt = 11'd4;
4'd4:	fnIamt = 11'd8;
4'd5:	fnIamt = 11'd16;
4'd15: fnIamt = 11'h7FF;
4'd14: fnIamt = 11'h7FE;
4'd13:	fnIamt = 11'h7FC;
4'd12:	fnIamt = 11'h7F8;
4'd11:	fnIamt = 11'h7F0;
default:	fnIamt = 11'd0;
endcase
endfunction

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction Fetch stage
//
// We want decodes in the IFETCH stage to be fast so they don't appear
// on the critical path. Keep the decodes to a minimum.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

/*
			case(micro_ip)
			// POP Ra
			7'd1:		begin micro_ip <= 7'd2; reb[fetch0].ir <= {29'h00,5'd31,micro_ir[13:9],1'b0,LDH}; dlen <= 4'd2; end	// LDOS $Ra,[$SP]
			7'd2:		begin micro_ip <= 7'd0; reb[fetch0].ir <= {13'h010,5'd31,5'd31,1'b0,ADDI}; ip.offs <= ip.offs + 4'd2; end							// ADD $SP,$SP,#8
			// POP Ra,Rb,Rc,Rd
			7'd5:		begin micro_ip <= 7'd6; reb[fetch0].ir <= {29'h00,5'd31,micro_ir[13: 9],1'b0,(micro_ir[31:29]>=3'd1)?LDH:NOP}; dlen <= 4'd4; end	// LDOS $Ra,[$SP]
			7'd6:		begin micro_ip <= 7'd7; reb[fetch0].ir <= {29'h10,5'd31,micro_ir[18:14],1'b0,(micro_ir[31:29]>=3'd2)?LDH:NOP}; end	// LDOS $Rb,[$SP]
			7'd7:		begin micro_ip <= 7'd8; reb[fetch0].ir <= {29'h20,5'd31,micro_ir[23:19],1'b0,(micro_ir[31:29]>=3'd3)?LDH:NOP}; end	// LDOS $Rc,[$SP]
			7'd8:		begin micro_ip <= 7'd9; reb[fetch0].ir <= {29'h30,5'd31,micro_ir[28:24],1'b0,(micro_ir[31:29]>=3'd4)?LDH:NOP}; end	// LDOS $Rc,[$SP]
			7'd9:		begin micro_ip <= 7'd0; reb[fetch0].ir <= {6'h0,micro_ir[31:29],4'h0,5'd31,5'd31,1'b0,ADDI}; ip.offs <= ip.offs + 4'd4; end							// ADD $SP,$SP,#24
			// PUSH Ra
			7'd10:	begin micro_ip <= 7'd11; reb[fetch0].ir <= {13'h1FF0,5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd2; end							// ADD $SP,$SP,#-16
			7'd11:	begin micro_ip <= 7'd0;  reb[fetch0].ir <= {29'h00,5'd31,micro_ir[13:9],1'b0,STH}; ip.offs <= ip.offs + 4'd2; end	// STOS $Ra,[$SP]
			// PUSH Ra,Rb,Rc,Rd
			7'd15:	begin micro_ip <= 7'd16; reb[fetch0].ir <= {{5'h1F,4'h0-micro_ir[31:29],4'h0},5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd4; end								// ADD $SP,$SP,#-24
			7'd16:	begin micro_ip <= 7'd17; reb[fetch0].ir <= {29'h00,5'd31,micro_ir[28:24],1'b0,(micro_ir[31:29]==3'd4)?STH:NOP}; end	// STOS $Rc,[$SP]
			7'd17:	begin micro_ip <= 7'd18; reb[fetch0].ir <= {22'd0,micro_ir[31:29]-2'd3,4'h0,5'd31,micro_ir[23:19],1'b0,(micro_ir[31:29]>=3'd3)?STH:NOP}; end	// STOS $Rb,8[$SP]
			7'd18:	begin micro_ip <= 7'd19; reb[fetch0].ir <= {22'd0,micro_ir[31:29]-2'd2,4'h0,5'd31,micro_ir[18:14],1'b0,(micro_ir[31:29]>=3'd2)?STH:NOP}; end	// STOS $Rb,8[$SP]
			7'd19:	begin micro_ip <= 7'd0;  reb[fetch0].ir <= {22'd0,micro_ir[31:29]-2'd1,4'h0,5'd31,micro_ir[13:9],1'b0,(micro_ir[31:29]>=3'd1)?STH:NOP}; ip.offs <= ip.offs + 4'd4; end		// STOS $Ra,16[$SP]
			// LEAVE
			7'd20:	begin micro_ip <= 7'd21; reb[fetch0].ir <= {13'h000,5'd30,5'd31,1'b0,ADDI};	end						// ADD $SP,$FP,#0
			7'd21:	begin micro_ip <= 7'd22; reb[fetch0].ir <= {29'h00,5'd31,5'd30,1'b0,LDH}; end				// LDO $FP,[$SP]
			7'd22:	begin micro_ip <= 7'd23; reb[fetch0].ir <= {29'h10,5'd31,5'd03,1'b0,LDH}; end				// LDO $T0,16[$SP]
			7'd23:	begin micro_ip <= 7'd26; reb[fetch0].ir <= {2'd1,5'd03,1'b0,MTLK}; end										// MTLK LK1,$T0
//			7'd24:	begin micro_ip <= 7'd25; ir <= {3'd6,8'h18,6'd63,6'd03,1'b0,LDOS}; end				// LDO $T0,24[$SP]
//			7'd25:	begin micro_ip <= 7'd26; ir <= {3'd0,1'b0,CSRRW,4'd0,16'h3103,6'd03,6'd00,1'b0,CSR}; end	// CSRRW $R0,$T0,0x3103
			7'd26: 	begin micro_ip <= 7'd27; reb[fetch0].ir <= {{6'h0,micro_ir[31:13]}+8'd4,4'b0,5'd31,5'd31,1'b0,ADDIL}; end	// ADD $SP,$SP,#Amt
			7'd27:	begin micro_ip <= 7'd0;  reb[fetch0].ir <= {1'd0,micro_ir[12:9],2'd1,1'b0,RTS}; ip.offs <= 32'hFFFD0000; end
			// STOO
			7'd28:	begin micro_ip <= 7'd29; reb[fetch0].ir <= {micro_ir[47:12],3'd0,1'b0,STOO}; dlen <= 4'd6; end
			7'd29:	begin micro_ip <= 7'd30; reb[fetch0].ir <= {micro_ir[47:12],3'd2,1'b0,STOO}; end
			7'd30:	begin micro_ip <= 7'd31; reb[fetch0].ir <= {micro_ir[47:12],3'd4,1'b0,STOO}; end
			7'd31:	begin micro_ip <= 7'd0;  reb[fetch0].ir <= {micro_ir[47:12],3'd6,1'b0,STOO}; ip.offs <= ip.offs + 4'd6; end
			// ENTER
			7'd32: 	begin micro_ip <= 7'd33; reb[fetch0].ir <= {13'h1FC0,5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd4; end						// ADD $SP,$SP,#-64
			7'd33:	begin micro_ip <= 7'd34; reb[fetch0].ir <= {29'h00,5'd31,5'd30,1'b0,STH}; end				// STO $FP,[$SP]
			7'd34:	begin micro_ip <= 7'd35; reb[fetch0].ir <= {2'd1,5'd03,1'b0,MFLK}; end										// MFLK $T0,LK1
			7'd35:	begin micro_ip <= 7'd38; reb[fetch0].ir <= {29'h10,5'd31,5'd03,1'b0,STH}; end				// STO $T0,16[$SP]
//			7'd36:	begin micro_ip <= 7'd37; ir <= {3'd0,1'b0,CSRRD,4'd0,16'h3103,6'd00,6'd03,1'b0,CSR}; end	// CSRRD $T0,$R0,0x3103
//			7'd37:	begin micro_ip <= 7'd38; ir <= {3'd6,8'h18,6'd63,6'd03,1'b0,STOS}; end				// STO $T0,24[$SP]
			7'd38:	begin micro_ip <= 7'd39; reb[fetch0].ir <= {29'h20,5'd31,5'd00,1'b0,STH}; end				// STH $R0,32[$SP]
			7'd39:	begin micro_ip <= 7'd40; reb[fetch0].ir <= {29'h30,5'd31,5'd00,1'b0,STH}; end				// STH $R0,48[$SP]
			7'd40: 	begin micro_ip <= 7'd41; reb[fetch0].ir <= {13'h000,5'd31,5'd30,1'b0,ADDI}; end						// ADD $FP,$SP,#0
			7'd41: 	begin micro_ip <= 7'd0;  reb[fetch0].ir <= {{9{micro_ir[31]}},micro_ir[31:12],3'b0,5'd31,5'd31,1'b0,ADDIL}; ip.offs <= ip.offs + 4'd4; end // SUB $SP,$SP,#Amt
			// DEFCAT
			7'd44:	begin micro_ip <= 7'd45; reb[fetch0].ir <= {3'd6,8'h00,6'd62,6'd3,1'b0,LDH}; dlen <= 4'd2; end					// LDO $Tn,[$FP]
			7'd45:	begin micro_ip <= 7'd46; reb[fetch0].ir <= {3'd6,8'h20,6'd3,6'd4,1'b0,LDHS}; end					// LDO $Tn+1,32[$Tn]
			7'd46:	begin micro_ip <= 7'd47; reb[fetch0].ir <= {3'd6,8'h10,6'd62,6'd4,1'b0,STHS}; end					// STO $Tn+1,16[$FP]
			7'd47:	begin micro_ip <= 7'd48; reb[fetch0].ir <= {3'd6,8'h28,6'd3,6'd4,1'b0,LDHS}; end					// LDO $Tn+1,40[$Tn]
			7'd48:	begin micro_ip <= 7'd0;  reb[fetch0].ir <= {3'd6,8'h18,6'd62,6'd4,1'b0,STHS}; ip.offs <= ip.offs + 4'd2; end					// STO $Tn+1,24[$FP]
			// BSETx
			7'd50:	begin micro_ip <= 7'd51; ir <= {micro_ir[34:32],23'h00,micro_ir[20:15],micro_ir[26:21],1'b0,4'h9,2'd0,micro_ir[30:29]}; end
			7'd51:	begin micro_ip <= 7'd52; ir <= {fnIamt(micro_ir[12:9]),micro_ir[20:15],micro_ir[20:15],1'b0,ADDI}; end
			7'd52:	begin micro_ip <= 7'd53; ir <= {11'h7FF,6'd58,6'd58,1'b0,ADDI}; end
			7'd53:	begin micro_ip <= 7'd51; ir <= {3'd0,8'd54,6'd58,7'd0,MJNEZ}; end
			7'd54:	begin micro_ip <= 7'd0;  ir <= NOP; ip.offs <= ip.offs + 4'd6; end
			7'd55:	begin micro_ip <= 7'd53; ir <= {11'h7FF,6'd58,6'd58,1'd0,ADDI}; end
			// STCTX
			7'd64:	begin micro_ip <= 7'd65; ir <= {micro_ir[15:13],30'h00,5'd0,1'b0,1'b0,STOO}; dlen <= 4'd2; end
			7'd65:	begin micro_ip <= 7'd66; ir <= {micro_ir[15:13],30'h10,5'd1,1'b0,1'b0,STOO}; end
			7'd66:	begin micro_ip <= 7'd67; ir <= {micro_ir[15:13],30'h20,5'd2,1'b0,1'b0,STOO}; end
			7'd67:	begin micro_ip <= 7'd68; ir <= {micro_ir[15:13],30'h30,5'd3,1'b0,1'b0,STOO}; end
			7'd68:	begin micro_ip <= 7'd69; ir <= {micro_ir[15:13],30'h40,5'd4,1'b0,1'b0,STOO}; end
			7'd69:	begin micro_ip <= 7'd70; ir <= {micro_ir[15:13],30'h50,5'd5,1'b0,1'b0,STOO}; end
			7'd70:	begin micro_ip <= 7'd71; ir <= {micro_ir[15:13],30'h60,5'd6,1'b0,1'b0,STOO}; end
			7'd71:	begin micro_ip <= 7'd72; ir <= {micro_ir[15:13],30'h70,5'd7,1'b0,1'b0,STOO}; end
			7'd72:	begin micro_ip <= 7'd73; ir <= {micro_ir[15:13],30'h80,5'd8,1'b0,1'b0,STOO}; end
			7'd73:	begin micro_ip <= 7'd74; ir <= {micro_ir[15:13],30'h90,5'd9,1'b0,1'b0,STOO}; end
			7'd74:	begin micro_ip <= 7'd75; ir <= {micro_ir[15:13],30'hA0,5'd10,1'b0,1'b0,STOO}; end
			7'd75:	begin micro_ip <= 7'd76; ir <= {micro_ir[15:13],30'hB0,5'd11,1'b0,1'b0,STOO}; end
			7'd76:	begin micro_ip <= 7'd77; ir <= {micro_ir[15:13],30'hC0,5'd12,1'b0,1'b0,STOO}; end
			7'd77:	begin micro_ip <= 7'd78; ir <= {micro_ir[15:13],30'hD0,5'd13,1'b0,1'b0,STOO}; end
			7'd78:	begin micro_ip <= 7'd79; ir <= {micro_ir[15:13],30'hE0,5'd14,1'b0,1'b0,STOO}; end
			7'd79:	begin micro_ip <= 7'd80; ir <= {micro_ir[15:13],30'hF0,5'd15,1'b0,1'b0,STOO}; end
			7'd80:	begin micro_ip <= 7'd81; ir <= {micro_ir[15:13],30'h100,5'd16,1'b0,1'b0,STOO}; end
			7'd81:	begin micro_ip <= 7'd82; ir <= {micro_ir[15:13],30'h110,5'd17,1'b0,1'b0,STOO}; end
			7'd82:	begin micro_ip <= 7'd83; ir <= {micro_ir[15:13],30'h120,5'd18,1'b0,1'b0,STOO}; end
			7'd83:	begin micro_ip <= 7'd84; ir <= {micro_ir[15:13],30'h130,5'd19,1'b0,1'b0,STOO}; end
			7'd84:	begin micro_ip <= 7'd85; ir <= {micro_ir[15:13],30'h140,5'd20,1'b0,1'b0,STOO}; end
			7'd85:	begin micro_ip <= 7'd86; ir <= {micro_ir[15:13],30'h150,5'd21,1'b0,1'b0,STOO}; end
			7'd86:	begin micro_ip <= 7'd87; ir <= {micro_ir[15:13],30'h160,5'd22,1'b0,1'b0,STOO}; end
			7'd87:	begin micro_ip <= 7'd88; ir <= {micro_ir[15:13],30'h170,5'd23,1'b0,1'b0,STOO}; end
			7'd88:	begin micro_ip <= 7'd89; ir <= {micro_ir[15:13],30'h180,5'd24,1'b0,1'b0,STOO}; end
			7'd89:	begin micro_ip <= 7'd90; ir <= {micro_ir[15:13],30'h190,5'd25,1'b0,1'b0,STOO}; end
			7'd90:	begin micro_ip <= 7'd91; ir <= {micro_ir[15:13],30'h1A0,5'd26,1'b0,1'b0,STOO}; end
			7'd91:	begin micro_ip <= 7'd92; ir <= {micro_ir[15:13],30'h1B0,5'd27,1'b0,1'b0,STOO}; end
			7'd92:	begin micro_ip <= 7'd93; ir <= {micro_ir[15:13],30'h1C0,5'd28,1'b0,1'b0,STOO}; end
			7'd93:	begin micro_ip <= 7'd94; ir <= {micro_ir[15:13],30'h1D0,5'd29,1'b0,1'b0,STOO}; end
			7'd94:	begin micro_ip <= 7'd95; ir <= {micro_ir[15:13],30'h1E0,5'd30,1'b0,1'b0,STOO}; end
			7'd95:	begin micro_ip <= 7'd0;  ir <= {micro_ir[15:13],30'h1F0,5'd31,1'b0,1'b0,STOO}; ip.offs <= ip.offs + 4'd2; end    
			// LDCTX
			7'd96:	begin micro_ip <= 7'd97;  ir <= {micro_ir[15:13],30'h00,3'd0,3'd1,1'b0,LDOO}; dlen <= 4'd2; end
			7'd97:	begin micro_ip <= 7'd98;  ir <= {micro_ir[15:13],30'h40,3'd1,3'd1,1'b0,LDOO}; end
			7'd98:	begin micro_ip <= 7'd99;  ir <= {micro_ir[15:13],30'h80,3'd2,3'd1,1'b0,LDOO}; end
			7'd99:	begin micro_ip <= 7'd100; ir <= {micro_ir[15:13],30'hC0,3'd3,3'd1,1'b0,LDOO}; end
			7'd100:	begin micro_ip <= 7'd101; ir <= {micro_ir[15:13],30'h100,3'd4,3'd1,1'b0,LDOO}; end
			7'd101:	begin micro_ip <= 7'd102; ir <= {micro_ir[15:13],30'h140,3'd5,3'd1,1'b0,LDOO}; end
			7'd102:	begin micro_ip <= 7'd103; ir <= {micro_ir[15:13],30'h180,3'd6,3'd1,1'b0,LDOO}; end
			7'd103:	begin micro_ip <= 7'd0;   ir <= {micro_ir[15:13],30'h1C0,3'd7,3'd1,1'b0,LDOO}; ip.offs <= ip.offs + 4'd2; end
			default:	;
			endcase
*/

Instruction mcir,mcir1;
wire [6:0] next_mip, next_mip1;
wire [3:0] incr, incr1;

Thor2022_micro_code umc1
(
	.micro_ipi(micro_ip),
	.next_mip(next_mip),
	.micro_ir(micro_ir),
	.ir(mcir),
	.incr(incr)
);

Thor2022_micro_code umc2
(
	.micro_ipi(next_mip),
	.next_mip(next_mip1),
	.micro_ir(micro_ir),
	.ir(mcir1),
	.incr(incr1)
);

wire [63:0] reb_fetch0_ir = reb[fetch0].ir;

function fnIsRepInsn;
input CodeAddress ip;
integer n;
begin
	fnIsRepInsn = 1'b0;
	for (n = 0; n < REB_ENTRIES; n = n + 1) begin
		if (reb[n].ip == ip && sns[n]==6'd63)
			fnIsRepInsn = 1'b1;
	end
end
endfunction


task tInsnFetch;
integer n;
begin
	prev_fetch0 <= fetch0;
	if (next_fetch0 != MaxSrcId)
		fetch0 <= next_fetch0;
	if (next_fetch1 != MaxSrcId)
		fetch1 <= next_fetch0;
	else
		fetch1 <= next_fetch0;
		
//	if (ihit && (reb[tail].state==EMPTY || reb[tail].state==RETIRED) && !branchmiss) begin// && ((tail + 2'd1) & 3'd7) != head0) begin
	if (branchmiss) begin
		//prev_ip <= ip;
		ip <= branchmiss_adr;
		tResetRegfileSrc();
		tNullReb(missid);
		clr_branchmiss <= 1'b1;
	end
	else if (ihit && !reb[fetch0].v && !branchmiss && fetch0 != prev_fetch0 && !fnIsRepInsn(ip)) begin// && ((tail + 2'd1) & 3'd7) != head0) begin
		prev_ip <= ip;
		// Age sequence numbers
		for (n = 0; n < REB_ENTRIES; n = n + 1) begin
			if (sns[n] > 'd0) begin
				if (fetch0!=fetch1 && fetch2)
					sns[n] <= sns[n] - 2'd2;
				else
					sns[n] <= sns[n] - 2'd1;
			end
		end
		if (fetch1!=fetch0 && fetch2)
		begin
			sns[fetch0] <= 6'd62;
			sns[fetch1] <= 6'd63;
			reb[fetch0].fetched <= 1'b1;
			reb[fetch0].v <= 1'b1;
			reb[fetch1].fetched <= 1'b1;
			reb[fetch1].v <= 1'b1;
		end
		else
		begin
			sns[fetch0] <= 6'd63;
			reb[fetch0].fetched <= 1'b1;
			reb[fetch0].v <= 1'b1;
		end
		ival <= VAL;
		dval <= ival;
		dlen <= ilen0;
		cio <= {2'b00,cio[15:2]};
		if (insn0.any.v && istep < vl) begin
			istep <= istep + 2'd1;
			ip <= ip;
		end
//		else if ((insn.any.opcode==BSET || insn.any.opcode==STMOV || insn.any.opcode==STFND || insn.any.opcode==STCMP) && r58 != 64'd0)
//			ip <= ip;
		else if (micro_ip != 'd0) begin
			if (fetch0!=fetch1 && fetch2)
			begin
				micro_ip <= next_mip1;
				reb[fetch0].ir <= mcir;
				reb[fetch1].ir <= mcir1;
			end
			else
			begin
				micro_ip <= next_mip;
				reb[fetch0].ir <= mcir;
			end
			if (next_mip=='d0) begin
				ip.offs <= ip.offs + incr;
				ip.micro_ip <= 7'd0;
			end
		end
		else begin
			istep <= 8'h00;
			ip <= next_ip;
		end
		if (btbe & btb_hit) begin
			btb_hit_count <= btb_hit_count + 2'd1;
			ip <= btb_tgt;
		end
		if (micro_ip=='d0) begin
			ir <= insn0;
			reb[fetch0].ir <= insn0;
			reb[fetch0].cause <= 16'h0000;
			$display("%d %h reb[%d].ir=%h", $time, ip, fetch0, insn0);
			if (fetch0!=fetch1 && fetch2)
				reb[fetch1].ir <= insn1;
			micro_ir <= insn0;
			case(insn0.any.opcode)
			POP:		begin micro_ip <= 7'd1; ip <= ip; ip.micro_ip <= 7'd127; end
			POP4R:	begin micro_ip <= 7'd5; ip <= ip; ip.micro_ip <= 7'd127; end
			PUSH:		begin micro_ip <= 7'd10; ip <= ip; ip.micro_ip <= 7'd127; end
			PUSH4R:	begin micro_ip <= 7'd15; ip <= ip; ip.micro_ip <= 7'd127; end
			ENTER:	begin micro_ip <= 7'd32; ip <= ip; ip.micro_ip <= 7'd127; end
			LEAVE:	begin micro_ip <= 7'd20; ip <= ip; ip.micro_ip <= 7'd127; end
//			STOO:		begin if (insn[10]) begin micro_ip <= 7'd28; ip <= ip; end end
			LDCTX:	begin micro_ip <= 7'd96; ip <= ip; ip.micro_ip <= 7'd127; end
			STCTX:	begin micro_ip <= 7'd64; ip <= ip; ip.micro_ip <= 7'd127; end
			BSET:		begin micro_ip <= 7'd55; ip <= ip; ip.micro_ip <= 7'd127; end
			// Note that BRA and JMP still need to be decoded for the execute stage
			// to work correctly.
			BRA:		
				begin
					ip.offs <= ip.offs + {{106{insn0[31]}},insn0[31:11],1'b0};
				end
			JMP:
				if (insn0.jmp.Rc=='d0) begin
					ip.offs <= {{94{insn0.jmp.Tgthi[18]}},insn0.jmp.Tgthi,insn0.jmp.Tgtlo,1'b0};
				end
				else if (insn0.jmp.Rc==3'd7) begin
					ip.offs <= ip.offs + {{94{insn0.jmp.Tgthi[18]}},insn0.jmp.Tgthi,insn0.jmp.Tgtlo,1'b0};
				end
			CARRY:	begin cio <= insn0[30:15]; cioreg <= insn0[11:9]; end
			default:	;
			endcase
		end
		reb[fetch0].ip.offs <= ip.offs;
		reb[fetch0].ip.micro_ip <= micro_ip;
		reb[fetch0].ilen <= ilen0;
		if (fetch0!=fetch1 && fetch2) begin
			reb[fetch1].ip.offs <= ip.offs + ilen0;
			reb[fetch1].ip.micro_ip <= next_mip;
			reb[fetch1].ilen <= ilen1;
		end
		/*
		if (micro_ip==7'd0) begin
			ir <= insn0;
			reb[fetch0].ir <= insn0;
			if (fetch0!=fetch1)
				reb[fetch1].ir <= insn1;
			micro_ir <= insn0;
		end
		*/		
		// Pop address from return address stack for prediction.
		if (micro_ip=='d0 || micro_ip==7'd27) begin
			if ((insn0.any.opcode==RTS && insn0[10:9]==2'b01) || micro_ip==7'd27) begin
				if (rts_sp > 5'd0) begin
					ip <= rts_stack[rts_sp-2'd1];
					rts_sp <= rts_sp - 1'd1;
					rts_pcount <= rts_pcount + 2'd1;
				end
			end
		end
		reb[fetch0].step <= istep;
		reb[fetch0].predict_taken <= ipredict_taken;
		if (fetch0!=fetch1 && fetch2)
			reb[fetch1].predict_taken <= ipredict_taken;
		dpfx <= is_prefix(insn0.any.opcode);
		distk_depth <= istk_depth;
		if (is_prefix(insn0.any.opcode))
			pfx_cnt <= pfx_cnt + 2'd1;
		else
			pfx_cnt <= 3'd0;
		if (di)
			dicnt <= dicnt - 2'd1;
		// Interrupts disabled while running micro-code.
		if (micro_ip=='d0 && cio==16'h0000) begin
			if (irq_i > pmStack[3:1] && gie && !dpfx && !di) begin
				reb[fetch0].cause <= 16'h8000|icause_i|(irq_i << 4'd8);
				//reb[fetch1].cause <= 16'h8000|icause_i|(irq_i << 4'd8);
				istk_depth <= istk_depth + 2'd1;
			end
			else if (wc_time_irq && gie && !dpfx && !di) begin
				reb[fetch0].cause <= {8'h80,FLT_TMR};
				//reb[fetch1].cause <= 16'h8000|FLT_TMR;
				istk_depth <= istk_depth + 2'd1;
			end
			// Triple prefix fault.
			else if (pfx_cnt > 3'd2) begin
				reb[fetch0].cause <= {8'h80,FLT_PFX};
				//reb[fetch1].cause <= 16'h8000|FLT_PFX;
				istk_depth <= istk_depth + 2'd1;
			end
			else begin
				if (insn0.any.opcode==BRK) begin
					reb[fetch0].cause <= FLT_BRK;
					istk_depth <= istk_depth + 2'd1;
				end
				/*
				else if (fetch0 != fetch1 && fetch2 && insn1.any.opcode==BRK) begin
					reb[fetch1].cause <= FLT_BRK;
					istk_depth <= istk_depth + 2'd1;
				end
				*/
			end
		end
		if (ipage_fault) begin
			reb[fetch0].cause <= {8'h80,FLT_CPF};
//			reb[fetch1].cause <= 16'h8000|FLT_CPF;
			istk_depth <= istk_depth + 2'd1;
			reb[fetch0].ir <= NOP_INSN;
			ir <= NOP_INSN;
		end
		if (itlbmiss) begin
			reb[fetch0].cause <= {8'h80,FLT_TLBMISS};
//			reb[fetch1].cause <= 16'h8000|FLT_TLBMISS;
			istk_depth <= istk_depth + 2'd1;
			reb[fetch0].ir <= NOP_INSN;
			ir <= NOP_INSN;
		end
		if (insn0.any.opcode==R1 && insn0.r3.func==DI)
			dicnt <= insn0[13:9];
//		if (insn1.any.opcode==R1 && insn1.r3.func==DI)
//			dicnt <= insn1[13:9];
	end
	// Wait for cache load
	else begin
//		else
			ip <= ip;
	end	
end
endtask


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction Decompress Stage
//
// Applicable only for compressed instructions.
// ToDo: add compressed instructions.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tDecompress0;
begin
	if (next_decompress0 != MaxSrcId)
		decompress0 <= #1 next_decompress0;
	if (reb[decompress0].fetched && !branchmiss) begin
		reb[decompress0].fetched <= 1'b0;
		reb[decompress0].decompressed <= 1'b1;
		reb[decompress0].ir <= reb[decompress0].ir ^ key;
	end
end
endtask

task tDecompress1;
begin
	if (next_decompress1 != MaxSrcId)
		decompress1 <= #1 next_decompress1;
	if (reb[decompress1].fetched && !branchmiss) begin
		reb[decompress1].fetched <= 1'b0;
		reb[decompress1].decompressed <= 1'b1;
		reb[decompress1].ir <= reb[decompress1].ir ^ key;
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Register fetch and decode stage
//
// Much of the decode is done above by combinational logic outside of the
// clock domain.
// Perform branching in this stage where possible. Relative and absolute
// branches can be performed here since the target address is known.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function fnNextInsnValid;
input [2:0] kk;
integer n;
begin
	fnNextInsnValid = 1'b0;
	for (n = 0; n < REB_ENTRIES; n = n + 1)
		if (sns[n]==sns[kk]+1)
			fnNextInsnValid = 1'b1;
end
endfunction

function fnPrevReg;
input [2:0] kk;
integer n;
begin
	fnPrevReg = 1'b0;
	for (n = 0; n < REB_ENTRIES; n = n + 1)
		if (sns[n]==sns[kk]-1 && reb[n].dec.isReg)
			fnPrevReg = 1'b1;
end
endfunction

function fnPrevInsn;
input [2:0] kk;
integer n;
begin
	fnPrevInsn = 3'd7;
	for (n = 0; n < REB_ENTRIES; n = n + 1)
		if (sns[n]==sns[kk]-1)
			fnPrevInsn = n;
end
endfunction

function fnNextInsn;
input [2:0] kk;
integer n;
begin
	fnNextInsn = 3'd7;
	for (n = 0; n < REB_ENTRIES; n = n + 1)
		if (sns[n]==sns[kk]+1)
			fnNextInsn = n;
end
endfunction

task tDecode;
integer n7;
begin
	if (next_dec0 != MaxSrcId) begin
		prev_dec <= dec;
		dec <= next_dec0;
	end
	if (reb[dec].decompressed && !branchmiss && reb[dec].v) begin
		$display("%d Decode[%d]:", $time, dec);
		$display("  ir=%h", reb[dec].ir);
		$display("  Ra=%d Rb=%d Rc=%d Rt=%d Rvm=%d", deco.Ra, deco.Rb, deco.Rc, deco.Rt, deco.Rvm);
		dec <= MaxSrcId;
		if (deco.mtlk)
			$stop;
		reb[dec].decompressed <= 1'b0;
		reb[dec].decoded <= 1'b1;
		reb[dec].dec <= deco;
		// There is no register fetch for an immediate prefix. Claim the stage is
		// done already.
		if (deco.isExi) begin
			reb[dec].decoded <= 1'b0;
			reb[dec].executed <= 1'b1;
		end
		reb[dec].istk_depth <= distk_depth;
		/*
		reb[dec].ia <= deco.Ravec ? vroa : {NLANES{rfoa}};
		reb[dec].ib <= deco.Rbvec ? vrob : {NLANES{rfob}};
		reb[dec].ic <= deco.Rcvec ? vroc : {NLANES{rfoc}};
		reb[dec].it <= deco.Rtvec ? vrot : {NLANES{rfot}};
		reb[dec].ca <= rfoca;
		reb[dec].iav <= rfoa_v;
		reb[dec].ibv <= rfob_v;
		reb[dec].icv <= rfoc_v;
		reb[dec].itv <= rfot_v;
		reb[dec].vmv <= rfom_v;
		*/
		reb[dec].idv <= !fnPrevReg(dec);
		reb[dec].lkv <= 1'b1;//(reb[head0].dec.Rt==deco.Rc && reb[head0].v && reb[head0].executed && reb[head0].dec.rfwr) || regfile_src[deco.Rc]==5'd31 || LkValid(reb[dec].ir);
		reb[dec].niv <= NextInsnValid(reb[dec].ir) || fnNextInsnValid(dec);
		/*
		reb[dec].ias <= Source1Valid(reb[dec].ir)||deco.Ra=='d0 ? 6'd31 : regfile_src[deco.Ra];
		reb[dec].ibs <= Source2Valid(reb[dec].ir)||deco.Rb=='d0 ? 6'd31 : regfile_src[deco.Rb];
		reb[dec].ics <= Source3Valid(reb[dec].ir)||deco.Rc=='d0 ? 6'd31 : regfile_src[deco.Rc];
		reb[dec].vms <= SourceMValid(reb[dec].ir) ? 6'd31 : regfile_src[deco.Rvm];
		reb[dec].lks <= LkValid(reb[dec].ir) ? 6'd31 : regfile_src[deco.Rc];
		*/
		reb[dec].cioreg <= cioreg;
		reb[dec].cio <= cio[1:0];
//		reb[dec].predict_taken <= dpredict_taken;
		reb[dec].step <= 'd0;
		reb[dec].count <= 'd0;
//		reb[dec].mask_bit <= mask[dstep];
//		reb[dec].vmask <= rfom;
		reb[dec].zbit <= deco.Rz;
		reb[dec].predictable_branch <= (deco.jxx && (reb[dec].ir.jxx.Rc=='d0 || reb[dec].ir.jxx.Rc==6'd31) || deco.jxz);
		
		if (fnPrevReg(dec)) begin
			if (reb[fnPrevInsn(dec)].decompressed) begin
				reb[fnPrevInsn(dec)].niv <= 1'b1;	// Allows REG to execute
				reb[dec].dec.Rt2 <= reb[fnPrevInsn(dec)].dec.Rt;
				reb[dec].ic <= reb[fnPrevInsn(dec)].ia;
				reb[dec].id <= reb[fnPrevInsn(dec)].ib;
				reb[dec].icv <= reb[fnPrevInsn(dec)].iav;
				reb[dec].idv <= reb[fnPrevInsn(dec)].ibv;
				reb[dec].ics <= reb[fnPrevInsn(dec)].ias;
				reb[dec].ids <= reb[fnPrevInsn(dec)].ibs;
			end
		end
		/*
		for (n7 = 0; n7 < 32; n7 = n7 + 1)
			if (regfile_src[n7]==dec && n7 != deco.Rt && n7 != head0) begin
				$display("%d Register %d source not reset.", $time, n7);
				//regfile_src[n7] <= 5'd31;
			end
		*/
		if (deco.carfwr)
			eip_src[deco.Ct] <= dec;
		
		
		if (reb[dec].ir.jxx.Rc=='d0 && deco.jxx && reb[dec].predict_taken && bpe) begin	// Jxx, DJxx
			if (ip.offs != deco.jmptgt) begin
				branchmiss_adr.offs <= deco.jmptgt;
				branchmiss_adr.micro_ip <= 'd0;
				xx <= 4'd1;
			end
			tStackRetadr(dec);
		end
		else if (reb[dec].ir.jxx.Rc==6'd31 && deco.jxx && reb[dec].predict_taken && bpe) begin	// Jxx, DJxx
			if (ip.offs != reb[dec].ip.offs + deco.jmptgt) begin
				branchmiss_adr.offs <= reb[dec].ip.offs + deco.jmptgt;
				branchmiss_adr.micro_ip <= 'd0;
				xx <= 4'd2;
			end
			tStackRetadr(dec);
		end
		else if (deco.jxz && reb[dec].predict_taken && bpe) begin	// Jxx, DJxx
			if (ip.offs != reb[dec].ip.offs + deco.jmptgt) begin
				branchmiss_adr.offs <= reb[dec].ip.offs + deco.jmptgt;
				branchmiss_adr.micro_ip <= 'd0;
				xx <= 4'd3;
			end
			tStackRetadr(dec);
		end
		
		if (deco.jmp|deco.bra|deco.jxx)
  		reb[dec].cares.offs <= reb[dec].ip.offs + reb[dec].ilen;
//  	else if (deco.mtlk)
//  		reb[dec].cares.offs <= rfoc;//(reb[head0].dec.Rt==deco.Rc && reb[head0].v && reb[head0].state==EXECUTED && reb[head0].dec.rfwr) ? reb[head0].res : regfile[deco.Rc];
	end
end
endtask

SrcId nxt_regfetch0;
always_comb
	if (next_regfetch0 != MaxSrcId)
		nxt_regfetch0 <= next_regfetch0;
	else
		nxt_regfetch0 <= regfetch0;
always_comb
	reb[regfetch0].nxt_rfetched <= reb[regfetch0].decoded && !branchmiss && reb[regfetch0].v;
always_comb
begin
	reb[regfetch0].nxt_iav <= rfoa_v;
	reb[regfetch0].nxt_ibv <= rfob_v;
	reb[regfetch0].nxt_icv <= rfoc_v;
	reb[regfetch0].nxt_itv <= rfot_v;
	reb[regfetch0].nxt_vmv <= rfom_v;
end
always_comb
begin
		reb[regfetch0].nxt_ias <= Source1Valid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Ra];
		reb[regfetch0].nxt_ibs <= Source2Valid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rb];
		reb[regfetch0].nxt_ics <= Source3Valid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rc];
		reb[regfetch0].nxt_its <= SourceTValid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rt];
		reb[regfetch0].nxt_vms <= SourceMValid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rvm];
end

task tRegfetch;
integer n;
begin
	regfetch0 <= nxt_regfetch0;
	if (reb[regfetch0].decoded && !branchmiss && reb[regfetch0].v) begin
		$display("Regfetch[%d] %d", regfetch0, $time);
		$display("  Ra=%d iav=%d ias=%d rfoa=%h", reb[regfetch0].dec.Ra, rfoa_v, Source1Valid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Ra], rfoa);
		$display("  Rb=%d ibv=%d ibs=%d rfob=%h", reb[regfetch0].dec.Rb, rfob_v, Source2Valid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rb], rfob);
		$display("  Rc=%d icv=%d ics=%d rfoc=%h", reb[regfetch0].dec.Rc, rfoc_v, Source3Valid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rc], rfoc);
		reb[regfetch0].decoded <= 1'b0;
		reb[regfetch0].rfetched <= 1'b1;
		reb[regfetch0].ia <= reb[regfetch0].dec.Ravec ? vroa : {NLANES{rfoa}};
		reb[regfetch0].ib <= reb[regfetch0].dec.Rbvec ? vrob : {NLANES{rfob}};
		reb[regfetch0].ic <= reb[regfetch0].dec.Rcvec ? vroc : {NLANES{rfoc}};
		reb[regfetch0].it <= reb[regfetch0].dec.Rtvec ? vrot : {NLANES{rfot}};
		reb[regfetch0].iav <= rfoa_v;
		reb[regfetch0].ibv <= rfob_v;
		reb[regfetch0].icv <= rfoc_v;
		reb[regfetch0].itv <= rfot_v;
		reb[regfetch0].vmv <= rfom_v;
		reb[regfetch0].ias <= Source1Valid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Ra];
		reb[regfetch0].ibs <= Source2Valid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rb];
		reb[regfetch0].ics <= Source3Valid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rc];
		reb[regfetch0].its <= SourceTValid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rt];
		reb[regfetch0].vms <= SourceMValid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rvm];
		reb[regfetch0].lks <= LkValid(reb[regfetch0].ir) ? 6'd31 : regfile_src[reb[regfetch0].dec.Rc];
		reb[regfetch0].vmask <= rfom;
		
		/*
		if (head0==regfile_src[reb[regfetch0].dec.Ra] && reb[head0].dec.rfwr) begin
			reb[regfetch0].iav <= 1'b1;
			reb[regfetch0].ia <= reb[regfetch0].dec.Ravec ? reb[head0].res : {NLANES{reb[head0].res[0]}};
		end
		if (head0==regfile_src[reb[regfetch0].dec.Rb] && reb[head0].dec.rfwr) begin
			reb[regfetch0].ibv <= 1'b1;
			reb[regfetch0].ib <= reb[regfetch0].dec.Rbvec ? reb[head0].res : {NLANES{reb[head0].res[0]}};
		end
		if (head0==regfile_src[reb[regfetch0].dec.Rc] && reb[head0].dec.rfwr) begin
			reb[regfetch0].icv <= 1'b1;
			reb[regfetch0].ic <= reb[regfetch0].dec.Rbvec ? reb[head0].res : {NLANES{reb[head0].res[0]}};
		end
		if (head0==regfile_src[reb[regfetch0].dec.Rt] && reb[head0].dec.rfwr) begin
			reb[regfetch0].itv <= 1'b1;
			reb[regfetch0].it <= reb[regfetch0].dec.Rbvec ? reb[head0].res : {NLANES{reb[head0].res[0]}};
		end
		if (head0==regfile_src[reb[regfetch0].dec.Rvm] && reb[head0].dec.rfwr) begin
			reb[regfetch0].vmv <= 1'b1;
			reb[regfetch0].vmask <= reb[head0].res[0];
		end
		*/
		/*
		if (commit0_src==regfile_src[reb[regfetch0].dec.Ra] && commit0_wr) begin
			reb[regfetch0].iav <= 1'b1;
			reb[regfetch0].ia <= reb[regfetch0].dec.Ravec ? commit0_bus : {NLANES{commit0_bus[0]}};
		end
		if (commit0_src==regfile_src[reb[regfetch0].dec.Rt] && commit0_wr) begin
			reb[regfetch0].itv <= 1'b1;
			reb[regfetch0].it <= reb[regfetch0].dec.Ravec ? commit0_bus : {NLANES{commit0_bus[0]}};
		end
		*/
		regfetch0 <= MaxSrcId;
	end

	if (exec != MaxSrcId) begin
		if (reb[exec].dec.Rt==reb[fnNextInsn(exec)].dec.Ra && reb[exec].dec.rfwr && reb[exec].executed) begin
			reb[fnNextInsn(exec)].iav <= 1'b1;
			reb[fnNextInsn(exec)].ia <= reb[fnNextInsn(exec)].dec.Ravec ? reb[exec].res : {NLANES{reb[exec].res[0]}};
		end
		if (reb[exec].dec.Rt==reb[fnNextInsn(exec)].dec.Rb && reb[exec].dec.rfwr && reb[exec].executed) begin
			reb[fnNextInsn(exec)].ibv <= 1'b1;
			reb[fnNextInsn(exec)].ib <= reb[fnNextInsn(exec)].dec.Rbvec ? reb[exec].res : {NLANES{reb[exec].res[0]}};
		end
		if (reb[exec].dec.Rt==reb[fnNextInsn(exec)].dec.Rc && reb[exec].dec.rfwr && reb[exec].executed) begin
			reb[fnNextInsn(exec)].icv <= 1'b1;
			reb[fnNextInsn(exec)].ic <= reb[fnNextInsn(exec)].dec.Rcvec ? reb[exec].res : {NLANES{reb[exec].res[0]}};
		end
		if (reb[exec].dec.Rt==reb[fnNextInsn(exec)].dec.Rt && reb[exec].dec.rfwr && reb[exec].executed) begin
			reb[fnNextInsn(exec)].itv <= 1'b1;
			reb[fnNextInsn(exec)].it <= reb[fnNextInsn(exec)].dec.Rtvec ? reb[exec].res : {NLANES{reb[exec].res[0]}};
		end
		if (reb[exec].dec.Rt==reb[fnNextInsn(exec)].dec.Rvm && reb[exec].dec.rfwr && reb[exec].executed) begin
			reb[fnNextInsn(exec)].vmv <= 1'b1;
			reb[fnNextInsn(exec)].vmask <= reb[exec].res[0];
		end
	end

end
endtask

task tMarkExecDone;
begin
	reb[exec].rfetched <= 1'b0;
	reb[exec].out <= 1'b0;
	reb[exec].executed <= reb[exec].v & !stomp[exec];
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Add memory ops to the memory queue.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tLoad;
input load_gather;
input Address vadr;		// vector address
input Address sadr;		// scalar address
begin
	memreq.tid <= {tid,exec};
	tid <= tid + 2'd1;
	memreq.ip <= reb[exec].ip;
	memreq.func <= reb[exec].dec.ldz ? MR_LOADZ : MR_LOAD;
	case(reb[exec].dec.memsz)
	byt:		begin memreq.func2 <= MR_LDB; end
	wyde:		begin memreq.func2 <= MR_LDW; end
	tetra:	begin memreq.func2 <= MR_LDT; end
	octa:		begin memreq.func2 <= MR_LDO; end
//	hexi:		begin memreq.func2 <= MR_LDH; end
	default:	begin memreq.func2 <= MR_LDO; end
	endcase
	memreq.sz <= reb[exec].dec.memsz;
	memreq.dat <= reb[exec].it[reb[exec].step];
	if (reb[exec].dec.is_vector) begin
		//memreq.func2 <= MR_LDO;
		if (load_gather) begin
			memreq.func2 <= MR_LDG;
			memreq.step <= reb[exec].step;
			memreq.count <= reb[exec].count;
	  	memreq.adr.offs <= vadr;
	  	// If not loading a compressed vector, always increment count.
	  	if (!reb[exec].ir[27] && !memreq_full) begin
	  		memreq.count <= reb[exec].count + 2'd1;
	  		reb[exec].count <= reb[exec].count + 2'd1;
	  	end
			if (reb[exec].vmask[reb[exec].step]) begin
				if (!memreq_full) begin
	  			memreq.wr <= TRUE;
	  			memreq.count <= reb[exec].count + 2'd1;
	  			reb[exec].count <= reb[exec].count + 2'd1;
	  		end
	  	end
	  	else if (reb[exec].zbit)
	  		memreq.sz <= nul;
	  	//if (reb[exec].step==NLANES-1 && !memreq_full)
			//	tMarkMem();
		end
		else begin
			memreq.func2 <= MR_LDV;
	  	memreq.adr.offs <= vadr;
	  	if (!memreq_full) begin
	  		memreq.wr <= TRUE;
	  		reb[exec].count <= 0;
	  		reb[exec].step <= 0;
  		end
		end
	end
	else begin
		memreq.adr.offs <= sadr;
		if (!memreq_full) begin
			memreq.wr <= TRUE;
		end
		else begin
			reb[exec].rfetched <= 1'b1;
			reb[exec].out <= 1'b0;
		end
	end
end
endtask

task tMemHist;
begin
	if (memreq.wr) begin
		if (memreq.func==MR_STORE) begin
			storeHistory[shndx] <= memreq;
			shndx <= shndx + 2'd1;
		end
	end
end
endtask

task tStore;
input scatter;
input Address vadr;		// vector address
input Address sadr;		// scalar address
begin
	memreq.tid <= {tid,exec};
	tid <= tid + 2'd1;
	memreq.func <= MR_STORE;
	memreq.ip <= reb[exec].ip;
	case(reb[exec].dec.memsz)
	byt:		begin memreq.func2 <= MR_STB; end
	wyde:		begin memreq.func2 <= MR_STW; end
	tetra:	begin memreq.func2 <= MR_STT; end
	octa:		begin memreq.func2 <= MR_STO; end
//	hexi:		begin memreq.func2 <= MR_STH; end
	default:	begin memreq.func2 <= MR_STO; end
	endcase
	memreq.sz <= reb[exec].dec.memsz;
	// For a scatter operation there will be separate writes queued to memory
	// for each vector lane.
	case(reb[exec].dec.memsz)
	byt:
		case(reb[exec].step[2:0])
		3'd0:	memreq.dat <= reb[exec].ic[reb[exec].step >> 3][ 7: 0];
		3'd1:	memreq.dat <= reb[exec].ic[reb[exec].step >> 3][15: 8];
		3'd2:	memreq.dat <= reb[exec].ic[reb[exec].step >> 3][23:16];
		3'd3:	memreq.dat <= reb[exec].ic[reb[exec].step >> 3][31:24];
		3'd4:	memreq.dat <= reb[exec].ic[reb[exec].step >> 3][39:32];
		3'd5:	memreq.dat <= reb[exec].ic[reb[exec].step >> 3][47:40];
		3'd6:	memreq.dat <= reb[exec].ic[reb[exec].step >> 3][55:48];
		3'd7:	memreq.dat <= reb[exec].ic[reb[exec].step >> 3][63:56];
		endcase
	wyde:
		case(reb[exec].step[1:0])
		2'd0:	memreq.dat <= reb[exec].ic[reb[exec].step >> 2][15: 0];
		2'd1:	memreq.dat <= reb[exec].ic[reb[exec].step >> 2][31:16];
		2'd2:	memreq.dat <= reb[exec].ic[reb[exec].step >> 2][47:32];
		2'd3:	memreq.dat <= reb[exec].ic[reb[exec].step >> 2][63:48];
		endcase
	tetra:
		case(reb[exec].step[0])
		1'd0:	memreq.dat <= reb[exec].ic[reb[exec].step >> 1][31: 0];
		1'd1:	memreq.dat <= reb[exec].ic[reb[exec].step >> 1][63:32];
		endcase
	octa:		memreq.dat <= reb[exec].ic[reb[exec].step];
	default:	memreq.dat <= reb[exec].ic[reb[exec].step];
	endcase
	if (reb[exec].dec.is_vector) begin
		//memreq.func2 <= MR_STO;
  	memreq.adr.offs <= vadr;
		if (reb[exec].vmask[reb[exec].step] && !memreq_full) begin
  		memreq.wr <= TRUE;
  		memreq.count <= reb[exec].count + 2'd1;
  		reb[exec].count <= reb[exec].count + 2'd1;
  	end
  	else if (reb[exec].zbit) begin
  		// If not compressing the vector, write out a zero.
  		if (!reb[exec].ir[27] && !memreq_full) begin
	  		reb[exec].count <= reb[exec].count + 2'd1;
	  		memreq.count <= reb[exec].count + 2'd1;
  			memreq.wr <= TRUE;
	  		memreq.dat <= 'd0;
	  	end
  	end
  	else begin
  		// If not compressing vector, skip over storage.
  		if (!reb[exec].ir[27])
	  		reb[exec].count <= reb[exec].count + 2'd1;
  	end
  	//if (reb[exec].step==NLANES-1 && !memreq_full)
		//	tMarkMem();
	end
	else begin
  	memreq.adr.offs <= sadr;
		if (!memreq_full) begin
			memreq.wr <= TRUE;
		end
		else begin
			reb[exec].rfetched <= 1'b1;
			reb[exec].out <= 1'b0;
		end
	end
end
endtask

task tExMultiCycle;
begin
	if (!reb[exec].out) begin
	  if (reb[exec].dec.mulall) begin
	  	aqe_wr <= !aqe_full;
	  	reb[exec].out <= !aqe_full;
	  	if (!aqe_full)
				tMarkExecDone();
//	    goto(MUL1);
	  end
	  else if (reb[exec].dec.divall) begin
	  	aqe_wr <= !aqe_full;
	  	reb[exec].out <= !aqe_full;
	  	if (!aqe_full)
				tMarkExecDone();
//	    goto(DIV1);
	  end
	  else if (reb[exec].dec.isDF) begin
	  	aqe_wr <= !aqe_full;
	  	reb[exec].out <= !aqe_full;
	  	if (!aqe_full)
				tMarkExecDone();
//	  	goto (DF1);
	  end
//    if (xFloat)
//      goto(FLOAT1);
	  else if (reb[exec].dec.loadr) begin
	  	tLoad(1'b0,
	  				reb[exec].ia[0] + reb[exec].dec.imm,
	  				reb[exec].ia[0] + reb[exec].dec.imm);
	  	//goto (WAIT_MEM1);
	  end
	  else if (reb[exec].dec.loadn) begin
	  	tLoad(
	  		reb[exec].dec.is_vector && reb[exec].dec.Rbvec,
	  		reb[exec].ia[0] + (reb[exec].dec.Rbvec ? reb[exec].ib[reb[exec].count] : (reb[exec].ib[0] + reb[exec].count * $bits(Value))),
	  		reb[exec].ia[0] + reb[exec].ib[0]);
	  	//goto (WAIT_MEM1);
	  end
	  else if (reb[exec].dec.ldoo) begin
	  	memreq.tid <= {tid,exec};
	  	tid <= tid + 2'd1;
	  	memreq.func <= MR_LOAD;
	  	memreq.func2 <= MR_LDOO;
//	  	memreq.sz <= hexiquad;
	  	memreq.adr.offs <= reb[exec].ia[0] + reb[exec].dec.imm;
	  	memreq.adr.offs[5:0] <= 6'h00;
	  	memreq.wr <= TRUE;
	  	//goto (WAIT_MEM1);
	  end
	  else if (reb[exec].dec.storer) begin
	  	case(reb[exec].dec.memsz)
	  	byt:
		  	tStore(
		  		1'b0,
		  		reb[exec].ia[0] + reb[exec].count * 8 + reb[exec].dec.imm,
		  		reb[exec].ia[0] + reb[exec].dec.imm
		  	);
		  wyde:
		  	tStore(
		  		1'b0,
		  		reb[exec].ia[0] + reb[exec].count * 16 + reb[exec].dec.imm,
		  		reb[exec].ia[0] + reb[exec].dec.imm
		  	);
		  tetra:
		  	tStore(
		  		1'b0,
		  		reb[exec].ia[0] + reb[exec].count * 32 + reb[exec].dec.imm,
		  		reb[exec].ia[0] + reb[exec].dec.imm
		  	);
	  	default:
		  	tStore(
		  		1'b0,
		  		reb[exec].ia[0] + reb[exec].count * 64 + reb[exec].dec.imm,
		  		reb[exec].ia[0] + reb[exec].dec.imm
		  	);
		  endcase
	  	//goto (WAIT_MEM1);
	  end
	  else if (reb[exec].dec.storen) begin
	  	case(reb[exec].dec.memsz)
	  	byt:
		  	tStore(
		  		1'b0,
		  		reb[exec].ia[0] + (reb[exec].dec.Rbvec ? reb[exec].ib[reb[exec].step] : (reb[exec].ib[0] + reb[exec].count * 8)),
		  		reb[exec].ia[0] + reb[exec].ib[0]
		  	);
	  	wyde:
		  	tStore(
		  		1'b0,
		  		reb[exec].ia[0] + (reb[exec].dec.Rbvec ? reb[exec].ib[reb[exec].step] : (reb[exec].ib[0] + reb[exec].count * 16)),
		  		reb[exec].ia[0] + reb[exec].ib[0]
		  	);
	  	tetra:
		  	tStore(
		  		1'b0,
		  		reb[exec].ia[0] + (reb[exec].dec.Rbvec ? reb[exec].ib[reb[exec].step] : (reb[exec].ib[0] + reb[exec].count * 32)),
		  		reb[exec].ia[0] + reb[exec].ib[0]
		  	);
		  default:
		  	tStore(
		  		1'b0,
		  		reb[exec].ia[0] + (reb[exec].dec.Rbvec ? reb[exec].ib[reb[exec].step] : (reb[exec].ib[0] + reb[exec].count * 64)),
		  		reb[exec].ia[0] + reb[exec].ib[0]
		  	);
		  endcase
	  	//goto (WAIT_MEM1);
	  end
		else if (reb[exec].dec.stset) begin
			if (reb[exec].ic != 64'd0) begin
		  	memreq.tid <= {tid,exec};
		  	tid <= tid + 2'd1;
		  	memreq.func <= MR_STORE;
		  	case(reb[exec].ir[30:29])
		  	2'd0:	begin memreq.func2 <= MR_STB; end
		  	2'd1:	begin memreq.func2 <= MR_STW; end
		  	2'd2:	begin memreq.func2 <= MR_STT; end
		  	default:	begin memreq.func2 <= MR_STO; end
		  	endcase
		  	memreq.sz <= {1'b0,reb[exec].ir[30:29]};
		  	memreq.adr.offs <= reb[exec].ia[0];
		  	memreq.dat <= reb[exec].ib[0];
		  	memreq.wr <= TRUE;
		  	//goto (WAIT_MEM1);
	  	end
	  	else
	  		reb[exec].dec.stset <= FALSE;
		end
		else if (reb[exec].dec.stmov) begin
			if (reb[exec].ic != 64'd0) begin
		  	memreq.tid <= {tid,exec};
		  	tid <= tid + 2'd1;
		  	memreq.func <= MR_MOVLD;
		  	case(reb[exec].ir[43:41])
		  	2'd0:	begin memreq.func2 <= MR_STB; end
		  	2'd1:	begin memreq.func2 <= MR_STW; end
		  	2'd2:	begin memreq.func2 <= MR_STT; end
		  	default:	begin memreq.func2 <= MR_STO; end
		  	endcase
		  	memreq.sz <= {1'b0,reb[exec].ir[42:41]};
		  	memreq.adr.offs <= reb[exec].ia[0] + reb[exec].ic[0];
		  	memreq.dat <= reb[exec].ib[0] + reb[exec].ic[0];
		  	memreq.wr <= TRUE;
		  	//goto (WAIT_MEM1);
	  	end
	  	else
	  		reb[exec].dec.stmov <= FALSE;
		end
		// Trap invalid op to prevent hang.
		else begin
			tMarkExecDone();
			mc_busy <= FALSE;
		end
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Perform conditional jump or branch operation.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tJxx;
integer n;
begin
  if (reb[exec].dec.jxx|reb[exec].dec.jxz) begin
  	if (reb[exec].predictable_branch)
  		cbranch_count <= cbranch_count + 2'd1;
  	if (!takb)
  		md.carfwr <= FALSE;
    if (bpe) begin
      if (reb[exec].predict_taken && !takb && reb[exec].predictable_branch) begin
        branchmiss_adr.offs <= reb[exec].ip.offs + reb[exec].ilen;
        cbranch_miss <= cbranch_miss + 2'd1;
				xx <= 4'd4;
      end
      else if ((!reb[exec].predict_taken && takb) || !reb[exec].predictable_branch) begin
      	tBranch(4'd3);
  			if (reb[exec].predictable_branch)
	        cbranch_miss <= cbranch_miss + 2'd1;
      end
    end
    else if (takb)
    	tBranch(4'd4);
    //$display("Branch hit=%f", real'(cbranch_count-cbranch_miss)/real'(cbranch_count)*100.0);
  end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Micro-code jump operation. Not currently used.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tMjnez;
begin
	if (reb[exec].dec.mjnez) begin
		if (!takb)
			micro_ip <= xir[28:21];
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Peform unconditional JMP operation.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tJmp;
begin
  if (reb[exec].dec.jmp) begin
 		reb[exec].takb <= 1'b1;
  	if (reb[exec].dec.dj ? (reb[exec].ia[0] != 64'd0) : (reb[exec].dec.Rc != 'd0 && reb[exec].dec.Rc != 6'd31))	// ==0,7 was already done at ifetch
  		tBranch(4'd5);
  	else
  		tStackRetadr(exec);
  	$display("%d EXEC: %h JMP", $time, reb[exec].ip);
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Perform BRA operation.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tBra;
begin
  if (reb[exec].dec.bra) begin
 		reb[exec].takb <= 1'b1;
  	if (reb[exec].dec.Rc != 'd0 && reb[exec].dec.Rc != 6'd31)	// ==0,7 was already done at ifetch
  		tBranch(4'd6);
  	else
  		tStackRetadr(exec);
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Perform return. If the return address is already correct then do not
// branch.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tRts;
integer n;
begin
	if (reb[exec].dec.rts) begin
		if (!ret_match) begin
			if (reb[exec].ir.rts.lk != 2'd0) begin
				tNullReb(exec);
	  		branchmiss_adr.offs <= reb[exec].ic[0];// + {reb[exec].ir.rts.cnst,1'b0};
	  		branchmiss_adr.micro_ip <= 'd0;
	  		reb[exec].jmptgt <= reb[exec].ic[0];
	  		reb[exec].takb <= 1'b1;
				xx <= 4'd5;
	  		$display("%d EXEC: %h RTS to %h", $time, reb[exec].ip, reb[exec].ic[0] + {reb[exec].ir.rts.cnst,1'b0});
			end
		end
		else
			ret_match_count <= ret_match_count + 2'd1;
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Stack the return address on an internal stack for prediction purposes.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tStackRetadr;
input SSrcId id;
begin
//	if (|reb[id].dec.lk)
//		tArgCaUpdate(exec,cares);
	if (reb[id].dec.lk==2'b01) begin
		if (rts_sp < 5'd31) begin
			rts_stack[rts_sp] <= reb[id].ip.offs + reb[id].ilen;
			rts_sp <= rts_sp + 2'd1;
		end
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute REG prefix
// Uses a lot of LUTs.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tExReg;
begin
	if (reb[exec].dec.isReg) begin
		reb[fnNextInsn(exec)].dec.Rt2 = reb[exec].dec.Rt;
		if (!reb[fnNextInsn(exec)].icv) begin
			reb[fnNextInsn(exec)].icv <= 1'b1;
			reb[fnNextInsn(exec)].ic <= reb[exec].ia;
		end
		if (!reb[fnNextInsn(exec)].idv) begin
			reb[fnNextInsn(exec)].idv <= 1'b1;
			reb[fnNextInsn(exec)].id <= reb[exec].ib;
		end
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute stage
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tExecute;
integer n;
integer nn;
begin
	// Is there anything to execute?
	if (next_exec != MaxSrcId)
		exec <= next_exec;
	if ((reb[exec].rfetched || reb[exec].out) & reb[exec].v & !stomp[exec]) begin
		$display("%h", reb[exec].ip);
		disassem(reb[exec].ip,reb[exec].ir);
		if (fnArgsValid(exec)) begin
			if (reb[exec].dec.is_valu)
				reb[exec].res <= vres;
			else
				reb[exec].res <= res;
			reb[exec].res_t2 <= res_t2;
			if (reb[exec].v) begin
				if (!reb[exec].dec.multi_cycle) begin
					tBra();
					tJxx();
			    tJmp();
			    tRts();
			    tExReg();
					if (reb[exec].dec.is_valu)
						tArgUpdate(exec,vres);
					else
						tArgUpdate(exec,res);
					tMarkExecDone();
				end
				else //if (!mc_busy)
				begin
					reb[exec].rfetched <= 1'b0;
					reb[exec].out <= 1'b1;
					// For a vector load, if a gather operation execute the multi-cycle operation
					// multiple time until the entire vector is loaded.
					if (reb[exec].dec.is_vector && (reb[exec].dec.loadn && reb[exec].dec.Rbvec)) begin
						reb[exec].step <= reb[exec].step + 2'd1;
						if (reb[exec].step==NLANES-1) begin
							reb[exec].step <= 'd0;
							reb[exec].count <= 'd0;
							tMarkExecDone();
						end
						else begin
							reb[exec].rfetched <= 1'b1;
							reb[exec].out <= 1'b0;
						end
					end
					// For a vector store execute the multi-cycle operation multiple times until
					// the entire vector is queued.
					else if (reb[exec].dec.is_vector && (reb[exec].dec.storer || reb[exec].dec.storen)) begin
						reb[exec].step <= reb[exec].step + 2'd1;
						if (reb[exec].step==NLANES-1) begin
							reb[exec].step <= 'd0;
							reb[exec].count <= 'd0;
							tMarkExecDone();
						end
						else begin
							reb[exec].rfetched <= 1'b1;
							reb[exec].out <= 1'b0;
						end
					end
					tExMultiCycle();
				end
			end	// xval
			exec <= next_exec;
		end
	end
end
endtask


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Update arguments as results come in from various busses.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tArgUpdate;
input SSrcId m;
input VecValue bus;
integer n;
begin
	for (n = 0; n < REB_ENTRIES; n = n + 1) begin
		if (!reb[n].iav && reb[n].rfetched) begin
			if (reb[n].ias==m) begin
				reb[n].ia <= bus;
				reb[n].iav <= 1'b1;
			end
		end
		if (!reb[n].ibv && reb[n].rfetched) begin
			if (reb[n].ibs==m) begin
				reb[n].ib <= bus;
				reb[n].ibv <= 1'b1;
			end
		end
		if (!reb[n].icv && reb[n].rfetched) begin
			if (reb[n].ics==m) begin
				reb[n].ic <= bus;
				reb[n].icv <= 1'b1;
			end
		end
		if (!reb[n].itv && reb[n].rfetched) begin
			if (reb[n].its==m) begin
				reb[n].it <= bus;
				reb[n].itv <= 1'b1;
			end
		end
		if (!reb[n].vmv && reb[n].rfetched) begin
			if (reb[n].vms==m) begin
				reb[n].vmask <= bus;
				reb[n].vmv <= 1'b1;
			end
		end
		/*
		if (!reb[n].nxt_iav && reb[n].nxt_rfetched) begin
			if (reb[n].nxt_ias==m) begin
				reb[n].ia <= bus;
				reb[n].iav <= 1'b1;
			end
		end
		if (!reb[n].nxt_ibv && reb[n].nxt_rfetched) begin
			if (reb[n].nxt_ibs==m) begin
				reb[n].ib <= bus;
				reb[n].ibv <= 1'b1;
			end
		end
		if (!reb[n].nxt_icv && reb[n].nxt_rfetched) begin
			if (reb[n].nxt_ics==m) begin
				reb[n].ic <= bus;
				reb[n].icv <= 1'b1;
			end
		end
		if (!reb[n].nxt_itv && reb[n].nxt_rfetched) begin
			if (reb[n].nxt_its==m) begin
				reb[n].it <= bus;
				reb[n].itv <= 1'b1;
			end
		end
		if (!reb[n].nxt_vmv && reb[n].nxt_rfetched) begin
			if (reb[n].nxt_vms==m) begin
				reb[n].vmask <= bus;
				reb[n].vmv <= 1'b1;
			end
		end
		*/
		if (!reb[n].idv && reb[n].rfetched) begin
			if (reb[n].ids==m) begin
				reb[n].id <= bus;
				reb[n].idv <= 1'b1;
			end
		end
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Writeback stage
//
// Update registers and reset the register file sources. Echo the update
// values to the execution unit arguments. And handle exceptions and
// special instructions like RTI.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg [2:0] last_zero1, last_zero2;

task tWriteback;
integer n8;
integer n13;
begin
	//if (reb[head0].state==EMPTY || reb[head0].state==RETIRED || reb[head0].state==EXECUTED)// && ((head0 + 2'd1) & 3'd7) != tail)
	head0 <= next_head0;
	head1 <= 3'd7;
//	head1 <= next_head1;
  if (commit0_wr) begin
  	$display("Writeback[%d]: %d", head0, $time);
  	$display("  Src:%d Tgt: %d val=%h", commit0_src,commit0_tgt, commit0_bus);
		tArgUpdate(commit0_src,commit0_bus);//,reb[commit0_src].cares);
	end
//  if (commit1_wr)
//		tArgUpdate(commit1_src,commit1_bus);//,reb[commit1_src].cares);
  if (commit0_wr) begin
    $display("  regfile[%d] <= %h", reb[commit0_src].dec.Rt, commit0_bus);
    // Globally enable interrupts after first update of stack pointer.
    if (reb[commit0_src].dec.Rt==6'd45) begin
    	sp <= commit0_bus;	// debug
      gie <= TRUE;
    end
  end
  if (reb[head0].executed && reb[head0].v) begin
		if (reb[head0].cio[0])
			preg[reb[head0].cioreg] <= reb[head0].res_t2;
		/*
		if (|reb[head0].cause) begin
			wcause <= reb[head0].cause;
			tProcessException();
		end
		else
		*/
		begin
			if (reb[head0].dec.sei)
				pmStack[3:1] <= reb[head0].ia[0][2:0]|reb[head0].ir[24:22];
			else if (reb[head0].dec.rti)
				tProcessRti();
	    else if (reb[head0].dec.csr)
	    	tProcessCsr();
			else if (reb[head0].dec.rex)
				tProcessRex();
			// Register file update
			/*
		  if (reb[head0].dec.rfwr) begin
		  	if (reb[head0].dec.Rtvec) begin
		  		if (reb[head0].mask_bit)
		  			vregfile[reb[head0].dec.Rt][reb[head0].step] <= reb[head0].res;
		  		else if (reb[head0].zbit)
		  			vregfile[reb[head0].dec.Rt][reb[head0].step] <= 64'd0;
		  	end
		  end
		  */
		end	// wcause
	    //regfile[reb[head0].dec.Rt] <= reb[head0].res[$bits(Value)-1:0];
	  tFreeRebs();
  end
  tRetirePrefixes();
  
	last_zero1 <= head0;
	last_zero2 <= last_zero1;
//	if (reb[last_zero1] != 'd0 && last_zero1 != head0 && !reb[last_zero1].out && last_zero1 != 3'd7 && head0!=3'd7)
//		$stop;
  for (n13 = 0; n13 < REB_ENTRIES; n13 = n13 + 1) begin
	  case({reb[n13].fetched,reb[n13].decompressed,reb[n13].decoded,reb[n13].rfetched,reb[n13].executed})
	  5'b00000,
	  5'b10000,
	  5'b01000,
	  5'b00100,
	  5'b00010,
	  5'b00001:	;
	  default:
			$stop;
		endcase
	end
	
end
endtask


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Writeback Helpers
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Freeup the REB slots
task tFreeRebs;
begin
	reb[head0] <= 'd0;
	reb[head0].out <= reb[head0].out;	// keep this signal
	/*
	if (commit_cnt==2'd2) begin
		reb[commit1_src].v <= 1'b0;
		reb[commit1_src].fetched <= 1'b0;
		reb[commit1_src].decompressed <= 1'b0;
		reb[commit1_src].decoded <= 1'b0;
		reb[commit1_src].out <= 1'b0;
		reb[commit1_src].executed <= 1'b0;
//		reb[commit1_src] <= 'd0;
	end
	*/
	retired_count <= retired_count + commit_cnt;
end
endtask

// Retire prefixes once the instruction is retired.
task tRetirePrefixes;
integer n8;
integer n11;
begin
	for (n11 = 0; n11 < REB_ENTRIES; n11 = n11 + 1) begin
		if (reb[n11].executed) begin
			for (n8 = 0; n8 < REB_ENTRIES; n8 = n8 + 1) begin
				if (reb[n8].dec.isExi && sns[n8]==sns[n11]-1)
					reb[n8] <= 'd0;
				if (sns[n8]==sns[n11]-2 && reb[n8].ir.any.opcode==EXIM)
					reb[n8] <= 'd0;
			end
		end
	end
	/*
	if (commit_cnt==2'd2) begin
		for (n8 = 0; n8 < REB_ENTRIES; n8 = n8 + 1) begin
			if (reb[n8].dec.isExi && sns[n8]==sns[commit1_src]-1)
				reb[n8] <= 'd0;
			if (sns[n8]==sns[commit1_src]-2 && reb[n8].ir.any.opcode==EXIM)
				reb[n8] <= 'd0;
		end
	end
	*/
end
endtask

task tProcessException;
begin
	if ((reb[head0].cause & 8'hff)==FLT_CPF)
		clr_ipage_fault <= 1'b1;
	if ((reb[head0].cause & 8'hff)==FLT_TLBMISS)
		clr_itlbmiss <= 1'b1;
	if (reb[head0].cause[15]) begin
		// IRQ level remains the same unless external IRQ present
		pmStack <= {pmStack[55:0],2'b11,2'b00,reb[head0].cause[10:8],1'b0};
		sp_sel <= 3'd4;
	end
	else begin
		pmStack <= {pmStack[55:0],2'b11,2'b00,pmStack[3:1],1'b0};
		sp_sel <= 3'd3;
	end
	plStack <= {plStack[55:0],8'hFF};
	cause[2'd3] <= reb[head0].cause & 16'h80FF;
	badaddr[2'd3] <= reb[head0].badAddr;
	eip_regfile[reb[head0].istk_depth] <= reb[head0].ip;
	eip_src[reb[head0].istk_depth] <= 6'd31;
	ip.micro_ip <= 8'h00;
	ip.offs <= tvec[3'd3] + {omode,6'h00};
	tNullReb(head0);
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tProcessRti;
begin
	if (|istk_depth) begin
		pmStack <= {8'hCE,pmStack[63:8]};
		plStack <= {8'hFF,plStack[63:8]};
		ip.offs <= reb[head0].ca.offs;	// 8-1
		ip.micro_ip <= reb[head0].ca.micro_ip;
		istk_depth <= istk_depth - 2'd1;
		case(pmStack[15:14])
		2'd0:	sp_sel <= 3'd0;
		2'd1:	sp_sel <= 3'd1;
		2'd2:	sp_sel <= 3'd2;
		2'd3:	sp_sel <= 3'd3;
		endcase
		tNullReb(head0);
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tProcessCsr;
begin
  case(reb[head0].ir.csr.op)
  3'd1:   tWriteCSR(reb[head0].ia[0],reb[head0].ir.csr.regno);
  3'd2:   tSetbitCSR(reb[head0].ia[0],reb[head0].ir.csr.regno);
  3'd3:   tClrbitCSR(reb[head0].ia[0],reb[head0].ir.csr.regno);
  default:	;
  endcase
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tProcessRex;
begin
	// Exception if trying to switch to higher mode
	if (omode <= reb[head0].ir[10:9]) begin
		pmStack <= {pmStack[55:0],2'b11,2'b00,pmStack[3:1],1'b0};
		plStack <= {plStack[55:0],8'hFF};
		cause[2'd3] <= FLT_PRIV;
		eip_regfile[reb[head0].dec.Ct] <= reb[head0].ip;
		ip.offs <= tvec[3'd3] + {omode,6'h00};
		sp_sel <= 3'd3;
		tNullReb(head0);
	end
	else begin
		if (status[3][reb[head0].ir[10:9]]) begin
			pmStack[7:6] <= reb[head0].ir[10:9];	// omode
			plStack <= {plStack[55:0],8'hFF};
			cause[reb[head0].ir[10:9]] <= cause[2'd3];
			badaddr[reb[head0].ir[10:9]] <= badaddr[2'd3];
			ip.offs <= tvec[reb[head0].ir[10:9]] + {omode,6'h00};
			tNullReb(head0);
			// Don't allow stack redirection for interrupt processing.
			if (sp_sel != 3'd4)
				case(reb[head0].ir[10:9])
				2'd0:	sp_sel <= 3'd0;
				2'd1:	sp_sel <= 3'd1;
				2'd2:	sp_sel <= 3'd2;
				2'd3:	sp_sel <= 3'd3;
				endcase
		end
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Trailer Stage
//
// Used for instruction synchronization.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tSyncTrailer;
begin
	if (advance_t) begin
		tSync <= wd.sync & wval;
		uSync <= tSync;
		vSync <= uSync;
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// This task is a debugging aid. It ensures that the about to be retired
// instruction at least has all arguments valid.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tArgCheck;
integer n;
begin
	if (!fnArgsValid(oldest) && reb[oldest].rfetched) begin
		$display("Arg missing");
		$stop;
//		stalled <= 1'b1;
	end
end
endtask


// Stall fix

task tStalled;
begin
	if (stalled1) begin
		stalled <= 1'b0;
		stalled1 <= 1'b0;
		if (!reb[oldest].iav) begin
			begin
				reb[oldest].ia <= rfoa;
				reb[oldest].iav <= 1'b1;
			end
		end
		if (!reb[oldest].ibv) begin
			begin
				reb[oldest].ib <= rfob;
				reb[oldest].ibv <= 1'b1;
			end
		end
		if (!reb[oldest].icv) begin
			begin
				reb[oldest].ic <= rfoc;
				reb[oldest].icv <= 1'b1;
			end
		end
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Reset the register file source. Done on a flow control change. Most of
// the logic is above.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tResetRegfileSrc;
integer n;
begin
	for (n = 0; n < REB_ENTRIES; n = n + 1) begin
  	if (|reb_latestID2[n])
  		eip_src[reb[n].dec.Ct] <= n;
  end
  for (n = 0; n < 16; n = n + 1) begin
  	if (~livetarget2[n])
  		eip_src[n] <= 6'd31;
  end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Null out the instructions following one that caused a control flow
// change. It should really only be necessary to clear a valid bit, but
// clearing the whole entry is safer and less confusing during debug.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tNullReb;
input SSrcId kk;
integer n9;
begin
	for (n9 = 0; n9 < REB_ENTRIES; n9 = n9 + 1) begin
		if (sns[n9] > sns[kk]) begin
			reb[n9] <= 'd0;
			reb[n9].out <= reb[n9].out;
//			sns[n9] <= REB_ENTRIES;
		end
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Common task for flow control changing operations. Sets the branch miss
// address appropriately.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tBranch;
input [3:0] yy;	// Debugging: who's the caller?
begin
  if (reb[exec].dec.Rc == 'd0) begin
  	branchmiss_adr.offs <= reb[exec].dec.jmptgt;
 		branchmiss_adr.micro_ip <= 'd0;
  	reb[exec].jmptgt.offs <= reb[exec].dec.jmptgt;
		xx <= 4'd6;
  end
  else if (reb[exec].dec.Rc == 6'd31) begin
  	branchmiss_adr.offs <= reb[exec].ip.offs + reb[exec].dec.jmptgt;
 		branchmiss_adr.micro_ip <= 'd0;
  	reb[exec].jmptgt.offs <= reb[exec].ip.offs + reb[exec].dec.jmptgt;
		xx <= 4'd7;
  end
  else begin
		branchmiss_adr.offs <= reb[exec].ic[0] + reb[exec].dec.jmptgt;
 		branchmiss_adr.micro_ip <= 'd0;
  	reb[exec].jmptgt.offs <= reb[exec].ic[0] + reb[exec].dec.jmptgt;
		xx <= 4'd8;
  end
  tNullReb(exec);
  tStackRetadr(exec);
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Kludgey logic to perform a wait operation. ToDo: improve this.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

integer n10;
task tWait;
begin
	if (first_flag || !done_flag) begin
		first_flag <= 1'b0;
		tNullReb(exec);
  	ip.offs <= reb[exec].ip.offs;
  	reb[exec].jmptgt.offs <= reb[exec].ip.offs;
	end
	else
		first_flag <= 1'b1;
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task ex_fault;
input SrcId ndx;
input [7:0] c;
begin
	if (reb[ndx].cause==16'h0)
		reb[ndx].cause <= {8'h00,c};
	mc_busy <= FALSE;
	goto (RUN);
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// CSR Read / Update tasks
//
// Important to use the correct assignment type for the following, otherwise
// The read won't happen until the clock cycle.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tReadCSR;
output Value res;
input [15:0] regno;
begin
	if (regno[13:12] <= omode) begin
		casez(regno[15:0])
		CSR_SCRATCH:	res = scratch[regno[13:12]];
		CSR_MHARTID: res = hartid_i;
		CSR_MCR0:	res = cr0|(dce << 5'd30);
		CSR_PTBR:	res = ptbr;
		CSR_KEYS:	res = keys2[regno[0]];
		CSR_SEMA: res = sema;
//		CSR_FSTAT:	res = fpscr;
		CSR_ASID:	res = asid;
		CSR_MBADADDR:	res = badaddr[regno[13:12]];
		CSR_TICK:	res = tick;
		CSR_CAUSE:	res = cause[regno[13:12]];
		CSR_MTVEC:	res = tvec[regno[1:0]];
		CSR_UCA:
			if (regno[3:0]==4'd7)
				res = xip.offs;
			else if (regno[3:0] < 4'd8)
				res = xca.offs;
			else
				res = 64'd0;
		CSR_MCA,CSR_HCA,CSR_SCA:
			if (regno[3:0]==4'd7)
				res = xip.offs;
			else
				res = xca.offs;
		CSR_MPLSTACK:	res = plStack;
		CSR_MPMSTACK:	res = pmStack;
		CSR_MVSTEP:	res = estep;
		CSR_MVTMP:	res = vtmp;
		CSR_TIME:	res = wc_time;
		CSR_MSTATUS:	res = status[3];
		CSR_MTCB:	res = tcbptr;
//		CSR_DSTUFF0:	res = stuff0;
//		CSR_DSTUFF1:	res = stuff1;
		default:	res = 64'd0;
		endcase
	end
	else
		res = 64'd0;
end
endtask

task tWriteCSR;
input Value val;
input [15:0] regno;
begin
	if (regno[13:12] <= omode) begin
		casez(regno[15:0])
		CSR_SCRATCH:	scratch[regno[13:12]] <= val;
		CSR_MCR0:		cr0 <= val;
		CSR_PTBR:		ptbr <= val;
		CSR_SEMA:		sema <= val;
		CSR_KEYS:		keys2[regno[0]] <= val;
//		CSR_FSTAT:	fpscr <= val;
		CSR_ASID: 	asid <= val;
		CSR_MBADADDR:	badaddr[regno[13:12]] <= val;
		CSR_CAUSE:	cause[regno[13:12]] <= val;
		CSR_MTVEC:	tvec[regno[1:0]] <= val;
		CSR_UCA:
			if (regno[3:0] < 4'd8)
				eip_regfile[wd.Ct].offs <= val;
		CSR_MCA,CSR_SCA,CSR_HCA:
			eip_regfile[wd.Ct].offs <= val;
		CSR_MPLSTACK:	plStack <= val;
		CSR_MPMSTACK:	pmStack <= val;
		CSR_MVSTEP:	estep <= val;
		CSR_MVTMP:	begin new_vtmp <= val; ld_vtmp <= TRUE; end
//		CSR_DSP:	dsp <= val;
		CSR_MTIME:	begin wc_time_dat <= val; ld_time <= TRUE; end
		CSR_MTIMECMP:	begin clr_wc_time_irq <= TRUE; mtimecmp <= val; end
		CSR_MSTATUS:	status[3] <= val;
		CSR_MTCB:	tcbptr <= val;
//		CSR_DSTUFF0:	stuff0 <= val;
//		CSR_DSTUFF1:	stuff1 <= val;
		default:	;
		endcase
	end
end
endtask

task tSetbitCSR;
input Value val;
input [15:0] regno;
begin
	if (regno[13:12] <= omode) begin
		casez(regno[15:0])
		CSR_MCR0:			cr0[val[5:0]] <= 1'b1;
		CSR_SEMA:			sema[val[5:0]] <= 1'b1;
		CSR_MPMSTACK:	pmStack <= pmStack | val;
		CSR_MSTATUS:	status[3] <= status[3] | val;
		default:	;
		endcase
	end
end
endtask

task tClrbitCSR;
input Value val;
input [15:0] regno;
begin
	if (regno[13:12] <= omode) begin
		casez(regno[15:0])
		CSR_MCR0:			cr0[val[5:0]] <= 1'b0;
		CSR_SEMA:			sema[val[5:0]] <= 1'b0;
		CSR_MPMSTACK:	pmStack <= pmStack & ~val;
		CSR_MSTATUS:	status[3] <= status[3] & ~val;
		default:	;
		endcase
	end
end
endtask


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// State machine.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task goto;
input [5:0] st;
begin
	state <= st;
end
endtask

task call;
input [5:0] st;
input [5:0] rst;
begin
	state2 <= state1;
	state1 <= rst;
	state <= st;
end
endtask

task sreturn;
begin
	state <= state1;
	state1 <= state2;
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Disassembler for debugging. It helps to have some output to allow 
// visual tracking in the simulation run.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function [31:0] fnRegName;
input [5:0] Rn;
begin
	case(Rn)
	6'd0:	fnRegName = "zero";
	6'd1:	fnRegName = "lr";
	6'd2:	fnRegName = "lr2";
	6'd3:	fnRegName = "a0";
	6'd4:	fnRegName = "a1";
	6'd5:	fnRegName = "t0";
	6'd6:	fnRegName = "t1";
	6'd7:	fnRegName = "t2";
	6'd8:	fnRegName = "t3";
	6'd9:	fnRegName = "t4";
	6'd10:	fnRegName = "t5";
	6'd11:	fnRegName = "t6";
	6'd12:	fnRegName = "s0";
	6'd13:	fnRegName = "s1";
	6'd14:	fnRegName = "s2";
	6'd15:	fnRegName = "s3";
	6'd16:	fnRegName = "s4";
	6'd17:	fnRegName = "s5";
	6'd18:	fnRegName = "s6";
	6'd19:	fnRegName = "s7";
	6'd20:	fnRegName = "a2";
	6'd21:	fnRegName = "a3";
	6'd22:	fnRegName = "a4";
	6'd23:	fnRegName = "a5";
	6'd24:	fnRegName = "a6";
	6'd25:	fnRegName = "a7";
	6'd26:	fnRegName = "lc";
	6'd27:	fnRegName = "r27";
	6'd28:	fnRegName = "r28";
	6'd29:	fnRegName = "gp";
	6'd30:	fnRegName = "fp";
	6'd31:	fnRegName = "sp";
	6'd32:	fnRegName = "vm0";
	6'd33:	fnRegName = "vm1";
	6'd34:	fnRegName = "vm2";
	6'd35:	fnRegName = "vm3";
	6'd36:	fnRegName = "vm4";
	6'd37:	fnRegName = "vm5";
	6'd38:	fnRegName = "vm6";
	6'd39:	fnRegName = "vm7";
	6'd40:	fnRegName = "lk1";
	6'd41:	fnRegName = "lk2";
	6'd42:	fnRegName = "lc";
	6'd43:	fnRegName = "ssp";
	6'd44:	fnRegName = "hsp";
	6'd45:	fnRegName = "msp";
	6'd46:	fnRegName = "isp";
	endcase
end
endfunction

task disassem;
input Instruction ir;
input CodeAddress ip;
begin
  case(ir.any.opcode)
  R2,R3:
  	case(ir.r3.func)
  	ADD:	$display("ADD %s,%s,%s", fnRegName(ir.r3.Rt), fnRegName(ir.r3.Ra), fnRegName(ir.r3.Rb));
  	AND:	$display("AND %s,%s,%s", fnRegName(ir.r3.Rt), fnRegName(ir.r3.Ra), fnRegName(ir.r3.Rb));
  	OR:		$display("OR %s,%s,%s", fnRegName(ir.r3.Rt), fnRegName(ir.r3.Ra), fnRegName(ir.r3.Rb));
  	default:	$display("????");
  	endcase
	ADD2R:	$display("ADD %s,%s,%s", fnRegName(ir.r3.Rt), fnRegName(ir.r3.Ra), fnRegName(ir.r3.Rb));
	AND2R:	$display("AND %s,%s,%s", fnRegName(ir.r3.Rt), fnRegName(ir.r3.Ra), fnRegName(ir.r3.Rb));
	OR2R:		$display("OR %s,%s,%s", fnRegName(ir.r3.Rt), fnRegName(ir.r3.Ra), fnRegName(ir.r3.Rb));
  ADDI:   
  	if (ir.ri.Ra=='d0)
      $display("LDI %s,%h", fnRegName(ir.ri.Rt), ir.ri.imm);
  	else
  		$display("ADD %s,%s,%h", fnRegName(ir.ri.Rt), fnRegName(ir.ri.Ra), ir.ri.imm);
  ADDIL:   
  	if (ir.ri.Ra=='d0)
      $display("LDI %s,%h", fnRegName(ir.ril.Rt), ir.ril.imm);
  	else
  		$display("ADD %s,%s,%h", fnRegName(ir.ril.Rt), fnRegName(ir.ril.Ra), ir.ril.imm);
  ANDI:		$display("AND %s,%s,%h", fnRegName(ir.ri.Rt), fnRegName(ir.ri.Ra), ir.ri.imm);
  ANDIL:	$display("AND %s,%s,%h", fnRegName(ir.ril.Rt), fnRegName(ir.ril.Ra), ir.ril.imm);
  ORI:		$display("OR %s,%s,%h", fnRegName(ir.ri.Rt), fnRegName(ir.ri.Ra), ir.ri.imm);
  ORIL:		$display("OR %s,%s,%h", fnRegName(ir.ril.Rt), fnRegName(ir.ril.Ra), ir.ril.imm);
  SLLI:		$display("SLL %s,%s,%d", fnRegName(ir.r2.Rt), fnRegName(ir.r2.Ra), ir[24:19]);
  LDT:		$display("LDT r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.ld.Ra);
  LDTU:		$display("LDTU r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.ld.Ra);
  LDO:		$display("LDO r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.ld.Ra);
  LDOS:		$display("LDO r%d,%d[r%d]", ir.ld.Rt, ir.lds.disp, ir.ld.Ra);
  LDV:		$display("LDV r%d,%d[r%d] : %h", ir.ld.Rt, ir.ld.disp, ir.ld.Ra, reb[exec].ia[0] + ir.ld.disp);
  LDHS:		$display("LDH r%d,%d[r%d] : %h", ir.ld.Rt, ir.lds.disp, ir.ld.Ra, reb[exec].ia[0] + ir.lds.disp);
  STT:		$display("STT r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.st.Ra);
  STO:		$display("STO r%d,%d[r%d]", ir.st.Rs, ir.st.disp, ir.st.Ra);
  STOS:		$display("STO r%d,%d[r%d] : %h", ir.st.Rs, ir.sts.disp, ir.st.Ra, reb[exec].ia[0] + ir.sts.disp);
  STV:		$display("STV r%d,%d[r%d] : %h", ir.st.Rs, ir.st.disp, ir.st.Ra, reb[exec].ia[0] + ir.st.disp);
  STHS:		$display("STH r%d,%d[r%d] : %h", ir.st.Rs, ir.sts.disp, ir.st.Ra, reb[exec].ia[0] + ir.sts.disp);
  RTS:   	$display("RTS #%d", ir.rts.cnst);
  ENTER:	$display("ENTER");
  LEAVE:	$display("LEAVE");
  BEQZ:		$display("BEQZ %h", {{64{ir[31]}},ir[31:19],ir[13:9]}+ip.offs);
  MTLK:		$display("MTLK r%d", ir.r1.Rt);
  default:	$display("<op>");
  endcase
end
endtask


endmodule
