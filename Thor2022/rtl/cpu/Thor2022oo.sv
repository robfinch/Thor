// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022io.sv
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

module Thor2022oo(hartid_i, rst_i, clk_i, clk2x_i, clk2d_i, wc_clk_i, clock,
		nmi_i, irq_i, icause_i,
		vpa_o, vda_o, bte_o, cti_o, bok_i, cyc_o, stb_o, lock_o, ack_i,
    err_i, we_o, sel_o, adr_o, dat_i, dat_o, cr_o, sr_o, rb_i, state_o, trigger_o);
input [63:0] hartid_i;
input rst_i;
input clk_i;
input clk2x_i;
input clk2d_i;
input wc_clk_i;
input clock;					// MMU clock algorithm
input nmi_i;
input [2:0] irq_i;
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

reg [5:0] rst_cnt;
reg [4:0] dicnt;
wire di = |dicnt;
wire [1:0] omode;
wire [1:0] memmode;
wire UserMode, SupervisorMode, HypervisorMode, MachineMode;
wire MUserMode;
reg gie;
reg [511:0] regfile [0:31];
SrcId [31:0] regfile_src;
Value r58;
reg [127:0] preg [0:7];
reg [15:0] cio;
reg [7:0] delay_cnt;
Value sp, t0;
Address caregfile [0:15];
SrcId [15:0] ca_src;
(* ram_style="block" *)
Value vregfile [0:31][0:63];
reg [63:0] vm_regfile [0:7];
wire ipage_fault;
reg clr_ipage_fault = 1'b0;
wire itlbmiss;
reg clr_itlbmiss = 1'b0;
reg wackr;
reg [31:0] livetarget;
reg [15:0] livetarget2;
reg [31:0] reb_cumulative [0:7];
reg [15:0] reb_cumulative2 [0:7];
reg [31:0] reb_livetarget [0:7];
reg [15:0] reb_livetarget2 [0:7];
reg [31:0] reb_latestID [0:7];
reg [15:0] reb_latestID2 [0:7];
reg [31:0] reb_livetarget [0:7];
reg [15:0] reb_livetarget2 [0:7];
reg [31:0] reb_out [0:7];
reg [15:0] reb_out2 [0:7];

integer n1;
initial begin
	for (n1 = 0; n1 < 32; n1 = n1 + 1) begin
		regfile[n1] <= 'd0;
		preg[n1 % 8] <= 'd0;
		caregfile[n1 % 16].offs <= 'd0;
	end
end

reg advance_w;
Value vroa, vrob, vroc;
Value wres2;
wire wrvrf;
reg first_flag, done_flag;

sReorderEntry [7:0] reb;
reg [2:0] head;
reg [2:0] exec;
reg [2:0] dec;
reg [2:0] tail;
reg [47:0] sn;

// Instruction fetch stage vars
reg ival;
reg [15:0] icause;
Instruction insn;
Instruction micro_ir,micro_ir1;
reg advance_i;
CodeAddress ip;
reg [6:0] micro_ip;
wire ipredict_taken;
wire ihit;
wire [pL1ICacheLineSize-1:0] ic_line;
wire [3:0] ilen;
wire btb_hit;
CodeAddress btb_tgt;
CodeAddress next_ip;
wire run;
reg [2:0] pfx_cnt;		// prefix counter
reg [7:0] istep;


// Decode stage vars
reg dval;
reg [15:0] dcause;
Instruction ir;
CodeAddress dip;
reg [2:0] cioreg;
reg dpfx;
reg advance_d;
reg [3:0] dlen;
DecodeOut deco, xd, md, wd;
reg dpredict_taken;
reg [4:0] Ra;
reg [4:0] Rb;
reg [4:0] Rc;
reg [4:0] Rc1;
reg [4:0] Rt;
reg [1:0] Tb;
reg [1:0] Tc;
reg [2:0] Rvm;
reg [3:0] Ca;
reg [3:0] Ct;
reg Rz;
always_comb Ra = deco.Ra;
always_comb Rb = deco.Rb;
always_comb Rc = deco.Rc;
always_comb Rt = deco.Rt;
always_comb Rvm = deco.Rvm;
always_comb Rz = deco.Rz;
always_comb Tb = deco.Tb;
always_comb Tc = deco.Tc;
always_comb Ca = deco.Ca;
always_comb Ct = deco.Ct;
reg [3:0] distk_depth;
reg [7:0] dstep;
reg zbit;

wire dAddi = deco.addi;
wire dld = deco.ld;
wire dst = deco.st;
Value rfoa, rfob, rfoc0, rfoc1, rfoc2, rfoc3, rfop;
reg rfoa_v, rfob_v, rfoc0_v, rfoc1_v, rfoc2_v, rfoc3_v;

Address rfoca;
reg [63:0] mask;
reg [7:0] wstep;

