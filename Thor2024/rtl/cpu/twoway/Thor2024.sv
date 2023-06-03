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

`define ZERO		32'd0

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

// exception types:
`define EXC_NONE	4'd0
`define EXC_HALT	4'd1
`define EXC_TLBMISS	4'd2
`define EXC_SIGSEGV	4'd3
`define EXC_INVALID	4'd4

`define INSTRUCTION_S1  6:4	// contains the syscall sub-class (NONE, CALL, MFSR, MTSR, EXC, etc.)
`define INSTRUCTION_S2  3:0	// contains the sub-class identifier value

`define FORW_BRANCH	1'b0

`define DRAMSLOT_AVAIL	2'b00
`define DRAMREQ_READY	2'b11

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

//`define FULL_ISSUE_LOGIC	1'b1

module Thor2024(rst_i, clk_i, irq_i, vect_i, wr_o, adr_o, dat_i, dat_o,
	ftaim_req, ftaim_resp, ftadm_req, ftadm_resp,
	snoop_adr, snoop_v, snoop_cid);
parameter CORENO = 6'd1;
parameter CID = 6'd1;
input rst_i;
input clk_i;
input [2:0] irq_i;
input [8:0] vect_i;
output reg wr_o;
output reg [31:0] adr_o;
input [31:0] dat_i;
output reg [31:0] dat_o;
output fta_cmd_request128_t [NDATA_PORTS-1:0] ftadm_req;
input fta_cmd_response128_t [NDATA_PORTS-1:0] ftadm_resp;
output fta_cmd_request128_t ftaim_req;
input fta_cmd_response128_t ftaim_resp;
input Thor2024pkg::address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;

integer n,nn,n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11;
genvar g;

wire value_t [AREGS-1:0] rf;
wire [AREGS-1:0] rf_v;
wire [4:0] rf_source[0:AREGS-1];
wire [31:0] pc;
wire clk;
wire rst;
assign rst = rst_i;
reg  [3:0] panic;		// indexes the message structure
reg [128:0] message [0:15];	// indexed by panic

typedef logic [QENTRIES-1:0] que_bitmask_t;

wire [63:0] dec_imm0, dec_imm1;

reg [7:0] atom_mask;
reg [5:0] postfix_mask;
reg [27:0] pred_mask;
reg [1:0] pred_val;

// instruction queue (ROB)
iq_entry_t [7:0] iq;

que_bitmask_t iq_v;
que_bitmask_t iqentry_source;
que_bitmask_t iqentry_imm;
que_bitmask_t iqentry_memready;
que_bitmask_t iqentry_memopsvalid;

que_bitmask_t iqentry_memissue;
que_bitmask_t iqentry_stomp;
que_bitmask_t iqentry_issue;
que_bitmask_t iqentry_fcu_issue;
reg [1:0] iqentry_islot [0:7];

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
que_ndx_t head0;
que_ndx_t head1;
que_ndx_t head2;	// used only to determine memory-access ordering
que_ndx_t head3;	// used only to determine memory-access ordering
que_ndx_t head4;	// used only to determine memory-access ordering
que_ndx_t head5;	// used only to determine memory-access ordering
que_ndx_t head6;	// used only to determine memory-access ordering
que_ndx_t head7;	// used only to determine memory-access ordering
que_ndx_t lastq0;
que_ndx_t lastq1;
reg fetch0,fetch1;
reg q1open,q2open,q3open,q4open;
reg canq1,canq2;
reg queued1Nop, queued2Nop;

que_ndx_t missid;

regspec_t Ra0, Rb0, Rc0, Rt0, Rp0;
regspec_t Ra1, Rb1, Rc1, Rt1, Rp1;

wire        fetchbuf;	// determines which pair to read from & write to
wire istall;

instruction_t [4:0] fetchbuf0_instr;
instruction_t fetchbuf0_postfixes [0:3];	
wire [31:0] fetchbuf0_pc;
wire        fetchbuf0_v;
wire        fetchbuf0_mem;
wire        fetchbuf0_jmp;
wire        fetchbuf0_rfw;
instruction_t [4:0] fetchbuf1_instr;
instruction_t fetchbuf1_postfixes [0:3];
wire [31:0] fetchbuf1_pc;
wire        fetchbuf1_v;
wire        fetchbuf1_mem;
wire        fetchbuf1_jmp;
wire        fetchbuf1_rfw;

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
reg [31:0] alu0_pc;
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
reg [31:0] alu1_pc;
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
reg [31:0] fcu_pc;
value_t fcu_bus;
wire  [3:0] fcu_id;
cause_code_t fcu_exc;
wire        fcu_v;
reg fcu_branchmiss;
reg [31:0] fcu_misspc;
reg takb;


wire branchback;
address_t backpc;
wire branchmiss;
address_t misspc;

wire dram_avail;
reg	[1:0] dram0;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	[1:0] dram1;	// state of the DRAM request (latency = 4; can have three in pipeline)
//reg	 [1:0] dram2;	// state of the DRAM request (latency = 4; can have three in pipeline)

value_t dram0_data;
reg [31:0] dram0_addr;
reg [63:0] dram0_sel;
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

value_t dram1_data;
reg [31:0] dram1_addr;
reg [63:0] dram1_sel;
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

reg [1:0] dramN [0:NDATA_PORTS-1];
value_t [NDATA_PORTS-1:0] dramN_data;
reg [63:0] dramN_sel [0:NDATA_PORTS-1];
reg [31:0] dramN_addr [0:NDATA_PORTS-1];
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
reg [63:0] I;	// instruction count

wire commit0_v;
wire [4:0] commit0_id;
regspec_t commit0_tgt;
value_t commit0_bus;
address_t commit_pc0;
reg commit_takb0;
address_t commit_brtgt0;
wire commit1_v;
wire [4:0] commit1_id;
regspec_t commit1_tgt;
value_t commit1_bus;
address_t commit_pc1;
reg commit_takb1;
address_t commit_brtgt1;
wire int_commit;

// CSRs
wire [2:0] im = 3'd7;

assign clk = clk_i;

function [63:0] fnA1;
input instruction_t fetchbuf_instr;
input address_t fetchbuf_pc;
input [5:0] Ra;
input [63:0] imm;
begin
	fnA1 = fnImma(fetchbuf_instr) ? imm : Ra==6'd53 ? fetchbuf_pc : rf[ Ra ];
end
endfunction

function [63:0] fnA2;
input instruction_t fetchbuf_instr;
input address_t fetchbuf_pc;
input [5:0] Rb;
input [63:0] imm;
begin
	fnA2 = fnImmb(fetchbuf_instr) ? imm : Rb==6'd53 ? fetchbuf_pc : rf[ Rb ];
end
endfunction

function [63:0] fnA3;
input instruction_t fetchbuf_instr;
input address_t fetchbuf_pc;
input [5:0] Rc;
input [63:0] imm;
begin
	fnA3 = fnImmc(fetchbuf_instr) ? imm : Rc==6'd53 ? fetchbuf_pc : rf[ Rc ];
end
endfunction

