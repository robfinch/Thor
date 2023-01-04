// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_dctag.sv
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

import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_dctag(clk, wr, adr, way, rclk, ndx, tag);
parameter LINES=256;
parameter WAYS=4;
parameter TAGBIT=14;
parameter LOBIT=6;
localparam HIBIT=$clog2(LINES)-1+LOBIT;
input clk;
input wr;
input Address adr;
input [1:0] way;
input rclk;
input [6:0] ndx;
(* ram_style="block" *)
output reg [$bits(Address)-1:TAGBIT] tag [3:0];

reg [$bits(Address)-1:TAGBIT] tags [0:WAYS *LINES-1];
reg [$clog2(LINES)-1:0] rndx;

integer g;
integer n;

initial begin
for (g = 0; g < WAYS; g = g + 1) begin
  for (n = 0; n < LINES; n = n + 1)
    tags[g * LINES + n] = 32'd1;
end
end

always_ff @(posedge clk)
begin
	if (wr)
		tags[way * LINES + adr[HIBIT:LOBIT]] <= adr[$bits(Address)-1:TAGBIT];
end
always_ff @(posedge rclk)
	rndx <= ndx;
always_comb
	tag[0] = tags[0 * LINES + rndx];
always_comb
	tag[1] = tags[1 * LINES + rndx];
always_comb
	tag[2] = tags[2 * LINES + rndx];
always_comb
	tag[3] = tags[3 * LINES + rndx];

endmodule
