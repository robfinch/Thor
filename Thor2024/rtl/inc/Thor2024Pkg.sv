`timescale 1ns / 10ps
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

package Thor2024pkg;

`undef IS_SIM
//`define IS_SIM	1
// Comment out to remove the sigmoid approximate function
//`define SIGMOID	1

//`define SUPPORT_16BIT_OPS		1
//`define SUPPORT_64BIT_OPS		1
//`define SUPPORT_128BIT_OPS	1
`define NLANES	4
`define NTHREADS	4
`define NREGS		64

`define L1CacheLines	1024
`define L1CacheLineSize		256

`define L1ICacheLineSize	256
`define L1ICacheLines	1024
`define L1ICacheWays 4

`define L1DCacheWays 4

parameter SUPPORT_PGREL	= 1'b0;	// Page relative branching
parameter SUPPORT_REP = 1'b1;
parameter REP_BIT = 31;

parameter QENTRIES = 8;

// Uncomment to have page relative branches.
//`define PGREL 1

parameter  NLANES = `NLANES;
// The following thread count carefully choosen.
// It cannot be over 13 as that makes the vector register file too big for
// synthesis to handle.
parameter NTHREADS = `NTHREADS;
parameter NREGS = `NREGS;

parameter pL1CacheLines = `L1CacheLines;
parameter pL1LineSize = `L1CacheLineSize;
parameter pL1ICacheLines = `L1CacheLines;
// The following arrived at as 512+32 bits for word at end of cache line, plus
// 40 bits for a possible constant postfix
parameter pL1ICacheLineSize = `L1ICacheLineSize;
parameter pL1Imsb = $clog2(`L1ICacheLines-1)-1+6;
parameter pL1ICacheWays = `L1ICacheWays;
parameter pL1DCacheWays = `L1DCacheWays;
parameter TidMSB = $clog2(`NTHREADS)-1;

parameter AREGS = `NREGS;
parameter REGFILE_LATENCY = 2;
parameter INSN_LEN = 8'd5;
parameter NDATA_PORTS = 2;

parameter RAS_DEPTH	= 4;

//
// define PANIC types
//
parameter PANIC_NONE		= 4'd0;
parameter PANIC_FETCHBUFBEQ	= 4'd1;
parameter PANIC_INVALIDISLOT	= 4'd2;
parameter PANIC_MEMORYRACE	= 4'd3;
parameter PANIC_IDENTICALDRAMS	= 4'd4;
parameter PANIC_OVERRUN		 = 4'd5;
parameter PANIC_HALTINSTRUCTION	= 4'd6;
parameter PANIC_INVALIDMEMOP	= 4'd7;
parameter PANIC_INVALIDFBSTATE = 4'd8;
parameter PANIC_INVALIDIQSTATE = 4'd9;
parameter PANIC_BRANCHBACK = 4'd10;
parameter PANIC_BADTARGETID	 = 4'd12;


typedef logic [$clog2(QENTRIES)-1:0] que_ndx_t;
typedef logic [NREGS-1:1] reg_bitmask_t;

typedef enum logic [3:0] {
	ST_RST = 4'd0,
	ST_RUN = 4'd1,
	ST_INVALL1 = 4'd7,
	ST_INVALL2 = 4'd8,
	ST_INVALL3 = 4'd9,
	ST_INVALL4 = 4'd10,
	ST_UPD1 = 4'd11,
	ST_UPD2 = 4'd12,
	ST_UPD3 = 4'd13
} tlb_state_t;

typedef enum logic [6:0] {
	OP_SYS			= 7'd00,
	OP_R2				= 7'd02,
	OP_SLTI			= 7'd03,
	OP_ADDI			= 7'd04,
	OP_SUBFI		= 7'd05,
	OP_MULI			= 7'd06,
	OP_CSR			= 7'd07,
	OP_ANDI			= 7'd08,
	OP_ORI			= 7'd09,
	OP_EORI			= 7'd10,
	OP_CMPI			= 7'd11,
	OP_DIVI			= 7'd13,
	OP_MULUI		= 7'd14,
	OP_MOV			= 7'd15,
	OP_CLR			= 7'd16,
	OP_SET			= 7'd17,
	OP_EXTU			= 7'd18,
	OP_EXT			= 7'd19,
	OP_COM			= 7'd20,
	OP_DIVUI		= 7'd21,
	OP_DEP			= 7'd23,
	/* 24 to 31 empty
	*/
	OP_DBcc			= 7'd29,
	OP_RTD			= 7'd35,
	OP_JSR			= 7'd36,
	OP_BEQ			= 7'd38,
	OP_BNE			= 7'd39,
	OP_BLT			= 7'd40,
	OP_BGE			= 7'd41,
	OP_BLE			= 7'd42,
	OP_BGT			= 7'd43,
	OP_BBC			= 7'd44,
	OP_BBS			= 7'd45,
	OP_LDB			= 7'd64,
	OP_LDBU			= 7'd65,
	OP_LDW			= 7'd66,
	OP_LDWU			= 7'd67,
	OP_LDT			= 7'd68,
	OP_LDTU			= 7'd69,
	OP_LDO			= 7'd70,
	OP_LDA			= 7'd74,
	OP_CACHE		= 7'd75,
	OP_LDX			= 7'd79,	
	OP_STB			= 7'd80,
	OP_STW			= 7'd81,
	OP_STT			= 7'd82,
	OP_STO			= 7'd83,
	OP_STX			= 7'd87,
	OP_ADDIPC		= 7'd96,
	OP_PRED			= 7'd121,
	OP_ATOM			= 7'd122,
	OP_PFX			= 7'd124,
	OP_NOP			= 7'd127
} opcode_t;
/*
typedef enum logic [2:0] {
	OP_CLR = 3'd0,
	OP_SET = 3'd1,
	OP_COM = 3'd2,
	OP_SBX = 3'd3,
	OP_EXTU = 3'd4,
	OP_EXTS = 3'd5,
	OP_DEP = 3'd6,
	OP_FFO = 3'd7
} bitfld_t;
*/
typedef enum logic [3:0] {
	OP_CMP_EQ	= 4'h0,
	OP_CMP_NE	= 4'd1,
	OP_CMP_LT	= 4'd2,
	OP_CMP_LE	= 4'd3,
	OP_CMP_GE	= 4'd4,
	OP_CMP_GT	= 4'd5,
	OP_CMP_LTU	= 4'd10,
	OP_CMP_LEU	= 4'd11,
	OP_CMP_GEU	= 4'd12,
	OP_CMP_GTU= 4'd13
} cmp_t;

typedef enum logic [1:0] {
	CM_INT = 2'd0,
	CM_POSIT = 2'd1,
	CM_FLOAT = 2'd2,
	CM_DECFLOAT = 2'd3
} branch_cm_t;

typedef enum logic [3:0] {
	EQ = 4'd0,
	NE = 4'd1,
	LT = 4'd2,
	LE = 4'd3,
	GE = 4'd4,
	GT = 4'd5,
	BC = 4'd6,
	BS = 4'd7,
	
	BCI = 4'd8,
	BSI = 4'd9,
	LO = 4'd10,
	LS = 4'd11,
	HS = 4'd12,
	HI = 4'd13,
	
	RA = 4'd14,
	SR = 4'd15
} branch_cnd_t;

typedef enum logic [3:0] {
	FEQ = 4'd0,
	FNE = 4'd1,
	FGT = 4'd2,
	FGE = 4'd3,
	FLT = 4'd4,
	FLE = 4'd5,
	FORD = 4'd6,
	FUN = 4'd7
} fbranch_cnd_t;

// R2 ops
typedef enum logic [6:0] {
	FN_AND			= 7'd00,
	FN_OR				= 7'd01,
	FN_EOR			= 7'd02,
	FN_CMP			= 7'd03,
	FN_ADD			= 7'd04,
	FN_SUB			= 7'd05,
	FN_NAND			= 7'd08,
	FN_NOR			= 7'd09,
	FN_ENOR			= 7'd10,
	FN_ANDC			= 7'd11,
	FN_ORC			= 7'd12,
	FN_MUL			= 7'd16,
	FN_DIV			= 7'd17,
	FN_MULU			= 7'd19,
	FN_DIVU			= 7'd20,
	FN_MULSU		= 7'd21,
	FN_DIVSU		= 7'd22,
	FN_MULH			= 7'd24,
	FN_MOD			= 7'd25,
	FN_MULUH		= 7'd27,
	FN_MODU			= 7'd28,
	FN_MULSUH		= 7'd29,
	FN_MODSU		= 7'd30,
	FN_SEQ			= 7'd80,
	FN_SNE			= 7'd81,
	FN_SLT			= 7'd82,
	FN_SLE			= 7'd83,
	FN_SLTU			= 7'd84,
	FN_SLEU			= 7'd85
} r2func_t;

typedef enum logic [5:0] {
	FN_LDBX = 6'd0,
	FN_LDBUX = 6'd1,
	FN_LDWX = 6'd2,
	FN_LDWUX = 6'd3,
	FN_LDTX = 6'd4,
	FN_LDTUX = 6'd5,
	FN_LDOX = 6'd6
} ldn_func_t;

typedef enum logic [5:0] {
	FN_STBX = 6'd0,
	FN_STWX = 6'd2,
	FN_STTX = 6'd4,
	FN_STOX = 6'd6
} stn_func_t;

typedef union packed {
	ldn_func_t ldn;
	stn_func_t stn;
} lsn_func_t;

typedef enum logic [6:0]
{
	FN_BRK = 7'd0,
	FN_IRQ = 7'd1,
	FN_SYS = 7'd2,
	FN_RTS = 7'd3,
	FN_RTI = 7'd4
} sys_func_t;

// R1 ops
typedef enum logic [5:0] {
	OP_RTI			= 6'h19,
	OP_REX			= 6'h1A,
	OP_FFINITE 	= 6'h20,
	OP_FNEG			= 6'h23,
	OP_FRSQRTE	= 6'h24,
	OP_FRES			= 6'h25,
	OP_FSIGMOID	= 6'h26,
	OP_I2F			= 6'h28,
	OP_F2I			= 6'h29,
	OP_FABS			= 6'h2A,
	OP_FNABS		= 6'h2B,
	OP_FCLASS		= 6'h2C,
	OP_FMAN			= 6'h2D,
	OP_FSIGN		= 6'h2E,
	OP_FTRUNC		= 6'h2F,
	OP_SEXTB		= 6'h38,
	OP_SEXTW		= 6'h39
} r1func_t;

typedef enum logic [6:0] {
	OP_FSCALEB = 7'd0,
	OP_FMIN = 7'd1,
	OP_FMAX = 7'd3,
	OP_FADD = 7'd4,
	OP_FCMP = 7'd5,
	OP_FMUL = 7'd6,
	OP_FDIV = 7'd7,
	OP_FNXT = 7'd14,
	OP_FREM = 7'd15
} f2func_t;

typedef enum logic [5:0] {
	OP_ASL 	= 6'd0,
	OP_ASR	= 6'd1,
	OP_LSL	= 6'd2,
	OP_LSR	= 6'd3,	
	OP_ROL	= 6'd4,
	OP_ROR	= 6'd5,
	OP_ZXB	= 6'd8,
	OP_SXB	= 6'd9,
	OP_ASLI	= 6'd32,
	OP_ASRI	= 6'd33,
	OP_LSLI	= 6'd34,
	OP_LSRI	= 6'd35,
	OP_ROLI	= 6'd36,
	OP_RORI	= 6'd37,
	OP_ZXBI	= 6'd40,
	OP_SXBI	= 6'd41
} shift_t;

typedef enum logic [2:0] {
	PRC8 = 3'd0,
	PRC16 = 3'd1,
	PRC32 = 3'd2,
	PRC64 = 3'd3,
	PRC128 = 3'd4,
	PRC512 = 3'd6,
	PRCNDX = 3'd7
} prec_t;

parameter NOP_INSN	= {32'd0,3'd4,OP_PFX};

typedef enum logic [4:0] {
	MR_NOP = 5'd0,
	MR_LOAD = 5'd1,
	MR_LOADZ = 5'd2,
	MR_STORE = 5'd3,
	MR_STOREPTR = 5'd4,
//	MR_TLBRD = 5'd4,
//	MR_TLBRW = 5'd5,
	MR_TLB = 5'd6,
	MR_LEA = 5'd7,
	MR_MOVLD = 5'd8,
	MR_MOVST = 5'd9,
	MR_RGN = 5'd10,
	MR_ICACHE_LOAD = 5'd11,
	MR_PTG = 5'd12,
	MR_CACHE = 5'd13,
	MR_ADD = 5'd16,
	MR_AND = 5'd17,
	MR_OR	= 5'd18,
	MR_EOR = 5'd19,
	MR_ASL = 5'd20,
	MR_LSR = 5'd21,
	MR_MIN = 5'd22,
	MR_MAX = 5'd23,
	MR_CAS = 5'd24
} memop_t;

parameter CSR_IE		= 16'h?004;
parameter CSR_CAUSE	= 16'h?006;
parameter CSR_REPBUF = 16'h0008;
parameter CSR_SEMA	= 16'h?00C;
parameter CSR_PTBR	= 16'h1003;
parameter CSR_HMASK	= 16'h1005;
parameter CSR_FSTAT	= 16'h?014;
parameter CSR_ASID	= 16'h101F;
parameter CSR_KEYS	= 16'b00010000001000??;
parameter CSR_KEYTBL= 16'h1024;
parameter CSR_SCRATCH=16'h?041;
parameter CSR_MCR0	= 16'h3000;
parameter CSR_MHARTID = 16'h3001;
parameter CSR_TICK	= 16'h3002;
parameter CSR_MBADADDR	= 16'h3007;
parameter CSR_MTVEC = 16'b00110000001100??;
parameter CSR_MDBAD	= 16'b00110000000110??;
parameter CSR_MDBAM	= 16'b00110000000111??;
parameter CSR_MDBCR	= 16'h3020;
parameter CSR_MDBSR	= 16'h3021;
parameter CSR_MPLSTACK	= 16'h303F;
parameter CSR_MPMSTACK	= 16'h3040;
parameter CSR_MSTUFF0	= 16'h3042;
parameter CSR_MSTUFF1	= 16'h3043;
parameter CSR_USTATUS	= 16'h0044;
parameter CSR_SSTATUS	= 16'h1044;
parameter CSR_HSTATUS	= 16'h2044;
parameter CSR_MSTATUS	= 16'h3044;
parameter CSR_MVSTEP= 16'h3046;
parameter CSR_MVTMP	= 16'h3047;
parameter CSR_MEIP	=	16'h3048;
parameter CSR_MECS	= 16'h3049;
parameter CSR_MPCS	= 16'h304A;
parameter CSR_UCA		=	16'b00000001000?????;
parameter CSR_SCA		=	16'b00010001000?????;
parameter CSR_HCA		=	16'b00100001000?????;
parameter CSR_MCA		=	16'b00110001000?????;
parameter CSR_MSEL	= 16'b0011010000100???;
parameter CSR_MTCBPTR=16'h3050;
parameter CSR_MGDT	= 16'h3051;
parameter CSR_MLDT	= 16'h3052;
parameter CSR_MTCB	= 16'h3054;
parameter CSR_MBVEC	= 16'b0011000001011???;
parameter CSR_MSP		= 16'h3060;
parameter CSR_TIME	= 16'h?FE0;
parameter CSR_MTIME	= 16'h3FE0;
parameter CSR_MTIMECMP	= 16'h3FE1;

typedef enum logic [2:0] {
	csrRead = 3'd0,
	csrWrite = 3'd1,
	csrAndNot = 3'd2,
	csrOr = 3'd3,
	csrEor = 3'd4
} csrop_t;

typedef enum logic [11:0] {
	FLT_NONE	= 12'h000,
	FLT_EXV		= 12'h002,
	FLT_TLBMISS = 12'h04,
	FLT_DCM		= 12'h005,
	FLT_CANARY= 12'h00B,
	FLT_SSM		= 12'h020,
	FLT_DBG		= 12'h021,
	FLT_IADR	= 12'h022,
	FLT_CHK		= 12'h027,
	FLT_DBZ		= 12'h028,
	FLT_OFL		= 12'h029,
	FLT_ALN		= 12'h030,
	FLT_KEY		= 12'h031,
	FLT_WRV		= 12'h032,
	FLT_RDV		= 12'h033,
	FLT_SGB		= 12'h034,
	FLT_PRIV	= 12'h035,
	FLT_WD		= 12'h036,
	FLT_UNIMP	= 12'h037,
	FLT_CPF		= 12'h039,
	FLT_DPF		= 12'h03A,
	FLT_LVL		= 12'h03B,
	FLT_PMA		= 12'h03D,
	FLT_BRK		= 12'h03F,
	FLT_TBL		= 12'h041,
	FLT_PFX		= 12'h0C8,
	FLT_TMR		= 12'h0E2,
	FLT_CSR		= 12'h0EC,
	FLT_RTI		= 12'h0ED,
	FLT_IRQ		= 12'h8EE,
	FLT_NMI		= 12'h8FE
} cause_code_t;

typedef enum logic [1:0] {
	OM_APP = 2'd0,
	OM_SUPERVISOR = 2'd1,
	OM_HYPERVISOR = 2'd2,
	OM_MACHINE = 2'd3
} operating_mode_t;

typedef enum logic [3:0] {
	nul = 4'd0,
	byt = 4'd1,
	wyde = 4'd2,
	tetra = 4'd3,
	penta = 4'd4,
	octa = 4'd5,
	hexi = 4'd6,
	dodeca = 4'd7,
	char = 4'd8,
	vect = 4'd10
} memsz_t;

typedef enum logic [1:0] {
	non = 2'd0,
	postinc = 2'd1,
	predec = 2'd2,
	memi = 2'd3
} addr_upd_t;

typedef logic [TidMSB:0] Tid;
typedef logic [TidMSB:0] tid_t;
typedef logic [11:0] order_tag_t;
typedef logic [11:0] ASID;
typedef logic [11:0] asid_t;
typedef logic [31:0] address_t;
typedef logic [31:0] virtual_address_t;
typedef logic [47:0] physical_address_t;
typedef logic [31:0] code_address_t;
typedef logic [63:0] value_t;
typedef struct packed {
	value_t H;
	value_t L;
} double_value_t;
typedef logic [31:0] half_value_t;
typedef logic [255:0] quad_value_t;
typedef logic [511:0] octa_value_t;
typedef logic [5:0] Func;
typedef logic [127:0] regs_bitmap_t;

typedef struct packed
{
	logic [5:0] num;
} regspec_t;

typedef struct packed
{
	logic [7:0] pl;			// privilege level
	logic [6:0] resv3;
	logic mprv;					// memory access priv indicator	
	logic [1:0] resv2;
	logic [1:0] ptrsz;	// pointer size 0=32,1=64,2=96
	operating_mode_t om;	// operating mode
	logic trace_en;			// instruction trace enable
	logic ssm;					// single step mode
	logic [2:0] ipl;		// interrupt privilege level
	logic die;					// debug interrupt enable
	logic mie;					// machine interrupt enable
	logic hie;					// hypervisor interrupt enable
	logic sie;					// supervisor interrupt enable
	logic uie;					// user interrupt enable
} status_reg_t;				// 32 bits

// Instruction types, makes decoding easier

typedef struct packed
{
	logic [31:0] imm;
	logic resv;
	opcode_t opcode;
} postfix_t;


typedef struct packed
{
	logic [32:0] payload;
	opcode_t opcode;
} anyinst_t;


typedef struct packed
{
	logic [2:0] fmt;
	logic [2:0] pr;
	f2func_t func;
	logic [1:0] im;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} f2inst_t;

typedef struct packed
{
	logic [2:0] fmt;
	logic [2:0] pr;
	r2func_t func;
	logic [1:0] im;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} r2inst_t;

typedef struct packed
{
	logic [2:0] fmt;
	logic [2:0] pr;
	sys_func_t func;
	logic [1:0] im;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} sys_inst_t;

typedef struct packed
{
	logic [1:0] fmt;
	logic [2:0] pr;
	logic [15:0] imm;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} imminst_t;

typedef struct packed
{
	logic [2:0] fmt;
	logic [2:0] pr;
	logic b;
	logic im;
	logic [5:0] resv;
	logic [6:0] imm;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} shiftiinst_t;

typedef struct packed
{
	logic [1:0] fmt;
	logic [2:0] pr;
	logic [1:0] op;
	logic [13:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} csrinst_t;

typedef struct packed
{
	logic [1:0] fmt;
	logic [2:0] pr;
	logic [11:0] disp;
	logic [1:0] pi;
	logic [1:0] ca;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} lsinst_t;

typedef struct packed
{
	logic [1:0] fmt;
	logic [2:0] pr;
	lsn_func_t func;
	logic [1:0] ca;
	logic d;
	logic sc;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} lsninst_t;

typedef struct packed
{
	logic [14:0] disphi;
	regspec_t Rb;
	regspec_t	Ra;
	logic [1:0] displo;
	logic op;
	branch_cm_t cm;
	logic lk;
	opcode_t opcode;
} brinst_t;

typedef struct packed
{
	logic [1:0] fmt;
	logic [2:0] pr;
	logic [15:0] immhi;
	regspec_t Ra;
	logic [3:0] immlo;
	logic [1:0] lk;
	opcode_t opcode;
} jsrinst_t;

typedef union packed
{
	sys_inst_t sys;
	f2inst_t	f2;
	r2inst_t	r2;
	brinst_t	br;
	jsrinst_t	jsr;
	jsrinst_t	jmp;
	imminst_t	imm;
	imminst_t	ri;
	shiftiinst_t shifti;
	csrinst_t	csr;
	lsinst_t	ls;
	lsninst_t	lsn;
	postfix_t	pfx;
	anyinst_t any;
} instruction_t;

typedef struct packed {
	address_t adr;
	logic [3:0] resv2;
	logic v;
	logic [2:0] icnt;
	logic [REP_BIT:0] imm;
	logic resv;
	logic [15:9] ins;
} rep_buffer_t;

typedef struct packed
{
	tid_t thread;
	logic v;
	order_tag_t tag;
	address_t pc;
	instruction_t insn;
	postfix_t pfx;
	postfix_t pfx2;
	postfix_t pfx3;
//	postfix_t pfx4;
	cause_code_t cause;
	logic [2:0] sp_sel;
} instruction_fetchbuf_t;

typedef struct packed
{
	logic v;
	regspec_t Ra;
	regspec_t Rb;
	regspec_t Rc;
	regspec_t Rm;
	regspec_t Rt;
	logic Ta;
	logic Tb;
	logic Tt;
	logic hasRa;
	logic hasRb;
	logic hasRc;
	logic hasRm;
	logic hasRt;
	logic Rtsrc;	// Rt is a source register
	quad_value_t imm;
	prec_t prc;
	logic rfwr;
	logic vrfwr;
	logic csr;
	logic csrrd;
	logic csrrw;
	logic csrrs;
	logic csrrc;
	logic is_vector;
	logic multicycle;
	logic mem;
	logic loadr;
	logic loadn;
	logic load;
	logic loadu;
	logic ldsr;
	logic storer;
	logic storen;
	logic store;
	logic stcr;
	logic need_steps;
	logic compress;
	memsz_t memsz;
	logic br;						// conditional branch
	logic cjb;					// call, jmp, or bra
	logic brk;
	logic irq;
	logic rti;
	logic flt;
	logic rex;
	logic pfx;
	logic popq;
} decode_bus_t;

typedef struct packed
{
	logic v;
	logic regfetched;
	logic out;
	logic agen;
	logic executed;
	logic memory;
	logic imiss;
	tid_t thread;
	instruction_fetchbuf_t ifb;
	decode_bus_t	dec;
	logic [3:0] count;
	logic [3:0] step;
	logic [2:0] retry;		// retry count
	cause_code_t cause;
	address_t badAddr;
	quad_value_t a;
	quad_value_t b;
	quad_value_t c;
	quad_value_t t;
	value_t mask;
	quad_value_t res;
} pipeline_reg_t;

typedef struct packed {
	logic [4:0] imiss;
	logic sleep;
	address_t pc;				// current instruction pointer
	address_t miss_pc;	// I$ miss address
} ThreadInfo_t;

typedef struct packed {
	logic loaded;						// 1=loaded internally
	logic stored;						// 1=stored externally
	address_t pc;						// return address
	address_t sp;						// Stack pointer location
} return_stack_t;

// No unsigned codes!
parameter MR_LDB	= 4'd0;
parameter MR_LDW	= 4'd1;
parameter MR_LDT	= 4'd2;
parameter MR_LDO	= 4'd3;
parameter MR_LDH 	= 4'd4;
parameter MR_LDP	= 4'd5;
parameter MR_LDN	= 4'd6;
parameter MR_LDSR	= 4'd7;
parameter MR_LDV	= 4'd9;
parameter MR_LDG	= 4'd10;
parameter MR_LDPTG = 4'd0;
parameter MR_STPTG = 4'd1;
parameter MR_RAS 	= 4'd12;
parameter MR_STB	= 4'd0;
parameter MR_STW	= 4'd1;
parameter MR_STT	= 4'd2;
parameter MR_STO	= 4'd3;
parameter MR_STH	= 4'd4;
parameter MR_STP 	= 4'd5;
parameter MR_STN	= 4'd6;
parameter MR_STCR	= 4'd7;
parameter MR_STPTR	= 4'd9;

// All the fields in this structure are *output* back to the system.
typedef struct packed
{
	logic [7:0] tid;		// tran id
	order_tag_t tag;
	tid_t thread;
	logic [1:0] omode;	// operating mode
	code_address_t ip;			// Debugging aid
	logic [5:0] step;		// vector step number
	logic [5:0] count;	// vector operation count
	logic wr;						// fifo write control
	memop_t func;				// operation to perform
	logic [3:0] func2;	// more resolution to function
	logic load;					// needed to place results
	logic store;
	logic group;
	logic need_steps;
	logic v;
	logic empty;
	cause_code_t cause;
	logic [3:0] cache_type;
	logic [63:0] sel;		// +16 for unaligned accesses
	asid_t asid;
	address_t adr;
	code_address_t vcadr;		// victim cache address
	logic dchit;
	logic cmt;
	memsz_t sz;					// indicates size of data
	logic [7:0] bytcnt;	// byte count of data to load/store
	logic [1:0] hit;
	logic [1:0] mod;		// line modified indicators
	logic [3:0] acr;		// acr bits from TLB lookup
	logic tlb_access;
	logic ptgram_en;
	logic rgn_en;
	logic pde_en;
	logic pmtram_ena;
	logic wr_tgt;
	regspec_t tgt;				// target register
	logic [511:0] res;		// stores unaligned data as well (must be last field)
} memory_arg_t;		//

// The full pipeline structure is not needed for writeback. The writeback fifos
// can be made smaller using a smaller structure.
// Ah, but it appears that writeback needs some of the instruction buffer.
// To support a few instructions like RTI and REX.
/*
typedef struct packed
{
	logic v;
	order_tag_t tag;
	cause_code_t cause;		// cause code
	code_address_t ip;		// address of instruction
	address_t adr;					// bad load/store address
	logic [5:0] step;			// vector step number
	logic [1023:0] res;		// instruction results
	logic wr_tgt;					// target register needs updating
	regspec_t tgt;				// target register
} writeback_info_t;
*/

const address_t RSTPC	= 32'hFFFD0000;

typedef struct packed {
	logic v;
	logic out;
	logic done;
	logic bt;
	logic agen;
	logic fc;
	logic alu;
	logic mul;
	logic mulu;
	logic div;
	logic divu;
	logic load;
	logic store;
	logic mem;
	logic sync;
	logic jmp;
	logic imm;
	logic rfw;
	value_t res;
	instruction_t op;
	cause_code_t exc;
	regspec_t tgt;
	logic [33:0] a0;
	value_t a1;
	logic a1_v;
	logic [4:0] a1_s;
	value_t a2;
	logic a2_v;
	logic [4:0] a2_s;
	value_t a3;
	logic a3_v;
	logic [4:0] a3_s;
	value_t at;
	logic at_v;
	logic [4:0] at_s;
	value_t ap;
	logic ap_v;
	logic [4:0] ap_s;
	address_t pc;
} iq_entry_t;

function fnIsBccR;
input instruction_t ir;
begin
	fnIsBccR = fnIsBranch(ir) && ir[10]==1'b1;
end
endfunction

function fnIsBranch;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS:
		fnIsBranch = 1'b1;
	default:
		fnIsBranch = 1'b0;
	endcase
end
endfunction

function fnBranchDispSign;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS:
		fnBranchDispSign = ir[39];
	default:	fnBranchDispSign = 1'b0;
	endcase	
end
endfunction

function [63:0] fnBranchDisp;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS:
		fnBranchDisp = {{47{ir[39]}},ir[39:25],ir[12:11]};
	default:	fnBranchDisp = 'd0;
	endcase
end
endfunction

function fnIsBackBranch;
input instruction_t ir;
begin
	fnIsBackBranch = fnIsBranch(ir) && fnBranchDispSign(ir);
end
endfunction

function fnIsCall;
input instruction_t ir;
begin
	fnIsCall = ir.any.opcode==OP_JSR;
end
endfunction

function fnIsFlowCtrl;
input instruction_t ir;
begin
	fnIsFlowCtrl = 1'b0;
	case(ir.any.opcode)
	OP_SYS:	fnIsFlowCtrl = 1'b1;
	OP_JSR:
		fnIsFlowCtrl = 1'b1;
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS:
		fnIsFlowCtrl = 1'b1;	
	OP_RTD:
		fnIsFlowCtrl = 1'b1;	
	default:
		fnIsFlowCtrl = 1'b0;
	endcase
end
endfunction

function fnIsRet;
input instruction_t ir;
begin
	fnIsRet = 1'b0;
	case(ir.any.opcode)
	OP_RTD:
		fnIsRet = 1'b1;	
	default:
		fnIsRet = 1'b0;
	endcase
end
endfunction

function [5:0] fnRa;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS:
		fnRa = ir[18:13];
	OP_RTD:
		fnRa = 6'd63;
	default:
		fnRa = ir[18:13];
	endcase
end
endfunction

function [5:0] fnRb;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS:
		fnRb = ir[24:19];
	default:
		fnRb = ir[24:19];
	endcase
end
endfunction

function [5:0] fnRc;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_RTD:
		fnRc = 6'd56 + ir[7:6];
	OP_STB,OP_STW,OP_STT,OP_STO,OP_STX:
		fnRc = ir[12:7];
	default:
		fnRc = 'd0;
	endcase
end
endfunction

function [5:0] fnRt;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnRt = ir[12:7];
		FN_CMP:	fnRt = ir[12:7];
		FN_MUL:	fnRt = ir[12:7];
		FN_DIV:	fnRt = ir[12:7];
		FN_SUB:	fnRt = ir[12:7];
		FN_MULU: fnRt = ir[12:7];
		FN_DIVU:	fnRt = ir[12:7];
		FN_MULH:	fnRt = ir[12:7];
		FN_MOD:	fnRt = ir[12:7];
		FN_MULUH:	fnRt = ir[12:7];
		FN_MODU:	fnRt = ir[12:7];
		FN_AND:	fnRt = ir[12:7];
		FN_OR:	fnRt = ir[12:7];
		FN_EOR:	fnRt = ir[12:7];
		FN_ANDC:	fnRt = ir[12:7];
		FN_NAND:	fnRt = ir[12:7];
		FN_NOR:	fnRt = ir[12:7];
		FN_ENOR:	fnRt = ir[12:7];
		FN_ORC:	fnRt = ir[12:7];
		FN_SEQ:	fnRt = ir[12:7];
		FN_SNE:	fnRt = ir[12:7];
		FN_SLT:	fnRt = ir[12:7];
		FN_SLE:	fnRt = ir[12:7];
		FN_SLTU:	fnRt = ir[12:7];
		FN_SLEU:	fnRt = ir[12:7];
		default:	fnRt = 'd0;
		endcase
	OP_JSR:	fnRt = 6'd56 + ir[7:6];
	OP_RTD:	fnRt = 6'd63;
	OP_JSR,
	OP_ADDI,OP_SUBFI,OP_CMPI,OP_MULI,OP_DIVI,OP_SLTI,
	OP_MULUI,OP_DIVUI,
	OP_ANDI,OP_ORI,OP_EORI:
		fnRt = ir[12:7];
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,
	OP_LDX:
		fnRt = ir[12:7];
	OP_ADDIPC:
		fnRt = ir[12:7];
	default:
		fnRt = 'd0;
	endcase
end
endfunction

function [5:0] fnRp;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnRp = {3'b100,ir[36:34]};
		FN_CMP:	fnRp = {3'b100,ir[36:34]};
		FN_MUL:	fnRp = {3'b100,ir[36:34]};
		FN_DIV:	fnRp = {3'b100,ir[36:34]};
		FN_SUB:	fnRp = {3'b100,ir[36:34]};
		FN_MULU: fnRp = {3'b100,ir[36:34]};
		FN_DIVU:	fnRp = {3'b100,ir[36:34]};
		FN_MULH:	fnRp = {3'b100,ir[36:34]};
		FN_MOD:	fnRp = {3'b100,ir[36:34]};
		FN_MULUH:	fnRp = {3'b100,ir[36:34]};
		FN_MODU:	fnRp = {3'b100,ir[36:34]};
		FN_AND:	fnRp = {3'b100,ir[36:34]};
		FN_OR:	fnRp = {3'b100,ir[36:34]};
		FN_EOR:	fnRp = {3'b100,ir[36:34]};
		FN_ANDC:	fnRp = {3'b100,ir[36:34]};
		FN_NAND:	fnRp = {3'b100,ir[36:34]};
		FN_NOR:	fnRp = {3'b100,ir[36:34]};
		FN_ENOR:	fnRp = {3'b100,ir[36:34]};
		FN_ORC:	fnRp = {3'b100,ir[36:34]};
		FN_SEQ:	fnRp = {3'b100,ir[36:34]};
		FN_SNE:	fnRp = {3'b100,ir[36:34]};
		FN_SLT:	fnRp = {3'b100,ir[36:34]};
		FN_SLE:	fnRp = {3'b100,ir[36:34]};
		FN_SLTU:	fnRp = {3'b100,ir[36:34]};
		FN_SLEU:	fnRp = {3'b100,ir[36:34]};
		default:	fnRp = 6'd46;
		endcase
	OP_JSR:	fnRp = {3'b100,ir[37:35]};
	OP_RTD:	fnRp = {3'b100,ir[37:35]};
	OP_JSR,
	OP_ADDI,OP_SUBFI,OP_CMPI,OP_MULI,OP_DIVI,OP_SLTI,
	OP_MULUI,OP_DIVUI,
	OP_ANDI,OP_ORI,OP_EORI:
		fnRp = {3'b100,ir[37:35]};
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,
	OP_LDX:
		fnRp = {3'b100,ir[37:35]};
	OP_ADDIPC:
		fnRp = {3'b100,ir[37:35]};
	default:
		fnRp = 6'd46;
	endcase
end
endfunction

//
// 1 if the the operand is automatically valid, 
// 0 if we need a RF value
function fnSource1v;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_SYS:	fnSource1v = 1'b1;
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnSource1v = ir[18:13]=='d0;
		FN_CMP:	fnSource1v = ir[18:13]=='d0;
		FN_MUL:	fnSource1v = ir[18:13]=='d0;
		FN_DIV:	fnSource1v = ir[18:13]=='d0;
		FN_SUB:	fnSource1v = ir[18:13]=='d0;
		FN_MULU: fnSource1v = ir[18:13]=='d0;
		FN_DIVU:	fnSource1v = ir[18:13]=='d0;
		FN_AND:	fnSource1v = ir[18:13]=='d0;
		FN_OR:	fnSource1v = ir[18:13]=='d0;
		FN_EOR:	fnSource1v = ir[18:13]=='d0;
		FN_ANDC:	fnSource1v = ir[18:13]=='d0;
		FN_NAND:	fnSource1v = ir[18:13]=='d0;
		FN_NOR:	fnSource1v = ir[18:13]=='d0;
		FN_ENOR:	fnSource1v = ir[18:13]=='d0;
		FN_ORC:	fnSource1v = ir[18:13]=='d0;
		FN_SEQ:	fnSource1v = ir[18:13]=='d0;
		FN_SNE:	fnSource1v = ir[18:13]=='d0;
		FN_SLT:	fnSource1v = ir[18:13]=='d0;
		FN_SLE:	fnSource1v = ir[18:13]=='d0;
		FN_SLTU:	fnSource1v = ir[18:13]=='d0;
		FN_SLEU:	fnSource1v = ir[18:13]=='d0;
		default:	fnSource1v = 1'b1;
		endcase
	OP_JSR,
	OP_ADDI:	fnSource1v = ir[18:13]=='d0;
	OP_CMPI:	fnSource1v = ir[18:13]=='d0;
	OP_MULI:	fnSource1v = ir[18:13]=='d0;
	OP_DIVI:	fnSource1v = ir[18:13]=='d0;
	OP_ANDI:	fnSource1v = ir[18:13]=='d0;
	OP_ORI:		fnSource1v = ir[18:13]=='d0;
	OP_EORI:	fnSource1v = ir[18:13]=='d0;
	OP_SLTI:	fnSource1v = ir[18:13]=='d0;
	OP_BEQ:		fnSource1v = ir[18:13]=='d0;
	OP_BNE:		fnSource1v = ir[18:13]=='d0;
	OP_BLT:		fnSource1v = ir[18:13]=='d0;
	OP_BLE:		fnSource1v = ir[18:13]=='d0;
	OP_BGT:		fnSource1v = ir[18:13]=='d0;
	OP_BGE:		fnSource1v = ir[18:13]=='d0;
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO:
		fnSource1v = ir[18:13]=='d0;
	OP_LDX:
		fnSource1v = ir[18:13]=='d0;
	OP_STB,OP_STW,OP_STT,OP_STO:
		fnSource1v = ir[18:13]=='d0;
	OP_STX:
		fnSource1v = ir[18:13]=='d0;
	default:	fnSource1v = 1'b1;
	endcase
end
endfunction

function fnSource2v;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_SYS:	fnSource2v = 1'b1;
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnSource2v = ir[24:19]=='d0;
		FN_CMP:	fnSource2v = ir[24:19]=='d0;
		FN_MUL:	fnSource2v = ir[24:19]=='d0;
		FN_DIV:	fnSource2v = ir[24:19]=='d0;
		FN_SUB:	fnSource2v = ir[24:19]=='d0;
		FN_MULU: fnSource2v = ir[24:19]=='d0;
		FN_DIVU: fnSource2v = ir[24:19]=='d0;
		FN_AND:	fnSource2v = ir[24:19]=='d0;
		FN_OR:	fnSource2v = ir[24:19]=='d0;
		FN_EOR:	fnSource2v = ir[24:19]=='d0;
		FN_ANDC:	fnSource2v = ir[24:19]=='d0;
		FN_NAND:	fnSource2v = ir[24:19]=='d0;
		FN_NOR:	fnSource2v = ir[24:19]=='d0;
		FN_ENOR:	fnSource2v = ir[24:19]=='d0;
		FN_ORC:	fnSource2v = ir[24:19]=='d0;
		FN_SEQ:	fnSource2v = ir[24:19]=='d0;
		FN_SNE:	fnSource2v = ir[24:19]=='d0;
		FN_SLT:	fnSource2v = ir[24:19]=='d0;
		FN_SLE:	fnSource2v = ir[24:19]=='d0;
		FN_SLTU:	fnSource2v = ir[24:19]=='d0;
		FN_SLEU:	fnSource2v = ir[24:19]=='d0;
		default:	fnSource2v = 1'b1;
		endcase
	OP_JSR,
	OP_ADDI:	fnSource2v = 1'b1;
	OP_CMPI:	fnSource2v = 1'b1;
	OP_MULI:	fnSource2v = 1'b1;
	OP_DIVI:	fnSource2v = 1'b1;
	OP_ANDI:	fnSource2v = 1'b1;
	OP_ORI:		fnSource2v = 1'b1;
	OP_EORI:	fnSource2v = 1'b1;
	OP_SLTI:	fnSource2v = 1'b1;
	OP_BEQ:		fnSource2v = ir[24:19]=='d0;
	OP_BNE:		fnSource2v = ir[24:19]=='d0;
	OP_BLT:		fnSource2v = ir[24:19]=='d0;
	OP_BLE:		fnSource2v = ir[24:19]=='d0;
	OP_BGT:		fnSource2v = ir[24:19]=='d0;
	OP_BGE:		fnSource2v = ir[24:19]=='d0;
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO:
		fnSource2v = 1'b1;
	OP_LDX:
		fnSource2v = ir[24:19]=='d0;
	OP_STB,OP_STW,OP_STT,OP_STO:
		fnSource2v = 1'b1;
	OP_STX:
		fnSource2v = ir[24:19]=='d0;
	default:	fnSource2v = 1'b1;
	endcase
end
endfunction

function fnSource3v;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_STB,OP_STW,OP_STT,OP_STO,OP_STX:
		fnSource3v = ir[12:7]=='d0;
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS:
		fnSource3v = ir[10] ? ir[30:25]=='d0 : 1'b1;	
	OP_RTD:
		fnSource3v = ir[7:6]=='d0;
	default:
		fnSource3v = 1'b1;
	endcase
end
endfunction

function fnSourceTv;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_SYS:	fnSourceTv = 1'b1;
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnSourceTv = ir[12:7]=='d0;
		FN_CMP:	fnSourceTv = ir[12:7]=='d0;
		FN_MUL:	fnSourceTv = ir[12:7]=='d0;
		FN_DIV:	fnSourceTv = ir[12:7]=='d0;
		FN_SUB:	fnSourceTv = ir[12:7]=='d0;
		FN_MULU: fnSourceTv = ir[12:7]=='d0;
		FN_DIVU: fnSourceTv = ir[12:7]=='d0;
		FN_AND:	fnSourceTv = ir[12:7]=='d0;
		FN_OR:	fnSourceTv = ir[12:7]=='d0;
		FN_EOR:	fnSourceTv = ir[12:7]=='d0;
		FN_ANDC:	fnSourceTv = ir[12:7]=='d0;
		FN_NAND:	fnSourceTv = ir[12:7]=='d0;
		FN_NOR:	fnSourceTv = ir[12:7]=='d0;
		FN_ENOR:	fnSourceTv = ir[12:7]=='d0;
		FN_ORC:	fnSourceTv = ir[12:7]=='d0;
		FN_SEQ:	fnSourceTv = ir[12:7]=='d0;
		FN_SNE:	fnSourceTv = ir[12:7]=='d0;
		FN_SLT:	fnSourceTv = ir[12:7]=='d0;
		FN_SLE:	fnSourceTv = ir[12:7]=='d0;
		FN_SLTU:	fnSourceTv = ir[12:7]=='d0;
		FN_SLEU:	fnSourceTv = ir[12:7]=='d0;
		default:	fnSourceTv = 1'b1;
		endcase
	OP_JSR,
	OP_ADDI:	fnSourceTv = ir[12:7]=='d0;
	OP_CMPI:	fnSourceTv = ir[12:7]=='d0;
	OP_MULI:	fnSourceTv = ir[12:7]=='d0;
	OP_DIVI:	fnSourceTv = ir[12:7]=='d0;
	OP_ANDI:	fnSourceTv = ir[12:7]=='d0;
	OP_ORI:		fnSourceTv = ir[12:7]=='d0;
	OP_EORI:	fnSourceTv = ir[12:7]=='d0;
	OP_SLTI:	fnSourceTv = ir[12:7]=='d0;
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO:
		fnSourceTv = ir[12:7]=='d0;
	OP_LDX:
		fnSourceTv = ir[12:7]=='d0;
	OP_STB,OP_STW,OP_STT,OP_STO,OP_STX:
		fnSourceTv = 1'b1;
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS:
		fnSourceTv = 1'b1;	
	default:
		fnSourceTv = 1'b1;
	endcase
end
endfunction

function fnSourcePv;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_SYS:	fnSourcePv = ~ir.r2.fmt[0];
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnSourcePv = ~ir.r2.fmt[0];
		FN_CMP:	fnSourcePv = ~ir.r2.fmt[0];
		FN_MUL:	fnSourcePv = ~ir.r2.fmt[0];
		FN_DIV:	fnSourcePv = ~ir.r2.fmt[0];
		FN_SUB:	fnSourcePv = ~ir.r2.fmt[0];
		FN_MULU: fnSourcePv = ~ir.r2.fmt[0];
		FN_DIVU: fnSourcePv = ~ir.r2.fmt[0];
		FN_AND:	fnSourcePv = ~ir.r2.fmt[0];
		FN_OR:	fnSourcePv = ~ir.r2.fmt[0];
		FN_EOR:	fnSourcePv = ~ir.r2.fmt[0];
		FN_ANDC:	fnSourcePv = ~ir.r2.fmt[0];
		FN_NAND:	fnSourcePv = ~ir.r2.fmt[0];
		FN_NOR:	fnSourcePv = ~ir.r2.fmt[0];
		FN_ENOR:	fnSourcePv = ~ir.r2.fmt[0];
		FN_ORC:	fnSourcePv = ~ir.r2.fmt[0];
		FN_SEQ:	fnSourcePv = ~ir.r2.fmt[0];
		FN_SNE:	fnSourcePv = ~ir.r2.fmt[0];
		FN_SLT:	fnSourcePv = ~ir.r2.fmt[0];
		FN_SLE:	fnSourcePv = ~ir.r2.fmt[0];
		FN_SLTU:	fnSourcePv = ~ir.r2.fmt[0];
		FN_SLEU:	fnSourcePv = ~ir.r2.fmt[0];
		default:	fnSourcePv = 1'b1;
		endcase
	OP_JSR,
	OP_ADDI:	fnSourcePv = ~ir.ri.fmt[0];
	OP_CMPI:	fnSourcePv = ~ir.ri.fmt[0];
	OP_MULI:	fnSourcePv = ~ir.ri.fmt[0];
	OP_DIVI:	fnSourcePv = ~ir.ri.fmt[0];
	OP_ANDI:	fnSourcePv = ~ir.ri.fmt[0];
	OP_ORI:		fnSourcePv = ~ir.ri.fmt[0];
	OP_EORI:	fnSourcePv = ~ir.ri.fmt[0];
	OP_SLTI:	fnSourcePv = ~ir.ri.fmt[0];
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO:
		fnSourcePv = ~ir.ri.fmt[0];
	OP_LDX:
		fnSourcePv = ~ir.ri.fmt[0];
	OP_STB,OP_STW,OP_STT,OP_STO,OP_STX:
		fnSourcePv = ~ir.ri.fmt[0];
	OP_BEQ,OP_BNE,OP_BLT,OP_BLE,OP_BGE,OP_BGT,OP_BBC,OP_BBS:
		fnSourcePv = 1'b1;
	default:
		fnSourcePv = 1'b1;
	endcase
end
endfunction

function fnIsLoad;
input [18:0] op;
begin
	case(opcode_t'(op[6:0]))
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,
	OP_LDX:
		fnIsLoad = 1'b1;
	default:
		fnIsLoad = 1'b1;
	endcase
end
endfunction

function fnIsStore;
input [18:0] op;
begin
	case(opcode_t'(op[6:0]))
	OP_STB,OP_STW,OP_STT,OP_STO,
	OP_STX:
		fnIsStore = 1'b1;
	default:
		fnIsStore = 1'b0;
	endcase
end
endfunction

function fnIsMem;
input instruction_t ir;
begin
	fnIsMem = fnIsLoad(ir) || fnIsStore(ir);
end
endfunction

function fnIsImm;
input [18:0] op;
begin
	fnIsImm = 1'b0;
	case(opcode_t'(op[6:0]))
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI,OP_DIVUI,OP_MULUI,
	OP_ANDI,OP_ORI,OP_EORI,OP_SLTI:
		fnIsImm = 1'b1;
	OP_RTD:
		fnIsImm = 1'b1;
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDA,OP_CACHE,
	OP_STB,OP_STW,OP_STT,OP_STO:
		fnIsImm = 1'b1;
	OP_ADDIPC:
		fnIsImm = 1'b1;
	default:
		fnIsImm = 1'b0;	
	endcase
end
endfunction

function [63:0] fnImm;
input instruction_t [4:0] ins;
reg [1:0] sz;
begin
	fnImm = 'd0;
	case(ins[0].any.opcode)
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI,OP_SLTI:
		fnImm = {{48{ins[0][34]}},ins[0][34:19]};
	OP_ANDI:	fnImm = {48'hFFFFFFFFFFFF,ins[0][34:19]};
	OP_ORI,OP_EORI:
		fnImm = {48'h0000,ins[0][34:19]};
	OP_RTD:	fnImm = {{16{ins[0][34]}},ins[0][34:19]};
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDA,OP_CACHE,
	OP_STB,OP_STW,OP_STT,OP_STO:
		fnImm = {{52{ins[0][34]}},ins[0][34:23]};
	OP_ADDIPC:
		fnImm = {{42{ins[0][34]}},ins[0][34:13]};
	default:
		fnImm = 'd0;
	endcase
	if (ins[1].any.opcode==OP_PFX) begin
		fnImm = {{32{ins[1][39]}},ins[1][39:8]};
		if (ins[2].any.opcode==OP_PFX)
			fnImm[63:32] = ins[2][39:8];
	end
end
endfunction

function fnImma;
input instruction_t ir;
begin
	fnImma = 1'b0;
	case(ir.any.opcode)
	OP_R2:
		if (&ir.r2.Ra)
			fnImma = 1'b1;
	default:	fnImma = 1'b0;
	endcase
end
endfunction

function fnImmb;
input instruction_t ir;
begin
	fnImmb = 1'b0;
	case(ir.any.opcode)
	OP_R2:
		if (&ir.r2.Rb)
			fnImmb = 1'b1;
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI,OP_SLTI:
		fnImmb = 1'b1;
	OP_RTD:
		fnImmb = 1'b1;
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDA,OP_CACHE,
	OP_STB,OP_STW,OP_STT,OP_STO:
		fnImmb = 1'b1;
	OP_ADDIPC:
		fnImmb = 1'b1;
	default:	fnImmb = 1'b0;
	endcase
end
endfunction

function [5:0] fnInsLen;
input [45:0] ins;
begin
	fnInsLen = 6'd4;
end
endfunction

function fnIsDivs;
input instruction_t ir;
begin
	fnIsDivs = ir.any.opcode==OP_DIVI ||
		(ir.any.opcode==OP_R2 && (ir.r2.func==FN_DIV || ir.r2.func==FN_MOD))
		;
end
endfunction

function fnIsDivu;
input instruction_t ir;
begin
	fnIsDivu = ir.any.opcode==OP_DIVUI ||
		(ir.any.opcode==OP_R2 && (ir.r2.func==FN_DIVU || ir.r2.func==FN_MODU))
		;
end
endfunction

function fnIsMuls;
input instruction_t ir;
begin
	fnIsMuls = ir.any.opcode==OP_MULI ||
		(ir.any.opcode==OP_R2 && (ir.r2.func==FN_MUL || ir.r2.func==FN_MULH))
		;
end
endfunction

function fnIsMulu;
input instruction_t ir;
begin
	fnIsMulu = ir.any.opcode==OP_MULUI ||
		(ir.any.opcode==OP_R2 && (ir.r2.func==FN_MULU || ir.r2.func==FN_MULUH))
		;
end
endfunction

function fnIsDiv;
input instruction_t ir;
begin
	fnIsDiv = fnIsDivs(ir) || fnIsDivu(ir);
end
endfunction

function fnIsIrq;
input instruction_t ir;
begin
	fnIsIrq = ir.any.opcode==OP_SYS && ir.sys.func==FN_IRQ;
end
endfunction

function fnIsAtom;
input instruction_t ir;
begin
	fnIsAtom = ir.any.opcode==OP_ATOM;
end
endfunction

function fnIsPred;
input instruction_t ir;
begin
	fnIsPred = ir.any.opcode==OP_PRED;
end
endfunction

function fnIsPostfix;
input instruction_t ir;
begin
	fnIsPostfix = ir.any.opcode==OP_PFX;
end
endfunction

function [63:0] fnDati;
input instruction_t ins;
input address_t adr;
input value_t dat;
case(ins.any.opcode)
OP_LDB:
  case(adr[2:0])
  3'd0:   fnDati = {{56{dat[7]}},dat[7:0]};
  3'd1:   fnDati = {{56{dat[15]}},dat[15:8]};
  3'd2:   fnDati = {{56{dat[23]}},dat[23:16]};
  3'd3:   fnDati = {{56{dat[31]}},dat[31:24]};
  3'd4:		fnDati = {{56{dat[39]}},dat[39:32]};
  3'd5:		fnDati = {{56{dat[47]}},dat[47:40]};
  3'd6:		fnDati = {{56{dat[55]}},dat[55:48]};
  3'd7:		fnDati = {{56{dat[63]}},dat[63:56]};
  endcase
OP_LDBU:
  case(adr[2:0])
  3'd0:   fnDati = {{56{1'b0}},dat[7:0]};
  3'd1:   fnDati = {{56{1'b0}},dat[15:8]};
  3'd2:   fnDati = {{56{1'b0}},dat[23:16]};
  3'd3:   fnDati = {{56{1'b0}},dat[31:24]};
  3'd4:   fnDati = {{56{1'b0}},dat[39:32]};
  3'd5:   fnDati = {{56{1'b0}},dat[47:40]};
  3'd6:   fnDati = {{56{1'b0}},dat[55:48]};
  3'd7:   fnDati = {{56{1'b0}},dat[63:56]};
  endcase
OP_LDW:
  case(adr[2:1])
  3'd0:   fnDati = {{48{dat[15]}},dat[15:0]};
  3'd1:   fnDati = {{48{dat[31]}},dat[31:16]};
  3'd2:   fnDati = {{48{dat[47]}},dat[47:32]};
  3'd3:   fnDati = {{48{dat[63]}},dat[63:48]};
  endcase
OP_LDWU:
  case(adr[2:1])
  3'd0:   fnDati = {{48{1'b0}},dat[15:0]};
  3'd1:   fnDati = {{48{1'b0}},dat[31:16]};
  3'd2:   fnDati = {{48{1'b0}},dat[47:32]};
  3'd3:   fnDati = {{48{1'b0}},dat[63:48]};
  endcase
OP_LDT:
	case(adr[2])
	1'b0:	fnDati = {{32{dat[31]}},dat[31:0]};
	1'b1:	fnDati = {{32{dat[63]}},dat[63:32]};
	endcase
OP_LDTU:
	case(adr[2])
	1'b0:	fnDati = {{32{1'b0}},dat[31:0]};
	1'b1:	fnDati = {{32{1'b0}},dat[63:32]};
	endcase
