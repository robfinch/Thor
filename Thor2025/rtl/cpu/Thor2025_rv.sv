// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
module Thor2025_rv(rst, clk, rgta, rgtb, rgtc, tags2free, rgua, rgub, rguc, valid);
parameter NPREG = 96;
parameter NFTAGS = 19;
input rst;
input clk;
input [6:0] rgta;
input [6:0] rgtb;
input [6:0] rgtc;
input [6:0] tags2free [NFTAGS-1:0];
input [6:0] rgua;
input [6:0] rgub;
input [6:0] rguc;
output reg [NPREG-1:0] valid;

integer n;

always_ff @(posedge clk)
if (rst) begin
	valid <= 'd0;
end
else begin
	// Registers allocated as targets (enqueue) are marked invalid.
	valid[rgta] <= 1'b0;
	valid[rgtb] <= 1'b0;
	valid[rgtc] <= 1'b0;
	// Registers freed up eg. branch miss are marked invalid.
	// Also previous physical register on commit.
	for (n = 0; n < NFTAGS; n = n + 1) begin
		valid[tags2free[n]] <= 1'b0;
	end
	// Registers written back to the register file are marked valid.
	valid[rgua] <= 1'b1;
	valid[rgub] <= 1'b1;
	valid[rguc] <= 1'b1;
	// Register zero is always_valid.
	valid[0] <= 1'b1;
end

endmodule
