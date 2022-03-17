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

module Thor2022io(hartid_i, rst_i, clk_i, clk2x_i, clk2d_i, wc_clk_i, clock,
		irq_i, icause_i,
		vpa_o, vda_o, bte_o, cti_o, bok_i, cyc_o, stb_o, lock_o, ack_i,
    err_i, we_o, sel_o, adr_o, dat_i, dat_o, cr_o, sr_o, rb_i, state_o, trigger_o);
input [63:0] hartid_i;
input rst_i;
input clk_i;
input clk2x_i;
input clk2d_i;
input wc_clk_i;
input clock;					// MMU clock algorithm
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

reg [5:0] rst_cnt;
wire [1:0] omode;
wire [1:0] memmode;
wire UserMode, SupervisorMode, HypervisorMode, MachineMode;
wire MUserMode;
reg gie;
reg [511:0] regfile [0:31];
Value r58;
reg [127:0] preg [0:7];
reg [15:0] cio;
reg [7:0] delay_cnt;
Value sp, t0;
Address caregfile [0:15];
(* ram_style="block" *)
Value vregfile [0:31][0:63];
reg [63:0] vm_regfile [0:7];

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

// Instruction fetch stage vars
reg ival;
reg [15:0] icause;
Instruction insn;
Instruction micro_ir,micro_ir1;
reg advance_i;
Address ip;
reg [6:0] micro_ip;
wire ipredict_taken;
wire ihit;
wire [pL1ICacheLineSize-1:0] ic_line;
wire [3:0] ilen;
wire btb_hit;
Address btb_tgt;
Address next_ip;
wire run;
reg [2:0] pfx_cnt;		// prefix counter
reg [7:0] istep;


// Decode stage vars
reg dval;
reg [15:0] dcause;
Instruction ir;
Address dip;
reg [2:0] cioreg;
reg dpfx;
reg advance_d;
reg [3:0] dlen;
DecodeOut deco;
reg dpredict_taken;
reg [4:0] Ra;
reg [4:0] Rb;
reg [4:0] Rc;
reg [4:0] Rc1;
reg [4:0] Rt, wRt;
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
Value rfoa, rfob, rfoc0, rfoc1, rfop;
Address rfoca;
reg [63:0] mask;
reg [7:0] wstep;

