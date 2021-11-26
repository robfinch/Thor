// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2021io.sv
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

import Thor2021_pkg::*;

module Thor2021io(hartid_i, rst_i, clk_i, clk2x_i, clk2d_i, wc_clk_i, irq_i, icause_i,
		vpa_o, vda_o, bte_o, cti_o, bok_i, cyc_o, stb_o, lock_o, ack_i,
    err_i, we_o, sel_o, adr_o, dat_i, dat_o, cr_o, sr_o, rb_i, state_o, trigger_o);
input [63:0] hartid_i;
input rst_i;
input clk_i;
input clk2x_i;
input clk2d_i;
input wc_clk_i;
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

reg [5:0] rst_cnt;
wire [1:0] omode;
wire [1:0] memmode;
wire UserMode, SupervisorMode, HypervisorMode, MachineMode;
wire MUserMode;
reg gie;
Value regfile [0:63];
Value sp [0:31];
Value lc;
Address caregfile [0:15];
(* ram_style="block" *)
Value vregfile [0:63][0:63];
reg [63:0] vm_regfile [0:7];

integer n1;
initial begin
	for (n1 = 0; n1 < 64; n1 = n1 + 1) begin
		regfile[n1] <= 64'd0;
		caregfile[n1 % 16].offs <= 32'd0;
		caregfile[n1 % 16].sel <= 32'd0;
	end
end

reg advance_w;
Value vroa, vrob, vroc;
Value wres2;
wire wrvrf;

// Instruction fetch stage vars
reg ival;
reg [15:0] icause;
Instruction insn;
reg advance_i;
Address ip;
wire ipredict_taken;
wire ihit;
wire [639:0] ic_line;
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
reg dpfx;
reg advance_d;
reg [3:0] dlen;
DecodeOut deco;
reg dpredict_taken;
reg [5:0] Ra;
reg [5:0] Rb;
reg [5:0] Rc;
reg [5:0] Rt;
reg [1:0] Tb;
reg [1:0] Tc;
reg [2:0] Rvm;
reg Rz;
always_comb Ra = deco.Ra;
always_comb Rb = deco.Rb;
always_comb Rc = deco.Rc;
always_comb Rt = deco.Rt;
always_comb Rvm = deco.Rvm;
always_comb Rz = deco.Rz;
always_comb Tb = deco.Tb;
always_comb Tc = deco.Tc;
reg [7:0] dstep;
reg zbit;

wire dAddi = deco.addi;
wire dld = deco.ld;
wire dst = deco.st;
Value rfoa, rfob, rfoc;
reg [63:0] mask;
reg [63:0] dlc;

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
reg [5:0] xRt,xRa,xRb,xRc,tRt;
reg xRtvec;
reg [2:0] xCat;
Value xa,xb,xc;
Value imm;
reg xmaskbit;
reg xzbit;
reg [2:0] xSc;
wire takb;
reg xpredict_taken;
reg xJmp;
reg [63:0] xJmptgt;
reg xJxx;
reg xdj;
reg xRts, xRti;
reg xRex;
reg xIsMultiCycle;
reg xLdz;
reg xLear,xLean;
reg xMem, xLoad;
reg xrfwr;
reg xcarfwr;
reg xvmrfwr;
reg xMul,xMuli;
reg xMulu,xMului;
reg xMulsu,xMulsui;
reg xIsMul,xIsDiv;
reg xDiv,xDivsu;
reg xDivi;
reg xLoadr, xLoadn;
reg xStorer, xStoren;
reg [2:0] xSeg;
reg [2:0] xMemsz;
reg xTlb;
reg xStset, xStmov, xStfnd, xStcmp;
reg xCsr;
reg xMtlc;
reg xwrlc;
reg xMfsel,xMtsel;
reg [63:0] xlc;
MemoryRequest memreq;
MemoryResponse memresp;
reg memresp_fifo_rd;
wire memresp_fifo_empty;
wire memresp_fifo_v;
reg [7:0] tid;
Value res,res2;
Value crypto_res;
Address cares;
reg ld_vtmp;
reg [7:0] xstep;

// Writeback stage vars
reg wval;
Instruction wir;
Address wip;
reg [15:0] wcause;
Address wbadAddr;
reg wrfwr;
reg wvmrfwr;
reg [5:0] wRt;
reg wRtvec;
reg wCsr;
reg wRti;
reg wRex;
reg wMtlc;
reg wwrlc;
reg wLoad;
reg [63:0] wlc;
Value wa;
Value wres;
reg [7:0] wstep;
reg wzbit;
reg wmaskbit;

reg tCsr;
reg uCsr;

