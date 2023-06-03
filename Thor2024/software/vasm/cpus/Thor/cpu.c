#include "vasm.h"

#define TRACE(x)		/*printf(x)*/
#define TRACE2(x,y)	/*printf((x),(y))*/
//#define BRANCH_PGREL 1

extern char* qual[MAX_QUALIFIERS];
extern int qual_len[MAX_QUALIFIERS];

const char *cpu_copyright="vasm Thor cpu backend (c) in 2021-2023 Robert Finch";

char *cpuname="Thor";
int bitsperbyte=8;
int bytespertaddr=8;
int abits=32;
static taddr sdreg = 61;
static taddr sd2reg = 60;
static taddr sd3reg = 59;
static __int64 regmask = 0x3fLL;

static insn_count = 0;
static byte_count = 0;

static insn_sizes1[20000];
static insn_sizes2[20000];
static int sz1ndx = 0;
static int sz2ndx = 0;
static short int argregs[11] = {1,2,3,48,49,50,51,42,43,44,45};
static short int tmpregs[12] = {4,5,6,7,8,9,10,11,12,13,14,15};
static short int saved_regs[16] = {16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31};

static char *qualifiers[] =
{
	"b", "w", "t", "o", "h", "B", "W", "T", "O", "H",
	"s", "d", "q",
	"none", "io", "rd", "rda", "wt", "wta", "wb", "wba"
};

static int qualifiers_code[] =
{
	0, 1, 2, 3, 4, 0, 1, 2, 3, 4,
	2, 3, 4,
	0x80, 0x80, 0x81, 0x82, 0x80, 0x81, 0x82, 0x83
};

static char *regnames[64] = {
	"r0", "a0", "a1", "a2", "t0", "t1", "t2", "t3",
	"t4", "t5", "t6", "t7", "t8", "t9", "t10", "t11",
	"s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7",
	"s8",	"s9", "s10", "s11", "s12", "s13", "s14", "s15",
	"m0", "m1", "m2", "m3", "m4", "m5", "m6", "m7",
	"a3", "a4", "a5", "a6", "a7", "a8", "a9", "a10",
	"r48", "r49", "r50", "r51", "ts", "pc", "cta", "lc",
	"lr0", "lr1", "lr2", "lr3", "gp1", "gp0", "fp", "sp"
};

static int regop[64] = {
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, 
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, 
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, 
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, 
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, 
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, 
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, 
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG
};

mnemonic mnemonics[]={
	"abs",	{OP_REG,OP_REG,0,0,0}, {R3RR,CPU_ALL,0,0x0C000001LL,5},

	"add", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(4LL)|IM2(0)|OPC(2LL),5,SZ_UNSIZED,0},	
	"add", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(4LL)|IM2(1LL)|OPC(2LL),5,SZ_UNSIZED,0},	
	"add", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FMT2(0)|OPC(4LL),5,SZ_UNSIZED,0},	

	"and", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(0)|IM2(0)|OPC(2LL),5,SZ_UNSIZED,0},	
	"and", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(0)|IM2(1)|OPC(2LL),5,SZ_UNSIZED,0},	
	"and", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FMT2(0)|OPC(8LL),5,SZ_UNSIZED,0},	

	"asl", {OP_REG,OP_REG,OP_REG,0}, {SH,CPU_ALL,0,SHFUNC(0x00LL)|OPC(88LL),5,SZ_UNSIZED,0},	
	"asl", {OP_REG,OP_REG,OP_IMM,0}, {SI,CPU_ALL,0,SHFUNC(0x40LL)|OPC(88LL),5,SZ_UNSIZED,0},	
	"asr", {OP_REG,OP_REG,OP_REG,0}, {SH,CPU_ALL,0,SHFUNC(0x02LL)|OPC(88LL),5,SZ_UNSIZED,0},	
	"asr", {OP_REG,OP_REG,OP_IMM,0}, {SI,CPU_ALL,0,SHFUNC(0x42LL)|OPC(88LL),5,SZ_UNSIZED,0},	

	"bbc",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(44LL),5,SZ_UNSIZED,0},
	"bbc",	{OP_REG,OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(46LL),5,SZ_UNSIZED,0},
	"bbs",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(45LL),5,SZ_UNSIZED,0},
	"bbs",	{OP_REG,OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(47LL),5,SZ_UNSIZED,0},
	"bcc",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(41LL),5,SZ_UNSIZED,0},

	"bcdadd", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x0000000000F5LL,6},	
	"bcdmul", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x0400000000F5LL,6},	
	"bcdsub", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x0200000000F5LL,6},	

	"bcs",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(40LL),5,SZ_UNSIZED,0},
	"beq",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(38LL),5,SZ_UNSIZED,0},
	"beqz",	{OP_REG,OP_IMM,0,0,0}, {BZ,CPU_ALL,0,OPC(38LL),5,SZ_UNSIZED,0},

//	"beven",	{OP_REG,OP_IMM,0,0,0}, {B,CPU_ALL,0,COND(13LL)|OPC(28LL),5},

	"bge",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(41LL),5,SZ_UNSIZED,0},
	"bgeu",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(41LL),5,SZ_UNSIZED,0},
	"bgt",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(43LL),5,SZ_UNSIZED,0},
	"bgtu",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(43LL),5,SZ_UNSIZED,0},
	"bhi",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(43LL),5,SZ_UNSIZED,0},
	"bhs",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(41LL),5,SZ_UNSIZED,0},
	"ble",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(42LL),5,SZ_UNSIZED,0},
	"bleu",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(42LL),5,SZ_UNSIZED,0},
	"bllt",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,LK(1)|OPC(40LL),5,SZ_UNSIZED,0},
	"blltu",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|LK(1)|OPC(40LL),5,SZ_UNSIZED,0},
	"blo",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(40LL),5,SZ_UNSIZED,0},
	"bls",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(42LL),5,SZ_UNSIZED,0},
	"blt",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(40LL),5,SZ_UNSIZED,0},
	"bltu",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,CM(1LL)|OPC(40LL),5,SZ_UNSIZED,0},

	"bmap", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(35)|IM2(0)|OPC(2LL),5,SZ_UNSIZED,0},	
	"bmm", 	{OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(34)|IM2(0)|OPC(2LL),5,SZ_UNSIZED,0},	

	"bne",	{OP_REG,OP_REG,OP_IMM,0,0}, {B,CPU_ALL,0,OPC(39LL),5,SZ_UNSIZED,0},
	"bnez",	{OP_REG,OP_IMM,0,0,0}, {BZ,CPU_ALL,0,OPC(39LL),5,SZ_UNSIZED,0},
	"bnz",	{OP_REG,OP_IMM,0,0,0}, {BZ,CPU_ALL,0,OPC(39LL),5,SZ_UNSIZED,0},
//	"bodd",	{OP_REG,OP_IMM,0,0,0}, {B,CPU_ALL,0,COND(5LL)|OPC(28LL),5},
//	"bodd",	{OP_REG,OP_IMM,0,0,0}, {B,CPU_ALL,0,COND(5LL)|OPC(28LL),5},

	"bra",	{OP_IMM,0,0,0,0}, {B2,CPU_ALL,0,COND(14LL)|OPC(27LL),5,SZ_UNSIZED,0},

	"brk",	{0,0,0,0,0}, {R1,CPU_ALL,0,0x00,5,SZ_UNSIZED,0},

	"bsr",	{OP_IMM,0,0,0,0}, {B2,CPU_ALL,0,OPC(32LL),5,SZ_UNSIZED,0},
	"bsr",	{OP_REG,OP_IMM,0,0,0}, {BL2,CPU_ALL,0,OPC(32LL),5,SZ_UNSIZED,0},

	"bytndx", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0xAA0000000002LL,6},	
	"bytndx", 	{OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0x00000055LL,4},

	"bz",	{OP_REG,OP_IMM,0,0,0}, {BZ,CPU_ALL,0,OPC(38LL),5,SZ_UNSIZED,0},

	"chk", 	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x320000000002LL,6},	
	"chk", 	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3,CPU_ALL,0,0x000000000045LL,6},	

	"clmul", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x5C0000000002LL,6},	
	"clmulh", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x5E0000000002LL,6},	

	"clr", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,R2FUNC(56LL)|OPC(13LL),5},	
	"clr", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,FUNC3(0LL)|OPC(13LL),5},	

	"cmovnz", 	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x5A0000000002LL,6},	

	"cmp", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(3LL)|IM2(0)|OPC(2LL),5,SZ_UNSIZED,0},	
	"cmp", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(3LL)|IM2(1)|OPC(2LL),5,SZ_UNSIZED,0},	
	"cmp", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FMT2(0)|OPC(11LL),5,SZ_UNSIZED,0},	

	"cntlz", {OP_VREG,OP_VREG,0,0,0}, {R1,CPU_ALL,0,0x00000101,4},
	"cntlz", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x00000001,4},
	"cntpop", {OP_VREG,OP_VREG,0,0,0}, {R1,CPU_ALL,0,0x04000101,4},
	"cntpop", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x04000001,4},

	"com",	{OP_VREG,OP_VREG,0,0,0}, {R3II,CPU_ALL,0,0x1417F00001AALL,6},
	"com", {OP_REG,OP_REG,0,0,0}, {RIL,CPU_ALL,0,0xFFFFFFF800DALL,6,0xFFF8000ALL,4},

	"cpuid", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x41LL,4},
	
	"csrrc", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FUNC2(0)|OPC(3),5,SZ_UNSIZED,0},
	"csrrc", {OP_REG,OP_IMM,OP_IMM,0,0}, {CSRI,CPU_ALL,0,FUNC2(1)|OPC(3),5,SZ_UNSIZED,0},
	"csrrd", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FUNC2(0)|OPC(3),5,SZ_UNSIZED,0},
	"csrrd", {OP_REG,OP_IMM,OP_IMM,0,0}, {CSRI,CPU_ALL,0,FUNC2(1)|OPC(3),5,SZ_UNSIZED,0},
	"csrrs", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FUNC2(0)|OPC(3),5,SZ_UNSIZED,0},
	"csrrs", {OP_REG,OP_IMM,OP_IMM,0,0}, {CSRI,CPU_ALL,0,FUNC2(1)|OPC(3),5,SZ_UNSIZED,0},
	"csrrw", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,OPC(3),5,SZ_UNSIZED,0},
	"csrrw", {OP_REG,OP_IMM,OP_IMM,0,0}, {CSRI,CPU_ALL,0,FUNC2(1)|OPC(3),5,SZ_UNSIZED,0},
	"csrwr", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,OPC(3),5,SZ_UNSIZED,0},
	"csrwr", {OP_REG,OP_IMM,OP_IMM,0,0}, {CSRI,CPU_ALL,0,FUNC2(1)|OPC(3),5,SZ_UNSIZED,0},

	"dbra",	{OP_IMM,0,0,0,0},{B,CPU_ALL,0,0x00001F000021LL,5,SZ_UNSIZED,0},

	"di",		{OP_NEXTREG,OP_NEXTREG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x2C0000000007LL,6},
	"dif",	{OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x280000000002LL,6},

	"div", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x142LL,6},	
	"div", {OP_VREG,OP_VREG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x142LL,6},
	"div", {OP_VREG,OP_VREG,OP_VREG,OP_VMREG,0}, {R3,CPU_ALL,0,0x200000000102LL,6},	
	"div", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x200000000102LL,6},	
	"div", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x200000000002LL,6},	
	"div", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x42LL,6},

	"divu", {OP_VREG,OP_VREG,OP_VREG,OP_VMREG,0}, {R3RR,CPU_ALL,0,0x220000000102LL,6},	
	"divu", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3RR,CPU_ALL,0,0x220000000102LL,6},	
	"divu", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x220000000002LL,6},	
	"divu", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0x4FLL,4},

	"djmp",	{OP_IMM,0,0,0,0},{J2,CPU_ALL,0,0x000000000021LL,6},
	"djmp",	{OP_LK,OP_IMM,0,0,0},{JL2,CPU_ALL,0,0x000000000021LL,6},

	"enor", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(2LL)|IM2(0)|OPC(2LL),5,SZ_UNSIZED,0},	
	"enor", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(2LL)|IM2(1)|OPC(2LL),5,SZ_UNSIZED,0},	
	"enor", {OP_REG,OP_REG,OP_IMM,0,0}, {RIB,CPU_ALL,0,FMT3(0)|R2FUNC(2LL)|IM2(2)|OPC(2LL),5,SZ_UNSIZED,0},	

	"eor", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(2LL)|IM2(0)|OPC(2LL),5,SZ_UNSIZED,0},	
	"eor", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(2LL)|IM2(1)|OPC(2LL),5,SZ_UNSIZED,0},	
	"eor", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FMT2(0)|OPC(10LL),5,SZ_UNSIZED,0},	

	"ext",	{OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,R2FUNC(61)|OPC(13),5,SZ_INTALL,SZ_HEXI},
	"ext",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,FUNC3(5)|OPC(13),5,SZ_INTALL,SZ_HEXI},
	"exts",	{OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,R2FUNC(61)|OPC(13),5,SZ_INTALL,SZ_HEXI},
	"exts",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,FUNC3(5)|OPC(13),5,SZ_INTALL,SZ_HEXI},
	"extu",	{OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,R2FUNC(60)|OPC(13),5,SZ_INTALL,SZ_HEXI},
	"extu",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,FUNC3(4)|OPC(13),5,SZ_INTALL,SZ_HEXI},

	"fadd", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_VREG|OP_REG,0,0}, {R2,CPU_ALL,0,FUNC5(4LL)|OPC(12LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fadd", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,0}, {RI,CPU_ALL,0,OPC(20LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fcmp", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_VREG|OP_REG,0,0}, {R2,CPU_ALL,0,FUNC5(5LL)|OPC(12LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fcmp", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,0}, {RI,CPU_ALL,0,OPC(21LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fcmp", {OP_VREG|OP_REG,OP_IMM,OP_VREG|OP_REG,0}, {RIV,CPU_ALL,0,0x80000000LL|OPC(21LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	
	"fcvtdq", {OP_VREG|OP_REG,OP_VREG|OP_REG,0,0,0}, {R1,CPU_ALL,0,FLT1(11)|FUNC5(1)|OPC(12LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	
	"fdiv", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_VREG|OP_REG,0,0}, {R2,CPU_ALL,0,FUNC5(7LL)|OPC(12LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fdiv", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,0}, {RI,CPU_ALL,0,OPC(23LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fdiv", {OP_VREG|OP_REG,OP_IMM,OP_VREG|OP_REG,0}, {RIV,CPU_ALL,0,0x80000000LL|OPC(23LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fmul", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_VREG|OP_REG,0,0}, {R2,CPU_ALL,0,FUNC5(6LL)|OPC(12LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fmul", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,0}, {RI,CPU_ALL,0,OPC(22LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fneg", {OP_VREG|OP_REG,OP_VREG|OP_REG,0,0,0}, {R2,CPU_ALL,0,RB(34LL)|FUNC5(1LL)|OPC(12LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fsub", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_VREG|OP_REG,0,0}, {R2,CPU_ALL,0,FUNC5(4LL)|OPC(12LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	
	"fsub", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,0}, {RI,CPU_ALL,0,OPC(20LL),5,SZ_FLTALL,SZ_DOUBLE, FLG_NEGIMM,FLG_FP},	
	"ftoi", {OP_VREG|OP_REG,OP_VREG|OP_REG,0,0,0}, {R2,CPU_ALL,0,RB(2LL)|FUNC5(1LL)|OPC(12LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	

	"int",	{OP_IMM,OP_IMM,0,0,0}, {INT,CPU_ALL,0,0xA6LL,4},

	"itof", {OP_VREG|OP_REG,OP_VREG|OP_REG,0,0,0}, {R2,CPU_ALL,0,RB(3LL)|FUNC5(1LL)|OPC(12LL),5,SZ_FLTALL,SZ_DOUBLE,FLG_FP},	

	"jmp",	{OP_REGIND,0,0,0,0}, {J2,CPU_ALL,0,OPC(24LL),5, SZ_UNSIZED,0},
	"jmp",	{OP_REG,0,0,0,0}, {J2,CPU_ALL,0,OPC(24LL),5, SZ_UNSIZED,0},
	"jmp",	{OP_IMM,0,0,0,0}, {J2,CPU_ALL,0,OPC(24LL),5, SZ_UNSIZED,0},
	"jsr",	{OP_REGIND,0,0,0}, {J2,CPU_ALL,0,RT(57LL)|OPC(24LL),5, SZ_UNSIZED,0},
	"jsr",	{OP_REG,OP_IND_SCNDX,0,0,0}, {JSCNDX,CPU_ALL,0,R2FUNC(24LL)|0x80000000L|OPC(2LL),5, SZ_UNSIZED,0},
	"jsr",	{OP_REG,OP_REGIND,0,0,0}, {JL2,CPU_ALL,0,OPC(24LL),5, SZ_UNSIZED,0},
	"jsr",	{OP_REG,OP_IMM,0,0,0}, {JL2,CPU_ALL,0,OPC(24LL),5, SZ_UNSIZED,0},
	"jsr",	{OP_IMM,0,0,0,0}, {J2,CPU_ALL,0,RT(57LL)|OPC(24LL),5, SZ_UNSIZED,0},

	"ldb",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(64LL),5, SZ_UNSIZED, 0},	
	"ldb",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(64LL),5, SZ_UNSIZED, 0},	
	"ldb",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(0)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	

	"ldbu",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(65LL),5, SZ_UNSIZED, 0},	
	"ldbu",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(65LL),5, SZ_UNSIZED, 0},	
	"ldbu",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(1LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	
	"ldbz",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(65LL),5, SZ_UNSIZED, 0},	
	"ldbz",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(65LL),5, SZ_UNSIZED, 0},	
	"ldbz",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(1LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	

	"ldh",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(72LL),5, SZ_UNSIZED, 0},	
	"ldh",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(72LL),5, SZ_UNSIZED, 0},	
	"ldh",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(8LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	

	"ldi", {OP_VREG|OP_REG,OP_NEXTREG,OP_IMM,0,0}, {RI,CPU_ALL,0,OPC(4LL),5, SZ_UNSIZED, 0},	

	"ldo",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(70LL),5, SZ_UNSIZED, 0},	
	"ldo",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(70LL),5, SZ_UNSIZED, 0},	
	"ldo",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(6LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	
	"ldou",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(71LL),5, SZ_UNSIZED, 0},	
	"ldou",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(71LL),5, SZ_UNSIZED, 0},	
	"ldou",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(7LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	
	"ldoz",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(71LL),5, SZ_UNSIZED, 0},	
	"ldoz",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(71LL),5, SZ_UNSIZED, 0},	
	"ldoz",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(7LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	

	"ldt",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(68LL),5, SZ_UNSIZED, 0},	
	"ldt",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(68LL),5, SZ_UNSIZED, 0},	
	"ldt",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(4LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	
	"ldtu",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(69LL),5, SZ_UNSIZED, 0},	
	"ldtu",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(69LL),5, SZ_UNSIZED, 0},	
	"ldtu",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(5LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	
	"ldtz",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(69LL),5, SZ_UNSIZED, 0},	
	"ldtz",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(69LL),5, SZ_UNSIZED, 0},	
	"ldtz",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(5LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	

	"ldw",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(66LL),5, SZ_UNSIZED, 0},	
	"ldw",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(66LL),5, SZ_UNSIZED, 0},	
	"ldw",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(2LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	
	"ldwu",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(67LL),5, SZ_UNSIZED, 0},	
	"ldwu",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(67LL),5, SZ_UNSIZED, 0},	
	"ldwu",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(3LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	
	"ldwz",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(67LL),5, SZ_UNSIZED, 0},	
	"ldwz",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(67LL),5, SZ_UNSIZED, 0},	
	"ldwz",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(3LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	

	"lda",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(74LL),5, SZ_UNSIZED, 0},	
	"lda",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(74LL),5, SZ_UNSIZED, 0},	
	"lda",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(10LL)|CPU_ALL,0,OPC(79LL),5, SZ_UNSIZED, 0},	

	"lsr", {OP_REG,OP_REG,OP_REG,0}, {SH,CPU_ALL,0,SHFUNC(0x01LL)|OPC(88LL),5,SZ_UNSIZED,0},	
	"lsr", {OP_REG,OP_REG,OP_IMM,0}, {SI,CPU_ALL,0,SHFUNC(0x41LL)|OPC(88LL),5,SZ_UNSIZED,0},	

	"max",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x520000000002LL,6},	
	"memdb",	{0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF9,2},
	"memsb",	{0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF8,2},
	"min",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x500000000002LL,6},	

	"mod", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,R2FUNC(7)|OPC(2)|0x200000000LL,5,SZ_INTALL,SZ_HEXI},
	"mod", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,R2FUNC(7)|OPC(2)|0x200000000LL,5,SZ_INTALL,SZ_HEXI},
	"modu", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,R2FUNC(7)|OPC(2)|0x300000000LL,5,SZ_INTALL,SZ_HEXI},
	"modu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,R2FUNC(7)|OPC(2)|0x300000000LL,5,SZ_INTALL,SZ_HEXI},

	"mov", {OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x13LL,5, SZ_INTALL,SZ_HEXI},	
	"move", {OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x13LL,5},	
