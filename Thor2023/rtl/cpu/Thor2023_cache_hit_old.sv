// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_cache_hit.sv
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
// 657 LUTs / 22 FFs                                                                          
// ============================================================================

import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_cache_hit(clk, adr, ndx, ptag, vtag, valid, hit,
	snoop_adr, snoop_v, snoop_ndx, snoop_hit, snoop_way, rway, victag, cv);
parameter LINES=256;
parameter WAYS=4;
parameter AWID=32;
parameter TAGBIT=14;
input clk;
input address_t adr;
input [$clog2(LINES)-1:0] ndx;
input cache_tag_t [3:0] ptag;
input cache_tag_t [3:0] vtag;
input [LINES-1:0] valid [0:WAYS-1];
output reg hit;
input address_t snoop_adr;
input snoop_v;
input [$clog2(LINES)-1:0] snoop_ndx;
output reg snoop_hit;
output reg [1:0] snoop_way;
output [1:0] rway;
output cache_tag_t victag;	// victim tag
output reg cv;

reg [AWID-7:0] prev_vtag = 'd0;
reg [1:0] prev_rway = 'd0;
reg [WAYS-1:0] hit1, snoop_hit1;
reg hit2;
reg cv2, cv1;
reg [1:0] rway1;

integer k,ks;
always_comb//ff @(posedge clk)
begin
	for (k = 0; k < WAYS; k = k + 1)
	  hit1[k] = vtag[k[1:0]]==adr[$bits(address_t)-1:TAGBIT] && valid[k][ndx]==1'b1;
end
always_comb//ff @(posedge clk)
begin
	for (ks = 0; ks < WAYS; ks = ks + 1)
	  snoop_hit1[ks] = ptag[ks[1:0]]==snoop_adr[$bits(address_t)-1:TAGBIT] && valid[ks][snoop_ndx]==1'b1;
end

integer k1;
always_comb
begin
	cv2 = 1'b0;
	for (k1 = 0; k1 < WAYS; k1 = k1 + 1)
	  cv2 = cv2 | valid[k1][ndx]==1'b1;
end

integer n;
always_comb
begin
	rway1 = prev_rway;
	for (n = 0; n < WAYS; n = n + 1)	
		if (hit1[n]) rway1 = n;
end

integer n1;
always_comb
begin
	snoop_way = 2'd0;
	for (n = 0; n < WAYS; n = n + 1)	
		if (snoop_hit1[n]) snoop_way = n;
end

// For victim cache update
integer m;
always_comb
begin
	victag = prev_vtag;
	for (m = 0; m < WAYS; m = m + 1)
		if (hit1[m]) victag = vtag[m[1:0]];
end


always_ff @(posedge clk)
	prev_rway <= rway1;
assign rway = rway1;

always_comb//ff @(posedge clk)
	hit = |hit1;
always_comb//ff @(posedge clk)
	snoop_hit = |snoop_hit1 & snoop_v;
//always_ff @(posedge clk)
//	hit = #1 hit2 & |hit1;

always_ff @(posedge clk)
	prev_vtag <= victag;
always_ff @(posedge clk)
	cv1 <= cv2;
always_ff @(posedge clk)
	cv <= cv1;	

endmodule
