// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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

import Thor2024pkg::*;

module Thor2024_tail(rst, clk, branchmiss, fetchbuf0_v, fetchbuf1_v,fetchbuf0_instr, iqentry_stomp, iq, tail0, tail1);
input rst;
input clk;
input branchmiss;
input fetchbuf0_v;
input fetchbuf1_v;
input instruction_t fetchbuf0_instr;
input [QENTRIES-1:0] iqentry_stomp;
input iq_entry_t [QENTRIES-1:0] iq;
output que_ndx_t tail0;
output que_ndx_t tail1;

always_ff @(posedge clk)
if (rst) begin
	tail0 <= 'd0;
	tail1 <= 4'd1;
end
else begin
	// Reset tail pointers on a branch miss, not strictly necessary but improves
	// performance.
	if (branchmiss) begin	// if branchmiss
		if (PERFORMANCE) begin
	    if (iqentry_stomp[0] & ~iqentry_stomp[7]) begin
				tail0 <= 0;
				tail1 <= 1;
	    end
	    else if (iqentry_stomp[1] & ~iqentry_stomp[0]) begin
				tail0 <= 1;
				tail1 <= 2;
	    end
	    else if (iqentry_stomp[2] & ~iqentry_stomp[1]) begin
				tail0 <= 2;
				tail1 <= 3;
	    end
	    else if (iqentry_stomp[3] & ~iqentry_stomp[2]) begin
				tail0 <= 3;
				tail1 <= 4;
	    end
	    else if (iqentry_stomp[4] & ~iqentry_stomp[3]) begin
				tail0 <= 4;
				tail1 <= 5;
	    end
	    else if (iqentry_stomp[5] & ~iqentry_stomp[4]) begin
				tail0 <= 5;
				tail1 <= 6;
	    end
	    else if (iqentry_stomp[6] & ~iqentry_stomp[5]) begin
				tail0 <= 6;
				tail1 <= 7;
	    end
	    else if (iqentry_stomp[7] & ~iqentry_stomp[6]) begin
				tail0 <= 7;
				tail1 <= 0;
	    end
		end
	end
	else begin
		case ({fetchbuf0_v, fetchbuf1_v})
		2'b00:	;
		2'b01:
			if (iq[tail0].v == INV) begin
				tail0 <= (tail0 + 2'd1) % QENTRIES;
				tail1 <= (tail1 + 2'd1) % QENTRIES;
			end
		2'b10:
			if (iq[tail0].v == INV) begin
				tail0 <= (tail0 + 2'd1) % QENTRIES;
				tail1 <= (tail1 + 2'd1) % QENTRIES;
			end
		2'b11:
			if (iq[tail0].v == INV) begin
				if (fnIsBackBranch(fetchbuf0_instr) == TRUE) begin
					tail0 <= (tail0 + 2'd1) % QENTRIES;
					tail1 <= (tail1 + 2'd1) % QENTRIES;
				end
				else begin
			    if (iq[tail1].v == INV && SUPPORT_Q2) begin
						tail0 <= (tail0 + 2'd2) % QENTRIES;
						tail1 <= (tail1 + 2'd2) % QENTRIES;
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % QENTRIES;
						tail1 <= (tail1 + 2'd1) % QENTRIES;
					end				
				end
			end
		endcase
	end
end

endmodule
