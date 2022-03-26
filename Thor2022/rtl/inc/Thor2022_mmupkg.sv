// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_mmupkg.sv
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

package Thor2022_mmupkg;

typedef struct packed
{
	logic [19:0] at;
	Thor2022_pkg::Address cta;
	Thor2022_pkg::Address pmt;
	Thor2022_pkg::Address nd;
	Thor2022_pkg::Address start;
} REGION;

typedef struct packed
{
	logic v;
	logic n;
	logic [13:0] rfu;
	logic [15:0] pci;
	logic [7:0] pl;
	logic [23:0] key;
	logic [31:0] access_count;
	logic [15:0] acl;
	logic [15:0] share_count;
} PMTE;	// 128 bits

typedef struct packed
{
	Thor2022_pkg::Address adr;
	logic [15:0] rfu;
	logic [15:0] pci;
	logic [31:0] access_count;
	logic [31:0] key;
	logic [11:0] asid;
	logic sc;
	logic sw;
	logic sr;
	logic sx;
	logic v;
	logic g;
	logic av;
	logic pad1;
	logic [3:0] bc;
	logic d;
	logic u;
	logic s;
	logic a;
	logic c;
	logic w;
	logic r;
	logic x;
	logic [3:0] mb;
	logic [3:0] me;
	logic [15:0] vpn;
	logic n;
	logic [7:0] pl;
	logic [15:0] ppn;
} TLBE;	// 288 bits

typedef struct packed
{
	logic [9:0] asid;
	logic [3:0] bc;
	logic [1:0] pad2;
	logic [15:0] vpn;
	logic v;
	logic g;
	logic [2:0] rwx;
	logic [2:0] wh;
	logic [3:0] mb;
	logic [3:0] me;
	logic [15:0] ppn;
} PTE;	// 64 bits

typedef struct packed
{
	Thor2022_pkg::Address padr;	// physical address of the PDE
	logic [2:0] lvl;
	logic v;
	logic d;
	logic u;
	logic a;
	logic [24:0] pad25;
	logic [5:0] mb;
	logic [5:0] me;
	logic sc;
	logic sw;
	logic sr;
	logic sx;
	logic [7:0] pl;
	logic n;
	logic g;
	logic av;
	logic s;
	logic c;
	logic w;
	logic r;
	logic x;
	logic [15:0] pad16;
	logic [47:0] ppn;
} HIER_PTE;	// 128 bits + address

typedef struct packed
{
	Thor2022_pkg::Address padr;	// physical address of the PDE
	logic [2:0] lvl;
	logic v;
	logic d;
	logic u;
	logic a;
	logic [8:0] pad9;
	logic [111:0] vpn;
} PDE;	// 128 bits + address

typedef struct packed
{
	logic v;
	Thor2022_pkg::Address adr;
	PDE pde;
} PTCE;

`define PtePerPtg 8
`define PtgSize 2048
`define StripsPerPtg	10

integer PtePerPtg = `PtePerPtg;
integer PtgSize = `PtgSize;

typedef struct packed
{
	PTE [`PtePerPtg-1:0] ptes;
} PTG;	// 1280 bits

typedef struct packed
{
	logic v;
	Thor2022_pkg::Address dadr;
	PTG ptg;
} PTGCE;
parameter PTGC_DEP = 8;

