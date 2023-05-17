// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024.v
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//
// Approx. 100,000 LUTs. 160,000 LC's.
// ============================================================================
//
import wishbone_pkg::*;
import Thor2024Pkg::*;

//`define SUPPORT_SMT		1'b1
//`define SUPPORT_DBG		1'b1
`define FULL_ISSUE_LOGIC	1'b1
`define QBITS		2:0
`define QENTRIES	8

module Thor2024(hartid, rst, clk, clk4x, tm_clk_i, irq_i, vec_i, 
		iwbm_req, iwbm_resp, dwbm_req, dwbm_resp, snoop_adr, snoop_v, snoop_cid,
    ol_o, pcr_o, pcr2_o, signal_i);
parameter WID=32;
input [WID-1:0] hartid;
input rst;
input clk;
input clk4x;
input tm_clk_i;
input [2:0] irq_i;
input [6:0] vec_i;
output wb_cmd_request128_t iwbm_req;
input wb_cmd_response128_t iwbm_resp;
output wb_cmd_request128_t dwbm_req;
input wb_cmd_response128_t dwbm_resp;
input address_t snoop_adr;
input snoop_v;
input [3:0] snoop_cid;
output [2:0] ol_o;
output [WID-1:0] pcr_o;
output [WID-1:0] pcr2_o;
input [31:0] signal_i;

parameter TM_CLKFREQ = 20000000;
parameter QENTRIES = 8;
parameter RSTPC = 32'hFFFC0100;
parameter BRKPC = 32'hFFFC0000;
`ifdef SUPPORT_SMT
parameter PREGS = 256;   // number of physical registers - 1
parameter AREGS = 256;   // number of architectural registers
`else
parameter PREGS = 128;
parameter AREGS = 128;
`endif
parameter RBIT = 11;
parameter DEBUG = 1'b0;
parameter NMAP = QENTRIES;
parameter BRANCH_PRED = 1'b0;
parameter SUP_TXE = 1'b0;
parameter SUP_VECTOR = 1;
parameter DBW = 64;
parameter ABW = 32;
parameter AMSB = ABW-1;
parameter NTHREAD = 1;
reg [3:0] i;
integer n;
integer j;
genvar g;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
// Memory access sizes
parameter byt = 3'd0;
parameter wyde = 3'd1;
parameter tetra = 3'd2;
parameter octa = 3'd3;

wire [RBIT:0] Ra0, Ra1;
wire [RBIT:0] Rb0, Rb1;
wire [RBIT:0] Rc0, Rc1;
wire [RBIT:0] Rt0, Rt1;
wire [WID-1:0] rfoa0,rfob0,rfoc0,rfoc0a;
wire [WID-1:0] rfoa1,rfob1,rfoc1,rfoc1a;
`ifdef SUPPORT_SMT
wire [7:0] Ra0s = {Ra0[7:0]};
wire [7:0] Ra1s = {Ra1[7:0]};
wire [7:0] Rb0s = {Rb0[7:0]};
wire [7:0] Rb1s = {Rb1[7:0]};
wire [7:0] Rc0s = {Rc0[7:0]};
wire [7:0] Rc1s = {Rc1[7:0]};
wire [7:0] Rt0s = {Rt0[7:0]};
wire [7:0] Rt1s = {Rt1[7:0]};
`else
wire [6:0] Ra0s = {Ra0[7],Ra0[5:0]};
wire [6:0] Ra1s = {Ra1[7],Ra1[5:0]};
wire [6:0] Rb0s = {Rb0[7],Rb0[5:0]};
wire [6:0] Rb1s = {Rb1[7],Rb1[5:0]};
wire [6:0] Rc0s = {Rc0[7],Rc0[5:0]};
wire [6:0] Rc1s = {Rc1[7],Rc1[5:0]};
wire [6:0] Rt0s = {Rt0[7],Rt0[5:0]};
wire [6:0] Rt1s = {Rt1[7],Rt1[5:0]};
/*
wire [5:0] Ra0s = {Ra0[5:0]};
wire [5:0] Ra1s = {Ra1[5:0]};
wire [5:0] Rb0s = {Rb0[5:0]};
wire [5:0] Rb1s = {Rb1[5:0]};
wire [5:0] Rc0s = {Rc0[5:0]};
wire [5:0] Rc1s = {Rc1[5:0]};
wire [5:0] Rt0s = {Rt0[5:0]};
wire [5:0] Rt1s = {Rt1[5:0]};
*/
`endif

reg  [PREGS-1:0] rf_v;
reg  [4:0] rf_source[0:AREGS-1];
initial begin
for (n = 0; n < AREGS; n = n + 1)
	rf_source[n] = 5'd0;
end
wire [31:0] pc0;
wire [31:0] pc1;

reg excmiss;
reg [51:0] excmisspc;
reg excthrd;
reg exception_set;
reg rdvq;               // accumulated read violation
reg errq;               // accumulated err_i input status
reg exvq;

// Vector
reg [5:0] vqe0, vqe1;   // vector element being queued
reg [5:0] vqet0, vqet1;
reg [7:0] vl;           // vector length
reg [63:0] vm [0:7];    // vector mask registers
reg [1:0] m2;

// CSR's
reg [51:0] cr0;
wire snr = cr0[17];		// sequence number reset
wire dce = cr0[30];     // data cache enable
wire bpe = cr0[32];     // branch predictor enable
wire ctgtxe = cr0[33];
// Simply setting this flag to zero should strip out almost all the logic
// associated SMT.
`ifdef SUPPORT_SMT
wire thread_en = cr0[16];
`else
wire thread_en = 1'b0;
`endif
wire vechain = cr0[18];
reg [7:0] fcu_timeout;
reg [51:0] tick;
reg [51:0] wc_time;
reg [51:0] pcr;
reg [51:0] pcr2;
assign pcr_o = pcr;
assign pcr2_o = pcr2;
reg [51:0] aec;
reg [15:0] cause[0:15];
reg [51:0] epc [0:NTHREAD];
address_t epc0 [0:NTHREAD];
reg [51:0] epc1 [0:NTHREAD];
reg [51:0] epc2 [0:NTHREAD];
reg [51:0] epc3 [0:NTHREAD];
reg [51:0] epc4 [0:NTHREAD];
reg [51:0] epc5 [0:NTHREAD];
reg [51:0] epc6 [0:NTHREAD];
reg [51:0] epc7 [0:NTHREAD];
reg [51:0] epc8 [0:NTHREAD]; 			// exception pc and stack
reg [51:0] mstatus [0:NTHREAD];  		// machine status
wire [2:0] im = mstatus[0][2:0];
wire [2:0] ol [0:NTHREAD];
assign ol[0] = mstatus[0][5:3];	// operating level
wire [7:0] cpl [0:NTHREAD];
assign cpl[0] = mstatus[0][13:6];	// current privilege level
wire [5:0] rgs [0:NTHREAD];
assign rgs[0] = mstatus[0][19:14];
assign ol[1] = mstatus[1][5:3];	// operating level
assign cpl[1] = mstatus[1][13:6];	// current privilege level
assign rgs[1] = mstatus[1][19:14];
reg [23:0] ol_stack [0:NTHREAD];
reg [23:0] im_stack [0:NTHREAD];
reg [51:0] pl_stack [0:NTHREAD];
reg [51:0] rs_stack [0:NTHREAD];
reg [51:0] fr_stack [0:NTHREAD];
wire mprv = mstatus[0][55];
wire [5:0] fprgs = mstatus[0][25:20];
assign ol_o = mprv ? ol_stack[0][2:0] : ol[0];
wire vca = mstatus[0][32];		// vector chaining active
reg [51:0] tcb;
reg [51:0] badaddr[0:15];
reg [51:0] tvec[0:7];
reg [51:0] sema;
reg [51:0] cas;         // compare and swap
reg [51:0] ve_hold;
reg isCAS, isAMO;
reg QNDX casid;
reg [51:0] sbl, sbu;
reg [5:0] regLR = 6'd61;

reg [2:0] fp_rm;
reg fp_inexe;
reg fp_dbzxe;
reg fp_underxe;
reg fp_overxe;
reg fp_invopxe;
reg fp_giopxe;
reg fp_nsfp = 1'b0;
reg fp_fractie;
reg fp_raz;

reg fp_neg;
reg fp_pos;
reg fp_zero;
reg fp_inf;

reg fp_inex;		// inexact exception
reg fp_dbzx;		// divide by zero exception
reg fp_underx;		// underflow exception
reg fp_overx;		// overflow exception
reg fp_giopx;		// global invalid operation exception
reg fp_sx;			// summary exception
reg fp_swtx;        // software triggered exception
reg fp_gx;
reg fp_invopx;

reg fp_infzerox;
reg fp_zerozerox;
reg fp_subinfx;
reg fp_infdivx;
reg fp_NaNCmpx;
reg fp_cvtx;
reg fp_sqrtx;
reg fp_snanx;

wire [51:0] fp_status = {
	fp_rm,
	fp_inexe,
	fp_dbzxe,
	fp_underxe,
	fp_overxe,
	fp_invopxe,
	fp_nsfp,

	fp_fractie,
	fp_raz,
	1'b0,
	fp_neg,
	fp_pos,
	fp_zero,
	fp_inf,

	fp_swtx,
	fp_inex,
	fp_dbzx,
	fp_underx,
	fp_overx,
	fp_giopx,
	fp_gx,
	fp_sx,
	
	fp_cvtx,
	fp_sqrtx,
	fp_NaNCmpx,
	fp_infzerox,
	fp_zerozerox,
	fp_infdivx,
	fp_subinfx,
	fp_snanx
	};

reg [51:0] fpu_csr;

//reg [25:0] m[0:8191];
reg  [3:0] panic;		// indexes the message structure
reg [128:0] message [0:15];	// indexed by panic

wire int_commit;
reg StatusHWI;
reg [31:0] insn0, insn1;
reg [159:0] postfix0, postfix1;
wire [31:0] insn0a, insn1a;

reg tgtq;
// Only need enough bits in the seqnence number to cover the instructions in
// the queue plus an extra count for skipping on branch misses. In this case
// that would be four bits minimum (count 0 to 8). 
wire [51:0] rdat0,rdat1,rdat2;
reg [51:0] xdati;

reg canq1, canq2;
reg queued1;
reg queued2;
reg queuedNop;

reg [33:0] codebuf[0:63];
reg [7:0] setpred;

// instruction queue (ROB)
reg [QENTRIES-1:0] iqentry_v;			// entry valid?  -- this should be the first bit
reg        iqentry_out	[0:QENTRIES-1];	// instruction has been issued to an ALU ... 
reg        iqentry_done	[0:QENTRIES-1];	// instruction result valid
reg        iqentry_cmt  [0:QENTRIES-1];
reg [QENTRIES-1:0] iqentry_thrd;		// which thread the instruction is in
reg        iqentry_pred [0:QENTRIES-1];  // predicate bit
reg        iqentry_bt  	[0:QENTRIES-1];	// branch-taken (used only for branches)
reg        iqentry_agen  	[0:QENTRIES-1];	// address-generate ... signifies that address is ready (only for LW/SW)
reg        iqentry_alu  [0:QENTRIES-1];  // alu type instruction
reg [QENTRIES-1:0] iqentry_alu0;	 // only valid on alu #0
reg        iqentry_fpu  [0:QENTRIES-1];  // floating point instruction
reg        iqentry_fc   [0:QENTRIES-1];   // flow control instruction
reg        iqentry_canex[0:QENTRIES-1];	// true if it's an instruction that can exception
reg        iqentry_load [0:QENTRIES-1];	// is a memory load instruction
reg        iqentry_mem	[0:QENTRIES-1];	// touches memory: 1 if LW/SW
reg        iqentry_memndx   [0:QENTRIES-1];  // indexed memory operation 
reg        iqentry_memdb    [0:QENTRIES-1];
reg        iqentry_memsb    [0:QENTRIES-1];
reg [QENTRIES-1:0] iqentry_sei;
reg        iqentry_aq   [0:QENTRIES-1];	// memory aquire
reg        iqentry_rl   [0:QENTRIES-1];	// memory release
reg        iqentry_jmp	[0:QENTRIES-1];	// changes control flow: 1 if BEQ/JALR
reg        iqentry_br   [0:QENTRIES-1];  // Bcc (for predictor)
reg        iqentry_sync [0:QENTRIES-1];  // sync instruction
reg        iqentry_fsync[0:QENTRIES-1];
reg        iqentry_rfw	[0:QENTRIES-1];	// writes to register file
reg  [7:0] iqentry_we   [0:QENTRIES-1];	// enable strobe
reg [WID-1:0] iqentry_res	[0:QENTRIES-1];	// instruction result
reg [33:0] iqentry_instr[0:QENTRIES-1];	// instruction opcode
reg  [7:0] iqentry_exc	[0:QENTRIES-1];	// only for branches ... indicates a HALT instruction
reg [RBIT:0] iqentry_tgt	[0:QENTRIES-1];	// Rt field or ZERO -- this is the instruction's target (if any)
reg  [5:0] iqentry_ven  [0:QENTRIES-1];  // vector element number
reg [WID-1:0] iqentry_a0	[0:QENTRIES-1];	// argument 0 (immediate)
reg [WID-1:0] iqentry_a1	[0:QENTRIES-1];	// argument 1
reg [WID-1:0] iqentry_a2	[0:QENTRIES-1];	// argument 2
reg [WID-1:0] iqentry_a3	[0:QENTRIES-1];	// argument 3
reg [51:0] iqentry_pc	[0:QENTRIES-1];	// program counter for this instruction
reg [RBIT:0] iqentry_Ra [0:QENTRIES-1];
reg [RBIT:0] iqentry_Rb [0:QENTRIES-1];
reg [RBIT:0] iqentry_Rc [0:QENTRIES-1];
// debugging
//reg  [4:0] iqentry_ra   [0:7];  // Ra

wire  [QENTRIES-1:0] iqentry_source;
reg   [QENTRIES-1:0] iqentry_imm;
wire  [QENTRIES-1:0] iqentry_memready;
wire  [QENTRIES-1:0] iqentry_memopsvalid;

reg  [QENTRIES-1:0] memissue;
reg [1:0] missued;
integer last_issue;
reg  [QENTRIES-1:0] iqentry_memissue;
wire [QENTRIES-1:0] iqentry_stomp;
reg [QENTRIES-1:0] iqentry_issue;
reg [QENTRIES-1:0] iqentry_issue_dc;
reg [1:0] iqentry_islot [0:QENTRIES-1];
reg [1:0] iqentry_mem_islot [0:QENTRIES-1];
reg [1:0] iqentry_fpu_islot [0:QENTRIES-1];
reg [QENTRIES-1:0] iqentry_fcu_issue;
reg [QENTRIES-1:0] iqentry_fpu_issue;

localparam QHBIT = $clog2(QENTRIES)-1;
typedef logic [QHBIt:0] QNDX;

QNDX tail0;
QNDX tail1;
QNDX head0;
QNDX head1;
QNDX head2;	// used only to determine memory-access ordering
QNDX head3;	// used only to determine memory-access ordering
QNDX head4;	// used only to determine memory-access ordering
QNDX head5;	// used only to determine memory-access ordering
QNDX head6;	// used only to determine memory-access ordering
QNDX head7;	// used only to determine memory-access ordering

wire take_branch0;
wire take_branch1;

reg [3:0] nop_fetchbuf;
wire        fetchbuf;	// determines which pair to read from & write to

wire [33:0] insn0a;	
wire [51:0] fetchbuf0_pc;
wire        fetchbuf0_v;
wire		fetchbuf0_thrd;
wire        fetchbuf0_mem;
wire 		fetchbuf0_memld;
wire        fetchbuf0_jmp;
wire        fetchbuf0_rfw;
wire [33:0] insn1a;
wire [51:0] fetchbuf1_pc;
wire        fetchbuf1_v;
wire		fetchbuf1_thrd;
wire        fetchbuf1_mem;
wire		fetchbuf1_memld;
wire        fetchbuf1_jmp;
wire        fetchbuf1_rfw;

wire [33:0] fetchbufA_instr;	
wire [51:0] fetchbufA_pc;
wire        fetchbufA_v;
wire [33:0] fetchbufB_instr;
wire [51:0] fetchbufB_pc;
wire        fetchbufB_v;
wire [33:0] fetchbufC_instr;
wire [51:0] fetchbufC_pc;
wire        fetchbufC_v;
wire [33:0] fetchbufD_instr;
wire [51:0] fetchbufD_pc;
wire        fetchbufD_v;

//reg        did_branchback0;
//reg        did_branchback1;

reg        alu0_ld;
reg        alu0_available;
reg        alu0_dataready;
wire       alu0_done;
reg        alu0_pred;
wire       alu0_idle;
reg  [3:0] alu0_sourceid;
reg [33:0] alu0_instr;
reg        alu0_bt;
reg [WID-1:0] alu0_argA;
reg [WID-1:0] alu0_argB;
reg [WID-1:0] alu0_argC;
reg [WID-1:0] alu0_argI;	// only used by BEQ
reg [RBIT:0] alu0_tgt;
reg [5:0]  alu0_ven;
reg        alu0_thrd;
reg [51:0] alu0_pc;
wire [WID-1:0] alu0_bus;
wire  [3:0] alu0_id;
wire  [8:0] alu0_exc;
wire        alu0_v;
wire        alu0_branchmiss;
wire [51:0] alu0_misspc;

reg        alu1_ld;
reg        alu1_available;
reg        alu1_dataready;
wire       alu1_done;
reg        alu1_pred;
wire       alu1_idle;
reg  [3:0] alu1_sourceid;
reg [33:0] alu1_instr;
reg        alu1_bt;
reg [WID-1:0] alu1_argA;
reg [WID-1:0] alu1_argB;
reg [WID-1:0] alu1_argC;
reg [WID-1:0] alu1_argI;	// only used by BEQ
reg [RBIT:0] alu1_tgt;
reg [5:0]  alu1_ven;
reg [51:0] alu1_pc;
wire [WID-1:0] alu1_bus;
wire  [3:0] alu1_id;
wire  [8:0] alu1_exc;
wire        alu1_v;
wire        alu1_branchmiss;
wire [51:0] alu1_misspc;

reg        fpu_ld;
reg        fpu_available;
reg        fpu_dataready;
wire       fpu_done;
reg        fpu_pred;
wire       fpu_idle;
reg  [3:0] fpu_sourceid;
reg [33:0] fpu_instr;
reg [WID-1:0] fpu_argA;
reg [WID-1:0] fpu_argB;
reg [WID-1:0] fpu_argC;
reg [WID-1:0] fpu_argI;	// only used by BEQ
reg [RBIT:0] fpu_tgt;
reg [51:0] fpu_pc;
wire [WID-1:0] fpu_bus;
wire  [3:0] fpu_id;
wire  [8:0] fpu_exc;
wire        fpu_v;
wire [WID-1:0] fpu_status;

reg [WID-1:0] waitctr;
reg        fcu_ld;
reg        fcu_dataready;
reg        fcu_done;
reg        fcu_pred;
reg         fcu_idle = 1'b1;
reg  [3:0] fcu_sourceid;
reg [33:0] fcu_instr;
reg        fcu_call;
reg        fcu_bt;
reg [WID-1:0] fcu_argA;
reg [WID-1:0] fcu_argB;
reg [WID-1:0] fcu_argC;
reg [WID-1:0] fcu_argI;	// only used by BEQ
reg [WID-1:0] fcu_argT;
reg [51:0] fcu_pc;
wire [WID-1:0] fcu_bus;
wire  [3:0] fcu_id;
reg   [8:0] fcu_exc;
wire        fcu_v;
reg        fcu_thrd;
reg        fcu_branchmiss;
reg  fcu_clearbm;
wire [51:0] fcu_misspc;

reg [WID-1:0] amo_argA;
reg [WID-1:0] amo_argB;
wire [WID-1:0] amo_res;
reg [33:0] amo_instr;

reg branchmiss;
reg branchmiss_thrd;
reg [31:0] misspc;
QNDX missid;

wire take_branch;
wire take_branchA;
wire take_branchB;
wire take_branchC;
wire take_branchD;

wire        dram_avail;
reg	 [2:0] dram0;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	 [2:0] dram1;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	 [2:0] dram2;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg [WID-1:0] dram0_data;
reg [51:0] dram0_addr;
reg [33:0] dram0_instr;
reg [RBIT:0] dram0_tgt;
reg  [3:0] dram0_id;
reg  [8:0] dram0_exc;
reg        dram0_unc;
reg [2:0]  dram0_memsize;
reg        dram0_load;	// is a load operation
reg [WID-1:0] dram1_data;
reg [51:0] dram1_addr;
reg [33:0] dram1_instr;
reg [RBIT:0] dram1_tgt;
reg  [3:0] dram1_id;
reg  [8:0] dram1_exc;
reg        dram1_unc;
reg [2:0]  dram1_memsize;
reg        dram1_load;
reg [WID-1:0] dram2_data;
reg [51:0] dram2_addr;
reg [33:0] dram2_instr;
reg [RBIT:0] dram2_tgt;
reg  [3:0] dram2_id;
reg  [8:0] dram2_exc;
reg        dram2_unc;
reg [2:0]  dram2_memsize;
reg        dram2_load;

reg        dramA_v;
reg  [3:0] dramA_id;
reg [WID-1:0] dramA_bus;
reg  [8:0] dramA_exc;
reg        dramB_v;
reg  [3:0] dramB_id;
reg [WID-1:0] dramB_bus;
reg  [8:0] dramB_exc;
reg        dramC_v;
reg  [3:0] dramC_id;
reg [WID-1:0] dramC_bus;
reg  [8:0] dramC_exc;

wire        outstanding_stores;
reg [63:0] I;	// instruction count

reg        commit0_v;
reg  [4:0] commit0_id;
reg [RBIT:0] commit0_tgt;
reg  [7:0] commit0_we;
reg [WID-1:0] commit0_bus;
reg        commit1_v;
reg  [4:0] commit1_id;
reg [RBIT:0] commit1_tgt;
reg  [7:0] commit1_we;
reg [WID-1:0] commit1_bus;

reg [4:0] bstate;
parameter BIDLE = 5'd0;
parameter B1 = 5'd1;
parameter B2 = 5'd2;
parameter B3 = 5'd3;
parameter B4 = 5'd4;
parameter B5 = 5'd5;
parameter B6 = 5'd6;
parameter B7 = 5'd7;
parameter B8 = 5'd8;
parameter B9 = 5'd9;
parameter B10 = 5'd10;
parameter B11 = 5'd11;
parameter B12 = 5'd12;
parameter B13 = 5'd13;
parameter B14 = 5'd14;
parameter B15 = 5'd15;
parameter B16 = 5'd16;
parameter B17 = 5'd17;
parameter B18 = 5'd18;
parameter B19 = 5'd19;
parameter B2a = 5'd20;
parameter B2b = 5'd21;
parameter B2c = 5'd22;
parameter B2d = 5'd23;
parameter B20 = 5'd24;
reg [1:0] bwhich;
reg [3:0] icstate,picstate;
parameter IDLE = 4'd0;
parameter IC1 = 4'd1;
parameter IC2 = 4'd2;
parameter IC3 = 4'd3;
parameter IC4 = 4'd4;
parameter IC5 = 4'd5;
parameter IC6 = 4'd6;
parameter IC7 = 4'd7;
parameter IC8 = 4'd8;
parameter IC9 = 4'd9;
parameter IC10 = 4'd10;
parameter IC3a = 4'd11;
reg invic, invdc;
reg icwhich,icnxt,L2_nxt;
wire ihit0,ihit1,ihit2;
wire ihit = ihit0&ihit1;
reg phit;
wire threadx;
always_comb
	phit <= ihit&&icstate==IDLE;
reg [1:0] iccnt;
reg L1_wr0,L1_wr1;
reg L1_invline;
reg [7:0] L1_en;
reg [57:0] L1_adr, L2_adr;
reg [416:0] L2_rdat;
wire [416:0] L2_dato;

Thor2024_regfile2w6r_oc #(.RBIT(RBIT)) urf1
(
  .clk(clk),
  .clk4x(clk4x),
  .wr0(commit0_v),
  .wr1(commit1_v),
  .we0(commit0_we),
  .we1(commit1_we),
  .wa0(commit0_tgt),
  .wa1(commit1_tgt),
  .i0(commit0_bus),
  .i1(commit1_bus),
	.rclk(~clk),
	.ra0(Ra0),
	.ra1(Rb0),
	.ra2(Rc0),
	.ra3(Ra1),
	.ra4(Rb1),
	.ra5(Rc1),
	.o0(rfoa0),
	.o1(rfob0),
	.o2(rfoc0a),
	.o3(rfoa1),
	.o4(rfob1),
	.o5(rfoc1a)
);
assign rfoc0 = Rc0[11:6]==6'h3F ? vm[Rc0[2:0]] : rfoc0a;
assign rfoc1 = Rc1[11:6]==6'h3F ? vm[Rc1[2:0]] : rfoc1a;

wire [255:0] ic_line_hi, ic_line_lo;
wire fifoToBiuFull0;
wire fifoToBiuWack0;
wire fifoFromBiuEmpty0;
memory_arg_t fifoToBiuArg0;
memory_arg_t fifoFromBiuArg0;
reg fifoFromBiuRd0;
wire fifoToBiuFull1;
wire fifoToBiuWack1;
wire fifoFromBiuEmpty1;
memory_arg_t fifoToBiuArg1;
memory_arg_t fifoFromBiuArg1;
reg fifoFromBiuRd1;

