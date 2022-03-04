// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2021_cache.sv
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

import Thor2021_pkg::*;

// -----------------------------------------------------------------------------
// Small, 64 line cache memory (4kiB) made from distributed RAM. Access is
// within a single clock cycle.
// -----------------------------------------------------------------------------

module Thor2021_L1_icache_mem(clk, wr, wlineno, i, rlineno, o, ov, invall, invline);
input clk;
input wr;
input [5:0] wlineno;
input [639:0] i;
input [5:0] rlineno;
output [639:0] o;
output ov;
input invall;
input invline;

reg [639:0] mem [0:63];
reg [63:0] valid;

always  @(posedge clk)
  if (wr) mem[wlineno] <= i;
always  @(posedge clk)
  if (invall) valid <= 64'd0;
  else if (invline) valid[wlineno] <= 1'b0;
  else if (wr) valid[wlineno] <= 1'b1;

assign o = mem[rlineno];
assign ov = valid[rlineno];

endmodule

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

module Thor2021_L1_icache_tag(wclk, wr, wadr, rclk, rce, radr, hit, invall, invline);
input wclk;
input wr;
input Address wadr;
input rclk;
input rce;
input Address radr;
output hit;
input invall;
input invline;

reg [63:0] tagvalid;
Address tagmem [0:63];

always @(posedge wclk)
  if (wr) tagmem[wadr[11:6]] <= wadr;
always @(posedge wclk)
  if (invall)  tagvalid <= 64'd0;
  else if (invline) tagvalid[wadr[11:6]] <= 1'b0;
  else if (wr) tagvalid[wadr[11:6]] <= 1'b1;

assign hit = {tagmem[radr[11:6]].sel,tagmem[radr[11:6]].offs[$bits(Offset)-1:12]} ==
						 {radr.sel,radr.offs[$bits(Offset)-1:12]} && tagvalid[radr[11:6]];

endmodule

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

module Thor2021_L1_icache(rst, clk, wr, adr, i, o, hit, invall, invline);
parameter IWAYS = 4;
input rst;
input clk;
input wr;
input Address adr;
input [639:0] i;
output reg [127:0] o;
output hit;
input invall;
input invline;

wire [639:0] ic [0:IWAYS-1];
wire [IWAYS-1:0] lv;            // line valid
wire [5:0] lineno;
wire taghit;
reg wr1;
wire [639:0] i1;
genvar g;

// Must update the cache memory on the cycle after a write to the tag memmory.
// Otherwise lineno won't be valid. Tag memory takes two clock cycles to update.
always @(posedge clk)
  wr1 <= wr;
always @(posedge clk)
	i1 <= i;

generate begin : gWay
	for (g = 0; g < IWAYS; g = g + 1)
