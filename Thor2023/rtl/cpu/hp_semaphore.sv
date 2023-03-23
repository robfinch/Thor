// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	hp_semaphore.sv
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

module hp_semaphore(rst, clk, set, clr, val);
parameter CHANNELS=16;
input rst;
input clk;
input [CHANNELS-1:0] set;
input [CHANNELS-1:0] clr;
output reg [CHANNELS-1:0] val;

wire [CHANNELS-1:0] rr_sel;
reg ff;

roundRobin
#(
	.N(CHANNELS)
) 
urr1
(
	.rst(rst),
	.clk(clk),
	.ce(~ff),		// If the ff is clear, arbitrate among the setters.
	.req(set),
	.lock('d0),
	.sel(rr_sel),
	.sel_enc()
);

// Any request to set the semaphore will be honored, but only the channel that
// was selected will get to clear the semaphore. Only the selected channel will
// receive indication that the semaphore was clear, other channels will see a set
// semaphore.

always_ff @(posedge clk)
if (rst)
	ff <= 1'b0;
else begin
	if (|set)
		ff <= 1'b1;
	else if (clr[rr_sel])
		ff <= 1'b0;
end

always_comb
begin
	val = {CHANNELS{1'b1}};	// default to block setting semaphore
	val[rr_sel] = 1'b0;			// only selected channel will see a clear
end

endmodule
