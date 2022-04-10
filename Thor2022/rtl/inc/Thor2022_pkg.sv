// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_pkg.sv
// For the crypto functions latency cannot depend on data operated on!
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

`ifndef TRUE
`define TRUE    1'b1
`define FALSE   1'b0
`endif
`ifndef VAL
`define VAL		1'b1
`define INV		1'b0
`endif

package Thor2022_pkg;

`define QSLOTS	2		// number of simulataneously queueable instructions
`define RENTRIES	8	// number of reorder buffer entries
`define OVERLAPPED_PIPELINE	1


// The following adds support for hardware page table walking. If not used
// software must load the TLB on a miss.
//`define SUPPORT_HWWALK	1

//`define SUPPORT_HASHPT	1
//`define SUPPORT_HASHPT2	1
`define SUPPORT_SHPTE	1
`define SUPPORT_HIERPT	1

// The following adds caching of PDEs and PTGs to improve performance at the
// cost of additional logic.
//`define SUPPORT_MMU_CACHE	1

parameter RSTIP	= 64'hFF000007FFFD0000;

parameter QSLOTS	= `QSLOTS;
parameter RENTRIES	= `RENTRIES;
parameter BitsQS	= $clog2(`QSLOTS-1);
parameter BitsRS	= $clog2(`RENTRIES-1) + 1;

parameter VALUE_SIZE = 64;


parameter OM_USER		= 2'd0;
parameter OM_SUPER	= 2'd1;
parameter OM_HYPER	= 2'd2;
parameter OM_MACHINE	= 2'd3;

parameter BRK			= 8'h00;
parameter R1			= 8'h01;
parameter R2			= 8'h02;
parameter R3			= 8'h03;
parameter ADDI		= 8'h04;
parameter SUBFI		= 8'h05;
parameter MULI		= 8'h06;
parameter OSR2		= 8'h07;
parameter ANDI		= 8'h08;
parameter ORI			= 8'h09;
parameter XORI		= 8'h0A;
parameter CMPI		= 8'h0B;
parameter CMP2R		= 8'h0C;
parameter	SUB2R		= 8'h0D;
parameter MULUI		= 8'h0E;
parameter CSR			= 8'h0F;
parameter CSRRD			= 3'd0;
parameter CSRRW			=	3'd1;
parameter CSRRS			= 3'd2;
parameter CSRRC			= 3'd3;
parameter BEQZ		= 8'h10;
parameter JEQZ		= 8'h10;
parameter DBEQZ		= 8'h11;
parameter DJEQZ		= 8'h11;
parameter BNEZ		= 8'h12;
parameter	JNEZ		= 8'h12;
//parameter DBNEZ		= 8'h13;
//parameter DJNEZ		= 8'h13;
parameter OR2R		= 8'h13;
parameter XOR2R		= 8'h14;
parameter MULFI		= 8'h15;
parameter SEQI		= 8'h16;
parameter SNEI		= 8'h17;
parameter SLTI		= 8'h18;
parameter ADD2R		= 8'h19;
parameter AND2R		= 8'h1A;
parameter SGTI		= 8'h1B;
parameter SLTUI		= 8'h1C;
parameter SGE2R		= 8'h1D;
parameter SLTU2R	= 8'h1E;
parameter SGTUI		= 8'h1F;

parameter JMP			= 8'h20;
parameter DJMP		= 8'h21;
parameter JBSI		= 8'h22;
parameter BRA			= 8'h23;
parameter JOR			= 8'h24;
parameter JBS			= 8'h25;
parameter JUN			= 8'h25;
parameter JEQ			= 8'h26;
parameter JNE			= 8'h27;
parameter JLT			= 8'h28;
parameter JGE			= 8'h29;
parameter JLE			= 8'h2A;
parameter JGT			= 8'h2B;
parameter SEQ2R		= 8'h2C;
parameter SNE2R		= 8'h2D;
parameter SGEU2R	= 8'h2F;

parameter DIVI		= 8'h40;
parameter CPUID		= 8'h41;
parameter BLEND		= 8'h44;
parameter CHKI		= 8'h45;
parameter EXI8		= 8'h46;
parameter EXI24		= 8'h48;
parameter EXI40		= 8'h4A;
parameter EXI56		= 8'h4C;
parameter EXIM		= 8'h50;
parameter SLT2R		= 8'h4E;
parameter DIVUI		= 8'h4F;

parameter VM			= 8'h52;
parameter VMFILL	= 8'h53;
parameter BYTNDXI	= 8'h55;
parameter WYDNDXI	= 8'h56;
parameter UTF21NDXI	= 8'h57;
parameter SLLR2		= 8'h58;
parameter SRLR2		= 8'h59;
parameter SRAR2		= 8'h5A;
parameter ROLR2		= 8'h5B;
parameter RORR2		= 8'h5C;
parameter SGEIL		= 8'h5D;
parameter MFLK		= 8'h5E;
parameter MTLK		= 8'h5F;

parameter SGEI		= 8'h60;
parameter F1			= 8'h61;
parameter F2			= 8'h62;
parameter F3			= 8'h63;
parameter DF1			= 8'h65;
parameter DF2			= 8'h66;
parameter DF3			= 8'h67;
parameter SLEI		= 8'h68;
parameter P1			= 8'h69;
parameter P2			= 8'h6A;
parameter P3			= 8'h6B;
parameter SLLI		= 8'h6C;
parameter SRLI		= 8'h6D;
parameter SRAI		= 8'h6E;
//parameter EXI41		= 8'b011011??;

