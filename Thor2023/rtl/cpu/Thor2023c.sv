import Thor2023Pkg::*;
import Thor2023MmuPkg::*;

module Thor2023(rst_i, clk_i, wbm_req, wbm_resp);
input rst_i;
input clk_i;
input bok_i;
output wb_write_request128_t wbm_req;
input wb_read_response128_t wbm_resp;
input rb_i;


wire clk_g;
assign clk_g = clk_i;

typedef enum logic [7:0] {
	IFETCH = 8'd1,
	DECODE,
	OFETCH,
	EXECUTE,
	WRITEBACK
} state_t;
state_t state;

address_t pc, opc, pc_o;
address_t asp, ssp, hsp, msp;		// stack pointers
wire ihit;
wire ihite ihito;
wire ic_valid;
wire [$bits(address_t)-1:6] ic_tage;
wire [$bits(address_t)-1:6] ic_tago;
reg [$bits(ICacheLine)*2-1:0] ic_line;
reg run;
status_reg_t sr;
operating_mode_t omode = sr.om;
wire AppMode = omode==OM_APP;
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

reg [5:0] Ra,Rb,Rc,Rt;
reg rfwr;
reg [95:0] res;
wire [95:0] rfoa, rfob, rfoc, rfop;
reg [95:0] a, b, c;
wire [95:0] imm2;
reg [95:0] imm;
wire [3:0] imm_inc;
reg predact;
reg [15:0] predbuf;
reg [4:0] predcond;
reg [5:0] predreg;
reg predt;

