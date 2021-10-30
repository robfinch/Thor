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
Value lc;
Address caregfile [0:7];

// Instruction fetch stage vars
reg ival;
Instruction insn;
wire advance_i;
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

// Execute stage vars
reg xval;
Instruction xir;
Address xip;
reg [3:0] xlen;
wire advance_x;
reg [5:0] xRt,xRa,xRb,wRt,tRt;
reg [2:0] xCat;
reg xpredict_taken;
reg xJmp;
reg xJxx;
reg xdj;
reg xRts;
reg xIsMultiCycle;
reg xLdz;
reg xrfwr;
reg xcarfwr;
MemoryRequest memreq;
MemoryResponse memresp;
reg memresp_fifo_rd;
wire memresp_fifo_empty;
wire memresp_fifo_v;
reg [7:0] tid;
Value res;
Address cares;

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
	.keys(),
	.arange(),
	.gdt(gdt),
	.ldt()
);

wire [63:0] siea = xa + {xb << Sc};

wire run = ihit && (state==RUN);
assign advance_x = !(xIsMultiCycle) & run;
assign advance_d = (advance_x | ~xval) & run;
assign advance_i = (advance_d | ~dval) & run;

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

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Register fetch and decode stage
  // Much of the decode is done above by combinational logic outside of the
  // clock domain.
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	if (advance_d) begin
		xval <= dval;
		xlen <= dlen;
		xa <= rfoa;
		xb <= rfob;
		xc <= rfoc;
		imm <= deco.imm;
		xRa <= Ra;
		xRb <= Rb;
		xRc <= Rc;
		xRt <= Rt;
		xCat <= deco.Cat;
		xip <= ip;
		xlen <= dlen;
		xIsMul <= deco.mul;
		xIsDiv <= deco.div;
		xFloat <= deco.float;
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
		xIsMultiCycle <= deco.multi_cycle;
		xrfwr <= deco.rfwr;
		xcarfwr <= deco.carfwr;
	end
	else if (advance_x)
		inv_x();

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Execute stage
  // If the execute stage has been invalidated it doesn't do anything. 
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	if (xval) begin
    if (xJxx) begin
    	if (xdj)
    		lc = lc - 2'd1;
    	if (ir.jxx.lk != 2'd0) begin
	    	caregfile[{1'b0,ir.jxx.lk}].offs <= ip.offs + 3'd6;
	    	caregfile[{1'b0,ir.jxx.lk}].sel <= ip.sel;
    	end
      if (bpe) begin
        if (xpredict_taken && !(xdj ? takb && lc != 64'd0 : takb)) begin
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
        else if (!xpredict_taken && (xdj ? takb && lc != 64'd0 : takb)) begin
			    ival <= INV;
			    inv_d();
			    inv_x();
			    if (xir.jxx.ca == 3'd0)
			    	ip.offs <= xJmptgt;
			    else if (xir.jxx.ca == 3'd7)
			    	ip.offs <= ip.offs + xJmptgt;
			    else
			    	ip.offs <= caregfile[xir.jmp.ca].offs + xJmptgt;
	    		if (caregfile[xir.jmp.ca].sel != ip.sel && xir.jmp.ca != 3'd0) begin
	    			ip.sel <= caregfile[xir.jmp.ca].sel;
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
      else if (xdj ? (takb && lc != 64'd0) : takb) begin
		    ival <= INV;
		    inv_d();
		    inv_x();
		    if (xir.jxx.ca == 3'd0)
		    	ip.offs <= xJmptgt;
		    else if (xir.jxx.ca == 3'd7)
		    	ip.offs <= ip.offs + xJmptgt;
		    else
		    	ip.offs <= caregfile[xir.jmp.ca].offs + xJmptgt;
    		if (caregfile[xir.jmp.ca].sel != ip.sel && xir.jmp.ca != 3'd0) begin
    			ip.sel <= caregfile[xir.jmp.ca].sel;
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
    if (xJmp) begin
    	if (xdj)
    		lc = lc - 2'd1;
    	if (xir.jmp.ca != 3'd0)	begin // ==0 was already done at ifetch
		    ival <= INV;
		    inv_d();
		    inv_x();
		    if (xir.jmp.ca == 3'd7)
		    	ip.offs <= ip.offs + xJmptgt;
		    else 
		    	ip.offs <= caregfile[xir.jmp.ca].offs + xJmptgt;
		  	if (ir.jxx.lk != 2'd0) begin
		    	caregfile[{1'b0,ir.jxx.lk}].offs <= ip.offs + 3'd6;
		    	caregfile[{1'b0,ir.jxx.lk}].sel <= ip.sel;
		  	end
    		// Selector changing?
    		if (caregfile[xir.jmp.ca].sel != ip.sel) begin
    			ip.sel <= caregfile[xir.jmp.ca].sel;
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
  	if (xRts) begin
  		// Selector changing?
  		if (xir.rts.lk != 2'd0) begin
		    ival <= INV;
		    inv_d();
		    inv_x();
	    	ip.offs <= caregfile[{1'b0,xir.rts.lk}].offs + {xir.rts.cnst,1'b0};
	  		if (caregfile[xir.rts.lk].sel != ip.sel) begin
    			ip.sel <= caregfile[{1'b0,xir.rts.lk}].sel;
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
    end
		
	end

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
					res <= memresp.res;
					upd_rf <= TRUE;
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
default:
	goto (RESTART1);	
endcase

	update_regfile();

end

// The register file is updated outside of the state case statement.
// It could be updated potentially on every clock cycle as long as
// xrfwr is true.

task update_regfile;
begin
  if (xrfwr & xval) begin
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
  LDT:		$display("LDT r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.Ra);
  LDTU:		$display("LDTU r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.Ra);
  LDO:		$display("LDO r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.Ra);
  STT:		$display("STT r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.Ra);
  STO:		$display("STO r%d,%d[r%d]", ir.ld.Rt, ir.ld.disp, ir.Ra);
  RTS:   	$display("RTS #%d", ir.rts.cnst);
  endcase
end
endtask


endmodule
