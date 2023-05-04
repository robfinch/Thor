// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_vec_regfile.sv
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

module Thor2023_vec_regfile(clk, wr, sel, wa, i, ra0, ra1, ra2, o0, o1, o2);
parameter WID=128;
localparam SELWID = WID/8;
input clk;
input wr;
input [SELWID-1:0] sel;
input [5:0] wa;
input [WID-1:0] i;
input [5:0] ra0;
input [5:0] ra1;
input [5:0] ra2;
output reg [WID-1:0] o0;
output reg [WID-1:0] o1;
output reg [WID-1:0] o2;

genvar g;

(* ram_style="distributed" *)
reg [WID-1:0] regs [0:63];
reg [WID-1:0] o01, o11, o21;

generate begin : gRegsUpdate
	for (g = 0; g < SELWID; g = g + 1) begin : gFor
		always_ff @(posedge clk)
			if (wr) 
				regs[wa][g*8+7:g*8] <= i[g*8+7:g*8];
	end
end
endgenerate

generate begin : gRegsRead1
	for (g = 0; g < SELWID; g = g + 1) begin : gFor
		always_comb
			o01[g*8+7:g*8] <= regs[ra0][g*8+7:g*8];
		always_comb
			o11[g*8+7:g*8] <= regs[ra1][g*8+7:g*8];
		always_comb
			o21[g*8+7:g*8] <= regs[ra2][g*8+7:g*8];
	end
end
endgenerate

generate begin : gRegsRead
	for (g = 0; g < SELWID; g = g + 1) begin : gFor
		always_comb
			o0[g*8+7:g*8] <= wa == ra0 && sel[g] ? i[g*8+7:g*8] : o01[g*8+7:g*8];
		always_comb
			o1[g*8+7:g*8] <= wa == ra1 && sel[g] ? i[g*8+7:g*8] : o11[g*8+7:g*8];
		always_comb
			o2[g*8+7:g*8] <= wa == ra2 && sel[g] ? i[g*8+7:g*8] : o21[g*8+7:g*8];
	end
end
endgenerate

endmodule

