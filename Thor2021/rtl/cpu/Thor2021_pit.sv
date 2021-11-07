`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	- programmable interval timer
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
//
//	Reg	Description
//	00	current count   (read only)
//	04	max count	    (read-write)
//  08  on time			(read-write)
//	0C	control
//		byte 0 for counter 0, byte 1 for counter 1, byte 2 for counter 2
//		bit in byte
//		0 = 1 = load, automatically clears
//	    1 = 1 = enable counting, 0 = disable counting
//		2 = 1 = auto-reload on terminal count, 0 = no reload
//		3 = 1 = use external clock, 0 = internal clk_i
//      4 = 1 = use gate to enable count, 0 = ignore gate
//	10	current count 1
//	14  max count 1
//	18  on time 1
//	20	current count 2
//	24	max count 2
//	28	on time 2
//	30	current count 3
//	34	max count 3
//	38	on time 3
//
//	- all four counter controls can be written at the same time with a
//    single instruction allowing synchronization of the counters.
// ============================================================================
//
module Thor2021_pit(rst_i, clk_i, cs_i, cyc_i, stb_i, ack_o, sel_i, we_i, adr_i, dat_i, dat_o,
	clk0, gate0, out0, clk1, gate1, out1, clk2, gate2, out2, clk3, gate3, out3
	);
input rst_i;
input clk_i;
input cs_i;
input cyc_i;
input stb_i;
output ack_o;
input [3:0] sel_i;
input we_i;
input [5:0] adr_i;
input [31:0] dat_i;
output reg [31:0] dat_o;
input clk0;
input gate0;
output out0;
input clk1;
input gate1;
output out1;
input clk2;
input gate2;
output out2;
input clk3;
input gate3;
output out3;

integer n;
reg [31:0] maxcount [0:3];
reg [31:0] count [0:3];
reg [31:0] ont [0:3];
wire [3:0] gate;
wire [3:0] pulse;
reg ld [0:3];
reg ce [0:3];
reg ar [0:3];
reg ge [0:3];
reg xc [0:3];
reg out [0:3];

wire cs = cyc_i & stb_i & cs_i;
reg rdy;
always @(posedge clk_i)
	rdy <= cs;
assign ack_o = cs ? (we_i ? 1'b1 : rdy) : 1'b0;

assign out0 = out[0];
assign out1 = out[1];
assign out2 = out[2];
assign out3 = out[3];
assign gate[0] = gate0;
assign gate[1] = gate1;
assign gate[2] = gate2;
assign gate[3] = gate3;

edge_det ued0 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk0), .pe(pulse[0]), .ne(), .ee());
edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk1), .pe(pulse[1]), .ne(), .ee());
edge_det ued2 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk2), .pe(pulse[2]), .ne(), .ee());
edge_det ued3 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk3), .pe(pulse[3]), .ne(), .ee());

initial begin
	for (n = 0; n < 4; n = n + 1) begin
		maxcount[n] <= 32'd0;
		count[n] <= 32'd0;
		ont[n] <= 32'd0;
		ld[n] <= 1'b0;
		ce[n] <= 1'b0;
		ar[n] <= 1'b0;
		ge[n] <= 1'b0;
		xc[n] <= 1'b0;
		out[n] <= 1'b0;
	end
end

always @(posedge clk_i)
if (rst_i) begin
	for (n = 0; n < 4; n = n + 1) begin
		ld[n] <= 1'b0;
		ce[n] <= 1'b0;
		ar[n] <= 1'b1;
		ge[n] <= 1'b0;
		out[n] <= 1'b0;
	end	
end
else begin
	for (n = 0; n < 4; n = n + 1) begin
		ld[n] <= 1'b0;
		if (cs && we_i && adr_i[5:4]==n)
		case(adr_i[3:2])
		2'd1:	maxcount[n] <= dat_i;
		2'd2:	ont[n] <= dat_i;
		2'd3:	begin
					if (sel_i[0]) begin
						ld[0] <= dat_i[0];
						ce[0] <= dat_i[1];
						ar[0] <= dat_i[2];
						xc[0] <= dat_i[3];
						ge[0] <= dat_i[4];
					end
					if (sel_i[1]) begin
						ld[1] <= dat_i[8];
						ce[1] <= dat_i[9];
						ar[1] <= dat_i[10];
						xc[1] <= dat_i[11];
						ge[1] <= dat_i[12];
					end
					if (sel_i[2]) begin
						ld[2] <= dat_i[16];
						ce[2] <= dat_i[17];
						ar[2] <= dat_i[18];
						xc[2] <= dat_i[19];
						ge[2] <= dat_i[20];
					end
					if (sel_i[3]) begin
						ld[3] <= dat_i[24];
						ce[3] <= dat_i[25];
						ar[3] <= dat_i[26];
						xc[3] <= dat_i[27];
						ge[3] <= dat_i[28];
					end
				end
		default:	;
		endcase
		if (cs) begin
			if (adr_i[5:4]==n)
				case(adr_i[3:2])
				2'd0:	dat_o <= count[n];
				2'd1:	dat_o <= maxcount[n];
				2'd2:	dat_o <= ont[n];
				2'd3:	dat_o <= {ge[3],xc[3],ar[3],ce[3],4'b0,ge[2],xc[2],ar[2],ce[2],4'b0,ge[1],xc[1],ar[1],ce[1],4'b0,ge[0],xc[0],ar[0],ce[0],1'b0};
				endcase
			end
		else
			dat_o <= 32'd0;
		
		if (ld[n]) begin
			count[n] <= maxcount[n];
		end
		else if ((xc[n] ? pulse[n] & ce[n] : ce[n]) & (ge[n] ? gate[n] : 1'b1)) begin
			count[n] <= count[n] - 2'd1;
			if (count[n]==ont[n])
				out[n] <= 1'b1;
			else if (count[n]==32'd0) begin
				out[n] <= 1'b0;
				if (ar[n]) begin
					count[n] <= maxcount[n];
				end
				else begin
					ce[n] <= 1'b0;
				end
			end
		end
	end
end

endmodule
