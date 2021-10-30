// ============================================================================
//        __
//   \\__/ o\    (C) 2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2021_btb_x1.sv
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

module Thor2021_BTB_x1(rst, clk, wr, wip, wtgt, takb, rclk, ip, tgt, hit, nip);
parameter RSTIP = 64'hFFC00007FFFC0100;
input rst;
input clk;
input wr;
input Address wip;
input Address wtgt;
input takb;
input rclk;
input Address ip;
output Address tgt;
output hit;
input Address nip;

integer n;

(* ram_style="block" *)
BTBEntry mem [0:1023];
initial begin
  for (n = 0; n < 1024; n = n + 1) begin
  	mem[n].v = INV;
    mem[n].insadr = RSTIP;
  end
end

always_ff @(posedge clk)
begin
  if (wr) #1 mem[pc[10:1]].tgtadr <= wtgt;
  if (wr) #1 mem[pc[10:1]].insadr <= wip;
  if (wr) #1 mem[pc[10:1]].v <= takb;
end

always_ff @(posedge rclk)
  #1 radr <= pc[10:1];
assign hit = mem[radr].insadr==ip && mem[radr].v;
assign btgt = hit ? mem[radr].tgtadr : nip;

endmodule
