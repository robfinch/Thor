#include "vasm.h"

#define TRACE(x)		//printf(x)
#define TRACE2(x,y)	//printf((x),(y))

char *cpu_copyright="vasm Thor cpu backend (c) in 2021 Robert Finch";

char *cpuname="Thor";
int bitsperbyte=8;
int bytespertaddr=8;
int abits=32;
static taddr sdreg = 61;
static taddr sd2reg = 60;
static taddr sd3reg = 59;

mnemonic mnemonics[]={
	"abs",	{OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x280000000002LL,6},	// ToDo: fix with NEXT?

	"add", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x080000000102LL,6},	// 3r
	"add", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x080000000102LL,6},	// 3r
	"add", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D4LL,6},
	"add", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x080000000002LL,6},	// 3r
	"add", {OP_REG,OP_REG,OP_IMM,OP_REG,0}, {R3IR,CPU_ALL,0,0x080000000002LL,6},	// 3r
	"add", {OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x080000000002LL,6},	// 3r
	"add", {OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {R3II,CPU_ALL,0,0x080000000002LL,6},	// 3r
	"add", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x19LL,4},	// 2r
	"add", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD4LL,6,0x04LL,4},

	"and", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x100000000102LL,6},	// 3r
	"and", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x100000000102LL,6},	// 3r
	"and", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D8LL,6},
	"and", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x100000000002LL,6},	// 3r
	"and", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x1ALL,4},	// 2r
	"and", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD8LL,6,0x08LL,4},

	"andc", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x160000000102LL,6},	// 3r
	"andc", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x160000000102LL,6},	// 3r
	"andc", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x160000000002LL,6},	// 3r
	"andn", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x160000000102LL,6},	// 3r
	"andn", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x160000000102LL,6},	// 3r
	"andn", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x160000000002LL,6},	// 3r

	"bcdadd", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x0000000000F5LL,6},	// 3r
	"bcdmul", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x0400000000F5LL,6},	// 3r
	"bcdsub", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x0200000000F5LL,6},	// 3r
	
	"bfalign",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x0000000000AALL,6},
	"bfchg",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x1400000000AALL,6},
	"bfchg",	{OP_REG,OP_REG,OP_IMM,OP_REG,0}, {R3IR,CPU_ALL,0,0x1400100000AALL,6},
	"bfchg",	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x1410000000AALL,6},
	"bfchg",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {R3II,CPU_ALL,0,0x1410100000AALL,6},
	"bfclr",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {R3II,CPU_ALL,0,0x1610100000AALL,6},
	"bfext",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x0A00000000AALL,6},
	"bfext",	{OP_REG,OP_REG,OP_IMM,OP_REG,0}, {R3IR,CPU_ALL,0,0x0A00100000AALL,6},
	"bfext",	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x0A10000000AALL,6},
	"bfext",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {R3II,CPU_ALL,0,0x0A10100000AALL,6},
	"bfextu",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {R3II,CPU_ALL,0,0x0810100000AALL,6},
	"bfffo",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {R3II,CPU_ALL,0,0x0210100000AALL,6},
	"bfset",	{OP_REG,OP_REG,OP_IMM,OP_IMM,0}, {R3II,CPU_ALL,0,0x1810100000AALL,6},

	"bmap", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x00000000004CLL,6},	// 3r
	"bmm", 	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x600000000002LL,6},	// 3r

	"beq",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E0000026LL,6},
	"beq",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E0000026LL,6},
	"beqz",	{OP_LK,OP_REG,OP_IMM,0,0}, {BL3,CPU_ALL,0,0xE0000010LL,4},
	"beqz",	{OP_REG,OP_IMM,0,0,0}, {B3,CPU_ALL,0,0xE0000010LL,4},
	"bge",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E0000029LL,6},
	"bge",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E0000029LL,6},
	"bgt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000002BLL,6},
	"bgt",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000002BLL,6},
	"ble",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000002ALL,6},
	"ble",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000002ALL,6},
	"blt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E0000028LL,6},
	"blt",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E0000028LL,6},
	"bgeu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000002DLL,6},
	"bgeu",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000002DLL,6},
	"bgtu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000002FLL,6},
	"bgtu",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000002FLL,6},
	"bleu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000002ELL,6},
	"bleu",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000002ELL,6},
	"bltu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000002CLL,6},
	"bltu",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000002CLL,6},
	"bne",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E0000027LL,6},
	"bne",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E0000027LL,6},
	"bnez",	{OP_LK,OP_REG,OP_IMM,0,0}, {BL3,CPU_ALL,0,0xE0000012LL,4},
	"bnez",	{OP_REG,OP_IMM,0,0,0}, {B3,CPU_ALL,0,0xE0000012LL,4},

	"bra",	{OP_IMM,0,0,0,0}, {B2,CPU_ALL,0,0x0000E0000020LL,6},
	"brk",	{0,0,0,0,0}, {R1,CPU_ALL,0,0x00,2},
	"bsr",	{OP_LK,OP_IMM,0,0,0}, {BL2,CPU_ALL,0,0x0000E0000020LL,6},
	"bsr",	{OP_IMM,0,0,0,0}, {B2,CPU_ALL,0,0x0000E0000220LL,6},

	"bytndx", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0xAA0000000002LL,6},	// 3r
	"bytndx", 	{OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0x00000055LL,4},	// ri

	"chk", 	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x320000000002LL,6},	// 3r
	"chk", 	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3,CPU_ALL,0,0x000000000045LL,6},	// 3r

	"clmul", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x5C0000000002LL,6},	// 3r
	"clmulh", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x5E0000000002LL,6},	// 3r

	"cmovnz", 	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x5A0000000002LL,6},	// 3r

	"cmp", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x540000000102LL,6},	// 2r
	"cmp", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x540000000102LL,6},	// 2r
	"cmp", {OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x540000000002LL,6},	// 2r
	"cmp", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD0LL,6,0x50,4},
	"cmpu", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x560000000102LL,6},	// 2r
	"cmpu", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x560000000102LL,6},	// 2r
	"cmpu", {OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x560000000002LL,6},	// 2r
	"cmpu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD1LL,6},
	
	"cntlz", {OP_VREG,OP_VREG,0,0,0}, {R1,CPU_ALL,0,0x00000101,4},
	"cntlz", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x00000001,4},
	"cntpop", {OP_VREG,OP_VREG,0,0,0}, {R1,CPU_ALL,0,0x04000101,4},
	"cntpop", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x04000001,4},

	"com",	{OP_VREG,OP_VREG,0,0,0}, {R3II,CPU_ALL,0,0x1417F00001AALL,6},
	"com",	{OP_REG,OP_REG,0,0,0}, {R3II,CPU_ALL,0,0x1417F00000AALL,6},

	"cpuid", {OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x41LL,4},
	
	"csrrw", {OP_REG,OP_REG,OP_IMM,0,0}, {CSR,CPU_ALL,0,0x02000000000FLL,6},

	"dbeq",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E0000036LL,6},
	"dbeq",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E0000036LL,6},
	"dbge",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E0000039LL,6},
	"dbge",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E0000039LL,6},
	"dbgt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000003BLL,6},
	"dbgt",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000003BLL,6},
	"dble",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000003ALL,6},
	"dble",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000003ALL,6},
	"dblt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E0000038LL,6},
	"dblt",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E0000038LL,6},
	"dbgeu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000003DLL,6},
	"dbgeu",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000003DLL,6},
	"dbgtu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000003FLL,6},
	"dbgtu",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000003FLL,6},
	"dbleu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000003ELL,6},
	"dbleu",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000003ELL,6},
	"dbltu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E000003CLL,6},
	"dbltu",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E000003CLL,6},
	"dbne",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_IMM,0}, {BL,CPU_ALL,0,0x0000E0000037LL,6},
	"dbne",	{OP_REG,OP_REG|OP_IMM7,OP_IMM,0,0}, {B,CPU_ALL,0,0x0000E0000037LL,6},
	"dbra",	{OP_IMM,0,0,0,0},{B2,CPU_ALL,0,0x0000E0000030LL,6},

	"di",		{OP_NEXTREG,OP_NEXTREG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x2C0000000007LL,6},
	"dif",	{OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x280000000002LL,6},

	"div", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x142LL,6},	// 3r
	"div", {OP_VREG,OP_VREG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x142LL,6},
	"div", {OP_VREG,OP_VREG,OP_VREG,OP_VMREG,0}, {R3,CPU_ALL,0,0x200000000102LL,6},	// 3r
	"div", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x200000000102LL,6},	// 3r
	"div", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x200000000002LL,6},	// 3r
	"div", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x42LL,6},

	"divu", {OP_VREG,OP_VREG,OP_VREG,OP_VMREG,0}, {R3RR,CPU_ALL,0,0x220000000102LL,6},	// 3r
	"divu", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3RR,CPU_ALL,0,0x220000000102LL,6},	// 3r
	"divu", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x220000000002LL,6},	// 3r
	"divu", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0x4FLL,4},

	"djeq",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x000000000036LL,6},
	"djeq",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x000000000036LL,6},
	"djge",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x000000000039LL,6},
	"djge",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x000000000039LL,6},
	"djgt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000003BLL,6},
	"djgt",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000003BLL,6},
	"djle",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000003ALL,6},
	"djle",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000003ALL,6},
	"djlt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x000000000038LL,6},
	"djlt",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x000000000038LL,6},
	"djgeu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000003DLL,6},
	"djgeu",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000003DLL,6},
	"djgtu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000003FLL,6},
	"djgtu",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000003FLL,6},
	"djleu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000003ELL,6},
	"djleu",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000003ELL,6},
	"djltu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000003CLL,6},
	"djltu",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000003CLL,6},
	"djne",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x000000000037LL,6},
	"djne",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x000000000037LL,6},

	"eor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x140000000102LL,6},	// 3r
	"eor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x140000000102LL,6},	// 3r
	"eor", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1DALL,6},
	"eor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x140000000002LL,6},	// 3r
	"eor", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x1ELL,4},	// 2r
	"eor", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xDALL,6,0x0ALL,4},

	"enor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x040000000102LL,6},	// 3r
	"enor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x040000000102LL,6},	// 3r
	"enor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x040000000002LL,6},	// 3r

	"int",	{OP_IMM,OP_IMM,0,0,0}, {INT,CPU_ALL,0,0xA6,4},

	"jeq",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x000000000026LL,6},
	"jeq",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x000000000026LL,6},
	"jge",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x000000000029LL,6},
	"jge",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x000000000029LL,6},
	"jgt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000002BLL,6},
	"jgt",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000002BLL,6},
	"jle",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000002ALL,6},
	"jle",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000002ALL,6},
	"jlt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x000000000028LL,6},
	"jlt",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x000000000028LL,6},
	"jgeu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000002DLL,6},
	"jgeu",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000002DLL,6},
	"jgtu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000002FLL,6},
	"jgtu",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000002FLL,6},
	"jleu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000002ELL,6},
	"jleu",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000002ELL,6},
	"jltu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x00000000002CLL,6},
	"jltu",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x00000000002CLL,6},
	"jne",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0}, {JL,CPU_ALL,0,0x000000000027LL,6},
	"jne",	{OP_REG,OP_REG|OP_IMM7,OP_CAREGIND,0,0}, {J,CPU_ALL,0,0x000000000027LL,6},

	"jmp",	{OP_CAREGIND,0,0,0,0}, {J2,CPU_ALL,0,0x00000020LL,6},
	"jmp",	{OP_IMM,0,0,0,0}, {J2,CPU_ALL,0,0x00000020LL,6},
	"jsr",	{OP_LK,OP_CAREGIND,0,0,0}, {JL2,CPU_ALL,0,0x00000020LL,6},
	"jsr",	{OP_LK,OP_IMM,0,0,0}, {JL2,CPU_ALL,0,0x00000020LL,6},
	"jsr",	{OP_IMM,0,0,0,0}, {J2,CPU_ALL,0,0x00000220LL,6},

	"ldi", {OP_REG,OP_NEXTREG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD4LL,6,0x04LL,4},

	"ldb",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x80LL,6},	
	"ldb",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB0LL,6},	
	"ldb",	{OP_VREG,OP_SEL|OP_SCNDX,OP_VMREG,0,0}, {SCNDX,CPU_ALL,0,0x1B0LL,6},	
	"ldbu",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x81LL,6},	
	"ldbu",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB1LL,6},	
	"ldbu",	{OP_VREG,OP_SEL|OP_SCNDX,OP_VMREG,0,0}, {SCNDX,CPU_ALL,0,0x1B1LL,6},	
	"ldo",	{OP_REG,OP_SEL|OP_REGIND8,0,0,0}, {REGIND,CPU_ALL,0,0x87LL,4},	
	"ldo",	{OP_REG,OP_SEL|OP_IMM,0,0}, {DIRECT,CPU_ALL,0,0x86LL,6,0x87,4},
	"ldo",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x86LL,6},	
	"ldo",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB6LL,6},	
	"ldt",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x84LL,6},	
	"ldt",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB4LL,6},	
	"ldtu",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x85LL,6},	
	"ldtu",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB5LL,6},	
	"ldw",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x82LL,6},	
	"ldw",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB2LL,6},	
	"ldwu",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x83LL,6},	
	"ldwu",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xB3LL,6},	

	"lea",	{OP_REG,OP_SEL|OP_IMM,0,0}, {DIRECT,CPU_ALL,0,0x86LL,6,0x8A,4},
	"lea",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {REGIND,CPU_ALL,0,0x8ALL,6},	
	"lea",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xBALL,6},	

	"max",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x520000000002LL,6},	// 3r
	"memdb",	{0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF9,2},
	"memsb",	{0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF8,2},
	"mfsel",	{OP_REG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x500000000007LL,6},	// 3r
	"mfsel",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x500000000007LL,6},	// 3r
	"min",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x500000000002LL,6},	// 3r

	"mov",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0817F00000AALL,6},
	"move",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0817F00000AALL,6},
	"movsxb",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0A10F00000AALL,6},
	"movsxw",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0A11F00000AALL,6},
	"movsxt",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0A13F00000AALL,6},
	"movzxb",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0810F00000AALL,6},
	"movzxw",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0811F00000AALL,6},
	"movzxt",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0813F00000AALL,6},

	"mtlc",		{OP_NEXTREG,OP_REG,0,0,0}, {R2,CPU_ALL,0,0xA0000052LL,4},

	"mtsel",	{OP_NEXTREG,OP_REG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x520000000007LL,6},	// 3r
	"mtsel",	{OP_NEXTREG,OP_REG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x520000000007LL,6},	// 3r

	"mul", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D2LL,6},	// 3r
	"mul", {OP_VREG,OP_VREG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x1D2LL,6},
	"mul", {OP_VREG,OP_VREG,OP_VREG,OP_VMREG,0}, {R3,CPU_ALL,0,0x0C0000000102LL,6},	// 3r
	"mul", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x0C0000000102LL,6},	// 3r
	"mul", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x0C0000000002LL,6},	// 3r
	"mul", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD2,6,0x06LL,4},

	"mulf", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x2A0000000002LL,6},	// 3r
	"mulf", {OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0x15LL,4},

	"mulh", {OP_REG,OP_REG,OP_REG,0,0}, {R3RR,CPU_ALL,0,0x1E0000000002LL,6},	// 3r

	"mux",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x680000000002LL,6},	// 3r

	"nand", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x000000000102LL,6},	// 3r
	"nand", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x000000000102LL,6},	// 3r
	"nand", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x000000000002LL,6},	// 3r

	"neg", {OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0x0A0000000002LL,6},	// 2r

	"nop",	{0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF1,2},

	"nor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x020000000102LL,6},	// 3r
	"nor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x020000000102LL,6},	// 3r
	"nor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x020000000002LL,6},	// 3r

	"or", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x120000000102LL,6},	// 3r
	"or", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x120000000102LL,6},	// 3r
	"or", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D9LL,6},
	"or", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x120000000002LL,6},	// 3r
	"or", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x1DLL,4},	// 2r
	"or", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD9LL,6,0x09LL,4},

	"orc", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x060000000102LL,6},	// 3r
	"orc", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x060000000102LL,6},	// 3r
	"orc", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x060000000002LL,6},	// 3r
	"orn", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x060000000102LL,6},	// 3r
	"orn", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x060000000102LL,6},	// 3r
	"orn", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x060000000002LL,6},	// 3r

	"peekq",	{OP_REG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x140000000007LL,6},	// 3r
	"peekq",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x140000000007LL,6},	// 3r

	"pfi",	{OP_REG,0,0,0,0},{R3RR,CPU_ALL,0,0x220000000007LL,6},	// 3r

	"popq",	{OP_REG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x120000000007LL,6},	// 3r
	"popq",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x120000000007LL,6},	// 3r

	"ptrdif",	{OP_REG,OP_REG,OP_REG,OP_IMM,0}, {R3RI,CPU_ALL,0,0x281000000002LL,6},
	"ptrdif",	{OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3RR,CPU_ALL,0,0x280000000002LL,6},

	"pushq",	{OP_NEXTREG,OP_REG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x100000000007LL,6},	// 3r
	"pushq",	{OP_NEXTREG,OP_REG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x100000000007LL,6},	// 3r

	"resetq",	{OP_NEXTREG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x180000000007LL,6},	// 3r
	"resetq",	{OP_NEXTREG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x180000000007LL,6},	// 3r

	"revbit",	{OP_REG,OP_REG,0,0,0}, {R1,CPU_ALL,0,0x50000001LL,4},

	"ret",	{OP_LK,OP_IMM,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"ret",	{OP_LK,0,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"ret",	{0,0,0,0,0}, {RTS,CPU_ALL,0,0x02F2LL, 2},

	"rex",	{OP_IMM,OP_REG,0,0,0},{REX,CPU_ALL,0,0x200000000007LL,6},	// 3r

	"rte",	{OP_IMM,OP_REG,0,0,0},{RTE,CPU_ALL,0,0x260000000007LL,6},	// 3r

	"rol",	{OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x860000000002LL,6},	// 3r
	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x860000000002LL,6},	// 3r
	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x860000000002LL,6},	// 3r
	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x860000000002LL,6},	// 3r
	"rol",	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x800000000002LL,6},	// 3r
	"rol",	{OP_REG,OP_REG,OP_IMM,0,0}, {R3,CPU_ALL,0,0x801000000002LL,6},	// 3r

	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x880000000002LL,6},	// 3r
	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x880000000002LL,6},	// 3r
	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x880000000002LL,6},	// 3r
	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x880000000002LL,6},	// 3r
	
	"rts",	{OP_LK,OP_IMM,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"rts",	{OP_LK,0,0,0,0}, {RTS,CPU_ALL,0,0x00F2LL, 2},
	"rts",	{0,0,0,0,0}, {RTS,CPU_ALL,0,0x02F2LL, 2},

	"sei",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x2E0000000007LL,6},	// 3r

	"seq", {OP_VREG,OP_VREG,OP_VREG,OP_VMREG,0}, {R3,CPU_ALL,0,0x4C0000000102LL,6},	// 3r
	"seq", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x4C0000000102LL,6},	// 3r
	"seq", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D6LL,6},
	"seq", {OP_VREG,OP_VREG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x1D6LL,6},
	"seq", {OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x4C0000000002LL,6},	// 3r
	"seq", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD6LL,6},

	"sge", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x420000000102LL,6},	// 3r
	"sge", {OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x420000000002LL,6},	// 3r
	"sgeu", {OP_VREG,OP_VREG,OP_VREG,0,0}, {R3,CPU_ALL,0,0x460000000102LL,6},	// 3r
	"sgeu", {OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x460000000002LL,6},	// 3r

	"sgt", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xDBLL,6,0x1B,4},
	"sgtu", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xDFLL,6,0x1F,4},
	"slt", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD8LL,6,0x18,4},

	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x800000000002LL,6},	// 3r
	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x800000000002LL,6},	// 3r
	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R2,CPU_ALL,0,0x58,4},
	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R2,CPU_ALL,0,0x58,4},

	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x840000000002LL,6},	// 3r
	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x840000000002LL,6},	// 3r
	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x840000000002LL,6},	// 3r
	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x840000000002LL,6},	// 3r

	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x820000000002LL,6},	// 3r
	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x820000000002LL,6},	// 3r
	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R3,CPU_ALL,0,0x820000000002LL,6},	// 3r
	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x820000000002LL,6},	// 3r

	"statq",	{OP_REG,OP_NEXTREG,OP_IMM,0,0},{R3RR,CPU_ALL,0,0x160000000007LL,6},	// 3r
	"statq",	{OP_REG,OP_NEXTREG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x160000000007LL,6},	// 3r

	"stb",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x90LL,6},	
	"stb",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC0LL,6},	
	"sto",	{OP_REG,OP_SEL|OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0x93LL,6,0x95LL,4},	
	"sto",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x93LL,6},	
	"sto",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC3LL,6},	
	"stt",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x92LL,6},	
	"stt",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC2LL,6},	
	"stw",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {REGIND,CPU_ALL,0,0x91LL,6},	
	"stw",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {SCNDX,CPU_ALL,0,0xC1LL,6},	

	"sub", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x0A0000000002LL,6},	// 3r
	"sub", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x0A0000000002LL,6},	// 3r
	"sub", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x0A0000000102LL,6},	// 3r
	"sub", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x0A0000000102LL,6},	// 3r
	"sub", {OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x0A0000000002LL,6},	// 2r
	"subf", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1D5LL,6},
	"subf", {OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0xD5LL,6},

	"sync", {0,0,0,0,0}, {BITS16,CPU_ALL,0,0xF7LL,2},
	"sys",	{OP_IMM,0,0,0,0}, {BITS32,CPU_ALL,0,0xA5,4},

	"tlbrw",	{OP_REG,OP_REG,OP_REG,0,0},{R3RR,CPU_ALL,0,0x3C0000000007LL,6},	// 3r

	"utf21ndx", 	{OP_REG,OP_VREG,OP_REG,0,0}, {R3,CPU_ALL,0,0x380000000102LL,6},	// 3r
	"utf21ndx", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x380000000002LL,6},	// 3r
	"utf21ndx", 	{OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x57LL,6},	// 3r

	"wfi", {0,0,0,0,0}, {BITS16,CPU_ALL,0,0xFALL,2},

	"wydendx", 	{OP_REG,OP_REG,OP_REG,0,0}, {R3,CPU_ALL,0,0x360000000002LL,6},	// 3r
	"wydendx", 	{OP_REG,OP_REG,OP_IMM,0,0}, {RIL,CPU_ALL,0,0x56LL,6},	// 3r

	// Alternate mnemonic for enor
	"xnor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x040000000102LL,6},	// 3r
	"xnor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x040000000102LL,6},	// 3r
	"xnor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x040000000002LL,6},	// 3r

	// Alternate mnemonic for eor
	"xor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x140000000102LL,6},	// 3r
	"xor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x140000000102LL,6},	// 3r
	"xor", {OP_VREG,OP_VREG,OP_IMM,OP_VMREG,0}, {RIL,CPU_ALL,0,0x1DALL,6},
	"xor", {OP_REG,OP_REG,OP_REG,OP_REG,0}, {R3,CPU_ALL,0,0x140000000002LL,6},	// 3r
	"xor", {OP_REG,OP_REG,OP_REG,0,0}, {R2,CPU_ALL,0,0x1ELL,4},	// 2r
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