Thor2024_biu ubiu1
(
	.rst(rst),
	.clk(clk),
	.tlbclk(clk),
	.clock(1'b0),
	.AppMode(),
	.MAppMode(),
	.omode(2'd3),
	.bounds_chk(1'b0),
	.pe(1'b1),
	.ip_asid(12'h0),
	.ip(pc0),
	.ip_o(),
	.ihit_o(),
	.ifStall(1'b0),
	.ic_line_hi(ic_line_hi),
	.ic_line_lo(ic_line_lo),
	.ic_valid(),
	.fifoToCtrl0_wack(fifoToBiuWack0),
	.fifoToCtrl0_i(fifToBiuArg0),
	.fifoToCtrl0_full_o(fifoToBiuFull0),
	.fifoFromCtrl0_o(fifoFromBiuArg0),
	.fifoFromCtrl0_rd(fifoFromBiuRd0),
	.fifoFromCtrl0_empty(fifoFromBiuEmpty0),
	.fifoFromCtrl0_v(),
	.fifoToCtrl1_wack(fifoToBiuWack1),
	.fifoToCtrl1_i(fifToBiuArg1),
	.fifoToCtrl1_full_o(fifoToBiuFull1),
	.fifoFromCtrl1_o(fifoFromBiuArg1),
	.fifoFromCtrl1_rd(fifoFromBiuRd1),
	.fifoFromCtrl1_empty(fifoFromBiuEmpty1),
	.fifoFromCtrl1_v(),
	// This port not used
	.bte_o(),
	.blen_o(),
	.tid_o(),
	.cti_o(),
	.seg_o(),
	.cyc_o(),
	.stb_o(),
	.we_o(),
	.sel_o(),
	.adr_o(),
	.dat_o(),
	.csr_o(),
	.stall_i(1'b0),
	.next_i(1'b0),
	.rty_i(1'b0),
	.ack_i(1'b0),
	.err_i(1'b0),
	.tid_i(8'h00),
	.dat_i('d0), 
	.rb_i('d0),
	.adr_i('d0),
	.asid_i('d0),

	.dce(1'b1),
	.keys('d0),
	.arange('d0),
	.ptbr('d0),
	.ipage_fault(),
	.clr_ipage_fault('d0),
	.iwbm_req(iwbm_req),
	.iwbm_resp(iwbm_resp), 
	.dwbm_req(dwbm_req),
	.dwbm_resp(dwbm_resp),
	.tlbacr(),
	.rollback(),
	.rollback_bitmaps(),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_cid(snoop_cid)
);

function fnIlen;
input [7:0] insn;
casez(insn[7:0])
8'b10100000:	fnIlen = 5'd08;
8'b10100001:	fnIlen = 5'd08;
8'b10100010:	fnIlen = 5'd08;
8'b10100101:	fnIlen = 5'd08;
8'b10100110:	fnIlen = 5'd08;
8'b10100111:	fnIlen = 5'd08;
8'b10101???:	fnIlen = 5'd08;
8'b?1001111:	fnIlen = 5'd08;
8'b?1010111:	fnIlen = 5'd08;
8'b?1100001:	fnIlen = 5'd08;
8'b?1100011:	fnIlen = 5'd08;
8'b?1100100:	fnIlen = 5'd08;
8'b?1100111:	fnIlen = 5'd08;
8'b?1101000:	fnIlen = 5'd08;
8'b?1101001:	fnIlen = 5'd08;
8'b?1101011:	fnIlen = 5'd08;
8'b?1110101:	fnIlen = 5'd08;
8'b11111100:	fnIlen = 5'd08;
8'b01111101:	fnIlen = 5'd12;
8'b11111101:	fnIlen = 5'd16;
8'b?1111110:	fnIlen = 5'd20;
default:	fnIlen = 5'd04;
endcase
end
endfunction

function fnIsPostfix;
input [6:0] insn;
begin
fnIsPostfix = insn==7'd124 || insn==7'd125 || insn==7'd126;
end
endfunction
	
reg [511:0] ic_line;
always_comb
	ic_line = {ic_line_hi,ic_line_lo};
always_comb
	insn0 = ic_line >> {pc0[4:0],3'd0};
always_comb
	postfix0 = {pc0[4:0] + fnIlen(insn0[7:0]),3'd0};
always_comb
	insn1 = ic_line >> {pc0[4:0] + (fnIsPostfix(postfix0) ? fnIlen(postfix0[6:0]) + fnIlen(insn0[7:0]) :
	fnIlen(insn0[7:0])),3'd0};
always_comb
	postfix1 = ic_line >> {pc0[4:0] + (fnIsPostfix(postfix0) ? fnIlen(postfix0[6:0]) + fnIlen(insn0[7:0]) :
	fnIlen(insn0[7:0])) + fnIlen(insn1[7:0]),3'd0};

/*
Gam_L1_icache uic0
(
    .rst(rst),
    .clk(clk),
    .nxt(icnxt),
    .wr(L1_wr0),
    .en(L1_en),
    .adr(icstate==IDLE||icstate==IC8 ? {pcr[5:0],pc0} : L1_adr),
    .wadr(L1_adr),
    .i(L2_rdat),
    .o(insn0a),
    .hit(ihit0),
    .invall(invic),
    .invline(L1_invline)
);
Gam_L1_icache uic1
(
    .rst(rst),
    .clk(clk),
    .nxt(icnxt),
    .wr(L1_wr1),
    .en(L1_en),
    .adr(icstate==IDLE||icstate==IC8 ? {pcr[5:0],pc1} : L1_adr),
    .wadr(L1_adr),
    .i(L2_rdat),
    .o(insn1a),
    .hit(ihit1),
    .invall(invic),
    .invline(L1_invline)
);
Gam_L2_icache uic2
(
    .rst(rst),
    .clk(clk),
    .nxt(L2_nxt),
    .wr(bstate==B7 && ack_i),
    .adr(L2_adr),
    .cnt(iccnt),
    .exv_i(exvq),
    .i(dat_i),
    .err_i(errq),
    .o(L2_dato),
    .hit(ihit2),
    .invall(invic),
    .invline()
);
*/
//-----------------------------------------------------------------------------
// Debug
//-----------------------------------------------------------------------------
`ifdef SUPPORT_DBG

wire [DBW-1:0] dbg_stat1x;
reg [DBW-1:0] dbg_stat;
reg [DBW-1:0] dbg_ctrl;
reg [ABW-1:0] dbg_adr0;
reg [ABW-1:0] dbg_adr1;
reg [ABW-1:0] dbg_adr2;
reg [ABW-1:0] dbg_adr3;
reg dbg_imatchA0,dbg_imatchA1,dbg_imatchA2,dbg_imatchA3,dbg_imatchA;
reg dbg_imatchB0,dbg_imatchB1,dbg_imatchB2,dbg_imatchB3,dbg_imatchB;

wire dbg_lmatch00 =
			dbg_ctrl[0] && dbg_ctrl[17:16]==2'b11 && dram0_addr[AMSB:3]==dbg_adr0[AMSB:3] &&
				((dbg_ctrl[19:18]==2'b00 && dram0_addr[2:0]==dbg_adr0[2:0]) ||
				 (dbg_ctrl[19:18]==2'b01 && dram0_addr[2:1]==dbg_adr0[2:1]) ||
				 (dbg_ctrl[19:18]==2'b10 && dram0_addr[2]==dbg_adr0[2]) ||
				 dbg_ctrl[19:18]==2'b11)
				 ;
wire dbg_lmatch01 =
             dbg_ctrl[0] && dbg_ctrl[17:16]==2'b11 && dram1_addr[AMSB:3]==dbg_adr0[AMSB:3] &&
                 ((dbg_ctrl[19:18]==2'b00 && dram1_addr[2:0]==dbg_adr0[2:0]) ||
                  (dbg_ctrl[19:18]==2'b01 && dram1_addr[2:1]==dbg_adr0[2:1]) ||
                  (dbg_ctrl[19:18]==2'b10 && dram1_addr[2]==dbg_adr0[2]) ||
                  dbg_ctrl[19:18]==2'b11)
                  ;
wire dbg_lmatch02 =
           dbg_ctrl[0] && dbg_ctrl[17:16]==2'b11 && dram2_addr[AMSB:3]==dbg_adr0[AMSB:3] &&
               ((dbg_ctrl[19:18]==2'b00 && dram2_addr[2:0]==dbg_adr0[2:0]) ||
                (dbg_ctrl[19:18]==2'b01 && dram2_addr[2:1]==dbg_adr0[2:1]) ||
                (dbg_ctrl[19:18]==2'b10 && dram2_addr[2]==dbg_adr0[2]) ||
                dbg_ctrl[19:18]==2'b11)
                ;
wire dbg_lmatch10 =
             dbg_ctrl[1] && dbg_ctrl[21:20]==2'b11 && dram0_addr[AMSB:3]==dbg_adr1[AMSB:3] &&
                 ((dbg_ctrl[23:22]==2'b00 && dram0_addr[2:0]==dbg_adr1[2:0]) ||
                  (dbg_ctrl[23:22]==2'b01 && dram0_addr[2:1]==dbg_adr1[2:1]) ||
                  (dbg_ctrl[23:22]==2'b10 && dram0_addr[2]==dbg_adr1[2]) ||
                  dbg_ctrl[23:22]==2'b11)
                  ;
wire dbg_lmatch11 =
           dbg_ctrl[1] && dbg_ctrl[21:20]==2'b11 && dram1_addr[AMSB:3]==dbg_adr1[AMSB:3] &&
               ((dbg_ctrl[23:22]==2'b00 && dram1_addr[2:0]==dbg_adr1[2:0]) ||
                (dbg_ctrl[23:22]==2'b01 && dram1_addr[2:1]==dbg_adr1[2:1]) ||
                (dbg_ctrl[23:22]==2'b10 && dram1_addr[2]==dbg_adr1[2]) ||
                dbg_ctrl[23:22]==2'b11)
                ;
wire dbg_lmatch12 =
           dbg_ctrl[1] && dbg_ctrl[21:20]==2'b11 && dram2_addr[AMSB:3]==dbg_adr1[AMSB:3] &&
               ((dbg_ctrl[23:22]==2'b00 && dram2_addr[2:0]==dbg_adr1[2:0]) ||
                (dbg_ctrl[23:22]==2'b01 && dram2_addr[2:1]==dbg_adr1[2:1]) ||
                (dbg_ctrl[23:22]==2'b10 && dram2_addr[2]==dbg_adr1[2]) ||
                dbg_ctrl[23:22]==2'b11)
                ;
wire dbg_lmatch20 =
               dbg_ctrl[2] && dbg_ctrl[25:24]==2'b11 && dram0_addr[AMSB:3]==dbg_adr2[AMSB:3] &&
                   ((dbg_ctrl[27:26]==2'b00 && dram0_addr[2:0]==dbg_adr2[2:0]) ||
                    (dbg_ctrl[27:26]==2'b01 && dram0_addr[2:1]==dbg_adr2[2:1]) ||
                    (dbg_ctrl[27:26]==2'b10 && dram0_addr[2]==dbg_adr2[2]) ||
                    dbg_ctrl[27:26]==2'b11)
                    ;
wire dbg_lmatch21 =
               dbg_ctrl[2] && dbg_ctrl[25:24]==2'b11 && dram1_addr[AMSB:3]==dbg_adr2[AMSB:3] &&
                   ((dbg_ctrl[27:26]==2'b00 && dram1_addr[2:0]==dbg_adr2[2:0]) ||
                    (dbg_ctrl[27:26]==2'b01 && dram1_addr[2:1]==dbg_adr2[2:1]) ||
                    (dbg_ctrl[27:26]==2'b10 && dram1_addr[2]==dbg_adr2[2]) ||
                    dbg_ctrl[27:26]==2'b11)
                    ;
wire dbg_lmatch22 =
               dbg_ctrl[2] && dbg_ctrl[25:24]==2'b11 && dram2_addr[AMSB:3]==dbg_adr2[AMSB:3] &&
                   ((dbg_ctrl[27:26]==2'b00 && dram2_addr[2:0]==dbg_adr2[2:0]) ||
                    (dbg_ctrl[27:26]==2'b01 && dram2_addr[2:1]==dbg_adr2[2:1]) ||
                    (dbg_ctrl[27:26]==2'b10 && dram2_addr[2]==dbg_adr2[2]) ||
                    dbg_ctrl[27:26]==2'b11)
                    ;
wire dbg_lmatch30 =
                 dbg_ctrl[3] && dbg_ctrl[29:28]==2'b11 && dram0_addr[AMSB:3]==dbg_adr3[AMSB:3] &&
                     ((dbg_ctrl[31:30]==2'b00 && dram0_addr[2:0]==dbg_adr3[2:0]) ||
                      (dbg_ctrl[31:30]==2'b01 && dram0_addr[2:1]==dbg_adr3[2:1]) ||
                      (dbg_ctrl[31:30]==2'b10 && dram0_addr[2]==dbg_adr3[2]) ||
                      dbg_ctrl[31:30]==2'b11)
                      ;
wire dbg_lmatch31 =
               dbg_ctrl[3] && dbg_ctrl[29:28]==2'b11 && dram1_addr[AMSB:3]==dbg_adr3[AMSB:3] &&
                   ((dbg_ctrl[31:30]==2'b00 && dram1_addr[2:0]==dbg_adr3[2:0]) ||
                    (dbg_ctrl[31:30]==2'b01 && dram1_addr[2:1]==dbg_adr3[2:1]) ||
                    (dbg_ctrl[31:30]==2'b10 && dram1_addr[2]==dbg_adr3[2]) ||
                    dbg_ctrl[31:30]==2'b11)
                    ;
wire dbg_lmatch32 =
               dbg_ctrl[3] && dbg_ctrl[29:28]==2'b11 && dram2_addr[AMSB:3]==dbg_adr3[AMSB:3] &&
                   ((dbg_ctrl[31:30]==2'b00 && dram2_addr[2:0]==dbg_adr3[2:0]) ||
                    (dbg_ctrl[31:30]==2'b01 && dram2_addr[2:1]==dbg_adr3[2:1]) ||
                    (dbg_ctrl[31:30]==2'b10 && dram2_addr[2]==dbg_adr3[2]) ||
                    dbg_ctrl[31:30]==2'b11)
                    ;
wire dbg_lmatch0 = dbg_lmatch00|dbg_lmatch10|dbg_lmatch20|dbg_lmatch30;                  
wire dbg_lmatch1 = dbg_lmatch01|dbg_lmatch11|dbg_lmatch21|dbg_lmatch31;                  
wire dbg_lmatch2 = dbg_lmatch02|dbg_lmatch12|dbg_lmatch22|dbg_lmatch32;                  
wire dbg_lmatch = dbg_lmatch00|dbg_lmatch10|dbg_lmatch20|dbg_lmatch30|
                  dbg_lmatch01|dbg_lmatch11|dbg_lmatch21|dbg_lmatch31|
                  dbg_lmatch02|dbg_lmatch12|dbg_lmatch22|dbg_lmatch32
                    ;

wire dbg_smatch00 =
			dbg_ctrl[0] && dbg_ctrl[17:16]==2'b11 && dram0_addr[AMSB:3]==dbg_adr0[AMSB:3] &&
				((dbg_ctrl[19:18]==2'b00 && dram0_addr[2:0]==dbg_adr0[2:0]) ||
				 (dbg_ctrl[19:18]==2'b01 && dram0_addr[2:1]==dbg_adr0[2:1]) ||
				 (dbg_ctrl[19:18]==2'b10 && dram0_addr[2]==dbg_adr0[2]) ||
				 dbg_ctrl[19:18]==2'b11)
				 ;
wire dbg_smatch01 =
             dbg_ctrl[0] && dbg_ctrl[17:16]==2'b11 && dram1_addr[AMSB:3]==dbg_adr0[AMSB:3] &&
                 ((dbg_ctrl[19:18]==2'b00 && dram1_addr[2:0]==dbg_adr0[2:0]) ||
                  (dbg_ctrl[19:18]==2'b01 && dram1_addr[2:1]==dbg_adr0[2:1]) ||
                  (dbg_ctrl[19:18]==2'b10 && dram1_addr[2]==dbg_adr0[2]) ||
                  dbg_ctrl[19:18]==2'b11)
                  ;
wire dbg_smatch02 =
           dbg_ctrl[0] && dbg_ctrl[17:16]==2'b11 && dram2_addr[AMSB:3]==dbg_adr0[AMSB:3] &&
               ((dbg_ctrl[19:18]==2'b00 && dram2_addr[2:0]==dbg_adr0[2:0]) ||
                (dbg_ctrl[19:18]==2'b01 && dram2_addr[2:1]==dbg_adr0[2:1]) ||
                (dbg_ctrl[19:18]==2'b10 && dram2_addr[2]==dbg_adr0[2]) ||
                dbg_ctrl[19:18]==2'b11)
                ;
wire dbg_smatch10 =
             dbg_ctrl[1] && dbg_ctrl[21:20]==2'b11 && dram0_addr[AMSB:3]==dbg_adr1[AMSB:3] &&
                 ((dbg_ctrl[23:22]==2'b00 && dram0_addr[2:0]==dbg_adr1[2:0]) ||
                  (dbg_ctrl[23:22]==2'b01 && dram0_addr[2:1]==dbg_adr1[2:1]) ||
                  (dbg_ctrl[23:22]==2'b10 && dram0_addr[2]==dbg_adr1[2]) ||
                  dbg_ctrl[23:22]==2'b11)
                  ;
wire dbg_smatch11 =
           dbg_ctrl[1] && dbg_ctrl[21:20]==2'b11 && dram1_addr[AMSB:3]==dbg_adr1[AMSB:3] &&
               ((dbg_ctrl[23:22]==2'b00 && dram1_addr[2:0]==dbg_adr1[2:0]) ||
                (dbg_ctrl[23:22]==2'b01 && dram1_addr[2:1]==dbg_adr1[2:1]) ||
                (dbg_ctrl[23:22]==2'b10 && dram1_addr[2]==dbg_adr1[2]) ||
                dbg_ctrl[23:22]==2'b11)
                ;
wire dbg_smatch12 =
           dbg_ctrl[1] && dbg_ctrl[21:20]==2'b11 && dram2_addr[AMSB:3]==dbg_adr1[AMSB:3] &&
               ((dbg_ctrl[23:22]==2'b00 && dram2_addr[2:0]==dbg_adr1[2:0]) ||
                (dbg_ctrl[23:22]==2'b01 && dram2_addr[2:1]==dbg_adr1[2:1]) ||
                (dbg_ctrl[23:22]==2'b10 && dram2_addr[2]==dbg_adr1[2]) ||
                dbg_ctrl[23:22]==2'b11)
                ;
wire dbg_smatch20 =
               dbg_ctrl[2] && dbg_ctrl[25:24]==2'b11 && dram0_addr[AMSB:3]==dbg_adr2[AMSB:3] &&
                   ((dbg_ctrl[27:26]==2'b00 && dram0_addr[2:0]==dbg_adr2[2:0]) ||
                    (dbg_ctrl[27:26]==2'b01 && dram0_addr[2:1]==dbg_adr2[2:1]) ||
                    (dbg_ctrl[27:26]==2'b10 && dram0_addr[2]==dbg_adr2[2]) ||
                    dbg_ctrl[27:26]==2'b11)
                    ;
wire dbg_smatch21 =
           dbg_ctrl[2] && dbg_ctrl[25:24]==2'b11 && dram1_addr[AMSB:3]==dbg_adr2[AMSB:3] &&
                    ((dbg_ctrl[27:26]==2'b00 && dram1_addr[2:0]==dbg_adr2[2:0]) ||
                     (dbg_ctrl[27:26]==2'b01 && dram1_addr[2:1]==dbg_adr2[2:1]) ||
                     (dbg_ctrl[27:26]==2'b10 && dram1_addr[2]==dbg_adr2[2]) ||
                     dbg_ctrl[27:26]==2'b11)
                     ;
wire dbg_smatch22 =
            dbg_ctrl[2] && dbg_ctrl[25:24]==2'b11 && dram2_addr[AMSB:3]==dbg_adr2[AMSB:3] &&
                     ((dbg_ctrl[27:26]==2'b00 && dram2_addr[2:0]==dbg_adr2[2:0]) ||
                      (dbg_ctrl[27:26]==2'b01 && dram2_addr[2:1]==dbg_adr2[2:1]) ||
                      (dbg_ctrl[27:26]==2'b10 && dram2_addr[2]==dbg_adr2[2]) ||
                      dbg_ctrl[27:26]==2'b11)
                      ;
wire dbg_smatch30 =
                 dbg_ctrl[3] && dbg_ctrl[29:28]==2'b11 && dram0_addr[AMSB:3]==dbg_adr3[AMSB:3] &&
                     ((dbg_ctrl[31:30]==2'b00 && dram0_addr[2:0]==dbg_adr3[2:0]) ||
                      (dbg_ctrl[31:30]==2'b01 && dram0_addr[2:1]==dbg_adr3[2:1]) ||
                      (dbg_ctrl[31:30]==2'b10 && dram0_addr[2]==dbg_adr3[2]) ||
                      dbg_ctrl[31:30]==2'b11)
                      ;
wire dbg_smatch31 =
               dbg_ctrl[3] && dbg_ctrl[29:28]==2'b11 && dram1_addr[AMSB:3]==dbg_adr3[AMSB:3] &&
                   ((dbg_ctrl[31:30]==2'b00 && dram1_addr[2:0]==dbg_adr3[2:0]) ||
                    (dbg_ctrl[31:30]==2'b01 && dram1_addr[2:1]==dbg_adr3[2:1]) ||
                    (dbg_ctrl[31:30]==2'b10 && dram1_addr[2]==dbg_adr3[2]) ||
                    dbg_ctrl[31:30]==2'b11)
                    ;
wire dbg_smatch32 =
               dbg_ctrl[3] && dbg_ctrl[29:28]==2'b11 && dram2_addr[AMSB:3]==dbg_adr3[AMSB:3] &&
                   ((dbg_ctrl[31:30]==2'b00 && dram2_addr[2:0]==dbg_adr3[2:0]) ||
                    (dbg_ctrl[31:30]==2'b01 && dram2_addr[2:1]==dbg_adr3[2:1]) ||
                    (dbg_ctrl[31:30]==2'b10 && dram2_addr[2]==dbg_adr3[2]) ||
                    dbg_ctrl[31:30]==2'b11)
                    ;
wire dbg_smatch0 = dbg_smatch00|dbg_smatch10|dbg_smatch20|dbg_smatch30;
wire dbg_smatch1 = dbg_smatch01|dbg_smatch11|dbg_smatch21|dbg_smatch31;
wire dbg_smatch2 = dbg_smatch02|dbg_smatch12|dbg_smatch22|dbg_smatch32;

wire dbg_smatch =   dbg_smatch00|dbg_smatch10|dbg_smatch20|dbg_smatch30|
                    dbg_smatch01|dbg_smatch11|dbg_smatch21|dbg_smatch31|
                    dbg_smatch02|dbg_smatch12|dbg_smatch22|dbg_smatch32
                    ;

wire dbg_stat0 = dbg_imatchA0 | dbg_imatchB0 | dbg_lmatch00 | dbg_lmatch01 | dbg_lmatch02 | dbg_smatch00 | dbg_smatch01 | dbg_smatch02;
wire dbg_stat1 = dbg_imatchA1 | dbg_imatchB1 | dbg_lmatch10 | dbg_lmatch11 | dbg_lmatch12 | dbg_smatch10 | dbg_smatch11 | dbg_smatch12;
wire dbg_stat2 = dbg_imatchA2 | dbg_imatchB2 | dbg_lmatch20 | dbg_lmatch21 | dbg_lmatch22 | dbg_smatch20 | dbg_smatch21 | dbg_smatch22;
wire dbg_stat3 = dbg_imatchA3 | dbg_imatchB3 | dbg_lmatch30 | dbg_lmatch31 | dbg_lmatch32 | dbg_smatch30 | dbg_smatch31 | dbg_smatch32;
assign dbg_stat1x = {dbg_stat3,dbg_stat2,dbg_stat1,dbg_stat0};
wire debug_on = |dbg_ctrl[3:0]|dbg_ctrl[7]|dbg_ctrl[63];

always_comb
begin
    if (dbg_ctrl[0] && dbg_ctrl[17:16]==2'b00 && fetchbuf0_pc==dbg_adr0)
        dbg_imatchA0 = TRUE;
    if (dbg_ctrl[1] && dbg_ctrl[21:20]==2'b00 && fetchbuf0_pc==dbg_adr1)
        dbg_imatchA1 = TRUE;
    if (dbg_ctrl[2] && dbg_ctrl[25:24]==2'b00 && fetchbuf0_pc==dbg_adr2)
        dbg_imatchA2 = TRUE;
    if (dbg_ctrl[3] && dbg_ctrl[29:28]==2'b00 && fetchbuf0_pc==dbg_adr3)
        dbg_imatchA3 = TRUE;
    if (dbg_imatchA0|dbg_imatchA1|dbg_imatchA2|dbg_imatchA3)
        dbg_imatchA = TRUE;
end

always_comb
begin
    if (dbg_ctrl[0] && dbg_ctrl[17:16]==2'b00 && fetchbuf1_pc==dbg_adr0)
        dbg_imatchB0 = TRUE;
    if (dbg_ctrl[1] && dbg_ctrl[21:20]==2'b00 && fetchbuf1_pc==dbg_adr1)
        dbg_imatchB1 = TRUE;
    if (dbg_ctrl[2] && dbg_ctrl[25:24]==2'b00 && fetchbuf1_pc==dbg_adr2)
        dbg_imatchB2 = TRUE;
    if (dbg_ctrl[3] && dbg_ctrl[29:28]==2'b00 && fetchbuf1_pc==dbg_adr3)
        dbg_imatchB3 = TRUE;
    if (dbg_imatchB0|dbg_imatchB1|dbg_imatchB2|dbg_imatchB3)
        dbg_imatchB = TRUE;
end
`endif

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

// hirq squashes the pc increment if there's an irq.
wire hirq = (irq_i > im) && ~int_commit;
always_comb
if (hirq)
	insn0 <= {13'd0,irq_i,3'b1,vec_i,OP_BRK};
else if (phit) begin
	if (insn0a[6:0]==OP_BRK && insn0a[23:19]==5'd0)
		insn0 <= {13'd1,3'd0,3'b0,`FLT_PRIV,OP_BRK};
	else
    	insn0 <= insn0a;
end
else
    insn0 <= 32'hFFFFFFFF;	// NOP
always_comb
if (hirq & ~thread_en)
    insn1 <= {13'd0,irq_i,3'b1,vec_i,OP_BRK};
else if (phit) begin
	if (insn1a[6:0]==OP_BRK && insn1a[23:19]==5'd0)
		insn1 <= {13'd1,3'd0,3'b0,`FLT_PRIV,OP_BRK};
	else
	    insn1 <= insn1a;
end
else
    insn1 <= 32'hFFFFFFFF;

wire [63:0] dc0_out, dc1_out, dc2_out;
assign rdat0 = dram0_unc ? xdati : dc0_out;
assign rdat1 = dram1_unc ? xdati : dc1_out;
assign rdat2 = dram2_unc ? xdati : dc2_out;

reg [1:0] dccnt;
wire dhit0, dhit1, dhit2;
wire dhit00, dhit10, dhit20;
wire dhit01, dhit11, dhit21;
reg [31:0] dc_wadr;
reg [63:0] dc_wdat;
reg isStore;

/*
Gam_dcache udc0
(
    .rst(rst),
    .wclk(clk),
    .wr((bstate==B2d && ack_i)||((bstate==B1||(bstate==B19 && isStore)) && dhit0)),
    .sel(sel_o),
    .wadr({pcr[5:0],adr_o}),
    .i(bstate==B2d ? dat_i : dat_o),
    .rclk(clk),
    .rdsize(dram0_memsize),
    .radr({pcr[5:0],dram0_addr}),
    .o(dc0_out),
    .hit(),
    .hit0(dhit0),
    .hit1()
);
Gam_dcache udc1
(
    .rst(rst),
    .wclk(clk),
    .wr((bstate==B2d && ack_i)||((bstate==B1||(bstate==B19 && isStore)) && dhit1)),
    .sel(sel_o),
    .wadr({pcr[5:0],adr_o}),
    .i(bstate==B2d ? dat_i : dat_o),
    .rclk(clk),
    .rdsize(dram1_memsize),
    .radr({pcr[5:0],dram1_addr}),
    .o(dc1_out),
    .hit(),
    .hit0(dhit1),
    .hit1()
);
Gam_dcache udc2
(
    .rst(rst),
    .wclk(clk),
    .wr((bstate==B2d && ack_i)||((bstate==B1||(bstate==B19 && isStore)) && dhit2)),
    .sel(sel_o),
    .wadr({pcr[5:0],adr_o}),
    .i(bstate==B2d ? dat_i : dat_o),
    .rclk(clk),
    .rdsize(dram2_memsize),
    .radr({pcr[5:0],dram2_addr}),
    .o(dc2_out),
    .hit(),
    .hit0(dhit2),
    .hit1()
);
*/

function QNDX idp1;
input QNDX id;
case(id)
3'd0:	idp1 = 3'd1;
3'd1:	idp1 = 3'd2;
3'd2:	idp1 = 3'd3;
3'd3:	idp1 = 3'd4;
3'd4:	idp1 = 3'd5;
3'd5:	idp1 = 3'd6;
3'd6:	idp1 = 3'd7;
3'd7:	idp1 = 3'd0;
endcase
endfunction

function QNDX idp2;
input QNDX id;
case(id)
3'd0:	idp2 = 3'd2;
3'd1:	idp2 = 3'd3;
3'd2:	idp2 = 3'd4;
3'd3:	idp2 = 3'd5;
3'd4:	idp2 = 3'd6;
3'd5:	idp2 = 3'd7;
3'd6:	idp2 = 3'd0;
3'd7:	idp2 = 3'd1;
endcase
endfunction

function QNDX idp3;
input QNDX id;
case(id)
3'd0:	idp3 = 3'd3;
3'd1:	idp3 = 3'd4;
3'd2:	idp3 = 3'd5;
3'd3:	idp3 = 3'd6;
3'd4:	idp3 = 3'd7;
3'd5:	idp3 = 3'd0;
3'd6:	idp3 = 3'd1;
3'd7:	idp3 = 3'd2;
endcase
endfunction

function QNDX idp4;
input QNDX id;
case(id)
3'd0:	idp4 = 3'd4;
3'd1:	idp4 = 3'd5;
3'd2:	idp4 = 3'd6;
3'd3:	idp4 = 3'd7;
3'd4:	idp4 = 3'd0;
3'd5:	idp4 = 3'd1;
3'd6:	idp4 = 3'd2;
3'd7:	idp4 = 3'd3;
endcase
endfunction

function QNDX idp5;
input QNDX id;
case(id)
3'd0:	idp5 = 3'd5;
3'd1:	idp5 = 3'd6;
3'd2:	idp5 = 3'd7;
3'd3:	idp5 = 3'd0;
3'd4:	idp5 = 3'd1;
3'd5:	idp5 = 3'd2;
3'd6:	idp5 = 3'd3;
3'd7:	idp5 = 3'd4;
endcase
endfunction

function QNDX idp6;
input QNDX id;
case(id)
3'd0:	idp6 = 3'd6;
3'd1:	idp6 = 3'd7;
3'd2:	idp6 = 3'd0;
3'd3:	idp6 = 3'd1;
3'd4:	idp6 = 3'd2;
3'd5:	idp6 = 3'd3;
3'd6:	idp6 = 3'd4;
3'd7:	idp6 = 3'd5;
endcase
endfunction

function QNDX idp7;
input QNDX id;
case(id)
3'd0:	idp7 = 3'd7;
3'd1:	idp7 = 3'd0;
3'd2:	idp7 = 3'd1;
3'd3:	idp7 = 3'd2;
3'd4:	idp7 = 3'd3;
3'd5:	idp7 = 3'd4;
3'd6:	idp7 = 3'd5;
3'd7:	idp7 = 3'd6;
endcase
endfunction

function QNDX idm1;
input QNDX id;
case(id)
3'd0:	idm1 = 3'd7;
3'd1:	idm1 = 3'd0;
3'd2:	idm1 = 3'd1;
3'd3:	idm1 = 3'd2;
3'd4:	idm1 = 3'd3;
3'd5:	idm1 = 3'd4;
3'd6:	idm1 = 3'd5;
3'd7:	idm1 = 3'd6;
endcase
endfunction

function [RBIT:0] fnRa;
input [31:0] isn;
case(isn[6:0])
OP_Bcc:		fnRa = isn[11: 7];
default:  fnRa = isn[16:12];
endcase
endfunction

function [RBIT:0] fnRb;
input [31:0] isn;
case(isn[6:0])
OP_Bcc:		fnRb = isn[16:12];
default:  fnRb = isn[21:17];
endcase
endfunction

function [RBIT:0] fnRc;
input [31:0] isn;
fnRc = isn[28:24];
endfunction

// 00 to 31		GPRs
// 32 to 47		PRs
// 48 to 50		LRs
// 64 to 95		FPRs
// 96 to 127	VRs

function [6:0] fnRt;
input [63:0] isn;
input thrd;
casez(isn[6:0])
OP_PR:
	case(isn[25:21])
	OP_PRADD,OP_PRAND,OP_PRANDN,OP_PROR,OP_PREOR,
	OP_PRASL,OP_PRLSR,OP_MTPR,OP_PRLDI,OP_PRROL,OP_PRROR,
	OP_PRSUB:	
		fnRt = {3'b010,isn[10:7]};
	OP_PRFIRST,OP_PRLAST,OP_MFPR,OP_PRCNTPOP:
		fnRt = {2'b00,isn[11:7]};
	default:	fnRt = 'd0;
	endcase
OP_PRFILL:	fnRt = {3'b010,isn[10:7]};
OP_ADD,OP_SUB,OP_CMP,
OP_AND,OP_OR,OP_EOR,
OP_NAND,OP_NOR,OP_ENOR,
OP_MUL,OP_DIV:
	casez(ir[31:29])
	3'b00?:	fnRt = {2'b00,isn[11:7]};
	default:	fnRt = {2'b11,isn[11:7]};
	endcase
OP_R2V:
	case(isn[25:22])
	OP_V2BITS:	fnRt = {2'b00,isn[11:7]};
	OP_V2BITSPR:	fnRt = {3'b010,isn[10:7]};
	OP_VEINS:	fnRt = {2'b10,isn[11:7]};
	OP_VEX:	fnRt = {2'b00,isn[11:7]};
	OP_VGIDX:	fnRt = {2'b10,isn[11:7]};
	OP_VSHLV,OP_VSHLVI: fnRt = {2'b10,isn[11:7]};
	OP_VSHRV,OP_VSHRVI: fnRt = {2'b10,isn[11:7]};
	default:	fnRt = 'd0;
	endcase
OP_R2S:
	case(isn[31:29])
	3'b00?:	fnRt = {2'b00,isn[11:7]};
	default:	fnRt = {2'b10,isn[11:7]};
	endcase
OP_R1:
	case(isn[31:29])
	3'b00?:	fnRt = {2'b00,isn[11:7]};
	default:	fnRt = {2'b10,isn[11:7]};
	endcase
OP_R2:    
	case(isn[25:22])
		`MOV:
			case(isn[25:23])
			3'd0:	fnRt = {isn[21:16],1'b0,isn[21:17]};
			3'd1:	fnRt = {rgs[thrd],1'b0,isn[21:17]};
			3'd2:	fnRt = {rs_stack[thrd][5:0],1'b0,isn[21:17]};
			3'd3:	fnRt = {rgs[thrd],1'b0,isn[21:17]};
			3'd4:	fnRt = {rgs[thrd][5:1],1'b1,1'b0,isn[21:17]};
			3'd5:	fnRt = {rgs[thrd],1'b0,isn[21:17]};
			3'd6:	fnRt = {rgs[thrd][5:1],1'b1,1'b0,isn[21:17]};
			default:fnRt = {rgs[thrd],1'b0,isn[21:17]};
			endcase
        `VMOV:
            case (isn[`INSTRUCTION_S1])
            5'h0:   fnRt = {6'h3F,1'b1,isn[21:17]};
            5'h1:   fnRt = {rgs[thrd],1'b0,isn[21:17]};
            default:	fnRt = 12'h000;
            endcase
        `R1:    
        	case(isn[20:16])
        	`CNTLO,`CNTLZ,`CNTPOP,`ABS,`NOT:
        		fnRt = {rgs[thrd],1'b0,isn[21:17]};
        	`MEMDB,`MEMSB,`SYNC:
        		fnRt = 12'd0;
        	default:	fnRt = 12'd0;
        	endcase
        `CMOVEQ:    fnRt = {rgs[thrd],1'b0,isn[`INSTRUCTION_S1]};
        `CMOVNE:    fnRt = {rgs[thrd],1'b0,isn[`INSTRUCTION_S1]};
        `MUX:       fnRt = {rgs[thrd],1'b0,isn[`INSTRUCTION_S1]};
        `MIN:       fnRt = {rgs[thrd],1'b0,isn[`INSTRUCTION_S1]};
        `MAX:       fnRt = {rgs[thrd],1'b0,isn[`INSTRUCTION_S1]};
        `LVX:       fnRt = {vqei,1'b1,isn[20:16]};
        OP_SHIFT,OP_SHIFTB,OP_SHIFTC,OP_SHIFTH:
        			fnRt = isn[25] ? {rgs[thrd],1'b0,isn[21:17]} : {rgs[thrd],1'b0,isn[28:24]};
        `SEI:		fnRt = {rgs[thrd],1'b0,isn[21:17]};
        `WAIT,`RTI,OP_CHK,
        OP_STBX,OP_STWX,OP_STTX,OP_STOX,OP_STOCX,OP_CACHEX:
        			fnRt = 12'd0;
        default:    fnRt = {rgs[thrd],1'b0,isn[28:24]};
        endcase
OP_FLT2:
	case(isn[25:22])
	OP_FSCALEB,OP_FMIN,OP_FMAX,OP_FADD,OP_FSUB,OP_FMUL,OP_FDIV,
	OP_FNEXT,OP_FREM:
		fnRt = {2'b10,isn[11:7]};					// Fn
	OP_FCMP:	fnRt = {2'b00,isn[11:7]};	// Rn
	OP_FSEQ,OP_FSNE,OP_FSLT,OP_FSLE:
		fnRt = {2'b010,isn[10:7]};				// PRn
	default:	fnRt = 'd0;
	endcase
OP_FLT2I:
	case(isn[55:52])
	OP_FADDI,OP_FSUBI,OP_FMINI,OP_FMAXI,OP_FMULI,OP_FDIVI,
	OP_FREMI:
		fnRt = {2'b10,isn[11:7]};					// Fn
	OP_FCMPI:	fnRt = {2'b00,isn[11:7]};	// Rn
	OP_FSEQI,OP_FSNEI,OP_FSLTI,OP_FSLEI,OP_FSGTI,OP_FSGEI:
		fnRt = {3'b010,isn[10:7]};				// PRn
	default:	fnRt = 'd0;
	endcase
		case(isn[31:26])
		`FTX,`FCX,`FEX,`FDX,`FRM:
					fnRt = 12'd0;
		`FSYNC:		fnRt = 12'd0;
		default:	fnRt = {rgs[thrd][5:1],1'b1,1'b0,isn[28:24]};
		endcase
OP_BRK:	fnRt = 12'd0;
`REX:	fnRt = 12'd0;
OP_CHK:	fnRt = 'd0;
OP_Bcc: fnRt = 'd0;
OP_STB,OP_STW,OP_STT,OP_STO,OP_STH,
OP_FSTH,OP_FSTS,OP_FSTD,OP_FSTQ,
OP_CACHE:
		fnRt = 'd0;
OP_JSR:	fnRt = 'd0;
	case(isn[8:7])
	2'b00:	fnRt = 'd0;
	2'b01:	fnRt = 7'd48;
	2'b10:	fnRt = 7'd49;
	2'b11:	fnRt = 7'd50;
	endcase
OP_RTD: fnRt = 7'd31;
`AMO:	fnRt = isn[31] ? {rgs[thrd],1'b0,isn[21:17]} : {rgs[thrd],1'b0,isn[28:24]};
default:    fnRt = {rgs[thrd],1'b0,isn[21:17]};
endcase
endfunction

// Determines which lanes of the target register get updated.
function [7:0] fnWe;
input [33:0] isn;
casez(isn[6:0])
OP_R2:
	case(isn[`INSTRUCTION_S2])
	`R1:
		case(isn[20:16])
		`ABS,`CNTLZ,`CNTLO,`CNTPOP:
			case(isn[23:21])
			3'b000: fnWe = 8'h01;
			3'b001:	fnWe = 8'h03;
			3'b010:	fnWe = 8'h0F;
			3'b011:	fnWe = 8'hFF;
			default:	fnWe = 8'hFF;
			endcase
		default: fnWe = 8'hFF;
		endcase
	OP_SHIFT:		fnWe = (~isn[25] & isn[21]) ? 8'hFF : 8'hFF;
	OP_SHIFTH:	fnWe = (~isn[25] & isn[21]) ? 8'hFF : 8'h0F;
	OP_SHIFTC:	fnWe = (~isn[25] & isn[21]) ? 8'hFF : 8'h03;
	OP_SHIFTB:	fnWe = (~isn[25] & isn[21]) ? 8'hFF : 8'h01;
	OP_ADD,OP_SUB,
	OP_AND,OP_OR,OP_EOR,
	`NAND,`NOR,`XNOR,
	`DIVMOD,`DIVMODU,`DIVMODSU,
	`MUL,`MULU,`MULSU:
		case(isn[23:21])
		3'b000: fnWe = 8'h01;
		3'b001:	fnWe = 8'h03;
		3'b010:	fnWe = 8'h0F;
		3'b011:	fnWe = 8'hFF;
		default:	fnWe = 8'hFF;
		endcase
	OP_CMP:
		case(isn[22:21])
		2'b00:	fnWe = 8'h01;
		2'b01:	fnWe = 8'h03;
		2'b10:	fnWe = 8'h0F;
		2'b11:	fnWe = 8'hFF;
		endcase
OP_LDX,
OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDOU,OP_LDH:
	fnWe = 1'b1;
default:	fnWe = 1'b0;
endcase
endfunction

// Detect if a source is automatically valid
function Source1Valid;
input [33:0] isn;
reg [RBIT:0] Rac;
casez(isn[6:0])
OP_BRK:   Source1Valid = TRUE;
OP_Bcc:   Source1Valid = isn[16:12]==5'd0;
OP_BccR:  Source1Valid = isn[16:12]==5'd0;
OP_BBc:   Source1Valid = isn[16:12]==5'd0;
`BEQI:  Source1Valid = isn[16:12]==5'd0;
OP_CHK:   Source1Valid = isn[16:12]==5'd0;
OP_R2:    case(isn[`INSTRUCTION_S2])
        OP_SHIFT:    Source1Valid = isn[16:12]==5'd0;
        OP_SHIFTH:   Source1Valid = isn[16:12]==5'd0;
        OP_SHIFTC:   Source1Valid = isn[16:12]==5'd0;
        OP_SHIFTB:   Source1Valid = isn[16:12]==5'd0;
        default:   Source1Valid = isn[16:12]==5'd0;
        endcase
OP_ADDI:  Source1Valid = isn[16:12]==5'd0;
OP_CMPI:  Source1Valid = isn[16:12]==5'd0;
`CMPUI: Source1Valid = isn[16:12]==5'd0;
OP_ANDI:  Source1Valid = isn[16:12]==5'd0;
OP_ORI:   Source1Valid = isn[16:12]==5'd0;
OP_EORI:  Source1Valid = isn[16:12]==5'd0;
OP_MULUI: Source1Valid = isn[16:12]==5'd0;
`AMO: 	Source1Valid = isn[16:12]==5'd0;
OP_LDB:    Source1Valid = isn[16:12]==5'd0;
OP_LDBO:   Source1Valid = isn[16:12]==5'd0;
OP_LDBU:   Source1Valid = isn[16:12]==5'd0;
OP_LDW:    Source1Valid = isn[16:12]==5'd0;
OP_LDWO:   Source1Valid = isn[16:12]==5'd0;
OP_LDWU:   Source1Valid = isn[16:12]==5'd0;
OP_LDT:    Source1Valid = isn[16:12]==5'd0;
OP_LDTO:   Source1Valid = isn[16:12]==5'd0;
OP_LDTU:   Source1Valid = isn[16:12]==5'd0;
OP_LDO:    Source1Valid = isn[16:12]==5'd0;
OP_LDOR:   Source1Valid = isn[16:12]==5'd0;
`LV:    Source1Valid = isn[16:12]==5'd0;
`LVx:   Source1Valid = isn[16:12]==5'd0;
OP_STB:    Source1Valid = isn[16:12]==5'd0;
OP_STW:    Source1Valid = isn[16:12]==5'd0;
OP_STT:    Source1Valid = isn[16:12]==5'd0;
OP_STO:    Source1Valid = isn[16:12]==5'd0;
OP_STOC:   Source1Valid = isn[16:12]==5'd0;
`SV:    Source1Valid = isn[16:12]==5'd0;
`CAS:   Source1Valid = isn[16:12]==5'd0;
`JAL:   Source1Valid = isn[16:12]==5'd0;
`RET:   Source1Valid = isn[16:12]==5'd0;
`CSRRW: Source1Valid = isn[16:12]==5'd0;
`BITFIELD: 	case(isn[31:28])
			`BFINSI:	Source1Valid = TRUE;
			default:	Source1Valid = isn[16:12]==5'd0;
			endcase
`VECTOR:
			Source1Valid = FALSE;
default:    Source1Valid = TRUE;
endcase
endfunction
  
function Source2Valid;
input [33:0] isn;
casez(isn[6:0])
OP_BRK:   Source2Valid = TRUE;
OP_Bcc:   Source2Valid = isn[21:17]==5'd0;
OP_BccR:  Source2Valid = isn[21:17]==5'd0;
OP_BBc:   Source2Valid = TRUE;
`BEQI:  Source2Valid = TRUE;
OP_CHK:   Source2Valid = isn[21:17]==5'd0;
OP_R2:    case(isn[`INSTRUCTION_S2])
        `R1:       Source2Valid = TRUE;
        OP_SHIFT:	   Source2Valid = isn[25] ? 1'b1 : isn[21:17]==5'd0;
        OP_SHIFTH:   Source2Valid = isn[25] ? 1'b1 : isn[21:17]==5'd0;
        OP_SHIFTC:   Source2Valid = isn[25] ? 1'b1 : isn[21:17]==5'd0;
        OP_SHIFTB:   Source2Valid = isn[25] ? 1'b1 : isn[21:17]==5'd0;
        `LVX,`SVX: Source2Valid = FALSE;
        default:   Source2Valid = isn[21:17]==5'd0;
        endcase
OP_ADDI:  Source2Valid = TRUE;
OP_CMPI:  Source2Valid = TRUE;
`CMPUI: Source2Valid = TRUE;
OP_ANDI:  Source2Valid = TRUE;
OP_ORI:   Source2Valid = TRUE;
OP_EORI:  Source2Valid = TRUE;
OP_MULUI: Source2Valid = TRUE;
`QOPI:	Source2Valid = isn[21:17]==5'd0;
OP_LDB:    Source2Valid = TRUE;
OP_LDBO:   Source2Valid = TRUE;
OP_LDBU:   Source2Valid = TRUE;
OP_LDW:    Source2Valid = TRUE;
OP_LDWO:   Source2Valid = TRUE;
OP_LDWU:   Source2Valid = TRUE;
OP_LDT:    Source2Valid = TRUE;
OP_LDTO:   Source2Valid = TRUE;
OP_LDTU:   Source2Valid = TRUE;
OP_LDO:    Source2Valid = TRUE;
OP_LDOR:   Source2Valid = TRUE;
`LVx:   Source2Valid = TRUE;
OP_STB:    Source2Valid = isn[21:17]==5'd0;
OP_STW:    Source2Valid = isn[21:17]==5'd0;
OP_STT:    Source2Valid = isn[21:17]==5'd0;
OP_STO:    Source2Valid = isn[21:17]==5'd0;
OP_STOC:   Source2Valid = isn[21:17]==5'd0;
`CAS:   Source2Valid = isn[21:17]==5'd0;
`JAL:   Source2Valid = TRUE;
`RET:   Source2Valid = isn[21:17]==5'd0;
`VECTOR:
		    case(isn[`INSTRUCTION_S2])
            `VABS:  Source2Valid = TRUE;
            `VMAND,`VMOR,`VMXOR,`VMXNOR,`VMPOP:
                Source2Valid = FALSE;
            `VADDS,`VSUBS,`VANDS,`VORS,`VXORS:
                Source2Valid = isn[21:17]==5'd0;
            `VBITS2V:   Source2Valid = TRUE;
            `V2BITS:    Source2Valid = isn[21:17]==5'd0;
            `VSHL,`VSHR,`VASR:  Source2Valid = isn[22:21]==2'd2;
            default:    Source2Valid = FALSE;
            endcase
`LV:        Source2Valid = TRUE;
`SV:        Source2Valid = FALSE;
`AMO:		Source2Valid = isn[31] || isn[21:17]==5'd0;
default:    Source2Valid = TRUE;
endcase
endfunction

function Source3Valid;
input [31:0] isn;
case(isn[6:0])
`VECTOR:
    case(isn[`INSTRUCTION_S2])
    `VEX:       Source3Valid = TRUE;
    default:    Source3Valid = TRUE;
    endcase
OP_BccR:  Source3Valid = isn[28:24]==5'd0;
OP_CHK:   Source3Valid = isn[28:24]==5'd0;
OP_R2:
    case(isn[`INSTRUCTION_S2])
    OP_STBX:       Source3Valid = isn[28:24]==5'd0;
    OP_STWX:       Source3Valid = isn[28:24]==5'd0;
    OP_STTX:       Source3Valid = isn[28:24]==5'd0;
    OP_STOX:       Source3Valid = isn[28:24]==5'd0;
    OP_STOCX:      Source3Valid = isn[28:24]==5'd0;
    `CASX:      Source3Valid = isn[28:24]==5'd0;
    `CMOVEQ,`CMOVNE,`MAJ:  Source3Valid = isn[28:24]==5'd0;
    default:    Source3Valid = TRUE;
    endcase
default:    Source3Valid = TRUE;
endcase
endfunction

// Used to indicate to the queue logic that the instruction needs to be
// recycled to the queue VL number of times.
function IsVector;
input [31:0] isn;
case(isn[6:0])
OP_R2:        
	case(isn[`INSTRUCTION_S2])
	`LVX,`SVX:  IsVector = TRUE;
	default:    IsVector = FALSE;
	endcase
`VECTOR:
			case(isn[`INSTRUCTION_S2])
			`VMxx:
				case(isn[25:23])
            	`VMAND,`VMOR,`VMXOR,`VMXNOR,`VMPOP:
                        IsVector = FALSE;
                default:	IsVector = TRUE;
                endcase
            `VEINS:     IsVector = FALSE;
            `VEX:       IsVector = FALSE;
            default:    IsVector = TRUE;
            endcase
`LV,`SV:    IsVector = TRUE;
default:    IsVector = FALSE;
endcase
endfunction

function IsVeins;
input [31:0] isn;
case(isn[6:0])
`VECTOR:    IsVeins = isn[`INSTRUCTION_S2]==`VEINS;
default:    IsVeins = FALSE;
endcase
endfunction

function IsVex;
input [31:0] isn;
case(isn[6:0])
`VECTOR:    IsVex = isn[`INSTRUCTION_S2]==`VEX;
default:    IsVex = FALSE;
endcase
endfunction

function IsVCmprss;
input [31:0] isn;
case(isn[6:0])
`VECTOR:    IsVCmprss = isn[`INSTRUCTION_S2]==`VCMPRSS || isn[`INSTRUCTION_S2]==`VCIDX;
default:    IsVCmprss = FALSE;
endcase
endfunction

function IsVShifti;
input [31:0] isn;
case(isn[6:0])
`VECTOR:
		    case(isn[`INSTRUCTION_S2])
            `VSHL,`VSHR,`VASR:
                IsVShifti = {isn[25],isn[22]}==2'd2;
            default:    IsVShifti = FALSE;
            endcase    
default:    IsVShifti = FALSE;
endcase
endfunction

function IsVLS;
input [31:0] isn;
case(isn[6:0])
OP_R2:
    case(isn[`INSTRUCTION_S2])
    `LVX,`SVX,`LVWS,`SVWS:  IsVLS = TRUE;
    default:    IsVLS = FALSE;
    endcase
`LV,`SV:    IsVLS = TRUE;
default:    IsVLS = FALSE;
endcase
endfunction

function [1:0] fnM2;
input [31:0] isn;
case(isn[6:0])
OP_R2:    fnM2 = isn[24:23];
default:    fnM2 = 2'b00;
endcase
endfunction

function IsALU;
input [33:0] isn;
casez(isn[6:0])
OP_R2:    case(isn[`INSTRUCTION_S2])
		`VMOV:		IsALU = TRUE;
        `RTI:       IsALU = FALSE;
        default:    IsALU = TRUE;
        endcase
OP_BRK: IsALU = FALSE;
OP_Bcc: IsALU = FALSE;
OP_CHK: IsALU = FALSE;
OP_JSR: IsALU = FALSE;
OP_RTx: IsALU = FALSE;
`VECTOR:
			case(isn[`INSTRUCTION_S2])
            `VSHL,`VSHR,`VASR:  IsALU = TRUE;
            default:    IsALU = isn[22:21]==2'b00;  // Integer
            endcase
OP_FLT2: IsALU = FALSE; 
OP_FLT2I: IsALU = FALSE; 
OP_FLT3: IsALU = FALSE; 
default:    IsALU = TRUE;
endcase
endfunction

function IsFPU;
input [31:0] isn;
case(isn[6:0])
OP_FLT2: IsFPU = TRUE;
OP_FLT2I:	IsFPU = TRUE;
OP_FLT3: IsFPU = TRUE;
`VECTOR:
		    case(isn[`INSTRUCTION_S2])
            `VSHL,`VSHR,`VASR:  IsFPU = FALSE;
            default:    IsFPU = isn[22:21]==2'b01;
            endcase
default:    IsFPU = FALSE;
endcase

endfunction

function HasConst;
input [33:0] isn;
casez(isn[6:0])
OP_BRK:   HasConst = FALSE;
OP_Bcc:   HasConst = FALSE;
OP_BccR:  HasConst = FALSE;
OP_BBc:   HasConst = FALSE;
OP_R2:    HasConst = FALSE;
/*
		case(isn[`INSTRUCTION_S2])
        OP_STTLI:  HasConst = TRUE;
        OP_STTRI:  HasConst = TRUE;
        default: HasConst = FALSE;
        endcase*/
OP_ADDI:  HasConst = TRUE;
OP_CMPI:  HasConst = TRUE;
OP_ANDI:  HasConst = TRUE;
OP_ORI:  HasConst = TRUE;
OP_EORI:  HasConst = TRUE;
OP_MULUI: HasConst = TRUE;
OP_MULI:  HasConst = TRUE;
OP_DIVUI: HasConst = TRUE;
OP_DIVI:  HasConst = TRUE;
`MODUI: HasConst = TRUE;
`MODI:  HasConst = TRUE;
OP_LDB:    HasConst = TRUE;
OP_LDBO:   HasConst = TRUE;
OP_LDBU:   HasConst = TRUE;
OP_LDW:    HasConst = TRUE;
OP_LDWO:   HasConst = TRUE;
OP_LDWU:   HasConst = TRUE;
OP_LDT:  HasConst = TRUE;
OP_LDTO:  HasConst = TRUE;
OP_LDTU:  HasConst = TRUE;
OP_LDO:  HasConst = TRUE;
OP_LDOR: HasConst = TRUE;
OP_STB:  HasConst = TRUE;
OP_STW:  HasConst = TRUE;
OP_STT:  HasConst = TRUE;
OP_STO:  HasConst = TRUE;
OP_STOC:   HasConst = TRUE;
`JAL:   HasConst = TRUE;
`CALL:  HasConst = TRUE;
`RET:   HasConst = TRUE;
`SccI:	HasConst = TRUE;
default:    HasConst = FALSE;
endcase
endfunction

function IsMem;
input [31:0] isn;
case(isn[6:0])
OP_LDX,OP_STX:
  IsMem = TRUE;
OP_LDB:   IsMem = TRUE;
OP_LDBU:  IsMem = TRUE;
OP_LDW:   IsMem = TRUE;
OP_LDWU:  IsMem = TRUE;
OP_LDT:   IsMem = TRUE;
OP_LDTU:	IsMem = TRUE;
OP_LDO:		IsMem = TRUE;
OP_LDOU:	IsMem = TRUE;
OP_LDH:		IsMem = TRUE;
OP_STB:   IsMem = TRUE;
OP_STW:   IsMem = TRUE;
OP_STT:   IsMem = TRUE;
OP_STO:   IsMem = TRUE;
OP_STH:   IsMem = TRUE;
default:  IsMem = FALSE;
endcase
endfunction

function IsMemNdx;
input [33:0] isn;
case(isn[6:0])
OP_LDX:
	casez(isn[58:53])
	6'b011111:	IsMemNdx = FALSE;	// CAS
	6'b100???:	IsMemNdx = FALSE;	// AMO
	default: IsMemNdx = TRUE;
	endcase
OP_STX:	IsMemNdx = TRUE;
default:    IsMemNdx = FALSE;
endcase
endfunction

function IsLoad;
input [31:0] isn;
case(isn[6:0])
OP_LDX:		IsLoad = TRUE;
OP_LDB:   IsLoad = TRUE;
OP_LDBU:  IsLoad = TRUE;
OP_LDW:   IsLoad = TRUE;
OP_LDWU:  IsLoad = TRUE;
OP_LDT:   IsLoad = TRUE;
OP_LDTU:  IsLoad = TRUE;
OP_LDO:   IsLoad = TRUE;
OP_LDOU:	IsLoad = TRUE;
OP_LDH:		IsLoad = TRUE;
default:    IsLoad = FALSE;
endcase
endfunction

function IsVolatileLoad;
input [63:0] isn;
case(isn[6:0])
OP_LDX:	IsVolatileLoad = isn[51:50]==2'b00;
default:	isn[18:17]==2'b00;
endcase
endfunction

function memsz_t MemSize;
input [63:0] isn;
case(isn[6:0])
OP_LDB,OP_LDBU,OP_STB: MemSize = byt;
OP_LDW,OP_LDWU,OP_STW: MemSize = wyde;
OP_LDT,OP_LDTU,OP_STT: MemSize = tetra;
OP_LDO,OP_LDOU,OP_STO: MemSize = octa;
OP_LDH,OP_STH: MemSize = hexi;
OP_LDX:
	casez(isn[58:53])
	6'b00000?:	MemSize = byt;
	6'b00001?:	MemSize = wyde;
	6'b00010?:	MemSize = tetra;
	6'b00011?:	MemSize = octa;
	6'b00100?:	MemSize = hexi;
	6'b001011:	MemSize = hexi;
	6'b001100:	MemSize = tetra;
	6'b001101:	MemSize = octa;
	6'b010010:	MemSize = hexi;
	6'b010100:	MemSize = tetra;
	6'b010110:	MemSize = octa;		// FLDDX
	6'b011000:	MemSize = hexi;		// FLDQX
	6'b011001:	MemSize = hexi;		// DFLD
	6'b011111:	MemSize = hexi;		// CAS
	6'b100???:	MemSize = hexi;
	default:	MemSize = hexi;
	endcase
default:    MemSize = hexi;
endcase
endfunction

function IsStore;
input [33:0] isn;
case(isn[6:0])
OP_STX:	IsStore = TRUE;
OP_STB: IsStore = TRUE;
OP_STW: IsStore = TRUE;
OP_STT: IsStore = TRUE;
OP_STO: IsStore = TRUE;
OP_STH:	IsStore = TRUE;
default:    IsStore = FALSE;
endcase
endfunction

function IsCAS;
input [63:0] isn;
case(isn[6:0])
OP_LDX:
  case(isn[58:53])
  OP_CAS:	IsCAS = TRUE;
  default:	IsCAS = FALSE;
  endcase
default:	IsCAS = FALSE;    
endcase
endfunction

function IsCompressed;
input [35:0] isn;
IsCompressed = (isn[6:3]==4'h2 || isn[6:3]==4'hD);
endfunction

function IsAMO;
input [63:0] isn;
case(isn[6:0])
OP_LDX:
	casez(isn[58:53])
	6'b100???:	IsAMO = TRUE;
	default:	IsAMO = FALSE;
	endcase
default:    IsAMO = FALSE;
endcase
endfunction

// Really IsPredictableBranch
// Does not include BccR's
function IsBranch;
input [31:0] isn;
casez(isn[6:0])
OP_BSR,
OP_BEQ,OP_BNE,
OP_BLT,OP_BGE,OP_BLE,OP_BGT,
OP_BBC,OP_BBS,OP_BBCI,OP_BBSI:
	IsBranch = TRUE;
default:    IsBranch = FALSE;
endcase
endfunction

function IsWait;
input [33:0] isn;
IsWait = isn[6:0]==OP_R2 && isn[`INSTRUCTION_S2]==`WAIT;
endfunction

function IsBrk;
input [33:0] isn;
IsBrk = isn[6:0]==OP_BRK;
endfunction

function IsRTI;
input [33:0] isn;
IsRTI = isn[6:0]==OP_R2 && isn[`INSTRUCTION_S2]==`RTI;
endfunction

function IsJAL;
input [33:0] isn;
IsJAL = isn[6:0]==`JAL;
endfunction

function IsCall;
input [33:0] isn;
IsCall = isn[6:0]==OP_JSR && ir[11:7] != 5'd0;
endfunction

function IsJmp;
input [33:0] isn;
IsJmp = isn[6:0]==OP_JSR && ir[11:7]==5'd0;
endfunction

function IsRet;
input [33:0] isn;
IsRet = isn[6:0]==`RET;
endfunction

function IsFlowCtrl;
input [31:0] isn;
casez(isn[6:0])
OP_BRK:    IsFlowCtrl = TRUE;
OP_R2:    case(isn[`INSTRUCTION_S2])
        `RTI:   IsFlowCtrl = TRUE;
        default:    IsFlowCtrl = FALSE;
        endcase
OP_Bcc:   IsFlowCtrl = TRUE;
OP_BccR:  IsFlowCtrl = TRUE;
OP_BBc:  IsFlowCtrl = TRUE;
OP_CHK:   IsFlowCtrl = TRUE;
OP_JSR:	IsFlowCtrl = TRUE;
`RET:   IsFlowCtrl = TRUE;
default:    IsFlowCtrl = FALSE;
endcase
endfunction

// fnCanException
//
// Used by memory issue logic.
// Returns TRUE if the instruction can cause an exception.
// In debug mode any instruction could potentially cause a breakpoint exception.
// Rather than check all the addresses for potential debug exceptions it's
// simpler to just have it so that all instructions could exception. This will
// slow processing down somewhat as stores will only be done at the head of the
// instruction queue, but it's debug mode so we probably don't care.
//
function fnCanException;
input [33:0] isn;
// ToDo add debug_on as input
`ifdef SUPPORT_DBG
if (debug_on)
    fnCanException = TRUE;
else
`endif
case(isn[6:0])
`FLOAT:
    case(isn[`INSTRUCTION_S2])
    `FDIV,`FMUL,`FADD,`FSUB,`FTX:
        fnCanException = TRUE;
    default:    fnCanException = FALSE;
    endcase
OP_ADDI,OP_DIVI,`MODI,OP_MULI:
    fnCanException = TRUE;
OP_R2:
    case(isn[`INSTRUCTION_S2])
    OP_ADD,OP_SUB,`MUL,`DIVMOD,`MULSU,`DIVMODSU:   fnCanException = TRUE;
    `RTI:   fnCanException = TRUE;
    default:    fnCanException = FALSE;
    endcase
default:
    fnCanException = IsMem(isn);
endcase
endfunction


function IsCache;
input [33:0] isn;
case(isn[6:0])
OP_R2:
    case(isn[`INSTRUCTION_S2])
    OP_CACHEX:    IsCache = TRUE;
    default:    IsCache = FALSE;
    endcase
OP_CACHE: IsCache = TRUE;
default: IsCache = FALSE;
endcase
endfunction

function [4:0] CacheCmd;
input [33:0] isn;
case(isn[6:0])
OP_R2:
    case(isn[`INSTRUCTION_S2])
    OP_CACHEX:    CacheCmd = isn[20:16];
    default:    CacheCmd = 5'd0;
    endcase
OP_CACHE: CacheCmd = isn[15:11];
default: CacheCmd = 5'd0;
endcase
endfunction

function IsSync;
input [31:0] isn;
IsSync = (isn[6:0]==OP_R2 && isn[`INSTRUCTION_S2]==`R1 && isn[25:21]==`SYNC); 
endfunction

function IsFSync;
input [33:0] isn;
IsFSync = (isn[6:0]==`FLOAT && isn[`INSTRUCTION_S2]==`FSYNC); 
endfunction

function IsMemdb;
input [33:0] isn;
IsMemdb = (isn[6:0]==OP_R2 && isn[`INSTRUCTION_S2]==`R1 && isn[25:21]==`MEMDB); 
endfunction

function IsMemsb;
input [33:0] isn;
IsMemsb = (isn[6:0]==OP_R2 && isn[`INSTRUCTION_S2]==`R1 && isn[25:21]==`MEMSB); 
endfunction

function IsSEI;
input [33:0] isn;
IsSEI = (isn[6:0]==OP_R2 && isn[`INSTRUCTION_S2]==`SEI); 
endfunction

function IsLV;
input [33:0] isn;
case(isn[6:0])
OP_R2:
    case(isn[`INSTRUCTION_S2])
    `LVX:   IsLV = TRUE;
    default:    IsLV = FALSE;
    endcase
`LV:        IsLV = TRUE;
default:    IsLV = FALSE;
endcase
endfunction

function IsRFW;
input [33:0] isn;
input [5:0] vqei;
input [5:0] vli;
input thrd;
if (fnRt(isn,vqei,vli,thrd)==12'd0) 
    IsRFW = FALSE;
else
casez(isn[6:0])
`VECTOR:
		    IsRFW = TRUE;
OP_R2:
    case(isn[`INSTRUCTION_S2])
    `R1:    IsRFW = TRUE;
    OP_ADD:   IsRFW = TRUE;
    OP_SUB:   IsRFW = TRUE;
    `CMP:   IsRFW = TRUE;
    `CMPU:  IsRFW = TRUE;
    OP_AND:   IsRFW = TRUE;
    OP_OR:    IsRFW = TRUE;
    OP_EOR:   IsRFW = TRUE;
    `MULU:  IsRFW = TRUE;
    `MULSU: IsRFW = TRUE;
    `MUL:   IsRFW = TRUE;
    `DIVMODU:  IsRFW = TRUE;
    `DIVMODSU: IsRFW = TRUE;
    `DIVMOD:IsRFW = TRUE;
    OP_LDBX:   IsRFW = TRUE;
    OP_LDBUX:  IsRFW = TRUE;
    OP_LDWX:   IsRFW = TRUE;
    OP_LDWUX:  IsRFW = TRUE;
    OP_LDTX:   IsRFW = TRUE;
    OP_LDTUX:  IsRFW = TRUE;
    OP_LDOX:   IsRFW = TRUE;
    OP_LDORX:  IsRFW = TRUE;
    `CASX:  IsRFW = TRUE;
    `MOV:	IsRFW = TRUE;
    `VMOV:	IsRFW = TRUE;
    OP_SHIFT,OP_SHIFTH,OP_SHIFTC,OP_SHIFTB:
	    	IsRFW = TRUE;
    `MIN,`MAX:    IsRFW = TRUE;
    `SEI:	IsRFW = TRUE;
    default:    IsRFW = FALSE;
    endcase
OP_BBc:
	case(isn[19:17])
	`IBNE:	IsRFW = TRUE;
	`DBNZ:	IsRFW = TRUE;
	default:	IsRFW = FALSE;
	endcase
`BITFIELD:  IsRFW = TRUE;
OP_ADDI:      IsRFW = TRUE;
OP_CMPI:      IsRFW = TRUE;
OP_ANDI:      IsRFW = TRUE;
OP_ORI:       IsRFW = TRUE;
OP_EORI:      IsRFW = TRUE;
OP_MULUI:     IsRFW = TRUE;
`MULSUI:    IsRFW = TRUE;
OP_MULI:      IsRFW = TRUE;
OP_DIVUI:     IsRFW = TRUE;
`DIVSUI:    IsRFW = TRUE;
OP_DIVI:      IsRFW = TRUE;
`MODUI:     IsRFW = TRUE;
`MODSUI:    IsRFW = TRUE;
`MODI:      IsRFW = TRUE;
`QOPI:		IsRFW = TRUE;
`JAL:       IsRFW = TRUE;
`CALL:      IsRFW = TRUE;  
`RET:       IsRFW = TRUE; 
OP_LDB:        IsRFW = TRUE;
OP_LDBO:       IsRFW = TRUE;
OP_LDBU:       IsRFW = TRUE;
OP_LDW:        IsRFW = TRUE;
OP_LDWO:       IsRFW = TRUE;
OP_LDWU:       IsRFW = TRUE;
OP_LDT:        IsRFW = TRUE;
OP_LDTO:       IsRFW = TRUE;
OP_LDTU:       IsRFW = TRUE;
OP_LDO:        IsRFW = TRUE;
OP_LDOR:       IsRFW = TRUE;
`CAS:       IsRFW = TRUE;
`AMO:		IsRFW = TRUE;
`CSRRW:		IsRFW = TRUE;
default:    IsRFW = FALSE;
endcase
endfunction

function IsShifti;
input [33:0] isn;
case(isn[6:0])
OP_R2:
    case(isn[`INSTRUCTION_S2])
    OP_SHIFT,OP_SHIFTH,OP_SHIFTC,OP_SHIFTB:
    	IsShifti = isn[25];
    default: IsShifti = FALSE;
    endcase
default: IsShifti = FALSE;
endcase
endfunction

function IsMul;
input [33:0] isn;
case(isn[6:0])
OP_R2:
    case(isn[`INSTRUCTION_S2])
    `MULU,`MULSU,`MUL: IsMul = TRUE;
    default:    IsMul = FALSE;
    endcase
OP_MULUI,`MULSUI,OP_MULI:  IsMul = TRUE;
default:    IsMul = FALSE;
endcase
endfunction

function IsDivmod;
input [33:0] isn;
case(isn[6:0])
OP_R2:
    case(isn[`INSTRUCTION_S2])
    `DIVMODU,`DIVMODSU,`DIVMOD: IsDivmod = TRUE;
    default: IsDivmod = FALSE;
    endcase
OP_DIVUI,`DIVSUI,OP_DIVI,`MODUI,`MODSUI,`MODI:  IsDivmod = TRUE;
default:    IsDivmod = FALSE;
endcase
endfunction

function IsAlu0Only;
input [33:0] isn;
case(isn[6:0])
OP_R2:
    case(isn[`INSTRUCTION_S2])
    `R1:        IsAlu0Only = TRUE;
    OP_SHIFT:     IsAlu0Only = TRUE;
    OP_LDBX,OP_LDBOX,OP_LDBUX,OP_LDWX,OP_LDWOX,OP_LDWUX,OP_LDTX,OP_LDTOX,OP_LDTUX,OP_LDOX,OP_LDORX:
    	IsAlu0Only = TRUE;
    OP_STBX,OP_STWX,OP_STTX,OP_STOX,OP_STOCX: IsAlu0Only = TRUE;
    `LVX,`SVX,`LVx:  IsAlu0Only = TRUE;
    `MULU,`MULSU,`MUL,
    `DIVMODU,`DIVMODSU,`DIVMOD: IsAlu0Only = TRUE;
    `MIN,`MAX:  IsAlu0Only = TRUE;
    default:    IsAlu0Only = FALSE;
    endcase
`VECTOR:
    case(isn[`INSTRUCTION_S2])
    `VSHL,`VSHR,`VASR:  IsAlu0Only = TRUE;
    default: IsAlu0Only = FALSE;
    endcase
`BITFIELD:  IsAlu0Only = TRUE;
OP_MULUI,`MULSUI,OP_MULI,
OP_DIVUI,`DIVSUI,OP_DIVI,
`MODUI,`MODSUI,`MODI:   IsAlu0Only = TRUE;
`CSRRW: IsAlu0Only = TRUE;
default:    IsAlu0Only = FALSE;
endcase
endfunction

function [7:0] fnSelect;
input [33:0] ins;
input [31:0] adr;
begin
	case(ins[6:0])
	OP_R2:
	   case(ins[`INSTRUCTION_S2])
       OP_LDBX,OP_LDBOX,OP_LDBUX,OP_STBX:
           case(adr[2:0])
           3'd0:    fnSelect = 8'h01;
           3'd1:    fnSelect = 8'h02;
           3'd2:    fnSelect = 8'h04;
           3'd3:    fnSelect = 8'h08;
           3'd4:    fnSelect = 8'h10;
           3'd5:    fnSelect = 8'h20;
           3'd6:    fnSelect = 8'h40;
           3'd7:    fnSelect = 8'h80;
           endcase
        OP_LDWX,OP_LDWOX,OP_LDWUX,OP_STWX:
            case(adr[2:1])
            2'd0:   fnSelect = 8'h03;
            2'd1:   fnSelect = 8'hC0;
            2'd2:   fnSelect = 8'h30;
            2'd3:   fnSelect = 8'hC0;
            endcase
    	OP_LDTX,OP_LDTOX,OP_LDTUX,OP_STTX:
           case(adr[2])
           1'b0:    fnSelect = 8'h0F;
           1'b1:    fnSelect = 8'hF0;
           endcase
       OP_LDOX,OP_STOX,OP_LDORX,OP_STOCX,`LVX,`SVX,`CASX:
           fnSelect = 8'hFF;
       default: fnSelect = 8'h00;
	   endcase
    OP_LDB,OP_LDBO,OP_LDBU,OP_STB:
		case(adr[2:0])
		3'd0:	fnSelect = 8'h01;
		3'd1:	fnSelect = 8'h02;
		3'd2:	fnSelect = 8'h04;
		3'd3:	fnSelect = 8'h08;
		3'd4:	fnSelect = 8'h10;
		3'd5:	fnSelect = 8'h20;
		3'd6:	fnSelect = 8'h40;
		3'd7:	fnSelect = 8'h80;
		endcase
    OP_LDW,OP_LDWO,OP_LDWU,OP_STW:
        case(adr[2:1])
        2'd0:   fnSelect = 8'h03;
        2'd1:   fnSelect = 8'hC0;
        2'd2:   fnSelect = 8'h30;
        2'd3:   fnSelect = 8'hC0;
        endcase
	OP_LDT,OP_LDTO,OP_LDTU,OP_STT:
		case(adr[2])
		1'b0:	fnSelect = 8'h0F;
		1'b1:	fnSelect = 8'hF0;
		endcase
	OP_LDO,OP_STO,OP_LDOR,OP_STOC,`CAS:   fnSelect = 8'hFF;
	`AMO:
		case(ins[23:21])
		3'd0:	fnSelect = 8'h01 << adr[2:0];
		3'd1:	fnSelect = 8'h03 << {adr[2:1],1'b0};
		3'd2:	fnSelect = 8'h0F << {adr[2],2'b00};
		3'd3:	fnSelect = 8'hFF;
		default:	fnSelect = 8'hFF;
		endcase
	default:	fnSelect = 8'h00;
	endcase
end
endfunction

function [63:0] fnDati;
input [33:0] ins;
input [31:0] adr;
input [63:0] dat;
case(ins[6:0])
OP_R2:
    case(ins[`INSTRUCTION_S2])
    OP_LDBX:
        case(adr[2:0])
        3'd0:   fnDati = {{56{dat[7]}},dat[7:0]};
        3'd1:   fnDati = {{56{dat[15]}},dat[15:8]};
        3'd2:   fnDati = {{56{dat[23]}},dat[23:16]};
        3'd3:   fnDati = {{56{dat[31]}},dat[31:24]};
        3'd4:   fnDati = {{56{dat[39]}},dat[39:32]};
        3'd5:   fnDati = {{56{dat[47]}},dat[47:40]};
        3'd6:   fnDati = {{56{dat[55]}},dat[55:48]};
        3'd7:   fnDati = {{56{dat[63]}},dat[63:56]};
        endcase
    OP_LDBOX,OP_LDBUX:
        case(adr[2:0])
        3'd0:   fnDati = {{56{1'b0}},dat[7:0]};
        3'd1:   fnDati = {{56{1'b0}},dat[15:8]};
        3'd2:   fnDati = {{56{1'b0}},dat[23:16]};
        3'd3:   fnDati = {{56{1'b0}},dat[31:24]};
        3'd4:   fnDati = {{56{1'b0}},dat[39:32]};
        3'd5:   fnDati = {{56{1'b0}},dat[47:40]};
        3'd6:   fnDati = {{56{1'b0}},dat[55:48]};
        3'd7:   fnDati = {{56{2'b0}},dat[63:56]};
        endcase
    OP_LDWX:
        case(adr[2:1])
        2'd0:   fnDati = {{48{dat[15]}},dat[15:0]};
        2'd1:   fnDati = {{48{dat[31]}},dat[31:16]};
        2'd2:   fnDati = {{48{dat[47]}},dat[47:32]};
        2'd3:   fnDati = {{48{dat[63]}},dat[63:48]};
        endcase
    OP_LDWOX,OP_LDWUX:
        case(adr[2:1])
        2'd0:   fnDati = {{48{1'b0}},dat[15:0]};
        2'd1:   fnDati = {{48{1'b0}},dat[31:16]};
        2'd2:   fnDati = {{48{1'b0}},dat[47:32]};
        2'd3:   fnDati = {{48{1'b0}},dat[63:48]};
        endcase
    OP_LDTX:
        case(adr[2])
        1'b0:   fnDati = {{32{dat[31]}},dat[31:0]};
        1'b1:   fnDati = {{32{dat[63]}},dat[63:32]};
        endcase
    OP_LDTOX,OP_LDTUX:
        case(adr[2])
        1'b0:   fnDati = {{32{1'b0}},dat[31:0]};
        1'b1:   fnDati = {{32{1'b0}},dat[63:32]};
        endcase
    OP_LDOX,OP_LDORX,`LVX,`CAS:  fnDati = dat;
    default:    fnDati = dat;
    endcase
OP_LDB:
    case(adr[2:0])
    3'd0:   fnDati = {{56{dat[7]}},dat[7:0]};
    3'd1:   fnDati = {{56{dat[15]}},dat[15:8]};
    3'd2:   fnDati = {{56{dat[23]}},dat[23:16]};
    3'd3:   fnDati = {{56{dat[31]}},dat[31:24]};
    3'd4:   fnDati = {{56{dat[39]}},dat[39:32]};
    3'd5:   fnDati = {{56{dat[47]}},dat[47:40]};
    3'd6:   fnDati = {{56{dat[55]}},dat[55:48]};
    3'd7:   fnDati = {{56{dat[63]}},dat[63:56]};
    endcase
OP_LDBO,OP_LDBU:
    case(adr[2:0])
    3'd0:   fnDati = {{56{1'b0}},dat[7:0]};
    3'd1:   fnDati = {{56{1'b0}},dat[15:8]};
    3'd2:   fnDati = {{56{1'b0}},dat[23:16]};
    3'd3:   fnDati = {{56{1'b0}},dat[31:24]};
    3'd4:   fnDati = {{56{1'b0}},dat[39:32]};
    3'd5:   fnDati = {{56{1'b0}},dat[47:40]};
    3'd6:   fnDati = {{56{1'b0}},dat[55:48]};
    3'd7:   fnDati = {{56{2'b0}},dat[63:56]};
    endcase