//	"mov",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0817F00000AALL,6},
//	"move",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0817F00000AALL,6},
	"movsxb",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0A120E0000AALL,6},
	"movsxt",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0A123E0000AALL,6},
	"movsxw",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0A121E0000AALL,6},
	"movzxb",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x08120E0000AALL,6},
	"movzxt",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x08123E0000AALL,6},
	"movzxw",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x08121E0000AALL,6},

	"mrts",	{0,0,0,0,0}, {RTS,CPU_ALL,0,0x01F2LL, 2},

	"mtlc",		{OP_NEXTREG,OP_REG,0,0,0}, {R2,CPU_ALL,0,0xA0000052LL,4},

	"mul", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_VREG|OP_REG,0,0}, {R2,CPU_ALL,0,R2FUNC(6LL)|OPC(2LL),5,SZ_INTALL,SZ_HEXI},	
	"mul", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,0}, {RI,CPU_ALL,0,OPC(6LL),5,SZ_INTALL,SZ_HEXI},	
	"mul", {OP_VREG|OP_REG,OP_IMM,OP_VREG|OP_REG,0}, {RIS,CPU_ALL,0,OPC(6LL),5,SZ_INTALL,SZ_HEXI},	

	"muladd", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x0C0000000002LL,6},	

	"mulf", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x2A0000000002LL,6},	
	"mulf", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0x15LL,4},

	"mulh", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x1E0000000002LL,6},	

	"mulu", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x1C0000000002LL,6},	
	"mulu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xDE,6,0x0ELL,4},

	"mux",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x680000000002LL,6},	

	"nand", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x000000000102LL,6},	
	"nand", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x000000000102LL,6},	
	"nand", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,R2FUNC(8LL)|OPC(2LL),5, SZ_INTALL, SZ_HEXI},	
	"nand", {OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,R2FUNC(8LL)|OPC(2LL),5, SZ_INTALL, SZ_HEXI},	

	"neg", {OP_REG,OP_NEXTREG,OP_REG,0,0}, {R2,CPU_ALL,0,0x0000000DLL,4},	
//	"neg",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A000001LL,4},

	"nop",	{0,0,0,0,0}, {BITS16,CPU_ALL,0,0xffffffffffLL,5, SZ_UNSIZED, 0},

	"nor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x020000000102LL,6},	
	"nor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x020000000102LL,6},	
	"nor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x020000000002LL,6},	
	"not", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x08000001LL,4},

	"or", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(0)|OPC(2LL),5,SZ_UNSIZED,0},	
	"or", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(1)|OPC(2LL),5,SZ_UNSIZED,0},	
	"or", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FMT2(0)|OPC(9LL),5,SZ_UNSIZED,0},	

	"orf", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_VREG|OP_REG,OP_VMREG,0}, {R2M,CPU_ALL,0,R2FUNC(9LL)|OPC(2LL),5, SZ_INTALL, SZ_HEXI},
	"orf", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,OP_VMREG,0}, {RIM,CPU_ALL,0,OPC(9LL),5, SZ_INTALL, SZ_HEXI},
	"orf", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_VREG|OP_REG,0,0}, {R2,CPU_ALL,0,R2FUNC(9LL)|OPC(2LL),5, SZ_INTALL, SZ_HEXI},	
	"orf", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,0}, {RI,CPU_ALL,0,OPC(9LL),5, SZ_INTALL, SZ_HEXI},	

	"peekq",	{OP_REG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x140000000007LL,6},	
	"peekq",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x140000000007LL,6},	

	"pcc",	{OP_REG,OP_PREDSTR,0,0,0}, {PRED,CPU_ALL,0,R2FUNC(32)|COND(11LL)|OPC(2LL),5, SZ_UNSIZED, 0},
	"pcs",	{OP_REG,OP_PREDSTR,0,0,0}, {PRED,CPU_ALL,0,R2FUNC(32)|COND(3LL)|OPC(2LL),5, SZ_UNSIZED, 0},
	"peq",	{OP_REG,OP_PREDSTR,0,0,0}, {PRED,CPU_ALL,0,R2FUNC(32)|COND(0LL)|OPC(2LL),5, SZ_UNSIZED, 0},
	"peven",	{OP_REG,OP_PREDSTR,0,0,0}, {PRED,CPU_ALL,0,R2FUNC(32)|COND(13LL)|OPC(2LL),5, SZ_UNSIZED, 0},

	"pfi",	{OP_REG,0,0,0,0},{R3RR,CPU_ALL,0,0x220000000007LL,6},	
	"pfx", 	{OP_IMM,0,0,0,0},{PFX,CPU_ALL,0,OPC(127LL),5,SZ_UNSIZED,0},

	"pop",	{OP_REG,OP_REG,OP_REG,OP_REG,0},{R4,CPU_ALL,0,0x800000BELL,4},	
	"pop",	{OP_REG,OP_REG,OP_REG,0,0},{R3,CPU_ALL,0,0x600000BELL,4},	
	"pop",	{OP_REG,OP_REG,0,0,0},{R3,CPU_ALL,0,0x400000BELL,4},	
	"pop",	{OP_REG,0,0,0,0},{R3,CPU_ALL,0,0x000BCLL,2},	

	"popq",	{OP_REG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x120000000007LL,6},	
	"popq",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x120000000007LL,6},	

	"ptghash", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x5E000001,4},

	"ptrdif",	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x281000000002LL,6},
	"ptrdif",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x280000000002LL,6},

	"push",	{OP_REG,OP_REG,OP_REG,OP_REG,0},{R4,CPU_ALL,0,0x800000AELL,4},	
	"push",	{OP_REG,OP_REG,OP_REG,0,0},{R3,CPU_ALL,0,0x600000AELL,4},	
	"push",	{OP_REG,OP_REG,0,0,0},{R3,CPU_ALL,0,0x400000AELL,4},	
	"push",	{OP_REG,0,0,0,0},{R3,CPU_ALL,0,0x000ACLL,2},	

	"pushq",	{OP_NEXTREG,OP_REG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x100000000007LL,6},	
	"pushq",	{OP_NEXTREG,OP_REG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x100000000007LL,6},	

//	"rem", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x200000000102LL,6},	
//	"rem", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x200000000002LL,6},	
//	"rem", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x42LL,6},
	"repbc", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(6LL)|OPC(0LL),5},
	"repbs", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(7LL)|OPC(0LL),5},
	"repdeq", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(2LL)|OPC(0LL),5},
	"repdge", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(4LL)|OPC(3LL),5},
	"repdgt", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(5LL)|OPC(3LL),5},
	"repdle", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(2LL)|OPC(3LL),5},
	"repdlt", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(2LL)|OPC(2LL),5},
	"repdne", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(2LL)|OPC(1LL),5},
	"repeq", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(2LL)|OPC(0LL),5},
	"repge", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(4LL)|OPC(3LL),5},
	"repgt", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(5LL)|OPC(3LL),5},
	"repibc", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|0x8000|CND3(6LL)|OPC(2LL),5},
	"repibs", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|0x8000|CND3(7LL)|OPC(2LL),5},
	"repieq", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|0x8000|CND3(0LL)|OPC(2LL),5},
	"repige", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|0x8000|CND3(4LL)|OPC(2LL),5},
	"repigt", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|0x8000|CND3(5LL)|OPC(2LL),5},
	"repile", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|0x8000|CND3(3LL)|OPC(2LL),5},
	"repilt", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|0x8000|CND3(2LL)|OPC(2LL),5},
	"repine", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|0x8000|CND3(1LL)|OPC(2LL),5},
	"reple", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(2LL)|OPC(3LL),5},
	"replt", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(2LL)|OPC(2LL),5},
	"repne", {OP_IMM,OP_IMM,0,0,0},{REP,CPU_ALL,0,R2FUNC(34LL)|CND3(2LL)|OPC(1LL),5},

	"resetq",	{OP_NEXTREG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x180000000007LL,6},	
	"resetq",	{OP_NEXTREG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x180000000007LL,6},	

	"revbit",	{OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x50000001LL,4},

	"ret", {OP_REG,0,0,0,0}, {RTDR,CPU_ALL,0,0x80000000LL|R2FUNC(4LL)|OPC(2LL),5,SZ_INTALL,SZ_HEXI},	
	"ret", {0,0,0,0,0}, {RTDR,CPU_ALL,0,0x80000000LL|R2FUNC(4LL)|OPC(2LL),5,SZ_INTALL,SZ_HEXI},	

	"rex",	{OP_IMM,OP_REG,0,0,0},{REX,CPU_ALL,0,0x200000000007LL,6},	

	"rol", {OP_REG,OP_REG,OP_REG,0}, {SH,CPU_ALL,0,SHFUNC(0x03LL)|OPC(88LL),5,SZ_UNSIZED,0},	
	"rol", {OP_REG,OP_REG,OP_IMM,0}, {SI,CPU_ALL,0,SHFUNC(0x43LL)|OPC(88LL),5,SZ_UNSIZED,0},	
	"ror", {OP_REG,OP_REG,OP_REG,0}, {SH,CPU_ALL,0,SHFUNC(0x04LL)|OPC(88LL),5,SZ_UNSIZED,0},	
	"ror", {OP_REG,OP_REG,OP_IMM,0}, {SI,CPU_ALL,0,SHFUNC(0x44LL)|OPC(88LL),5,SZ_UNSIZED,0},	

	"rtd", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {RTDR,CPU_ALL,0,0x80000000LL|R2FUNC(4LL)|OPC(2LL),5,SZ_INTALL,SZ_HEXI},	
	"rtd", {OP_NEXTREG,OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM}, {RTDI,CPU_ALL,0,0x80000000LL|OPC(4LL),5,SZ_INTALL,SZ_HEXI},	
	"rtd", {OP_REG,OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM}, {RTDI,CPU_ALL,0,0x80000000LL|OPC(4LL),5,SZ_INTALL,SZ_HEXI},	
	"rti",	{OP_IMM,0,0,0,0}, {RTS,CPU_ALL,0,0x00F0LL, 2},
	"rti",	{0,0,0,0,0}, {RTS,CPU_ALL,0,0x00F0LL, 2},
	"rts", {OP_REG,0,0,0,0}, {RTDR,CPU_ALL,0,0x80000000LL|R2FUNC(4LL)|OPC(2LL),5,SZ_INTALL,SZ_HEXI},	
	"rts", {0,0,0,0,0}, {RTDR,CPU_ALL,0,0x80000000LL|R2FUNC(4LL)|OPC(2LL),5,SZ_INTALL,SZ_HEXI},	

	"rts",	{OP_LK,OP_IMM,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"rts",	{OP_LK,0,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"rts",	{0,0,0,0,0}, {RTS,CPU_ALL,0,0x02F2LL, 2},

	"sbx", {OP_VREG|OP_REG,OP_VREG|OP_REG,OP_IMM,OP_IMM,0}, {RII,CPU_ALL,0,FUNC3(3LL)|OPC(13LL),5,SZ_INTALL,SZ_HEXI},	

	"sei",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x2E0000000007LL,6},	

	"seq", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(0)|OPC(80LL),5,SZ_UNSIZED,0},	
	"seq", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(1)|OPC(80LL),5,SZ_UNSIZED,0},	
	"seq", {OP_REG,OP_REG,OP_IMM,0,0}, {RIB,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(2)|OPC(80LL),5,SZ_UNSIZED,0},	
	"sle", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(0)|OPC(83LL),5,SZ_UNSIZED,0},	
	"sle", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(1)|OPC(83LL),5,SZ_UNSIZED,0},	
	"sle", {OP_REG,OP_REG,OP_IMM,0,0}, {RIB,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(2)|OPC(83LL),5,SZ_UNSIZED,0},	
	"sleu", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(0)|OPC(85LL),5,SZ_UNSIZED,0},	
	"sleu", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(1)|OPC(85LL),5,SZ_UNSIZED,0},	
	"sleu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIB,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(2)|OPC(85LL),5,SZ_UNSIZED,0},	
	"slt", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(0)|OPC(82LL),5,SZ_UNSIZED,0},	
	"slt", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(1)|OPC(82LL),5,SZ_UNSIZED,0},	
	"slt", {OP_REG,OP_REG,OP_IMM,0,0}, {RIB,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(2)|OPC(82LL),5,SZ_UNSIZED,0},	