parameter LDB			= 8'h80;
parameter LDBU		= 8'h81;
parameter LDW			= 8'h82;
parameter LDWU		= 8'h83;
parameter LDT			= 8'h84;
parameter LDTU		= 8'h85;
parameter LDO			= 8'h86;
parameter LDOU		= 8'h87;
parameter LDH			= 8'h88;
parameter LDHS		= 8'h89;
//parameter LLA			= 8'h88;
parameter LDHP		= 8'h8A;
parameter LDHR		= 8'h8B;
parameter LDOO		= 8'h8C;
parameter LDHQ		= 8'h8D;
parameter LDCTX		= 8'h8E;

parameter STB			= 8'h90;
parameter STW			= 8'h91;
parameter STT			= 8'h92;
parameter STO			= 8'h93;
parameter STH			= 8'h94;
parameter STHS		= 8'h95;
parameter STHC		= 8'h96;
parameter STHP		= 8'h97;
parameter STOO		= 8'h9C;
parameter BSET		= 8'h98;
parameter STMOV		= 8'h99;
parameter STCMP		= 8'h9A;
parameter STFND		= 8'h9B;
parameter STCTX		= 8'h9D;
parameter CACHE		= 8'h9F;

parameter SYS			= 8'hA5;
parameter INT			= 8'hA6;
parameter MOV			= 8'hA7;
parameter STPTR		= 8'hA8;
parameter STPTRX	= 8'hA9;
parameter BTFLD		= 8'hAA;
parameter BFALIGN		= 7'h00;
parameter BFFFO			= 7'h01;
parameter BFEXTU		= 7'h04;
parameter BFEXT			= 7'h05;
parameter ANDM			= 7'h08;
parameter BFSET			= 7'h09;
parameter BFCHG			= 7'h0A;
parameter BFCLR			= 7'h0B;
parameter CMOVNZ		= 7'h10;
parameter PUSH		= 8'hAC;
parameter PUSH2R	= 8'hAD;
parameter PUSH4R	= 8'hAE;
parameter ENTER		= 8'hAF;

parameter LDBX		= 8'hB0;
parameter LDBUX		= 8'hB1;
parameter LDWX		= 8'hB2;
parameter LDWUX		= 8'hB3;
parameter LDTX		= 8'hB4;
parameter LDTUX		= 8'hB5;
parameter LDOX		= 8'hB6;
parameter LDOUX		= 8'hB7;
parameter LDHX		= 8'hB8;
parameter LDHPX		= 8'hBA;
parameter LDHRX		= 8'hBB;
parameter LEAVE		= 8'hBF;

parameter POP			= 8'hBC;
parameter LDHQX		= 8'hBD;
parameter POP4R		= 8'hBE;

parameter STBX		= 8'hC0;
parameter STWX		= 8'hC1;
parameter STTX		= 8'hC2;
parameter STOX		= 8'hC3;
parameter STHX		= 8'hC4;
parameter STHCX		= 8'hC6;
parameter STHPX		= 8'hC7;
parameter LDSP		= 8'hC8;
parameter STSP		= 8'hC9;
parameter STOOX		= 8'hCC;
parameter LDOOX		= 8'hCD;
parameter CACHEX	= 8'hCF;

parameter LDxX		= 8'hB0;
parameter STxX		= 8'hC0;

parameter CMPIL		= 8'hD0;
parameter SLEIL		= 8'hD1;
parameter MULIL		= 8'hD2;
parameter SLTIL		= 8'hD3;
parameter ADDIL		= 8'hD4;
parameter SUBFIL	= 8'hD5;
parameter SEQIL		= 8'hD6;
parameter SNEIL		= 8'hD7;
parameter ANDIL		= 8'hD8;
parameter ORIL		= 8'hD9;
parameter XORIL		= 8'hDA;
parameter SGTIL		= 8'hDB;
parameter SLTUIL	= 8'hDC;
parameter DIVIL		= 8'hDD;
parameter MULUIL	= 8'hDE;
parameter SGTUIL	= 8'hDF;

parameter ADDIXL	= 8'hE4;
parameter SLEUIL	= 8'hE6;
parameter SGEUIL	= 8'hE7;

parameter NOP			= 8'hF1;
parameter RTS			= 8'hF2;
parameter CARRY		= 8'hF3;
parameter BCD			= 8'hF5;
parameter SYNC		= 8'hF7;
parameter MEMSB		= 8'hF8;
parameter MEMDB		= 8'hF9;
parameter WFI			= 8'hFA;
parameter PFI			= 8'hFB;
parameter MJNEZ	  = 8'hFC;

parameter NOP_INSN	= NOP;

// R1
parameter CNTLZ		= 7'h00;
parameter CNTLO		= 7'h01;
parameter CNTPOP	= 7'h02;
parameter COM			= 7'h03;
parameter NOT			= 7'h04;
parameter NEG			= 7'h05;
parameter ABS			= 7'h06;
parameter NABS		= 7'h07;
parameter SQRT		= 7'h08;
parameter V2BITS	= 7'h18;
parameter BITS2V	= 7'h19;
parameter PTGHASH	= 7'h2F;
parameter SEI			= 7'h40;
parameter DI			= 7'h41;