OP_LDW:
    case(adr[2:1])
    2'd0:   fnDati = {{48{dat[15]}},dat[15:0]};
    2'd1:   fnDati = {{48{dat[31]}},dat[31:16]};
    2'd2:   fnDati = {{48{dat[47]}},dat[47:32]};
    2'd3:   fnDati = {{48{dat[63]}},dat[63:48]};
    endcase
OP_LDWO,OP_LDWU:
    case(adr[2:1])
    2'd0:   fnDati = {{48{1'b0}},dat[15:0]};
    2'd1:   fnDati = {{48{1'b0}},dat[31:16]};
    2'd2:   fnDati = {{48{1'b0}},dat[47:32]};
    2'd3:   fnDati = {{48{1'b0}},dat[63:48]};
    endcase
OP_LDT:
    case(adr[2])
    1'b0:   fnDati = {{32{dat[31]}},dat[31:0]};
    1'b1:   fnDati = {{32{dat[63]}},dat[63:32]};
    endcase
OP_LDTO,OP_LDTU:
    case(adr[2])
    1'b0:   fnDati = {{32{1'b0}},dat[31:0]};
    1'b1:   fnDati = {{32{1'b0}},dat[63:32]};
    endcase
OP_LDO,OP_LDOR,`LV,`CAS,`AMO:   fnDati = dat;
default:    fnDati = dat;
endcase
endfunction

function [63:0] fnDato;
input [33:0] isn;
input [63:0] dat;
case(isn[6:0])
OP_R2:
    case(isn[`INSTRUCTION_S2])
    OP_STBX:   fnDato = {8{dat[7:0]}};
    OP_STWX:   fnDato = {4{dat[15:0]}};
    OP_STTX:   fnDato = {2{dat[31:0]}};
    default:    fnDato = dat;
    endcase
