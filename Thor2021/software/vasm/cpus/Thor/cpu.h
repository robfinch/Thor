/* (c) in 2021 by Robert Finch */

#define LITTLEENDIAN 1
#define BIGENDIAN 0
#define VASM_CPU_THOR 1

/* maximum number of operands in one mnemonic */
#define MAX_OPERANDS 5

/* maximum number of mnemonic-qualifiers per mnemonic */
#define MAX_QUALIFIERS 1

/* maximum number of additional command-line-flags for this cpu */

/* data type to represent a target-address */
typedef int64_t taddr;
typedef uint64_t utaddr;

/* minimum instruction alignment */
#define INST_ALIGN 2

/* default alignment for n-bit data */
#define DATA_ALIGN(n) ((n)<=8?1:(n)<=16?2:(n)<=32?4:8)

/* operand class for n-bit data definitions */
#define DATA_OPERAND(n) thor_data_operand(n)

/* #define NEXT (-1)   use operand_type+1 for next operand */

/* type to store each operand */
typedef struct {
  uint32_t type;
  unsigned char attr;   /* reloc attribute != REL_NONE when present */
  unsigned char format;
  char basereg;
  char ndxreg;
  char scale;
  char selector;
  expr *value;
} operand;

/* operand-types */
#define OP_REG						0x00000001L
#define OP_IMM11					0x00000002L
#define OP_IMM23					0x00000004L
#define OP_IMM30					0x00000008L
#define OP_IMM46					0x00000010L
#define OP_IMM64					0x00000020L
#define OP_IMM78					0x00000040L
#define OP_REGT						0x00000100L
#define OP_VMREG					0x00000200L
#define OP_UIMM6					0x00000400L
#define OP_REGIND8				0x00000800L
#define OP_REGIND24				0x00001000L
#define OP_REGIND30				0x00002000L
#define OP_REGIND46				0x00004000L
#define OP_REGIND64				0x00008000L
#define OP_REGIND78				0x00010000L
#define OP_SCNDX					0x00020000L
#define OP_LK							0x00040000L
#define OP_CAREG					0x00080000L
#define OP_BRTGT20				0x00100000L
#define OP_BRTGT12				0x00200000L
#define OP_BRTGT34				0x00400000L
#define OP_DATA						0x00800000L
#define OP_SEL						0x01000000L
#define OP_VREG						0x02000000L
#define OP_IMM7						0x04000000L
#define OP_CAREGIND				0x08000000L
#define OP_BRTGT					0x10000000L
#define OP_REG7						0x20000000L

#define OP_NEXT			-1

/* supersets of other operands */
#define OP_IMM			(OP_IMM7|OP_IMM11|OP_IMM23|OP_IMM30|OP_IMM46|OP_IMM64|OP_IMM78)
#define OP_REGIND		(OP_REGIND8|OP_REGIND24|OP_REGIND30|OP_REGIND46|OP_REGIND64|OP_REGIND78)
#define OP_MEM      (OP_REGIND|OP_SCNDX)
#define OP_ALL      0x3fffffff

#define OP_ISMEM(x) ((((x) & OP_MEM)!=0)

#define CPU_SMALL 1
#define CPU_LARGE 2
#define CPU_ALL  (-1)

typedef struct {
	unsigned int format;
  unsigned int available;
  uint64_t prefix;
  uint64_t opcode;
  size_t len;
  uint64_t short_opcode;
  size_t short_len;
} mnemonic_extension;

#define EXI7	0x46
#define EXI23	0x47
#define EXI41	0x7C
#define EXI55	0x49
#define EXIM	0x4A

// Instruction Formats
#define	R3		1
#define B			2
#define B2		3
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
#define BITS32	26
#define REX		27
#define RTE		28
#define R1		29
#define DIRECT	30
#define CSR		31
#define B3		32
#define BL3		33
#define J3		34
#define JL3		35

#define RT(x)		(((x) & 0x3fLL) << 9LL)
#define RA(x)		(((x) & 0x3fLL) << 15LL)
#define RB(x)		(((x) & 0x7fLL) << 21LL)
#define TB(x)		(((x) & 3LL) << 27LL)
#define RC(x)		(((x) & 0x7fLL) << 29LL)
#define TC(x)		(((x) & 3LL) << 35LL)
#define SC(x)		(((x) & 7LL) << 29LL)
#define CA(x)		(((x) & 7LL) << 29LL)

/* special data operand types: */
#define OP_D8  0x40001001
#define OP_D16 0x40001002
#define OP_D32 0x40001003
#define OP_D64 0x40001004
#define OP_F32 0x40001005
#define OP_F64 0x40001006

#define OP_DATA(t) (t >= OP_D8)
#define OP_FLOAT(t) (t >= OP_F32)