// R2
parameter NAND		= 7'h00;
parameter NOR			= 7'h01;
parameter XNOR		= 7'h02;
parameter ORC			= 7'h03;
parameter ADD			= 7'h04;
parameter SUB			= 7'h05;
parameter MUL			= 7'h06;
parameter AND			= 7'h08;
parameter OR			= 7'h09;
parameter XOR			= 7'h0A;
parameter ANDC		= 7'h0B;
parameter MULU		= 7'h0E;
parameter MULH		= 7'h0F;
parameter DIV			= 7'h10;
parameter DIVU		= 7'h11;
parameter DIVSU		= 7'h12;
parameter PTRDIF	= 7'h14;
parameter MULF		= 7'h15;
parameter MULSU		= 7'h16;
parameter CHK			= 7'h19;
parameter BYTNDX	= 7'h1A;
parameter WYDNDX	= 7'h1B;
parameter UTF21NDX= 7'h1C;
parameter MULSUH	= 7'h1D;
parameter MULUH		= 7'h1E;
parameter SLT			= 7'h20;
parameter SGE			= 7'h21;
parameter SLTU		= 7'h22;
parameter SGEU		= 7'h23;
parameter SEQ			= 7'h26;
parameter SNE			= 7'h27;
parameter MIN			= 7'h28;
parameter MAX			= 7'h29;
parameter CMP			= 7'h2A;
parameter CMPU		= 7'h2B;
parameter CLMUL		= 7'h2E;
parameter CLMULH	= 7'h2F;
parameter BMM			= 7'h30;
parameter MUX			= 7'h34;
parameter SLL			= 7'h40;
parameter SRL			= 7'h41;
parameter SRA			= 7'h42;
parameter ROL			= 7'h43;
parameter ROR			= 7'h44;
parameter PTENDX	= 7'h45;
parameter SLLH		= 7'h48;
parameter SRLH		= 7'h49;
parameter SRAH		= 7'h4A;
parameter ROLH		= 7'h4B;
parameter RORH		= 7'h4C;

// OSR2
parameter PUSHQ		= 7'h08;
parameter POPQ		= 7'h09;
parameter PEEKQ		= 7'h0A;
parameter STATQ		= 7'h0B;
parameter RESETQ	= 7'h0C;
parameter REX			= 7'h10;
parameter RTI			= 7'h13;
parameter RGNRW		= 7'h1C;
parameter TLBRW		= 7'h1E;
parameter LDPTG		= 7'h24;
parameter STPTG		= 7'h25;
parameter MFSEL		= 7'h28;
parameter MTSEL		= 7'h29;

// VM
parameter VMADD		= 5'h04;
parameter VMSUB		= 5'h05;
parameter VMAND		= 5'h08;
parameter VMOR		= 5'h09;
parameter VMXOR		= 5'h0A;
parameter VMCNTPOP	= 5'h0D;
parameter VMFIRST	= 5'h0E;
parameter VMLAST	= 5'h0F;
parameter MTVM		= 5'h10;
parameter MFVM		= 5'h11;
parameter MTVL		= 5'h12;
parameter MFVL		= 5'h13;
parameter MTLC		= 5'h14;
parameter MFLC		= 5'h15;
parameter VMSLL0	= 5'h1C;
parameter VMSLL1	= 5'h1D;
parameter VMSRL0	= 5'h1E;
parameter VMSRL1	= 5'h1F;

// Cypto
parameter SM4ED		= 7'h56;	// R2
parameter SM4KS		= 7'h57;	// R2
parameter SHA256SIG0	= 7'h30;
parameter SHA256SIG1	= 7'h31;
parameter SHA256SUM0	= 7'h32;
parameter SHA256SUM1	= 7'h33;
parameter SHA512SIG0	= 7'h34;
parameter SHA512SIG1	= 7'h35;
parameter SHA512SUM0	= 7'h36;
parameter SHA512SUM1	= 7'h37;
parameter SM3P0		= 7'h38;
parameter SM3P1		= 7'h39;

// Neural Network Accelerator
parameter NNA_MFACT	= 7'h62;
parameter NNA_MTBC	= 7'h65;
parameter NNA_MTBIAS	= 7'h62;
parameter NNA_MTFB	= 7'h63;
parameter NNA_MTIN	= 7'h61;
parameter NNA_MTMC	= 7'h64;
parameter NNA_MTWT	= 7'h60;
parameter NNA_STAT	= 7'h61;
parameter NNA_TRIG	= 7'h60;

// F1
parameter FMOV	= 6'h00;
parameter I2F		= 6'h02;
parameter F2I		= 6'h03;
parameter FSQRT	= 6'h08;
parameter FRM		= 6'h14;
parameter FSYNC	= 6'h16;
parameter CPYSGN= 6'h18;
parameter SGNINV= 6'h19;
parameter FABS	= 6'h20;
parameter FNABS	= 6'h21;
parameter FNEG	= 6'h22;

// F2
parameter FMIN	= 6'h02;
parameter FMAX	= 6'h03;
parameter FADD	= 6'h04;
parameter FSUB	= 6'h05;
parameter FMUL	= 6'h08;
parameter FDIV	= 6'h09;
parameter FCMP	= 6'h10;
parameter FSEQ	= 6'h11;
parameter FSLT	= 6'h12;
parameter FSLE	= 6'h13;
parameter FSNE	= 6'h14;
parameter FCMPB	= 6'h15;
parameter FSETM = 6'h16;

// F3
parameter FMA		= 4'h00;
parameter FMS		= 4'h01;
parameter FNMA	= 4'h02;
parameter FNMS	= 4'h03;

// DF1
parameter DFMOV		= 6'h00;
parameter I2DF		= 6'h02;
parameter DF2I		= 6'h03;
parameter DFSQRT	= 6'h08;
parameter DFRM		= 6'h14;
parameter DFSYNC	= 6'h16;
parameter DFCPYSGN= 6'h18;
parameter DFSGNINV= 6'h19;
parameter DFABS		= 6'h20;
parameter DFNABS	= 6'h21;
parameter DFNEG		= 6'h22;

// DF2
parameter DFADD		= 6'h04;
parameter DFSUB		= 6'h05;
parameter DFMUL		= 6'h08;
parameter DFDIV		= 6'h09;

// P1
parameter PMOV	= 6'h00;
parameter I2P		= 6'h02;
parameter P2I		= 6'h03;
parameter PSQRT	= 6'h08;
parameter PRM		= 6'h14;
parameter PSYNC	= 6'h16;
parameter PCPYSGN	= 6'h18;
parameter PSGNINV	= 6'h19;
parameter PABS	= 6'h20;
parameter PNABS	= 6'h21;
parameter PNEG	= 6'h22;