OP_STB:   fnDato = {8{dat[7:0]}};
OP_STW:   fnDato = {4{dat[15:0]}};
OP_STT:   fnDato = {2{dat[31:0]}};
`AMO:
	case(isn[23:21])
	3'd0:	fnDato = {8{dat[7:0]}};
	3'd1:	fnDato = {4{dat[15:0]}};
	3'd2:	fnDato = {2{dat[31:0]}};
	3'd3:	fnDato = dat;
	default:	fnDato = dat;
	endcase
default:    fnDato = dat;
endcase
endfunction

// Indicate if the ALU instruction is valid immediately (single cycle operation)
function IsSingleCycle;
input [33:0] isn;
IsSingleCycle = TRUE;
endfunction

initial begin: Init
	//
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

// ---------------------------------------------------------------------------
// FETCH
// ---------------------------------------------------------------------------
//
assign fetchbuf0_mem   = IsMem(insn0a);
assign fetchbuf0_memld = IsMem(insn0a) & IsLoad(insn0a);
assign fetchbuf0_jmp   = IsFlowCtrl(insn0a);
assign fetchbuf0_rfw   = IsRFW(insn0a,vqe0,vl,fetchbuf0_thrd);

assign fetchbuf1_mem   = IsMem(insn1a);
assign fetchbuf1_memld = IsMem(ins1a) & IsLoad(insn1a);
assign fetchbuf1_jmp   = IsFlowCtrl(insn1a);
assign fetchbuf1_rfw   = IsRFW(insn1a,vqe1,vl,fetchbuf1_thrd);

//initial begin: stop_at
//#1000000; panic <= `PANIC_OVERRUN;
//end

//
// BRANCH-MISS LOGIC: livetarget
//
// livetarget implies that there is a not-to-be-stomped instruction that targets the register in question
// therefore, if it is zero it implies the rf_v value should become VALID on a branchmiss
// 

reg vqueued2;
assign Ra0 = fnRa(insn0a,vqe0,vl,fetchbuf0_thrd);
assign Rb0 = fnRb(insn0a,1'b0,vqe0,rfoa0[5:0],rfoa1[5:0],fetchbuf0_thrd);
assign Rc0 = fnRc(insn0a,vqe0,fetchbuf0_thrd);
assign Rt0 = fnRt(insn0a,vqet0,vl,fetchbuf0_thrd);
assign Ra1 = fnRa(insn1a,vqueued2 ? vqe0 + 1 : vqe1,vl,fetchbuf1_thrd);
assign Rb1 = fnRb(insn1a,1'b1,vqueued2 ? vqe0 + 1 : vqe1,rfoa0[5:0],rfoa1[5:0],fetchbuf1_thrd);
assign Rc1 = fnRc(insn1a,vqueued2 ? vqe0 + 1 : vqe1,fetchbuf1_thrd);
assign Rt1 = fnRt(insn1a,vqueued2 ? vqet0 + 1 : vqet1,vl,fetchbuf1_thrd);

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
assign could_issue[g] = iqentry_v[g] && !iqentry_done[g] && !iqentry_out[g] &&
                                 (iqentry_mem[g] ? !iqentry_agen[g] : 1'b1);
end                                 
end
endgenerate

// The (old) simulator didn't handle the asynchronous race loop properly in the 
// original code. It would issue two instructions to the same islot. So the
// issue logic has been re-written to eliminate the asynchronous loop.
// Can't issue to the ALU if it's busy doing a long running operation like a 
// divide.
// ToDo: fix the memory synchronization, see fp_issue below

always_comb
begin
	iqentry_issue = 8'h00;
	for (n = 0; n < QENTRIES; n = n + 1)
		iqentry_islot[n] = 2'b00;
	
	// aluissue is a task
	if (alu0_idle) begin
		if (could_issue[head0] && iqentry_alu[head0]
		&& !iqentry_issue[head0]) begin
		  iqentry_issue[head0] = TRUE;
		  iqentry_islot[head0] = 2'b00;
		end
		else if (could_issue[head1] && !iqentry_issue[head1] && iqentry_alu[head1]
		)
		begin
		  iqentry_issue[head1] = TRUE;
		  iqentry_islot[head1] = 2'b00;
		end
		else if (could_issue[head2] && !iqentry_issue[head2] && iqentry_alu[head2]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		)
		begin
			iqentry_issue[head2] = TRUE;
			iqentry_islot[head2] = 2'b00;
		end
		else if (could_issue[head3] && !iqentry_issue[head3] && iqentry_alu[head3]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
			)
		) begin
			iqentry_issue[head3] = TRUE;
			iqentry_islot[head3] = 2'b00;
		end
		else if (could_issue[head4] && !iqentry_issue[head4] && iqentry_alu[head4]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
		 	)
		&& (!(iqentry_v[head3] && iqentry_sync[head3]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2]))
			)
		) begin
			iqentry_issue[head4] = TRUE;
			iqentry_islot[head4] = 2'b00;
		end
		else if (could_issue[head5] && !iqentry_issue[head5] && iqentry_alu[head5]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
		 	)
		&& (!(iqentry_v[head3] && iqentry_sync[head3]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2]))
			)
		&& (!(iqentry_v[head4] && iqentry_sync[head4]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3]))
			)
		) begin
			iqentry_issue[head5] = TRUE;
			iqentry_islot[head5] = 2'b00;
		end
`ifdef FULL_ISSUE_LOGIC
		else if (could_issue[head6] && !iqentry_issue[head6] && iqentry_alu[head6]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
		 	)
		&& (!(iqentry_v[head3] && iqentry_sync[head3]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2]))
			)
		&& (!(iqentry_v[head4] && iqentry_sync[head4]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3]))
			)
		&& (!(iqentry_v[head5] && iqentry_sync[head5]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3])
		 	&&   (!iqentry_v[head4]))
			)
		) begin
			iqentry_issue[head6] = TRUE;
			iqentry_islot[head6] = 2'b00;
		end
		else if (could_issue[head7] && !iqentry_issue[head7] && iqentry_alu[head7]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
		 	)
		&& (!(iqentry_v[head3] && iqentry_sync[head3]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2]))
			)
		&& (!(iqentry_v[head4] && iqentry_sync[head4]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3]))
			)
		&& (!(iqentry_v[head5] && iqentry_sync[head5]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3])
		 	&&   (!iqentry_v[head4]))
			)
		&& (!(iqentry_v[head6] && iqentry_sync[head6]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3])
		 	&&   (!iqentry_v[head4])
		 	&&   (!iqentry_v[head5]))
			)
		) begin
			iqentry_issue[head7] = TRUE;
			iqentry_islot[head7] = 2'b00;
		end
`endif
	end

	if (alu1_idle) begin
		if (could_issue[head0] && iqentry_alu[head0]
		&& !iqentry_alu0[head0]	// alu0only
		&& !iqentry_issue[head0]) begin
		  iqentry_issue[head0] = TRUE;
		  iqentry_islot[head0] = 2'b01;
		end
		else if (could_issue[head1] && !iqentry_issue[head1] && iqentry_alu[head1]
		&& !iqentry_alu0[head1])
		begin
		  iqentry_issue[head1] = TRUE;
		  iqentry_islot[head1] = 2'b01;
		end
		else if (could_issue[head2] && !iqentry_issue[head2] && iqentry_alu[head2]
		&& !iqentry_alu0[head2]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		)
		begin
			iqentry_issue[head2] = TRUE;
			iqentry_islot[head2] = 2'b01;
		end
		else if (could_issue[head3] && !iqentry_issue[head3] && iqentry_alu[head3]
		&& !iqentry_alu0[head3]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
			)
		) begin
			iqentry_issue[head3] = TRUE;
			iqentry_islot[head3] = 2'b01;
		end
		else if (could_issue[head4] && !iqentry_issue[head4] && iqentry_alu[head4]
		&& !iqentry_alu0[head4]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
		 	)
		&& (!(iqentry_v[head3] && iqentry_sync[head3]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2]))
			)
		) begin
			iqentry_issue[head4] = TRUE;
			iqentry_islot[head4] = 2'b01;
		end
		else if (could_issue[head5] && !iqentry_issue[head5] && iqentry_alu[head5]
		&& !iqentry_alu0[head5]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
		 	)
		&& (!(iqentry_v[head3] && iqentry_sync[head3]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2]))
			)
		&& (!(iqentry_v[head4] && iqentry_sync[head4]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3]))
			)
		) begin
			iqentry_issue[head5] = TRUE;
			iqentry_islot[head5] = 2'b01;
		end
`ifdef FULL_ISSUE_LOGIC
		else if (could_issue[head6] && !iqentry_issue[head6] && iqentry_alu[head6]
		&& !iqentry_alu0[head6]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
		 	)
		&& (!(iqentry_v[head3] && iqentry_sync[head3]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2]))
			)
		&& (!(iqentry_v[head4] && iqentry_sync[head4]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3]))
			)
		&& (!(iqentry_v[head5] && iqentry_sync[head5]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3])
		 	&&   (!iqentry_v[head4]))
			)
		) begin
			iqentry_issue[head6] = TRUE;
			iqentry_islot[head6] = 2'b01;
		end
		else if (could_issue[head7] && !iqentry_issue[head7] && iqentry_alu[head7]
		&& !iqentry_alu0[head7]
		&& (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
		&& (!(iqentry_v[head2] && iqentry_sync[head2]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1]))
		 	)
		&& (!(iqentry_v[head3] && iqentry_sync[head3]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2]))
			)
		&& (!(iqentry_v[head4] && iqentry_sync[head4]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3]))
			)
		&& (!(iqentry_v[head5] && iqentry_sync[head5]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3])
		 	&&   (!iqentry_v[head4]))
			)
		&& (!(iqentry_v[head6] && iqentry_sync[head6]) ||
		 		((!iqentry_v[head0])
		 	&&   (!iqentry_v[head1])
		 	&&   (!iqentry_v[head2])
		 	&&   (!iqentry_v[head3])
		 	&&   (!iqentry_v[head4])
		 	&&   (!iqentry_v[head5]))
			)
		) begin
			iqentry_issue[head7] = TRUE;
			iqentry_islot[head7] = 2'b01;
		end
`endif
	end
//	aluissue(alu0_idle,8'h00,2'b00);
//	aluissue(alu1_idle,iqentry_alu0,2'b01);

end

always_comb
begin
	iqentry_fpu_issue = 8'h00;
//	fpuissue(fpu_idle,2'b00);
	if (fpu_idle) begin
    if (could_issue[head0] && iqentry_fpu[head0]) begin
      iqentry_fpu_issue[head0] = TRUE;
      iqentry_fpu_islot[head0] = 2'b00;
    end
    else if (could_issue[head1] && iqentry_fpu[head1])
    begin
      iqentry_fpu_issue[head1] = TRUE;
      iqentry_fpu_islot[head1] = 2'b00;
    end
    else if (could_issue[head2] && iqentry_fpu[head2]
    && (!(iqentry_v[head1] && (iqentry_sync[head1] || iqentry_fsync[head1])) || !iqentry_v[head0])
    ) begin
      iqentry_fpu_issue[head2] = TRUE;
      iqentry_fpu_islot[head2] = 2'b00;
    end
    else if (could_issue[head3] && iqentry_fpu[head3]
    && (!(iqentry_v[head1] && (iqentry_sync[head1] || iqentry_fsync[head1])) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && (iqentry_sync[head2] || iqentry_fsync[head2])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
     	)
    ) begin
      iqentry_fpu_issue[head3] = TRUE;
      iqentry_fpu_islot[head3] = 2'b00;
    end
    else if (could_issue[head4] && iqentry_fpu[head4]
    && (!(iqentry_v[head1] && (iqentry_sync[head1] || iqentry_fsync[head1])) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && (iqentry_sync[head2] || iqentry_fsync[head2])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
     	)
    && (!(iqentry_v[head3] && (iqentry_sync[head3] || iqentry_fsync[head3])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2]))
    	)
    ) begin
      iqentry_fpu_issue[head4] = TRUE;
      iqentry_fpu_islot[head4] = 2'b00;
    end
    else if (could_issue[head5] && iqentry_fpu[head5]
    && (!(iqentry_v[head1] && (iqentry_sync[head1] || iqentry_fsync[head1])) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && (iqentry_sync[head2] || iqentry_fsync[head2])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
     	)
    && (!(iqentry_v[head3] && (iqentry_sync[head3] || iqentry_fsync[head3])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2]))
    	)
    && (!(iqentry_v[head4] && (iqentry_sync[head4] || iqentry_fsync[head4])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3]))
    	)
   	) begin
	      iqentry_fpu_issue[head5] = TRUE;
	      iqentry_fpu_islot[head5] = 2'b00;
    end
`ifdef FULL_ISSUE_LOGIC
    else if (could_issue[head6] && iqentry_fpu[head6]
    && (!(iqentry_v[head1] && (iqentry_sync[head1] || iqentry_fsync[head1])) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && (iqentry_sync[head2] || iqentry_fsync[head2])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
     	)
    && (!(iqentry_v[head3] && (iqentry_sync[head3] || iqentry_fsync[head3])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2]))
    	)
    && (!(iqentry_v[head4] && (iqentry_sync[head4] || iqentry_fsync[head4])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3]))
    	)
    && (!(iqentry_v[head5] && (iqentry_sync[head5] || iqentry_fsync[head5])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3])
     	&&   (!iqentry_v[head4]))
    	)
    ) begin
    	iqentry_fpu_issue[head6] = TRUE;
	    iqentry_fpu_islot[head6] = 2'b00;
    end
    else if (could_issue[head7] && iqentry_fpu[head7]
    && (!(iqentry_v[head1] && (iqentry_sync[head1] || iqentry_fsync[head1])) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && (iqentry_sync[head2] || iqentry_fsync[head2])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
     	)
    && (!(iqentry_v[head3] && (iqentry_sync[head3] || iqentry_fsync[head3])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2]))
    	)
    && (!(iqentry_v[head4] && (iqentry_sync[head4] || iqentry_fsync[head4])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3]))
    	)
    && (!(iqentry_v[head5] && (iqentry_sync[head5] || iqentry_fsync[head5])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3])
     	&&   (!iqentry_v[head4]))
    	)
    && (!(iqentry_v[head6] && (iqentry_sync[head6] || iqentry_fsync[head6])) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3])
     	&&   (!iqentry_v[head4])
     	&&   (!iqentry_v[head5]))
    	)
	)
    begin
   		iqentry_fpu_issue[head7] = TRUE;
		iqentry_fpu_islot[head7] = 2'b00;
	end
`endif
	end
end


//assign nextqd = 8'hFF;

// Don't issue to the fcu until the following instruction is enqueued.
// However, if the queue is full then issue anyway. A branch miss will likely occur.
always_comb//(could_issue or head0 or head1 or head2 or head3 or head4 or head5 or head6 or head7)
begin
	iqentry_fcu_issue = 8'h00;
	if (fcu_done) begin
    if (could_issue[head0] && iqentry_fc[head0]) begin
      iqentry_fcu_issue[head0] = TRUE;
    end
    else if (could_issue[head1] && iqentry_fc[head1])
    begin
      iqentry_fcu_issue[head1] = TRUE;
    end
    else if (could_issue[head2] && iqentry_fc[head2]
    && (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
    ) begin
   		iqentry_fcu_issue[head2] = TRUE;
    end
    else if (could_issue[head3] && iqentry_fc[head3]
    && (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && iqentry_sync[head2]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
    	)
    ) begin
   		iqentry_fcu_issue[head3] = TRUE;
    end
    else if (could_issue[head4] && iqentry_fc[head4]
    && (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && iqentry_sync[head2]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
     	)
    && (!(iqentry_v[head3] && iqentry_sync[head3]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2]))
    	)
    ) begin
   		iqentry_fcu_issue[head4] = TRUE;
    end
    else if (could_issue[head5] && iqentry_fc[head5]
    && (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && iqentry_sync[head2]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
     	)
    && (!(iqentry_v[head3] && iqentry_sync[head3]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2]))
    	)
    && (!(iqentry_v[head4] && iqentry_sync[head4]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3]))
    	)
    ) begin
   		iqentry_fcu_issue[head5] = TRUE;
    end
 
`ifdef FULL_ISSUE_LOGIC
    else if (could_issue[head6] && iqentry_fc[head6]
    && (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && iqentry_sync[head2]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
     	)
    && (!(iqentry_v[head3] && iqentry_sync[head3]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2]))
    	)
    && (!(iqentry_v[head4] && iqentry_sync[head4]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3]))
    	)
    && (!(iqentry_v[head5] && iqentry_sync[head5]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3])
     	&&   (!iqentry_v[head4]))
    	)
    ) begin
   		iqentry_fcu_issue[head6] = TRUE;
    end
   
    else if (could_issue[head7] && iqentry_fc[head7]
    && (!(iqentry_v[head1] && iqentry_sync[head1]) || !iqentry_v[head0])
    && (!(iqentry_v[head2] && iqentry_sync[head2]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1]))
     	)
    && (!(iqentry_v[head3] && iqentry_sync[head3]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2]))
    	)
    && (!(iqentry_v[head4] && iqentry_sync[head4]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3]))
    	)
    && (!(iqentry_v[head5] && iqentry_sync[head5]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3])
     	&&   (!iqentry_v[head4]))
    	)
    && (!(iqentry_v[head6] && iqentry_sync[head6]) ||
     		((!iqentry_v[head0])
     	&&   (!iqentry_v[head1])
     	&&   (!iqentry_v[head2])
     	&&   (!iqentry_v[head3])
     	&&   (!iqentry_v[head4])
     	&&   (!iqentry_v[head5]))
    	)
    ) begin
   		iqentry_fcu_issue[head7] = TRUE;
  	end
`endif
	end
end

//
// determine if the instructions ready to issue can, in fact, issue.
// "ready" means that the instruction has valid operands but has not gone yet
reg [1:0] issue_count, missue_count;
always_comb
begin
	issue_count = 0;
	 memissue[ head0 ] =	iqentry_memready[ head0 ];		// first in line ... go as soon as ready
	 if (memissue[head0])
	 	issue_count = issue_count + 1;

	 memissue[ head1 ] =	~iqentry_stomp[head1] && iqentry_memready[ head1 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					//&& ~iqentry_memready[head0]
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head1] != iqentry_a1[head0]))
					// ... if a release, any prior memory ops must be done before this one
					&& (iqentry_rl[head1] ? iqentry_done[head0] || !iqentry_v[head0] || !iqentry_mem[head0] : 1'b1)
					// ... if a preivous op has the aquire bit set
					&& !(iqentry_aq[head0] && iqentry_v[head0])
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iqentry_load[head1] ||
					   !(iqentry_fc[head0]||iqentry_canex[head0]));
	 if (memissue[head1])
	 	issue_count = issue_count + 1;

	 memissue[ head2 ] =	~iqentry_stomp[head2] && iqentry_memready[ head2 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					//&& ~iqentry_memready[head0]
					//&& ~iqentry_memready[head1] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head2] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head2] != iqentry_a1[head1]))
					// ... if a release, any prior memory ops must be done before this one
					&& (iqentry_rl[head2] ? (iqentry_done[head0] || !iqentry_v[head0] || !iqentry_mem[head0])
										 && (iqentry_done[head1] || !iqentry_v[head1] || !iqentry_mem[head1])
											 : 1'b1)
					// ... if a preivous op has the aquire bit set
					&& !(iqentry_aq[head0] && iqentry_v[head0])
					&& !(iqentry_aq[head1] && iqentry_v[head1])
					// ... and there isn't a barrier, or everything before the barrier is done or invalid
                    && (!(iqentry_v[head1] && iqentry_memsb[head1]) || (iqentry_done[head0] || !iqentry_v[head0]))
    				&& (!(iqentry_v[head1] && iqentry_memdb[head1]) || (!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0]))
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iqentry_load[head2] ||
					      !(iqentry_fc[head0]||iqentry_canex[head0])
					   && !(iqentry_fc[head1]||iqentry_canex[head1]));
	 if (memissue[head2])
	 	issue_count = issue_count + 1;
					        
	 memissue[ head3 ] =	~iqentry_stomp[head3] && iqentry_memready[ head3 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& issue_count < 3
					//&& ~iqentry_memready[head0]
					//&& ~iqentry_memready[head1] 
					//&& ~iqentry_memready[head2] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head3] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head3] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head3] != iqentry_a1[head2]))
					// ... if a release, any prior memory ops must be done before this one
					&& (iqentry_rl[head3] ? (iqentry_done[head0] || !iqentry_v[head0] || !iqentry_mem[head0])
										 && (iqentry_done[head1] || !iqentry_v[head1] || !iqentry_mem[head1])
										 && (iqentry_done[head2] || !iqentry_v[head2] || !iqentry_mem[head2])
											 : 1'b1)
					// ... if a preivous op has the aquire bit set
					&& !(iqentry_aq[head0] && iqentry_v[head0])
					&& !(iqentry_aq[head1] && iqentry_v[head1])
					&& !(iqentry_aq[head2] && iqentry_v[head2])
					// ... and there isn't a barrier, or everything before the barrier is done or invalid
                    && (!(iqentry_v[head1] && iqentry_memsb[head1]) || (iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memsb[head2]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1]))
                    		)
    				&& (!(iqentry_v[head1] && iqentry_memdb[head1]) || (!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memdb[head2]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1]))
                     		)
                    // ... and, if it is a SW, there is no chance of it being undone
					&& (iqentry_load[head3] ||
		      		      !(iqentry_fc[head0]||iqentry_canex[head0])
                       && !(iqentry_fc[head1]||iqentry_canex[head1])
                       && !(iqentry_fc[head2]||iqentry_canex[head2]));
	 if (memissue[head3])
	 	issue_count = issue_count + 1;

	 memissue[ head4 ] =	~iqentry_stomp[head4] && iqentry_memready[ head4 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& issue_count < 3
					//&& ~iqentry_memready[head0]
					//&& ~iqentry_memready[head1] 
					//&& ~iqentry_memready[head2] 
					//&& ~iqentry_memready[head3] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head4] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head4] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head4] != iqentry_a1[head2]))
					&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
						|| (iqentry_a1_v[head3] && iqentry_a1[head4] != iqentry_a1[head3]))
					// ... if a release, any prior memory ops must be done before this one
					&& (iqentry_rl[head4] ? (iqentry_done[head0] || !iqentry_v[head0] || !iqentry_mem[head0])
										 && (iqentry_done[head1] || !iqentry_v[head1] || !iqentry_mem[head1])
										 && (iqentry_done[head2] || !iqentry_v[head2] || !iqentry_mem[head2])
										 && (iqentry_done[head3] || !iqentry_v[head3] || !iqentry_mem[head3])
											 : 1'b1)
					// ... if a preivous op has the aquire bit set
					&& !(iqentry_aq[head0] && iqentry_v[head0])
					&& !(iqentry_aq[head1] && iqentry_v[head1])
					&& !(iqentry_aq[head2] && iqentry_v[head2])
					&& !(iqentry_aq[head3] && iqentry_v[head3])
					// ... and there isn't a barrier, or everything before the barrier is done or invalid
                    && (!(iqentry_v[head1] && iqentry_memsb[head1]) || (iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memsb[head2]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1]))
                    		)
                    && (!(iqentry_v[head3] && iqentry_memsb[head3]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2]))
                    		)
    				&& (!(iqentry_v[head1] && iqentry_memdb[head1]) || (!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memdb[head2]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1]))
                     		)
                    && (!(iqentry_v[head3] && iqentry_memdb[head3]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2]))
                     		)
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iqentry_load[head4] ||
		      		      !(iqentry_fc[head0]||iqentry_canex[head0])
                       && !(iqentry_fc[head1]||iqentry_canex[head1])
                       && !(iqentry_fc[head2]||iqentry_canex[head2])
                       && !(iqentry_fc[head3]||iqentry_canex[head3]));
	 if (memissue[head4])
	 	issue_count = issue_count + 1;

	 memissue[ head5 ] =	~iqentry_stomp[head5] && iqentry_memready[ head5 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& issue_count < 3
					//&& ~iqentry_memready[head0]
					//&& ~iqentry_memready[head1] 
					//&& ~iqentry_memready[head2] 
					//&& ~iqentry_memready[head3] 
					//&& ~iqentry_memready[head4] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head5] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head5] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head5] != iqentry_a1[head2]))
					&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
						|| (iqentry_a1_v[head3] && iqentry_a1[head5] != iqentry_a1[head3]))
					&& (!iqentry_mem[head4] || (iqentry_agen[head4] & iqentry_out[head4]) 
						|| (iqentry_a1_v[head4] && iqentry_a1[head5] != iqentry_a1[head4]))
					// ... if a release, any prior memory ops must be done before this one
					&& (iqentry_rl[head5] ? (iqentry_done[head0] || !iqentry_v[head0] || !iqentry_mem[head0])
										 && (iqentry_done[head1] || !iqentry_v[head1] || !iqentry_mem[head1])
										 && (iqentry_done[head2] || !iqentry_v[head2] || !iqentry_mem[head2])
										 && (iqentry_done[head3] || !iqentry_v[head3] || !iqentry_mem[head3])
										 && (iqentry_done[head4] || !iqentry_v[head4] || !iqentry_mem[head4])
											 : 1'b1)
					// ... if a preivous op has the aquire bit set
					&& !(iqentry_aq[head0] && iqentry_v[head0])
					&& !(iqentry_aq[head1] && iqentry_v[head1])
					&& !(iqentry_aq[head2] && iqentry_v[head2])
					&& !(iqentry_aq[head3] && iqentry_v[head3])
					&& !(iqentry_aq[head4] && iqentry_v[head4])
					// ... and there isn't a barrier, or everything before the barrier is done or invalid
                    && (!(iqentry_v[head1] && iqentry_memsb[head1]) || (iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memsb[head2]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1]))
                    		)
                    && (!(iqentry_v[head3] && iqentry_memsb[head3]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2]))
                    		)
                    && (!(iqentry_v[head4] && iqentry_memsb[head4]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2])
                    		&&   (iqentry_done[head3] || !iqentry_v[head3]))
                    		)
    				&& (!(iqentry_v[head1] && iqentry_memdb[head1]) || (!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memdb[head2]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1]))
                     		)
                    && (!(iqentry_v[head3] && iqentry_memdb[head3]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2]))
                     		)
                    && (!(iqentry_v[head4] && iqentry_memdb[head4]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2])
                     		&& (!iqentry_mem[head3] || iqentry_done[head3] || !iqentry_v[head3]))
                     		)
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iqentry_load[head5] ||
		      		      !(iqentry_fc[head0]||iqentry_canex[head0])
                       && !(iqentry_fc[head1]||iqentry_canex[head1])
                       && !(iqentry_fc[head2]||iqentry_canex[head2])
                       && !(iqentry_fc[head3]||iqentry_canex[head3])
                       && !(iqentry_fc[head4]||iqentry_canex[head4]));
	 if (memissue[head5])
	 	issue_count = issue_count + 1;