//	"seq", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x4C0000000002LL,6},	
//	"seq", {OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x4C0000000002LL,6},	

//	"slt", {OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x400000000002LL,6},	

	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x800000000002LL,6},	
	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x800000000002LL,6},	
	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R2,CPU_ALL,0,0x58,4},
//	"sll",	{OP_REG,OP_REG,OP_IMM,0,0}, {SHIFTI,CPU_ALL,0,0x800000000002LL,6},
	"sll",	{OP_REG,OP_REG,OP_IMM,0,0}, {RI6,CPU_ALL,0,0x6C,4},
	"sll",	{OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x58,4},

	"sllp",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x800000000002LL,6},	
	"sllp",	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3,CPU_ALL,0,0x800000000002LL,6},	

//	"sne", {OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x4E0000000002LL,6},	
//	"sne", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x4E0000000002LL,6},	
	"sne", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(0)|OPC(81LL),5,SZ_UNSIZED,0},	
	"sne", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(1)|OPC(81LL),5,SZ_UNSIZED,0},	
	"sne", {OP_REG,OP_REG,OP_IMM,0,0}, {RIB,CPU_ALL,0,FMT3(0)|R2FUNC(1LL)|IM2(2)|OPC(81LL),5,SZ_UNSIZED,0},	

	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x840000000002LL,6},	
	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x840000000002LL,6},	
	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x840000000002LL,6},	
//	"sra",	{OP_REG,OP_REG,OP_IMM,0,0}, {SHIFTI,CPU_ALL,0,0x840000000002LL,6},
	"sra",	{OP_REG,OP_REG,OP_IMM,0,0}, {RI6,CPU_ALL,0,0x6E,4},
	"sra",	{OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x5A,4},

	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x820000000002LL,6},	
	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x820000000002LL,6},	
	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x820000000002LL,6},	
//	"srl",	{OP_REG,OP_REG,OP_IMM,0,0}, {SHIFTI,CPU_ALL,0,0x820000000002LL,6},
	"srl",	{OP_REG,OP_REG,OP_IMM,0,0}, {RI6,CPU_ALL,0,0x6D,4},
	"srl",	{OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x59,4},

	"statq",	{OP_REG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x160000000007LL,6},	
	"statq",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x160000000007LL,6},	

	"stb",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(80LL),5, SZ_UNSIZED, 0},	
	"stb",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(80LL),5, SZ_UNSIZED, 0},	
	"stb",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(0)|CPU_ALL,0,OPC(87LL),5, SZ_UNSIZED, 0},	

	"sth",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(84LL),5, SZ_UNSIZED, 0},	
	"sth",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(84LL),5, SZ_UNSIZED, 0},	
	"sth",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(4LL)|CPU_ALL,0,OPC(87LL),5, SZ_UNSIZED, 0},	

	"sto",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(83LL),5, SZ_UNSIZED, 0},	
	"sto",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(83LL),5, SZ_UNSIZED, 0},	
	"sto",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(3LL)|CPU_ALL,0,OPC(87LL),5, SZ_UNSIZED, 0},	

	"stt",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(82LL),5, SZ_UNSIZED, 0},	
	"stt",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(82LL),5, SZ_UNSIZED, 0},	
	"stt",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(2LL)|CPU_ALL,0,OPC(87LL),5, SZ_UNSIZED, 0},	

	"stw",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,OPC(81LL),5, SZ_UNSIZED, 0},	
	"stw",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,OPC(81LL),5, SZ_UNSIZED, 0},	
	"stw",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,LSFUNC(1LL)|CPU_ALL,0,OPC(87LL),5, SZ_UNSIZED, 0},	

	"sub", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(5LL)|IM2(0)|OPC(2LL),5,SZ_UNSIZED,0},	
	"sub", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(5LL)|IM2(1LL)|OPC(2LL),5,SZ_UNSIZED,0},	
	"sub", {OP_REG,OP_REG,OP_IMM,0,0}, {RIB,CPU_ALL,0,FMT3(0)|R2FUNC(5LL)|IM2(2LL)|OPC(2LL),5,SZ_UNSIZED,0},	

	"subf", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FMT2(0)|OPC(5LL),5,SZ_UNSIZED,0},	

/* 0000_1010_0001_0001_1111_0000_0000_0000_0000_0000_AALL */

	"sxb",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A120E0000AALL,6},	
	"sxc",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A121E0000AALL,6},	/* alternate mnemonic for sxw */
	"sxo",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A123E0000AALL,6},
	"sxw",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A121E0000AALL,6},
	"sxt",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A123E0000AALL,6},

	"sync", {0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF7LL,2},
	"sys",	{OP_IMM,0,0,0,0}, {BITS40,CPU_ALL,0,OPC(0LL),5},
	"syscall",	{0,0,0,0,0}, {BITS40,CPU_ALL,0,OPC(0LL),5},

	"tlbrw",	{OP_REG,OP_REG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x3C0000000007LL,6},	

	"utf21ndx", 	{OP_REG,OP_VREG,OP_REG,0,0}, {R3,CPU_ALL,0,0x380000000102LL,6},	
	"utf21ndx", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x380000000002LL,6},	
	"utf21ndx", 	{OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x57LL,6},	

	"vmask",	{OP_VMSTR,0,0,0,0}, {VMASK,CPU_ALL,0,R2FUNC(34)|OPC(2),5},

	"wfi", {0,0,0,0,0}, {BITS16,CPU_ALL,0,0xFALL,2},

	"wydendx", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x360000000002LL,6},	
	"wydendx", 	{OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x56LL,6},	

	/* Alternate mnemonic for enor */

	/* Alternate mnemonic for eor */
	"xor", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,FMT3(0)|R2FUNC(2LL)|IM2(0LL)|OPC(2LL),5,SZ_UNSIZED,0},	
	"xor", {OP_REG,OP_IMM,OP_REG,0,0}, {RIA,CPU_ALL,0,FMT3(0)|R2FUNC(2LL)|IM2(1LL)|OPC(2LL),5,SZ_UNSIZED,0},	
	"xor", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,FMT2(0)|OPC(10LL),5,SZ_UNSIZED,0},	

};

const int mnemonic_cnt = sizeof(mnemonics)/sizeof(mnemonics[0]);

int thor_data_operand(int n)
{
  if (n&OPSZ_FLOAT) return OPSZ_BITS(n)>64?OP_F128:OPSZ_BITS(n)>32?OP_F64:OP_F32;
  if (OPSZ_BITS(n)<=8) return OP_D8;
  if (OPSZ_BITS(n)<=16) return OP_D16;
  if (OPSZ_BITS(n)<=32) return OP_D32;
  if (OPSZ_BITS(n)<=64) return OP_D64;
  return OP_D128;
}

static int getextcode(char c)
{
  switch (tolower((unsigned char)c)) {
    case 'b':
      return EXT_BYTE;
    case 'w':
      return EXT_WYDE;
    case 't':
    	return EXT_TETRA;
    case 'o':
    	return EXT_OCTA;
    case 'h':
    	return EXT_HEXI;
    case 's':
      return EXT_SINGLE;
    case 'd':
      return EXT_DOUBLE;
    case 'q':
      return EXT_QUAD;
  }
  return -1;
}

/* convert lower-case extension character to a SIZE_xxx code */
static uint16_t lc_ext_to_size(char ext)
{
  switch (ext) {
    case 'b': return EXT_BYTE;
    case 'w': return EXT_WYDE;
    case 't': return EXT_TETRA;
    case 'o':	return EXT_OCTA;
    case 'h':	return EXT_HEXI;
    case 's': return EXT_SINGLE;
    case 'd': return EXT_DOUBLE;
    case 'q': return EXT_QUAD;
  }
  return -1;
}

/* parse instruction and save extension locations */
char *parse_instruction(char *s,int *inst_len,char **ext,int *ext_len,
                        int *ext_cnt)
{
  char *inst = s;

	TRACE("pi ");
  while (*s && *s!='.' && !isspace((unsigned char)*s))
    s++;
  *inst_len = s - inst;
//  printf("inslen: %d\n", *inst_len);
  while (*s =='.' && *ext_cnt < MAX_QUALIFIERS) {
    /* extension present */
    ext[*ext_cnt] = ++s;
    while (*s && *s!='.' && !isspace((unsigned char)*s))
      s++;
    ext_len[*ext_cnt] = s - ext[*ext_cnt];
    *ext_cnt += 1;
//    printf("extlen: %d, ext:%.50s\n", *ext_len, ext[(*ext_cnt)-1]);
  }
  return (s);
}

/* fill in pointers to default qualifiers, return number of qualifiers */
int set_default_qualifiers(char **q,int *q_len)
{
	TRACE("setdq ");
  q[0] = "o";
  q_len[0] = 1;
  return (1);
}

/* check if a given value fits within a certain number of bits */
static int is_nbit(thuge val, int64_t n)
{
	thuge low, high;
  if (n > 95)
    return (1);
  low = hneg(hshl(huge_from_int(1LL), n-1LL));
  high = hshl(huge_from_int(1LL), n-1LL);
	return (hcmp(val,low) >= 0 && hcmp(val,high) < 0);
}
/*
static int is_nbit(thuge val, int64_t n)
{
	int r1, r2;
	thuge low, high;
//  if (n > 63)
//    return (1);
	low.lo = 1;
	low.hi = 0;
	low = hshl(low,(n-1LL));
	high = low;
	low = tsub(huge_zero(),low);
	low = -(1LL << (n - 1LL));
	high = (1LL << (n - 1LL));
	r1 = hcmp(val, low);
	r2 = hcmp(val, high);
	return (r1 >= 0 && r2 < 0);
}
*/
static int is_identchar(unsigned char ch)
{
	return (isalnum(ch) || ch == '_');
}

static int is_reg6(char *p, char **ep, int* typ)
{
	int nn;
	int sgn = 0;
	int n = 0;

	TRACE("is_reg6 ");
	if (ep)	
		*ep = p;
	if (p[0]=='-' || p[0]=='~') {
		sgn = 64;
		n = 1;
		while(p[n]==' ' || p[n]=='\t')
			n++;
	}
	
	for (nn = 0; nn < 64; nn++) {
		if (p[n] == regnames[nn][0] && p[n+1]== regnames[nn][1]) {
			if (!ISIDCHAR((unsigned char)p[n+2])) {
				if (regnames[nn][2]=='\0') {
					if (ep)
						*ep = &p[2];
					*typ = regop[nn];
					return (nn+sgn);
				}
				return (-1);
			}
			if (regnames[nn][2]=='\0')
				return (-1);
			if (regnames[nn][2]==p[n+2]) {
				if (!ISIDCHAR((unsigned char)p[n+3])) {
					if (regnames[nn][3]=='\0') {
						*typ = regop[nn];
						if (ep)
							*ep = &p[n+3];
						return (nn+sgn);
					}
					return (-1);
				}
				if (regnames[nn][3]=='\0')
					return (-1);
				if (regnames[nn][3]==p[n+3]) {
					if (!ISIDCHAR((unsigned char)p[n+4])) {
						if (regnames[nn][4]=='\0') {
							if (ep)
								*ep = &p[n+4];
							*typ = regop[nn];
							return (nn+sgn);
						}
						return (-1);
					}
				}
			}
		}
	}
	return (-1);	
}

