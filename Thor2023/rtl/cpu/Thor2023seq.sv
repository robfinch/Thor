// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023seq.sv
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

import Thor2023Pkg::*;
import Thor2023Mmupkg::*;
import wishbone_pkg::*;
import Thor2023_cache_pkg::*;

module Thor2023seq(coreno_i, rst_i, clk_i, bok_i, wbm_req, wbm_resp, rb_i,
	iwbm_req, iwbm_resp, dwbm_req, dwbm_resp,
	snoop_v, snoop_adr, snoop_cid);
parameter CID = 6'd1;
parameter VWID=128;
parameter PCREG = 53;
parameter SCREG = 53;
input value_t coreno_i;
input rst_i;
input clk_i;
input bok_i;
output wb_cmd_request128_t wbm_req;
input wb_cmd_response128_t wbm_resp;
input rb_i;
output wb_cmd_request128_t iwbm_req;
input wb_cmd_response128_t iwbm_resp;
output wb_cmd_request128_t dwbm_req;
input wb_cmd_response128_t dwbm_resp;
input snoop_v;
input address_t snoop_adr;
input [3:0] snoop_cid;

genvar g;
wire clk_g;
assign clk_g = clk_i;

typedef enum logic [3:0] {
	IFETCH = 8'd1,
	DECODE,
	OFETCH,
	EXECUTE,
	MEMORY,
	MEMORY1,
	MEMORY2,
	MEMORY3,
	MEMORY4,
	MEMORY5,
	WRITEBACK
} state_t;
state_t state;

Thor2023Pkg::asid_t pc_asid;
Thor2023Pkg::asid_t data_asid;
address_t pc, opc, pc_o;
value_t asp, ssp, hsp, msp;		// stack pointers
wire ihit;
wire ic_valid;
Thor2023_cache_pkg::ICacheLine ic_line_lo, ic_line_hi;
reg [Thor2023_cache_pkg::ICacheLineWidth*2-1:0] ic_data;

status_reg_t sr;
status_reg_t [15:0] sr_stack;
operating_mode_t omode;
wire mprv = sr.mprv;
wire AppMode = omode==OM_APP;
wire MAppMode = mprv ? sr_stack[0].om==OM_APP : sr.om==OM_APP;

wire ipage_fault;
reg clr_ipage_fault;
wire itlbmiss;
reg clk_itlbmiss;
address_t ptbr;
reg run = 1'b1;
wire vpa_o;
wire vda_o;
wire sr_o;
wire cr_o;
instruction_t ir;
vector_instruction_t vir;
postfix_t postfix1;
postfix_t postfix2;
postfix_t postfix3;
postfix_t postfix4;
postfix_t vpostfix1;
postfix_t vpostfix2;
postfix_t vpostfix3;
postfix_t vpostfix4;
wire [31:0] cmpo;
wire [VWID-1:0] vcmpo;
address_t ea, nea;
reg [7:0] tid;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// CSRs
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg pe = 1'b0;
Thor2023Pkg::asid_t asid;
reg dce;
value_t keys2 [0:1];
reg [23:0] keys [0:7];
always_comb
begin
	keys[0] = keys2[0][ 31: 0];
	keys[1] = keys2[0][ 63:32];
	keys[2] = keys2[0][ 95:64];
	keys[3] = keys2[0][127:96];
	keys[4] = keys2[1][ 31: 0];
	keys[5] = keys2[1][ 63:32];
	keys[6] = keys2[1][ 95:64];
	keys[7] = keys2[1][127:96];
end
value_t tick;
value_t canary;
reg [7:0] cause_code;					// exception cause
Thor2023Pkg::address_t [3:0] tvec;
Thor2023Pkg::address_t [7:0] epc;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire memreq_full;
wire memreq_wack;
memory_arg_t memreq;
memory_arg_t memresp;
reg memresp_fifo_rd;
wire memresp_fifo_empty;
wire memresp_fifo_v;
reg rollback = 1'b0;
reg is_jsr;

regspec_t Ra,Rb,Rc,Rt;
reg rfwr,rfwrg,rfwrv;
value_t res;
reg [VWID-1:0] vres;
reg [VWID/8-1:0] vsel;
value_t rfoa, rfob, rfoc, rfop;
wire [VWID-1:0] rfoav, rfobv, rfocv;
reg [VWID-1:0] shlv;
value_t a, b, c;
reg [VWID-1:0] va, vb, vc;
reg [VWID-1:0] va1, vb1, vc1;
wire [VWID-1:0] vaddo, vcmpo;
value_t imm2;
value_t imm;
value_t vimm2;
value_t vimm;
wire [4:0] imm_inc;
wire [4:0] vimm_inc;
reg predact;
reg [15:0] predbuf;
reg [4:0] predcond;
reg [5:0] predreg;
reg predt;
wire takb;
quad_value_t group_out;
quad_value_t group_in;
reg is_vec;
reg [4:0] bytcnt2;
reg [63:0] sel2;
value_t data2;

always_comb
	omode = sr.om;

always_comb
	pc_asid = asid;
always_comb
	data_asid = asid;

