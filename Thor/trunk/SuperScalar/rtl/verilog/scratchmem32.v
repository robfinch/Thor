// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2015  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@opencores.org
//       ||
//
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
// ============================================================================
//
module scratchmem32(rst_i, clk_i, cyc_i, stb_i, ack_o, we_i, sel_i, adr_i, dat_i, dat_o);
parameter DBW=32;
input rst_i;
input clk_i;
input cyc_i;
input stb_i;
output ack_o;
input we_i;
input [DBW/8-1:0] sel_i;
input [DBW-1:0] adr_i;
input [DBW-1:0] dat_i;
output [DBW-1:0] dat_o;
reg [DBW-1:0] dat_o;

integer n;

reg [7:0] smemA0 [4095:0];
reg [7:0] smemB0 [4095:0];
reg [7:0] smemC0 [4095:0];
reg [7:0] smemD0 [4095:0];

initial begin
for (n = 0; n < 4096; n = n + 1)
begin
	smemA0[n] = 0;
	smemB0[n] = 0;
	smemC0[n] = 0;
	smemD0[n] = 0;
end
end
/*
generate
begin : gmem
if (DBW==64) begin
reg [7:0] smemE [4095:0];
reg [7:0] smemF [4095:0];
reg [7:0] smemG [4095:0];
reg [7:0] smemH [4095:0];

initial begin
for (n = 0; n < 4096; n = n + 1)
begin
	smemE[n] = 0;
	smemF[n] = 0;
	smemG[n] = 0;
	smemH[n] = 0;
end
end
end
end
endgenerate
*/
reg [13:2] radr;


wire cs = cyc_i && stb_i && adr_i[31:14]==18'h0000;

reg rdy,rdy1;
always @(posedge clk_i)
begin
	rdy1 <= cs;
	rdy <= rdy1 & cs;
end
assign ack_o = cs ? (we_i ? 1'b1 : rdy) : 1'b0;


always @(posedge clk_i)
	if (cs & we_i) begin
		$display("************************");
		$display("************************");
		$display("************************");
		$display ("wrote to scratchmem: %h=%h", adr_i, dat_i);
		$display("************************");
		$display("************************");
		$display("************************");
	end
always @(posedge clk_i)
	if (cs & we_i & sel_i[0]) begin
		smemA0[adr_i[13:2]] <= dat_i[7:0];
    end
always @(posedge clk_i)
	if (cs & we_i & sel_i[1]) begin
		smemB0[adr_i[13:2]] <= dat_i[15:8];
    end
always @(posedge clk_i)
	if (cs & we_i & sel_i[2]) begin
		smemC0[adr_i[13:2]] <= dat_i[23:16];
    end
always @(posedge clk_i)
	if (cs & we_i & sel_i[3]) begin
		smemD0[adr_i[13:2]] <= dat_i[31:24];
	end

/*
generate
begin : wmem
if (DBW==64) begin
always @(posedge clk_i)
	if (cs & we_i & sel_i[4])
		smemE[adr_i[13:2]] <= dat_i[39:32];
always @(posedge clk_i)
	if (cs & we_i & sel_i[5])
		smemF[adr_i[13:2]] <= dat_i[47:40];
always @(posedge clk_i)
	if (cs & we_i & sel_i[6])
		smemG[adr_i[13:2]] <= dat_i[55:48];
always @(posedge clk_i)
	if (cs & we_i & sel_i[7])
		smemH[adr_i[13:2]] <= dat_i[63:56];
end
end
endgenerate
*/
wire pe_cs;
edge_det u1(.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(cs), .pe(pe_cs), .ne(), .ee() );

reg [13:2] ctr;
always @(posedge clk_i)
	if (pe_cs) begin
		ctr <= adr_i[13:2] + 12'd1;
	end
	else if (cs)
		ctr <= ctr + 13'd1;

always @(posedge clk_i)
	radr <= pe_cs ? adr_i[13:2] : ctr;

//assign dat_o = cs ? {smemH[radr],smemG[radr],smemF[radr],smemE[radr],
//				smemD[radr],smemC[radr],smemB[radr],smemA[radr]} : 64'd0;
/*
generate begin : rdram
if (DBW==64) begin
always @(posedge clk_i)
if (cs) begin
	dat_o <= {smemH[radr],smemG[radr],smemF[radr],smemE[radr],
	           smemD[radr],smemC[radr],smemB[radr],smemA[radr]};
end
else
	dat_o <= {DBW{1'd0}};
end
else begin
always @(posedge clk_i)
if (cs) begin
	dat_o <= {smemD[radr],smemC[radr],smemB[radr],smemA[radr]};
end
else
	dat_o <= {DBW{1'd0}};
end
end
endgenerate
*/
wire [31:0] d0 = {smemD0[radr],smemC0[radr],smemB0[radr],smemA0[radr]};

always @(posedge clk_i)
if (cs) begin
	dat_o <= d0;
end
else
	dat_o <= {DBW{1'd0}};

endmodule
