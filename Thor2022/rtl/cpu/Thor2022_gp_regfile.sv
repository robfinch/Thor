// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_gp_regfile.sv
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

import const_pkg::*;
import Thor2022_pkg::*;

module Thor2022_gp_regfile(clk, wr0, wr1, wa0, wa1, i0, i1,
	ip0, ip1,
	ra0, ra1, ra2, ra3, ra4, ra5, o0, o1, o2, o3, o4, o5);
input clk;
input wr0;
input wr1;
input [4:0] wa0;
input [4:0] wa1;
input Value i0;
input Value i1;
input CodeAddress ip0;
input CodeAddress ip1;
input [4:0] ra0;
input [4:0] ra1;
input [4:0] ra2;
input [4:0] ra3;
input [4:0] ra4;
input [4:0] ra5;
output Value o0;
output Value o1;
output Value o2;
output Value o3;
output Value o4;
output Value o5;

integer n;
reg [31:0] way;
Value regfileA [0:31];
Value regfileB [0:31];

initial begin
	for (n = 0; n < 32; n = n + 1) begin
		regfileA[n] = 'd0;
		regfileB[n] = 'd0;
	end
end

always_ff @(posedge clk)
if (wr0 & wr1) begin
	if (wa0==wa1) begin
		way[wa0] <= 1'b1;
		regfileB[wa1] <= i1;
	end
	else begin
		way[wa0] <= 1'b0;
		way[wa1] <= 1'b1;
		regfileA[wa0] <= i0;
		regfileB[wa1] <= i1;
	end
end
else if (wr0) begin
	way[wa0] <= 1'b0;
	regfileA[wa0] <= i0;
end
else if (wr1) begin
	way[wa1] <= 1'b1;
	regfileB[wa1] <= i1;
end

always_comb
	o0 = ra0=='d0 ? 'd0 : ra0==wa1 ? i1 : ra0==wa0 ? i0 : way[ra0] ? regfileB[ra0] : regfileA[ra0];
always_comb
	o1 = ra1=='d0 ? 'd0 : ra1==wa1 ? i1 : ra1==wa0 ? i0 : way[ra1] ? regfileB[ra1] : regfileA[ra1];
always_comb
	o2 = ra2=='d0 ? 'd0 : ra2==5'd31 ? ip0 : ra2==wa1 ? i1 : ra2==wa0 ? i0 : way[ra2] ? regfileB[ra2] : regfileA[ra2];
always_comb
	o3 = ra3=='d0 ? 'd0 : ra3==wa1 ? i1 : ra3==wa0 ? i0 : way[ra3] ? regfileB[ra3] : regfileA[ra3];
always_comb
	o4 = ra4=='d0 ? 'd0 : ra4==wa1 ? i1 : ra4==wa0 ? i0 : way[ra4] ? regfileB[ra4] : regfileA[ra4];
always_comb
	o5 = ra5=='d0 ? 'd0 : ra5==5'd31 ? ip1 : ra5==wa1 ? i1 : ra5==wa0 ? i0 : way[ra5] ? regfileB[ra5] : regfileA[ra5];

endmodule
