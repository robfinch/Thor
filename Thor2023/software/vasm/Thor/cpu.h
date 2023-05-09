/* (c) in 2021-2023 by Robert Finch */
#define FLOAT_PARSER 1
#include "hugeint.h"

#define LITTLEENDIAN 1
#define BIGENDIAN 0
#define VASM_CPU_THOR 1
#define HAVE_INSTRUCTION_EXTENSION	1

/* maximum number of operands in one mnemonic */
#define MAX_OPERANDS 5

/* maximum number of mnemonic-qualifiers per mnemonic */
#define MAX_QUALIFIERS 1

/* maximum number of additional command-line-flags for this cpu */

/* data type to represent a target-address */
typedef int64_t taddr;
typedef uint64_t utaddr;

/* minimum instruction alignment */
#define INST_ALIGN 1

/* default alignment for n-bit data */
#define DATA_ALIGN(n) ((n)<=8?1:(n)<=16?2:(n)<=32?4:8)

/* operand class for n-bit data definitions */
#define DATA_OPERAND(n) thor_data_operand(n)

/* #define NEXT (-1)   use operand_type+1 for next operand */

/* type to store each operand */
typedef struct {
	unsigned char number;
  uint32_t type;
  unsigned char attr;   /* reloc attribute != REL_NONE when present */
  unsigned char format;
  char basereg;
  char ndxreg;
  char scale;
  expr *value;
} operand;

/* operand-types */
#define OP_REG						0x00000001L
#define OP_IMM13					0x00000002L
#define OP_IMM23					0x00000004L
#define OP_IMM30					0x00000008L
#define OP_IMM46					0x00000010L
#define OP_IMM64					0x00000020L
#define OP_VMSTR					0x00000040L
#define OP_PREDSTR				0x00000080L
#define OP_REG6						0x00000100L
#define OP_VMREG					0x00000200L
#define OP_UIMM6					0x00000400L
#define OP_REGIND					0x00000800L
#define OP_BRTGT					0x00001000L
#define OP_REG7						0x00001000L
#define OP_SCNDX					0x00020000L
#define OP_LK							0x00040000L
#define OP_CAREG					0x00080000L
#define OP_IND_SCNDX			0x00100000L
#define OP_BRTGT28				0x00200000L
#define OP_BRTGT34				0x00400000L
#define OP_DATA						0x00800000L
#define OP_SEL						0x01000000L
#define OP_VREG						0x02000000L
#define OP_IMM7						0x04000000L
#define OP_CAREGIND				0x08000000L

#define OP_NEXT			0x20000000L
#define OP_NEXTREG	0x10000000L

/* supersets of other operands */
#define OP_IMM			(OP_IMM7|OP_IMM13|OP_IMM23|OP_IMM30|OP_IMM46|OP_IMM64)
#define OP_MEM      (OP_REGIND|OP_SCNDX)
#define OP_ALL      0x0fffffffL

#define OP_ISMEM(x) ((((x) & OP_MEM)!=0)

#define CPU_SMALL 1
#define CPU_LARGE 2
#define CPU_ALL  (-1)

#define EXT_BYTE	0
#define EXT_WYDE	1
#define EXT_TETRA	2
#define EXT_OCTA	3
#define EXT_HEXI	4
#define EXT_SINGLE	1
#define EXT_DOUBLE	2
#define EXT_QUAD		3

#define SZ_BYTE	1
#define SZ_WYDE	2
#define SZ_TETRA	4
#define SZ_OCTA	8
#define SZ_HEXI	16
#define SZ_SINGLE	2
#define SZ_DOUBLE 4
#define SZ_QUAD		8
#define SZ_UNSIZED	128

#define SZ_INTALL	(SZ_BYTE|SZ_WYDE|SZ_TETRA|SZ_OCTA|SZ_HEXI)
#define SZ_FLTALL	(SZ_SINGLE|SZ_DOUBLE|SZ_QUAD)

typedef struct {
	unsigned int format;
  unsigned int available;
  uint64_t prefix;
  uint64_t opcode;
  size_t len;
  uint8_t size;
  uint8_t defsize;
  unsigned int flags;
  uint64_t short_opcode;
  size_t short_len;
} mnemonic_extension;

typedef struct {
	int const_expr;		// in pass one
	int	size;
	int postfix_count;
} instruction_ext;

#define FLG_NEGIMM	1
#define FLG_FP			2
#define FLG_MASK		4

