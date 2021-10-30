import Thor2021_pkg::*;

module Thor2021(hartid_i, rst_i, clk_i, clk2x_i, clk2d_i, irq_i, icause_i,
		vpa_o, vda_o, bte_o, cti_o, bok_i, cyc_o, stb_o, lock_o, ack_i,
    err_i, we_o, sel_o, adr_o, dat_i, dat_o, cr_o, sr_o, rb_i, state_o, trigger_o);
input [63:0] hartid_i;
input rst_i;
input clk_i;
input clk2x_i;
input clk2d_i;
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

wire clk_g = clk_i;

reg [5:0] state;
wire [1:0] omode;
wire [1:0] memmode;
wire UserMode, SupervisorMode, HypervisorMode, MachineMode;
wire MUserMode;
reg gie;
Instruction mir,wir;
Value regfile [0:63];
Value sp [0:31];

// Instruction fetch stage vars
reg ival;
Instruction insn;
Address ip;
Address [7:0] caregfile;
wire ihit;
wire [639:0] ic_line;
wire [3:0] ilen;
wire btb_hit;
Address btb_tgt;
Address next_ip;

// Decode stage vars
reg dval;
Instruction ir;
Address dip;
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

// Execute stage vars
reg xval;
Instruction xir;
Address xip;
reg [5:0] xRt,xRa,xRb,wRt,tRt;
reg xpredict_taken;
reg xJxx;
reg memresp_fifo_rd;
wire memresp_fifo_empty;
wire memresp_fifo_v;
reg [7:0] tid;

// CSRs
reg [63:0] cr0;
wire pe = cr0[0];				// protected mode enable
wire dce = cr0[30];     // data cache enable
wire bpe = cr0[32];     // branch prediction enable
wire btbe	= cr0[33];		// branch target buffer enable
reg [7:0] asid;
Value gdt;

Value bf_out;

Thor2021_decoder udec (ir, xir, deco);

Thor2021_eval_branch ube (xir, xa, xb, takb);


