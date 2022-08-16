#include "vasm.h"

#define TRACE(x)		/*printf(x)*/
#define TRACE2(x,y)	/*printf((x),(y))*/

char *cpu_copyright="vasm Thor cpu backend (c) in 2021-2022 Robert Finch";

char *cpuname="Thor";
int bitsperbyte=8;
int bytespertaddr=8;
int abits=32;
static taddr sdreg = 29;
static taddr sd2reg = 28;
static taddr sd3reg = 27;
static __int64 regmask = 0x1fLL;

static insn_count = 0;
static byte_count = 0;

static insn_sizes1[20000];
static insn_sizes2[20000];
static int sz1ndx = 0;
static int sz2ndx = 0;
static short int argregs[10] = {3,4,20,21,22,23,24,25,-1,-1};
static short int tmpregs[10] = {5,6,7,8,9,10,11,-1,-1};
static short int saved_regs[10] = {12,13,14,15,16,17,18,19,-1,-1};

mnemonic mnemonics[]={
	"abs",	{OP_REG,OP_REG,0,0,0}, {R3RR,CPU_ALL,0,0x0C000001LL,4},

	"add", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x080000000102LL,6},
	"add", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x080000000102LL,6},
	"add", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D4LL,6},
	"add", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x080000000002LL,6},	
	"add", {OP_REG,OP_REG,OP_IMM,OP_REG,0}, {R3IR,CPU_ALL,0,0x080000000002LL,6},	
	"add", {OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x080000000002LL,6},	
	"add", {OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {R3II,CPU_ALL,0,0x080000000002LL,6},	
	"add", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x19LL,4},	
	"add", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD4LL,6,0x04LL,4},

	"and", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x100000000102LL,6},	
	"and", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x100000000102LL,6},	
	"and", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D8LL,6},
	"and", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x100000000002LL,6},	
	"and", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x1ALL,4},	
	"and", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD8LL,6,0x08LL,4},

	"andc", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x160000000102LL,6},	
	"andc", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x160000000102LL,6},	
	"andc", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x160000000002LL,6},	
	"andn", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x160000000102LL,6},	
	"andn", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x160000000102LL,6},	
	"andn", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x160000000002LL,6},	

	"bcdadd", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x0000000000F5LL,6},	
	"bcdmul", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x0400000000F5LL,6},	
	"bcdsub", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x0200000000F5LL,6},	
	
	"bfalign",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {BFR3RR,CPU_ALL,0,0x0000000000AALL,6},
	"bfchg",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {BFR3RR,CPU_ALL,0,0x1400000000AALL,6},
	"bfchg",	{OP_REG,OP_REG,OP_IMM,OP_REG,0}, {BFR3IR,CPU_ALL,0,0x1400200000AALL,6},
	"bfchg",	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {BFR3RI,CPU_ALL,0,0x1401000000AALL,6},
	"bfchg",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,0x1401200000AALL,6},
	"bfclr",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,0x1601200000AALL,6},
	"bfext",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {BFR3RR,CPU_ALL,0,0x0A00000000AALL,6},
	"bfext",	{OP_REG,OP_REG,OP_IMM,OP_REG,0}, {BFR3IR,CPU_ALL,0,0x0A00200000AALL,6},
	"bfext",	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {BFR3RI,CPU_ALL,0,0x0A01000000AALL,6},
	"bfext",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,0x0A01200000AALL,6},
	"bfextu",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,0x0801200000AALL,6},
	"bfffo",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,0x0201200000AALL,6},
	"bfset",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,0x1801200000AALL,6},

	"bmap", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x00000000004CLL,6},	
	"bmm", 	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x600000000002LL,6},	

	"bbc",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F000025LL,6},
	"bbc",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F000025LL,6},
	"bbs",	{OP_LK,OP_REG,OP_REG,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F000825LL,6},
	"bbs",	{OP_LK,OP_REG,OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F000822LL,6},
	"bbs",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F000822LL,6},
	"beq",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F000026LL,6},
	"beq",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F000026LL,6},
//	"beqz",	{OP_LK,OP_REG,OP_IMM,0,0}, {BL3,CPU_ALL,0,0xE0000010LL,4},
	"beqz",	{OP_REG,OP_IMM,0,0,0}, {B3,CPU_ALL,0,0x00000010LL,4},
	"bge",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F000029LL,6},
	"bge",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F000029LL,6},
	"bgt",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F00002BLL,6},
	"bgt",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F00002BLL,6},
	"ble",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F00002ALL,6},
	"ble",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F00002ALL,6},
	"blt",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F000028LL,6},
	"blt",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F000028LL,6},
	"bgeu",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F002029LL,6},
	"bgeu",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F002029LL,6},
	"bgtu",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F00202BLL,6},
	"bgtu",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F00202BLL,6},
	"bleu",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F00202ALL,6},
	"bleu",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F00202ALL,6},
	"bltu",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F002028LL,6},
	"bltu",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F002028LL,6},
	"bne",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_IMM,0}, {BL,CPU_ALL,0,0x00001F000027LL,6},
	"bne",	{OP_REG,OP_REG|OP_IMM,OP_IMM,0,0}, {B,CPU_ALL,0,0x00001F000027LL,6},
//	"bnez",	{OP_LK,OP_REG,OP_IMM,0,0}, {BL3,CPU_ALL,0,0xE0000012LL,4},
	"bnez",	{OP_REG,OP_IMM,0,0,0}, {B3,CPU_ALL,0,0x00000012LL,4},

	"bra",	{OP_IMM,0,0,0,0}, {B2,CPU_ALL,0,0x0000E0000020LL,6,0x00000023LL,4},
	"brk",	{0,0,0,0,0}, {R1,CPU_ALL,0,0x00,2},
	"bsr",	{OP_LK,OP_IMM,0,0,0}, {BL2,CPU_ALL,0,0x0000E0000020LL,6,0x00000023LL,4},
	"bsr",	{OP_IMM,0,0,0,0}, {B2,CPU_ALL,0,0x0000E0000220LL,6,0x00000223LL,4},

	"bytndx", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0xAA0000000002LL,6},	
	"bytndx", 	{OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0x00000055LL,4},

	"chk", 	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x320000000002LL,6},	
	"chk", 	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3,CPU_ALL,0,0x000000000045LL,6},	

	"clmul", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x5C0000000002LL,6},	
	"clmulh", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x5E0000000002LL,6},	

	"cmovnz", 	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x5A0000000002LL,6},	

	"cmp", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x540000000102LL,6},	
	"cmp", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x540000000102LL,6},	
	"cmp", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x0000000CLL,4},	
	"cmp", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD0LL,6,0x0BLL,4},
	
	"cmpu", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x560000000102LL,6},	
	"cmpu", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x560000000102LL,6},	
	"cmpu", {OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x560000000002LL,6},	
	"cmpu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD1LL,6},
	
	"cntlz", {OP_VREG,OP_VREG,0,0,0}, {R1,CPU_ALL,0,0x00000101,4},
	"cntlz", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x00000001,4},
	"cntpop", {OP_VREG,OP_VREG,0,0,0}, {R1,CPU_ALL,0,0x04000101,4},
	"cntpop", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x04000001,4},

	"com",	{OP_VREG,OP_VREG,0,0,0}, {R3II,CPU_ALL,0,0x1417F00001AALL,6},
	"com", {OP_REG,OP_REG,0,0,0}, {RIL,CPU_ALL,0,0xFFFFFFF800DALL,6,0xFFF8000ALL,4},

	"cpuid", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x41LL,4},
	
	"csrrd", {OP_REG,OP_REG,OP_IMM,0,0}, {CSR,CPU_ALL,0,0x00000000000FLL,6},
	"csrrw", {OP_REG,OP_REG,OP_IMM,0,0}, {CSR,CPU_ALL,0,0x02000000000FLL,6},

	"dbra",	{OP_IMM,0,0,0,0},{B2,CPU_ALL,0,0x00001F000021LL,6},
	"dbra",	{OP_LK,OP_IMM,0,0,0},{BL2,CPU_ALL,0,0x00001F000021LL,6},

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

	"eor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM,OP_VREG|OP_REG|OP_IMM,0}, {R3,CPU_ALL,0,0x140000000102LL,6},	
	"eor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM,OP_VREG|OP_REG|OP_IMM,OP_VMREG}, {R3,CPU_ALL,0,0x140000000102LL,6},	
	"eor", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1DALL,6},
	"eor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x140000000002LL,6},	
	"eor", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x1ELL,4},	
	"eor", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xDALL,6,0x0ALL,4},

	"enor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM,OP_VREG|OP_REG|OP_IMM,0}, {R3,CPU_ALL,0,0x040000000102LL,6},	
	"enor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM,OP_VREG|OP_REG|OP_IMM,OP_VMREG}, {R3,CPU_ALL,0,0x040000000102LL,6},	
	"enor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x040000000002LL,6},	
	
	"enter", {OP_IMM,0,0,0,0}, {ENTER,CPU_ALL,0,0xAFLL,4},
	"exi56", {OP_IMM,0,0,0,0}, {EXI56F,CPU_ALL,0,0x4CLL,8},
	"exim", {OP_IMM,0,0,0,0}, {EXI56F,CPU_ALL,0,0x50LL,8},

	"ext",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {BFR3RR,CPU_ALL,0,0x0A00000000AALL,6},
	"ext",	{OP_REG,OP_REG,OP_IMM,OP_REG,0}, {BFR3IR,CPU_ALL,0,0x0A00200000AALL,6},
	"ext",	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {BFR3RI,CPU_ALL,0,0x0A01000000AALL,6},
	"ext",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,0x0A01200000AALL,6},
	"extu",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {BFR3RR,CPU_ALL,0,0x0800000000AALL,6},
	"extu",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {BFR3II,CPU_ALL,0,0x0801200000AALL,6},

	"int",	{OP_IMM,OP_IMM,0,0,0}, {INT,CPU_ALL,0,0xA6LL,4},

	"jeq",	{OP_LK,OP_REG,OP_REG,OP_REGIND,0}, {JL,CPU_ALL,0,0x000000000026LL,6},
	"jeq",	{OP_REG,OP_REG,OP_REGIND,0,0}, {J,CPU_ALL,0,0x000000000026LL,6},
