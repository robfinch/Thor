// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
import fta_bus_pkg::*;
import Thor2024_cache_pkg::*;
import Thor2024pkg::*;

`define ZERO		64'd0

// JALR and EXTENDED are synonyms
`define EXTEND	3'd7

// system-call subclasses:
`define SYS_NONE	3'd0
`define SYS_CALL	3'd1
`define SYS_MFSR	3'd2
`define SYS_MTSR	3'd3
`define SYS_RFU1	3'd4
`define SYS_RFU2	3'd5
`define SYS_RFU3	3'd6
`define SYS_EXC		3'd7	// doesn't need to be last, but what the heck

//
// define PANIC types
//
`define PANIC_NONE		4'd0
`define PANIC_FETCHBUFBEQ	4'd1
`define PANIC_INVALIDISLOT	4'd2
`define PANIC_MEMORYRACE	4'd3
`define PANIC_IDENTICALDRAMS	4'd4
`define PANIC_OVERRUN		4'd5
`define PANIC_HALTINSTRUCTION	4'd6
`define PANIC_INVALIDMEMOP	4'd7
`define PANIC_INVALIDFBSTATE 4'd8
`define PANIC_INVALIDIQSTATE 4'd9 
`define PANIC_BRANCHBACK 4'd10
`define PANIC_BADTARGETID	4'd12
`define PANIC_COMMIT 4'd13

module Thor2024(coreno_i, rst_i, clk_i, clk2x_i, irq_i, vect_i,
	ftaim_req, ftaim_resp, ftaim_full, ftadm_req, ftadm_resp, ftadm_full,
	snoop_adr, snoop_v, snoop_cid);
parameter CORENO = 6'd1;
parameter CID = 6'd1;
parameter DRAMSLOT_AVAIL = 3'd0;
parameter DRAMSLOT_READY = 3'd1;
parameter DRAMSLOT_ACTIVE = 3'd2;
input [63:0] coreno_i;
input rst_i;
input clk_i;
input clk2x_i;
input [2:0] irq_i;
input [8:0] vect_i;
output fta_cmd_request128_t [NDATA_PORTS-1:0] ftadm_req;
input fta_cmd_response128_t [NDATA_PORTS-1:0] ftadm_resp;
input ftadm_full;
output fta_cmd_request128_t ftaim_req;
input fta_cmd_response128_t ftaim_resp;
input ftaim_full;
input Thor2024pkg::address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;

integer n,nn,n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16;
genvar g;

wire [AREGS-1:0] rf_v;
wire [4:0] rf_source[0:AREGS-1];
pc_address_t pc;
wire clk;
wire rst;
assign rst = rst_i;
reg  [3:0] panic;		// indexes the message structure
wire [3:0] head_panic;
reg [128:0] message [0:15];	// indexed by panic

wire [63:0] dec_imm0, dec_imm1;

reg [7:0] atom_mask;
reg [5:0] postfix_mask;
reg [27:0] pred_mask;
reg [1:0] pred_val;

// instruction queue (ROB)
iq_entry_t [QENTRIES-1:0] iq;

que_bitmask_t iq_v;							// current valid state
que_bitmask_t iqentry_source;
que_bitmask_t iqentry_imm;
que_bitmask_t iqentry_memready;
que_bitmask_t iqentry_memopsvalid;

que_bitmask_t iqentry_memissue;
que_bitmask_t iqentry_stomp;
que_bitmask_t iqentry_issue;
que_bitmask_t iqentry_issue_reg;
que_bitmask_t iqentry_issue2;
que_bitmask_t iqentry_fcu_issue;
que_bitmask_t iqentry_fpu_issue;
wire [1:0] iqentry_islot [0:QENTRIES-1];

reg_bitmask_t livetarget;
reg_bitmask_t [QENTRIES-1:0] iqentry_livetarget;
reg_bitmask_t iqentry_0_latestID;
reg_bitmask_t iqentry_1_latestID;
reg_bitmask_t iqentry_2_latestID;
reg_bitmask_t iqentry_3_latestID;
reg_bitmask_t iqentry_4_latestID;
reg_bitmask_t iqentry_5_latestID;
reg_bitmask_t iqentry_6_latestID;
reg_bitmask_t iqentry_7_latestID;
reg_bitmask_t iqentry_0_cumulative;
reg_bitmask_t iqentry_1_cumulative;
reg_bitmask_t iqentry_2_cumulative;
reg_bitmask_t iqentry_3_cumulative;
reg_bitmask_t iqentry_4_cumulative;
reg_bitmask_t iqentry_5_cumulative;
reg_bitmask_t iqentry_6_cumulative;
reg_bitmask_t iqentry_7_cumulative;
reg_bitmask_t [QENTRIES-1:0] iq_out;

que_ndx_t tail0;
que_ndx_t tail1;
// heads 2 to 7 used only to determine memory-access ordering
que_ndx_t [QENTRIES-1:0] heads;
que_ndx_t lastq0;
que_ndx_t lastq1;
reg fetch0,fetch1;
reg q1open,q2open,q3open,q4open;
reg canq1,canq2;
reg queued1Nop, queued2Nop;

que_ndx_t missid;

reg rfva0, rfvb0, rfvc0, rfvt0, rfvp0;
reg rfva1, rfvb1, rfvc1, rfvt1, rfvp1;
regspec_t Ra0, Rb0, Rc0, Rt0, Rp0;
regspec_t Ra1, Rb1, Rc1, Rt1, Rp1;

wire        fetchbuf;	// determines which pair to read from & write to
wire istall;

instruction_t [4:0] fetchbuf0_instr;
instruction_t fetchbuf0_postfixes [0:3];	
pc_address_t fetchbuf0_pc;
wire        fetchbuf0_v;
wire        fetchbuf0_jmp;
wire        fetchbuf0_rfw;
instruction_t [4:0] fetchbuf1_instr;
instruction_t fetchbuf1_postfixes [0:3];
pc_address_t fetchbuf1_pc;
wire        fetchbuf1_v;
wire        fetchbuf1_jmp;
wire        fetchbuf1_rfw;

decode_bus_t db0,db1;
value_t rfoa0,rfob0,rfoc0,rfot0,rfop0;
value_t rfoa1,rfob1,rfoc1,rfot1,rfop1;

assign fetchbuf0_jmp = 1'b0;
assign fetchbuf1_jmp = 1'b0;

reg alu0_idle = 1'b1;
reg        alu0_available;
reg        alu0_dataready;
reg  [3:0] alu0_sourceid;
instruction_t alu0_instr;
reg alu0_div;
value_t alu0_argA;
value_t alu0_argB;
value_t alu0_argC;
value_t alu0_argT;
value_t alu0_argP;
value_t alu0_argI;	// only used by BEQ
value_t alu0_cmpo;
pc_address_t alu0_pc;
value_t alu0_bus;
wire  [3:0] alu0_id;
cause_code_t alu0_exc;
wire        alu0_v;
double_value_t alu0_prod,alu0_prod1,alu0_prod2;
double_value_t alu0_produ,alu0_produ1,alu0_produ2;
reg [3:0] mul0_cnt;
reg mul0_done;
value_t div0_q,div0_r;
wire div0_done,div0_dbz;
reg alu0_ld;

reg alu1_idle = 1'b1;
reg        alu1_available;
reg        alu1_dataready;
reg  [3:0] alu1_sourceid;
instruction_t alu1_instr;
reg alu1_div;
value_t alu1_argA;
value_t alu1_argB;
value_t alu1_argC;
value_t alu1_argT;
value_t alu1_argP;
value_t alu1_argI;	// only used by BEQ
value_t alu1_cmpo;
pc_address_t alu1_pc;
value_t alu1_bus;
wire  [3:0] alu1_id;
cause_code_t alu1_exc;
wire        alu1_v;
double_value_t alu1_prod,alu1_prod1,alu1_prod2;
double_value_t alu1_produ,alu1_produ1,alu1_produ2;
reg [3:0] mul1_cnt;
reg mul1_done;
value_t div1_q,div1_r;
wire div1_done,div1_dbz;
reg alu1_ld;

reg fpu_idle = 1'b1;
reg        fpu_available;
reg        fpu_dataready;
reg  [3:0] fpu_sourceid;
instruction_t fpu_instr;
value_t fpu_argA;
value_t fpu_argB;
value_t fpu_argC;
value_t fpu_argT;
value_t fpu_argP;
value_t fpu_argI;	// only used by BEQ
pc_address_t fpu_pc;
value_t fpu_bus;
wire  [3:0] fpu_id;
cause_code_t fpu_exc;
wire        fpu_v;
wire fpu_done;

reg fcu_idle = 1'b1;
reg        fcu_available;
reg        fcu_dataready;
reg  [3:0] fcu_sourceid;
instruction_t fcu_instr;
reg        fcu_bt;
value_t fcu_argA;
value_t fcu_argB;
value_t fcu_argC;
value_t fcu_argT;
value_t fcu_argP;
value_t fcu_argI;	// only used by BEQ
pc_address_t fcu_pc;
value_t fcu_bus;
wire  [3:0] fcu_id;
cause_code_t fcu_exc;
wire        fcu_v;
reg fcu_branchmiss;
pc_address_t fcu_misspc;
instruction_t fcu_missir;
reg takb;

que_ndx_t excid;
pc_address_t excmisspc;
reg excmiss;
instruction_t excir;

wire branchback;
reg did_branchback, did_branchback1, did_branchback2;
pc_address_t backpc;
wire branchmiss;
pc_address_t misspc;
instruction_t missir;

wire dram_avail;
reg	[2:0] dram0,dram0p;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	[2:0] dram1,dram1p;	// state of the DRAM request (latency = 4; can have three in pipeline)
//reg	 [1:0] dram2;	// state of the DRAM request (latency = 4; can have three in pipeline)

reg [639:0] dram0_data;
address_t dram0_addr;
reg [79:0] dram0_sel;
instruction_t dram0_op;
memsz_t dram0_memsz;
reg dram0_load;
reg dram0_loadz;
reg dram0_store;
regspec_t dram0_tgt;
reg  [4:0] dram0_id;
cause_code_t dram0_exc;
reg dram0_ack;
reg [7:0] dram0_tid;
reg dram0_more;

reg [639:0] dram1_data;
address_t dram1_addr;
reg [79:0] dram1_sel;
instruction_t dram1_op;
memsz_t dram1_memsz;
reg dram1_load;
reg dram1_loadz;
reg dram1_store;
regspec_t dram1_tgt;
reg  [4:0] dram1_id;
cause_code_t dram1_exc;
reg dram1_ack;
reg [7:0] dram1_tid;
reg dram1_more;

/*
value_t dram2_data;
reg [31:0] dram2_addr;
instruction_t dram2_op;
reg dram2_load;
reg dram2_store;
regspec_t dram2_tgt;
reg  [4:0] dram2_id;
cause_code_t dram2_exc;
reg dram2_ack;
*/

reg [2:0] dramN [0:NDATA_PORTS-1];
reg [511:0] dramN_data [0:NDATA_PORTS-1];
reg [63:0] dramN_sel [0:NDATA_PORTS-1];
address_t dramN_addr [0:NDATA_PORTS-1];
reg [NDATA_PORTS-1:0] dramN_load;
reg [NDATA_PORTS-1:0] dramN_loadz;
reg [NDATA_PORTS-1:0] dramN_store;
reg [NDATA_PORTS-1:0] dramN_ack;
reg [7:0] dramN_tid [0:NDATA_PORTS-1];
memsz_t dramN_memsz;

value_t dram_bus0;
regspec_t dram_tgt0;
reg  [4:0] dram_id0;
cause_code_t dram_exc0;
reg        dram_v0;
value_t dram_bus1;
regspec_t dram_tgt1;
reg  [4:0] dram_id1;
cause_code_t dram_exc1;
reg        dram_v1;

wire        outstanding_stores;
wire [39:0] I;	// instruction count

wire commit0_v, commit2_v, commit3_v;
reg commit0a_v, commit1a_v;
wire [4:0] commit0_id, commit2_id, commit3_id;
reg [4:0] commit0a_id, commit1a_id;
regspec_t commit0_tgt;
value_t commit0_bus, commit2_bus, commit3_bus;
value_t commit0a_bus, commit1a_bus;
pc_address_t commit_pc0;
reg commit_takb0;
pc_address_t commit_brtgt0;
instruction_t commit0_instr;
wire commit1_v;
wire [4:0] commit1_id;
regspec_t commit1_tgt;
value_t commit1_bus;
pc_address_t commit_pc1;
reg commit_takb1;
pc_address_t commit_brtgt1;
instruction_t commit1_instr;
wire int_commit;

// CSRs
reg [63:0] tick;
cause_code_t [3:0] cause;
status_reg_t sr_stack [0:8];
status_reg_t sr;
pc_address_t pc_stack [0:8];
wire [2:0] im = sr.ipl;
reg [5:0] regset = 6'd0;
asid_t asid;
asid_t ip_asid;
pc_address_t [3:0] kvec;
pc_address_t avec;

assign clk = clk_i;

function [63:0] fnA1;
input instruction_t fetchbuf_instr;
input value_t rfo;
input [63:0] imm;
begin
	fnA1 = fnImma(fetchbuf_instr) ? imm : rfo;
end
endfunction

function [63:0] fnA2;
input instruction_t fetchbuf_instr;
input value_t rfo;
input [63:0] imm;
begin
	fnA2 = fnImmb(fetchbuf_instr) ? imm : rfo;
end
endfunction

function [63:0] fnA3;
input instruction_t fetchbuf_instr;
input value_t rfo;
input [63:0] imm;
begin
	fnA3 = fnImmc(fetchbuf_instr) ? imm : rfo;
end
endfunction

function [63:0] fnAP;
input instruction_t ir;
input value_t rfo;
begin
	case(ir.any.opcode)
	OP_R2:	
		if (ir.r2.fmt[0])
			fnAP = rfo;
		else
			fnAP = {64{1'b1}};
	OP_JSR,
	OP_ADDI:	fnAP = ir.ri.fmt[0] ? rfo : {64{1'b1}};
	OP_CMPI:	fnAP = ir.ri.fmt[0] ? rfo : {64{1'b1}};
	OP_MULI:	fnAP = ir.ri.fmt[0] ? rfo : {64{1'b1}};
	OP_DIVI:	fnAP = ir.ri.fmt[0] ? rfo : {64{1'b1}};
	OP_ANDI:	fnAP = ir.ri.fmt[0] ? rfo : {64{1'b1}};
	OP_ORI:		fnAP = ir.ri.fmt[0] ? rfo : {64{1'b1}};
	OP_EORI:	fnAP = ir.ri.fmt[0] ? rfo : {64{1'b1}};
	OP_SLTI:	fnAP = ir.ri.fmt[0] ? rfo : {64{1'b1}};
	OP_BEQ:		fnAP = {64{1'b1}};
	OP_BNE:		fnAP = {64{1'b1}};
	OP_BLT:		fnAP = {64{1'b1}};
	OP_BLE:		fnAP = {64{1'b1}};
	OP_BGT:		fnAP = {64{1'b1}};
	OP_BGE:		fnAP = {64{1'b1}};
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO:
		fnAP = ir.ls.fmt[0] ? rfo : {64{1'b1}};
	OP_LDX:
		fnAP = ir.lsn.fmt[0] ? rfo : {64{1'b1}};
	OP_STB,OP_STW,OP_STT,OP_STO:
		fnAP = ir.ls.fmt[0] ? rfo : {64{1'b1}};
	OP_STX:
		fnAP = ir.lsn.fmt[0] ? rfo : {64{1'b1}};
	default:	fnAP = {64{1'b1}};
	endcase
end
endfunction

generate begin : gIqOut
	for (g = 0; g < QENTRIES; g = g + 1)
		decoder6 iqog(.num(iq[g].tgt), .out(iq_out[g]));
end
endgenerate

// Get the valid slice.
initial begin
//for (n5 = 0; n5 < QENTRIES; n5 = n5 + 1)
//	iq_v[n5] = iq[n5].v & iq_inv[n5];
end
/*
initial begin: stop_at
	#1000000; panic = `PANIC_OVERRUN;
end
*/
initial begin: Init
	integer i;

/*
	for (i=0; i<65536; i=i+1)
	    m[i] = 0;
*/
//	$readmemh("init.dat", m);
	for (i=0; i<QENTRIES; i=i+1) begin
	  iq[i].v = INV;
	end

//	dram2 = 0;

	//
	// set up panic messages
	message[ `PANIC_NONE ]			= "NONE            ";
	message[ `PANIC_FETCHBUFBEQ ]		= "FETCHBUFBEQ     ";
	message[ `PANIC_INVALIDISLOT ]		= "INVALIDISLOT    ";
	message[ `PANIC_IDENTICALDRAMS ]	= "IDENTICALDRAMS  ";
	message[ `PANIC_OVERRUN ]		= "OVERRUN         ";
	message[ `PANIC_HALTINSTRUCTION ]	= "HALTINSTRUCTION ";
	message[ `PANIC_INVALIDMEMOP ]		= "INVALIDMEMOP    ";
	message[ `PANIC_INVALIDFBSTATE ]	= "INVALIDFBSTATE  ";
	message[ `PANIC_INVALIDIQSTATE ]	= "INVALIDIQSTATE  ";
	message[ `PANIC_BRANCHBACK ]		= "BRANCHBACK      ";
	message[ `PANIC_MEMORYRACE ]		= "MEMORYRACE      ";

end

address_t pco;
wire ihito,ihit;

instruction_t [4:0] inst0, inst1;
instruction_t ins0, ins1;
instruction_t [3:0] pfx0;
instruction_t [3:0] pfx1;
ICacheLine ic_line_hi, ic_line_lo;
reg [1023:0] ic_line;

reg [9:0] pci;

always_comb
if (ICacheBundleWidth==120)
	case(pco[3:0])
	4'h0:	pci <= {4'b0,pco[5:4],4'h5};
	4'h5:	pci <= {4'b0,pco[5:4],4'hA};
	4'hA:	pci <= {{4'b0,pco[5:4]}+2'd1,4'h0};
	default:	pci <= {4'b0,pco[5:4],4'h5};
	endcase
else
	pci <= {{1'b0,pco[5:0]}+4'd5,3'd0};

always_comb
	ic_line = {ic_line_hi.data,ic_line_lo.data};
always_comb
if (ICacheBundleWidth==120)
	{pfx0[3],pfx0[2],pfx0[1],pfx0[0],ins0} = ic_line >> (pco[5:4] * 120 + pco[3:2] * 40);
else
	{pfx0[3],pfx0[2],pfx0[1],pfx0[0],ins0} = ic_line >> {pco[5:0],3'd0};
always_comb
if (ICacheBundleWidth==120)
	{pfx1[3],pfx1[2],pfx1[1],pfx1[0],ins1} = ic_line >> (pci[5:4] * 120 + pci[3:2] * 40);
else
	{pfx1[3],pfx1[2],pfx1[1],pfx1[0],ins1} = ic_line >> {{1'b0,pco[5:0]}+4'd5,3'd0};

// hirq squashes the pc increment if there's an irq.
// Normally atom_mask is zero.
reg hirq;

always_comb
if ((fnIsAtom(fetchbuf0_instr) || fnIsAtom(fetchbuf1_instr)) && irq_i != 3'd7)
	hirq = 'd0;
else
	hirq = (irq_i > im) && ~int_commit && (irq_i > atom_mask[2:0]);
always_comb
if (hirq)
	inst0 <= {{4{33'h1FFFFFFFF,OP_NOP}},FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS};
else //if (ihito)
 	inst0 <= {pfx0[3],pfx0[2],pfx0[1],pfx0[0],ins0};
//else
//  inst0 <= {5{33'h1FFFFFFFE,OP_NOP}};

always_comb
if (hirq)
	inst1 <= {{4{33'h1FFFFFFFF,OP_NOP}},FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS};
else //if (ihito)
  inst1 <= {pfx1[3],pfx1[2],pfx1[1],pfx1[0],ins1};
//else
//  inst1 <= {5{33'h1FFFFFFFE,OP_NOP}};


/*
always_comb
	if (dram0_op==`LW || dram1_op==`LW || dram2_op==`LW)
		adr_o = icache_radr;
	else
		adr_o = icache_uadr;