/* parse a general purpose register, r0 to r63 */
static int is_reg(char *p, char **ep)
{
	int rg = -1;
	int sgn = 0;
	int n = 0;

	TRACE("is_reg ");
	*ep = p;
	if (p[0]=='-' || p[0]=='~') {
		sgn = 64;
		n = 1;
		while(p[n]==' ' || p[n]=='\t')
			n++;
	}
	/* SP */
	if ((p[n]=='s' || p[n]=='S') && (p[n+1]=='p' || p[n+1]=='P') && !ISIDCHAR((unsigned char)p[n+2])) {
		*ep = &p[n+2];
		return (63+sgn);
	}
	/* FP */
	if ((p[n]=='f' || p[n]=='F') && (p[n+1]=='p' || p[n+1]=='P') && !ISIDCHAR((unsigned char)p[n+2])) {
		*ep = &p[n+2];
		return (62+sgn);
	}
	/* GP */
	if ((p[n]=='g' || p[n]=='G') && (p[n+1]=='p' || p[n+1]=='P') && !ISIDCHAR((unsigned char)p[n+2])) {
		*ep = &p[n+2];
		return (61+sgn);
	}
	/* GP0 */
	if ((p[n]=='g' || p[n]=='G') && (p[n+1]=='p' || p[n+1]=='P') && p[n+2]=='0' && !ISIDCHAR((unsigned char)p[n+3])) {
		*ep = &p[n+3];
		return (61+sgn);
	}
	/* GP1 */
	if ((p[n]=='g' || p[n]=='G') && (p[n+1]=='p' || p[n+1]=='P') && p[n+2]=='1' && !ISIDCHAR((unsigned char)p[n+3])) {
		*ep = &p[n+3];
		return (60+sgn);
	}
	/* GP2 */
	if ((p[n]=='g' || p[n]=='G') && (p[n+1]=='p' || p[n+1]=='P') && p[n+2]=='2' && !ISIDCHAR((unsigned char)p[n+3])) {
		*ep = &p[n+3];
		return (59+sgn);
	}
	/* Argument registers 0 to 9 */
	if (p[n] == 'a' || p[n]=='A') {
		if (isdigit((unsigned char)p[n+1]) && !ISIDCHAR((unsigned char)p[n+2])) {
			rg = p[n+1]-'0';
			rg = argregs[rg];	
			*ep = &p[n+2];
			return (rg+sgn);
		}
	}
	/* Temporary registers 0 to 9 */
	if (p[n] == 't' || p[n]=='T') {
		if (isdigit((unsigned char)p[n+1]) && !ISIDCHAR((unsigned char)p[n+2])) {
			rg = p[n+1]-'0';
			rg = tmpregs[rg];
			*ep = &p[n+2];
			return (rg+sgn);
		}
	}
	if (p[n] == 't' || p[n]=='T') {
		if (isdigit((unsigned char)p[n+1]) && isdigit((unsigned char)p[n+2]) && !ISIDCHAR((unsigned char)p[n+3])) {
			rg = (p[n+1]-'0') * 10 + p[n+2]-'0';	
			if (rg < 12) {
				rg = tmpregs[rg];
				*ep = &p[n+3];
				return (rg+sgn);
			}
		}
	}
	/* Register vars 0 to 9 */
	if (p[n] == 's' || p[n]=='S') {
		if (isdigit((unsigned char)p[n+1]) && !ISIDCHAR((unsigned char)p[n+2])) {
			rg = p[n+1]-'0';	
			rg = saved_regs[rg];
			*ep = &p[n+2];
			return (rg+sgn);
		}
	}
	if (p[n] == 's' || p[n]=='S') {
		if (isdigit((unsigned char)p[n+1]) && isdigit((unsigned char)p[n+2]) && !ISIDCHAR((unsigned char)p[n+3])) {
			rg = (p[n+1]-'0') * 10 + p[n+2]-'0';	
			if (rg < 16) {
				rg = saved_regs[rg];
				*ep = &p[n+3];
				return (rg+sgn);
			}
		}
	}
	/* LC */
	if ((p[n]=='l' || p[n]=='L') && (p[n+1]=='c' || p[n+1]=='C') && !ISIDCHAR((unsigned char)p[n+2])) {
		*ep = &p[n+2];
		return (55+sgn);
	}
	if (p[n] != 'r' && p[n] != 'R') {
		return (-1);
	}
	if (isdigit((unsigned char)p[n+1]) && isdigit((unsigned char)p[n+2]) && !ISIDCHAR((unsigned char)p[n+3])) {
		rg = (p[n+1]-'0')*10 + p[n+2]-'0';
		if (rg < 64) {
			*ep = &p[n+3];
			return (rg+sgn);
		}
		return (-1);
	}
	if (isdigit((unsigned char)p[n+1]) && !ISIDCHAR((unsigned char)p[n+2])) {
		rg = p[n+1]-'0';
		*ep = &p[n+2];
		return (rg+sgn);
	}
	return (-1);
}

/* parse a vector register, v0 to v63 */
static int is_vreg(char *p, char **ep)
{
	int rg = -1;
	int sgn = 0;
	int n = 0;
	
	*ep = p;
	if (p[0]=='-' || p[0]=='~') {
		sgn = 64;
		n = 1;
		while(p[n]==' ' || p[n]=='\t')
			n++;
	}

	if (p[n] != 'v' && p[n] != 'V') {
		return (-1);
	}
	if (isdigit((unsigned char)p[n+1]) && isdigit((unsigned char)p[n+2]) && !ISIDCHAR((unsigned char)p[n+3])) {
		rg = (p[n+1]-'0')*10 + p[n+2]-'0';
		if (rg < 64) {
			*ep = &p[n+3];
			return (rg+sgn);
		}
		return (-1);
	}
	if (isdigit((unsigned char)p[n+1]) && !ISIDCHAR((unsigned char)p[n+2])) {
		rg = p[n+1]-'0';
		*ep = &p[n+2];
		return (rg+sgn);
	}
	return (-1);
}

/* parse a link register, lk0 to lk3 */
static int is_lkreg(char *p, char **ep)
{
	int rg = -1;

	*ep = p;
	if (*p != 'l' && *p != 'L') {
		return (-1);
	}
	if (p[1] != 'k' && p[1] != 'K') {
		return (-1);
	}
	if (isdigit((unsigned char)p[2]) && !ISIDCHAR((unsigned char)p[3])) {
		rg = p[2]-'0';
		if (rg < 4) {
			*ep = &p[3];
			return (rg);
		}
	}
	return (-1);
}

/* parse a code address register, ca0 to ca7 */
static int is_careg(char *p, char **ep)
{
	int rg = -1;

	*ep = p;
	/* IP */
	if ((p[0]=='I' || p[0]=='i') && (p[1]=='P' || p[1]=='p') && !ISIDCHAR((unsigned char)p[3])) {
		*ep = &p[3];
		return (7);
	}
	/* PC */
	if ((p[0]=='P' || p[0]=='p') && (p[1]=='C' || p[1]=='c') && !ISIDCHAR((unsigned char)p[3])) {
		*ep = &p[3];
		return (7);
	}
	if (*p != 'c' && *p != 'C') {
		return (-1);
	}
	if (p[1] != 'a' && p[1] != 'A') {
		return (-1);
	}
	if (isdigit((unsigned char)p[2]) && !ISIDCHAR((unsigned char)p[3])) {
		rg = p[2]-'0';
		if (rg < 8) {
			*ep = &p[3];
			return (rg);
		}
	}
	return (-1);
}

/* Parse a vector mask register, vm0 to vm7
	 The 'z' indicator follows the register number.
	 vm5z for instance indicates to zero out masked results, while
	 vm5 by itself indicates to not modify the masked result register.
*/
static int is_vmreg(char *p, char **ep)
{
	int rg = -1;
	int z = 0;

	*ep = p;
	if (*p != 'v' && *p != 'V') {
		return (-1);
	}
	if (p[1] != 'm' && p[1] != 'M') {
		return (-1);
	}
	if (isdigit((unsigned char)p[2])) {
		if (p[3]=='Z' || p[3]=='z') {
			p++;
			z = 1;
		}
		if (!ISIDCHAR((unsigned char)p[3])) {
			rg = p[2]-'0';
			if (rg < 8) {
				rg = (rg << 1) + z;
				*ep = &p[3];
				return (rg);
			}
		}
	}
	return (-1);
}

static int is_predstr(char *p, char **ep)
{
	int nn;
	int val = 0;

	if (p[0]!='"')
		return (-1);
	for (nn = 1; nn < 10; nn++) {
		switch(p[nn]) {
		case 0:
			if (ep)
				*ep = &p[nn];
			return (-1);
		case '"':
			if (ep)
				*ep = &p[nn+1];
			return (val);
		case 'I':
		case 'i':
			break;
		case 'T':
		case 't':
			val |= 1 << (nn-1)*2;
			break;
		case 'F':
		case 'f':
			val |= 2 << (nn-1)*2;
			break;
		}
	}
	return (val);	
}

static int is_vmstr(char *p, char **ep)
{
	int nn;
	int val = 0;

	if (p[0]!='"')
		return (-1);
	for (nn = 1; nn < 10; nn++) {
		switch(p[nn]) {
		case 0:
			if (ep)
				*ep = &p[nn];
			return (-1);
		case '"':
			if (ep)
				*ep = &p[nn+1];
			return (val);
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
			val |= (p[nn]-'0') << (nn-1)*3;
			break;
		}
	}
	return (val);	
}

static int is_branch(mnemonic* mnemo)
{
	switch(mnemo->ext.format) {
	case B:
	case BZ:
	case BL:
	case J:
	case JL:
	case B2:
	case BL2:
	case J2:
	case JL2:
	case J3:
	case JL3:
		return (1);
	}
	return (0);	
}

static char *parse_reloc_attr(char *p,operand *op)
{
	TRACE("prs_rel_attr");
  p = skip(p);
  while (*p == '@') {
    unsigned char chk;

    p++;
    chk = op->attr;
    if (!strncmp(p,"got",3)) {
      op->attr = REL_GOT;
      p += 3;
    }
    else if (!strncmp(p,"plt",3)) {
      op->attr = REL_PLT;
      p += 3;
    }
    else if (!strncmp(p,"sdax",4)) {
      op->attr = REL_SD;
      p += 4;
    }
    else if (!strncmp(p,"sdarx",5)) {
      op->attr = REL_SD;
      p += 5;
    }
    else if (!strncmp(p,"sdarel",6)) {
      op->attr = REL_SD;
      p += 6;
    }
    else if (!strncmp(p,"sectoff",7)) {
      op->attr = REL_SECOFF;
      p += 7;
    }
    else if (!strncmp(p,"local",5)) {
      op->attr = REL_LOCALPC;
      p += 5;
    }
    else if (!strncmp(p,"globdat",7)) {
      op->attr = REL_GLOBDAT;
      p += 7;
    }
    if (chk!=REL_NONE && chk!=op->attr)
      cpu_error(7);  /* multiple relocation attributes */
  }

  return p;
}

static char *parse_idx(char* p,operand* op, int* match)
{
	int rg, rg2, nrg, nrg2;
	int dmm;
	char *pp = p;

	TRACE("pndx ");
	if (match)
		*match = 0;	
	if (((rg = is_reg(p, &p)) >= 0) || (rg2 = is_reg6(p, &p, &dmm))) {
		op->basereg = rg >= 0 ? rg : rg2;
		p = skip(p);
		if (*p=='+') {
			p = skip(p+1);
			if (((nrg = is_reg(p, &p)) >= 0) || (nrg2 = is_reg6(p,&p, &dmm))) {
				op->ndxreg = nrg >= 0 ? nrg : nrg2;
    		p = skip(p);
    		op->type = OP_SCNDX;
    		if (*p=='*') {
    			p = skip(p+1);
    			op->scale = 1;
    		}
    		else
    			op->scale = 0;
			}
			else if ((nrg = is_vreg(p, &p)) >= 0) {
				op->ndxreg = nrg;
    		p = skip(p);
    		op->type = OP_SCNDX;
			}
			else {
				cpu_error(0);
				return (0);
			}
		}
		else {
			op->scale = 0;
			op->ndxreg = 0;
			op->type = OP_REGIND;
		}
		if (match)
			*match = pp!=p;
	}
	return (p);
}

int parse_operand(char *p,int len,operand *op,int optype)
{
	int rg, nrg, rg2, nrg2;
	int rv = PO_NOMATCH;
	char ch;
	int dmm,mtch;

	TRACE("PO ");
	op->attr = REL_NONE;

  if (!OP_DATAM(optype)) {
    p = parse_reloc_attr(p,op);

		if (optype==OP_NEXTREG) {
	    op->type = OP_REG;
	    op->basereg = 0;
	    op->value = number_expr((taddr)0);
			return (PO_NEXT);
		}
		if (optype==OP_NEXT) {
	    op->value = number_expr((taddr)0);
			return (PO_NEXT);
		}

	  p=skip(p);
	  if ((rg = is_reg6(p, &p, &op->type)) >= 0) {
	    op->basereg=rg;
	    op->value = number_expr((taddr)rg);
	  }
	  else if ((rg = is_reg(p, &p)) >= 0) {
	    op->type=OP_REG;
	    op->basereg=rg;
	    op->value = number_expr((taddr)rg);
	  }
	  else if ((rg = is_vreg(p, &p)) >= 0) {
	    op->type=OP_VREG;
	    op->basereg=rg;
	    op->value = number_expr((taddr)rg);
	  }
	  else if ((rg = is_careg(p, &p)) >= 0) {
	    op->type=OP_CAREG;
	    op->basereg=rg;
	    op->value = number_expr((taddr)rg);
	  }
	  else if ((rg = is_vmreg(p, &p)) >= 0) {
	    op->type=OP_VMREG;
	    op->basereg=rg;
	    op->value = number_expr((taddr)rg);
	  }
	  else if ((rg = is_lkreg(p, &p)) >= 0) {
	    op->type=OP_LK;
	    op->basereg=rg;
	    op->value = number_expr((taddr)rg);
	  }
	  else if ((rg = is_predstr(p, &p)) >= 0) {
	  	op->type = OP_PREDSTR;
	  	op->value = number_expr((taddr)rg);
	  }
	  else if(p[0]=='#'){
	    op->type=OP_IMM;
	    p=skip(p+1);
	    op->value=parse_expr_huge(&p);
	  }else{
	    int parent=0;
	    expr *tree;
	    op->type=-1;
	    if (*p == '[') {
	    	tree = number_expr((taddr)0);
	    }
	    else {
	    	tree=parse_expr_huge(&p);
	    	while (is_identchar(*p)) p++;
	    }
	    if(!tree)
	      return (PO_NOMATCH);
	   	op->type = OP_IMM;
	    if(*p=='['){
	      parent=1;
	      p=skip(p+1);
	    }
	    p=skip(p);
	    if(parent){
	    	p = parse_idx(p, op, &mtch);
	    	if (!mtch) {
		    	tree=parse_expr_huge(&p);
				  p = parse_reloc_attr(p,op);
	    		if (*p=='[') {
			      p=skip(p+1);
	    			p = parse_idx(p, op, &mtch);
	    			if (mtch) {
	    				op->type = OP_IND_SCNDX;
	    			}
			      if(*p!=']'){
							cpu_error(5);
							return (0);
						}
			      p=skip(p+1);
	    		}
	    	}
	      if(*p!=']'){
					cpu_error(5);
					return (0);
	      }
	      else
					p=skip(p+1);
	    }
	    op->value=tree;
	  }
		TRACE("p");
  	if(optype & op->type) {
    	return (PO_MATCH);
  	}
	}
	else {
	  op->value = OP_FLOAT(optype) ? parse_expr_float(&p) : parse_expr_huge(&p);
		op->type = optype;
		return (PO_MATCH);
	}
  return (PO_NOMATCH);
}

operand *new_operand()
{
	TRACE("newo ");
  operand *nw=mymalloc(sizeof(*nw));
  nw->type=-1;
  return nw;
}

static void fix_reloctype(dblock *db,int rtype)
{
  rlist *rl;

	TRACE("fixrel ");
  for (rl=db->relocs; rl!=NULL; rl=rl->next)
    rl->type = rtype;
}