//	"jeqz",	{OP_LK,OP_REG,OP_IMM,0,0}, {JL3,CPU_ALL,0,0x00000010LL,4},
	"jeqz",	{OP_REG,OP_IMM,0,0,0}, {J3,CPU_ALL,0,0x00000010LL,4},
	"jge",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_REGIND,0}, {JL,CPU_ALL,0,0x000000000029LL,6},
	"jge",	{OP_REG,OP_REG|OP_IMM,OP_REGIND,0,0}, {J,CPU_ALL,0,0x000000000029LL,6},
	"jgt",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_REGIND,0}, {JL,CPU_ALL,0,0x00000000002BLL,6},
	"jgt",	{OP_REG,OP_REG|OP_IMM,OP_REGIND,0,0}, {J,CPU_ALL,0,0x00000000002BLL,6},
	"jle",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_REGIND,0}, {JL,CPU_ALL,0,0x00000000002ALL,6},
	"jle",	{OP_REG,OP_REG|OP_IMM,OP_REGIND,0,0}, {J,CPU_ALL,0,0x00000000002ALL,6},
	"jlt",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_REGIND,0}, {JL,CPU_ALL,0,0x000000000028LL,6},
	"jlt",	{OP_REG,OP_REG|OP_IMM,OP_REGIND,0,0}, {J,CPU_ALL,0,0x000000000028LL,6},
	"jgeu",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_REGIND,0}, {JL,CPU_ALL,0,0x00000000002DLL,6},
	"jgeu",	{OP_REG,OP_REG|OP_IMM,OP_REGIND,0,0}, {J,CPU_ALL,0,0x00000000002DLL,6},
	"jgtu",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_REGIND,0}, {JL,CPU_ALL,0,0x00000000002FLL,6},
	"jgtu",	{OP_REG,OP_REG|OP_IMM,OP_REGIND,0,0}, {J,CPU_ALL,0,0x00000000002FLL,6},
	"jleu",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_REGIND,0}, {JL,CPU_ALL,0,0x00000000002ELL,6},
	"jleu",	{OP_REG,OP_REG|OP_IMM,OP_REGIND,0,0}, {J,CPU_ALL,0,0x00000000002ELL,6},
	"jltu",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_REGIND,0}, {JL,CPU_ALL,0,0x00000000002CLL,6},
	"jltu",	{OP_REG,OP_REG|OP_IMM,OP_REGIND,0,0}, {J,CPU_ALL,0,0x00000000002CLL,6},
	"jne",	{OP_LK,OP_REG,OP_REG|OP_IMM,OP_REGIND,0}, {JL,CPU_ALL,0,0x000000000027LL,6},
	"jne",	{OP_REG,OP_REG|OP_IMM,OP_REGIND,0,0}, {J,CPU_ALL,0,0x000000000027LL,6},
//	"jnez",	{OP_LK,OP_REG,OP_IMM,0,0}, {JL3,CPU_ALL,0,0x00000012LL,4},
	"jnez",	{OP_REG,OP_IMM,0,0,0}, {J3,CPU_ALL,0,0x00000012LL,4},

	"jmp",	{OP_REGIND,0,0,0,0}, {J2,CPU_ALL,0,0x00000020LL,6},
	"jmp",	{OP_IMM,0,0,0,0}, {J2,CPU_ALL,0,0x00000020LL,6},
	"jsr",	{OP_LK,OP_REGIND,0,0,0}, {JL2,CPU_ALL,0,0x00000020LL,6},
	"jsr",	{OP_LK,OP_IMM,0,0,0}, {JL2,CPU_ALL,0,0x00000020LL,6},
	"jsr",	{OP_IMM,0,0,0,0}, {J2,CPU_ALL,0,0x00000220LL,6},

	"ldi", {OP_REG,OP_NEXTREG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD4LL,6,0x04LL,4},

	"ldb",	{OP_REG,OP_IMM,0,0}, {DIRECT,CPU_ALL,0,0x80LL,6,0x78,4},	
	"ldb",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x80LL,6,0x78,4},	
	"ldb",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB0LL,4},	
	"ldb",	{OP_VREG,OP_SCNDX,OP_VMREG,0,0}, {SCNDX,CPU_ALL,0,0x1B0LL,4},	
	"ldbu",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x81LL,6,0x79,4},	
	"ldbu",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB1LL,4},	
	"ldbu",	{OP_VREG,OP_SCNDX,OP_VMREG,0,0}, {SCNDX,CPU_ALL,0,0x1B1LL,4},	
	"ldbus",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0x79,4},	
//	"ldo",	{OP_REG,OP_SEL|OP_REGIND8,0,0,0}, {REGIND,CPU_ALL,0,0x87LL,4},	
	"ldh",	{OP_REG,OP_SEL|OP_IMM,0,0}, {DIRECT,CPU_ALL,0,0x88LL,6,0x89LL,4},
	"ldh",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x88LL,6,0x89LL,4},	
	"ldh",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB8LL,4},	
	"ldhp",	{OP_REG,OP_IMM,0,0}, {DIRECT,CPU_ALL,0,0x8ALL,6},
	"ldhp",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x8ALL,6},	
	"ldhp",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xBALL,4},	
	"ldhs",	{OP_REG,OP_SEL|OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0x89LL,4,0x89LL,4},
	"ldhs",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x89LL,4,0x89LL,4},	
	
	"ldo",	{OP_REG,OP_SEL|OP_IMM,0,0}, {DIRECT,CPU_ALL,0,0x86LL},
	"ldo",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x86LL,6},	
	"ldo",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB6LL,4},	
	"ldou",	{OP_REG,OP_SEL|OP_IMM,0,0}, {DIRECT,CPU_ALL,0,0x87LL},
	"ldou",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x87LL,6},	
	"ldou",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB7LL,4},	
	
	"ldptg",	{OP_REG,OP_REG,0,0,0},{R3RR,CPU_ALL,0,0x480000000007LL,6},	

	"ldt",	{OP_REG,OP_SEL|OP_IMM,0,0}, {DIRECT,CPU_ALL,0,0x84LL,6},	
	"ldt",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x84LL,6},	
	"ldt",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB4LL,4},	

	"ldtu",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x85LL,6},	
	"ldtu",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB5LL,4},	
	"ldw",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x82LL,6,0x7A,4},	
	"ldw",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB2LL,4},	
	"ldwu",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x83LL,6,0x7B,4},	
	"ldwu",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB3LL,4},	

	"lea",	{OP_REG,OP_IMM,0,0}, {DIRECT,CPU_ALL,0,0xD4LL,6,0x04,4},
	"lea",	{OP_REG,OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0xD4LL,6,0x04,4},
	"lea",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0x19LL,4},	

	"leave", {OP_IMM,0,0,0,0}, {LEAVE,CPU_ALL,0,0xBFLL,4},

	"max",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x520000000002LL,6},	
	"memdb",	{0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF9,2},
	"memsb",	{0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF8,2},
	"mflk",		{OP_LK,OP_REG,0,0,0}, {MFLK,CPU_ALL,0,0x5ELL,2},
	"mflk",		{OP_REG,OP_LK,0,0,0}, {MFLK,CPU_ALL,0,0x5ELL,2},
	"mfsel",	{OP_REG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x500000000007LL,6},	
	"mfsel",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x500000000007LL,6},	
	"min",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x500000000002LL,6},	

	"mov", {OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x13LL,4},	
	"move", {OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x13LL,4},	
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
	"mtlk",		{OP_LK,OP_REG,0,0,0}, {MTLK,CPU_ALL,0,0x5FLL,2},

	"mtsel",	{OP_REG,OP_IMM,0,0,0},{MTSEL,CPU_ALL,0,0x520000000007LL,6},	
	"mtsel",	{OP_REG,OP_REG,0,0,0},{MTSEL,CPU_ALL,0,0x520000000007LL,6},	

	"mul", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D2LL,6},	
	"mul", {OP_VREG,OP_VREG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x1D2LL,6},
	"mul", {OP_VREG,OP_VREG,OP_VREG,OP_VMREG,0}, {R3,CPU_ALL,0,0x0C0000000102LL,6},	
	"mul", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x0C0000000102LL,6},	
	"mul", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x0C0000000002LL,6},	
	"mul", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD2,6,0x06LL,4},
	"muladd", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x0C0000000002LL,6},	

	"mulf", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x2A0000000002LL,6},	
	"mulf", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0x15LL,4},

	"mulh", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x1E0000000002LL,6},	

	"mulu", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x1C0000000002LL,6},	
	"mulu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xDE,6,0x0ELL,4},

	"mux",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x680000000002LL,6},	

	"nand", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x000000000102LL,6},	
	"nand", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x000000000102LL,6},	
	"nand", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x000000000002LL,6},	

	"neg", {OP_REG,OP_NEXTREG,OP_REG,0,0}, {R2,CPU_ALL,0,0x0000000DLL,4},	
