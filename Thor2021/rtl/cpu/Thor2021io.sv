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

wire [1:0] omode;
wire [1:0] memmode;
wire UserMode, SupervisorMode, HypervisorMode, MachineMode;
wire MUserMode;
reg gie;
Instruction mir,wir;
Value regfile [0:63];
Value sp [0:31];
Value lc;
Address caregfile [0:15];

// Instruction fetch stage vars
reg ival;
reg [15:0] icause;
Instruction insn;
wire advance_i;
Address ip;
wire ipredict_taken;
wire ihit;
wire [639:0] ic_line;
wire [3:0] ilen;
wire btb_hit;
Address btb_tgt;
Address next_ip;
wire run;

// Decode stage vars
reg dval;
reg [15:0] dcause;
Instruction ir;
Address dip;
wire advance_d;
reg [3:0] dlen;
DecodeOut deco;
reg dpredict_taken;
wire [5:0] Ra = deco.Ra;
wire [5:0] Rb = deco.Rb;
wire [5:0] Rc = deco.Rc;
wire [5:0] Rt = deco.Rt;
wire [1:0] Tb = deco.Tb;
wire [1:0] Tc = deco.Tc;
wire dAddi = deco.addi;
wire dld = deco.ld;
wire dst = deco.st;
Value rfoa, rfob, rfoc;
reg [63:0] dlc;

// Execute stage vars
reg xval;
reg [15:0] xcause;
Address xbadAddr;
Instruction xir;
Address xip;
reg [3:0] xlen;
wire advance_x;
reg [5:0] xRt,xRa,xRb,xRc,wRt,tRt;
reg [2:0] xCat;
Value xa,xb,xc;
Value imm;
reg [2:0] xSc;
wire takb;
reg xpredict_taken;
reg xJmp, xJmptgt;
reg xJxx;
reg xdj;
reg xRts, xRti;
reg xRex;
reg xIsMultiCycle;
reg xLdz;
reg xrfwr;
reg xcarfwr;
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
reg xCsr;
reg xMtlc;
reg xwrlc;
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

