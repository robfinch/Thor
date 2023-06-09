// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_ifetch.sv
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

import Thor2024pkg::*;

module Thor2024_rsb(rst, clk, pop, push, pc, o);
input rst;
input clk;
input pop;
input push;
input pc_address_t pc;
output pc_address_t o;

integer n;
pc_address_t [63:0] rsb_stack;
reg [5:0] rsb_sp;
reg push1, pop1;

always_ff @(posedge clk, posedge rst)
if (rst) begin
	rsb_sp <= 'd0;
	for (n = 0; n < 32; n = n + 1)
		rsb_stack[n] <= 44'hFFFD0000000;
end
else begin
	push1 <= push;
	pop1 <= pop;
	if ((pop & ~pop1) & (push & ~push1))
		;
	else if (pop & ~pop1)
		rsb_sp <= rsb_sp + 2'd1;
	else if (push & ~push1)
		rsb_sp <= rsb_sp - 2'd1;
	if (push & ~push1)
		rsb_stack[rsb_sp - 2'd1] <= pc;
end

assign o = rsb_stack[rsb_sp];

endmodule
