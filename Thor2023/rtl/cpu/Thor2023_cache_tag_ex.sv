// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_cache_tag_ex.sv
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
// 352 LUTs / 4096 FFs                                                                          
// ============================================================================

import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_cache_tag_ex(rst, clk, wr, vadr_i, padr_i, way, rclk, ndx, tag,
	ptags0, ptags1, ptags2, ptags3);
parameter LINES=64;
parameter WAYS=4;
parameter TAGBIT=12;
parameter LOBIT=6;
localparam HIBIT=$clog2(LINES)-1+LOBIT;
input rst;
input clk;
input wr;
input Thor2023Pkg::address_t vadr_i;
input Thor2023Pkg::address_t padr_i;
input [1:0] way;
input rclk;
input [$clog2(LINES)-1:0] ndx;
output cache_tag_ex_t [3:0] tag;
output cache_tag_ex_t ptags0 [0:LINES-1];	// physical tags
output cache_tag_ex_t ptags1 [0:LINES-1];
output cache_tag_ex_t ptags2 [0:LINES-1];
output cache_tag_ex_t ptags3 [0:LINES-1];


//typedef logic [$bits(code_address_t)-1:TAGBIT] tag_t;

(* ram_style="distributed" *)
cache_tag_ex_t vtags0 [0:LINES-1];	// virtual tags
(* ram_style="distributed" *)
cache_tag_ex_t vtags1 [0:LINES-1];
(* ram_style="distributed" *)
cache_tag_ex_t vtags2 [0:LINES-1];
(* ram_style="distributed" *)
cache_tag_ex_t vtags3 [0:LINES-1];

/*
cache_tag_ex_t [LINES-1:0] ptags0;
cache_tag_ex_t [LINES-1:0] ptags1;
cache_tag_ex_t [LINES-1:0] ptags2;
cache_tag_ex_t [LINES-1:0] ptags3;
*/
integer g,g1;
integer n,n1;

initial begin
for (n = 0; n < LINES; n = n + 1) begin
	vtags0[n] <= 'd1;
	vtags1[n] <= 'd1;
	vtags2[n] <= 'd1;
	vtags3[n] <= 'd1;
	ptags0[n] <= 'd1;
	ptags1[n] <= 'd1;
	ptags2[n] <= 'd1;
	ptags3[n] <= 'd1;
end
end

always_ff @(posedge clk)
// Resetting all the tags will force implementation with FF's. Since tag values
// do not matter to synthesis it is simply omitted.
`ifdef IS_SIM
if (rst) begin
	for (n1 = 0; n1 < LINES; n1 = n1 + 1) begin
		vtags0[n1] <= 'd1;
		vtags1[n1] <= 'd1;
		vtags2[n1] <= 'd1;
		vtags3[n1] <= 'd1;
	end
end
else
`endif
begin
	if (wr && way==2'd0) vtags0[vadr_i[HIBIT:LOBIT]] <= {vadr_i[$bits(Thor2023Pkg::address_t)-1:TAGBIT]};
	if (wr && way==2'd1) vtags1[vadr_i[HIBIT:LOBIT]] <= {vadr_i[$bits(Thor2023Pkg::address_t)-1:TAGBIT]};
	if (wr && way==2'd2) vtags2[vadr_i[HIBIT:LOBIT]] <= {vadr_i[$bits(Thor2023Pkg::address_t)-1:TAGBIT]};
	if (wr && way==2'd3) vtags3[vadr_i[HIBIT:LOBIT]] <= {vadr_i[$bits(Thor2023Pkg::address_t)-1:TAGBIT]};
end

always_ff @(posedge clk)
begin
	if (wr && way==2'd0) ptags0[vadr_i[HIBIT:LOBIT]] <= {padr_i[$bits(Thor2023Pkg::address_t)-1:TAGBIT]};
	if (wr && way==2'd1) ptags1[vadr_i[HIBIT:LOBIT]] <= {padr_i[$bits(Thor2023Pkg::address_t)-1:TAGBIT]};
	if (wr && way==2'd2) ptags2[vadr_i[HIBIT:LOBIT]] <= {padr_i[$bits(Thor2023Pkg::address_t)-1:TAGBIT]};
	if (wr && way==2'd3) ptags3[vadr_i[HIBIT:LOBIT]] <= {padr_i[$bits(Thor2023Pkg::address_t)-1:TAGBIT]};
end

assign tag[0] = vtags0[ndx];
assign tag[1] = vtags1[ndx];
assign tag[2] = vtags2[ndx];
assign tag[3] = vtags3[ndx];

endmodule