// Writeback stage vars
reg wval;
Instruction wir;
reg [15:0] wcause;
wire advance_w;
reg wrfwr;
reg [5:0] wRt;
reg wCsr;
reg wRti;
reg wRex;
reg wMtlc;
reg wwrlc;
reg [63:0] wlc;
Value wa;
Value wres;


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
if (Ra==6'd0 && (dAddi | dld | dst))
  rfoa = {VALUE_SIZE{1'b0}};
else if (Ra==xRt && xval && xrfwr)
  rfoa = res;
else if (Ra==wRt && wval && wrfwr)
	rfoa = wres;
else
  case(Ra)
  6'd63:  rfoa = sp [{omode,ilvl}];
  default:    rfoa = regfile[Ra];
  endcase

always_comb
if (Tb[1])
	rfob = {{57{Tb[0]}},Tb[0],Rb};
else if (Rb==xRt && xval && xrfwr)
  rfob = res;
else if (Rb==wRt && wval && wrfwr)
	rfob = wres;
else
  case(Rb)
  6'd63:  rfob = sp [{omode,ilvl}];
  default:    rfob = regfile[Rb];
  endcase

always_comb
if (Tc[1])
	rfoc = {{57{Tc[0]}},Tc[0],Rc};
else if (Rc==xRt && xval && xrfwr)
  rfoc = res;
else if (Rc==wRt && wval && wrfwr)
	rfoc = wres;
else
  case(Rc)
  6'd63:  rfoc = sp [{omode,ilvl}];
  default:    rfoc = regfile[Rc];
  endcase

always_comb
	if (xMtlc && xval && xrfwr)
		dlc = res;
	else if (xwrlc && xval)
		dlc = xlc;
	else if (wMtlc && wres && wrfwr)
		dlc = wres;
	else if (wwrlc && wval)
		dlc = wlc;
	else
		dlc = lc;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute stage combinational logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Thor2021_eval_branch ube (xir, xa, xb, takb);

wire [6:0] cntlz_out;
cntlz64 uclz(xir.r1.func[0] ? ~xa : xa, cntlz_out);

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
	MTLC:			res2 <= xa;
	MFLC:			res2 <= xlc;
	default:	res2 <= 64'd0;
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
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX:
							res2 = memresp.res;
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
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

assign run = ihit && (state==RUN);
assign advance_w = run;
assign advance_x = (advance_w | ~wval) & ~xIsMultiCycle & run;
assign advance_d = (advance_x | ~xval) & ihit;
assign advance_i = (advance_d | ~dval) & ihit;

always_ff @(posedge clk_g)
if (rst_i) begin
	state <= RESTART1;
	ld_time <= FALSE;
	wval <= INV;
	xval <= INV;
	dval <= INV;
	ival <= INV;
	xIsMultiCycle <= FALSE;
	xSeg <= 3'd0;
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
end
else begin
	memreq.wr <= FALSE;
	if (ld_time==TRUE && wc_time_dat==wc_time)
		ld_time <= FALSE;
	if (clr_wc_time_irq && !wc_time_irq)
		clr_wc_time_irq <= FALSE;
case (state)
RESTART1:
	begin
		memresp_fifo_rd <= FALSE;
		gdt <= 64'hFFFFFFFFFFFFFFC0;	// startup table (bit 75 to 12)
		ip.offs <= 32'hFFFD0000;
		ip.sel <= 32'hFF000007;				// entry 7 of the GDT
		gie <= FALSE;
		pmStack <= 64'h3e3e3e3e3e3e3e3e;	// Machine mode, irq level 7, ints disabled
		plStack <= 64'hffffffffffffffff;	// PL = 255
		istk_depth <= 4'd1;
		wval <= INV;
		xval <= INV;
		dval <= INV;
		ival <= INV;
		lc <= 64'd0;
		goto(RESTART2);
	end
RESTART2:
	begin
		goto(RUN);
	end
RUN:
	begin
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Instruction Fetch stage
  // We want decodes in the IFETCH stage to be fast so they don't appear
  // on the critical path. Keep the decodes to a minimum.
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	if (advance_i) begin
		ival <= VAL;
		ip <= next_ip;
		if (insn.jmp.Ca==3'd0 && (insn.any.opcode==JMP || insn.any.opcode==DJMP))
			ip.offs <= {{30{insn.jmp.Tgthi[15]}},insn.jmp.Tgthi,insn.jmp.Tgtlo,1'b0};
		else if (insn.jmp.Ca==3'd7 && (insn.any.opcode==JMP || insn.any.opcode==DJMP))
			ip.offs <= ip.offs + {{30{insn.jmp.Tgthi[15]}},insn.jmp.Tgthi,insn.jmp.Tgtlo,1'b0};
		else if (btbe & btb_hit)
			ip <= btb_tgt;
		dlen <= ilen;
		dval <= ival;
		ir <= insn;
		dpredict_taken <= ipredict_taken;
		dcause <= icause;
		if (irq_i > pmStack[3:1] && gie && !is_prefix(insn.any.opcode))
			icause <= 16'h8000|icause_i|(irq_i << 4'd8);
		else if (wc_time_irq)
			icause <= 16'h8000|FLT_TMR;
		else if (insn.any.opcode==BRK)
			icause <= FLT_BRK;
	end
	// Wait for cache load
	else begin
		ip <= ip;
		if (advance_d)
			inv_d();
	end	

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Register fetch and decode stage
  // Much of the decode is done above by combinational logic outside of the
  // clock domain.
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
		xCat <= deco.Cat;
		xip <= ip;
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
		xSeg <= deco.seg;
		xTlb <= deco.tlb;
		xIsMultiCycle <= deco.multi_cycle;
		xrfwr <= deco.rfwr;
		xcarfwr <= deco.carfwr;
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
		xcause <= dcause;
		xpredict_taken <= dpredict_taken;
	end
	else if (advance_x)
		inv_x();

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Execute stage
  // If the execute stage has been invalidated it doesn't do anything. 
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	if (advance_x) begin
		wval <= xval;
		wir <= xir;
		wRt <= xRt;
		wrfwr <= xrfwr;
		wres <= res;
		wlc <= xlc;
		wCsr <= xCsr;
		wRti <= xRti;
		wRex <= xRex;
		wMtlc <= xMtlc;
		wwrlc <= xwrlc;
		wa <= xa;
    if (xJxx) begin
    	if (xdj)
    		wlc = xlc - 2'd1;
    	if (ir.jxx.lk != 2'd0) begin
	    	caregfile[{1'b0,ir.jxx.lk}].offs <= ip.offs + 3'd6;
	    	caregfile[{1'b0,ir.jxx.lk}].sel <= ip.sel;
    	end
      if (bpe) begin
        if (xpredict_taken && !(xdj ? takb && xlc != 64'd0 : takb)) begin
			    ival <= INV;
			    inv_d();
			    inv_x();
          ip.offs <= xip.offs + 3'd6;
          // Was selector changed? If so change it back.
	    		if (xip.sel != ip.sel) begin
	    			ip.sel <= xip.sel;
	    			memreq.func <= MR_LOAD;
	    			memreq.func2 <= MR_LDDESC;
	    			memreq.adr <= xip.sel;
	    			memreq.seg <= xip.sel[23] ? 5'd17 : 5'd31;	// LDT or GDT
	    			memreq.dat <= 5'd7;		// update CS descriptor cache
	    			memreq.wr <= TRUE;
	    			goto (WAIT_MEM1);
	    		end
        end
        else if (!xpredict_taken && (xdj ? takb && xlc != 64'd0 : takb)) begin
			    ival <= INV;
			    inv_d();
			    inv_x();
			    if (xir.jxx.Ca == 3'd0)
			    	ip.offs <= xJmptgt;
			    else if (xir.jxx.Ca == 3'd7)
			    	ip.offs <= ip.offs + xJmptgt;
			    else
			    	ip.offs <= caregfile[xir.jmp.Ca].offs + xJmptgt;
	    		if (caregfile[xir.jmp.Ca].sel != ip.sel && xir.jmp.Ca != 3'd0 && xir.jmp.Ca != 3'd7) begin
	    			ip.sel <= caregfile[xir.jmp.Ca].sel;
	    			memreq.func <= MR_LOAD;
	    			memreq.func2 <= MR_LDDESC;
	    			memreq.adr <= caregfile[xir.jmp.Ca].sel;
	    			memreq.seg <= caregfile[xir.jmp.Ca].sel[23] ? 5'd17 : 5'd31;	// LDT or GDT
	    			memreq.dat <= 5'd7;		// update CS descriptor cache
	    			memreq.wr <= TRUE;
	    			goto (WAIT_MEM1);
	    		end
        end
      end
      else if (xdj ? (takb && xlc != 64'd0) : takb) begin
		    ival <= INV;
		    inv_d();
		    inv_x();
		    if (xir.jxx.Ca == 3'd0)
		    	ip.offs <= xJmptgt;
		    else if (xir.jxx.Ca == 3'd7)
		    	ip.offs <= ip.offs + xJmptgt;
		    else
		    	ip.offs <= caregfile[xir.jmp.Ca].offs + xJmptgt;
    		if (caregfile[xir.jmp.Ca].sel != ip.sel && xir.jmp.Ca != 3'd0 && xir.jmp.Ca != 3'd7) begin
    			ip.sel <= caregfile[xir.jmp.Ca].sel;
    			memreq.func <= MR_LOAD;
    			memreq.func2 <= MR_LDDESC;
    			memreq.adr <= caregfile[xir.jmp.Ca].sel;
    			memreq.seg <= caregfile[xir.jmp.Ca].sel[23] ? 5'd17 : 5'd31;	// LDT or GDT
    			memreq.dat <= 5'd7;		// update CS descriptor cache
    			memreq.wr <= TRUE;
    			goto (WAIT_MEM1);
    		end
      end
    end
    if (xJmp) begin
    	if (xdj)
    		wlc = xlc - 2'd1;
	  	if (ir.jxx.lk != 2'd0) begin
	    	caregfile[{1'b0,ir.jxx.lk}].offs <= ip.offs + 3'd6;
	    	caregfile[{1'b0,ir.jxx.lk}].sel <= ip.sel;
	  	end
    	if (xir.jmp.Ca != 3'd0 && xir.jmp.Ca != 3'd7)	begin // ==0,7 was already done at ifetch
		    ival <= INV;
		    inv_d();
		    inv_x();
	    	ip.offs <= caregfile[xir.jmp.Ca].offs + xJmptgt;
    		// Selector changing?
    		if (caregfile[xir.jmp.Ca].sel != ip.sel) begin
    			ip.sel <= caregfile[xir.jmp.Ca].sel;
    			memreq.func <= MR_LOAD;
    			memreq.func2 <= MR_LDDESC;
    			memreq.adr <= caregfile[xir.jmp.Ca].sel;
    			memreq.seg <= caregfile[xir.jmp.Ca].sel[23] ? 5'd17 : 5'd31;	// LDT or GDT
    			memreq.dat <= 5'd7;		// update CS descriptor cache
    			memreq.wr <= TRUE;
    			goto (WAIT_MEM1);
    		end
    	end
  	end
  	if (xRts) begin
  		if (xir.rts.lk != 2'd0) begin
		    ival <= INV;
		    inv_d();
		    inv_x();
	    	ip.offs <= caregfile[{1'b0,xir.rts.lk}].offs + {xir.rts.cnst,1'b0};
	  		// Selector changing?
	  		if (caregfile[xir.rts.lk].sel != ip.sel) begin
    			ip.sel <= caregfile[{1'b0,xir.rts.lk}].sel;
	  			memreq.func <= MR_LOAD;
	  			memreq.func2 <= MR_LDDESC;
	  			memreq.adr <= caregfile[xir.rts.lk].sel;
	  			memreq.seg <= caregfile[xir.rts.lk].sel[23] ? 5'd17 : 5'd31;	// LDT or GDT
	  			memreq.dat <= 5'd7;		// update CS descriptor cache
	  			memreq.wr <= TRUE;
	  			goto (WAIT_MEM1);
	  		end
  		end
  	if (xMtlc)
  		wlc <= res;
  	end

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
    	memreq.adr <= xa + imm;
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
    	memreq.adr <= siea;
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
    	memreq.adr <= xa + imm;
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
    	memreq.adr <= siea;
    	memreq.dat <= xc;
    	memreq.seg <= {2'd0,xSeg};
    	memreq.wr <= TRUE;
    	goto (WAIT_MEM1);
    end
    else if (xTlb) begin
    	memreq.tid <= tid;
    	tid <= tid + 2'd1;
    	memreq.func <= MR_TLB;
    	memreq.func2 <= MR_STO;
    	memreq.sel <= 16'h00FF;
    	memreq.adr <= xa;
    	memreq.dat <= xb;
    	memreq.seg <= {2'd0,3'd0};
    	memreq.wr <= TRUE;
    	goto (WAIT_MEM1);
  	end
	end
	else if (advance_w)
		inv_w();

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Writeback stage
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  if (advance_w) begin
		if (|wcause) begin
			// IRQ level remains the same unless external IRQ present
			if (wcause[15])
				pmStack <= {pmStack[55:0],2'b0,2'b11,wcause[10:8],1'b0};
			else
				pmStack <= {pmStack[55:0],2'b0,2'b11,pmStack[3:1],1'b0};
			plStack <= {plStack[55:0],8'hFF};
			cause[2'd3] <= wcause;
			caregfile[4'h8+istk_depth] <= ip;
			istk_depth <= istk_depth + 2'd1;
			ip.sel <= tvec[2'd3].sel;
			ip.offs <= tvec[2'd3].offs + {omode,6'h00};
			inv_i();
			inv_d();
			inv_x();
			inv_w();
		end
		else if (wval) begin
	    if (wCsr)
	      case(wir.csr.op)
	      3'd1:   tWriteCSR(wa,wir.csr.regno);
	      3'd2:   tSetbitCSR(wa,wir.csr.regno);
	      3'd3:   tClrbitCSR(wa,wir.csr.regno);
	      default:	;
	      endcase
			if (wRti) begin
				if (|istk_depth) begin
					pmStack <= {8'h3E,pmStack[63:8]};
					plStack <= {8'hFF,plStack[63:8]};
					ip <= caregfile[4'h7+istk_depth];	// 8-1
					istk_depth <= istk_depth - 2'd1;
					inv_i();
					inv_d();
					inv_x();
					inv_w();
				end
			end
			if (wRex) begin
				if (omode <= wir[10:9]) begin
					pmStack <= {pmStack[55:0],2'b0,2'b11,pmStack[3:1],1'b0};
					plStack <= {plStack[55:0],8'hFF};
					cause[2'd3] <= FLT_PRIV;
					caregfile[3'd6] <= ip;
					ip.sel <= tvec[2'd3].sel;
					ip.offs <= tvec[2'd3].offs + {omode,6'h00};
					inv_i();
					inv_d();
					inv_x();
					inv_w();
				end
				else begin
					pmStack[2:1] <= wir[10:9];	// omode
				end
			end
			// Register file update
		  if (wrfwr) begin
		    case(wRt)
		    6'd63:  sp[{omode,ilvl}] <= {wres[63:3],3'h0};
		    endcase
		    regfile[wRt] <= wres;
		    $display("regfile[%d] <= %h", wRt, wres);
		    // Globally enable interrupts after first update of stack pointer.
		    if (wRt==6'd63)
		      gie <= TRUE;
		  end
		  if (wMtlc)
		  	lc <= wres;
		  else if (wwrlc)
		  	lc <= wlc;
		end
  end
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
			if (memresp.tid == memreq.tid) begin
				if (memreq.func==MR_LOAD || memreq.func==MR_LOADZ) begin
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
    goto(INVnRUN2);
  end
INVnRUN2:
  begin
    inv_x();
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

task inv_i;
begin
  ival <= INV;
end
endtask

task inv_d;
begin
  dval <= INV;
end
endtask

task inv_x;
begin
  xval <= INV;
end
endtask

task inv_w;
begin
  wval <= INV;
end
endtask

task ex_branch;
Address nxt_ip;
begin
    ival <= INV;
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
		CSR_MCA:
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
		CSR_MCA:
			if (regno[4:1] != 4'd7)
				case(regno[0])
				1'b0:	caregfile[regno[4:1]].offs = val;
				1'b1:	caregfile[regno[4:1]].sel = val;
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
