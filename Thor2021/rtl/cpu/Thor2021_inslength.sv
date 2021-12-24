// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2021_inslength.sv
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

import Thor2021_pkg::*;

module Thor20221_inslength(ir, o);
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
ADCI:		o = 4'd4;
SBCFI:	o = 4'd4;
MULUI:	o = 4'd4;
CSR:		o = 4'd6;
MULFI:	o = 4'd4;
SEQI:		o = 4'd4;
SNEI:		o = 4'd4;
SLTI:		o = 4'd4;
SLTIL:	o = 4'd6;
SGTIL:	o = 4'd6;
SGTI:		o = 4'd4;
SLTUI:	o = 4'd4;
SLTUIL:	o = 4'd6;
SGTUIL:	o = 4'd6;
SGTUI:	o = 4'd4;
ADD2R:	o = 4'd4;
AND2R:	o = 4'd4;
OR2R:		o = 4'd4;
XOR2R:	o = 4'd4;
JEQZ:		o = 4'd4;
JNEZ:		o = 4'd4;
DJEQZ:	o = 4'd4;
DJNEZ:	o = 4'd4;
8'h2?:	o = 4'd6;		// Branches
8'h3?:	o = 4'd6;		// Decrement branches
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
EXI7:		o = 4'd2;
EXI23:	o = 4'd4;
EXI55:	o = 4'd8;
EXI41:	o = 4'd6;
F1:			o = 4'd4;
F2:			o = 4'd6;
F3:			o = 4'd6;
DF1:		o = 4'd4;
DF2:		o = 4'd6;
DF3:		o = 4'd6;
P1:			o = 4'd4;
P2:			o = 4'd6;
P3:			o = 4'd6;
LDB:		o = 4'd6;
LDBU:		o = 4'd6;
LDW:		o = 4'd6;
LDWU:		o = 4'd6;
LDT:		o = 4'd6;
LDTU:		o = 4'd6;
LDO:		o = 4'd6;
LDOS:		o = 4'd4;
LEA:		o = 4'd6;
STB:		o = 4'd6;
STW:		o = 4'd6;
STT:		o = 4'd6;
STO:		o = 4'd6;
STOS:		o = 4'd4;
CACHE:	o = 4'd6;
SYS:		o = 4'd4;
INT:		o = 4'd4;
MOV:		o = 4'd4;
BTFLD:	o = 4'd6;
LDBX:		o = 4'd6;
LDBUX:	o = 4'd6;
LDWX:		o = 4'd6;
LDWUX:	o = 4'd6;
LDTX:		o = 4'd6;
LDTUX:	o = 4'd6;
LDOX:		o = 4'd6;
LEAX:		o = 4'd6;
STBX:		o = 4'd6;
STWX:		o = 4'd6;
STTX:		o = 4'd6;
STOX:		o = 4'd6;
CACHEX:	o = 4'd6;
8'hD?:	o = 4'd6;
8'hE?:	o = 4'd6;
NOP:		o = 4'd2;
RTS:		o = 4'd2;
RTE:		o = 4'd2;
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
PUSH2R:	o = 4'h4;
PUSH3R:	o = 4'h4;
POP2R:	o = 4'h4;
POP3R:	o = 4'h4;
default:	o = 4'h2;
endcase

endmodule
