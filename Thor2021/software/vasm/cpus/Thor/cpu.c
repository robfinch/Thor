#include "vasm.h"

char *cpu_copyright="vasm Thor cpu backend (c) in 2021 Robert Finch";

char *cpuname="Thor";
int bitsperbyte=8;
int bytespertaddr=8;

mnemonic mnemonics[]={
	"add", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x080000000002LL,6},	// 3r
	"add", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x080000000002LL,6},	// 3r
	"add", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x080000000102LL,6},	// 3r
	"add", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x080000000102LL,6},	// 3r
	"add", {OP_REG,OP_REG,OP_REG|OP_IMM7,VM_REG,0}, {R3,CPU_ALL,0,0x080000000002LL,6},	// 2r
	"add", {OP_REG,OP_REG,OP_REG|OP_IMM7,0}, {R2,CPU_ALL,0,0x19LL,4},	// 2r
	"add", {OP_REG,OP_REG,OP_IMM,OP_VMREG,0}, {R3,CPU_ALL,0,0xD4LL,6},
	"add", {OP_REG,OP_REG,OP_IMM,0,0}, {R3,CPU_ALL,0,0xD4LL,6},

	"and", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x100000000002LL,6},	// 3r
	"and", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x100000000002LL,6},	// 3r
	"and", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x100000000102LL,6},	// 3r
	"and", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x100000000102LL,6},	// 3r
	"and", {OP_REG,OP_REG,OP_REG|OP_IMM7,VM_REG,0}, {R3,CPU_ALL,0,0x100000000002LL,6},	// 2r
	"and", {OP_REG,OP_REG,OP_REG|OP_IMM7,0}, {R2,CPU_ALL,0,0x1ALL,4},	// 2r
	"and", {OP_REG,OP_REG,OP_IMM,OP_VMREG,0}, {R3,CPU_ALL,0,0xD8LL,6},
	"and", {OP_REG,OP_REG,OP_IMM,0,0}, {R3,CPU_ALL,0,0xD8LL,6},

	"beq",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E0000026LL,6},
	"beq",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E0000026LL,6},
	"bge",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E0000029LL,6},
	"bge",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E0000029LL,6},
	"bgt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000002BLL,6},
	"bgt",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000002BLL,6},
	"ble",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000002ALL,6},
	"ble",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000002ALL,6},
	"blt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E0000028LL,6},
	"blt",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E0000028LL,6},
	"bgeu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000002DLL,6},
	"bgeu",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000002DLL,6},
	"bgtu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000002FLL,6},
	"bgtu",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000002FLL,6},
	"bleu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000002ELL,6},
	"bleu",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000002ELL,6},
	"bltu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000002CLL,6},
	"bltu",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000002CLL,6},
	"bne",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E0000027LL,6},
	"bne",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E0000027LL,6},

	"bra",	{OP_BRTGT34,0,0,0,0}, {B2,CPU_ALL,0,0x0000E0000020LL,6},
	"bsr",	{OP_LK,OP_BRTGT34,0,0,0}, {B2,CPU_ALL,0,0x0000E0000020LL,6},
	"bsr",	{OP_BRTGT34,0,0,0,0}, {B2,CPU_ALL,0,0x0000E0000020LL,6},

	"dbeq",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E0000036LL,6},
	"dbeq",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E0000036LL,6},
	"dbge",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E0000039LL,6},
	"dbge",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E0000039LL,6},
	"dbgt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000003BLL,6},
	"dbgt",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000003BLL,6},
	"dble",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000003ALL,6},
	"dble",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000003ALL,6},
	"dblt",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E0000038LL,6},
	"dblt",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E0000038LL,6},
	"dbgeu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000003DLL,6},
	"dbgeu",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000003DLL,6},
	"dbgtu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000003FLL,6},
	"dbgtu",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000003FLL,6},
	"dbleu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000003ELL,6},
	"dbleu",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000003ELL,6},
	"dbltu",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E000003CLL,6},
	"dbltu",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E000003CLL,6},
	"dbne",	{OP_LK,OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0}, {BL,CPU_ALL,0,0x0000E0000037LL,6},
	"dbne",	{OP_REG,OP_REG|OP_IMM7,OP_BRTGT20,0,0}, {B,CPU_ALL,0,0x0000E0000037LL,6},

	"jmp",	{OP_BRTGT34,0,0,0,0}, {J2,CPU_ALL,0,0x00000020LL,6},
	"jsr",	{O_LK,OP_BRTGT34,0,0,0,0}, {JL2,CPU_ALL,0,0x00000020LL,6},
	"jsr",	{OP_BRTGT34,0,0,0,0}, {J2,CPU_ALL,0,0x00000020LL,6},

	"ldb",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {LS,CPU_ALL,0,0x80LL,6},	
	"ldb",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xB0LL,6},	
	"ldbu",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {LS,CPU_ALL,0,0x81LL,6},	
	"ldbu",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xB1LL,6},	
	"ldo",	{OP_REG,OP_SEL|OP_REGIND8,0,0,0}, {LS,CPU_ALL,0,0x87LL,4},	
	"ldo",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {LS,CPU_ALL,0,0x86LL,6},	
	"ldo",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xB6LL,6},	
	"ldt",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {LS,CPU_ALL,0,0x84LL,6},	
	"ldt",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xB4LL,6},	
	"ldtu",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {LS,CPU_ALL,0,0x85LL,6},	
	"ldtu",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xB5LL,6},	
	"ldw",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {LS,CPU_ALL,0,0x82LL,6},	
	"ldw",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xB2LL,6},	
	"ldwu",	{OP_REG,OP_SEL|OP_REGIND,0,0}, {LS,CPU_ALL,0,0x83LL,6},	
	"ldwu",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xB3LL,6},	

	"move",	{OP_REG,OP_REG,0,0,0}, {MV,CPU_ALL,0,0x0817F00000AALL,6},

	"or", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x120000000002LL,6},	// 3r
	"or", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x120000000002LL,6},	// 3r
	"or", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x120000000102LL,6},	// 3r
	"or", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x120000000102LL,6},	// 3r
	"or", {OP_REG,OP_REG,OP_REG|OP_IMM7,VM_REG,0}, {R3,CPU_ALL,0,0x120000000002LL,6},	// 2r
	"or", {OP_REG,OP_REG,OP_REG|OP_IMM7,0}, {R2,CPU_ALL,0,0x1DLL,4},	// 2r
	"or", {OP_REG,OP_REG,OP_IMM,OP_VMREG,0}, {R3,CPU_ALL,0,0xD9LL,6},
	"or", {OP_REG,OP_REG,OP_IMM,0,0}, {R3,CPU_ALL,0,0xD9LL,6},

	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x860000000002LL,6},	// 3r
	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x860000000002LL,6},	// 3r
	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,VM_REG,0}, {R3,CPU_ALL,0,0x860000000002LL,6},	// 3r
	"rol",	{OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x860000000002LL,6},	// 3r

	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x880000000002LL,6},	// 3r
	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x880000000002LL,6},	// 3r
	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,VM_REG,0}, {R3,CPU_ALL,0,0x880000000002LL,6},	// 3r
	"ror",	{OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x880000000002LL,6},	// 3r

	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x800000000002LL,6},	// 3r
	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x800000000002LL,6},	// 3r
	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_VMREG,0}, {R2,CPU_ALL,0,0x58,4},
	"sll",	{OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R2,CPU_ALL,0,0x58,4},

	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x840000000002LL,6},	// 3r
	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x840000000002LL,6},	// 3r
	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,VM_REG,0}, {R3,CPU_ALL,0,0x840000000002LL,6},	// 3r
	"sra",	{OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x840000000002LL,6},	// 3r

	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x820000000002LL,6},	// 3r
	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x820000000002LL,6},	// 3r
	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,VM_REG,0}, {R3,CPU_ALL,0,0x820000000002LL,6},	// 3r
	"srl",	{OP_REG,OP_REG,OP_REG|OP_IMM7,0,0}, {R3,CPU_ALL,0,0x820000000002LL,6},	// 3r

	"stb",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {LS,CPU_ALL,0,0x90LL,6},	
	"stb",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xC0LL,6},	
	"sto",	{OP_REG,OP_SEL|OP_REGIND8,0,0,0}, {LS,CPU_ALL,0,0x95LL,4},	
	"sto",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {LS,CPU_ALL,0,0x93LL,6},	
	"sto",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xC3LL,6},	
	"stt",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {LS,CPU_ALL,0,0x92LL,6},	
	"stt",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xC2LL,6},	
	"stw",	{OP_REG,OP_SEL|OP_REGIND,0,0,0}, {LS,CPU_ALL,0,0x91LL,6},	
	"stw",	{OP_REG,OP_SEL|OP_SCNDX,0,0,0}, {LS,CPU_ALL,0,0xC1LL,6},	

	"xor", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x140000000002LL,6},	// 3r
	"xor", {OP_REG,OP_REG,OP_REG|OP_IMM7,OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x140000000002LL,6},	// 3r
	"xor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,0}, {R3,CPU_ALL,0,0x140000000102LL,6},	// 3r
	"xor", {OP_VREG,OP_VREG,OP_VREG|OP_REG|OP_IMM7,OP_VREG|OP_REG|OP_IMM7,OP_VMREG}, {R3,CPU_ALL,0,0x140000000102LL,6},	// 3r
	"xor", {OP_REG,OP_REG,OP_REG|OP_IMM7,VM_REG,0}, {R3,CPU_ALL,0,0x140000000002LL,6},	// 2r
	"xor", {OP_REG,OP_REG,OP_REG|OP_IMM7,0}, {R2,CPU_ALL,0,0x1ELL,4},	// 2r
	"xor", {OP_REG,OP_REG,OP_IMM,OP_VMREG,0}, {R3,CPU_ALL,0,0xDALL,6},
	"xor", {OP_REG,OP_REG,OP_IMM,0,0}, {R3,CPU_ALL,0,0xDALL,6},

};