//	"neg",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A000001LL,4},

	"nop",	{0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF1,2},

	"nor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x020000000102LL,6},	
	"nor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x020000000102LL,6},	
	"nor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x020000000002LL,6},	
	"not", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x08000001LL,4},

	"or", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x120000000102LL,6},	
	"or", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x120000000102LL,6},	
	"or", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D9LL,6},
	"or", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x120000000002LL,6},	
	"or", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x13LL,4},	
	"or", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD9LL,6,0x09LL,4},

	"orc", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x060000000102LL,6},	
	"orc", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x060000000102LL,6},	
	"orc", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x060000000002LL,6},	
	"orn", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x060000000102LL,6},	
	"orn", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x060000000102LL,6},	
	"orn", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x060000000002LL,6},	

	"peekq",	{OP_REG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x140000000007LL,6},	
	"peekq",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x140000000007LL,6},	

	"pfi",	{OP_REG,0,0,0,0},{R3RR,CPU_ALL,0,0x220000000007LL,6},	

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

	"resetq",	{OP_NEXTREG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x180000000007LL,6},	
	"resetq",	{OP_NEXTREG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x180000000007LL,6},	

	"revbit",	{OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x50000001LL,4},

	"ret",	{OP_LK,OP_IMM,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"ret",	{OP_LK,0,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"ret",	{0,0,0,0,0}, {RTS,CPU_ALL,0,0x02F2LL, 2},

	"rex",	{OP_IMM,OP_REG,0,0,0},{REX,CPU_ALL,0,0x200000000007LL,6},	

	"rte",	{OP_IMM,OP_REG,0,0,0},{RTE,CPU_ALL,0,0x260000000007LL,6},	

	"rol",	{OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x860000000002LL,6},	
	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x860000000002LL,6},	
	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x860000000002LL,6},	
	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x860000000002LL,6},	
	"rol",	{OP_REG,OP_REG,OP_IMM,0,0}, {SHIFTI,CPU_ALL,0,0x860000000002LL,6},
	"rol",	{OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x5B,4},

	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x880000000002LL,6},	
	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x880000000002LL,6},	
	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x880000000002LL,6},	
	"ror",	{OP_REG,OP_REG,OP_IMM,0,0}, {SHIFTI,CPU_ALL,0,0x880000000002LL,6},
	"ror",	{OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x5C,4},
	
	"rti",	{OP_IMM,0,0,0,0}, {RTS,CPU_ALL,0,0x00F0LL, 2},
	"rti",	{0,0,0,0,0}, {RTS,CPU_ALL,0,0x00F0LL, 2},

	"rts",	{OP_LK,OP_IMM,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"rts",	{OP_LK,0,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"rts",	{0,0,0,0,0}, {RTS,CPU_ALL,0,0x02F2LL, 2},

	"sei",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x2E0000000007LL,6},	

	"seq", {OP_VREG,OP_VREG,OP_VREG,OP_VMREG,0}, {R3,CPU_ALL,0,0x4C0000000102LL,6},	
	"seq", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x4C0000000102LL,6},	
	"seq", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D6LL,6},
	"seq", {OP_VREG,OP_VREG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x1D6LL,6},
//	"seq", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x4C0000000002LL,6},	
//	"seq", {OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x4C0000000002LL,6},	
	"seq", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x44,4},
	"seq", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD6LL,6,0x16,4},

	"sge", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x420000000102LL,6},	
	"sge", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x420000000002LL,6},	
//	"sge", {OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x420000000002LL,6},	
	"sge", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x5DLL,6,0x60,4},	
	"sgeu", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x460000000102LL,6},	
	"sgeu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xE7LL,6},	
	"sgeu", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x460000000002LL,6},	

	"sgt", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xDBLL,6,0x1BLL,4},
	"sgtu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xDFLL,6,0x1FLL,4},
	"sle", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD1LL,6,0x68,4},	
	"sleu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xE6LL,6},	
	"slt", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD3LL,6,0x18LL,4},
	"slt", {OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0xD3LL,6},
	"slt", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0xD3LL,6},
	"slt", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x4ELL,4},	
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
	"sne", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x45,4},
	"sne", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD7LL,6,0x17,4},

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

	"stb",	{OP_REG,OP_SEL|OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0x90LL,6},	
	"stb",	{OP_REG,OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x90LL,6,0xCALL,4},	
	"stb",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC0LL,4},	
	"sth",	{OP_REG,OP_SEL|OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0x94LL,6,0x95LL,4},	
	"sth",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x94LL,6,0x95LL,4},	
	"sth",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC4LL,4},	
	"sthp",	{OP_REG,OP_SEL|OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0x97LL,6},	
	"sthp",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x97LL,6},	
	"sthp",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC7LL,4},	
	"sths",	{OP_REG,OP_SEL|OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0x95LL,4,0x95LL,4},
	"sths",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x95LL,4,0x95LL,4},	
	"sto",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0x93LL,6,0x95LL,4},	
	"sto",	{OP_REG,OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x93LL,6,0xCDLL,4},	
	"sto",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC3LL,4},	
	"stptg",	{OP_REG,OP_REG,OP_REG,OP_REG,0},{R3RR,CPU_ALL,0,0x4A0000000007LL,6},	
	"stt",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0x92LL,6},	
	"stt",	{OP_REG,OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x92LL,6,0xCCLL,4},	
	"stt",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC2LL,4},	
	"stw",	{OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0x91LL,6},	
	"stw",	{OP_REG,OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x91LL,6,0xCBLL,4},	
	"stw",	{OP_REG,OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC1LL,4},	

	"sub", {OP_REG,OP_REG,OP_REG|OP_IMM,OP_REG|OP_IMM,OP_VMREG}, {R3,CPU_ALL,0,0x0A0000000002LL,6},	
	"sub", {OP_REG,OP_REG,OP_REG|OP_IMM,OP_REG|OP_IMM,0}, {R3,CPU_ALL,0,0x0A0000000002LL,6},	
	"sub", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM,OP_VREG|OP_REG|OP_IMM,0}, {R3,CPU_ALL,0,0x0A0000000102LL,6},	
	"sub", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM,OP_VREG|OP_REG|OP_IMM,OP_VMREG}, {R3,CPU_ALL,0,0x0A0000000102LL,6},	
	"sub", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x0000000DLL,4},	
	"sub", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD4LL,6,0x04LL,4,FLG_NEGIMM},

	"subf", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D5LL,6},
	"subf", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD5LL,6},
/* 0000_1010_0001_0001_1111_0000_0000_0000_0000_0000_AALL */

	"sxb",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A120E0000AALL,6},	
	"sxc",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A121E0000AALL,6},	/* alternate mnemonic for sxw */
	"sxo",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A123E0000AALL,6},
	"sxw",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A121E0000AALL,6},
	"sxt",	{OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A123E0000AALL,6},

	"sync", {0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF7LL,2},
	"sys",	{OP_IMM,0,0,0,0}, {BITS32,CPU_ALL,0,0xA5,4},

	"tlbrw",	{OP_REG,OP_REG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x3C0000000007LL,6},	

	"utf21ndx", 	{OP_REG,OP_VREG,OP_REG,0,0}, {R3,CPU_ALL,0,0x380000000102LL,6},	
	"utf21ndx", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x380000000002LL,6},	
	"utf21ndx", 	{OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x57LL,6},	

	"wfi", {0,0,0,0,0}, {BITS16,CPU_ALL,0,0xFALL,2},

	"wydendx", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x360000000002LL,6},	
	"wydendx", 	{OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x56LL,6},	

	/* Alternate mnemonic for enor */
	"xnor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x040000000102LL,6},	
	"xnor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x040000000102LL,6},	
	"xnor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x040000000002LL,6},	

	/* Alternate mnemonic for eor */
	"xor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x140000000102LL,6},	
	"xor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x140000000102LL,6},	
	"xor", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1DALL,6},
	"xor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x140000000002LL,6},	
	"xor", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x1ELL,4},	
	"xor", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xDALL,6,0x0ALL,4},

};

