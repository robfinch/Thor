// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_cmp.sv
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

module Thor2023_cmp(a, b, o);
parameter WID=96;
input [WID-1:0] a;
input [WID-1:0] b;
output reg [31:0] o;

wire [15:0] fcmpo;
wire nan;

generate begin : gFPCmp
	case(WID)
	PRC32:
		fpCompare32 ufpc1
		(
			.a(a),
			.b(b),
			.o(fcmpo),
			.inf(),
			.nan(nan),
			.snan()
		);
	PRC64:
		fpCompare64 ufpc1
		(
			.a(a),
			.b(b),
			.o(fcmpo),
			.inf(),
			.nan(nan),
			.snan()
		);
	default:
		fpCompare96 ufpc1
		(
			.a(a),
			.b(b),
			.o(fcmpo),
			.inf(),
			.nan(nan),
			.snan()
		);
	endcase
end
endgenerate

always_comb
begin
	o[0] = a==b;
	o[1] = $signed(a) < $signed(b);
	o[2] = $signed(a) <= $signed(b);
	o[3] = a < b;
	o[4] = a <= b;
	o[5] = a[0];
	o[6] = a=='d0;
	o[7] = a[95];
	o[8] = a!=b;
	o[9] = $signed(a) >= $signed(b);
	o[10] = $signed(a) > $signed(b);
	o[11] = a >= b;
	o[12] = a > b;
	o[13] = ~a[0];
	o[14] = a != 'd0;
	o[15] = 1'b1;
	
	o[16] = !nan & fcmpo[0];
	o[17] = fcmpo[8];
	o[18] = !nan & !fcmpo[0] & !fcmpo[1];
	o[19] = nan | (!fcmpo[0] & !fcmpo[1]);
	o[20] = fcmpo[0] | (!nan & !fcmpo[1]);
	o[21] = nan | (!fcmpo[1] | fcmpo[0]);
	o[22] = fcmpo[1] & (!nan & !fcmpo[0]);
	o[23] = nan | (!fcmpo[0] & fcmpo[1]);
	o[24] = fcmpo[0] | (!nan & fcmpo[1]);
	o[25] = nan | (fcmpo[0] | fcmpo[1]);
	o[26] = !nan & !fcmpo[0];
	o[27] = nan & !fcmpo[0];
	o[28] = !nan;
	o[29] = nan;
	
	o[30] = 1'b0;
	o[31] = 1'b0;
end

endmodule
