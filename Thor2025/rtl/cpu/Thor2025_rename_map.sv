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
// Thor Register Rename Map
//
//     The register rename map is really an array of maps to allow backout
// capability for branch misses and exceptions. Whenever a new map entry is
// added, the entire current map is copied to a new map, and the new map 
// entries inserted. The new map is then made the current map.
//
// Backout:
//     The map number used to map rename registers is stored in the ROB when
// an instruction is enqueued. When a backout occurs, the current rename map
// number is reset to the one from the ROB containing the branch.
//
// ToDo: add a valid bit
// ============================================================================
//
module Thor2025_rename_map(rst, clk, nq, cp, ndx, wr0, wr1, wr2,
	ra, rb, rc, rd,
	rra, rrb, rrc, rrd,
	va,vb,vc,vd,
	wra, wrra, wrb, wrrb, wrc, wrrc,
	cmta, cmtb, cmtc);
parameter NCHECK = 8;
input rst;
input clk;
input nq;			// enqueue instruction
input cp;			// checkpoint
input [$clog2(NCHECK)-1:0] ndx;	// index to active map
input wr0;
input wr1;
input wr2;
input [5:0] wra;	// architectural register
input [5:0] wrb;
input [5:0] wrc;
input [6:0] wrra;	// physical register
input [6:0] wrrb;
input [6:0] wrrc;
input [5:0] cmtaa;				// architectural register being committed
input [5:0] cmtba;
input [5:0] cmtca;
input [6:0] cmtap;				// physical register to commit
input [6:0] cmtbp;
input [6:0] cmtcp;
input [5:0] ra [4:0];		// architectural register
input [5:0] rb [4:0];
input [5:0] rc [4:0];
input [5:0] rd [4:0];
output reg [6:0] rra [4:0];	// physical register
output reg [6:0] rrb [4:0];	// physical register
output reg [6:0] rrc [4:0];	// physical register
output reg [6:0] rrd [4:0];	// physical register
output reg [4:0] va;			// translation is valid for register
output reg [4:0] vb;
output reg [4:0] vc;
output reg [4:0] vd;
output reg [6:0] freea;	// previous register to free
output reg [6:0] freeb;
output reg [6:0] freec;

