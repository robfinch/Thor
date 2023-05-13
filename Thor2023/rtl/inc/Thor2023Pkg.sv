`timescale 1ns / 10ps

package Thor2023Pkg;

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
parameter VAL = 1'b1;
parameter INV = 1'b0;

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

parameter REGFILE_LATENCY = 2;

parameter RAS_DEPTH	= 4;

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

typedef enum logic [4:0] {
	OP_TRAP			= 5'd00,
	OP_R2				= 5'd02,
	OP_CSR			= 5'd03,
	OP_ADDI			= 5'd04,
	OP_CMPI			= 5'd05,
	OP_MULI			= 5'd06,
	OP_DIVI			= 5'd07,
	OP_ANDI			= 5'd08,
	OP_ORI			= 5'd09,
	OP_EORI			= 5'd10,
	OP_FLT2			= 5'd12,
	OP_BITFLD		= 5'd13,
	OP_SHIFT		= 5'd14,
	OP_FMA			= 5'd15,
	OP_LOAD			= 5'd16,
	OP_LOADZ		= 5'd17,
	OP_STORE		= 5'd18,
	OP_FADDI		= 5'd20,
	OP_FCMPI		= 5'd21,
	OP_FMULI		= 5'd22,
	OP_FDIVI		= 5'd23,
	OP_JSR			= 5'd24,
	OP_LOADG		= 5'd26,
	OP_Bcc			= 5'd27,
	OP_LBcc			= 5'd28,
	OP_DBcc			= 5'd29,
	OP_PFX			= 5'd31
} opcode_t;

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
typedef enum logic [5:0] {
	OP_CNTLZ		= 6'd00,
	OP_CNTLO		= 6'd01,
	OP_CNTPOP		= 6'd02,
	OP_ABS			= 6'd03,
	OP_ADD			= 6'd04,
	OP_CMP			= 6'd05,
	OP_MUL			= 6'd06,
	OP_DIV			= 6'd07,
	OP_AND			= 6'd08,
	OP_OR				= 6'd09,
	OP_EOR			= 6'd10,
	OP_CHRNDX		= 6'd11,
	OP_JSRR			= 6'd24,
	OP_PRED			= 6'd32,
	OP_CARRY		= 6'd33,
	OP_REP			= 6'd34,
	OP_ATOM			= 6'd35,
	OP_V2BITS		= 6'd40,
	OP_BITS2V		= 6'd41
} r2func_t;

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

typedef enum logic [4:0] {
	OP_FSCALEB = 5'd0,
	OP_FMIN = 5'd1,
	OP_FMAX = 5'd3,
	OP_FADD = 5'd4,
	OP_FCMP = 5'd5,
	OP_FMUL = 5'd6,
	OP_FDIV = 5'd7,
	OP_FNXT = 5'd14,
	OP_FREM = 5'd15
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
	logic sign;					// 1=negate
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
	logic [2:0] typ;
	logic [4:0] opcode;
} postfix_t;


typedef struct packed
{
	logic [39:0] imm;
	logic [2:0] typ;
	logic [4:0] opcode;
} lpostfix_t;


typedef struct packed
{
	logic [30:0] payload;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} anyinst_t;


typedef struct packed
{
	logic [38:0] payload;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lanyinst_t;


typedef struct packed
{
	logic [1:0] resv1;
	logic [5:0] Rc;
	logic Vc;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} f3inst_t;

typedef struct packed
{
	logic [7:0] pad;
	logic [1:0] resv1;
	logic [5:0] Rc;
	logic Vc;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lf3inst_t;

typedef struct packed
{
	f2func_t func;
	logic [2:0] rm;
	logic Vc;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} f2inst_t;

typedef struct packed
{
	logic [7:0] pad;
	f2func_t func;
	logic [2:0] rm;
	logic Vc;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lf2inst_t;

typedef struct packed
{
	logic resv1;
	logic Vc;
	logic [5:0] Rc;
	logic S;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} bfinst_t;

typedef struct packed
{
	logic [7:0] pad;
	logic resv1;
	logic Vc;
	logic [5:0] Rc;
	logic S;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lbfinst_t;

typedef struct packed
{
	r2func_t func;
	logic resv1;
	logic Vc;
	logic S;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} r2inst_t;

typedef struct packed
{
	logic [7:0] pad;
	r2func_t func;
	logic resv1;
	logic Vc;
	logic S;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lr2inst_t;

typedef struct packed
{
	r2func_t func;
	logic resv1;
	logic Vc;
	logic S;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} cmpinst_t;

typedef struct packed
{
	logic [7:0] pad;
	r2func_t func;
	logic resv1;
	logic Vc;
	logic S;
	logic Vb;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lcmpinst_t;

typedef struct packed
{
	logic [6:0] immhi;
	logic Vc;
	logic S;
	logic [7:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} imminst_t;

typedef struct packed
{
	logic [7:0] pad;
	logic [6:0] immhi;
	logic Vc;
	logic S;
	logic [7:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} limminst_t;

typedef struct packed
{
	logic [6:0] immhi;
	logic Vc;
	logic S;
	logic [7:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} cmpiinst_t;

typedef struct packed
{
	logic [7:0] pad;
	logic [6:0] immhi;
	logic Vc;
	logic S;
	logic [7:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lcmpiinst_t;

typedef struct packed
{
	logic [4:0] func;
	logic [1:0] resv2;
	logic Vc;
	logic S;
	logic resv1;
	logic [6:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} shiftiinst_t;

typedef struct packed
{
	logic [7:0] pad;
	logic [4:0] func;
	logic [1:0] resv2;
	logic Vc;
	logic S;
	logic resv1;
	logic [6:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lshiftiinst_t;

typedef struct packed
{
	logic i;
	logic Vc;
	logic [5:0] immhi;
	logic S;
	logic [7:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	csrop_t csrop;
	opcode_t opcode;
} csrinst_t;

typedef struct packed
{
	logic [7:0] pad;
	logic i;
	logic Vc;
	logic [5:0] immhi;
	logic S;
	logic [7:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	csrop_t csrop;
	opcode_t opcode;
} lcsrinst_t;

typedef struct packed
{
	logic F;
	logic [1:0] ca;
	logic [5:0] Disphi;
	logic Vb;
	regspec_t Rb;
	regspec_t Rn;
	logic [6:0] Displo;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lsinst_t;

typedef struct packed
{
	logic [7:0] pad;
	logic F;
	logic [1:0] ca;
	logic [5:0] Disphi;
	logic Vb;
	regspec_t Rb;
	regspec_t Rn;
	logic [6:0] Displo;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} llsinst_t;

typedef struct packed
{
	logic F;
	logic Vc;
	logic [5:0] Rc;
	logic Sc;
	logic Vb;
	regspec_t Rb;
	regspec_t Rn;
	addr_upd_t upd;
	logic [1:0] ca;
	prec_t sz2;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} lsninst_t;

typedef struct packed
{
	logic [7:0] pad;
	logic F;
	logic Vc;
	logic [5:0] Rc;
	logic Sc;
	logic Vb;
	regspec_t Rb;
	regspec_t Rn;
	addr_upd_t upd;
	logic [1:0] ca;
	prec_t sz2;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} llsninst_t;

typedef struct packed
{
	logic [16:0] Disp;
	branch_cm_t cm;
	logic [5:0] Rn;
	logic [5:0]	Rm;
	branch_cnd_t cnd;	
	opcode_t opcode;
} brinst_t;

typedef struct packed
{
	logic [24:0] Disp;
	branch_cm_t cm;
	logic [5:0] Rn;
	logic [5:0]	Rm;
	branch_cnd_t cnd;	
	opcode_t opcode;
} lbrinst_t;

typedef struct packed
{
	logic [6:0] immhi;
	logic Vc;
	logic S;
	logic [7:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} jsrinst_t;

typedef struct packed
{
	logic [7:0] pad;
	logic [6:0] immhi;
	logic Vc;
	logic S;
	logic [7:0] immlo;
	regspec_t Ra;
	regspec_t Rt;
	logic vec;
	prec_t sz;
	opcode_t opcode;
} ljsrinst_t;

typedef union packed
{
	f3inst_t 	f3;
	f2inst_t	f2;
	bfinst_t 	bf;
	r2inst_t	r2;
	brinst_t	br;
	jsrinst_t	jsr;
	jsrinst_t	jmp;
	imminst_t	imm;
	imminst_t	ri;
	cmpinst_t	cmp;
	cmpiinst_t cmpi;
	shiftiinst_t shifti;
	csrinst_t	csr;
	lsinst_t	ls;
	lsninst_t	lsn;
	postfix_t	pfx;
	anyinst_t any;
} instruction_t;

typedef union packed
{
	lf3inst_t 	f3;
	lf2inst_t	f2;
	lbfinst_t 	bf;
	lr2inst_t	r2;
	lbrinst_t	br;
	ljsrinst_t	jsr;
	ljsrinst_t	jmp;
	limminst_t	imm;
	limminst_t	ri;
	lcmpinst_t	cmp;
	lcmpiinst_t cmpi;
	lshiftiinst_t shifti;
	lcsrinst_t	csr;
	llsinst_t	ls;
	llsninst_t	lsn;
	lpostfix_t	pfx;
	lanyinst_t any;
} linstruction_t;

typedef struct packed
{
	logic resv;
	regspec_t Vm;
	instruction_t ins;
} vector_instruction_t;

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

endpackage