begin
Thor2021_L1_icache_mem u1
(
  .clk(clk),
  .wr(wr1 && way==g),
  .wlineno(lineno),
  .i(i1),
  .rlineno(lineno),
  .o(ic[g]),
  .ov(lv[g]),
  .invall(invall),
  .invline(invline)
);
Thor2021_L1_icache_tag ut1
(
	.wclk(clk),
	.wr(wr1 && way==g),
	.wadr(),
	.rclk(clk),
	.rce(1'b1),
	.radr(),
	.hit(nhit[g]),
	.invall(invall),
	.invline(invline)
);
end
end
endgenerate

assign hit = |nhit;

//always @(radr or ic0 or ic1)
always @(adr or ic)
case(adr[4:0])
5'h00:  o <= ic[39:0];
5'h05:  o <= ic[79:40];
5'h0A:  o <= ic[119:80];
5'h10:  o <= ic[159:120];
5'h15:  o <= ic[199:160];
5'h1A:  o <= ic[239:200];
default:    o <= `IALIGN_FAULT_INSN;
endcase

endmodule

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

module DSD9_L2_icache_mem(clk, wr, lineno, oe, i, o, ov, invall, invline);
input clk;
input wr;
input [8:0] lineno;
input oe;               // odd / even half of line
input [127:0] i;
output [239:0] o;
output reg ov;
input invall;
input invline;

reg [239:0] mem [0:511];
reg [511:0] valid;
reg [8:0] rrcl;

//  instruction parcels per cache line
wire [8:0] cache_line;

wire wr0 = wr & ~oe;
wire wr1 = wr & oe;

always @(posedge clk)
    if (invall) valid <= 512'd0;
    else if (invline) valid[lineno] <= 1'b0;
    else if (wr) valid[lineno] <= 1'b1;

always @(posedge clk)
begin
    if (wr0) mem[lineno][119:0] <= i[119:0];
    if (wr1) mem[lineno][239:120] <= i[119:0];
end

always @(posedge clk)
    rrcl <= lineno;        
    
always @(posedge clk)
    ov <= valid[lineno];

assign o = mem[rrcl];

endmodule

// -----------------------------------------------------------------------------
// Because the line to update is driven by the output of the cam tag memory,
// the tag write should occur only during the first half of the line load.
// Otherwise the line number would change in the middle of the line. The
// first half of the line load is signified by an even hexibyte address (
// address bit 4).
// -----------------------------------------------------------------------------

module DSD9_L2_icache(rst, clk, wr, adr, i, o, hit, invall, invline);
parameter CAMTAGS = 1'b0;   // 32 way
parameter FOURWAY = 1'b1;
input rst;
input clk;
input wr;
input [37:0] adr;
input [127:0] i;
output [239:0] o;
output hit;
input invall;
input invline;

wire lv;            // line valid
wire [8:0] lineno;
wire taghit;
reg wr1,wr2;
reg oe1;
reg [127:0] i1;

// Must update the cache memory on the cycle after a write to the tag memmory.
// Otherwise lineno won't be valid. camTag memory takes two clock cycles to update.
always @(posedge clk)
    wr1 <= wr;
always @(posedge clk)
    wr2 <= wr1;
always @(posedge clk)
    oe1 <= adr[4];
always @(posedge clk)
    i1 <= i;

DSD9_L2_icache_mem u1
(
    .clk(clk),
    .wr(CAMTAGS ? wr2 : wr1),
    .lineno(lineno),
    .oe(oe1),
    .i(i1),
    .o(o),
    .ov(lv),
    .invall(invall),
    .invline(invline)
);

generate
begin : tags
if (FOURWAY)
DSD9_L2_icache_cmptag4way u2
(
    .rst(rst),
    .clk(clk),
    .wr(wr & ~adr[4]),
    .adr(adr),
    .lineno(lineno),
    .hit(taghit)
);
else if (CAMTAGS)
DSD9_L2_icache_camtag u2
(
    .rst(rst),
    .clk(clk),
    .wr(wr & ~adr[4]),
    .adr(adr),
    .lineno(lineno),
    .hit(taghit)
);
else
DSD9_L2_icache_cmptag u2
(
    .rst(rst),
    .clk(clk),
    .wr(wr & ~adr[4]),
    .adr(adr),
    .lineno(lineno),
    .hit(taghit)
);
end
endgenerate

assign hit = taghit & lv;

endmodule

// Four way set associative tag memory
module DSD9_L2_icache_cmptag4way(rst, clk, wr, adr, lineno, hit);
input rst;
input clk;
input wr;
input [37:0] adr;
output reg [8:0] lineno;
output hit;

reg [25:0] mem0 [0:127];
reg [25:0] mem1 [0:127];
reg [25:0] mem2 [0:127];
reg [25:0] mem3 [0:127];
reg [37:0] rradr;
integer n;
initial begin
    for (n = 0; n < 128; n = n + 1)
    begin
        mem0[n] = 0;
        mem1[n] = 0;
        mem2[n] = 0;
        mem3[n] = 0;
    end
end

reg wr2;
always @(posedge clk)
    wr2 <= wr;
wire [21:0] lfsro;
lfsr #(22,22'h0ACE3) u1 (rst, clk, !(wr2|wr), 1'b0, lfsro);
reg [8:0] wlineno;
always @(posedge clk)
begin
    if (wr && lfsro[1:0]==2'b00) begin mem0[adr[11:5]] <= adr[37:12]; wlineno <= {2'b00,adr[11:5]}; end
    if (wr && lfsro[1:0]==2'b01) begin mem1[adr[11:5]] <= adr[37:12]; wlineno <= {2'b01,adr[11:5]}; end
    if (wr && lfsro[1:0]==2'b10) begin mem2[adr[11:5]] <= adr[37:12]; wlineno <= {2'b10,adr[11:5]}; end
    if (wr && lfsro[1:0]==2'b11) begin mem3[adr[11:5]] <= adr[37:12]; wlineno <= {2'b11,adr[11:5]}; end
end
always @(posedge clk)
    rradr <= adr;
wire hit0 = mem0[rradr[11:5]]==rradr[37:12];
wire hit1 = mem1[rradr[11:5]]==rradr[37:12];
wire hit2 = mem2[rradr[11:5]]==rradr[37:12];
wire hit3 = mem3[rradr[11:5]]==rradr[37:12];
always @*
    if (wr2) lineno = wlineno;
    else if (hit0) lineno = {2'b00,rradr[11:5]};
    else if (hit1) lineno = {2'b01,rradr[11:5]};
    else if (hit2) lineno = {2'b10,rradr[11:5]};
    else lineno = {2'b11,rradr[11:5]};
assign hit = hit0|hit1|hit2|hit3;
endmodule

// Simple tag array, 1-way direct mapped
module DSD9_L2_icache_cmptag(rst, clk, wr, adr, lineno, hit);
input rst;
input clk;
input wr;
input [37:0] adr;
output reg [8:0] lineno;
output hit;

reg [23:0] mem [0:511];
reg [37:0] rradr;
integer n;
initial begin
    for (n = 0; n < 512; n = n + 1)
    begin
        mem[n] = 0;
    end
end

reg wr2;
always @(posedge clk)
    wr2 <= wr;
reg [8:0] wlineno;
always @(posedge clk)
begin
    if (wr) begin mem[adr[13:5]] <= adr[37:14]; wlineno <= adr[13:5]; end
end
always @(posedge clk)
    rradr <= adr;
wire hit = mem[rradr[13:5]]==rradr[37:14];
always @*
    if (wr2) lineno = wlineno;
    else lineno = rradr[13:5];
endmodule

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

module DSD9_dcache_mem(wclk, wr, wadr, sel, i, rclk, radr, o0, o1);
input wclk;
input wr;
input [13:0] wadr;
input [15:0] sel;
input [127:0] i;
input rclk;
input [13:0] radr;
output [255:0] o0;
output [255:0] o1;

reg [255:0] mem [0:511];
reg [13:0] rradr,rradrp32;

always @(posedge rclk)
    rradr <= radr;        
always @(posedge rclk)
    rradrp32 <= radr + 14'd32;

genvar n;
generate
begin
for (n = 0; n < 16; n = n + 1)
begin : dmem
reg [7:0] mem [31:0][0:511];
always @(posedge wclk)
begin
    if (wr & sel[n] & ~wadr[4]) mem[n][wadr[13:5]] <= i[n*8+7:n*8];
    if (wr & sel[n] & wadr[4]) mem[n+16][wadr[13:5]] <= i[n*8+7:n*8];
end
end
end
endgenerate

generate
begin
for (n = 0; n < 32; n = n + 1)
begin : dmemr
assign o0[n*8+7:n*8] = mem[n][rradr[13:5]];
assign o1[n*8+7:n*8] = mem[n][rradrp32[13:5]];
end
end
endgenerate

endmodule

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

module DSD9_dcache_tag(wclk, wr, wadr, rclk, radr, hit0, hit1);
input wclk;
input wr;
input [37:0] wadr;
input rclk;
input [37:0] radr;
output reg hit0;
output reg hit1;

wire [37:0] tago0, tago1;
wire [37:0] radrp32 = radr + 32'd32;

DSD9_dcache_tag1 u1 (
  .clka(wclk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(wr),      // input wire [0 : 0] wea
  .addra(wadr[13:5]),  // input wire [8 : 0] addra
  .dina(wadr),    // input wire [31 : 0] dina
  .clkb(rclk),    // input wire clkb
  .enb(1'b1),
  .addrb(radr[13:5]),  // input wire [8 : 0] addrb
  .doutb(tago0)  // output wire [31 : 0] doutb
);

DSD9_dcache_tag1 u2 (
  .clka(wclk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(wr),      // input wire [0 : 0] wea
  .addra(wadr[13:5]),  // input wire [8 : 0] addra
  .dina(wadr),    // input wire [31 : 0] dina
  .clkb(rclk),    // input wire clkb
  .enb(1'b1),
  .addrb(radrp32[13:5]),  // input wire [8 : 0] addrb
  .doutb(tago1)  // output wire [31 : 0] doutb
);

always @(posedge rclk)
    hit0 <= tago0[37:14]==radr[37:14];
always @(posedge rclk)
    hit1 <= tago1[37:14]==radrp32[37:14];

endmodule

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

module DSD9_dcache(wclk, wr, sel, wadr, i, rclk, rdsize, radr, o, hit, hit0, hit1);
input wclk;
input wr;
input [15:0] sel;
input [37:0] wadr;
input [127:0] i;
input rclk;
input [2:0] rdsize;
input [37:0] radr;
output reg [79:0] o;
output reg hit;
output hit0;
output hit1;
parameter byt = 3'd0;
parameter wyde = 3'd1;
parameter tetra = 3'd2;
parameter penta = 3'd3;
parameter deci = 3'd4;

wire [255:0] dc0, dc1;
wire [13:0] radrp32 = radr + 32'd32;

dcache_mem u1 (
  .clka(wclk),    // input wire clka
  .ena(wr),      // input wire ena
  .wea(sel),      // input wire [15 : 0] wea
  .addra(wadr[13:4]),  // input wire [9 : 0] addra
  .dina(i),    // input wire [127 : 0] dina
  .clkb(rclk),    // input wire clkb
  .addrb(radr[13:5]),  // input wire [8 : 0] addrb
  .doutb(dc0)  // output wire [255 : 0] doutb
);

dcache_mem u2 (
  .clka(wclk),    // input wire clka
  .ena(wr),      // input wire ena
  .wea(sel),      // input wire [15 : 0] wea
  .addra(wadr[13:4]),  // input wire [9 : 0] addra
  .dina(i),    // input wire [127 : 0] dina
  .clkb(rclk),    // input wire clkb
  .addrb(radrp32[13:5]),  // input wire [8 : 0] addrb
  .doutb(dc1)  // output wire [255 : 0] doutb
);

DSD9_dcache_tag u3
(
    .wclk(wclk),
    .wr(wr),
    .wadr(wadr),
    .rclk(rclk),
    .radr(radr),
    .hit0(hit0),
    .hit1(hit1)
);

// hit0, hit1 are also delayed by a clock already
always @(posedge rclk)
    o <= {dc1,dc0} >> {radr[4:0],3'b0};

always @*
    if (hit0 & hit1)
        hit = `TRUE;
    else if (hit0) begin
        case(rdsize)
        wyde:   hit = radr[4:0] <= 5'h1E;
        tetra:  hit = radr[4:0] <= 5'h1C;
        penta:  hit = radr[4:0] <= 5'h1B;
        deci:   hit = radr[4:0] <= 5'h16;
        default:    hit = `TRUE;    // byte
        endcase
    end
    else
        hit = `FALSE;

endmodule

module dcache_mem(clka, ena, wea, addra, dina, clkb, addrb, doutb);
input clka;
input ena;
input [15:0] wea;
input [9:0] addra;
input [127:0] dina;
input clkb;
input [8:0] addrb;
output reg [255:0] doutb;

reg [255:0] mem [0:511];
reg [255:0] doutb1;

genvar g;
generate begin
for (g = 0; g < 16; g = g + 1)
begin
always @(posedge clka)
    if (ena & wea[g] & ~addra[0]) mem[addra[9:1]][g*8+7:g*8] <= dina[g*8+7:g*8];
always @(posedge clka)
    if (ena & wea[g] & addra[0]) mem[addra[9:1]][g*8+7+128:g*8+128] <= dina[g*8+7:g*8];
end
end
endgenerate
always @(posedge clkb)
    doutb1 <= mem[addrb];
always @(posedge clkb)
    doutb <= doutb1;

endmodule