int mnemonic_cnt=sizeof(mnemonics)/sizeof(mnemonics[0]);

char *parse_instruction(char *s,int *inst_len,char **ext,int *ext_len,
                        int *ext_cnt)
/* parse instruction and save extension locations */
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

int set_default_qualifiers(char **q,int *q_len)
/* fill in pointers to default qualifiers, return number of qualifiers */
{
  q[0] = "o";
  q_len[0] = 1;
  return (1);
}

static int is_nbit(int64_t val, int64_t n)
{
	int64_t low, high;
  if (n > 63)
    return (true);
	low = -(1LL << (n - 1LL));
	high = (1LL << (n - 1LL));
	return (val >= low && val < high);
}

static int is_reg(char *p, **ep)
{
	int rg = -1;

	*ep = p;
	if (*p != 'r' && *p != 'R') {
		return (-1);
	}
	if (isdigit((unsigned char)p[1]) && isdigit((unsigned char)p[2]) && !isalnum((unsigned char)p[3]) && p[3] != '_') {
		rg = (p[1]-'0')*10 + p[2]-'0';
		if (rg < 64) {
			ep = &p[3];
			return (rg);
		}
		return (-1);
	}
	if (isdigit((unsigned char)p[1]) && !isalnum((unsigned char)p[2]) && p[2] != '_') {
		rg = p[1]-'0';
		ep = &p[2];
		return (rg);
	}
	return (-1);
}

