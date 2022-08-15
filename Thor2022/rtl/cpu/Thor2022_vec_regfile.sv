// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_vec_regfile.sv
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

module Thor2022_vec_regfile(clk, wr0, wr1, wa0, wa1, m0, m1, z0, z1, i0, i1,
	ra0, ra1, ra2, ra3, ra4, ra5, ra6, ra7, o0, o1, o2, o3, o4, o5, o6, o7);
input clk;
input wr0;
input wr1;
input [4:0] wa0;
input [4:0] wa1;
input [63:0] m0;
input [63:0] m1;
input z0;
input z1;
input VecValue i0;
input VecValue i1;
input [4:0] ra0;
input [4:0] ra1;
input [4:0] ra2;
input [4:0] ra3;
input [4:0] ra4;
input [4:0] ra5;
input [4:0] ra6;
input [4:0] ra7;
output VecValue o0;
output VecValue o1;
output VecValue o2;
output VecValue o3;
output VecValue o4;
output VecValue o5;
output VecValue o6;
output VecValue o7;

integer n, k;
reg [31:0] way [0:NLANES-1];
Value regfileA [0:NLANES-1][0:31];
Value regfileB [0:NLANES-1][0:31];

initial begin
	for (k = 0; k < NLANES; k = k + 1) begin
		way[k] = 32'd0;
		for (n = 0; n < 32; n = n + 1) begin
			regfileA[k][n] = 'd0;
			regfileB[k][n] = 'd0;
		end
	end
end

genvar g;
generate
for (g = 0; g < NLANES; g = g + 1)
always_ff @(posedge clk)
if (wr0 & wr1) begin
	if (wa0==wa1) begin
		if (m1[g]) begin
			way[g][wa1] <= 1'b1;
			regfileB[g][wa1] <= i1[g];
		end
		else if (z1) begin
			way[g][wa1] <= 1'b1;
			regfileB[g][wa1] <= 64'd0;
		end
		else if (m0[g]) begin
			way[g][wa0] <= 1'b0;
			regfileA[g][wa0] <= i0[g];
		end
		else if (z0) begin
			way[g][wa0] <= 1'b0;
			regfileA[g][wa0] <= 64'd0;
		end
	end
	else begin
		if (m0[g]) begin
			way[g][wa0] <= 1'b0;
			regfileA[g][wa0] <= i0[g];
		end
		else if (z0) begin
			way[g][wa0] <= 1'b0;
			regfileA[g][wa0] <= 64'd0;
		end
		if (m1[g]) begin
			way[g][wa1] <= 1'b1;
			regfileB[g][wa1] <= i1[g];
		end
		else if (z1) begin
			way[g][wa1] <= 1'b1;
			regfileB[g][wa1] <= 64'd0;
		end
	end
end
else if (wr0) begin
	if (m0[g]) begin
		way[g][wa0] <= 1'b0;
		regfileA[g][wa0] <= i0[g];
	end
	else if (z0) begin
		way[g][wa0] <= 1'b0;
		regfileA[g][wa0] <= 64'd0;
	end
end
else if (wr1) begin
	if (m1[g]) begin
		way[g][wa1] <= 1'b1;
		regfileB[g][wa1] <= i1[g];
	end
	else if (z1) begin
		way[g][wa1] <= 1'b1;
		regfileB[g][wa1] <= 64'd0;
	end
end
endgenerate

genvar j;
generate
for (j = 0; j < NLANES; j = j + 1) begin
always_comb
	o0[j] = ra0=='d0 ? 64'd0 :
					ra0==wa1 && wr1 && m1[j] ? i1[j] : ra0==wa1 && wr1 && z1 ? 64'd0 :
					ra0==wa0 && wr0 && m0[j] ? i0[j] : ra0==wa0 && wr0 && z0 ? 64'd0 :
					way[j][ra0] ? regfileB[j][ra0] : regfileA[j][ra0];
always_comb
	o1[j] = ra1=='d0 ? 64'd0 :
					ra1==wa1 && wr1 && m1[j] ? i1[j] : ra1==wa1 && wr1 && z1 ? 64'd0 :
					ra1==wa0 && wr0 && m0[j] ? i0[j] : ra1==wa0 && wr0 && z0 ? 64'd0 :
					way[j][ra1] ? regfileB[j][ra1] : regfileA[j][ra1];
always_comb
	o2[j] = ra2=='d0 ? 64'd0 :
					ra2==wa1 && wr1 && m1[j] ? i1[j] : ra2==wa1 && wr1 && z1 ? 64'd0 :
					ra2==wa0 && wr0 && m0[j] ? i0[j] : ra2==wa0 && wr0 && z0 ? 64'd0 :
					way[j][ra2] ? regfileB[j][ra2] : regfileA[j][ra2];
always_comb
	o3[j] = ra3=='d0 ? 64'd0 :
					ra3==wa1 && wr1 && m1[j] ? i1[j] : ra3==wa1 && wr1 && z1 ? 64'd0 :
					ra3==wa0 && wr0 && m0[j] ? i0[j] : ra3==wa0 && wr0 && z0 ? 64'd0 :
					way[j][ra3] ? regfileB[j][ra3] : regfileA[j][ra3];
always_comb
	o4[j] = ra4=='d0 ? 64'd0 :
					ra4==wa1 && wr1 && m1[j] ? i1[j] : ra4==wa1 && wr1 && z1 ? 64'd0 :
					ra4==wa0 && wr0 && m0[j] ? i0[j] : ra4==wa0 && wr0 && z0 ? 64'd0 :
					way[j][ra4] ? regfileB[j][ra4] : regfileA[j][ra4];
always_comb
	o5[j] = ra5=='d0 ? 64'd0 :
					ra5==wa1 && wr1 && m1[j] ? i1[j] : ra5==wa1 && wr1 && z1 ? 64'd0 :
					ra5==wa0 && wr0 && m0[j] ? i0[j] : ra5==wa0 && wr0 && z0 ? 64'd0 :
					way[j][ra5] ? regfileB[j][ra5] : regfileA[j][ra5];
always_comb
	o6[j] = ra6=='d0 ? 64'd0 :
					ra6==wa1 && wr1 && m1[j] ? i1[j] : ra6==wa1 && wr1 && z1 ? 64'd0 :
					ra6==wa0 && wr0 && m0[j] ? i0[j] : ra6==wa0 && wr0 && z0 ? 64'd0 :
					way[j][ra6] ? regfileB[j][ra6] : regfileA[j][ra6];
always_comb
	o7[j] = ra7=='d0 ? 64'd0 :
					ra7==wa1 && wr1 && m1[j] ? i1[j] : ra7==wa1 && wr1 && z1 ? 64'd0 :
					ra7==wa0 && wr0 && m0[j] ? i0[j] : ra7==wa0 && wr0 && z0 ? 64'd0 :
					way[j][ra7] ? regfileB[j][ra7] : regfileA[j][ra7];
end
endgenerate

endmodule