vreg_blkmem uvr1 (
  .clka(clk_g),    // input wire clka
  .ena(advance_w),      // input wire ena
  .wea(wrvrf),      // input wire [0 : 0] wea
  .addra({wRt,wstep}),  // input wire [11 : 0] addra
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
  .addra({wRt,wstep}),  // input wire [11 : 0] addra
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
  .addra({wRt,wstep}),  // input wire [11 : 0] addra
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
Address xip;
reg [3:0] xlen;
reg advance_x;
reg [4:0] xRt,xRa,xRb,xRc,tRt;
reg [3:0] xCt;
reg [2:0] xistk_depth;
reg [2:0] xcioreg;
reg [1:0] xcio;
reg xRtvec;
reg [2:0] xCat;
Value xa,xb,xc0,xc1,pn;
Value imm;
Address xca;
Address xcares;
reg xmaskbit;
reg xzbit;
reg [2:0] xSc;
wire takb;
reg xpredict_taken;
reg xJmp;
reg [127:0] xJmptgt;
reg xJxx, xJxz;
reg xPredictableBranch;
reg xdj;
reg xmjnez;
reg xRts, xRti;
reg xRex;
reg xFlowchg;
reg xIsMultiCycle;
reg xLdz;
reg xLear,xLean;
reg xMem, xLoad, xLdoo;
reg xrfwr;
reg xcarfwr;
reg xvmrfwr;
reg xMul,xMuli;
reg xMulu,xMului;
reg xMulsu,xMulsui;
reg xIsMul,xIsDiv;
reg xMulf,xMulfi;
reg xDiv,xDivsu;
reg xDivi;
reg xLoadr, xLoadn;
reg xStorer, xStoren;
reg xStoo;
reg [2:0] xSeg;
reg [2:0] xMemsz;
reg xTlb, xRgn;
reg xBset, xStmov, xStfnd, xStcmp;
reg xCsr,xSync;
reg xMtlk;
reg xMfsel,xMtsel;
MemoryRequest memreq;
MemoryResponse memresp;
reg memresp_fifo_rd;
wire memresp_fifo_empty;
wire memresp_fifo_v;
reg [7:0] tid;
reg [128:0] res,res2;
Value crypto_res, carry_res;
Address cares;
reg ld_vtmp;
reg [7:0] xstep;
reg [2:0] xrm,xdfrm;
reg xIsDF;

// Memory
reg mval;
Instruction mir;
Address mip;
reg advance_m;
reg [15:0] mcause;
Address mbadAddr;
Address mca;
Address mcares;
reg mrfwr, m512, m256;
reg mcarfwr;
reg mvmrfwr;
reg [4:0] mRt;
reg [3:0] mCt;
reg [2:0] mistk_depth;
reg [2:0] mcioreg;
reg [1:0] mcio;
reg mStset,mStmov,mStfnd,mStcmp;
reg mRtvec;
reg mCsr,mSync;
reg mJxx, mJxz, mJmp;
reg mRti;
reg mRex;
reg mRts;
reg mFlowchg;
reg mLoad;
Value ma;
Value mres, mcarry_res;
reg [511:0] mres512;
reg [7:0] mstep;
reg mzbit;
reg mmaskbit;
Address mJmptgt;
reg mtakb;
reg mExBranch;

// Writeback stage vars
reg wval;
Instruction wir;
Address wip;
reg [15:0] wcause;
Address wbadAddr;
Address wlk;
Address wca;
Address wcares;
reg wrfwr, w512, w256;
reg wvmrfwr;
reg wcarfwr;
reg [3:0] wCt;
reg [2:0] wistk_depth;
reg [2:0] wcioreg;
reg [1:0] wcio;
reg wStset,wStmov,wStfnd,wStcmp;
reg wRtvec;
reg wCsr,wSync;
reg wJxx, wJxz, wJmp;
reg wRts;
reg wRti;
reg wRex;
reg wFlowchg;
reg wLoad;
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
Value scratch [0:3];
Address ptbr;
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
reg [7:0] asid;
Value gdt;
Selector ldt;
Selector keytbl;
Selector tcbptr;
reg [63:0] keys2 [0:3];
reg [19:0] keys [0:7];
always_comb
begin
	keys[0] = keys2[0][19:0];
	keys[1] = keys2[0][39:20];
	keys[2] = keys2[0][59:40];
	keys[3] = keys2[1][19:0];
	keys[4] = keys2[1][39:20];
	keys[5] = keys2[1][59:40];
	keys[6] = keys2[2][19:0];
	keys[7] = keys2[2][39:20];
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

Thor2022_decoder udec (
	.ir(ir),
	.xir(xir),
	.xval(xval),
	.mir(mir),
	.mval(mval),
	.deco(deco),
	.distk_depth(distk_depth),
	.rm(rm),
	.dfrm(dfrm)
);

`ifdef OVERLAPPED_PIPELINE
always_comb
if (Ra==6'd0)
  rfoa = {VALUE_SIZE{1'b0}};
else if (deco.Ravec)
	rfoa = vroa;
else if (Ra==xRt && xrfwr && xval)
  rfoa = res;
else if (Ra==mRt && mrfwr && mval)
	rfoa = mres;
else if (Ra==wRt && wrfwr && wval)
	rfoa = wres;
else
	rfoa = regfile[Ra[4:2]] >> {Ra[1:0],7'd0};
/*
  case(Ra)
  6'd63:  rfoa = sp [{omode,ilvl}];
  default:    rfoa = regfile[Ra];
  endcase
*/
always_comb
if (Tb[1])
	rfob = {{58{Tb[0]}},Tb[0],Rb};
else if (Rb=='d0)
	rfob = {VALUE_SIZE{1'b0}};
else if (deco.Rbvec)
	rfob = vrob;
else if (Rb==xRt && xrfwr && xval)
  rfob = res;
else if (Rb==mRt && mrfwr && mval)
	rfob = mres;
else if (Rb==wRt && wrfwr && wval)
	rfob = wres;
else
	rfob = regfile[Rb[4:2]] >> {Rb[1:0],7'd0};
/*	
  case(Rb)
  6'd63:  rfob = sp [{omode,ilvl}];
  default:    rfob = regfile[Rb];
  endcase
*/
always_comb
if (Tc[1])
	rfoc0 = {{58{Tc[0]}},Tc[0],Rc};
else if (Rc=='d0)
	rfoc0 = {VALUE_SIZE{1'b0}};
else if (deco.Rcvec)
	rfoc0 = vroc;
else if (Rc==xRt && xrfwr && xval)
  rfoc0 = res;
else if (Rc==mRt && mrfwr && mval)
	rfoc0 = mres;
else if (Rc==wRt && wrfwr && wval)
	rfoc0 = wres;
else
	rfoc0 = regfile[Rc[4:2]] >> {Rc[1:0],7'd0};

always_comb
	Rc1 = Rc + 2'd1;
always_comb
if (Rc1==xRt && xrfwr && xval)
  rfoc1 = res;
else if (Rc1==mRt && mrfwr && mval)
	rfoc1 = mres;
else if (Rc1==wRt && wrfwr && wval)
	rfoc1 = wres;
else
	rfoc1 = regfile[Rc1[4:2]] >> {Rc1[1:0],7'd0};
/*
  case(Rc)
  6'd63:  rfoc = sp [{omode,ilvl}];
  default:    rfoc = regfile[Rc];
  endcase
*/

always_comb
	if (cioreg==3'd0 || ~cio[1])
		rfop = 'd0;
	else if (xval && xcioreg==cioreg && xcio[0])
		rfop = carry_res;
	else if (mval && mcioreg==cioreg && mcio[0])
		rfop = mcarry_res;
	else if (wval && wcioreg==cioreg && wcio[0])
		rfop = wcarry_res;
	else
		rfop = preg[cioreg];

always_comb
	if (Ca == xCt && xcarfwr && xval)
		rfoca = xcares;
	else if (Ca == mCt && mcarfwr && mval)
		rfoca = mcares;
	else if (Ca == wCt && wcarfwr && wval)
		rfoca = wcares;
	else
		rfoca = caregfile[Ca];

`else
always_comb
if (Ra=='d0)
  rfoa = {VALUE_SIZE{1'b0}};
else if (deco.Ravec)
	rfoa = vroa;
else
	rfoa = regfile[Ra[4:2]] >> {Ra[1:0],7'd0};
/*
  case(Ra)
  6'd63:  rfoa = sp [{omode,ilvl}];
  default:    rfoa = regfile[Ra];
  endcase
*/
always_comb
if (Tb[1])
	rfob = {{58{Tb[0]}},Tb[0],Rb};
else if (Rb=='d0)
	rfob = {VALUE_SIZE{1'b0}};
else if (deco.Rbvec)
	rfob = vrob;
else
	rfob = regfile[Rb[4:2]] >> {Rb[1:0],7'd0};
/*	
  case(Rb)
  6'd63:  rfob = sp [{omode,ilvl}];
  default:    rfob = regfile[Rb];
  endcase
*/
always_comb
if (Tc[1])
	rfoc0 = {{58{Tc[0]}},Tc[0],Rc};
else if (Rc=='d0)
	rfoc0 = {VALUE_SIZE{1'b0}};
else if (deco.Rcvec)
	rfoc0 = vroc;
else
	rfoc0 = regfile[Rc[4:2]] >> {Rc[1:0],7'd0};

reg [5:0] Rc1;
always_comb
	Rc1 = Rc + 2'd1;
always_comb
	rfoc1 = regfile[Rc1[4:2]] >> {Rc1[1:0],7'd0};
/*
  case(Rc)
  6'd63:  rfoc = sp [{omode,ilvl}];
  default:    rfoc = regfile[Rc];
  endcase
*/

always_comb
	if (cioreg==3'd0 || ~cio[1])
		rfop = 64'd0;
	else
		rfop = preg[cioreg];

always_comb
	rfoca = caregfile[Ca];

`endif

always_comb
	mask = vm_regfile[deco.Rvm];

always_comb
	zbit = deco.Rz;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute stage combinational logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

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

wire [7:0] cntlz_out;
cntlz128 uclz(xir.r1.func[0] ? ~xa : xa, cntlz_out);

//wire [255:0] sllrho = {128'd0,xa[127:0]|pn[127:0]} << {xb[4:0],4'h0};
//wire [255:0] srlrho = {pn[127:0]|xa[127:0],128'd0} >> {xb[4:0],4'h0};
//wire [255:0] sraho = {{128{xa[127]}},xa[127:0],128'd0} >> {xb[4:0],4'h0};
wire [255:0] sllro = {128'd0,xa[127:0]|pn[127:0]} << xb[6:0];
wire [255:0] srlro = {pn[127:0]|xa[127:0],128'd0} >> xb[6:0];
wire [255:0] srao = {{128{xa[127]}},xa[127:0],128'd0} >> xb[6:0];

wire [255:0] mul_prod1;
reg [255:0] mul_prod;
wire [255:0] mul_prod2561;
reg [255:0] mul_prod256;
reg [39:0] mulf_prod;
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
wire multovf = ((xMulu|xMului) ? mul_prod256[255:128] != 'd0 : mul_prod256[255:128] != {128{mul_prod256[127]}});
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
  .ss(xDiv),
  .su(xDivsu),
  .isDivi(xDivi),
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
	.a(xa[63:0]),
	.b(xb[63:0]),
	.c(xc0[63:0]),
	.o(bf_out)
);

Thor2022_crypto ucrypto
(
	.ir(xir),
	.m(xm),
	.z(xz),
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
	SLL:	res2 = sllro[127:0] + xc0;
	SRL:	res2 = srlro[255:128];
	SRA:	res2 = srao[255:128];
	ROL:	res2 = sllro[127:0]|sllro[255:128];
	ROR:	res2 = srlro[255:128]|srlro[127:0];
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
AND2R:				res2 = xa & xb;
OR2R:					res2 = xa | xb | pn;
XOR2R:				res2 = xa ^ xb ^ pn;
SLT2R:				res2 = $signed(xa) < $signed(xb);
LEAX:					res2 = xa + (xb << xSc);
ADDI,ADDIL,LEA:		res2 = xa + imm + pn;
SUBFI,SUBFIL:	res2 = imm - xa - pn;
ANDI,ANDIL:		res2 = xa & imm;
ORI,ORIL:			res2 = xa | imm | pn;
XORI,XORIL:		res2 = xa ^ imm ^ pn;
SLLR2:				res2 = xa << xb[5:0];
//SLLHR2:				res2 = sllrho[127:0];// + xc0;
CMPI,CMPIL:		res2 = cmpio;//$signed(xa) < $signed(imm) ? -128'd1 : xa==imm ? 'd0 : 128'd1;
//CMPUI,CMPUIL:	res2 = xa < imm ? -128'd1 : xa==imm ? 'd0 : 128'd1;
MULI,MULIL:		res2 = mul_prod256[127:0] + pn;
MULUI:MULUIL:	res2 = mul_prod256[127:0] + pn;
MULFI:				res2 = mul_prod256[127:0] + pn;
DIVI,DIVIL:		res2 = qo;
SEQI,SEQIL:		res2 = xa == imm;
SNEI,SNEIL:		res2 = xa != imm;
SLTI,SLTIL:		res2 = $signed(xa) < $signed(imm);
SGTI,SGTIL:		res2 = $signed(xa) > $signed(imm);
SLTUI,SLTUIL:	res2 = xa < imm;
SGTUI,SGTUIL:	res2 = xa > imm;
DJMP:					res2 = xa - 2'd1;
//STSET:				res2 = xc0 - 2'd1;
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOR,LDHS,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX:
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
R2:
	case(xir.r3.func)
	ADD:			carry_res = res2[128];
	SUB:			carry_res = res2[128];
	MUL:			carry_res = mul_prod[255:128];
	MULU:			carry_res = mul_prod[255:128];
	MULSU:		carry_res = mul_prod[255:128];
	SLL:			carry_res = sllro[255:128];
	SRL:			carry_res = srlro[127:0];
	SRA:			carry_res = srao[127:0];
	default:	carry_res = 128'd0;
	endcase
// (a&b)|(a&~s)|(b&~s)
ADD2R:	carry_res = res2[128];
default:	carry_res = 128'd0;
endcase

Thor2022_inslength uil(insn, ilen);

always_comb
begin
 	next_ip.offs = ip.offs + ilen;
end

Thor2022_BTB_x1 ubtb
(
	.rst(rst_i),
	.clk(clk_g),
	.wr(wExbranch & wval),
	.wip(wip),
	.wtgt(wJmptgt),
	.takb(wtakb),
	.rclk(~clk_g),
	.ip(ip),
	.tgt(btb_tgt),
	.hit(btb_hit),
	.nip(next_ip)
);

Thor2022_gselectPredictor ubp
(
	.rst(rst_i),
	.clk(clk_g),
	.en(bpe),
	.xisBranch(xJxx),
	.xip(xip),
	.takb(takb),
	.ip(ip),
	.predict_taken(ipredict_taken)
);

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
	.ip(ip),
	.ihit(ihit),
	.ifStall(!run),
	.ic_line(ic_line),
	.fifoToCtrl_i(memreq),
	.fifoToCtrl_full_o(),
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
	.ptbr(ptbr)
);

always_comb
begin
	insn = ic_line >> {ip.offs[5:1],4'd0};
end

Address siea;
always_comb
	siea = xa + xb;

assign wrvrf = wrfwr && wRtvec && (wmaskbit||wzbit);
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

`ifdef OVERLAPPED_PIPELINE
wire stall_i = !ihit;
wire stall_d = ((deco.storer|deco.storen|deco.stset|deco.stcmp|deco.stfnd|deco.stmov|deco.enter) &&
								(((|xcause || xFlowchg || xLoad) && xval) ||
								 ((|mcause || mFlowchg) && mval) ||
								 ((|wcause || wFlowchg) && wval))) ||
								 ((xIsMul||xIsDiv) && xval) ||
								(xLoad && (Ra==xRt || {Tb,Rb}=={2'b00,xRt} || {Tc,Rc}=={2'b00,xRt} || Rc1==xRt) && xval && xRt!=6'd0) ||
//								(mLoad && (Ra==mRt || {Tb,Rb}=={2'b00,mRt} || {Tc,Rc}=={2'b00,mRt} || Rc1==mRt) && mval && mRt!=6'd0) ||
//								(wLoad && (Ra==wRt || {Tb,Rb}=={2'b00,wRt} || {Tc,Rc}=={2'b00,wRt} || Rc1==wRt) && wval && wRt!=6'd0) ||
								(xSync && xval) || (mSync && mval) || (wSync && wval) || tSync || uSync || vSync;

assign run = ihit;
always_comb advance_t = !stall_i && (state==RUN);
always_comb	advance_w = advance_t;
always_comb advance_m = advance_w;
always_comb advance_x = advance_m;
always_comb advance_d = advance_x && !stall_d;
always_comb advance_i = advance_d;
`else
assign run = ihit;
always_comb advance_t = TRUE;
always_comb	advance_w = TRUE;
always_comb advance_m = TRUE;
always_comb advance_x = TRUE;
always_comb advance_d = TRUE;
always_comb advance_i = ihit;
`endif

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
`ifdef OVERLAPPED_PIPELINE
	tInsnFetch();
	tDecode();
	tExecute();
	tMemory();
	tWriteback();
	tSyncTrailer();
`endif
	tStateMachine();

end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Support tasks
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task inv_i;
begin
	micro_ip <= 6'd0;
//  ival <= INV;
  icause <= 16'h0;
end
endtask

task inv_d;
begin
  dval <= INV;
  dcause <= 16'h0;
	ir <= {7'd0,1'b0,NOP};
end
endtask

task inv_x;
begin
  xval <= INV;
 	xcause <= 16'h0;
end
endtask

task inv_m;
begin
  mval <= INV;
  mcause <= 16'h0;
end
endtask

task inv_w;
begin
  wval <= INV;
  wcause <= 16'h0;
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

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
	xrfwr <= FALSE;
	xIsMultiCycle <= FALSE;
	xMem <= FALSE;
	xLoad <= FALSE;
	xStoo <= FALSE;
	xSeg <= 3'd0;
	xSc <= 3'd0;
	xBset <= FALSE;
	xStcmp <= FALSE;
	xStmov <= FALSE;
	xStfnd <= FALSE;
	xJxx <= FALSE;
	xJmp <= FALSE;
	xJxz <= FALSE;
	xdj <= FALSE;
	xPredictableBranch <= FALSE;
	xRt <= 6'd0;
	xCt <= 4'h0;
	xRti <= FALSE;
	mRti <= FALSE;
	xRex <= FALSE;
	mRex <= FALSE;
	tid <= 8'h00;
	memreq.tid <= 8'h00;
	memreq.step <= 6'd0;
	memreq.wr <= 1'b0;
	memreq.func <= 4'd0;
	memreq.func2 <= 3'd0;
	memreq.adr <= 64'h0;
	memreq.seg <= 5'd0;
	memreq.dat <= 128'd0;
	memreq.sel <= 16'h0;
	dpfx <= FALSE;
	pfx_cnt <= 3'd0;
//	cr0 <= 64'h300000001;
	cr0 <= 64'h200000001;
	rst_cnt <= 6'd0;
	xCsr <= 1'b0;
	mCsr <= 1'b0;
	wCsr <= 1'b0;
	wSync <= 1'b0;
	mSync <= 1'b0;
	xSync <= 1'b0;
	tSync <= 1'b0;
	uSync <= 1'b0;
	vSync <= 1'b0;
	wLoad <= FALSE;
	memresp_fifo_rd <= FALSE;
	gdt <= 64'hFFFFFFFFFFFFFFC0;	// startup table (bit 75 to 12)
	ip.offs <= 32'hFFFD0000;
	gie <= FALSE;
	pmStack <= 64'h3e3e3e3e3e3e3e3e;	// Machine mode, irq level 7, ints disabled
	plStack <= 64'hffffffffffffffff;	// PL = 255
	asid <= 8'h00;
	istk_depth <= 4'd1;
	icause <= 16'h0000;
	dcause <= 16'h0000;
	xcause <= 16'h0000;
	mcause <= 16'h0000;
	wcause <= 16'h0000;
	wLoad <= FALSE;
	mExBranch <= FALSE;
	wExBranch <= FALSE;
	xMtlk <= FALSE;
	micro_ip <= 6'd0;
	m512 <= FALSE;
	m256 <= FALSE;
	w512 <= FALSE;
	w256 <= FALSE;
	cio <= 16'h0000;
	xcio <= 2'd0;
	mcio <= 2'd0;
	wcio <= 2'd0;
	mJmp <= FALSE;
	wJmp <= FALSE;
	mJxx <= FALSE;
	mJxz <= FALSE;
	wJxx <= FALSE;
	wJxz <= FALSE;
	mRts <= FALSE;
	wRts <= FALSE;
	xFlowchg <= FALSE;
	mFlowchg <= FALSE;
	wFlowchg <= FALSE;
	rm <= 'd0;
	dfrm <= 'd0;
	xIsDF <= 1'b0;
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
`ifdef OVERLAPPED_PIPELINE
		goto(RUN);
`else
		goto (IFETCH);
`endif
	end
`ifndef OVERLAPPED_PIPELINE
IFETCH:	tInsnFetch();
DECODE: tDecode();
EXECUTE:	tExecute();
MEMORY:	tMemory();
WRITEBACK:	tWriteback();
SYNC:	tSyncTrailer();
`endif
RUN:
	begin
	end	// RUN

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Wait for a response from the BIU.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
WAIT_MEM1:
	begin
		if (!memresp_fifo_empty) begin
			memresp_fifo_rd <= TRUE;
			goto (WAIT_MEM2);
		end
	end
WAIT_MEM2:
	begin
		if (memresp_fifo_v) begin
			memresp_fifo_rd <= FALSE;
			mLoad <= FALSE;
			mres <= memresp.res;
			mres512 <= memresp.res;
			if (mStset|mStmov)
				mrfwr <= TRUE;
			m512 <= FALSE;
			m256 <= FALSE;
			if (memresp.tid == memreq.tid) begin
				if (memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==MR_MFSEL) begin
					mrfwr <= FALSE;
					if (memreq.func2!=MR_LDDESC) begin
						mrfwr <= TRUE;
					end
					if (memreq.func2==MR_LDOO)
						m512 <= TRUE;
				end
				else if (memreq.func==MR_TLB) begin
					m256 <= TRUE;
				end
				else if (memreq.func==MR_RGN)
					mrfwr <= TRUE;
				if (|memresp.cause) begin
					if (~|mcause)
						mistk_depth <= mistk_depth + 2'd1;
					wcause <= memresp.cause;
					wbadAddr <= memresp.badAddr;
				end
				goto (INVnRUN);
			end
		end
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Invalidate the xir and switch back to the run state.
// The xir is invalidated to prevent the instruction from executing again.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
INVnRUN:
  begin
`ifdef OVERLAPPED_PIPELINE
    goto(RUN);
`else
		goto(IFETCH);
`endif
  end
INVnRUN2:
  begin
    //inv_x();
		xx <= 4'd7;
`ifdef OVERLAPPED_PIPELINE
    goto(RUN);
`else
		goto(IFETCH);
`endif
  end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Step1: setup operands and capture sign
MUL1:
  begin
    if (xMul) mul_sign <= xa[$bits(Value)-1] ^ xb[$bits(Value)-1];
    else if (xMuli) mul_sign <= xa[$bits(Value)-1] ^ imm[$bits(Value)-1];
    else if (xMulsu) mul_sign <= xa[$bits(Value)-1];
    else if (xMulsui) mul_sign <= xa[$bits(Value)-1];
    else mul_sign <= 1'b0;  // MULU, MULUI
    if (xMul) aa <= fnAbs(xa);
    else if (xMuli) aa <= fnAbs(xa);
    else if (xMulsu) aa <= fnAbs(xa);
    else if (xMulsui) aa <= fnAbs(xa);
    else aa <= xa;
    if (xMul) bb <= fnAbs(xb);
    else if (xMuli) bb <= fnAbs(imm);
    else if (xMulsu) bb <= xb;
    else if (xMulsui) bb <= imm;
    else if (xMulu|xMulf) bb <= xb;
    else bb <= imm; // MULUI
    delay_cnt <= (xMulf|xMulfi) ? 8'd3 : 8'd18;	// Multiplier has 18 stages
	// Now wait for the six stage pipeline to finish
    goto (MUL2);
  end
MUL2:
  call(DELAYN,MUL9);
MUL9:
  begin
//    mul_prod <= (xMulf|xMulfi) ? mulf_prod : mul_sign ? -mul_prod1 : mul_prod1;
    mul_prod256 <= (xMulf|xMulfi) ? mulf_prod : mul_sign ? -mul_prod2561 : mul_prod2561;
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
begin
	if (advance_i) begin
`ifndef OVERLAPPED_PIPELINE
		goto (DECODE);
`endif
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
			7'd1:		begin micro_ip <= 7'd2; ir <= {29'h00,5'd31,micro_ir[13:9],1'b0,LDH}; dlen <= 4'd2; end	// LDOS $Ra,[$SP]
			7'd2:		begin micro_ip <= 7'd0; ir <= {13'h010,5'd31,5'd31,1'b0,ADDI}; ip.offs <= ip.offs + 4'd2; end							// ADD $SP,$SP,#8
			// POP Ra,Rb
			7'd3:		begin micro_ip <= 7'd4; ir <= {29'h00,5'd31,micro_ir[13: 9],1'b0,LDH}; dlen <= 4'd4; end	// LDOS $Ra,[$SP]
			7'd4:		begin micro_ip <= 7'd5; ir <= {29'h10,5'd31,micro_ir[18:14],1'b0,LDH}; end	// LDOS $Rb,[$SP]
			7'd5:		begin micro_ip <= 7'd0; ir <= {13'h020,5'd31,5'd31,1'b0,ADDI}; ip.offs <= ip.offs + 4'd4; end							// ADD $SP,$SP,#16
			// POP Ra,Rb,Rc
			7'd6:		begin micro_ip <= 7'd7; ir <= {29'h00,5'd31,micro_ir[13: 9],1'b0,LDH}; dlen <= 4'd4; end	// LDOS $Ra,[$SP]
			7'd7:		begin micro_ip <= 7'd8; ir <= {29'h10,5'd31,micro_ir[18:14],1'b0,LDH}; end	// LDOS $Rb,[$SP]
			7'd8:		begin micro_ip <= 7'd9; ir <= {29'h20,5'd31,micro_ir[23:19],1'b0,LDH}; end	// LDOS $Rc,[$SP]
			7'd9:		begin micro_ip <= 7'd0; ir <= {13'h030,5'd31,5'd31,1'b0,ADDI}; ip.offs <= ip.offs + 4'd4; end							// ADD $SP,$SP,#24
			// PUSH Ra
			7'd10:	begin micro_ip <= 7'd11; ir <= {13'h1FF0,5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd2; end							// ADD $SP,$SP,#-8
			7'd11:	begin micro_ip <= 7'd0;  ir <= {29'h00,5'd31,micro_ir[13:9],1'b0,STH}; ip.offs <= ip.offs + 4'd2; end	// STOS $Ra,[$SP]
			// PUSH Ra,Rb
			7'd12:	begin micro_ip <= 7'd13; ir <= {13'h1FE0,5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd4; end								// ADD $SP,$SP,#-16
			7'd13:	begin micro_ip <= 7'd14; ir <= {29'h00,5'd31,micro_ir[18:14],1'b0,STH}; end	// STOS $Rb,[$SP]
			7'd14:	begin micro_ip <= 7'd0;  ir <= {29'h10,5'd31,micro_ir[13:9],1'b0,STH}; ip.offs <= ip.offs + 4'd4; end		// STOS $Ra,8[$SP]
			// PUSH Ra,Rb,Rc
			7'd15:	begin micro_ip <= 7'd16; ir <= {14'h1FD0,5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd4; end								// ADD $SP,$SP,#-24
			7'd16:	begin micro_ip <= 7'd17; ir <= {29'h00,5'd31,micro_ir[23:19],1'b0,STH}; end	// STOS $Rc,[$SP]
			7'd17:	begin micro_ip <= 7'd18; ir <= {29'h10,5'd31,micro_ir[18:14],1'b0,STH}; end	// STOS $Rb,8[$SP]
			7'd18:	begin micro_ip <= 7'd0;  ir <= {29'h20,5'd31,micro_ir[13:9],1'b0,STH}; ip.offs <= ip.offs + 4'd4; end		// STOS $Ra,16[$SP]
			// LEAVE
			7'd20:	begin micro_ip <= 7'd21; ir <= {13'h000,5'd30,5'd31,1'b0,ADDI};	end						// ADD $SP,$FP,#0
			7'd21:	begin micro_ip <= 7'd22; ir <= {29'h00,5'd31,5'd30,1'b0,LDH}; end				// LDO $FP,[$SP]
			7'd22:	begin micro_ip <= 7'd23; ir <= {29'h10,5'd31,5'd03,1'b0,LDH}; end				// LDO $T0,16[$SP]
			7'd23:	begin micro_ip <= 7'd26; ir <= {2'd0,5'd03,1'b0,MTLK}; end										// MTLK LK1,$T0
//			7'd24:	begin micro_ip <= 7'd25; ir <= {3'd6,8'h18,6'd63,6'd03,1'b0,LDOS}; end				// LDO $T0,24[$SP]
//			7'd25:	begin micro_ip <= 7'd26; ir <= {3'd0,1'b0,CSRRW,4'd0,16'h3103,6'd03,6'd00,1'b0,CSR}; end	// CSRRW $R0,$T0,0x3103
			7'd26: 	begin micro_ip <= 7'd27; ir <= {{6'h0,micro_ir[31:13]}+8'd4,4'b0,5'd31,5'd31,1'b0,ADDIL}; end	// ADD $SP,$SP,#Amt
			7'd27:	begin micro_ip <= 7'd0;  ir <= {1'd0,micro_ir[12:9],2'd1,1'b0,RTS}; ip.offs <= 32'hFFFD0000; end
			// STOO
			7'd28:	begin micro_ip <= 7'd29; ir <= {micro_ir[47:12],3'd0,1'b0,STOO}; dlen <= 4'd6; end
			7'd29:	begin micro_ip <= 7'd30; ir <= {micro_ir[47:12],3'd2,1'b0,STOO}; end
			7'd30:	begin micro_ip <= 7'd31; ir <= {micro_ir[47:12],3'd4,1'b0,STOO}; end
			7'd31:	begin micro_ip <= 7'd0;  ir <= {micro_ir[47:12],3'd6,1'b0,STOO}; ip.offs <= ip.offs + 4'd6; end
			// ENTER
			7'd32: 	begin micro_ip <= 7'd33; ir <= {13'h1FC0,5'd31,5'd31,1'b0,ADDI}; dlen <= 4'd4; end						// ADD $SP,$SP,#-64
			7'd33:	begin micro_ip <= 7'd34; ir <= {29'h00,5'd31,5'd30,1'b0,STH}; end				// STO $FP,[$SP]
			7'd34:	begin micro_ip <= 7'd35; ir <= {2'd0,5'd03,1'b0,MFLK}; end										// MFLK $T0,LK1
			7'd35:	begin micro_ip <= 7'd38; ir <= {29'h10,5'd31,5'd03,1'b0,STH}; end				// STO $T0,16[$SP]
//			7'd36:	begin micro_ip <= 7'd37; ir <= {3'd0,1'b0,CSRRD,4'd0,16'h3103,6'd00,6'd03,1'b0,CSR}; end	// CSRRD $T0,$R0,0x3103
//			7'd37:	begin micro_ip <= 7'd38; ir <= {3'd6,8'h18,6'd63,6'd03,1'b0,STOS}; end				// STO $T0,24[$SP]
			7'd38:	begin micro_ip <= 7'd39; ir <= {29'h20,5'd31,5'd00,1'b0,STH}; end				// STH $R0,32[$SP]
			7'd39:	begin micro_ip <= 7'd40; ir <= {29'h30,5'd31,5'd00,1'b0,STH}; end				// STH $R0,48[$SP]
			7'd40: 	begin micro_ip <= 7'd41; ir <= {13'h000,5'd31,5'd30,1'b0,ADDI}; end						// ADD $FP,$SP,#0
			7'd41: 	begin micro_ip <= 7'd0;  ir <= {{9{micro_ir[31]}},micro_ir[31:12],3'b0,5'd31,5'd31,1'b0,ADDIL}; ip.offs <= ip.offs + 4'd4; end // SUB $SP,$SP,#Amt
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
			POP2R:	begin micro_ip <= 7'd3; ip <= ip; end
			POP3R:	begin micro_ip <= 7'd6; ip <= ip; end
			PUSH:		begin micro_ip <= 7'd10; ip <= ip; end
			PUSH2R:	begin micro_ip <= 7'd12; ip <= ip; end
			PUSH3R:	begin micro_ip <= 7'd15; ip <= ip; end
			ENTER:	begin micro_ip <= 7'd32; ip <= ip; end
			LEAVE:	begin micro_ip <= 7'd20; ip <= ip; end
//			STOO:		begin if (insn[10]) begin micro_ip <= 7'd28; ip <= ip; end end
			LDCTX:	begin micro_ip <= 7'd96; ip <= ip; end
			STCTX:	begin micro_ip <= 7'd64; ip <= ip; end
			BSET:		begin micro_ip <= 7'd55; ip <= ip; end
			JMP:
				if (insn.jmp.Ca==3'd0)
					ip.offs <= {{30{insn.jmp.Tgthi[15]}},insn.jmp.Tgthi,insn.jmp.Tgtlo,1'b0};
				else if (insn.jmp.Ca==3'd7)
					ip.offs <= ip.offs + {{30{insn.jmp.Tgthi[15]}},insn.jmp.Tgthi,insn.jmp.Tgtlo,1'b0};
			CARRY:	begin cio <= insn[30:15]; cioreg <= insn[11:9]; end
			default:	;
			endcase
		dip <= ip;
		dstep <= istep;
		if (micro_ip==7'd0) begin
			ir <= insn;
			micro_ir <= insn;
		end
		dpredict_taken <= ipredict_taken;
		dcause <= icause;
		dpfx <= is_prefix(insn.any.opcode);
		distk_depth <= istk_depth;
		if (is_prefix(insn.any.opcode))
			pfx_cnt <= pfx_cnt + 2'd1;
		else
			pfx_cnt <= 3'd0;
		// Interrupts disabled while running micro-code.
		if (micro_ip==7'd0 && cio==16'h0000) begin
			if (irq_i > pmStack[3:1] && gie && !dpfx) begin
				icause <= 16'h8000|icause_i|(irq_i << 4'd8);
				istk_depth <= istk_depth + 2'd1;
			end
			else if (wc_time_irq && gie && !dpfx) begin
				icause <= 16'h8000|FLT_TMR;
				istk_depth <= istk_depth + 2'd1;
			end
			else if (insn.any.opcode==BRK) begin
				icause <= FLT_BRK;
				istk_depth <= istk_depth + 2'd1;
			end
			// Triple prefix fault.
			else if (pfx_cnt > 3'd2) begin
				icause <= 16'h8000|FLT_PFX;
				istk_depth <= istk_depth + 2'd1;
			end
		end
	end
	// Wait for cache load
	else begin
`ifdef OVERLAPPED_PIPELINE
		ip <= ip;
		if (advance_d)
			inv_d();
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
begin
	if (advance_d) begin
`ifndef OVERLAPPED_PIPELINE
		goto (EXECUTE);
`endif
		xistk_depth <= distk_depth;
		xval <= dval;
		xir <= ir;
		xlen <= dlen;
		xa <= rfoa;
		xb <= rfob;
		xc0 <= rfoc0;
		xc1 <= rfoc1;
		xca <= rfoca;
		pn <= rfop;
		imm <= deco.imm;
		xRa <= Ra;
		xRb <= Rb;
		xRc <= Rc;
		xRt <= Rt;
		xCt <= Ct;
		xcioreg <= cioreg;
		xcio <= cio[1:0];
		xCat <= deco.Cat;
		xip <= dip;
//		xFloat <= deco.float;
		xJmp <= deco.jmp;
		xJxx <= deco.jxx;
		xJxz <= deco.jxz;
		xmjnez <= deco.mjnez;
		xdj <= deco.dj;
		xRts <= deco.rts;
		xFlowchg <= deco.flowchg;
		xJmptgt <= deco.jmptgt;
		xpredict_taken <= dpredict_taken;
		xLoadr <= deco.loadr;
		xLoadn <= deco.loadn;
		xLdoo <= deco.ldoo;
		xStorer <= deco.storer;
		xStoren <= deco.storen;
		xStoo <= deco.stoo;
		xLdz <= deco.ldz;
		xMemsz <= deco.memsz;
		xLear <= deco.lear;
		xLean <= deco.lean;
		xMem <= deco.mem;
		xLoad <= deco.load;
		xTlb <= deco.tlb;
		xRgn <= deco.rgn;
		xBset <= deco.stset;
		xStmov <= deco.stmov;
		xStcmp <= deco.stcmp;
		xStfnd <= deco.stfnd;
		xIsMultiCycle <= deco.multi_cycle;
		xrfwr <= deco.rfwr;
		xcarfwr <= deco.carfwr;
		xvmrfwr <= deco.vmrfwr;
		xMul <= deco.mul;
		xMuli <= deco.muli;
		xMulsu <= deco.mulsu;
		xMulsui <= deco.mulsui;
		xMulf <= deco.mulf;
		xMulfi <= deco.mulfi;
		xIsMul <= deco.mulall;
		xIsDiv <= deco.divall;
		xDiv <= deco.div;
		xDivsu <= deco.divsu;
		xDivi <= deco.divalli;
		xCsr <= deco.csr;
		xSync <= deco.sync;
		xRti <= deco.rti;
		xRex <= deco.rex;
		xMfsel <= deco.mfsel;
		xMtsel <= deco.mtsel;
		xcause <= dcause;
		xstep <= dstep;
		xRtvec <= deco.Rtvec;
		xMtlk <= deco.mtlk;
		xrm <= deco.rm;
		xdfrm <= deco.dfrm;
		xIsDF <= deco.isDF;
		xmaskbit <= mask[dstep];
		xzbit <= zbit;
		xpredict_taken <= dpredict_taken;
		// The BTB might have predicted the correct address following the branch, so
		// do not invalidate unless flow is changing.
		xPredictableBranch <= (ir.jxx.Ca==3'd0 || ir.jxx.Ca==3'd7);
		if (ir.jxx.Ca==3'd0 && deco.jxx && dpredict_taken && bpe) begin	// Jxx, DJxx
			if (ip.offs != deco.jmptgt) begin
				inv_i();
				inv_d();
				ip.offs <= deco.jmptgt;
			end
		end
		else if (ir.jxx.Ca==3'd7 && deco.jxx && dpredict_taken && bpe) begin	// Jxx, DJxx
			if (ip.offs != dip.offs + deco.jmptgt) begin
				inv_i();
				inv_d();
				ip.offs <= dip.offs + deco.jmptgt;
			end
		end
		if (deco.jxx||deco.jxz) begin
  		xcares.offs <= dip.offs + dlen;
		end
		if (deco.jmp)
  		xcares.offs <= dip.offs + dlen;
  	else if (deco.mtlk)
  		xcares.offs <= rfoc0;
	end
`ifdef OVERLAPPED_PIPELINE
	else if (advance_x) begin
		inv_x();
		xx <= 4'd1;
	end
`endif
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tExMem;
begin
//			xIsMultiCycle <= FALSE;
  if (xIsMul)
    goto(MUL1);
  if (xIsDiv)
    goto(DIV1);
  if (xIsDF)
  	goto (DF1);
//    if (xFloat)
//      goto(FLOAT1);
  if (xLoadr) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= xLdz ? MR_LOADZ : MR_LOAD;
  	case(xMemsz)
  	byt:		begin memreq.func2 <= MR_LDB; memreq.sel <= 16'h0001; end
  	wyde:		begin memreq.func2 <= MR_LDW; memreq.sel <= 16'h0003; end
  	tetra:	begin memreq.func2 <= MR_LDT; memreq.sel <= 16'h000F; end
  	octa:		begin memreq.func2 <= MR_LDT; memreq.sel <= 16'h00FF; end
  	hexi:		begin memreq.func2 <= MR_LDH; memreq.sel <= 16'hFFFF; end
  	default:	begin memreq.func2 <= MR_LDO; memreq.sel <= 16'h00FF; end
  	endcase
  	memreq.adr.offs <= xa + imm;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
  else if (xLdoo) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_LOAD;
  	memreq.func2 <= MR_LDOO;
  	memreq.sel <= 16'hFFFF;
  	memreq.adr.offs <= xa + imm;
  	memreq.adr.offs[5:0] <= 6'h00;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
/* should be LLA
  else if (xLear) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= xLdz ? MR_LOADZ : MR_LOAD;
  	memreq.func2 <= MR_LEA;
  	memreq.adr.offs <= xa + imm;
  	memreq.seg <= {2'd0,xSeg};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
*/
  else if (xLoadn) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= xLdz ? MR_LOADZ : MR_LOAD;
  	case(xMemsz)
  	byt:		begin memreq.func2 <= MR_LDB; memreq.sel <= 16'h0001; end
  	wyde:		begin memreq.func2 <= MR_LDW; memreq.sel <= 16'h0003; end
  	tetra:	begin memreq.func2 <= MR_LDT; memreq.sel <= 16'h000F; end
  	octa:		begin memreq.func2 <= MR_LDT; memreq.sel <= 16'h00FF; end
  	hexi:		begin memreq.func2 <= MR_LDH; memreq.sel <= 16'hFFFF; end
  	default:	begin memreq.func2 <= MR_LDO; memreq.sel <= 16'h00FF; end
  	endcase
  	memreq.adr.offs <= siea;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
/*
  else if (xLean) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= xLdz ? MR_LOADZ : MR_LOAD;
  	memreq.func2 <= MR_LEA;
  	memreq.adr.offs <= siea;
  	memreq.seg <= {2'd0,xSeg};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
*/
  else if (xStorer) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_STORE;
  	case(xMemsz)
  	byt:		begin memreq.func2 <= MR_STB; memreq.sel <= 16'h0001; end
  	wyde:		begin memreq.func2 <= MR_STW; memreq.sel <= 16'h0003; end
  	tetra:	begin memreq.func2 <= MR_STT; memreq.sel <= 16'h000F; end
  	hexi:		begin memreq.func2 <= MR_STH; memreq.sel <= 16'hFFFF; end
  	default:	begin memreq.func2 <= MR_STO; memreq.sel <= 16'h00FF; end
  	endcase
  	memreq.adr.offs <= xa + imm;
  	memreq.dat <= {xc1,xc0};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
  else if (xStoren) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_STORE;
  	case(xMemsz)
  	byt:		begin memreq.func2 <= MR_STB; memreq.sel <= 16'h0001; end
  	wyde:		begin memreq.func2 <= MR_STW; memreq.sel <= 16'h0003; end
  	tetra:	begin memreq.func2 <= MR_STT; memreq.sel <= 16'h000F; end
  	hexi:		begin memreq.func2 <= MR_STH; memreq.sel <= 16'hFFFF; end
  	default:	begin memreq.func2 <= MR_STO; memreq.sel <= 16'h00FF; end
  	endcase
  	memreq.adr.offs <= siea;
  	memreq.dat <= {xc1,xc0};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
	else if (xBset) begin
		if (xc0 != 64'd0) begin
	  	memreq.tid <= tid;
	  	tid <= tid + 2'd1;
	  	memreq.func <= MR_STORE;
	  	case(xir[30:29])
	  	2'd0:	begin memreq.func2 <= MR_STB; memreq.sel <= 16'h0001; end
	  	2'd1:	begin memreq.func2 <= MR_STW; memreq.sel <= 16'h0003; end
	  	2'd2:	begin memreq.func2 <= MR_STT; memreq.sel <= 16'h000F; end
	  	default:	begin memreq.func2 <= MR_STO; memreq.sel <= 16'h00FF; end
	  	endcase
	  	memreq.adr.offs <= xa;
	  	memreq.dat <= xb;
	  	memreq.wr <= TRUE;
	  	goto (WAIT_MEM1);
  	end
  	else
  		xBset <= FALSE;
	end
	else if (xStmov) begin
		if (xc0 != 64'd0) begin
	  	memreq.tid <= tid;
	  	tid <= tid + 2'd1;
	  	memreq.func <= MR_MOVLD;
	  	case(xir[43:41])
	  	2'd0:	begin memreq.func2 <= MR_STB; memreq.sel <= 16'h0001; end
	  	2'd1:	begin memreq.func2 <= MR_STW; memreq.sel <= 16'h0003; end
	  	2'd2:	begin memreq.func2 <= MR_STT; memreq.sel <= 16'h000F; end
	  	default:	begin memreq.func2 <= MR_STO; memreq.sel <= 16'h00FF; end
	  	endcase
	  	memreq.adr.offs <= xa + xc0;
	  	memreq.dat <= xb + xc0;
	  	memreq.wr <= TRUE;
	  	goto (WAIT_MEM1);
  	end
  	else
  		xStmov <= FALSE;
	end
  else if (xTlb) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_TLB;
  	memreq.func2 <= MR_STO;
  	memreq.sel <= 16'h00FF;
  	memreq.adr <= 'd0;
  	memreq.dat <= {xb,xa};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
	end
  else if (xRgn) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_RGN;
  	memreq.func2 <= MR_STO;
  	memreq.sel <= 16'h00FF;
  	memreq.adr <= xb;
  	memreq.dat <= xa;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tJxx;
begin
  if (xJxx|xJxz) begin
  	mExBranch <= TRUE;
  	if (!takb)
  		mcarfwr <= FALSE;
    if (bpe) begin
      if (xpredict_taken && !takb && xPredictableBranch) begin
		    inv_i();
		    inv_d();
		    inv_x();
				xx <= 4'd2;
        ip.offs <= xip.offs + xlen;
      end
      else if ((!xpredict_taken && takb) || !xPredictableBranch)
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
	if (xmjnez) begin
		if (!takb)
			micro_ip <= xir[28:21];
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tJmp;
begin
  if (xJmp) begin
  	mExBranch <= TRUE;
  	if (xdj ? (xa != 64'd0) : (xir.jmp.Ca != 3'd0 && xir.jmp.Ca != 3'd7))	// ==0,7 was already done at ifetch
  		tBranch(4'd5);
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tRts;
begin
	if (xRts) begin
		if (xir.rts.lk != 2'd0) begin
	    inv_i();
	    inv_d();
	    inv_x();
			xx <= 4'd6;
  		ip.offs <= xca.offs + {xir.rts.cnst,1'b0};
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
begin
	if (advance_x) begin
`ifndef OVERLAPPED_PIPELINE
		goto (MEMORY);
`endif
		mistk_depth <= xistk_depth;
		mval <= xval;
		mir <= xir;
		mip <= xip;
		mRt <= xRt;
		mCt <= xCt;
		mcares <= xcares;
		mcioreg <= xcioreg;
		mcio <= xcio;
		mrfwr <= xrfwr;
		mvmrfwr <= xvmrfwr;
		mcarfwr <= xcarfwr;
		mLoad <= xLoad;
		mStset <= xBset;
		mStmov <= xStmov;
		// For loads the memory result will be set by the state machine. Do
		// not override the state machine's setting.
		if (!xLoad)
			mres <= res;
		mcarry_res <= carry_res;
		mCsr <= xCsr;
		mSync <= xSync;
		mJmp <= xJmp;
		mJxx <= xJxx;
		mJxz <= xJxz;
		mRts <= xRts;
		mRti <= xRti;
		mRex <= xRex;
		mFlowchg <= xFlowchg;
		ma <= xa;
		mca <= xca;
		mstep <= xstep;
		mmaskbit <= xmaskbit;
		mzbit <= xzbit;
		mRtvec <= xRtvec;
		mtakb <= takb;
		mExBranch <= FALSE;
		if (xval) begin
			tJxx();
	    tJmp();
	  	tRts();
			tExMem();

		end	// xval
	end	// advance_x
`ifdef OVERLAPPED_PIPELINE
	else if (advance_m)
		inv_m();
`endif
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Memory stage
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
task tMemory;
begin
	if (advance_m) begin
`ifndef OVERLAPPED_PIPELINE
		goto (WRITEBACK);
`endif
		wistk_depth <= mistk_depth;
		wval <= mval;
		wir <= mir;
		wip <= mip;
		wRt <= mRt;
		wCt <= mCt;
		wcioreg <= mcioreg;
		wcio <= mcio;
		wcarry_res <= mcarry_res;
		wrfwr <= mrfwr;
		w512 <= m512;
		w256 <= m256;
		wvmrfwr <= mvmrfwr;
		wcarfwr <= mcarfwr;
		wLoad <= mLoad;
		wStset <= mStset;
		wStmov <= mStmov;
		wres <= mres;
		wcares <= mcares;
		wres512 <= mres512;
		wCsr <= mCsr;
		wSync <= mSync;
		wJmp <= mJmp;
		wJxx <= mJxx;
		wJxz <= mJxz;
		wRts <= mRts;
		wRti <= mRti;
		wRex <= mRex;
		wFlowchg <= mFlowchg;
		wa <= ma;
		wca <= mca;
		wstep <= mstep;
		wmaskbit <= mmaskbit;
		wzbit <= mzbit;
		wRtvec <= mRtvec;
		wtakb <= mtakb;
		wJmptgt <= mJmptgt;
		wExBranch <= mExBranch;
	end
`ifdef OVERLAPPED_PIPELINE
	else if (advance_w)
		inv_w();
`endif
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Writeback stage
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
task tWriteback;
begin
  if (advance_w) begin
`ifndef OVERLAPPED_PIPELINE
		goto (SYNC);
`endif
		if (wval) begin
			if (wcio[0])
				preg[wcioreg] <= wcarry_res;
			if (|wcause) begin
		  	if (wcause[15])
					// IRQ level remains the same unless external IRQ present
					pmStack <= {pmStack[55:0],2'b0,2'b11,wcause[10:8],1'b0};
				else
					pmStack <= {pmStack[55:0],2'b0,2'b11,pmStack[3:1],1'b0};
				plStack <= {plStack[55:0],8'hFF};
				cause[2'd3] <= wcause & 16'h80FF;
				badaddr[2'd3] <= wbadAddr;
				caregfile[4'd8+wistk_depth] <= ip;
				ip.offs <= tvec[3'd3] + {omode,6'h00};
				inv_i();
				inv_d();
				inv_x();
				inv_m();
				inv_w();
				xx <= 4'd8;
			end
			else begin
		  	if (wcarfwr)
		    	caregfile[wCt] <= wcares;
				if (wRti) begin
					if (|istk_depth) begin
						pmStack <= {8'h3E,pmStack[63:8]};
						plStack <= {8'hFF,plStack[63:8]};
						ip.offs <= wca.offs;	// 8-1
						istk_depth <= istk_depth - 2'd1;
						inv_i();
						inv_d();
						inv_x();
						inv_m();
						inv_w();
						xx <= 4'd9;
					end
				end
		    else if (wCsr)
		      case(wir.csr.op)
		      3'd1:   tWriteCSR(wa,wir.csr.regno);
		      3'd2:   tSetbitCSR(wa,wir.csr.regno);
		      3'd3:   tClrbitCSR(wa,wir.csr.regno);
		      default:	;
		      endcase
				else if (wRex) begin
					if (omode <= wir[10:9]) begin
						pmStack <= {pmStack[55:0],2'b0,2'b11,pmStack[3:1],1'b0};
						plStack <= {plStack[55:0],8'hFF};
						cause[2'd3] <= FLT_PRIV;
						caregfile[wCt] <= ip;
						ip.offs <= tvec[3'd3] + {omode,6'h00};
						inv_i();
						inv_d();
						inv_x();
						inv_m();
						inv_w();
						xx <= 4'd10;
					end
					else begin
						pmStack[2:1] <= wir[10:9];	// omode
					end
				end
				// Register file update
			  if (wrfwr) begin
			  	if (wRtvec) begin
			  		if (wmaskbit)
			  			vregfile[wRt][wstep] <= wres;
			  		else if (wzbit)
			  			vregfile[wRt][wstep] <= 64'd0;
			  	end
			  	else begin
			  		/*
				    case(wRt)
				    6'd63:  sp[{omode,ilvl}] <= {wres[63:3],3'h0};
				    endcase
				    */
				    if (w512)
				    	regfile[wRt[4:2]] <= wres512;
				    else if (w256) begin
				    	if (wRt!=5'd0)
					    	case(wRt[1])
					    	1'd0:	regfile[wRt[4:2]][255:  0] <= wres512[255:0];
					    	1'd1:	regfile[wRt[4:2]][511:256] <= wres512[255:0];
					    	endcase
				    end
				    else
					    case(wRt[1:0])
					    2'd0:	regfile[wRt[4:2]][127:  0] <= wres;
					    2'd1:	regfile[wRt[4:2]][255:128] <= wres;
					    2'd2:	regfile[wRt[4:2]][383:256] <= wres;
					    2'd3:	regfile[wRt[4:2]][511:384] <= wres;
					  	endcase
				    $display("regfile[%d] <= %h", wRt, wres);
				    // Globally enable interrupts after first update of stack pointer.
				    if (wRt==5'd31) begin
				    	sp <= wres;	// debug
				      gie <= TRUE;
				    end
				    if (wRt==5'd26)
				    	r58 <= wres;
				    if (wRt==5'd11)
				    	t0 <= wres;
				  end
			  end
			  if (wvmrfwr)
			  	vm_regfile[wRt[2:0]] <= wres;
			end	// wcause
		end		// wval
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
`ifndef OVERLAPPED_PIPELINE
	goto (IFETCH);
`endif
	if (advance_t) begin
		tSync <= wSync & wval;
		uSync <= tSync;
		vSync <= uSync;
	end
end
endtask

task tBranch;
input [3:0] yy;
begin
  inv_i();
  inv_d();
  inv_x();
	xx <= yy;
  if (xir.jxx.Ca == 4'd0) begin
  	ip.offs <= xJmptgt;
  	mJmptgt.offs <= xJmptgt;
  end
  else if (xir.jxx.Ca == 4'd7) begin
  	ip.offs <= xip.offs + xJmptgt;
  	mJmptgt.offs <= xip.offs + xJmptgt;
  end
  else begin
		ip.offs <= xca.offs + xJmptgt;
  	mJmptgt.offs <= xca.offs + xJmptgt;
  end
end
endtask

task tWait;
begin
	if (first_flag || !done_flag) begin
		first_flag <= 1'b0;
	  inv_i();
	  inv_d();
	  inv_x();
  	ip.offs <= xip.offs;
  	mJmptgt.offs <= xip.offs;
	end
	else
		first_flag <= 1'b1;
end
endtask

task ex_fault;
input [15:0] c;
begin
	if (xcause==16'h0)
		xcause <= c;
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
		CSR_ARTBR:	res = artbr;
		CSR_KEYTBL:	res = keytbl;
		CSR_KEYS:	res = keys2[regno[1:0]];
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
		CSR_ARTBR:	artbr <= val;
		CSR_SEMA:		sema <= val;
		CSR_KEYTBL:	keytbl <= val;
		CSR_KEYS:		keys2[regno[1:0]] <= val;
//		CSR_FSTAT:	fpscr <= val;
		CSR_ASID: 	asid <= val;
		CSR_MBADADDR:	badaddr[regno[13:12]] <= val;
		CSR_CAUSE:	cause[regno[13:12]] <= val;
		CSR_MTVEC:	tvec[regno[1:0]] <= val;
		CSR_UCA:
			if (regno[3:0] < 4'd8)
				caregfile[wCt].offs <= val;
		CSR_MCA,CSR_SCA,CSR_HCA:
			caregfile[wCt].offs <= val;
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