// CSRs
reg [63:0] cr0;
wire pe = cr0[0];				// protected mode enable
wire dce;     					// data cache enable
wire bpe = cr0[32];     // branch prediction enable
wire btbe	= cr0[33];		// branch target buffer enable
Value scratch [0:3];
reg [63:0] tick;
reg [63:0] wc_time;			// wall-clock time
reg [63:0] mtimecmp;
Address tvec [0:3];
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

Thor2021_decoder udec (ir, xir, deco);

always_comb
if (Ra==6'd0)
  rfoa = {VALUE_SIZE{1'b0}};
else if (deco.Ravec)
	rfoa = vroa;
else if (Ra==xRt && xrfwr && xval)
  rfoa = res;
else if (Ra==wRt && wrfwr && wval)
	rfoa = wres;
else
	rfoa = regfile[Ra];
/*
  case(Ra)
  6'd63:  rfoa = sp [{omode,ilvl}];
  default:    rfoa = regfile[Ra];
  endcase
*/
always_comb
if (Tb[1])
	rfob = {{57{Tb[0]}},Tb[0],Rb};
else if (Rb==6'd0)
	rfob = {VALUE_SIZE{1'b0}};
else if (deco.Rbvec)
	rfob = vrob;
else if (Rb==xRt && xrfwr && xval)
  rfob = res;
else if (Rb==wRt && wrfwr && wval)
	rfob = wres;
else
	rfob = regfile[Rb];
/*	
  case(Rb)
  6'd63:  rfob = sp [{omode,ilvl}];
  default:    rfob = regfile[Rb];
  endcase
*/
always_comb
if (Tc[1])
	rfoc = {{57{Tc[0]}},Tc[0],Rc};
else if (Rc==6'd0)
	rfoc = {VALUE_SIZE{1'b0}};
else if (deco.Rcvec)
	rfoc = vroc;
else if (Rc==xRt && xrfwr && xval)
  rfoc = res;
else if (Rc==wRt && wrfwr && wval)
	rfoc = wres;
else
	rfoc = regfile[Rc];
/*
  case(Rc)
  6'd63:  rfoc = sp [{omode,ilvl}];
  default:    rfoc = regfile[Rc];
  endcase
*/

always_comb
	if (xMtlc && xrfwr && xval)
		dlc = res;
	else if (xwrlc && xval)
		dlc = xlc;
	else if (wMtlc && wrfwr && wval)
		dlc = wres;
	else if (wwrlc && wval)
		dlc = wlc;
	else
		dlc = lc;

always_comb
	mask = vm_regfile[deco.Rvm];

always_comb
	zbit = deco.Rz;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute stage combinational logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Thor2021_eval_branch ube (xir, xa, xb, takb);

wire [6:0] cntlz_out;
cntlz64 uclz(xir.r1.func[0] ? ~xa : xa, cntlz_out);

wire [127:0] sllro = {xb,xa} << xc[5:0];
wire [127:0] srlro = {xb,xa} >> xc[5:0];
wire [63:0] srao = {{64{xa[63]}},xa} >> xb[5:0];

wire [127:0] mul_prod1;
reg [127:0] mul_prod;
reg mul_sign;
Value aa, bb;

// 6 stage pipeline
Thor2021_multiplier umul
(
  .CLK(clk_g),
  .A(aa),
  .B(bb),
  .P(mul_prod1)
);
wire multovf = ((xMulu|xMului) ? mul_prod[127:64] != 64'd0 : mul_prod[127:64] != {64{mul_prod[63]}});

wire [63:0] qo, ro;
wire dvd_done;
wire dvByZr;
Thor2021_divider udiv
(
  .rst(rst_i),
  .clk(clk2x_i),
  .ld(xIsDiv),
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


Thor2021_bitfield ubf
(
	.ir(xir),
	.a(xa),
	.b(xb),
	.c(xc),
	.o(bf_out)
);

Thor2021_crypto ucrypto
(
	.ir(xir),
	.m(xm),
	.z(xz),
	.a(xa),
	.b(xb),
	.c(xc),
	.t(),
	.o(crypto_res)
);

Value mux_out;
integer n2;
always_comb
    for (n2 = 0; n2 < $bits(Value); n2 = n2 + 1)
        mux_out[n2] = xa[n2] ? xb[n2] : xc[n2];

Value csr_res;
always_comb
	tReadCSR (csr_res, xir.csr.regno);

always_comb
case(xir.any.opcode)
R1:
	case(xir.r1.func)
	CNTLZ:	res2 = {57'd0,cntlz_out};
	CNTLO:	res2 = {57'd0,cntlz_out};
	default:	res2 = 64'd0;
	endcase
R2:
	case(xir.r3.func)
	ADD:	res2 = xa + xb + xc;
	SUB:	res2 = xa - xb;
	AND:	res2 = xa & xb & xc;
	OR:		res2 = xa | xb | xc;
	XOR:	res2 = xa ^ xb ^ xc;
	SLLP:	res2 = sllro[127:64];
	SRLP:	res2 = srlro[63:0];
	SRA:	res2 = srao;
	MUL:	res2 = mul_prod[63:0];
	MULH:	res2 = mul_prod[127:64];
	MULU:	res2 = mul_prod[63:0];
	MULUH:	res2 = mul_prod[127:64];
	MULSU:res2 = mul_prod[63:0];
	DIV:	res2 = qo;
	DIVU:	res2 = qo;
	DIVSU:	res2 = qo;
	MUX:	res2 = mux_out;
	default:			res2 = 64'd0;
	endcase
VM:
	case(xir.vmr2.func)
	MTVM:			res2 = xa;
	MTLC:			res2 = xa;
	MFLC:			res2 = xlc;
	default:	res2 = 64'd0;
	endcase
OSR2:
	case(xir.r3.func)
	MFSEL:		res2 = memresp.res;
	default:	res2 = 64'd0;
	endcase
CSR:		res2 = csr_res;
BTFLD:	res2 = bf_out;
ADD2R:				res2 = xa + xb;
AND2R:				res2 = xa & xb;
OR2R:					res2 = xa | xb;
XOR2R:				res2 = xa ^ xb;
ADDI,ADDIL:		res2 = xa + imm;
SUBFI,SUBFIL:	res2 = imm - xa;
ANDI,ANDIL:		res2 = xa & imm;
ORI,ORIL:			res2 = xa | imm;
XORI,XORIL:		res2 = xa ^ imm;
SLLR2:				res2 = xa << xb[5:0];
CMPI,CMPIL:		res2 = $signed(xa) < $signed(imm) ? -64'd1 : xa==imm ? 64'd0 : 64'd1;
CMPUI,CMPUIL:	res2 = xa < imm ? -64'd1 : xa==imm ? 64'd0 : 64'd1;
MULI,MULIL:		res2 = mul_prod[63:0];
MULUI:MULUIL:	res2 = mul_prod[63:0];
DIVI,DIVIL:		res2 = qo;
SEQI,SEQIL:		res2 = xa == imm;
SNEI,SNEIL:		res2 = xa != imm;
SLTI,SLTIL:		res2 = $signed(xa) < $signed(imm);
SGTI,SGTIL:		res2 = $signed(xa) > $signed(imm);
SLTUI,SLTUIL:	res2 = xa < imm;
SGTUI,SGTUIL:	res2 = xa > imm;
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDOR,LDOS,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX:
							res2 = memresp.res;
STSET:							
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
	3'd0:	res2 = xc + 4'd1;
	3'd1:	res2 = xc + 4'd2;
	3'd2:	res2 = xc + 4'd4;
	3'd3:	res2 = xc + 4'd8;
	3'd4:	res2 = xc - 4'd1;
	3'd5:	res2 = xc - 4'd2;
	3'd6:	res2 = xc - 4'd4;
	3'd7:	res2 = xc - 4'd8;
	endcase
default:			res2 = 64'd0;
endcase

always_comb
	res = res2|crypto_res;

Thor20221_inslength uil(insn, ilen);

always_comb
begin
	next_ip.sel = ip.sel;
 	next_ip.offs = ip.offs + ilen;
end

Thor2021_BTB_x1 ubtb
(
	.rst(rst_i),
	.clk(clk_g),
	.wr(),
	.wip(),
	.wtgt(),
	.takb(),
	.rclk(~clk_g),
	.ip(ip),
	.tgt(btb_tgt),
	.hit(btb_hit),
	.nip(next_ip)
);

Thor2021_gselectPredictor ubp
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

Thor2021_biu ubiu
(
	.rst(rst_i),
	.clk(clk_g),
	.tlbclk(clk2x_i),
	.UserMode(UserMode),
	.MUserMode(MUserMode),
	.omode(omode),
	.ASID(asid),
	.ea_seg(),
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
	.gdt(gdt),
	.ldt()
);

always_comb
	insn = ic_line >> {ip.offs[5:1],4'd0};

wire [63:0] siea = xa + {xb << xSc};

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
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [2:0] clr_stall_x;
wire stall_d = (deco.storer|deco.storen|deco.stset|deco.stcmp|deco.stfnd|deco.stmov) && (|xcause || xRti || xRex);
wire stall_x = 1'b0;//((xLoad && (Ra==xRt || {Tb,Rb}=={2'b00,xRt} || {Tc,Rc}=={2'b00,xRt}) && xval && xRt!=6'd0) && !clr_stall_x[2]);// ||
//							  (wLoad && (Ra==wRt || {Tb,Rb}=={2'b00,wRt} || {Tc,Rc}=={2'b00,wRt}) && wval && wRt!=6'd0)) &&
//							  state!=RUN;

assign run = ihit;
always_comb	advance_w = ihit && (state==RUN||state==INVnRUN) && (!stall_x);
always_comb advance_x = ihit && (advance_w || !wval) && (state==RUN) && !(wCsr && wval) && !tCsr && !uCsr && (!stall_x);
always_comb advance_d = ihit && (advance_x || !xval) && !stall_d;
always_comb advance_i = ihit && (advance_d || !dval);

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
	xx <= FALSE;
	memreq.wr <= FALSE;
	if (ld_time==TRUE && wc_time_dat==wc_time)
		ld_time <= FALSE;
	if (clr_wc_time_irq && !wc_time_irq)
		clr_wc_time_irq <= FALSE;

	tInsnFetch();
	tDecode();
	tStateMachine();
	tExecute();
	tWriteback();

	if (ihit) begin
		tCsr <= wCsr & wval;
		uCsr <= tCsr;
	end

end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Support tasks
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task inv_i;
begin
  ival <= INV;
  icause <= 16'h0;
end
endtask

task inv_d;
begin
  dval <= INV;
  dcause <= 16'h0;
end
endtask

task inv_x;
begin
  xval <= INV;
 	xcause <= 16'h0;
end
endtask

task inv_w;
begin
  wval <= INV;
  wcause <= 16'h0;
end
endtask

task tReset;
begin
	ld_time <= FALSE;
	wval <= INV;
	xval <= INV;
	dval <= INV;
	ival <= INV;
	ir <= NOP_INSN;
	xir <= NOP_INSN;
	wir <= NOP_INSN;
	xIsMultiCycle <= FALSE;
	xMem <= FALSE;
	xLoad <= FALSE;
	xSeg <= 3'd0;
	xSc <= 3'd0;
	xStset <= FALSE;
	xStcmp <= FALSE;
	xStmov <= FALSE;
	xStfnd <= FALSE;
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
	cr0 <= 64'h300000001;
	rst_cnt <= 6'd0;
	xCsr <= 1'b0;
	wCsr <= 1'b0;
	tCsr <= 1'b0;
	uCsr <= 1'b0;
	wLoad <= FALSE;
	clr_stall_x <= 3'b0;
	memresp_fifo_rd <= FALSE;
	gdt <= 64'hFFFFFFFFFFFFFFC0;	// startup table (bit 75 to 12)
	ip.offs <= 32'hFFFD0000;
	ip.sel <= 32'hFF000007;				// entry 7 of the GDT
	gie <= FALSE;
	pmStack <= 64'h3e3e3e3e3e3e3e3e;	// Machine mode, irq level 7, ints disabled
	plStack <= 64'hffffffffffffffff;	// PL = 255
	asid <= 8'h00;
	istk_depth <= 4'd1;
	icause <= 16'h0000;
	dcause <= 16'h0000;
	xcause <= 16'h0000;
	wcause <= 16'h0000;
	lc <= 64'd0;
	wLoad <= FALSE;
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
		clr_stall_x <= {clr_stall_x[1:0],1'b0};
		if (stall_x)
			tExMem();
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
			xLoad <= FALSE;
			if (xStset|xStmov)
				xrfwr <= TRUE;
			if (memresp.tid == memreq.tid) begin
				if (memreq.func==MR_LOAD || memreq.func==MR_LOADZ || memreq.func==MR_MFSEL) begin
					xrfwr <= FALSE;
					if (memreq.func2!=MR_LDDESC) begin
						xrfwr <= TRUE;
					end
				end
				if (|memresp.cause) begin
					xcause <= memresp.cause;
					xbadAddr <= memresp.badAddr;
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
		wRt <= xRt;
  	wres <= res;
		wval <= TRUE;
		wrfwr <= xrfwr;
		wcause <= xcause;
		wbadAddr <= xbadAddr;
		clr_stall_x <= 3'b111;
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
    else if (xMulu) bb <= xb;
    else bb <= imm; // MULUI
	// Now wait for the six stage pipeline to finish
    call(DELAY6,MUL9);
  end
MUL9:
  begin
    mul_prod <= mul_sign ? -mul_prod1 : mul_prod1;
    //upd_rf <= `TRUE;
    goto(INVnRUN);
    if (multovf & mexrout[5]) begin
      ex_fault(FLT_OFL);
    end
  end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DIV1:
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
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
// Instruction Fetch stage
// We want decodes in the IFETCH stage to be fast so they don't appear
// on the critical path. Keep the decodes to a minimum.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tInsnFetch;
begin
	if (advance_i) begin
		ival <= VAL;
		if (insn.any.v && istep < vl) begin
			istep <= istep + 2'd1;
			ip <= ip;
		end
		else if ((insn.any.opcode==STSET || insn.any.opcode==STMOV || insn.any.opcode==STFND || insn.any.opcode==STCMP) && lc != 64'd0)
			ip <= ip;
		else begin
			istep <= 8'h00;
			ip <= next_ip;
		end
		if (insn.jmp.Ca==3'd0 && (insn.any.opcode==JMP))
			ip.offs <= {{30{insn.jmp.Tgthi[15]}},insn.jmp.Tgthi,insn.jmp.Tgtlo,1'b0};
		else if (insn.jmp.Ca==3'd7 && (insn.any.opcode==JMP))
			ip.offs <= ip.offs + {{30{insn.jmp.Tgthi[15]}},insn.jmp.Tgthi,insn.jmp.Tgtlo,1'b0};
		else if (btbe & btb_hit)
			ip <= btb_tgt;
		dip <= ip;
		dlen <= ilen;
		dval <= ival;
		dstep <= istep;
		ir <= insn;
		dpredict_taken <= ipredict_taken;
		dcause <= icause;
		dpfx <= is_prefix(insn.any.opcode);
		if (is_prefix(insn.any.opcode))
			pfx_cnt <= pfx_cnt + 2'd1;
		else
			pfx_cnt <= 3'd0;
		if (irq_i > pmStack[3:1] && gie && !dpfx)
			icause <= 16'h8000|icause_i|(irq_i << 4'd8);
		else if (wc_time_irq && gie && !dpfx)
			icause <= 16'h8000|FLT_TMR;
		else if (insn.any.opcode==BRK)
			icause <= FLT_BRK;
		// Triple prefix fault.
		else if (pfx_cnt > 3'd2)
			icause <= 16'h8000|FLT_PFX;
	end
	// Wait for cache load
	else begin
		ip <= ip;
		if (advance_d)
			inv_d();
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
		xval <= dval;
		xir <= ir;
		xlen <= dlen;
		xa <= rfoa;
		xb <= rfob;
		xc <= rfoc;
		imm <= deco.imm;
		xlc <= dlc;
		xRa <= Ra;
		xRb <= Rb;
		xRc <= Rc;
		xRt <= Rt;
		xSc <= deco.scale;
		xCat <= deco.Cat;
		xip <= dip;
		xlen <= dlen;
//		xFloat <= deco.float;
		xJmp <= deco.jmp;
		xJxx <= deco.jxx;
		xdj <= deco.dj;
		xRts <= deco.rts;
		xJmptgt <= deco.jmptgt;
		xpredict_taken <= dpredict_taken;
		xLoadr <= deco.loadr;
		xLoadn <= deco.loadn;
		xStorer <= deco.storer;
		xStoren <= deco.storen;
		xLdz <= deco.ldz;
		xMemsz <= deco.memsz;
		xLear <= deco.lear;
		xLean <= deco.lean;
		xSeg <= deco.seg;
		xMem <= deco.mem;
		xLoad <= deco.load;
		xTlb <= deco.tlb;
		xStset <= deco.stset;
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
		xIsMul <= deco.mulall;
		xIsDiv <= deco.divall;
		xDiv <= deco.div;
		xDivsu <= deco.divsu;
		xDivi <= deco.divalli;
		xCsr <= deco.csr;
		xRti <= deco.rti;
		xRex <= deco.rex;
		xMtlc <= deco.mtlc;
		xwrlc <= deco.wrlc;
		xMfsel <= deco.mfsel;
		xMtsel <= deco.mtsel;
		xcause <= dcause;
		xstep <= dstep;
		xRtvec <= deco.Rtvec;
		xmaskbit <= mask[dstep];
		xzbit <= zbit;
		xpredict_taken <= dpredict_taken;
		if (ir.jxx.Ca==3'd0 && deco.jxx && dpredict_taken) begin	// Jxx, DJxx
			inv_i();
			inv_d();
			ip.offs <= deco.jmptgt;
		end
		else if (ir.jxx.Ca==3'd7 && deco.jxx && dpredict_taken) begin	// Jxx, DJxx
			inv_i();
			inv_d();
			ip.offs <= ip.offs + deco.jmptgt;
		end
	end
	else if (advance_x) begin
		inv_x();
		xx <= 4'd1;
	end
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
  	default:	begin memreq.func2 <= MR_LDO; memreq.sel <= 16'h00FF; end
  	endcase
  	memreq.adr.offs <= xa + imm;
  	memreq.seg <= {2'd0,xSeg};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
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
  else if (xLoadn) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= xLdz ? MR_LOADZ : MR_LOAD;
  	case(xMemsz)
  	byt:		begin memreq.func2 <= MR_LDB; memreq.sel <= 16'h0001; end
  	wyde:		begin memreq.func2 <= MR_LDW; memreq.sel <= 16'h0003; end
  	tetra:	begin memreq.func2 <= MR_LDT; memreq.sel <= 16'h000F; end
  	default:	begin memreq.func2 <= MR_LDO; memreq.sel <= 16'h00FF; end
  	endcase
  	memreq.adr.offs <= siea;
  	memreq.seg <= {2'd0,xSeg};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
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
  else if (xStorer) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_STORE;
  	case(xMemsz)
  	byt:		begin memreq.func2 <= MR_STB; memreq.sel <= 16'h0001; end
  	wyde:		begin memreq.func2 <= MR_STW; memreq.sel <= 16'h0003; end
  	tetra:	begin memreq.func2 <= MR_STT; memreq.sel <= 16'h000F; end
  	default:	begin memreq.func2 <= MR_STO; memreq.sel <= 16'h00FF; end
  	endcase
  	memreq.adr.offs <= xa + imm;
  	memreq.dat <= xc;
  	memreq.seg <= {2'd0,xSeg};
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
  	default:	begin memreq.func2 <= MR_STO; memreq.sel <= 16'h00FF; end
  	endcase
  	memreq.adr.offs <= siea;
  	memreq.dat <= xc;
  	memreq.seg <= {2'd0,xSeg};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
  end
	else if (xStset) begin
		if (xlc != 64'd0) begin
   		wlc <= xlc - 2'd1;
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
	  	memreq.seg <= {2'd0,xir[34:32]};
	  	memreq.wr <= TRUE;
	  	goto (WAIT_MEM1);
  	end
  	else
  		xStset <= FALSE;
	end
	else if (xStmov) begin
		if (xlc != 64'd0) begin
   		wlc <= xlc - 2'd1;
	  	memreq.tid <= tid;
	  	tid <= tid + 2'd1;
	  	memreq.func <= MR_MOVLD;
	  	case(xir[43:41])
	  	2'd0:	begin memreq.func2 <= MR_STB; memreq.sel <= 16'h0001; end
	  	2'd1:	begin memreq.func2 <= MR_STW; memreq.sel <= 16'h0003; end
	  	2'd2:	begin memreq.func2 <= MR_STT; memreq.sel <= 16'h000F; end
	  	default:	begin memreq.func2 <= MR_STO; memreq.sel <= 16'h00FF; end
	  	endcase
	  	memreq.adr.offs <= xa + xc;
	  	memreq.dat <= xb + xc;
	  	memreq.seg <= {2'd0,xir[47:45]};
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
  	memreq.adr <= xa;		// must use entire adr (64 bits)
  	memreq.dat <= xb;
  	memreq.seg <= {2'd0,3'd0};
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
	end
  else if (xMfsel) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_MFSEL;
  	memreq.func2 <= 4'd0;
  	memreq.sel <= 16'hFFFF;
  	memreq.adr <= 64'd0;
  	memreq.dat <= {59'd0,xb[4:0]};
  	memreq.seg <= 5'd0;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
	end
  else if (xMtsel) begin
  	memreq.tid <= tid;
  	tid <= tid + 2'd1;
  	memreq.func <= MR_LOAD;
  	memreq.func2 <= MR_LDDESC;
  	memreq.sel <= 16'hFFFF;
  	memreq.adr <= xa;
  	memreq.dat <= {59'd0,xb[4:0]};
  	memreq.seg <= 5'd0;
  	memreq.wr <= TRUE;
  	goto (WAIT_MEM1);
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
		wval <= xval;
		wir <= xir;
		wip <= xip;
		wRt <= xRt;
		wrfwr <= xrfwr;
		wvmrfwr <= xvmrfwr;
		wLoad <= xLoad;
		wres <= res;
		wlc <= xlc;
		wCsr <= xCsr;
		wRti <= xRti;
		wRex <= xRex;
		wMtlc <= xMtlc;
		wwrlc <= xwrlc;
		wa <= xa;
		wstep <= xstep;
		wmaskbit <= xmaskbit;
		wzbit <= xzbit;
		wRtvec <= xRtvec;
		if (xval) begin
	    if (xJxx) begin
	    	if (xdj)
	    		wlc <= xlc - 2'd1;
	    	if (xir.jxx.lk != 2'd0) begin
		    	caregfile[{2'b0,xir.jxx.lk}].offs <= xip.offs + 3'd6;
		    	caregfile[{2'b0,xir.jxx.lk}].sel <= xip.sel;
	    	end
	      if (bpe) begin
	        if (xpredict_taken && !(xdj ? takb && xlc != 64'd0 : takb)) begin
				    inv_i();
				    inv_d();
				    inv_x();
						xx <= 4'd2;
	          ip.offs <= xip.offs + 3'd6;
	          // Was selector changed? If so change it back.
	          tChangeIPSel(xip.sel);
	        end
	        else if (!xpredict_taken && (xdj ? takb && xlc != 64'd0 : takb)) begin
				    inv_i();
				    inv_d();
				    inv_x();
						xx <= 4'd3;
				    if (xir.jxx.Ca == 3'd0)
				    	ip.offs <= xJmptgt;
				    else if (xir.jxx.Ca == 3'd7)
				    	ip.offs <= xip.offs + xJmptgt;
				    else
				    	ip.offs <= caregfile[xir.jxx.Ca].offs + xJmptgt;
		    		if (xir.jxx.Ca != 3'd0 && xir.jxx.Ca != 3'd7)
	  	  			tChangeIPSel(caregfile[{1'b0,xir.jxx.Ca}].sel);
	        end
	      end
	      else if (xdj ? (takb && xlc != 64'd0) : takb) begin
			    inv_i();
			    inv_d();
			    inv_x();
					xx <= 4'd4;
			    if (xir.jxx.Ca == 3'd0)
			    	ip.offs <= xJmptgt;
			    else if (xir.jxx.Ca == 3'd7)
			    	ip.offs <= xip.offs + xJmptgt;
			    else
			    	ip.offs <= caregfile[xir.jxx.Ca].offs + xJmptgt;
	    		if (xir.jxx.Ca != 3'd0 && xir.jxx.Ca != 3'd7)
	    			tChangeIPSel(caregfile[{1'b0,xir.jxx.Ca}].sel);
	      end
	    end
	    if (xJmp) begin
	    	if (xdj)
	    		wlc <= xlc - 2'd1;
		  	if (xir.jmp.lk != 2'd0) begin
		    	caregfile[{2'b0,xir.jmp.lk}].offs <= xip.offs + 3'd6;
		    	caregfile[{2'b0,xir.jmp.lk}].sel <= xip.sel;
		  	end
	    	if (xdj ? xlc != 64'd0 : xir.jmp.Ca != 3'd0 && xir.jmp.Ca != 3'd7)	begin // ==0,7 was already done at ifetch
			    inv_i();
			    inv_d();
			    inv_x();
					xx <= 4'd5;
			    if (xir.jmp.Ca==3'd0)
			    	ip.offs <= xJmptgt;
			    else if (xir.jmp.Ca==3'd7)
			    	ip.offs <= xip.offs + xJmptgt;
			    else
		    		ip.offs <= caregfile[{1'b0,xir.jmp.Ca}].offs + xJmptgt;
	    		// Selector changing?
	    		if (xir.jmp.Ca != 3'd0 && xir.jmp.Ca != 3'd7)
	    			tChangeIPSel(caregfile[{1'b0,xir.jmp.Ca}].sel);
	    	end
	  	end
	  	if (xRts) begin
	  		if (xir.rts.lk != 2'd0) begin
			    inv_i();
			    inv_d();
			    inv_x();
					xx <= 4'd6;
		    	ip.offs <= caregfile[{2'b0,xir.rts.lk}].offs + {xir.rts.cnst,1'b0};
		  		// Selector changing?
		  		tChangeIPSel(caregfile[{2'b0,xir.rts.lk}].sel);
	  		end
	  	if (xMtlc)
	  		wlc <= res;
	  	end

			tExMem();

		end	// xval
	end	// advance_x
	else if (advance_w)
		inv_w();
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Writeback stage
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
task tWriteback;
begin
  if (advance_w) begin
		if (wval) begin
			if (|wcause) begin
		  	if (wcause[15])
					// IRQ level remains the same unless external IRQ present
					pmStack <= {pmStack[55:0],2'b0,2'b11,wcause[10:8],1'b0};
				else
					pmStack <= {pmStack[55:0],2'b0,2'b11,pmStack[3:1],1'b0};
				plStack <= {plStack[55:0],8'hFF};
				cause[2'd3] <= wcause & 16'h80FF;
				badaddr[2'd3] <= wbadAddr;
				caregfile[4'h8+istk_depth] <= ip;
				istk_depth <= istk_depth + 2'd1;
				ip.sel <= tvec[2'd3].sel;
				ip.offs <= tvec[2'd3].offs + {omode,6'h00};
				tChangeIPSel(tvec[2'd3].sel);
				inv_i();
				inv_d();
				inv_x();
				xx <= 4'd8;
				inv_w();
				xx <= TRUE;
			end
			else begin
				if (wRti) begin
					if (|istk_depth) begin
						pmStack <= {8'h3E,pmStack[63:8]};
						plStack <= {8'hFF,plStack[63:8]};
						ip.offs <= caregfile[4'h7+istk_depth].offs;	// 8-1
						istk_depth <= istk_depth - 2'd1;
						inv_i();
						inv_d();
						inv_x();
						inv_w();
						tChangeIPSel(caregfile[4'h7+istk_depth].sel);
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
						caregfile[3'd6] <= ip;
						ip.offs <= tvec[2'd3].offs + {omode,6'h00};
						tChangeIPSel(tvec[2'd3].sel);
						inv_i();
						inv_d();
						inv_x();
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
				    regfile[wRt] <= wres;
				    $display("regfile[%d] <= %h", wRt, wres);
				    // Globally enable interrupts after first update of stack pointer.
				    if (wRt==6'd63)
				      gie <= TRUE;
				  end
			  end
			  if (wvmrfwr)
			  	vm_regfile[wRt[2:0]] <= wres;
			  if (wMtlc)
			  	lc <= wres;
			  else if (wwrlc)
			  	lc <= wlc;
			end	// wcause
		end		// wval
  end			// advance_w
end
endtask

// Called to load a new CS descriptor if the CS changes.

task tChangeIPSel;
input Selector sel;
begin
	if (sel != xip.sel) begin
		ip.sel <= sel;
		memreq.func <= MR_LOAD;
		memreq.func2 <= MR_LDDESC;
		memreq.adr <= sel;
		memreq.seg <= sel[23] ? 5'd17 : 5'd31;	// LDT or GDT
		memreq.dat <= 5'd7;		// update CS descriptor cache
		memreq.wr <= TRUE;
		goto (WAIT_MEM1);
	end
end
endtask

task ex_branch;
Address nxt_ip;
begin
    inv_i();
    inv_d();
    inv_x();
    ip <= nxt_ip;
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
			if (regno[4:1]==4'd7)
				case(regno[0])
				1'b0:	res = xip.offs;
				1'b1:	res = xip.sel;
				endcase
			else if (regno[4:1] < 4'd8)
				case(regno[0])
				1'b0:	res = caregfile[regno[4:1]].offs;
				1'b1:	res = caregfile[regno[4:1]].sel;
				endcase
			else
				res = 64'd0;
		CSR_MCA,CSR_HCA,CSR_SCA:
			if (regno[4:1]==4'd7)
				case(regno[0])
				1'b0:	res = xip.offs;
				1'b1:	res = xip.sel;
				endcase
			else
				case(regno[0])
				1'b0:	res = caregfile[regno[4:1]].offs;
				1'b1:	res = caregfile[regno[4:1]].sel;
				endcase
		CSR_MPLSTACK:	res = plStack;
		CSR_MPMSTACK:	res = pmStack;
		CSR_MVSTEP:	res = estep;
		CSR_MVTMP:	res = vtmp;
		CSR_TIME:	res = wc_time;
		CSR_MSTATUS:	res = status[3];
		CSR_MTCB:	res = tcbptr;
//		CSR_DSTUFF0:	res = stuff0;
//		CSR_DSTUFF1:	res = stuff1;
		CSR_MGDT:	res = gdt;
		CSR_MLDT:	res = ldt;
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
		CSR_SEMA:		sema <= val;
		CSR_KEYTBL:	keytbl <= val;
		CSR_KEYS:		keys2[regno[1:0]] <= val;
//		CSR_FSTAT:	fpscr <= val;
		CSR_ASID: 	asid <= val;
		CSR_MBADADDR:	badaddr[regno[13:12]] <= val;
		CSR_CAUSE:	cause[regno[13:12]] <= val;
		CSR_MTVEC:	tvec[regno[1:0]] <= val;
		CSR_UCA:
			if (regno[4:1] < 4'd8)
				case(regno[0])
				1'b0:	caregfile[regno[4:1]].offs <= val;
				1'b1:	caregfile[regno[4:1]].sel <= val;
				endcase
		CSR_MCA,CSR_SCA,CSR_HCA:
			case(regno[0])
			1'b0:	caregfile[regno[4:1]].offs <= val;
			1'b1:	caregfile[regno[4:1]].sel <= val;
			endcase
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
		CSR_MGDT:	gdt <= val;
		CSR_MLDT:	
			if (ldt != val[31:0]) begin
				ldt <= val[31:0];
  			memreq.func <= MR_LOAD;
  			memreq.func2 <= MR_LDDESC;
  			memreq.adr <= val[31:0];
  			memreq.seg <= val[23] ? 5'd17 : 5'd31;	// LDT or GDT
  			memreq.dat <= 5'd17;		// update LDT descriptor cache
  			memreq.wr <= TRUE;
  			goto (WAIT_MEM1);
			end
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
  STO:		$display("STO r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.st.Ra);
  RTS:   	$display("RTS #%d", ir.rts.cnst);
  endcase
end
endtask


endmodule
