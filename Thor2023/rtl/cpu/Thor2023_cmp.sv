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

module Thor2023_cmp(flt, a, b, o);
parameter WID=128;
input flt;
input [WID-1:0] a;
input [WID-1:0] b;
output reg [15:0] o;

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
		fpCompare128 ufpc1
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
	if (flt) begin
		o[0] = !nan & fcmpo[0];
		o[1] = fcmpo[8];
		o[2] = !nan & !fcmpo[0] & !fcmpo[1];
		o[3] = nan | (!fcmpo[0] & !fcmpo[1]);
		o[4] = fcmpo[0] | (!nan & !fcmpo[1]);
		o[5] = nan | (!fcmpo[1] | fcmpo[0]);
		o[6] = fcmpo[1] & (!nan & !fcmpo[0]);
		o[7] = nan | (!fcmpo[0] & fcmpo[1]);
		o[8] = fcmpo[0] | (!nan & fcmpo[1]);
		o[9] = nan | (fcmpo[0] | fcmpo[1]);
		o[10] = !nan & !fcmpo[0];
		o[11] = nan & !fcmpo[0];
		o[12] = !nan;
		o[13] = nan;
		
		o[14] = 1'b0;
		o[15] = 1'b0;
	end
	else begin
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
	end
end

endmodule
