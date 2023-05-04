// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_vec_add.sv
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

module Thor2023_vec_add(ir, Rt, a, b, o);
parameter WID=512;
input instruction_t ir;
input regspec_t Rt;
input [WID-1:0] a;
input [WID-1:0] b;
output reg [WID-1:0] o;

genvar g;

reg [WID-1:0] s8, s16, s32, s64, s128;

generate begin : gVecAdd8
	for (g = 0; g < WID/8; g = g + 1)
		always_comb
			s8[g*8+7:g*8] <= Rt.sign ? -(a[g*8+7:g*8] + b[g*8+7:g*8]) : a[g*8+7:g*8] + b[g*8+7:g*8];
end
endgenerate

generate begin : gVecAdd16
	for (g = 0; g < WID/16; g = g + 1)
		always_comb
			s16[g*16+15:g*16] <= Rt.sign ? -(a[g*16+15:g*16] + b[g*16+15:g*16]) : a[g*16+15:g*16] + b[g*16+15:g*16];
end
endgenerate

generate begin : gVecAdd32
	for (g = 0; g < WID/32; g = g + 1)
		always_comb
			s32[g*32+31:g*32] <= Rt.sign ? -(a[g*32+31:g*32] + b[g*32+31:g*32]) : a[g*32+31:g*32] + b[g*32+31:g*32];
end
endgenerate

generate begin : gVecAdd64
	for (g = 0; g < WID/64; g = g + 1)
		always_comb
			s64[g*64+63:g*64] <= Rt.sign ? -(a[g*64+63:g*64] + b[g*64+63:g*64]) : a[g*64+63:g*64] + b[g*64+63:g*64];
end
endgenerate

generate begin : gVecAdd128
	for (g = 0; g < WID/128; g = g + 1)
		always_comb
			s128[g*128+127:g*128] <= Rt.sign ? -(a[g*128+127:g*128] + b[g*128+127:g*128]) : a[g*128+127:g*128] + b[g*128+127:g*128];
end
endgenerate

always_comb
	case(ir.any.sz)
	PRC8:	o = s8;
	PRC16:	o = s16;
	PRC32:	o = s32;
	PRC64:	o = s64;
	default:	o = s128;
	endcase

endmodule
