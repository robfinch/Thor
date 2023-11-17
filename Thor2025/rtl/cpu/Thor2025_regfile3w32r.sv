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
module Thor2025_regfile3w32r(rst, clk, 
	wr0, wr1, wr2, we0, we1, we2, wa0, wa1, wa2, i0, i1, i2,
	rclk, ra, o);
parameter WID=64;
parameter RBIT = 11;
parameter RPORTS = 28;
input rst;
input clk;
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
input [RBIT:0] ra [0:RPORTS-1];
output reg [WID-1:0] o [0:RPORTS-1];

reg wr;
reg [RBIT:0] wa;
reg [WID-1:0] i;
reg [7:0] we;
wire [WID-1:0] o0 [0:RPORTS-1];
wire [WID-1:0] o1 [0:RPORTS-1];
wire [WID-1:0] o2 [0:RPORTS-1];
reg wr1x;
reg [RBIT:0] wa1x;
reg [WID-1:0] i1x;
reg [7:0] we1x;

genvar g;

generate begin : gRF
	for (g = 0; g < 32; g = g + 1) begin
		Thor2025_regfileRam urf0 (
		  .clka(clk),
		  .ena(wr0),
		  .wea(we0),
		  .addra(wa0),
		  .dina(i0),
		  .clkb(rclk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o0[g])
		);
		Thor2025_regfileRam urf1 (
		  .clka(clk),
		  .ena(wr1),
		  .wea(we1),
		  .addra(wa1),
		  .dina(i1),
		  .clkb(rclk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o1[g])
		);
		Thor2025_regfileRam urf2 (
		  .clka(clk),
		  .ena(wr2),
		  .wea(we2),
		  .addra(wa2),
		  .dina(i2),
		  .clkb(rclk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o2[g])
		);
	end
end
endgenerate

integer n;
// Live value table
reg [1:0] lvt [95:0];

always_ff @(posedge clk, posedge rst)
if (rst) begin
	for (n = 0; n < 96; n = n + 1)
		lvt[n] <= 'd0;
end
else begin
	case({wr2,wr1,wr0})
	3'b111:
		if (wa0==wa1 && wa0==wa2)
			lvt[wa2] <= 2'd2;
		else if (wa0==wa2) begin
			lvt[wa2] <= 2'd2;
			lvt[wa1] <= 2'd1;
		end
		else if (wa1==wa2) begin
			lvt[wa2] <= 2'd2;
			lvt[wa0] <= 2'd0;
		end
		else if (wa0==wa1) begin
			lvt[wa1] <= 2'd1;
			lvt[wa2] <= 2'd2;
		end
		else begin
			lvt[wa2] <= 2'd2;
			lvt[wa1] <= 2'd1;
			lvt[wa0] <= 2'd0;
		end
	3'b110:
		if (wa1==wa2)
			lvt[wa2] <= 2'd2;
		else begin
			lvt[wa1] <= 2'd1;
			lvt[wa2] <= 2'd2;
		end
	3'b101:
		if (wa0==wa2)
			lvt[wa2] <= 2'd2;
		else begin
			lvt[wa0] <= 2'd0;
			lvt[wa2] <= 2'd2;
		end
	3'b100:
		lvt[wa2] <= 2'd2;
	3'b011:
		if (wa0==wa1)
			lvt[wa1] <= 2'd1;
		else begin
			lvt[wa0] <= 2'd0;
			lvt[wa1] <= 2'd1;
		end
	3'b010:
		lvt[wa1] <= 2'd1;
	3'b001:
		lvt[wa0] <= 2'd0;
	3'b000:
		;
	endcase
end

generate begin : gRFO
	for (g = 0; g < 32; g = g + 1) begin
		always_comb
			o[g] = ra[g][5:0]==6'd0 ? {WID{1'b0}} :
				(wr2 && (ra[g]==wa2)) ? i2 :
				(wr1 && (ra[g]==wa1)) ? i1 :
				(wr0 && (ra[g]==wa0)) ? i0 : lvt[ra[g]]==2'd2 ? o2[g] : lvt[ra[g]]==2'd1 ? o1[g] : o0[g];
	end
end
endgenerate

endmodule