`ifdef FULL_ISSUE_LOGIC
	 memissue[ head6 ] =	~iqentry_stomp[head6] && iqentry_memready[ head6 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& issue_count < 3
					//&& ~iqentry_memready[head0]
					//&& ~iqentry_memready[head1] 
					//&& ~iqentry_memready[head2] 
					//&& ~iqentry_memready[head3] 
					//&& ~iqentry_memready[head4] 
					//&& ~iqentry_memready[head5] 
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
					&& (iqentry_rl[head6] ? (iqentry_done[head0] || !iqentry_v[head0] || !iqentry_mem[head0])
										 && (iqentry_done[head1] || !iqentry_v[head1] || !iqentry_mem[head1])
										 && (iqentry_done[head2] || !iqentry_v[head2] || !iqentry_mem[head2])
										 && (iqentry_done[head3] || !iqentry_v[head3] || !iqentry_mem[head3])
										 && (iqentry_done[head4] || !iqentry_v[head4] || !iqentry_mem[head4])
										 && (iqentry_done[head5] || !iqentry_v[head5] || !iqentry_mem[head5])
											 : 1'b1)
					// ... if a preivous op has the aquire bit set
					&& !(iqentry_aq[head0] && iqentry_v[head0])
					&& !(iqentry_aq[head1] && iqentry_v[head1])
					&& !(iqentry_aq[head2] && iqentry_v[head2])
					&& !(iqentry_aq[head3] && iqentry_v[head3])
					&& !(iqentry_aq[head4] && iqentry_v[head4])
					&& !(iqentry_aq[head5] && iqentry_v[head5])
					// ... and there isn't a barrier, or everything before the barrier is done or invalid
                    && (!(iqentry_v[head1] && iqentry_memsb[head1]) || (iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memsb[head2]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1]))
                    		)
                    && (!(iqentry_v[head3] && iqentry_memsb[head3]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2]))
                    		)
                    && (!(iqentry_v[head4] && iqentry_memsb[head4]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2])
                    		&&   (iqentry_done[head3] || !iqentry_v[head3]))
                    		)
                    && (!(iqentry_v[head5] && iqentry_memsb[head5]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2])
                    		&&   (iqentry_done[head3] || !iqentry_v[head3])
                    		&&   (iqentry_done[head4] || !iqentry_v[head4]))
                    		)
    				&& (!(iqentry_v[head1] && iqentry_memdb[head1]) || (!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memdb[head2]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1]))
                     		)
                    && (!(iqentry_v[head3] && iqentry_memdb[head3]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2]))
                     		)
                    && (!(iqentry_v[head4] && iqentry_memdb[head4]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2])
                     		&& (!iqentry_mem[head3] || iqentry_done[head3] || !iqentry_v[head3]))
                     		)
                    && (!(iqentry_v[head5] && iqentry_memdb[head5]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2])
                     		&& (!iqentry_mem[head3] || iqentry_done[head3] || !iqentry_v[head3])
                     		&& (!iqentry_mem[head4] || iqentry_done[head4] || !iqentry_v[head4]))
                     		)
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iqentry_load[head6] ||
		      		      !(iqentry_fc[head0]||iqentry_canex[head0])
                       && !(iqentry_fc[head1]||iqentry_canex[head1])
                       && !(iqentry_fc[head2]||iqentry_canex[head2])
                       && !(iqentry_fc[head3]||iqentry_canex[head3])
                       && !(iqentry_fc[head4]||iqentry_canex[head4])
                       && !(iqentry_fc[head5]||iqentry_canex[head5]));
	 if (memissue[head6])
	 	issue_count = issue_count + 1;

	 memissue[ head7 ] =	~iqentry_stomp[head7] && iqentry_memready[ head7 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& issue_count < 3
					//&& ~iqentry_memready[head0]
					//&& ~iqentry_memready[head1] 
					//&& ~iqentry_memready[head2] 
					//&& ~iqentry_memready[head3] 
					//&& ~iqentry_memready[head4] 
					//&& ~iqentry_memready[head5] 
					//&& ~iqentry_memready[head6] 
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
					&& (iqentry_rl[head7] ? (iqentry_done[head0] || !iqentry_v[head0] || !iqentry_mem[head0])
										 && (iqentry_done[head1] || !iqentry_v[head1] || !iqentry_mem[head1])
										 && (iqentry_done[head2] || !iqentry_v[head2] || !iqentry_mem[head2])
										 && (iqentry_done[head3] || !iqentry_v[head3] || !iqentry_mem[head3])
										 && (iqentry_done[head4] || !iqentry_v[head4] || !iqentry_mem[head4])
										 && (iqentry_done[head5] || !iqentry_v[head5] || !iqentry_mem[head5])
										 && (iqentry_done[head6] || !iqentry_v[head6] || !iqentry_mem[head6])
											 : 1'b1)
					// ... if a preivous op has the aquire bit set
					&& !(iqentry_aq[head0] && iqentry_v[head0])
					&& !(iqentry_aq[head1] && iqentry_v[head1])
					&& !(iqentry_aq[head2] && iqentry_v[head2])
					&& !(iqentry_aq[head3] && iqentry_v[head3])
					&& !(iqentry_aq[head4] && iqentry_v[head4])
					&& !(iqentry_aq[head5] && iqentry_v[head5])
					&& !(iqentry_aq[head6] && iqentry_v[head6])
					// ... and there isn't a barrier, or everything before the barrier is done or invalid
                    && (!(iqentry_v[head1] && iqentry_memsb[head1]) || (iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memsb[head2]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1]))
                    		)
                    && (!(iqentry_v[head3] && iqentry_memsb[head3]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2]))
                    		)
                    && (!(iqentry_v[head4] && iqentry_memsb[head4]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2])
                    		&&   (iqentry_done[head3] || !iqentry_v[head3]))
                    		)
                    && (!(iqentry_v[head5] && iqentry_memsb[head5]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2])
                    		&&   (iqentry_done[head3] || !iqentry_v[head3])
                    		&&   (iqentry_done[head4] || !iqentry_v[head4]))
                    		)
                    && (!(iqentry_v[head6] && iqentry_memsb[head6]) ||
                    			((iqentry_done[head0] || !iqentry_v[head0])
                    		&&   (iqentry_done[head1] || !iqentry_v[head1])
                    		&&   (iqentry_done[head2] || !iqentry_v[head2])
                    		&&   (iqentry_done[head3] || !iqentry_v[head3])
                    		&&   (iqentry_done[head4] || !iqentry_v[head4])
                    		&&   (iqentry_done[head5] || !iqentry_v[head5]))
                    		)
    				&& (!(iqentry_v[head1] && iqentry_memdb[head1]) || (!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0]))
                    && (!(iqentry_v[head2] && iqentry_memdb[head2]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1]))
                     		)
                    && (!(iqentry_v[head3] && iqentry_memdb[head3]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2]))
                     		)
                    && (!(iqentry_v[head4] && iqentry_memdb[head4]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2])
                     		&& (!iqentry_mem[head3] || iqentry_done[head3] || !iqentry_v[head3]))
                     		)
                    && (!(iqentry_v[head5] && iqentry_memdb[head5]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2])
                     		&& (!iqentry_mem[head3] || iqentry_done[head3] || !iqentry_v[head3])
                     		&& (!iqentry_mem[head4] || iqentry_done[head4] || !iqentry_v[head4]))
                     		)
                    && (!(iqentry_v[head6] && iqentry_memdb[head6]) ||
                     		  ((!iqentry_mem[head0] || iqentry_done[head0] || !iqentry_v[head0])
                     		&& (!iqentry_mem[head1] || iqentry_done[head1] || !iqentry_v[head1])
                     		&& (!iqentry_mem[head2] || iqentry_done[head2] || !iqentry_v[head2])
                     		&& (!iqentry_mem[head3] || iqentry_done[head3] || !iqentry_v[head3])
                     		&& (!iqentry_mem[head4] || iqentry_done[head4] || !iqentry_v[head4])
                     		&& (!iqentry_mem[head5] || iqentry_done[head5] || !iqentry_v[head5]))
                     		)
					// ... and, if it is a SW, there is no chance of it being undone
					&& (iqentry_load[head7] ||
		      		      !(iqentry_fc[head0]||iqentry_canex[head0])
                       && !(iqentry_fc[head1]||iqentry_canex[head1])
                       && !(iqentry_fc[head2]||iqentry_canex[head2])
                       && !(iqentry_fc[head3]||iqentry_canex[head3])
                       && !(iqentry_fc[head4]||iqentry_canex[head4])
                       && !(iqentry_fc[head5]||iqentry_canex[head5])
                       && !(iqentry_fc[head6]||iqentry_canex[head6]));
`endif
end
//
    // EXECUTE
    //
    reg [63:0] csr_r;
    always_comb
        read_csr(alu0_instr[29:16],csr_r,alu0_thrd);
    Gam_alu #(.BIG(1'b1),.SUP_VECTOR(SUP_VECTOR)) ualu0 (
        .rst(rst),
        .clk(clk),
        .ld(alu0_ld),
        .abort(1'b0),
        .instr(alu0_instr),
        .a(alu0_argA),
        .b(alu0_argB),
        .c(alu0_argC),
        .imm(alu0_argI),
        .tgt(alu0_tgt),
        .ven(alu0_ven),
        .vm(vm[alu0_instr[24:23]]),
        .sbl(sbl),
        .sbu(sbu),
        .csr(csr_r),
        .o(alu0_bus),
        .ob(alu0b_bus),
        .done(alu0_done),
        .idle(alu0_idle),
        .excen(aec[4:0]),
        .exc(alu0_exc),
        .thrd(alu0_thrd)
    );
    Gam_alu #(.BIG(1'b0),.SUP_VECTOR(SUP_VECTOR)) ualu1 (
        .rst(rst),
        .clk(clk),
        .ld(alu1_ld),
        .abort(1'b0),
        .instr(alu1_instr),
        .a(alu1_argA),
        .b(alu1_argB),
        .c(alu1_argC),
        .imm(alu1_argI),
        .tgt(alu1_tgt),
        .ven(alu1_ven),
        .vm(vm[alu1_instr[24:23]]),
        .sbl(sbl),
        .sbu(sbu),
        .csr(64'd0),
        .o(alu1_bus),
        .ob(alu1b_bus),
        .done(alu1_done),
        .idle(alu1_idle),
        .excen(aec[4:0]),
        .exc(alu1_exc),
        .thrd(1'b0)
    );
    fpUnit #(WID) ufp1
    (
        .rst(rst),
        .clk(clk),
        .clk4x(clk4x),
        .ce(1'b1),
        .ir(fpu_instr),
        .ld(fpu_ld),
        .a(fpu_argA),
        .b(fpu_argB),
        .imm(fpu_argI),
        .o(fpu_bus),
        .csr_i(),
        .status(fpu_status),
        .exception(),
        .done(fpu_done)
    );
    assign fpu_exc = |fpu_status[15:0] ? `FLT_FLT : `FLT_NONE;

    assign  alu0_v = alu0_dataready,
	        alu1_v = alu1_dataready;
    assign  alu0_id = alu0_sourceid,
     	    alu1_id = alu1_sourceid;
    assign  fpu_v = fpu_dataready;
    assign  fpu_id = fpu_sourceid;

    assign  fcu_v = fcu_dataready;
    assign  fcu_id = fcu_sourceid;
    
    wire [4:0] fcmpo;
    wire fnanx;
    fp_cmp_unit ufcmp1 (fcu_argA, fcu_argB, fcmpo, fnanx);

	wire fcu_takb;

    always_comb
    begin
        fcu_exc <= `FLT_NONE;
        casez(fcu_instr[6:0])
        OP_CHK:   begin
                    if (fcu_instr[21])
                        fcu_exc <= fcu_argA >= fcu_argB && fcu_argA < fcu_argC ? `FLT_NONE : `FLT_CHK;
                end
        `REX:
            case(ol[fcu_thrd])
            `OL_USER:   fcu_exc <= `FLT_PRIV;
            default:    ;
            endcase
		endcase
	end

	Gam_EvalBranch ube1
	(
		.instr(fcu_instr),
		.a(fcu_argA),
		.b(fcu_argB),
		.c(fcu_argC),
		.takb(fcu_takb)
	);

	Gam_FCU_Calc ufcuc1
	(
		.ol(ol[fcu_thrd]),
		.instr(fcu_instr),
		.tvec(tvec[fcu_instr[13:11]]),
		.a(fcu_argA),
		.i(fcu_argI),
		.pc(fcu_pc),
		.im(im),
		.waitctr(waitctr),
		.bus(fcu_bus)
	);

assign  fcu_misspc =
    IsRTI(fcu_instr) ? fcu_argB :
    (fcu_instr[6:0] == `REX) ? fcu_bus :
    (IsBrk(fcu_instr)) ? {tvec[0][31:8], ol[fcu_thrd], 5'h0} :
    (IsRet(fcu_instr)) ? fcu_argB:
    (IsJAL(fcu_instr)) ? fcu_argA + fcu_argI:
    (fcu_instr[6:0] == OP_CHK) ? (fcu_pc + 32'd4 + fcu_argI) :
    (fcu_instr[6:0] == OP_BccR) ? (~fcu_takb ? fcu_pc + 4 : fcu_argC) :
                                            (~fcu_takb ? fcu_pc + 4 : fcu_pc + 4 + 
                                            {{51{fcu_instr[`INSTRUCTION_SB]}},fcu_instr[31:22],fcu_instr[0],2'b00});
                                            
                                            //fcu_argI);
// To avoid false branch mispredicts the branch isn't evaluated until the
// following instruction queues. The address of the next instruction is
// looked at to see if the BTB predicted correctly.

wire fcu_brk_miss = (IsBrk(fcu_instr) || IsRTI(fcu_instr)) && fcu_v;
wire fcu_ret_miss = IsRet(fcu_instr) && fcu_v && (fcu_argB != iqentry_pc[thread_en ? idp2(fcu_id) : idp1(fcu_id)]);
wire fcu_jal_miss = IsJAL(fcu_instr) && fcu_v && fcu_argA + fcu_argI != iqentry_pc[thread_en ? idp2(fcu_id) : idp1(fcu_id)];
wire fcu_followed = iqentry_sn[nid] > iqentry_sn[fcu_idQNDX];
always_comb
if (fcu_dataready) begin
//	if (fcu_timeout[7])
//		fcu_branchmiss = TRUE;
	// Break and RTI switch register sets, and so are always treated as a branch miss in order to
	// flush the pipeline. Hardware interrupts also stream break instructions so they need to 
	// flushed from the queue so the interrupt is recognized only once.
	// BRK and RTI are handled as excmiss types which are processed during the commit stage.
//	else
	if (fcu_brk_miss)
		fcu_branchmiss = TRUE & ~fcu_clearbm;
    // the following instruction is queued
	else
	if (fcu_followed) begin
`ifdef SUPPORT_SMT		
		if (fcu_instr[6:0] == `REX && (im < ~ol[fcu_thrd]) && fcu_v)
`else
		if (fcu_instr[6:0] == `REX && (im < ~ol) && fcu_v)
