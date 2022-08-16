// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_inslength.sv
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

import Thor2022_pkg::*;

module Thor2022_inslength(ir, o);
input Instruction ir;
output reg [3:0] o;

always_comb
casez(ir.any.opcode)
BRK:		o = 4'd2;
R1:			o = 4'd4;
R2:			o = 4'd6;
R3:			o = 4'd6;
ADDI:		o = 4'd4;
SUBFI:	o = 4'd4;
MULI:		o = 4'd4;
OSR2:		o = 4'd6;
ANDI:		o = 4'd4;
ORI:		o = 4'd4;
XORI:		o = 4'd4;
MULUI:	o = 4'd4;
CSR:		o = 4'd6;
MULFI:	o = 4'd4;
SEQI:		o = 4'd4;
SNEI:		o = 4'd4;
SLTI:		o = 4'd4;
SLTIL:	o = 4'd6;
SLEI:		o = 4'd4;
SGEI:		o = 4'd4;
SGTIL:	o = 4'd6;
SGTI:		o = 4'd4;
SLTUI:	o = 4'd4;
SLTUIL:	o = 4'd6;
SGTUIL:	o = 4'd6;
SGTUI:	o = 4'd4;
SLEUIL:	o = 4'd6;
SGEUIL:	o = 4'd6;
ADD2R:	o = 4'd4;
AND2R:	o = 4'd4;
OR2R:		o = 4'd4;
XOR2R:	o = 4'd4;
BRA:		o = 4'd4;
JEQZ:		o = 4'd4;
JNEZ:		o = 4'd4;
JMP:	 	o = 4'd6;
DJMP:		o = 4'd6;
JBS:		o = 4'd6;
JBSI:		o = 4'd6;
JEQ:		o = 4'd6;
JNE:		o = 4'd6;
JLT:		o = 4'd6;
JGE:		o = 4'd6;
JLE:		o = 4'd6;
JGT:		o = 4'd6;
DIVI:		o = 4'd4;
CPUID:	o = 4'd4;
DIVIL:	o = 4'd6;
MUX:		o = 4'd6;
ADDIL:	o = 4'd6;
CHKI:		o = 4'd6;
MULIL:	o = 4'd6;
SNEIL:	o = 4'd6;
ANDIL:	o = 4'd6;
ORIL:		o = 4'd6;
XORIL:	o = 4'd6;
SEQIL:	o = 4'd6;
//BMAP:		o = 4'd6;
MULUIL:	o = 4'd6;
DIVUI:	o = 4'd4;
CMPI:		o = 4'd4;
VM:			o = 4'd4;
VMFILL:	o = 4'd4;
BYTNDX:	o = 4'd4;
WYDNDX:	o = 4'd6;
UTF21NDX:	o = 4'd6;
EXI8:		o = 4'd2;
EXI8+1:	o = 4'd2;
EXI24:	o = 4'd4;
EXI24+1:	o = 4'd4;
EXI40:	o = 4'd6;
EXI40+1:	o = 4'd6;
EXI56:	o = 4'd8;
EXI56+1:	o = 4'd8;
EXIM:		o = 4'd8;
F1:			o = 4'd4;
F2:			o = 4'd6;
F3:			o = 4'd6;
DF1:		o = 4'd4;
DF2:		o = 4'd6;
DF3:		o = 4'd6;
P1:			o = 4'd4;
P2:			o = 4'd6;
P3:			o = 4'd6;
LDBS:		o = 4'd4;
LDBUS:	o = 4'd4;
LDWS:		o = 4'd4;
LDWUS:	o = 4'd4;
LDTS:		o = 4'd4;
LDTUS:	o = 4'd4;
LDOS:		o = 4'd4;
LDOUS:	o = 4'd4;
LDB:		o = 4'd6;
LDBU:		o = 4'd6;
LDW:		o = 4'd6;
LDWU:		o = 4'd6;
LDT:		o = 4'd6;
LDTU:		o = 4'd6;
LDO:		o = 4'd6;
LDOU:		o = 4'd6;
LDV:		o = 4'd6;
LDHS:		o = 4'd4;
LDHP:		o = 4'd6;
STBS:		o = 4'd4;
STWS:		o = 4'd4;
STTS:		o = 4'd4;
STOS:		o = 4'd4;
STB:		o = 4'd6;
STW:		o = 4'd6;
STT:		o = 4'd6;
STO:		o = 4'd6;
STV:		o = 4'd6;
STHS:		o = 4'd4;
STHP:		o = 4'd6;
CACHE:	o = 4'd6;
SYS:		o = 4'd4;
INT:		o = 4'd4;
MOV:		o = 4'd4;
BTFLD:	o = 4'd6;
LDBX:		o = 4'd4;
LDBUX:	o = 4'd4;
LDWX:		o = 4'd4;
LDWUX:	o = 4'd4;
LDTX:		o = 4'd4;
LDTUX:	o = 4'd4;
LDOX:		o = 4'd4;
LDOUX:	o = 4'd4;
LDVX:		o = 4'd4;
LDHPX:	o = 4'd4;
LDSP:		o = 4'd2;
STBX:		o = 4'd4;
STWX:		o = 4'd4;
STTX:		o = 4'd4;
STOX:		o = 4'd4;
STVX:		o = 4'd4;
STHPX:	o = 4'd4;
STSP:		o = 4'd2;
CACHEX:	o = 4'd4;
8'hD?:	o = 4'd6;
NOP:		o = 4'd2;
RTS:		o = 4'd2;
BCD:		o = 4'h6;
SYNC:		o = 4'h2;
MEMSB:	o = 4'h2;
MEMDB:	o = 4'h2;
WFI:		o = 4'h2;
SEI:		o = 4'h2;
MFLK:		o = 4'h2;
MTLK:		o = 4'h2;
ENTER:	o = 4'h4;
LEAVE:	o = 4'h4;
PUSH:		o = 4'h2;
POP:		o = 4'h2;
PUSH4R:	o = 4'h4;
POP4R:	o = 4'h4;
LDCTX:	o = 4'h2;
STCTX:	o = 4'h2;
CMP2R:	o = 4'd4;
SLT2R:	o = 4'h4;
SLTU2R:	o = 4'h4;
SEQ2R:	o = 4'h4;
SNE2R:	o = 4'h4;
SGE2R:	o = 4'h4;
SGEU2R:	o = 4'h4;
SLLR2:	o = 4'h4;
SRLR2:	o = 4'h4;
SRAR2:	o = 4'h4;
ROLR2:	o = 4'h4;
RORR2:	o = 4'h4;
SLLI:		o = 4'h4;
SRLI:		o = 4'h4;
SRAI:		o = 4'h4;
//ADDIXL:	o = 4'd12;
default:	o = 4'h2;
endcase

endmodule