vreg_blkmem uvr1 (
  .clka(clk_g),    // input wire clka
  .ena(advance_w),      // input wire ena
  .wea(wrvrf),      // input wire [0 : 0] wea
  .addra({wd.Rt,wstep}),  // input wire [11 : 0] addra
  .dina(wres2),    // input wire [63 : 0] dina
  .douta(),  // output wire [63 : 0] douta
  .clkb(~clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .web(1'b0),      // input wire [0 : 0] web
  .addrb({Ra,dstep}),  // input wire [11 : 0] addrb
  .dinb(64'd0),    // input wire [63 : 0] dinb
  .doutb(vroa)  // output wire [63 : 0] doutb
);
vreg_blkmem uvr2 (
  .clka(clk_g),    // input wire clka
  .ena(advance_w),      // input wire ena
  .wea(wrvrf),      // input wire [0 : 0] wea
  .addra({wd.Rt,wstep}),  // input wire [11 : 0] addra
  .dina(wres2),    // input wire [63 : 0] dina
  .douta(),  // output wire [63 : 0] douta
  .clkb(~clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .web(1'b0),      // input wire [0 : 0] web
  .addrb({Rb,dstep}),  // input wire [11 : 0] addrb
  .dinb(64'd0),    // input wire [63 : 0] dinb
  .doutb(vrob)  // output wire [63 : 0] doutb
);
vreg_blkmem uvr3 (
  .clka(clk_g),    // input wire clka
  .ena(advance_w),      // input wire ena
  .wea(wrvrf),      // input wire [0 : 0] wea
  .addra({wd.Rt,wstep}),  // input wire [11 : 0] addra
  .dina(wres2),    // input wire [63 : 0] dina
  .douta(),  // output wire [63 : 0] douta
  .clkb(~clk_g),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .web(1'b0),      // input wire [0 : 0] web
  .addrb({Rc,dstep}),  // input wire [11 : 0] addrb
  .dinb(64'd0),    // input wire [63 : 0] dinb
  .doutb(vroc)  // output wire [63 : 0] doutb
);

// Execute stage vars
reg xval;
reg [15:0] xcause;
Address xbadAddr;
Instruction xir;
CodeAddress xip;
reg [3:0] xlen;
reg advance_x;
reg [4:0] tRt;
reg [2:0] xistk_depth;
reg [2:0] xcioreg;
reg [1:0] xcio;
Value xa;
Value xb;
Value xc0;
Value xc1;
Value xc2;
Value xc3;
Value pn;
Value imm;
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
MemoryResponse memresp;
reg memresp_fifo_rd;
wire memresp_fifo_empty;
wire memresp_fifo_v;
reg [7:0] tid;
reg [128:0] res,res2;
Value crypto_res, carry_res;
CodeAddress cares;
reg ld_vtmp;
reg [7:0] xstep;
reg [2:0] xrm,xdfrm;

// Memory
reg mval;
Instruction mir;
CodeAddress mip;
reg advance_m;
reg [15:0] mcause;
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
Value mres, mcarry_res;
reg [511:0] mres512;
reg [7:0] mstep;
reg mzbit;
reg mmaskbit;
CodeAddress mJmptgt;
reg mtakb;
reg mExBranch;

// Writeback stage vars
reg wval;
Instruction wir;
CodeAddress wip;
reg [15:0] wcause;
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
Value wres, wcarry_res;
reg [511:0] wres512;
reg wzbit;
reg wmaskbit;
Address wJmptgt;
reg wtakb;
reg wExBranch;

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
Selector dbad [0:3];
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
Selector ldt;
Selector keytbl;
Selector tcbptr;
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

assign omode = pmStack[2:1];
assign MachineMode = omode==2'b11;
assign HypervisorMode = omode==2'b10;
assign SupervisorMode = omode==2'b01;
assign UserMode = omode==2'b00;
assign memmode = mprv ? pmStack[6:5] : omode;
wire MMachineMode = memmode==2'b11;
assign MUserMode = memmode==2'b00;

Value bf_out;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Decode stage combinational logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Instruction dxir, dmir;
reg dxval, dmval;
integer k2;
always_comb
begin
	dxir = NOP;
	dmir = NOP;
	dxval = FALSE;
	dmval = FALSE;
	for (k2 = 0; k2 < 8; k2 = k2 + 1) begin
		if (reb[k2].sn == reb[dec].sn - 1) begin
			dxir = reb[k2].ir;
			dxval = reb[k2].v;
		end
		if (reb[k2].sn == reb[dec].sn - 2) begin
			dmir = reb[k2].ir;
			dmval = reb[k2].v;
		end
	end
end

Thor2022_decoder udec (
	.ir(reb[dec].ir),
	.xir(dxir),
	.xval(dxval),
	.mir(dmir),
	.mval(dmval),
	.deco(deco),
	.distk_depth(distk_depth),
	.rm(rm),
	.dfrm(dfrm)
);

always_comb
if (deco.Ra=='d0)
	rfoa = 'd0;
else if (reb[head].dec.Rt==deco.Ra && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr)
	rfoa = reb[head].res;
else
	rfoa = regfile[deco.Ra[4:2]] >> {deco.Ra[1:0],7'b0};

always_comb
if (deco.Rb=='d0)
	rfob = 'd0;
else if (reb[head].dec.Rt==deco.Rb && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr)
	rfob = reb[head].res;
else
	rfob = regfile[deco.Rb[4:2]] >> {deco.Rb[1:0],7'b0};

always_comb
if (deco.Rc=='d0)
	rfoc0 = 'd0;
else if (reb[head].dec.Rt==deco.Rc && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr)
	rfoc0 = reb[head].res;
else
	rfoc0 = regfile[deco.Rc[4:2]] >> {deco.Rc[1:0],7'b0};

always_comb
if (reb[head].dec.Rt=={deco.Rc[4:2],2'b01} && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr)
	rfoc1 = reb[head].res;
else
	rfoc1 = regfile[deco.Rc[4:2]] >> {2'b01,7'b0};

always_comb
if (reb[head].dec.Rt=={deco.Rc[4:2],2'b10} && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr)
	rfoc2 = reb[head].res;
else
	rfoc2 = regfile[deco.Rc[4:2]] >> {2'b10,7'b0};

always_comb
if (reb[head].dec.Rt=={deco.Rc[4:2],2'b11} && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr)
	rfoc3 = reb[head].res;
else
	rfoc3 = regfile[deco.Rc[4:2]] >> {2'b11,7'b0};

always_comb
	if (cioreg==3'd0 || ~cio[1])
		rfop = 'd0;
	else if (reb[head].v && reb[head].cioreg==cioreg && reb[head].state==3'd4 && reb[head].cio[0])
		rfop = reb[head].carry_res;
	else
		rfop = preg[cioreg];

always_comb
	if (deco.Ca == reb[head].dec.Ct && reb[head].state==3'd4 && reb[head].dec.carfwr && reb[head].v)
		rfoca = reb[head].cares;
	else
		rfoca = caregfile[deco.Ca];

always_comb
	rfoa_v = (reb[head].dec.Rt==deco.Ra && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr) || regfile_src[deco.Ra]==5'd31 || Source1Valid(reb[dec].ir);
always_comb
	rfob_v = (reb[head].dec.Rt==deco.Rb && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr) || regfile_src[deco.Rb]==5'd31 || Source2Valid(reb[dec].ir);
always_comb
	rfoc0_v = (reb[head].dec.Rt==deco.Rc && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr) || regfile_src[deco.Rc]==5'd31 || Source3Valid(reb[dec].ir);
always_comb
	rfoc1_v = (reb[head].dec.Rt=={deco.Rc[4:2],2'b01} && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr) || regfile_src[{deco.Rc[4:2],2'b01}]==5'd31 || Source3Valid(reb[dec].ir);
always_comb
	rfoc2_v = (reb[head].dec.Rt=={deco.Rc[4:2],2'b10} && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr) || regfile_src[{deco.Rc[4:2],2'b10}]==5'd31 || Source3Valid(reb[dec].ir);
always_comb
	rfoc3_v = (reb[head].dec.Rt=={deco.Rc[4:2],2'b11} && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr) || regfile_src[{deco.Rc[4:2],2'b11}]==5'd31 || Source3Valid(reb[dec].ir);
	
always_comb
	mask = vm_regfile[deco.Rvm];

always_comb
	zbit = deco.Rz;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Branch miss logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

integer n,j,k;
reg [2:0] missid;
reg [7:0] stomp;
always_comb
	missid = exec;

wire branchmiss = 
	((reb[missid].dec.jxx|reb[missid].dec.jxz|reb[missid].dec.mjnez) & takb) | //reb[exec].dec.jmp | reb[exec].dec.bra |
		(reb[missid].dec.rts & reb[missid].dec.Ca != 2'b00);

always @*
begin
	for (n = 0; n < 8; n = n + 1)
		stomp[n] = 1'b0;
	if (branchmiss) begin
		for (n = 0; n < 8; n = n + 1) begin
			if (reb[n].sn > reb[missid].sn)
				stomp[n] = 1'b1;
		end
	end
end

always @*
	for (n = 0; n < 8; n = n + 1)
		reb_livetarget[n] = {32{reb[n].v}} & {32{~stomp[n]}} & reb_out[n];
always @*
	for (n = 0; n < 8; n = n + 1)
		reb_livetarget2[n] = {16{reb[n].v}} & {16{~stomp[n]}} & reb_out2[n];
always @*
for (j = 1; j < 32; j = j + 1) begin
	livetarget[j] = 1'b0;
	for (n = 0; n < 8; n = n + 1)
		livetarget[j] = livetarget[j] | reb_livetarget[n][j];
end
always @*
for (j = 1; j < 16; j = j + 1) begin
	livetarget2[j] = 1'b0;
	for (n = 0; n < 8; n = n + 1)
		livetarget2[j] = livetarget2[j] | reb_livetarget2[n][j];
end

always @*
	for (n = 0; n < 8; n = n + 1) begin
		reb_cumulative[n] = 1'b0;
		for (j = n; j < n + 8; j = j + 1) begin
			if (missid==(j % 8))
				for (k = n; k <= j; k = k + 1)
					reb_cumulative[n] = reb_cumulative[n] | reb_livetarget[k % 8];
		end
	end
always @*
	for (n = 0; n < 8; n = n + 1) begin
		reb_cumulative2[n] = 1'b0;
		for (j = n; j < n + 8; j = j + 1) begin
			if (missid==(j % 8))
				for (k = n; k <= j; k = k + 1)
					reb_cumulative2[n] = reb_cumulative2[n] | reb_livetarget2[k % 8];
		end
	end

always @*
	for (n = 0; n < 8; n = n + 1)
    reb_latestID[n] = (missid == n || ((reb_livetarget[n] & reb_cumulative[(n+1)%8]) == {32{1'b0}}))
				    ? reb_livetarget[n]
				    : {32{1'b0}};
always @*
	for (n = 0; n < 8; n = n + 1)
    reb_latestID2[n] = (missid == n || ((reb_livetarget2[n] & reb_cumulative2[(n+1)%8]) == {16{1'b0}}))
				    ? reb_livetarget2[n]
				    : {16{1'b0}};

always @*
for (n = 0; n < 8; n = n + 1)
	reb_out[n] <= 32'h1 << reb[n].dec.Rt;
always @*
for (n = 0; n < 8; n = n + 1)
	reb_out2[n] <= 16'h1 << reb[n].dec.Ct;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute stage combinational logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire [2:0] pte_en;
wire pte_found;
reg [511:0] ptg;
wire [127:0] pte;
always_comb
	ptg = {xc3,xc2,xc1,xc0};

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
Thor2022_eval_branch ube (.inst(xir), .a(xa), .b(xb), .takb(takb));

wire [127:0] cmpo, cmpio;
Thor2022_compare ucmp1
(
	.a(xa),
	.b(xb),
	.o(cmpo)
);

Thor2022_compare ucmp2
(
	.a(xa),
	.b(imm),
	.o(cmpio)
);

wire [15:0] hash;
Thor2022_ipt_hash uhash1
(
	.clk(clk_g),
	.asid(asid),
	.adr(xa),
	.mask(ptbr[127:96]),
	.hash(hash)
);

wire [7:0] cntlz_out;
cntlz128 uclz(xir.r1.func[0] ? ~xa : xa, cntlz_out);

//wire [255:0] sllrho = {128'd0,xa[127:0]|pn[127:0]} << {xb[4:0],4'h0};
//wire [255:0] srlrho = {pn[127:0]|xa[127:0],128'd0} >> {xb[4:0],4'h0};
//wire [255:0] sraho = {{128{xa[127]}},xa[127:0],128'd0} >> {xb[4:0],4'h0};
wire [255:0] sllio = {128'd0,xa[127:0]|pn[127:0]} << imm[6:0];
wire [255:0] srlio = {pn[127:0]|xa[127:0],128'd0} >> imm[6:0];
wire [255:0] sraio = {{128{xa[127]}},xa[127:0],128'd0} >> imm[6:0];
wire [255:0] sllro = {128'd0,xa[127:0]|pn[127:0]} << xb[6:0];
wire [255:0] srlro = {pn[127:0]|xa[127:0],128'd0} >> xb[6:0];
wire [255:0] sraro = {{128{xa[127]}},xa[127:0],128'd0} >> xb[6:0];

wire [255:0] mul_prod1;
reg [255:0] mul_prod;
wire [255:0] mul_prod2561;
reg [255:0] mul_prod256='d0;
reg [39:0] mulf_prod='d0;
reg mul_sign;
Value aa, bb;

// 18 stage pipeline
mult128x128 umul1
(
	.clk(clk_g),
	.ce(1'b1),
	.a(aa),
	.b(bb),
	.o(mul_prod2561)
);
wire multovf = ((reb[exec].dec.mulu|reb[exec].dec.mului) ? mul_prod256[255:128] != 'd0 : mul_prod256[255:128] != {128{mul_prod256[127]}});
/*
Thor2021_multiplier umul
(
  .CLK(clk_g),
  .A(aa),
  .B(bb),
  .P(mul_prod1)
);
wire multovf = ((xMulu|xMului) ? mul_prod[127:64] != 64'd0 : mul_prod[127:64] != {64{mul_prod[63]}});
*/

always_comb
	xa = reb[exec].ia;
always_comb
	xb = reb[exec].ib;
always_comb
	xc0 = reb[exec].ic0;
always_comb
	xc1 = reb[exec].ic1;
always_comb
	xc2 = reb[exec].ic3;
always_comb
	xc3 = reb[exec].ic3;
always_comb
	xir = reb[exec].ir;
always_comb
	imm = reb[exec].dec.imm;
always_comb
	pn = reb[exec].pn;

// 3 stage pipeline
mult24x16 umulf
(
  .clk(clk_g),
  .ce(1'b1),
  .a(aa[23:0]),
  .b(bb[15:0]),
  .o(mulf_prod)
);

wire [127:0] qo, ro;
wire dvd_done;
wire dvByZr;

Thor2022_divider #(.WID(128)) udiv
(
  .rst(rst_i),
  .clk(clk2x_i),
  .ld(state==DIV1),
  .abort(1'b0),
  .ss(reb[exec].dec.div),
  .su(reb[exec].dec.divsu),
  .isDivi(reb[exec].dec.divi),
  .a(xa),
  .b(xb),
  .imm(imm),
  .qo(qo),
  .ro(ro),
  .dvByZr(dvByZr),
  .done(dvd_done),
  .idle()
);


Thor2022_bitfield ubf
(
	.ir(xir),
	.a(xa),
	.b(xb),
	.c(xc0),
	.o(bf_out)
);

Thor2022_crypto ucrypto
(
	.ir(xir),
	.m(xmaskbit),
	.z(xzbit),
	.a(xa[63:0]),
	.b(xb[63:0]),
	.c(xc0[63:0]),
	.t(),
	.o(crypto_res)
);

wire [127:0] dfaso;
// takes about 30 clocks (32 to be safe)
DFPAddsub128nr udfa1
(
	.clk(clk_g),
	.ce(1'b1),
	.rm(xdfrm),
	.op(xir.r3.func==DFSUB),
	.a(xa),
	.b(xb),
	.o(dfaso)
);

wire [127:0] dfmulo;
wire dfmul_done;
DFPMultiply128nr udfmul1
(
	.clk(clk_g),
	.ce(1'b1),
	.ld(state==DF1),
	.a(xa),
	.b(xb),
	.o(dfmulo),
	.rm(xdfrm),
	.sign_exe(),
	.inf(),
	.overflow(),
	.underflow(),
	.done(dfmul_done)
);

Value mux_out;
integer n2;
always_comb
    for (n2 = 0; n2 < $bits(Value); n2 = n2 + 1)
        mux_out[n2] = xa[n2] ? xb[n2] : xc0[n2];

Value csr_res;
always_comb
	tReadCSR (csr_res, xir.csr.regno);

always_comb
case(xir.any.opcode)
R1:
	case(xir.r1.func)
	CNTLZ:	res2 = {121'd0,cntlz_out};
	CNTLO:	res2 = {121'd0,cntlz_out};
	PTGHASH:	res2 = hash;
	NOT:		res2 = |xa ? 'd0 : 128'd1;
	SEI:		res2 = ilvl;
	default:	res2 = 'd0;
	endcase
R2:
	case(xir.r3.func)
	ADD:	res2 = xa + xb + (xc0|pn);
	SUB:	res2 = xa - xb - pn;
	CMP:	res2 = cmpo;
	AND:	res2 = xa & xb & xc0;
	OR:		res2 = xa | xb | xc0;
	XOR:	res2 = xa ^ xb ^ xc0;
	SLL:	res2 = sllio[127:0];
	SRL:	res2 = srlio[255:128];
	SRA:	res2 = sraio[255:128];
	ROL:	res2 = sllio[127:0]|sllro[255:128];
	ROR:	res2 = srlio[255:128]|srlro[127:0];
//	SLLH:	res2 = sllrho[127:0] + xc0;
//	SRLH:	res2 = srlrho[255:128];
//	SRAH:	res2 = sraho[255:128];
//	ROLH:	res2 = sllrho[127:0]|sllrho[255:128];
//	RORH:	res2 = srlrho[255:128]|srlrho[127:0];
	MUL:	res2 = mul_prod256[127:0] + xc0 + pn;
	MULH:	res2 = mul_prod256[255:128];
	MULU:	res2 = mul_prod256[127:0] + xc0 + pn;
	MULUH:	res2 = mul_prod256[255:128];
	MULSU:res2 = mul_prod256[127:0] + xc0 + pn;
	MULF:	res2 = mul_prod256[127:0] + xc0 + pn;
	DIV:	res2 = qo;
	DIVU:	res2 = qo;
	DIVSU:	res2 = qo;
	MUX:	res2 = mux_out;
	SLT:	res2 = ($signed(xa) < $signed(xb)) ? xc0 : 'd0;
	SGE:	res2 = ($signed(xa) >= $signed(xb)) ? xc0 : 'd0;
	SLTU:	res2 = (xa < xb) ? xc0 : 'd0;
	SGEU:	res2 = (xa >= xb) ? xc0 : 'd0;
	SEQ:	res2 = (xa == xb) ? xc0 : 'd0;
	SNE:	res2 = (xa != xb) ? xc0 : 'd0;
	PTENDX:	res2 = pte_found ? pte_en : -128'd1;
	default:			res2 = 'd0;
	endcase
DF2:
	case(xir.r3.func)
	DFADD,DFSUB:	res2 = dfaso;
	default:	res2 = 'd0;
	endcase
VM:
	case(xir.vmr2.func)
	MTVM:			res2 = xa;
	default:	res2 = 'd0;
	endcase
OSR2:
	case(xir.r3.func)
	MFSEL:		res2 = memresp.res;
	default:	res2 = 'd0;
	endcase
CSR:		res2 = csr_res;
MFLK:		res2 = xca.offs;
BTFLD:	res2 = bf_out;
ADD2R:				res2 = xa + xb + pn;
SUB2R:				res2 = xa - xb - pn;
AND2R:				res2 = xa & xb;
OR2R:					res2 = xa | xb | pn;
XOR2R:				res2 = xa ^ xb ^ pn;
SEQ2R:				res2 = xa == xb;
SNE2R:				res2 = xa != xb;
SLT2R:				res2 = $signed(xa) < $signed(xb);
SLTU2R:				res2 = xa < xb;
SGEU2R:				res2 = xa >= xb;
SGE2R:				res2 = $signed(xa) >= $signed(xb);
CMP2R:				res2 = cmpo;
ADDI,ADDIL:		res2 = xa + imm + pn;
SUBFI,SUBFIL:	res2 = imm - xa - pn;
ANDI,ANDIL:		res2 = xa & imm;
ORI,ORIL:			res2 = xa | imm | pn;
XORI,XORIL:		res2 = xa ^ imm ^ pn;
SLLR2:				res2 = sllro[127:0];
SRLR2:				res2 = srlro[255:128];
SRAR2:				res2 = sraro[255:128];
ROLR2:				res2 = sllro[127:0]|sllro[255:128];
RORR2:				res2 = srlro[127:0]|srlro[255:128];
SLLI:					res2 = sllio[127:0];
SRLI:					res2 = srlio[255:128];
SRAI:					res2 = sraio[255:128];
//SLLHR2:				res2 = sllrho[127:0];// + xc0;
CMPI,CMPIL:		res2 = cmpio;//$signed(xa) < $signed(imm) ? -128'd1 : xa==imm ? 'd0 : 128'd1;
//CMPUI,CMPUIL:	res2 = xa < imm ? -128'd1 : xa==imm ? 'd0 : 128'd1;
MULI,MULIL:		res2 = mul_prod256[127:0] + pn;
MULUI,MULUIL:	res2 = mul_prod256[127:0] + pn;
MULFI:				res2 = mul_prod256[127:0] + pn;
DIVI,DIVIL:		res2 = qo;
SEQI,SEQIL:		res2 = xa == imm;
SNEI,SNEIL:		res2 = xa != imm;
SLTI,SLTIL:		res2 = $signed(xa) < $signed(imm);
SLEI,SLEIL:		res2 = $signed(xa) <= $signed(imm);
SGTI,SGTIL:		res2 = $signed(xa) > $signed(imm);
SGEI,SGEIL:		res2 = $signed(xa) >= $signed(imm);
SLTUI,SLTUIL:	res2 = xa < imm;
SLEUIL:				res2 = xa <= imm;
SGTUIL:				res2 = xa > imm;
SGEUIL:				res2 = xa >= imm;
DJMP:					res2 = xa - 2'd1;
//STSET:				res2 = xc0 - 2'd1;
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOU,LDH,LDHR,LDHS,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDOUX,LDHX:
							res2 = memresp.res;
BSET:							
	case(xir[31:29])
	3'd0:	res2 = xa + 4'd1;
	3'd1:	res2 = xa + 4'd2;
	3'd2:	res2 = xa + 4'd4;
	3'd3:	res2 = xa + 4'd8;
	3'd4:	res2 = xa - 4'd1;
	3'd5:	res2 = xa - 4'd2;
	3'd6:	res2 = xa - 4'd4;
	3'd7:	res2 = xa - 4'd8;
	endcase
STMOV:							
	case(xir[43:41])
	3'd0:	res2 = xc0 + 4'd1;
	3'd1:	res2 = xc0 + 4'd2;
	3'd2:	res2 = xc0 + 4'd4;
	3'd3:	res2 = xc0 + 4'd8;
	3'd4:	res2 = xc0 - 4'd1;
	3'd5:	res2 = xc0 - 4'd2;
	3'd6:	res2 = xc0 - 4'd4;
	3'd7:	res2 = xc0 - 4'd8;
	endcase
default:			res2 = 64'd0;
endcase

always_comb
	res = res2;//|crypto_res;

always_comb
case(xir.any.opcode)
MTLK:	cares <= xa;
JMP,DJMP,BRA:	cares <= reb[exec].ip + reb[exec].ilen;
default:	cares <= caregfile[1];
endcase

always_comb
case(xir.any.opcode)
R2:
	case(xir.r3.func)
	ADD:			carry_res = res2[128];
	SUB:			carry_res = res2[128];
	MUL:			carry_res = mul_prod[255:128];
	MULU:			carry_res = mul_prod[255:128];
	MULSU:		carry_res = mul_prod[255:128];
	SLL:			carry_res = sllio[255:128];
	SRL:			carry_res = srlio[127:0];
	SRA:			carry_res = sraio[127:0];
	default:	carry_res = 128'd0;
	endcase
// (a&b)|(a&~s)|(b&~s)
ADD2R:	carry_res = res2[128];
SUB2R:	carry_res = res2[128];
SLLR2:	carry_res = sllro[255:128];
SRLR2:	carry_res = srlro[127:0];
SRAR2:	carry_res = sraro[127:0];
SLLI:		carry_res = sllio[255:128];
SRLI:		carry_res = srlio[127:0];
SRAI:		carry_res = sraio[127:0];
default:	carry_res = 128'd0;
endcase

Thor2022_inslength uil(insn, ilen);

always_comb
begin
	next_ip.micro_ip = 'd0;
 	next_ip.offs = ip.offs + ilen;
end

Thor2022_BTB_x1 ubtb
(
	.rst(rst_i),
	.clk(clk_g),
	.wr(wExBranch & wval),
	.wip(wip.offs),
	.wtgt(wJmptgt),
	.takb(wtakb),
	.rclk(~clk_g),
	.ip(ip.offs),
	.tgt(btb_tgt),
	.hit(btb_hit),
	.nip(next_ip.offs)
);

Thor2022_gselectPredictor ubp
(
	.rst(rst_i),
	.clk(clk_g),
	.en(bpe),
	.xisBranch(reb[exec].dec.jxx),
	.xip(xip.offs),
	.takb(takb),
	.ip(ip.offs),
	.predict_taken(ipredict_taken)
);

wire memreq_wack;
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
	.fifoToCtrl_full_o(),
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

always_comb
begin
	insn = ic_line >> {ip.offs[5:1],4'd0};
end

Address siea;
always_comb
	siea = xa + xb;

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
// Pipeline control
//
// Stores are delayed until it can be guarenteed that they will complete
// without an intervening flow control change.
// If the target of a load operation is used by the next instruction, then
// execution of that instruction needs to be delayed until the load is
// complete.
// A synchronizing instruction causes a stall until the sync clears.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire stall_i = !ihit;
wire stall_d = ((deco.storer|deco.storen|deco.stset|deco.stcmp|deco.stfnd|deco.stmov) &&
								(((|xcause || reb[exec].dec.flowchg || reb[exec].dec.load) && xval) ||
								 ((|mcause || md.flowchg) && mval) ||
								 ((|wcause || wd.flowchg) && wval))) ||
								 ((reb[exec].dec.mulall||reb[exec].dec.divall) && xval) ||
//								(reb[exec].dec.load && (Ra==reb[exec].dec.Rt || {Tb,Rb}=={1'b0,reb[exec].dec.Rt} || {Tc,Rc}=={1'b0,reb[exec].dec.Rt} || Rc1==reb[exec].dec.Rt || Rc2==reb[exec].dec.Rt || Rc3==reb[exec].dec.Rt) && xval && reb[exec].dec.Rt!='d0) ||
//								(md.load && (Ra==md.Rt || {Tb,Rb}=={2'b00,md.Rt} || {Tc,Rc}=={2'b00,md.Rt} || Rc1==md.Rt) && mval && md.Rt!='d0) ||
//								(wd.load && (Ra==wd.Rt || {Tb,Rb}=={2'b00,wd.Rt} || {Tc,Rc}=={2'b00,wd.Rt} || Rc1==wd.Rt) && wval && wd.Rt!=6'd0) ||
								(reb[exec].dec.sync && xval) || (md.sync && mval) || (wd.sync && wval) || tSync || uSync || vSync;

assign run = ihit;
always_comb advance_t = !stall_i && (state==RUN);
always_comb	advance_w = advance_t;
always_comb advance_m = advance_w;
always_comb advance_x = advance_m;
always_comb advance_d = advance_x && !stall_d;
always_comb advance_i = advance_d;

reg [3:0] xx;	// debug marker

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Pipeline
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always_ff @(posedge clk_g)
if (rst_i) begin
	tReset();
	goto (RESTART1);
end
else begin
	tOnce();
	tInsnFetch();
	tDecode();
	tExecute();
	tWriteback();
	tSyncTrailer();
	tStateMachine();

end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function fnArgsValid;
input [2:0] kk;
fnArgsValid = (reb[kk].iav && reb[kk].ibv &&
				reb[kk].ic0v && reb[kk].ic1v && reb[kk].ic2v && reb[kk].ic3v && reb[kk].lkv);
endfunction

integer kk;
reg [2:0] next_exec;
reg mc_busy;
always_comb
begin
next_exec = exec;
for (kk = 7; kk >= 0; kk = kk - 1)
	if (kk != exec) begin
		if ((reb[kk].state==3'd2 || reb[kk].state==3'd3) && reb[kk].v && !stomp[kk])
			if (fnArgsValid(kk)) begin
				if (!mc_busy || !reb[kk].dec.multi_cycle) begin
					if (reb[kk].dec.mem) begin
						if (reb[next_exec].dec.mem && reb[next_exec].state < 3'd4) begin
							if (reb[kk].sn < reb[next_exec].sn)
								next_exec = kk;
						end
						else
							next_exec = kk;
					end
					else begin
						if (!(reb[next_exec].dec.mem && reb[next_exec].state < 3'd4))
							next_exec = kk;
					end
				end
			end
	end
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Support tasks
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
integer n6;

task tReset;
begin
	ld_time <= FALSE;
	wval <= INV;
	xval <= INV;
	mval <= INV;
	dval <= INV;
	ival <= INV;
	ir <= NOP_INSN;
	xir <= NOP_INSN;
	mir <= NOP_INSN;
	wir <= NOP_INSN;
	xSc <= 3'd0;
	xPredictableBranch <= FALSE;
	tid <= 8'h00;
	memreq.tid <= 8'h00;
	memreq.step <= 6'd0;
	memreq.wr <= 1'b0;
	memreq.func <= 'd0;
	memreq.func2 <= 'd0;
	memreq.adr <= 'h0;
	memreq.dat <= 'd0;
	memreq.sz <= 'h0;
	dpfx <= FALSE;
	pfx_cnt <= 3'd0;
//	cr0 <= 64'h300000001;
	cr0 <= 64'h200000001;
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
	pmStack <= 64'h3e3e3e3e3e3e3e3e;	// Machine mode, irq level 7, ints disabled
	plStack <= 64'hffffffffffffffff;	// PL = 255
	asid <= 'h0;
	istk_depth <= 4'd1;
	icause <= 16'h0000;
	dcause <= 16'h0000;
	xcause <= 16'h0000;
	mcause <= 16'h0000;
	wcause <= 16'h0000;
	mExBranch <= FALSE;
	wExBranch <= FALSE;
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
		reb[n6].state <= 3'd7;
	end
	for (n6 = 0; n6 < 32; n6 = n6 + 1)
		regfile_src[n6] <= 5'd31;
	for (n6 = 0; n6 < 16; n6 = n6 + 1)
		ca_src[n6] <= 5'd31;
	sn <= 'd0;
	head <= 'd0;
	tail <= 'd0;
	exec <= 'd0;
	dec <= 'd0;
	mc_busy <= 'd0;
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Once per clock operations.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tOnce;
begin
	xx <= 4'h0;
	memreq.wr <= FALSE;
	if (ld_time==TRUE && wc_time_dat==wc_time)
		ld_time <= FALSE;
	if (clr_wc_time_irq && !wc_time_irq)
		clr_wc_time_irq <= FALSE;
	clr_ipage_fault <= 1'b0;
end
endtask

task tStateMachine;
begin
case (state)
RESTART1:
	begin
		tReset();
		goto(RESTART2);
	end
RESTART2:
	begin
		rst_cnt <= 6'd0;
		goto(RUN);
	end
RUN:
	begin
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
				goto (WAIT_MEM2);
			end
		end
	end
WAIT_MEM2:
	begin
		//wackr <= 1'b0;
		if (memresp_fifo_v)
		begin
			memresp_fifo_rd <= FALSE;
			reb[exec].res <= memresp.res;
			if (mStset|mStmov)
				reb[exec].dec.rfwr <= TRUE;
			if (memresp.tid == memreq.tid) begin
				if (memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==MR_MFSEL) begin
					reb[exec].dec.rfwr <= FALSE;
					if (memreq.func2!=MR_LDDESC) begin
						reb[exec].dec.rfwr <= TRUE;
					end
					if (memreq.func2==MR_LDOO)
						reb[exec].w512 <= TRUE;
				end
				else if (memreq.sz==3'd5) begin
					reb[exec].w256 <= TRUE;
				end
				if (|memresp.cause) begin
					if (~|reb[exec].cause)
						reb[exec].istk_depth <= reb[exec].istk_depth + 2'd1;
					reb[exec].cause <= memresp.cause;
					reb[exec].badAddr <= memresp.badAddr;
				end
				reb[exec].state <= EXECUTED;
				exec <= next_exec;
			 	tArgUpdate(exec);
			 	mc_busy <= FALSE;
				goto (RUN);
			end
		end
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Invalidate the xir and switch back to the run state.
// The xir is invalidated to prevent the instruction from executing again.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
INVnRUN:
  begin
  	reb[exec].state <= EXECUTED;
		exec <= next_exec;
  	reb[exec].res <= res;
  	reb[exec].carry_res <= carry_res;
  	tArgUpdate(exec);
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
    if (reb[exec].dec.mul) mul_sign <= xa[$bits(Value)-1] ^ xb[$bits(Value)-1];
    else if (reb[exec].dec.muli) mul_sign <= xa[$bits(Value)-1] ^ imm[$bits(Value)-1];
    else if (reb[exec].dec.mulsu) mul_sign <= xa[$bits(Value)-1];
    else if (reb[exec].dec.mulsui) mul_sign <= xa[$bits(Value)-1];
    else mul_sign <= 1'b0;  // MULU, MULUI
    if (reb[exec].dec.mul) aa <= fnAbs(xa);
    else if (reb[exec].dec.muli) aa <= fnAbs(xa);
    else if (reb[exec].dec.mulsu) aa <= fnAbs(xa);
    else if (reb[exec].dec.mulsui) aa <= fnAbs(xa);
    else aa <= xa;
    if (reb[exec].dec.mul) bb <= fnAbs(xb);
    else if (reb[exec].dec.muli) bb <= fnAbs(imm);
    else if (reb[exec].dec.mulsu) bb <= xb;
    else if (reb[exec].dec.mulsui) bb <= imm;
    else if (reb[exec].dec.mulu|reb[exec].dec.mulf) bb <= xb;
    else bb <= imm; // MULUI
    delay_cnt <= (reb[exec].dec.mulf|reb[exec].dec.mulfi) ? 8'd3 : 8'd18;	// Multiplier has 18 stages
	// Now wait for the six stage pipeline to finish
    goto (MUL2);
  end
MUL2:
  call(DELAYN,MUL9);
MUL9:
  begin
//    mul_prod <= (xMulf|xMulfi) ? mulf_prod : mul_sign ? -mul_prod1 : mul_prod1;
    mul_prod256 <= (reb[exec].dec.mulf|reb[exec].dec.mulfi) ? mulf_prod : mul_sign ? -mul_prod2561 : mul_prod2561;
    //upd_rf <= `TRUE;
    goto(INVnRUN);
    if (multovf & mexrout[5]) begin
      ex_fault(FLT_OFL);
    end
  end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DIV1:
	goto (DIV2);
DIV2:
  if (dvd_done) begin
    //upd_rf <= `TRUE;
    goto(INVnRUN);
    if (dvByZr & mexrout[3]) begin
      ex_fault(FLT_DBZ);
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
	if (dfmul_done)
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
// We want decodes in the IFETCH stage to be fast so they don't appear
// on the critical path. Keep the decodes to a minimum.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tInsnFetch;
integer n17;
begin
	// Choose the next fetch bucket.
	for (n17 = 0; n17 < 8; n17 = n17 + 1)
		if (n17 != tail && (reb[n17].state==RETIRED || reb[n17].state==EMPTY))
			tail <= n17;
	if (ihit && (reb[tail].state==3'd0 || reb[tail].state==RETIRED)) begin// && ((tail + 2'd1) & 3'd7) != head) begin
		reb[tail].state <= FETCHED;
		reb[tail].sn <= sn;
		reb[tail].v <= 1'b1;
		sn <= sn + 2'd1;
		tail <= tail + 2'd1;
		ival <= VAL;
		dval <= ival;
		dlen <= ilen;
		cio <= {2'b00,cio[15:2]};
		if (insn.any.v && istep < vl) begin
			istep <= istep + 2'd1;
			ip <= ip;
		end
//		else if ((insn.any.opcode==BSET || insn.any.opcode==STMOV || insn.any.opcode==STFND || insn.any.opcode==STCMP) && r58 != 64'd0)
//			ip <= ip;
		else if (micro_ip != 7'd0) begin
			case(micro_ip)
			// POP Ra
			7'd1:		begin micro_ip <= 7'd2; reb[tail].ir <= {29'h00,5'd31,micro_ir[13:9],1'b0,LDH}; dlen <= 4'd2; end	// LDOS $Ra,[$SP]
			7'd2:		begin micro_ip <= 7'd0; reb[tail].ir <= {13'h010,5'd31,5'd31,1'b0,ADDI}; ip.offs <= ip.offs + 4'd2; end							// ADD $SP,$SP,#8
			// POP Ra,Rb,Rc,Rd
			7'd5:		begin micro_ip <= 7'd6; reb[tail].ir <= {29'h00,5'd31,micro_ir[13: 9],1'b0,(micro_ir[31:29]>=3'd1)?LDH:NOP}; dlen <= 4'd4; end	// LDOS $Ra,[$SP]
			7'd6:		begin micro_ip <= 7'd7; reb[tail].ir <= {29'h10,5'd31,micro_ir[18:14],1'b0,(micro_ir[31:29]>=3'd2)?LDH:NOP}; end	// LDOS $Rb,[$SP]
			7'd7:		begin micro_ip <= 7'd8; reb[tail].ir <= {29'h20,5'd31,micro_ir[23:19],1'b0,(micro_ir[31:29]>=3'd3)?LDH:NOP}; end	// LDOS $Rc,[$SP]
			7'd8:		begin micro_ip <= 7'd9; reb[tail].ir <= {29'h30,5'd31,micro_ir[28:24],1'b0,(micro_ir[31:29]>=3'd4)?LDH:NOP}; end	// LDOS $Rc,[$SP]
			7'd9:		begin micro_ip <= 7'd0; reb[tail].ir <= {6'h0,micro_ir[31:29],4'h0,5'd31,5'd31,1'b0,ADDI}; ip.offs <= ip.offs + 4'd4; end							// ADD $SP,$SP,#24
			// PUSH Ra
			7'd10:	begin micro_ip <= 7'd11; reb[tail].ir <= {13'h1FF0,5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd2; end							// ADD $SP,$SP,#-16
			7'd11:	begin micro_ip <= 7'd0;  reb[tail].ir <= {29'h00,5'd31,micro_ir[13:9],1'b0,STH}; ip.offs <= ip.offs + 4'd2; end	// STOS $Ra,[$SP]
			// PUSH Ra,Rb,Rc,Rd
			7'd15:	begin micro_ip <= 7'd16; reb[tail].ir <= {{5'h1F,4'h0-micro_ir[31:29],4'h0},5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd4; end								// ADD $SP,$SP,#-24
			7'd16:	begin micro_ip <= 7'd17; reb[tail].ir <= {29'h00,5'd31,micro_ir[28:24],1'b0,(micro_ir[31:29]==3'd4)?STH:NOP}; end	// STOS $Rc,[$SP]
			7'd17:	begin micro_ip <= 7'd18; reb[tail].ir <= {22'd0,micro_ir[31:29]-2'd3,4'h0,5'd31,micro_ir[23:19],1'b0,(micro_ir[31:29]>=3'd3)?STH:NOP}; end	// STOS $Rb,8[$SP]
			7'd18:	begin micro_ip <= 7'd19; reb[tail].ir <= {22'd0,micro_ir[31:29]-2'd2,4'h0,5'd31,micro_ir[18:14],1'b0,(micro_ir[31:29]>=3'd2)?STH:NOP}; end	// STOS $Rb,8[$SP]
			7'd19:	begin micro_ip <= 7'd0;  reb[tail].ir <= {22'd0,micro_ir[31:29]-2'd1,4'h0,5'd31,micro_ir[13:9],1'b0,(micro_ir[31:29]>=3'd1)?STH:NOP}; ip.offs <= ip.offs + 4'd4; end		// STOS $Ra,16[$SP]
			// LEAVE
			7'd20:	begin micro_ip <= 7'd21; reb[tail].ir <= {13'h000,5'd30,5'd31,1'b0,ADDI};	end						// ADD $SP,$FP,#0
			7'd21:	begin micro_ip <= 7'd22; reb[tail].ir <= {29'h00,5'd31,5'd30,1'b0,LDH}; end				// LDO $FP,[$SP]
			7'd22:	begin micro_ip <= 7'd23; reb[tail].ir <= {29'h10,5'd31,5'd03,1'b0,LDH}; end				// LDO $T0,16[$SP]
			7'd23:	begin micro_ip <= 7'd26; reb[tail].ir <= {2'd1,5'd03,1'b0,MTLK}; end										// MTLK LK1,$T0
//			7'd24:	begin micro_ip <= 7'd25; ir <= {3'd6,8'h18,6'd63,6'd03,1'b0,LDOS}; end				// LDO $T0,24[$SP]
//			7'd25:	begin micro_ip <= 7'd26; ir <= {3'd0,1'b0,CSRRW,4'd0,16'h3103,6'd03,6'd00,1'b0,CSR}; end	// CSRRW $R0,$T0,0x3103
			7'd26: 	begin micro_ip <= 7'd27; reb[tail].ir <= {{6'h0,micro_ir[31:13]}+8'd4,4'b0,5'd31,5'd31,1'b0,ADDIL}; end	// ADD $SP,$SP,#Amt
			7'd27:	begin micro_ip <= 7'd0;  reb[tail].ir <= {1'd0,micro_ir[12:9],2'd1,1'b0,RTS}; ip.offs <= 32'hFFFD0000; end
			// STOO
			7'd28:	begin micro_ip <= 7'd29; ir <= {micro_ir[47:12],3'd0,1'b0,STOO}; dlen <= 4'd6; end
			7'd29:	begin micro_ip <= 7'd30; ir <= {micro_ir[47:12],3'd2,1'b0,STOO}; end
			7'd30:	begin micro_ip <= 7'd31; ir <= {micro_ir[47:12],3'd4,1'b0,STOO}; end
			7'd31:	begin micro_ip <= 7'd0;  ir <= {micro_ir[47:12],3'd6,1'b0,STOO}; ip.offs <= ip.offs + 4'd6; end
			// ENTER
			7'd32: 	begin micro_ip <= 7'd33; reb[tail].ir <= {13'h1FC0,5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd4; end						// ADD $SP,$SP,#-64
			7'd33:	begin micro_ip <= 7'd34; reb[tail].ir <= {29'h00,5'd31,5'd30,1'b0,STH}; end				// STO $FP,[$SP]
			7'd34:	begin micro_ip <= 7'd35; reb[tail].ir <= {2'd1,5'd03,1'b0,MFLK}; end										// MFLK $T0,LK1
			7'd35:	begin micro_ip <= 7'd38; reb[tail].ir <= {29'h10,5'd31,5'd03,1'b0,STH}; end				// STO $T0,16[$SP]
//			7'd36:	begin micro_ip <= 7'd37; ir <= {3'd0,1'b0,CSRRD,4'd0,16'h3103,6'd00,6'd03,1'b0,CSR}; end	// CSRRD $T0,$R0,0x3103
//			7'd37:	begin micro_ip <= 7'd38; ir <= {3'd6,8'h18,6'd63,6'd03,1'b0,STOS}; end				// STO $T0,24[$SP]
			7'd38:	begin micro_ip <= 7'd39; reb[tail].ir <= {29'h20,5'd31,5'd00,1'b0,STH}; end				// STH $R0,32[$SP]
			7'd39:	begin micro_ip <= 7'd40; reb[tail].ir <= {29'h30,5'd31,5'd00,1'b0,STH}; end				// STH $R0,48[$SP]
			7'd40: 	begin micro_ip <= 7'd41; reb[tail].ir <= {13'h000,5'd31,5'd30,1'b0,ADDI}; end						// ADD $FP,$SP,#0
			7'd41: 	begin micro_ip <= 7'd0;  reb[tail].ir <= {{9{micro_ir[31]}},micro_ir[31:12],3'b0,5'd31,5'd31,1'b0,ADDIL}; ip.offs <= ip.offs + 4'd4; end // SUB $SP,$SP,#Amt
			// DEFCAT
			7'd44:	begin micro_ip <= 7'd45; ir <= {3'd6,8'h00,6'd62,6'd3,1'b0,LDH}; dlen <= 4'd2; end					// LDO $Tn,[$FP]
			7'd45:	begin micro_ip <= 7'd46; ir <= {3'd6,8'h20,6'd3,6'd4,1'b0,LDHS}; end					// LDO $Tn+1,32[$Tn]
			7'd46:	begin micro_ip <= 7'd47; ir <= {3'd6,8'h10,6'd62,6'd4,1'b0,STHS}; end					// STO $Tn+1,16[$FP]
			7'd47:	begin micro_ip <= 7'd48; ir <= {3'd6,8'h28,6'd3,6'd4,1'b0,LDHS}; end					// LDO $Tn+1,40[$Tn]
			7'd48:	begin micro_ip <= 7'd0;  ir <= {3'd6,8'h18,6'd62,6'd4,1'b0,STHS}; ip.offs <= ip.offs + 4'd2; end					// STO $Tn+1,24[$FP]
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
		end
		else begin
			istep <= 8'h00;
			ip <= next_ip;
		end
		if (btbe & btb_hit)
			ip <= btb_tgt;
		if (micro_ip==7'd0)
			case(insn.any.opcode)
			POP:		begin micro_ip <= 7'd1; ip <= ip; end
			POP4R:	begin micro_ip <= 7'd5; ip <= ip; end
			PUSH:		begin micro_ip <= 7'd10; ip <= ip; end
			PUSH4R:	begin micro_ip <= 7'd15; ip <= ip; end
			ENTER:	begin micro_ip <= 7'd32; ip <= ip; end
			LEAVE:	begin micro_ip <= 7'd20; ip <= ip; end
//			STOO:		begin if (insn[10]) begin micro_ip <= 7'd28; ip <= ip; end end
			LDCTX:	begin micro_ip <= 7'd96; ip <= ip; end
			STCTX:	begin micro_ip <= 7'd64; ip <= ip; end
			BSET:		begin micro_ip <= 7'd55; ip <= ip; end
			BRA:
				if (insn[31:29]==3'd0)
					ip.offs <= {{109{insn[28]}},insn[28:11],1'b0};
				else if (insn[31:29]==3'd7)
					ip.offs <= ip.offs + {{109{insn[28]}},insn[28:11],1'b0};
			JMP:
				if (insn.jmp.Ca==3'd0)
					ip.offs <= {{94{insn.jmp.Tgthi[15]}},insn.jmp.Tgthi,insn.jmp.Tgtlo,1'b0};
				else if (insn.jmp.Ca==3'd7)
					ip.offs <= ip.offs + {{94{insn.jmp.Tgthi[15]}},insn.jmp.Tgthi,insn.jmp.Tgtlo,1'b0};
			CARRY:	begin cio <= insn[30:15]; cioreg <= insn[11:9]; end
			default:	;
			endcase
		reb[tail].ip <= ip;
		reb[tail].ip.micro_ip <= micro_ip;
		reb[tail].ilen <= ilen;
		if (micro_ip==7'd0) begin
			ir <= insn;
			reb[tail].ir <= insn;
			micro_ir <= insn;
		end
		reb[tail].step <= istep;
		reb[tail].predict_taken <= ipredict_taken;
		dpfx <= is_prefix(insn.any.opcode);
		distk_depth <= istk_depth;
		if (is_prefix(insn.any.opcode))
			pfx_cnt <= pfx_cnt + 2'd1;
		else
			pfx_cnt <= 3'd0;
		if (di)
			dicnt <= dicnt - 2'd1;
		// Interrupts disabled while running micro-code.
		if (micro_ip==7'd0 && cio==16'h0000) begin
			if (irq_i > pmStack[3:1] && gie && !dpfx && !di) begin
				reb[tail].cause <= 16'h8000|icause_i|(irq_i << 4'd8);
				istk_depth <= istk_depth + 2'd1;
			end
			else if (wc_time_irq && gie && !dpfx && !di) begin
				reb[tail].cause <= 16'h8000|FLT_TMR;
				istk_depth <= istk_depth + 2'd1;
			end
			else if (insn.any.opcode==BRK) begin
				reb[tail].cause <= FLT_BRK;
				istk_depth <= istk_depth + 2'd1;
			end
			// Triple prefix fault.
			else if (pfx_cnt > 3'd2) begin
				reb[tail].cause <= 16'h8000|FLT_PFX;
				istk_depth <= istk_depth + 2'd1;
			end
		end
		if (ipage_fault) begin
			reb[tail].cause <= 16'h8000|FLT_CPF;
			istk_depth <= istk_depth + 2'd1;
			reb[tail].ir <= NOP_INSN;
			ir <= NOP_INSN;
		end
		if (itlbmiss) begin
			reb[tail].cause <= 16'h8000|FLT_TLBMISS;
			istk_depth <= istk_depth + 2'd1;
			reb[tail].ir <= NOP_INSN;
			ir <= NOP_INSN;
		end
		if (insn.any.opcode==R1 && insn.r3.func==DI)
			dicnt <= insn[13:9];
	end
	// Wait for cache load
	else begin
`ifdef OVERLAPPED_PIPELINE
		ip <= ip;
`endif
	end	
end
endtask


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Register fetch and decode stage
// Much of the decode is done above by combinational logic outside of the
// clock domain.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tDecode;
integer n7;
begin
	// Choose the next decode bucket.
	for (n7 = 0; n7 < 8; n7 = n7 + 1)
		if (n7 != dec && reb[n7].state==FETCHED)
			dec <= n7;
	if (reb[dec].state==FETCHED) begin
		reb[dec].state <= DECODED;
		reb[dec].dec <= deco;
		reb[dec].istk_depth <= distk_depth;
		reb[dec].ia <= rfoa;
		reb[dec].ib <= rfob;
		reb[dec].ic0 <= rfoc0;
		reb[dec].ic1 <= rfoc1;
		reb[dec].ic2 <= rfoc2;
		reb[dec].ic3 <= rfoc3;
		reb[dec].pn <= rfop;
		reb[dec].ca <= rfoca;
		reb[dec].iav <= rfoa_v;
		reb[dec].ibv <= rfob_v;
		reb[dec].ic0v <= rfoc0_v;
		reb[dec].ic1v <= rfoc1_v;
		reb[dec].ic2v <= rfoc2_v;
		reb[dec].ic3v <= rfoc3_v;
		reb[dec].lkv <= (reb[head].dec.Ct==deco.Ca && reb[head].v && reb[head].state==3'd4 && reb[head].dec.carfwr) || ca_src[deco.Ca]==5'd31 || LkValid(reb[dec].ir);
		reb[dec].ias <= Source1Valid(reb[dec].ir)||deco.Ra=='d0 ? 5'd31 : regfile_src[deco.Ra];
		reb[dec].ibs <= Source2Valid(reb[dec].ir)||deco.Rb=='d0 ? 5'd31 : regfile_src[deco.Rb];
		reb[dec].ic0s <= Source3Valid(reb[dec].ir)||deco.Rc=='d0 ? 5'd31 : regfile_src[deco.Rc];
		reb[dec].ic1s <= Source3Valid(reb[dec].ir) ? 5'd31 : regfile_src[{deco.Rc[4:2],2'b01}];
		reb[dec].ic2s <= Source3Valid(reb[dec].ir) ? 5'd31 : regfile_src[{deco.Rc[4:2],2'b10}];
		reb[dec].ic3s <= Source3Valid(reb[dec].ir) ? 5'd31 : regfile_src[{deco.Rc[4:2],2'b11}];
		reb[dec].lks <= LkValid(reb[dec].ir) ? 5'd31 : ca_src[deco.Ca];
		reb[dec].cioreg <= cioreg;
		reb[dec].cio <= cio[1:0];
		reb[dec].predict_taken <= dpredict_taken;
		reb[dec].cause <= dcause;
		reb[dec].step <= dstep;
		reb[dec].mask_bit <= mask[dstep];
		reb[dec].zbit <= zbit;
		reb[dec].predictable_branch <= (ir.jxx.Ca==3'd0 || ir.jxx.Ca==3'd7);
		regfile_src[deco.Rt] <= dec;
		regfile_src[5'd0] <= 5'd31;
		ca_src[deco.Ct] <= dec;
		
		xval <= dval;
		if (ir.jxx.Ca==3'd0 && deco.jxx && dpredict_taken && bpe) begin	// Jxx, DJxx
			if (ip.offs != deco.jmptgt) begin
				for (n7 = 0; n7 < 8; n7 = n7 + 1)
					if (reb[n7].sn > reb[dec].sn)
						reb[n7] <= 'd0;
				reb[dec].ip.offs <= deco.jmptgt;
			end
		end
		else if (ir.jxx.Ca==3'd7 && deco.jxx && dpredict_taken && bpe) begin	// Jxx, DJxx
			if (ip.offs != reb[dec].ip.offs + deco.jmptgt) begin
				for (n7 = 0; n7 < 8; n7 = n7 + 1)
					if (reb[n7].sn > reb[dec].sn)
						reb[n7] <= 'd0;
				reb[dec].ip.offs <= reb[dec].ip.offs + deco.jmptgt;
			end
		end
		if (deco.jmp|deco.bra|deco.jxx)
  		reb[dec].cares.offs <= reb[dec].ip.offs + reb[dec].ilen;
  	else if (deco.mtlk)
  		reb[dec].cares.offs <= (reb[head].dec.Rt==deco.Rc && reb[head].v && reb[head].state==3'd4 && reb[head].dec.rfwr) ? reb[head].res : regfile[deco.Rc];
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tExMem;
begin
  if (reb[exec].dec.mulall)
    goto(MUL1);
  if (reb[exec].dec.divall)
    goto(DIV1);
  if (reb[exec].dec.isDF)
  	goto (DF1);
//    if (xFloat)
//      goto(FLOAT1);
  if (reb[exec].dec.loadr) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= reb[exec].dec.ldz ? MR_LOADZ : MR_LOAD;
  	case(reb[exec].dec.memsz)
  	byt:		begin memreq.func2 <= MR_LDB; end
  	wyde:		begin memreq.func2 <= MR_LDW; end
  	tetra:	begin memreq.func2 <= MR_LDT; end
  	octa:		begin memreq.func2 <= MR_LDO; end
  	hexi:		begin memreq.func2 <= MR_LDH; end
  	default:	begin memreq.func2 <= MR_LDO; end
  	endcase
  	memreq.sz <= reb[exec].dec.memsz;
  	memreq.adr.offs <= reb[exec].ia + reb[exec].imm;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
  else if (reb[exec].dec.ldoo) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_LOAD;
  	memreq.func2 <= MR_LDOO;
  	memreq.sz <= hexiquad;
  	memreq.adr.offs <= reb[exec].ia + reb[exec].imm;
  	memreq.adr.offs[5:0] <= 6'h00;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
/* should be LLA
  else if (xLear) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= reb[exec].dec.ldz ? MR_LOADZ : MR_LOAD;
  	memreq.func2 <= MR_LEA;
  	memreq.adr.offs <= xa + imm;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
*/
  else if (reb[exec].dec.loadn) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= reb[exec].dec.ldz ? MR_LOADZ : MR_LOAD;
  	case(reb[exec].dec.memsz)
  	byt:		begin memreq.func2 <= MR_LDB; end
  	wyde:		begin memreq.func2 <= MR_LDW; end
  	tetra:	begin memreq.func2 <= MR_LDT; end
  	octa:		begin memreq.func2 <= MR_LDT; end
  	hexi:		begin memreq.func2 <= MR_LDH; end
  	default:	begin memreq.func2 <= MR_LDO; end
  	endcase
  	memreq.sz <= reb[exec].dec.memsz;
  	memreq.adr.offs <= reb[exec].ia + reb[exec].ib;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
/*
  else if (xLean) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= reb[exec].dec.ldz ? MR_LOADZ : MR_LOAD;
  	memreq.func2 <= MR_LEA;
  	memreq.adr.offs <= siea;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
*/
  else if (reb[exec].dec.storer) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_STORE;
  	case(reb[exec].dec.memsz)
  	byt:		begin memreq.func2 <= MR_STB; end
  	wyde:		begin memreq.func2 <= MR_STW; end
  	tetra:	begin memreq.func2 <= MR_STT; end
  	hexi:		begin memreq.func2 <= MR_STH; end
  	default:	begin memreq.func2 <= MR_STO; end
  	endcase
  	memreq.sz <= reb[exec].dec.memsz;
  	memreq.adr.offs <= reb[exec].ia + reb[exec].imm;
  	memreq.dat <= {xc1,xc0};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
  else if (reb[exec].dec.storen) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_STORE;
  	case(reb[exec].dec.memsz)
  	byt:		begin memreq.func2 <= MR_STB; end
  	wyde:		begin memreq.func2 <= MR_STW; end
  	tetra:	begin memreq.func2 <= MR_STT; end
  	hexi:		begin memreq.func2 <= MR_STH; end
  	default:	begin memreq.func2 <= MR_STO; end
  	endcase
  	memreq.sz <= reb[exec].dec.memsz;
  	memreq.adr.offs <= reb[exec].ia + reb[exec].ib;
  	memreq.dat <= {reb[exec].ic1,reb[exec].ic0};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
	else if (reb[exec].dec.stset) begin
		if (reb[exec].ic0 != 64'd0) begin
	  	memreq.tid <= tid;
	  	tid <= tid + 2'd1;
	  	memreq.func <= MR_STORE;
	  	case(reb[exec].ir[30:29])
	  	2'd0:	begin memreq.func2 <= MR_STB; end
	  	2'd1:	begin memreq.func2 <= MR_STW; end
	  	2'd2:	begin memreq.func2 <= MR_STT; end
	  	default:	begin memreq.func2 <= MR_STO; end
	  	endcase
	  	memreq.sz <= {1'b0,reb[exec].ir[30:29]};
	  	memreq.adr.offs <= reb[exec].ia;
	  	memreq.dat <= reb[exec].ib;
	  	memreq.wr <= TRUE;
	  	goto (WAIT_MEM1);
  	end
  	else
  		reb[exec].dec.stset <= FALSE;
	end
	else if (reb[exec].dec.stmov) begin
		if (reb[exec].ic0 != 64'd0) begin
	  	memreq.tid <= tid;
	  	tid <= tid + 2'd1;
	  	memreq.func <= MR_MOVLD;
	  	case(reb[exec].ir[43:41])
	  	2'd0:	begin memreq.func2 <= MR_STB; end
	  	2'd1:	begin memreq.func2 <= MR_STW; end
	  	2'd2:	begin memreq.func2 <= MR_STT; end
	  	default:	begin memreq.func2 <= MR_STO; end
	  	endcase
	  	memreq.sz <= {1'b0,reb[exec].ir[42:41]};
	  	memreq.adr.offs <= reb[exec].ia + reb[exec].ic0;
	  	memreq.dat <= reb[exec].ib + reb[exec].ic0;
	  	memreq.wr <= TRUE;
	  	goto (WAIT_MEM1);
  	end
  	else
  		reb[exec].dec.stmov <= FALSE;
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tJxx;
integer n;
begin
  if (reb[exec].dec.jxx|reb[exec].dec.jxz) begin
  	mExBranch <= TRUE;
  	if (!takb)
  		md.carfwr <= FALSE;
    if (bpe) begin
      if (reb[exec].predict_taken && !takb && reb[exec].predictable_branch) begin
			for (n = 0; n < 8; n = n + 1)
				if (reb[n].sn > reb[exec].sn)
					reb[n] <= 'd0;
        ip.offs <= xip.offs + xlen;
      end
      else if ((!reb[exec].predict_taken && takb) || !reb[exec].predictable_branch)
      	tBranch(4'd3);
    end
    else if (takb)
    	tBranch(4'd4);
  end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tJmp;
begin
  if (reb[exec].dec.jmp) begin
  	mExBranch <= TRUE;
  	if (reb[exec].dec.dj ? (xa != 64'd0) : (reb[exec].dec.Ca != 3'd0 && reb[exec].dec.Ca != 3'd7))	// ==0,7 was already done at ifetch
  		tBranch(4'd5);
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tBra;
begin
  if (reb[exec].dec.bra) begin
  	mExBranch <= TRUE;
  	if (reb[exec].dec.Ca != 3'd0 && reb[exec].dec.Ca != 3'd7)	// ==0,7 was already done at ifetch
  		tBranch(4'd6);
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tRts;
integer n;
begin
	if (reb[exec].dec.rts) begin
		if (xir.rts.lk != 2'd0) begin
			for (n = 0; n < 8; n = n + 1)
				if (reb[n].sn > reb[exec].sn)
					reb[n] <= 'd0;
  		ip.offs <= reb[exec].ca.offs + {reb[exec].ir.rts.cnst,1'b0};
		end
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute stage
// If the execute stage has been invalidated it doesn't do anything. 
// Must be after INVnRUN state code.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
task tExecute;
integer n;
integer nn;
begin
	// Is there anything to execute?
//	if (reb[exec].state==EMPTY || reb[exec].state==RETIRED || reb[exec].state==EXECUTED)
	exec <= next_exec;
	if (reb[exec].state==DECODED) begin
		if (fnArgsValid(exec)) begin
			reb[exec].state <= OUT;
			reb[exec].w256 <= 1'b0;
			reb[exec].w512 <= 1'b0;
			reb[exec].res <= res;
			reb[exec].carry_res <= carry_res;
			reb[exec].cares <= cares;
			mExBranch <= FALSE;
			if (reb[exec].v) begin
				if (!reb[exec].dec.multi_cycle) begin
					tArgUpdate(exec);
					reb[exec].state <= EXECUTED;
					tBra();
					tJxx();
			    tJmp();
			  	tRts();
				end
				else if (!mc_busy) begin
					mc_busy <= TRUE;
					tArgUpdate(exec);
					tExMem();
				end
			end	// xval
			exec <= next_exec;
		end
	end
	
	for (n = 0; n < 8; n = n + 1)
		if (reb[n].state==EXECUTED)
			tArgUpdate(n);
end
endtask

task tArgUpdate;
input [2:0] m;
integer n;
begin
	for (n = 0; n < 8; n = n + 1) begin
		if (!reb[n].iav) begin
			/*
			if (reb[m].dec.Rt==reb[n].dec.Ra && reb[m].state == 3'd4 && reb[m].v) begin
				reb[n].ia <= reb[m].res;
				reb[n].iav <= 1'b1;
			end
			*/
			//if (reb[head].dec.Rt==reb[n].dec.Ra && reb[head].state==3'd4 && reb[head].v) begin
			if (reb[n].ias==m && reb[m].v && reb[m].state==3'd4) begin
				reb[n].ia <= reb[m].res;
				reb[n].iav <= 1'b1;
			end
			else if (reb[reb[n].ias].v && reb[reb[n].ias].state==3'd4) begin
				reb[n].ia <= reb[reb[n].ias].res;
				reb[n].iav <= 1'b1;
			end
		end
		if (!reb[n].ibv) begin
			/*
			if (reb[m].dec.Rt==reb[n].dec.Rb && reb[m].state == 3'd4 && reb[m].v) begin
				reb[n].ib <= reb[m].res;
				reb[n].ibv <= 1'b1;
			end
			*/
			//if (reb[head].dec.Rt==reb[n].dec.Rb && reb[head].state==3'd4 && reb[head].v) begin
			if (reb[n].ibs==m && reb[m].v && reb[m].state==3'd4) begin
				reb[n].ib <= reb[m].res;
				reb[n].ibv <= 1'b1;
			end
		end
		if (!reb[n].ic0v) begin
			/*
			if (reb[m].dec.Rt==reb[n].dec.Rc && reb[m].state == 3'd4 && reb[m].v) begin
				reb[n].ic0 <= reb[m].res;
				reb[n].ic0v <= 1'b1;
			end
			if (reb[m].dec.Rt==reb[n].dec.Rc && reb[m].state==3'd4 && reb[m].v) begin
			*/
			if (reb[n].ic0s==m && reb[m].v && reb[m].state==3'd4) begin
				reb[n].ic0 <= reb[m].res;
				reb[n].ic0v <= 1'b1;
			end
		end
		if (!reb[n].ic1v) begin
			/*
			if (reb[m].dec.Rt==reb[n].dec.Rc+1 && reb[m].state == 3'd4 && reb[m].v) begin
				reb[n].ic1 <= reb[m].res;
				reb[n].ic1v <= 1'b1;
			end
			if (reb[m].dec.Rt==reb[n].dec.Rc+1 && reb[m].state==3'd4 && reb[m].v) begin
			*/
			if (reb[n].ic1s==m && reb[m].v && reb[m].state==3'd4) begin
				reb[n].ic1 <= reb[m].res;
				reb[n].ic1v <= 1'b1;
			end
		end
		if (!reb[n].ic2v) begin
			/*
			if (reb[m].dec.Rt=={reb[n].dec.Rc[4:2],2'b10} && reb[m].state == 3'd4 && reb[m].v) begin
				reb[n].ic2 <= reb[m].res;
				reb[n].ic2v <= 1'b1;
			end
			if (reb[m].dec.Rt=={reb[n].dec.Rc[4:2],2'b10} && reb[m].state==3'd4 && reb[m].v) begin
			*/
			if (reb[n].ic2s==m && reb[m].v && reb[m].state==3'd4) begin
				reb[n].ic2 <= reb[m].res;
				reb[n].ic2v <= 1'b1;
			end
		end
		if (!reb[n].ic3v) begin
			/*
			if (reb[m].dec.Rt=={reb[n].dec.Rc[4:2],2'b11} && reb[m].state == 3'd4 && reb[m].v) begin
				reb[n].ic3 <= reb[m].res;
				reb[n].ic3v <= 1'b1;
			end
			if (reb[m].dec.Rt=={reb[n].dec.Rc[4:2],2'b11} && reb[m].state==3'd4 && reb[m].v) begin
			*/
			if (reb[n].ic3s==m && reb[m].v && reb[m].state==3'd4) begin
				reb[n].ic3 <= reb[m].res;
				reb[n].ic3v <= 1'b1;
			end
		end
		if (!reb[n].lkv) begin
			/*
			if (reb[m].dec.Ct==reb[n].dec.lk && reb[m].state == 3'd4 && reb[m].v) begin
				reb[n].lk <= reb[m].cares;
				reb[n].lkv <= 1'b1;
			end
			if (reb[m].dec.Ct==reb[n].dec.lk && reb[m].state==3'd4 && reb[m].v) begin
			*/
			if (reb[n].lks==m && reb[m].v && reb[m].state==3'd4) begin
				reb[n].lk <= reb[m].cares;
				reb[n].lkv <= 1'b1;
			end
		end
	end
end
endtask

// Wait for the next instruction to become executed or empty before retiring it.
integer n8;
reg [2:0] next_head;
always_comb
begin
	next_head = head;
	for (n8 = 0; n8 < 8; n8 = n8 + 1)
		if (reb[n8].sn == reb[head].sn + 1)
			next_head = n8;
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Writeback stage
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
task tWriteback;
integer n8;
begin
	/*
	if ((reb[0].state==3'd0 || reb[0].state==3'd7) &&
	(reb[1].state==3'd0 || reb[1].state==3'd7) &&
	(reb[2].state==3'd0 || reb[2].state==3'd7) &&
	(reb[3].state==3'd0 || reb[3].state==3'd7) &&
	(reb[4].state==3'd0 || reb[4].state==3'd7) &&
	(reb[5].state==3'd0 || reb[5].state==3'd7) &&
	(reb[6].state==3'd0 || reb[6].state==3'd7) &&
	(reb[7].state==3'd0 || reb[7].state==3'd7)) begin
		head <= (tail - 2'd1) & 3'd7;
	end
	*/
//	if (reb[head].state==EMPTY || reb[head].state==RETIRED)// && ((head + 2'd1) & 3'd7) != tail)
//		head <= head + 2'd1;
  if (reb[head].state==EXECUTED) begin
		head <= next_head;
		if (reb[head].v) begin
			tArgUpdate(head);
			if (reb[head].dec.sei)
				pmStack[3:1] <= reb[head].ia[2:0]|reb[head].ir[24:22];
			if (reb[head].cio[0])
				preg[reb[head].cioreg] <= reb[head].carry_res;
			if (|reb[head].cause) begin
				if ((reb[head].cause & 8'hff)==FLT_CPF)
					clr_ipage_fault <= 1'b1;
				if ((reb[head].cause & 8'hff)==FLT_TLBMISS)
					clr_itlbmiss <= 1'b1;
		  	if (reb[head].cause[15])
					// IRQ level remains the same unless external IRQ present
					pmStack <= {pmStack[55:0],2'b0,2'b11,reb[head].cause[10:8],1'b0};
				else
					pmStack <= {pmStack[55:0],2'b0,2'b11,pmStack[3:1],1'b0};
				plStack <= {plStack[55:0],8'hFF};
				cause[2'd3] <= reb[head].cause & 16'h80FF;
				badaddr[2'd3] <= reb[head].badAddr;
				caregfile[4'd8+reb[head].istk_depth] <= reb[head].ip;
	    	ca_src[4'd8+reb[head].istk_depth] <= 5'd31;
				ip.offs <= tvec[3'd3] + {omode,6'h00};
				for (n8 = 0; n8 < 8; n8 = n8 + 1)
					if (reb[n8].sn > reb[head].sn)
						reb[n8] <= 'd0;
			end
			else begin
		  	if (reb[head].dec.carfwr) begin
		    	caregfile[reb[head].dec.Ct] <= reb[head].cares;
		    	ca_src[reb[head].dec.Ct] <= 5'd31;
		    end
				if (reb[head].dec.rti) begin
					if (|istk_depth) begin
						pmStack <= {8'h3E,pmStack[63:8]};
						plStack <= {8'hFF,plStack[63:8]};
						ip.offs <= reb[head].ca.offs;	// 8-1
						ip.micro_ip <= reb[head].ca.micro_ip;
						istk_depth <= istk_depth - 2'd1;
						for (n8 = 0; n8 < 8; n8 = n8 + 1)
							if (reb[n8].sn > reb[head].sn)
								reb[n8] <= 'd0;
					end
				end
		    else if (reb[head].dec.csr)
		      case(reb[head].ir.csr.op)
		      3'd1:   tWriteCSR(reb[head].ia,wir.csr.regno);
		      3'd2:   tSetbitCSR(reb[head].ia,wir.csr.regno);
		      3'd3:   tClrbitCSR(reb[head].ia,wir.csr.regno);
		      default:	;
		      endcase
				else if (reb[head].dec.rex) begin
					if (omode <= reb[head].ir[10:9]) begin
						pmStack <= {pmStack[55:0],2'b0,2'b11,pmStack[3:1],1'b0};
						plStack <= {plStack[55:0],8'hFF};
						cause[2'd3] <= FLT_PRIV;
						caregfile[reb[head].dec.Ct] <= reb[head].ip;
						ip.offs <= tvec[3'd3] + {omode,6'h00};
						for (n8 = 0; n8 < 8; n8 = n8 + 1)
							if (reb[n8].sn > reb[head].sn)
								reb[n8] <= 'd0;
					end
					else begin
						pmStack[2:1] <= reb[head].ir[10:9];	// omode
					end
				end
				// Register file update
			  if (reb[head].dec.rfwr) begin
			  	if (reb[head].dec.Rtvec) begin
			  		if (reb[head].mask_bit)
			  			vregfile[reb[head].dec.Rt][reb[head].step] <= reb[head].res;
			  		else if (reb[head].zbit)
			  			vregfile[reb[head].dec.Rt][reb[head].step] <= 64'd0;
			  	end
			  	else begin
			  		/*
				    case(wd.Rt)
				    6'd63:  sp[{omode,ilvl}] <= {wres[63:3],3'h0};
				    endcase
				    */
				    if (reb[head].w512) begin
				    	regfile[reb[head].dec.Rt[4:2]] <= reb[head].res;
				    	regfile_src[reb[head].dec.Rt+2'd0] <= 5'd31;
				    	regfile_src[reb[head].dec.Rt+2'd1] <= 5'd31;
				    	regfile_src[reb[head].dec.Rt+2'd2] <= 5'd31;
				    	regfile_src[reb[head].dec.Rt+2'd3] <= 5'd31;
				    end
				    else if (reb[head].w256) begin
				    	if (reb[head].dec.Rt!=5'd0) begin
					    	case(reb[head].dec.Rt[1])
					    	1'd0:	regfile[reb[head].dec.Rt[4:2]][255:  0] <= reb[head].res[255:0];
					    	1'd1:	regfile[reb[head].dec.Rt[4:2]][511:256] <= reb[head].res[255:0];
					    	endcase
					    	regfile_src[reb[head].dec.Rt+2'd0] <= 5'd31;
					    	regfile_src[reb[head].dec.Rt+2'd1] <= 5'd31;
					    end
				    end
				    else begin
					    case(reb[head].dec.Rt[1:0])
					    2'd0:	regfile[reb[head].dec.Rt[4:2]][127:  0] <= reb[head].res[127:0];
					    2'd1:	regfile[reb[head].dec.Rt[4:2]][255:128] <= reb[head].res[127:0];
					    2'd2:	regfile[reb[head].dec.Rt[4:2]][383:256] <= reb[head].res[127:0];
					    2'd3:	regfile[reb[head].dec.Rt[4:2]][511:384] <= reb[head].res[127:0];
					  	endcase
				    	regfile_src[reb[head].dec.Rt] <= 5'd31;
					  end
				    $display("regfile[%d] <= %h", reb[head].dec.Rt, reb[head].res);
				    // Globally enable interrupts after first update of stack pointer.
				    if (reb[head].dec.Rt==5'd31) begin
				    	sp <= reb[head].res[127:0];	// debug
				      gie <= TRUE;
				    end
				    if (reb[head].dec.Rt==5'd26)
				    	r58 <= reb[head].res[127:0];
				    if (reb[head].dec.Rt==5'd11)
				    	t0 <= reb[head].res[127:0];
				  end
			  end
			  if (reb[head].dec.vmrfwr)
			  	vm_regfile[reb[head].dec.Rt[2:0]] <= reb[head].res[127:0];
			end	// wcause
		end		// wval
		// Retire prefixes once the instruction is retired.
		for (n8 = 0; n8 < 8; n8 = n8 + 1) begin
			if (reb[n8].dec.isExi && reb[n8].sn==reb[head].sn-1)
				reb[n8].state <= RETIRED;
			if (reb[n8].sn==reb[head].sn-2 && reb[n8].ir.any.opcode==EXIM)
				reb[n8].state <= RETIRED;
		end
		reb[head].state <= RETIRED;
  end			// advance_w
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

integer n9;
task tBranch;
input [3:0] yy;
integer n;
begin
	for (n = 0; n < 8; n = n + 1) begin
  	if (|reb_latestID[n])
  		regfile_src[reb[n].dec.Rt] <= n;
  	if (|reb_latestID2[n])
  		ca_src[reb[n].dec.Ct] <= n;
  	if (~livetarget[n])
  		regfile_src[reb[n].dec.Rt] <= 5'd31;
  	if (~livetarget2[n])
  		ca_src[reb[n].dec.Ct] <= 5'd31;
  end
	for (n9 = 0; n9 < 8; n9 = n9 + 1)
		if (reb[n9].sn > reb[exec].sn)
			reb[n9] <= 'd0;
  if (reb[exec].dec.Ca == 4'd0) begin
  	ip.offs <= reb[exec].dec.jmptgt;
  	mJmptgt.offs <= reb[exec].dec.jmptgt;
  end
  else if (reb[exec].dec.Ca == 4'd7) begin
  	ip.offs <= reb[exec].ip.offs + reb[exec].dec.jmptgt;
  	mJmptgt.offs <= reb[exec].ip.offs + reb[exec].dec.jmptgt;
  end
  else begin
		ip.offs <= reb[exec].ca.offs + reb[exec].dec.jmptgt;
  	mJmptgt.offs <= reb[exec].ca.offs + reb[exec].dec.jmptgt;
  end
end
endtask

integer n10;
task tWait;
begin
	if (first_flag || !done_flag) begin
		first_flag <= 1'b0;
		for (n10 = 0; n10 < 8; n10 = n10 + 1)
			if (reb[n10].sn > reb[exec].sn)
				reb[n10] <= 'd0;
  	ip.offs <= reb[exec].ip.offs;
  	mJmptgt.offs <= reb[exec].ip.offs;
	end
	else
		first_flag <= 1'b1;
end
endtask

task ex_fault;
input [15:0] c;
begin
	if (xcause==16'h0)
		reb[exec].cause <= c;
	mc_busy <= FALSE;
	goto (RUN);
end
endtask

// Important to use the correct assignment type for the following, otherwise
// The read won't happen until the clock cycle.
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
				caregfile[wd.Ct].offs <= val;
		CSR_MCA,CSR_SCA,CSR_HCA:
			caregfile[wd.Ct].offs <= val;
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


task disassem;
input Instruction ir;
begin
  case(ir.any.opcode)
  ADDI:   
  	if (ir.ri.Ra==6'd0)
      $display("LDI r%d,%d", ir.ri.Rt, ir.ri.imm);
  	else
  		$display("ADD r%d,r%d,%d", ir.ri.Rt, ir.ri.Ra, ir.ri.imm);
  ADDIL:   
  	if (ir.ri.Ra==6'd0)
      $display("LDI r%d,%d", ir.ril.Rt, ir.ril.imm);
  	else
  		$display("ADD r%d,r%d,%d", ir.ril.Rt, ir.ril.Ra, ir.ril.imm);
  ORI:		$display("OR r%d,r%d,%d", ir.ri.Rt, ir.ri.Ra, ir.ri.imm);
  ORIL:		$display("OR r%d,r%d,%d", ir.ril.Rt, ir.ril.Ra, ir.ril.imm);
  LDT:		$display("LDT r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.ld.Ra);
  LDTU:		$display("LDTU r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.ld.Ra);
  LDO:		$display("LDO r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.ld.Ra);
  STT:		$display("STT r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.st.Ra);
  STO:		$display("STO r%d,%d[r%d]", ir.st.Rs, ir.st.disp, ir.st.Ra);
  RTS:   	$display("RTS #%d", ir.rts.cnst);
  endcase
end
endtask


endmodule
