//=============================================================================
//        __
//   \\__/ o\    (C) 2019-2023  Robert Finch, Waterloo
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
//=============================================================================
//

module gselectPredictor(rst, clk, clk2x, en, xisBranch, xip, takb, ip, predict_taken);
parameter AMSB=31;
parameter DBW=16;
input rst;
input clk;
input clk2x;
input en;
input [1:0] xisBranch;
input [AMSB:0] xip [0:1];
input [1:0] takb;
input [AMSB:0] ip;
output reg predict_taken;

integer n;

reg [AMSB+1:0] pcs [0:31];
reg [AMSB:0] pc = 1'd0;
reg takbx;
reg [4:0] pcshead,pcstail;
reg wrhist;
reg [2:0] gbl_branch_hist;
reg [1:0] branch_history_table [511:0];
// For simulation only, initialize the history table to zeros.
// In the real world we don't care.
initial begin
	for (n = 0; n < 512; n = n + 1)
		branch_history_table[n] = 3;
end
wire [8:0] bht_wa = {pc[6:0],gbl_branch_hist[2:1]};		// write address
wire [1:0] bht_xbits = branch_history_table[bht_wa];
reg [8:0] bht_ra;
reg [1:0] bht_ibits;
always_comb
begin
	bht_ra = {ip[6:0],gbl_branch_hist[2:1]};	// read address (IF stage)
	bht_ibits = branch_history_table[bht_ra];
	predict_taken = (bht_ibits==2'd0 || bht_ibits==2'd1) && en;
end

reg xisBr;
reg xtkb;
reg [AMSB:0] xipx;
always_comb
begin
	xisBr <= xisBranch[clk];
	xtkb <= takb[clk];
	xipx <= xip[clk];
end

always_ff @(posedge clk2x)
if (rst)
	pcstail <= 5'd0;
else begin
	if (xisBr) begin
		pcs[pcstail] <= {xtkb,xipx[AMSB:0]};
		pcstail <= pcstail + 5'd1;
	end
end

always_ff @(posedge clk)
if (rst)
	pcshead <= 5'd0;
else begin
	wrhist <= 1'b0;
	if (pcshead != pcstail) begin
		pc <= pcs[pcshead][AMSB:0];
		takbx <= pcs[pcshead][AMSB+1];
		wrhist <= 1'b1;
		pcshead <= pcshead + 5'd1;
	end
end

// Two bit saturating counter
// If taking a branch in commit0 then a following branch
// in commit1 is never encountered. So only update for
// commit1 if commit0 is not taken.
reg [1:0] xbits_new;
always_comb
if (wrhist) begin
	if (takbx) begin
		if (bht_xbits != 2'd1)
			xbits_new <= bht_xbits + 2'd1;
		else
			xbits_new <= bht_xbits;
	end
	else begin
		if (bht_xbits != 2'd3)
			xbits_new <= bht_xbits - 2'd1;
		else
			xbits_new <= bht_xbits;
	end
end
else
	xbits_new <= bht_xbits;

always_ff @(posedge clk)
if (rst)
	gbl_branch_hist <= 3'b000;
else begin
  if (en) begin
    if (wrhist) begin
      gbl_branch_hist <= {gbl_branch_hist[1:0],takbx};
      branch_history_table[bht_wa] <= xbits_new;
    end
	end
end

endmodule

