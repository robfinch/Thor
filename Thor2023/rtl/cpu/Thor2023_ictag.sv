// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_ictag.sv
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

module Thor2023_ictag(rst, clk, wr, ipo, way, rclk, ndx, tag);
parameter LINES=256;
parameter WAYS=4;
parameter TAGBIT=14;
parameter LOBIT=6;
localparam HIBIT=$clog2(LINES)-1+LOBIT;
input rst;
input clk;
input wr;
input code_address_t ipo;
input [1:0] way;
input rclk;
input [$clog2(LINES)-1:0] ndx;
(* ram_style="distributed" *)
output [$bits(code_address_t)-1:TAGBIT] tag [0:3];

//typedef logic [$bits(code_address_t)-1:TAGBIT] tag_t;

(* ram_style="distributed" *)
reg [$bits(code_address_t)-1:TAGBIT] tags [0:WAYS-1][0:LINES-1];
reg [7:0] rndx;

integer g,g1;
integer n,n1;

initial begin
for (g = 0; g < WAYS; g = g + 1) begin
  for (n = 0; n < LINES; n = n + 1)
    tags[g][n] = 32'd1;
end
end

always_ff @(posedge clk)
// Resetting all the tags will force implementation with FF's. Since tag values
// do not matter to synthesis it is simply omitted.
`ifdef IS_SIM
if (rst) begin
	for (g1 = 0; g1 < WAYS; g1 = g1 + 1) begin
	  for (n1 = 0; n1 < LINES; n1 = n1 + 1)
	    tags[g1][n1] = 32'd1;
	end
end
else
`endif
begin
	if (wr)
		tags[way][ipo[HIBIT:LOBIT]] <= ipo[$bits(code_address_t)-1:TAGBIT];	// We know bit[5]
end

always_comb//ff @(posedge rclk)
	rndx <= ndx;
assign tag[0] = tags[0][rndx];
assign tag[1] = tags[1][rndx];
assign tag[2] = tags[2][rndx];
assign tag[3] = tags[3][rndx];

endmodule
