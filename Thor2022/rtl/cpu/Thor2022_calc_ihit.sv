// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_calc_ihit.sv
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
import Thor2022_mmupkg::*;

module Thor2022_calc_ihit(clk, ip, tag, valid, ihit, rway, vtag);
input clk;
input [AWID-1:0] ip;
input [AWID-1:6] tag [0:3] [0:512/4-1];
input [512/4-1:0] valid [0:3];
output reg ihit;
output reg [1:0] rway;
output reg [AWID-7:0] vtag;	// victim tag

reg [AWID-7:0] prev_vtag = 'd0;
reg [1:0] prev_rway = 'd0;
reg ihit1a;
reg ihit1b;
reg ihit1c;
reg ihit1d;

always_ff @(posedge clk)
begin
  ihit1a = tag[0][ip[12:6]]==ip[AWID-1:6] && valid[0][ip[12:6]]==TRUE;
  ihit1b = tag[1][ip[12:6]]==ip[AWID-1:6] && valid[1][ip[12:6]]==TRUE;
  ihit1c = tag[2][ip[12:6]]==ip[AWID-1:6] && valid[2][ip[12:6]]==TRUE;
  ihit1d = tag[3][ip[12:6]]==ip[AWID-1:6] && valid[3][ip[12:6]]==TRUE;
	ihit = ihit1a|ihit1b|ihit1c|ihit1d;
end

always_comb
begin
  case(1'b1)
  ihit1a: rway <= 2'b00;
  ihit1b: rway <= 2'b01;
  ihit1c: rway <= 2'b10;
  ihit1d: rway <= 2'b11;
  default:  rway <= prev_rway;
  endcase
end

always_ff @(posedge clk)
	prev_rway <= rway;

// For victim cache update
always_comb
begin
  case(1'b1)
  ihit1a: vtag <= tag[0][ip[12:6]];
  ihit1b: vtag <= tag[1][ip[12:6]];
  ihit1c: vtag <= tag[2][ip[12:6]];
  ihit1d: vtag <= tag[3][ip[12:6]];
  default:  vtag <= prev_vtag;
  endcase
end

always_ff @(posedge clk)
	prev_vtag <= vtag;

endmodule