static int get_reloc_type(operand *op)
{
  int rtype = REL_NONE;

	TRACE("grel ");
  if (OP_DATAM(op->type)) {  /* data relocs */
    return (REL_ABS);
  }

  else {  /* handle instruction relocs */
  	switch(op->format) {
  	
  	/* BEQ r1,r2,target */
  	case B:
  		if (op->number==1) {
  			rtype = REL_ABS;
  			break;
  		}
  		if (op->number > 1)
	      switch (op->attr) {
	        case REL_NONE:
	          rtype = REL_PC;
	          break;
	        case REL_PLT:
	          rtype = REL_PLTPC;
	          break;
	        case REL_LOCALPC:
	          rtype = REL_LOCALPC;
	          break;
	        case REL_ABS:
	        	rtype = REL_ABS;
	        	break;
	        default:
	          cpu_error(11);
	          break;
	      }
 			rtype = REL_PC;
      break;

		/* BEQZ r2,.target */
		/* BRA	LR1,target */
  	case BZ:
  	case BL2:
  		if (op->number > 0)
	      switch (op->attr) {
	        case REL_NONE:
	          rtype = REL_PC;
	          break;
	        case REL_PLT:
	          rtype = REL_PLTPC;
	          break;
	        case REL_LOCALPC:
	          rtype = REL_LOCALPC;
	          break;
	        case REL_ABS:
	        	rtype = REL_ABS;
	        	break;
	        default:
	          cpu_error(11);
	          break;
	      }
 			rtype = REL_PC;
      break;

		/* BRA target */		
  	case B2:
      switch (op->attr) {
        case REL_NONE:
          rtype = REL_PC;
          break;
        case REL_PLT:
          rtype = REL_PLTPC;
          break;
        case REL_LOCALPC:
          rtype = REL_LOCALPC;
          break;
        case REL_ABS:
        	rtype = REL_ABS;
        	break;
        default:
          cpu_error(11);
          break;
      }
 			rtype = REL_PC;
      break;
  		
  	/* JEQ r1,r2,target */
    case J:
    	if (op->number > 1)
	      switch (op->attr) {
	        case REL_NONE:
	          rtype = REL_ABS;
	          break;
	        case REL_PLT:
	        case REL_GLOBDAT:
	        case REL_SECOFF:
	          rtype = op->attr;
	          break;
	        default:
	          cpu_error(11); /* reloc attribute not supported by operand */
	          break;
	      }
      break;

		/* JEQ LK1,r1,r1,target */ 
    case JL:
    	if (op->number > 2)
	      switch (op->attr) {
	        case REL_NONE:
	          rtype = REL_ABS;
	          break;
	        case REL_PLT:
	        case REL_GLOBDAT:
	        case REL_SECOFF:
	          rtype = op->attr;
	          break;
	        default:
	          cpu_error(11); /* reloc attribute not supported by operand */
	          break;
	      }
      break;

		/* JMP target */
    case J2:
      switch (op->attr) {
        case REL_NONE:
          rtype = REL_ABS;
          break;
        case REL_PLT:
        case REL_GLOBDAT:
        case REL_SECOFF:
          rtype = op->attr;
          break;
        default:
          cpu_error(11); /* reloc attribute not supported by operand */
          break;
      }
      break;

		/* JMP LK1,target */
    case JL2:
    	if (op->number > 0)
	      switch (op->attr) {
	        case REL_NONE:
	          rtype = REL_ABS;
	          break;
	        case REL_PLT:
	        case REL_GLOBDAT:
	        case REL_SECOFF:
	          rtype = op->attr;
	          break;
	        default:
	          cpu_error(11); /* reloc attribute not supported by operand */
	          break;
	      }
      break;

		/* JEQZ r1,target */
    case J3:
    	if (op->number > 0)
	      switch (op->attr) {
	        case REL_NONE:
	          rtype = REL_ABS;
	          break;
	        case REL_PLT:
	        case REL_GLOBDAT:
	        case REL_SECOFF:
	          rtype = op->attr;
	          break;
	        default:
	          cpu_error(11); /* reloc attribute not supported by operand */
	          break;
	      }
      break;

		/* JEQZ LK1,r1,target */
    case JL3:
    	if (op->number > 1)
	      switch (op->attr) {
	        case REL_NONE:
	          rtype = REL_ABS;
	          break;
	        case REL_PLT:
	        case REL_GLOBDAT:
	        case REL_SECOFF:
	          rtype = op->attr;
	          break;
	        default:
	          cpu_error(11); /* reloc attribute not supported by operand */
	          break;
	      }
      break;

    default:
      switch (op->attr) {
        case REL_NONE:
          rtype = REL_ABS;
          break;
        case REL_GOT:
        case REL_PLT:
        case REL_SD:
          rtype = op->attr;
          break;
        default:
          cpu_error(11); /* reloc attribute not supported by operand */
          break;
      }
  	}
  }
  return (rtype);
}

/* create a reloc-entry when operand contains a non-constant expression */
static thuge make_reloc(int reloctype,operand *op,section *sec,
                        taddr pc,rlist **reloclist, int *constexpr)
{
  thuge val;
  thuge shl64;

	TRACE("M ");
	*constexpr = 1;
	val.lo = val.hi = 0LL;
  if (!eval_expr(op->value,&val.lo,sec,pc)) {
//  if (!eval_expr_huge(op->value,&val)) {
  	*constexpr = 0;
    /* non-constant expression requires a relocation entry */
    symbol *base;
    int btype,pos,size,disp;
    thuge addend;
    taddr mask;

		base = NULL;
    btype = find_base(op->value,&base,sec,pc);
    pos = disp = 0;

    if (btype > BASE_ILLEGAL) {
      if (btype == BASE_PCREL) {
        if (reloctype == REL_ABS)
          reloctype = REL_PC;
        else
          goto illreloc;
      }

      if (reloctype == REL_PC && !is_pc_reloc(base,sec)) {
        /* a relative branch - reloc is only needed for external reference */
				TRACE("m");
#ifdef BRANCH_PGREL				
				/* Should be relative branch, let's make sure. */
		 		if (op->format==B || op->format==B2 || op->format==BL2 || op->format==BZ) {
 					val.lo &= 0xffffffffffffc000LL;
 					val = hsub(val,huge_from_int(pc & 0xffffffffffffc000LL));
        	return (val);
      	}
#endif      	
				val = hsub(val,huge_from_int(pc));
	    	return (val);
      }

			eval_expr_huge(op->value,&val);

      /* determine reloc size, offset and mask */
      if (OP_DATAM(op->type)) {  /* data operand */
        switch (op->type) {
          case OP_D8:
            size = 8;
            break;
          case OP_D16:
            size = 16;
            break;
          case OP_D32:
          case OP_F32:
            size = 32;
            break;
          case OP_D64:
          case OP_F64:
            size = 64;
            break;
          case OP_D128:
          case OP_F128:
            size = 128;
            break;
          default:
            ierror(0);
            break;
        }
        reloctype = REL_ABS;
        addend = val;
        mask = -1;
      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           pos,size,disp,mask);
      }
      else {  /* instruction operand */
        addend = (btype == BASE_PCREL) ? hadd(val, huge_from_int(disp)) : val;
      	switch(op->format) {
      	/* Conditional jump */
      	case J:
      	case JL:
		      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           29,19,0,0x3ffffeLL);
          break;
      	/* Unconditional jump */
        case J2:
        case JL2:
		      add_extnreloc_masked(reloclist,base,val.lo,reloctype,
                           11,13,0,0x3ffeLL);
		      add_extnreloc_masked(reloclist,base,val.lo,reloctype,
                           29,19,0,0x1ffffc000LL);
          break;
				/* Short conditional jump */
      	case J3:
      	case JL3:
		      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           9,5,0,0x3eLL);
		      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           19,13,0,0x7ffc0LL);
          break;
        case RI:
        case RIS:
        case RIV:
        case RIM:
        case RIMV:
        case RTDI:
        	if (is_nbit(addend,16LL)) {
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           19,16,0,0xffffLL);
        	}	/* ToDo: fix for 31 bits and above */
        	else if (is_nbit(addend,32LL)) {
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           8,32,5,0xffffffffLL);
        	}
        	else if (is_nbit(addend,64LL)) {
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           8,32,5,0xffffffffLL);
            shl64 = hshl(addend,32LL);
			      add_extnreloc_masked(reloclist,base,shl64.lo,reloctype,
                           8,32,10,0xffffffffLL);
        	}
        	else {
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           8,32,5,0xffffffffLL);
            shl64 = hshl(addend,32LL);
			      add_extnreloc_masked(reloclist,base,shl64.lo,reloctype,
                           8,32,10,0xffffffffLL);
			      add_extnreloc_masked(reloclist,base,shl64.lo,reloctype,
                           8,32,15,0xffffffff00000000LL);
        	}
        	break;
        case DIRECT:
        	if (is_nbit(addend,14LL)) {
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           21,14,0,0x3fffLL);
        	}
        	else if (is_nbit(addend,32LL) || abits < 33) {
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           8,32,5,0xffffffffLL);
        	}
        	else if (is_nbit(addend,64LL) || abits < 65) {
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           8,32,5,0xffffffffLL);
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           8,32,10,0xffffffff00000000LL);
        	}
        	else {	// abits > 64
	          goto illreloc;
        	}
        	break;
        case REGIND:
        	if (op->basereg==sdreg) {
        		reloctype = REL_SD;
        		/*
        		if (mnemo->ext.short_opcode && is_nbit(addend,13)) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           19,13,0,0x1fffLL);
        		}
        		else
        		*/
	        	if (is_nbit(addend,14LL)) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           21,14,0,0x3fffLL);
	        	}
	        	else if (is_nbit(addend,32LL) || abits < 33) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
	        	}
	        	else if (is_nbit(addend,64LL) || abits < 65) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,10,0xffffffff00000000LL);
	        	}
	        	else {	// abits > 64
		          goto illreloc;
	        	}
        	}
        	else if (op->basereg==sd2reg) {
        		int org_sdr = sdreg;
        		sdreg = sd2reg;
        		reloctype = REL_SD;
	        	if (is_nbit(addend,14LL)) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           21,14,0,0x3fffLL);
	        	}
	        	else if (is_nbit(addend,32LL) || abits < 33) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
	        	}
	        	else if (is_nbit(addend,64LL) || abits < 65) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,10,0xffffffff00000000LL);
	        	}
	        	else {	// abits > 64
		          goto illreloc;
	        	}
						sdreg = org_sdr;        		
        	}
        	else if (op->basereg==sd3reg) {
        		int org_sdr = sdreg;
        		sdreg = sd3reg;
        		reloctype = REL_SD;
	        	if (is_nbit(addend,14LL)) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           21,14,0,0x3fffLL);
	        	}
	        	else if (is_nbit(addend,32LL) || abits < 33) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
	        	}
	        	else if (is_nbit(addend,64LL) || abits < 65) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,10,0xffffffff00000000LL);
	        	}
	        	else {	// abits > 64
		          goto illreloc;
	        	}
						sdreg = org_sdr;        		
        	}
        	else {
	        	if (is_nbit(addend,14LL)) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           21,14,0,0x3fffLL);
	        	}
	        	else if (is_nbit(addend,32LL) || abits < 33) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
	        	}
	        	else if (is_nbit(addend,64LL) || abits < 65) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,10,0xffffffff00000000LL);
	        	}
	        	else {	// abits > 64
		          goto illreloc;
	        	}
        	}
        	break;
        case SCNDX:
        case JSCNDX:
        	if (op->basereg==sdreg) {
        		reloctype = REL_SD;
        		/*
        		if (mnemo->ext.short_opcode && is_nbit(addend,13)) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           19,13,0,0x1fffLL);
        		}
        		else
        		*/
	        	if (is_nbit(addend,32LL) || abits < 33) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
	        	}
	        	else if (is_nbit(addend,64LL) || abits < 65) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,10,0xffffffff00000000LL);
	        	}
	        	else {	// abits > 64
		          goto illreloc;
	        	}
        	}
        	else if (op->basereg==sd2reg) {
        		int org_sdr = sdreg;
        		sdreg = sd2reg;
        		reloctype = REL_SD;
	        	if (is_nbit(addend,32LL) || abits < 33) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
	        	}
	        	else if (is_nbit(addend,64LL) || abits < 65) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,10,0xffffffff00000000LL);
	        	}
	        	else {	// abits > 64
		          goto illreloc;
	        	}
						sdreg = org_sdr;        		
        	}
        	else if (op->basereg==sd3reg) {
        		int org_sdr = sdreg;
        		sdreg = sd3reg;
        		reloctype = REL_SD;
	        	if (is_nbit(addend,32LL) || abits < 33) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
	        	}
	        	else if (is_nbit(addend,64LL) || abits < 65) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,10,0xffffffff00000000LL);
	        	}
	        	else {	// abits > 64
		          goto illreloc;
	        	}
						sdreg = org_sdr;        		
        	}
        	else {
	        	if (is_nbit(addend,32LL) || abits < 33) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
	        	}
	        	else if (is_nbit(addend,64LL) || abits < 65) {
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,5,0xffffffffLL);
				      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
	                           8,32,10,0xffffffff00000000LL);
	        	}
	        	else {	// abits > 64
		          goto illreloc;
	        	}
        	}
        	break;
        default:
        		/* relocation of address as data */
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                          0,63,0,0x7fffffffffffffffLL);
					;
      	}
      }
    }
    else if (btype != BASE_NONE) {
illreloc:
      general_error(38);  /* illegal relocation */
    }
  }
  else {
  	val.lo = val.hi = 0;
		eval_expr_huge(op->value,&val);
#ifdef BRANCH_PGREL 		
 		if (op->format==B || op->format==B2 || op->format==BL2 || op->format==BZ) {
 			if (reloctype == REL_PC) {
 				val.lo &= 0xffffffffffffc000LL;
 				val = hsub(val,huge_from_int(pc & 0xffffffffffffc000LL));
 			}
 			else if (reloctype==REL_ABS) {
 				val.hi = 0;
 				val.lo &= 0x3fffLL;
 			}
 		} 	
		else
#endif		
		if (reloctype == REL_PC) {
			/* a relative reference to an absolute label */
			TRACE("n");
			return hsub(val,huge_from_int(pc));
		}
  }

	TRACE("m");
  return val;
}


static void encode_reg(uint64_t* insn, operand *op, mnemonic* mnemo, int i)
{
	TRACE("enr ");
	if (insn) {
		switch(mnemo->ext.format) {
		case PRED:
			*insn = *insn | RB(op->basereg);
			break;
		case RI:
		case RII:
		case RTDI:
		case RIM:
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			else if (i==1)
				*insn = *insn| (RA(op->basereg));
			else if (i==3)
				*insn = *insn| (RC(op->basereg & 3LL));
			break;
		case RIV:
		case RIS:
		case RIMV:			
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			else if (i==2)
				*insn = *insn| (RA(op->basereg));
			break;
		case BFR3IR:
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			else if (i==1)
				*insn = *insn| (RA(op->basereg));
			if (i==3)			
				*insn = *insn| (RC(op->basereg));
			break;
		case R1:
		case BFR3II:
		case RI6:
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			break;
		case MV:
		case CSR:
		case R2:
		case R3RI:
		case BFR3RI:
		case SHIFTI:
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask));
			break;
		case RTDR:
			if (i==0)
				*insn = *insn| (RT(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask));
			else if (i==3)
				*insn = *insn| (RC(op->basereg & 3LL));
			break;
		case R4:
		case R3:
		case R3RR:
			if (i==0)
				*insn = *insn| (RT(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask));
			else if (i==3)
				*insn = *insn| (RC(op->basereg & regmask));
			break;
		case B:
			if (i==0)
				*insn = *insn| (RA(op->basereg));
			else if (i==1)
				*insn = *insn| (RB(op->basereg));
			break;			
		case BZ:
			if (i==0)
				*insn = *insn| (RA(op->basereg));
			break;			
		case BL2:
			if (i==0)
				*insn = *insn| (RB(op->basereg & 3));
			break;			
		case J:
			if (i==0)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RB(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RC(op->basereg));
			break;
		case J3:
			if (i==0)
				*insn = *insn| (RA(op->basereg & regmask));
			break;
		case BL:
		case JL:
			if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask));
			else if (i==3)
				*insn = *insn| (RC(op->basereg));
			break;
		case JL3:
			if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			break;
		case REGIND:
			if (i==0)
				*insn = *insn| (RT(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			break;
		case SCNDX:
			if (i==0)
				*insn = *insn| (RT(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask));
			break;
		case JSCNDX:
			if (i==0)
				*insn = *insn| (RA(op->basereg));
			else if (i==1)
				*insn = *insn| (RB(op->basereg));
			break;
		case DIRECT:
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			break;
		}				
	}
}