parameter MR_LOAD = 4'd0;
parameter MR_STORE = 4'd1;
parameter MR_TLB = 4'd2;
parameter MR_CACHE = 4'd3;
parameter LEA2 = 4'd4;
//parameter RTS2 = 3'd5;
parameter M_JALI	= 4'd5;
parameter M_CALL	= 4'd6;
parameter MR_LOADZ = 4'd7;		// unsigned load
parameter MR_MFSEL = 4'd8;
parameter MR_MTSEL = 4'd9;
parameter MR_MOVLD = 4'd10;
parameter MR_MOVST = 4'd11;
parameter MR_RGN = 4'd12;
parameter MR_PTG = 4'd15;

parameter CSR_CAUSE	= 16'h?006;
parameter CSR_SEMA	= 16'h?00C;
parameter CSR_PTBR	= 16'h1003;
parameter CSR_ARTBR	= 16'h1005;
parameter CSR_FSTAT	= 16'h?014;
parameter CSR_ASID	= 16'h101F;
parameter CSR_KEYS	= 16'b00010000001000??;
parameter CSR_KEYTBL= 16'h1024;
parameter CSR_SCRATCH=16'h?041;
parameter CSR_MCR0	= 16'h3000;
parameter CSR_MHARTID = 16'h3001;
parameter CSR_TICK	= 16'h3002;
parameter CSR_MBADADDR	= 16'h3007;
parameter CSR_MTVEC = 16'b0011000000110???;
parameter CSR_MPLSTACK	= 16'h303F;
parameter CSR_MPMSTACK	= 16'h3040;
parameter CSR_MSTUFF0	= 16'h3042;
parameter CSR_MSTUFF1	= 16'h3043;
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

parameter FLT_NONE	= 8'h00;
parameter FLT_TLBMISS = 8'h04;
parameter FLT_IADR	= 8'h22;
parameter FLT_CHK		= 8'h27;
parameter FLT_DBZ		= 8'h28;
parameter FLT_OFL		= 8'h29;
parameter FLT_KEY		= 8'h31;
parameter FLT_WRV		= 8'h32;
parameter FLT_RDV		= 8'h33;
parameter FLT_SGB		= 8'h34;
parameter FLT_PRIV	= 8'h35;
parameter FLT_WD		= 8'h36;
parameter FLT_UNIMP	= 8'h37;
parameter FLT_CPF		= 8'h39;
parameter FLT_DPF		= 8'h3A;
parameter FLT_LVL		= 8'h3B;
parameter FLT_PMA		= 8'h3D;
parameter FLT_BRK		= 8'h3F;
parameter FLT_PFX		= 8'hC8;
parameter FLT_TMR		= 8'hE2;
parameter FLT_NMI		= 8'hFE;

parameter pL1CacheLines = 64;
parameter pL1LineSize = 512;
parameter pL1ICacheLines = 512;
parameter pL1ICacheLineSize = 640;
localparam pL1Imsb = $clog2(pL1ICacheLines-1)-1+6;

typedef logic [63:0] Value;
typedef logic [31:0] Offset;
typedef logic [32-13:0] BTBTag;
typedef logic [11:0] ASID;
typedef logic [BitsRS:0] SrcId;
typedef logic [BitsRS:0] RNdx;

typedef struct packed
{
	logic [7:0] pl;
	logic ti;
	logic [22:0] ndx;
} Selector;

typedef struct packed
{
	Offset offs;
} Address;

typedef struct packed
{
	logic [7:0] micro_ip;
	logic [31:0] offs;
} CodeAddress;

typedef struct packed
{
	Offset offs;
} VirtualAddress;

typedef struct packed
{
	logic [31:0] offs;
} PhysicalAddress;

typedef struct packed
{
	logic [7:0] micro_ip;
	Offset offs;
} IPAddress;

typedef struct packed
{
	logic [31:0] pad;
	logic [12:0] imm;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} riinst;

typedef struct packed
{
	logic [15:0] pad;
	logic [28:0] imm;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} rilinst;

typedef struct packed
{
	logic [15:0] pad;
	logic [2:0] m;
	logic z;
	logic [24:0] imm;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} rilvinst;

typedef struct packed
{
	logic [31:0] imm;
	logic [6:0] pad;
	logic Tb;
	logic [4:0] Rb;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} bmapinst;

typedef struct packed
{
	logic [31:0] pad;
	logic [6:0] func;
	logic [2:0] m;
	logic z;
	logic [1:0] sz;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} r1inst;

typedef struct packed
{
	logic [23:0] pad;
	logic [6:0] func;
	logic [2:0] m;
	logic z;
	logic [2:0] sz;
	logic p;
	logic Tb;
	logic [4:0] Rb;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} r2inst;

typedef struct packed
{
	logic [15:0] pad;
	logic [6:0] func;
	logic [2:0] m;
	logic z;
	logic [1:0] pad2;
	logic [2:0] sz;
	logic p;
	logic Tc;
	logic [4:0] Rc;
	logic Tb;
	logic [4:0] Rb;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} r3inst;

typedef struct packed
{
	logic [47:0] pad;
	logic [4:0] cnst;
	logic [1:0] lk;
	logic v;
	logic [7:0] opcode;
} rts_inst;
;
typedef struct packed
{
	logic [54:0] pad;
	logic v;
	logic [7:0] opcode;
} anyinst;

typedef struct packed
{
	logic [15:0] pad;
	logic [20:0] Tgthi;
	logic [2:0] Ca;
	logic [4:0] Rb;
	logic [4:0] Ra;
	logic [2:0] cm;
	logic [1:0] lk;
	logic v;
	logic [7:0] opcode;
} jxxinst;

