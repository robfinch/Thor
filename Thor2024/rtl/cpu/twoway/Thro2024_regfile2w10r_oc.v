`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//
//
// Register file with two write ports and six read ports.
// ============================================================================
//
//`define SIM

module Thor2024_regfileRam_sim(clka, ena, wea, addra, dina, clkb, enb, addrb, doutb);
parameter WID=32;
parameter RBIT = 11;
input clka;
input ena;
input [7:0] wea;
input [RBIT:0] addra;
input [WID-1:0] dina;
input clkb;
input enb;
input [RBIT:0] addrb;
output [WID-1:0] doutb;

integer n;
(* RAM_STYLE="BLOCK" *)
reg [WID-1:0] mem [0:4095];
reg [RBIT:0] raddrb;

initial begin
	for (n = 0; n < 4096; n = n + 1)
		mem[n] = 0;
end

always @(posedge clka) if (ena & wea[0]) mem[addra][7:0] <= dina[7:0];
always @(posedge clka) if (ena & wea[1]) mem[addra][15:8] <= dina[15:8];
always @(posedge clka) if (ena & wea[2]) mem[addra][23:16] <= dina[23:16];
always @(posedge clka) if (ena & wea[3]) mem[addra][31:24] <= dina[31:24];
always @(posedge clka) if (ena & wea[4]) mem[addra][39:32] <= dina[39:32];
always @(posedge clka) if (ena & wea[5]) mem[addra][47:40] <= dina[47:40];
always @(posedge clka) if (ena & wea[6]) mem[addra][55:48] <= dina[55:48];
always @(posedge clka) if (ena & wea[7]) mem[addra][63:56] <= dina[63:56];

always @(posedge clkb)
	raddrb <= addrb;
assign doutb = mem[raddrb];
	
endmodule

module Thor2024_regfile2w10r_oc(clk4x, clk, wr0, wr1, we0, we1, wa0, wa1, i0, i1,
	rclk, ra0, ra1, ra2, ra3, ra4, ra5, ra6, ra7, ra8, ra9
	o0, o1, o2, o3, o4, o5, o6, o7, o8, o9);
parameter WID=64;
parameter RBIT = 11;
input clk4x;
input clk;
input wr0;
input wr1;
input [7:0] we0;
input [7:0] we1;
input [RBIT:0] wa0;
input [RBIT:0] wa1;
input [WID-1:0] i0;
input [WID-1:0] i1;
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
reg wr1x;
reg [RBIT:0] wa1x;
reg [WID-1:0] i1x;
reg [7:0] we1x;

`ifdef SIM
Thor2024_regfileRam_sim urf10 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra0),
  .doutb(o00)
);

Thor2024_regfileRam_sim urf11 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra1),
  .doutb(o01)
);

Thor2024_regfileRam_sim urf12 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra2),
  .doutb(o02)
);

Thor2024_regfileRam_sim urf13 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra3),
  .doutb(o03)
);

Thor2024_regfileRam_sim urf14 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra4),
  .doutb(o04)
);

Thor2024_regfileRam_sim urf15 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra5),
  .doutb(o05)
);

Thor2024_regfileRam_sim urf16 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra6),
  .doutb(o06)
);

Thor2024_regfileRam_sim urf17 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra7),
  .doutb(o07)
);

Thor2024_regfileRam_sim urf18 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra8),
  .doutb(o08)
);

Thor2024_regfileRam_sim urf19 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra9),
  .doutb(o09)
);
`else
Thor2024_regfileRam urf10 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra0),
  .doutb(o00)
);

Thor2024_regfileRam urf11 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra1),
  .doutb(o01)
);

Thor2024_regfileRam urf12 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra2),
  .doutb(o02)
);

Thor2024_regfileRam urf13 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra3),
  .doutb(o03)
);

Thor2024_regfileRam urf14 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra4),
  .doutb(o04)
);

Thor2024_regfileRam urf15 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra5),
  .doutb(o05)
);

Thor2024_regfileRam urf16 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra6),
  .doutb(o06)
);

Thor2024_regfileRam urf17 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra7),
  .doutb(o07)
);

Thor2024_regfileRam urf18 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra8),
  .doutb(o08)
);

