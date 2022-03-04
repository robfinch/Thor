// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2021_tailptrs.sv
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

module Thor2021_tailptrs(rst_i, clk_i, branchmiss, stomp, queuedCnt,
	tails, active_tag, rob);
parameter QSLOTS = `QSLOTS;
parameter RENTRIES = `RENTRIES;
input rst_i;
input clk_i;
input branchmiss;
input [RENTRIES-1:0] stomp;
input [2:0] queuedCnt;
output SrcId tails [0:QSLOTS-1];
output SrcId active_tag;
input sReorderEntry rob [0:RENTRIES-1];

integer n, j;

always_ff @(posedge clk_i)
if (rst_i) begin
	for (n = 0; n < RENTRIES; n = n + 1)
		tails[n] <= n;
	active_tag <= 1'd0;
end
else begin
	if (!branchmiss) begin
		for (n = 0; n < RENTRIES; n = n + 1)
			tails[n] <= (tails[n] + queuedCnt) % RENTRIES;	
	end
	else begin
		for (n = RENTRIES-1; n >= 0; n = n - 1)
			// (QENTRIES-1) is needed to ensure that n increments forwards so that the modulus is
			// a positive number.
			if (stomp[n] & ~stomp[(n+(RENTRIES-1))%RENTRIES]) begin
				for (j = 0; j < QSLOTS; j = j + 1)
					tails[j] <= (n + j) % RENTRIES;
				active_tag <= rob[n].br_tag;
			end
	end
end

endmodule