*/
	
//
// FETCH
//
// fetch exactly two instructions from memory into the fetch buffer
// unless either one of the buffers is still full, in which case we
// do nothing (kinda like alpha approach)
//

pc_address_t next_pc;
wire ntakb,ptakb;
reg invce = 1'b0;
reg dc_invline = 1'b0;
reg dc_invall = 1'b0;
reg ic_invline = 1'b0;
reg ic_invall = 1'b0;
ICacheLine ic_line_o;

wire wr_ic;
wire ic_valid;
address_t ic_miss_adr;
asid_t ic_miss_asid;
wire [1:0] ic_wway;
  
Thor2024_icache
#(.CORENO(CORENO),.CID(0))
uic1
(
	.rst(rst),
	.clk(clk),
	.invce(invce),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_cid(snoop_cid),
	.invall(ic_invall),
	.invline(ic_invline),
	.ip_asid(ip_asid),
	.ip(pc.pc),
	.ip_o(pco),
	.ihit_o(ihito),
	.ihit(ihit),
	.ic_line_hi_o(ic_line_hi),
	.ic_line_lo_o(ic_line_lo),
	.ic_valid(ic_valid),
	.miss_adr(ic_miss_adr),
	.miss_asid(ic_miss_asid),
	.ic_line_i(ic_line_o),
	.wway(ic_wway),
	.wr_ic(wr_ic)
);

Thor2024_icache_ctrl
#(.CORENO(CORENO),.CID(0))
icctrl1
(
	.rst(rst),
	.clk(clk),
	.wbm_req(ftaim_req),
	.wbm_resp(ftaim_resp),
	.ftam_full(ftaim_full),
	.hit(ihit),
	.miss_adr(ic_miss_adr),
	.miss_asid(ic_miss_asid),
	.wr_ic(wr_ic),
	.way(ic_wway),
	.line_o(ic_line_o),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_cid(snoop_cid)
);

Thor2024_btb ubtb1
(
	.rst(rst),
	.clk(clk),
	.rclk(~clk),
	.pc(pc),
	.next_pc(next_pc),
	.takb(ntakb),
	.commit_pc0(commit_pc0),
	.commit_brtgt0(commit_brtgt0),
	.commit_takb0(commit_takb0),
	.commit_pc1(commit_pc1),
	.commit_brtgt1(commit_brtgt1),
	.commit_takb1(commit_takb1)
);