static int is_vreg(char *p, **ep)
{
	int rg = -1;

	*ep = p;
	if (*p != 'v' && *p != 'V') {
		return (-1);
	}
	if (isdigit((unsigned char)p[1]) && isdigit((unsigned char)p[2]) && !isalnum((unsigned char)p[3]) && p[3] != '_') {
		rg = (p[1]-'0')*10 + p[2]-'0';
		if (rg < 64) {
			ep = &p[3];
			return (rg);
		}
		return (-1);
	}
	if (isdigit((unsigned char)p[1]) && !isalnum((unsigned char)p[2]) && p[2] != '_') {
		rg = p[1]-'0';
		ep = &p[2];
		return (rg);
	}
	return (-1);
}

static int is_lkreg(char *p, **ep)
{
	int rg = -1;

	*ep = p;
	if (*p != 'l' && *p != 'L') {
		return (-1);
	}
	if (p[1] != 'k' && p[1] != 'K') {
		return (-1);
	}
	if (isdigit((unsigned char)p[2]) && !isalnum((unsigned char)p[3]) && p[3] != '_') {
		rg = p[2]-'0';
		if (rg < 4) {
			ep = &p[3];
			return (rg);
		}
	}
	return (-1);
}

static int is_careg(char *p, **ep)
{
	int rg = -1;

	*ep = p;
	if (*p != 'c' && *p != 'C') {
		return (-1);
	}
	if (p[1] != 'a' && p[1] != 'A') {
		return (-1);
	}
	if (isdigit((unsigned char)p[2]) && !isalnum((unsigned char)p[3]) && p[3] != '_') {
		rg = p[2]-'0';
		ep = &p[3];
		return (rg);
	}
	return (-1);
}

static int is_vmreg(char *p, **ep)
{
	int rg = -1;

	*ep = p;
	if (*p != 'v' && *p != 'V') {
		return (-1);
	}
	if (p[1] != 'm' && p[1] != 'M') {
		return (-1);
	}
	if (isdigit((unsigned char)p[2]) && !isalnum((unsigned char)p[3]) && p[3] != '_') {
		rg = p[2]-'0';
		if (rg < 8) {
			ep = &p[3];
			return (rg);
		}
	}
	return (-1);
}