typedef struct packed
{
	logic [15:0] pad;
	logic [15:0] Tgthi;
	logic [2:0] Ca;
	logic [17:0] Tgtlo;
	logic [1:0] lk;
	logic v;
	logic [7:0] opcode;
} jmpinst;

typedef struct packed
{
	logic [31:0] pad;
	logic [4:0] func;
	logic [8:0] pad1;
	logic [2:0] Vmb;
	logic [2:0] Vma;
	logic [2:0] Vmt;
	logic v;
	logic [7:0] opcode;
} vmr2_inst;

typedef struct packed
{
	logic [15:0] pad;
	logic [28:0] disp;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} ld_inst;

typedef struct packed
{
	logic [15:0] pad;
	logic [2:0] m;
	logic z;
	logic c;
	logic [23:0] disp;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} vld_inst;

typedef struct packed
{
	logic [31:0] pad;
	logic [12:0] disp;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} lds_inst;

typedef struct packed
{
	logic [31:0] pad;
	logic [2:0] m;
	logic z;
	logic c;
	logic [1:0] pad2;
	logic Tb;
	logic [4:0] Rb;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} ldx_inst;

typedef struct packed
{
	logic [15:0] pad;
	logic [28:0] disp;
	logic [4:0] Ra;
	logic [4:0] Rs;
	logic v;
	logic [7:0] opcode;
} st_inst;

typedef struct packed
{
	logic [31:0] pad;
	logic [12:0] disp;
	logic [4:0] Ra;
	logic [4:0] Rs;
	logic v;
	logic [7:0] opcode;
} sts_inst;

typedef struct packed
{
	logic [31:0] pad;
	logic [2:0] m;
	logic z;
	logic c;
	logic [1:0] pad2;
	logic Tb;
	logic [4:0] Rb;
	logic [4:0] Ra;
	logic [4:0] Rs;
	logic v;
	logic [7:0] opcode;
} stx_inst;

typedef struct packed
{
	logic [15:0] pad;
	logic [3:0] func;
	logic S;
	logic [6:0] pad5;
	logic [4:0] Me;
	logic Tc;
	logic [4:0] Rc;
	logic Tb;
	logic [4:0] Rb;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} rm_inst;

typedef struct packed
{
	logic [15:0] pad;
	logic [2:0] m;
	logic z;
	logic [2:0] op;
	logic [5:0] padlo;
	logic [15:0] regno;
	logic [4:0] Ra;
	logic [4:0] Rt;
	logic v;
	logic [7:0] opcode;
} csr_inst;

typedef union packed
{
	bmapinst bmap;
	r3inst r3;
	r2inst r2;
	r1inst r1;
	rilinst ril;
	rilvinst rilv;
	rilvinst rixlv;
	riinst ri;
	jxxinst jxx;
	jmpinst jmp;
	rts_inst rts;
	vmr2_inst vmr2;
	ld_inst ld;
	lds_inst lds;
	vld_inst vld;
	ldx_inst ldx;
	st_inst st;
	sts_inst sts;
	stx_inst stx;
	rm_inst rm;
	csr_inst csr;
	anyinst	any;
} Instruction;

typedef struct packed
{
	Instruction ir;
	Address ip;
	logic [3:0] len;
} sInstAlignOut;

typedef struct packed
{
	logic v;
	CodeAddress insadr;
	CodeAddress	tgtadr;
} BTBEntry;

// No unsigned codes!
parameter MR_LDB	= 4'd0;
parameter MR_LDW	= 4'd1;
parameter MR_LDT	= 4'd2;
parameter MR_LDO	= 4'd3;
parameter MR_LDOR	= 4'd4;
parameter MR_LDOB	= 4'd5;
parameter MR_LDOO = 4'd6;
parameter MR_LDH	= 4'd7;
parameter MR_LDHP = 4'd8;
parameter MR_LDPTG = 4'd0;
parameter MR_STPTG = 4'd1;
parameter MR_LDDESC = 4'd12;
parameter MR_STB	= 4'd0;
parameter MR_STW	= 4'd1;
parameter MR_STT	= 4'd2;
parameter MR_STO	= 4'd3;
parameter MR_STOC	= 4'd4;
parameter MR_STOO	= 4'd5;
parameter MR_STH	= 4'd7;
parameter MR_STHP	= 4'd8;
parameter MR_STPTR	= 4'd9;

typedef struct packed
{
	logic [7:0] tid;		// tran id
	logic [5:0] step;		// vector operation step
	logic wr;
	logic [3:0] func;		// function to perform
	logic [3:0] func2;	// more resolution to function
	Address adr;
	logic [255:0] dat;
	logic [3:0] sz;		// indicates size of data
} MemoryRequest;	// 315

// All the fields in this structure are *output* back to the system.
typedef struct packed
{
	logic [7:0] tid;		// tran id
	logic [5:0] step;
	logic wr;
	logic v;
	logic empty;
	logic [15:0] cause;
	Address badAddr;
	logic [511:0] res;
	logic cmt;
	logic ldcs;
	logic mtsel;
} MemoryResponse;	// 612

typedef struct packed
{
	logic p;						// present
	logic sys;					// 1=system segment
	logic stk;					// 1=stack segment
	logic a;						// accessed
	logic c;						// 1=cachable
	logic	r;						// 1=readable
	logic w;						// 1=writable
	logic x;						// 1=executable
	logic [7:0] dpl;		// privilege level
	logic con;					// 1=conforming
	logic [2:0] u;
} SegACR;

typedef struct packed
{
	SegACR	acr;
	logic [43:0] pad_limit;
	logic [63:0] limit;
	logic [63:0] pad_base;
	logic [63:0] base;
} SegDesc;