int mnemonic_cnt=sizeof(mnemonics)/sizeof(mnemonics[0]);

int thor_data_operand(int n)
{
  if (n&OPSZ_FLOAT) return OPSZ_BITS(n)>32?OP_F64:OP_F32;
  if (OPSZ_BITS(n)<=8) return OP_D8;
  if (OPSZ_BITS(n)<=16) return OP_D16;
  if (OPSZ_BITS(n)<=32) return OP_D32;
  return OP_D64;
}

/* parse instruction and save extension locations */
char *parse_instruction(char *s,int *inst_len,char **ext,int *ext_len,
                        int *ext_cnt)
{
  char *inst = s;

  while (*s && *s!='.' && !isspace((unsigned char)*s))
    s++;
  *inst_len = s - inst;
  if (*s =='.') {
    /* extension present */
    ext[*ext_cnt] = ++s;
    while (*s && *s!='.' && !isspace((unsigned char)*s))
      s++;
    ext_len[*ext_cnt] = s - ext[*ext_cnt];
    *ext_cnt += 1;
  }
  return (s);
}

/* fill in pointers to default qualifiers, return number of qualifiers */
int set_default_qualifiers(char **q,int *q_len)
{
  q[0] = "o";
  q_len[0] = 1;
  return (1);
}

/* check if a given value fits within a certain number of bits */
static int is_nbit(int64_t val, int64_t n)
{
	int64_t low, high;
  if (n > 63)
    return (1);
	low = -(1LL << (n - 1LL));
	high = (1LL << (n - 1LL));
	return (val >= low && val < high);
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

/* parse a general purpose register, r0 to r63 */
static int is_reg(char *p, char **ep)
{
	int rg = -1;
	
	*ep = p;
	/* SP */
	if ((p[0]=='s' || p[0]=='S') && (p[1]=='p' || p[1]=='P') && !ISIDCHAR((unsigned char)p[2])) {
		*ep = &p[2];
		return (31);
	}
	/* FP */
	if ((p[0]=='f' || p[0]=='F') && (p[1]=='p' || p[1]=='P') && !ISIDCHAR((unsigned char)p[2])) {
		*ep = &p[2];
		return (30);
	}
	/* GP */
	if ((p[0]=='g' || p[0]=='G') && (p[1]=='p' || p[1]=='P') && !ISIDCHAR((unsigned char)p[2])) {
		*ep = &p[2];
		return (29);
	}
	/* GP1 */
	if ((p[0]=='g' || p[0]=='G') && (p[1]=='p' || p[1]=='P') && p[2]=='1' && !ISIDCHAR((unsigned char)p[3])) {
		*ep = &p[3];
		return (28);
	}
	/* GP2 */
	if ((p[0]=='g' || p[0]=='G') && (p[1]=='p' || p[1]=='P') && p[2]=='2' && !ISIDCHAR((unsigned char)p[3])) {
		*ep = &p[3];
		return (27);
	}
	/* Argument registers 0 to 9 */
	if (*p == 'a' || *p=='A') {
		if (isdigit((unsigned char)p[1]) && !ISIDCHAR((unsigned char)p[2])) {
			rg = p[1]-'0';
			rg = argregs[rg];	
			*ep = &p[2];
			return (rg);
		}
	}
	/* Temporary registers 0 to 9 */
	if (*p == 't' || *p=='T') {
		if (isdigit((unsigned char)p[1]) && !ISIDCHAR((unsigned char)p[2])) {
			rg = p[1]-'0';
			rg = tmpregs[rg];
			*ep = &p[2];
			return (rg);
		}
	}
	/* Register vars 0 to 9 */
	if (*p == 's' || *p=='S') {
		if (isdigit((unsigned char)p[1]) && !ISIDCHAR((unsigned char)p[2])) {
			rg = p[1]-'0';	
			rg = saved_regs[rg];
			*ep = &p[2];
			return (rg);
		}
	}
	if (*p != 'r' && *p != 'R') {
		return (-1);
	}
	if (isdigit((unsigned char)p[1]) && isdigit((unsigned char)p[2]) && !ISIDCHAR((unsigned char)p[3])) {
		rg = (p[1]-'0')*10 + p[2]-'0';
		if (rg < 32) {
			*ep = &p[3];
			return (rg);
		}
		return (-1);
	}
	if (isdigit((unsigned char)p[1]) && !ISIDCHAR((unsigned char)p[2])) {
		rg = p[1]-'0';
		*ep = &p[2];
		return (rg);
	}
	return (-1);
}

/* parse a vector register, v0 to v63 */
static int is_vreg(char *p, char **ep)
{
	int rg = -1;

	*ep = p;
	if (*p != 'v' && *p != 'V') {
		return (-1);
	}
	if (isdigit((unsigned char)p[1]) && isdigit((unsigned char)p[2]) && !ISIDCHAR((unsigned char)p[3])) {
		rg = (p[1]-'0')*10 + p[2]-'0';
		if (rg < 32) {
			*ep = &p[3];
			return (rg);
		}
		return (-1);
	}
	if (isdigit((unsigned char)p[1]) && !ISIDCHAR((unsigned char)p[2])) {
		rg = p[1]-'0';
		*ep = &p[2];
		return (rg);
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

static int is_branch(mnemonic* mnemo)
{
	switch(mnemo->ext.format) {
	case B:
	case BL:
	case J:
	case JL:
	case B2:
	case BL2:
	case J2:
	case JL2:
	case B3:
	case BL3:
	case J3:
	case JL3:
		return (1);
	}
	return (0);	
}

int parse_operand(char *p,int len,operand *op,int requires)
{
	int rg, nrg;
	int rv = PO_NOMATCH;
	char ch;

	TRACE("P");
	op->attr = REL_NONE;
	op->value = NULL;

	if (requires==OP_NEXTREG) {
    op->type = OP_REG;
    op->basereg = 0;
    op->value = number_expr((taddr)0);
		return (PO_NEXT);
	}
	if (requires==OP_NEXT) {
    op->value = number_expr((taddr)0);
		return (PO_NEXT);
	}

  p=skip(p);
  if ((rg = is_reg(p, &p)) >= 0) {
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
  else if(p[0]=='#'){
    op->type=OP_IMM;
    p=skip(p+1);
    op->value=parse_expr(&p);
  }else{
    int parent=0;
    expr *tree;
    op->type=-1;
    if (*p == '[') {
    	tree = number_expr((taddr)0);
    }
    else
    	tree=parse_expr(&p);
    if(!tree)
      return (PO_NOMATCH);
   	op->type = OP_IMM;
    if(*p=='['){
      parent=1;
      p=skip(p+1);
    }
    p=skip(p);
    if(parent){
    	if ((rg = is_reg(p, &p)) >= 0) {
    		op->basereg = rg;
    		p = skip(p);
    		if (*p=='+') {
    			p = skip(p+1);
    			if ((nrg = is_reg(p, &p)) >= 0) {
    				op->ndxreg = nrg;
		    		p = skip(p);
		    		op->type = OP_SCNDX;
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
    			op->type = OP_REGIND;
    		}
    	}
    	else if ((rg = is_careg(p, &p)) >= 0) {
    		op->basereg = rg;
    		op->type = OP_CAREGIND;
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
  if(requires & op->type) {
    return (PO_MATCH);
  }
  return (PO_NOMATCH);
}

operand *new_operand()
{
  operand *nw=mymalloc(sizeof(*nw));
  nw->type=-1;
  return nw;
}

static void fix_reloctype(dblock *db,int rtype)
{
  rlist *rl;

  for (rl=db->relocs; rl!=NULL; rl=rl->next)
    rl->type = rtype;
}


static int get_reloc_type(operand *op)
{
  int rtype = REL_NONE;

  if (OP_DATAM(op->type)) {  /* data relocs */
    return (REL_ABS);
  }

  else {  /* handle instruction relocs */
  	switch(op->format) {
  	
  	/* BEQ r1,r2,target */
  	case B:
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
	        default:
	          cpu_error(11);
	          break;
	      }
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
        default:
          cpu_error(11);
          break;
      }
      break;
  		
  	/* BEQZ r1,target */
  	case B3:
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
	        default:
	          cpu_error(11);
	          break;
	      }
      break;

		/* BEQ LK1,r1,r2,target */
  	case BL:
  		if (op->number > 2)
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
	        default:
	          cpu_error(11);
	          break;
	      }
      break;

		/* BRA	LK1,target */
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
	        default:
	          cpu_error(11);
	          break;
	      }
      break;

  	/* BEQZ LK1,r1,target */
  	case BL3:
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
	        default:
	          cpu_error(11);
	          break;
	      }
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
static taddr make_reloc(int reloctype,operand *op,section *sec,
                        taddr pc,rlist **reloclist, int *constexpr)
{
  taddr val;

	TRACE("M");
	*constexpr = 1;
  if (!eval_expr(op->value,&val,sec,pc)) {
  	*constexpr = 0;
    /* non-constant expression requires a relocation entry */
    symbol *base;
    int btype,pos,size,disp;
    taddr addend,mask;

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
        return val-pc;
      }

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
          default:
            ierror(0);
            break;
        }
        addend = val;
        mask = -1;
      }
      else {  /* instruction operand */
        addend = (btype == BASE_PCREL) ? val + disp : val;
      	switch(op->format) {
      	/* Conditional jump */
      	case J:
      	case JL:
		      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           29,19,0,0x3ffffeLL);
          break;
      	/* Unconditional jump */
        case J2:
        case JL2:
		      add_extnreloc_masked(reloclist,base,val,reloctype,
                           11,13,0,0x3ffeLL);
		      add_extnreloc_masked(reloclist,base,val,reloctype,
                           29,19,0,0x1ffffc000LL);
          break;
				/* Short conditional jump */
      	case J3:
      	case JL3:
		      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,5,0,0x3eLL);
		      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           19,13,0,0x7ffc0LL);
          break;
        case RIL:
        	if (abits < 30) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           19,29,0,0x1fffffffLL);
        	}	/* ToDo: fix for 31 bits and above */
        	else if (abits < 32) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,7,0,0xFE0000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           35,24,0,0x00ffffffLL);
        		
        	}
        	else if (abits < 49) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,23,0,0xFFFFFE000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           51,24,0,0x00ffffffLL);
        	}
        	else {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,39,0,0xfffffffffe000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           67,24,0,0x00ffffffLL);
        		
        	}
        	break;
        case DIRECT:
        	if (abits < 30) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           19,29,0,0x1fffffffLL);
        	}
        	else if (abits < 33) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,7,0,0xfe000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           35,24,0,0x00ffffffLL);
        		
        	}
        	else if (abits < 49) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,23,0,0xfffffe000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           51,24,0,0x00ffffffLL);
        	}
        	else {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,39,0,0xfffffffffe000000LL);
            /* might need a fix here for another bit */
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           67,24,0,0x00ffffffLL);
        		
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
        		if (abits < 30) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           19,29,0,0x1fffffffLL);
        		}
	        	else if (abits < 33) {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,7,0,0xfe00000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           35,24,0,0xffffffLL);
	        		
	        	}
	        	else if (abits < 49) {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                         9,23,0,0xfffffe000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                         51,24,0,0xffffffLL);
	        	}
	        	else {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                         9,39,0,0xfffffffffe000000LL);
	            /* might need a fix here for another bit */
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                         67,24,0,0xffffffLL);
						}        		
        	}
        	else if (op->basereg==sd2reg) {
        		int org_sdr = sdreg;
        		sdreg = sd2reg;
        		reloctype = REL_SD;
        		if (abits < 25) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           19,29,0,0x1fffffffLL);
        		}
	        	else if (abits < 33) {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,7,0,0xfe000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           35,24,0,0xffffffLL);
	        		
	        	}
	        	else if (abits < 49) {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,23,0,0xfffffe000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           51,24,0,0xffffffLL);
	        	}
	        	else {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,39,0,0xfffffffffe000000LL);
	            /* might need a fix here for another bit */
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           67,24,0,0x00ffffffLL);
						}
						sdreg = org_sdr;        		
        	}
        	else if (op->basereg==sd3reg) {
        		int org_sdr = sdreg;
        		sdreg = sd3reg;
        		reloctype = REL_SD;
        		if (abits < 25) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           19,29,0,0x1fffffffLL);
        		}
	        	else if (abits < 33) {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,7,0,0xfe000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           35,24,0,0xffffffLL);
	        		
	        	}
	        	else if (abits < 49) {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,23,0,0xfffffe000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           51,24,0,0xffffffLL);
	        	}
	        	else {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,39,0,0xfffffffffe000000LL);
	            /* might need a fix here for another bit */
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           67,24,0,0x00ffffffLL);
						}
						sdreg = org_sdr;        		
        	}
        	else {
        		if (abits < 25) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           19,29,0,0x1fffffffLL);
        		}
	        	else if (abits < 33) {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,7,0,0xfe000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           35,24,0,0xffffffLL);
	        		
	        	}
	        	else if (abits < 49) {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,23,0,0xfffffe000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           51,24,0,0xffffffLL);
	        	}
	        	else {
			      	add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,0x01000000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,39,0,0xfffffffffe000000LL);
	            /* might need a fix here for another bit */
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           67,24,0,0x00ffffffLL);
						}
        	}
        	break;
        default:
        		/* relocation of address as data */
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
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
     if (reloctype == REL_PC) {
       /* a relative reference to an absolute label */
			TRACE("n");
       return val-pc;
     }
  }

	TRACE("m");
  return val;
}