always_comb
if (Ra==6'd0 && (dAddi | dld | dst))
  rfoa = {VALUE_SIZE{1'b0}};
else if (Ra==xRt)
  rfoa = res;
else
  case(Ra)
  6'd63:  rfoa = sp [{ol,ilvl}];
  default:    rfoa = regfile[Ra];
  endcase

always_comb
if (Tb[1])
	rfob = {{57{Tb[0]}},Tb[0],Rb};
else if (Rb==xRt)
  rfob = res;
else
  case(Rb)
  6'd63:  rfob = sp [{ol,ilvl}];
  default:    rfob = regfile[Rb];
  endcase

always_comb
if (Tc[1])
	rfoc = {{57{Tc[0]}},Tc[0],Rc};
else if (Rc==xRt)
  rfoc = res;
else
  case(Rc)
  6'd63:  rfoc = sp [{ol,ilvl}];
  default:    rfoc = regfile[Rc];
  endcase

Thor2021_bitfield ubf
(
	.ir(xir),
	.a(xa),
	.b(xb),
	.c(xc),
	.o(bf_out)
);

always_comb
case(xir.any.opcode)
R1:
R2:
	case(xir.r3.func)
	ADD:	res = xa + xb + xc;
	SUB:	res = xa - xb - xc;
	AND:	res = xa & xb & xc;
	OR:		res = xa | xb | xc;
	XOR:	res = xa ^ xb ^ xc;
	default:			res = 64'd0;
	endcase
BTFLD:	res = bf_out;
ADD2R:				res = xa + xb;
AND2R:				res = xa & xb;
OR2R:					res = xa | xb;
XOR2R:				res = xa ^ xb;
ADDI,ADDIL:		res = xa + imm;
SUBFI,SUBFIL:	res = imm - xa;
ANDI,ANDIL:		res = xa & imm;
ORI,ORIL:			res = xa | imm;
XORI,XORIL:		res = xa ^ imm;
CMPI,CMPIL:		res = $signed(xa) < $signed(imm) ? -64'd1 : xa==imm ? 64'd0 : 64'd1;
CMPUI,CMPIUL:	res = xa < imm ? -64'd1 : xa==imm ? 64'd0 : 64'd1;
SEQI,SEQIL:		res = xa == imm;
SNEI,SNEIL:		res = xa != imm;
SLTI,SLTIL:		res = $signed(xa) < $signed(imm);
SGTI,SGTIL:		res = $signed(xa) > $signed(imm);
SLTUI,SLTUIL:	res = xa < imm;
SGTUI,SGTUIL:	res = xa > imm;
default:			res = 64'd0;
endcase

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

Thor2021_biu ubiu
(
	.rst(rst),
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
	.ifStall(),
	.ic_line(ic_line),
	.fifoToCtrl_i(),
	.fifoToCtrl_full_o(),
	.fifoFromCtrl_o(),
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
	.keys(),
	.arange(),
	.gdt(gdt),
	.ldt()
);

wire [63:0] siea = xa + {xb << Sc};

always_ff @(posedge clk_g)
begin
	upd_rf <= FALSE;
	memreq.wr <= FALSE;
case (state)
RESTART1:
	begin
		memresp_fifo_rd <= FALSE;
		gdt <= 64'hFFFFFFFFFFFC0000;	// startup table
		gie <= FALSE;
		goto(RESTART2);
	end
RESTART2:
	begin
		goto(RUN);
	end
RUN:
	if (advance_i) begin
		ival <= VAL;
		ip <= next_ip;
		if (insn.jmp.ca==3'd0 && insn.any.opcode==JMP)
			ip.offs <= {{30{insn.jmp.Tgthi[15]}},insn.jmp.Tgthi,insn.jmp.Tgtlo,1'b0};
		else if (btbe & btb_hit)
			ip <= btb_tgt;
		dlen <= ilen;
		dval <= ival;
	end
	else begin
		ip <= ip;
		if (!ihit) begin
			goto(LOAD_ICACHE1);
		end
	end	

	if (advance_d) begin
		xval <= dval;
		xa <= rfoa;
		xb <= rfob;
		xc <= rfoc;
		imm <= deco.imm;
		xRa <= Ra;
		xRb <= Rb;
		xRc <= Rc;
		xRt <= Rt;
		xip <= ip;
		xlen <= dlen;
		xIsMul <= deco.mul;
		xIsDiv <= deco.div;
		xFloat <= deco.float;
		xJxx <= deco.jxx;
		xJmptgt <= deco.jmptgt;
		xpredict_taken <= dpredict_taken;
		xLoadr <= deco.loadr;
		xLoadn <= deco.loadn;
		xStorer <= deco.storer;
		xStoren <= deco.storen;
		xLdz <= deco.ldz;
		xMemsz <= deco.memsz;
	end
	else if (advance_x)
		inv_x();

	if (xval) begin
    if (xJxx) begin
      if (bpe) begin
        if (xpredict_taken & ~takb) begin
          ex_branch(xip + xinslen);
        end
        else if (~xpredict_taken & takb) begin
          ex_branch(xip + xbrdisp);
        end
      end
      else if (takb)
        ex_branch(xip + xbrdisp);
    end
    if (xJmp) begin
    	if (xir.jmp.ca != 3'd0)	begin // ==0 was already done at ifetch
		    ival <= INV;
		    inv_d();
		    inv_x();
    		ip.offs <= xJmptgt;
    		// Selector changing?
    		if (caregfile[xir.jmp.ca].sel != ip.sel) begin
    			memreq.func <= MR_LOAD;
    			memreq.func2 <= MR_LDDESC;
    			memreq.adr <= caregfile[xir.jmp.ca].sel;
    			memreq.seg <= caregfile[xir.jmp.ca].sel[23] ? 5'd17 : 5'd31;	// LDT or GDT
    			memreq.dat <= 5'd7;		// update CS descriptor cache
    			memreq.wr <= TRUE;
    			goto (WAIT_MEM1);
    		end
    	end
  	end

    if (xIsMul)
      goto(MUL1);
    if (xIsDiv)
      goto(DIV1);
    if (xFloat)
      goto(FLOAT1);

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
    	memreq.adr <= a + imm;
    	memreq.seg <= {2'd0,xSeg};
    	memreq.wr <= TRUE;
    	goto (WAIT_MEM1);
    end
    if (xLoadn) begin
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
    if (xStorer) begin
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
    	next_state(STORE1);
    end
    if (xStoren) begin
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
    	next_state(STORE1);
    end
		
	end

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
					res <= memresp.res;
					upd_rf <= TRUE;
				end
				goto (INVnRUN);
			end
		end
	end

// Invalidate the xir and switch back to the run state.
// The xir is invalidated to prevent the instruction from executing again.
INVnRUN:
  begin
    goto(INVnRUN2);
  end
INVnRUN2:
  begin
    inv_x();
    goto(RUN);
  end

default:
	goto (RESTART1);	
endcase

	update_regfile();

end

// The register file is updated outside of the state case statement.
// It could be updated potentially on every clock cycle as long as
// upd_rf is true.

task update_regfile;
begin
  if (upd_rf & !xinv) begin
    case(xRt)
    6'd63:  sp[{ol,ilvl}] <= {res[63:3],3'h0};
    endcase
    regfile[xRt] <= res;
    $display("regfile[%d] <= %h", xRt, res);
    // Globally enable interrupts after first update of stack pointer.
    if (xRt==6'd63)
      gie <= TRUE;
  end
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
  xRt2 <= 6'd0;
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

task goto;
input [5:0] st;
begin
	state <= st;
end
endtask

endmodule