typedef struct packed
{
	SegACR	acr;
	logic [43:0] pad_limit;
	logic [63:0] limit;
	logic [63:0] pad_base;
	logic [63:0] base;
} MemSegDesc;

typedef struct packed
{
	logic fuf;	// underflow
	logic fof;	// overflow
	logic fdz;	// divide by zero
	logic fnv;	// invalid operation
	logic fnx;	// inexact
	logic lt;
	logic	eq;
	logic gt;
	logic inf;
} sFPFlags;

parameter byt = 3'd0;
parameter wyde = 3'd1;
parameter tetra = 3'd2;
parameter octa = 3'd3;
parameter hexi = 3'd4;
parameter hexipair = 3'd5;
parameter hexiquad = 3'd6;
parameter ptr = 3'd7;

typedef struct packed
{
	logic rfwr;
	logic carfwr;
	logic vmrfwr;
	Value imm;
	logic [4:0] Ra;
	logic [4:0] Rb;
	logic [4:0] Rc;
	logic [4:0] Rt;
	logic [1:0] Tb;
	logic [1:0] Tc;
	logic [2:0] Rvm;
	logic Rz;
	logic Ravec;
	logic Rbvec;
	logic Rcvec;
	logic Rtvec;
	logic [3:0] Cat;
	logic is_vector;			// a vector instruction
	logic is_cbranch;			// is a conditional branch
	logic float;
	logic addi;
	logic ld;
	logic st;
	logic bra;
	logic jmp;
	logic jxx;
	logic jxz;
	logic dj;
	logic mjnez;
	logic [63:0] jmptgt;
	logic [3:0] lk;
	logic rts;
	logic loadr;
	logic loadn;
	logic storer;
	logic storen;
	logic ldoo;
	logic stoo;
	logic ldz;
	logic mem;
	logic load;
	logic store;
	logic [2:0] memsz;
	logic lear;
	logic lean;
	logic tlb;
	logic rgn;
	logic ptg;
	logic stset;
	logic stmov;
	logic stfnd;
	logic stcmp;
	logic multi_cycle;
	logic mul;
	logic muli;
	logic mulu;
	logic mului;
	logic mulsu;
	logic mulsui;
	logic mulall;
	logic mulalli;
	logic div;
	logic divi;
	logic divu;
	logic divui;
	logic divsu;
	logic divsui;
	logic divall;
	logic divalli;
	logic mulf;
	logic mulfi;
	logic csr;
	logic rti;
	logic sei;
	logic rex;
	logic sync;
	logic mtlc;
	logic wrlc;
	logic mfsel;
	logic mtsel;
	logic ril;
	logic mflk;
	logic mtlk;
	logic enter;
	logic push;
	logic flowchg;
	logic [3:0] Ca;
	logic [3:0] Ct;
	logic [2:0] rm;
	logic [2:0] dfrm;
	logic isDF;
	logic isExi;
} DecodeOut;

parameter RS_INVALID = 3'd0;

typedef struct packed
{
	logic [5:0] rid;
	logic v;
	logic fetched;
	logic decompressed;
	logic decoded;
	logic out;						// instruction is out being executed
	logic executed;
	logic stomp;
	logic cmt;						// commit, clears as soon as committed
	logic cmt2;						// sticky commit, clears when entry reassigned
	logic vcmt;						// entire vector is committed.
	IPAddress ip;
	Instruction ir;
	Instruction lsm_mask;
	logic w256;
	logic w512;
	logic [3:0] ilen;
	logic [3:0] istk_depth;
	DecodeOut dec;
	logic is_vec;
	logic [3:0] br_tag;			// Branch tag
	logic [5:0] count;		// LDM / STM count
	logic takb;
	logic predict_taken;
	logic predictable_branch;
	logic [5:0] step;			// vector step
	logic step_v;
	logic [15:0] cause;
	Value ia;
	Value ib;
	Value ic0;
	Value ic1;
	Value ic2;
	Value ic3;
	Value id;
	Value pn;
	IPAddress lk;
	IPAddress ca;
	logic [2:0] cioreg;
	logic [1:0] cio;
	logic [5:0] ia_ele;
	logic [5:0] ib_ele;
	logic [5:0] ic_ele;
	logic [5:0] id_ele;
	logic [5:0] it_ele;
	logic [127:0] imm;
	Value vmask;						// vector mask register value
	logic mask_bit;
	logic zbit;
	logic z;
	logic iav;
	logic ibv;
	logic ic0v;
	logic ic1v;
	logic ic2v;
	logic ic3v;
	logic lkv;
	logic idv;
	logic itv;
	logic vmv;
	SrcId ias;
	SrcId ibs;
	SrcId ic0s;
	SrcId ic1s;
	SrcId ic2s;
	SrcId ic3s;
	SrcId lks;
	SrcId ids;
	logic idib;					// id comes from ia
	SrcId its;
	SrcId vms;
	logic [511:0] res;
	IPAddress cares;
	Value carry_res;
	sFPFlags fp_flags;
	logic [5:0] res_ele;
//	logic [15:0] cause;
	logic [2:0] irq_level;
	logic lockout;
	Address badAddr;
	logic wr_fu;				// write to functional unit
	logic [47:0] sn;
} sReorderEntry;

function Value fnAbs;
input Value jj;
fnAbs = jj[$bits(Value)-1] ? -jj : jj;
endfunction

function is_prefix;
input [7:0] opc;
	is_prefix = opc==EXI8 || opc==EXI24 || opc==EXI40 ||
							opc==EXI56 || opc==EXIM ||
							opc==EXI8+1 || opc==EXI24+1 || opc==EXI40+1 ||
							opc==EXI56+1
							;