static void encode_reg(uint64_t* insn, operand *op, mnemonic* mnemo, int i)
{
	if (insn) {
		switch(mnemo->ext.format) {
		case BFR3IR:
			if (i==0)
				*insn = *insn| (RT(op->basereg & 0x1f));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			if (i==3)			
				*insn = *insn| (RC(op->basereg & regmask)) | (TC(0));
			break;
		case R1:
		case BFR3II:
		case RI6:
			if (i==0)
				*insn = *insn| (RT(op->basereg & 0x1f));
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
				*insn = *insn| (RT(op->basereg & 0x1f));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask)) | (TB(0));
			break;
		case R4:
		case R3:
		case R3RR:
			if (i==0)
				*insn = *insn| (RT(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & regmask)) | (TB(0));
			else if (i==3)
				*insn = *insn| (RC(op->basereg & regmask)) | (TC(0));
			break;
		case B:
		case J:
			if (i==0)
				*insn = *insn| (RA(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RB(op->basereg & regmask));
			else if (i==2)
				*insn = *insn| (RCB(op->basereg & regmask));
			break;
		case B3:
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
		case BL3:
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
				*insn = *insn| (RB(op->basereg & regmask)) | (TB(0));
			break;
		case RIL:
			if (i==0)
				*insn = *insn| (RT(op->basereg & regmask));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			break;
		case DIRECT:
			if (i==0)
				*insn = *insn| (RT(op->basereg & regmask));
			break;
		case MTSEL:
			if (i==0)
				*insn = *insn| (RB(op->basereg & regmask)) | (TB(0));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & regmask));
			break;
		case MTLK:
		case MFLK:
			if (i==0||i==1)
				*insn = *insn| (RT(op->basereg & regmask));
			break;
		}				
	}
}

