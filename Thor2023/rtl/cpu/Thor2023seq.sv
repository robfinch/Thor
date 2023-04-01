import Thor2023Pkg::*;
import Thor2023Mmupkg::*;
import wishbone_pkg::*;

module Thor2023seq(coreno_i, rst_i, clk_i, bok_i, wbm_req, wbm_resp, rb_i,
	iwbm_req, iwbm_resp, dwbm_req, dwbm_resp,
	snoop_v, snoop_adr, snoop_cid);
input [95:0] coreno_i;
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


wire clk_g;
assign clk_g = clk_i;

typedef enum logic [3:0] {
	IFETCH = 8'd1,
	DECODE,
	OFETCH,
	EXECUTE,
	MEMORY,
	MEMORY2,
	WRITEBACK
} state_t;
state_t state;

address_t pc, opc, pc_o;
address_t asp, ssp, hsp, msp;		// stack pointers
wire ihit;
wire ihite, ihito;
wire ic_valid;
wire [$bits(address_t)-1:6] ic_tage;
wire [$bits(address_t)-1:6] ic_tago;
ICacheLine ic_line_lo, ic_line_hi;
reg [ICacheLineWidth*2-1:0] ic_data;

status_reg_t [7:0] sr_stack;
status_reg_t sr;
operating_mode_t omode = sr.om;
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
instruction_t postfix1;
instruction_t postfix2;
instruction_t postfix3;
wire [31:0] cmpo;
address_t ea;
reg [7:0] tid;

// CSRs
reg pe = 1'b0;
reg [7:0] asid;
reg dce;
reg [95:0] keys2 [0:1];
reg [23:0] keys [0:7];
always_comb
begin
	keys[0] = keys2[0][23:0];
	keys[1] = keys2[0][47:24];
	keys[2] = keys2[0][71:48];
	keys[3] = keys2[0][95:72];
	keys[4] = keys2[1][23:0];
	keys[5] = keys2[1][47:24];
	keys[6] = keys2[1][71:48];
	keys[7] = keys2[1][95:72];
end

wire memreq_full;
wire memreq_wack;
memory_arg_t memreq;
memory_arg_t memresp;
reg memresp_fifo_rd;
wire memresp_fifo_empty;
wire memresp_fifo_v;
reg rollback = 1'b0;

regspec_t Ra,Rb,Rc,Rt;
reg rfwr,rfwrg;
reg [95:0] res;
wire [95:0] rfoa, rfob, rfoc, rfop;
reg [95:0] a, b, c;
wire [95:0] imm2;
reg [95:0] imm;
wire [4:0] imm_inc;
reg predact;
reg [15:0] predbuf;
reg [4:0] predcond;
reg [5:0] predreg;
reg predt;
wire takb;
wire [511:0] group_out;
reg [511:0] group_in;

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
	.pc(pc),
	.om(omode)
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