static int is_identchar(unsigned char ch)
{
	return (isalnum(ch) || ch == '_');
}

/* parse a general purpose register, r0 to r63 */
static int is_reg(char *p, char **ep)
{
	int rg = -1;
	
	*ep = p;
	// SP
	if ((p[0]=='s' || p[0]=='S') && (p[1]=='p' || p[1]=='P') && !ISIDCHAR((unsigned char)p[2])) {
		*ep = &p[2];
		return (63);
	}
	// FP
	if ((p[0]=='f' || p[0]=='F') && (p[1]=='p' || p[1]=='P') && !ISIDCHAR((unsigned char)p[2])) {
		*ep = &p[2];
		return (62);
	}
	// GP
	if ((p[0]=='g' || p[0]=='G') && (p[1]=='p' || p[1]=='P') && !ISIDCHAR((unsigned char)p[2])) {
		*ep = &p[2];
		return (61);
	}
	// Argument registers 0 to 9
	if (*p == 'a' || *p=='A') {
		if (isdigit((unsigned char)p[1]) && !ISIDCHAR((unsigned char)p[2])) {
			rg = p[1]-'0' + 1;	// 1,2
			if (rg > 2)					// 21 to 28
				rg += 18;
			*ep = &p[2];
			return (rg);
		}
	}
	// Temporary registers 0 to 9
	if (*p == 't' || *p=='T') {
		if (isdigit((unsigned char)p[1]) && !ISIDCHAR((unsigned char)p[2])) {
			rg = p[1]-'0' + 3;	// 3 to 10
			if (rg > 10)
				rg += 19;					// 29,30
			*ep = &p[2];
			return (rg);
		}
	}
	// Register vars 0 to 9
	if (*p == 's' || *p=='S') {
		if (isdigit((unsigned char)p[1]) && !ISIDCHAR((unsigned char)p[2])) {
			rg = p[1]-'0' + 11;	// 11 to 20
			*ep = &p[2];
			return (rg);
		}
	}
	if (*p != 'r' && *p != 'R') {
		return (-1);
	}
	if (isdigit((unsigned char)p[1]) && isdigit((unsigned char)p[2]) && !ISIDCHAR((unsigned char)p[3])) {
		rg = (p[1]-'0')*10 + p[2]-'0';
		if (rg < 64) {
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
		if (rg < 64) {
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
	// IP
	if ((p[0]=='I' || p[0]=='i') && (p[1]=='P' || p[1]=='p') && !ISIDCHAR((unsigned char)p[3])) {
		*ep = &p[3];
		return (7);
	}
	// PC
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

/* parse a selector register */
static int is_selector(char *p, char **ep)
{
	static char *sels[8] = { "ZS", "DS", "ES", "FS", "GS", "HS", "SS", "CS" };
	int n;
	
	*ep = p;
	for (n = 0; n < 8; n++) {
		if (toupper(*p)==sels[n][0] && toupper(p[1])==sels[n][1] && p[2]==':') {
			*ep = &p[3];
			return (n);
		}
	}
	return (-1);
}

/* Choose a default selector register number */
static int select_selector(char basereg, char ndxreg)
{
	// Stack reference
	if (basereg==63 || basereg==62)
		return (6);	// SS
	if (ndxreg==63 || ndxreg==62)
		return (6);	// SS
	return (1);	// DS
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

	TRACE("P");
	op->attr = REL_NONE;
	op->selector = -1;
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
    if ((rg = is_selector(p, &p)) >= 0) {
    	op->selector = rg;
    	if (!(requires & OP_SEL)) {
    		cpu_error(17);
    	}
    }
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
		    		if (*p=='*') {
		    			p = skip(p+1);
		    			if(*p=='1') {
		    				op->scale = 0;
		    				p = skip(p);
		    			}
		    			else if (*p=='2') {
		    				op->scale = 1;
		    				p = skip(p);
		    			}
		    			else if (*p=='4') {
		    				op->scale = 2;
		    				p = skip(p);
		    			}
		    			else if (*p=='8') {
		    				op->scale = 3;
		    				p = skip(p);
		    			}
		    			else if (*p==']')
		    				op->scale = -1;
		    			else {
		    				cpu_error(0);
		    				return (0);
		    			}
		    		}
		    		op->type = OP_SCNDX;
    			}
    			else if ((nrg = is_vreg(p, &p)) >= 0) {
    				op->ndxreg = nrg;
		    		p = skip(p);
		    		if (*p=='*') {
		    			p = skip(p+1);
		    			if(*p=='1') {
		    				op->scale = 0;
		    				p = skip(p);
		    			}
		    			else if (*p=='2') {
		    				op->scale = 1;
		    				p = skip(p);
		    			}
		    			else if (*p=='4') {
		    				op->scale = 2;
		    				p = skip(p);
		    			}
		    			else if (*p=='8') {
		    				op->scale = 3;
		    				p = skip(p);
		    			}
		    			else if (*p==']')
		    				op->scale = -1;
		    			else {
		    				cpu_error(0);
		    				return (0);
		    			}
		    		}
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

  if (OP_DATA(op->type)) {  /* data relocs */
    return (REL_ABS);
  }

  else {  /* handle instruction relocs */
  	switch(op->format) {
  	case B:
  	case BL:
  	case B2:
  	case BL2:
  	case B3:
  	case BL3:
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

    case J:
    case JL:
    case J2:
    case JL2:
    case J3:
    case JL3:
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
      if (OP_DATA(op->type)) {  /* data operand */
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
        printf("reloctype=%d\n", reloctype);
        printf("addend:%llx\n", addend);
      	switch(op->format) {
      	/* Conditional jump */
      	case J:
      	case JL:
		      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           11,4,0,0x1eLL);
		      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           32,16,0,0x1fffe0LL);
          break;
      	/* Unconditional jump */
        case J2:
        case JL2:
		      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           11,18,0,0x7fffeLL);
		      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           32,16,0,0x7fff80000LL);
          break;
				/* Short conditional jump */
      	case J3:
      	case JL3:
		      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           11,4,0,0x1eLL);
		      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           21,8,0,0x1fe0LL);
          break;
        case RIL:
        	if (abits < 24) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           21,23,0,0x7fffffLL);
        	}
        	else if (abits < 31) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,7,0,0x3f800000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           37,23,0,0x7fffffLL);
        		
        	}
        	else if (abits < 47) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,23,0,0x3fffff800000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           53,23,0,0x7fffffLL);
        	}
        	else {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,2,0,0x1800000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,39,0,0xfffffffffe000000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           69,23,0,0x7fffffLL);
        		
        	}
        	break;
        case DIRECT:
        	if (abits < 25) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           21,24,0,0xffffffLL);
        	}
        	else if (abits < 31) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,7,0,0x3f800000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           37,24,0,0xffffffLL);
        		
        	}
        	else if (abits < 47) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,23,0,0x3fffff800000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           53,24,0,0xffffffLL);
        	}
        	else {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,2,0,0x1800000LL);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           9,39,0,0xfffffffffe000000LL);
            /* might need a fix here for another bit */
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           69,24,0,0xffffffLL);
        		
        	}
        	break;
        case REGIND:
        	if (op->basereg==sdreg) {
        		reloctype = REL_SD;
        		if (abits < 25) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           21,24,0,0xffffffLL);
        		}
	        	else if (abits < 31) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,7,0,0x3f800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           37,24,0,0xffffffLL);
	        		
	        	}
	        	else if (abits < 47) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,23,0,0x3fffff800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           53,24,0,0xffffffLL);
	        	}
	        	else {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           0,2,0,0x1800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,39,0,0xfffffffffe000000LL);
	            /* might need a fix here for another bit */
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           69,24,0,0xffffffLL);
						}        		
        	}
        	else if (op->basereg==sd2reg) {
        		int org_sdr = sdreg;
        		sdreg = sd2reg;
        		reloctype = REL_SD;
        		if (abits < 25) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           21,24,0,0xffffffLL);
        		}
	        	else if (abits < 31) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,7,0,0x3f800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           37,24,0,0xffffffLL);
	        		
	        	}
	        	else if (abits < 47) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,23,0,0x3fffff800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           53,24,0,0xffffffLL);
	        	}
	        	else {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           0,2,0,0x1800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,39,0,0xfffffffffe000000LL);
	            /* might need a fix here for another bit */
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           69,24,0,0xffffffLL);
						}
						sdreg = org_sdr;        		
        	}
        	else if (op->basereg==sd3reg) {
        		int org_sdr = sdreg;
        		sdreg = sd3reg;
        		reloctype = REL_SD;
        		if (abits < 25) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           21,24,0,0xffffffLL);
        		}
	        	else if (abits < 31) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,7,0,0x3f800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           37,24,0,0xffffffLL);
	        		
	        	}
	        	else if (abits < 47) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,23,0,0x3fffff800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           53,24,0,0xffffffLL);
	        	}
	        	else {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           0,2,0,0x1800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,39,0,0xfffffffffe000000LL);
	            /* might need a fix here for another bit */
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           69,24,0,0xffffffLL);
						}
						sdreg = org_sdr;        		
        	}
        	else {
        		if (abits < 25) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           21,24,0,0xffffffLL);
        		}
	        	else if (abits < 31) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,7,0,0x3f800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           37,24,0,0xffffffLL);
	        		
	        	}
	        	else if (abits < 47) {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,23,0,0x3fffff800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           53,24,0,0xffffffLL);
	        	}
	        	else {
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           0,2,0,0x1800000LL);
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           9,39,0,0xfffffffffe000000LL);
	            /* might need a fix here for another bit */
				      add_extnreloc_masked(reloclist,base,addend,reloctype,
	                           69,24,0,0xffffffLL);
						}        		
        	}
        	break;
        default:
        		/* relocation of address as data */
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                          0,63,0,0x7fffffffffffffffLL);
//		      general_error(38);  /* illegal relocation */
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