endfunction

// Detect if a source is automatically valid
function Source1Valid;
input Instruction isn;
casez(isn.any.opcode)
// BUnit:	
BRK:	Source1Valid = `TRUE;
R1:
	case(isn.r1.func)
	SEI:	Source1Valid = isn.r2.Ra==5'd0;
	endcase
R2:
	case(isn.r2.func)
	default:	Source1Valid = isn.r3.Ra==5'd0;
	endcase
R3:
	case(isn.r3.func)
	default:	Source1Valid = isn.r3.Ra==5'd0;
	endcase
ADDI,SUBFI,MULI,ANDI,ORI,XORI,MULUI,CSR:
	Source1Valid = isn.ri.Ra==5'd0;
OSR2:
	case(isn.r2.func)
	RTI:	Source1Valid = isn.r2.Ra==5'd0;
	REX:	Source1Valid = isn.r2.Ra==5'd0;
	default: Source1Valid = `TRUE;
	endcase
// Branches
JMP,DJMP,BRA:	Source1Valid = `TRUE;
JBS,JBSI,JEQ,JNE,JLT,JGE,JLE,JGT:
	Source1Valid = isn.jxx.Ra==5'd0;
DIVI,CPUID,DIVIL,ADDIL,CHKI,MULIL,SNEIL,ANDIL,ORIL,XORIL,SEQIL,MULUI,DIVUI:
	Source1Valid = isn.ri.Ra==5'd0;
CMPI,BYTNDXI,WYDNDXI,UTF21NDXI:
	Source1Valid = isn.ri.Ra==5'd0;
VM:
	case(isn.vmr2.func)
	MFVM:	Source1Valid = `TRUE;
	MFVL:	Source1Valid = `FALSE;
	MTVM:	Source1Valid = isn[17:12]==5'd0;
	MTVL:	Source1Valid = isn[17:12]==5'd0;
	VMADD,VMAND,VMOR,VMXOR,VMSLL0,VMSLL1,VMSRL0,VMSRL1,VMSUB:
		Source1Valid = `FALSE;
	VMCNTPOP,VMFIRST,VMLAST:
		Source1Valid = `TRUE;
	default:	Source1Valid = `TRUE;
	endcase
VMFILL:	Source1Valid = `TRUE;
CMPIL:	Source1Valid = isn.ri.Ra==5'd0;
F1:
	case(isn.r1.func)
	FSYNC:		Source1Valid = `TRUE;
	default:	Source1Valid = isn.r1.Ra==5'd0;
	endcase
F2:	Source1Valid = isn.r2.Ra==5'd0;
F3:	Source1Valid = isn.r3.Ra==5'd0;
DF1:
	case(isn.r1.func)
	DFSYNC:		Source1Valid = `TRUE;
	default:	Source1Valid = isn.r1.Ra==5'd0;
	endcase
DF2:	Source1Valid = isn.r2.Ra==5'd0;
DF3:	Source1Valid = isn.r3.Ra==5'd0;
P1:
	case(isn.r1.func)
	PSYNC:		Source1Valid = `TRUE;
	default:	Source1Valid = isn.r1.Ra==5'd0;
	endcase
P2:	Source1Valid = isn.r2.Ra==5'd0;
P3:	Source1Valid = isn.r3.Ra==5'd0;
LDSP,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDHS,LDHR,LDOU,LDH,LDSP:
	Source1Valid = isn.ld.Ra==5'd0;
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDHRX,LDOUX,LDHX:
	Source1Valid = isn.ld.Ra==6'd0;
LDHP,LDHPX,LDHQ,LDHQX:
	Source1Valid = isn.ld.Ra==5'd0;
STB,STW,STT,STO,STH,STHP,STHC,STPTR,STHS,STSP:
	Source1Valid = isn.st.Ra==5'd0;
STBX,STWX,STTX,STOX,STHX,STHPX,STHCX,STPTRX:
	Source1Valid = isn.st.Ra==5'd0;
SYS:	Source1Valid = `TRUE;
INT:	Source1Valid = `TRUE;
MOV:	Source1Valid = isn.r1.Ra==5'd0;
BTFLD:	Source1Valid = isn.r1.Ra==5'd0;
NOP:	Source1Valid = `TRUE;
RTS:	Source1Valid = `TRUE;
BCD:	Source1Valid = isn.r1.Ra==5'd0;
SYNC,MEMSB,MEMDB,WFI:	Source1Valid = `TRUE;
EXI8,EXI8+1,EXI24,EXI24+1,EXI40,EXI40+1,EXI56,EXI56+1,EXIM:
	Source1Valid = `TRUE;
LEAVE: Source1Valid = `TRUE;
MFLK: Source1Valid = `TRUE;
MTLK: Source1Valid = `TRUE;
default:
	Source1Valid = `FALSE;
endcase
endfunction

function LkValid;
input Instruction isn;
casez(isn.any.opcode)
MFLK:	LkValid=isn[15:14]==2'd0;
RTS:	LkValid=isn.rts.lk==2'd0;
default:	LkValid = `TRUE;
endcase
endfunction

function Source2Valid;
input Instruction isn;
casez(isn.any.opcode)
// BUnit:	
BRK:	Source2Valid = `TRUE;
R1:
	case(isn.r1.func)
	SEI:	Source2Valid = `TRUE;
	default:	Source2Valid = `TRUE;
	endcase
R2:	Source2Valid = isn.r3.Rb==5'd0;
R3:
	case(isn.r3.func)
	CHK:	Source2Valid = isn.r3.Rb==5'd0;
	MUX:	Source2Valid = isn.r3.Rb==5'd0;
	default:	Source2Valid = `TRUE;
	endcase
ADDI,SUBFI,MULI,ANDI,ORI,XORI,MULUI,CSR:
	Source2Valid = `TRUE;
