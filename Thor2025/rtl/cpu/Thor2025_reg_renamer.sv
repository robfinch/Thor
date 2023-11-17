// ============================================================================
//        __
//   \\__/ o\    (C) 2014-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// Allocate up to three registers per clock.
// Free up to 19 registers per clock.
// We need to be able to free many more registers than are allocated in the 
// event of a pipeline flush. Normally up to three register values will be
// committed to the register file.
// ============================================================================
//
module Thor2025_reg_renamer(rst,clk,tags2free,freevals,alloc0,alloc1,alloc2,wo0,wo1,wo2);
parameter PREG = 96;
parameter NFTAGS = 19;
input rst;
input clk;
input [6:0] tags2free [NFTAGS-1:0];		// register tags to free
input [NFTAGS-1:0] freevals;					// bitmnask indicating which tags to free
input alloc0;					// allocate target register 0
input alloc1;
input alloc2;
output reg [6:0] wo0;	// target register tag
output reg [6:0] wo1;
output reg [6:0] wo2;

integer n;
reg [PREG-1:0] avail, availy;
reg [PREG-1:0] availx [0:NFTAGS-1];

wire [6:0] o0, o1, o2;
wire [95:0] unavail0 = 96'd1 << o0;
wire [95:0] unavail1 = 96'd1 << o1;
wire [95:0] unavail2 = 96'd1 << o2;

genvar g;
generate begin : gAvailx
	for (g = 0; g < NFTAGS; g = g + 1) begin
		always_comb
			availx[g] <= {95'd0,freevals[g]} << tags2free[g];
	end
end
endgenerate

ffo96 uffo1(avail, o0);
ffo96 uffo2(avail & ~unavail0, o1);
ffo96 uffo3(avail & ~unavail0 & ~unavail1, o2);

always_comb
begin
	availy = 'd0;
	for (n = 0; n < NFTAGS; n = n + 1)
		availy = availy | availx[n];
end

always_ff @(posedge clk)
if (rst) begin
	avail <= {PREG{1'b1}};
	wo0 <= 'd0;
	wo1 <= 'd0;
	wo2 <= 'd0;
end
else begin
	case({alloc2,alloc1,alloc0})
	3'b111:
		begin
			wo0 <= o0;
			wo1 <= o1;
			wo2 <= o2;
			avail <= avail & ~(unavail2|unavail1|unavail0) | availy;
		end
	3'b110:
		begin
			wo1 <= o0;
			wo2 <= o1;
			avail <= avail & ~(unavail1|unavail0) | availy;
		end
	3'b101:
		begin
			wo0 <= o0;
			wo2 <= o1;
			avail <= avail & ~(unavail1|unavail0) | availy;
		end
	3'b100:
		begin
			wo2 <= o0;
			avail <= avail & ~unavail0 | availy;
		end
	3'b011:
		begin
			wo0 <= o0;
			wo1 <= o1;
			avail <= avail & ~(unavail1|unavail0) | availy;
		end
	3'b010:
		begin
			wo1 <= o0;
			avail <= avail & ~unavail0 | availy;
		end
	3'b001:
		begin
			wo0 <= o0;
			avail <= avail & ~unavail0 | availy;
		end
	3'b000:
	 	avail <= avail | availy;
	endcase
end

endmodule

