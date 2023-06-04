// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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

module Thor2024_blend(a, c0, c1, o);
input value_t a;
input value_t c0;
input value_t c1;
output value_t o;

typedef struct packed {
	logic [1:0] pad;
	logic [9:0] r;
	logic [9:0] g;
	logic [9:0] b;
} RGB;

reg [20:0] r0, g0, b0;
reg [20:0] r1, g1, b1;
RGB argb0, argb1;
RGB c0rgb0, c0rgb1;
RGB c1rgb0, c1rgb1;

assign argb0 = a[31:0];
assign argb1 = a[63:32];
assign c0rgb0 = c0[31:0];
assign c0rgb1 = c0[63:32];
assign c1rgb0 = c1[31:0];
assign c1rgb1 = c1[63:32];

always_comb
begin
	r0 = {argb0.r,1'b0} * c0rgb0.r + argb0.r * {~c1rgb0.r,1'b0};
	g0 = {argb0.g,1'b0} * c0rgb0.g + argb0.g * {~c1rgb0.g,1'b0};
	b0 = {argb0.b,1'b0} * c0rgb0.b + argb0.b * {~c1rgb0.b,1'b0};
	r1 = {argb1.r,1'b0} * c0rgb1.r + argb1.r * {~c1rgb1.r,1'b0};
	g1 = {argb1.g,1'b0} * c0rgb1.g + argb1.g * {~c1rgb1.g,1'b0};
	b1 = {argb1.b,1'b0} * c0rgb1.b + argb1.b * {~c1rgb1.b,1'b0};
	// Saturate to white
	r0 = r0[20] ? 10'h3FF : r0[19:10];
	g0 = g0[20] ? 10'h3FF : g0[19:10];
	b0 = b0[20] ? 10'h3FF : b0[19:10];
	r1 = r1[20] ? 10'h3FF : r1[19:10];
	g1 = g1[20] ? 10'h3FF : g1[19:10];
	b1 = b1[20] ? 10'h3FF : b1[19:10];
	
	o = 'd0;
	o[29: 0] = {r0[9:0],g0[9:0],b0[9:0]};
	o[61:32] = {r1[9:0],g1[9:0],b1[9:0]};
end

endmodule