OSR2:
	case(isn.r2.func)
	RTI:	Source2Valid = `TRUE;
	REX:	Source2Valid = `TRUE;
	default: Source2Valid = `TRUE;
	endcase
// Branches
JMP,DJMP,BRA:	Source2Valid = `TRUE;
JBS,JEQ,JNE,JLT,JGE,JLE,JGT:
	Source2Valid = isn.jxx.Rb==5'd0;
JBSI:	Source2Valid = `TRUE;
DIVI,CPUID,DIVIL,ADDIL,CHKI,MULIL,SNEIL,ANDIL,ORIL,XORIL,SEQIL,MULUI,DIVUI:
	Source2Valid = `TRUE;
CMPI,BYTNDXI,WYDNDXI,UTF21NDXI:
	Source2Valid = `TRUE;
VM:
	case(isn.vmr2.func)
	MFVM:	Source2Valid = `FALSE;
	MFVL:	Source2Valid = `TRUE;
	MTVM:	Source2Valid = `TRUE;
	MTVL:	Source2Valid = `TRUE;
	VMADD,VMAND,VMOR,VMXOR,VMSLL0,VMSLL1,VMSRL0,VMSRL1,VMSUB:
		Source2Valid = `FALSE;
	VMCNTPOP,VMFIRST,VMLAST:
		Source2Valid = `FALSE;
	default:	Source2Valid = `TRUE;
	endcase
VMFILL:	Source2Valid = `TRUE;
CMPIL:	Source2Valid = `TRUE;
//`FUnit:
F1:
	case(isn.r1.func)
	FSYNC:		Source2Valid = `TRUE;
	default:	Source2Valid = `TRUE;
	endcase
F2:	Source2Valid = isn.r2.Rb==6'd0;
F3:	Source2Valid = isn.r3.Rb==6'd0;
DF1:
	case(isn.r1.func)
	DFSYNC:		Source2Valid = `TRUE;
	default:	Source2Valid = `TRUE;
	endcase
DF2:	Source2Valid = isn.r2.Rb==6'd0;
DF3:	Source2Valid = isn.r3.Rb==6'd0;
P1:
	case(isn.r1.func)
	PSYNC:		Source2Valid = `TRUE;
	default:	Source2Valid = `TRUE;
	endcase
P2:	Source2Valid = isn.r2.Rb==6'd0;
P3:	Source2Valid = isn.r3.Rb==6'd0;
LDSP,
LDB,LDBU,LDW,LDWU,LDT,LDTU,LDO,LDHS,LDHR,LDOU,LDH,LDSP:
	Source2Valid = `TRUE;
LDBX,LDBUX,LDWX,LDWUX,LDTX,LDTUX,LDOX,LDHRX,LDOUX,LDHX:
	Source2Valid = isn.ldx.Rb==6'd0;
LDHP,LDHPX,LDHQ,LDHQX:	Source2Valid = isn.ldx.Rb==6'd0;
STB,STW,STT,STO,STH,STHP,STHC,STPTR,STHS,STSP:
	Source2Valid = `TRUE;
STBX,STWX,STTX,STOX,STHX,STHPX,STHCX,STPTRX:
	Source2Valid = isn.stx.Rb==6'd0;
INT:	Source2Valid = `TRUE;
MOV:	Source2Valid = `TRUE;
BTFLD:	
	case(isn.rm.func)
	default:	Source2Valid = isn.r2.Rb==6'd0;
	endcase
NOP:	Source2Valid = `TRUE;
RTS:	Source2Valid = `TRUE;
BCD:	Source2Valid = isn.r2.Rb==6'd0;
SYNC,MEMSB,MEMDB,WFI:	Source2Valid = `TRUE;
EXI8,EXI8+1,EXI24,EXI24+1,EXI40,EXI40+1,EXI56,EXI56+1,EXIM:
	Source2Valid = `TRUE;
RTS:	Source2Valid = `TRUE;
LEAVE: Source2Valid = `TRUE;
MFLK: Source2Valid = `TRUE;
MTLK: Source2Valid = `TRUE;
default:
	Source2Valid = `FALSE;
endcase
endfunction

function Source3Valid;
input Instruction isn;
casez(isn.any.opcode)
R1:	Source3Valid = 1'b1;
R3:
	case(isn.r3.func)
	CHK:	Source3Valid = isn.r3.Rc==5'd0;
	MUX:	Source3Valid = isn.r3.Rc==5'd0;
	default:	Source3Valid = `TRUE;
	endcase
// Branches
F3:	Source3Valid = isn.r3.Rc==5'd0;
DF3:	Source3Valid = isn.r3.Rc==5'd0;
P3:	Source3Valid = isn.r3.Rc==5'd0;
BTFLD:	Source3Valid = isn.r3.Rc==5'd0;
STB,STW,STT,STO,STH,STHP,STHC,STPTR,STHS,STSP:
	Source3Valid = isn.st.Rs=='d0;
STBX,STWX,STTX,STOX,STHX,STHPX,STHCX,STPTRX:
	Source3Valid = isn.stx.Rs=='d0;
LEAVE: Source3Valid = `TRUE;
MTLK:	 Source3Valid = isn[13:9]=='d0;
default:
	Source3Valid = `TRUE;
endcase
endfunction

function Source31Valid;
input Instruction isn;
case(isn.any.opcode)
STHP,STHPX:	Source31Valid = isn.st.Rs=='d0;
default:
	Source31Valid = `TRUE;
endcase
endfunction

function Source32Valid;
input Instruction isn;
Source32Valid = `TRUE;
endfunction

function Source33Valid;
input Instruction isn;
Source33Valid = `TRUE;
endfunction

endpackage