static size_t encode_immed(uint64_t *prefix, uint64_t *prefix2, uint64_t *insn, mnemonic* mnemo,
	operand *op, taddr hval, int constexpr, int i, char vector)
{
	size_t isize;
	int64_t val;

	if (mnemo->ext.flags & FLG_NEGIMM)
		hval = -hval;	/* ToDo: check here for value overflow */
	val = hval;
	if (constexpr) {
		if (mnemo->ext.format==DIRECT) {
			isize = 6;
			/*if (mnemo->ext.short_opcode) {
				if (is_nbit(val,8)) {
					isize = 4;
				}
			} */
			if (!is_nbit(hval,24)) {
				if (prefix)
					*prefix = ((val >> 25LL) << 9LL) | EXI8 | ((val >> 24LL) & 1LL);
				isize = (2<<8)|6;
				if (!is_nbit(hval,32)) {
					if (prefix)
						*prefix = ((val >> 25LL) << 9LL) | EXI24 | ((val >> 24LL) & 1LL);
					isize = (4<<8)|6;
					if (!is_nbit(hval,48)) {
						if (prefix)
							*prefix = ((val >> 25LL) << 9LL) | EXI40 | ((val >> 24LL) & 1LL);
 						isize = (6<<8)|6;
						if (!is_nbit(hval,64)) {
							if (prefix)
								*prefix = ((val >> 25LL) << 9LL) | EXI56 | ((val >> 24LL) & 1LL);
	 						isize = (8<<8)|6;
						}
					}
				}
			}
			if (insn) {
				switch(isize) {
				case 4:
					*insn = *insn | ((val & 0x7ffLL) << 19LL);
					break;
				case 6:	
					*insn = *insn | ((val & 0x1fffffffLL) << 19LL);
					break;
				case (2<<8)|6:
				case (4<<8)|6:
				case (6<<8)|6:
					*insn = *insn | ((val & 0x1fffffffLL) << 19LL);
					break;
				}
			}
		}
		else if (mnemo->ext.format == CSR) {
			isize = 6;
			if (insn) {
				*insn = *insn | ((val & 0xffffLL) << 19LL);
			}
		}
		else if (mnemo->ext.format == RTS) {
			isize = 2;
			if (insn)
				*insn = *insn | ((val & regmask) << 11LL);
		}
		else if (mnemo->ext.format==R2) {
			isize = 4;
			if (insn) {
				if (mnemo->ext.opcode==0x5D)	// SLLH
					*insn = *insn | RB((val >> 4LL) & regmask) | TB(2);
				else
					*insn = *insn | RB(val & regmask) | TB(2);
			}
		}
		else if (mnemo->ext.format==R3) {
			isize = 6;
			if (i==2) {
				if (insn)
					*insn = *insn | RB(val & regmask) | TB(2);
			}
			else if (i==3)
				if (insn)
					*insn = *insn | RC(val & regmask) | TC(2);
		}
		else if (mnemo->ext.format==BFR3RI || mnemo->ext.format==BFR3IR || mnemo->ext.format==BFR3II) {
			isize = 6;
			if (i==2) {
				if (insn)
					*insn = *insn | RB(val & regmask) | TB(0) | ((val >> 5LL) & 3LL) << 31LL;
			}
			else if (i==3)
				if (insn)
					*insn = *insn | RC(val & regmask) | TC(0) | ((val >> 5LL) & 3LL) << 34LL;
		}
		else if (mnemo->ext.format==SHIFTI) {
			isize = 6;
			if (insn)
				*insn = *insn | ((val & 0x7fLL) << 29);
		}
		else if (mnemo->ext.format==RI6) {
			isize = 4;
			if (insn)
				*insn = *insn | ((val & 0x3fLL) << 19);
		}
		else if (mnemo->ext.format==J2) {
			isize = 6;
			if (insn)
				*insn = *insn | (((val >> 1LL) & 0x1fffLL) << 11LL) | ((((val >> 1LL) >> 13LL) & 0x7ffffLL) << 29LL);
		}
		else if (mnemo->ext.format==ENTER) {
			isize = 4;
			if (insn)
				*insn = *insn | ((-val & 0x7fffffLL) << 9LL);
		}
		else if (mnemo->ext.format==LEAVE) {
			isize = 4;
			if (insn)
				*insn = *insn | ((val & 0x7fffffLL) << 9LL);
		}
		else if (mnemo->ext.opcode==EXI56) {
			isize = 8;
			if (insn)
				*insn = *insn | ((val & 0xfffffffffffffeLL) << 8LL) | (val & 1LL);
		}
		else if (mnemo->ext.opcode==EXIM) {
			isize = 8;
			if (insn)
				*insn = *insn | ((val & 0x7fffffffffffffLL) << 9LL);
		}
		else {
			if (op->type & OP_IMM13)
				isize = 4;
			else
				isize = 6;
			/*
			if (!is_nbit(hval,80)) {
				isize = (8<<16)|(8<<8)|6;
				if (prefix2)
					*prefix2 = ((hval.hi >> 16LL) << 9LL) | EXIM;
				if (prefix)
					*prefix = ((hval.hi & 0xffffLL) << 48LL) | 
						((val >> 25LL) << 9LL) | EXI56 | ((val >> 24LL) & 1LL);
			}
			else
			if (!is_nbit(hval,64)) {
				if (prefix)
					*prefix = ((hval.hi & 0xffffLL) << 48LL) | 
						((val >> 25LL) << 9LL) | EXI56 | ((val >> 24LL) & 1LL);
				isize = (8<<8)|6;
			}
			else
			*/
			if (!is_nbit(hval,48)) {
				if (prefix)
					*prefix = ((val >> 25LL) << 9LL) | EXI40 | ((val >> 24LL) & 1LL);
				isize = (6<<8)|6;
			}
			else if (!is_nbit(hval,32)) {
				if (prefix)
					*prefix = ((val >> 25LL) << 9LL) | EXI24 | ((val >> 24LL) & 1LL);
				isize = (4<<8)|6;
			}
			else if (!is_nbit(hval,vector ? 24 : 29)) {
				if (prefix)
					*prefix = ((val >> 25LL) << 9LL) | EXI8 | ((val >> 24LL) & 1LL);
				isize = (2<<8)|6;
			}
			else if (!is_nbit(hval,13))
				isize = 6;
			if (insn) {
				switch(isize) {
				case 4:	
					*insn = *insn | ((val & 0x1fffLL) << 19LL);
					*insn = *insn & ~0xff;	/* clear opcode */
					*insn = *insn | mnemo->ext.short_opcode;
					break;
				case 6:	
				case (2<<8)|6:
				case (4<<8)|6:
				case (6<<8)|6:
				case (8<<8)|6:
					*insn = *insn | ((val & (vector ? 0xffffffLL : 0x1fffffffLL)) << 19LL);
					break;
				}
			}
		}
	}
	else {
		if (mnemo->ext.format==DIRECT) {
			isize = 6;
			goto j2;
			if (mnemo->ext.short_opcode && is_nbit(val,13)) {
				isize = 4;
j1:
				if (insn) {
					*insn = *insn | ((val & 0x1fffLL) << 19LL);
					*insn = *insn & ~0xff;	/* clear opcode */
					*insn = *insn | mnemo->ext.short_opcode;
				}
				return (isize);
			}
			goto j2;
		}
		if (mnemo->ext.format==CSR) {
			isize = 6;
			cpu_error(2);
		}
		else if (mnemo->ext.format==SHIFTI) {
			isize = 6;
			if (insn)
				*insn = *insn | ((val & 0x7fLL) << 29);
		}
		else if (mnemo->ext.format==RI6) {
			isize = 4;
			if (insn)
				*insn = *insn | ((val & 0x3fLL) << 19);
		}
		else if (mnemo->ext.format==J2) {
			isize = 6;
			if (insn)
				*insn = *insn | (((val >> 1LL) & 0x1fffLL) << 11LL) | ((((val >> 1LL) >> 13LL) & 0x7ffffLL) << 29LL);
		}
		else if (mnemo->ext.format==R2) {
			isize = 4;
			if (mnemo->ext.opcode==0x5D) {	// SLLH
				if (insn)
					*insn = *insn | RB((val >> 4LL) & 0x1fLL) | TB(2);
			}
			else {
				if (insn)
					*insn = *insn | RB(val & 0x1fLL) | TB(2);
			}
		}
		else if (mnemo->ext.format==BFR3RI || mnemo->ext.format==BFR3IR || mnemo->ext.format==BFR3II) {
			isize = 6;
			if (i==2) {
				if (insn)
					*insn = *insn | RB(val & regmask) | TB(0) | ((val >> 5LL) & 3LL) << 31LL;
			}
			else if (i==3)
				if (insn)
					*insn = *insn | RC(val & regmask) | TC(0) | ((val >> 5LL) & 3LL) << 34LL;
		}
		else if (mnemo->ext.format==ENTER) {
			isize = 4;
			if (insn)
				*insn = *insn | ((-val & 0x7fffffLL) << 9LL);
		}
		else if (mnemo->ext.format==LEAVE) {
			isize = 4;
			if (insn)
				*insn = *insn | ((val & 0x7fffffLL) << 9LL);
		}
		else if (mnemo->ext.opcode==EXI56) {
			isize = 8;
			if (insn)
				*insn = *insn | ((val & 0xfffffffffffffeLL) << 8LL) | (val & 1LL);
		}
		else if (mnemo->ext.opcode==EXIM) {
			isize = 8;
			if (insn)
				*insn = *insn | ((val & 0x7fffffffffffffLL) << 9LL);
		}
		else {
			if (op->type & OP_IMM13) {
				isize = 4;
				if (!is_nbit(val,13))
					goto j2;
				goto j1;
			}
			else {
j2:
				if (abits < 25) {
					isize = 6;
					if (insn)
						*insn = *insn | ((val & (vector ? 0xffffffLL : 0x1fffffffLL)) << 19LL);
					if (prefix)
						*prefix = 0;
				}
				else if (abits < 33) {
					isize = (2<<8)|6;
					if (insn)
						*insn = *insn | ((val & (vector ? 0xffffffLL : 0x1fffffffLL)) << 19LL);
					if (prefix)
						*prefix = ((val >> 25LL) << 9LL) | EXI8 | ((val >> 24) & 1LL);
				}
				else if (abits < 49) {
					isize = (4<<8)|6;
					if (insn)
						*insn = *insn | ((val & (vector ? 0xffffffLL : 0x1fffffffLL)) << 19LL);
					if (prefix)
						*prefix = ((val >> 25LL) << 9LL) | EXI24 | ((val >> 24) & 1LL);
				}
				else if (abits < 65) {
					isize = (6<<8)|6;
					if (insn)
						*insn = *insn | ((val & (vector ? 0xffffffLL : 0x1fffffffLL)) << 19LL);
					if (prefix)
						*prefix = ((val >> 25LL) << 9LL) | EXI40 | ((val >> 24LL) & 1LL);
				}
				else {
					isize = (8<<8)|6;
					if (insn)
						*insn = *insn | ((val & (vector ? 0xffffffLL : 0x1fffffffLL)) << 19LL);
					if (prefix)
						*prefix = ((val >> 25LL) << 9LL) | EXI56 | ((val >> 24LL) & 1LL);
				}
			}
		}
	}
	return (isize);
}