OP_LDO:
  fnDati = dat;
OP_LDX:
	case(ins.lsn.func.ldn)
	FN_LDBX:
	  case(adr[2:0])
	  3'd0:   fnDati = {{56{dat[7]}},dat[7:0]};
	  3'd1:   fnDati = {{56{dat[15]}},dat[15:8]};
	  3'd2:   fnDati = {{56{dat[23]}},dat[23:16]};
	  3'd3:   fnDati = {{56{dat[31]}},dat[31:24]};
	  3'd4:		fnDati = {{56{dat[39]}},dat[39:32]};
	  3'd5:		fnDati = {{56{dat[47]}},dat[47:40]};
	  3'd6:		fnDati = {{56{dat[55]}},dat[55:48]};
	  3'd7:		fnDati = {{56{dat[63]}},dat[63:56]};
	  endcase
	FN_LDBUX:
	  case(adr[2:0])
	  3'd0:   fnDati = {{56{1'b0}},dat[7:0]};
	  3'd1:   fnDati = {{56{1'b0}},dat[15:8]};
	  3'd2:   fnDati = {{56{1'b0}},dat[23:16]};
	  3'd3:   fnDati = {{56{1'b0}},dat[31:24]};
	  3'd4:   fnDati = {{56{1'b0}},dat[39:32]};
	  3'd5:   fnDati = {{56{1'b0}},dat[47:40]};
	  3'd6:   fnDati = {{56{1'b0}},dat[55:48]};
	  3'd7:   fnDati = {{56{1'b0}},dat[63:56]};
	  endcase
	FN_LDWX:
	  case(adr[2:1])
	  3'd0:   fnDati = {{48{dat[15]}},dat[15:0]};
	  3'd1:   fnDati = {{48{dat[31]}},dat[31:16]};
	  3'd2:   fnDati = {{48{dat[47]}},dat[47:32]};
	  3'd3:   fnDati = {{48{dat[63]}},dat[63:48]};
	  endcase
	FN_LDWUX:
	  case(adr[2:1])
	  3'd0:   fnDati = {{48{1'b0}},dat[15:0]};
	  3'd1:   fnDati = {{48{1'b0}},dat[31:16]};
	  3'd2:   fnDati = {{48{1'b0}},dat[47:32]};
	  3'd3:   fnDati = {{48{1'b0}},dat[63:48]};
	  endcase
	FN_LDTX:
		case(adr[2])
		1'b0:	fnDati = {{32{dat[31]}},dat[31:0]};
		1'b1:	fnDati = {{32{dat[63]}},dat[63:32]};
		endcase
	FN_LDTUX:
		case(adr[2])
		1'b0:	fnDati = {{32{1'b0}},dat[31:0]};
		1'b1:	fnDati = {{32{1'b0}},dat[63:32]};
		endcase
	FN_LDOX:
	  fnDati = dat;
	default:	fnDati = dat;
	endcase
default:    fnDati = dat;
endcase
endfunction

endpackage