parameter MEMORY_INIT = 7'd0;
parameter MEMORY_IDLE = 7'd1;
parameter MEMORY_DISPATCH = 7'd2;
parameter MEMORY3 = 7'd3;
parameter MEMORY4 = 7'd4;
parameter MEMORY5 = 7'd5;
parameter MEMORY_ACKLO = 7'd6;
parameter MEMORY_NACKLO = 7'd7;
parameter MEMORY8 = 7'd8;
parameter MEMORY9 = 7'd9;
parameter MEMORY10 = 7'd10;
parameter MEMORY11 = 7'd11;
parameter MEMORY_ACKHI = 7'd12;
parameter MEMORY13 = 7'd13;
parameter DATA_ALIGN = 7'd14;
parameter MEMORY_KEYCHK1 = 7'd15;
parameter MEMORY_KEYCHK2 = 7'd16;
parameter KEYCHK_ERR = 7'd17;
parameter TLB1 = 7'd21;
parameter TLB2 = 7'd22;
parameter TLB3 = 7'd23;
parameter RGN1 = 7'd25;
parameter RGN2 = 7'd26;
parameter RGN3 = 7'd27;
parameter IFETCH0 = 7'd30;
parameter IFETCH1 = 7'd31;
parameter IFETCH2 = 7'd32;
parameter IFETCH3 = 7'd33;
parameter IFETCH4 = 7'd34;
parameter IFETCH5 = 7'd35;
parameter IFETCH6 = 7'd36;
parameter IFETCH1a = 7'd37;
parameter IFETCH1b = 7'd38;
parameter IFETCH3a = 7'd39;
parameter DFETCH2 = 7'd42;
parameter DFETCH3 = 7'd43;
parameter DFETCH4 = 7'd44;
parameter DFETCH5 = 7'd45;
parameter DFETCH6 = 7'd46;
parameter DFETCH7 = 7'd47;
parameter DFETCH8 = 7'd48;
parameter DFETCH9 = 7'd49;
parameter KYLD = 7'd51;
parameter KYLD2 = 7'd52;
parameter KYLD3 = 7'd53;
parameter KYLD4 = 7'd54;
parameter KYLD5 = 7'd55;
parameter KYLD6 = 7'd56;
parameter KYLD7 = 7'd57;
parameter MEMORY1 = 7'd60;
parameter MFSEL1 = 7'd61;
parameter MEMORY_ACTIVATE_LO = 7'd62;
parameter MEMORY_ACTIVATE_HI = 7'd63;
parameter IPT_FETCH1 = 7'd64;
parameter IPT_FETCH2 = 7'd65;
parameter IPT_FETCH3 = 7'd66;
parameter IPT_FETCH4 = 7'd67;
parameter IPT_FETCH5 = 7'd68;
parameter IPT_RW_PTG2 = 7'd69;
parameter IPT_RW_PTG3 = 7'd70;
parameter IPT_RW_PTG4 = 7'd71;
parameter IPT_RW_PTG5 = 7'd72;
parameter IPT_RW_PTG6 = 7'd73;
parameter IPT_WRITE_PTE = 7'd75;
parameter IPT_IDLE = 7'd76;
parameter PT_FETCH1 = 7'd81;
parameter PT_FETCH2 = 7'd82;
parameter PT_FETCH3 = 7'd83;
parameter PT_FETCH4 = 7'd84;
parameter PT_FETCH5 = 7'd85;
parameter PT_FETCH6 = 7'd86;
parameter PT_RW_PTE1 = 7'd92;
parameter PT_RW_PTE2 = 7'd93;
parameter PT_RW_PTE3 = 7'd94;
parameter PT_RW_PTE4 = 7'd95;
parameter PT_RW_PTE5 = 7'd96;
parameter PT_RW_PTE6 = 7'd97;
parameter PT_RW_PTE7 = 7'd98;
parameter PT_WRITE_PTE = 7'd99;
parameter PMT_FETCH1 = 7'd101;
parameter PMT_FETCH2 = 7'd102;
parameter PMT_FETCH3 = 7'd103;
parameter PMT_FETCH4 = 7'd104;
parameter PMT_FETCH5 = 7'd105;
parameter PT_RW_PDE1 = 7'd108;
parameter PT_RW_PDE2 = 7'd109;
parameter PT_RW_PDE3 = 7'd110;
parameter PT_RW_PDE4 = 7'd111;
parameter PT_RW_PDE5 = 7'd112;
parameter PT_RW_PDE6 = 7'd113;
parameter PT_RW_PDE7 = 7'd114;
parameter PTG1 = 7'd115;
parameter PTG2 = 7'd116;
parameter PTG3 = 7'd117;
parameter IPT_CLOCK1 = 7'd1;
parameter IPT_CLOCK2 = 7'd2;
parameter IPT_CLOCK3 = 7'd3;

endpackage
