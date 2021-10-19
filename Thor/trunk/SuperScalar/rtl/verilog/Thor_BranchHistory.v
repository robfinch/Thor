//=============================================================================
//        __
//   \\__/ o\    (C) 2013,2015  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//  
//	Thor_BranchHistory.v
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
//=============================================================================
//
module Thor_BranchHistory(rst, clk, advanceX, xisBranch, pc, xpc, takb, predict_taken);
parameter DBW=64;
input rst;
input clk;
input advanceX;
input xisBranch;
input [DBW-1:0] pc;
input [DBW-1:0] xpc;
input takb;
output predict_taken;

integer n;
reg [2:0] gbl_branch_hist;
reg [1:0] branch_history_table [255:0];
// For simulation only, initialize the history table to zeros.
// In the real world we don't care.
initial begin
    gbl_branch_hist = 0;
	for (n = 0; n < 256; n = n + 1)
		branch_history_table[n] = 0;
end
wire [7:0] bht_wa = {xpc[7:2],gbl_branch_hist[2:1]};		// write address
wire [7:0] bht_ra = {pc[7:2],gbl_branch_hist[2:1]};	// read address (IF stage)
wire [1:0] bht_xbits = branch_history_table[bht_wa];
wire [1:0] bht_ibits = branch_history_table[bht_ra];
assign predict_taken = bht_ibits==2'd0 || bht_ibits==2'd1;

// Two bit saturating counter
reg [1:0] xbits_new;
always @(takb or bht_xbits)
if (takb) begin
	if (bht_xbits != 2'd1)
		xbits_new <= bht_xbits + 2'd1;
	else
		xbits_new <= bht_xbits;
end
else begin
	if (bht_xbits != 2'd2)
		xbits_new <= bht_xbits - 2'd1;
	else
		xbits_new <= bht_xbits;
end

always @(posedge clk)
if (rst)
	gbl_branch_hist <= 3'b000;
else begin
	if (advanceX) begin
		if (xisBranch) begin
			gbl_branch_hist <= {gbl_branch_hist[1:0],takb};
			branch_history_table[bht_wa] <= xbits_new;
		end
	end
end

endmodule