Thor2023_regfile urf1 
(
	.clk(clk_g),
	.wg(1'b0),
	.gwa('d0),
	.gi('d0),
	.wr(rfwr),
	.wa(Rt), 
	.i(res),
	.gra('d0),
	.go(),
	.ra0(Ra),
	.ra1(Rb),
	.ra2(Rc), 
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
	.om(om)
);

//module Thor2023_biu(
//	rollback, rollback_bitmaps);

always_comb
	wbm_req.cid = 4'd7;
always_comb
	if (vpa_o)
		wbm_req.seg_o <= CODE;
	else
		wbm_req.seg_o <= DATA;
always_comb
	if (wbm_we & cr_o)
		wbm_csr <= 1'b1;
	else if (!wbm_we & sr_o)
		wbm_csr <= 1'b1;
	else
		wbm_csr <= 1'b0;

Thor2023_biu ubiu
(
	.rst(rst_i),
	.clk(clk_g),
	.tlbclk(clk_g),
	.clock(clock),
	.AppMode(AppMode),
	.MAppMode(MAppMode),
	.omode(omode),
	.ASID(asid),
	.bounds_chk(),
	.pe(pe),
	.ip(pc),
	.ip_o(pc_o),
	.ihit(ihit),
	.ihite(ihite),
	.ihito(ihito),
	.ifStall(!run),
	.ic_line(ic_line),
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
	.bok_i(bok_i),
	.bte_o(wbm_req.bte),
	.blen_o(wbm_req.blen),
	.tid_o(),
	.cti_o(wbm_req.cti),
	.seg_o(seg_o),
	.vpa_o(vpa_o),
	.vda_o(vda_o),
	.cyc_o(wbm_req.cyc),
	.stb_o(wbm_req.stb),
	.ack_i(wbm_resp.ack),
	.rty_i(wbm_resp.rty),
	.err_i(wbm_resp.err),
	.tid_i(wbm_resp.tid),
	.we_o(wbm_req.we),
	.sel_o(wbm_req.sel),
	.adr_o(wbm_req.adr),
	.dat_i(wbm_resp.dat),
	.dat_o(wbm_req.dat),
	.sr_o(sr_o),
	.cr_o(cr_o),
	.rb_i(rb_i),
	.stall_i(),
	.next_i(),
	.dce(dce),
	.keys(keys),
	.arange(),
	.ptbr(ptbr),
	.ipage_fault(ipage_fault),
	.clr_ipage_fault(clr_ipage_fault),
	.itlbmiss(itlbmiss),
	.clr_itlbmiss(clr_itlbmiss),
	.rollback(rollback),
	.rollback_bitmaps()
);

always_ff @(posedge clk_g)
if (state==IFETCH && ihit)
	{postfix3,postfix2,postfix1,ir} <= ic_line >> {pc[4:0],3'b0};

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
)

always_ff @(posedge clk_g)
if (rst_i)
	tReset();
else begin
	tOnce();
	case(state)
	IFETCH:
		begin
			opc <= pc;
			if (ihit) begin
				goto (DECODE);
			end
		end
	DECODE:
		begin
			pc <= pc + imm_inc;
			case(ir.any.opcode)
			R2:
				case(ir.any.func)
				OP_PRED:
					begin
						predbuf <= {ir[33:29],ir[26:16]};
						predreg <= ir[15:10];
						predcond <= ir[9:5];
					end
				endcase
			OP_ADD,OP_CMP,OP_AND,OP_OR,_OP_EOR,OP_MUL,OP_DIV:
				begin
					Ra <= ir.r2.Ra;
					Rb <= ir.r2.Rb;
					Rt <= ir.r2.Rt;
				end	
			endcase
			imm <= imm2;
			goto (OFETCH);
		end
	OFETCH:
		begin
			goto (EXECUTE);
			predbuf <= {predbuf,2'b11};
			a <= Ra.sign ? -rfoa : rfoa;
			c <= rfoc;
			case(ir.any.opcode)
			R2:
				case(ir.r2.func)
				OP_PRED:
					begin
						predbuf <= {ir[33:29],ir[26:16]};
						predreg <= ir[15:10];
						predcond <= ir[9:5];
						goto (IFETCH);
					end
				endcase
			OP_ADD,OP_CMP,OP_MUL,OP_DIV,OP_AND,OP_OR,OP_EOR:
				b <= imm;
			default:
				b <= Rb.sign ? -rfob : rfob;
			endcase
			// If predicate is false, ignore instruction
			if (!((predbuf[15:14]==2'b01 &&  rfop[predcond]) || 
					(predbuf[15:14]==2'b10 && ~rfop[predcond]) ||
					(predbuf[15:14]==2'b11) ||
					(predbuf[15:14]==2'b00)))
				goto (IFETCH);
		end
	EXECUTE:
		begin
			case(ir.any.opcode)
			R2:
				case(ir.r2.func)
				OP_ADD:	begin res <= Rt.sign ? -(a + b) : a + b; rfwr <= 1'b1; goto (IFETCH); end
				OP_CMP:	begin res <= {64'd0,cmpo}; rfwr <= 1'b1; goto (IFETCH); end
				OP_AND:	begin res <= Rt.sign ? ~(a & b) : a & b; rfwr <= 1'b1; goto (IFETCH); end
				OP_OR:	begin res <= Rt.sign ? ~(a | b) : a | b; rfwr <= 1'b1; goto (IFETCH); end
				OP_EOR:	begin res <= Rt.sign ? ~(a ^ b) : a ^ b; rfwr <= 1'b1; goto (IFETCH); end
				default:	;
				endcase
			OP_ADD:	res <= begin Rt.sign ? -(a + b) : a + b; rfwr <= 1'b1; goto (IFETCH); end
			OP_CMP:	res <= begin {64'd0,cmpo}; rfwr <= 1'b1; goto (IFETCH); end
			OP_AND:	res <= begin Rt.sign ? ~(a & b) : a & b; rfwr <= 1'b1; goto (IFETCH); end
			OP_OR:	res <= begin Rt.sign ? ~(a | b) : a | b; rfwr <= 1'b1; goto (IFETCH); end
			OP_EOR:	res <= begin Rt.sign ? ~(a ^ b) : a ^ b; rfwr <= 1'b1; goto (IFETCH); end
			OP_Bcc:
				begin
					if (takb) begin
						pc <= opc + {{{40{ir[39]}},ir[39:16]};
					end
					goto (IFETCH);
				end				
			OP_LOAD:
				begin
					memreq.tid <= tid;
					memreq.tag <= 'd0;
					memreq.thread <= 'd0;
					memreq.omode <= om;
					memreq.ip <= pc;
					memreq.step <= 'd0;
					memreq.count <= 'd0;
					memreq.wr <= 1'b1;
					memreq.adr <= ea; 
					memreq.func <= MR_LOAD;
					case(ir.ls.sz)
					PRC8:		memreq.func2 <= MR_LDB;
					PRC16:	memreq.func2 <= MR_LDW;
					PRC32:	memreq.func2 <= MR_LDT;
					PRC64:	memreq.func2 <= MR_LDO;
					PRC24:	memreq.func2 <= MR_LDC;
					PRC40:	memreq.func2 <= MR_LDP;
					PRC96:	memreq.func2 <= MR_LDN;
					default:	memreq.func2 <= MR_LDN;
					endcase
					memreq.load <= 1'b1;
					memreq.store <= 1'b0;
					memreq.need_steps <= 1'b0;
					memreq.v <= 1'b1;
					memreq.empty <= 1'b0;
					memreq.cause <= 'd0;
					case(ir.ls.sz)
					PRC8:		memreq.sel <= 16'h0001;
					PRC16:	memreq.sel <= 16'h0003;
					PRC32:	memreq.sel <= 16'h000F;
					PRC64:	memreq.sel <= 16'h00FF;
					PRC24:	memreq.sel <= 16'h0007;
					PRC40:	memreq.sel <= 16'h001F;
					PRC96:	memreq.sel <= 16'h0FFF;
					default:	memreq.sel <= 16'h0FFF;
					endcase
					memreq.asid <= asid;
					memreq.adr <= ea;
					memreq.vcadr <= 'd0;
					memreq.res <= 'd0;
					memreq.dchit <= 'd0;
					memreq.cmt <= 'd0;
					case(ir.ls.sz)
					PRC8:		memreq.sz <= byt;
					PRC16:	memreq.sz <= wyde;
					PRC32:	memreq.sz <= tetra;
					PRC64:	memreq.sz <= octa;
					PRC24:	memreq.sz <= char;
					PRC40:	memreq.sz <= penta;
					PRC96:	memreq.sz <= n96;
					default:	memreq.sz <= nul;
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
					memreq.tid <= tid;
					memreq.tag <= 'd0;
					memreq.thread <= 'd0;
					memreq.omode <= om;
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
					default:	memreq.func2 <= MR_STN;
					endcase
					memreq.load <= 1'b0;
					memreq.store <= 1'b1;
					memreq.need_steps <= 1'b0;
					memreq.v <= 1'b1;
					memreq.empty <= 1'b0;
					memreq.cause <= 'd0;
					case(ir.ls.sz)
					PRC8:		memreq.sel <= 16'h0001;
					PRC16:	memreq.sel <= 16'h0003;
					PRC32:	memreq.sel <= 16'h000F;
					PRC64:	memreq.sel <= 16'h00FF;
					PRC24:	memreq.sel <= 16'h0007;
					PRC40:	memreq.sel <= 16'h001F;
					PRC96:	memreq.sel <= 16'h0FFF;
					default:	memreq.sel <= 16'h0FFF;
					endcase
					memreq.asid <= asid;
					memreq.adr <= ea;
					memreq.vcadr <= 'd0;
					memreq.res <= a;
					memreq.dchit <= 'd0;
					memreq.cmt <= 'd0;
					case(ir.ls.sz)
					PRC8:		memreq.sz <= byt;
					PRC16:	memreq.sz <= wyde;
					PRC32:	memreq.sz <= tetra;
					PRC64:	memreq.sz <= octa;
					PRC24:	memreq.sz <= char;
					PRC40:	memreq.sz <= penta;
					PRC96:	memreq.sz <= n96;
					default:	memreq.sz <= nul;
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
				rfwr <= 1'b1;
				Rt <= memresp.tgt;
				res <= memresp.dat;
			end
			goto (IFETCH);
		end
	endcase
end

task tReset;
begin
	pc <= RSTPC;
	tid <= 'd0;
	predbuf <= 16'hFFFF;
	predreg <= 'd0;
	predact <= 'd0;
	goto (IFETCH);
end
endtask

task tOnce;
begin
	rfwr <= 1'b0;
	memreq.wr <= 1'b0;
	memresp_fifo_rd <= 1'b0;
end
endtask

task goto;
input [7:0] nst;
begin
	state <= nst;
end
endtask

endmodule