/* Evaluate branch operands excepting GPRs which are handled earlier.
	Returns 1 if the branch was processed, 0 if illegal branch format.
*/
static int encode_branch(uint64_t* insn, mnemonic* mnemo, operand* op, int64_t val, int* isize, int i)
{
	*isize = 6;

	TRACE("evb:");
	switch(mnemo->ext.format) {

	case B:
		if (op->type == OP_IMM) {
			if (insn) {
				switch(i) {
				case 1:
					*insn |= RB(val>>2)|((val & 3LL) << 12);
					break;
				case 2:
		  		uint64_t tgt;
		  		*insn |= RCB(31);
		  		tgt = (((val >> 1LL) & 0x7ffffLL) << 29LL);
		  		*insn |= tgt;
			  	break;
				}
			}
	  	return (1);
		}
		break;

	case BL:
		if (op->type == OP_IMM) {
			if (insn) {
				switch(i) {
				case 2:
					*insn |= RB(val>>2)|((val & 3LL) << 12);
					break;
				case 3:
			  	if (insn) {
			  		uint64_t tgt;
			  		*insn |= RCB(31);
			  		tgt = (((val >> 1LL) & 0x7ffffLL) << 29LL);
			  		*insn |= tgt;
			  	}
			  	break;
				}
			}
	  	return (1);
		}
		break;

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
	  		*insn |= RCB(op->basereg & 0x1f);
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
		  		*insn |= RCB(0);
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
	  		*insn |= RCB(op->basereg & 0x1f);
	  		tgt = (((val >> 1LL) & 0x7ffffLL) << 29LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case B2:
	  if (op->type==OP_IMM) {
	  	if (insn) {
	  		uint64_t tgt;
	  		if (is_nbit(val,21)) {
	  			*isize = 4;
	  			tgt = (((val >> 1LL) & 0x1fffffLL) << 11LL);
	  			*insn &= -256LL;
	  			*insn |= mnemo->ext.short_opcode;
	  		}
	  		else {
	  			*insn |= RCB(0x1f);
	  			tgt = (((val >> 1LL) & 0x1fffLL) << 11LL) | (((val >> 14LL) & 0x7ffffLL) << 29LL);
	  		}
	  		*insn |= tgt;
	  	}
	  	else {
	  		if (is_nbit(val,21))
	  			*isize = 4;
	  	}
	  	return (1);
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
	  		*insn |= RCB(op->basereg & 0x1f);
	    		tgt = (((val >> 1LL) & 0x1fffLL) << 11LL) | (((val >> 14LL) & 0x7ffffLL) << 29LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case BL2:
  	if (op->type==OP_IMM) {
	  	if (insn) {
    		uint64_t tgt;
	  		if (is_nbit(val,21)) {
	  			*isize = 4;
	  			tgt = (((val >> 1LL) & 0x1fffffLL) << 11LL);
	  			*insn &= -256LL;
	  			*insn |= mnemo->ext.short_opcode;
	  		}
	  		else {
	    		*insn |= RCB(0x1f);
	    		tgt = (((val >> 1LL) & 0x1fffLL) << 11LL) | (((val >> 14LL) & 0x7ffffLL) << 29LL);
	    	}
    		*insn |= tgt;
	  	}
	  	else {
	  		if (is_nbit(val,21))
	  			*isize = 4;
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
	  		*insn |= RCB(op->basereg & 0x1f);
	    		tgt = (((val >> 1LL) & 0x1fffLL) << 11LL) | (((val >> 14LL) & 0x7ffffLL) << 29LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case B3:
		*isize = 4;
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

	case BL3:
		*isize = 4;
		if (op->type == OP_IMM) {
			if (insn) {
				switch(i) {
				case 2:
			  	if (insn) {
			  		uint64_t tgt;
			  		*insn |= CA(7);
			  		tgt = (((val >> 1LL) & 0x1fLL) << 9LL) | (((val >> 6LL) & 0x1fffLL) << 19LL);
			  		*insn |= tgt;
			  	}
			  	break;
				}
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

/* evaluate expressions and try to optimize instruction,
   return size of instruction 

   Since the instruction may contain a prefix which varies in size, both the
   size of the instruction and the size of the prefix is returned. The size
   of the instruction is in byte 0 of the return value, the size of the 
   prefix is in byte 1. The total size may be calculated using a simple
   shift and sum.
*/
size_t encode_thor_operands(instruction *ip,section *sec,taddr pc,
                     uint64_t *prefix, uint64_t *prefix2, uint64_t *insn, dblock *db)
{
  mnemonic *mnemo = &mnemonics[ip->code];
  size_t isize;
  int i;
  operand op;
	int constexpr;
	int reg = 0;
	char vector_insn = 0;
	int64_t op1val;

	TRACE("Eto:");
	isize = mnemo->ext.len;
  if (insn != NULL) {
    *insn = mnemo->ext.opcode;
    if (pc & 1)
      cpu_error(19);  /* bad instruction alignment */
   }

	if (prefix)
		*prefix = 0;

	// Detect a vector instruction
  for (i=0; i<MAX_OPERANDS && ip->op[i]!=NULL; i++) {
  	if (ip->op[i]->type==OP_VREG) {
  		vector_insn = 1;
  		if (insn)
  			*insn |= 0x100;
  		break;
  	}
	}

  for (i=0; i<MAX_OPERANDS && ip->op[i]!=NULL; i++) {
    operand *pop;
    int reloctype;
    taddr hval;
    int64_t val;

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
        if (!eval_expr(op.value,&val,sec,pc)) {
          if (reloctype == REL_PC)
//          	hval = hsub(huge_zero(),pc);
						val -= pc;
        }
      }
    }
    else {
      if (!eval_expr(op.value,&val,sec,pc))
        if (insn != NULL) {
/*	    	printf("***A4 val:%lld****", val);
          cpu_error(2);  */ /* constant integer expression required */
        }
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
		else if (mnemo->operand_type[i]==OP_LK) {
			if (insn) {
 				switch(mnemo->ext.format) {
 				case JL:
 				case JL2:
 				case JL3:
 				case BL:
 				case BL2:
 				case BL3:
 				case RTS:
 					if (i==0)
 						*insn = *insn| RT(op.basereg & 0x3);
 					break;
 				case MTLK:
 				case MFLK:
					if (i==0||i==1)
 						*insn = *insn| (((op.basereg-1) & 0x1) << 15LL);
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
			isize = encode_immed(prefix, prefix2, insn, mnemo, &op, hval, constexpr, i, vector_insn);
    }
    else if (encode_branch(insn, mnemo, &op, val, &isize, i)) {
			TRACE("Etho4:");
    	;
    }
    else if ((mnemo->operand_type[i]&OP_REGIND) && op.type==OP_REGIND) {
			TRACE("Etho5:");
    	/* Check for short form */
    	if (constexpr) {
//	    	if (0 && is_nbit(val,8) && (mnemo->ext.opcode==0x86LL || mnemo->ext.opcode==0x93LL)) {
	   		if (mnemo->ext.opcode==0x95LL || mnemo->ext.opcode==0x89LL) {
	    		isize = 4;
	    		if (insn) {
	    			if (mnemo->ext.opcode==0x89LL)
	    				*insn = (*insn & ~0xffLL) | 0x89LL;
	    			else
	    				*insn = (*insn & ~0xffLL) | 0x95LL;
		    		if (i==0)
		    			*insn |= (RT(op.basereg & regmask));
		    		else if (i==1) {
		    			*insn |= (RA(op.basereg & regmask));
		    			*insn |= ((val & 0x1fffLL) << 19LL);
		    		}
	    		}
	    	}
	    	else {
	    		/*
	    		if (is_nbit(val,13) && mnemo->ext.short_opcode!=0) {
	    			isize = 4;
		    		if (insn) {
			    		if (i==0)
			    			*insn |= (RT(op.basereg & regmask));
			    		else if (i==1) {
			    			*insn |= (RA(op.basereg & regmask));
			    			*insn |= (val & 0x1fffLL) << 19LL;
			    		}
			    		*insn = (*insn & ~0xffLL) | mnemo->ext.short_opcode;
		    		}
	    		}
	    		else
	    		*/
	    		{
		    		isize = 6;
		    		if (insn) {
			    		if (i==0)
			    			*insn |= (RT(op.basereg & regmask));
			    		else if (i==1) {
			    			*insn |= (RA(op.basereg & regmask));
			    			*insn |= (val & 0x1fffffffLL) << 19LL;
			    		}
		    		}
		    	}
	    		if (!is_nbit(val,28) && abits > 28) {
	    			if (prefix)
							*prefix = ((val >> 25LL) << 9LL) | EXI8 | ((val >> 24LL) & 1LL);
						isize = (2<<8)|6;
						if (!is_nbit(val,32) && abits > 32) {
							if (prefix)
								*prefix = ((val >> 25LL) << 9LL) | EXI24 | ((val >> 24LL) & 1LL);
	 						isize = (4<<8)|6;
							if (!is_nbit(val,48) && abits > 48) {
								if (prefix)
									*prefix = ((val >> 25LL) << 9LL) | EXI40 | ((val >> 24LL) & 1LL);
		 						isize = (6<<8)|6;
								if (!is_nbit(val,64) && abits > 64) {
									if (prefix)
										*prefix = ((val >> 23LL) << 9LL) | EXI56 | ((val >> 24LL) & 1LL);
			 						isize = (8<<8)|6;
								}
							}
						}
					}
				}
  		}
  		else {
    		if (insn) {
	    		if (i==0)
	    			*insn |= (RT(op.basereg & regmask));
	    		else if (i==1) {
	    			*insn |= (RA(op.basereg & regmask));
	    			*insn |= (val & 0x1fffffffLL) << 19LL;
	    		}
    		}
	    	if (0 && is_nbit(val,13) && (mnemo->ext.opcode==0x86LL || mnemo->ext.opcode==0x93LL)) {
	    		isize = 4;
	    		if (insn) {
	    			if (mnemo->ext.opcode==0x86LL)
	    				*insn = (*insn & ~0xffLL) | 0x89LL;
	    			else
	    				*insn = (*insn & ~0xffLL) | 0x95LL;
		    		if (i==0)
		    			*insn |= (RT(op.basereg & regmask));
		    		else if (i==1) {
		    			*insn |= (RA(op.basereg & regmask));
		    			*insn |= ((val & 0x1fffLL) << 19LL);
		    		}
	    		}
	    	}
	    	/*
    		else if (is_nbit(val,13) && mnemo->ext.short_opcode!=0 && reloctype==REL_NONE) {
    			isize = 4;
	    		if (insn) {
		    		if (i==0)
		    			*insn |= (RT(op.basereg & regmask));
		    		else if (i==1) {
		    			*insn |= (RA(op.basereg & regmask));
		    			*insn |= (val & 0x1fffLL) << 19LL;
		    		}
		    		*insn = (*insn & ~0xffLL) | mnemo->ext.short_opcode;
	    		}
    		}
    		*/
    		else if (abits < 30) {
  				isize = 6;
  				if (insn)
						*insn = *insn | ((val & 0x1fffffffLL) << 19LL);
					if (prefix)
						*prefix = 0;
    		}
    		else if (abits < 33) {
  				isize = (2<<8)|6;
  				if (insn)
						*insn = *insn | ((val & 0xffffffLL) << 19LL);
					if (prefix)
						*prefix = ((val >> 25LL) << 9LL) | EXI8 | ((val >> 24LL) & 1LL);
    		}
    		else if (abits < 48) {
  				isize = (4<<8)|6;
  				if (insn)
						*insn = *insn | ((val & 0xffffffLL) << 19LL);
					if (prefix)
						*prefix = ((val >> 25LL) << 9LL) | EXI24 | ((val >> 24LL) & 1LL);
    		}
    		else {
  				isize = (6<<8)|6;
  				if (insn)
						*insn = *insn | ((val & 0xffffffLL) << 19LL);
					if (prefix)
						*prefix = ((val >> 25LL) << 9LL) | EXI40 | ((val >> 24LL) & 1LL);
    		}
  		}
    }
    else if ((mnemo->operand_type[i]&OP_SCNDX) && op.type==OP_SCNDX) {
			TRACE("Etho6:");
    	isize = 4;
  		if (insn) {
  			*insn |= (RA(op.basereg & regmask));
  			/* *insn |= ((val & 0xffLL) << 21LL); */
  			*insn |= RB(op.ndxreg & regmask);
  		}
    }
	}
	
	if (mnemo->ext.opcode==0x88LL || mnemo->ext.opcode==0x89LL ||
		mnemo->ext.opcode==0x94LL || mnemo->ext.opcode==0x95LL) {	// LDH Rt,n[SP] or STH Rs,n[SP]
		if (ip->op[1]->type==OP_REGIND && ip->op[0]->type==OP_REG) {
			if (ip->op[1]->basereg==31LL) {
				if (mnemo->ext.opcode==0x88LL || mnemo->ext.opcode==0x89LL) {
					switch(op1val & 0x1fffLL) {
					case 0:
						isize = 2;
						if (insn) {
							*insn = 0xC8LL |	// opcode
							(*insn & (0x1fLL << 9LL)); // Rt
						}
						break;
					case 16:
						isize = 2;
						if (insn) {
							*insn = 0xC8LL |	// opcode
							(*insn & (0x1fLL << 9LL)) | // Rt
							(1LL << 14LL);
						}
						break;
					case 32:
						isize = 2;
						if (insn) {
							*insn = 0xC8LL |	// opcode
							(*insn & (0x1fLL << 9LL)) | // Rt
							(2LL << 14LL);
						}	
						break;
					case 48:
						isize = 2;
						if (insn) {
							*insn = 0xC8LL |	// opcode
							(*insn & (0x1fLL << 9LL)) | // Rt
							(3LL << 14LL);
						}
						break;
					}
				}		
				else {
					switch(op1val & 0x1fffLL) {
					case 0:
						isize = 2;
						if (insn) {
							*insn = 0xC9LL |	// opcode
							(*insn & (0x1fLL << 9LL)); // Rt
						}
						break;
					case 16:
						isize = 2;
						if (insn) {
							*insn = 0xC9LL |	// opcode
							(*insn & (0x1fLL << 9LL)) | // Rt
							(1LL << 14LL);
						}
						break;
					case 32:
						isize = 2;
						if (insn) {
							*insn = 0xC9LL |	// opcode
							(*insn & (0x1fLL << 9LL)) | // Rt
							(2LL << 14LL);
						}
						break;
					case 48:
						isize = 2;
						if (insn) {
							*insn = 0xC9LL |	// opcode
							(*insn & (0x1fLL << 9LL)) | // Rt
							(3LL << 14LL);
						}
						break;
					}
				}		
			}
		}
	}
	
	TRACE("G");
	return (isize);
}

/* Calculate the size of the current instruction; must be identical
   to the data created by eval_instruction. */
size_t instruction_size(instruction *ip,section *sec,taddr pc)
{
	size_t sz = encode_thor_operands(ip,sec,pc,NULL,NULL,NULL,NULL);
	sz = (sz & 0xff) + ((sz >> 8) & 0xff) + (sz >> 16);
	insn_sizes1[sz1ndx++] = sz;
	TRACE2("isize=%d ", sz);
  return (sz);
}


/* Convert an instruction into a DATA atom including relocations,
   when necessary. */
dblock *eval_instruction(instruction *ip,section *sec,taddr pc)
{
  dblock *db = new_dblock();
  uint64_t prefix, prefix2;
  uint64_t insn;
  size_t sz;

	prefix = 0;
	prefix2 = 0;
	sz = encode_thor_operands(ip,sec,pc,&prefix,&prefix2,&insn,db);
	db->size = (sz & 0xff) + ((sz >> 8) & 0xff) + (sz >> 16);
	insn_sizes2[sz2ndx++] = db->size;
  if (db->size) {
    unsigned char *d = db->data = mymalloc(db->size);
    int i;

		if (sz >> 16) {
	    d = setval(0,d,sz >> 16,prefix2);
	    insn_count++;
	  }
		if ((sz >> 8) & 0xff) {
	    d = setval(0,d,(sz >> 8) & 0xff,prefix);
	    insn_count++;
	  }
    d = setval(0,d,sz & 0xff,insn);
    insn_count++;
    byte_count += db->size;
  }
  return (db);
}


/* Create a dblock (with relocs, if necessary) for size bits of data. */
dblock *eval_data(operand *op,size_t bitsize,section *sec,taddr pc)
{
  dblock *db = new_dblock();
  taddr val;
  tfloat flt;
  int constexpr = 1;

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

    switch (bitsize) {
      case 32:
        conv2ieee32(0,db->data,flt);
        break;
      case 64:
        conv2ieee64(0,db->data,flt);
        break;
      default:
        cpu_error(10);  /* data has illegal type */
        break;
    }
  }
  else {
    val = make_reloc(get_reloc_type(op),op,sec,pc,&db->relocs,&constexpr);

    switch (db->size) {
      case 1:
        db->data[0] = val & 0xff;
        break;
      case 2:
      case 4:
      case 8:
        setval(0,db->data,db->size,val);
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
	insn_count = 0;
	byte_count = 0;
  return 1;
}

/* return true, if the passed argument is understood */
int cpu_args(char *p)
{
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