Thor2024_ifetch uif1
(
	.rst(rst),
	.clk(clk),
	.hit(ihito),
	.irq(hirq),
	.branchback(branchback),
	.backpc(backpc),
	.branchmiss(branchmiss),
	.misspc(misspc),
	.missir(missir),
	.next_pc(next_pc),
	.takb(ntakb),
	.ptakb(ptakb),
	.pc(pc),
	.pc_i({pco,12'h000}),
	.stall(istall),
	.inst0(inst0),
	.inst1(inst1),
	.iq(iq),
	.tail0(tail0),
	.tail1(tail1),
	.fetchbuf(fetchbuf),
	.fetchbuf0_instr(fetchbuf0_instr),
	.fetchbuf0_v(fetchbuf0_v),
	.fetchbuf0_pc(fetchbuf0_pc),
	.fetchbuf1_instr(fetchbuf1_instr),
	.fetchbuf1_v(fetchbuf1_v),
	.fetchbuf1_pc(fetchbuf1_pc),
	.commit0_v(commit0_v),
	.commit0_instr(commit0_instr),	
	.commit0_pc(commit_pc0),
	.commit1_v(commit1_v),
	.commit1_instr(commit1_instr),	
	.commit1_pc(commit_pc0)
);

Thor2024_decoder udeci0
(
	.instr(fetchbuf0_instr),
	.db(db0)
);

Thor2024_decoder udeci1
(
	.instr(fetchbuf1_instr),
	.db(db1)
);

assign fetchbuf0_rfw = Rt0 != 'd0;
assign fetchbuf1_rfw = Rt1 != 'd0;

/* under construction */
always_comb
	q1open = ~iq_v[tail0];
always_comb
	q2open = ~iq_v[tail0] & ~iq_v[tail1];
always_comb
begin
	canq1 = FALSE;
	canq2 = FALSE;
	queued2Nop = FALSE;
	queued1Nop = FALSE;
	if (!branchmiss) begin
		if (fetchbuf0_v & fetchbuf1_v) begin
			canq2 = TRUE;
			if (fnIsNop(fetchbuf0_instr[0]) && fnIsNop(fetchbuf1_instr[0]))
				queued2Nop = TRUE;
		end
		else if (fetchbuf0_v) begin
			canq1 = TRUE;
			if (fnIsNop(fetchbuf0_instr[0]))
				queued1Nop = TRUE;
		end
		else if (fetchbuf1_v) begin
			canq1 = TRUE;
			if (fnIsNop(fetchbuf1_instr[0]))
				queued1Nop = TRUE;
		end
	end
end

wire [NDATA_PORTS-1:0] dcache_load;
wire [NDATA_PORTS-1:0] dhit;
wire [NDATA_PORTS-1:0] modified;
wire [1:0] uway [0:NDATA_PORTS-1];
fta_cmd_request512_t [NDATA_PORTS-1:0] cpu_request_i;
fta_cmd_request512_t [NDATA_PORTS-1:0] cpu_request_i2;
fta_cmd_response512_t [NDATA_PORTS-1:0] cpu_resp_o;
fta_cmd_response512_t [NDATA_PORTS-1:0] update_data_i;
wire [NDATA_PORTS-1:0] dump;
wire DCacheLine dump_o[0:NDATA_PORTS-1];
wire [NDATA_PORTS-1:0] dump_ack;
wire [NDATA_PORTS-1:0] dwr;
wire [1:0] dway [0:NDATA_PORTS-1];

always_comb
begin
	dramN[0] = dram0;
	dramN_addr[0] = dram0_addr;
	dramN_data[0] = dram0_data[511:0];
	dramN_sel[0] = dram0_sel[63:0];
	dramN_store[0] = dram0_store;
	dramN_load[0] = dram0_load;
	dramN_loadz[0] = dram0_loadz;
	dramN_memsz[0] = dram0_memsz;
	dramN_tid[0] = dram0_tid;
	dram0_ack = dramN_ack[0];

	if (NDATA_PORTS > 1) begin
		dramN[1] = dram1;
		dramN_addr[1] = dram1_addr;
		dramN_data[1] = dram1_data[511:0];
		dramN_sel[1] = dram1_sel[63:0];
		dramN_store[1] = dram1_store;
		dramN_load[1] = dram1_load;
		dramN_loadz[1] = dram1_loadz;
		dramN_memsz[1] = dram1_memsz;
		dramN_tid[1] = dram1_tid;
		dram1_ack = dramN_ack[1];
	end

/*
	dramN[2] = dram2;
	dramN_addr[2] = dram2_addr;
	dramN_data[2] = dram2_data;
	dramN_store[2] = dram2_store;
	dram2_ack = dramN_ack[2];
*/
end

generate begin : gDcache
for (g = 0; g < NDATA_PORTS; g = g + 1) begin

	always_comb
	begin
		cpu_request_i[g].cid = CID + g + 1;
		cpu_request_i[g].tid = dramN_tid[g];
		cpu_request_i[g].om = fta_bus_pkg::MACHINE;
		cpu_request_i[g].cmd = dramN_store[g] ? CMD_STORE : dramN_loadz[g] ? CMD_LOADZ : dramN_load[g] ? CMD_LOAD : CMD_NONE;
		cpu_request_i[g].bte = fta_bus_pkg::LINEAR;
		cpu_request_i[g].cti = fta_bus_pkg::CLASSIC;
		cpu_request_i[g].blen = 'd0;
		cpu_request_i[g].seg = fta_bus_pkg::DATA;
		cpu_request_i[g].asid = ip_asid;
		cpu_request_i[g].cyc = dramN[g]==DRAMSLOT_READY;
		cpu_request_i[g].stb = dramN[g]==DRAMSLOT_READY;
		cpu_request_i[g].we = dramN_store[g];
		cpu_request_i[g].vadr = dramN_addr[g];
		cpu_request_i[g].padr = 'd0;
		cpu_request_i[g].sz = fta_bus_pkg::fta_size_t'(dramN_memsz[g]);
		cpu_request_i[g].dat = dramN_data[g];
		cpu_request_i[g].sel = dramN_sel[g];
		cpu_request_i[g].pl = 8'h00;
		cpu_request_i[g].pri = 4'd7;
		cpu_request_i[g].cache = fta_bus_pkg::WT_READWRITE_ALLOCATE;
		dramN_ack[g] = cpu_resp_o[g].ack;
	end

	Thor2024_dcache
	#(.CORENO(CORENO), .CID(g+1))
	udc1
	(
		.rst(rst),
		.clk(clk),
		.dce(1'b1),
		.snoop_adr(snoop_adr),
		.snoop_v(snoop_v),
		.snoop_cid(snoop_cid),
		.cache_load(dcache_load[g]),
		.hit(dhit[g]),
		.modified(modified[g]),
		.uway(uway[g]),
		.cpu_req_i(cpu_request_i2[g]),
		.cpu_resp_o(cpu_resp_o[g]),
		.update_data_i(update_data_i[g]),
		.dump(dump[g]),
		.dump_o(dump_o[g]),
		.dump_ack_i(dump_ack[g]),
		.wr(dwr[g]),
		.way(dway[g]),
		.invce(invce),
		.dc_invline(dc_invline),
		.dc_invall(dc_invall)
	);

	Thor2024_dcache_ctrl
	#(.CORENO(CORENO), .CID(g+1))
	udcctrl1
	(
		.rst_i(rst),
		.clk_i(clk),
		.dce(1'b1),
		.ftam_req(ftadm_req[g]),
		.ftam_resp(ftadm_resp[g]),
		.ftam_full(ftadm_full),
		.acr(),
		.hit(dhit[g]),
		.modified(modified[g]),
		.cache_load(dcache_load[g]),
		.cpu_request_i(cpu_request_i[g]),
		.cpu_request_i2(cpu_request_i2[g]),
		.data_to_cache_o(update_data_i[g]),
		.response_from_cache_i(cpu_resp_o[g]),
		.wr(dwr[g]),
		.uway(uway[g]),
		.way(dway[g]),
		.dump(dump[g]),
		.dump_i(dump_o[g]),
		.dump_ack(dump_ack[g]),
		.snoop_adr(snoop_adr),
		.snoop_v(snoop_v),
		.snoop_cid(snoop_cid)
	);

end
end
endgenerate

/* 
assign db0.mem   = (fetchbuf == 1'b0) 
		? (fetchbufA_instr[`INSTRUCTION_OP] == `LW || fetchbufA_instr[`INSTRUCTION_OP] == `SW)
		: (fetchbufC_instr[`INSTRUCTION_OP] == `LW || fetchbufC_instr[`INSTRUCTION_OP] == `SW);
assign fetchbuf0_jmp   = (fetchbuf == 1'b0)
		? (fetchbufA_instr[`INSTRUCTION_OP] == `BEQ || fetchbufA_instr[`INSTRUCTION_OP] == `JALR)
		: (fetchbufC_instr[`INSTRUCTION_OP] == `BEQ || fetchbufC_instr[`INSTRUCTION_OP] == `JALR);
assign fetchbuf0_rfw   = (fetchbuf == 1'b0)
		? (fetchbufA_instr[`INSTRUCTION_OP] != `BEQ && fetchbufA_instr[`INSTRUCTION_OP] != `SW)
		: (fetchbufC_instr[`INSTRUCTION_OP] != `BEQ && fetchbufC_instr[`INSTRUCTION_OP] != `SW);

assign db1.mem   = (fetchbuf == 1'b0) 
		? (fetchbufB_instr[`INSTRUCTION_OP] == `LW || fetchbufB_instr[`INSTRUCTION_OP] == `SW)
		: (fetchbufD_instr[`INSTRUCTION_OP] == `LW || fetchbufD_instr[`INSTRUCTION_OP] == `SW);
assign fetchbuf1_jmp   = (fetchbuf == 1'b0)
		? (fetchbufB_instr[`INSTRUCTION_OP] == `BEQ || fetchbufB_instr[`INSTRUCTION_OP] == `JALR)
		: (fetchbufD_instr[`INSTRUCTION_OP] == `BEQ || fetchbufD_instr[`INSTRUCTION_OP] == `JALR);
assign fetchbuf1_rfw   = (fetchbuf == 1'b0)
		? (fetchbufB_instr[`INSTRUCTION_OP] != `BEQ && fetchbufB_instr[`INSTRUCTION_OP] != `SW)
		: (fetchbufD_instr[`INSTRUCTION_OP] != `BEQ && fetchbufD_instr[`INSTRUCTION_OP] != `SW);
*/
//
// BRANCH-MISS LOGIC: livetarget
//
// livetarget implies that there is a not-to-be-stomped instruction that targets the register in question
// therefore, if it is zero it implies the rf_v value should become VALID on a branchmiss
// 

always_comb
for (n7 = 1; n7 < AREGS; n7 = n7 + 1)
	livetarget[n7] = iqentry_livetarget[0][n7]
								| iqentry_livetarget[1][n7]
								| iqentry_livetarget[2][n7]
								| iqentry_livetarget[3][n7]
	    					| iqentry_livetarget[4][n7]
	    					| iqentry_livetarget[5][n7]
	    					| iqentry_livetarget[6][n7]
	    					| iqentry_livetarget[7][n7]
	    					;

always_comb
for (n6 = 0; n6 < QENTRIES; n6 = n6 + 1)
	iqentry_livetarget[n6] = {63 {iq_v[n6]}} & {63 {~iqentry_stomp[n6]}} & iq_out[n6];

assign iqentry_0_cumulative = (missid==3'd0) ? iqentry_livetarget[0] :
                              (missid==3'd1) ? iqentry_livetarget[0] |
                                               iqentry_livetarget[1] :
                              (missid==3'd2) ? iqentry_livetarget[0] |
                                               iqentry_livetarget[1] |
                                               iqentry_livetarget[2] :
                              (missid==3'd3) ? iqentry_livetarget[0] |
                                               iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] :
                              (missid==3'd4) ? iqentry_livetarget[0] |
                                               iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] | 
                                               iqentry_livetarget[4] :
                              (missid==3'd5) ? iqentry_livetarget[0] |
                                               iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] | 
                                               iqentry_livetarget[4] |
                                               iqentry_livetarget[5] :
                              (missid==3'd6) ? iqentry_livetarget[0] |
                                               iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] | 
                                               iqentry_livetarget[4] |
                                               iqentry_livetarget[5] |
                                               iqentry_livetarget[6] :
                              (missid==3'd7) ? iqentry_livetarget[0] |
                                               iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] | 
                                               iqentry_livetarget[4] |
                                               iqentry_livetarget[5] |
                                               iqentry_livetarget[6] |
                                               iqentry_livetarget[7] :
                                               'd0;

assign iqentry_1_cumulative = (missid==3'd1) ? iqentry_livetarget[1] :
                              (missid==3'd2) ? iqentry_livetarget[1] |
                                               iqentry_livetarget[2] :
                              (missid==3'd3) ? iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] :
                              (missid==3'd4) ? iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] |
                                               iqentry_livetarget[4] :
                              (missid==3'd5) ? iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] |
                                               iqentry_livetarget[4] | 
                                               iqentry_livetarget[5] :
                              (missid==3'd6) ? iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] |
                                               iqentry_livetarget[4] | 
                                               iqentry_livetarget[5] |
                                               iqentry_livetarget[6] :
                              (missid==3'd7) ? iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] |
                                               iqentry_livetarget[4] | 
                                               iqentry_livetarget[5] |
                                               iqentry_livetarget[6] |
                                               iqentry_livetarget[7] :
                              (missid==3'd0) ? iqentry_livetarget[1] |
                                               iqentry_livetarget[2] |
                                               iqentry_livetarget[3] |
                                               iqentry_livetarget[4] | 
                                               iqentry_livetarget[5] |
                                               iqentry_livetarget[6] |
                                               iqentry_livetarget[7] |
                                               iqentry_livetarget[0] :
                                               'd0;

assign iqentry_2_cumulative = (missid==3'd2) ? iqentry_livetarget[2] :
                                 (missid==3'd3) ? iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] :
                                 (missid==3'd4) ? iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] :
                                 (missid==3'd5) ? iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] :
                                 (missid==3'd6) ? iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] | 
                                                  iqentry_livetarget[6] :
                                 (missid==3'd7) ? iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] | 
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] :
                                 (missid==3'd0) ? iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] | 
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] :
                                 (missid==3'd1) ? iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] | 
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] |
                                                  iqentry_livetarget[1] :
                                                  'd0;

assign iqentry_3_cumulative = (missid==3'd3) ? iqentry_livetarget[3] :
                                 (missid==3'd4) ? iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] :
                                 (missid==3'd5) ? iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] :
                                 (missid==3'd6) ? iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] :
                                 (missid==3'd7) ? iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] | 
                                                  iqentry_livetarget[7] :
                                 (missid==3'd0) ? iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] | 
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] :
                                 (missid==3'd1) ? iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] | 
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] |
                                                  iqentry_livetarget[1] :
                                 (missid==3'd2) ? iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] | 
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] |
                                                  iqentry_livetarget[1] |
                                                  iqentry_livetarget[2] :
                                                  'd0;

assign iqentry_4_cumulative = (missid==3'd4) ? iqentry_livetarget[4] :
                                 (missid==3'd5) ? iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] :
                                 (missid==3'd6) ? iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] :
                                 (missid==3'd7) ? iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] :
                                 (missid==3'd0) ? iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] | 
                                                  iqentry_livetarget[0] :
                                 (missid==3'd1) ? iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] | 
                                                  iqentry_livetarget[0] |
                                                  iqentry_livetarget[1] :
                                 (missid==3'd2) ? iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] | 
                                                  iqentry_livetarget[0] |
                                                  iqentry_livetarget[1] |
                                                  iqentry_livetarget[2] :
                                 (missid==3'd3) ? iqentry_livetarget[4] |
                                                  iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] | 
                                                  iqentry_livetarget[0] |
                                                  iqentry_livetarget[1] |
                                                  iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] :
                                                  'd0;

assign iqentry_5_cumulative = (missid==3'd5) ? iqentry_livetarget[5] :
                                 (missid==3'd6) ? iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] :
                                 (missid==3'd7) ? iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] :
                                 (missid==3'd0) ? iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] :
                                 (missid==3'd1) ? iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] | 
                                                  iqentry_livetarget[1] :
                                 (missid==3'd2) ? iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] | 
                                                  iqentry_livetarget[1] |
                                                  iqentry_livetarget[2] :
                                 (missid==3'd3) ? iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] | 
                                                  iqentry_livetarget[1] |
                                                  iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] :
                                 (missid==3'd4) ? iqentry_livetarget[5] |
                                                  iqentry_livetarget[6] |
                                                  iqentry_livetarget[7] |
                                                  iqentry_livetarget[0] | 
                                                  iqentry_livetarget[1] |
                                                  iqentry_livetarget[2] |
                                                  iqentry_livetarget[3] |
                                                  iqentry_livetarget[4] :
                                                  'd0;
assign iqentry_6_cumulative = (missid==3'd6) ? iqentry_livetarget[6] :
                                   (missid==3'd7) ? iqentry_livetarget[6] |
                                                    iqentry_livetarget[7] :
                                   (missid==3'd0) ? iqentry_livetarget[6] |
                                                    iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] :
                                   (missid==3'd1) ? iqentry_livetarget[6] |
                                                    iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] :
                                   (missid==3'd2) ? iqentry_livetarget[6] |
                                                    iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] | 
                                                    iqentry_livetarget[2] :
                                   (missid==3'd3) ? iqentry_livetarget[6] |
                                                    iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] | 
                                                    iqentry_livetarget[2] |
                                                    iqentry_livetarget[3] :
                                   (missid==3'd4) ? iqentry_livetarget[6] |
                                                    iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] | 
                                                    iqentry_livetarget[2] |
                                                    iqentry_livetarget[3] |
                                                    iqentry_livetarget[4] :
                                   (missid==3'd5) ? iqentry_livetarget[6] |
                                                    iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] | 
                                                    iqentry_livetarget[2] |
                                                    iqentry_livetarget[3] |
                                                    iqentry_livetarget[4] |
                                                    iqentry_livetarget[5] :
                                                    'd0;

assign iqentry_7_cumulative = (missid==3'd7) ? iqentry_livetarget[7] :
                                   (missid==3'd0) ? iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] :
                                   (missid==3'd1) ? iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] :
                                   (missid==3'd2) ? iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] |
                                                    iqentry_livetarget[2] :
                                   (missid==3'd3) ? iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] |
                                                    iqentry_livetarget[2] | 
                                                    iqentry_livetarget[3] :
                                   (missid==3'd4) ? iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] |
                                                    iqentry_livetarget[2] | 
                                                    iqentry_livetarget[3] |
                                                    iqentry_livetarget[4] :
                                   (missid==3'd5) ? iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] |
                                                    iqentry_livetarget[2] | 
                                                    iqentry_livetarget[3] |
                                                    iqentry_livetarget[4] |
                                                    iqentry_livetarget[5] :
                                   (missid==3'd6) ? iqentry_livetarget[7] |
                                                    iqentry_livetarget[0] |
                                                    iqentry_livetarget[1] |
                                                    iqentry_livetarget[2] | 
                                                    iqentry_livetarget[3] |
                                                    iqentry_livetarget[4] |
                                                    iqentry_livetarget[5] |
                                                    iqentry_livetarget[6] :
                                                    'd0;

assign iqentry_0_latestID = (missid == 3'd0 || ((iqentry_livetarget[0] & iqentry_1_cumulative) == 'd0))
		    ? iqentry_livetarget[0]
		    : 'd0;

assign iqentry_1_latestID = (missid == 3'd1 || ((iqentry_livetarget[1] & iqentry_2_cumulative) == 'd0))
		    ? iqentry_livetarget[1]
		    : 'd0;

assign iqentry_2_latestID = (missid == 3'd2 || ((iqentry_livetarget[2] & iqentry_3_cumulative) == 'd0))
		    ? iqentry_livetarget[2]
		    : 'd0;

assign iqentry_3_latestID = (missid == 3'd3 || ((iqentry_livetarget[3] & iqentry_4_cumulative) == 'd0))
		    ? iqentry_livetarget[3]
		    : 'd0;

assign iqentry_4_latestID = (missid == 3'd4 || ((iqentry_livetarget[4] & iqentry_5_cumulative) == 'd0))
		    ? iqentry_livetarget[4]
		    : 'd0;

assign iqentry_5_latestID = (missid == 3'd5 || ((iqentry_livetarget[5] & iqentry_6_cumulative) == 'd0))
		    ? iqentry_livetarget[5]
		    : 'd0;

assign iqentry_6_latestID = (missid == 3'd6 || ((iqentry_livetarget[6] & iqentry_7_cumulative) == 'd0))
		    ? iqentry_livetarget[6]
		    : 'd0;

assign iqentry_7_latestID = (missid == 3'd7 || ((iqentry_livetarget[7] & iqentry_0_cumulative) == 'd0))
		    ? iqentry_livetarget[7]
		    : 'd0;

assign 
	iqentry_source[0] = | iqentry_0_latestID,
  iqentry_source[1] = | iqentry_1_latestID,
  iqentry_source[2] = | iqentry_2_latestID,
  iqentry_source[3] = | iqentry_3_latestID,
  iqentry_source[4] = | iqentry_4_latestID,
  iqentry_source[5] = | iqentry_5_latestID,
  iqentry_source[6] = | iqentry_6_latestID,
  iqentry_source[7] = | iqentry_7_latestID;

Thor2024_head uhead1
(
	.rst(rst),
	.clk(clk),
	.heads(heads),
	.tail0(tail0),
	.tail1(tail1),
	.iq(iq),
	.panic_i(panic),
	.panic_o(head_panic),
	.I(I)
);

Thor2024_tail utail1
(
	.rst(rst),
	.clk(clk),
	.branchmiss(branchmiss),
	.fetchbuf0_v(fetchbuf0_v),
	.fetchbuf1_v(fetchbuf1_v),
	.iq(iq),
	.tail0(tail0),
	.tail1(tail1)
);


Thor2024_regfile_source urfs1
(
	.rst(rst),
	.clk(clk),
	.tail0(tail0),
	.tail1(tail1),
	.branchmiss(branchmiss),
	.did_branchback(did_branchback),
	.Rt0(Rt0),
	.Rt1(Rt1),
	.fetchbuf0_instr(fetchbuf0_instr[0]),
	.fetchbuf1_instr(fetchbuf1_instr[0]),
	.fetchbuf0_mem(db0.mem),
	.fetchbuf1_mem(db1.mem),
	.fetchbuf0_v(fetchbuf0_v),
	.fetchbuf1_v(fetchbuf1_v),
	.fetchbuf0_rfw(fetchbuf0_rfw),
	.fetchbuf1_rfw(fetchbuf1_rfw),
	.iqentry_0_latestID(iqentry_0_latestID),
	.iqentry_1_latestID(iqentry_1_latestID),
	.iqentry_2_latestID(iqentry_2_latestID),
	.iqentry_3_latestID(iqentry_3_latestID),
	.iqentry_4_latestID(iqentry_4_latestID),
	.iqentry_5_latestID(iqentry_5_latestID),
	.iqentry_6_latestID(iqentry_6_latestID),
	.iqentry_7_latestID(iqentry_7_latestID),
	.iq(iq),
	.rf_source(rf_source)
);

Thor2024_regfile_valid urfv1
(
	.rst(rst),
	.clk(clk),
	.branchmiss(branchmiss),
	.did_branchback(did_branchback),
	.Rt0(Rt0),
	.Rt1(Rt1),
	.livetarget(livetarget),
	.tail0(tail0),
	.tail1(tail1),
	.fetchbuf0_v(fetchbuf0_v),
	.fetchbuf1_v(fetchbuf1_v),
	.fetchbuf0_rfw(fetchbuf0_rfw),
	.fetchbuf1_rfw(fetchbuf1_rfw),
	.fetchbuf0_instr(fetchbuf0_instr[0]),
	.fetchbuf1_instr(fetchbuf1_instr[0]),
	.iq(iq),
	.iqentry_source(iqentry_source),
	.commit0_v(commit0_v),
	.commit1_v(commit1_v),
	.commit0_tgt(commit0_tgt),
	.commit1_tgt(commit1_tgt),
	.commit0_id(commit0_id),
	.commit1_id(commit1_id),
	.rf_source(rf_source),
	.rf_v(rf_v)
);

/*
Thor2024_regfile urf1
(
	.rst(rst),
	.clk(clk),
	.commit0_v(commit0_v),
	.commit1_v(commit1_v),
	.commit0_tgt(commit0_tgt),
	.commit1_tgt(commit1_tgt),
	.commit0_bus(commit0_bus),
	.commit1_bus(commit1_bus),
	.rf(rf)
);
*/

Thor2024_regfile2w10r urf2
(
	.rst(rst),
	.clk(clk),
	.pc0(fetchbuf0_pc),
	.pc1(fetchbuf1_pc),
	.wr0(commit0_v),
	.wr1(commit1_v),
	.we0(8'hFF),
	.we1(8'hFF),
	.wa0({regset,commit0_tgt}),
	.wa1({regset,commit1_tgt}),
	.i0(commit0_bus),
	.i1(commit1_bus),
	.rclk(clk2x_i),
	.ra0({regset,Ra0}),
	.ra1({regset,Rb0}),
	.ra2({regset,Rc0}),
	.ra3({regset,Rt0}),
	.ra4({regset,Rp0}),
	.ra5({regset,Ra1}),
	.ra6({regset,Rb1}),
	.ra7({regset,Rc1}),
	.ra8({regset,Rt1}),
	.ra9({regset,Rp1}),
	.o0(rfoa0),
	.o1(rfob0),
	.o2(rfoc0),
	.o3(rfot0),
	.o4(rfop0),
	.o5(rfoa1),
	.o6(rfob1),
	.o7(rfoc1),
	.o8(rfot1),
	.o9(rfop1)
);

always_comb
	Ra0 = db0.Ra;
always_comb
	Rb0 = db0.Rb;
always_comb
	Rc0 = db0.Rc;
always_comb
	Rt0 = db0.Rt;
always_comb
	Rp0 = &pred_mask[3:0] ? db0.Rp : {2'b10,pred_mask[3:0]};
always_comb
	Ra1 = db1.Ra;
always_comb
	Rb1 = db1.Rb;
always_comb
	Rc1 = db1.Rc;
always_comb
	Rt1 = db1.Rt;
always_comb
	Rp1 = &pred_mask[7:4] ? db1.Rp : {2'b10,pred_mask[7:4]};

always_comb
	did_branchback = did_branchback1;// & ~did_branchback2;

//
// additional logic for ISSUE
//
// for the moment, we look at ALU-input buffers to allow back-to-back issue of 
// dependent instructions ... we do not, however, look ahead for DRAM requests 
// that will become valid in the next cycle.  instead, these have to propagate
// their results into the IQ entry directly, at which point it becomes issue-able
//

// note that, for all intents & purposes, iqentry_done == iqentry_agen ... no need to duplicate

que_bitmask_t args_valid;
que_bitmask_t could_issue;

generate begin : issue_logic
for (g = 0; g < QENTRIES; g = g + 1)
begin
assign args_valid[g] = (iq[g].a1_v
				    || (iq[g].a1_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].a1_s == alu1_sourceid && alu1_dataready))
				    && (iq[g].a2_v
				    || (iq[g].a2_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].a2_s == alu1_sourceid && alu1_dataready))
				    && (iq[g].a3_v
				    || (iq[g].mem & ~iq[g].agen)
				    || (iq[g].a3_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].a3_s == alu1_sourceid && alu1_dataready))
				    && (iq[g].at_v
				    || (iq[g].at_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].at_s == alu1_sourceid && alu1_dataready))
				    && (iq[g].ap_v
				    || (iq[g].ap_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].ap_s == alu1_sourceid && alu1_dataready))
				    ;
assign could_issue[g] = iq_v[g] && !iq[g].done 
												&& !iq[g].out
												&& args_valid[g]
                        && (iq[g].mem ? !iq[g].agen : 1'b1);
end                                 
end
endgenerate

Thor2024_alu_issue ualuiss1
(
	.alu0_idle(alu0_idle),
	.alu1_idle(alu1_idle),
	.iqentry_islot(iqentry_islot),
	.could_issue(could_issue), 
	.head0(heads[0]),
	.head1(heads[1]),
	.head2(heads[2]),
	.head3(heads[3]),
	.head4(heads[4]),
	.head5(heads[5]),
	.head6(heads[6]),
	.head7(heads[7]),
	.iq(iq),
	.iqentry_issue(iqentry_issue)
);

Thor2024_fpu_issue ufpuiss1
(
	.fpu_idle(fpu_idle),
	.could_issue(could_issue), 
	.head0(heads[0]),
	.head1(heads[1]),
	.head2(heads[2]),
	.head3(heads[3]),
	.head4(heads[4]),
	.head5(heads[5]),
	.head6(heads[6]),
	.head7(heads[7]),
	.iq(iq),
	.iqentry_fpu_issue(iqentry_fpu_issue)
);

Thor2024_fcu_issue ufcuiss1
(
	.fcu_idle(fcu_idle),
	.could_issue(could_issue), 
	.head0(heads[0]),
	.head1(heads[1]),
	.head2(heads[2]),
	.head3(heads[3]),
	.head4(heads[4]),
	.head5(heads[5]),
	.head6(heads[6]),
	.head7(heads[7]),
	.iq(iq),
	.iqentry_fcu_issue(iqentry_fcu_issue)
);

assign iqentry_issue2 = iqentry_issue | iqentry_issue_reg;

/*
always_comb
	for (n2 = 0; n2 < 8; n2 = n2 + 1) begin
    iqentry_issue[n2] = (iq[n2].v && !iq[n2].out && !iq[n2].agen
				&& (heads[0] == n2[2:0] || ~|iqentry_islot[(n2+7)&7] || (iqentry_islot[(n2+7)&7] == 2'b01 && ~iqentry_issue[(n2+7)&7]))
				&& (iq[n2].a1_v 
				    || (iq[n2].a1_s == alu0_sourceid && alu0_dataready)
				    || (iq[n2].a1_s == alu1_sourceid && alu1_dataready))
				&& (iq[n2].a2_v 
				    || (iq[n2].mem & ~iq[n2].agen)
				    || (iq[n2].a2_s == alu0_sourceid && alu0_dataready)
				    || (iq[n2].a2_s == alu1_sourceid && alu1_dataready)));
				    
    iqentry_islot[n2] = (heads[0] == n2[2:0]) ? 2'b00
				: (iqentry_islot[(n2+7)&7] == 2'b11) ? 2'b11
				: (iqentry_islot[(n2+7)&7] + {1'b0, iqentry_issue[(n2+7)&7]});
	end
*/
// 
// additional logic for handling a branch miss (STOMP logic)
// Must also stomp on the last entry queued as a branch has a delayed effect.
//
//reg [$clog2(QENTRIES)-1:0] n4p;
always_comb
for (n4 = 0; n4 < QENTRIES; n4 = n4 + 1)
begin
	//n4p = (n4 + (QENTRIES-1)) % QENTRIES;
	iqentry_stomp[n4] =
		(branchmiss
		&& iq[n4].sn >= iq[missid].sn
		&& iq_v[n4]
		&& heads[0] != n4[$clog2(QENTRIES)-1:0])
	;
	/*
	iqentry_stomp[n4] = branchmiss
											&& iq[n4].v
											&& heads[0] != n4[$clog2(QENTRIES)-1:0]
											&& (missid == n4p || iqentry_stomp[n4p])
											;
	*/
	// Since branchback happens at queue time there will not be any other
	// instructions coming after the branch except for the two instructions
	// queued due to the fetch delay.
	/*
	if (did_branchback) begin
		if (~lastq0[3])
			iqentry_stomp[lastq0] = iq[lastq0].pc != backpc;
		if (~lastq1[3])
			iqentry_stomp[lastq1] = iq[lastq0].pc != backpc;
	end
	*/
end											
//    	iqentry_stomp[0] = branchmiss && iq[0].v && heads[0] != 3'd0 && (missid == 3'd7 || iqentry_stomp[7]),

Thor2024_memissue umemissue1
(
	.rst(rst),
	.clk(clk), 
	.head0(heads[0]),
	.head1(heads[1]),
	.head2(heads[2]),
	.head3(heads[3]),
	.head4(heads[4]),
	.head5(heads[5]),
	.head6(heads[6]),
	.head7(heads[7]),
	.iqentry_memready(iqentry_memready),
	.iqentry_stomp(iqentry_stomp),
	.iq(iq),
	.iqentry_memissue(iqentry_memissue)
);

//
// EXECUTE
//
value_t csr_res;
always_comb
	tReadCSR(csr_res,alu0_argI[15:0]);

Thor2024_alu ualu0
(
	.rst(rst),
	.clk(clk),
	.clk2x(clk2x_i),
	.ld(alu0_ld),
	.ir(alu0_instr),
	.div(alu0_div),
	.a(alu0_argA),
	.b(alu0_argB),
	.c(alu0_argC),
	.i(alu0_argI),
	.t(alu0_argT),
	.p(alu0_argP),
	.csr(csr_res),
	.o(alu0_bus),
	.mul_done(mul0_done),
	.div_done(div0_done),
	.div_dbz()
);

generate begin : gAlu1
if (NALU > 1) begin
	Thor2024_alu ualu1
	(
		.rst(rst),
		.clk(clk),
		.clk2x(clk2x_i),
		.ld(alu1_ld),
		.ir(alu1_instr),
		.div(alu1_div),
		.a(alu1_argA),
		.b(alu1_argB),
		.c(alu1_argC),
		.i(alu1_argI),
		.t(alu1_argT),
		.p(alu1_argP),
		.csr('d0),
		.o(alu1_bus),
		.mul_done(mul1_done),
		.div_done(div1_done),
		.div_dbz()
	);
end
end
endgenerate

    assign  alu0_v = alu0_dataready,
	    alu1_v = alu1_dataready;

    assign  alu0_id = alu0_sourceid,
	    alu1_id = alu1_sourceid;

    assign  fcu_v = fcu_dataready;
    assign  fcu_id = fcu_sourceid;

generate begin : gFpu
if (NFPU > 0) begin
	Thor2024_fpu ufpu1
	(
		.rst(rst),
		.clk(clk),
		.ir(fpu_instr),
		.rm('d0),
		.a(fpu_argA),
		.b(fpu_argB),
		.c(fpu_argC),
		.t(fpu_argT),
		.i(fpu_argI),
		.p(fpu_argP),
		.o(fpu_bus),
		.done(fpu_done)
	);
end
end
endgenerate

assign fpu_v = fpu_dataready;
assign fpu_id = fpu_sourceid;

pc_address_t tgtpc;

always_comb
	if (fnIsBccR(fcu_instr))
		tgtpc = {fcu_argC + {{53{fcu_instr[39]}},fcu_instr[39:31],fcu_instr[12:11]},12'h000};
	else if (fnIsBranch(fcu_instr))
		tgtpc = {fcu_pc.pc + {{47{fcu_instr[39]}},fcu_instr[39:25],fcu_instr[12:11]},12'h000};
	else if (fnIsCall(fcu_instr))
		tgtpc = {fcu_argA + fcu_argI,12'h000};
	else if (fnIsRti(fcu_instr))
		tgtpc = fcu_instr[8:7]==2'd1 ? pc_stack[1] : pc_stack[0];
	else if (fnIsRet(fcu_instr))
		tgtpc = {fcu_argC + fcu_instr[15:8],12'h000};
	else
		tgtpc = RSTPC;

pc_address_t tpc;
always_comb
	tpc = fnPCInc(fcu_pc);

always_comb
	if (fnIsBccR(fcu_instr)) begin
		fcu_misspc.pc = fcu_bt ? tpc.pc : fcu_argC + {{53{fcu_instr[39]}},fcu_instr[39:31],fcu_instr[12:11]};
		fcu_misspc.micro_ip = 12'h000;
	end
	else if (fnIsBranch(fcu_instr)) begin
		fcu_misspc.pc = fcu_bt ? tpc.pc : fcu_pc.pc + {{47{fcu_instr[39]}},fcu_instr[39:25],fcu_instr[12:11]};
		fcu_misspc.micro_ip = 12'h000;
	end
	else if (fnIsCall(fcu_instr)) begin
		fcu_misspc.pc = fcu_argA + fcu_argI;
		fcu_misspc.micro_ip = 12'h000;
	end
	// Must be tested before Ret
	else if (fnIsRti(fcu_instr)) begin
		fcu_misspc = fcu_instr[8:7]==2'd1 ? pc_stack[1] : pc_stack[0];
	end
	else if (fnIsRet(fcu_instr)) begin
		fcu_misspc = {fcu_argC + fcu_instr[15:8],12'h000};
	end
	else
		fcu_misspc = RSTPC;

always_comb
	fcu_missir <= fcu_instr;


Thor2024_branch_eval ube1
(
	.instr(fcu_instr),
	.a(fcu_argA),
	.b(fcu_argB),
	.takb(takb)
);

always_comb
	if (fnIsCallType(fcu_instr))
		fcu_bus = fcu_pc.pc + 4'd5;
	else
		fcu_bus = tpc;

always_comb
if (fcu_instr.any.opcode==OP_SYS) begin
	case(fcu_instr.sys.func)
	FN_BRK:	fcu_exc = FLT_DBG;
	FN_SYS:	fcu_exc = cause_code_t'(fcu_instr[24:16]);
	default:	fcu_exc = FLT_NONE;
	endcase
end

always_comb
if (fcu_dataready) begin
	if (fnIsBranch(fcu_instr))
		fcu_branchmiss = ((takb && ~fcu_bt) || (!takb && fcu_bt));
	else if (fnIsCall(fcu_instr))
		fcu_branchmiss = TRUE;
	else if (fnIsRet(fcu_instr))
		fcu_branchmiss = TRUE;
	else
		fcu_branchmiss = FALSE;		
end
else begin
	fcu_branchmiss = FALSE;
end

assign  branchmiss = excmiss | fcu_branchmiss,
  misspc = excmiss ? excmisspc : fcu_misspc,
  missir = excmiss ? excir : fcu_missir,
  missid = excmiss ? excid : fcu_sourceid;

//
// additional DRAM-enqueue logic

assign dram_avail = (dram0 == DRAMSLOT_AVAIL);// || dram1 == DRAMSLOT_AVAIL);// || dram2 == DRAMSLOT_AVAIL);

always_comb
for (n9 = 0; n9 < QENTRIES; n9 = n9 + 1)
	iqentry_memopsvalid[n9] = (iq[n9].mem & (iq[n9].load|iq[n9].a3_v) & iq[n9].agen);

always_comb
for (n10 = 0; n10 < QENTRIES; n10 = n10 + 1)
  iqentry_memready[n10] = (iq_v[n10]
  		& iqentry_memopsvalid[n10] 
  		& ~iqentry_memissue[n10] 
  		& ~iq[n10].done 
  		& ~iq[n10].out 
  		& ~iqentry_stomp[n10])
  		;

assign outstanding_stores = (dram0 && dram0_store);// || (dram1 && dram1_store);// || (dram2 && dram2_store);

always_ff @(posedge clk, posedge rst)
if (rst)
	tick <= 'd0;
else
	tick <= tick + 2'd1;

//
// ENQUEUE
//
// place up to two instructions from the fetch buffer into slots in the IQ.
//   note: they are placed in-order, and they are expected to be executed
// 0, 1, or 2 of the fetch buffers may have valid data
// 0, 1, or 2 slots in the instruction queue may be available.
// if we notice that one of the instructions in the fetch buffer is a backwards branch,
// predict it taken (set branchback/backpc and delete any instructions after it in fetchbuf)
//
always_ff @(posedge clk) begin

if (rst)
	tReset();

alu0_ld <= 1'b0;
alu1_ld <= 1'b0;
dram0p <= dram0;
dram1p <= dram1;
commit0a_v <= commit0_v;
commit0a_id <= commit0_id;
commit0a_bus <= commit0_bus;
commit1a_v <= commit1_v;
commit1a_id <= commit1_id;
commit1a_bus <= commit1_bus;
excmiss <= 1'b0;

if (fnIsAtom(fetchbuf0_instr[0]))
	atom_mask <= fetchbuf0_instr[0][30:7];
if (fnIsAtom(fetchbuf1_instr[1]))
	atom_mask <= fetchbuf1_instr[1][30:7];

did_branchback2 <= did_branchback1;

	//
	// enqueue fetchbuf0 and fetchbuf1, but only if there is room, 
	// and ignore fetchbuf1 if fetchbuf0 has a backwards branch in it.
	//
	// also, do some instruction-decode ... set the operand_valid bits in the IQ
	// appropriately so that the DATAINCOMING stage does not have to look at the opcode
	//
	if (!branchmiss) 	// don't bother doing anything if there's been a branch miss

		case ({fetchbuf0_v, fetchbuf1_v})

    2'b00: ; // do nothing

    2'b01:
    	if (iq_v[tail0] == INV) begin
				did_branchback1 <= branchback & ~did_branchback;
				for (n12 = 0; n12 < QENTRIES; n12 = n12 + 1)
					iq[n12].sn <= |iq[n12].sn ? iq[n12].sn - 2'd1 : iq[n12].sn;
				iq[tail0].sn <= 6'h3F;
				iq[tail0].done <= db1.nop;
				iq[tail0].out    <=   INV;
				iq[tail0].res    <=   `ZERO;
				iq[tail0].op    <=   fetchbuf1_instr[0]; 
				iq[tail0].bt    <=   db1.backbr;//(fnIsBackBranch(fetchbuf1_instr[0])) | ptakb; 
				iq[tail0].agen    <=   INV;
				iq[tail0].pc    <=   fetchbuf1_pc;
				iq[tail0].imm <= db1.has_imm;
				iq[tail0].fc <= db1.fc;
		    iq[tail0].alu <= db1.alu;
		    iq[tail0].alu0 <= db1.alu0;
		    iq[tail0].fpu = db1.fpu;
		    iq[tail0].mul <= db1.mul;
		    iq[tail0].mulu <= db1.mulu;
		    iq[tail0].div <= db1.div;
		    iq[tail0].divu <= db1.divu;
		    iq[tail0].sync <= 1'b0;
				iq[tail0].mem <= db1.mem;
				iq[tail0].load <= db1.load;
				iq[tail0].loadz <= db1.loadz;
				iq[tail0].store <= db1.store;
				iq[tail0].jmp    <=   fetchbuf1_jmp;
				iq[tail0].rfw    <=   fetchbuf1_rfw;
				iq[tail0].tgt <= Rt1;
				iq[tail0].exc <= FLT_NONE;
				iq[tail0].takb <= 1'b0;
				iq[tail0].brtgt <= 'd0;
				iq[tail0].Ra <= Ra1;
				iq[tail0].Rb <= Rb1;
				iq[tail0].Rc <= Rc1;
				iq[tail0].Rt <= Rt1;
				iq[tail0].Rp <= Rp1;
				iq[tail0].a0 <= db1.imm;
				iq[tail0].a1 <= fnA1(fetchbuf1_instr[0], rfoa1, db1.imm);
				iq[tail0].a1_v <= fnSource1v(fetchbuf1_instr[0]) || rf_v[ Ra1 ];
				iq[tail0].a1_s <= rf_source [ Ra1 ];
				iq[tail0].a2 <= fnA2(fetchbuf1_instr[0], rfob1, db1.imm);
				iq[tail0].a2_v <= fnSource2v(fetchbuf1_instr[0]) || rf_v[ Rb1 ];
				iq[tail0].a2_s  <= rf_source [ Rb1 ];
				iq[tail0].a3 <= fnA3(fetchbuf1_instr[0], rfoc1, db1.imm);
				iq[tail0].a3_v <= fnSource3v(fetchbuf1_instr[0]) || rf_v[ Rc1 ];
				iq[tail0].a3_s  <= rf_source [ Rc1 ];
				iq[tail0].at <= rfot1;
				iq[tail0].at_v <= fnSourceTv(fetchbuf1_instr[0]) || rf_v[ Rt1 ];
				iq[tail0].at_s  <= rf_source [ Rt1 ];
				iq[tail0].ap <= fnAP(fetchbuf1_instr[0], rfop1);
				iq[tail0].ap_v <= fnSourcePv(fetchbuf1_instr[0]) || rf_v[ Rp1 ];
				iq[tail0].ap_s  <= rf_source [ Rp1 ];
				lastq0 <= {1'b0,tail0};
				lastq1 <= {1'b1,tail0};
				if (!fnIsPostfix(fetchbuf1_instr[0])) begin
					atom_mask <= atom_mask >> 4'd3;
					pred_mask <= {4'hF,pred_mask} >> 4'd4;
					postfix_mask <= 'd0;
				end
				else
					postfix_mask <= {postfix_mask[4:0],1'b1};
				if (postfix_mask[5])
					iq[tail0].exc <= FLT_PFX;
				if (fnIsPred(fetchbuf1_instr[0])) begin
					pred_mask <= fetchbuf1_instr[0][34:7];
				end
				iqentry_issue_reg[tail0] <= 1'b0;
			end
    2'b10:
    	begin
	    	if (iq_v[tail0] == INV && (~^pred_mask[1:0] || pred_mask[1:0]==pred_val)) begin
					if (!db0.br)		panic <= `PANIC_FETCHBUFBEQ;
					if (!db0.backbr)	panic <= `PANIC_FETCHBUFBEQ;
					//
					// this should only happen when the first instruction is a BEQ-backwards and the IQ
					// happened to be full on the previous cycle (thus we deleted fetchbuf1 but did not
					// enqueue fetchbuf0) ... probably no need to check for LW -- sanity check, just in case
					//
					did_branchback1 <= branchback & ~did_branchback;
					for (n12 = 0; n12 < QENTRIES; n12 = n12 + 1)
						iq[n12].sn <= |iq[n12].sn ? iq[n12].sn - 2'd1 : iq[n12].sn;
					iq[tail0].sn <= 6'h3F;
					iq[tail0].done <= db0.nop;
					iq[tail0].out	<= INV;
					iq[tail0].res	<= `ZERO;
					iq[tail0].op <= fetchbuf0_instr[0]; 			// BEQ
					iq[tail0].bt <= VAL;
					iq[tail0].agen <= INV;
					iq[tail0].pc <= fetchbuf0_pc;
					iq[tail0].imm <= db0.has_imm;
					iq[tail0].fc <= db0.fc;
			    iq[tail0].alu <= db0.alu;
			    iq[tail0].alu0 <= db0.alu0;
			    iq[tail0].fpu = db0.fpu;
			    iq[tail0].mul <= db0.mul;
			    iq[tail0].mulu <= db0.mulu;
			    iq[tail0].div <= db0.div;
			    iq[tail0].divu <= db0.divu;
			    iq[tail0].sync <= 1'b0;
					iq[tail0].mem <= db0.mem;
					iq[tail0].load <= db0.load;
					iq[tail0].loadz <= db0.loadz;
					iq[tail0].store <= db0.store;
					iq[tail0].jmp <= fetchbuf0_jmp;
					iq[tail0].rfw <= fetchbuf0_rfw;
					iq[tail0].tgt <= Rt0;
					iq[tail0].exc    <=	FLT_NONE;
					iq[tail0].takb <= 1'b0;
					iq[tail0].brtgt <= 'd0;
					iq[tail0].Ra <= Ra0;
					iq[tail0].Rb <= Rb0;
					iq[tail0].Rc <= Rc0;
					iq[tail0].Rt <= Rt0;
					iq[tail0].Rp <= Rp0;
					iq[tail0].a0	<=	db0.imm;
					iq[tail0].a1 <= fnA1(fetchbuf0_instr[0], rfoa0, db0.imm);
					iq[tail0].a1_v <= fnSource1v(fetchbuf0_instr[0]) || rf_v[ Ra0 ];
					iq[tail0].a1_s <= rf_source [ Ra0 ];
					iq[tail0].a2 <= fnA2(fetchbuf0_instr[0], rfob0, db0.imm);
					iq[tail0].a2_v <= fnSource2v(fetchbuf0_instr[0]) || rf_v[ Rb0 ];
					iq[tail0].a2_s  <= rf_source [ Rb0 ];
					iq[tail0].a3 <= fnA3(fetchbuf0_instr[0], rfoc0, db0.imm);
					iq[tail0].a3_v <= fnSource3v(fetchbuf0_instr[0]) || rf_v[ Rc0 ];
					iq[tail0].a3_s  <= rf_source [ Rc0 ];
					iq[tail0].at <= rfot0;
					iq[tail0].at_v <= fnSourceTv(fetchbuf0_instr[0]) || rf_v[ Rt0 ];
					iq[tail0].at_s  <= rf_source [ Rt0 ];
					iq[tail0].ap <= fnAP(fetchbuf0_instr[0], rfop0);
					iq[tail0].ap_v <= fnSourcePv(fetchbuf0_instr[0]) || rf_v[ Rp0 ];
					iq[tail0].ap_s  <= rf_source [ Rp0 ];
					lastq0 <= {1'b0,tail0};
					lastq1 <= {1'b1,tail0};
					if (!fnIsPostfix(fetchbuf0_instr[0])) begin
						atom_mask <= atom_mask >> 4'd3;
						pred_mask <= {4'hF,pred_mask} >> 4'd4;
						postfix_mask <= 'd0;
					end
					else
						postfix_mask <= {postfix_mask[4:0],1'b1};
					if (postfix_mask[5])
						iq[tail0].exc <= FLT_PFX;
					if (fnIsPred(fetchbuf0_instr[0]))
						pred_mask <= fetchbuf0_instr[0][34:7];
					iqentry_issue_reg[tail0] <= 1'b0;
		    end
	  	end

    2'b11:
    	if (iq_v[tail0] == INV) begin

				//
				// if the first instruction is a backwards branch, enqueue it & stomp on all following instructions
				//
				if (db0.backbr) begin
					did_branchback1 <= branchback & ~did_branchback;
					for (n12 = 0; n12 < QENTRIES; n12 = n12 + 1)
						iq[n12].sn <= |iq[n12].sn ? iq[n12].sn - 2'd1 : iq[n12].sn;
					iq[tail0].sn <= 6'h3F;
			    iq[tail0].done <=	db0.nop;
			    iq[tail0].out    <=	INV;
			    iq[tail0].res    <=	`ZERO;
			    iq[tail0].op    <=	fetchbuf0_instr[0]; 			// BEQ
			    iq[tail0].bt    <=	VAL;
			    iq[tail0].agen    <=	INV;
			    iq[tail0].pc    <=	fetchbuf0_pc;
					iq[tail0].imm <= db0.has_imm;
					iq[tail0].fc <= db0.fc;
			    iq[tail0].alu <= db0.alu;
			    iq[tail0].alu0 <= db0.alu0;
			    iq[tail0].fpu = db0.fpu;
			    iq[tail0].mul <= db0.mul;
			    iq[tail0].mulu <= db0.mulu;
			    iq[tail0].div <= db0.div;
			    iq[tail0].divu <= db0.divu;
			    iq[tail0].sync <= 1'b0;
			    iq[tail0].mem    <=	db0.mem;
					iq[tail0].load <= db0.load;
					iq[tail0].loadz <= db0.loadz;
					iq[tail0].store <= db0.store;
			    iq[tail0].jmp    <=	fetchbuf0_jmp;
			    iq[tail0].rfw    <=	fetchbuf0_rfw;
					iq[tail0].tgt <= Rt0;
			    iq[tail0].exc    <=	FLT_NONE;
					iq[tail0].takb <= 1'b0;
					iq[tail0].brtgt <= 'd0;
					iq[tail0].Ra <= Ra0;
					iq[tail0].Rb <= Rb0;
					iq[tail0].Rc <= Rc0;
					iq[tail0].Rt <= Rt0;
					iq[tail0].Rp <= Rp0;
			    iq[tail0].a0 <= db0.imm;
					iq[tail0].a1 <= fnA1(fetchbuf0_instr[0], rfoa0, db0.imm);
					iq[tail0].a1_v <= fnSource1v(fetchbuf0_instr[0]) || rf_v[ Ra0 ];
					iq[tail0].a1_s <= rf_source [ Ra0 ];
					iq[tail0].a2 <= fnA2(fetchbuf0_instr[0], rfob0, db0.imm);
					iq[tail0].a2_v <= fnSource2v(fetchbuf0_instr[0]) || rf_v[ Rb0 ];
					iq[tail0].a2_s  <= rf_source [ Rb0 ];
					iq[tail0].a3 <= fnA3(fetchbuf0_instr[0], rfoc0, db0.imm);
					iq[tail0].a3_v <= fnSource3v(fetchbuf0_instr[0]) || rf_v[ Rc0 ];
					iq[tail0].a3_s  <= rf_source [ Rc0 ];
					iq[tail0].at <= rfot0;
					iq[tail0].at_v <= fnSourceTv(fetchbuf0_instr[0]) || rf_v[ Rt0 ];
					iq[tail0].at_s  <= rf_source [ Rt0 ];
					iq[tail0].ap <= fnAP(fetchbuf0_instr[0], rfop0);
					iq[tail0].ap_v <= fnSourcePv(fetchbuf0_instr[0]) || rf_v[ Rp0 ];
					iq[tail0].ap_s  <= rf_source [ Rp0 ];
					lastq0 <= {1'b0,tail0};
					lastq1 <= {1'b1,tail0};
					if (!fnIsPostfix(fetchbuf0_instr[0])) begin
						atom_mask <= atom_mask >> 4'd3;
						pred_mask <= {4'hF,pred_mask} >> 4'd4;
						postfix_mask <= 'd0;
					end
					else
						postfix_mask <= {postfix_mask[4:0],1'b1};
					if (postfix_mask[5])
						iq[tail0].exc <= FLT_PFX;
					if (fnIsPred(fetchbuf0_instr[0]))
						pred_mask <= fetchbuf0_instr[0][34:7];
					iqentry_issue_reg[tail0] <= 1'b0;
				end

				else begin	// fetchbuf0 doesn't contain a backwards branch
					if (!fnIsPostfix(fetchbuf0_instr[0]))
						pred_mask <= pred_mask >> 4'd2;
			    //
			    // so -- we can enqueue 1 or 2 instructions, depending on space in the IQ
			    // update tail0/tail1 separately (at top)
			    // update the rf_v and rf_source bits separately (at end)
			    //   the problem is that if we do have two instructions, 
			    //   they may interact with each other, so we have to be
			    //   careful about where things point.
			    //

			    //
			    // enqueue the first instruction ...
			    //
					did_branchback1 <= branchback & ~did_branchback;
					for (n12 = 0; n12 < QENTRIES; n12 = n12 + 1)
						iq[n12].sn <= |iq[n12].sn ? iq[n12].sn - 2'd1 : iq[n12].sn;
					iq[tail0].sn <= 6'h3F;
			    iq[tail0].done <= db0.nop;
			    iq[tail0].out    <=   INV;
			    iq[tail0].res    <=   `ZERO;
			    iq[tail0].op    <=   fetchbuf0_instr[0]; 
			    iq[tail0].bt    <=   INV;//ptakb;
			    iq[tail0].agen    <=   INV;
			    iq[tail0].pc    <=   fetchbuf0_pc;
					iq[tail0].imm <= db0.has_imm;
					iq[tail0].fc <= db0.fc;
			    iq[tail0].fpu = db0.fpu;
			    iq[tail0].alu <= db0.alu;
			    iq[tail0].alu0 <= db0.alu0;
			    iq[tail0].mul <= db0.mul;
			    iq[tail0].mulu <= db0.mulu;
			    iq[tail0].div <= db0.div;
			    iq[tail0].divu <= db0.divu;
			    iq[tail0].sync <= 1'b0;
			    iq[tail0].mem <= db0.mem;
					iq[tail0].load <= db0.load;
					iq[tail0].loadz <= db0.loadz;
					iq[tail0].store <= db0.store;
			    iq[tail0].jmp    <=   fetchbuf0_jmp;
			    iq[tail0].rfw    <=   fetchbuf0_rfw;
					iq[tail0].tgt <= Rt0;
			    iq[tail0].exc    <=   FLT_NONE;
					iq[tail0].takb <= 1'b0;
					iq[tail0].brtgt <= 'd0;
					iq[tail0].Ra <= Ra0;
					iq[tail0].Rb <= Rb0;
					iq[tail0].Rc <= Rc0;
					iq[tail0].Rt <= Rt0;
					iq[tail0].Rp <= Rp0;
			    iq[tail0].a0 <= db0.imm;
					iq[tail0].a1 <= fnA1(fetchbuf0_instr[0], rfoa0, db0.imm);
					iq[tail0].a1_v <= fnSource1v(fetchbuf0_instr[0]) || rf_v[ Ra0 ];
					iq[tail0].a1_s <= rf_source [ Ra0 ];
					iq[tail0].a2 <= fnA2(fetchbuf0_instr[0], rfob0, db0.imm);
					iq[tail0].a2_v <= fnSource2v(fetchbuf0_instr[0]) || rf_v[ Rb0 ];
					iq[tail0].a2_s <= rf_source [ Rb0 ];
					iq[tail0].a3 <= fnA3(fetchbuf0_instr[0], rfoc0, db0.imm);
					iq[tail0].a3_v <= fnSource3v(fetchbuf0_instr[0]) || rf_v[ Rc0 ];
					iq[tail0].a3_s  <= rf_source [ Rc0 ];
					iq[tail0].at <= rfot0;
					iq[tail0].at_v <= fnSourceTv(fetchbuf0_instr[0]) || rf_v[ Rt0 ];
					iq[tail0].at_s  <= rf_source [ Rt0 ];
					iq[tail0].ap <= fnAP(fetchbuf0_instr[0], rfop0);
					iq[tail0].ap_v <= fnSourcePv(fetchbuf0_instr[0]) || rf_v[ Rp0 ];
					iq[tail0].ap_s  <= rf_source [ Rp0 ];
					lastq0 <= {1'b0,tail0};
					lastq1 <= {1'b1,tail0};
					if (!fnIsPostfix(fetchbuf0_instr[0])) begin
						atom_mask <= atom_mask >> 4'd3;
						pred_mask <= {4'hF,pred_mask} >> 4'd4;
						postfix_mask <= 'd0;
					end
					else
						postfix_mask <= {postfix_mask[4:0],1'b1};
					if (postfix_mask[5])
						iq[tail0].exc <= FLT_PFX;
					if (fnIsPred(fetchbuf0_instr[0]))
						pred_mask <= fetchbuf0_instr[0][34:7];
					iqentry_issue_reg[tail0] <= 1'b0;

			    //
			    // if there is room for a second instruction, enqueue it
			    //
			    if (iq_v[tail1] == INV) begin

						for (n12 = 0; n12 < QENTRIES; n12 = n12 + 1)
							iq[n12].sn <= |iq[n12].sn ? iq[n12].sn - 2'd2 : iq[n12].sn;
						iq[tail0].sn <= 6'h3E;	// <- this needs be done again here
						iq[tail1].sn <= 6'h3F;
						iq[tail1].done <= db1.nop;
						iq[tail1].out    <=   INV;
						iq[tail1].res    <=   `ZERO;
						iq[tail1].op    <=   fetchbuf1_instr[0]; 
						iq[tail1].bt    <=   db1.backbr;//(fnIsBackBranch(fetchbuf1_instr[0]))|ptakb; 
						iq[tail1].agen    <=   INV;
						iq[tail1].pc    <=   fetchbuf1_pc;
						iq[tail1].imm <= db1.has_imm;
						iq[tail1].fc <= db1.fc;
				    iq[tail1].alu <= db1.alu;
			    	iq[tail1].alu0 <= db1.alu0;
				    iq[tail1].fpu = db1.fpu;
				    iq[tail1].mul <= db1.mul;
				    iq[tail1].mulu <= db1.mulu;
				    iq[tail1].div <= db1.div;
				    iq[tail1].divu <= db1.divu;
				    iq[tail1].sync <= 1'b0;
						iq[tail1].mem <= db1.mem;
						iq[tail1].load <= db1.load;
						iq[tail1].loadz <= db1.loadz;
						iq[tail1].store <= db1.store;
						iq[tail1].jmp    <=   fetchbuf1_jmp;
						iq[tail1].rfw    <=   fetchbuf1_rfw;
						iq[tail1].tgt <= Rt1;
						iq[tail1].exc <= FLT_NONE;
						iq[tail1].takb <= 1'b0;
						iq[tail1].brtgt <= 'd0;
						iq[tail1].Ra <= Ra1;
						iq[tail1].Rb <= Rb1;
						iq[tail1].Rc <= Rc1;
						iq[tail1].Rt <= Rt1;
						iq[tail1].Rp <= Rp1;
						iq[tail1].a0 <= db1.imm;
						iq[tail1].a1 <= fnA1(fetchbuf1_instr[0], rfoa1, db1.imm);
						iq[tail1].a2 <= fnA2(fetchbuf1_instr[0], rfob1, db1.imm);
						iq[tail1].a3 <= fnA3(fetchbuf1_instr[0], rfoc1, db1.imm);
						iq[tail1].at <= rfot1;
						iq[tail1].ap <= fnAP(fetchbuf1_instr[0], rfop1);
						lastq1 <= {1'b0,tail1};
						if (!fnIsPostfix(fetchbuf1_instr[0])) begin
							atom_mask <= atom_mask >> 4'd6;
							pred_mask <= {8'hFF,pred_mask} >> 4'd8;
							postfix_mask <= 'd0;
						end
						else
							postfix_mask <= {postfix_mask[4:0],1'b1};
						if (postfix_mask[5])
							iq[tail1].exc <= FLT_PFX;
						if (fnIsPred(fetchbuf1_instr[0]))
							pred_mask <= fetchbuf1_instr[0][34:7];
						iqentry_issue_reg[tail1] <= 1'b0;

						// a1/a2_v and a1/a2_s values require a bit of thinking ...

						//
						// SOURCE 1 ... this is relatively straightforward, because all instructions
						// that have a source (i.e. every instruction but LUI) read from RB
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSource1v(fetchbuf1_instr[0])) begin
					    iq[tail1].a1_v <= VAL;
					    iq[tail1].a1_s <= 'd0;
						end
						// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
						else if (~fetchbuf0_rfw) begin
					    iq[tail1].a1_v <= rf_v [ Ra1 ];
					    iq[tail1].a1_s <= rf_source [ Ra1 ];
						end
						// otherwise, previous instruction does write to RF ... see if overlap
						else if (Rt0 != 'd0 && Ra1 == Rt0) begin
					    // if the previous instruction is a LW, then grab result from memq, not the iq
					    iq[tail1].a1_v <= INV;
					    iq[tail1].a1_s <= { db0.mem, tail0 };
						end
						// if no overlap, get info from rf_v and rf_source
						else begin
					    iq[tail1].a1_v <= rf_v [ Ra1 ];
					    iq[tail1].a1_s <= rf_source [ Ra1 ];
						end

						//
						// SOURCE 2 ... this is more contorted than the logic for SOURCE 1 because
						// some instructions (NAND and ADD) read from RC and others (SW, BEQ) read from RA
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSource2v(fetchbuf1_instr[0])) begin
					    iq[tail1].a2_v <= VAL;
					    iq[tail1].a2_s <= 'd0;
						end
						// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
						else if (~fetchbuf0_rfw) begin
					    iq[tail1].a2_v <= rf_v [ Rb1 ];
					    iq[tail1].a2_s <= rf_source [ Rb1 ];
						end
						// otherwise, previous instruction does write to RF ... see if overlap
						else if (Rt0 != 6'd0 && Rb1 == Rt0) begin
					    // if the previous instruction is a LW, then grab result from memq, not the iq
					    iq[tail1].a2_v <= INV;
					    iq[tail1].a2_s <= { db0.mem, tail0 };
						end
						// if no overlap, get info from rf_v and rf_source
						else begin
					    iq[tail1].a2_v <= rf_v [ Rb1 ];
					    iq[tail1].a2_s <= rf_source [ Rb1 ];
						end

						//
						// SOURCE 3 ... 
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSource3v(fetchbuf1_instr[0])) begin
					    iq[tail1].a3_v <= VAL;
					    iq[tail1].a3_s <= 'd0;
						end
						// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
						else if (~fetchbuf0_rfw) begin
					    iq[tail1].a3_v <= rf_v [ Rc1 ];
					    iq[tail1].a3_s <= rf_source [ Rc1 ];
						end
						// otherwise, previous instruction does write to RF ... see if overlap
						else if (Rt0 != 5'd0 && Rc1 == Rt0) begin
					    // if the previous instruction is a LW, then grab result from memq, not the iq
					    iq[tail1].a3_v <= INV;
					    iq[tail1].a3_s <= { db0.mem, tail0 };
						end
						// if no overlap, get info from rf_v and rf_source
						else begin
					    iq[tail1].a3_v <= rf_v [ Rc1 ];
					    iq[tail1].a3_s <= rf_source [ Rc1 ];
						end

						//
						// SOURCE T ... 
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSourceTv(fetchbuf1_instr[0])) begin
					    iq[tail1].at_v <= VAL;
					    iq[tail1].at_s <= 'd0;
						end
						// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
						else if (~fetchbuf0_rfw) begin
					    iq[tail1].at_v <= rf_v [ Rt1 ];
					    iq[tail1].at_s <= rf_source [ Rt1 ];
						end
						// otherwise, previous instruction does write to RF ... see if overlap
						else if (Rt0 != 6'd0 && Rt1 == Rt0) begin
					    // if the previous instruction is a LW, then grab result from memq, not the iq
					    iq[tail1].at_v <= INV;
					    iq[tail1].at_s <= { db0.mem, tail0 };
						end
						// if no overlap, get info from rf_v and rf_source
						else begin
					    iq[tail1].at_v <= rf_v [ Rt1 ];
					    iq[tail1].at_s <= rf_source [ Rt1 ];
						end

						//
						// SOURCE P ... 
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSourcePv(fetchbuf1_instr[0])) begin
					    iq[tail1].ap_v <= VAL;
					    iq[tail1].ap_s <= 'd0;
						end
						// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
						else if (~fetchbuf0_rfw) begin
					    iq[tail1].ap_v <= rf_v [ Rp1 ];
					    iq[tail1].ap_s <= rf_source [ Rp1 ];
						end
						// otherwise, previous instruction does write to RF ... see if overlap
						else if (Rt0 != 6'd0 && Rp1 == Rt0) begin
					    // if the previous instruction is a LW, then grab result from memq, not the iq
					    iq[tail1].ap_v <= INV;
					    iq[tail1].ap_s <= { db0.mem, tail0 };
						end
						// if no overlap, get info from rf_v and rf_source
						else begin
					    iq[tail1].ap_v <= rf_v [ Rp1 ];
					    iq[tail1].ap_s <= rf_source [ Rp1 ];
						end
					end	
	    	end// ends the "else fetchbuf0 doesn't have a backwards branch" clause
	    end
		endcase
//
// DATAINCOMING
//
// wait for operand/s to appear on alu busses and puts them into 
// the iqentry_a1 and iqentry_a2 slots (if appropriate)
// as well as the appropriate iqentry_res slots (and setting valid bits)
//
	//
	// put results into the appropriate instruction entries
	//
	for (n13 = 0; n13 < QENTRIES; n13 = n13 + 1)
		if (iqentry_issue[n13])
			iqentry_issue_reg[n13] <= 1'b1;
	if (alu0_v) begin
    iq[ alu0_id[2:0] ].res <= alu0_bus;
    iq[ alu0_id[2:0] ].exc <= alu0_exc;
    iq[ alu0_id[2:0] ].done <= (!iq[ alu0_id[2:0] ].load && !iq[ alu0_id[2:0] ].store);
    iq[ alu0_id[2:0] ].out <= INV;
    iq[ alu0_id[2:0] ].agen <= VAL;
    if (!iq[ alu0_id[2:0] ].load && !iq[ alu0_id[2:0] ].store)
    	iqentry_issue_reg[alu0_id[2:0]] <= 1'b0;
	end
	if (NALU > 1 && alu1_v) begin
    iq[ alu1_id[2:0] ].res <= alu1_bus;
    iq[ alu1_id[2:0] ].exc <= alu1_exc;
    iq[ alu1_id[2:0] ].done <= (!iq[ alu1_id[2:0] ].load && !iq[ alu1_id[2:0] ].store);
    iq[ alu1_id[2:0] ].out <= INV;
    iq[ alu1_id[2:0] ].agen <= VAL;
	end
	if (NFPU > 0 && fpu_v) begin
    iq[ fpu_id[2:0] ].res <= fpu_bus;
    iq[ fpu_id[2:0] ].exc <= fpu_exc;
    iq[ fpu_id[2:0] ].done <= fpu_done;
    iq[ fpu_id[2:0] ].out <= INV;
    iq[ fpu_id[2:0] ].agen <= VAL;
	end
	if (fcu_v) begin
    iq[ fcu_id[2:0] ].res <= fcu_bus;
    iq[ fcu_id[2:0] ].exc <= fcu_exc;
    iq[ fcu_id[2:0] ].done <= VAL;
    iq[ fcu_id[2:0] ].out <= INV;
    iq[ fcu_id[2:0] ].agen <= VAL;
    iq[ fcu_id[2:0] ].takb <= takb;
    iq[ fcu_id[2:0] ].brtgt <= tgtpc;
	end
	if (dram_v0 && iq_v[ dram_id0[2:0] ] && iq[ dram_id0[2:0] ].mem ) begin	// if data for stomped instruction, ignore
    iq[ dram_id0[2:0] ].res <= dram_bus0;
    iq[ dram_id0[2:0] ].exc <= dram_exc0;
    iq[ dram_id0[2:0] ].done <= VAL;
	end
	if (NDATA_PORTS > 1) begin
		if (dram_v1 && iq_v[ dram_id1[2:0] ] && iq[ dram_id1[2:0] ].mem ) begin	// if data for stomped instruction, ignore
	    iq[ dram_id1[2:0] ].res <= dram_bus1;
	    iq[ dram_id1[2:0] ].exc <= dram_exc1;
	    iq[ dram_id1[2:0] ].done <= VAL;
		end
	end

	//
	// set the IQ entry == DONE as soon as the SW is let loose to the memory system
	//
	
	if (dram0 == DRAMSLOT_ACTIVE && dram0p==DRAMSLOT_READY && dram0_store) begin
//    if ((alu0_v && dram0_id[2:0] == alu0_id[2:0]) || (alu1_v && dram0_id[2:0] == alu1_id[2:0]))	panic <= `PANIC_MEMORYRACE;
    iq[ dram0_id[2:0] ].done <= VAL;
    iq[ dram0_id[2:0] ].out <= INV;
	end
	if (NDATA_PORTS > 1) begin
		if (dram1 == DRAMSLOT_ACTIVE && dram0p==DRAMSLOT_READY && dram1_store) begin
//	    if ((alu0_v && dram1_id[2:0] == alu0_id[2:0]) || (alu1_v && dram1_id[2:0] == alu1_id[2:0]))	panic <= `PANIC_MEMORYRACE;
	    iq[ dram1_id[2:0] ].done <= VAL;
	    iq[ dram1_id[2:0] ].out <= INV;
		end
	end
	
	/*
	if (dram2 == 2'd1 && fnIsStore(dram2_op)) begin
    if ((alu0_v && dram2_id[2:0] == alu0_id[2:0]) || (alu1_v && dram2_id[2:0] == alu1_id[2:0]))	panic <= `PANIC_MEMORYRACE;
    iq[ dram2_id[2:0] ].done <= VAL;
    iq[ dram2_id[2:0] ].out <= INV;
	end
	*/
	//
	// see if anybody else wants the results ... look at lots of buses:
	//  - alu0_bus
	//  - alu1_bus
	//	- fcu_bus
	//  - dram_bus0
	//  - dram_bus1
	//  - commit0_bus
	//  - commit1_bus
	//

	for (nn = 0; nn < QENTRIES; nn = nn + 1) begin
		/*
		if (iq[nn].a1_v == INV && iq[nn].v == VAL && iq[nn].Ra == Ra0 && rfva0) begin
	    iq[nn].a1 <= rfoa0;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].v == VAL && iq[nn].Rb == Rb0 && rfvb0) begin
	    iq[nn].a2 <= rfob0;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].v == VAL && iq[nn].Rc == Rc0 && rfvc0) begin
	    iq[nn].a3 <= rfoc0;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].v == VAL && iq[nn].Rt == Rt0 && rfvt0) begin
	    iq[nn].at <= rfot0;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].v == VAL && iq[nn].Rp == Rp0 && rfvp0) begin
	    iq[nn].ap <= rfop0;
	    iq[nn].ap_v <= VAL;
		end

		if (iq[nn].a1_v == INV && iq[nn].v == VAL && iq[nn].Ra == Ra1 && rfva1) begin
	    iq[nn].a1 <= rfoa1;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].v == VAL && iq[nn].Rb == Rb1 && rfvb1) begin
	    iq[nn].a2 <= rfob1;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].v == VAL && iq[nn].Rc == Rc1 && rfvc1) begin
	    iq[nn].a3 <= rfoc1;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].v == VAL && iq[nn].Rt == Rt1 && rfvt1) begin
	    iq[nn].at <= rfot1;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].v == VAL && iq[nn].Rp == Rp1 && rfvp1) begin
	    iq[nn].ap <= rfop1;
	    iq[nn].ap_v <= VAL;
		end
		*/
		if (iq[nn].a1_v == INV && iq[nn].a1_s == alu0_id && iq_v[nn] == VAL && alu0_v == VAL) begin
	    iq[nn].a1 <= alu0_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == alu0_id && iq_v[nn] == VAL && alu0_v == VAL) begin
	    iq[nn].a2 <= alu0_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == alu0_id && iq_v[nn] == VAL && alu0_v == VAL) begin
	    iq[nn].a3 <= alu0_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == alu0_id && iq_v[nn] == VAL && alu0_v == VAL) begin
	    iq[nn].at <= alu0_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == alu0_id && iq_v[nn] == VAL && alu0_v == VAL) begin
	    iq[nn].ap <= alu0_bus;
	    iq[nn].ap_v <= VAL;
		end

		if (NALU > 1) begin
			if (iq[nn].a1_v == INV && iq[nn].a1_s == alu1_id && iq_v[nn] == VAL && alu1_v == VAL) begin
		    iq[nn].a1 <= alu1_bus;
		    iq[nn].a1_v <= VAL;
			end
			if (iq[nn].a2_v == INV && iq[nn].a2_s == alu1_id && iq_v[nn] == VAL && alu1_v == VAL) begin
		    iq[nn].a2 <= alu1_bus;
		    iq[nn].a2_v <= VAL;
			end
			if (iq[nn].a3_v == INV && iq[nn].a3_s == alu1_id && iq_v[nn] == VAL && alu1_v == VAL) begin
		    iq[nn].a3 <= alu1_bus;
		    iq[nn].a3_v <= VAL;
			end
			if (iq[nn].at_v == INV && iq[nn].at_s == alu1_id && iq_v[nn] == VAL && alu1_v == VAL) begin
		    iq[nn].at <= alu1_bus;
		    iq[nn].at_v <= VAL;
			end
			if (iq[nn].ap_v == INV && iq[nn].ap_s == alu1_id && iq_v[nn] == VAL && alu1_v == VAL) begin
		    iq[nn].ap <= alu1_bus;
		    iq[nn].ap_v <= VAL;
			end
		end

		if (NFPU > 0) begin
			if (iq[nn].a1_v == INV && iq[nn].a1_s == fpu_id && iq_v[nn] == VAL && fpu_v == VAL) begin
		    iq[nn].a1 <= fpu_bus;
		    iq[nn].a1_v <= VAL;
			end
			if (iq[nn].a2_v == INV && iq[nn].a2_s == fpu_id && iq_v[nn] == VAL && fpu_v == VAL) begin
		    iq[nn].a2 <= fpu_bus;
		    iq[nn].a2_v <= VAL;
			end
			if (iq[nn].a3_v == INV && iq[nn].a3_s == fpu_id && iq_v[nn] == VAL && fpu_v == VAL) begin
		    iq[nn].a3 <= fpu_bus;
		    iq[nn].a3_v <= VAL;
			end
			if (iq[nn].at_v == INV && iq[nn].at_s == fpu_id && iq_v[nn] == VAL && fpu_v == VAL) begin
		    iq[nn].at <= fpu_bus;
		    iq[nn].at_v <= VAL;
			end
			if (iq[nn].ap_v == INV && iq[nn].ap_s == fpu_id && iq_v[nn] == VAL && fpu_v == VAL) begin
		    iq[nn].ap <= fpu_bus;
		    iq[nn].ap_v <= VAL;
			end
		end

		if (iq[nn].a1_v == INV && iq[nn].a1_s == fcu_id && iq_v[nn] == VAL && fcu_v == VAL) begin
	    iq[nn].a1 <= fcu_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == fcu_id && iq_v[nn] == VAL && fcu_v == VAL) begin
	    iq[nn].a2 <= fcu_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == fcu_id && iq_v[nn] == VAL && fcu_v == VAL) begin
	    iq[nn].a3 <= fcu_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == fcu_id && iq_v[nn] == VAL && fcu_v == VAL) begin
	    iq[nn].at <= fcu_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == fcu_id && iq_v[nn] == VAL && fcu_v == VAL) begin
	    iq[nn].ap <= fcu_bus;
	    iq[nn].ap_v <= VAL;
		end
		
		if (iq[nn].a1_v == INV && iq[nn].a1_s == dram_id0 && iq_v[nn] == VAL && dram_v0 == VAL) begin
	    iq[nn].a1 <= dram_bus0;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == dram_id0 && iq_v[nn] == VAL && dram_v0 == VAL) begin
	    iq[nn].a2 <= dram_bus0;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == dram_id0 && iq_v[nn] == VAL && dram_v0 == VAL) begin
	    iq[nn].a3 <= dram_bus0;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == dram_id0 && iq_v[nn] == VAL && dram_v0 == VAL) begin
	    iq[nn].at <= dram_bus0;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == dram_id0 && iq_v[nn] == VAL && dram_v0 == VAL) begin
	    iq[nn].ap <= dram_bus0;
	    iq[nn].ap_v <= VAL;
		end
		
		if (NDATA_PORTS > 1) begin
			if (iq[nn].a1_v == INV && iq[nn].a1_s == dram_id1 && iq_v[nn] == VAL && dram_v1 == VAL) begin
		    iq[nn].a1 <= dram_bus1;
		    iq[nn].a1_v <= VAL;
			end
			if (iq[nn].a2_v == INV && iq[nn].a2_s == dram_id1 && iq_v[nn] == VAL && dram_v1 == VAL) begin
		    iq[nn].a2 <= dram_bus1;
		    iq[nn].a2_v <= VAL;
			end
			if (iq[nn].a3_v == INV && iq[nn].a3_s == dram_id1 && iq_v[nn] == VAL && dram_v1 == VAL) begin
		    iq[nn].a3 <= dram_bus1;
		    iq[nn].a3_v <= VAL;
			end
			if (iq[nn].at_v == INV && iq[nn].at_s == dram_id1 && iq_v[nn] == VAL && dram_v1 == VAL) begin
		    iq[nn].at <= dram_bus1;
		    iq[nn].at_v <= VAL;
			end
			if (iq[nn].ap_v == INV && iq[nn].ap_s == dram_id1 && iq_v[nn] == VAL && dram_v1 == VAL) begin
		    iq[nn].ap <= dram_bus1;
		    iq[nn].ap_v <= VAL;
			end
		end
		
		if (iq[nn].a1_v == INV && iq[nn].a1_s == commit0a_id && iq_v[nn] == VAL && commit0a_v == VAL) begin
	    iq[nn].a1 <= commit0a_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == commit0a_id && iq_v[nn] == VAL && commit0a_v == VAL) begin
	    iq[nn].a2 <= commit0a_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == commit0a_id && iq_v[nn] == VAL && commit0a_v == VAL) begin
	    iq[nn].a3 <= commit0a_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == commit0a_id && iq_v[nn] == VAL && commit0a_v == VAL) begin
	    iq[nn].at <= commit0a_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == commit0a_id && iq_v[nn] == VAL && commit0a_v == VAL) begin
	    iq[nn].ap <= commit0a_bus;
	    iq[nn].ap_v <= VAL;
		end
		
		if (iq[nn].a1_v == INV && iq[nn].a1_s == commit1a_id && iq_v[nn] == VAL && commit1a_v == VAL) begin
	    iq[nn].a1 <= commit1a_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == commit1a_id && iq_v[nn] == VAL && commit1a_v == VAL) begin
	    iq[nn].a2 <= commit1a_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == commit1a_id && iq_v[nn] == VAL && commit1a_v == VAL) begin
	    iq[nn].a3 <= commit1a_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == commit1a_id && iq_v[nn] == VAL && commit1a_v == VAL) begin
	    iq[nn].at <= commit1a_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == commit1a_id && iq_v[nn] == VAL && commit1a_v == VAL) begin
	    iq[nn].ap <= commit1a_bus;
	    iq[nn].ap_v <= VAL;
		end

		// These may be overridden by commit0 / commit1
		if (SUPPORT_COMMIT23) begin
			if (iq[nn].a1_v == INV && iq[nn].a1_s == commit2_id && iq_v[nn] == VAL && commit2_v == VAL) begin
		    iq[nn].a1 <= commit2_bus;
		    iq[nn].a1_v <= VAL;
			end
			if (iq[nn].a2_v == INV && iq[nn].a2_s == commit2_id && iq_v[nn] == VAL && commit2_v == VAL) begin
		    iq[nn].a2 <= commit2_bus;
		    iq[nn].a2_v <= VAL;
			end
			if (iq[nn].a3_v == INV && iq[nn].a3_s == commit2_id && iq_v[nn] == VAL && commit2_v == VAL) begin
		    iq[nn].a3 <= commit2_bus;
		    iq[nn].a3_v <= VAL;
			end
			if (iq[nn].at_v == INV && iq[nn].at_s == commit2_id && iq_v[nn] == VAL && commit2_v == VAL) begin
		    iq[nn].at <= commit2_bus;
		    iq[nn].at_v <= VAL;
			end
			if (iq[nn].ap_v == INV && iq[nn].ap_s == commit2_id && iq_v[nn] == VAL && commit2_v == VAL) begin
		    iq[nn].ap <= commit2_bus;
		    iq[nn].ap_v <= VAL;
			end

			if (iq[nn].a1_v == INV && iq[nn].a1_s == commit3_id && iq_v[nn] == VAL && commit3_v == VAL) begin
		    iq[nn].a1 <= commit3_bus;
		    iq[nn].a1_v <= VAL;
			end
			if (iq[nn].a2_v == INV && iq[nn].a2_s == commit3_id && iq_v[nn] == VAL && commit3_v == VAL) begin
		    iq[nn].a2 <= commit3_bus;
		    iq[nn].a2_v <= VAL;
			end
			if (iq[nn].a3_v == INV && iq[nn].a3_s == commit3_id && iq_v[nn] == VAL && commit3_v == VAL) begin
		    iq[nn].a3 <= commit3_bus;
		    iq[nn].a3_v <= VAL;
			end
			if (iq[nn].at_v == INV && iq[nn].at_s == commit3_id && iq_v[nn] == VAL && commit3_v == VAL) begin
		    iq[nn].at <= commit3_bus;
		    iq[nn].at_v <= VAL;
			end
			if (iq[nn].ap_v == INV && iq[nn].ap_s == commit3_id && iq_v[nn] == VAL && commit3_v == VAL) begin
		    iq[nn].ap <= commit3_bus;
		    iq[nn].ap_v <= VAL;
			end
		end

		if (iq[nn].a1_v == INV && iq[nn].a1_s == commit0_id && iq_v[nn] == VAL && commit0_v == VAL) begin
	    iq[nn].a1 <= commit0_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == commit0_id && iq_v[nn] == VAL && commit0_v == VAL) begin
	    iq[nn].a2 <= commit0_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == commit0_id && iq_v[nn] == VAL && commit0_v == VAL) begin
	    iq[nn].a3 <= commit0_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == commit0_id && iq_v[nn] == VAL && commit0_v == VAL) begin
	    iq[nn].at <= commit0_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == commit0_id && iq_v[nn] == VAL && commit0_v == VAL) begin
	    iq[nn].ap <= commit0_bus;
	    iq[nn].ap_v <= VAL;
		end
		
		if (iq[nn].a1_v == INV && iq[nn].a1_s == commit1_id && iq_v[nn] == VAL && commit1_v == VAL) begin
	    iq[nn].a1 <= commit1_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == commit1_id && iq_v[nn] == VAL && commit1_v == VAL) begin
	    iq[nn].a2 <= commit1_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == commit1_id && iq_v[nn] == VAL && commit1_v == VAL) begin
	    iq[nn].a3 <= commit1_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == commit1_id && iq_v[nn] == VAL && commit1_v == VAL) begin
	    iq[nn].at <= commit1_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == commit1_id && iq_v[nn] == VAL && commit1_v == VAL) begin
	    iq[nn].ap <= commit1_bus;
	    iq[nn].ap_v <= VAL;
		end

	end

//
// ISSUE 
//
// determines what instructions are ready to go, then places them
// in the various ALU queues.  
// also invalidates instructions following a branch-miss BEQ or any JALR (STOMP logic)
//

alu0_dataready <= alu0_available 
		&& ((iqentry_issue2[0] && iqentry_islot[0] == 2'd0 && !iqentry_stomp[0] && (iq[0].div|iq[0].divu ? div0_done : 1'b1) && (iq[0].mul|iq[0].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue2[1] && iqentry_islot[1] == 2'd0 && !iqentry_stomp[1] && (iq[1].div|iq[1].divu ? div0_done : 1'b1) && (iq[1].mul|iq[1].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue2[2] && iqentry_islot[2] == 2'd0 && !iqentry_stomp[2] && (iq[2].div|iq[2].divu ? div0_done : 1'b1) && (iq[2].mul|iq[2].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue2[3] && iqentry_islot[3] == 2'd0 && !iqentry_stomp[3] && (iq[3].div|iq[3].divu ? div0_done : 1'b1) && (iq[3].mul|iq[3].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue2[4] && iqentry_islot[4] == 2'd0 && !iqentry_stomp[4] && (iq[4].div|iq[4].divu ? div0_done : 1'b1) && (iq[4].mul|iq[4].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue2[5] && iqentry_islot[5] == 2'd0 && !iqentry_stomp[5] && (iq[5].div|iq[5].divu ? div0_done : 1'b1) && (iq[5].mul|iq[5].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue2[6] && iqentry_islot[6] == 2'd0 && !iqentry_stomp[6] && (iq[6].div|iq[6].divu ? div0_done : 1'b1) && (iq[6].mul|iq[6].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue2[7] && iqentry_islot[7] == 2'd0 && !iqentry_stomp[7] && (iq[7].div|iq[7].divu ? div0_done : 1'b1) && (iq[7].mul|iq[7].mulu ? mul0_done : 1'b1)));

alu1_dataready <= alu1_available 
		&& ((iqentry_issue2[0] && iqentry_islot[0] == 2'd1 && !iqentry_stomp[0] && (iq[0].div|iq[0].divu ? div1_done : 1'b1) && (iq[0].mul|iq[0].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue2[1] && iqentry_islot[1] == 2'd1 && !iqentry_stomp[1] && (iq[1].div|iq[1].divu ? div1_done : 1'b1) && (iq[1].mul|iq[1].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue2[2] && iqentry_islot[2] == 2'd1 && !iqentry_stomp[2] && (iq[2].div|iq[2].divu ? div1_done : 1'b1) && (iq[2].mul|iq[2].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue2[3] && iqentry_islot[3] == 2'd1 && !iqentry_stomp[3] && (iq[3].div|iq[3].divu ? div1_done : 1'b1) && (iq[3].mul|iq[3].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue2[4] && iqentry_islot[4] == 2'd1 && !iqentry_stomp[4] && (iq[4].div|iq[4].divu ? div1_done : 1'b1) && (iq[4].mul|iq[4].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue2[5] && iqentry_islot[5] == 2'd1 && !iqentry_stomp[5] && (iq[5].div|iq[5].divu ? div1_done : 1'b1) && (iq[5].mul|iq[5].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue2[6] && iqentry_islot[6] == 2'd1 && !iqentry_stomp[6] && (iq[6].div|iq[6].divu ? div1_done : 1'b1) && (iq[6].mul|iq[6].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue2[7] && iqentry_islot[7] == 2'd1 && !iqentry_stomp[7] && (iq[7].div|iq[7].divu ? div1_done : 1'b1) && (iq[7].mul|iq[7].mulu ? mul1_done : 1'b1)));

fpu_dataready <= fpu_available && NFPU > 0 && fpu_done
		&& ((iqentry_fpu_issue[0] && !iqentry_stomp[0])
		 || (iqentry_fpu_issue[1] && !iqentry_stomp[1])
		 || (iqentry_fpu_issue[2] && !iqentry_stomp[2])
		 || (iqentry_fpu_issue[3] && !iqentry_stomp[3])
		 || (iqentry_fpu_issue[4] && !iqentry_stomp[4])
		 || (iqentry_fpu_issue[5] && !iqentry_stomp[5])
		 || (iqentry_fpu_issue[6] && !iqentry_stomp[6])
		 || (iqentry_fpu_issue[7] && !iqentry_stomp[7]));

fcu_dataready <= fcu_available 
		&& ((iqentry_fcu_issue[0] && !iqentry_stomp[0])
		 || (iqentry_fcu_issue[1] && !iqentry_stomp[1])
		 || (iqentry_fcu_issue[2] && !iqentry_stomp[2])
		 || (iqentry_fcu_issue[3] && !iqentry_stomp[3])
		 || (iqentry_fcu_issue[4] && !iqentry_stomp[4])
		 || (iqentry_fcu_issue[5] && !iqentry_stomp[5])
		 || (iqentry_fcu_issue[6] && !iqentry_stomp[6])
		 || (iqentry_fcu_issue[7] && !iqentry_stomp[7]));

	for (n1 = 0; n1 < QENTRIES; n1 = n1 + 1) begin
		if (iq_v[n1] && iqentry_stomp[n1]) begin
	    if (dram0_id[2:0] == n1[2:0])	dram0 <= DRAMSLOT_AVAIL;
	    if (dram1_id[2:0] == n1[2:0])	dram1 <= DRAMSLOT_AVAIL;
//	    if (dram2_id[2:0] == n1[2:0])	dram2 <= `DRAMSLOT_AVAIL;
		end
		else begin
			if (iqentry_issue[n1]) begin
		    case (iqentry_islot[n1]) 
				2'd0: 
					if (alu0_available) begin
						alu0_sourceid	<= n1[3:0];
						alu0_instr <= iq[n1].op;
						alu0_div <= iq[n1].div;
						alu0_pc <= iq[n1].pc;
						alu0_argA	<= 
										  iq[n1].a1_v ? iq[n1].a1
								    : (iq[n1].a1_s == alu0_id) ? alu0_bus
								    : (iq[n1].a1_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu0_argB	<= 
											 iq[n1].imm ? iq[n1].a0
								    : iq[n1].a2_v ? iq[n1].a2
										: (iq[n1].a2_s == alu0_id) ? alu0_bus
										: (iq[n1].a2_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu0_argC	<= 
								       iq[n1].a3_v ? iq[n1].a3
										: (iq[n1].a3_s == alu0_id) ? alu0_bus
										: (iq[n1].a3_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu0_argT	<= 
								       iq[n1].at_v ? iq[n1].at
										: (iq[n1].at_s == alu0_id) ? alu0_bus
										: (iq[n1].at_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu0_argP	<= 
								       iq[n1].ap_v ? iq[n1].ap
										: (iq[n1].ap_s == alu0_id) ? alu0_bus
										: (iq[n1].ap_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu0_argI	<= iq[n1].a0;
						alu0_ld <= 1'b1;
			    end
				2'd1:
					if (NALU > 1 && alu1_available) begin
						alu1_sourceid	<= n1[3:0];
						alu1_instr <= iq[n1].op;
						alu1_div <= iq[n1].div;
						alu1_pc <= iq[n1].pc;
						alu1_argA	<= 
										  iq[n1].a1_v ? iq[n1].a1
								    : (iq[n1].a1_s == alu0_id) ? alu0_bus
								    : (iq[n1].a1_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu1_argB	<= 
											 iq[n1].imm ? iq[n1].a0
								    :  iq[n1].a2_v ? iq[n1].a2
										: (iq[n1].a2_s == alu0_id) ? alu0_bus
										: (iq[n1].a2_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu1_argC	<= 
								       iq[n1].a3_v ? iq[n1].a3
										: (iq[n1].a3_s == alu0_id) ? alu0_bus
										: (iq[n1].a3_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu1_argT	<= 
								       iq[n1].at_v ? iq[n1].at
										: (iq[n1].at_s == alu0_id) ? alu0_bus
										: (iq[n1].at_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu1_argP	<= 
								       iq[n1].ap_v ? iq[n1].ap
										: (iq[n1].ap_s == alu0_id) ? alu0_bus
										: (iq[n1].ap_s == alu1_id) ? alu1_bus
								    : {2{32'hDEADBEEF}};
						alu1_argI	<= iq[n1].a0;
						alu1_ld <= 1'b1;
			    end
				default: panic <= `PANIC_INVALIDISLOT;
		    endcase
		    iq[n1].out <= VAL;
		    // if it is a memory operation, this is the address-generation step ... collect result into arg1
		    if (iq[n1].mem) begin
					iq[n1].a1_v <= INV;
					iq[n1].a1_s <= n1[3:0];
		    end
		  end
		  if (iqentry_fcu_issue[n1]) begin
				if (fcu_available) begin
					fcu_sourceid	<= n1[3:0];
					fcu_instr		<= iq[n1].op;
					fcu_bt		<= iq[n1].bt;
					fcu_pc		<= iq[n1].pc;
					fcu_argA	<= 
									  iq[n1].a1_v ? iq[n1].a1
							    : (iq[n1].a1_s == alu0_id) ? alu0_bus
							    : (iq[n1].a1_s == alu1_id) ? alu1_bus
							    : {2{32'hDEADBEEF}};
					fcu_argB	<= 
							      (iq[n1].a2_v ? iq[n1].a2
									: (iq[n1].a2_s == alu0_id) ? alu0_bus
									: (iq[n1].a2_s == alu1_id) ? alu1_bus
									: {2{32'hDEADBEEF}});
					fcu_argC	<= 
							      (iq[n1].a3_v ? iq[n1].a3
									: (iq[n1].a3_s == alu0_id) ? alu0_bus
									: (iq[n1].a3_s == alu1_id) ? alu1_bus
									: {2{32'hDEADBEEF}});
					fcu_argI	<= iq[n1].a0;
		    end
		  end
		  if (NFPU > 0 && iqentry_fpu_issue[n1]) begin
				if (fpu_available) begin
					fpu_sourceid	<= n1[3:0];
					fpu_instr <= iq[n1].op;
					fpu_pc <= iq[n1].pc;
					fpu_argA	<= 
									  iq[n1].a1_v ? iq[n1].a1
							    : (iq[n1].a1_s == fpu_id) ? fpu_bus
							    : 32'hDEADBEEF;
					fpu_argB	<= 
							      (iq[n1].a2_v ? iq[n1].a2
									: (iq[n1].a2_s == fpu_id) ? fpu_bus
									: 32'hDEADBEEF);
					fpu_argC	<= 
							      (iq[n1].a3_v ? iq[n1].a3
									: (iq[n1].a3_s == fpu_id) ? fpu_bus
									: 32'hDEADBEEF);
					fpu_argT	<= 
							      (iq[n1].at_v ? iq[n1].at
									: (iq[n1].at_s == fpu_id) ? fpu_bus
									: 32'hDEADBEEF);
					fpu_argP	<= 
							      (iq[n1].ap_v ? iq[n1].ap
									: (iq[n1].ap_s == fpu_id) ? fpu_bus
									: 32'hDEADBEEF);
					fpu_argI	<= iq[n1].a0;
		    end
		  end
		end
	end

//
// MEMORY
//
// update the memory queues and put data out on bus if appropriate
//

	//
	// dram0, dram1, dram2 are the "state machines" that keep track
	// of three pipelined DRAM requests.  if any has the value "00", 
	// then it can accept a request (which bumps it up to the value "01"
	// at the end of the cycle).  once it hits the value "11" the request
	// is finished and the dram_bus takes the value.  if it is a store, the 
	// dram_bus value is not used, but the dram_v value along with the
	// dram_id value signals the waiting memq entry that the store is
	// completed and the instruction can commit.
	//

	if (rst)
		dram0 <= DRAMSLOT_AVAIL;
	else
		case(dram0)
		DRAMSLOT_AVAIL:	;
		DRAMSLOT_READY:
			begin
				dram0 <= dram0 + 2'd1;
				if (|dram0_sel[79:64]) begin
					dram0_more <= 1'b1;
				end
			end
		DRAMSLOT_ACTIVE:
			if (dram0_ack) begin
				iq[dram0_id[2:0]].out <= INV;
				/*
				if (dram0_store && !dram0_more) begin
					iq[dram0_id[2:0]].done <= VAL;
					iq[dram0_id[2:0]].out <= INV;
				end
				*/
				dram0 <= DRAMSLOT_AVAIL;
			end
		default:
			if (iq_v[dram0_id[2:0]])
				dram0 <= dram0 + 2'd1;
			else
				dram0 <= DRAMSLOT_AVAIL;
		endcase

	if (NDATA_PORTS > 1) begin
		if (rst)
			dram1 <= DRAMSLOT_AVAIL;
		else
			case(dram1)
			DRAMSLOT_AVAIL:	;
			DRAMSLOT_READY:
				begin
					dram1 <= dram1 + 2'd1;
					if (|dram1_sel[79:64]) begin
						dram1_more <= 1'b1;
					end
				end
			DRAMSLOT_ACTIVE:
				if (dram1_ack) begin
					iq[dram1_id[2:0]].out <= INV;
					/*
					if (dram1_store && !dram1_more) begin
						iq[dram1_id[2:0]].done <= VAL;
						iq[dram1_id[2:0]].out <= INV;
					end
					*/
					dram1 <= DRAMSLOT_AVAIL;
				end
			default:
				if (iq_v[dram1_id[2:0]])
					dram1 <= dram1 + 2'd1;
				else
					dram1 <= DRAMSLOT_AVAIL;
			endcase
	end
/*
	case(dram2)
	`DRAMSLOT_AVAIL:	;
	`DRAMREQ_READY:
		if (dram2_ack)
			dram2 <= dram2 + 2'd1;
	default:
		dram2 <= dram2 + 2'd1;
	endcase
*/
/*
	casez ({dram0, dram1})//, dram2})
	    // not particularly portable ...
	    4'b1111,
	    4'b11??,
	    4'b??11:	;//panic <= `PANIC_IDENTICALDRAMS;

	    default:
*/
	  begin
	    
		//
		// grab requests that have finished and put them on the dram_bus
		if (dram0 == DRAMSLOT_ACTIVE && dram0_ack && ~|dram0_sel[79:64]) begin
	    dram_v0 <= dram0_load;
	    dram_id0 <= dram0_id;
	    dram_tgt0 <= dram0_tgt;
	    dram_exc0 <= dram0_exc;
	    if (dram0_load)
	    	dram_bus0 <= fnDati(dram0_op,dram0_addr,cpu_resp_o[0] >> {dram0_addr[5:0],3'd0});
	    else if (dram0_store) begin
	    	dram0_store <= 'd0;
	    	dram0_sel <= 'd0;
	  	end
	    else			panic <= `PANIC_INVALIDMEMOP;
	    if (dram0_store)
	    	$display("m[%h] <- %h", dram0_addr, dram0_data);
		end
		else
			dram_v0 <= INV;
		if (NDATA_PORTS > 1) begin
			if (dram1 == DRAMSLOT_ACTIVE && dram1_ack && ~|dram1_sel[79:64]) begin
		    dram_v1 <= dram1_load;
		    dram_id1 <= dram1_id;
		    dram_tgt1 <= dram1_tgt;
		    dram_exc1 <= dram1_exc;
		    if (dram1_load) 	
		    	dram_bus1 <= fnDati(dram1_op,dram1_addr,cpu_resp_o[1] >> {dram1_addr[5:0],3'd0});	
		    else if (dram1_store) begin
		    	dram1_store <= 1'b0;
		    	dram1_sel <= 'd0;
		  	end
		    else			panic <= `PANIC_INVALIDMEMOP;
		    if (dram1_store)
		     	$display("m[%h] <- %h", dram1_addr, dram1_data);
			end
			else
				dram_v1 <= INV;
		end
		/*
		else if (dram2 == `DRAMREQ_READY && dram2_ack) begin
		    dram_v <= (dram2_load);
		    dram_id <= dram2_id;
		    dram_tgt <= dram2_tgt;
		    dram_exc <= dram2_exc;
		    if (dram2_load) 	
		    	casez(dram2_addr)
		    	32'hFFD?????:	
		    		begin
		    			adr_o <= dram2_addr;
		    			dram_bus <= dat_i;
		    		end
		    	default: dram_bus <= icache_odat2;	
		    	endcase
		    else if (dram2_store)
		    	casez(dram2_addr)
		    	32'hFFD?????:
		    		begin
		    			wr_o <= 1'b1;
		    			adr_o <= dram2_addr;
		    			dat_o <= dram2_data;
		    		end
		    	default:	;
		    	endcase
		    else			panic <= `PANIC_INVALIDMEMOP;
		    if (dram2_store)
		     	$display("m[%h] <- %h", dram2_addr, dram2_data);
		end
		*/
    end
//	endcase

	//
	// take requests that are ready and put them into DRAM slots

	if (dram0 == DRAMSLOT_AVAIL)	dram0_exc <= FLT_NONE;
	if (dram1 == DRAMSLOT_AVAIL)	dram1_exc <= FLT_NONE;
//	if (dram2 == `DRAMSLOT_AVAIL)	dram2_exc <= FLT_NONE;

	for (n3 = 0; n3 < QENTRIES; n3 = n3 + 1) begin
		if (~iqentry_stomp[n3] && iqentry_memissue[n3] && iq[n3].agen && ~iq[n3].out) begin
	    if (dram0 == DRAMSLOT_AVAIL) begin
				dram0 		<= 2'd1;
				dram0_id 	<= { 1'b1, n3[2:0] };
				dram0_op 	<= iq[n3].op;
				dram0_load <= iq[n3].load;
				dram0_loadz <= iq[n3].loadz;
				dram0_store <= iq[n3].store;
				dram0_tgt 	<= iq[n3].tgt;
				if (dram0_more) begin
					dram0_sel <= dram0_sel >> 8'd64;
					dram0_addr <= {iq[n3].a1[$bits(address_t)-1:6] + 2'd1,6'h0};
					dram0_data <= dram0_data >> 12'd512;
				end
				else begin
					dram0_sel <= {64'h0,fnSel(iq[n3].op)} << iq[n3].a1[5:0];
					dram0_addr	<= iq[n3].a1;
					dram0_data	<= {448'h0,iq[n3].a3} << {iq[n3].a1[5:0],3'b0};
				end
				dram0_memsz <= fnMemsz(iq[n3].op);
				dram0_tid[2:0] <= dram0_tid[2:0] + 2'd1;
				dram0_tid[7:3] <= {4'h1,1'b0};
				iq[n3].out <= VAL;
	    end
	    else if (dram1 == DRAMSLOT_AVAIL && NDATA_PORTS > 1) begin
				dram1 		<= 2'd1;
				dram1_id 	<= { 1'b1, n3[2:0] };
				dram1_op 	<= iq[n3].op;
				dram1_load <= iq[n3].load;
				dram1_loadz <= iq[n3].loadz;
				dram1_store <= iq[n3].store;
				dram1_tgt 	<= iq[n3].tgt;
				if (dram1_more) begin
					dram1_sel <= dram1_sel >> 8'd64;
					dram1_addr <= {iq[n3].a1[$bits(address_t)-1:6] + 2'd1,6'h0};
					dram1_data <= dram1_data >> 12'd512;
				end
				else begin
					dram1_sel <= {64'h0,fnSel(iq[n3].op)} << iq[n3].a1[5:0];
					dram1_addr	<= iq[n3].a1;
					dram1_data	<= {448'h0,iq[n3].a3} << {iq[n3].a1[5:0],3'b0};
				end
				dram1_memsz <= fnMemsz(iq[n3].op);
				dram1_tid[2:0] <= dram1_tid[2:0] + 2'd1;
				dram1_tid[7:3] <= {4'h2,1'b0};
				iq[n3].out	<= VAL;
	    end
	    /*
	    else if (dram2 == `DRAMSLOT_AVAIL) begin
				dram2 		<= 2'd1;
				dram2_id 	<= { 1'b1, n3[2:0] };
				dram2_op 	<= iq[n3].op;
				dram2_load <= iq[n3].load;
				dram2_store <= iq[n3].store;
				dram2_tgt 	<= iq[n3].tgt;
				dram2_data	<= iq[n3].a2;
				dram2_addr	<= iq[n3].a1;
				iq[n3].out	<= VAL;
	    end
	    */
		end
	end

//
// COMMIT PHASE (dequeue only ... not register-file update)
//
// look at heads[0] and heads[1] and let 'em write to the register file if they are ready
//
	
  tOddball_commit(commit0_v, heads[0]);
  tOddball_commit(commit1_v, heads[1]);
  
  if (|head_panic)
  	panic <= head_panic;
end

Thor2024_que_valid uiqv1
(
	.rst(rst),
	.clk(clk),
	.stomp(iqentry_stomp),
	.iq(iq),
	.panic(panic),
	.heads(heads),
	.tail0(tail0), 
	.tail1(tail1), 
	.branchmiss(branchmiss),
	.backbr(db0.backbr),
	.fetchbuf0_v(fetchbuf0_v),
	.fetchbuf1_v(fetchbuf1_v),
	.pred_mask(pred_mask[1:0]),
	.pred_val(pred_val),
	.iq_v(iq_v)
);

always_comb
	for (n16 = 0; n16 < QENTRIES; n16 = n16 + 1)
		iq[n16].v = iq_v[n16];


//
// additional COMMIT logic
//

assign commit0_v = ({iq_v[heads[0]], iq[heads[0]].done} == 2'b11 && ~|panic);
assign commit1_v = (   {iq_v[heads[0]], iq[heads[0]].done} != 2'b10 
	&& {iq_v[heads[1]], iq[heads[1]].done} == 2'b11 && ~|panic);

// These two are not really committing results, they act more as result forwarding.
assign commit2_v =  (iq_v[heads[2]] & iq[heads[2]].done);
assign commit3_v =  (iq_v[heads[3]] & iq[heads[3]].done);

assign commit0_id = {iq[heads[0]].mem, heads[0]};	// if a memory op, it has a DRAM-bus id
assign commit1_id = {iq[heads[1]].mem, heads[1]};	// if a memory op, it has a DRAM-bus id
assign commit2_id = {iq[heads[2]].mem, heads[2]};	// if a memory op, it has a DRAM-bus id
assign commit3_id = {iq[heads[3]].mem, heads[3]};	// if a memory op, it has a DRAM-bus id

assign commit0_tgt = iq[heads[0]].tgt;
assign commit1_tgt = iq[heads[1]].tgt;

assign commit0_bus = iq[heads[0]].res;
assign commit1_bus = iq[heads[1]].res;
assign commit2_bus = iq[heads[2]].res;
assign commit3_bus = iq[heads[3]].res;

assign commit0_instr = iq[heads[0]].op;
assign commit1_instr = iq[heads[1]].op;
assign commit_pc0 = iq[heads[0]].pc;
assign commit_pc1 = iq[heads[1]].pc;
assign commit_brtgt0 = iq[heads[0]].brtgt;
assign commit_brtgt1 = iq[heads[1]].brtgt;
assign commit_takb0 =iq[heads[0]].takb;
assign commit_takb1 =iq[heads[1]].takb;

assign int_commit = (commit0_v && fnIsIrq(iq[heads[0]].op)) ||
                    (commit0_v && commit1_v && fnIsIrq(iq[heads[1]].op));


generate begin : gDisplay
if (SIM) begin
always_ff @(posedge clk) begin: clock_n_debug
	reg [7:0] i;
	integer j;

	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("%h.%h #", pc.pc, pc.micro_ip);
	for (i=0; i< AREGS; i=i+4)
	    $display("%d: %h %d %o  %d: %h %d %o  %d: %h %d %o  %d: %h %d %o #",
	    	i+0, urf2.ab[i+1] ? urf2.urf20.mem[i+0] : urf2.urf10.mem[i+0], rf_v[i+0], rf_source[i+0],
	    	i+1, urf2.ab[i+1] ? urf2.urf20.mem[i+1] : urf2.urf10.mem[i+1], rf_v[i+1], rf_source[i+1],
	    	i+2, urf2.ab[i+2] ? urf2.urf20.mem[i+2] : urf2.urf10.mem[i+2], rf_v[i+2], rf_source[i+2],
	    	i+3, urf2.ab[i+3] ? urf2.urf20.mem[i+3] : urf2.urf10.mem[i+3], rf_v[i+3], rf_source[i+3]
	    );
	$display("%c %h #", branchback?"b":" ", backpc.pc);
	$display("%c%c A: %d %h,%h %h.%h #",
	    45, fetchbuf?45:62, uif1.fetchbufA_v, uif1.fetchbufA_instr[1], uif1.fetchbufA_instr[0], uif1.fetchbufA_pc.pc, uif1.fetchbufA_pc.micro_ip);
	$display("%c%c B: %d %h,%h %h.%h #",
	    45, fetchbuf?45:62, uif1.fetchbufB_v, uif1.fetchbufB_instr[1], uif1.fetchbufB_instr[0], uif1.fetchbufB_pc.pc, uif1.fetchbufB_pc.micro_ip);
	$display("%c%c C: %d %h,%h %h.%h #",
	    45, fetchbuf?62:45, uif1.fetchbufC_v, uif1.fetchbufC_instr[1], uif1.fetchbufC_instr[0], uif1.fetchbufC_pc.pc, uif1.fetchbufC_pc.micro_ip);
	$display("%c%c D: %d %h,%h %h.%h #",
	    45, fetchbuf?62:45, uif1.fetchbufD_v, uif1.fetchbufD_instr[1], uif1.fetchbufD_instr[0], uif1.fetchbufD_pc.pc, uif1.fetchbufD_pc.micro_ip);

	for (i=0; i<QENTRIES; i=i+1) 
	    $display("%c%c %h %d: %c%c%c%c %d %c%c %d %c %c%d 0%d %o %h %h %h %d %o %h %d %o %h %d %o %h.%h #",
		(i[2:0]==heads[0])?72:46, (i[2:0]==tail0)?84:46, iq[i].sn, i,
		iq_v[i]?"v":"-", iq[i].done?"d":"-", iq[i].out?"o":"-", iq[i].bt?"t":"-", iqentry_memissue[i], iq[i].agen?"a":"-", iqentry_issue2[i]?"i":"-",
		((i==0) ? iqentry_islot[0] : (i==1) ? iqentry_islot[1] : (i==2) ? iqentry_islot[2] : (i==3) ? iqentry_islot[3] :
		 (i==4) ? iqentry_islot[4] : (i==5) ? iqentry_islot[5] : (i==6) ? iqentry_islot[6] : iqentry_islot[7]), iqentry_stomp[i]?"s":"-",
		(iq[i].fc ? "b" : (iq[i].load || iq[i].store) ? "m" : "a"), 
		iq[i].op.any.opcode, iq[i].tgt, iq[i].exc, iq[i].res, iq[i].a0, iq[i].a1, iq[i].a1_v,
		iq[i].a1_s, iq[i].a2, iq[i].a2_v, iq[i].a2_s, iq[i].a3, iq[i].a3_v, iq[i].a3_s, iq[i].pc.pc, iq[i].pc.micro_ip);

	$display("DRAM");
	$display("%d%c %h %h %c%d %o #",
	    dram0, dram0_ack?"A":" ", dram0_addr, dram0_data, ((dram0_load || dram0_store) ? 109 : 97), 
	    dram0_op, dram0_id);
	if (NDATA_PORTS > 1) begin
	$display("%d %h %h %c%d %o #",
	    dram1, dram1_addr, dram1_data, ((dram1_load || dram1_store) ? 109 : 97), 
	    dram1_op, dram1_id);
	end
//	$display("%d %h %h %c%d %o #",
//	    dram2, dram2_addr, dram2_data, (fnIsFlowCtrl(dram2_op) ? 98 : (dram2_load || dram2_store) ? 109 : 97), 
//	    dram2_op, dram2_id);
	$display("%d %h %o %h #", dram_v0, dram_bus0, dram_id0, dram_exc0);
	$display("%d %h %o %h #", dram_v1, dram_bus1, dram_id1, dram_exc1);

	$display("%d %h %h %h %c%d %o %h #",
		alu0_dataready, alu0_argI, alu0_argA, alu0_argB, 
		 ((fnIsLoad(alu0_instr) || fnIsStore(alu0_instr)) ? 109 : 97),
		alu0_instr, alu0_sourceid, alu0_pc);
	$display("%d %h %o 0 #", alu0_v, alu0_bus, alu0_id);
	$display("%o #", alu0_sourceid); 

	$display("%d %h %h %h %c%d %o %h #",
		alu1_dataready, alu1_argI, alu1_argA, alu1_argB, 
		 ((fnIsLoad(alu1_instr) || fnIsStore(alu1_instr)) ? 109 : 97),
		alu1_instr, alu1_sourceid, alu1_pc);
	$display("%d %h %o 0 #", alu1_v, alu1_bus, alu1_id);
	$display("%o #", alu1_sourceid); 

	$display("0: %d %h %o 0%d #", commit0_v, commit0_bus, commit0_id, commit0_tgt);
	$display("1: %d %h %o 0%d #", commit1_v, commit1_bus, commit1_id, commit1_tgt);

/*
	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("  pc0=%h", pc0);
	$display("  pc1=%h", pc1);
	$display("  reg0=%h, v=%d, src=%o", rf[0], rf_v[0], rf_source[0]);
	$display("  reg1=%h, v=%d, src=%o", rf[1], rf_v[1], rf_source[1]);
	$display("  reg2=%h, v=%d, src=%o", rf[2], rf_v[2], rf_source[2]);
	$display("  reg3=%h, v=%d, src=%o", rf[3], rf_v[3], rf_source[3]);
	$display("  reg4=%h, v=%d, src=%o", rf[4], rf_v[4], rf_source[4]);
	$display("  reg5=%h, v=%d, src=%o", rf[5], rf_v[5], rf_source[5]);
	$display("  reg6=%h, v=%d, src=%o", rf[6], rf_v[6], rf_source[6]);
	$display("  reg7=%h, v=%d, src=%o", rf[7], rf_v[7], rf_source[7]);

	$display("Fetch Buffers:");
	$display("  %c%c fbA: v=%d instr=%h pc=%h     %c%c fbC: v=%d instr=%h pc=%h", 
	    fetchbuf?32:45, fetchbuf?32:62, fetchbufA_v, fetchbufA_instr, fetchbufA_pc,
	    fetchbuf?45:32, fetchbuf?62:32, fetchbufC_v, fetchbufC_instr, fetchbufC_pc);
	$display("  %c%c fbB: v=%d instr=%h pc=%h     %c%c fbD: v=%d instr=%h pc=%h", 
	    fetchbuf?32:45, fetchbuf?32:62, fetchbufB_v, fetchbufB_instr, fetchbufB_pc,
	    fetchbuf?45:32, fetchbuf?62:32, fetchbufD_v, fetchbufD_instr, fetchbufD_pc);
	$display("  branchback=%d backpc=%h", branchback, backpc);

	$display("Instruction Queue:");
	for (i=0; i<8; i=i+1) 
	    $display(" %c%c%d: v=%d done=%d out=%d agen=%d res=%h op=%d bt=%d tgt=%d a1=%h (v=%d/s=%o) a2=%h (v=%d/s=%o) im=%h pc=%h exc=%h",
		(i[2:0]==heads[0])?72:32, (i[2:0]==tail0)?84:32, i,
		iqentry_v[i], iqentry_done[i], iqentry_out[i], iqentry_agen[i], iqentry_res[i], iqentry_op[i], 
		iqentry_bt[i], iqentry_tgt[i], iqentry_a1[i], iqentry_a1_v[i], iqentry_a1_s[i], iqentry_a2[i], iqentry_a2_v[i], 
		iqentry_a2_s[i], iqentry_a0[i], iqentry_pc[i], iqentry_exc[i]);

	$display("Scheduling Status:");
	$display("  iqentry0 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
		iqentry_0_issue, iqentry_0_islot, iqentry_stomp[0], iqentry_source[0], iqentry_memready[0], iqentry_memissue[0]);
	$display("  iqentry1 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
		iqentry_1_issue, iqentry_1_islot, iqentry_stomp[1], iqentry_source[1], iqentry_memready[1], iqentry_memissue[1]);
	$display("  iqentry2 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
		iqentry_2_issue, iqentry_2_islot, iqentry_stomp[2], iqentry_source[2], iqentry_memready[2], iqentry_memissue[2]);
	$display("  iqentry3 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
		iqentry_3_issue, iqentry_3_islot, iqentry_stomp[3], iqentry_source[3], iqentry_memready[3], iqentry_memissue[3]);
	$display("  iqentry4 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
		iqentry_4_issue, iqentry_4_islot, iqentry_stomp[4], iqentry_source[4], iqentry_memready[4], iqentry_memissue[4]);
	$display("  iqentry5 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
		iqentry_5_issue, iqentry_5_islot, iqentry_stomp[5], iqentry_source[5], iqentry_memready[5], iqentry_memissue[5]);
	$display("  iqentry6 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
		iqentry_6_issue, iqentry_6_islot, iqentry_stomp[6], iqentry_source[6], iqentry_memready[6], iqentry_memissue[6]);
	$display("  iqentry7 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
		iqentry_7_issue, iqentry_7_islot, iqentry_stomp[7], iqentry_source[7], iqentry_memready[7], iqentry_memissue[7]);

	$display("ALU Inputs:");
	$display("  0: avail=%d data=%d id=%o op=%d a1=%h a2=%h im=%h bt=%d",
		alu0_available, alu0_dataready, alu0_sourceid, alu0_instr, alu0_argA,
		alu0_argB, alu0_argI, alu0_bt);
	$display("  1: avail=%d data=%d id=%o op=%d a1=%h a2=%h im=%h bt=%d",
		alu1_available, alu1_dataready, alu1_sourceid, alu1_instr, alu1_argA,
		alu1_argB, alu1_argI, alu1_bt);

	$display("ALU Outputs:");
	$display("  0: v=%d bus=%h id=%o bmiss=%d misspc=%h missid=%o",
		alu0_v, alu0_bus, alu0_id, alu0_branchmiss, alu0_misspc, alu0_sourceid);
	$display("  1: v=%d bus=%h id=%o bmiss=%d misspc=%h missid=%o",
		alu1_v, alu1_bus, alu1_id, alu1_branchmiss, alu1_misspc, alu1_sourceid);

	$display("DRAM Status:");
	$display("  OUT: v=%d data=%h tgt=%d id=%o", dram_v, dram_bus, dram_tgt, dram_id);
	$display("  dram0: status=%h addr=%h data=%h op=%d tgt=%d id=%o",
	    dram0, dram0_addr, dram0_data, dram0_op, dram0_tgt, dram0_id);
	$display("  dram1: status=%h addr=%h data=%h op=%d tgt=%d id=%o", 
	    dram1, dram1_addr, dram1_data, dram1_op, dram1_tgt, dram1_id);
	$display("  dram2: status=%h addr=%h data=%h op=%d tgt=%d id=%o",
	    dram2, dram2_addr, dram2_data, dram2_op, dram2_tgt, dram2_id);

	$display("Commit Buses:");
	$display("  0: v=%d id=%o data=%h", commit0_v, commit0_id, commit0_bus);
	$display("  1: v=%d id=%o data=%h", commit1_v, commit1_id, commit1_bus);

*/
	$display("");

	if (|panic) begin
	    $display("");
	    $display("-----------------------------------------------------------------");
	    $display("-----------------------------------------------------------------");
	    $display("---------------     PANIC:%s     -----------------", message[panic]);
	    $display("-----------------------------------------------------------------");
	    $display("-----------------------------------------------------------------");
	    $display("");
	    $display("");
	end
  $display("instructions committed: %d", I);
  $display("total execution cycles: %d", $time / 30);
	if (|panic && ~outstanding_stores) begin
	    $finish;
	end

end
end
end
endgenerate

task tReset;
begin
	for (n14 = 0; n14 < 4; n14 = n14 + 1) begin
		kvec[n14] <= RSTPC;
		avec[n14] <= RSTPC;
	end
	excir <= {33'd0,OP_NOP};
	sr <= 'd0;
	sr.om <= OM_MACHINE;
	sr.ipl <= 3'd7;				// non-maskable interrupts only
	asid <= 'd0;
	ip_asid <= 'd0;
	atom_mask <= 'd0;
	postfix_mask <= 'd0;
	pred_mask <= 28'hFFFFFFF;
	pred_val <= 1'b1;
	dram0 <= DRAMSLOT_AVAIL;
	dram0p <= DRAMSLOT_AVAIL;
	dram0_addr <= 'd0;
	dram0_data <= 'd0;
	dram0_exc <= FLT_NONE;
	dram0_id <= 'd0;
	dram0_load <= 'd0;
	dram0_store <= 'd0;
	dram0_op <= OP_NOP;
	dram0_tgt <= 'd0;
	dram0_tid <= 'd0;
	dram0_more <= 'd0;
	dram1 <= DRAMSLOT_AVAIL;
	dram1p <= DRAMSLOT_AVAIL;
	dram1_tid <= 8'h08;
	dram1_more <= 'd0;
	dram_v0 <= 'd0;
	dram_v1 <= 'd0;
	panic <= `PANIC_NONE;
	did_branchback1 <= 'd0;
	did_branchback2 <= 'd0;
	iqentry_issue_reg <= 'd0;
	for (n14 = 0; n14 < QENTRIES; n14 = n14 + 1)
		iq[n14].sn <= 6'd0;
	alu0_available <= 1;
	alu0_dataready <= 0;
	alu1_available <= 1;
	alu1_dataready <= 0;
	alu0_ld <= 1'b0;
	alu1_ld <= 1'b0;
	fcu_available <= 1;
	fcu_dataready <= 0;
	fcu_pc <= 'd0;
	fcu_sourceid <= 'd0;
	fcu_instr <= OP_NOP;
//	fcu_exc <= FLT_NONE;
	fcu_bt <= 'd0;
	fcu_argA <= 'd0;
	fcu_argB <= 'd0;
	fcu_argC <= 'd0;
	fcu_argT <= 'd0;
	fcu_argP <= 'd0;
	/*
	for (n11 = 0; n11 < NDATA_PORTS; n11 = n11 + 1) begin
		dramN[n11] <= 'd0;
		dramN_load[n11] <= 'd0;
		dramN_loadz[n11] <= 'd0;
		dramN_store[n11] <= 'd0;
		dramN_addr[n11] <= 'd0;
		dramN_data[n11] <= 'd0;
		dramN_sel[n11] <= 'd0;
		dramN_ack[n11] <= 'd0;
		dramN_memsz[n11] <= Thor2024pkg::nul;
		dramN_tid[n11] = {4'd0,n11[0],3'd0};
	end
	*/
end
endtask


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Commit miscellaneous instructions to machine state.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tOddball_commit;
input v;
input que_ndx_t head;
begin
	if (iq[head].exc != FLT_NONE)
		tProcessExc(head,iq[head].pc);
	case(iq[head].op.any.opcode)
	OP_SYS:
		tProcessExc(head,fnPCInc(iq[head].pc));
	OP_CSR:	
		case(iq[head].op[34:33])
		2'd0:	;	// readCSR
		2'd1:	tWriteCSR(iq[head].a2,{2'b0,iq[head].op[32:19]});
		2'd2:	tSetbitCSR(iq[head].a2,{2'b0,iq[head].op[32:19]});
		2'd3:	tClrbitCSR(iq[head].a2,{2'b0,iq[head].op[32:19]});
		endcase
	OP_RTD:
		if (iq[head].op[10:9]==2'd1) // RTI
			tProcessRti(iq[head].op[8:7]==2'd1);
	OP_IRQ:
		case(iq[head].op[25:22])
		4'h7:	tRex(head,iq[head].op);
		default:	;
		endcase
	default:	;
	endcase
end
endtask


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// CSR Read / Update tasks
//
// Important to use the correct assignment type for the following, otherwise
// The read won't happen until the clock cycle.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tReadCSR;
output value_t res;
input [15:0] regno;
begin
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		$display("regno: %h, om=%d", regno, sr.om);
		casez(regno[15:0])
		CSR_MCORENO:	res = coreno_i;
		CSR_TICK:	res = tick;
		CSR_ASID:	res = asid;
		16'h303C:	res = {sr_stack[1],sr_stack[0]};
		16'h303D:	res = {sr_stack[3],sr_stack[2]};
		16'h303E:	res = {sr_stack[5],sr_stack[4]};
		16'h303F:	res = {sr_stack[7],sr_stack[6]};
		(CSR_MEPC+0):	res = pc_stack[0];
		(CSR_MEPC+1):	res = pc_stack[1];
		(CSR_MEPC+2):	res = pc_stack[2];
		(CSR_MEPC+3):	res = pc_stack[3];
		(CSR_MEPC+4):	res = pc_stack[4];
		(CSR_MEPC+5):	res = pc_stack[5];
		(CSR_MEPC+6):	res = pc_stack[6];
		(CSR_MEPC+7):	res = pc_stack[7];
		/*
		CSR_SCRATCH:	res = scratch[regno[13:12]];
		CSR_MHARTID: res = hartid_i;
		CSR_MCR0:	res = cr0|(dce << 5'd30);
		CSR_PTBR:	res = ptbr;
		CSR_HMASK:	res = hmask;
		CSR_KEYS:	res = keys2[regno[0]];
		CSR_SEMA: res = sema;
//		CSR_FSTAT:	res = fpscr;
		CSR_MBADADDR:	res = badaddr[regno[13:12]];
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
		*/
		default:	res = 64'd0;
		endcase
	end
	else
		res = 64'd0;
end
endtask

task tWriteCSR;
input value_t val;
input [15:0] regno;
begin
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		CSR_ASID: 	asid <= val;
		16'h303C: {sr_stack[1],sr_stack[0]} <= val;
		16'h303D:	{sr_stack[3],sr_stack[2]} <= val;
		16'h303E:	{sr_stack[5],sr_stack[4]} <= val;
		16'h303F:	{sr_stack[7],sr_stack[6]} <= val;
		CSR_MEPC+0:	pc_stack[0] <= val;
		CSR_MEPC+1:	pc_stack[1] <= val;
		CSR_MEPC+2:	pc_stack[2] <= val;
		CSR_MEPC+3:	pc_stack[3] <= val;
		CSR_MEPC+4:	pc_stack[4] <= val;
		CSR_MEPC+5:	pc_stack[5] <= val;
		CSR_MEPC+6:	pc_stack[6] <= val;
		CSR_MEPC+7:	pc_stack[7] <= val;
		/*
		CSR_SCRATCH:	scratch[regno[13:12]] <= val;
		CSR_MCR0:		cr0 <= val;
		CSR_PTBR:		ptbr <= val;
		CSR_HMASK:	hmask <= val;
		CSR_SEMA:		sema <= val;
		CSR_KEYS:		keys2[regno[0]] <= val;
//		CSR_FSTAT:	fpscr <= val;
		CSR_MBADADDR:	badaddr[regno[13:12]] <= val;
		CSR_CAUSE:	cause[regno[13:12]] <= val[11:0];
		CSR_MTVEC:	tvec[regno[1:0]] <= val;
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
		*/
		default:	;
		endcase
	end
end
endtask

task tSetbitCSR;
input value_t val;
input [15:0] regno;
begin
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		/*
		CSR_MCR0:			cr0[val[5:0]] <= 1'b1;
		CSR_SEMA:			sema[val[5:0]] <= 1'b1;
		CSR_MPMSTACK:	pmStack <= pmStack | val;
		CSR_MSTATUS:	status[3] <= status[3] | val;
		*/
		default:	;
		endcase
	end
end
endtask

task tClrbitCSR;
input value_t val;
input [15:0] regno;
begin
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		/*
		CSR_MCR0:			cr0[val[5:0]] <= 1'b0;
		CSR_SEMA:			sema[val[5:0]] <= 1'b0;
		CSR_MPMSTACK:	pmStack <= pmStack & ~val;
		CSR_MSTATUS:	status[3] <= status[3] & ~val;
		*/
		default:	;
		endcase
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Exception processing tasks.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tProcessExc;
input que_ndx_t id;
input pc_address_t retpc;
integer nn;
reg [8:0] vecno;
begin
	vecno = iq[id].imm ? iq[id].a0[8:0] : iq[id].a1[8:0];
	for (nn = 1; nn < 8; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn-1];
	sr_stack[0] <= sr;
	for (nn = 1; nn < 8; nn = nn + 1)
		pc_stack[nn] <= pc_stack[nn-1];
	pc_stack[0] <= retpc;
	sr.ipl <= 3'd7;
	excir <= iq[id].op;
	excid <= id;
	excmiss <= 1'b1;
	if (vecno < 9'd64)
		excmisspc <= {kvec[3][$bits(pc_address_t)-1:4] + vecno,4'h0,12'h000};
	else
		excmisspc <= {avec[$bits(pc_address_t)-1:4] + vecno,4'h0,12'h000};
end
endtask

task tProcessRti;
input twoup;
integer nn;
begin
	sr <= twoup ? sr_stack[1] : sr_stack[0];
	for (nn = 0; nn < 7; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn+1+twoup];
	sr_stack[7].ipl <= 3'd7;
	sr_stack[8].ipl <= 3'd7;
	sr_stack[7].om <= OM_MACHINE;
	sr_stack[8].om <= OM_MACHINE;
	for (nn = 0; nn < 7; nn = nn + 1)
		pc_stack[nn] <=	pc_stack[nn+1+twoup];
	pc_stack[7] <= RSTPC;
	pc_stack[8] <= RSTPC;
end
endtask

task tRex;
input que_ndx_t id;
input instruction_t ir;
reg [8:0] vecno;
begin
	vecno = cause[3][8:0];
	if (sr.om > ir[8:7]) begin
		sr.om <= operating_mode_t'(ir[8:7]);
		excid <= id;
		excmiss <= 1'b1;
		if (vecno < 9'd64)
			excmisspc <= {kvec[ir[8:7]][$bits(pc_address_t)-1:4] + vecno,4'h0,12'h000};
		else
			excmisspc <= {avec[$bits(pc_address_t)-1:4] + vecno,4'h0,12'h000};
	end
end
endtask

endmodule

module decoder6 (num, out);
input [5:0] num;
output [63:1] out;

reg [63:0] out1;
always_comb
	out1 = 64'd1 << num;

assign out = out1[63:1];

endmodule