static void encode_vreg(uint64_t* insn, operand *op, mnemonic* mnemo, int i)
{
	TRACE("envr ");
	if (insn) {
		switch(mnemo->ext.format) {
		case BFR3IR:
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			if (i==3)			
				*insn = *insn| (RC(op->basereg & regmask));
			break;

		case R1:
		case BFR3II:
		case RI:
		case RIM:
		case RTDI:
		case RII:
		case RI6:
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			else if (i==1)
				*insn = *insn| (RA(op->basereg));
			else if (i==2)
				*insn = *insn| (RK(op->basereg));
			break;

		case RIV:
		case RIS:
		case RIMV:
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			else if (i==2)
				*insn = *insn| (RA(op->basereg));
			else if (i==3)
				*insn = *insn| (RK(op->basereg));
			break;

		case R2:
		case R2M:
		case RTDR:
			if (i==0)
				*insn = *insn| (RT(op->basereg)) | V(1);
			else if (i==1)
				*insn = *insn| (RA(op->basereg));
			else if (i==2)
				*insn = *insn| (RB(op->basereg)) | VB(1);
			else if (i==3)
				*insn = *insn| (RK(op->basereg));
			break;

		case MV:
		case CSR:
		case R3RI:
		case BFR3RI:
		case SHIFTI:
			if (i==0)
				*insn = *insn| (RT(op->basereg));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask));
			break;

		case R4:
		case R3:
		case R3RR:
			if (i==0)
				*insn = *insn| (RT(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask));
			else if (i==3)
				*insn = *insn| (RC(op->basereg & regmask));
			break;

		case B:
		case BZ:
		case BL2:
			break;
		case J:
			if (i==0)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RB(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RCB(op->basereg & regmask));
			break;
		case J3:
			if (i==0)
				*insn = *insn| (RA(op->basereg & regmask));
			break;
		case BL:
		case JL:
			if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask));
			else if (i==3)
				*insn = *insn| (RCB(op->basereg & regmask));
			break;
		case JL3:
			if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			break;

		case REGIND:
			if (i==0)
				*insn = *insn| (RA(op->basereg));
			else if (i==1)
				*insn = *insn| (RB(op->basereg));
			else if (i==2)
				*insn = *insn| (RK(op->basereg));
			break;
		case SCNDX:
			if (i==0)
				*insn = *insn| (RA(op->basereg));
			else if (i==1)
				*insn = *insn| (RB(op->basereg));
			else if (i==2)
				*insn = *insn| (RC(op->basereg));
			else if (i==3)
				*insn = *insn| (RK(op->basereg));
			break;
		case JSCNDX:
			if (i==0)
				*insn = *insn| (RA(op->basereg));
			else if (i==1)
				*insn = *insn| (RB(op->basereg));
			break;
		case DIRECT:
			if (i==0)
				*insn = *insn| (RA(op->basereg));
			else if (i==1)
				*insn = *insn| (RK(op->basereg));
			break;
		}				
	}
}

static void encode_reg6(uint64_t* insn, operand *op, mnemonic* mnemo, int i)
{
	TRACE("enr6 ");
	if (insn) {
		switch(mnemo->ext.format) {
		case RI64:
		case RI48:
			if (i==0)
				*insn = *insn| RT(op->basereg);
			else if (i==1)
				*insn = *insn| RA(op->basereg);
		case R3R:
			if (i==0)
				*insn = *insn| RT(op->basereg);
			else if (i==1)
				*insn = *insn| RA(op->basereg);
			else if (i==2)
				*insn = *insn| RB(op->basereg);
			else if (i==3)
				*insn = *insn| RC(op->basereg);
		}				
	}
}

static size_t encode_direct(uint64_t *insn, thuge val, thuge* postfix, size_t* pfxsize)
{
	size_t isize = 5;

	TRACE("endir ");
	*pfxsize = 0;
	*postfix = val;
	if (abits > 14) {
		isize = 10;
		*pfxsize = 4;
		*postfix = val;
	}
	if (abits > 32) {
		isize = 15;
		*pfxsize = 8;
		*postfix = val;
	}
	if (abits > 64) {
		isize = 25;
		*pfxsize = 16;
		*postfix = val;
	}
	if (insn) {
		*insn = *insn | ((val.lo & 0x3fffLL) << 21LL);
	}
	return (isize);
}

static size_t encode_immed_RI(thuge* postfix, size_t* pfxsize, uint64_t *insn, thuge hval, int i)
{
	size_t isize = 5;

	if (i==2) {
		if (insn)
			*insn = *insn | ((hval.lo & 0xffffLL) << 19LL);
		if (!is_nbit(hval,16LL)) {
			if (postfix) {
				isize = 10;
				*postfix = hval;
				*pfxsize = 4;
				if (!is_nbit(hval,32LL)) {
					isize = 15;
					*pfxsize = 8;
				}
				if (!is_nbit(hval,64LL)) {
					isize = 25;
					*pfxsize = 16;
				}
			}
		}
	}
	return (isize);
}

static size_t encode_immed(
	thuge *postfix, size_t* pfxsize,
	uint64_t *insn, mnemonic* mnemo,
	operand *op, thuge hval, int constexpr, int i, char vector)
{
	size_t isize = 5;
	thuge val, val2;

	TRACE("enimm ");
	*pfxsize = 0;
	if (mnemo->ext.format==PFX) {
		*pfxsize = 4;
		if (insn) *insn = *insn |	((hval.lo  & 0xffffffffLL) << 8LL);
		return (isize);
	}

	if (postfix) {
		(*postfix).lo = 0;
		(*postfix).hi = 0;
	}
		
	if (hval.hi & 0x80000000LL)
		hval.hi |= 0xFFFFFFFF00000000LL;

	if (mnemo->ext.flags & FLG_NEGIMM) {
		if (mnemo->ext.flags & FLG_FP)
			hval.hi ^= 0x8000000000000000LL;
		else
			hval = hneg(hval);	/* ToDo: check here for value overflow */
	}

	val = hval;
	val2 = hshr(val,32LL);
	if (constexpr) {
		if (mnemo->ext.format==DIRECT) {
			isize = encode_direct(insn, hval, postfix, pfxsize);
		}
		else if (mnemo->ext.format == CSR) {
			if (insn) {
				*insn = *insn | ((val.lo & 0xffLL) << 24LL) | (((val.lo) >> 8LL) << 33LL);
			}
		}
		else if (mnemo->ext.format == RTS) {
			if (insn)
				*insn = *insn | ((val.lo & regmask) << 11LL);
		}
		else if (mnemo->ext.format==R2) {
			if (insn) {
				if (mnemo->ext.opcode==0x5D)	// SLLH
					*insn = *insn | RB((val.lo >> 4LL) & regmask);
				else
					*insn = *insn | RB(val.lo & regmask);
			}
		}
		else if (mnemo->ext.format==R3) {
			if (i==2) {
				if (insn)
					*insn = *insn | RB(val.lo & regmask);
			}
			else if (i==3)
				if (insn)
					*insn = *insn | RC(val.lo & regmask);
		}
		else if (mnemo->ext.format==BFR3RI || mnemo->ext.format==BFR3IR || mnemo->ext.format==BFR3II) {
			if (i==2) {
				if (insn)
					*insn = *insn | BFOFFS(val.lo);
			}
			else if (i==3)
				if (insn)
					*insn = *insn | BFWID(val.lo);
		}
		else if (mnemo->ext.format==SHIFTI) {
			if (insn)
				*insn = *insn | ((val.lo & 0x7fLL) << 29LL);
		}
		else if (mnemo->ext.format==RI6) {
			if (insn)
				*insn = *insn | ((val.lo & 0x3fLL) << 19LL);
		}
		else if (mnemo->ext.format==RII) {
			if (i==2) {
				if (insn)
					*insn = *insn | ((val.lo & 0x7fLL) << 23LL);
			}
			else if (i==3) {
				if (insn)
					*insn = *insn | ((val.lo & 0x7fLL) << 30LL);
			}
		}
		else if (mnemo->ext.format==CSRI) {
			if (i==1) {
				if (insn)
					*insn = *insn | ((val.lo & 0x7fLL) << 16LL);
			}
			else if (i==2) {
				if (insn)
					*insn = *insn | ((val.lo & 0xffLL) << 23LL) | (((val.lo >> 8LL) & 0x3fLL) << 32LL);
			}
		}

		else if (mnemo->ext.format==J2) {
			if (insn)
				*insn = *insn | (((val.lo >> 1LL) & 0x1fffLL) << 11LL) | ((((val.lo >> 1LL) >> 13LL) & 0x7ffffLL) << 29LL);
		}
		else if (mnemo->ext.format==ENTER) {
			if (insn)
				*insn = *insn | ((-val.lo & 0x7fffffLL) << 9LL);
		}
		else if (mnemo->ext.format==LEAVE) {
			if (insn)
				*insn = *insn | ((val.lo & 0x7fffffLL) << 9LL);
		}
		else if (mnemo->ext.format==RIL || mnemo->ext.format==RTDI) {
			if (postfix) {
				isize = 8;
				*pfxsize = 2;
				*postfix = hval;
				if (!is_nbit(hval,16LL)) {
					isize = 10;
					*pfxsize = 4;
					*postfix = hval;
				}
				if (!is_nbit(hval,32LL)) {
					isize = 14;
					*pfxsize = 8;
				}
				if (!is_nbit(hval,64LL)) {
					isize = 22;
					*pfxsize = 16;
				}
			}
		}
		else if (mnemo->ext.format==REP) {
			if (insn) {
				if (i==0) {
					*insn |= ((hval.lo & 0x7fffLL) << 16LL);
					if (!is_nbit(hval,15LL)) {
						if (postfix) {
							isize = 8;
							*pfxsize = 2;
							*postfix = hval;
							if (!is_nbit(hval,32LL)) {
								isize = 10;
								*pfxsize = 4;
							}
							if (!is_nbit(hval,32LL)) {
								isize = 14;
								*pfxsize = 8;
							}
							if (!is_nbit(hval,64LL)) {
								isize = 22;
								*pfxsize = 16;
							}
						}
					}
				}
				else if (i==1)
					*insn |= ((val.lo & 0x7LL) << 12LL);
			}
		}
		else if (mnemo->ext.format==RI)
			isize = encode_immed_RI(postfix, pfxsize, insn, val, i);
		else {
			/*
			if (!is_nbit(hval,80)) {
				isize = (8<<16)|(8<<8)|6;
				if (modifier2)
					*modifier2 = ((hval.hi >> 16LL) << 9LL) | EXIM;
				if (modifier)
					*modifier = ((hval.hi & 0xffffLL) << 48LL) | 
						((val.lo >> 25LL) << 9LL) | EXI56 | ((val.lo >> 24LL) & 1LL);
			}
			else
			if (!is_nbit(hval,64)) {
				if (modifier)
					*modifier = ((hval.hi & 0xffffLL) << 48LL) | 
						((val.lo >> 25LL) << 9LL) | EXI56 | ((val.lo >> 24LL) & 1LL);
				isize = (8<<8)|6;
			}
			else
			*/
			if (insn)
				*insn = *insn | ((val.lo & 0xffLL) << 23LL) | (((val.lo >> 8LL) & 0x7fLL) << 33LL);
			if (!is_nbit(hval,15LL)) {
				if (postfix) {
					isize = 8;
					*pfxsize = 2;
					*postfix = hval;
					if (!is_nbit(hval,16LL)) {
						isize = 10;
						*pfxsize = 4;
					}
					if (!is_nbit(hval,32LL)) {
						isize = 14;
						*pfxsize = 8;
					}
					if (!is_nbit(hval,64LL)) {
						isize = 22;
						*pfxsize = 16;
					}
				}
			}
		}
	}
	else {
		if (mnemo->ext.format==DIRECT) {
			isize = encode_direct(insn, hval, postfix, pfxsize);
		}
		else if (mnemo->ext.format==CSRI) {
			if (i==1) {
				if (insn)
					*insn = *insn | ((val.lo & 0x7fLL) << 16);
			}
			else if (i==2) {
				if (insn)
					*insn = *insn | ((val.lo & 0xffLL) << 23LL) | (((val.lo >> 8LL) & 0x3fLL) << 32LL);
			}
		}
		else if (mnemo->ext.format==CSR) {
			cpu_error(2);
		}
		else if (mnemo->ext.format==SHIFTI) {
			if (insn)
				*insn = *insn | ((val.lo & 0x7fLL) << 24LL);
		}
		else if (mnemo->ext.format==RI6) {
			if (insn)
				*insn = *insn | ((val.lo & 0x3fLL) << 24LL);
		}
		else if (mnemo->ext.format==J2) {
			if (insn)
				*insn = *insn | (((val.lo >> 1LL) & 0x1fffLL) << 11LL) | ((((val.lo >> 1LL) >> 13LL) & 0x7ffffLL) << 29LL);
		}
		else if (mnemo->ext.format==R2) {
			if (mnemo->ext.opcode==0x5D) {	// SLLH
				if (insn)
					*insn = *insn | RB((val.lo >> 4LL) & 0x1fLL);
			}
			else {
				if (insn)
					*insn = *insn | RB(val.lo);
			}
		}
		else if (mnemo->ext.format==BFR3RI || mnemo->ext.format==BFR3IR || mnemo->ext.format==BFR3II) {
			isize = 5;
			if (i==2) {
				if (insn)
					*insn = *insn | BFOFFS(val.lo);
			}
			else if (i==3)
				if (insn)
					*insn = *insn | BFWID(val.lo);
		}
		else if (mnemo->ext.format==RI || mnemo->ext.format==RIV || mnemo->ext.format==RIS || 
			mnemo->ext.format==RIM || mnemo->ext.format==RIMV)
			isize = encode_immed_RI(postfix, pfxsize, insn, val, i);
		else if (mnemo->ext.format==RIL) {
			if (!is_nbit(hval,15LL)) {
				if (postfix) {
					isize = 8;
					*pfxsize = 2;
					*postfix = hval;
					if (!is_nbit(hval,16LL)) {
						isize = 10;
						*pfxsize = 4;
					}
					if (!is_nbit(hval,32LL)) {
						isize = 14;
						*pfxsize = 8;
					}
					if (!is_nbit(hval,64LL)) {
						isize = 22;
						*pfxsize = 16;
					}
				}
			}
		}
		else if (mnemo->ext.format==RII) {
			if (i==2) {
				if (insn)
					*insn = *insn | ((val.lo & 0x7fLL) << 23LL);
			}
			else if (i==3) {
				if (insn)
					*insn = *insn | ((val.lo & 0x7fLL) << 30LL);
			}
		}
		else if (mnemo->ext.format==REP) {
			if (insn) {
				if (i==0) {
					*insn |= ((val.lo & 0x7fffLL) << 16LL);
					if (!is_nbit(hval,15LL)) {
						if (postfix) {
							isize = 10;
							*pfxsize = 4;
							*postfix = hval;
							if (!is_nbit(hval,32LL)) {
								isize = 14;
								*pfxsize = 8;
								*postfix = hval;
							}
							if (!is_nbit(hval,64LL)) {
								isize = 22;
								*pfxsize = 16;
								*postfix = hval;
							}
						}
					}
				}
				else if (i==1)
					*insn |= ((val.lo & 0x7LL) << 12LL);
			}
		}
		else {
			if (op->type & OP_IMM) {
				if (!is_nbit(val,16LL))
					goto j2;
				if (insn)
					*insn = *insn | ((val.lo & 0xffLL) << 23LL) || (((val.lo >> 8LL) & 0xffLL) << 32LL);
				return (isize);
			}
			else {
j2:
				if (insn)
					*insn = *insn | ((val.lo & 0xffLL) << 8LL);
				if (abits > 7) {
					if (postfix) {
						isize = 8;
						*pfxsize = 2;
						*postfix = hval;
						if (abits > 16) {
							isize = 10;
							*pfxsize = 4;
							*postfix = hval;
						}
						if (abits > 32) {
							isize = 14;
							*pfxsize = 8;
							*postfix = hval;
						}
						if (abits > 64) {
							isize = 22;
							*pfxsize = 16;
							*postfix = hval;
						}
					}
				}
			}
		}
	}
	return (isize);
}

static int encode_pred(uint64_t* insn, mnemonic* mnemo, operand* op, int64_t val, int* isize, int i)
{
	*isize = 5;

	TRACE("enpred ");
	if (op->type==OP_PREDSTR) {
		if (insn) {
			*insn |= ((val & 0x7ffLL) << 16LL) | (((val >> 11LL) & 0x1fLL) << 29LL);
		}
	}	
	return (*isize);
}