#define EXI8	0x46
#define EXI24	0x48
#define EXI40	0x4A
#define EXI56	0x4C
#define EXIM	0x50

// Instruction Formats
#define	R3		1
#define B			2
#define B2		3
#define BZ		4
#define J2		5
#define LS		6
#define MV		7
#define R2		8
#define BL		9
#define JL2		10
#define REGIND	11
#define SCNDX		12
#define J			13
#define JL		14
#define BL2		15
#define RI		16
#define RIL		17
#define RTS		18
#define R3RR	19
#define R3IR	20
#define R3RI	21
#define R3II	22
#define VR3		23
#define INT		24
#define BITS16	25
#define BITS40	26
#define REX		27
#define RTE		28
#define R1		29
#define DIRECT	30
#define CSR		31
#define B3		32
#define BL3		33
#define J3		34
#define JL3		35
#define RII		36
#define RTDR	37
#define RTDI	38
#define ENTER	39
#define LEAVE	40
#define EXI56F	41
#define R4 42
#define SHIFTI	43
#define BFR3RR	44
#define BFR3IR	45
#define BFR3RI	46
#define BFR3II	47
#define RI6			48
#define RI64		49
#define R3R			50
#define RI48		51
#define R2M			52
#define RIM			53
#define PRED		54
#define VMASK		55
#define CSRI		56
#define RIV			57
#define PFX			58
#define RIMV		59
#define RIS			60
#define JSCNDX	61
#define REP			62

#define OPC(x)	(((x) & 0x1fLL))
#define COND(x)	(((x) & 0xfLL) << 5LL)
#define CND3(x)	(((x) & 0x7LL) << 9LL)
#define RM(x)		(((x) & 0x3fLL) << 9LL)
#define RN(x)		(((x) & 0x3fLL) << 15LL)
#define SZ(x)		(((x) & 7LL) << 5LL)
#define V(x)		(((x) & 1LL) << 8LL)
#define FUNC2A(x)	(((x) & 0x3LL) << 32LL)
#define FUNC(x)	(((x) & 0x3fLL) << 34LL)
#define FUNC2(x)	(((x) & 0x3LL) << 38LL)
#define FUNC3(x)	(((x) & 0x7LL) << 37LL)
#define FUNC5(x)	(((x) & 0x1fLL) << 35LL)
#define FLT1(x)	(((x) & 0x3fLL) << 23LL)
#define RT(x)		(((x) & 0x3fLL) << 9LL)
#define ST(x)		(((x) & 1LL) << 15LL)
#define RA(x)		(((x) & 0x3fLL) << 16LL)
#define SA(x)		(((x) & 1LL) << 22LL)
#define RB(x)		(((x) & 0x3fLL) << 23LL)
#define SB(x)		(((x) & 1LL) << 29LL)
#define VB(x)		(((x) & 1LL) << 30LL)
#define S(x)		(((x) & 1LL) << 31LL)
#define RC(x)		(((x) & 0x3fLL) << 32LL)
#define VC(x)		(((x) & 1LL) << 39LL)
#define RCB(x)		(((x) & 0x1fLL) << 24LL)
#define CA(x)		(((x) & 7LL) << 29LL)
#define CAB(x)		(((x) & 7LL) << 24LL)
#define BFOFFS(x)	(((x) & 0x7fLL) << 23LL)
#define BFWID(x)	(((x) & 0x7fLL) << 30LL)

#define RT6(x)		(((x) & 0x3fLL) << 9LL)
#define RA6(x)		(((x) & 0x3fLL) << 15LL)
#define RB6(x)		(((x) & 0x3fLL) << 21LL)
#define TB6(x)		(((x) & 1LL) << 27LL)
#define RC6(x)		(((x) & 0x3fLL) << 28LL)
#define TC6(x)		(((x) & 1LL) << 34LL)

#define RK(x)			(((x) & 0x3fLL) << 40LL)
#define SK(x)			(((x) & 1LL) << 46LL)

/* special data operand types: */
#define OP_D8  0x40001001
#define OP_D16 0x40001002
#define OP_D32 0x40001003
#define OP_D64 0x40001004
#define OP_D128 0x40001005
#define OP_F32 0x40001006
#define OP_F64 0x40001007
#define OP_F128 0x40001008

#define OP_DATAM(t) (t >= OP_D8)
#define OP_FLOAT(t) (t >= OP_F32)
