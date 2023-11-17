`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
//
module Thor2025_regfile3w10r(rst, clk, pc0, pc1, 
	wr0, wr1, wr2, we0, we1, we2, wa0, wa1, wa2, i0, i1, i2,
	rclk, ra0, ra1, ra2, ra3, ra4, ra5, ra6, ra7, ra8, ra9,
	o0, o1, o2, o3, o4, o5, o6, o7, o8, o9);
parameter WID=64;
parameter RBIT = 11;
input rst;
input clk;
input [WID-1:0] pc0;
input [WID-1:0] pc1;
input wr0;
input wr1;
input wr2;
input [7:0] we0;
input [7:0] we1;
input [7:0] we2;
input [RBIT:0] wa0;
input [RBIT:0] wa1;
input [RBIT:0] wa2;
input [WID-1:0] i0;
input [WID-1:0] i1;
input [WID-1:0] i2;
input rclk;
input [RBIT:0] ra0;
input [RBIT:0] ra1;
input [RBIT:0] ra2;
input [RBIT:0] ra3;
input [RBIT:0] ra4;
input [RBIT:0] ra5;
input [RBIT:0] ra6;
input [RBIT:0] ra7;
input [RBIT:0] ra8;
input [RBIT:0] ra9;
output [WID-1:0] o0;
output [WID-1:0] o1;
output [WID-1:0] o2;
output [WID-1:0] o3;
output [WID-1:0] o4;
output [WID-1:0] o5;
output [WID-1:0] o6;
output [WID-1:0] o7;
output [WID-1:0] o8;
output [WID-1:0] o9;

reg wr;
reg [RBIT:0] wa;
reg [WID-1:0] i;
reg [7:0] we;
wire [WID-1:0] o00, o01, o02, o03, o04, o05, o06, o07, o08, o09;
wire [WID-1:0] o10, o11, o12, o13, o14, o15, o16, o17, o18, o19;
wire [WID-1:0] o20, o21, o22, o23, o24, o25, o26, o27, o28, o29;
reg wr1x;
reg [RBIT:0] wa1x;
reg [WID-1:0] i1x;
reg [7:0] we1x;

Thor2024_regfileRam urf10 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra0),
  .doutb(o00)
);

Thor2024_regfileRam urf11 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra1),
  .doutb(o01)
);

Thor2024_regfileRam urf12 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra2),
  .doutb(o02)
);

Thor2024_regfileRam urf13 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra3),
  .doutb(o03)
);

Thor2024_regfileRam urf14 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra4),
  .doutb(o04)
);

Thor2024_regfileRam urf15 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra5),
  .doutb(o05)
);

Thor2024_regfileRam urf16 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra6),
  .doutb(o06)
);

Thor2024_regfileRam urf17 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra7),
  .doutb(o07)
);

Thor2024_regfileRam urf18 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra8),
  .doutb(o08)
);

Thor2024_regfileRam urf19 (
  .clka(clk),
  .ena(wr0),
  .wea(we0),
  .addra(wa0),
  .dina(i0),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra9),
  .doutb(o09)
);

Thor2024_regfileRam urf20 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra0),
  .doutb(o10)
);

Thor2024_regfileRam urf21 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra1),
  .doutb(o11)
);

Thor2024_regfileRam urf22 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra2),
  .doutb(o12)
);

Thor2024_regfileRam urf23 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra3),
  .doutb(o13)
);

Thor2024_regfileRam urf24 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra4),
  .doutb(o14)
);

Thor2024_regfileRam urf25 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra5),
  .doutb(o15)
);

Thor2024_regfileRam urf26 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra6),
  .doutb(o16)
);

Thor2024_regfileRam urf27 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra7),
  .doutb(o17)
);

Thor2024_regfileRam urf28 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra8),
  .doutb(o18)
);

Thor2024_regfileRam urf29 (
  .clka(clk),
  .ena(wr1),
  .wea(we1),
  .addra(wa1),
  .dina(i1),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra9),
  .doutb(o19)
);

Thor2024_regfileRam urf30 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra0),
  .doutb(o20)
);

Thor2024_regfileRam urf31 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra1),
  .doutb(o21)
);

Thor2024_regfileRam urf32 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra2),
  .doutb(o22)
);

Thor2024_regfileRam urf33 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra3),
  .doutb(o23)
);

Thor2024_regfileRam urf34 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra4),
  .doutb(o24)
);

Thor2024_regfileRam urf35 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra5),
  .doutb(o25)
);

Thor2024_regfileRam urf36 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra6),
  .doutb(o26)
);

Thor2024_regfileRam urf37 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra7),
  .doutb(o27)
);

Thor2024_regfileRam urf38 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra8),
  .doutb(o28)
);

Thor2024_regfileRam urf39 (
  .clka(clk),
  .ena(wr2),
  .wea(we2),
  .addra(wa2),
  .dina(i2),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra9),
  .doutb(o29)
);

integer n;
// Live value table
reg [1:0] abc [63:0];

always_ff @(posedge clk, posedge rst)
if (rst) begin
	for (n = 0; n < 64; n = n + 1)
		abc[n] <= 'd0;
end
else begin
	case({wr2,wr1,wr0})
	3'b111:
		if (wa0==wa1 && wa0==wa2)
			abc[wa2] <= 2'd2;
		else if (wa0==wa2) begin
			abc[wa2] <= 2'd2;
			abc[wa1] <= 2'd1;
		end
		else if (wa1==wa2) begin
			abc[wa2] <= 2'd2;
			abc[wa0] <= 2'd0;
		end
		else if (wa0==wa1) begin
			abc[wa1] <= 2'd1;
			abc[wa2] <= 2'd2;
		end
		else begin
			abc[wa2] <= 2'd2;
			abc[wa1] <= 2'd1;
			abc[wa0] <= 2'd0;
		end
	3'b110:
		if (wa1==wa2)
			abc[wa2] <= 2'd2;
		else begin
			abc[wa1] <= 2'd1;
			abc[wa2] <= 2'd2;
		end
	3'b101:
		if (wa0==wa2)
			abc[wa2] <= 2'd2;
		else begin
			abc[wa0] <= 2'd0;
			abc[wa2] <= 2'd2;
		end
	3'b100:
		abc[wa2] <= 2'd2;
	3'b011:
		if (wa0==wa1)
			abc[wa1] <= 2'd1;
		else begin
			abc[wa0] <= 2'd0;
			abc[wa1] <= 2'd1;
		end
	3'b010:
		abc[wa1] <= 2'd1;
	3'b001:
		abc[wa0] <= 2'd0;
	3'b000:
		;
	endcase
end

assign o0 = ra0[5:0]==6'd0 ? {WID{1'b0}} : ra0[5:0]==6'd53 ? pc0 :
	(wr2 && (ra0==wa2)) ? i2 :
	(wr1 && (ra0==wa1)) ? i1 :
	(wr0 && (ra0==wa0)) ? i0 : abc[ra0]==2'd2 ? o20 : abc[ra0]==2'd1 ? o10 : o00;
assign o1 = ra1[5:0]==6'd0 ? {WID{1'b0}} : ra1[5:0]==6'd53 ? pc0 :
	(wr2 && (ra1==wa2)) ? i2 :
	(wr1 && (ra1==wa1)) ? i1 :
	(wr0 && (ra1==wa0)) ? i0 : abc[ra1]==2'd2 ? o21 : abc[ra1]==2'd1 ? o11 : o01;
assign o2 = ra2[5:0]==6'd0 ? {WID{1'b0}} : ra2[5:0]==6'd53 ? pc0 :
	(wr2 && (ra2==wa2)) ? i2 :
	(wr1 && (ra2==wa1)) ? i1 :
	(wr0 && (ra2==wa0)) ? i0 : abc[ra2]==2'd2 ? o22 : abc[ra2]==2'd1 ? o12 : o02;
assign o3 = ra3[5:0]==6'd0 ? {WID{1'b0}} : ra3[5:0]==6'd53 ? pc0 :
	(wr2 && (ra3==wa2)) ? i2 :
	(wr1 && (ra3==wa1)) ? i1 :
	(wr0 && (ra3==wa0)) ? i0 : abc[ra3]==2'd2 ? o23 : abc[ra3]==2'd1 ? o13 : o03;
assign o4 = ra4[5:0]==6'd0 ? {WID{1'b0}} : ra4[5:0]==6'd63 ? {WID{1'b1}} :
  (wr2 && (ra4==wa2)) ? i2 :
  (wr1 && (ra4==wa1)) ? i1 :
  (wr0 && (ra4==wa0)) ? i0 : abc[ra4]==2'd2 ? o24 : abc[ra4]==2'd1 ? o14 : o04;

assign o5 = ra5[5:0]==6'd0 ? {WID{1'b0}} : ra5[5:0]==6'd53 ? pc1 :
  (wr2 && (ra5==wa2)) ? i2 :
  (wr1 && (ra5==wa1)) ? i1 :
  (wr0 && (ra5==wa0)) ? i0 : abc[ra5]==2'd1 ? o25 : abc[ra5]==2'd1 ? o15 : o05;
assign o6 = ra6[5:0]==6'd0 ? {WID{1'b0}} : ra6[5:0]==6'd53 ? pc1 :
  (wr2 && (ra6==wa2)) ? i2 :
  (wr1 && (ra6==wa1)) ? i1 :
  (wr0 && (ra6==wa0)) ? i0 : abc[ra6]==2'd2 ? o26 : abc[ra6]==2'd1 ? o16 : o06;
assign o7 = ra7[5:0]==6'd0 ? {WID{1'b0}} : ra7[5:0]==6'd53 ? pc1 :
  (wr2 && (ra7==wa2)) ? i2 :
  (wr1 && (ra7==wa1)) ? i1 :
  (wr0 && (ra7==wa0)) ? i0 : abc[ra7]==2'd2 ? o27 : abc[ra7]==2'd1 ? o17 : o07;
assign o8 = ra8[5:0]==6'd0 ? {WID{1'b0}} : ra8[5:0]==6'd53 ? pc1 :
  (wr2 && (ra8==wa2)) ? i2 :
  (wr1 && (ra8==wa1)) ? i1 :
  (wr0 && (ra8==wa0)) ? i0 : abc[ra8]==2'd2 ? o28 : abc[ra8]==2'd1 ? o18 : o08;
assign o9 = ra9[5:0]==6'd0 ? {WID{1'b0}} : ra9[5:0]==6'd63 ? {WID{1'b1}} :
  (wr2 && (ra9==wa2)) ? i2 :
  (wr1 && (ra9==wa1)) ? i1 :
  (wr0 && (ra9==wa0)) ? i0 : abc[ra9]==2'd2 ? o29 : abc[ra9]==2'd1 ? o19 : o09;
/*
assign o0 = ra0[5:0]==6'd0 ? {WID{1'b0}} : ra0[5:0]==6'd53 ? pc0 : ab[ra0] ? o10 : o00;
assign o1 = ra1[5:0]==6'd0 ? {WID{1'b0}} : ra1[5:0]==6'd53 ? pc0 : ab[ra1] ? o11 : o01;
assign o2 = ra2[5:0]==6'd0 ? {WID{1'b0}} : ra2[5:0]==6'd53 ? pc0 : ab[ra2] ? o12 : o02;
assign o3 = ra3[5:0]==6'd0 ? {WID{1'b0}} : ra3[5:0]==6'd53 ? pc0 : ab[ra3] ? o13 : o03;
assign o4 = ra4[5:0]==6'd0 ? {WID{1'b0}} : ra4[5:0]==6'd63 ? {WID{1'b1}} : ab[ra4] ? o14 : o04;

assign o5 = ra5[5:0]==6'd0 ? {WID{1'b0}} : ra5[5:0]==6'd53 ? pc1 : ab[ra5] ? o15 : o05;
assign o6 = ra6[5:0]==6'd0 ? {WID{1'b0}} : ra6[5:0]==6'd53 ? pc1 : ab[ra6] ? o16 : o06;
assign o7 = ra7[5:0]==6'd0 ? {WID{1'b0}} : ra7[5:0]==6'd53 ? pc1 : ab[ra7] ? o17 : o07;
assign o8 = ra8[5:0]==6'd0 ? {WID{1'b0}} : ra8[5:0]==6'd53 ? pc1 : ab[ra8] ? o18 : o08;
assign o9 = ra9[5:0]==6'd0 ? {WID{1'b0}} : ra9[5:0]==6'd63 ? {WID{1'b1}} : ab[ra9] ? o19 : o09;
*/
endmodule