static int is_selector(char *p, char **ep)
{
	static char *sels[8] = { "ZS", "DS", "ES", "FS", "GS", "HS", "SS", "CS" };
	int n;
	
	*ep = p;
	for (n = 0; n < 8; n++) {
		if (toupper(*p)==sels[n][0]) && toupper(p[1])==sels[n][1] && p[2]==':') {
			*ep = &p[3];
			return (n);
		}
	}
	return (-1);
}

int parse_operand(char *p,int len,operand *op,int requires)
{
	int rg, nrg;
	int rv = PO_NOMATCH;

	op->selector = -1;
  p=skip(p);
  if ((rg = is_reg(p, &p)) >= 0) {
    op->type=OP_REG;
    op->basereg=rg;
  }
  else if ((rg = is_vreg(p, &p)) >= 0) {
    op->type=OP_VREG;
    op->basereg=rg;
  }
  else if ((rg = is_careg(p, &p)) >= 0) {
    op->type=OP_CAREG;
    op->basereg=rg;
  }
  else if ((rg = is_vmreg(p, &p)) >= 0) {
    op->type=OP_VMREG;
    op->basereg=rg;
  }
  else if ((rg = is_lkreg(p, &p)) >= 0) {
    op->type=OP_LKREG;
    op->basereg=rg;
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
    tree=parse_expr(&p);
    if(!tree)
      return 0;
   	op->type = requires;
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
    op->offset=tree;
  }
  if(requires & op->type)
    return (PO_MATCH);
  return (PO_NOMATCH);
}

/* Return new instruction code, if instruction can be optimized
   to another one. */
static int opt_inst(instruction *p,section *sec,taddr pc)
{
  /* Ganz simples Beispiel. */

  /* add->addq */
  if((p->code==2||p->code==4)&&p->op[0]->type==OP_IMM32){
    taddr val;
    if(eval_expr(p->op[0]->offset,&val,sec,pc)&&val<16)
      return 5;
  }
  /* jmp->bra */
  if(p->code==6){
    expr *tree=p->op[0]->offset;
    if(tree->type==SYM&&tree->c.sym->sec==sec&&LOCREF(tree->c.sym)&&
       tree->c.sym->pc-pc>=-128&&tree->c.sym->pc-pc<=127)
      return 7;
  }
  return p->code;
}

operand *new_operand()
{
  operand *nw=mymalloc(sizeof(*nw));
  nw->type=-1;
  return nw;
}

size_t eval_thor_operands(instruction *ip,section *sec,taddr pc,
                     uint64_t *prefix, uint64_t *insn, dblock *db)
