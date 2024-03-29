// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_dchit.sv
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

module Thor2023_dchit(rst, clk, tags, ndx, adr, valid, hits, hit, rway);
parameter LINES=256;
parameter TAGBIT=14;
input rst;
input clk;
input [$bits(address_t)-1:TAGBIT] tags [3:0];
input [$clog2(LINES)-1:0] ndx;
input physical_address_t adr;
input [LINES-1:0] valid [0:3];
output reg [3:0] hits;
output reg hit;
output reg [1:0] rway;

reg [1:0] prev_rway;

always_comb	//(posedge clk_g)
  hits[0] <= tags[2'd0]==adr[$bits(address_t)-1:TAGBIT] && valid[0][ndx];
always_comb	//(posedge clk_g)
  hits[1] <= tags[2'd1]==adr[$bits(address_t)-1:TAGBIT] && valid[1][ndx];
always_comb	//(posedge clk_g)
  hits[2] <= tags[2'd2]==adr[$bits(address_t)-1:TAGBIT] && valid[2][ndx];
always_comb	//(posedge clk_g)
  hits[3] <= tags[2'd3]==adr[$bits(address_t)-1:TAGBIT] && valid[3][ndx];
always_ff @(posedge clk)
	hit <= |hits;

always_ff @(posedge clk)
begin
  case(1'b1)
  hits[0]: rway <= 2'b00;
  hits[1]: rway <= 2'b01;
  hits[2]: rway <= 2'b10;
  hits[3]: rway <= 2'b11;
  default:  rway <= prev_rway;
  endcase
end

always_ff @(posedge clk, posedge rst)
if (rst)
	prev_rway <= 2'b00;
else
	prev_rway <= rway;

endmodule
