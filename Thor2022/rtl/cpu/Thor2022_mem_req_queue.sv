// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_mem_req_queue.sv
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
import Thor2022_mmupkg::*;

module Thor2022_mem_req_queue(rst, clk, wr0, wr_ack0, i0, wr1, wr_ack1, i1,
	rd, o, valid, empty, ldo0, found0, ldo1, found1);
parameter AWID = 32;
parameter QDEP = 3;
input rst;
input clk;
input wr0;
output reg wr_ack0;
input MemoryRequest i0;
input wr1;
output reg wr_ack1;
input MemoryRequest i1;
input rd;
output MemoryRequest o;
output reg valid;
output reg empty;
output MemoryRequest ldo0;
output reg found0;
output MemoryRequest ldo1;
output reg found1;

reg [3:0] qndx = 'd0;
MemoryRequest [QDEP-1:0] que;
reg [QDEP-1:0] valid_bits = 'd0;
reg [63:0] isel0, isel1;
reg [63:0] qsel [0:QDEP-1];
reg [255:0] imask0, imask1;
reg [255:0] dat10, dat11;
reg sx0, sx1;
reg [7:0] last_tid0, last_tid1;

integer n5;
initial begin
	for (n5 = 0; n5 < QDEP; n5 = n5 + 1) begin
		que[n5] = 'd0;
	end
end

// Align select lines.
reg [31:0] i0_sel, i1_sel;
function [31:0] fnSel;
input [2:0] sz;
case(sz)
byt:	fnSel = 32'h00000001;
wyde:	fnSel = 32'h00000003;
tetra:	fnSel = 32'h0000000F;
octa:	fnSel = 32'h000000FF;
hexi:	fnSel = 32'h0000FFFF;
hexipair:	fnSel = 32'hFFFFFFFF;
default:	fnSel = 32'h000000FF;
endcase
endfunction

always_comb
	i0_sel = fnSel(i0.sz);
always_comb
	i1_sel = fnSel(i1.sz);

always_comb
	isel0 = i0_sel << i0.adr[3:0];
always_comb
	isel1 = i1_sel << i1.adr[3:0];
integer n1;
always_comb
for (n1 = 0; n1 < QDEP; n1 = n1 + 1)
	qsel[n1] = fnSel(que[n1].sz) << que[n1].adr[3:0];

// Generate a mask for the load data.

genvar g1;
generate begin : giMask
for (g1 = 0; g1 < 32; g1 = g1 + 1)
begin
	always_comb
		if (i0_sel[g1])
			imask0[g1*8+7:g1*8] = 8'hFF;
		else
			imask0[g1*8+7:g1*8] = 8'h00;
	always_comb
		if (i0_sel[g1])
			sx0 = dat10[g1*8+7];
	always_comb
		if (i1_sel[g1])
			imask1[g1*8+7:g1*8] = 8'hFF;
		else
			imask1[g1*8+7:g1*8] = 8'h00;
	always_comb
		if (i1_sel[g1])
			sx1 = dat11[g1*8+7];
end
end
endgenerate

// Search the queue for a matching store. If more than one store matches the
// most recently added store is the chosen one.

always_comb
begin
	tSearch(i0,isel0,sx0,imask0,ldo0,found0);
	tSearch(i1,isel1,sx1,imask1,ldo1,found1);
end

task tSearch;
input MemoryRequest i;
input [63:0] isel;
input sx;
input [255:0] imask;
output MemoryRequest ldo;
output found;
integer n2;
reg [255:0] dat1;
begin
	ldo = i;
	found = 1'b0;
	if (i.func==MR_LOAD || i.func==MR_LOADZ) begin
		for (n2 = 0; n2 < QDEP; n2 = n2 + 1) begin
			if (i.adr[AWID-1:4]==que[n2].adr[AWID-1:4] && valid_bits[n2]) begin
				if ((isel & qsel[n2])==isel) begin
					found = 1'b1;
					// Align the data with the load address
					if (i.adr > que[n2].adr)
						dat1 = que[n2].dat >> {i.adr - que[n2].adr,3'b0};
					else
						dat1 = que[n2].dat << {que[n2].adr - i.adr,3'b0};
					if (i.func==MR_LOAD)
						ldo.dat = sx ? (dat1 & imask) | ~imask : (dat1 & imask);
					else
						ldo.dat = dat1 & imask;
				end
			end
		end
	end
end
endtask


integer n3;
always_ff @(posedge clk)
if (rst) begin
	valid_bits <= 'd0;
	wr_ack0 <= 1'b0;
	wr_ack1 <= 1'b0;
	last_tid0 <= 8'd255;
	last_tid1 <= 8'd255;
end
else begin
	wr_ack0 <= 1'b0;
	wr_ack1 <= 1'b0;
	o <= que[0];
	valid <= valid_bits[0];
	if (wr0 && found0)
		wr_ack0 <= 1'b1;
	if (wr1 && found1)
		wr_ack1 <= 1'b1;
	// Port #0 take precedence.
	if (rd & wr0 & !found0) begin
		for (n3 = 1; n3 < QDEP; n3 = n3 + 1) begin
			que[n3-1] <= que[n3];
			valid_bits[n3-1] <= valid_bits[n3];
		end
		wr_ack0 <= 1'b1;
		if (last_tid0 != i0.tid) begin
			que[qndx] <= i0;
			last_tid0 <= i0.tid;
			valid_bits[qndx] <= 1'b1;
		end
		else
			qndx <= qndx - 2'd1;
	end
	else if (rd & wr1 & !found1) begin
		for (n3 = 1; n3 < QDEP; n3 = n3 + 1) begin
			que[n3-1] <= que[n3];
			valid_bits[n3-1] <= valid_bits[n3];
		end
		wr_ack1 <= 1'b1;
		if (last_tid1 != i1.tid) begin
			que[qndx] <= i1;
			valid_bits[qndx] <= 1'b1;
		end
		else
			qndx <= qndx - 2'd1;
	end
	else if (wr0 & !found0) begin
		if (qndx < QDEP) begin
			if (last_tid0 != i0.tid) begin
				que[qndx] <= i0;
				valid_bits[qndx] <= 1'b1;
				qndx <= qndx + 2'd1;
			end
			wr_ack0 <= 1'b1;
		end
	end
	else if (wr1 & !found1) begin
		if (qndx < QDEP) begin
			if (last_tid1 != i1.tid) begin
				que[qndx] <= i1;
				valid_bits[qndx] <= 1'b1;
				qndx <= qndx + 2'd1;
			end
			wr_ack1 <= 1'b1;
		end
	end
	else if (rd) begin
		qndx <= qndx - 2'd1;
		for (n3 = 1; n3 < QDEP; n3 = n3 + 1) begin
			que[n3-1] <= que[n3];
			valid_bits[n3-1] <= valid_bits[n3];
		end
		valid_bits[QDEP-1] <= 1'b0;
	end
end

always_comb
	empty = ~|valid_bits;
	
endmodule