/* evaluate expressions and try to optimize instruction,
   return size of instruction */
{
  mnemonic *mnemo = &mnemonics[ip->code];
  size_t isize;
  int i;
  operand op;

	isize = mnemo->len;
  if (insn != NULL)
    *insn = mnemo->ext.opcode;

  for (i=0; i<MAX_OPERANDS && ip->op[i]!=NULL; i++) {
    operand *pop;
    int reloctype;
    taddr val;

    op = *(ip->op[i]);

    if (op.type == NEXT) {
      /* special case: operand omitted and use this operand's type + 1
         for the next operand */
      op = *(ip->op[++i]);
      op.type = mnemo->operand_type[i-1] + 1;
    }

    if ((reloctype = get_reloc_type(&op)) != REL_NONE) {
      if (db != NULL) {
        val = make_reloc(reloctype,&op,sec,pc,&db->relocs);
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
        if (insn != NULL)
          cpu_error(2);  /* constant integer expression required */
    }

		if (mnemo->operand_type[i]==OP_REG) {
			if (*insn) {
 				switch(mnemo->ext.format) {
 				case R2:
 					if (i==0)
 						*insn = *insn| (RT(op.basereg & 0x3f));
 					else if (i==1)
 						*insn = *insn| (RA(op.basereg & 0x3f));
 					else if (i==2)
 						*insn = *insn| (RB(op.basereg & 0x3f)) | (TB(0));
 					break;
 				case R3:
 					if (i==0)
 						*insn = *insn| (RT(op.basereg & 0x3f));
 					else if (i==1)
 						*insn = *insn| (RA(op.basereg & 0x3f));
 					else if (i==2)
 						*insn = *insn| (RB(op.basereg & 0x3f)) | (TB(0));
 					else if (i==3)
 						*insn = *insn| (RC(op.basereg & 0x3f)) | (TC(0));
 					break;
 				case B:
 					if (i==0)
 						*insn = *insn| (RA(op.basereg & 0x3f));
 					else if (i==1)
 						*insn = *insn| (RB(op.basereg & 0x3f)) | (TB(0));
 					break;
 				case BL:
 					if (i==1)
 						*insn = *insn| (RA(op.basereg & 0x3f));
 					else if (i==2)
 						*insn = *insn| (RB(op.basereg & 0x3f)) | (TB(0));
 					break;
				}				
			}
		}
		else if (mnemo->operand_type[i]==OP_LKREG) {
			if (*insn) {
 				switch(mnemo->ext.format) {
 				case JL2:
 				case BL:
 					if (i==0)
 						*insn = *insn| (RT(op.basereg & 0x3));
 					break;
 				default:
 					cpu_error(18);
				}				
			}
		}
    else if ((mnemo->operand_type[i]&OP_IMM7) && op.type==OP_IMM) {
 			if (!is_nbit(val, 7)) {
 				cpu_error(12,val,-64,64);
 			}
 			if (*insn) {
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
 					if (i==2)
 						*insn = *insn| (TB(2|((val>>6) & 1))) | (RB(val & 0x3f));
 					break;
 				case B:
 					if (i==1)
 						*insn = *insn| (TB(2|((val>>6) & 1))) | (RB(val & 0x3f));
 					break;
 				}
 			}
    }
    else if (&mnemo->operand_type[i]&OP_IMM) && op.type==OP_IMM) {
  		if (op.type & OP_IMM11) {
  			isize = 4;
  			if (!is_nbit(val,11)) {
  				isize = 6;
					if (!is_nbit(val,23)) {
						op.prefix = ((val >> 23LL) << 9LL) | EXI7;
 						isize = 8;
						if (!is_nbit(val,30)) {
							op.prefix = ((val >> 23LL) << 9LL) | EXI23;
							isize = 10;
							if (!is_nbit(val,46)) {
								op.prefix = ((val >> 23LL) << 9LL) | EXI39;
								isize = 12;
								if (!is_nbit(val,62)) {
  								op.prefix = ((val >> 23LL) << 9LL) | EXI55;
									isize = 14;
								}
							}
						}
					}
  			}
    	}
    	else if (op.type==OP_REGIND) {
    		// Short register indirect
    		if (op.type & OP_REGIND8) {
	    		isize = 4;
	    		if (!is_nbit(val,8)) {
	    			isize = 6;
		    		if (!is_nbit(val,24)) {
							op.prefix = ((val >> 23LL) << 9LL) | EXI7;
							isize = 8;
							if (!is_nbit(val,30)) {
								op.prefix = ((val >> 23LL) << 9LL) | EXI23;
								isize = 10;
								if (!is_nbit(val,46)) {
									op.prefix = ((val >> 23LL) << 9LL) | EXI39;
									isize = 12;
									if (!is_nbit(val,62)) {
										op.prefix = ((val >> 23LL) << 9LL) | EXI55;
										isize = 14;
									}
								}
							}
						}
					}
    		}
    		else {
    			isize = 6;
	    		if (!is_nbit(val,24)) {
						op.prefix = ((val >> 23LL) << 9LL) | EXI7;
						isize = 8;
						if (!is_nbit(val,30)) {
							op.prefix = ((val >> 23LL) << 9LL) | EXI23;
							isize = 10;
							if (!is_nbit(val,46)) {
								op.prefix = ((val >> 23LL) << 9LL) | EXI39;
								isize = 12;
								if (!is_nbit(val,62)) {
									op.prefix = ((val >> 23LL) << 9LL) | EXI55;
									isize = 14;
								}
							}
						}
					}
    		}
    	}
    }
	}
}

size_t instruction_size(instruction *ip,section *sec,taddr pc)
/* Calculate the size of the current instruction; must be identical
   to the data created by eval_instruction. */
{
  return (eval_thor_operands(ip,sec,pc,NULL,NULL,NULL));
}


dblock *eval_instruction(instruction *ip,section *sec,taddr pc)
/* Convert an instruction into a DATA atom including relocations,
   when necessary. */
{
  dblock *db = new_dblock();
  uint64_t insn[2];

  if (db->size = eval_operands(ip,sec,pc,insn,db)) {
    unsigned char *d = db->data = mymalloc(db->size);
    int i;

    for (i=0; i<db->size/4; i++)
      d = setval(1,d,4,insn[i]);
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
  /* no args */
  return 0;
}

/* parse cpu-specific directives; return pointer to end of
   cpu-specific text */
char *parse_cpu_special(char *s)
{
  /* no specials */
  return s;
}