Thor2024_regfileRam urf19 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra9),
  .doutb(o09)
);

Thor2024_regfileRam urf20 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra0),
  .doutb(o10)
);

Thor2024_regfileRam urf21 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra1),
  .doutb(o11)
);

Thor2024_regfileRam urf22 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra2),
  .doutb(o12)
);

Thor2024_regfileRam urf23 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra3),
  .doutb(o13)
);

Thor2024_regfileRam urf24 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra4),
  .doutb(o14)
);

Thor2024_regfileRam urf25 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra5),
  .doutb(o15)
);

Thor2024_regfileRam urf26 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra6),
  .doutb(o16)
);

Thor2024_regfileRam urf27 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra7),
  .doutb(o17)
);

Thor2024_regfileRam urf28 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra8),
  .doutb(o18)
);

Thor2024_regfileRam urf29 (
  .clka(clk4x),
  .ena(wr),
  .wea(we),
  .addra(wa),
  .dina(i),
  .clkb(rclk),
  .enb(1'b1),
  .addrb(ra9),
  .doutb(o19)
);
`endif

reg [63:0] ab;

always_ff @(posedge clk)

// The same clock edge that would normally update the register file is the
// clock edge that causes the data to disappear for the next cycle. The
// data needs to be held onto so that it can update the register file on
// the next 4x clock.
always @(posedge clk)
begin
	wr1x <= wr1;
	we1x <= we1;
	wa1x <= wa1;
	i1x <= i1;
end

reg wclk2;
always @(posedge clk4x)
begin
	wclk2 <= clk;
	if (clk & ~wclk2) begin
		wr <= wr0;
		we <= we0;
		wa <= wa0;
		i <= i0;
	end
	else if (~clk & wclk2) begin
		wr <= wr1x;
		we <= we1x;
		wa <= wa1x;
		i <= i1x;
	end
	else begin
		wr <= 1'b0;
		we <= 8'h00;
		wa <= 'd0;
		i <= 'd0;
	end
end

assign o0 = ra0[5:0]==6'd0 ? {WID{1'b0}} :
	(wr1 && (ra0==wa1)) ? i1 :
	(wr0 && (ra0==wa0)) ? i0 : o00;
assign o1 = ra1[5:0]==6'd0 ? {WID{1'b0}} :
	(wr1 && (ra1==wa1)) ? i1 :
	(wr0 && (ra1==wa0)) ? i0 : o01;
assign o2 = ra2[5:0]==6'd0 ? {WID{1'b0}} :
	(wr1 && (ra2==wa1)) ? i1 :
	(wr0 && (ra2==wa0)) ? i0 : o02;
assign o3 = ra3[5:0]==6'd0 ? {WID{1'b0}} :
	(wr1 && (ra3==wa1)) ? i1 :
	(wr0 && (ra3==wa0)) ? i0 : o03;
assign o4 = ra4[5:0]==6'd0 ? {WID{1'b0}} :
  (wr1 && (ra4==wa1)) ? i1 :
  (wr0 && (ra4==wa0)) ? i0 : o04;
assign o5 = ra5[5:0]==6'd0 ? {WID{1'b0}} :
  (wr1 && (ra5==wa1)) ? i1 :
  (wr0 && (ra5==wa0)) ? i0 : o05;
assign o6 = ra6[5:0]==6'd0 ? {WID{1'b0}} :
  (wr1 && (ra6==wa1)) ? i1 :
  (wr0 && (ra6==wa0)) ? i0 : o06;
assign o7 = ra7[5:0]==6'd0 ? {WID{1'b0}} :
  (wr1 && (ra7==wa1)) ? i1 :
  (wr0 && (ra7==wa0)) ? i0 : o07;
assign o8 = ra8[5:0]==6'd0 ? {WID{1'b0}} :
  (wr1 && (ra8==wa1)) ? i1 :
  (wr0 && (ra8==wa0)) ? i0 : o08;
assign o8 = ra9[5:0]==6'd0 ? {WID{1'b0}} :
  (wr1 && (ra9==wa1)) ? i1 :
  (wr0 && (ra9==wa0)) ? i0 : o09;

endmodule