`endif		
			fcu_branchmiss = TRUE & ~fcu_clearbm;
		else if (fcu_ret_miss)
			fcu_branchmiss = TRUE & ~fcu_clearbm;
		else if (IsBranch(fcu_instr) && fcu_v && (((fcu_takb && (~fcu_bt || (fcu_misspc != iqentry_pc[nid]))) ||
		                            (~fcu_takb && ( fcu_bt || (fcu_pc + 32'd4 != iqentry_pc[nid])))) || iqentry_v[nid]))
		    fcu_branchmiss = TRUE & ~fcu_clearbm;
		else if (fcu_jal_miss)
		    fcu_branchmiss = TRUE & ~fcu_clearbm;
		else if (fcu_instr[6:0] == OP_CHK && ~fcu_takb && fcu_v)
		    fcu_branchmiss = TRUE & ~fcu_clearbm;
		else
		    fcu_branchmiss = FALSE;
	end
	else begin
		// Stuck at the head and can't finish because there's still an uncommitted instruction in the queue.
		// -> cause a branch miss to clear the queue.
		if (iqentry_v[nid] && !IsCall(fcu_instr) && !IsJmp(fcu_instr) && fcu_v)
			fcu_branchmiss = TRUE & ~fcu_clearbm;
		else
		/*
		if (fcu_id==head0 && iqentry_v[idp1(head0)]) begin
			if ((fcu_bus[0] && (~fcu_bt || (fcu_misspc == iqentry_pc[nid]))) ||
		                            (~fcu_bus[0] && ( fcu_bt || (fcu_pc + 32'd4 == iqentry_pc[nid]))))
		        fcu_branchmiss = FALSE;
		    else
				fcu_branchmiss = TRUE;
		end
		else if (fcu_id==head1 && iqentry_v[idp2(head1)]) begin
			if ((fcu_bus[0] && (~fcu_bt || (fcu_misspc == iqentry_pc[nid]))) ||
		                            (~fcu_bus[0] && ( fcu_bt || (fcu_pc + 32'd4 == iqentry_pc[nid]))))
		        fcu_branchmiss = FALSE;
		    else
				fcu_branchmiss = TRUE;
		end
		else*/
			fcu_branchmiss = FALSE;
	end
end
else
	fcu_branchmiss = FALSE;
/*
assign fcu_branchmiss = fcu_dataready &&
            // and the following instruction is queued
            iqentry_v[idp1(fcu_id)] && iqentry_sn[idp1(fcu_id)]==iqentry_sn[fcu_idQNDX]+5'd1 && 
            ((IsBrk(fcu_instr) || IsRTI(fcu_instr)) ||
            ((fcu_instr[6:0] == `REX && (im < ~ol)) ||
            (fcu_instr[6:0] == OP_CHK && ~fcu_bus[0]) ||
		   (IsRTI(fcu_instr) && epc != iqentry_pc[idp1(fcu_idQNDX)]) ||
		   // If it's a ret and the return address doesn't match the address of the
		   // next queued instruction then the return prediction was wrong.
		   (/*IsRet(fcu_instr) &&
		     IsRet(fcu_instr) && ((fcu_argB != iqentry_pc[idp1(fcu_id)]) || (iqentry_sn[fcu_idQNDX]+5'd1!=iqentry_sn[idp1(fcu_id)]) || !iqentry_v[idp1(fcu_id)])) ||
		   (IsBrk(fcu_instr) && {tvec[0][31:8], ol, 5'h0} != iqentry_pc[idp1(fcu_id)]) ||
//			   (fcu_instr[6:0] == OP_BccR && fcu_argC != iqentry_pc[(fcu_idQNDX+3'd1)&7] && fcu_bus[0]) ||
		    (IsBranch(fcu_instr) && ((fcu_bus[0] && (~fcu_bt || (fcu_misspc != iqentry_pc[idp1(fcu_id)]))) ||
		                            (~fcu_bus[0] && ( fcu_bt || (fcu_pc + 32'd4 != iqentry_pc[idp1(fcu_id)]))))) ||
		    (IsJAL(fcu_instr)) && fcu_argA + fcu_argI != iqentry_pc[idp1(fcu_id)]));
*/

// Flow control ops don't issue until the next instruction queues.
// The fcu_timeout tracks how long the flow control op has been in the "out" state.
// It should never be that way more than a couple of cycles. Sometimes the fcu_wr pulse got missed
// because the following instruction got stomped on during a branchmiss, hence iqentry_v isn't true.
wire fcu_wr = (fcu_v && iqentry_v[nid] && iqentry_sn[nid] > iqentry_sn[fcu_idQNDX]);//	// && iqentry_v[nid]
//					&& fcu_instr==iqentry_instr[fcu_idQNDX]);// || fcu_timeout==8'h05;

	Gam_AMO_alu uamoalu0 (amo_instr, amo_argA, amo_argB, amo_res);

//assign fcu_done = IsWait(fcu_instr) ? ((waitctr==64'd1) || signal_i[fcu_argA[4:0]|fcu_argI[4:0]]) :
//					fcu_v && iqentry_v[idp1(fcu_id)] && iqentry_sn[idp1(fcu_id)]==iqentry_sn[fcu_idQNDX]+5'd1;

// An exception in a committing instruction takes precedence
/*
Too slow. Needs to be registered
assign  branchmiss = excmiss|fcu_branchmiss,
    misspc = excmiss ? excmisspc : fcu_misspc,
    missid = excmiss ? (|iqentry_exc[head0] ? head0 : head1) : fcu_sourceid;
assign branchmiss_thrd =  excmiss ? excthrd : fcu_thrd;
*/

//
// additional DRAM-enqueue logic

assign dram_avail = (dram0 == `DRAMSLOT_AVAIL || dram1 == `DRAMSLOT_AVAIL || dram2 == `DRAMSLOT_AVAIL);

assign  iqentry_memopsvalid[0] = (iqentry_mem[0] & iqentry_a2_v[0] & iqentry_agen[0]),
    iqentry_memopsvalid[1] = (iqentry_mem[1] & iqentry_a2_v[1] & iqentry_agen[1]),
    iqentry_memopsvalid[2] = (iqentry_mem[2] & iqentry_a2_v[2] & iqentry_agen[2]),
    iqentry_memopsvalid[3] = (iqentry_mem[3] & iqentry_a2_v[3] & iqentry_agen[3]),
    iqentry_memopsvalid[4] = (iqentry_mem[4] & iqentry_a2_v[4] & iqentry_agen[4]),
    iqentry_memopsvalid[5] = (iqentry_mem[5] & iqentry_a2_v[5] & iqentry_agen[5]),
    iqentry_memopsvalid[6] = (iqentry_mem[6] & iqentry_a2_v[6] & iqentry_agen[6]),
    iqentry_memopsvalid[7] = (iqentry_mem[7] & iqentry_a2_v[7] & iqentry_agen[7]);

assign  iqentry_memready[0] = (iqentry_v[0] & iqentry_memopsvalid[0] & ~iqentry_memissue[0] & ~iqentry_done[0] & ~iqentry_out[0] & ~iqentry_stomp[0]),
    iqentry_memready[1] = (iqentry_v[1] & iqentry_memopsvalid[1] & ~iqentry_memissue[1] & ~iqentry_done[1] & ~iqentry_out[1] & ~iqentry_stomp[1]),
    iqentry_memready[2] = (iqentry_v[2] & iqentry_memopsvalid[2] & ~iqentry_memissue[2] & ~iqentry_done[2] & ~iqentry_out[2] & ~iqentry_stomp[2]),
    iqentry_memready[3] = (iqentry_v[3] & iqentry_memopsvalid[3] & ~iqentry_memissue[3] & ~iqentry_done[3] & ~iqentry_out[3] & ~iqentry_stomp[3]),
    iqentry_memready[4] = (iqentry_v[4] & iqentry_memopsvalid[4] & ~iqentry_memissue[4] & ~iqentry_done[4] & ~iqentry_out[4] & ~iqentry_stomp[4]),
    iqentry_memready[5] = (iqentry_v[5] & iqentry_memopsvalid[5] & ~iqentry_memissue[5] & ~iqentry_done[5] & ~iqentry_out[5] & ~iqentry_stomp[5]),
    iqentry_memready[6] = (iqentry_v[6] & iqentry_memopsvalid[6] & ~iqentry_memissue[6] & ~iqentry_done[6] & ~iqentry_out[6] & ~iqentry_stomp[6]),
    iqentry_memready[7] = (iqentry_v[7] & iqentry_memopsvalid[7] & ~iqentry_memissue[7] & ~iqentry_done[7] & ~iqentry_out[7] & ~iqentry_stomp[7]);

assign outstanding_stores = (dram0 && IsStore(dram0_instr)) ||
                            (dram1 && IsStore(dram1_instr)) ||
                            (dram2 && IsStore(dram2_instr));

//
// additional COMMIT logic
//
always_comb
begin
    commit0_v <= ({iqentry_v[head0], iqentry_cmt[head0]} == 2'b11 && ~|panic);
    commit0_id <= {iqentry_mem[head0], head0};	// if a memory op, it has a DRAM-bus id
    commit0_tgt <= iqentry_tgt[head0];
    commit0_we  <= iqentry_we[head0];
    commit0_bus <= iqentry_res[head0];
    commit1_v <= ({iqentry_v[head0], iqentry_cmt[head0]} != 2'b10
               && {iqentry_v[head1], iqentry_cmt[head1]} == 2'b11
               && ~|panic);
    commit1_id <= {iqentry_mem[head1], head1};
    commit1_tgt <= iqentry_tgt[head1];  
    commit1_we  <= iqentry_we[head1];
    commit1_bus <= iqentry_res[head1];
end
    
assign int_commit = (commit0_v && IsBrk(iqentry_instr[head0])) ||
                    (commit0_v && commit1_v && IsBrk(iqentry_instr[head1]));

/*always @(posedge clk)
    rf_vra0 <= regIsValid[Ra0s];
always @(posedge clk)
    rf_vra1 <= regIsValid[Ra1s];
*/
// Check how many instructions can be queued. This might be fewer than the
// number ready to queue from the fetch stage if queue slots aren't
// available or if there are no more physical registers left for remapping.
// The fetch stage needs to know how many instructions will queue so this
// logic is placed here.
// NOPs are filtered out and do not enter the instruction queue. The core
// will stream NOPs on a cache miss and they would mess up the queue order
// if there are immediate prefixes in the queue.
// For the VEX instruction, the instruction can't queue until register Ra
// is valid, because register Ra is used to specify the vector element to
// read.
wire q2open = iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV;
wire q3open = iqentry_v[tail0]==`INV && iqentry_v[tail1]==`INV && iqentry_v[idp1(tail1)]==`INV;
always_comb
begin
    canq1 <= FALSE;
    canq2 <= FALSE;
    queued1 <= FALSE;
    queued2 <= FALSE;
    queuedNop <= FALSE;
    vqueued2 <= FALSE;
    if (!branchmiss) begin
        // Two available
        if (fetchbuf1_v & fetchbuf0_v) begin
            // Is there a pair of NOPs ? (cache miss)
            if ((insn0a[6:0]==`NOP) && (insn1a[6:0]==`NOP))
                queuedNop <= TRUE; 
            else begin
                // If it's a predicted branch queue only the first instruction, the second
                // instruction will be stomped on.
                if (take_branch0 && fetchbuf1_thrd==fetchbuf0_thrd) begin
                    if (iqentry_v[tail0]==`INV) begin
                        canq1 <= TRUE;
                        queued1 <= TRUE;
                    end
                end
                // This is where a single NOP is allowed through to simplify the code. A
                // single NOP can't be a cache miss. Otherwise it would be necessary to queue
                // fetchbuf1 on tail0 it would add a nightmare to the enqueue code.
                // Not a branch and there are two instructions fetched, see whether or not
                // both instructions can be queued.
                else begin
                    if (iqentry_v[tail0]==`INV) begin
                        canq1 <= !IsVex(insn0a) || rf_vra0 || !SUP_VECTOR;
                        queued1 <= (
                        	((!IsVex(insn0a) || rf_vra0) && (!IsVector(insn0a))) || !SUP_VECTOR);
                        if (iqentry_v[tail1]==`INV) begin
                            canq2 <= ((!IsVex(insn1a) || rf_vra1)) || !SUP_VECTOR;
                            queued2 <= (
                            	(!IsVector(insn1a) && (!IsVex(insn1a) || rf_vra1) && (!IsVector(insn0a))) || !SUP_VECTOR);
                            vqueued2 <= IsVector(insn0a) && vqe0 < vl-2 && !vechain;
                        end
                    end
                    // If an irq is active during a vector instruction fetch, claim the vector instruction
                    // is finished queueing even though it may not be. It'll pick up where it left off after
                    // the exception is processed.
                    if (hirq) begin
                    	if (IsVector(insn0a) && IsVector(insn1a) && vechain) begin
                    		queued1 <= TRUE;
                    		queued2 <= TRUE;
                    	end
                    	else if (IsVector(insn0a)) begin
                    		queued1 <= TRUE;
                    		if (vqe0 < vl-2)
                    			queued2 <= TRUE;
                    		else
                    			queued2 <= iqentry_v[tail1]==`INV;
                    	end
                    end
                end
            end
        end
        // One available
        else if (fetchbuf0_v) begin
            if (insn0a[6:0]!=`NOP) begin
                if (iqentry_v[tail0]==`INV) begin
                    canq1 <= !IsVex(insn0a) || rf_vra0 || !SUP_VECTOR;
                    queued1 <=  
                    	(((!IsVex(insn0a) || rf_vra0) && (!IsVector(insn0a))) || !SUP_VECTOR);
                end
                if (iqentry_v[tail1]==`INV) begin
                	canq2 <= IsVector(insn0a) && vqe0 < vl-2 && SUP_VECTOR;
                    vqueued2 <= IsVector(insn0a) && vqe0 < vl-2 && !vechain;
            	end
            	if (hirq) begin
                	if (IsVector(insn0a)) begin
                		queued1 <= TRUE;
                		if (vqe0 < vl-2)
                			queued2 <= iqentry_v[tail1]==`INV;
                	end
            	end
            end
            else
                queuedNop <= TRUE;
        end
        else if (fetchbuf1_v) begin
            if (insn1a[6:0]!=`NOP) begin
                if (iqentry_v[tail0]==`INV) begin
                    canq1 <= !IsVex(insn1a) || rf_vra1 || !SUP_VECTOR;
                    queued1 <= (
                    	((!IsVex(insn1a) || rf_vra1) && (!IsVector(insn1a))) || !SUP_VECTOR);
                end
                if (iqentry_v[tail1]==`INV) begin
                	canq2 <= IsVector(insn1a) && vqe1 < vl-2 && SUP_VECTOR;
                    vqueued2 <= IsVector(insn1a) && vqe1 < vl-2;
            	end
            	if (hirq) begin
                	if (IsVector(insn1a)) begin
                		queued1 <= TRUE;
                		if (vqe1 < vl-2)
                			queued2 <= iqentry_v[tail1]==`INV;
                	end
            	end
            end
            else
                queuedNop <= TRUE;
        end
        //else no instructions available to queue
    end
    else begin
        // One available
        if (fetchbuf0_v && fetchbuf0_thrd != branchmiss_thrd) begin
            if (insn0a[6:0]!=`NOP) begin
                if (iqentry_v[tail0]==`INV) begin
                    canq1 <= !IsVex(insn0a) || rf_vra0 || !SUP_VECTOR;
                    queued1 <= (
                    	((!IsVex(insn0a) || rf_vra0) && (!IsVector(insn0a))) || !SUP_VECTOR);
                end
                if (iqentry_v[tail1]==`INV) begin
                	canq2 <= IsVector(insn0a) && vqe0 < vl-2 && SUP_VECTOR;
                    vqueued2 <= IsVector(insn0a) && vqe0 < vl-2 && !vechain;
            	end
            end
            else
                queuedNop <= TRUE;
        end
        else if (fetchbuf1_v && fetchbuf1_thrd != branchmiss_thrd) begin
            if (insn1a[6:0]!=`NOP) begin
                if (iqentry_v[tail0]==`INV) begin
                    canq1 <= !IsVex(insn1a) || rf_vra1 || !SUP_VECTOR;
                    queued1 <= (
                    	((!IsVex(insn1a) || rf_vra1) && (!IsVector(insn1a))) || !SUP_VECTOR);
                end
                if (iqentry_v[tail1]==`INV) begin
                	canq2 <= IsVector(insn1a) && vqe1 < vl-2 && SUP_VECTOR;
                    vqueued2 <= IsVector(insn0a) && vqe0 < vl-2 && !vechain;
            	end
            end
            else
                queuedNop <= TRUE;
        end
	end
end

//
// Branchmiss seems to be sticky sometimes during simulation. For instance branch miss
// and cache miss at same time. The branchmiss should clear before the core continues
// so the positive edge is detected to avoid incrementing the sequnce number too many
// times.
wire pebm;
edge_det uedbm (.rst(rst), .clk(clk), .ce(1'b1), .i(branchmiss), .pe(pebm), .ne(), .ee() );

reg [5:0] ld_time;
reg [63:0] wc_time_dat;
reg [63:0] wc_times;
always @(posedge tm_clk_i)
begin
	if (|ld_time)
		wc_time <= wc_time_dat;
	else begin
		wc_time[31:0] <= wc_time[31:0] + 32'd1;
		if (wc_time[31:0] >= TM_CLKFREQ-1) begin
			wc_time[31:0] <= 32'd0;
			wc_time[63:32] <= wc_time[63:32] + 32'd1;
		end
	end
end

// Monster clock domain.
// Like to move some of this to clocking under different always blocks in order
// to help out the toolset's synthesis, but it ain't gonna be easy.
// Simulation doesn't like it if things are under separate always blocks.
// Synthesis doesn't like it if things are under the same always block.

always @(posedge clk)
begin
	branchmiss <= excmiss|fcu_branchmiss;
    misspc <= excmiss ? excmisspc : fcu_misspc;
    missid <= excmiss ? (|iqentry_exc[head0] ? head0 : head1) : fcu_sourceid;
	branchmiss_thrd <=  excmiss ? excthrd : fcu_thrd;
end

always @(posedge clk)
if (rst) begin
	for (n = 0; n < NTHREAD; n = n + 1)
     	mstatus[n] <= 64'h0007;	// select register set #0 for thread 0
    for (n = 0; n < QENTRIES; n = n + 1) begin
         iqentry_v[n] <= 1'b0;
         iqentry_done[n] <= 1'b0;
         iqentry_cmt[n] <= 1'b0;
         iqentry_out[n] <= 1'b0;
         iqentry_agen[n] <= 1'b0;
         iqentry_sn[n] <= 8'd0;
         iqentry_bt[n] <= 1'b0;
    	 iqentry_instr[n] <= `NOP_INSN;
    	 iqentry_mem[n] <= 1'b0;
    	 iqentry_memndx[n] <= FALSE;
         iqentry_memissue[n] <= FALSE;
         iqentry_tgt[n] <= 6'd0;
         iqentry_a1[n] <= 64'd0;
         iqentry_a2[n] <= 64'd0;
         iqentry_a3[n] <= 64'd0;
         iqentry_a1_v[n] <= `INV;
         iqentry_a2_v[n] <= `INV;
         iqentry_a3_v[n] <= `INV;
         iqentry_a1_s[n] <= 5'd0;
         iqentry_a2_s[n] <= 5'd0;
         iqentry_a3_s[n] <= 5'd0;
    end
     dram0 <= `DRAMSLOT_AVAIL;
     dram1 <= `DRAMSLOT_AVAIL;
     dram2 <= `DRAMSLOT_AVAIL;
     dram0_instr <= `NOP_INSN;
     dram1_instr <= `NOP_INSN;
     dram2_instr <= `NOP_INSN;
     dram0_addr <= 32'h0;
     dram1_addr <= 32'h0;
     dram2_addr <= 32'h0;
     L1_adr <= RSTPC;
     invic <= FALSE;
     tail0 <= 3'd0;
     tail1 <= 3'd1;
     head0 <= 0;
     head1 <= 1;
     head2 <= 2;
     head3 <= 3;
     head4 <= 4;
     head5 <= 5;
     head6 <= 6;
     head7 <= 7;
     panic = `PANIC_NONE;
     alu0_available <= 1;
     alu0_dataready <= 0;
     alu1_available <= 1;
     alu1_dataready <= 0;
     alu0_sourceid <= 5'd0;
     alu1_sourceid <= 5'd0;
     fcu_dataready <= 0;
     fcu_instr <= `NOP_INSN;
     fcu_retadr_v <= 0;
     dramA_v <= 0;
     dramB_v <= 0;
     dramC_v <= 0;
     I <= 0;
     icstate <= IDLE;
     bstate <= BIDLE;
     tick <= 64'd0;
     bte_o <= 2'b00;
     cti_o <= 3'b000;
     cyc_o <= `LOW;
     stb_o <= `LOW;
     we_o <= `LOW;
     sel_o <= 8'h00;
     sr_o <= `LOW;
     cr_o <= `LOW;
     adr_o <= RSTPC;
     icl_o <= `LOW;      	// instruction cache load
     cr0 <= 64'd0;
     cr0[13:8] <= 6'd0;		// select register set #0
     cr0[30] <= TRUE;    	// enable data caching
     cr0[32] <= TRUE;    	// enable branch predictor
     cr0[16] <= 1'b0;		// disable SMT
     cr0[17] <= 1'b0;		// sequence number reset = 1
     pcr <= 32'd0;
     pcr2 <= 64'd0;
    for (n = 0; n < PREGS; n = n + 1)
         rf_v[n] <= `VAL;
     tgtq <= FALSE;
     fp_rm <= 3'd0;			// round nearest even - default rounding mode
     waitctr <= 64'd0;
    for (n = 0; n < 16; n = n + 1)
         badaddr[n] <= 64'd0;
     sbl <= 32'h0;
     sbu <= 32'hFFFFFFFF;
    // Vector
     vqe0 <= 6'd0;
     vqet0 <= 6'd0;
     vqe1 <= 6'd0;
     vqet1 <= 6'd0;
     vl <= 7'd62;
    for (n = 0; n < 8; n = n + 1)
         vm[n] <= 64'h7FFFFFFFFFFFFFFF;
     nop_fetchbuf <= 4'h0;
     seq_num <= 5'd0;
     seq_num1 <= 5'd0;
     fcu_done <= TRUE;
     sema <= 64'h0;
end
else begin
	idu0_ld <= FALSE;
	idu1_ld <= FALSE;
	idu0_v <= `INV;
	idu1_v <= `INV;
	ld_time <= {ld_time[4:0],1'b0};
	wc_times <= wc_time;
     rf_vra0 <= regIsValid[Ra0s];
     rf_vra1 <= regIsValid[Ra1s];
    if (vqe0 >= vl) begin
         vqe0 <= 6'd0;
         vqet0 <= 6'h0;
    end
    if (vqe1 >= vl) begin
         vqe1 <= 6'd0;
         vqet1 <= 6'h0;
    end
    // Turn off vector chaining indicator when chained instructions are done.
    if ((vqe0 >= vl || vqe0==6'd0) && (vqe1 >= vl || vqe1==6'd0))
    	mstatus[0][32] <= 1'b0;

     nop_fetchbuf <= 4'h0;
     excmiss <= FALSE;
     invic <= FALSE;
     tick <= tick + 64'd1;
     alu0_ld <= FALSE;
     alu1_ld <= FALSE;
     fpu_ld <= FALSE;
     fcu_ld <= FALSE;
     fcu_retadr_v <= FALSE;
     dramA_v <= FALSE;
     dramB_v <= FALSE;
     dramC_v <= FALSE;
     cr0[17] <= 1'b0;
    if (waitctr != 64'd0)
         waitctr <= waitctr - 64'd1;


    if (IsFlowCtrl(iqentry_instr[fcu_idQNDX]) && iqentry_v[fcu_idQNDX] && !iqentry_done[fcu_idQNDX] && iqentry_out[fcu_idQNDX])
    	fcu_timeout <= fcu_timeout + 8'd1;

    //
    // ENQUEUE
    //
    // place up to two instructions from the fetch buffer into slots in the IQ.
    //   note: they are placed in-order, and they are expected to be executed
    // 0, 1, or 2 of the fetch buffers may have valid data
    // 0, 1, or 2 slots in the instruction queue may be available.
    // if we notice that one of the instructions in the fetch buffer is a predicted branch,
    // (set branchback/backpc and delete any instructions after it in fetchbuf)
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
		    if (canq1) begin
	            if (IsVector(insn1a) && SUP_VECTOR) begin
	                 vqe1 <= vqe1 + 4'd1;
	                if (IsVCmprss(insn1a)) begin
	                    if (vm[insn1a[25:23]][vqe1])
	                         vqet1 <= vqet1 + 4'd1;
	                end
	                else
	                     vqet1 <= vqet1 + 4'd1; 
	                if (vqe1 >= vl-2)
	                	 nop_fetchbuf <= fetchbuf ? 4'b0100 : 4'b0001;
		            enque1(tail0, vqe1);
		             tgtq <= FALSE;
		            if (fetchbuf1_rfw) begin
		                 rf_source[ Rt1s ] <= { 1'b0, fetchbuf1_memld, tail0 };	// top bit indicates ALU/MEM bus
		                 rf_v [Rt1s] <= `INV;
		            end
	                if (canq2 && vqe1 < vl-2) begin
		                 vqe1 <= vqe1 + 4'd2;
		                if (IsVCmprss(insn1a)) begin
		                    if (vm[insn1a[25:23]][vqe1+6'd1])
		                         vqet1 <= vqet1 + 4'd2;
		                end
		                else
		                     vqet1 <= vqet1 + 4'd2;
			            enque1(tail1, vqe1 + 6'd1);
			             tgtq <= FALSE;
	            	end
	            end
	            else begin
		            enque1(tail0, 6'd0);
		             tgtq <= FALSE;
	        	end
		    end

	    2'b10:
	    	if (canq1) begin
//		    $display("queued1: %d", queued1);
//			if (!IsBranch(insn0a))		panic <= `PANIC_FETCHBUFBEQ;
//			if (!predict_taken0)	panic <= `PANIC_FETCHBUFBEQ;
			//
			// this should only happen when the first instruction is a BEQ-backwards and the IQ
			// happened to be full on the previous cycle (thus we deleted fetchbuf1 but did not
			// enqueue fetchbuf0) ... probably no need to check for LW -- sanity check, just in case
			//
	            if (IsVector(insn0a) && SUP_VECTOR) begin
	                 vqe0 <= vqe0 + 4'd1;
	                if (IsVCmprss(insn0a)) begin
	                    if (vm[insn0a[25:23]][vqe0])
	                         vqet0 <= vqet0 + 4'd1;
	                end
	                else
	                     vqet0 <= vqet0 + 4'd1;
	                if (vqe0 >= vl-2)
	                	 nop_fetchbuf <= fetchbuf ? 4'b1000 : 4'b0010;
		    		enque0(tail0, vqe0);
		             tgtq <= FALSE;
	                if (canq2) begin
			            if (vqe0 < vl-2) begin
			                 vqe0 <= vqe0 + 4'd2;
			                if (IsVCmprss(insn0a)) begin
			                    if (vm[insn0a[25:23]][vqe0+6'd1])
			                         vqet0 <= vqet0 + 4'd2;
			                end
			                else
			                     vqet0 <= vqet0 + 4'd2;
			    			enque0(tail1, vqe0 + 6'd1);
				             tgtq <= FALSE;
			            end
	            	end
	            end
	            else begin
		    		enque0(tail0, 6'd0);
		             tgtq <= FALSE;
		        end
		    end

	    2'b11:
		    if (canq1) begin
				//
				// if the first instruction is a predicted branch, enqueue it & stomp on all following instructions
				// but only if the following instruction is in the same thread. Otherwise we want to queue two.
				//
				if (take_branch0 && fetchbuf1_thrd==fetchbuf0_thrd) begin
		             tgtq <= FALSE;
		            enque0(tail0,6'd0);
				end

				else begin	// fetchbuf0 doesn't contain a predicted branch
				    //
				    // so -- we can enqueue 1 or 2 instructions, depending on space in the IQ
				    // update the rf_v and rf_source bits separately (at end)
				    //   the problem is that if we do have two instructions, 
				    //   they may interact with each other, so we have to be
				    //   careful about where things point.
				    //
				    // enqueue the first instruction ...
				    //
		            if (IsVector(insn0a) && SUP_VECTOR) begin
		                 vqe0 <= vqe0 + 4'd1;
		                if (IsVCmprss(insn0a)) begin
		                    if (vm[insn0a[25:23]][vqe0])
		                         vqet0 <= vqet0 + 4'd1;
		                end
		                else
		                     vqet0 <= vqet0 + 4'd1; 
		                if (vqe0 >= vl-2)
		                	nop_fetchbuf <= fetchbuf ? 4'b1000 : 4'b0010;
		            end
		            tgtq <= FALSE;
		            if (vqe0 < vl || !IsVector(insn0a)) begin
			            enque0(tail0, vqe0);
					    //
					    // if there is room for a second instruction, enqueue it
					    //
					    if (canq2) begin
					    	if (vechain && IsVector(insn1a)
					    	&& Ra1s != Rt0s	// And there is no dependency
					    	&& Rb1s != Rt0s
					    	&& Rc1s != Rt0s
					    	) begin
`ifdef SUPPORT_SMT					    		
					    		mstatus[0][32] <= 1'b1;
`else
					    		mstatus[32] <= 1'b1;
`endif					    		
				                vqe1 <= vqe1 + 4'd1;
				                if (IsVCmprss(insn1a)) begin
				                    if (vm[insn1a[25:23]][vqe1])
				                         vqet1 <= vqet1 + 4'd1;
				                end
				                else
				                     vqet1 <= vqet1 + 4'd1; 
				                if (vqe1 >= vl-2)
				                	nop_fetchbuf <= fetchbuf ? 4'b0100 : 4'b0001;
					      		enque1(tail1, 6'd0);

					    	end
					    	// If there was a vector instruction in fetchbuf0, we really
					    	// want to queue the next vector element, not the next
					    	// instruction waiting in fetchbuf1.
				            else if (IsVector(insn0a) && SUP_VECTOR && vqe0 < vl-1) begin
				                 vqe0 <= vqe0 + 4'd2;
				                if (IsVCmprss(insn0a)) begin
				                    if (vm[insn0a[25:23]][vqe0+6'd1])
				                         vqet0 <= vqet0 + 4'd2;
				                end
				                else
				                     vqet0 <= vqet0 + 4'd2; 
				                if (vqe0 >= vl-3)
			    	            	 nop_fetchbuf <= fetchbuf ? 4'b1000 : 4'b0010;
			    	            if (vqe0 < vl-1) begin
						      		enque0(tail1, vqe0 + 6'd1);
								end
				        	end
				            else if (IsVector(insn1a) && SUP_VECTOR) begin
			            		 vqe1 <= 6'd1;
				                if (IsVCmprss(insn1a)) begin
				                    if (vm[insn1a[25:23]][IsVector(insn0a)? 6'd0:vqe1+6'd1])
			                        	 vqet1 <= 6'd1;
			                        else
			                        	 vqet1 <= 6'd0;
				                end
				                else
			                   		 vqet1 <= 6'd1; 
			                    if (IsVector(insn0a) && SUP_VECTOR)
			   	            		nop_fetchbuf <= fetchbuf ? 4'b1000 : 4'b0010;
					      		enque1(tail1, 6'd0);

				            end
				            else begin
//					      		enque1(tail1, seq_num + 5'd1, 6'd0);
					      		enque1(tail1, 6'd0);
							end

					    end	// ends the "if IQ[tail1] is available" clause
				    end

				end	// ends the "else fetchbuf0 doesn't have a backwards branch" clause
		    end
		endcase

    //
    // DATAINCOMING
    //
    // wait for operand/s to appear on alu busses and puts them into 
    // the iqentry_a1 and iqentry_a2 slots (if appropriate)
    // as well as the appropriate iqentry_res slots (and setting valid bits)
	//
	// put results into the appropriate instruction entries
	//
    // This chunk of code has to be before the enqueue stage so that the agen bit
    // can be reset to zero by enqueue.
    // put results into the appropriate instruction entries
    //
    if (IsMul(alu0_instr)|IsDivmod(alu0_instr)) begin
        if (alu0_done) begin
             alu0_dataready <= TRUE;
        end
    end

	if (alu0_v) begin
	     iqentry_tgt [ alu0_idQNDX ] <= alu0_tgt;
         iqentry_res	[ alu0_idQNDX ] <= alu0_bus;
         iqentry_exc	[ alu0_idQNDX ] <= alu0_exc;
         iqentry_done[ alu0_idQNDX ] <= !iqentry_mem[ alu0_idQNDX ] && alu0_done;
         iqentry_cmt[ alu0_idQNDX ] <= !iqentry_mem[ alu0_idQNDX ] && alu0_done;
         iqentry_out	[ alu0_idQNDX ] <= `INV;
         iqentry_agen[ alu0_idQNDX ] <= `VAL;//!iqentry_fc[alu0_idQNDX];  // RET
         alu0_dataready <= FALSE;
	end
	if (alu1_v) begin
	     iqentry_tgt [ alu1_idQNDX ] <= alu1_tgt;
         iqentry_res	[ alu1_idQNDX ] <= alu1_bus;
         iqentry_exc	[ alu1_idQNDX ] <= alu1_exc;
         iqentry_done[ alu1_idQNDX ] <= !iqentry_mem[ alu1_idQNDX ] && alu1_done;
         iqentry_cmt[ alu1_idQNDX ] <= !iqentry_mem[ alu1_idQNDX ] && alu1_done;
         iqentry_out	[ alu1_idQNDX ] <= `INV;
         iqentry_agen[ alu1_idQNDX ] <= `VAL;//!iqentry_fc[alu1_idQNDX];  // RET
         alu1_dataready <= FALSE;
	end
	if (fpu_v) begin
         iqentry_res    [ fpu_idQNDX ] <= fpu_bus;
         iqentry_a0     [ fpu_idQNDX ] <= fpu_status; 
         iqentry_exc    [ fpu_idQNDX ] <= fpu_exc;
         iqentry_done[ fpu_idQNDX ] <= fpu_done;
         iqentry_cmt[ fpu_idQNDX ] <= fpu_done;
         iqentry_out    [ fpu_idQNDX ] <= `INV;
         //iqentry_agen[ fpu_idQNDX ] <= `VAL;  // RET
         fpu_dataready <= FALSE;
    end
	if (fcu_wr) begin
	    if (fcu_ld)
	        waitctr <= fcu_argA;
        iqentry_res [ fcu_idQNDX ] <= fcu_bus;
        iqentry_exc [ fcu_idQNDX ] <= fcu_exc;
        if (IsWait(fcu_instr)) begin
             iqentry_done [ fcu_idQNDX ] <= (waitctr==64'd1) || signal_i[fcu_argA[4:0]|fcu_argI[4:0]];
             iqentry_cmt [ fcu_idQNDX ] <= (waitctr==64'd1) || signal_i[fcu_argA[4:0]|fcu_argI[4:0]];
             fcu_done <= TRUE;
        end
        else begin
             iqentry_done[ fcu_idQNDX ] <= TRUE;
             iqentry_cmt[ fcu_idQNDX ] <= TRUE;
             fcu_done <= TRUE;
        end
//            if (IsWait(fcu_instr) ? (waitctr==64'd1) || signal_i[fcu_argA[4:0]|fcu_argI[4:0]] : !IsMem(fcu_instr) && !IsImmp(fcu_instr))
//                iqentry_instr[ dram_idQNDX] <= `NOP_INSN;
        // Only safe place to propagate the miss pc is a0.
        iqentry_a0[ fcu_idQNDX ] <= fcu_misspc;
        // Update branch taken indicator.
        if (IsJAL(fcu_instr) || IsRet(fcu_instr) || IsBrk(fcu_instr) || IsRTI(fcu_instr) ) begin
             iqentry_bt[ fcu_idQNDX ] <= `VAL;
            // Only safe place to propagate the miss pc is a0.
//             iqentry_a0[ fcu_idQNDX ] <= fcu_misspc;
        end
        else if (IsBranch(fcu_instr)) begin
             iqentry_bt[ fcu_idQNDX ] <= fcu_takb;
//             iqentry_a0[ fcu_idQNDX ] <= fcu_misspc;
        end 
         iqentry_out [ fcu_idQNDX ] <= `INV;
         //iqentry_agen[ fcu_idQNDX ] <= `VAL;//!IsRet(fcu_instr);
       	fcu_dataready <= `VAL;
         //fcu_dataready <= fcu_branchmiss || !iqentry_agen[ fcu_idQNDX ] || !(iqentry_mem[ fcu_idQNDX ] && IsLoad(iqentry_instr[fcu_idQNDX]));
         //fcu_instr[6:0] <= fcu_branchmiss|| (!IsMem(fcu_instr) && !IsWait(fcu_instr))? `NOP : fcu_instr[6:0]; // to clear branchmiss
	end
	// Clear a branch miss when target instruction is fetched.
	if (fcu_branchmiss) begin
		if ((fetchbuf0_v && fetchbuf0_pc==misspc) ||
			(fetchbuf1_v && fetchbuf1_pc==misspc))
		fcu_clearbm <= TRUE;
		//fcu_instr[6:0] <= `NOP;
		//iqentry_instr[fcu_id][6:0] <= `NOP;
	end

//	if (dram_v && iqentry_v[ dram_idQNDX ] && iqentry_mem[ dram_idQNDX ] ) begin	// if data for stomped instruction, ignore
	if (dramA_v && iqentry_v[ dramA_idQNDX ] && iqentry_load[ dramA_idQNDX ] ) begin	// if data for stomped instruction, ignore
        iqentry_res	[ dramA_idQNDX ] <= dramA_bus;
        iqentry_exc	[ dramA_idQNDX ] <= dramA_exc;
        iqentry_done[ dramA_idQNDX ] <= `VAL;
        iqentry_out [ dramA_idQNDX ] <= `INV;
        iqentry_cmt[ dramA_idQNDX ] <= `VAL;
	    iqentry_aq  [ dramA_idQNDX ] <= `INV;
	end
	if (dramB_v && iqentry_v[ dramB_idQNDX ] && iqentry_load[ dramB_idQNDX ] ) begin	// if data for stomped instruction, ignore
        iqentry_res	[ dramB_idQNDX ] <= dramB_bus;
        iqentry_exc	[ dramB_idQNDX ] <= dramB_exc;
        iqentry_done[ dramB_idQNDX ] <= `VAL;
        iqentry_out [ dramB_idQNDX ] <= `INV;
        iqentry_cmt[ dramB_idQNDX ] <= `VAL;
	    iqentry_aq  [ dramB_idQNDX ] <= `INV;
	end
	if (dramC_v && iqentry_v[ dramC_idQNDX ] && iqentry_load[ dramC_idQNDX ] ) begin	// if data for stomped instruction, ignore
        iqentry_res	[ dramC_idQNDX ] <= dramC_bus;
        iqentry_exc	[ dramC_idQNDX ] <= dramC_exc;
        iqentry_done[ dramC_idQNDX ] <= `VAL;
        iqentry_out [ dramC_idQNDX ] <= `INV;
        iqentry_cmt[ dramC_idQNDX ] <= `VAL;
	    iqentry_aq  [ dramC_idQNDX ] <= `INV;
	end

	//
	// set the IQ entry == DONE as soon as the SW is let loose to the memory system
	//
	if (dram0 == `DRAMSLOT_BUSY && IsStore(dram0_instr)) begin
	    if ((alu0_v && (dram0_idQNDX == alu0_idQNDX)) || (alu1_v && (dram0_idQNDX == alu1_idQNDX)))	 panic <= `PANIC_MEMORYRACE;
	    iqentry_done[ dram0_idQNDX ] <= `VAL;
	    iqentry_out[ dram0_idQNDX ] <= `INV;
	end
	if (dram1 == `DRAMSLOT_BUSY && IsStore(dram1_instr)) begin
	    if ((alu0_v && (dram1_idQNDX == alu0_idQNDX)) || (alu1_v && (dram1_idQNDX == alu1_idQNDX)))	 panic <= `PANIC_MEMORYRACE;
	    iqentry_done[ dram1_idQNDX ] <= `VAL;
	    iqentry_out[ dram1_idQNDX ] <= `INV;
	end
	if (dram2 == `DRAMSLOT_BUSY && IsStore(dram2_instr)) begin
	    if ((alu0_v && (dram2_idQNDX == alu0_idQNDX)) || (alu1_v && (dram2_idQNDX == alu1_idQNDX)))	 panic <= `PANIC_MEMORYRACE;
	    iqentry_done[ dram2_idQNDX ] <= `VAL;
	    iqentry_out[ dram2_idQNDX ] <= `INV;
	end

    //
    // ISSUE 
    //
    // determines what instructions are ready to go, then places them
    // in the various ALU queues.  
    // also invalidates instructions following a branch-miss BEQ or any JALR (STOMP logic)
    //

    for (n = 0; n < QENTRIES; n = n + 1)
        if (iqentry_issue[n] && !(iqentry_v[n] && iqentry_stomp[n])) begin
            case (iqentry_islot[n]) 
            2'd0: if (alu0_available & alu0_done) begin
                 alu0_sourceid	<= n[3:0];
                 alu0_pred   <= iqentry_pred[n];
                 alu0_instr	<= iqentry_instr[n];
                 alu0_bt		<= iqentry_bt[n];
                 alu0_pc		<= iqentry_pc[n];
                 alu0_argA	<= iqentry_a1[n];
                 alu0_argB	<= iqentry_imm[n]
                            ? iqentry_a0[n]
                            : (iqentry_a2[n]);
                 alu0_argC	<= iqentry_a3[n];
                 alu0_argI	<= iqentry_a0[n];
                 alu0_tgt    <= IsVeins(iqentry_instr[n]) ?
                                {6'h0,1'b1,iqentry_tgt[n][4:0]} | ((iqentry_a2[n][5:0])) << 6 : 
                                iqentry_tgt[n];
                 alu0_ven    <= iqentry_ven[n];
                 alu0_thrd   <= iqentry_thrd[n];
                 alu0_dataready <= IsSingleCycle(iqentry_instr[n]);
                 alu0_ld <= TRUE;
                 iqentry_out[n] <= `VAL;
                // if it is a memory operation, this is the address-generation step ... collect result into arg1
                if (iqentry_mem[n]) begin
                 iqentry_a1_v[n] <= `INV;
                 iqentry_a1_s[n] <= n[3:0];
                end
                end
            2'd1: if (alu1_available && alu1_done) begin
                 alu1_sourceid	<= n[3:0];
                 alu1_pred   <= iqentry_pred[n];
                 alu1_instr	<= iqentry_instr[n];
                 alu1_bt		<= iqentry_bt[n];
                 alu1_pc		<= iqentry_pc[n];
                 alu1_argA	<= iqentry_a1[n];
                 alu1_argB	<= iqentry_imm[n]
                            ? iqentry_a0[n]
                            : (iqentry_a2[n]);
                 alu1_argC	<= iqentry_a3[n];
                 alu1_argI	<= iqentry_a0[n];
                 alu1_tgt    <= IsVeins(iqentry_instr[n]) ?
                                {6'h0,1'b1,iqentry_tgt[n][4:0]} | ((iqentry_a2[n][5:0])) << 6 : 
                                iqentry_tgt[n];
                 alu1_ven    <= iqentry_ven[n];
                 alu1_dataready <= IsSingleCycle(iqentry_instr[n]);
                 alu1_ld <= TRUE;
                 iqentry_out[n] <= `VAL;
                // if it is a memory operation, this is the address-generation step ... collect result into arg1
                if (iqentry_mem[n]) begin
                 iqentry_a1_v[n] <= `INV;
                 iqentry_a1_s[n] <= n[3:0];
                end
                end
            default:  panic <= `PANIC_INVALIDISLOT;
            endcase
        end

    for (n = 0; n < QENTRIES; n = n + 1)
        if (iqentry_fpu_issue[n] && !(iqentry_v[n] && iqentry_stomp[n])) begin
            if (fpu_done) begin
                 fpu_sourceid	<= n[3:0];
                 fpu_pred   <= iqentry_pred[n];
                 fpu_instr	<= iqentry_instr[n];
                 fpu_pc		<= iqentry_pc[n];
                 fpu_argA	<= iqentry_a1[n];
                 fpu_argB	<= iqentry_a2[n];
                 fpu_argC	<= iqentry_a3[n];
                 fpu_argI	<= iqentry_a0[n];
                 fpu_dataready <= `VAL;
                 fpu_ld <= TRUE;
                 iqentry_out[n] <= `VAL;
            end
        end

    for (n = 0; n < QENTRIES; n = n + 1)
        if (iqentry_fcu_issue[n] && !(iqentry_v[n] && iqentry_stomp[n])) begin
            if (fcu_done) begin
                 fcu_sourceid	<= n[3:0];
                 fcu_pred   <= iqentry_pred[n];
                 fcu_instr	<= iqentry_instr[n];
                 fcu_call   <= IsCall(iqentry_instr[n])|IsJAL(iqentry_instr[n]);
                 fcu_bt		<= iqentry_bt[n];
                 fcu_pc		<= iqentry_pc[n];
                 fcu_argA	<= iqentry_a1[n];
`ifdef SUPPORT_SMT                            
                 fcu_argB	<= IsRTI(iqentry_instr[n]) ? epc0[iqentry_thrd[n]]
`else
                 fcu_argB	<= IsRTI(iqentry_instr[n]) ? epc0
`endif                 
                 			: iqentry_a2[n];
                 waitctr	<= iqentry_imm[n]
                            ? iqentry_a0[n]
                            : iqentry_a2[n];
                 fcu_argC	<= iqentry_a3[n];
                 fcu_argI	<= iqentry_a0[n];
                 fcu_thrd   <= iqentry_thrd[n];
                 fcu_dataready <= `VAL;
                 fcu_clearbm <= FALSE;
                 fcu_retadr_v <= `INV;
                 fcu_ld <= TRUE;
                 fcu_timeout <= 8'h00;
                 iqentry_out[n] <= `VAL;
                 fcu_done <= FALSE;
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

//	if (dram0 != `DRAMSLOT_AVAIL)	dram0 <= dram0 + 2'd1;
//	if (dram1 != `DRAMSLOT_AVAIL)	dram1 <= dram1 + 2'd1;
//	if (dram2 != `DRAMSLOT_AVAIL)	dram2 <= dram2 + 2'd1;

    //
    // grab requests that have finished and put them on the dram_bus
    if (dram0 == `DRAMREQ_READY) begin
         dram0 <= `DRAMSLOT_AVAIL;
         dramA_v <= dram0_load;
         dramA_id <= dram0_id;
         dramA_exc <= dram0_exc;
         dramA_bus <= fnDati(dram0_instr,dram0_addr,rdat0);
        if (IsStore(dram0_instr)) 	$display("m[%h] <- %h", dram0_addr, dram0_data);
    end
//    else
//    	dramA_v <= `INV;
    if (dram1 == `DRAMREQ_READY) begin
         dram1 <= `DRAMSLOT_AVAIL;
         dramB_v <= dram1_load;
         dramB_id <= dram1_id;
         dramB_exc <= dram1_exc;
         dramB_bus <= fnDati(dram1_instr,dram1_addr,rdat1);
        if (IsStore(dram1_instr))     $display("m[%h] <- %h", dram1_addr, dram1_data);
    end
//    else
//    	dramB_v <= `INV;
    if (dram2 == `DRAMREQ_READY) begin
         dram2 <= `DRAMSLOT_AVAIL;
         dramC_v <= dram2_load;
         dramC_id <= dram2_id;
         dramC_exc <= dram2_exc;
         dramC_bus <= fnDati(dram2_instr,dram2_addr,rdat2);
        if (IsStore(dram2_instr))     $display("m[%h] <- %h", dram2_addr, dram2_data);
    end
//    else
//    	dramC_v <= `INV;

	//
	// determine if the instructions ready to issue can, in fact, issue.
	// "ready" means that the instruction has valid operands but has not gone yet
	iqentry_memissue <= memissue;
	missue_count <= issue_count;


	//
	// take requests that are ready and put them into DRAM slots

	if (dram0 == `DRAMSLOT_AVAIL)	 dram0_exc <= `FLT_NONE;
	if (dram1 == `DRAMSLOT_AVAIL)	 dram1_exc <= `FLT_NONE;
	if (dram2 == `DRAMSLOT_AVAIL)	 dram2_exc <= `FLT_NONE;

    for (n = 0; n < QENTRIES; n = n + 1)
        if (iqentry_v[n] && iqentry_stomp[n]) begin
            iqentry_v[n] <= `INV;
            if (dram0_idQNDX == nQNDX)  dram0 <= `DRAMSLOT_AVAIL;
            if (dram1_idQNDX == nQNDX)  dram1 <= `DRAMSLOT_AVAIL;
            if (dram2_idQNDX == nQNDX)  dram2 <= `DRAMSLOT_AVAIL;
        end

	last_issue = 8;
    for (n = 0; n < QENTRIES; n = n + 1)
        if (~iqentry_stomp[n] && iqentry_memissue[n] && iqentry_agen[n] && ~iqentry_out[n]) begin
            if (dram0 == `DRAMSLOT_AVAIL) begin
            	dramA_v <= `INV;
             dram0 		<= `DRAMSLOT_BUSY;
             dram0_id 	<= { 1'b1, nQNDX };
             dram0_instr <= iqentry_instr[n];
             dram0_tgt 	<= iqentry_tgt[n];
             dram0_data	<= iqentry_memndx[n] ? iqentry_a3[n] : iqentry_a2[n];
             dram0_addr	<= iqentry_a1[n];
             dram0_unc   <= iqentry_a1[n][51:20]==32'hFFFFFFFD || !dce || IsVolatileLoad(iqentry_instr[n]);
             dram0_memsize <= MemSize(iqentry_instr[n]);
             dram0_load <= iqentry_load[n];
             last_issue = n;
            end
        end
    if (last_issue < 8)
       	iqentry_out[last_issue] <= `VAL;
    for (n = 0; n < QENTRIES; n = n + 1)
        if (~iqentry_stomp[n] && iqentry_memissue[n] && iqentry_agen[n] && ~iqentry_out[n]) begin
        	if (n < last_issue) begin
	            if (dram1 == `DRAMSLOT_AVAIL) begin
            		dramB_v <= `INV;
	             dram1 		<= `DRAMSLOT_BUSY;
	             dram1_id 	<= { 1'b1, nQNDX };
	             dram1_instr <= iqentry_instr[n];
	             dram1_tgt 	<= iqentry_tgt[n];
	             dram1_data	<= iqentry_memndx[n] ? iqentry_a3[n] : iqentry_a2[n];
	             dram1_addr	<= iqentry_a1[n];
	             dram1_unc   <= iqentry_a1[n][51:20]==32'hFFFFFFFD || !dce || IsVolatileLoad(iqentry_instr[n]);
	             dram1_memsize <= MemSize(iqentry_instr[n]);
	             dram1_load <= iqentry_load[n];
	             last_issue = n;
	            end
        	end
        end
    if (last_issue < 8)
       	iqentry_out[last_issue] <= `VAL;
    for (n = 0; n < QENTRIES; n = n + 1)
        if (~iqentry_stomp[n] && iqentry_memissue[n] && iqentry_agen[n] && ~iqentry_out[n]) begin
        	if (n < last_issue) begin
	            if (dram2 == `DRAMSLOT_AVAIL) begin
            		dramC_v <= `INV;
	             dram2 		<= `DRAMSLOT_BUSY;
	             dram2_id 	<= { 1'b1, nQNDX };
	             dram2_instr	<= iqentry_instr[n];
	             dram2_tgt 	<= iqentry_tgt[n];
	             dram2_data	<= iqentry_memndx[n] ? iqentry_a3[n] : iqentry_a2[n];
	             dram2_addr	<= iqentry_a1[n];
	             dram2_unc   <= iqentry_a1[n][51:20]==32'hFFFFFFFD || !dce || IsVolatileLoad(iqentry_instr[n]);
	             dram2_memsize <= MemSize(iqentry_instr[n]);
	             dram2_load <= iqentry_load[n];
	            end
        	end
        end
    if (last_issue < 8)
       	iqentry_out[last_issue] <= `VAL;

    // It's better to check a sequence number here because if the code is in a
    // loop that such that the previous iteration of the loop is still in the
    // queue the PC could match when we don;t really want a prefix for that
    // iteration.
    for (n = 0; n < QENTRIES; n = n + 1)
    begin
        if (!iqentry_v[n])
             iqentry_done[n] <= FALSE;
    end
      


    //
    // COMMIT PHASE (dequeue only ... not register-file update)
    //
    // look at head0 and head1 and let 'em write to the register file if they are ready
    //
//    always @(posedge clk) begin: commit_phase

    oddball_commit(commit0_v, head0);
    oddball_commit(commit1_v, head1);

// Fetch and queue are limited to two instructions per cycle, so we might as
// well limit retiring to two instructions max to conserve logic.
//
if (~|panic)
    casez ({ iqentry_v[head0],
	iqentry_cmt[head0],
	iqentry_v[head1],
	iqentry_cmt[head1]})

	// retire 3
	4'b0?_0?:
		if (head0 != tail0 && head1 != tail0) begin
 		    head_inc(2);
		end
		else if (head0 != tail0) begin
		    head_inc(1);
		end

	// retire 1 (wait for regfile for head1)
	4'b0?_10:
		    head_inc(1);

	// retire 2
	4'b0?_11:
        begin
            iqentry_v[head1] <= `INV;
            head_inc(2);
        end

	// retire 0 (stuck on head0)
	4'b10_??:	;
	
	// retire 1 or 2
	4'b11_0?:
		if (head1 != tail0) begin
			iqentry_v[head0] <= `INV;
			head_inc(2);
		end
		else begin
			iqentry_v[head0] <= `INV;
			head_inc(1);
		end

	// retire 1 (wait for regfile for head1)
	4'b11_10:
		begin
			iqentry_v[head0] <= `INV;
			head_inc(1);
		end

	// retire 2
	4'b11_11:
	    begin
            iqentry_v[head0] <= `INV;    // may conflict with STOMP, but since both are setting to 0, it is okay
            iqentry_v[head1] <= `INV;    // may conflict with STOMP, but since both are setting to 0, it is okay
        	head_inc(2);
	    end
    endcase


	 rf_source[0] <= 0;
	 L1_wr0 <= FALSE;
	 L1_wr1 <= FALSE;
	 L1_invline <= FALSE;
     icnxt <= FALSE;
     L2_nxt <= FALSE;
// Instruction cache state machine.
// On a miss first see if the instruction is in the L2 cache. No need to go to
// the BIU on an L1 miss.
// If not the machine will wait until the BIU loads the L2 cache.

    // Capture the previous ic state, used to determine how long to wait in
    // icstate #4.
     picstate <= icstate;
case(icstate)
IDLE:
	// If the bus unit is busy doing an update involving L1_adr or L2_adr
	// we have to wait.
    if (bstate != B7 && bstate != B9) begin
        if (!ihit0) begin
             L1_adr <= {pcr[5:0],pc0[51:3],3'h0};
             L2_adr <= {pcr[5:0],pc0[51:3],3'h0};
             L1_invline <= TRUE;
             icwhich <= 1'b0;
             iccnt <= 2'b00;
             icstate <= IC2;
        end
        else if (!ihit1) begin
             L1_adr <= {pcr[5:0],pc1[51:3],3'h0};
             L2_adr <= {pcr[5:0],pc1[51:3],3'h0};
             L1_invline <= TRUE;
             icwhich <= 1'b1;
             iccnt <= 2'b00;
             icstate <= IC2;
        end
    end
IC2:     icstate <= IC3;
IC3:     icstate <= IC3a;
IC3a:     icstate <= IC4;
        // If data was in the L2 cache already there's no need to wait on the
        // BIU to retrieve data. It can be determined if the hit signal was
        // already active when this state was entered in which case waiting
        // will do no good.
        // The IC machine will stall in this state until the BIU has loaded the
        // L2 cache. 
IC4:    if (ihit2 && picstate==IC3a) begin
			L1_en <= 8'hFF;
            L1_wr1 <= TRUE;
            L1_wr0 <= TRUE;
            L1_adr <= L2_adr;
            L2_rdat <= L2_dato;
            icstate <= IC5;
		end
		else if (bstate!=B9)
			;
		else begin
             //L1_wr1 <= TRUE;
             //L1_wr0 <= TRUE;
             //L1_adr <= L2_adr;
             //L2_rdat <= L2_dato;
             icstate <= IC5;
        end
IC5:     icstate <= IC6;
IC6:     icstate <= IC8;
IC7:	icstate <= IC8;
IC8:    begin
             icstate <= IDLE;
             icnxt <= TRUE;
        end
default:     icstate <= IDLE;
endcase

if (dram0_load)
case(dram0)
`DRAMSLOT_AVAIL:	;
`DRAMSLOT_BUSY:		dram0 <= dram0 + !dram0_unc;
3'd2:				dram0 <= dram0 + 3'd1;
3'd3:				dram0 <= dram0 + 3'd1;
3'd4:				if (dhit0) dram0 <= `DRAMREQ_READY; else dram0 <= `DRAMSLOT_REQBUS;
`DRAMSLOT_REQBUS:	;
`DRAMSLOT_HASBUS:	;
`DRAMREQ_READY:		;
endcase

if (dram1_load)
case(dram1)
`DRAMSLOT_AVAIL:	;
`DRAMSLOT_BUSY:		dram1 <= dram1 + !dram1_unc;
3'd2:				dram1 <= dram1 + 3'd1;
3'd3:				dram1 <= dram1 + 3'd1;
3'd4:				if (dhit1) dram1 <= `DRAMREQ_READY; else dram1 <= `DRAMSLOT_REQBUS;
`DRAMSLOT_REQBUS:	;
`DRAMSLOT_HASBUS:	;
`DRAMREQ_READY:		;
endcase

if (dram2_load)
case(dram2)
`DRAMSLOT_AVAIL:	;
`DRAMSLOT_BUSY:		dram2 <= dram2 + !dram2_unc;
3'd2:				dram2 <= dram2 + 3'd1;
3'd3:				dram2 <= dram2 + 3'd1;
3'd4:				if (dhit2) dram2 <= `DRAMREQ_READY; else dram2 <= `DRAMSLOT_REQBUS;
`DRAMSLOT_REQBUS:	;
`DRAMSLOT_HASBUS:	;
`DRAMREQ_READY:		;
endcase

// Bus Interface Unit (BIU)
// Interfaces to the external bus which is WISHBONE compatible.
// Stores take precedence over other operations.
// Next data cache read misses are serviced.
// Uncached data reads are serviced.
// Finally L2 instruction cache misses are serviced.

case(bstate)
BIDLE:
    begin
         isCAS <= FALSE;
         isAMO <= FALSE;
         rdvq <= 1'b0;
         errq <= 1'b0;
         exvq <= 1'b0;
         bwhich <= 2'b11;
        if (dram0==`DRAMSLOT_BUSY && (IsCAS(dram0_instr) || IsAMO(dram0_instr))) begin
`ifdef SUPPORT_DBG      
            if (dbg_smatch0|dbg_lmatch0) begin
                 dramA_v <= TRUE;
                 dramA_id <= dram0_id;
                 dramA_exc <= `FLT_DBG;
                 dramA_bus <= 52'h0;
                 dram0 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 dram0 <= `DRAMSLOT_HASBUS;
                 isCAS <= IsCAS(dram0_instr);
                 isAMO <= IsAMO(dram0_instr);
                 casid <= dram0_id;
                 bwhich <= 2'b00;
                 cyc_o <= `HIGH;
                 stb_o <= `HIGH;
                 sel_o <= fnSelect(dram0_instr,dram0_addr);
                 adr_o <= dram0_addr;
                 dat_o <= fnDato(dram0_instr,dram0_data);
                 bstate <= B12;
            end
        end
        else if (dram1==`DRAMSLOT_BUSY && (IsCAS(dram1_instr) || IsAMO(dram1_instr))) begin
`ifdef SUPPORT_DBG        	
            if (dbg_smatch1|dbg_lmatch1) begin
                 dramB_v <= TRUE;
                 dramB_id <= dram1_id;
                 dramB_exc <= `FLT_DBG;
                 dramB_bus <= 52'h0;
                 dram1 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 dram1 <= `DRAMSLOT_HASBUS;
                 isCAS <= IsCAS(dram1_instr);
                 isAMO <= IsAMO(dram1_instr);
                 casid <= dram1_id;
                 bwhich <= 2'b01;
                 cyc_o <= `HIGH;
                 stb_o <= `HIGH;
                 sel_o <= fnSelect(dram1_instr,dram1_addr);
                 adr_o <= dram1_addr;
                 dat_o <= fnDato(dram1_instr,dram1_data);
                 bstate <= B12;
            end
        end
        else if (dram2==`DRAMSLOT_BUSY && (IsCAS(dram2_instr) || IsAMO(dram2_instr))) begin
`ifdef SUPPORT_DBG        	
            if (dbg_smatch2|dbg_lmatch2) begin
                 dramC_v <= TRUE;
                 dramC_id <= dram2_id;
                 dramC_exc <= `FLT_DBG;
                 dramC_bus <= 52'h0;
                 dram2 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 dram2 <= `DRAMSLOT_HASBUS;
                 isCAS <= IsCAS(dram2_instr);
                 isAMO <= IsAMO(dram2_instr);
                 casid <= dram2_id;
                 bwhich <= 2'b10;
                 cyc_o <= `HIGH;
                 stb_o <= `HIGH;
                 sel_o <= fnSelect(dram2_instr,dram2_addr);
                 adr_o <= dram2_addr;
                 dat_o <= fnDato(dram2_instr,dram2_data);
                 bstate <= B12;
            end
        end
        else if (dram0==`DRAMSLOT_BUSY && IsStore(dram0_instr)) begin
`ifdef SUPPORT_DBG        	
            if (dbg_smatch0) begin
                 dramA_v <= TRUE;
                 dramA_id <= dram0_id;
                 dramA_exc <= `FLT_DBG;
                 dramA_bus <= 52'h0;
                 dram0 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 dram0 <= `DRAMSLOT_HASBUS;
                 dram0_instr[6:0] <= `NOP;
                 bwhich <= 2'b00;
				 cyc_o <= `HIGH;
				 stb_o <= `HIGH;
                 we_o <= `HIGH;
                 sel_o <= fnSelect(dram0_instr,dram0_addr);
                 adr_o <= dram0_addr;
                 dat_o <= fnDato(dram0_instr,dram0_data);
                 cr_o <= IsSWC(dram0_instr);
                 bstate <= B1;
            end
        end
        else if (dram1==`DRAMSLOT_BUSY && IsStore(dram1_instr)) begin
`ifdef SUPPORT_DBG        	
            if (dbg_smatch1) begin
                 dramB_v <= TRUE;
                 dramB_id <= dram1_id;
                 dramB_exc <= `FLT_DBG;
                 dramB_bus <= 52'h0;
                 dram1 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 dram1 <= `DRAMSLOT_HASBUS;
                 dram1_instr[6:0] <= `NOP;
                 bwhich <= 2'b01;
				 cyc_o <= `HIGH;
				 stb_o <= `HIGH;
                 we_o <= `HIGH;
                 sel_o <= fnSelect(dram1_instr,dram1_addr);
                 adr_o <= dram1_addr;
                 dat_o <= fnDato(dram1_instr,dram1_data);
                 cr_o <= IsSWC(dram1_instr);
                 bstate <= B1;
            end
        end
        else if (dram2==`DRAMSLOT_BUSY && IsStore(dram2_instr)) begin
`ifdef SUPPORT_DBG        	
            if (dbg_smatch2) begin
                 dramC_v <= TRUE;
                 dramC_id <= dram2_id;
                 dramC_exc <= `FLT_DBG;
                 dramC_bus <= 52'h0;
                 dram2 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 dram2 <= `DRAMSLOT_HASBUS;
                 dram2_instr[6:0] <= `NOP;
                 bwhich <= 2'b10;
				 cyc_o <= `HIGH;
				 stb_o <= `HIGH;
                 we_o <= `HIGH;
                 sel_o <= fnSelect(dram2_instr,dram2_addr);
                 adr_o <= dram2_addr;
                 dat_o <= fnDato(dram2_instr,dram2_data);
                 cr_o <= IsSWC(dram2_instr);
                 bstate <= B1;
            end
        end
        // Check for read misses on the data cache
        else if (!dram0_unc && dram0==`DRAMSLOT_REQBUS && dram0_load) begin
`ifdef SUPPORT_DBG        	
            if (dbg_lmatch0) begin
                 dramA_v <= TRUE;
                 dramA_id <= dram0_id;
                 dramA_exc <= `FLT_DBG;
                 dramA_bus <= 52'h0;
                 dram0 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 dram0 <= `DRAMSLOT_HASBUS;
                 bwhich <= 2'b00;
                 bstate <= B2; 
            end
        end
        else if (!dram1_unc && dram1==`DRAMSLOT_REQBUS && dram1_load) begin
`ifdef SUPPORT_DBG        	
            if (dbg_lmatch1) begin
                 dramB_v <= TRUE;
                 dramB_id <= dram1_id;
                 dramB_exc <= `FLT_DBG;
                 dramB_bus <= 52'h0;
                 dram1 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 dram1 <= `DRAMSLOT_HASBUS;
                 bwhich <= 2'b01;
                 bstate <= B2;
            end 
        end
        else if (!dram2_unc && dram2==`DRAMSLOT_REQBUS && dram2_load) begin
`ifdef SUPPORT_DBG        	
            if (dbg_lmatch2) begin
                 dramC_v <= TRUE;
                 dramC_id <= dram2_id;
                 dramC_exc <= `FLT_DBG;
                 dramC_bus <= 52'h0;
                 dram2 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 dram2 <= `DRAMSLOT_HASBUS;
                 bwhich <= 2'b10;
                 bstate <= B2;
            end 
        end
        else if (dram0_unc && dram0==`DRAMSLOT_BUSY && dram0_load) begin
`ifdef SUPPORT_DBG        	
            if (dbg_lmatch0) begin
                 dramA_v <= TRUE;
                 dramA_id <= dram0_id;
                 dramA_exc <= `FLT_DBG;
                 dramA_bus <= 52'h0;
                 dram0 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 bwhich <= 2'b00;
                 cyc_o <= `HIGH;
                 stb_o <= `HIGH;
                 sel_o <= fnSelect(dram0_instr,dram0_addr);
                 adr_o <= {dram0_addr[31:3],3'b0};
                 sr_o <=  IsLWR(dram0_instr);
                 bstate <= B12;
            end
        end
        else if (dram1_unc && dram1==`DRAMSLOT_BUSY && dram1_load) begin
`ifdef SUPPORT_DBG        	
            if (dbg_lmatch1) begin
                 dramB_v <= TRUE;
                 dramB_id <= dram1_id;
                 dramB_exc <= `FLT_DBG;
                 dramB_bus <= 52'h0;
                 dram1 <= `DRAMSLOT_AVAIL;
            end
            else
`endif            
            begin
                 bwhich <= 2'b01;
                 cyc_o <= `HIGH;
                 stb_o <= `HIGH;
                 sel_o <= fnSelect(dram1_instr,dram1_addr);
                 adr_o <= {dram1_addr[31:3],3'b0};
                 sr_o <=  IsLWR(dram1_instr);
                 bstate <= B12;
            end
        end
        else if (dram2_unc && dram2==`DRAMSLOT_BUSY && dram2_load) begin
`ifdef SUPPORT_DBG        	
            if (dbg_lmatch2) begin
                 dramC_v <= TRUE;
                 dramC_id <= dram2_id;
                 dramC_exc <= `FLT_DBG;
                 dramC_bus <= 52'h0;
                 dram2 <= 2'd0;
            end
            else
`endif            
            begin
                 bwhich <= 2'b10;
                 cyc_o <= `HIGH;
                 stb_o <= `HIGH;
                 sel_o <= fnSelect(dram2_instr,dram2_addr);
                 adr_o <= {dram2_addr[31:3],3'b0};
                 sr_o <=  IsLWR(dram2_instr);
                 bstate <= B12;
            end
        end
        // Check for L2 cache miss
        else if (!ihit2) begin
             cti_o <= 3'b001;
             bte_o <= 2'b01;	// 4 beat burst wrap
             cyc_o <= `HIGH;
             stb_o <= `HIGH;
             sel_o <= 8'hFF;
             icl_o <= `HIGH;
//            adr_o <= icwhich ? {pc0[31:5],5'b0} : {pc1[31:5],5'b0};
//            L2_adr <= icwhich ? {pc0[31:5],5'b0} : {pc1[31:5],5'b0};
             adr_o <= {pcr[5:0],L1_adr[51:3],3'h0};
             L2_adr <= {pcr[5:0],L1_adr[51:3],3'h0};
             bstate <= B7;
        end
    end
// Terminal state for a store operation.
B1:
    if (ack_i|err_i) begin
    	 isStore <= TRUE;
         cyc_o <= `LOW;
         stb_o <= `LOW;
         we_o <= `LOW;
         sel_o <= 8'h00;
         cr_o <= 1'b0;
        // This isn't a good way of doing things; the state should be propagated
        // to the commit stage, however since this is a store we know there will
        // be no change of program flow. So the reservation status bit is set
        // here. The author wanted to avoid the complexity of propagating the
        // input signal to the commit stage. It does mean that the SWC
        // instruction should be surrounded by SYNC's.
        if (cr_o)
             sema[0] <= rbi_i;
        case(bwhich)
        2'd0:   begin
                 dram0 <= `DRAMREQ_READY;
                 iqentry_exc[dram0_idQNDX] <= wrv_i|err_i ? `FLT_DWF : `FLT_NONE;
                if (err_i|wrv_i)  iqentry_a1[dram0_idQNDX] <= adr_o; 
			    iqentry_cmt[ dram0_idQNDX ] <= `VAL;
			    iqentry_aq[ dram0_idQNDX ] <= `INV;
         		//iqentry_out[ dram0_idQNDX ] <= `INV;
                end
        2'd1:   begin
                 dram1 <= `DRAMREQ_READY;
                 iqentry_exc[dram1_idQNDX] <= wrv_i|err_i ? `FLT_DWF : `FLT_NONE;
                if (err_i|wrv_i)  iqentry_a1[dram1_idQNDX] <= adr_o; 
			    iqentry_cmt[ dram1_idQNDX ] <= `VAL;
			    iqentry_aq[ dram1_idQNDX ] <= `INV;
         		//iqentry_out[ dram1_idQNDX ] <= `INV;
                end
        2'd2:   begin
                 dram2 <= `DRAMREQ_READY;
                 iqentry_exc[dram2_idQNDX] <= wrv_i|err_i ? `FLT_DWF : `FLT_NONE;
                if (err_i|wrv_i)  iqentry_a1[dram2_idQNDX] <= adr_o; 
			    iqentry_cmt[ dram2_idQNDX ] <= `VAL;
			    iqentry_aq[ dram2_idQNDX ] <= `INV;
         		//iqentry_out[ dram2_idQNDX ] <= `INV;
                end
        default:    ;
        endcase
         bstate <= B19;
    end
B2:
    begin
    dccnt <= 2'd0;
    case(bwhich)
    2'd0:   begin
             cti_o <= 3'b001;
             bte_o <= 2'b01;
             cyc_o <= `HIGH;
             stb_o <= `HIGH;
             sel_o <= fnSelect(dram0_instr,dram0_addr);
             adr_o <= {dram0_addr[31:3],3'b0};
             bstate <= B2d;
            end
    2'd1:   begin
             cti_o <= 3'b001;
             bte_o <= 2'b01;
             cyc_o <= `HIGH;
             stb_o <= `HIGH;
             sel_o <= fnSelect(dram1_instr,dram1_addr);
             adr_o <= {dram1_addr[31:3],3'b0};
             bstate <= B2d;
            end
    2'd2:   begin
             cti_o <= 3'b001;
             bte_o <= 2'b01;
             cyc_o <= `HIGH;
             stb_o <= `HIGH;
             sel_o <= fnSelect(dram2_instr,dram2_addr);
             adr_o <= {dram2_addr[31:3],3'b0};
             bstate <= B2d;
            end
    default:    if (~ack_i)  bstate <= BIDLE;
    endcase
    end
// Data cache load terminal state
B2d:
    if (ack_i|err_i) begin
        errq <= errq | err_i;
        rdvq <= rdvq | rdv_i;
        case(bwhich)
        2'd0:   if (err_i|rdv_i) begin
                     iqentry_a1[dram0_idQNDX] <= adr_o;
                     iqentry_exc[dram0_idQNDX] <= err_i ? `FLT_DBE : `FLT_DRF;
                end
        2'd1:   if (err_i|rdv_i) begin
                     iqentry_a1[dram1_idQNDX] <= adr_o;
                     iqentry_exc[dram1_idQNDX] <= err_i ? `FLT_DBE : `FLT_DRF;
                end
        2'd2:   if (err_i|rdv_i) begin
                     iqentry_a1[dram2_idQNDX] <= adr_o;
                     iqentry_exc[dram2_idQNDX] <= err_i ? `FLT_DBE : `FLT_DRF;
                end
        default:    ;
        endcase
        dccnt <= dccnt + 2'd1;
        adr_o[4:3] <= adr_o[4:3] + 2'd1;
        bstate <= B2d;
        if (dccnt==2'd2)
             cti_o <= 3'b111;
        if (dccnt==2'd3) begin
             cti_o <= 3'b000;
             bte_o <= 2'b00;
             cyc_o <= `LOW;
             stb_o <= `LOW;
             sel_o <= 8'h00;
             bstate <= B4;
        end
    end
B3: begin
         stb_o <= `HIGH;
         bstate <= B2d;
    end
B4:  bstate <= B5;
B5:  bstate <= B6;
B6: begin
    case(bwhich)
    2'd0:    dram0 <= `DRAMSLOT_BUSY;  // causes retest of dhit
    2'd1:    dram1 <= `DRAMSLOT_BUSY;
    2'd2:    dram2 <= `DRAMSLOT_BUSY;
    default:    ;
    endcase
    if (~ack_i)  bstate <= BIDLE;
    end

// Ack state for instruction cache load
B7:
    if (ack_i|err_i) begin
        errq <= errq | err_i;
        exvq <= exvq | exv_i;
        L1_en <= 8'h3 << {L2_adr[4:3],1'b0};
        L1_wr0 <= TRUE;
        L1_wr1 <= TRUE;
        L1_adr <= L2_adr;
        if (err_i)
        	L2_rdat <= {8{13'b0,3'd7,3'b0,`FLT_IBE,OP_BRK}};
        else
        	L2_rdat <= {4{dat_i}};
        iccnt <= iccnt + 2'd1;
        //stb_o <= `LOW;
        if (iccnt==2'd2)
            cti_o <= 3'b111;
        if (iccnt==2'd3) begin
            cti_o <= 3'b000;
            bte_o <= 2'b00;		// linear burst
            cyc_o <= `LOW;
            stb_o <= `LOW;
            sel_o <= 8'h00;
            icl_o <= `LOW;
            bstate <= B9;
        end
        else begin
            L2_adr[4:3] <= L2_adr[4:3] + 2'd1;
        end
    end
B9:
 	begin
		L1_wr0 <= FALSE;
		L1_wr1 <= FALSE;
		L1_en <= 8'hFF;
		if (~ack_i) begin
			bstate <= BIDLE;
			L2_nxt <= TRUE;
		end
	end
B12:
    if (ack_i|err_i) begin
        if (isCAS) begin
    	     iqentry_res	[ casidQNDX ] <= (dat_i == cas);
             iqentry_exc [ casidQNDX ] <= err_i ? `FLT_DRF : rdv_i ? `FLT_DRF : `FLT_NONE;
             iqentry_done[ casidQNDX ] <= `VAL;
    	     iqentry_instr[ casidQNDX] <= `NOP_INSN;
    	     iqentry_out [ casidQNDX ] <= `INV;
    	    if (err_i | rdv_i) iqentry_a1[casidQNDX] <= adr_o;
            if (dat_i == cas) begin
                 stb_o <= `LOW;
                 we_o <= TRUE;
                 bstate <= B15;
            end
            else begin
                 cas <= dat_i;
                 cyc_o <= `LOW;
                 stb_o <= `LOW;
                 sel_o <= 8'h00;
                case(bwhich)
                2'b00:   dram0 <= `DRAMREQ_READY;
                2'b01:   dram1 <= `DRAMREQ_READY;
                2'b10:   dram2 <= `DRAMREQ_READY;
                default:    ;
                endcase
                 bstate <= B19;
            end
        end
        else if (isAMO) begin
    	     iqentry_res [ casidQNDX ] <= dat_i;
    	     amo_argA <= dat_i;
    	     amo_argB <= iqentry_instr[casidQNDX][31] ? {{59{iqentry_instr[casidQNDX][20:16]}},iqentry_instr[casidQNDX][20:16]} : iqentry_a2[casidQNDX];
    	     amo_instr <= iqentry_instr[casidQNDX];
             iqentry_exc [ casidQNDX ] <= err_i ? `FLT_DRF : rdv_i ? `FLT_DRF : `FLT_NONE;
             if (err_i | rdv_i) iqentry_a1[casidQNDX] <= adr_o;
             stb_o <= `LOW;
             bstate <= B20;
    	end
        else begin
             cyc_o <= `LOW;
             stb_o <= `LOW;
             sel_o <= 8'h00;
             sr_o <= `LOW;
             xdati <= dat_i;
            case(bwhich)
            2'b00:  begin
                     dram0 <= `DRAMREQ_READY;
                     iqentry_exc [ dram0_idQNDX ] <= err_i ? `FLT_DRF : rdv_i ? `FLT_DRF : `FLT_NONE;
                    if (err_i|rdv_i)  iqentry_a1[dram0_idQNDX] <= adr_o;
                    end
            2'b01:  begin
                     dram1 <= `DRAMREQ_READY;
                     iqentry_exc [ dram1_idQNDX ] <= err_i ? `FLT_DRF : rdv_i ? `FLT_DRF : `FLT_NONE;
                    if (err_i|rdv_i)  iqentry_a1[dram1_idQNDX] <= adr_o;
                    end
            2'b10:  begin
                     dram2 <= `DRAMREQ_READY;
                     iqentry_exc [ dram2_idQNDX ] <= err_i ? `FLT_DRF : rdv_i ? `FLT_DRF : `FLT_NONE;
                    if (err_i|rdv_i)  iqentry_a1[dram2_idQNDX] <= adr_o;
                    end
            default:    ;
            endcase
             bstate <= B19;
        end
    end
// Three cycles to detemrine if there's a cache hit during a store.
B16:    begin
            case(bwhich)
            2'd0:      if (dhit0) begin  dram0 <= `DRAMREQ_READY; bstate <= B17; end
            2'd1:      if (dhit1) begin  dram1 <= `DRAMREQ_READY; bstate <= B17; end
            2'd2:      if (dhit2) begin  dram2 <= `DRAMREQ_READY; bstate <= B17; end
            default:    bstate <= BIDLE;
            endcase
            end
B17:     bstate <= B18;
B18:     bstate <= B19;
B19:    if (~ack_i)  begin bstate <= BIDLE; isStore <= FALSE; end
B20:
	if (~ack_i) begin
		stb_o <= `HIGH;
		we_o  <= `HIGH;
		dat_o <= fnDato(amo_instr,amo_res);
		bstate <= B1;
	end
default:     bstate <= BIDLE;
endcase

    case({fetchbuf0_v, fetchbuf1_v})
    2'b00:  ;
    2'b01:
        if (canq1) begin
           	tail0 <= idp1(tail0);
           	tail1 <= idp1(tail1);
        end
    2'b10:
        if (canq1) begin
            tail0 <= idp1(tail0);
            tail1 <= idp1(tail1);
        end
    2'b11:
        if (canq1) begin
            if (IsBranch(insn0a) && predict_taken0 && fetchbuf0_thrd==fetchbuf1_thrd) begin
                 tail0 <= idp1(tail0);
                 tail1 <= idp1(tail1);
            end
            else begin
				if (vqe0 < vl || !IsVector(insn0a)) begin
	                if (canq2) begin
	                     tail0 <= idp2(tail0);
	                     tail1 <= idp2(tail1);
	                end
	                else begin    // queued1 will be true
	                     tail0 <= idp1(tail0);
	                     tail1 <= idp1(tail1);
	                end
            	end
            end
        end
    endcase
/*
    if (pebm)
         seq_num <= seq_num + 5'd3;
    else if (queued2)
         seq_num <= seq_num + 5'd2;
    else if (queued1)
         seq_num <= seq_num + 5'd1;
*/
//	#5 rf[0] = 0; rf_v[0] = 1; rf_source[0] = 0;
	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("%h #", pc0);
`ifdef SUPPORT_SMT
    $display ("Regfile: %d", rgs[0]);
	for (n=0; n < 32; n=n+4) begin
	    $display("%d: %h %d %o   %d: %h %d %o   %d: %h %d %o   %d: %h %d %o#",
	       n[4:0]+0, urf1.urf10.mem[{rgs[0],1'b0,n[4:2],2'b00}], regIsValid[n+0], rf_source[n+0],
	       n[4:0]+1, urf1.urf10.mem[{rgs[0],1'b0,n[4:2],2'b01}], regIsValid[n+1], rf_source[n+1],
	       n[4:0]+2, urf1.urf10.mem[{rgs[0],1'b0,n[4:2],2'b10}], regIsValid[n+2], rf_source[n+2],
	       n[4:0]+3, urf1.urf10.mem[{rgs[0],1'b0,n[4:2],2'b11}], regIsValid[n+3], rf_source[n+3]
	       );
	end
	if (thread_en) begin
	    $display ("Regfile: %d", rgs[1]);
		for (n=128; n < 160; n=n+4) begin
		    $display("%d: %h %d %o   %d: %h %d %o   %d: %h %d %o   %d: %h %d %o#",
		       n[4:0]+0, urf1.urf10.mem[{rgs[1],1'b0,n[4:2],2'b00}], regIsValid[n+0], rf_source[n+0],
		       n[4:0]+1, urf1.urf10.mem[{rgs[1],1'b0,n[4:2],2'b01}], regIsValid[n+1], rf_source[n+1],
		       n[4:0]+2, urf1.urf10.mem[{rgs[1],1'b0,n[4:2],2'b10}], regIsValid[n+2], rf_source[n+2],
		       n[4:0]+3, urf1.urf10.mem[{rgs[1],1'b0,n[4:2],2'b11}], regIsValid[n+3], rf_source[n+3]
		       );
		end
	end
`else
    $display ("Regfile: %d", rgs);
	for (n=0; n < 32; n=n+4) begin
	    $display("%d: %h %d %o   %d: %h %d %o   %d: %h %d %o   %d: %h %d %o#",
	       n[4:0]+0, urf1.urf10.mem[{rgs,1'b0,n[4:2],2'b00}], regIsValid[n+0], rf_source[n+0],
	       n[4:0]+1, urf1.urf10.mem[{rgs,1'b0,n[4:2],2'b01}], regIsValid[n+1], rf_source[n+1],
	       n[4:0]+2, urf1.urf10.mem[{rgs,1'b0,n[4:2],2'b10}], regIsValid[n+2], rf_source[n+2],
	       n[4:0]+3, urf1.urf10.mem[{rgs,1'b0,n[4:2],2'b11}], regIsValid[n+3], rf_source[n+3]
	       );
	end
`endif
	$display("Call Stack:");
	for (n = 0; n < 32; n = n + 4)
		$display("%c%d: %h   %c%d: %h   %c%d: %h   %c%d: %h",
			ufb1.ursb1.rasp==n+0 ?">" : " ", n[4:0]+0, ufb1.ursb1.ras[n+0],
			ufb1.ursb1.rasp==n+1 ?">" : " ", n[4:0]+1, ufb1.ursb1.ras[n+1],
			ufb1.ursb1.rasp==n+2 ?">" : " ", n[4:0]+2, ufb1.ursb1.ras[n+2],
			ufb1.ursb1.rasp==n+3 ?">" : " ", n[4:0]+3, ufb1.ursb1.ras[n+3]
		);
	$display("\n");
	
//    $display("Return address stack:");
//    for (n = 0; n < 16; n = n + 1)
//        $display("%d %h", rasp+n[3:0], ras[rasp+n[3:0]]);
	$display("TakeBr:%d #", take_branch);//, backpc);
	$display("%c%c A: %d %h %h #",
	    45, fetchbuf?45:62, fetchbufA_v, fetchbufA_instr, fetchbufA_pc);
	$display("%c%c B: %d %h %h #",
	    45, fetchbuf?45:62, fetchbufB_v, fetchbufB_instr, fetchbufB_pc);
	$display("%c%c C: %d %h %h #",
	    45, fetchbuf?62:45, fetchbufC_v, fetchbufC_instr, fetchbufC_pc);
	$display("%c%c D: %d %h %h #",
	    45, fetchbuf?62:45, fetchbufD_v, fetchbufD_instr, fetchbufD_pc);

	for (i=0; i<QENTRIES; i=i+1) 
	    $display("%c%c %d: %c%c%c %d %d %c%c %d %c %c%h 0%d %o %h %h %h %d %o %h %d %o %h %d %o %d:%h %h %d#",
		(iQNDX==head0)?"C":".", (iQNDX==tail0)?"Q":".", iQNDX,
		iqentry_v[i]?"v":"-", iqentry_done[i]?"d":"-", iqentry_out[i]?"o":"-", iqentry_bt[i], iqentry_memissue[i], iqentry_agen[i] ? "a": "-", iqentry_issue[i]?"i":"-",
		((i==0) ? iqentry_islot[0] : (i==1) ? iqentry_islot[1] : (i==2) ? iqentry_islot[2] : (i==3) ? iqentry_islot[3] :
		 (i==4) ? iqentry_islot[4] : (i==5) ? iqentry_islot[5] : (i==6) ? iqentry_islot[6] : iqentry_islot[7]), iqentry_stomp[i]?"s":"-",
		(IsFlowCtrl(iqentry_instr[i]) ? 98 : (IsMem(iqentry_instr[i])) ? 109 : 97), 
		iqentry_instr[i], iqentry_tgt[i][4:0],
		iqentry_exc[i], iqentry_res[i], iqentry_a0[i], iqentry_a1[i], iqentry_a1_v[i],
		iqentry_a1_s[i],
		iqentry_a2[i], iqentry_a2_v[i], iqentry_a2_s[i],
		iqentry_a3[i], iqentry_a3_v[i], iqentry_a3_s[i],
		iqentry_thrd[i],
		iqentry_pc[i],
		iqentry_sn[i], iqentry_ven[i]
		);
    $display("DRAM");
	$display("%d %h %h %c%h %o #",
	    dram0, dram0_addr, dram0_data, (IsFlowCtrl(dram0_instr) ? 98 : (IsMem(dram0_instr)) ? 109 : 97), 
	    dram0_instr, dram0_id);
	$display("%d %h %h %c%h %o #",
	    dram1, dram1_addr, dram1_data, (IsFlowCtrl(dram1_instr) ? 98 : (IsMem(dram1_instr)) ? 109 : 97), 
	    dram1_instr, dram1_id);
	$display("%d %h %h %c%h %o #",
	    dram2, dram2_addr, dram2_data, (IsFlowCtrl(dram2_instr) ? 98 : (IsMem(dram2_instr)) ? 109 : 97), 
	    dram2_instr, dram2_id);
	$display("%d %h %o %h #", dramA_v, dramA_bus, dramA_id, dramA_exc);
	$display("%d %h %o %h #", dramB_v, dramB_bus, dramB_id, dramB_exc);
	$display("%d %h %o %h #", dramC_v, dramC_bus, dramC_id, dramC_exc);
    $display("ALU");
	$display("%d %h %h %h %c%h %d %o %h #",
		alu0_dataready, alu0_argI, alu0_argA, alu0_argB, 
		 (IsFlowCtrl(alu0_instr) ? 98 : IsMem(alu0_instr) ? 109 : 97),
		alu0_instr, alu0_bt, alu0_sourceid, alu0_pc);
	$display("%d %h %o 0 #", alu0_v, alu0_bus, alu0_id);

	$display("%d %h %h %h %c%h %d %o %h #",
		alu1_dataready, alu1_argI, alu1_argA, alu1_argB, 
		 (IsFlowCtrl(alu1_instr) ? 98 : IsMem(alu1_instr) ? 109 : 97),
		alu1_instr, alu1_bt, alu1_sourceid, alu1_pc);
	$display("%d %h %o 0 #", alu1_v, alu1_bus, alu1_id);
	$display("FCU");
	$display("%d %h %h %h %h #", fcu_v, fcu_bus, fcu_argI, fcu_argA, fcu_argB);
	$display("%c %h %h #", fcu_branchmiss?"m":" ", fcu_sourceid, fcu_misspc); 
    $display("Commit");
	$display("0: %c %h %o 0%d #", commit0_v?"v":" ", commit0_bus, commit0_id, commit0_tgt[4:0]);
	$display("1: %c %h %o 0%d #", commit1_v?"v":" ", commit1_bus, commit1_id, commit1_tgt[4:0]);
    $display("instructions committed: %d ticks: %d ", I, tick);
//
//	$display("\n\n\n\n\n\n\n\n");
//	$display("TIME %0d", $time);
//	$display("  pc0=%h", pc0);
//	$display("  pc1=%h", pc1);
//	$display("  reg0=%h, v=%d, src=%o", rf[0], rf_v[0], rf_source[0]);
//	$display("  reg1=%h, v=%d, src=%o", rf[1], rf_v[1], rf_source[1]);
//	$display("  reg2=%h, v=%d, src=%o", rf[2], rf_v[2], rf_source[2]);
//	$display("  reg3=%h, v=%d, src=%o", rf[3], rf_v[3], rf_source[3]);
//	$display("  reg4=%h, v=%d, src=%o", rf[4], rf_v[4], rf_source[4]);
//	$display("  reg5=%h, v=%d, src=%o", rf[5], rf_v[5], rf_source[5]);
//	$display("  reg6=%h, v=%d, src=%o", rf[6], rf_v[6], rf_source[6]);
//	$display("  reg7=%h, v=%d, src=%o", rf[7], rf_v[7], rf_source[7]);

//	$display("Fetch Buffers:");
//	$display("  %c%c fbA: v=%d instr=%h pc=%h     %c%c fbC: v=%d instr=%h pc=%h", 
//	    fetchbuf?32:45, fetchbuf?32:62, fetchbufA_v, fetchbufA_instr, fetchbufA_pc,
//	    fetchbuf?45:32, fetchbuf?62:32, fetchbufC_v, fetchbufC_instr, fetchbufC_pc);
//	$display("  %c%c fbB: v=%d instr=%h pc=%h     %c%c fbD: v=%d instr=%h pc=%h", 
//	    fetchbuf?32:45, fetchbuf?32:62, fetchbufB_v, fetchbufB_instr, fetchbufB_pc,
//	    fetchbuf?45:32, fetchbuf?62:32, fetchbufD_v, fetchbufD_instr, fetchbufD_pc);
//	$display("  branchback=%d backpc=%h", branchback, backpc);

//	$display("Instruction Queue:");
//	for (i=0; i<8; i=i+1) 
//	    $display(" %c%c%d: v=%d done=%d out=%d agen=%d res=%h op=%d bt=%d tgt=%d a1=%h (v=%d/s=%o) a2=%h (v=%d/s=%o) im=%h pc=%h exc=%h",
//		(iQNDX==head0)?72:32, (iQNDX==tail0)?84:32, i,
//		iqentry_v[i], iqentry_done[i], iqentry_out[i], iqentry_agen[i], iqentry_res[i], iqentry_op[i], 
//		iqentry_bt[i], iqentry_tgt[i], iqentry_a1[i], iqentry_a1_v[i], iqentry_a1_s[i], iqentry_a2[i], iqentry_a2_v[i], 
//		iqentry_a2_s[i], iqentry_a0[i], iqentry_pc[i], iqentry_exc[i]);

//	$display("Scheduling Status:");
//	$display("  iqentry0 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
//		iqentry_0_issue, iqentry_0_islot, iqentry_stomp[0], iqentry_source[0], iqentry_memready[0], iqentry_memissue[0]);
//	$display("  iqentry1 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
//		iqentry_1_issue, iqentry_1_islot, iqentry_stomp[1], iqentry_source[1], iqentry_memready[1], iqentry_memissue[1]);
//	$display("  iqentry2 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
//		iqentry_2_issue, iqentry_2_islot, iqentry_stomp[2], iqentry_source[2], iqentry_memready[2], iqentry_memissue[2]);
//	$display("  iqentry3 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
//		iqentry_3_issue, iqentry_3_islot, iqentry_stomp[3], iqentry_source[3], iqentry_memready[3], iqentry_memissue[3]);
//	$display("  iqentry4 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
//		iqentry_4_issue, iqentry_4_islot, iqentry_stomp[4], iqentry_source[4], iqentry_memready[4], iqentry_memissue[4]);
//	$display("  iqentry5 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
//		iqentry_5_issue, iqentry_5_islot, iqentry_stomp[5], iqentry_source[5], iqentry_memready[5], iqentry_memissue[5]);
//	$display("  iqentry6 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
//		iqentry_6_issue, iqentry_6_islot, iqentry_stomp[6], iqentry_source[6], iqentry_memready[6], iqentry_memissue[6]);
//	$display("  iqentry7 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
//		iqentry_7_issue, iqentry_7_islot, iqentry_stomp[7], iqentry_source[7], iqentry_memready[7], iqentry_memissue[7]);

//	$display("ALU Inputs:");
//	$display("  0: avail=%d data=%d id=%o op=%d a1=%h a2=%h im=%h bt=%d",
//		alu0_available, alu0_dataready, alu0_sourceid, alu0_op, alu0_argA,
//		alu0_argB, alu0_argI, alu0_bt);
//	$display("  1: avail=%d data=%d id=%o op=%d a1=%h a2=%h im=%h bt=%d",
//		alu1_available, alu1_dataready, alu1_sourceid, alu1_op, alu1_argA,
//		alu1_argB, alu1_argI, alu1_bt);

//	$display("ALU Outputs:");
//	$display("  0: v=%d bus=%h id=%o bmiss=%d misspc=%h missid=%o",
//		alu0_v, alu0_bus, alu0_id, alu0_branchmiss, alu0_misspc, alu0_sourceid);
//	$display("  1: v=%d bus=%h id=%o bmiss=%d misspc=%h missid=%o",
//		alu1_v, alu1_bus, alu1_id, alu1_branchmiss, alu1_misspc, alu1_sourceid);

//	$display("DRAM Status:");
//	$display("  OUT: v=%d data=%h tgt=%d id=%o", dram_v, dram_bus, dram_tgt, dram_id);
//	$display("  dram0: status=%h addr=%h data=%h op=%d tgt=%d id=%o",
//	    dram0, dram0_addr, dram0_data, dram0_op, dram0_tgt, dram0_id);
//	$display("  dram1: status=%h addr=%h data=%h op=%d tgt=%d id=%o", 
//	    dram1, dram1_addr, dram1_data, dram1_op, dram1_tgt, dram1_id);
//	$display("  dram2: status=%h addr=%h data=%h op=%d tgt=%d id=%o",
//	    dram2, dram2_addr, dram2_data, dram2_op, dram2_tgt, dram2_id);

//	$display("Commit Buses:");
//	$display("  0: v=%d id=%o data=%h", commit0_v, commit0_id, commit0_bus);
//	$display("  1: v=%d id=%o data=%h", commit1_v, commit1_id, commit1_bus);

//
//	$display("Memory Contents:");
//	for (j=0; j<64; j=j+16)
//	    $display("  %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h", 
//		m[j+0], m[j+1], m[j+2], m[j+3], m[j+4], m[j+5], m[j+6], m[j+7],
//		m[j+8], m[j+9], m[j+10], m[j+11], m[j+12], m[j+13], m[j+14], m[j+15]);

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

end // clock domain
// Increment the head pointers
// Also increments the instruction counter
// Used when instructions are committed.
// Also clear any outstanding state bits that foul things up.
//
task head_inc;
input QNDX amt;
begin
     head0 <= head0 + amt;
     head1 <= head1 + amt;
     head2 <= head2 + amt;
     head3 <= head3 + amt;
     head4 <= head4 + amt;
     head5 <= head5 + amt;
     head6 <= head6 + amt;
     head7 <= head7 + amt;
     I <= I + amt;
    if (amt==3'd2) begin
     iqentry_agen[head0] <= `INV;
     iqentry_agen[head1] <= `INV;
    end else if (amt==3'd1)
	     iqentry_agen[head0] <= `INV;
end
endtask

// Enqueue fetchbuf0 onto the tail of the instruction queue
task enque0;
input QNDX tail;
input [5:0] venno;
begin
	iqentry_exc[tail] <= `FLT_NONE;
`ifdef SUPPORT_DBG
    if (dbg_imatchA)
        iqentry_exc[tail] <= `FLT_DBG;
    else if (dbg_ctrl[63])
        iqentry_exc[tail] <= `FLT_SSM;
`endif
	iqentry_v    [tail]    <=    `VAL;
	iqentry_thrd [tail]    <=   1'b0;
	iqentry_done [tail]    <=    `INV;
	iqentry_cmt  [tail]    <=	`INV;
	iqentry_pred [tail]    <=   `VAL;
	iqentry_out  [tail]    <=    `INV;
	iqentry_res  [tail]    <=    `ZERO;
	iqentry_instr[tail]    <=    IsVLS(insn0a) ? (vm[fnM2(insn0a)] ? insn0a : `NOP_INSN) : insn0a;
	iqentry_bt   [tail]    <=    (IsBranch(insn0a) && predict_taken0);
	iqentry_agen [tail]    <=    `INV;
// If the previous instruction was a hardware interrupt and this instruction is a hardware interrupt
// inherit the previous pc.
//if (IsBrk(insn0a) && !insn0a[15] &&
//   (IsBrk(iqentry_instr[idm1(tail)]) && !iqentry_instr[idm1(tail1)][15] && iqentry_v[idm1(tail)]))
//   iqentry_pc   [tail]    <= iqentry_pc[idm1(tail)];
//else
	 iqentry_pc   [tail] <= fetchbuf0_pc;
	iqentry_alu  [tail]    <=   IsALU(insn0a);
	iqentry_alu0 [tail]    <=   IsAlu0Only(insn0a);
	iqentry_fpu  [tail]    <=   IsFPU(insn0a);
	iqentry_fc   [tail]    <=   IsFlowCtrl(insn0a);
	iqentry_canex[tail]    <=   fnCanException(insn0a);
	iqentry_load [tail]    <=   IsLoad(insn0a);
	iqentry_mem  [tail]    <=   fetchbuf0_mem;
	iqentry_memndx[tail]   <=   IsMemNdx(insn0a);
	iqentry_memdb[tail]    <=   IsMemdb(insn0a);
	iqentry_memsb[tail]    <=   IsMemsb(insn0a);
	iqentry_sei	 [tail]	   <=   IsSEI(insn0a);
	iqentry_aq   [tail]    <=   (IsAMO(insn0a)|IsLWRX(insn0a)|IsSWCX(insn0a)) & insn0a[25];
	iqentry_rl   [tail]    <=   (IsAMO(insn0a)|IsLWRX(insn0a)|IsSWCX(insn0a)) & insn0a[24];
	iqentry_jmp  [tail]    <=   fetchbuf0_jmp;
	iqentry_br   [tail]    <=  	IsBranch(insn0a);
	iqentry_sync [tail]    <=  	IsSync(insn0a)||IsBrk(insn0a)||IsRTI(insn0a);
	iqentry_fsync[tail]    <=  	IsFSync(insn0a);
	iqentry_rfw  [tail]    <=   fetchbuf0_rfw;
	iqentry_we   [tail]    <= 	fnWe(insn0a);
	iqentry_tgt  [tail]    <=	Rt0;
	iqentry_Ra[tail] <= Ra0;
	iqentry_Rb[tail] <= Rb0;
	iqentry_Rc[tail] <= Rc0;
	iqentry_ven  [tail]    <=   venno;
	iqentry_exc  [tail]    <=    `EXC_NONE;
	iqentry_imm  [tail]    <= HasConst(insn0a);
	iqentry_a0   [tail]    <= {{48{insn0a[`INSTRUCTION_SB]}},insn0a[31:16]};
	iqentry_a1   [tail]    <=    rfoa0;
	iqentry_a1_v [tail]    <=    Source1Valid(insn0a) | regIsValid[Ra0s];
	iqentry_a1_s [tail]    <=    rf_source[Ra0s];
	iqentry_a2   [tail]    <=    rfob0;
	iqentry_a2_v [tail]    <=    Source2Valid(insn0a) | regIsValid[Rb0s];
	iqentry_a2_s [tail]    <=    rf_source[Rb0s];
	iqentry_a3   [tail]    <=    rfoc0;
	iqentry_a3_v [tail]    <=    Source3Valid(insn0a) | regIsValid[Rc0s];
	iqentry_a3_s [tail]    <=    rf_source[Rc0s];
end
endtask

// Enque fetchbuf1. Fetchbuf1 might be the second instruction to queue so some
// of this code checks to see which tail it is being queued on.
task enque1;
input QNDX tail;
input [5:0] venno;
begin
 iqentry_exc[tail] <= `FLT_NONE;
`ifdef SUPPORT_DBG
    if (dbg_imatchB)
        iqentry_exc[tail] <= `FLT_DBG;
    else if (dbg_ctrl[63])
        iqentry_exc[tail] <= `FLT_SSM;
`endif
	iqentry_v    [tail]    <=   `VAL;
	iqentry_thrd [tail]    <=   thread_en ? 1'b1 : 1'b0;
	iqentry_done [tail]    <=   `INV;
	iqentry_cmt  [tail]    <=	`INV;
	iqentry_pred [tail]    <=   `VAL;
	iqentry_out  [tail]    <=   `INV;
	iqentry_res  [tail]    <=   `ZERO;
	iqentry_instr[tail]    <=   IsVLS(insn1a) ? (vm[fnM2(insn1a)] ? insn1a : `NOP_INSN) : insn1a; 
	iqentry_bt   [tail]    <=   (IsBranch(insn1a) && predict_taken1); 
	iqentry_agen [tail]    <=   `INV;
// If queing 2nd instruction must read from first
if (tail==tail1) begin
    // If the previous instruction was a hardware interrupt and this instruction is a hardware interrupt
    // inherit the previous pc.
//    if (IsBrk(insn1a) && !insn1a[15] &&
//        IsBrk(insn0a) && !insn0a[15])
//       iqentry_pc   [tail]    <= fetchbuf0_pc;
//    else
		iqentry_pc   [tail] <= fetchbuf1_pc;
end
else begin
    // If the previous instruction was a hardware interrupt and this instruction is a hardware interrupt
    // inherit the previous pc.
//    if (IsBrk(insn1a) && !insn1a[15] &&
//       (IsBrk(iqentry_instr[idp7(tail)]) && !iqentry_instr[idm1(tail)][15] && iqentry_v[idm1(tail)]))
//       iqentry_pc   [tail]    <= iqentry_pc[idm1(tail)];
//    else
		iqentry_pc   [tail] <= fetchbuf1_pc;
end
	iqentry_alu  [tail]    <=   IsALU(insn1a);
	iqentry_alu0 [tail]    <=   IsAlu0Only(insn1a);
	iqentry_fpu  [tail]    <=   IsFPU(insn1a);
	iqentry_fc   [tail]    <=   IsFlowCtrl(insn1a);
	iqentry_canex[tail]    <=   fnCanException(insn1a);
	iqentry_load [tail]    <=   IsLoad(insn1a);
	iqentry_mem  [tail]    <=   fetchbuf1_mem;
	iqentry_memndx[tail]   <=   IsMemNdx(insn1a);
	iqentry_memdb[tail]    <=   IsMemdb(insn1a);
	iqentry_memsb[tail]    <=   IsMemsb(insn1a);
	iqentry_sei	 [tail]	   <=   IsSEI(insn1a);
	iqentry_aq   [tail]    <=   (IsAMO(insn1a)|IsLWRX(insn1a)|IsSWCX(insn1a)) & insn1a[25];
	iqentry_rl   [tail]    <=   (IsAMO(insn1a)|IsLWRX(insn1a)|IsSWCX(insn1a)) & insn1a[24];
	iqentry_jmp  [tail]    <=   fetchbuf1_jmp;
	iqentry_br   [tail]    <=   IsBranch(insn1a);
	iqentry_sync [tail]    <=   IsSync(insn1a)||IsBrk(insn1a)||IsRTI(insn1a);
	iqentry_fsync[tail]    <=   IsFSync(insn1a);
	iqentry_rfw  [tail]    <=   fetchbuf1_rfw;
	iqentry_we   [tail]    <= 	fnWe(insn1a);
	iqentry_tgt  [tail]    <= Rt1;
	iqentry_Ra[tail] <= Ra1;
	iqentry_Rb[tail] <= Rb1;
	iqentry_Rc[tail] <= Rc1;
	iqentry_ven  [tail]    <=   venno;
	iqentry_exc  [tail]    <=   `EXC_NONE;
	iqentry_imm  [tail]    <= HasConst(insn1a);
	iqentry_a0   [tail]    <= {{48{insn1a[`INSTRUCTION_SB]}},insn1a[31:16]};
	iqentry_a1   [tail]    <=	rfoa1;
	iqentry_a1_v [tail]    <=	Source1Valid(insn1a) | regIsValid[Ra1s];
	iqentry_a1_s [tail]    <=	rf_source[Ra1s];
	iqentry_a2   [tail]    <=	rfob1;
	iqentry_a2_v [tail]    <=	Source2Valid(insn1a) | regIsValid[Rb1s];
	iqentry_a2_s [tail]    <=	rf_source[Rb1s];
	iqentry_a3   [tail]    <=	rfoc1;
	iqentry_a3_v [tail]    <=	Source3Valid(insn1a) | regIsValid[Rc1s];
	iqentry_a3_s [tail]    <=	rf_source[Rc1s];
end
endtask

function IsOddball;
input QNDX head;
if (|iqentry_exc[head])
    IsOddball = TRUE;
else
case(iqentry_instr[head][6:0])
OP_BRK:   IsOddball = TRUE;
`VECTOR:
    case(iqentry_instr[head][`INSTRUCTION_S2])
    `VSxx:  IsOddball = TRUE;
    default:    IsOddball = FALSE;
    endcase
OP_R2:
    case(iqentry_instr[head][`INSTRUCTION_S2])
    `VMOV:  IsOddball = TRUE;
    `SEI,`RTI,OP_CACHEX: IsOddball = TRUE;
    default:    IsOddball = FALSE;
    endcase
`CSRRW,`REX,OP_CACHE,`FLOAT:  IsOddball = TRUE;
default:    IsOddball = FALSE;
endcase
endfunction
    
// This task takes care of commits for things other than the register file.
task oddball_commit;
input v;
input QNDX head;
reg thread;
begin
    thread = iqentry_thrd[head];
    if (v) begin
        if (|iqentry_exc[head]) begin
            excmiss <= TRUE;
          	excmisspc <= {tvec[3'd0][51:8],ol[thread],5'h00};
            excthrd <= iqentry_thrd[head];
            badaddr[{thread,3'd0}] <= iqentry_a1[head];
            epc0[thread] <= iqentry_pc[head]+ 32'd4;
            epc1[thread] <= epc0[thread];
            epc2[thread] <= epc1[thread];
            epc3[thread] <= epc2[thread];
            epc4[thread] <= epc3[thread];
            epc5[thread] <= epc4[thread];
            epc6[thread] <= epc5[thread];
            epc7[thread] <= epc6[thread];
            epc8[thread] <= epc7[thread];
            im_stack[thread] <= {im_stack[thread][20:0],im};
            ol_stack[thread] <= {ol_stack[thread][20:0],ol[thread]};
            pl_stack[thread] <= {pl_stack[thread][55:0],cpl[thread]};
            rs_stack[thread] <= {rs_stack[thread][55:0],rgs[thread]};
            cause[{thread,3'd0}] <= {8'd0,iqentry_exc[head]};
            mstatus[thread][5:3] <= 3'd0;
            mstatus[thread][13:6] <= 8'h00;
            mstatus[thread][19:14] <= 6'd0;
            sema[0] <= 1'b0;
            ve_hold <= {vqet1,10'd0,vqe1,10'd0,vqet0,10'd0,vqe0};
`ifdef SUPPORT_DBG            
            dbg_ctrl[62:55] <= {dbg_ctrl[61:55],dbg_ctrl[63]}; 
            dbg_ctrl[63] <= FALSE;
`endif            
        end
        else
        case(iqentry_instr[head][6:0])
        OP_BRK:   
        		// BRK is treated as a nop unless it's a software interrupt or a
        		// hardware interrupt at a higher priority than the current priority.
                if ((iqentry_instr[head][23:19] > 5'd0) || iqentry_instr[head][18:16] > im) begin
		            excmiss <= TRUE;
            		excmisspc <= {tvec[3'd0][31:8],ol[thread],5'h00};
            		excthrd <= iqentry_thrd[head];
                    epc0[thread] <= iqentry_pc[head] + {iqentry_instr[head][23:19],2'b00};
                    epc1[thread] <= epc0[thread];
                    epc2[thread] <= epc1[thread];
                    epc3[thread] <= epc2[thread];
                    epc4[thread] <= epc3[thread];
                    epc5[thread] <= epc4[thread];
                    epc6[thread] <= epc5[thread];
                    epc7[thread] <= epc6[thread];
                    epc8[thread] <= epc7[thread];
                    im_stack[thread] <= {im_stack[thread][20:0],im};
                    ol_stack[thread] <= {ol_stack[thread][20:0],ol[thread]};
                    pl_stack[thread] <= {pl_stack[thread][55:0],cpl[thread]};
                    rs_stack[thread] <= {rs_stack[thread][55:0],rgs[thread]};
                    mstatus[thread][19:14] <= 6'd0;
                    cause[{thread,3'd0}] <= {iqentry_instr[head][31:24],iqentry_instr[head][13:6]};
                    mstatus[thread][5:3] <= 3'd0;
	                mstatus[thread][13:6] <= 8'h00;
                    // For hardware interrupts only, set a new mask level
                    // Select register set according to interrupt level
                    if (iqentry_instr[head][23:19]==5'd0) begin
                        mstatus[thread][2:0] <= 3'd7;//iqentry_instr[head][18:16];
                        mstatus[thread][42:40] <= iqentry_instr[head][18:16];
                        mstatus[thread][19:14] <= {1'b0,iqentry_instr[head][18:16],2'b00};
                    end
                    sema[0] <= 1'b0;
                    ve_hold <= {vqet1,10'd0,vqe1,10'd0,vqet0,10'd0,vqe0};
`ifdef SUPPORT_DBG                    
                    dbg_ctrl[62:55] <= {dbg_ctrl[61:55],dbg_ctrl[63]}; 
                    dbg_ctrl[63] <= FALSE;
`endif                    
                end
        `VECTOR:
            casez(iqentry_tgt[head])
            8'b00100xxx:  vm[iqentry_tgt[head][2:0]] <= iqentry_res[head];
            8'b00101111:  vl <= iqentry_res[head];
            default:    ;
            endcase
        OP_R2:
            case(iqentry_instr[head][`INSTRUCTION_S2])
            `R1:	case(iqentry_instr[head][20:16])
            		`CHAIN_OFF:	cr0[18] <= 1'b0;
            		`CHAIN_ON:	cr0[18] <= 1'b1;
            		default:	;
        			endcase
            `VMOV:  casez(iqentry_tgt[head])
                    12'b1111111_00???:  vm[iqentry_tgt[head][2:0]] <= iqentry_res[head];
                    12'b1111111_01111:  vl <= iqentry_res[head];
                    default:	;
                    endcase
            `SEI:   mstatus[thread][2:0] <= iqentry_res[head][2:0];   // S1
            `RTI:   begin
		            excmiss <= TRUE;
            		excmisspc <= epc0[thread];
            		excthrd <= thread;
            		mstatus[thread][2:0] <= im_stack[thread][2:0];
            		mstatus[thread][5:3] <= ol_stack[thread][2:0];
            		mstatus[thread][13:6] <= pl_stack[thread][7:0];
            		mstatus[thread][19:14] <= rs_stack[thread][5:0];
            		im_stack[thread] <= {3'd7,im_stack[thread][23:3]};
            		ol_stack[thread] <= {3'd0,ol_stack[thread][23:3]};
            		pl_stack[thread] <= {8'h00,pl_stack[thread][63:8]};
            		rs_stack[thread] <= {8'h00,rs_stack[thread][63:8]};
                    epc0[thread] <= epc1[thread];
                    epc1[thread] <= epc2[thread];
                    epc2[thread] <= epc3[thread];
                    epc3[thread] <= epc4[thread];
                    epc4[thread] <= epc5[thread];
                    epc5[thread] <= epc6[thread];
                    epc6[thread] <= epc7[thread];
                    epc7[thread] <= epc8[thread];
                    epc8[thread] <= {tvec[0][31:8], ol[thread], 5'h0};
                    sema[0] <= 1'b0;
                    sema[iqentry_res[head][5:0]] <= 1'b0;
                    vqe0  <= ve_hold[ 5: 0];
                    vqet0 <= ve_hold[21:16];
                    vqe1  <= ve_hold[37:32];
                    vqet1 <= ve_hold[53:48];
`ifdef SUPPORT_DBG                    
                    dbg_ctrl[62:55] <= {FALSE,dbg_ctrl[62:56]}; 
                    dbg_ctrl[63] <= dbg_ctrl[55];
`endif                    
                    end
            OP_CACHEX:
                    case(iqentry_instr[head][20:16])
                    5'h03:  invic <= TRUE;
                    5'h10:  cr0[30] <= FALSE;
                    5'h11:  cr0[30] <= TRUE;
                    default:    ;
                    endcase
            default: ;
            endcase
        `CSRRW:
        		begin
        		write_csr(iqentry_instr[head][31:16],iqentry_a1[head],thread);
        		end
        `REX:
            // Can only redirect to a lower level
            if (ol[thread] < iqentry_instr[head][13:11]) begin
                mstatus[thread][5:3] <= iqentry_instr[head][13:11];
                badaddr[{thread,iqentry_instr[head][13:11]}] <= badaddr[{thread,ol[thread]}];
                cause[{thread,iqentry_instr[head][13:11]}] <= cause[{thread,ol[thread]}];
                mstatus[thread][13:6] <= iqentry_instr[head][23:16] | iqentry_a1[head][7:0];
            end
        OP_CACHE:
            case(iqentry_instr[head][15:11])
            5'h03:  invic <= TRUE;
            5'h10:  cr0[30] <= FALSE;
            5'h11:  cr0[30] <= TRUE;
            default:    ;
            endcase
        `FLOAT:
            case(iqentry_instr[head][`INSTRUCTION_S2])
            `FRM:   fp_rm <= iqentry_res[head][2:0];
            `FCX:
                begin
                    fp_sx <= fp_sx & ~iqentry_res[head][5];
                    fp_inex <= fp_inex & ~iqentry_res[head][4];
                    fp_dbzx <= fp_dbzx & ~(iqentry_res[head][3]|iqentry_res[head][0]);
                    fp_underx <= fp_underx & ~iqentry_res[head][2];
                    fp_overx <= fp_overx & ~iqentry_res[head][1];
                    fp_giopx <= fp_giopx & ~iqentry_res[head][0];
                    fp_infdivx <= fp_infdivx & ~iqentry_res[head][0];
                    fp_zerozerox <= fp_zerozerox & ~iqentry_res[head][0];
                    fp_subinfx   <= fp_subinfx   & ~iqentry_res[head][0];
                    fp_infzerox  <= fp_infzerox  & ~iqentry_res[head][0];
                    fp_NaNCmpx   <= fp_NaNCmpx   & ~iqentry_res[head][0];
                    fp_swtx <= 1'b0;
                end
            `FDX:
                begin
                    fp_inexe <= fp_inexe     & ~iqentry_res[head][4];
                    fp_dbzxe <= fp_dbzxe     & ~iqentry_res[head][3];
                    fp_underxe <= fp_underxe & ~iqentry_res[head][2];
                    fp_overxe <= fp_overxe   & ~iqentry_res[head][1];
                    fp_invopxe <= fp_invopxe & ~iqentry_res[head][0];
                end
            `FEX:
                begin
                    fp_inexe <= fp_inexe     | iqentry_res[head][4];
                    fp_dbzxe <= fp_dbzxe     | iqentry_res[head][3];
                    fp_underxe <= fp_underxe | iqentry_res[head][2];
                    fp_overxe <= fp_overxe   | iqentry_res[head][1];
                    fp_invopxe <= fp_invopxe | iqentry_res[head][0];
                end
            default:
                begin
                    // 31 to 29 is rounding mode
                    // 28 to 24 are exception enables
                    // 23 is nsfp
                    // 22 is a fractie
                    fp_fractie <= iqentry_a0[head][22];
                    fp_raz <= iqentry_a0[head][21];
                    // 20 is a 0
                    fp_neg <= iqentry_a0[head][19];
                    fp_pos <= iqentry_a0[head][18];
                    fp_zero <= iqentry_a0[head][17];
                    fp_inf <= iqentry_a0[head][16];
                    // 15 swtx
                    // 14 
                    fp_inex <= fp_inex | (fp_inexe & iqentry_a0[head][14]);
                    fp_dbzx <= fp_dbzx | (fp_dbzxe & iqentry_a0[head][13]);
                    fp_underx <= fp_underx | (fp_underxe & iqentry_a0[head][12]);
                    fp_overx <= fp_overx | (fp_overxe & iqentry_a0[head][11]);
                    //fp_giopx <= fp_giopx | (fp_giopxe & iqentry_res2[head][10]);
                    //fp_invopx <= fp_invopx | (fp_invopxe & iqentry_res2[head][24]);
                    //
                    fp_cvtx <= fp_cvtx |  (fp_giopxe & iqentry_a0[head][7]);
                    fp_sqrtx <= fp_sqrtx |  (fp_giopxe & iqentry_a0[head][6]);
                    fp_NaNCmpx <= fp_NaNCmpx |  (fp_giopxe & iqentry_a0[head][5]);
                    fp_infzerox <= fp_infzerox |  (fp_giopxe & iqentry_a0[head][4]);
                    fp_zerozerox <= fp_zerozerox |  (fp_giopxe & iqentry_a0[head][3]);
                    fp_infdivx <= fp_infdivx | (fp_giopxe & iqentry_a0[head][2]);
                    fp_subinfx <= fp_subinfx | (fp_giopxe & iqentry_a0[head][1]);
                    fp_snanx <= fp_snanx | (fp_giopxe & iqentry_a0[head][0]);

                end
            endcase
        default:    ;
        endcase
        // Once the flow control instruction commits, NOP it out to allow
        // pending stores to be issued.
        iqentry_instr[head][5:0] <= `NOP;
    end
end
endtask

// CSR access tasks
task read_csr;
input [13:0] csrno;
output [63:0] dat;
input [4:0] thread;
begin
    if (csrno[13:11] >= ol[thread])
    casez(csrno[10:0])
    `CSR_CR0:       dat <= cr0;
    `CSR_HARTID:    dat <= hartid;
    `CSR_TICK:      dat <= tick;
    `CSR_PCR:       dat <= pcr;
    `CSR_PCR2:      dat <= pcr2;
    `CSR_SEMA:      dat <= sema;
    `CSR_SBL:       dat <= sbl;
    `CSR_SBU:       dat <= sbu;
    `CSR_TCB:		dat <= tcb;
    `CSR_FSTAT:     dat <= fp_status;
`ifdef SUPPORT_DBG    
    `CSR_DBAD0:     dat <= dbg_adr0;
    `CSR_DBAD1:     dat <= dbg_adr1;
    `CSR_DBAD2:     dat <= dbg_adr2;
    `CSR_DBAD3:     dat <= dbg_adr3;
    `CSR_DBCTRL:    dat <= dbg_ctrl;
    `CSR_DBSTAT:    dat <= dbg_stat;
`endif   
    `CSR_CAS:       dat <= cas;
    `CSR_TVEC:      dat <= tvec[csrno[2:0]];
    `CSR_BADADR:    dat <= badaddr[{thread,csrno[13:11]}];
    `CSR_CAUSE:     dat <= {48'd0,cause[{thread,csrno[13:11]}]};
    `CSR_IM_STACK:	dat <= im_stack[thread];
    `CSR_OL_STACK:	dat <= ol_stack[thread];
    `CSR_PL_STACK:	dat <= pl_stack[thread];
    `CSR_RS_STACK:	dat <= rs_stack[thread];
    `CSR_STATUS:    dat <= mstatus[thread][63:0];
    `CSR_EPC0:      dat <= epc0[thread];
    `CSR_EPC1:      dat <= epc1[thread];
    `CSR_EPC2:      dat <= epc2[thread];
    `CSR_EPC3:      dat <= epc3[thread];
    `CSR_EPC4:      dat <= epc4[thread];
    `CSR_EPC5:      dat <= epc5[thread];
    `CSR_EPC6:      dat <= epc6[thread];
    `CSR_EPC7:      dat <= epc7[thread];
    `CSR_CODEBUF:   dat <= codebuf[csrno[5:0]];
    `CSR_TIME:		dat <= wc_times;
    `CSR_INFO:
                    case(csrno[3:0])
                    4'd0:   dat <= "Finitron";  // manufacturer
                    4'd1:   dat <= "        ";
                    4'd2:   dat <= "64 bit  ";  // CPU class
                    4'd3:   dat <= "        ";
                    4'd4:   dat <= "FT64    ";  // Name
                    4'd5:   dat <= "        ";
                    4'd6:   dat <= 64'd1;       // model #
                    4'd7:   dat <= 64'd1;       // serial number
                    4'd8:   dat <= {32'd16384,32'd16384};   // cache sizes instruction,data
                    4'd9:   dat <= 64'd0;
                    default:    dat <= 64'd0;
                    endcase
    default:    begin    
    			$display("Unsupported CSR:%h",csrno[10:0]);
    			dat <= 64'hEEEEEEEEEEEEEEEE;
    			end
    endcase
    else
        dat <= 64'h0;
end
endtask

task write_csr;
input [15:0] csrno;
input [63:0] dat;
input [4:0] thread;
begin
    if (csrno[13:11] >= ol[thread])
    case(csrno[15:14])
    2'd1:   // CSRRW
        casez(csrno[10:0])
        `CSR_CR0:       cr0 <= dat;
        `CSR_PCR:       pcr <= dat[31:0];
        `CSR_PCR2:      pcr2 <= dat;
        `CSR_SEMA:      sema <= dat;
        `CSR_SBL:       sbl <= dat[31:0];
        `CSR_SBU:       sbu <= dat[31:0];
        `CSR_TCB:		tcb <= dat;
        `CSR_BADADR:    badaddr[{thread,csrno[13:11]}] <= dat;
        `CSR_CAUSE:     cause[{thread,csrno[13:11]}] <= dat[15:0];
`ifdef SUPPORT_DBG        
        `CSR_DBAD0:     dbg_adr0 <= dat[AMSB:0];
        `CSR_DBAD1:     dbg_adr1 <= dat[AMSB:0];
        `CSR_DBAD2:     dbg_adr2 <= dat[AMSB:0];
        `CSR_DBAD3:     dbg_adr3 <= dat[AMSB:0];
        `CSR_DBCTRL:    dbg_ctrl <= dat;
`endif        
        `CSR_CAS:       cas <= dat;
        `CSR_TVEC:      tvec[csrno[2:0]] <= dat[31:0];
        `CSR_IM_STACK:	im_stack[thread] <= dat[23:0];
        `CSR_OL_STACK:	ol_stack[thread] <= dat[23:0];
        `CSR_PL_STACK:	pl_stack[thread] <= dat;
        `CSR_RS_STACK:	rs_stack[thread] <= dat;
        `CSR_STATUS:    mstatus[thread][51:0] <= dat;
        `CSR_EPC0:      epc0[thread] <= dat;
        `CSR_EPC1:      epc1[thread] <= dat;
        `CSR_EPC2:      epc2[thread] <= dat;
        `CSR_EPC3:      epc3[thread] <= dat;
        `CSR_EPC4:      epc4[thread] <= dat;
        `CSR_EPC5:      epc5[thread] <= dat;
        `CSR_EPC6:      epc6[thread] <= dat;
        `CSR_EPC7:      epc7[thread] <= dat;
		`CSR_TIME:		begin
						ld_time <= 6'h3f;
						wc_time_dat <= dat;
						end
        `CSR_CODEBUF:   codebuf[csrno[5:0]] <= dat;
        default:    ;
        endcase
    2'd2:   // CSRRS
        case(csrno[10:0])
        `CSR_CR0:       cr0 <= cr0 | dat;
        `CSR_PCR:       pcr[31:0] <= pcr[31:0] | dat[31:0];
        `CSR_PCR2:      pcr2 <= pcr2 | dat;
`ifdef SUPPORT_DBG        
        `CSR_DBCTRL:    dbg_ctrl <= dbg_ctrl | dat;
`endif        
        `CSR_SEMA:      sema <= sema | dat;
        `CSR_STATUS:    mstatus[thread][51:0] <= mstatus[thread][51:0] | dat;
        default:    ;
        endcase
    2'd3:   // CSRRC
        case(csrno[10:0])
        `CSR_CR0:       cr0 <= cr0 & ~dat;
        `CSR_PCR:       pcr <= pcr & ~dat;
        `CSR_PCR2:      pcr2 <= pcr2 & ~dat;
`ifdef SUPPORT_DBG        
        `CSR_DBCTRL:    dbg_ctrl <= dbg_ctrl & ~dat;
`endif        
        `CSR_SEMA:      sema <= sema & ~dat;
        `CSR_STATUS:    mstatus[thread][51:0] <= mstatus[thread][51:0] & ~dat;
        default:    ;
        endcase
    default:    ;
    endcase
end
endtask

endmodule
