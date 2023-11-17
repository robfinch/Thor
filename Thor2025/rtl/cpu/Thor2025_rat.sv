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
//
// Status: Untested, unused
//
// Thor Register Alias Table
//
// ToDo: add a valid bit
// ============================================================================
//
module Thor2025_rat(rst, clk, nq, flush, wr0, wr1, wr2,
	rn,
	rrn,
	vn,
	wra, wrra, wrb, wrrb, wrc, wrrc, cmtav, cmtbv, cmtcv,
	cmtaa, cmtba, cmtca, cmtap, cmtbp, cmtcp, freea, freeb, freec);
parameter NCHECK = 2;
parameter NPORT = 28;
input rst;
input clk;
input nq;			// enqueue instruction
input flush;	// pipeline flush
input wr0;
input wr1;
input wr2;
input [5:0] wra;	// architectural register
input [5:0] wrb;
input [5:0] wrc;
input [6:0] wrra;	// physical register
input [6:0] wrrb;
input [6:0] wrrc;
input cmtav;							// commit valid
input cmtbv;
input cmtcv;
input [5:0] cmtaa;				// architectural register being committed
input [5:0] cmtba;
input [5:0] cmtca;
input [6:0] cmtap;				// physical register to commit
input [6:0] cmtbp;
input [6:0] cmtcp;
input [5:0] rn [NPORT-1:0];		// architectural register
output reg [6:0] rrn [NPORT-1:0];	// physical register
output reg [NPORT-1:0] vn;			// translation is valid for register
output reg [6:0] freea;	// previous register to free
output reg [6:0] freeb;
output reg [6:0] freec;

integer n,m;
reg [7:0] map [NCHECK-1:0][63:0];

genvar g;

generate begin : gRRN
	for (g = 0; g < NPORT; g = g + 1) begin
		always_comb
			rrn[g] = map[1][rn[g]][6:0];
		always_comb
			vn[g] = map[1][rn[g]][7];
	end
end
endgenerate

always_ff @(posedge clk)
if (rst) begin
	for (m = 0; m < NCHECK; m = m + 1)
		for (n = 0; n < 64; n = n + 1) begin
			map[m][n] <= 0;
		end
	freea <= 'd0;
	freeb <= 'd0;
	freec <= 'd0;
end
else begin
	// Copy the comitted rename map to a speculative one, as for when a branch miss occurs.
	if (flush) begin
		for (n = 0; n < 64; n = n + 1) begin
			map[1][n] <= map[0][n];
		end
	end
	// Place physical register in committed map.
	// Free previous physical register associated with architectural one.
	if (cmtav) begin
		map[0][cmtaa] <= cmtap;
		freea <= map[0][cmtaa];
	end
	else
	 	freea <= cmtap;
	if (cmtbv) begin
		map[0][cmtba] <= cmtbp;
		freeb <= map[0][cmtba];
	end
	else
	 	freeb <= cmtbp;
	if (cmtcv) begin
		map[0][cmtca] <= cmtcp;
		freec <= map[0][cmtca];
	end
	else
	 	freec <= cmtcp;
	if (nq) begin
		/*
		case({wr2,wr1,wr0})
		3'b111:
			if (wra==wrb && wra==wrc) begin
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else if (wra==wrb) begin
				map[ndx+1][wrb] <= {1'b1,wrrb};
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else if (wra==wrc) begin
				map[ndx+1][wrb] <= {1'b1,wrrb};
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else if (wrb==wrc) begin
				map[ndx+1][wra] <= {1'b1,wrra};
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else begin
				map[ndx+1][wra] <= {1'b1,wrra};
				map[ndx+1][wrb] <= {1'b1,wrrb};
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
		3'b110:
			if (wrb==wrc) begin
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else begin
				map[ndx+1][wrb] <= {1'b1,wrrb};
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
		3'b101:
			if (wra==wrc) begin
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else begin
				map[ndx+1][wra] <= {1'b1,wrra};
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
		3'b100:	
			begin
				map[ndx+1][wrc] <= {1'b1,wrrc};
			end
		*/
		case({1'b0,wr1,wr0})
		3'b011:
			if (wra==wrb) begin
				map[1][wrb] <= {1'b1,wrrb};
			end
			else begin
				map[1][wra] <= {1'b1,wrra};
				map[1][wrb] <= {1'b1,wrrb};
			end
		3'b010:	
			begin
				map[1][wrb] <= {1'b1,wrrb};
			end
		3'b001:	
			begin
				map[1][wra] <= {1'b1,wrra};
			end
		3'b000:	;
		endcase
//		ndx <= ndx + 1;						// make the new map the current one for mappings
	end
end

endmodule