integer n,m;
`ifdef LVT
reg [7:0] map0 [7:0][63:0];
reg [7:0] map1 [7:0][63:0];
reg [7:0] map2 [7:0][63:0];
reg [1:0] lvt [7:0][63:0];

genvar g;

generate begin : gRRA
	for (g = 0; g < 4; g = g + 1) begin
		always_comb
			case(lvt[ndx][ra[g]])
			2'd0:	rra[g] = map0[ndx][ra[g]][6:0];
			2'd1:	rra[g] = map1[ndx][ra[g]][6:0];
			2'd2:	rra[g] = map2[ndx][ra[g]][6:0];
			default:	rra[g] = 'd0;
			endcase
		always_comb
			case(lvt[ndx][ra[g]])
			2'd0:	va[g] = map0[ndx][ra[g]][7];
			2'd1:	va[g] = map1[ndx][ra[g]][7];
			2'd2:	va[g] = map2[ndx][ra[g]][7];
			default:	va[g] = 'd0;
			endcase
		always_comb
			case(lvt[ndx][rb[g]])
			2'd0:	rrb[g] = map0[ndx][rb[g]][6:0];
			2'd1:	rrb[g] = map1[ndx][rb[g]][6:0];
			2'd2:	rrb[g] = map2[ndx][rb[g]][6:0];
			default:	rrb[g] = 'd0;
			endcase
		always_comb
			case(lvt[ndx][rb[g]])
			2'd0:	vb[g] = map0[ndx][rb[g]][7];
			2'd1:	vb[g] = map1[ndx][rb[g]][7];
			2'd2:	vb[g] = map2[ndx][rb[g]][7];
			default:	vb[g] = 'd0;
			endcase
		always_comb
			case(lvt[ndx][rc[g]])
			2'd0:	rrc[g] = map0[ndx][rc[g]][6:0];
			2'd1:	rrc[g] = map1[ndx][rc[g]][6:0];
			2'd2:	rrc[g] = map2[ndx][rc[g]][6:0];
			default:	rrc[g] = 'd0;
			endcase
		always_comb
			case(lvt[ndx][rc[g]])
			2'd0:	vc[g] = map0[ndx][rc[g]][7];
			2'd1:	vc[g] = map1[ndx][rc[g]][7];
			2'd2:	vc[g] = map2[ndx][rc[g]][7];
			default:	vc[g] = 'd0;
			endcase
		always_comb
			case(lvt[ndx][rd[g]])
			2'd0:	rrd[g] = map0[ndx][rd[g]][6:0];
			2'd1:	rrd[g] = map1[ndx][rd[g]][6:0];
			2'd2:	rrd[g] = map2[ndx][rd[g]][6:0];
			default:	rrd[g] = 'd0;
			endcase
		always_comb
			case(lvt[ndx][rd[g]])
			2'd0:	vd[g] = map0[ndx][rd[g]][7];
			2'd1:	vd[g] = map1[ndx][rd[g]][7];
			2'd2:	vd[g] = map2[ndx][rd[g]][7];
			default:	vd[g] = 'd0;
			endcase
	end
end
endgenerate

always_ff @(posedge clk)
if (rst) begin
	for (m = 0; m < 8; m = m + 1)
		for (n = 0; n < 64; n = n + 1) begin
			map0[m][n] <= 0;
			map1[m][n] <= 0;
			map2[m][n] <= 0;
			lvt[m][n] <= 0;
		end
end
else begin
	if (cp) begin
		for (n = 0; n < 64; n = n + 1) begin		// copy the current rename map to a new one
			map0[ndx+1][n] <= map0[ndx][n];
			map1[ndx+1][n] <= map1[ndx][n];
			map2[ndx+1][n] <= map2[ndx][n];
			lvt[ndx+1][n] <= lvt[ndx][n];
		end
	end
	if (nq) begin
		case({wr2,wr1,wr0})
		3'b111:
			if (wra==wrb && wra==wrc) begin
				lvt[ndx+1][wrc] <= 2'd2;
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else if (wra==wrb) begin
				lvt[ndx+1][wrb] <= 2'd1;
				lvt[ndx+1][wrc] <= 2'd2;
				map1[ndx+1][wrb] <= {1'b1,wrrb};
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else if (wra==wrc) begin
				lvt[ndx+1][wrb] <= 2'd1;
				lvt[ndx+1][wrc] <= 2'd2;
				map1[ndx+1][wrb] <= {1'b1,wrrb};
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else if (wrb==wrc) begin
				lvt[ndx+1][wra] <= 2'd0;
				lvt[ndx+1][wrc] <= 2'd2;
				map0[ndx+1][wra] <= {1'b1,wrra};
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else begin
				lvt[ndx+1][wra] <= 2'd0;
				lvt[ndx+1][wrb] <= 2'd1;
				lvt[ndx+1][wrc] <= 2'd2;
				map0[ndx+1][wra] <= {1'b1,wrra};
				map1[ndx+1][wrb] <= {1'b1,wrrb};
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
		3'b110:
			if (wrb==wrc) begin
				lvt[ndx+1][wrc] <= 2'd2;
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else begin
				lvt[ndx+1][wrb] <= 2'd1;
				lvt[ndx+1][wrc] <= 2'd2;
				map1[ndx+1][wrb] <= {1'b1,wrrb};
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
		3'b101:
			if (wra==wrc) begin
				lvt[ndx+1][wrc] <= 2'd2;
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
			else begin
				lvt[ndx+1][wra] <= 2'd0;
				lvt[ndx+1][wrc] <= 2'd2;
				map0[ndx+1][wra] <= {1'b1,wrra};
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
		3'b100:	
			begin
				lvt[ndx+1][wrc] <= 2'd2;
				map2[ndx+1][wrc] <= {1'b1,wrrc};
			end
		3'b011:
			if (wra==wrb) begin
				lvt[ndx+1][wrb] <= 2'd1;
				map1[ndx+1][wrb] <= {1'b1,wrrb};
			end
			else begin
				lvt[ndx+1][wra] <= 2'd0;
				lvt[ndx+1][wrb] <= 2'd1;
				map0[ndx+1][wra] <= {1'b1,wrra};
				map1[ndx+1][wrb] <= {1'b1,wrrb};
			end
		3'b010:	
			begin
				lvt[ndx+1][wrb] <= 2'd1;
				map1[ndx+1][wrb] <= {1'b1,wrrb};
			end
		3'b001:	
			begin
				lvt[ndx+1][wra] <= 2'd0;
				map0[ndx+1][wra] <= {1'b1,wrra};
			end
		3'b000:	;
		endcase
//		ndx <= ndx + 1;						// make the new map the current one for mappings
	end
end
`else
reg [7:0] map [NCHECK-1:0][63:0];

genvar g;

generate begin : gRRA
	for (g = 0; g < 5; g = g + 1) begin
		always_comb
			rra[g] = map[ndx][ra[g]][6:0];
		always_comb
			va[g] = map[ndx][ra[g]][7];
		always_comb
			rrb[g] = map[ndx][rb[g]][6:0];
		always_comb
			vb[g] = map[ndx][rb[g]][7];
		always_comb
			rrc[g] = map[ndx][rc[g]][6:0];
		always_comb
			vc[g] = map[ndx][rc[g]][7];
		always_comb
			rrd[g] = map[ndx][rd[g]][6:0];
		always_comb
			vd[g] = map[ndx][rd[g]][7];
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
	if (cp) begin
		for (n = 0; n < 64; n = n + 1) begin		// copy the current rename map to a new one
			map[ndx+1][n] <= map[ndx][n];
		end
		map[ndx+1][cmtaa] <= cmtap;
		map[ndx+1][cmtba] <= cmtbp;
		map[ndx+1][cmtca] <= cmtcp;
	end
	else begin
		map[ndx][cmtaa] <= cmtap;
		map[ndx][cmtba] <= cmtbp;
		map[ndx][cmtca] <= cmtcp;
	end
	freea <= map[ndx][cmtaa];
	freeb <= map[ndx][cmtba];
	freec <= map[ndx][cmtca];
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
				map[ndx+1][wrb] <= {1'b1,wrrb};
			end
			else begin
				map[ndx+1][wra] <= {1'b1,wrra};
				map[ndx+1][wrb] <= {1'b1,wrrb};
			end
		3'b010:	
			begin
				map[ndx+1][wrb] <= {1'b1,wrrb};
			end
		3'b001:	
			begin
				map[ndx+1][wra] <= {1'b1,wrra};
			end
		3'b000:	;
		endcase
//		ndx <= ndx + 1;						// make the new map the current one for mappings
	end
end
`endif


endmodule