function [63:0] fnAP;
input instruction_t ir;
input [5:0] Rp;
begin
	case(ir.any.opcode)
	OP_R2:	
		if (ir.r2.fmt[0])
			fnAP = rf [ Rp ];
		else
			fnAP = {64{1'b1}};
	OP_JSR,
	OP_ADDI:	fnAP = ir.ri.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_CMPI:	fnAP = ir.ri.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_MULI:	fnAP = ir.ri.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_DIVI:	fnAP = ir.ri.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_ANDI:	fnAP = ir.ri.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_ORI:		fnAP = ir.ri.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_EORI:	fnAP = ir.ri.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_SLTI:	fnAP = ir.ri.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_BEQ:		fnAP = {64{1'b1}};
	OP_BNE:		fnAP = {64{1'b1}};
	OP_BLT:		fnAP = {64{1'b1}};
	OP_BLE:		fnAP = {64{1'b1}};
	OP_BGT:		fnAP = {64{1'b1}};
	OP_BGE:		fnAP = {64{1'b1}};
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO:
		fnAP = ir.ls.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_LDX:
		fnAP = ir.lsn.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_STB,OP_STW,OP_STT,OP_STO:
		fnAP = ir.ls.fmt[0] ? rf [Rp] : {64{1'b1}};
	OP_STX:
		fnAP = ir.lsn.fmt[0] ? rf [Rp] : {64{1'b1}};
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
for (n5 = 0; n5 < QENTRIES; n5 = n5 + 1)
	iq_v[n5] = iq[n5].v;
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

always_comb
	ic_line = {ic_line_hi.data,ic_line_lo.data};
always_comb
	{pfx0[3],pfx0[2],pfx0[1],pfx0[0],ins0} = ic_line >> {pco[5:0],3'd0};
always_comb
	{pfx1[3],pfx1[2],pfx1[1],pfx1[0],ins1} = ic_line >> {pco[5:0]+4'd5,3'd0};

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
else if (ihito)
 	inst0 <= {pfx0[3],pfx0[2],pfx0[1],pfx0[0],ins0};
else
  inst0 <= {5{33'h1FFFFFFFE,OP_NOP}};

always_comb
if (hirq)
	inst1 <= {{4{33'h1FFFFFFFF,OP_NOP}},FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS};
else if (ihito)
  inst1 <= {pfx1[3],pfx1[2],pfx1[1],pfx1[0],ins1};
else
  inst1 <= {5{33'h1FFFFFFFE,OP_NOP}};


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

address_t next_pc;
wire ntakb,ptakb;
reg invce = 1'b0;
reg dc_invline = 1'b0;
reg dc_invall = 1'b0;
reg ic_invline = 1'b0;
reg ic_invall = 1'b0;
ICacheLine ic_line_o;

asid_t ip_asid;
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
	.ip(pc),
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
	.next_pc(next_pc),
	.takb(ntakb),
	.ptakb(ptakb),
	.pc(pc),
	.pc_i(pco),
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
	.fetchbuf1_pc(fetchbuf1_pc)
);

Thor2024_decode_imm udeci0
(
	.ins(fetchbuf0_instr),
	.imm(dec_imm0)
);

Thor2024_decode_imm udeci1
(
	.ins(fetchbuf1_instr),
	.imm(dec_imm1)
);

assign fetchbuf0_mem = fnIsMem(fetchbuf0_instr[0]);
assign fetchbuf1_mem = fnIsMem(fetchbuf1_instr[0]);
assign fetchbuf0_rfw = Rt0 != 'd0;
assign fetchbuf1_rfw = Rt1 != 'd0;

always_comb
	q1open = ~iq[tail0].v;
always_comb
	q2open = ~iq[tail0].v & ~iq[tail1].v;
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
	dramN_data[0] = dram0_data;
	dramN_sel[0] = dram0_sel;
	dramN_store[0] = dram0_store;
	dramN_load[0] = dram0_load;
	dramN_loadz[0] = dram0_loadz;
	dramN_memsz[0] = dram0_memsz;
	dramN_tid[0] = dram0_tid;
	dram0_ack = dramN_ack[0];
	
	dramN[1] = dram1;
	dramN_addr[1] = dram1_addr;
	dramN_data[1] = dram1_data;
	dramN_sel[1] = dram1_sel;
	dramN_store[1] = dram1_store;
	dramN_load[1] = dram1_load;
	dramN_loadz[1] = dram1_loadz;
	dramN_memsz[1] = dram1_memsz;
	dramN_tid[1] = dram1_tid;
	dram1_ack = dramN_ack[1];
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
		cpu_request_i[g].cyc = dramN[g]==`DRAMREQ_READY;
		cpu_request_i[g].stb = dramN[g]==`DRAMREQ_READY;
		cpu_request_i[g].we = dramN_store[g];
		cpu_request_i[g].vadr = dramN_addr[g];
		cpu_request_i[g].padr = 'd0;
		cpu_request_i[g].sz = fta_bus_pkg::fta_size_t'(dramN_memsz[g]);
		cpu_request_i[g].dat = dramN_data[g] << {dramN_addr[g][5:0],3'd0};
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
assign fetchbuf0_mem   = (fetchbuf == 1'b0) 
		? (fetchbufA_instr[`INSTRUCTION_OP] == `LW || fetchbufA_instr[`INSTRUCTION_OP] == `SW)
		: (fetchbufC_instr[`INSTRUCTION_OP] == `LW || fetchbufC_instr[`INSTRUCTION_OP] == `SW);
assign fetchbuf0_jmp   = (fetchbuf == 1'b0)
		? (fetchbufA_instr[`INSTRUCTION_OP] == `BEQ || fetchbufA_instr[`INSTRUCTION_OP] == `JALR)
		: (fetchbufC_instr[`INSTRUCTION_OP] == `BEQ || fetchbufC_instr[`INSTRUCTION_OP] == `JALR);
assign fetchbuf0_rfw   = (fetchbuf == 1'b0)
		? (fetchbufA_instr[`INSTRUCTION_OP] != `BEQ && fetchbufA_instr[`INSTRUCTION_OP] != `SW)
		: (fetchbufC_instr[`INSTRUCTION_OP] != `BEQ && fetchbufC_instr[`INSTRUCTION_OP] != `SW);

assign fetchbuf1_mem   = (fetchbuf == 1'b0) 
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
	iqentry_livetarget[n6] = {63 {iq[n6].v}} & {63 {~iqentry_stomp[n6]}} & iq_out[n6];

//
// BRANCH-MISS LOGIC: latestID
//
// latestID is the instruction queue ID of the newest instruction (latest) that targets
// a particular register.  looks a lot like scheduling logic, but in reverse.
// 

assign iqentry_0_latestID = (missid == 3'd0 || ((iqentry_livetarget[0] & iqentry_1_cumulative) == 'd0))
		    ? iqentry_livetarget[0]
		    : 'd0;
assign iqentry_0_cumulative = (missid == 3'd0)
		    ? iqentry_livetarget[0]
		    : iqentry_livetarget[0] | iqentry_1_cumulative;

assign iqentry_1_latestID = (missid == 3'd1 || ((iqentry_livetarget[1] & iqentry_2_cumulative) == 'd0))
		    ? iqentry_livetarget[1]
		    : 'd0;
assign iqentry_1_cumulative = (missid == 3'd1)
		    ? iqentry_livetarget[1]
		    : iqentry_livetarget[1] | iqentry_2_cumulative;

assign iqentry_2_latestID = (missid == 3'd2 || ((iqentry_livetarget[2] & iqentry_3_cumulative) == 'd0))
		    ? iqentry_livetarget[2]
		    : 'd0;
assign iqentry_2_cumulative = (missid == 3'd2)
		    ? iqentry_livetarget[2]
		    : iqentry_livetarget[2] | iqentry_3_cumulative;

assign iqentry_3_latestID = (missid == 3'd3 || ((iqentry_livetarget[3] & iqentry_4_cumulative) == 'd0))
		    ? iqentry_livetarget[3]
		    : 'd0;
assign iqentry_3_cumulative = (missid == 3'd3)
		    ? iqentry_livetarget[3]
		    : iqentry_livetarget[3] | iqentry_4_cumulative;

assign iqentry_4_latestID = (missid == 3'd4 || ((iqentry_livetarget[4] & iqentry_5_cumulative) == 'd0))
		    ? iqentry_livetarget[4]
		    : 'd0;
assign iqentry_4_cumulative = (missid == 3'd4)
		    ? iqentry_livetarget[4]
		    : iqentry_livetarget[4] | iqentry_5_cumulative;

assign iqentry_5_latestID = (missid == 3'd5 || ((iqentry_livetarget[5] & iqentry_6_cumulative) == 'd0))
		    ? iqentry_livetarget[5]
		    : 'd0;
assign iqentry_5_cumulative = (missid == 3'd5)
		    ? iqentry_livetarget[5]
		    : iqentry_livetarget[5] | iqentry_6_cumulative;

assign iqentry_6_latestID = (missid == 3'd6 || ((iqentry_livetarget[6] & iqentry_7_cumulative) == 'd0))
		    ? iqentry_livetarget[6]
		    : 'd0;
assign iqentry_6_cumulative = (missid == 3'd6)
		    ? iqentry_livetarget[6]
		    : iqentry_livetarget[6] | iqentry_7_cumulative;

assign iqentry_7_latestID = (missid == 3'd7 || ((iqentry_livetarget[7] & iqentry_0_cumulative) == 'd0))
		    ? iqentry_livetarget[7]
		    : 'd0;
assign iqentry_7_cumulative = (missid == 3'd7)
		    ? iqentry_livetarget[7]
		    : iqentry_livetarget[7] | iqentry_0_cumulative;
assign iqentry_7_latestID = (missid == 3'd7 || ((iqentry_livetarget[7] & iqentry_0_cumulative) == 'd0))
		    ? iqentry_livetarget[7]
		    : 'd0;
assign iqentry_7_cumulative = (missid == 3'd7)
		    ? iqentry_livetarget[7]
		    : iqentry_livetarget[7] | iqentry_0_cumulative;

assign 
	iqentry_source[0] = | iqentry_0_latestID,
  iqentry_source[1] = | iqentry_1_latestID,
  iqentry_source[2] = | iqentry_2_latestID,
  iqentry_source[3] = | iqentry_3_latestID,
  iqentry_source[4] = | iqentry_4_latestID,
  iqentry_source[5] = | iqentry_5_latestID,
  iqentry_source[6] = | iqentry_6_latestID,
  iqentry_source[7] = | iqentry_7_latestID;

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
	.fetchbuf0_instr(fetchbuf0_instr),
	.fetchbuf1_instr(fetchbuf1_instr),
	.fetchbuf0_mem(fetchbuf0_mem),
	.fetchbuf1_mem(fetchbuf1_mem),
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
	.tail0(tail0),
	.tail1(tail1),
	.fetchbuf0_v(fetchbuf0_v),
	.fetchbuf1_v(fetchbuf1_v),
	.fetchbuf0_rfw(fetchbuf0_rfw),
	.fetchbuf1_rfw(fetchbuf1_rfw),
	.fetchbuf0_instr(fetchbuf0_instr),
	.fetchbuf1_instr(fetchbuf1_instr),
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

always_comb
	Ra0 = fnRa(fetchbuf0_instr[0]);
always_comb
	Rb0 = fnRb(fetchbuf0_instr[0]);
always_comb
	Rc0 = fnRc(fetchbuf0_instr[0]);
always_comb
	Rt0 = fnRt(fetchbuf0_instr[0]);
always_comb
	Rp0 = &pred_mask[3:0] ? fnRp(fetchbuf0_instr[0]) : {2'b10,pred_mask[3:0]};
always_comb
	Ra1 = fnRa(fetchbuf1_instr[0]);
always_comb
	Rb1 = fnRb(fetchbuf1_instr[0]);
always_comb
	Rc1 = fnRc(fetchbuf1_instr[0]);
always_comb
	Rt1 = fnRt(fetchbuf1_instr[0]);
always_comb
	Rp1 = &pred_mask[7:4] ? fnRp(fetchbuf1_instr[0]) : {2'b10,pred_mask[7:4]};

//
// additional logic for ISSUE
//
// for the moment, we look at ALU-input buffers to allow back-to-back issue of 
// dependent instructions ... we do not, however, look ahead for DRAM requests 
// that will become valid in the next cycle.  instead, these have to propagate
// their results into the IQ entry directly, at which point it becomes issue-able
//

// note that, for all intents & purposes, iqentry_done == iqentry_agen ... no need to duplicate

wire [QENTRIES-1:0] args_valid;
wire [QENTRIES-1:0] could_issue;

generate begin : issue_logic
for (g = 0; g < QENTRIES; g = g + 1)
begin
assign args_valid[g] = (iq[g].a1_v
				    || (iq[g].a1_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].a1_s == alu1_sourceid && alu1_dataready))
				    && (iq[g].a2_v
				    || (iq[g].mem & ~iq[g].agen)
				    || (iq[g].a2_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].a2_s == alu1_sourceid && alu1_dataready))
				    && (iq[g].a3_v
				    || (iq[g].a3_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].a3_s == alu1_sourceid && alu1_dataready))
				    && (iq[g].at_v
				    || (iq[g].at_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].at_s == alu1_sourceid && alu1_dataready))
				    && (iq[g].ap_v
				    || (iq[g].ap_s == alu0_sourceid && alu0_dataready)
				    || (iq[g].ap_s == alu1_sourceid && alu1_dataready))
				    ;
assign could_issue[g] = iq[g].v && !iq[g].done && !iq[g].out
												&& args_valid[g]
                        && (iq[g].mem ? !iq[g].agen : 1'b1);
end                                 
end
endgenerate

// FPGAs do not handle race loops very well.
// The (old) simulator didn't handle the asynchronous race loop properly in the 
// original code. It would issue two instructions to the same islot. So the
// issue logic has been re-written to eliminate the asynchronous loop.
// Can't issue to the ALU if it's busy doing a long running operation like a 
// divide.
// ToDo: fix the memory synchronization, see fp_issue below

always_comb
begin
	iqentry_issue = 'h0;
	for (n = 0; n < QENTRIES; n = n + 1)
		iqentry_islot[n] = 2'b00;
	
	// aluissue is a task
	if (alu0_idle) begin
		if (could_issue[head0] && iq[head0].alu
		&& !iqentry_issue[head0]) begin
		  iqentry_issue[head0] = `TRUE;
		  iqentry_islot[head0] = 2'b00;
		end
		else if (could_issue[head1] && !iqentry_issue[head1] && iq[head1].alu
		)
		begin
		  iqentry_issue[head1] = `TRUE;
		  iqentry_islot[head1] = 2'b00;
		end
		else if (could_issue[head2] && !iqentry_issue[head2] && iq[head2].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		)
		begin
			iqentry_issue[head2] = `TRUE;
			iqentry_islot[head2] = 2'b00;
		end
		else if (could_issue[head3] && !iqentry_issue[head3] && iq[head3].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
			)
		) begin
			iqentry_issue[head3] = `TRUE;
			iqentry_islot[head3] = 2'b00;
		end
		else if (could_issue[head4] && !iqentry_issue[head4] && iq[head4].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		) begin
			iqentry_issue[head4] = `TRUE;
			iqentry_islot[head4] = 2'b00;
		end
		else if (could_issue[head5] && !iqentry_issue[head5] && iq[head5].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		) begin
			iqentry_issue[head5] = `TRUE;
			iqentry_islot[head5] = 2'b00;
		end
`ifdef FULL_ISSUE_LOGIC
		else if (could_issue[head6] && !iqentry_issue[head6] && iq[head6].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		&& (!(iq[head5].v && iq[head5].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v))
			)
		) begin
			iqentry_issue[head6] = `TRUE;
			iqentry_islot[head6] = 2'b00;
		end
		else if (could_issue[head7] && !iqentry_issue[head7] && iq[head7].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		&& (!(iq[head5].v && iq[head5].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v))
			)
		&& (!(iq[head6].v && iq[head6].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v)
		 	&&   (!iq[head5].v))
			)
		) begin
			iqentry_issue[head7] = `TRUE;
			iqentry_islot[head7] = 2'b00;
		end
`endif
	end

	if (alu1_idle) begin
		if (could_issue[head0] && iq[head0].alu
		&& !iqentry_issue[head0]) begin
		  iqentry_issue[head0] = `TRUE;
		  iqentry_islot[head0] = 2'b01;
		end
		else if (could_issue[head1] && !iqentry_issue[head1] && iq[head1].alu)
		begin
		  iqentry_issue[head1] = `TRUE;
		  iqentry_islot[head1] = 2'b01;
		end
		else if (could_issue[head2] && !iqentry_issue[head2] && iq[head2].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		)
		begin
			iqentry_issue[head2] = `TRUE;
			iqentry_islot[head2] = 2'b01;
		end
		else if (could_issue[head3] && !iqentry_issue[head3] && iq[head3].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
			)
		) begin
			iqentry_issue[head3] = `TRUE;
			iqentry_islot[head3] = 2'b01;
		end
		else if (could_issue[head4] && !iqentry_issue[head4] && iq[head4].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		) begin
			iqentry_issue[head4] = `TRUE;
			iqentry_islot[head4] = 2'b01;
		end
		else if (could_issue[head5] && !iqentry_issue[head5] && iq[head5].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		) begin
			iqentry_issue[head5] = `TRUE;
			iqentry_islot[head5] = 2'b01;
		end
`ifdef FULL_ISSUE_LOGIC
		else if (could_issue[head6] && !iqentry_issue[head6] && iq[head6].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		&& (!(iq[head5].v && iq[head5].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v))
			)
		) begin
			iqentry_issue[head6] = `TRUE;
			iqentry_islot[head6] = 2'b01;
		end
		else if (could_issue[head7] && !iqentry_issue[head7] && iq[head7].alu
		&& (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
		&& (!(iq[head2].v && iq[head2].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v))
		 	)
		&& (!(iq[head3].v && iq[head3].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v))
			)
		&& (!(iq[head4].v && iq[head4].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v))
			)
		&& (!(iq[head5].v && iq[head5].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v))
			)
		&& (!(iq[head6].v && iq[head6].sync) ||
		 		((!iq[head0].v)
		 	&&   (!iq[head1].v)
		 	&&   (!iq[head2].v)
		 	&&   (!iq[head3].v)
		 	&&   (!iq[head4].v)
		 	&&   (!iq[head5].v))
			)
		) begin
			iqentry_issue[head7] = `TRUE;
			iqentry_islot[head7] = 2'b01;
		end
`endif
	end
end

// Don't issue to the fcu until the following instruction is enqueued.
// However, if the queue is full then issue anyway. A branch miss will likely occur.
always_comb
begin
	iqentry_fcu_issue = 8'h00;
	if (fcu_idle) begin
    if (could_issue[head0] && iq[head0].fc) begin
      iqentry_fcu_issue[head0] = `TRUE;
    end
    else if (could_issue[head1] && iq[head1].fc)
    begin
      iqentry_fcu_issue[head1] = `TRUE;
    end
    else if (could_issue[head2] && iq[head2].fc
    && (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
    ) begin
   		iqentry_fcu_issue[head2] = `TRUE;
    end
    else if (could_issue[head3] && iq[head3].fc
    && (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
    && (!(iq[head2].v && iq[head2].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v))
    	)
    ) begin
   		iqentry_fcu_issue[head3] = `TRUE;
    end
    else if (could_issue[head4] && iq[head4].fc
    && (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
    && (!(iq[head2].v && iq[head2].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v))
     	)
    && (!(iq[head3].v && iq[head3].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v))
    	)
    ) begin
   		iqentry_fcu_issue[head4] = `TRUE;
    end
    else if (could_issue[head5] && iq[head5].fc
    && (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
    && (!(iq[head2].v && iq[head2].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v))
     	)
    && (!(iq[head3].v && iq[head3].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v))
    	)
    && (!(iq[head4].v && iq[head4].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v)
     	&&   (!iq[head3].v))
    	)
    ) begin
   		iqentry_fcu_issue[head5] = `TRUE;
    end
 
`ifdef FULL_ISSUE_LOGIC
    else if (could_issue[head6] && iq[head6].fc
    && (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
    && (!(iq[head2].v && iq[head2].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v))
     	)
    && (!(iq[head3].v && iq[head3].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v))
    	)
    && (!(iq[head4].v && iq[head4].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v)
     	&&   (!iq[head3].v))
    	)
    && (!(iq[head5].v && iq[head5].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v)
     	&&   (!iq[head3].v)
     	&&   (!iq[head4].v))
    	)
    ) begin
   		iqentry_fcu_issue[head6] = `TRUE;
    end
   
    else if (could_issue[head7] && iq[head7].fc
    && (!(iq[head1].v && iq[head1].sync) || !iq[head0].v)
    && (!(iq[head2].v && iq[head2].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v))
     	)
    && (!(iq[head3].v && iq[head3].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v))
    	)
    && (!(iq[head4].v && iq[head4].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v)
     	&&   (!iq[head3].v))
    	)
    && (!(iq[head5].v && iq[head5].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v)
     	&&   (!iq[head3].v)
     	&&   (!iq[head4].v))
    	)
    && (!(iq[head6].v && iq[head6].sync) ||
     		((!iq[head0].v)
     	&&   (!iq[head1].v)
     	&&   (!iq[head2].v)
     	&&   (!iq[head3].v)
     	&&   (!iq[head4].v)
     	&&   (!iq[head5].v))
    	)
    ) begin
   		iqentry_fcu_issue[head7] = `TRUE;
  	end
`endif
	end
end

/*
always_comb
	for (n2 = 0; n2 < 8; n2 = n2 + 1) begin
    iqentry_issue[n2] = (iq[n2].v && !iq[n2].out && !iq[n2].agen
				&& (head0 == n2[2:0] || ~|iqentry_islot[(n2+7)&7] || (iqentry_islot[(n2+7)&7] == 2'b01 && ~iqentry_issue[(n2+7)&7]))
				&& (iq[n2].a1_v 
				    || (iq[n2].a1_s == alu0_sourceid && alu0_dataready)
				    || (iq[n2].a1_s == alu1_sourceid && alu1_dataready))
				&& (iq[n2].a2_v 
				    || (iq[n2].mem & ~iq[n2].agen)
				    || (iq[n2].a2_s == alu0_sourceid && alu0_dataready)
				    || (iq[n2].a2_s == alu1_sourceid && alu1_dataready)));
				    
    iqentry_islot[n2] = (head0 == n2[2:0]) ? 2'b00
				: (iqentry_islot[(n2+7)&7] == 2'b11) ? 2'b11
				: (iqentry_islot[(n2+7)&7] + {1'b0, iqentry_issue[(n2+7)&7]});
	end
*/
// 
// additional logic for handling a branch miss (STOMP logic)
// Must also stomp on the last entry queued as a branch has a delayed effect.
//
reg [$clog2(QENTRIES)-1:0] n4p;
always_comb
for (n4 = 0; n4 < QENTRIES; n4 = n4 + 1)
begin
	n4p = (n4 + (QENTRIES-1)) % QENTRIES;
	iqentry_stomp[n4] = branchmiss
											&& iq[n4].v
											&& head0 != n4[$clog2(QENTRIES)-1:0]
											&& (missid == n4p || iqentry_stomp[n4p])
											;
	if (~lastq0[3])
		iqentry_stomp[lastq0] = 1'b1;
	if (~lastq1[3])
		iqentry_stomp[lastq1] = 1'b1;
end											
//    	iqentry_stomp[0] = branchmiss && iq[0].v && head0 != 3'd0 && (missid == 3'd7 || iqentry_stomp[7]),


//
// EXECUTE
//
Thor2024_alu ualu0
(
	.rst(rst),
	.clk(clk),
	.ir(alu0_instr),
	.div(alu0_div),
	.a(alu0_argA),
	.b(alu0_argB),
	.c(alu0_argC),
	.t(alu0_argT),
	.p(alu0_argP),
	.o(alu0_bus),
	.mul_done(mul0_done),
	.div_done(div0_done),
	.div_dbz()
);

Thor2024_alu ualu1
(
	.rst(rst),
	.clk(clk),
	.ir(alu1_instr),
	.div(alu1_div),
	.a(alu1_argA),
	.b(alu1_argB),
	.c(alu1_argC),
	.t(alu1_argT),
	.p(alu1_argP),
	.o(alu1_bus),
	.mul_done(mul1_done),
	.div_done(div1_done),
	.div_dbz()
);

    assign  alu0_v = alu0_dataready,
	    alu1_v = alu1_dataready;

    assign  alu0_id = alu0_sourceid,
	    alu1_id = alu1_sourceid;

    assign  fcu_v = fcu_dataready;
    assign  fcu_id = fcu_sourceid;

address_t tgtpc;

always_comb
	if (fnIsBccR(fcu_instr))
		tgtpc = fcu_argC + {{53{fcu_instr[39]}},fcu_instr[39:31],fcu_instr[12:11]};
	else if (fnIsBranch(fcu_instr))
		tgtpc = fcu_pc + {{47{fcu_instr[39]}},fcu_instr[39:25],fcu_instr[12:11]};
	else if (fnIsCall(fcu_instr)) begin
		if (fcu_instr[7:6]==2'd3)
			tgtpc = fcu_argI;
		else
			tgtpc = fcu_pc + fcu_argI;
	end
	else if (fnIsRet(fcu_instr))
		tgtpc = fcu_argC + fcu_instr[15:8];
	else
		tgtpc = 32'hFFFD0000;

always_comb
	if (fnIsBccR(fcu_instr))
		fcu_misspc = fcu_bt ? fcu_pc + 4'd5 : fcu_argC + {{53{fcu_instr[39]}},fcu_instr[39:31],fcu_instr[12:11]};
	else if (fnIsBranch(fcu_instr))
		fcu_misspc = fcu_bt ? fcu_pc + 4'd5 : fcu_pc + {{47{fcu_instr[39]}},fcu_instr[39:25],fcu_instr[12:11]};
	else if (fnIsCall(fcu_instr)) begin
		if (fcu_instr[7:6]==2'd3)
			fcu_misspc = fcu_argI;
		else
			fcu_misspc = fcu_pc + fcu_argI;
	end
	else if (fnIsRet(fcu_instr))
		fcu_misspc = fcu_argC + fcu_instr[15:8];
	else
		fcu_misspc = 32'hFFFD0000;

always_comb
	case(fcu_instr.br.cm)
	2'd0:	// integer signed branches
		case(fcu_instr.any.opcode)
		OP_BEQ:	takb = fcu_argA==fcu_argB;
		OP_BNE:	takb = fcu_argA!=fcu_argB;
		OP_BLT:	takb = $signed(fcu_argA) < $signed(fcu_argB);
		OP_BLE:	takb = $signed(fcu_argA) <= $signed(fcu_argB);
		OP_BGT:	takb = $signed(fcu_argA) > $signed(fcu_argB);
		OP_BGE:	takb = $signed(fcu_argA) >= $signed(fcu_argB);
		OP_BBS:	takb = fcu_argA[fcu_argB[5:0]];
		default:	takb = 1'b0;
		endcase	
	2'd1:	// integer usigned branches
		case(fcu_instr.any.opcode)
		OP_BEQ:	takb = fcu_argA==fcu_argB;
		OP_BNE:	takb = fcu_argA!=fcu_argB;
		OP_BLT:	takb = fcu_argA < fcu_argB;
		OP_BLE:	takb = fcu_argA <= fcu_argB;
		OP_BGT:	takb = fcu_argA > fcu_argB;
		OP_BGE:	takb = fcu_argA >= fcu_argB;
		OP_BBS:	takb = fcu_argA[fcu_argB[5:0]];
		default:	takb = 1'b0;
		endcase	
	default:	takb = 1'b0;
	endcase

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

assign  branchmiss = fcu_branchmiss,
  misspc = fcu_misspc,
  missid = fcu_sourceid;

//
// additional DRAM-enqueue logic

assign dram_avail = (dram0 == `DRAMSLOT_AVAIL || dram1 == `DRAMSLOT_AVAIL);// || dram2 == `DRAMSLOT_AVAIL);

always_comb
for (n9 = 0; n9 < QENTRIES; n9 = n9 + 1)
	iqentry_memopsvalid[n9] = (iq[n9].mem & (iq[n9].load|iq[n9].a3_v) & iq[n9].agen);

always_comb
for (n10 = 0; n10 < QENTRIES; n10 = n10 + 1)
  iqentry_memready[n10] = (iq[n10].v
  		& iqentry_memopsvalid[n10] 
  		& ~iqentry_memissue[n10] 
  		& ~iq[n10].done 
  		& ~iq[n10].out 
  		& ~iqentry_stomp[n10])
  		;

assign outstanding_stores = (dram0 && dram0_store) || (dram1 && dram1_store);// || (dram2 && dram2_store);

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

if (fnIsAtom(fetchbuf0_instr[0]))
	atom_mask <= fetchbuf0_instr[0][30:7];
if (fnIsAtom(fetchbuf1_instr[1]))
	atom_mask <= fetchbuf1_instr[1][30:7];

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
    	if (iq[tail0].v == INV) begin
				iq[tail0].v    <=   VAL;
				iq[tail0].done    <=   INV;
				iq[tail0].out    <=   INV;
				iq[tail0].res    <=   `ZERO;
				iq[tail0].op    <=   fetchbuf1_instr[0]; 
				iq[tail0].bt    <=   INV;//(fnIsBackBranch(fetchbuf1_instr[0])) | ptakb; 
				iq[tail0].agen    <=   INV;
				iq[tail0].pc    <=   fetchbuf1_pc;
				iq[tail0].imm <= fnIsImm(fetchbuf1_instr[0]);
				iq[tail0].fc <= fnIsFlowCtrl(fetchbuf1_instr[0]);
		    iq[tail0].alu <= !fnIsFlowCtrl(fetchbuf1_instr[0]);
		    iq[tail0].mul <= fnIsMuls(fetchbuf1_instr[0]);
		    iq[tail0].mulu <= fnIsMulu(fetchbuf1_instr[0]);
		    iq[tail0].div <= fnIsDivs(fetchbuf1_instr[0]);
		    iq[tail0].divu <= fnIsDivu(fetchbuf1_instr[0]);
		    iq[tail0].sync <= 1'b0;
				iq[tail0].mem    <=   fetchbuf1_mem;
				iq[tail0].load <= fnIsLoad(fetchbuf1_instr[0]);
				iq[tail0].loadz <= fnIsLoadz(fetchbuf1_instr[0]);
				iq[tail0].store <= fnIsStore(fetchbuf1_instr[0]);
				iq[tail0].jmp    <=   fetchbuf1_jmp;
				iq[tail0].rfw    <=   fetchbuf1_rfw;
				iq[tail0].tgt <= Rt1;
				iq[tail0].exc <= FLT_NONE;
				iq[tail0].takb <= 1'b0;
				iq[tail0].brtgt <= 'd0;
				iq[tail0].a0 <= dec_imm1;
				iq[tail0].a1 <= fnA1(fetchbuf1_instr[0], fetchbuf1_pc, Ra1, dec_imm1);
				iq[tail0].a1_v <= fnSource1v(fetchbuf1_instr[0]) | rf_v[ Ra1 ];
				iq[tail0].a1_s <= rf_source [ Ra1 ];
				iq[tail0].a2 <= fnA2(fetchbuf1_instr[0], fetchbuf1_pc, Rb1, dec_imm1);
				iq[tail0].a2_v <= fnSource2v(fetchbuf1_instr[0]) | rf_v[ Rb1 ];
				iq[tail0].a2_s  <= rf_source [ Rb1 ];
				iq[tail0].a3 <= fnA3(fetchbuf1_instr[0], fetchbuf1_pc, Rc1, dec_imm1);
				iq[tail0].a3_v <= fnSource3v(fetchbuf1_instr[0]) | rf_v[ Rc1 ];
				iq[tail0].a3_s  <= rf_source [ Rc1 ];
				iq[tail0].at <= rf [ Rt1 ];
				iq[tail0].at_v <= fnSourceTv(fetchbuf1_instr[0]) | rf_v[ Rt1 ];
				iq[tail0].at_s  <= rf_source [ Rt1 ];
				iq[tail0].ap <= fnAP(fetchbuf1_instr[0], Rp1);
				iq[tail0].ap_v <= fnSourcePv(fetchbuf1_instr[0]) | rf_v[ Rp1 ];
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
			end
    2'b10:
    	begin
	    	if (0 && iq[tail0].v == INV && (~^pred_mask[1:0] || pred_mask[1:0]==pred_val)) begin
					if (!fnIsBranch(fetchbuf0_instr[0]))		panic <= `PANIC_FETCHBUFBEQ;
					if (!fnIsBackBranch(fetchbuf0_instr[0]))	panic <= `PANIC_FETCHBUFBEQ;
					//
					// this should only happen when the first instruction is a BEQ-backwards and the IQ
					// happened to be full on the previous cycle (thus we deleted fetchbuf1 but did not
					// enqueue fetchbuf0) ... probably no need to check for LW -- sanity check, just in case
					//
					iq[tail0].v	<=	VAL;
					iq[tail0].done <= INV;
					iq[tail0].out	<= INV;
					iq[tail0].res	<= `ZERO;
					iq[tail0].op <= fetchbuf0_instr[0]; 			// BEQ
					iq[tail0].bt <= VAL;
					iq[tail0].agen <= INV;
					iq[tail0].pc <= fetchbuf0_pc;
					iq[tail0].imm <= fnIsImm(fetchbuf0_instr[0]);
					iq[tail0].fc <= fnIsFlowCtrl(fetchbuf0_instr[0]);
			    iq[tail0].alu <= !fnIsFlowCtrl(fetchbuf0_instr[0]);
			    iq[tail0].mul <= fnIsMuls(fetchbuf0_instr[0]);
			    iq[tail0].mulu <= fnIsMulu(fetchbuf0_instr[0]);
			    iq[tail0].div <= fnIsDivs(fetchbuf0_instr[0]);
			    iq[tail0].divu <= fnIsDivu(fetchbuf0_instr[0]);
			    iq[tail0].sync <= 1'b0;
					iq[tail0].mem <= fetchbuf0_mem;
					iq[tail0].load <= fnIsLoad(fetchbuf0_instr[0]);
					iq[tail0].loadz <= fnIsLoadz(fetchbuf0_instr[0]);
					iq[tail0].store <= fnIsStore(fetchbuf0_instr[0]);
					iq[tail0].jmp <= fetchbuf0_jmp;
					iq[tail0].rfw <= fetchbuf0_rfw;
					iq[tail0].tgt <= Rt0;
					iq[tail0].exc    <=	FLT_NONE;
					iq[tail0].takb <= 1'b0;
					iq[tail0].brtgt <= 'd0;
					iq[tail0].a0	<=	dec_imm0;
					iq[tail0].a1 <= fnA1(fetchbuf0_instr[0], fetchbuf0_pc, Ra0, dec_imm0);
					iq[tail0].a1_v <= fnSource1v(fetchbuf0_instr[0]) | rf_v[ Ra0 ];
					iq[tail0].a1_s <= rf_source [ Ra0 ];
					iq[tail0].a2 <= fnA2(fetchbuf0_instr[0], fetchbuf0_pc, Rb0, dec_imm0);
					iq[tail0].a2_v <= fnSource2v(fetchbuf0_instr[0]) | rf_v[ Rb0 ];
					iq[tail0].a2_s  <= rf_source [ Rb0 ];
					iq[tail0].a3 <= fnA3(fetchbuf0_instr[0], fetchbuf0_pc, Rc0, dec_imm0);
					iq[tail0].a3_v <= fnSource3v(fetchbuf0_instr[0]) | rf_v[ Rc0 ];
					iq[tail0].a3_s  <= rf_source [ Rc0 ];
					iq[tail0].at <= rf [ Rt0 ];
					iq[tail0].at_v <= fnSourceTv(fetchbuf0_instr[0]) | rf_v[ Rt0 ];
					iq[tail0].at_s  <= rf_source [ Rt0 ];
					iq[tail0].ap <= fnAP(fetchbuf0_instr[0], Rp0);
					iq[tail0].ap_v <= fnSourcePv(fetchbuf0_instr[0]) | rf_v[ Rp0 ];
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
		    end
	  	end

    2'b11:
    	if (iq[tail0].v == INV) begin

				//
				// if the first instruction is a backwards branch, enqueue it & stomp on all following instructions
				//
				if (0 && fnIsBackBranch(fetchbuf0_instr[0])) begin
			    iq[tail0].v    <=	VAL;
			    iq[tail0].done    <=	INV;
			    iq[tail0].out    <=	INV;
			    iq[tail0].res    <=	`ZERO;
			    iq[tail0].op    <=	fetchbuf0_instr[0]; 			// BEQ
			    iq[tail0].bt    <=	VAL;
			    iq[tail0].agen    <=	INV;
			    iq[tail0].pc    <=	fetchbuf0_pc;
					iq[tail0].imm <= fnIsImm(fetchbuf0_instr[0]);
					iq[tail0].fc <= fnIsFlowCtrl(fetchbuf0_instr[0]);
			    iq[tail0].alu <= !fnIsFlowCtrl(fetchbuf0_instr[0]);
			    iq[tail0].mul <= fnIsMuls(fetchbuf0_instr[0]);
			    iq[tail0].mulu <= fnIsMulu(fetchbuf0_instr[0]);
			    iq[tail0].div <= fnIsDivs(fetchbuf0_instr[0]);
			    iq[tail0].divu <= fnIsDivu(fetchbuf0_instr[0]);
			    iq[tail0].sync <= 1'b0;
			    iq[tail0].mem    <=	fetchbuf0_mem;
					iq[tail0].load <= fnIsLoad(fetchbuf0_instr[0]);
					iq[tail0].loadz <= fnIsLoadz(fetchbuf0_instr[0]);
					iq[tail0].store <= fnIsStore(fetchbuf0_instr[0]);
			    iq[tail0].jmp    <=	fetchbuf0_jmp;
			    iq[tail0].rfw    <=	fetchbuf0_rfw;
					iq[tail0].tgt <= Rt0;
			    iq[tail0].exc    <=	FLT_NONE;
					iq[tail0].takb <= 1'b0;
					iq[tail0].brtgt <= 'd0;
			    iq[tail0].a0 <= dec_imm0;
					iq[tail0].a1 <= fnA1(fetchbuf0_instr[0], fetchbuf0_pc, Ra0, dec_imm0);
					iq[tail0].a1_v <= fnSource1v(fetchbuf0_instr[0]) | rf_v[ Ra0 ];
					iq[tail0].a1_s <= rf_source [ Ra0 ];
					iq[tail0].a2 <= fnA2(fetchbuf0_instr[0], fetchbuf0_pc, Rb0, dec_imm0);
					iq[tail0].a2_v <= fnSource2v(fetchbuf0_instr[0]) | rf_v[ Rb0 ];
					iq[tail0].a2_s  <= rf_source [ Rb0 ];
					iq[tail0].a3 <= fnA3(fetchbuf0_instr[0], fetchbuf0_pc, Rc0, dec_imm0);
					iq[tail0].a3_v <= fnSource3v(fetchbuf0_instr[0]) | rf_v[ Rc0 ];
					iq[tail0].a3_s  <= rf_source [ Rc0 ];
					iq[tail0].at <= rf [ Rt0 ];
					iq[tail0].at_v <= fnSourceTv(fetchbuf0_instr[0]) | rf_v[ Rt0 ];
					iq[tail0].at_s  <= rf_source [ Rt0 ];
					iq[tail0].ap <= fnAP(fetchbuf0_instr[0], Rp0);
					iq[tail0].ap_v <= fnSourcePv(fetchbuf0_instr[0]) | rf_v[ Rp0 ];
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
			    iq[tail0].v    <=   VAL;
			    iq[tail0].done    <=   INV;
			    iq[tail0].out    <=   INV;
			    iq[tail0].res    <=   `ZERO;
			    iq[tail0].op    <=   fetchbuf0_instr[0]; 
			    iq[tail0].bt    <=   INV;//ptakb;
			    iq[tail0].agen    <=   INV;
			    iq[tail0].pc    <=   fetchbuf0_pc;
					iq[tail0].imm <= fnIsImm(fetchbuf0_instr[0]);
					iq[tail0].fc <= fnIsFlowCtrl(fetchbuf0_instr[0]);
			    iq[tail0].alu <= !fnIsFlowCtrl(fetchbuf0_instr[0]);
			    iq[tail0].mul <= fnIsMuls(fetchbuf0_instr[0]);
			    iq[tail0].mulu <= fnIsMulu(fetchbuf0_instr[0]);
			    iq[tail0].div <= fnIsDivs(fetchbuf0_instr[0]);
			    iq[tail0].divu <= fnIsDivu(fetchbuf0_instr[0]);
			    iq[tail0].sync <= 1'b0;
			    iq[tail0].mem    <=   fetchbuf0_mem;
					iq[tail0].load <= fnIsLoad(fetchbuf0_instr[0]);
					iq[tail0].loadz <= fnIsLoadz(fetchbuf0_instr[0]);
					iq[tail0].store <= fnIsStore(fetchbuf0_instr[0]);
			    iq[tail0].jmp    <=   fetchbuf0_jmp;
			    iq[tail0].rfw    <=   fetchbuf0_rfw;
					iq[tail0].tgt <= Rt0;
			    iq[tail0].exc    <=   FLT_NONE;
					iq[tail0].takb <= 1'b0;
					iq[tail0].brtgt <= 'd0;
			    iq[tail0].a0 <= dec_imm0;
					iq[tail0].a1 <= fnA1(fetchbuf0_instr[0], fetchbuf0_pc, Ra0, dec_imm0);
					iq[tail0].a1_v <= fnSource1v(fetchbuf0_instr[0]) | rf_v[ Ra0 ];
					iq[tail0].a1_s <= rf_source [ Ra0 ];
					iq[tail0].a2 <= fnA2(fetchbuf0_instr[0], fetchbuf0_pc, Rb0, dec_imm0);
					iq[tail0].a2_v <= fnSource2v(fetchbuf0_instr[0]) | rf_v[ Rb0 ];
					iq[tail0].a2_s <= rf_source [ Rb0 ];
					iq[tail0].a3 <= fnA3(fetchbuf0_instr[0], fetchbuf0_pc, Rc0, dec_imm0);
					iq[tail0].a3_v <= fnSource3v(fetchbuf0_instr[0]) | rf_v[ Rc0 ];
					iq[tail0].a3_s  <= rf_source [ Rc0 ];
					iq[tail0].at <= rf [ Rt0 ];
					iq[tail0].at_v <= fnSourceTv(fetchbuf0_instr[0]) | rf_v[ Rt0 ];
					iq[tail0].at_s  <= rf_source [ Rt0 ];
					iq[tail0].ap <= fnAP(fetchbuf0_instr[0], Rp0);
					iq[tail0].ap_v <= fnSourcePv(fetchbuf0_instr[0]) | rf_v[ Rp0 ];
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

			    //
			    // if there is room for a second instruction, enqueue it
			    //
			    if (iq[tail1].v == INV) begin

						iq[tail1].v    <=   VAL;
						iq[tail1].done    <=   INV;
						iq[tail1].out    <=   INV;
						iq[tail1].res    <=   `ZERO;
						iq[tail1].op    <=   fetchbuf1_instr[0]; 
						iq[tail1].bt    <=   INV;//(fnIsBackBranch(fetchbuf1_instr[0]))|ptakb; 
						iq[tail1].agen    <=   INV;
						iq[tail1].pc    <=   fetchbuf1_pc;
						iq[tail1].imm <= fnIsImm(fetchbuf1_instr[0]);
						iq[tail1].fc <= fnIsFlowCtrl(fetchbuf1_instr[0]);
				    iq[tail1].alu <= !fnIsFlowCtrl(fetchbuf1_instr[0]);
				    iq[tail1].mul <= fnIsMuls(fetchbuf1_instr[0]);
				    iq[tail1].mulu <= fnIsMulu(fetchbuf1_instr[0]);
				    iq[tail1].div <= fnIsDivs(fetchbuf1_instr[0]);
				    iq[tail1].divu <= fnIsDivu(fetchbuf1_instr[0]);
				    iq[tail1].sync <= 1'b0;
						iq[tail1].mem    <=   fetchbuf1_mem;
						iq[tail1].load <= fnIsLoad(fetchbuf1_instr[0]);
						iq[tail1].loadz <= fnIsLoadz(fetchbuf1_instr[0]);
						iq[tail1].store <= fnIsStore(fetchbuf1_instr[0]);
						iq[tail1].jmp    <=   fetchbuf1_jmp;
						iq[tail1].rfw    <=   fetchbuf1_rfw;
						iq[tail1].tgt <= Rt1;
						iq[tail1].exc <= FLT_NONE;
						iq[tail1].takb <= 1'b0;
						iq[tail1].brtgt <= 'd0;
						iq[tail1].a0 <= dec_imm1;
						iq[tail1].a1 <= fnA1(fetchbuf1_instr[0], fetchbuf1_pc, Ra1, dec_imm1);
						iq[tail1].a2 <= fnA2(fetchbuf1_instr[0], fetchbuf1_pc, Rb1, dec_imm1);
						iq[tail1].a3 <= fnA3(fetchbuf1_instr[0], fetchbuf1_pc, Rc1, dec_imm1);
						iq[tail1].at <= rf [ Rt1 ];
						iq[tail1].ap <= fnAP(fetchbuf1_instr[0], Rp1);
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
					    iq[tail1].a1_s <= { fetchbuf0_mem, tail0 };
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
						else if (Rt0 != 5'd0 && Rb1 == Rt0) begin
					    // if the previous instruction is a LW, then grab result from memq, not the iq
					    iq[tail1].a2_v <= INV;
					    iq[tail1].a2_s <= { fetchbuf0_mem, tail0 };
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
					    iq[tail1].a3_s <= { fetchbuf0_mem, tail0 };
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
					    iq[tail1].at_s <= { fetchbuf0_mem, tail0 };
						end
						// if no overlap, get info from rf_v and rf_source
						else begin
					    iq[tail1].at_v <= rf_v [ Rt1 ];
					    iq[tail1].at_s <= rf_source [ Rt1 ];
						end

						//
						// SOURCE T ... 
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
						else if (Rt0 != 5'd0 && Rp1 == Rt0) begin
					    // if the previous instruction is a LW, then grab result from memq, not the iq
					    iq[tail1].ap_v <= INV;
					    iq[tail1].ap_s <= { fetchbuf0_mem, tail0 };
						end
						// if no overlap, get info from rf_v and rf_source
						else begin
					    iq[tail1].ap_v <= rf_v [ Rp1 ];
					    iq[tail1].ap_s <= rf_source [ Rp1 ];
						end

					end	// ends the "else fetchbuf0 doesn't have a backwards branch" clause
	    	end
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
	if (alu0_v) begin
    iq[ alu0_id[2:0] ].res <= alu0_bus;
    iq[ alu0_id[2:0] ].exc <= alu0_exc;
    iq[ alu0_id[2:0] ].done <= (!iq[ alu0_id[2:0] ].load && !iq[ alu0_id[2:0] ].store);
    iq[ alu0_id[2:0] ].out <= INV;
    iq[ alu0_id[2:0] ].agen <= VAL;
	end
	if (alu1_v) begin
    iq[ alu1_id[2:0] ].res <= alu1_bus;
    iq[ alu1_id[2:0] ].exc <= alu1_exc;
    iq[ alu1_id[2:0] ].done <= (!iq[ alu1_id[2:0] ].load && !iq[ alu1_id[2:0] ].store);
    iq[ alu1_id[2:0] ].out <= INV;
    iq[ alu1_id[2:0] ].agen <= VAL;
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
	if (dram_v0 && iq[ dram_id0[2:0] ].v && iq[ dram_id0[2:0] ].mem ) begin	// if data for stomped instruction, ignore
    iq[ dram_id0[2:0] ].res <= dram_bus0;
    iq[ dram_id0[2:0] ].exc <= dram_exc0;
    iq[ dram_id0[2:0] ].done <= VAL;
	end
	if (dram_v1 && iq[ dram_id1[2:0] ].v && iq[ dram_id1[2:0] ].mem ) begin	// if data for stomped instruction, ignore
    iq[ dram_id1[2:0] ].res <= dram_bus1;
    iq[ dram_id1[2:0] ].exc <= dram_exc1;
    iq[ dram_id1[2:0] ].done <= VAL;
	end

	//
	// set the IQ entry == DONE as soon as the SW is let loose to the memory system
	//
	if (dram0 == 2'd1 && dram0_store) begin
    if ((alu0_v && dram0_id[2:0] == alu0_id[2:0]) || (alu1_v && dram0_id[2:0] == alu1_id[2:0]))	panic <= `PANIC_MEMORYRACE;
    iq[ dram0_id[2:0] ].done <= VAL;
    iq[ dram0_id[2:0] ].out <= INV;
	end
	if (dram1 == 2'd1 && dram1_store) begin
    if ((alu0_v && dram1_id[2:0] == alu0_id[2:0]) || (alu1_v && dram1_id[2:0] == alu1_id[2:0]))	panic <= `PANIC_MEMORYRACE;
    iq[ dram1_id[2:0] ].done <= VAL;
    iq[ dram1_id[2:0] ].out <= INV;
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
		if (iq[nn].a1_v == INV && iq[nn].a1_s == alu0_id && iq[nn].v == VAL && alu0_v == VAL) begin
	    iq[nn].a1 <= alu0_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == alu0_id && iq[nn].v == VAL && alu0_v == VAL) begin
	    iq[nn].a2 <= alu0_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == alu0_id && iq[nn].v == VAL && alu0_v == VAL) begin
	    iq[nn].a3 <= alu0_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == alu0_id && iq[nn].v == VAL && alu0_v == VAL) begin
	    iq[nn].at <= alu0_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == alu0_id && iq[nn].v == VAL && alu0_v == VAL) begin
	    iq[nn].ap <= alu0_bus;
	    iq[nn].ap_v <= VAL;
		end

		if (iq[nn].a1_v == INV && iq[nn].a1_s == alu1_id && iq[nn].v == VAL && alu1_v == VAL) begin
	    iq[nn].a1 <= alu1_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == alu1_id && iq[nn].v == VAL && alu1_v == VAL) begin
	    iq[nn].a2 <= alu1_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == alu1_id && iq[nn].v == VAL && alu1_v == VAL) begin
	    iq[nn].a3 <= alu1_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == alu1_id && iq[nn].v == VAL && alu1_v == VAL) begin
	    iq[nn].at <= alu1_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == alu1_id && iq[nn].v == VAL && alu1_v == VAL) begin
	    iq[nn].ap <= alu1_bus;
	    iq[nn].ap_v <= VAL;
		end

		if (iq[nn].a1_v == INV && iq[nn].a1_s == fcu_id && iq[nn].v == VAL && fcu_v == VAL) begin
	    iq[nn].a1 <= fcu_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == fcu_id && iq[nn].v == VAL && fcu_v == VAL) begin
	    iq[nn].a2 <= fcu_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == fcu_id && iq[nn].v == VAL && fcu_v == VAL) begin
	    iq[nn].a3 <= fcu_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == fcu_id && iq[nn].v == VAL && fcu_v == VAL) begin
	    iq[nn].at <= fcu_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == fcu_id && iq[nn].v == VAL && fcu_v == VAL) begin
	    iq[nn].ap <= fcu_bus;
	    iq[nn].ap_v <= VAL;
		end
		
		if (iq[nn].a1_v == INV && iq[nn].a1_s == dram_id0 && iq[nn].v == VAL && dram_v0 == VAL) begin
	    iq[nn].a1 <= dram_bus0;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == dram_id0 && iq[nn].v == VAL && dram_v0 == VAL) begin
	    iq[nn].a2 <= dram_bus0;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == dram_id0 && iq[nn].v == VAL && dram_v0 == VAL) begin
	    iq[nn].a3 <= dram_bus0;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == dram_id0 && iq[nn].v == VAL && dram_v0 == VAL) begin
	    iq[nn].at <= dram_bus0;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == dram_id0 && iq[nn].v == VAL && dram_v0 == VAL) begin
	    iq[nn].ap <= dram_bus0;
	    iq[nn].ap_v <= VAL;
		end
		
		if (iq[nn].a1_v == INV && iq[nn].a1_s == dram_id1 && iq[nn].v == VAL && dram_v1 == VAL) begin
	    iq[nn].a1 <= dram_bus1;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == dram_id1 && iq[nn].v == VAL && dram_v1 == VAL) begin
	    iq[nn].a2 <= dram_bus1;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == dram_id1 && iq[nn].v == VAL && dram_v1 == VAL) begin
	    iq[nn].a3 <= dram_bus1;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == dram_id1 && iq[nn].v == VAL && dram_v1 == VAL) begin
	    iq[nn].at <= dram_bus1;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == dram_id1 && iq[nn].v == VAL && dram_v1 == VAL) begin
	    iq[nn].ap <= dram_bus1;
	    iq[nn].ap_v <= VAL;
		end
		
		if (iq[nn].a1_v == INV && iq[nn].a1_s == commit0_id && iq[nn].v == VAL && commit0_v == VAL) begin
	    iq[nn].a1 <= commit0_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == commit0_id && iq[nn].v == VAL && commit0_v == VAL) begin
	    iq[nn].a2 <= commit0_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == commit0_id && iq[nn].v == VAL && commit0_v == VAL) begin
	    iq[nn].a3 <= commit0_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == commit0_id && iq[nn].v == VAL && commit0_v == VAL) begin
	    iq[nn].at <= commit0_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == commit0_id && iq[nn].v == VAL && commit0_v == VAL) begin
	    iq[nn].ap <= commit0_bus;
	    iq[nn].ap_v <= VAL;
		end
		
		if (iq[nn].a1_v == INV && iq[nn].a1_s == commit1_id && iq[nn].v == VAL && commit1_v == VAL) begin
	    iq[nn].a1 <= commit1_bus;
	    iq[nn].a1_v <= VAL;
		end
		if (iq[nn].a2_v == INV && iq[nn].a2_s == commit1_id && iq[nn].v == VAL && commit1_v == VAL) begin
	    iq[nn].a2 <= commit1_bus;
	    iq[nn].a2_v <= VAL;
		end
		if (iq[nn].a3_v == INV && iq[nn].a3_s == commit1_id && iq[nn].v == VAL && commit1_v == VAL) begin
	    iq[nn].a3 <= commit1_bus;
	    iq[nn].a3_v <= VAL;
		end
		if (iq[nn].at_v == INV && iq[nn].at_s == commit1_id && iq[nn].v == VAL && commit1_v == VAL) begin
	    iq[nn].at <= commit1_bus;
	    iq[nn].at_v <= VAL;
		end
		if (iq[nn].ap_v == INV && iq[nn].ap_s == commit1_id && iq[nn].v == VAL && commit1_v == VAL) begin
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
		&& ((iqentry_issue[0] && iqentry_islot[0] == 2'd0 && !iqentry_stomp[0] && (iq[0].div|iq[0].divu ? div0_done : 1'b1) && (iq[0].mul|iq[0].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue[1] && iqentry_islot[1] == 2'd0 && !iqentry_stomp[1] && (iq[1].div|iq[1].divu ? div0_done : 1'b1) && (iq[1].mul|iq[1].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue[2] && iqentry_islot[2] == 2'd0 && !iqentry_stomp[2] && (iq[2].div|iq[2].divu ? div0_done : 1'b1) && (iq[2].mul|iq[2].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue[3] && iqentry_islot[3] == 2'd0 && !iqentry_stomp[3] && (iq[3].div|iq[3].divu ? div0_done : 1'b1) && (iq[3].mul|iq[3].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue[4] && iqentry_islot[4] == 2'd0 && !iqentry_stomp[4] && (iq[4].div|iq[4].divu ? div0_done : 1'b1) && (iq[4].mul|iq[4].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue[5] && iqentry_islot[5] == 2'd0 && !iqentry_stomp[5] && (iq[5].div|iq[5].divu ? div0_done : 1'b1) && (iq[5].mul|iq[5].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue[6] && iqentry_islot[6] == 2'd0 && !iqentry_stomp[6] && (iq[6].div|iq[6].divu ? div0_done : 1'b1) && (iq[6].mul|iq[6].mulu ? mul0_done : 1'b1))
		 || (iqentry_issue[7] && iqentry_islot[7] == 2'd0 && !iqentry_stomp[7] && (iq[7].div|iq[7].divu ? div0_done : 1'b1) && (iq[7].mul|iq[7].mulu ? mul0_done : 1'b1)));

alu1_dataready <= alu1_available 
		&& ((iqentry_issue[0] && iqentry_islot[0] == 2'd1 && !iqentry_stomp[0] && (iq[0].div|iq[0].divu ? div1_done : 1'b1) && (iq[0].mul|iq[0].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue[1] && iqentry_islot[1] == 2'd1 && !iqentry_stomp[1] && (iq[1].div|iq[1].divu ? div1_done : 1'b1) && (iq[1].mul|iq[1].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue[2] && iqentry_islot[2] == 2'd1 && !iqentry_stomp[2] && (iq[2].div|iq[2].divu ? div1_done : 1'b1) && (iq[2].mul|iq[2].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue[3] && iqentry_islot[3] == 2'd1 && !iqentry_stomp[3] && (iq[3].div|iq[3].divu ? div1_done : 1'b1) && (iq[3].mul|iq[3].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue[4] && iqentry_islot[4] == 2'd1 && !iqentry_stomp[4] && (iq[4].div|iq[4].divu ? div1_done : 1'b1) && (iq[4].mul|iq[4].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue[5] && iqentry_islot[5] == 2'd1 && !iqentry_stomp[5] && (iq[5].div|iq[5].divu ? div1_done : 1'b1) && (iq[5].mul|iq[5].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue[6] && iqentry_islot[6] == 2'd1 && !iqentry_stomp[6] && (iq[6].div|iq[6].divu ? div1_done : 1'b1) && (iq[6].mul|iq[6].mulu ? mul1_done : 1'b1))
		 || (iqentry_issue[7] && iqentry_islot[7] == 2'd1 && !iqentry_stomp[7] && (iq[7].div|iq[7].divu ? div1_done : 1'b1) && (iq[7].mul|iq[7].mulu ? mul1_done : 1'b1)));

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
		if (iq[n1].v && iqentry_stomp[n1]) begin
	    iq[n1].v <= INV;
	    if (dram0_id[2:0] == n1[2:0])	dram0 <= `DRAMSLOT_AVAIL;
	    if (dram1_id[2:0] == n1[2:0])	dram1 <= `DRAMSLOT_AVAIL;
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
								    : 32'hDEADBEEF;
						alu0_argB	<= 
								       iq[n1].a2_v ? iq[n1].a2
										: (iq[n1].a2_s == alu0_id) ? alu0_bus
										: (iq[n1].a2_s == alu1_id) ? alu1_bus
										: 32'hDEADBEEF;
						alu0_argC	<= 
								      (iq[n1].a3_v ? iq[n1].a3
										: (iq[n1].a3_s == alu0_id) ? alu0_bus
										: (iq[n1].a3_s == alu1_id) ? alu1_bus
										: 32'hDEADBEEF);
						alu0_argT	<= 
								      (iq[n1].at_v ? iq[n1].at
										: (iq[n1].at_s == alu0_id) ? alu0_bus
										: (iq[n1].at_s == alu1_id) ? alu1_bus
										: 32'hDEADBEEF);
						alu0_argP	<= 
								      (iq[n1].ap_v ? iq[n1].ap
										: (iq[n1].ap_s == alu0_id) ? alu0_bus
										: (iq[n1].ap_s == alu1_id) ? alu1_bus
										: 32'hDEADBEEF);
						alu0_argI	<= iq[n1].a0;
			    end
				2'd1:
					if (alu1_available) begin
						alu1_sourceid	<= n1[3:0];
						alu1_instr <= iq[n1].op;
						alu1_div <= iq[n1].div;
						alu1_pc <= iq[n1].pc;
						alu1_argA	<= 
										  iq[n1].a1_v ? iq[n1].a1
								    : (iq[n1].a1_s == alu0_id) ? alu0_bus
								    : (iq[n1].a1_s == alu1_id) ? alu1_bus
								    : 32'hDEADBEEF;
						alu1_argB	<= 
								      (iq[n1].a2_v ? iq[n1].a2
										: (iq[n1].a2_s == alu0_id) ? alu0_bus
										: (iq[n1].a2_s == alu1_id) ? alu1_bus
										: 32'hDEADBEEF);
						alu1_argC	<= 
								      (iq[n1].a3_v ? iq[n1].a3
										: (iq[n1].a3_s == alu0_id) ? alu0_bus
										: (iq[n1].a3_s == alu1_id) ? alu1_bus
										: 32'hDEADBEEF);
						alu1_argT	<= 
								      (iq[n1].at_v ? iq[n1].at
										: (iq[n1].at_s == alu0_id) ? alu0_bus
										: (iq[n1].at_s == alu1_id) ? alu1_bus
										: 32'hDEADBEEF);
						alu1_argP	<= 
								      (iq[n1].ap_v ? iq[n1].ap
										: (iq[n1].ap_s == alu0_id) ? alu0_bus
										: (iq[n1].ap_s == alu1_id) ? alu1_bus
										: 32'hDEADBEEF);
						alu1_argI	<= iq[n1].a0;
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
		dram0 <= `DRAMSLOT_AVAIL;
	else
		case(dram0)
		`DRAMSLOT_AVAIL:	;
		`DRAMREQ_READY:
			if (dram0_ack)
				dram0 <= dram0 + 2'd1;
		default:
			if (iq[dram0_id[2:0]].v)
				dram0 <= dram0 + 2'd1;
			else
				dram0 <= `DRAMSLOT_AVAIL;
		endcase

	if (rst)
		dram1 <= `DRAMSLOT_AVAIL;
	else
		case(dram1)
		`DRAMSLOT_AVAIL:	;
		`DRAMREQ_READY:
			if (dram1_ack)
				dram1 <= dram1 + 2'd1;
		default:
			if (iq[dram1_id[2:0]].v)
				dram1 <= dram1 + 2'd1;
			else
				dram1 <= `DRAMSLOT_AVAIL;
		endcase
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
	casex ({dram0, dram1})//, dram2})
	    // not particularly portable ...
	    4'b1111,
	    4'b11xx,
	    4'bxx11:	;//panic <= `PANIC_IDENTICALDRAMS;

	    default: begin
		//
		// grab requests that have finished and put them on the dram_bus
		if (dram0 == `DRAMREQ_READY && dram0_ack) begin
	    dram_v0 <= dram0_load;
	    dram_id0 <= dram0_id;
	    dram_tgt0 <= dram0_tgt;
	    dram_exc0 <= dram0_exc;
	    if (dram0_load)
	    	dram_bus0 <= fnDati(dram0_op,dram0_addr,cpu_resp_o[0] >> {dram0_addr[5:0],3'd0});
	    else if (dram0_store)
	    	;
	    else			panic <= `PANIC_INVALIDMEMOP;
	    if (dram0_store)
	    	$display("m[%h] <- %h", dram0_addr, dram0_data);
		end
		else
			dram_v0 <= INV;
		if (dram1 == `DRAMREQ_READY && dram1_ack) begin
	    dram_v1 <= (dram1_load);
	    dram_id1 <= dram1_id;
	    dram_tgt1 <= dram1_tgt;
	    dram_exc1 <= dram1_exc;
	    if (dram1_load) 	
	    	dram_bus1 <= fnDati(dram1_op,dram1_addr,cpu_resp_o[1] >> {dram1_addr[5:0],3'd0});	
	    else if (dram1_store)
	    	;
	    else			panic <= `PANIC_INVALIDMEMOP;
	    if (dram1_store)
	     	$display("m[%h] <- %h", dram1_addr, dram1_data);
		end
		else
			dram_v1 <= INV;
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
	endcase

	//
	// determine if the instructions ready to issue can, in fact, issue.
	// "ready" means that the instruction has valid operands but has not gone yet
	iqentry_memissue[ head0 ] <=	iqentry_memready[ head0 ];		// first in line ... go as soon as ready

	iqentry_memissue[ head1 ] <=	~iqentry_stomp[head1] && iqentry_memready[ head1 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head1].a1 != iq[head0].a1))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head1].load || (!fnIsFlowCtrl(iq[head0].op)));

	iqentry_memissue[ head2 ] <=	~iqentry_stomp[head2] && iqentry_memready[ head2 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head2].a1 != iq[head0].a1))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head2].a1 != iq[head1].a1))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head2].load ||
					    ( !fnIsFlowCtrl(iq[head0].op) && !fnIsFlowCtrl(iq[head1].op)));

	iqentry_memissue[ head3 ] <=	~iqentry_stomp[head3] && iqentry_memready[ head3 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head3].a1 != iq[head0].a1))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head3].a1 != iq[head1].a1))
					&& (!iq[head2].mem || (iq[head2].agen & iq[head2].out) 
						|| (iq[head2].a1_v && iq[head3].a1 != iq[head2].a1))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head3].load ||
					    ( !fnIsFlowCtrl(iq[head0].op) &&
					      !fnIsFlowCtrl(iq[head1].op) &&
					      !fnIsFlowCtrl(iq[head2].op)));

	iqentry_memissue[ head4 ] <=	~iqentry_stomp[head4] && iqentry_memready[ head4 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head4].a1 != iq[head0].a1))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head4].a1 != iq[head1].a1))
					&& (!iq[head2].mem || (iq[head2].agen & iq[head2].out) 
						|| (iq[head2].a1_v && iq[head4].a1 != iq[head2].a1))
					&& (!iq[head3].mem || (iq[head3].agen & iq[head3].out) 
						|| (iq[head3].a1_v && iq[head4].a1 != iq[head3].a1))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head4].load ||
					    ( !fnIsFlowCtrl(iq[head0].op) &&
					    	!fnIsFlowCtrl(iq[head1].op) &&
					    	!fnIsFlowCtrl(iq[head2].op) &&
					    	!fnIsFlowCtrl(iq[head3].op)));

	iqentry_memissue[ head5 ] <=	~iqentry_stomp[head5] && iqentry_memready[ head5 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					&& ~iqentry_memready[head4] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iq[head0].mem || (iq[head0].agen & iq[head0].out) 
						|| (iq[head0].a1_v && iq[head5].a1 != iq[head0].a1))
					&& (!iq[head1].mem || (iq[head1].agen & iq[head1].out) 
						|| (iq[head1].a1_v && iq[head5].a1 != iq[head1].a1))
					&& (!iq[head2].mem || (iq[head2].agen & iq[head2].out) 
						|| (iq[head2].a1_v && iq[head5].a1 != iq[head2].a1))
					&& (!iq[head3].mem || (iq[head3].agen & iq[head3].out) 
						|| (iq[head3].a1_v && iq[head5].a1 != iq[head3].a1))
					&& (!iq[head4].mem || (iq[head4].agen & iq[head4].out) 
						|| (iq[head4].a1_v && iq[head5].a1 != iq[head4].a1))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iq[head5].load ||
					    ( !fnIsFlowCtrl(iq[head0].op) &&
					    	!fnIsFlowCtrl(iq[head1].op) &&
					    	!fnIsFlowCtrl(iq[head2].op) &&
					    	!fnIsFlowCtrl(iq[head3].op) &&
					    	!fnIsFlowCtrl(iq[head4].op)));

	iqentry_memissue [head6] <= 1'b0;
	iqentry_memissue [head7] <= 1'b0;

/*
	iqentry_memissue[ head6 ] <=	~iqentry_stomp[head6] && iqentry_memready[ head6 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					&& ~iqentry_memready[head4] 
					&& ~iqentry_memready[head5] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head6] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head6] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head6] != iqentry_a1[head2]))
					&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
						|| (iqentry_a1_v[head3] && iqentry_a1[head6] != iqentry_a1[head3]))
					&& (!iqentry_mem[head4] || (iqentry_agen[head4] & iqentry_out[head4]) 
						|| (iqentry_a1_v[head4] && iqentry_a1[head6] != iqentry_a1[head4]))
					&& (!iqentry_mem[head5] || (iqentry_agen[head5] & iqentry_out[head5]) 
						|| (iqentry_a1_v[head5] && iqentry_a1[head6] != iqentry_a1[head5]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iqentry_op[head6] == `LW ||
					    (   iqentry_op[head0] != `BEQ && iqentry_op[head0] != `JALR
					     && iqentry_op[head1] != `BEQ && iqentry_op[head1] != `JALR
					     && iqentry_op[head2] != `BEQ && iqentry_op[head2] != `JALR
					     && iqentry_op[head3] != `BEQ && iqentry_op[head3] != `JALR
					     && iqentry_op[head4] != `BEQ && iqentry_op[head4] != `JALR
					     && iqentry_op[head5] != `BEQ && iqentry_op[head5] != `JALR));

	iqentry_memissue[ head7 ] <=	~iqentry_stomp[head7] && iqentry_memready[ head7 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					&& ~iqentry_memready[head4] 
					&& ~iqentry_memready[head5] 
					&& ~iqentry_memready[head6] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head7] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head7] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head7] != iqentry_a1[head2]))
					&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
						|| (iqentry_a1_v[head3] && iqentry_a1[head7] != iqentry_a1[head3]))
					&& (!iqentry_mem[head4] || (iqentry_agen[head4] & iqentry_out[head4]) 
						|| (iqentry_a1_v[head4] && iqentry_a1[head7] != iqentry_a1[head4]))
					&& (!iqentry_mem[head5] || (iqentry_agen[head5] & iqentry_out[head5]) 
						|| (iqentry_a1_v[head5] && iqentry_a1[head7] != iqentry_a1[head5]))
					&& (!iqentry_mem[head6] || (iqentry_agen[head6] & iqentry_out[head6]) 
						|| (iqentry_a1_v[head6] && iqentry_a1[head7] != iqentry_a1[head6]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iqentry_op[head7] == `LW ||
					    (   iqentry_op[head0] != `BEQ && iqentry_op[head0] != `JALR
					     && iqentry_op[head1] != `BEQ && iqentry_op[head1] != `JALR
					     && iqentry_op[head2] != `BEQ && iqentry_op[head2] != `JALR
					     && iqentry_op[head3] != `BEQ && iqentry_op[head3] != `JALR
					     && iqentry_op[head4] != `BEQ && iqentry_op[head4] != `JALR
					     && iqentry_op[head5] != `BEQ && iqentry_op[head5] != `JALR
					     && iqentry_op[head6] != `BEQ && iqentry_op[head6] != `JALR));
*/
	//
	// take requests that are ready and put them into DRAM slots

	if (dram0 == `DRAMSLOT_AVAIL)	dram0_exc <= FLT_NONE;
	if (dram1 == `DRAMSLOT_AVAIL)	dram1_exc <= FLT_NONE;
//	if (dram2 == `DRAMSLOT_AVAIL)	dram2_exc <= FLT_NONE;

	for (n3 = 0; n3 < QENTRIES; n3 = n3 + 1) begin
		if (~iqentry_stomp[n3] && iqentry_memissue[n3] && iq[n3].agen && ~iq[n3].out) begin
	    if (dram0 == `DRAMSLOT_AVAIL) begin
				dram0 		<= 2'd1;
				dram0_id 	<= { 1'b1, n3[2:0] };
				dram0_op 	<= iq[n3].op;
				dram0_load <= iq[n3].load;
				dram0_loadz <= iq[n3].loadz;
				dram0_store <= iq[n3].store;
				dram0_tgt 	<= iq[n3].tgt;
				dram0_data	<= {448'h0,iq[n3].a3} << {iq[n3].a1[5:0],3'b0};
				dram0_addr	<= iq[n3].a1;
				dram0_memsz <= fnMemsz(iq[n3].op);
				dram0_sel <= {48'h0,fnSel(iq[n3].op)} << iq[n3].a1[5:0];
				dram0_tid[2:0] <= dram0_tid[2:0] + 2'd1;
				dram0_tid[7:3] <= {4'h1,1'b0};
				iq[n3].out	<= VAL;
	    end
	    else if (dram1 == `DRAMSLOT_AVAIL) begin
				dram1 		<= 2'd1;
				dram1_id 	<= { 1'b1, n3[2:0] };
				dram1_op 	<= iq[n3].op;
				dram1_load <= iq[n3].load;
				dram1_loadz <= iq[n3].loadz;
				dram1_store <= iq[n3].store;
				dram1_tgt 	<= iq[n3].tgt;
				dram1_data	<= {448'h0,iq[n3].a3} << {iq[n3].a1[5:0],3'b0};
				dram1_addr	<= iq[n3].a1;
				dram1_memsz <= fnMemsz(iq[n3].op);
				dram1_sel <= {48'h0,fnSel(iq[n3].op)} << iq[n3].a1[5:0];
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
// look at head0 and head1 and let 'em write to the register file if they are ready
//
	if (~|panic)
	case ({ iq[head0].v,
		iq[head0].done,
		iq[head1].v,
		iq[head1].done })

	    // 4'b00_00	- neither valid; skip both
	    // 4'b00_01	- neither valid; skip both
	    // 4'b00_10	- skip head0, wait on head1
	    // 4'b00_11	- skip head0, commit head1
	    // 4'b01_00	- neither valid; skip both
	    // 4'b01_01	- neither valid; skip both
	    // 4'b01_10	- skip head0, wait on head1
	    // 4'b01_11	- skip head0, commit head1
	    // 4'b10_00	- wait on head0
	    // 4'b10_01	- wait on head0
	    // 4'b10_10	- wait on head0
	    // 4'b10_11	- wait on head0
	    // 4'b11_00	- commit head0, skip head1
	    // 4'b11_01	- commit head0, skip head1
	    // 4'b11_10	- commit head0, wait on head1
	    // 4'b11_11	- commit head0, commit head1

	    //
	    // retire 0
	    4'b10_00,
	    4'b10_01,
	    4'b10_10,
	    4'b10_11: ;

	    //
	    // retire 1
	    4'b00_10,
	    4'b01_10,
	    4'b11_10: begin
		if (iq[head0].v || head0 != tail0) begin
		    iq[head0].v <= INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		    head0 <= head0 + 1;
		    head1 <= head1 + 1;
		    head2 <= head2 + 1;
		    head3 <= head3 + 1;
		    head4 <= head4 + 1;
		    head5 <= head5 + 1;
		    head6 <= head6 + 1;
		    head7 <= head7 + 1;
		    if (iq[head0].v && iq[head0].exc)	panic <= `PANIC_HALTINSTRUCTION;
		    I <= I + 1;
		end
	    end

	    //
	    // retire 2
	    default: begin
		if ((iq[head0].v && iq[head1].v) || (head0 != tail0 && head1 != tail0)) begin
		    iq[head0].v <= INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		    iq[head1].v <= INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		    head0 <= head0 + 2;
		    head1 <= head1 + 2;
		    head2 <= head2 + 2;
		    head3 <= head3 + 2;
		    head4 <= head4 + 2;
		    head5 <= head5 + 2;
		    head6 <= head6 + 2;
		    head7 <= head7 + 2;
		    if (iq[head0].v && iq[head0].exc)	panic <= `PANIC_HALTINSTRUCTION;
		    if (iq[head1].v && iq[head1].exc)	panic <= `PANIC_HALTINSTRUCTION;
		    I <= I + 2;
		end
		else if (iq[head0].v || head0 != tail0) begin
		    iq[head0].v <= INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		    head0 <= head0 + 1;
		    head1 <= head1 + 1;
		    head2 <= head2 + 1;
		    head3 <= head3 + 1;
		    head4 <= head4 + 1;
		    head5 <= head5 + 1;
		    head6 <= head6 + 1;
		    head7 <= head7 + 1;
		    if (iq[head0].v && iq[head0].exc)	panic <= `PANIC_HALTINSTRUCTION;
		    I <= I + 1;
		end
	    end
	endcase

    end

//
// additional COMMIT logic
//

assign commit0_v = ({iq[head0].v, iq[head0].done} == 2'b11 && ~|panic);
assign commit1_v = (   {iq[head0].v, iq[head0].done} != 2'b10 
	&& {iq[head1].v, iq[head1].done} == 2'b11 && ~|panic);

assign commit0_id = {iq[head0].mem, head0};	// if a memory op, it has a DRAM-bus id
assign commit1_id = {iq[head1].mem, head1};	// if a memory op, it has a DRAM-bus id

assign commit0_tgt = iq[head0].tgt;
assign commit1_tgt = iq[head1].tgt;

assign commit0_bus = iq[head0].res;
assign commit1_bus = iq[head1].res;

assign commit_pc0 = iq[head0].pc;
assign commit_pc1 = iq[head1].pc;
assign commit_brtgt0 = iq[head0].brtgt;
assign commit_brtgt1 = iq[head1].brtgt;
assign commit_takb0 =iq[head0].takb;
assign commit_takb1 =iq[head1].takb;

assign int_commit = (commit0_v && fnIsIrq(iq[head0].op)) ||
                    (commit0_v && commit1_v && fnIsIrq(iq[head1].op));


always_ff @(posedge clk) begin: clock_n_debug
	reg [7:0] i;
	integer j;

	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("%h #", pc);

	for (i=0; i< AREGS; i=i+4)
	    $display("%d: %h %d %o  %d: %h %d %o  %d: %h %d %o  %d: %h %d %o #",
	    	i, rf[i], rf_v[i], rf_source[i],
	    	i+1, rf[i+1], rf_v[i+1], rf_source[i+1],
	    	i+2, rf[i+2], rf_v[i+2], rf_source[i+2],
	    	i+3, rf[i+3], rf_v[i+3], rf_source[i+3]
	    );

	$display("%c %h #", branchback?"b":" ", backpc);
	$display("%c%c A: %d %h,%h %h #",
	    45, fetchbuf?45:62, uif1.fetchbufA_v, uif1.fetchbufA_instr[1], uif1.fetchbufA_instr[0], uif1.fetchbufA_pc);
	$display("%c%c B: %d %h,%h %h #",
	    45, fetchbuf?45:62, uif1.fetchbufB_v, uif1.fetchbufB_instr[1], uif1.fetchbufB_instr[0], uif1.fetchbufB_pc);
	$display("%c%c C: %d %h,%h %h #",
	    45, fetchbuf?62:45, uif1.fetchbufC_v, uif1.fetchbufC_instr[1], uif1.fetchbufC_instr[0], uif1.fetchbufC_pc);
	$display("%c%c D: %d %h,%h %h #",
	    45, fetchbuf?62:45, uif1.fetchbufD_v, uif1.fetchbufD_instr[1], uif1.fetchbufD_instr[0], uif1.fetchbufD_pc);

	for (i=0; i<8; i=i+1) 
	    $display("%c%c %d: %c%c%c%c %d %c%c %d %c %c%d 0%d %o %h %h %h %d %o %h %d %o %h #",
		(i[2:0]==head0)?72:46, (i[2:0]==tail0)?84:46, i,
		iq[i].v?"v":"-", iq[i].done?"d":"-", iq[i].out?"o":"-", iq[i].bt?"t":"-", iqentry_memissue[i], iq[i].agen?"a":"-", iqentry_issue[i]?"i":"-",
		((i==0) ? iqentry_islot[0] : (i==1) ? iqentry_islot[1] : (i==2) ? iqentry_islot[2] : (i==3) ? iqentry_islot[3] :
		 (i==4) ? iqentry_islot[4] : (i==5) ? iqentry_islot[5] : (i==6) ? iqentry_islot[6] : iqentry_islot[7]), iqentry_stomp[i]?"s":"-",
		(fnIsFlowCtrl(iq[i].op) ? "b" : (iq[i].load || iq[i].store) ? "m" : "a"), 
		iq[i].op.any.opcode, iq[i].tgt, iq[i].exc, iq[i].res, iq[i].a0, iq[i].a1, iq[i].a1_v,
		iq[i].a1_s, iq[i].a2, iq[i].a2_v, iq[i].a2_s, iq[i].pc);

	$display("%d %h %h %c%d %o #",
	    dram0, dram0_addr, dram0_data, (fnIsFlowCtrl(dram0_op) ? 98 : (dram0_load || dram0_store) ? 109 : 97), 
	    dram0_op, dram0_id);
	$display("%d %h %h %c%d %o #",
	    dram1, dram1_addr, dram1_data, (fnIsFlowCtrl(dram1_op) ? 98 : (dram1_load || dram1_store) ? 109 : 97), 
	    dram1_op, dram1_id);
//	$display("%d %h %h %c%d %o #",
//	    dram2, dram2_addr, dram2_data, (fnIsFlowCtrl(dram2_op) ? 98 : (dram2_load || dram2_store) ? 109 : 97), 
//	    dram2_op, dram2_id);
	$display("%d %h %o %h #", dram_v0, dram_bus0, dram_id0, dram_exc0);
	$display("%d %h %o %h #", dram_v1, dram_bus1, dram_id1, dram_exc1);

	$display("%d %h %h %h %c%d %o %h #",
		alu0_dataready, alu0_argI, alu0_argA, alu0_argB, 
		 ((fnIsFlowCtrl(alu0_instr)) ? 98 : (fnIsLoad(alu0_instr) || fnIsStore(alu0_instr)) ? 109 : 97),
		alu0_instr, alu0_sourceid, alu0_pc);
	$display("%d %h %o 0 #", alu0_v, alu0_bus, alu0_id);
	$display("%o #", alu0_sourceid); 

	$display("%d %h %h %h %c%d %o %h #",
		alu1_dataready, alu1_argI, alu1_argA, alu1_argB, 
		 ((fnIsFlowCtrl(alu1_instr)) ? 98 : (fnIsLoad(alu1_instr) || fnIsStore(alu1_instr)) ? 109 : 97),
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
		(i[2:0]==head0)?72:32, (i[2:0]==tail0)?84:32, i,
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
	    $display("instructions committed: %d", I);
	    $display("total execution cycles: %d", $time / 10);
	    $display("");
	end
	if (|panic && ~outstanding_stores) begin
	    $finish;
	end

    end

task tReset;
begin
	ip_asid <= 'd0;
	atom_mask <= 'd0;
	postfix_mask <= 'd0;
	pred_mask <= 28'hFFFFFFF;
	pred_val <= 1'b1;
	dram0 <= `DRAMSLOT_AVAIL;
	dram0_addr <= 'd0;
	dram0_data <= 'd0;
	dram0_exc <= FLT_NONE;
	dram0_id <= 'd0;
	dram0_load <= 'd0;
	dram0_store <= 'd0;
	dram0_op <= OP_NOP;
	dram0_tgt <= 'd0;
	dram0_tid <= 'd0;
	dram1 <= 'd0;
	dram1_tid <= 8'h08;
	dram_v0 <= 'd0;
	dram_v1 <= 'd0;
	head0 <= 'd0;
	head1 <= 1;
	head2 <= 2;
	head3 <= 3;
	head4 <= 4;
	head5 <= 5;
	head6 <= 6;
	head7 <= 7;
	panic <= `PANIC_NONE;
	alu0_available <= 1;
	alu0_dataready <= 0;
	alu1_available <= 1;
	alu1_dataready <= 0;
	fcu_available <= 1;
	fcu_dataready <= 0;
	fcu_pc <= 'd0;
	fcu_sourceid <= 'd0;
	fcu_instr <= OP_NOP;
	fcu_exc <= FLT_NONE;
	fcu_bt <= 'd0;
	fcu_argA <= 'd0;
	fcu_argB <= 'd0;
	fcu_argC <= 'd0;
	fcu_argT <= 'd0;
	fcu_argP <= 'd0;
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
	I <= 0;
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