function fnAlignFaultDetect;
input wb_cmd_request512_t req;
begin
	fnAlignFaultDetect = 0;	
	if (req.cache > NON_CACHEABLE)
		case(req.sz)
		Thor2023Pkg::nul:		;		
		Thor2023Pkg::byt:		;
		Thor2023Pkg::wyde: 	if (req.vadr[5:0]==6'h3F) fnAlignFaultDetect = 1;
		Thor2023Pkg::tetra:	if (req.vadr[5:0] >6'h3C) fnAlignFaultDetect = 1;
		Thor2023Pkg::octa:	if (req.vadr[5:0] >6'h38) fnAlignFaultDetect = 1;
		Thor2023Pkg::hexi:	if (req.vadr[5:0] >6'h30) fnAlignFaultDetect = 1;
		default:	if (req.vadr[5:0]!=5'h00) fnAlignFaultDetect = 1;
		endcase
	else
		case(req.sz)
		Thor2023Pkg::nul:		;		
		Thor2023Pkg::byt:		;
		Thor2023Pkg::wyde: 	if (req.vadr[3:0]==4'hF) fnAlignFaultDetect = 1;
		Thor2023Pkg::tetra:	if (req.vadr[3:0] >4'hC) fnAlignFaultDetect = 1;
		Thor2023Pkg::octa:	if (req.vadr[3:0] >4'h8) fnAlignFaultDetect = 1;
		Thor2023Pkg::hexi:	if (req.vadr[3:0] >4'h0) fnAlignFaultDetect = 1;
		default:	if (req.vadr[3:0]!=4'h0) fnAlignFaultDetect = 1;
		endcase
end
endfunction

function fnSpan;
input [2:0] prc;
input wb_address_t adr;
begin
	fnSpan = 0;
	case(prc)
	PRC8:		;
	PRC16: 	if (adr[5:0]==6'h3F) fnSpan = 1;
	PRC32:	if (adr[5:0] >6'h3C) fnSpan = 1;
	PRC64:	if (adr[5:0] >6'h38) fnSpan = 1;
	PRC128:	if (adr[5:0] >6'h30) fnSpan = 1;
	PRCNDX: if (adr[5:0]!=  'd0) fnSpan = 1;
	default:	if (adr[5:0]!=5'h00) fnSpan = 1;
	endcase
end
endfunction

// Decode if the instruction is a vector instruction. One of the vector
// specification bits in the instruction must be set.

function fnIsVector;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_R2:	fnIsVector = ir.any.vec|ir.r2.Vb|ir.r2.Vc;
	OP_FLT2:	fnIsVector = ir.any.vec|ir.f2.Vb|ir.f2.Vc;
	OP_BITFLD:	fnIsVector = ir.any.vec|ir.bf.Vb|ir.bf.Vc;
	OP_CSR:	fnIsVector = ir.any.vec|ir.csr.Vc;
	OP_Bcc:	fnIsVector = 1'b0;
	OP_FBcc:	fnIsVector = 1'b0;
	OP_DBcc:	fnIsVector = 1'b0;
	OP_PFX:	fnIsVector = 1'b0;
	OP_ADDI:	fnIsVector = (ir.any.vec|ir.ri.Vc) & ~ir[31];
	OP_LOAD,OP_LOADZ,OP_STORE:
		if (ir.ls.sz==3'd7)
			fnIsVector = ir.lsn.vec|ir.lsn.Vb|ir.lsn.Vc;
		else
			fnIsVector = ir.ls.vec|ir.ls.Vb;
	default:	fnIsVector = ir.any.vec|ir.r2.Vc;
	endcase
end
endfunction

// Decode if the instruction has a vector mask register. This is used to
// increment the PC by an extra byte so the decode must be simple and fast.

function fnHasMask;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_Bcc:	fnHasMask = 1'b0;
	OP_FBcc:	fnHasMask = 1'b0;
	OP_DBcc:	fnHasMask = 1'b0;
	OP_PFX:	fnHasMask = 1'b0;
	default:	fnHasMask = ir.any.vec;
	endcase
end
endfunction

Thor2023_regfile urf1 
(
	.clk(clk_g),
	.wg(rfwrg),
	.gwa(Ra.num[3:0]),
	.gi(group_in),
	.wr(rfwr),
	.wa(Rt.num), 
	.i(res),
	.gra(Ra.num[3:0]),
	.go(group_out),
	.ra0(Ra.num),
	.ra1(Rb.num),
	.ra2(Rc.num), 
	.ra3(predreg),
	.o0(rfoa),
	.o1(rfob),
	.o2(rfoc),
	.o3(rfop),
	.asp(asp),
	.ssp(ssp),
	.hsp(hsp),
	.msp(msp), 
	.sc(canary),
	.om(omode)
);

Thor2023_vec_regfile
#(
	.WID(VWID)
)
uvrf1
(
	.clk(clk_g),
	.wr(rfwrv),
	.sel(vsel),
	.wa(Rt.num),
	.i(vres),
	.ra0(Ra.num),
	.ra1(Rb.num),
	.ra2(Rc.num),
	.o0(rfoav),
	.o1(rfobv),
	.o2(rfocv)
);


//module Thor2023_biu(
//	rollback, rollback_bitmaps);

always_comb
	wbm_req.cid = 4'd7;
always_comb
	if (wbm_req.we & cr_o)
		wbm_req.csr <= 1'b1;
	else if (!wbm_req.we & sr_o)
		wbm_req.csr <= 1'b1;
	else
		wbm_req.csr <= 1'b0;

Thor2023_biu 
#(
	.CID(CID)
)
ubiu
(
	.rst(rst_i),
	.clk(clk_g),
	.tlbclk(clk_g),
	.clock(1'b0),
	.AppMode(AppMode),
	.MAppMode(MAppMode),
	.omode(omode),
	.bounds_chk(),
	.pe(pe),
	
	.ip_asid(pc_asid),
	.ip(pc),
	.ip_o(pc_o),
	.ihit_o(ihit),
	.ifStall(!run),
	.ic_line_hi(ic_line_hi),
	.ic_line_lo(ic_line_lo),
	.ic_valid(ic_valid),

	.fifoToCtrl_i(memreq),
	.fifoToCtrl_full_o(memreq_full),
	.fifoToCtrl_wack(memreq_wack),
	.fifoFromCtrl_o(memresp),
	.fifoFromCtrl_rd(memresp_fifo_rd),
	.fifoFromCtrl_empty(memresp_fifo_empty),
	.fifoFromCtrl_v(memresp_fifo_v),
//	.bok_i(bok_i),
	.bte_o(wbm_req.bte),
	.blen_o(wbm_req.blen),
	.tid_o(wbm_req.tid),
	.cti_o(wbm_req.cti),
	.seg_o(wbm_req.seg),
//	.vpa_o(vpa_o),
//	.vda_o(vda_o),
	.cyc_o(wbm_req.cyc),
	.stb_o(wbm_req.stb),
	.ack_i(wbm_resp.ack),
	.stall_i(1'b0),
	.next_i(wbm_resp.next),
	.rty_i(wbm_resp.rty),
	.err_i(wbm_resp.err),
	.tid_i(wbm_resp.tid),
	.we_o(wbm_req.we),
	.sel_o(wbm_req.sel),
	.adr_o(wbm_req.padr),
	.dat_i(wbm_resp.dat),
	.dat_o(wbm_req.data1),
	.csr_o(wbm_req.csr),
	.adr_i(wbm_resp.adr),
	.dce(dce),
	.keys(keys),
	.arange(),
	.ptbr(ptbr),
	.rollback(rollback),
	.rollback_bitmaps(),
	.iwbm_req(iwbm_req),
	.iwbm_resp(iwbm_resp),
	.dwbm_req(dwbm_req),
	.dwbm_resp(dwbm_resp),
	.snoop_v(snoop_v),
	.snoop_adr(snoop_adr),
	.snoop_cid(snoop_cid)
);

always_comb
	ic_data = {ic_line_hi.data,ic_line_lo.data};
	
always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	{postfix3,postfix2,postfix1,ir} <= {4{NOP_INSN}};
else begin
	if (state==IFETCH && ihit) begin
		{postfix4,postfix3,postfix2,postfix1,ir} <= ic_data >> {pc_o[4:0],3'b0};
		{vpostfix4,vpostfix3,vpostfix2,vpostfix1,vir} <= ic_data >> {pc_o[4:0],3'b0};
	end
end

always_comb
	is_vec = ir.any.vec;

Thor2023_decode_imm udci1
(
	.ir(ir),
	.ir2(postfix1),
	.ir3(postfix2),
	.ir4(postfix3),
	.ir5(postfix4),
	.imm(imm2),
	.inc(imm_inc)
);

Thor2023_decode_imm udci2
(
	.ir(vir),
	.ir2(vpostfix1),
	.ir3(vpostfix2),
	.ir4(vpostfix3),
	.ir5(vpostfix4),
	.imm(vimm2),
	.inc(vimm_inc)
);

Thor2023_cmp
#(
	.WID(96)
)
ucmp1
(
	.a(a),
	.b(b),
	.o(cmpo)
);

Thor2023_agen uagen1 (
	.ir(ir),
	.b(b),
	.c(c),
	.imm(imm),
	.adr(ea),
	.nxt_adr(nea)
);

Thor2023_eval_branch ube1
(
	.inst(ir),
	.fdm(1'b0),
	.a(a),
	.b(b),
	.takb(takb)
);

Thor2023_vec_add
#(
	.WID(VWID)
)
uvadd1
(
	.ir(ir),
	.Rt(Rt),
	.a(va),
	.b(vb),
	.o(vaddo)
);

/*
Thor2023_vec_cmp
#(
	.WID(VWID)
)
uvcmp1
(
	.a(va),
	.b(vb),
	.o(vcmpo)
);
*/

value_t shl = a << b[6:0];
value_t shli = a << ir.r2.Rb[6:0];
value_t shr = a >> b[6:0];
value_t shri = a >> ir.r2.Rb[6:0];
value_t asr = {{128{a[127]}},a} >> b[6:0];
value_t asri = {{128{a[127]}},a} >> ir.r2.Rb[6:0];
double_value_t rol = {a,a} << b[6:0];
double_value_t roli = {a,a} << ir.r2.Rb[6:0];
double_value_t ror = {a,a} >> b[6:0];
double_value_t rori = {a,a} >> ir.r2.Rb[6:0];

generate begin : gShl
	for (g = 0; g < VWID/8; g = g + 1) begin : gFor
		always_comb
			case(ir.any.sz)
			PRC8:	shlv[g*8+7:g*8] = va[g*8+7:g*8] << vb[g*8+2:g*8];
			PRC16: if (g < VWID/16) shlv[g*16+15:g*16] = va[g*16+15:g*16] << vb[g*16+3:g*16];
			PRC32: if (g < VWID/32) shlv[g*32+31:g*32] = va[g*32+31:g*32] << vb[g*32+4:g*32];
			PRC64: if (g < VWID/64) shlv[g*64+63:g*64] = va[g*64+63:g*64] << vb[g*64+5:g*64];
			PRC128: if (g < VWID/128) shlv[g*128+127:g*128] = va[g*128+127:g*128] << vb[g*128+6:g*128];
			default:	if (g < VWID/128) shlv[g*128+127:g*128] = va[g*128+127:g*128] << vb[g*128+6:g*128];
			endcase
	end
end
endgenerate

generate begin : gInvA
	for (g = 0; g < VWID/8; g = g + 1) begin : gFor
		always_comb
		case(ir.any.sz)
		PRC8:	va1[g*8+7:g*8] = Ra.sign ? -rfoav[g*8+7:g*8] : rfoav[g*8+7:g*8];
		PRC16: if (g < VWID/16) va1[g*16+15:g*16] = Ra.sign ? -rfoav[g*16+15:g*16] : rfoav[g*16+15:g*16];
		PRC32: if (g < VWID/32) va1[g*32+31:g*32] = Ra.sign ? -rfoav[g*32+31:g*32] : rfoav[g*32+31:g*32];
		PRC64: if (g < VWID/64) va1[g*64+63:g*64] = Ra.sign ? -rfoav[g*64+63:g*64] : rfoav[g*64+63:g*64];
		PRC128: if (g < VWID/128) va1[g*+127:g*128] = Ra.sign ? -rfoav[g*128+127:g*128] : rfoav[g*128+127:g*128];
		default: if (g < VWID/128) va1[g*128+127:g*128] = Ra.sign ? -rfoav[g*128+127:g*128] : rfoav[g*128+127:g*128];
		endcase
	end
end
endgenerate

generate begin : gInvB
	for (g = 0; g < VWID/8; g = g + 1) begin : gFor
		always_comb
		case(ir.any.sz)
		PRC8:	vb1[g*8+7:g*8] = Rb.sign ? -rfobv[g*8+7:g*8] : rfobv[g*8+7:g*8];
		PRC16: if (g < VWID/16) vb1[g*16+15:g*16] = Rb.sign ? -rfobv[g*16+15:g*16] : rfobv[g*16+15:g*16];
		PRC32: if (g < VWID/32) vb1[g*32+31:g*32] = Rb.sign ? -rfobv[g*32+31:g*32] : rfobv[g*32+31:g*32];
		PRC64: if (g < VWID/64) vb1[g*64+63:g*64] = Rb.sign ? -rfobv[g*64+63:g*64] : rfobv[g*64+63:g*64];
		PRC128: if (g < VWID/128) vb1[g*128+127:g*128] = Rb.sign ? -rfobv[g*128+127:g*128] : rfobv[g*128+127:g*128];
		default: if (g < VWID/128) vb1[g*128+127:g*128] = Rb.sign ? -rfobv[g*128+127:g*128] : rfobv[g*128+127:g*128];
		endcase
	end
end
endgenerate

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	tReset();
else begin
	tOnce();
	case(state)
	IFETCH:	tIFetch();
	DECODE:	tDecode();
	OFETCH:	tOFetch();
	EXECUTE: tExecute();
	MEMORY: tMemory(state);
	endcase
	$display("===================================================================");
	$display("%d", $time);
	$display("===================================================================");
	$display("pc = %h", pc);
	$display("pfx2:%h pfx1:%h ir: %h", postfix2,postfix1,ir);
end

task tReset;
integer nn;
begin
	for (nn = 0; nn < 16; nn = nn + 1) begin
		sr_stack[nn] <= 'd0;
		sr_stack[nn].om <= OM_MACHINE;
	end
	sr <= 'd0;
	sr.om <= OM_MACHINE;
	pc <= RSTPC;
	opc <= RSTPC;
	asp <= 128'hFFFCFE70;
	ssp <= 128'hFFFCFEF0;
	hsp <= 128'hFFFCFF70;
	msp <= 128'hFFFCFFF0;
	asid <= 'd0;
	tid <= 'd1;
	predbuf <= 16'hFFFF;
	predreg <= 'd0;
	predact <= 'd0;
	memreq <= 'd0;
	Ra <= 'd0;
	Rb <= 'd0;
	Rc <= 'd0;
	Rt <= 'd0;
	a <= 'd0;
	b <= 'd0;
	c <= 'd0;
	va <= 'd0;
	vb <= 'd0;
	vc <= 'd0;
	imm <= 'd0;
	rfwr <= 'd0;
	rfwrg <= 'd0;
	rfwrv <= 'd0;
	res <= 'd0;
	vres <= 'd0;
	group_in <= 'd0;
	memresp_fifo_rd <= 1'b0;
	goto (IFETCH);
end
endtask

task tOnce;
begin
	rfwr <= 1'b0;
	rfwrg <= 1'b0;
	rfwrv <= 1'b0;
	memreq.wr <= 1'b0;
	memresp_fifo_rd <= 1'b0;
end
endtask

task tIFetch;
begin
	opc <= pc;
	if (ihit)
		goto (DECODE);
end
endtask

task tDecode;
begin
	goto (OFETCH);
	// Vector instructions may increment the PC by an additional byte.
	pc <= pc + imm_inc + (fnHasMask(ir) ? 2'd1 : 2'd0);
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		OP_ADD:
			begin
				Ra <= ir.r2.Ra;
				Rb <= ir.r2.Rb;
				Rc <= 6'd56 + ir.lsn.Rc[1:0];
				Rt <= ir.r2.Rt;
			end
		OP_CMP,OP_AND,OP_OR,OP_EOR,OP_MUL,OP_DIV:
			begin
				Ra <= ir.r2.Ra;
				Rb <= ir.r2.Rb;
				Rt <= ir.r2.Rt;
			end	
		default:	;
		endcase
	OP_SHIFT:
		case(ir.r2.func)
		OP_ASL,OP_LSR,OP_LSL,OP_ASR,OP_ROL,OP_ROR:
			begin
				Ra <= ir.r2.Ra;
				Rb <= ir.r2.Rb;
				Rt <= ir.r2.Rt;
			end
		OP_ASLI,OP_LSRI,OP_LSLI,OP_ASRI,OP_ROLI,OP_RORI:
			begin
				Ra <= ir.r2.Ra;
				Rb <= ir.r2.Rb;
				Rt <= ir.r2.Rt;
			end
		default:	;
		endcase
	OP_ADDI:
		begin
			Ra = ir.r2.Ra;
			Rc = 6'd56 + ir.r2.Rb[1:0];
			Rt <= ir.r2.Rt;
		end
	OP_CMPI,OP_ANDI,OP_ORI,OP_EORI,OP_MULI,OP_DIVI,
	OP_CSR:
		begin
			Ra <= ir.r2.Ra;
			Rb <= ir.r2.Rb;
			Rt <= ir.r2.Rt;
		end	
	OP_LOAD,OP_LOADZ:
		begin
			Ra <= 'd0;
			Rb <= ir.ls.Rb;
			Rc <= ir.lsn.Rc;
			Rt <= ir.ls.Rn;
		end
	OP_STORE:
		begin
			Ra <= ir.ls.Rn;
			Rb <= ir.ls.Rb;
			Rc <= ir.lsn.Rc;
			Rt <= 'd0;
		end
	OP_Bcc, OP_DBcc:
		begin
			Ra <= ir.br.Rm;
			Rb <= ir.br.Rn;
		end
	default:	;
	endcase
	imm <= imm2;
end
endtask

task tOFetch;
begin
	goto (EXECUTE);
	predbuf <= {predbuf,2'b11};
	if (Ra.num==PCREG)
		a <= opc;
	else
		a <= Ra.sign ? -rfoa : rfoa;
	if (Rb.num==PCREG)
		b <= opc;
	va <= va1;
	case(ir.any.opcode)
	OP_R2:
		begin
			case(ir.r2.func)
			OP_PRED:
				begin
					predbuf <= {ir[33:29],ir[26:16]};
					predreg <= ir[15:10];
					predcond <= ir[9:5];
					goto (IFETCH);
				end
			default:	;
			endcase
		end
	OP_ADDI:
		begin
			if (ir[31])	// RTS / RTD
				b <= {imm[$bits(value_t)-1:4],4'd0};
			else
				b <= imm;
		end
	OP_MULI,OP_ANDI,OP_ORI,OP_EORI:
		begin
			b <= imm;
		end
	OP_CMPI,OP_DIVI,OP_FCMPI,OP_FDIVI:
		begin
			if (ir[31]) begin
				a <= imm;
				b <= Ra.sign ? -rfoa : rfoa;
			end
			else begin
				a <= Ra.sign ? -rfoa : rfoa;
				b <= imm;
			end
			if (Ra.num==PCREG) begin
				if (ir[31])
					b <= opc;
				else
					a <= opc;
			end
		end
	OP_CSR:
		begin
			b <= {ir[37:32],ir[30:23]};
		end
	OP_Bcc,OP_DBcc:
		begin
			if (postfix1.opcode==OP_PFX)
				b <= imm;
			else
				case(ir.br.cnd)
				BCI,BSI:	b <= Rb.num;
				default:
					if (Rb.num==PCREG)
						b <= opc;
					else
						b <= rfob;
				endcase
		end
	default:
		begin
			if (Rb.num!=PCREG)
				b <= Rb.sign ? -rfob : rfob;
			vb <= vb1;
		end
	endcase
	case(ir.any.opcode)
	OP_LOAD,OP_LOADZ,OP_STORE:
		if (ir.ls.sz==PRCNDX) begin
			if (ir[11:9]==3'd7) begin
				c <= 'd0;
				vc <= 'd0;
			end
			else begin
				c <= rfoc;
				vc <= rfocv;
			end
		end
		else begin
			c <= 'd0;
			vc <= 'd0;
		end
	default:	
		begin
			c <= rfoc;
			vc <= rfocv;
		end
	endcase
	if (ir.any.opcode==OP_STORE && Ra.num==SCREG && !ir.any.vec)
		a <= canary;

	// If predicate is false, ignore instruction
	if (!((predbuf[15:14]==2'b01 &&  rfop[predcond]) || 
			(predbuf[15:14]==2'b10 && ~rfop[predcond]) ||
			(predbuf[15:14]==2'b11) ||
			(predbuf[15:14]==2'b00)))
		goto (IFETCH);
end
endtask

task tExecute;
begin
	// Default action is to go back to IFETCH.
	goto (IFETCH);
	case(ir.any.opcode)
	OP_R2:
		begin
			case(ir.r2.func)
			OP_ADD:	
				begin
					res <= Rt.sign ? -(a + b) : a + b;
					rfwr <= !is_vec;
					if (ir[31])
						pc <= c;
				end
			OP_CMP:	
				begin
					case(ir[33:32])
					2'b00:	res <= {64'd0,cmpo};
					2'b01:	res <= {64'd0,Rt.sign ^ cmpo[0]};
					2'b10:	res <= {64'd0,Rt.sign ^ cmpo[3]};
					2'b11:	res <= {64'd0,Rt.sign ^ cmpo[2]};
					endcase
					rfwr <= !is_vec;
				end
			OP_AND:	begin res <= Rt.sign ? ~(a & b) : a & b; rfwr <= !is_vec; end
			OP_OR:	begin res <= Rt.sign ? ~(a | b) : a | b; rfwr <= !is_vec; end
			OP_EOR:	begin res <= Rt.sign ? ~(a ^ b) : a ^ b; rfwr <= !is_vec; end
			default:	;
			endcase
			case(ir.r2.func)
			OP_ADD:	begin vres <= vaddo; rfwrv <= is_vec; end
			OP_CMP:	begin vres <= {64'd0,vcmpo}; rfwrv <= is_vec; end
			OP_AND:	begin vres <= Rt.sign ? ~(va & vb) : va & vb; rfwrv <= is_vec; end
			OP_OR:	begin vres <= Rt.sign ? ~(va | vb) : va | vb; rfwrv <= is_vec; end
			OP_EOR:	begin vres <= Rt.sign ? ~(va ^ vb) : va ^ vb; rfwrv <= is_vec; end
			OP_JSR:
				begin
					is_jsr <= 1'b1;
					if (ir[31]) begin
						tExLoad(fnSpan(ir.any.sz,ea) ? MR_LOADZ : MR_LOAD);
						goto (MEMORY);
					end
					else
						pc <= ea;
				end
			default:	;
			endcase
		end
	OP_SHIFT:
		case(ir.r2.func)
		OP_ASL,OP_LSL:
			begin
				res <= Rt.sign ? ~shl : shl;
				vres <= Rt.sign ? ~shlv : shlv;
				rfwr <= !is_vec;
				rfwrv <= is_vec;
				goto (IFETCH);
			end
		OP_LSR:					begin res <= Rt.sign ? ~shr : shr; rfwr <= 1'b1; end
		OP_ASR:					begin res <= Rt.sign ? ~asr : asr; rfwr <= 1'b1; end
		OP_ROL:					begin res <= Rt.sign ? ~rol : rol; rfwr <= 1'b1; end
		OP_ROR:					begin res <= Rt.sign ? ~ror : ror; rfwr <= 1'b1; end
		OP_ASLI,OP_LSLI:	begin res <= Rt.sign ? ~shli : shli; rfwr <= 1'b1; end
		OP_LSRI:				begin res <= Rt.sign ? ~shri : shri; rfwr <= 1'b1; end
		OP_ASRI:				begin res <= Rt.sign ? ~asri : asri; rfwr <= 1'b1; end
		OP_ROLI:				begin res <= Rt.sign ? ~roli : roli; rfwr <= 1'b1; end
		OP_RORI:				begin res <= Rt.sign ? ~rori : rori; rfwr <= 1'b1; end
		default:				begin res <= 'd0; end	 //tUnimp();
		endcase
	OP_ADDI:	
		begin
			res <= Rt.sign ? -(a + b) : a + b; rfwr <= !is_vec;
			vres <= vaddo; rfwrv <= is_vec;
			if (ir[31]) begin
				if (ir[26:25]==2'b00)
					pc <= c;
				else
					tRte();
			end
		end
	OP_CMPI:	begin res <= {64'd0,cmpo}; rfwr <= 1'b1; end
	OP_ANDI:
		begin
			res <= Rt.sign ? ~(a & b) : a & b; rfwr <= !is_vec;
			vres <= Rt.sign ? ~(va & vb) : va & vb; rfwrv <= is_vec;
		end
	OP_ORI:		
		begin
			res <= Rt.sign ? ~(a | b) : a | b; rfwr <= !is_vec;
			vres <= Rt.sign ? ~(va | vb) : va | vb; rfwrv <= is_vec;
		end
	OP_EORI:
		begin
			res <= Rt.sign ? ~(a ^ b) : a ^ b; rfwr <= !is_vec;
			vres <= Rt.sign ? ~(va ^ vb) : va ^ vb; rfwrv <= is_vec;
		end
	OP_CSR:
		if (omode >= b[13:12]) begin
			case(b[11:0])
			12'h001:	begin res <= Rt.sign ? ~coreno_i : coreno_i; rfwr <= 1'b1; end
			default:	res <= 'd0;
			endcase
		end
		else begin
			res <= 'd0;
			// tPrivilege();
		end
	OP_JSR:
		begin
			is_jsr <= 1'b1;
			if (ir[31]) begin
				tExLoad(fnSpan(ir.any.sz,ea) ? MR_LOADZ : MR_LOAD);
				goto (MEMORY);
			end
			else
				pc <= ea;
		end
	OP_Bcc, OP_DBcc:	tExBranch();
	OP_LOAD:	begin tExLoad(fnSpan(ir.any.sz,ea) ? MR_LOADZ : MR_LOAD); goto (MEMORY); end
	OP_LOADZ:	begin tExLoad(MR_LOADZ); goto (MEMORY); end
	OP_STORE:	begin tExStore(); goto (MEMORY); end
	default:	;
	endcase
end
endtask

task tMemory;
input state_t state;
begin
	case(state)
	MEMORY:
		begin
			/*
			if (fnAlignFaultDetect(memreq)) begin
				memresp.cause = FLT_ALN;
			end
			else
			*/
			begin
				memreq.wr <= 1'b1;
				if (memreq_wack)
					goto (MEMORY1);
			end
		end
	MEMORY1:
		begin
			if (!memresp_fifo_empty) begin
				memresp_fifo_rd <= 1'b1;
				goto (MEMORY2);
			end
		end
	MEMORY2:	tMemory2();
	MEMORY3:
		begin
			memreq.wr <= 1'b1;
			if (memreq_wack)
				goto (MEMORY4);
		end
	MEMORY4:
		begin
			if (!memresp_fifo_empty) begin
				memresp_fifo_rd <= 1'b1;
				goto (MEMORY5);
			end
		end
	MEMORY5:	tMemory5();
	default:
		begin
			$display("Illegal memory state (%d)", state);
			$finish;
		end
	endcase
end
endtask

task tMemory2;
begin
	if (memresp.load) begin
		if (is_jsr) begin
			if (|sel2) begin
				tExLoad2(MR_LOAD);
				goto (MEMORY3);
			end
			else begin
				if (ir[15])
					pc <= opc + memresp.res;
				else begin
					case(ir.any.sz)
					byt:	pc[7:0] <= memresp.res[7:0];
					wyde: pc[15:0] <= memresp.res[15:0];
					tetra: pc[31:0] <= memresp.res[31:0];
					octa: pc[63:0] <= memresp.res[63:0];
					default:	pc <= memresp.res;
					endcase
				end
				goto (IFETCH);
			end
		end
		else begin
			if (memresp.group)
				rfwrg <= ~|sel2;
			else
				rfwr <= ~|sel2;
			Rt <= memresp.tgt;
			res <= memresp.res;
			group_in <= memresp.res;
			if (memresp.tgt==SCREG && memresp.res[127:0] != canary) begin
				tException(FLT_CANARY);
			end
			if (|sel2) begin
				tExLoad2(ir.any.opcode==OP_LOADZ ? MR_LOADZ : MR_LOAD);
				goto (MEMORY3);
			end
			else
				goto (IFETCH);
		end
	end
	else begin
		if (|sel2) begin
			tExStore2();
			goto (MEMORY3);
		end
		else
			goto (IFETCH);
	end
end
endtask

task tMemory5;
begin
	goto (IFETCH);
	if (memresp.load) begin
		if (is_jsr) begin
			if (ir[15])
				pc <= opc + memresp.res;
			else begin
				case(ir.any.sz)
				byt:	pc[7:0] <= memresp.res[7:0];
				wyde: pc[15:0] <= memresp.res[15:0];
				tetra: pc[31:0] <= memresp.res[31:0];
				octa: pc[63:0] <= memresp.res[63:0];
				default:	pc <= memresp.res;
				endcase
			end
		end
		else begin
			if (memresp.group)
				rfwrg <= 1'b1;
			else
				rfwr <= 1'b1;
			Rt <= memresp.tgt;
			res <= res | (memresp.res << {7'd64-ea[5:0],3'b0});
			group_in <= group_in | (memresp.res << {7'd64-ea[5:0],3'b0});
		end
	end
end
endtask

task tExBranch;
begin
	case(ir.br.cnd)
	RA:
		begin
			rfwr <= 1'b0;
			Rt <= 'd0;
			res <= opc;
//			pc[27:0] <= {ir[23:12],ir[39:24]};
`ifdef PGREL
			pc[13:0] <= ir[37:24];
			pc[$bits(address_t)-1:14] <= opc[$bits(address_t)-1:14] + {{99{ir[23]}},ir[23:11],ir[39:38]};
`else
			pc[$bits(address_t)-1:0] <= opc[$bits(address_t)-1:0] + {{99{ir[23]}},ir[23:11],ir[39:24]};
`endif
		end
	SR:
		begin
			rfwr <= 1'b1;
			Rt <= 6'd56+ir.br.Rn[1:0];
			res <= opc + 4'd5;
`ifdef PGREL			
			pc[13:0] <= ir[37:24];
			pc[$bits(address_t)-1:14] <= opc[$bits(address_t)-1:14] + {{99{ir[23]}},ir[23:11],ir[39:38]};
`else
			pc[$bits(address_t)-1:0] <= opc[$bits(address_t)-1:0] + {{99{ir[23]}},ir[23:11],ir[39:24]};
`endif
		end
	default:
		if (takb) begin
`ifdef PGREL			
			pc[13:0] <= ir[37:24];
			pc[$bits(address_t)-1:14] <= opc[$bits(address_t)-1:14] + {{109{ir[23]}},ir[23:21],ir[39:38]};
`else
			pc[$bits(address_t)-1:0] <= opc[$bits(address_t)-1:0] + {{109{ir[23]}},ir[23:21],ir[39:24]};
`endif			
		end
	endcase
	goto (IFETCH);
end				
endtask


task tMemsz;
input st;
begin
	case(ir.ls.sz)
	PRC8:		
		if (st && ir[39:38]==2'b01) begin
			case(sr.ptrsz)
			2'd0:	memreq.sz <= Thor2023Pkg::tetra;
			2'd1: memreq.sz <= Thor2023Pkg::octa;
			2'd2:	memreq.sz <= Thor2023Pkg::hexi;
			default:	memreq.sz <= Thor2023Pkg::hexi;
			endcase
		end
		else
			memreq.sz <= Thor2023Pkg::byt;
	PRC16:	memreq.sz <= Thor2023Pkg::wyde;
	PRC32:	memreq.sz <= Thor2023Pkg::tetra;
	PRC64:	memreq.sz <= Thor2023Pkg::octa;
	PRC128:	memreq.sz <= Thor2023Pkg::hexi;
	PRCNDX:
		case(ir[11:9])
		PRC8:		memreq.sz <= Thor2023Pkg::byt;
		PRC16:	memreq.sz <= Thor2023Pkg::wyde;
		PRC32:	memreq.sz <= Thor2023Pkg::tetra;
		PRC64:	memreq.sz <= Thor2023Pkg::octa;
		PRC128:	memreq.sz <= Thor2023Pkg::hexi;
		PRCNDX:	memreq.sz <= Thor2023Pkg::vect;
		default:	memreq.sz <= Thor2023Pkg::hexi;
		endcase
	default:	
		memreq.sz <= Thor2023Pkg::hexi;
	endcase
end
endtask

task tMemsel;
input st;
begin
	case(ir.ls.sz)
	PRC8:
		if (st && ir[39:38]==2'b01) begin
			case(sr.ptrsz)
			2'd0:	memreq.sel <= 64'h000F;
			2'd1: memreq.sel <= 64'h00FF;
			2'd2:	memreq.sel <= 64'hFFFF;
			default:	memreq.sel <= 64'h00FF;
			endcase
		end
		else begin
			memreq.sel <= 64'h0001;
			sel2 <= 64'h0000;
		end
	PRC16:	tPRC16();
	PRC32:	tPRC32();
	PRC64:	tPRC64();
	PRC128:	tPRC128();
	PRCNDX:
		case(ir[11:9])
		PRC16:	tPRC16();
		PRC32:	tPRC32();
		PRC64:	tPRC64();
		PRC128:	tPRC128();
		PRCNDX:	tPRC512();
		default:	tPRC128();
		endcase
	default:
		tPRC128();
	endcase
end
endtask

task tExLoad;
input memop_t fn;
begin
	memreq <= 'd0;
	memreq.tid <= tid;
	memreq.tag <= 'd0;
	memreq.thread <= 'd0;
	memreq.omode <= omode;
	memreq.ip <= pc;
	memreq.step <= 'd0;
	memreq.count <= 'd0;
	memreq.adr <= ea; 
	memreq.func <= fn;//ir.any.opcode==OP_LOADZ ? MR_LOADZ : MR_LOAD;
	memreq.load <= 1'b1;
	memreq.store <= 1'b0;
	memreq.need_steps <= 1'b0;
	memreq.v <= 1'b1;
	memreq.empty <= 1'b0;
	memreq.cause <= FLT_NONE;
	tMemsel(0);
	if (ir.ls.sz==3'd7 && ir[11:9]==3'd7)
		memreq.group <= 1'b1;
	memreq.asid <= data_asid;
	if (ir.ls.sz==PRCNDX)
		memreq.adr <= ir[14]==1'b1 ? nea : ea;
	else
		memreq.adr <= ir[38]==1'b1 ? nea : ea;
	memreq.vcadr <= 'd0;
	memreq.cache_type <= 4'(wishbone_pkg::CACHEABLE);
	memreq.res <= 'd0;
	memreq.dchit <= 'd0;
	memreq.cmt <= 'd0;
	tMemsz(0);
	memreq.hit <= 2'b00;
	memreq.mod <= 2'b00;
	memreq.acr <= 4'hF;
	memreq.tlb_access <= 1'b0;
	memreq.ptgram_en <= 1'b0;
	memreq.rgn_en <= 1'b0;
	memreq.pde_en <= 1'b0;
	memreq.pmtram_ena <= 1'b0;
	memreq.wr_tgt <= 1'b1;
	memreq.tgt <= Rt;
	tid <= tid + 2'd1;
end
endtask

task tExLoad2;
input memop_t fn;
begin
	memreq <= 'd0;
	memreq.tid <= tid;
	memreq.tag <= 'd0;
	memreq.thread <= 'd0;
	memreq.omode <= omode;
	memreq.ip <= pc;
	memreq.step <= 'd0;
	memreq.count <= 'd0;
	memreq.adr <= nea; 
	memreq.func <= fn;
	memreq.load <= 1'b1;
	memreq.store <= 1'b0;
	memreq.need_steps <= 1'b0;
	memreq.v <= 1'b1;
	memreq.empty <= 1'b0;
	memreq.cause <= FLT_NONE;
	memreq.sel <= sel2;
	memreq.asid <= asid;
	memreq.vcadr <= 'd0;
	memreq.cache_type <= 4'(wishbone_pkg::CACHEABLE);
	memreq.res <= 'd0;
	memreq.dchit <= 'd0;
	memreq.cmt <= 'd0;
	tMemsz(0);
//	memreq.bycnt <= bytcnt2;
	memreq.hit <= 2'b00;
	memreq.mod <= 2'b00;
	memreq.acr <= 4'hF;
	memreq.tlb_access <= 1'b0;
	memreq.ptgram_en <= 1'b0;
	memreq.rgn_en <= 1'b0;
	memreq.pde_en <= 1'b0;
	memreq.pmtram_ena <= 1'b0;
	memreq.wr_tgt <= 1'b1;
	memreq.tgt <= Rt;
	tid <= tid + 2'd1;
end
endtask

task tExStore;
begin
	memreq <= 'd0;
	memreq.tid <= tid;
	memreq.tag <= 'd0;
	memreq.thread <= 'd0;
	memreq.omode <= omode;
	memreq.ip <= pc;
	memreq.step <= 'd0;
	memreq.count <= 'd0;
	memreq.func <= MR_STORE;

	case(ir.ls.sz)
	PRC8:		
		if (ir[39:38]==2'b01)
			memreq.func <= MR_STOREPTR;
	default:	;
	endcase

	memreq.load <= 1'b0;
	memreq.store <= 1'b1;
	memreq.need_steps <= 1'b0;
	memreq.v <= 1'b1;
	memreq.empty <= 1'b0;
	memreq.cause <= FLT_NONE;
	tMemsel(1);
	memreq.asid <= data_asid;

	if (ir.ls.sz==PRCNDX)
		memreq.adr <= ir[14]==1'b1 ? nea : ea;
	else
		memreq.adr <= ir[38]==1'b1 ? nea : ea;
	
	memreq.vcadr <= 'd0;
	if (ir.ls.sz==3'd7 && ir[11:9]==3'd7) begin
		memreq.group <= 1'b1;
		memreq.res <= {32'd0,group_out};
	end
	else
		memreq.res <= {416'd0,a};
	memreq.cache_type <= 4'(wishbone_pkg::CACHEABLE);
	memreq.dchit <= 'd0;
	memreq.cmt <= 'd0;
	tMemsz(1);
	memreq.hit <= 2'b00;
	memreq.mod <= 2'b00;
	memreq.acr <= 4'hF;
	memreq.tlb_access <= 1'b0;
	memreq.ptgram_en <= 1'b0;
	memreq.rgn_en <= 1'b0;
	memreq.pde_en <= 1'b0;
	memreq.pmtram_ena <= 1'b0;
	memreq.wr_tgt <= 1'b0;
	memreq.tgt <= 'd0;
	tid <= tid + 2'd1;
end
endtask

task tExStore2;
begin
	memreq <= 'd0;
	memreq.tid <= tid;
	memreq.tag <= 'd0;
	memreq.thread <= 'd0;
	memreq.omode <= omode;
	memreq.ip <= pc;
	memreq.step <= 'd0;
	memreq.count <= 'd0;
	memreq.func <= MR_STORE;

	case(ir.ls.sz)
	PRC8:		
		if (ir[39:38]==2'b01)
			memreq.func <= MR_STOREPTR;
	default:	;
	endcase
	memreq.load <= 1'b0;
	memreq.store <= 1'b1;
	memreq.need_steps <= 1'b0;
	memreq.v <= 1'b1;
	memreq.empty <= 1'b0;
	memreq.cause <= FLT_NONE;
	memreq.sel <= sel2;
	memreq.asid <= asid;
	memreq.adr <= nea;
	memreq.vcadr <= 'd0;
	memreq.res <= {416'd0,data2};
	memreq.cache_type <= 4'(wishbone_pkg::CACHEABLE);
	memreq.dchit <= 'd0;
	memreq.cmt <= 'd0;

	tMemsz(1);
	memreq.bytcnt <= bytcnt2;
	memreq.hit <= 2'b00;
	memreq.mod <= 2'b00;
	memreq.acr <= 4'hF;
	memreq.tlb_access <= 1'b0;
	memreq.ptgram_en <= 1'b0;
	memreq.rgn_en <= 1'b0;
	memreq.pde_en <= 1'b0;
	memreq.pmtram_ena <= 1'b0;
	memreq.wr_tgt <= 1'b0;
	memreq.tgt <= 'd0;
	tid <= tid + 2'd1;
end
endtask

task tPRC16;
begin
	memreq.bytcnt <= 8'd2;
	data2 <= a >> (10'd512 - {ea[0],3'b0});
	bytcnt2 <= {7'h0,ea[0]};
	memreq.sel <= 64'h0000000000000003 >> ea[0];
	sel2 <= ~(64'hFFFFFFFFFFFFFFFF << ea[0]);
end
endtask

task tPRC32;
begin
	memreq.bytcnt <= 8'd4;
	data2 <= a >> (10'd512 - {ea[1:0],3'b0});
	bytcnt2 <= {6'h0,ea[1:0]};
	memreq.sel <= 64'h000000000000000F >> ea[1:0];
	sel2 <= ~(64'hFFFFFFFFFFFFFFFF << ea[1:0]);
end
endtask

task tPRC64;
begin
	memreq.bytcnt <= 8'd8;
	data2 <= a >> (10'd512 - {ea[2:0],3'b0});
	bytcnt2 <= {5'h0,ea[2:0]};
	memreq.sel <= 64'h00000000000000FF >> ea[2:0];
	sel2 <= ~(64'hFFFFFFFFFFFFFFFF << ea[2:0]);
end
endtask

task tPRC128;
begin
	memreq.bytcnt <= 8'd16;
	data2 <= a >> (10'd512 - {ea[3:0],3'b0});
	bytcnt2 <= {4'h0,ea[3:0]};
	memreq.sel <= 64'h000000000000FFFF >> ea[3:0];
	sel2 <= ~(64'hFFFFFFFFFFFFFFFF << ea[3:0]);
end
endtask

task tPRC512;
begin
	memreq.bytcnt <= 8'd64;
	data2 <= a >> (10'd512 - {ea[5:0],3'b0});
	bytcnt2 <= {2'h0,ea[5:0]};
	memreq.sel <= 64'hFFFFFFFFFFFFFFFF >> ea[5:0];
	sel2 <= ~(64'hFFFFFFFFFFFFFFFF << ea[5:0]);
end
endtask

task tException;
input [7:0] c;
integer j;
begin
	cause_code <= c;
	for (j = 1; j < 8; j = j + 1)
		sr_stack[j] <= sr_stack[j-1];
	sr_stack[0] <= sr;
	for (j = 1; j < 8; j = j + 1)
		epc[j] <= epc[j-1];
	epc[0] <= pc;
	pc <= {tvec[3][$bits(Thor2023Pkg::address_t)-1:8],omode,6'h0};
	goto (IFETCH);
end
endtask

task tRte;
integer j;
begin
	if (ir[6:5]==2'd1) begin
		sr <= sr_stack[0];
		for (j = 0; j < 7; j = j + 1)
			sr_stack[j] <= sr_stack[j+1];
		pc <= epc[0] + ir[38:32];
		for (j = 0; j < 7; j = j + 1)
			epc[j] <= epc[j+1];
		epc[7] <= RSTPC;
	end
	// Two up level return
	else if (ir[6:5]==2'd2) begin
		sr <= sr_stack[1];
		for (j = 0; j < 6; j = j + 1)
			sr_stack[j] <= sr_stack[j+2];
		pc <= epc[1] + ir[38:32];
		for (j = 0; j < 6; j = j + 1)
			epc[j] <= epc[j+2];
		epc[6] <= RSTPC;
		epc[7] <= RSTPC;
	end
	rfwr <= 1'b1;
	res <= a + {ir[30:27],4'h0};
	goto (IFETCH);
end
endtask

task goto;
input state_t nst;
begin
	state <= nst;
end
endtask

endmodule