static void eval_reg(uint64_t* insn, operand *op, mnemonic* mnemo, int i)
{
	if (insn) {
		switch(mnemo->ext.format) {
		case R2:
		case R3RI:
			if (i==0)
				*insn = *insn| (RT(op->basereg & 0x3f));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & 0x3f));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & 0x3f)) | (TB(0));
			break;
		case R3:
		case R3RR:
			if (i==0)
				*insn = *insn| (RT(op->basereg & 0x3f));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & 0x3f));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & 0x3f)) | (TB(0));
			else if (i==3)
				*insn = *insn| (RC(op->basereg & 0x3f)) | (TC(0));
			break;
		case B:
		case J:
			if (i==0)
				*insn = *insn| (RA(op->basereg & 0x3f));
			else if (i==1)
				*insn = *insn| (RB(op->basereg & 0x3f)) | (TB(0));
			break;
		case BL:
		case JL:
			if (i==1)
				*insn = *insn| (RA(op->basereg & 0x3f));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & 0x3f)) | (TB(0));
			break;
		case REGIND:
			if (i==0)
				*insn = *insn| (RT(op->basereg & 0x3f));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & 0x3f));
			break;
		case SCNDX:
			if (i==0)
				*insn = *insn| (RT(op->basereg & 0x3f));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & 0x3f));
			else if (i==2)
				*insn = *insn| (RB(op->basereg & 0x3f)) | (TB(0));
			break;
		case RIL:
			if (i==0)
				*insn = *insn| (RT(op->basereg & 0x3f));
			else if (i==1)
				*insn = *insn| (RA(op->basereg & 0x3f));
			break;
		case DIRECT:
			if (i==0)
				*insn = *insn| (RT(op->basereg & 0x3f));
			break;
		}				
	}
}

