// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_regfile_src.sv
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

module Thor2022_regfile_src(rst, clk, head0,
	commit0_id, commit0_wr, commit0_tgt, commit1_wr, commit1_tgt,
	branchmiss, reb, latestID, livetarget, latestID2, livetarget2, 
	decbus0, decbus1, dec0, dec1, regfile_valid, next_regfile_src, regfile_src);
input rst;
input clk;
input [2:0] head0;
input [5:0] commit0_id;
input commit0_wr;
input [5:0] commit0_tgt;
input commit1_wr;
input [5:0] commit1_tgt;
input branchmiss;
input sReorderEntry [7:0] reb;
input [NREGS-1:0] latestID [0:7];
input [NREGS-1:0] livetarget;
input [NREGS-1:0] latestID2 [0:7];
input [NREGS-1:0] livetarget2;
input DecodeOut decbus0;
input DecodeOut decbus1;
input [2:0] dec0;
input [2:0] dec1;
input [NREGS-1:0] regfile_valid;
output reg [5:0] next_regfile_src [0:NREGS-1];
output reg [5:0] regfile_src [0:NREGS-1];

integer n,n1;

always_ff @(negedge clk)
if (rst) begin
	for (n = 0; n < NREGS; n = n + 1) begin
		next_regfile_src[n] <= 6'd31;
	end
end
else begin

	for (n = 0; n < NREGS; n = n + 1)
		next_regfile_src[n] <= regfile_src[n];

	if (branchmiss) begin
		for (n = 0; n < REB_ENTRIES; n = n + 1) begin
	  	if (|latestID[n]) begin
	  		next_regfile_src[reb[n].dec.Rt] <= #1 n;
	  		$display("%h Reset reg %d source to %d", reb[n].ip, reb[n].dec.Rt, n);
	  	end
	  	if (|latestID2[n]) begin
	  		next_regfile_src[reb[n].dec.Rt2] <= #1 n;
	  		$display("%h Reset reg %d source to %d", reb[n].ip, reb[n].dec.Rt2, n);
	  	end
	  end
	  /*
	  for (n = 0; n < 32; n = n + 1) begin
	  	if (~livetarget[n]) begin
	  		next_regfile_src[n] <= 5'd31;
	  		$display("%d Reg %d - no live target", $time, n);
	  	end
	  	if (~livetarget2[n]) begin
	  		next_regfile_src[n] <= 5'd31;
	  		$display("%d Reg %d - no live target", $time, n);
	  	end
	  end
	  */
	end
	else begin
//		for (n = 0; n < NREGS; n = n + 1)
//			if (commit0_tgt==n && commit0_wr && commit0_id==regfile_src[n])
//				regfile_src[n] <= 6'd31;
		if (dec0!= 3'd7 && reb[dec0].decompressed) begin
			for (n = 0; n < NREGS; n = n + 1)
				if (regfile_src[n]==dec0 && n != decbus0.Rt && n != decbus0.Rt2) begin
					if (regfile_valid[n])
						next_regfile_src[n] <= 6'd31;
					$display("%d Register %d source not reset.", $time, n);
					//next_regfile_src[n] <= 5'd31;
				end
			if (decbus0.rfwr) begin
				next_regfile_src[decbus0.Rt] <= #1 dec0;
				next_regfile_src[decbus0.Rt2] <= #1 dec0;
			end
				
			if (dec1!=3'd7 && reb[dec1].decompressed) begin
				if (decbus1.rfwr) begin
					next_regfile_src[decbus1.Rt] <= #1 dec1;
					next_regfile_src[decbus1.Rt2] <= #1 dec1;
				end
			end
		end
	end
	/*
	if (commit0_wr) begin
		next_regfile_src[commit0_tgt] <= 5'd31;
  	$display("Regfile %d source reset", commit0_tgt);
  end
	if (commit1_wr) begin
		next_regfile_src[commit1_tgt] <= 5'd31;
  	$display("Regfile %d source reset", commit1_tgt);
	end
	*/
	next_regfile_src[6'd0] <= #1 6'd31;
end


always_ff @(posedge clk)
if (rst) begin
	for (n1 = 0; n1 < NREGS; n1 = n1 + 1)
		regfile_src[n1] <= #1 6'd31;
end
else begin
	for (n1 = 0; n1 < NREGS; n1 = n1 + 1) begin
		regfile_src[n1] <= #1 next_regfile_src[n1];
		if (regfile_src[n1] != next_regfile_src[n1])
			$display("%d %h Register %d source set to %d", $time, reb[dec0].ip, reb[dec0].dec.Rt, dec0);
	end
	regfile_src[6'd0] <= #1 6'd31;
end


endmodule
