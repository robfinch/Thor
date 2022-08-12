// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_regfile_valid.sv
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

module Thor2022_regfile_valid(rst, clk, commit0_id, commit0_wr, commit0_tgt, commit1_id, commit1_wr, commit1_tgt,
	branchmiss, reb, latestID, livetarget, decbus0, decbus1, dec0, dec1, regfile_src, next_regfile_valid, regfile_valid);
input rst;
input clk;
input [2:0] commit0_id;
input commit0_wr;
input [5:0] commit0_tgt;
input [2:0] commit1_id;
input commit1_wr;
input [5:0] commit1_tgt;
input branchmiss;
input sReorderEntry [7:0] reb;
input [NREGS-1:0] latestID [0:7];
input [NREGS-1:0] livetarget;
input DecodeOut decbus0;
input DecodeOut decbus1;
input [2:0] dec0;
input [2:0] dec1;
input [5:0] regfile_src [0:NREGS-1];
output reg [NREGS-1:0] next_regfile_valid;
output reg [NREGS-1:0] regfile_valid;

integer n,n1,n2;

reg [REB_ENTRIES-1:0] iq_source;
always_comb
	for (n2 = 0; n2 < REB_ENTRIES; n2 = n2 + 1)
	  iq_source[n] = |latestID[n2];

always_comb
if (rst) begin
	for (n = 0; n < NREGS; n = n + 1)
		next_regfile_valid[n] = 1'd1;
end
else begin

	for (n = 0; n < NREGS; n = n + 1)
		next_regfile_valid[n] = regfile_valid[n];

	if (branchmiss) begin
	  for (n = 0; n < NREGS; n = n + 1) begin
	  	if (~livetarget[n]) begin
	  		next_regfile_valid[n] = 1'd1;
	  		$display("%d Reg %d - no live target", $time, n);
	  	end
	  end
	end
	
	if (commit0_wr && !regfile_valid[commit0_tgt] && !(branchmiss && !livetarget[commit0_tgt])) begin
		next_regfile_valid[commit0_tgt] = (regfile_src[commit0_tgt]==commit0_id) || (branchmiss && iq_source[commit0_id]);
  	$display("Regfile %d valid=%d", commit0_tgt, (regfile_src[commit0_tgt]==commit0_id) || (branchmiss && iq_source[commit0_id]));
  end
	if (commit1_wr && !regfile_valid[commit1_tgt] && !(branchmiss && !livetarget[commit1_tgt])) begin
		next_regfile_valid[commit1_tgt] = (regfile_src[commit1_tgt]==commit1_id) || (branchmiss && iq_source[commit1_id]);
  	$display("Regfile %d valid=%d", commit1_tgt, (regfile_src[commit1_tgt]==commit1_id) || (branchmiss && iq_source[commit1_id]));
	end

	next_regfile_valid[6'd0] <= 1'd1;
end

always_ff @(posedge clk)
if (rst) begin
	for (n1 = 0; n1 < NREGS; n1 = n1 + 1)
		regfile_valid[n1] <= 1'b1;
end
else begin
	for (n1 = 0; n1 < NREGS; n1 = n1 + 1) begin
		regfile_valid[n1] <= #1 next_regfile_valid[n1];
	end
	if (dec0 != 3'd7 && reb[dec0].decompressed) begin
//			for (n = 0; n < 32; n = n + 1)
//				if (regfile_src[n]==dec0 && n != decbus0.Rt && n != head0) begin
//					$display("%d Register %d source not reset.", $time, n);
//					regfile_valid[n] <= 1'd1;
//				end
		if (decbus0.rfwr)
			regfile_valid[decbus0.Rt] <= 1'b0;
		if (dec1 != 3'd7 && reb[dec1].decompressed) begin
			if (decbus1.rfwr)
				regfile_valid[decbus1.Rt] <= 1'b0;
		end
	end
	regfile_valid[6'd0] <= 1'd1;
end

endmodule