static size_t eval_immed(uint64_t *prefix, uint64_t *insn, mnemonic* mnemo,
	operand *op, int64_t val, int constexpr, int i, int selector)
{
	size_t isize;

	if (constexpr) {
		if (mnemo->ext.format==DIRECT) {
			if (selector==-1) {
				if (op->selector >= 0)
					selector = op->selector;
				else
					selector = select_selector(op->basereg & 0x3f, 0);
			}
			isize = 6;
			if (mnemo->ext.short_opcode) {
				if (is_nbit(val,8)) {
					isize = 4;
				}
			}
			if (!is_nbit(val,23)) {
				if (prefix)
					*prefix = ((val >> 23LL) << 9LL) | EXI7;
				isize = (2<<8)|6;
				if (!is_nbit(val,30)) {
					if (prefix)
						*prefix = ((val >> 23LL) << 9LL) | EXI23;
					isize = (4<<8)|6;
					if (!is_nbit(val,46)) {
						if (prefix)
							*prefix = ((val >> 25LL) << 9LL) | EXI41 | ((val >> 23) & 3LL);
 						isize = (6<<8)|6;
						if (!is_nbit(val,62)) {
							if (prefix)
								*prefix = ((val >> 23LL) << 9LL) | EXI55;
	 						isize = (8<<8)|6;
						}
					}
				}
			}
			if (insn) {
				switch(isize) {
				case 4:
					*insn = *insn | ((val & 0xffLL) << 21LL);
					*insn |= (selector & 7LL) << 29LL;
					break;
				case 6:	
					*insn = *insn | ((val & 0xffffffLL) << 21LL);
					*insn |= (selector & 7LL) << 45LL;
					break;
				case (2<<8)|6:
				case (4<<8)|6:
				case (6<<8)|6:
					*insn = *insn | ((val & 0xffffffLL) << 21LL);
					*insn |= (selector & 7LL) << 45LL;
					break;
				}
			}
		}
		else if (mnemo->ext.format == CSR) {
			isize = 6;
			if (insn) {
				*insn = *insn | ((val & 0xffffLL) << 21LL);
			}
		}
		else if (mnemo->ext.format == RTS) {
			isize = 2;
			if (insn)
				*insn = *insn | ((val & 0x1fLL) << 11LL);
		}
		else {
			if (op->type & OP_IMM11)
				isize = 4;
			else
				isize = 6;
			if (!is_nbit(val,11)) {
				isize = 6;
				if (!is_nbit(val,23)) {
					if (prefix)
						*prefix = ((val >> 23LL) << 9LL) | EXI7;
					isize = (2<<8)|6;
					if (!is_nbit(val,30)) {
						if (prefix)
							*prefix = ((val >> 23LL) << 9LL) | EXI23;
						isize = (4<<8)|6;
						if (!is_nbit(val,46)) {
							if (prefix)
								*prefix = ((val >> 25LL) << 9LL) | EXI41 | ((val >> 23) & 3LL);
	 						isize = (6<<8)|6;
							if (!is_nbit(val,64)) {
								if (prefix)
									*prefix = ((val >> 23LL) << 9LL) | EXI55;
		 						isize = (8<<8)|6;
							}
						}
					}
				}
			}
			if (insn) {
				switch(isize) {
				case 4:	
					*insn = *insn | ((val & 0x7ffLL) << 21LL);
					*insn = *insn & ~0xff;	// clear opcode
					*insn = *insn | mnemo->ext.short_opcode;
					break;
				case 6:	
				case (2<<8)|6:
				case (4<<8)|6:
				case (6<<8)|6:
				case (8<<8)|6:
					*insn = *insn | ((val & 0x7fffffLL) << 21LL);
					break;
				}
			}
		}
	}
	else {
		if (mnemo->ext.format==CSR) {
			isize = 6;
			cpu_error(2);
		}
		else if (abits < 24) {
			isize = 6;
			if (insn)
				*insn = *insn | ((val & 0x7fffffLL) << 21LL);
			if (prefix)
				*prefix = 0;
		}
		else if (abits < 31) {
			isize = (2<<8)|6;
			if (insn)
				*insn = *insn | ((val & 0x7fffffLL) << 21LL);
			if (prefix)
				*prefix = ((val >> 23LL) << 9LL) | EXI7;
		}
		else if (abits < 46) {
			isize = (4<<8)|6;
			if (insn)
				*insn = *insn | ((val & 0x7fffffLL) << 21LL);
			if (prefix)
				*prefix = ((val >> 23LL) << 9LL) | EXI23;
		}
		else if (abits < 64) {
			isize = (6<<8)|6;
			if (insn)
				*insn = *insn | ((val & 0x7fffffLL) << 21LL);
			if (prefix)
				*prefix = ((val >> 25LL) << 9LL) | EXI41 | ((val >> 23) & 3LL);
		}
		else {
			isize = (8<<8)|6;
			if (insn)
				*insn = *insn | ((val & 0x7fffffLL) << 21LL);
			if (prefix)
				*prefix = ((val >> 23LL) << 9LL) | EXI55;
		}
	}
	return (isize);
}