Thor2023_biu ubiu
(
	.rst(rst_i),
	.clk(clk_g),
	.tlbclk(clk_g),
	.clock(1'b0),
	.AppMode(AppMode),
	.MAppMode(MAppMode),
	.omode(omode),
//	.ASID(asid),
	.bounds_chk(),
	.pe(pe),
	.ip(pc),
	.ip_o(pc_o),
	.ihit_o(ihit),
	.ihite(ihite),
	.ihito(ihito),
	.ifStall(!run),
	.ic_line_hi(ic_line_hi),
	.ic_line_lo(ic_line_lo),
	.ic_valid(ic_valid),
	.ic_tage(ic_tage),
	.ic_tago(ic_tago),
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
	if (state==IFETCH && ihit)
		{postfix3,postfix2,postfix1,ir} <= ic_data >> {pc[4:0],3'b0};
end

Thor2023_decode_imm udci1
(
	.ir(ir),
	.ir2(postfix1),
	.ir3(postfix2),
	.ir4(postfix3),
	.imm(imm2),
	.inc(imm_inc)
);

Thor2023_cmp ucmp1
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
	.adr(ea)
);

Thor2023_eval_branch ube1
(
	.inst(ir),
	.fdm(1'b0),
	.a(a),
	.b(b),
	.takb(takb)
);

wire [95:0] shl = a << b[6:0];
wire [95:0] shli = a << ir.r2.Rb[6:0];
wire [95:0] shr = a >> b[6:0];
wire [95:0] shri = a >> ir.r2.Rb[6:0];
wire [95:0] asr = {{95{a[95]}},a} >> b[6:0];
wire [95:0] asri = {{95{a[95]}},a} >> ir.r2.Rb[6:0];
wire [191:0] rol = {a,a} << b[6:0];
wire [191:0] roli = {a,a} << ir.r2.Rb[6:0];
wire [191:0] ror = {a,a} >> b[6:0];
wire [191:0] rori = {a,a} >> ir.r2.Rb[6:0];

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	tReset();
else begin
	tOnce();
	case(state)
	IFETCH:	tIFetch();
	DECODE:	tDecode();
	OFETCH:	tOFetch();
	EXECUTE:
		begin
			case(ir.any.opcode)
			OP_R2:
				case(ir.r2.func)
				OP_ADD:	begin res <= Rt.sign ? -(a + b) : a + b; rfwr <= 1'b1; goto (IFETCH); end
				OP_CMP:	begin res <= {64'd0,cmpo}; rfwr <= 1'b1; goto (IFETCH); end
				OP_AND:	begin res <= Rt.sign ? ~(a & b) : a & b; rfwr <= 1'b1; goto (IFETCH); end
				OP_OR:	begin res <= Rt.sign ? ~(a | b) : a | b; rfwr <= 1'b1; goto (IFETCH); end
				OP_EOR:	begin res <= Rt.sign ? ~(a ^ b) : a ^ b; rfwr <= 1'b1; goto (IFETCH); end
				default:	;
				endcase
			OP_SHIFT:
				case(ir.r2.func)
				OP_ASL,OP_LSL:	begin res <= Rt.sign ? ~shl : shl; rfwr <= 1'b1; goto (IFETCH); end
				OP_LSR:					begin res <= Rt.sign ? ~shr : shr; rfwr <= 1'b1; goto (IFETCH); end
				OP_ASR:					begin res <= Rt.sign ? ~asr : asr; rfwr <= 1'b1; goto (IFETCH); end
				OP_ROL:					begin res <= Rt.sign ? ~rol : rol; rfwr <= 1'b1; goto (IFETCH); end
				OP_ROR:					begin res <= Rt.sign ? ~ror : ror; rfwr <= 1'b1; goto (IFETCH); end
				OP_ASLI,OP_LSLI:	begin res <= Rt.sign ? ~shli : shli; rfwr <= 1'b1; goto (IFETCH); end
				OP_LSRI:				begin res <= Rt.sign ? ~shri : shri; rfwr <= 1'b1; goto (IFETCH); end
				OP_ASRI:				begin res <= Rt.sign ? ~asri : asri; rfwr <= 1'b1; goto (IFETCH); end
				OP_ROLI:				begin res <= Rt.sign ? ~roli : roli; rfwr <= 1'b1; goto (IFETCH); end
				OP_RORI:				begin res <= Rt.sign ? ~rori : rori; rfwr <= 1'b1; goto (IFETCH); end
				default:				begin res <= 'd0; goto (IFETCH); end	 //tUnimp();
				endcase
			OP_ADDI:	begin res <= Rt.sign ? -(a + b) : a + b; rfwr <= 1'b1; goto (IFETCH); end
			OP_CMPI:	begin res <= {64'd0,cmpo}; rfwr <= 1'b1; goto (IFETCH); end
			OP_ANDI:	begin res <= Rt.sign ? ~(a & b) : a & b; rfwr <= 1'b1; goto (IFETCH); end
			OP_ORI:		begin res <= Rt.sign ? ~(a | b) : a | b; rfwr <= 1'b1; goto (IFETCH); end
			OP_EORI:	begin res <= Rt.sign ? ~(a ^ b) : a ^ b; rfwr <= 1'b1; goto (IFETCH); end
			OP_CSR:
				if (omode >= b[13:12]) begin
					goto (IFETCH);
					case(b[11:0])
					12'h001:	begin res <= Rt.sign ? ~coreno_i : coreno_i; rfwr <= 1'b1; goto (IFETCH); end
					default:	res <= 'd0;
					endcase
				end
				else begin
					res <= 'd0;
					// tPrivilege();
					goto (IFETCH);
				end
			OP_Bcc:	tExBranch();
			OP_LOAD,OP_LOADZ:
				begin
					memreq <= 'd0;
					memreq.tid <= tid;
					memreq.tag <= 'd0;
					memreq.thread <= 'd0;
					memreq.omode <= omode;
					memreq.ip <= pc;
					memreq.step <= 'd0;
					memreq.count <= 'd0;
					memreq.wr <= 1'b1;
					memreq.adr <= ea; 
					memreq.func <= ir.any.opcode==OP_LOADZ ? MR_LOADZ : MR_LOAD;
					case(ir.ls.sz)
					PRC8:		memreq.func2 <= MR_LDB;
					PRC16:	memreq.func2 <= MR_LDW;
					PRC32:	memreq.func2 <= MR_LDT;
					PRC64:	memreq.func2 <= MR_LDO;
					PRC24:	memreq.func2 <= MR_LDC;
					PRC40:	memreq.func2 <= MR_LDP;
					PRC96:	memreq.func2 <= MR_LDN;
					default:
						begin
							if (ir[39])
								case(sr.ptrsz)
								2'd0:	memreq.func2 <= MR_LDT;
								2'd1: memreq.func2 <= MR_LDO;
								2'd2:	memreq.func2 <= MR_LDN;
								default:	memreq.func2 <= MR_LDO;
								endcase
							else
								memreq.func2 <= MR_LDN;
						end
					endcase
					memreq.load <= 1'b1;
					memreq.store <= 1'b0;
					memreq.need_steps <= 1'b0;
					memreq.v <= 1'b1;
					memreq.empty <= 1'b0;
					memreq.cause <= FLT_NONE;
					case(ir.ls.sz)
					PRC8:		memreq.sel <= 16'h0001;
					PRC16:	memreq.sel <= 16'h0003;
					PRC32:	memreq.sel <= 16'h000F;
					PRC64:	memreq.sel <= 16'h00FF;
					PRC24:	memreq.sel <= 16'h0007;
					PRC40:	memreq.sel <= 16'h001F;
					PRC96:	memreq.sel <= 16'h0FFF;
					default:
						if (ir[39])
							case(sr.ptrsz)
							2'd0:	memreq.sel <= 64'h000F;
							2'd1:	memreq.sel <= 64'h00FF;
							2'd2:	memreq.sel <= 64'h0FFF;
							default:	memreq.sel <= 16'h00FF;
							endcase
						else
							memreq.sel <= 64'h0FFFFFFFFFFFFFFF;
					endcase
					if (ir.ls.sz==3'd7 && ir[39])
						memreq.group <= 1'b1;
					memreq.asid <= asid;
					memreq.adr <= ea;
					memreq.vcadr <= 'd0;
					memreq.res <= 'd0;
					memreq.dchit <= 'd0;
					memreq.cmt <= 'd0;
					case(ir.ls.sz)
					PRC8:		memreq.sz <= Thor2023Pkg::byt;
					PRC16:	memreq.sz <= Thor2023Pkg::wyde;
					PRC32:	memreq.sz <= Thor2023Pkg::tetra;
					PRC64:	memreq.sz <= Thor2023Pkg::octa;
					PRC24:	memreq.sz <= Thor2023Pkg::char;
					PRC40:	memreq.sz <= Thor2023Pkg::penta;
					PRC96:	memreq.sz <= Thor2023Pkg::dodeca;
					default:	memreq.sz <= Thor2023Pkg::nul;
					endcase
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
					goto (MEMORY);
				end
			OP_STORE:
				begin
					memreq <= 'd0;
					memreq.tid <= tid;
					memreq.tag <= 'd0;
					memreq.thread <= 'd0;
					memreq.omode <= omode;
					memreq.ip <= pc;
					memreq.step <= 'd0;
					memreq.count <= 'd0;
					memreq.wr <= 1'b1;
					memreq.adr <= ea; 
					memreq.func <= MR_STORE;
					case(ir.ls.sz)
					PRC8:		memreq.func2 <= MR_STB;
					PRC16:	memreq.func2 <= MR_STW;
					PRC32:	memreq.func2 <= MR_STT;
					PRC64:	memreq.func2 <= MR_STO;
					PRC24:	memreq.func2 <= MR_STC;
					PRC40:	memreq.func2 <= MR_STP;
					PRC96:	memreq.func2 <= MR_STN;
					default:	
						begin
							if (ir[39]) begin
								memreq.func <= MR_STOREPTR;
								case(sr.ptrsz)
								2'd0:	memreq.func2 <= MR_STT;
								2'd1: memreq.func2 <= MR_STO;
								2'd2:	memreq.func2 <= MR_STN;
								default:	memreq.func2 <= MR_STO;
								endcase
							end
							else
								memreq.func2 <= MR_STN;
						end
					endcase
					memreq.load <= 1'b0;
					memreq.store <= 1'b1;
					memreq.need_steps <= 1'b0;
					memreq.v <= 1'b1;
					memreq.empty <= 1'b0;
					memreq.cause <= FLT_NONE;
					case(ir.ls.sz)
					PRC8:		memreq.sel <= 64'h0001;
					PRC16:	memreq.sel <= 64'h0003;
					PRC32:	memreq.sel <= 64'h000F;
					PRC64:	memreq.sel <= 64'h00FF;
					PRC24:	memreq.sel <= 64'h0007;
					PRC40:	memreq.sel <= 64'h001F;
					PRC96:	memreq.sel <= 64'h0FFF;
					default:
						if (ir[39])
							case(sr.ptrsz)
							2'd0:	memreq.sel <= 64'h000F;
							2'd1:	memreq.sel <= 64'h00FF;
							2'd2:	memreq.sel <= 64'h0FFF;
							default:	memreq.sel <= 16'h00FF;
							endcase
						else
							memreq.sel <= 64'h0FFFFFFFFFFFFFFF;
					endcase
					memreq.asid <= asid;
					memreq.adr <= ea;
					memreq.vcadr <= 'd0;
					if (ir.ls.sz==3'd7 && ir[39]) begin
						memreq.group <= 1'b1;
						memreq.res <= {32'd0,group_out};
					end
					else
						memreq.res <= {416'd0,a};
					memreq.dchit <= 'd0;
					memreq.cmt <= 'd0;
					case(ir.ls.sz)
					PRC8:		memreq.sz <= Thor2023Pkg::byt;
					PRC16:	memreq.sz <= Thor2023Pkg::wyde;
					PRC32:	memreq.sz <= Thor2023Pkg::tetra;
					PRC64:	memreq.sz <= Thor2023Pkg::octa;
					PRC24:	memreq.sz <= Thor2023Pkg::char;
					PRC40:	memreq.sz <= Thor2023Pkg::penta;
					PRC96:	memreq.sz <= Thor2023Pkg::dodeca;
					default:	
						case(sr.ptrsz)
						2'd0:	memreq.sz <= Thor2023Pkg::tetra;
						2'd1:	memreq.sz <= Thor2023Pkg::octa;
						2'd2:	memreq.sz <= Thor2023Pkg::dodeca;
						default:	memreq.sz <= Thor2023Pkg::octa;
						endcase
					endcase
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
					goto (MEMORY);
				end
			default:	;
			endcase
		end
	MEMORY:
		begin
			if (!memresp_fifo_empty) begin
				memresp_fifo_rd <= 1'b1;
				goto (MEMORY2);
			end
		end
	MEMORY2:
		begin
			if (memresp.load) begin
				if (memresp.group)
					rfwrg <= 1'b1;
				else
					rfwr <= 1'b1;
				Rt <= memresp.tgt;
				res <= memresp.res;
				group_in <= memresp.res;
			end
			goto (IFETCH);
		end
	endcase
	$display("===================================================================");
	$display("%d", $time);
	$display("===================================================================");
	$display("pc = %h", pc);
	$display("pfx2:%h pfx1:%h ir: %h", postfix2,postfix1,ir);
end

task tReset;
begin
	sr.om <= OM_MACHINE;
	pc <= RSTPC;
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
	imm <= 'd0;
	goto (IFETCH);
end
endtask

task tOnce;
begin
	rfwr <= 1'b0;
	rfwrg <= 1'b0;
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
	pc <= pc + imm_inc;
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		OP_ADD,OP_CMP,OP_AND,OP_OR,OP_EOR,OP_MUL,OP_DIV:
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
	OP_ADDI,OP_CMPI,OP_ANDI,OP_ORI,OP_EORI,OP_MULI,OP_DIVI,
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
			Rc <= ir.ls.Rc;
			Rt <= ir.ls.Rn;
		end
	OP_STORE:
		begin
			Ra <= ir.ls.Rn;
			Rb <= ir.ls.Rb;
			Rc <= ir.ls.Rc;
			Rt <= 'd0;
		end
	default:	;
	endcase
	imm <= imm2;
	goto (OFETCH);
end
endtask

task tOFetch;
begin
	goto (EXECUTE);
	predbuf <= {predbuf,2'b11};
	a <= Ra.sign ? -rfoa : rfoa;
	case(ir.any.opcode)
	OP_R2:
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
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_ANDI,OP_ORI,OP_EORI:
		b <= imm;
	OP_CSR:
		b <= {ir[37:32],ir[30:23]};
	default:
		b <= Rb.sign ? -rfob : rfob;
	endcase
	case(ir.any.opcode)
	OP_LOAD,OP_LOADZ,OP_STORE:
		if (ir.ls.sz==PRCNDX) begin
			if (ir[11:9]==3'd7)
				c <= 'd0;
			else
				c <= rfoc;
		end
		else
			c <= 'd0;
	default:	c <= rfoc;
	endcase
	// If predicate is false, ignore instruction
	if (!((predbuf[15:14]==2'b01 &&  rfop[predcond]) || 
			(predbuf[15:14]==2'b10 && ~rfop[predcond]) ||
			(predbuf[15:14]==2'b11) ||
			(predbuf[15:14]==2'b00)))
		goto (IFETCH);
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
			pc[13:0] <= ir[37:24];
			pc[$bits(address_t)-1:14] <= opc[$bits(address_t)-1:14] + {{68{ir[23]}},ir[23:12],ir[39:38]};
		end
	SR:
		begin
			rfwr <= 1'b1;
			Rt <= 6'd56+ir.br.Rn[1:0];
			res <= opc;
			pc[13:0] <= ir[37:24];
			pc[$bits(address_t)-1:14] <= opc[$bits(address_t)-1:14] + {{68{ir[23]}},ir[23:12],ir[39:38]};
		end
	default:
		if (takb) begin
			pc[13:0] <= ir[37:24];
			pc[$bits(address_t)-1:14] <= opc[$bits(address_t)-1:14] + {{80{ir[39]}},ir[39:38]};
		end
	endcase
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