static int encode_vmask(uint64_t* insn, mnemonic* mnemo, operand* op, int64_t val, int* isize, int i)
{
	*isize = 5;

	TRACE("evm ");
	if (op->type==OP_VMSTR) {
		if (insn) {
			*insn |= ((val & 0x3fffffLL) << 5LL) | (((val >> 22LL) & 0x3LL) << 29LL);
		}
	}	
	return (*isize);
}

/* Encode condional branch. */

static void encode_branch_B(uint64_t* insn, operand* op, int64_t val, int i, thuge* postfix, size_t* pfxsize)
{
	uint64_t tgt;

	if (op->type == OP_IMM) {
		switch(i) {
		case 1:
			*postfix = huge_from_int(val);
			if (postfix) {
				*pfxsize = 2;
			}
			if (!is_nbit(huge_from_int(val), 16LL)) {
				*pfxsize = 4;
			}
			if (!is_nbit(huge_from_int(val), 32LL)) {
				*pfxsize = 8;
			}
			break;
#ifdef BRANCH_PGREL			
		case 2:
			if (insn) {
  			tgt = (((val >> 14LL) & 0x3LL) << 38LL);
  			*insn |= tgt;
  			tgt = (((val >> 16LL) & 0x7LL) << 21LL);
  			*insn |= tgt;
  		}
	  	break;
	  case 3:
	  	if (insn) {
  			tgt = ((val & 0x3fffLL) << 24LL);
  			*insn |= tgt;
  		}
	  	break;
#else	  	
		case 2:
	  	if (insn) {
  			tgt = ((val & 0x1ffffLL) << 23LL);
  			*insn |= tgt;
  		}
			break;
#endif	  	
		}
	}
}

/* Encode uncondional branch, has wider target field. */

static void encode_branch_BL2(uint64_t* insn, operand* op, int64_t val, int i)
{
	uint64_t tgt;

	if (op->type == OP_IMM) {
		if (insn) {
			switch(i) {
#ifdef BRANCH_PGREL				
			case 1:
	  		tgt = (((val >> 14LL) & 0x3LL) << 38LL);
	  		*insn |= tgt;
	  		tgt |= (((val >> 17LL) & 0xfffLL) << 11LL);
	  		*insn |= tgt;
		  	break;
		  case 2:
	  		tgt = ((val & 0x3fffLL) << 23LL);
	  		*insn |= tgt;
		  	break;
#else
			case 1:
	  		tgt = ((val & 0x1ffffLL) << 23LL);
	  		*insn |= tgt;
	  		tgt |= (((val >> 17LL) & 0xfffLL) << 11LL);
	  		*insn |= tgt;
		  	break;
#endif		  
			}
		}
	}
}