/* Evaluate branch operands excepting GPRs which are handled earlier.
	Returns 1 if the branch was processed, 0 if illegal branch format.
*/
static int eval_branch(uint64_t* insn, mnemonic* mnemo, operand* op, int64_t val, int* isize, int i)
{
	*isize = 6;

	TRACE("evb:");
	switch(mnemo->ext.format) {

	case B:
		if (op->type == OP_IMM) {
			if (insn) {
				switch(i) {
				case 1:
					*insn |= RB(val) | TB(2);
					break;
				case 2:
			  	if (insn) {
			  		uint64_t tgt;
			  		*insn |= CA(7);
			  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffffLL) << 32LL);
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
					*insn |= RB(val) | TB(2);
					break;
				case 2:
		  		uint64_t tgt;
		  		*insn |= CA(0);
		  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffffLL) << 32LL);
		  		*insn |= tgt;
		  		break;
	  		}
	  	}
	  	return (1);
		}
	  if (op->type==OP_CAREGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(op->basereg & 0x7);
	  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffffLL) << 32LL);
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
					*insn |= RB(val) | TB(2);
					break;
				case 3:
		  		uint64_t tgt;
		  		*insn |= CA(0);
		  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffffLL) << 32LL);
		  		*insn |= tgt;
		  		break;
	  		}
	  	}
	  	return (1);
		}
	  if (op->type==OP_CAREGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(op->basereg & 0x7);
	  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffffLL) << 32LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case B2:
	  if (op->type==OP_IMM) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(mnemo->ext.format==B2 ? 0x7 : 0x0);
	  		tgt = (((val >> 1LL) & 0x3ffffLL) << 11LL) | (((val >> 19LL) & 0xffffLL) << 32LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case J2:
	  if (op->type==OP_IMM) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(mnemo->ext.format==B2 ? 0x7 : 0x0);
	  		tgt = (((val >> 1LL) & 0x3ffffLL) << 11LL) | (((val >> 19LL) & 0xffffLL) << 32LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
		}
	  if (op->type==OP_CAREGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(op->basereg & 0x7);
	    		tgt = (((val >> 1LL) & 0x3ffffLL) << 11LL) | (((val >> 19LL) & 0xffffLL) << 32LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case BL2:
  	if (op->type==OP_IMM) {
	  	if (insn) {
    		uint64_t tgt;
    		*insn |= CA(mnemo->ext.format==BL2 ? 0x7 : 0x0);
    		tgt = (((val >> 1LL) & 0x3ffffLL) << 11LL) | (((val >> 19LL) & 0xffffLL) << 32LL);
    		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  break;

	case JL2:
  	if (op->type==OP_IMM) {
	  	if (insn) {
    		uint64_t tgt;
    		*insn |= CA(mnemo->ext.format==BL2 ? 0x7 : 0x0);
    		tgt = (((val >> 1LL) & 0x3ffffLL) << 11LL) | (((val >> 19LL) & 0xffffLL) << 32LL);
    		*insn |= tgt;
	  	}
	  	return (1);
	  }
	  if (op->type==OP_CAREGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(op->basereg & 0x7);
	    		tgt = (((val >> 1LL) & 0x3ffffLL) << 11LL) | (((val >> 19LL) & 0xffffLL) << 32LL);
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
			  		*insn |= CA(7);
			  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffLL) << 21LL);
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
			  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffLL) << 21LL);
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
	  if (op->type==OP_CAREGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(op->basereg & 0x7);
	  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffLL) << 21LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
		else if (op->type == OP_IMM) {
			if (insn) {
				switch(i) {
				case 1:
			  	if (insn) {
			  		uint64_t tgt;
			  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffLL) << 21LL);
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
	  if (op->type==OP_CAREGIND) {
	  	if (insn) {
	  		uint64_t tgt;
	  		*insn |= CA(op->basereg & 0x7);
	  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffLL) << 21LL);
	  		*insn |= tgt;
	  	}
	  	return (1);
	  }
		else if (op->type == OP_IMM) {
			if (insn) {
				switch(i) {
				case 2:
			  	if (insn) {
			  		uint64_t tgt;
			  		tgt = (((val >> 1LL) & 0xfLL) << 11LL) | (((val >> 5LL) & 0xffLL) << 21LL);
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
size_t eval_thor_operands(instruction *ip,section *sec,taddr pc,
                     uint64_t *prefix, uint64_t *insn, dblock *db)
{
  mnemonic *mnemo = &mnemonics[ip->code];
  size_t isize;
  int i;
  operand op;
	char selector = -1;
	int constexpr;
	int reg = 0;

	TRACE("Eto:");
	isize = mnemo->ext.len;
  if (insn != NULL) {
    *insn = mnemo->ext.opcode;
    if (pc & 1)
      cpu_error(19);  /* bad instruction alignment */
   }

	if (prefix)
		*prefix = 0;

  for (i=0; i<MAX_OPERANDS && ip->op[i]!=NULL; i++) {
    operand *pop;
    int reloctype;
    taddr val;

		TRACE("F");
    op = *(ip->op[i]);
    /* reflect the format back into the operand */
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
            val -= pc;
        }
      }
    }
    else {
      if (!eval_expr(op.value,&val,sec,pc))
        if (insn != NULL) {
//	    	printf("***A4 val:%lld****", val);
//          cpu_error(2);  /* constant integer expression required */
        }
    }

		TRACE("Ethof:");
    if (db!=NULL && op.type==OP_REGIND && op.attr==REL_NONE) {
			TRACE("Ethof1:");
      if (op.basereg == sdreg) {  /* is it a small data reference? */
				TRACE("Ethof3:");
        fix_reloctype(db,REL_SD);
//        else if (reg == sd2reg)  /* EABI small data 2 */
//          fix_reloctype(db,REL_PPCEABI_SDA2);
			}
    }

		TRACE("Etho2:");
		if (op.type==OP_REG) {
			eval_reg(insn, &op, mnemo, i);
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
 					if (i==2)	// it must be
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
			isize = eval_immed(prefix, insn, mnemo, &op, val, constexpr, i, selector);
    }
    else if (eval_branch(insn, mnemo, &op, val, &isize, i)) {
			TRACE("Etho4:");
    	;
    }
    else if ((mnemo->operand_type[i]&OP_REGIND) && op.type==OP_REGIND) {
			TRACE("Etho5:");
    	// Check for short form
    	if (constexpr) {
	    	if (is_nbit(val,8) && (mnemo->ext.opcode==0x86LL || mnemo->ext.opcode==0x93LL)) {
	    		isize = 4;
	    		if (insn) {
	    			if (mnemo->ext.opcode==0x86LL)
	    				*insn = (*insn & ~0xffLL) | 0x87LL;
	    			else
	    				*insn = (*insn & ~0xffLL) | 0x95LL;
		    		if (i==0)
		    			*insn |= (RT(op.basereg & 0x3f));
		    		else if (i==1) {
		    			*insn |= (RA(op.basereg & 0x3f));
		    			if (selector==-1) {
		    				if (op.selector >= 0)
		    					selector = op.selector;
		    				else
		    					selector = select_selector(op.basereg & 0x3f, 0);
		    			}
		    			*insn |= (selector & 7LL) << 29LL;
		    			*insn |= ((val & 0xffLL) << 21LL);
		    		}
	    		}
	    	}
	    	// Else long form
	    	else {
	    		isize = 6;
	    		if (insn) {
		    		if (i==0)
		    			*insn |= (RT(op.basereg & 0x3f));
		    		else if (i==1) {
		    			*insn |= (RA(op.basereg & 0x3f));
		    			if (selector==-1) {
		    				if (op.selector >= 0)
		    					selector = op.selector;
		    				else
		    					selector = select_selector(op.basereg & 0x3f, 0);
		    			}
		    			*insn |= (selector & 7LL) << 45LL;
		    			*insn |= (val & 0xffffffLL) << 21LL;
		    		}
	    		}
	    		if (!is_nbit(val,24) && abits > 23) {
	    			if (prefix)
							*prefix = ((val >> 23LL) << 9LL) | EXI7;
						isize = (2<<8)|6;
						if (!is_nbit(val,30) && abits > 30) {
							if (prefix)
								*prefix = ((val >> 23LL) << 9LL) | EXI23;
	 						isize = (4<<8)|6;
							if (!is_nbit(val,46) && abits > 46) {
								if (prefix)
									*prefix = ((val >> 25LL) << 9LL) | EXI41 | ((val >> 23LL) & 3LL);
		 						isize = (6<<8)|6;
								if (!is_nbit(val,62) && abits > 62) {
									if (prefix)
										*prefix = ((val >> 23LL) << 9LL) | EXI55;
			 						isize = (8<<8)|6;
								}
							}
						}
					}
				}
  		}
  		else {
    		if (abits < 24) {
  				isize = 6;
  				if (insn)
						*insn = *insn | ((val & 0xffffffLL) << 21LL);
					if (prefix)
						*prefix = 0;
    		}
    		else if (abits < 31) {
  				isize = (2<<8)|6;
  				if (insn)
						*insn = *insn | ((val & 0xffffffLL) << 21LL);
					if (prefix)
						*prefix = ((val >> 23LL) << 9LL) | EXI7;
    		}
    		else if (abits < 46) {
  				isize = (4<<8)|6;
  				if (insn)
						*insn = *insn | ((val & 0xffffffLL) << 21LL);
					if (prefix)
						*prefix = ((val >> 23LL) << 9LL) | EXI23;
    		}
    		else {
  				isize = (6<<8)|6;
  				if (insn)
						*insn = *insn | ((val & 0xffffffLL) << 21LL);
					if (prefix)
						*prefix = ((val >> 25LL) << 9LL) | EXI41 | ((val >> 23) & 3LL);
    		}
  		}
    }
    else if ((mnemo->operand_type[i]&OP_SCNDX) && op.type==OP_SCNDX) {
			TRACE("Etho6:");
    	isize = 6;
  		if (insn) {
  			*insn |= (RA(op.basereg & 0x3f));
  			if (selector==-1) {
  				if (op.selector >= 0)
  					selector = op.selector;
  				else
  					selector = select_selector(op.basereg & 0x3f, op.ndxreg & 0x3f);
  			}
  			*insn |= (selector & 7LL) << 32LL;
  			//*insn |= ((val & 0xffLL) << 21LL);
  			*insn |= RB(op.ndxreg & 0x3fLL);
  			*insn |= SC(op.scale & 0x7LL);
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
	size_t sz = eval_thor_operands(ip,sec,pc,NULL,NULL,NULL);
	sz = (sz & 0xff) + (sz >> 8);
	TRACE2("isize=%d ", sz);
  return (sz);
}


/* Convert an instruction into a DATA atom including relocations,
   when necessary. */
dblock *eval_instruction(instruction *ip,section *sec,taddr pc)
{
  dblock *db = new_dblock();
  uint64_t prefix;
  uint64_t insn;
  size_t sz;

	sz = eval_thor_operands(ip,sec,pc,&prefix,&insn,db);
	db->size = (sz & 0xff) + (sz >> 8);
  if (db->size) {
    unsigned char *d = db->data = mymalloc(db->size);
    int i;

		if (sz >> 8)
	    d = setval(0,d,sz >> 8,prefix);
    d = setval(0,d,sz & 0xff,insn);
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
//  if (!OP_DATA(op->type))
//    ierror(0);

  db->size = bitsize >> 3;
  db->data = mymalloc(db->size);

  if (type_of_expr(op->value) == FLT) {
    if (!eval_expr_float(op->value,&flt))
      general_error(60);  /* cannot evaluate floating point */

    switch (bitsize) {
      case 32:
        conv2ieee32(1,db->data,flt);
        break;
      case 64:
        conv2ieee64(1,db->data,flt);
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
