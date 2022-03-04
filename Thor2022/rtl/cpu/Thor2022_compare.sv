// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2021_Compare.sv
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

import Thor2022_pkg::*;

module Thor2022_compare(a, b, o);
input [127:0] a;
input [127:0] b;
output reg [127:0] o;

wire [11:0] dfco;
DFPCompare128 udfc1 (
	.a(a),
	.b(b),
	.o(dfco)
);

always_comb
begin
	o = 'd0;
	o[0] = a==b;
	o[1] = $signed(a) < $signed(b);
	o[2] = $signed(a) < $signed(b) || a==b;
	o[5] = a < b;
	o[6] = a <= b;
	o[8] = a != b;
	o[9] = $signed(a) >= $signed(b);
	o[10] = $signed(a) > $signed(b);
	o[32] = dfco[0];	// equal
	o[33] = dfco[1];	// less than
	o[34] = dfco[2];	// less than or equal
	o[35] = dfco[3];	// magnitude less than
	o[36] = dfco[4];	// unordered
	o[37] = dfco[5];	// not equal
	o[38] = dfco[6];	// not less than (greater than or equal)
	o[39] = dfco[7];	// not less than or equal (greater than)
	o[40] = dfco[8];	// not magnitude less than (magnitude greater than or equal)
	o[41] = dfco[9];	// not unordered (ordered)
end

endmodule