/* Evaluate branch operands excepting GPRs which are handled earlier.
	Returns 1 if the branch was processed, 0 if illegal branch format.
*/
static int encode_branch(uint64_t* insn, mnemonic* mnemo, operand* op, int64_t val, int* isize, int i, thuge* postfix, size_t* pfxsize)
{
	uint64_t tgt;
	*isize = 5;

	TRACE("encb:");
	switch(mnemo->ext.format) {

	case B:
		encode_branch_B(insn, op, val, i, postfix, pfxsize);
  	return (1);

	case B2:
		encode_branch_BL2(insn, op, val, i-1);
  	return (1);

	case BZ:
		encode_branch_B(insn, op, val, i+1, postfix, pfxsize);
  	return (1);

	case BL2:
		encode_branch_BL2(insn, op, val, i);
  	return (1);

	case J:
		if (op->type == OP_IMM) {
	  	if (insn) {
	  		switch(i) {
	  		case 1:
					*insn |= RB(val>>2)|((val & 3LL) << 12);
					break;
				case 2:
		  		uint64_t tgt;
		  		*insn |= CAB(0);
		  		tgt = (((val >> 1LL) & 0x7ffffLL) << 29LL);
		  		*insn |= tgt;
		  		break;
	  		}
	  	}
	  	return (1);
		}
	  if (op->type==OP_REGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= RC(op->basereg);
	  		tgt = (((val >> 1LL) & 0x7ffffLL) << 29LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case JL:
		if (op->type == OP_IMM) {
	  	if (insn) {
	  		switch(i) {
	  		case 2:
					*insn |= RB(val>>2)|((val & 3LL) << 12);
					break;
				case 3:
		  		uint64_t tgt;
		  		*insn |= RC(0);
		  		tgt = (((val >> 1LL) & 0x7ffffLL) << 29LL);
		  		*insn |= tgt;
		  		break;
	  		}
	  	}
	  	return (1);
		}
	  if (op->type==OP_REGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= RC(op->basereg);
	  		tgt = (((val >> 1LL) & 0x7ffffLL) << 29LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  if (op->type==OP_IND_SCNDX) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= RC(op->basereg);
	  		tgt = (((val >> 1LL) & 0x7ffffLL) << 29LL);
	  		*insn |= tgt;
	  	}
	  }
	  break;

	case J2:
	  if (op->type==OP_IMM) {
	  	if (insn) {
	  		uint64_t tgt;
	  		//*insn |= CA(mnemo->ext.format==B2 ? 0x7 : 0x0);
	  		tgt = (((val >> 1LL) & 0x1fffLL) << 11LL) | (((val >> 14LL) & 0x7ffffLL) << 29LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
		}
	  if (op->type==OP_REGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= RC(op->basereg);
	    		tgt = (((val >> 1LL) & 0x1fffLL) << 11LL) | (((val >> 14LL) & 0x7ffffLL) << 29LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case JL2:
  	if (op->type==OP_IMM) {
	  	if (insn) {
    		uint64_t tgt;
    		tgt = (((val >> 1LL) & 0x1fffLL) << 11LL) | (((val >> 14LL) & 0x7ffffLL) << 29LL);
    		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  if (op->type==OP_REGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= RC(op->basereg);
	    		tgt = (((val >> 1LL) & 0x1fffLL) << 11LL) | (((val >> 14LL) & 0x7ffffLL) << 29LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case J3:
		*isize = 4;
		/*
	  if (op->type==OP_REGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(op->basereg & 0x7);
	  		tgt = (((val >> 1LL) & 0x1fLL) << 9LL) | (((val >> 6LL) & 0x1fffLL) << 19LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
		else 
		*/
		if (op->type == OP_IMM) {
			if (insn) {
				switch(i) {
				case 1:
			  	if (insn) {
			  		uint64_t tgt;
			  		tgt = (((val >> 1LL) & 0x1fLL) << 9LL) | (((val >> 6LL) & 0x1fffLL) << 19LL);
			  		*insn |= tgt;
			  	}
			  	break;
				}
			}
	  	return (1);
		}
		break;

	case JL3:
		*isize = 5;
		/*
	  if (op->type==OP_REGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(op->basereg & 0x7);
	  		tgt = (((val >> 1LL) & 0x1fLL) << 9LL) | (((val >> 6LL) & 0x1fffLL) << 19LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
		else
		*/
		if (op->type == OP_IMM) {
			if (insn) {
				switch(i) {
				case 2:
			  	if (insn) {
			  		uint64_t tgt;
			  		tgt = (((val >> 1LL) & 0x1fLL) << 9LL) | (((val >> 6LL) & 0x1fffLL) << 19LL);
			  		*insn |= tgt;
			  	}
			  	break;
				}
			}
	  	return (1);
		}
		break;

  }
  TRACE("ebv0:");
  return (0);
}

static size_t encode_scndx(
	instruction *ip,
	uint64_t* insn,
	operand* op,
	thuge val,
	int constexpr,
	thuge *postfix,
	size_t* pfxsize,
	int i,
	int pass
)
{
	size_t isize = 5;

	TRACE("Etho6:");
	if (insn) {
		if (i==0)
			*insn |= (RA(op->basereg));
		else if (i==1) {
			*insn |= (RB(op->basereg));
			/* *insn |= ((val & 0xffLL) << 21LL); */
			*insn |= RC(op->ndxreg);
			*insn |= S(op->scale);
		}
	}
	if (pass==1)
		ip->ext.const_expr = constexpr;
	if ((constexpr && pass==1) || ip->ext.const_expr) {
		/* 	db is NULL for the first encode_thor_operands 
				If there is a constant during the first pass, then it should remain the
				same during the second pass. The size of the constant will be known.
		*/
		if (val.lo != 0LL || val.hi != 0LL) {
			*pfxsize = 2;
 			*postfix = val;
 			isize = 8;
	  	if (!is_nbit(val,16) && abits > 16) {
				*pfxsize = 4;
 				isize = 10;
	  	}
	  	if (!is_nbit(val,32) && abits > 32) {
				*pfxsize = 8;
 				isize = 15;
	  	}
	  	if (!is_nbit(val,64) && abits > 64) {
				*pfxsize = 16;
	 			isize = 25;
	  	}
  	}
	}
	else {
		*pfxsize = 2;
		*postfix = val;
		isize = 8;
  	if (abits > 16) {
			*pfxsize = 4;
 			isize = 10;
  	}
  	if (abits > 32) {
			*pfxsize = 8;
 			isize = 15;
  	}
  	if (abits > 64) {
			*pfxsize = 16;
 			isize = 25;
  	}
	}
	return (isize);
}

static size_t encode_jscndx(
	instruction *ip,
	uint64_t* insn,
	operand* op,
	thuge val,
	int constexpr,
	thuge* postfix,
	size_t* pfxsize,
	int i,
	int pass
)
{
	size_t isize = 5;

	TRACE("E_jscndx:");
	if (insn) {
		if (i==1)
			*insn |= (RA(op->basereg));
		else if (i==2) {
			*insn |= (RB(op->ndxreg));
		}
	}
	if (pass==1)
		ip->ext.const_expr = constexpr;
	if ((constexpr && pass==1) || ip->ext.const_expr) {
		/* 	db is NULL for the first encode_thor_operands 
				If there is a constant during the first pass, then it should remain the
				same during the second pass. The size of the constant will be known.
		*/
		if (1 || val.lo != 0LL || val.hi != 0LL) {
			*pfxsize = 2;
			isize = 8;
 			(*postfix).lo = val.lo;
 			(*postfix).hi = val.hi;
	  	if (!is_nbit(val,16) && abits > 16) {
				*pfxsize = 4;
				isize = 10;
	  	}
	  	if (!is_nbit(val,32) && abits > 32) {
				*pfxsize = 8;
				isize = 15;
	  	}
	  	if (!is_nbit(val,64) && abits > 64) {
				*pfxsize = 16;
				isize = 25;
	  	}
  	}
	}
	else {
		*pfxsize = 2;
		(*postfix).lo = val.lo;
		(*postfix).hi = val.hi;
			isize = 8;
  	if (abits > 16) {
			*pfxsize = 4;
			isize = 10;
  	}
  	if (abits > 32) {
			*pfxsize = 8;
			isize = 15;
  	}
  	if (abits > 64) {
			*pfxsize = 16;
			isize = 25;
  	}
	}
	return (isize);
}

static size_t encode_regind(
	instruction *ip,
	uint64_t* insn,
	operand* op,
	thuge val,
	int constexpr,
	thuge *postfix,
	size_t* pfxsize,
	int i,
	int pass
)
{
	size_t isize = 5;

	TRACE("Etho5:");
	if (insn) {
		if (i==0)
			*insn |= (RA(op->basereg));
		else if (i==1) {
			*insn |= (RB(op->basereg));
			*insn |= (val.lo & 0x3fffLL) << 21LL;
		}
	}
	if (pass==1)
		ip->ext.const_expr = constexpr;
	if ((constexpr && pass==1) || ip->ext.const_expr) {
		if (!is_nbit(val,64LL)) {
			*pfxsize = 16;
			*postfix = val;
			isize = 25;
		}
		else if (!is_nbit(val,32)) {
			*pfxsize = 8;
			*postfix = val;
			isize = 15;
		}
		else if (!is_nbit(val,16)) {
			*pfxsize = 4;
			*postfix = val;
			isize = 10;
		}
		else if (!is_nbit(val,13)) {
			*pfxsize = 2;
			*postfix = val;
			isize = 8;
		}
	}
	else {
		if (abits > 64) {
			*pfxsize = 16;
			*postfix = val;
			isize = 25;
		}
		else if (abits > 32) {
			*pfxsize = 8;
			*postfix = val;
			isize = 15;
		}
		else if (abits > 16) {
			*pfxsize = 4;
			*postfix = val;
			isize = 10;
		}
		else if (abits > 13) {
			*pfxsize = 2;
			*postfix = val;
			isize = 8;
		}
	}
	return (isize);
}

/* Create additional operand for split target branches */

static void create_split_target_operands(instruction* ip, mnemonic* mnemo)
{
	switch(mnemo->ext.format) {
	case B:
		TRACE("Fmtb:");
		if (ip->op[2]) {
			ip->op[3] = new_operand();
			memcpy(ip->op[3], ip->op[2], sizeof(operand));
			ip->op[3]->number = 3;
			ip->op[3]->attr = REL_ABS;
			ip->op[3]->value = copy_tree(ip->op[2]->value);
		}
		break;
	case BZ:
	case BL2:
		TRACE("Fmtb:");
		if (ip->op[1]) {
			ip->op[2] = new_operand();
			memcpy(ip->op[2], ip->op[1], sizeof(operand));
			ip->op[2]->number = 2;
			ip->op[2]->attr = REL_ABS;
			ip->op[2]->value = copy_tree(ip->op[1]->value);
		}
		break;
	case B2:
		TRACE("Fmtb:");
		if (ip->op[0]) {
			ip->op[1] = new_operand();
			memcpy(ip->op[1], ip->op[0], sizeof(operand));
			ip->op[1]->number = 1;
			ip->op[1]->attr = REL_ABS;
			ip->op[1]->value = copy_tree(ip->op[0]->value);
		}
		break;
	}
}

// Encode any instruction qualifiers.
// These include: operation size code and cache-ability specifiers.

static void encode_qualifiers(instruction* ip, uint64_t* insn)
{
	int i, j;
	int setsz = 0;
  mnemonic *mnemo = &mnemonics[ip->code];

	TRACE("eq ");
	if (insn == NULL)
		return;
	return;
/*
	for (i = 0; ip->qualifiers[i] && i < MAX_QUALIFIERS; i++) {
//	for (i = 0; i < MAX_QUALIFIERS; i++) {
//		if (qual[i]==NULL || qual_len[i] <= 0)
//			continue;
//		printf("ip->qualifiers:%.50s\n", ip->qualifiers[i]);
		for (j = 0; j < sizeof(qualifiers_code)/sizeof(int); j++) {
			if (strnicmp(ip->qualifiers[i],qualifiers[j],7)==0) {
				if (qualifiers_code[j] & 0x80) {
					switch(mnemo->ext.format) {
					case SCNDX:
						*insn |= (uint64_t)(qualifiers_code[j] & 3) << 12LL;
						break;
					case REGIND:
					case DIRECT:
						*insn |= (uint64_t)(qualifiers_code[j] & 3) << 37LL;
						break;
					}
				}
				// else size code
				else {
					if (mnemo->ext.size != SZ_UNSIZED) {
						setsz = 1;
						if (mnemo->ext.format==SCNDX)
							*insn |= (uint64_t)(qualifiers_code[j]) << 9LL;
						else
							*insn |= (uint64_t)SZ(qualifiers_code[j]);
					}
				}
				break;
			}
		}
	}
	if (mnemo->ext.size != SZ_UNSIZED && !setsz)
		*insn |= (uint64_t)SZ(mnemo->ext.defsize);
*/
}

/* evaluate expressions and try to optimize instruction,
   return size of instruction 

   Since the instruction may contain a modifier which varies in size, both the
   size of the instruction and the size of the modifier is returned. The size
   of the instruction is in byte 0 of the return value, the size of the 
   modifier is in byte 1. The total size may be calculated using a simple
   shift and sum.
*/
size_t encode_thor_instruction(instruction *ip,section *sec,taddr pc,
  uint64_t *modifier1, uint64_t *modifier2, thuge* postfix, size_t* pfxsize,
  uint64_t *insn, dblock *db)
{
  mnemonic *mnemo = &mnemonics[ip->code];
  size_t isize = 5;
  int i;
  operand op;
	int constexpr;
	int reg = 0;
	char vector_insn = 0;
	char has_vector_mask = mnemo->ext.flags & FLG_MASK;
	thuge op1val, wval;
	char ext;
	uint64_t szcode;
	int setsz = 0;

	TRACE("Eto:");
	*pfxsize = 0;
	if (modifier1)
		*modifier1 = 0;
	if (modifier2)
		*modifier2 = 0;
	if (postfix) {
		(*postfix).lo = 0;
		(*postfix).hi = 0;
	}

//  ext = ip->qualifiers[0] ?
//             tolower((unsigned char)ip->qualifiers[0][0]) : '\0';
//  szcode = 
//	  ((mnemo->ext.size) == SZ_UNSIZED) ?
//    0 : lc_ext_to_size(ext) < 0 ? mnemo->ext.defsize : lc_ext_to_size(ext);

	//isize = mnemo->ext.len;
	/*
  if (insn != NULL) {
    *insn = mnemo->ext.opcode;
    *insn |= SZ(szcode);
   }
	*/

	isize = mnemo->ext.len;
  if (insn != NULL)
    *insn = mnemo->ext.opcode;
	encode_qualifiers(ip, insn);


	if (modifier1)
		*modifier1 = 0;

#ifdef BRANCH_PGREL
	/* Create additional operand for split target branches */
	create_split_target_operands(ip, mnemo);
#endif

	// Detect a vector instruction
  for (i=0; i<MAX_OPERANDS && ip->op[i]!=NULL; i++) {
  	if (ip->op[i]->type==OP_VREG) {
  		vector_insn = 1;
  		break;
  	}
	}

  for (i=0; i<MAX_OPERANDS && ip->op[i]!=NULL; i++) {
    operand *pop;
    int reloctype;
    taddr hval;
    thuge val;

		TRACE("F");
    op = *(ip->op[i]);
    /* reflect the format back into the operand */
    ip->op[i]->number = i;
    op.number = i;
    op.format = mnemo->ext.format;

      /* special case: operand omitted and use this operand's type + 1
         for the next operand */
    /*
    if (op.type == NEXT) {
      op = *(ip->op[++i]);
      op.type = mnemo->operand_type[i-1] + 1;
    }
	*/
		constexpr = 1;
    if ((reloctype = get_reloc_type(&op)) != REL_NONE) {
      if (db != NULL) {
        val = make_reloc(reloctype,&op,sec,pc,&db->relocs,&constexpr);
      }
      else {
      	val.lo = val.hi = 0;
        if (!eval_expr_huge(op.value,&val)){//,sec,pc)) {
#ifdef BRANCH_PGREL        	
        	if (is_branch(mnemo)) {
	          if (reloctype == REL_PC) {
	//          	hval = hsub(huge_zero(),pc);
							//val -= pc;
							val.lo &= 0xffffffffffffc000LL;
							val = hsub(val,huge_from_int(pc & 0xffffffffffffc000LL));
						}
			 			else if (reloctype==REL_ABS) {
			 				val.hi = 0;
			 				val.lo &= 0x3fffLL;
			 			}
		 			}
		 			else
#endif		 				

		 			if (is_branch(mnemo)) {
	          if (reloctype == REL_PC) {
							val = hsub(val,huge_from_int(pc));
						}		 			
		 			}
		 			
        }
      }
    }
    else {
//      if (!eval_expr(op.value,&val,sec,pc))
      if (!eval_expr_huge(op.value,&val)) {
        if (insn != NULL) {
/*	    	printf("***A4 val:%lld****", val);
          cpu_error(2);  */ /* constant integer expression required */
        }
      }
    }
  	if (is_branch(mnemo)) {
//			val = hsub(wval,huge_from_int(pc));
		}

		if (i==1) {
			op1val = val;
		}

		TRACE("Ethof:");
    if (db!=NULL && op.type==OP_REGIND && op.attr==REL_NONE) {
			TRACE("Ethof1:");
      if (op.basereg == sdreg) {  /* is it a small data reference? */
				TRACE("Ethof3:");
        fix_reloctype(db,REL_SD);
/*        else if (reg == sd2reg)*/  /* EABI small data 2 */
/*          fix_reloctype(db,REL_PPCEABI_SDA2); */
			}
    }

		TRACE("Etho2:");
		if (op.type==OP_REG) {
			encode_reg(insn, &op, mnemo, i);
		}
		else if (op.type==OP_REG6) {
			encode_reg6(insn, &op, mnemo, i);
		}
		else if (mnemo->operand_type[i]==OP_LK) {
			if (insn) {
 				switch(mnemo->ext.format) {
 				case JL:
 				case JL2:
 				case JL3:
 				case BL:
 				case RTS:
 					if (i==0)
 						*insn = *insn| RT(op.basereg);
 					break;
				default:
 					cpu_error(18);
				}				
			}
		}
		/*
    else if ((mnemo->operand_type[i]&OP_IMM7) && op.type==OP_IMM) {
 			if (!is_nbit(val, 7)) {
 				cpu_error(12,val,-64,64);
 			}
 			if (insn) {
 				switch(mnemo->ext.format) {
 				case R2:
 					if (i==2)
 						*insn = *insn| (TB(2|((val>>6) & 1))) | (RB(val & 0x3f));
 					break;
 				case R3:
 					if (i==2)
 						*insn = *insn| (TB(2|((val>>6) & 1))) | (RB(val & 0x3f));
 					else if (i==3)
 						*insn = *insn| (TC(2|((val>>6) & 1))) | (RC(val & 0x3f));
 					break;
 				case BL:
 				case JL:
 					if (i==2)
 						*insn = *insn| (TB(2|((val>>6) & 1))) | (RB(val & 0x3f));
 					break;
 				case B:
 				case J:
 					if (i==1)
 						*insn = *insn| (TB(2|((val>>6) & 1))) | (RB(val & 0x3f));
 					break;
 				}
 			}
    }
    */
    else if (((mnemo->operand_type[i])&OP_IMM) && (op.type==OP_IMM) && !is_branch(mnemo)) {
			TRACE("Etho3:");
			isize = encode_immed(postfix, pfxsize, insn, mnemo, &op, val, constexpr, i, vector_insn);
    }
    else if (encode_branch(insn, mnemo, &op, val.lo, &isize, i, postfix, pfxsize)) {
			TRACE("Etho4:");
    	;
    }
    else if (mnemo->operand_type[i]==OP_PREDSTR) {
    	encode_pred(insn, mnemo, &op, val.lo, &isize, i);
    }
    else if (mnemo->operand_type[i]==OP_VMSTR) {
    	encode_vmask(insn, mnemo, &op, val.lo, &isize, i);
    }
    else if ((mnemo->operand_type[i]&OP_REGIND)==OP_REGIND && op.type==OP_REGIND)
			isize = encode_regind(ip, insn, &op, val, constexpr, postfix, pfxsize, i, db==NULL);
    else if ((mnemo->operand_type[i]&OP_SCNDX)==OP_SCNDX && op.type==OP_SCNDX)
			isize = encode_scndx(ip, insn, &op, val, constexpr, postfix, pfxsize, i, db==NULL);
    else if ((mnemo->operand_type[i]&OP_IND_SCNDX)==OP_IND_SCNDX && op.type==OP_IND_SCNDX)
			isize = encode_jscndx(ip, insn, &op, val, constexpr, postfix, pfxsize, i, db==NULL);
	}
	
	if (has_vector_mask)
		isize = 6;	// otherwise 5
	TRACE("G");
	return (isize);
}

/* Calculate the size of the current instruction; must be identical
   to the data created by eval_instruction. */
size_t instruction_size(instruction *ip,section *sec,taddr pc)
{
	size_t pfxsize = 0;
  uint64_t modifier1, modifier2;
  thuge postfix;
  instruction* lip = NULL;
  section* lsec = NULL;
  taddr lpc = -1;

	TRACE("is "); 
	modifier1 = 0;
	modifier2 = 0;
	postfix.lo = postfix.hi = 0;
	size_t sz = 0;

	sz = encode_thor_instruction(ip,sec,pc,
		&modifier1,&modifier2,&postfix,&pfxsize,NULL,NULL
	);
	sz = sz + (modifier1 >> 48LL) + (modifier2 >> 48LL);

	if (ip->ext.size != 0) {
//		if (ip->ext.size != sz)
//			printf("size diff\n");
	}
	else
		ip->ext.size = sz;
	if (0 && sz > 80) {
		printf("mod1: %I64d\n", modifier1 >> 48LL);
		printf("mod2: %I64d\n", modifier2 >> 48LL);
		exit(21);
	}
	insn_sizes1[sz1ndx++] = sz;
	TRACE2("isize=%d ", sz);
  return (sz);
}


/* Convert an instruction into a DATA atom including relocations,
   when necessary. */
dblock *eval_instruction(instruction *ip,section *sec,taddr pc)
{
  dblock *db = new_dblock();
  uint64_t modifier1, modifier2;
  thuge postfix;
  uint64_t insn;
  size_t sz, pfxsize;

	TRACE("ei ");
	modifier1 = 0;
	modifier2 = 0;
	postfix.lo = postfix.hi = 0;
	sz = encode_thor_instruction(ip,sec,pc,&modifier1,&modifier2,
		&postfix, &pfxsize, &insn, db);
	sz = sz + (modifier1 >> 48LL) + (modifier2 >> 48LL);

//	if (sz != ip->ext.size)
//		printf("sizediff2\n");
	insn_sizes2[sz2ndx] = sz;
  if (db) {
    unsigned char *d = db->data = mymalloc(sz);
    int i;
    
    db->size = sz;

		if (modifier1 >> 48LL) {
	    d = setval(0,d,5,modifier1 & 0xffffffffffLL);
	    insn_count++;
	  }
		if (modifier2 >> 48LL) {
	    d = setval(0,d,5,modifier2 & 0xffffffffffLL);
	    insn_count++;
	  }
    d = setval(0,d,5,insn);
    insn_count++;
		switch(pfxsize) {
		case 4:	
			d = setval(0,d,1,124);
			d = setval(0,d,4,postfix.lo & 0xffffffffLL);
			insn_count++;
			break;
		case 8:	
			d = setval(0,d,1,124);
			d = setval(0,d,4,postfix.lo & 0xffffffffLL);
			d = setval(0,d,1,124);
			d = setval(0,d,4,postfix.lo >> 32LL);
			insn_count+=2;
			break;
		case 16:
			d = setval(0,d,1,124);
			d = setval(0,d,4,postfix.lo & 0xffffffffLL);
			d = setval(0,d,1,124);
			d = setval(0,d,4,postfix.lo >> 32LL);
			d = setval(0,d,1,124);
			d = setval(0,d,4,postfix.hi & 0xffffffffLL);
			d = setval(0,d,1,124);
			d = setval(0,d,4,postfix.hi >> 32LL);
			insn_count+=4;
			break;
		}
	  /*
		while (db->size < insn_sizes1[sz2ndx]) {
	    d = setval(0,d,5,0x9fLL);	// NOP
	    db->size += 5;
	    insn_count++;
		}	
		sz2ndx++;
		*/
    byte_count += db->size;
  }
  return (db);
}


/* Create a dblock (with relocs, if necessary) for size bits of data. */
dblock *eval_data(operand *op,size_t bitsize,section *sec,taddr pc)
{
  dblock *db = new_dblock();
  thuge val;
  tfloat flt;
  int constexpr = 1;

	TRACE("ed ");
  if ((bitsize & 7) || bitsize > 64)
    cpu_error(9,bitsize);  /* data size not supported */
  /*
	if (!OP_DATAM(op->type))
  	ierror(0);
	*/
  db->size = bitsize >> 3;
  db->data = mymalloc(db->size);

  if (type_of_expr(op->value) == FLT) {
    if (!eval_expr_float(op->value,&flt))
      general_error(60);  /* cannot evaluate floating point */
/*
    switch (bitsize) {
      case 32:
        conv2ieee32(0,db->data,flt);
        break;
      case 64:
        conv2ieee64(0,db->data,flt);
        break;
      default:
        cpu_error(10);
        break;
    }
*/
  }
  else {
    val = make_reloc(get_reloc_type(op),op,sec,pc,&db->relocs,&constexpr);

    switch (db->size) {
      case 1:
        db->data[0] = val.lo & 0xff;
        break;
      case 2:
      case 4:
      case 8:
        setval(0,db->data,db->size,val.lo);
        break;
      default:
        ierror(0);
        break;
    }
  }

  return db;
}

/* return true, if initialization was successfull */
int init_cpu()
{
	TRACE("icpu ");
	insn_count = 0;
	byte_count = 0;
  return (1);
}

/* To be inserted at the end of main() for debugging */

void at_end()
{
	int lmt = sz1ndx > sz2ndx ? sz2ndx : sz1ndx;
	int ndx;

	printf("Instructions: %d\n", insn_count);
	printf("Bytes: %d\n", byte_count);
	printf("%f bytes per instruction\n", (double)(byte_count)/(double)(insn_count));
	/*
	for (ndx = 0; ndx < lmt; ndx++) {
		printf("%csz1=%d, sz2=%d\n", insn_sizes1[ndx]!=insn_sizes2[ndx] ? '*' : ' ', insn_sizes1[ndx], insn_sizes2[ndx]);
	}
	*/
}
/* return true, if the passed argument is understood */
int cpu_args(char *p)
{
//	atexit(at_end);
  abits = 32;
  if (strncmp(p, "-abits=", 7)==0) {
  	abits = atoi(&p[7]);
  	if (abits < 16)
  		abits = 16;
  	else if (abits > 64)
  		abits = 64;
  	return (1);
  }
  return (0);
}

static taddr read_sdreg(char **s,taddr def)
{
  expr *tree;
  taddr val = def;

	TRACE("rdsd ");
  *s = skip(*s);
  tree = parse_expr(s);
  simplify_expr(tree);
  if (tree->type==NUM && tree->c.val>=0 && tree->c.val<=63)
    val = tree->c.val;
  else
    cpu_error(13);  /* not a valid register */
  free_expr(tree);
  return val;
}


/* parse cpu-specific directives; return pointer to end of
   cpu-specific text */
char *parse_cpu_special(char *start)
{
	TRACE("pcs ");
  char *name=start,*s=start;

  if (ISIDSTART(*s)) {
    s++;
    while (ISIDCHAR(*s))
      s++;
    if (s-name==6 && !strncmp(name,".sdreg",6)) {
      sdreg = read_sdreg(&s,sdreg);
      return s;
    }
    else if (s-name==7 && !strncmp(name,".sd2reg",7)) {
      sd2reg = read_sdreg(&s,sd2reg);
      return s;
    }
    else if (s-name==7 && !strncmp(name,".sd3reg",7)) {
      sd3reg = read_sdreg(&s,sd3reg);
      return s;
    }
  }
  return start;
}

void init_instruction_ext(instruction_ext *ext)
{
	TRACE("iie ");
	if (ext) {
		ext->size = 0;
		ext->postfix_count = 0;
		ext->const_expr = 0;
	}
}