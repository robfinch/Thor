// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_mem_req_queue.sv
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
// 16492 LUTs / 5998 FFs   No merging and no load bypassing
// 39955 LUTs / 6067 FFs	 No load bypassing
// 66457 LUTs / 6077 FFs   with merging and load bypass
// ============================================================================

import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_mem_req_queue(rst, clk, wr0, wr_ack0, i0, wr1, wr_ack1, i1,
	rd, o, valid, empty, ldo0, found0, ldo1, found1, full,
	rollback, rollback_bitmaps);
parameter AWID = 32;
parameter QDEP = 8;
parameter MERGE_STORES = 1'b0;
parameter LOAD_BYPASS = 1'b0;
input rst;
input clk;
input wr0;
output reg wr_ack0;
input memory_arg_t i0;
input wr1;
output reg wr_ack1;
input memory_arg_t i1;
input rd;
output memory_arg_t o;
output reg valid;
output reg empty;
output memory_arg_t ldo0;
output reg found0;
output memory_arg_t ldo1;
output reg found1;
output reg full;
input [NTHREADS-1:0] rollback;
output reg [127:0] rollback_bitmaps [0:NTHREADS-1];

localparam LOG_QDEP = $clog2(QDEP)-1;
localparam NSEL = 32;

integer n3, n5, n6, m1;
genvar g1, g2;
reg [LOG_QDEP:0] qndx = 'd0;
memory_arg_t [QDEP-1:0] que;
reg [QDEP-1:0] valid_bits = 'd0;
reg [NSEL-1:0] isel0, isel1;
reg [NSEL-1:0] msel0 [0:QDEP-1];
reg [NSEL-1:0] msel1 [0:QDEP-1];
reg [DCacheLineWidth-1:0] imask0, imask1;
reg [DCacheLineWidth-1:0] dat10, dat11;
memory_arg_t datm0 [0:QDEP-1];
memory_arg_t datm1 [0:QDEP-1];
memory_arg_t i0_, i1_;
reg [31:0] sx0, sx1;
reg [7:0] last_tid;
reg [QDEP-1:0] overlapping_store0, overlapping_store1;

initial begin
	for (n5 = 0; n5 < QDEP; n5 = n5 + 1) begin
		que[n5] = 'd0;
	end
end

// Align select lines.
reg [NSEL-1:0] i0_sel, i1_sel;
function [NSEL-1:0] fnSel;
input Thor2023Pkg::memsz_t sz;
case(sz)
Thor2023Pkg::byt:	fnSel = 32'h00000001;
Thor2023Pkg::wyde:	fnSel = 32'h00000003;
Thor2023Pkg::tetra:	fnSel = 32'h0000000F;
Thor2023Pkg::octa:	fnSel = 32'h000000FF;
Thor2023Pkg::hexi:	fnSel = 32'h0000FFFF;
//hexi:	fnSel = 32'h0000FFFF;
//hexipair:	fnSel = 32'hFFFFFFFF;
default:	fnSel = 32'h000000FF;
endcase
endfunction

always_comb
	i0_sel = fnSel(i0.sz);
always_comb
	i1_sel = fnSel(i1.sz);

// Move select and data values to their raw positions.
always_comb
begin
	i0_ = i0;
	i1_ = i1;
	i0_.sel = i0_sel << i0.adr[3:0];
	i1_.sel = i1_sel << i1.adr[3:0];
	i0_.res = i0.res << {i0.adr[3:0],3'b0};
	i1_.res = i1.res << {i1.adr[3:0],3'b0};
end

// Generate a mask for the load data.

generate begin
for (g1 = 0; g1 < 32; g1 = g1 + 1)
begin
	always_comb
		if (i0_sel[g1])
			imask0[g1*8+7:g1*8] = 8'hFF;
		else
			imask0[g1*8+7:g1*8] = 8'h00;
	always_comb
		if (i0_sel[g1])
			sx0[g1] = dat10[g1*8+7];
		else
			sx0[g1] = 1'b0;
	always_comb
		if (i1_sel[g1])
			imask1[g1*8+7:g1*8] = 8'hFF;
		else
			imask1[g1*8+7:g1*8] = 8'h00;
	always_comb
		if (i1_sel[g1])
			sx1[g1] = dat11[g1*8+7];
		else
			sx1[g1] = 1'b0;
end
end
endgenerate

// Search the queue for a matching load or store. If more than one store
// matches the most recently added store is the chosen one. Return the
// data for a load that matches. Ignore a store that is to the same address
// with the same data. However, perform the operations if the operaetion is
// non-cacheable as it may be to an I/O device.

reg foundst0, foundst1;
always_comb
begin
	tSearch(MR_LOAD,MR_LOADZ,i0,isel0,sx0,imask0,ldo0,found0);
	tSearch(MR_LOAD,MR_LOADZ,i1,isel1,sx1,imask1,ldo1,found1);
	tSearch(MR_STORE,MR_STORE,i0,isel0,sx0,imask0,ldo0,foundst0);
	tSearch(MR_STORE,MR_STORE,i1,isel1,sx1,imask1,ldo1,foundst1);
end

task tSearch;
input [3:0] func1;
input [3:0] func2;
input memory_arg_t i;
input [NSEL-1:0] isel;
input [31:0] sx;
input [DCacheLineWidth-1:0] imask;
output memory_arg_t ldo;
output found;
integer n2;
reg [DCacheLineWidth-1:0] dat1;
begin
	ldo = i;
	found = 1'b0;
	// If the data is non-cacheable then it might be an I/O access. Force the
	// operation to complete through the external bus by flagging as not found.
	if (i.cache_type!=wishbone_pkg::NC_NB && i.cache_type!=wishbone_pkg::NON_CACHEABLE && LOAD_BYPASS) begin
		// A store is not found if the data is not the same.
		if (i.func!=MR_STORE || i.res == que[n2].res) begin
			if (i.func==func1 || i.func==func2) begin
				for (n2 = 0; n2 < QDEP; n2 = n2 + 1) begin
					if (i.adr[AWID-1:DCacheTagLoBit]==que[n2].adr[AWID-1:DCacheTagLoBit] && valid_bits[n2]) begin
						if ((isel & que[n2].sel)==isel) begin
							found = 1'b1;
							// Align the data with the load address
							if (i.adr > que[n2].adr)
								dat1 = que[n2].res >> {i.adr - que[n2].adr,3'b0};
							else
								dat1 = que[n2].res >> {que[n2].adr - i.adr,3'b0};
							// For a LOAD sign extend value to machine width.
							if (i.func==MR_LOAD) begin
								ldo.res = /*|sx ? (dat1 & imask) | ~imask :*/ (dat1 & imask);
								case(i.sz)
								Thor2023Pkg::byt:	ldo.res = {{120{ldo.res[7]}},ldo.res[7:0]};
								Thor2023Pkg::wyde: ldo.res = {{112{ldo.res[15]}},ldo.res[15:0]};
								Thor2023Pkg::tetra:ldo.res = {{96{ldo.res[31]}},ldo.res[31:0]};
								Thor2023Pkg::octa:ldo.res = {{64{ldo.res[63]}},ldo.res[63:0]};
								Thor2023Pkg::hexi:ldo.res = ldo.res[127:0];
								default:	ldo.res = ldo.res[127:0];
								endcase
							end
							else	// MR_LOADZ
								ldo.res = dat1 & imask;
						end
					end
				end
			end
		end
	end
end
endtask


// Generate an array of arguments with data merged in.

generate begin : gMergeDat
	for (g2 = 0; g2 < QDEP; g2 = g2 + 1) begin
		if (MERGE_STORES) begin
			MergeDat #(NSEL) umg0(que[g2], i0_, datm0[g2]);
			MergeDat #(NSEL) umg1(que[g2], i1_, datm1[g2]);
		end
		else begin
			always_comb
			begin
				datm0[g2] <= 'd0;	// avoid no driver warning.
				datm1[g2] <= 'd0;
			end
		end
	end
end
endgenerate

always_comb
begin
	overlapping_store0 = 'd0;
	overlapping_store1 = 'd0;
	if (MERGE_STORES) begin
		for (n6 = 0; n6 < QDEP; n6 = n6 + 1) begin
			if (i0.cache_type != wishbone_pkg::NC_NB && i0.cache_type != wishbone_pkg::NON_CACHEABLE) begin
				if (wr0 && que[n6].adr[AWID-1:DCacheTagLoBit]==i0.adr[AWID-1:DCacheTagLoBit] &&
					i0.func==MR_STORE && que[n6].func==MR_STORE)
					overlapping_store0[n6] = 1'b1;
				// Search que for overlapping address, read or write, already present in the
				// queue. If there  are any, then do not merge the stores.
				for (m1 = 0; m1 < QDEP; m1 = m1 + 1) begin
					if (m1 > n6) begin
						if (que[n6].adr[AWID-1:DCacheTagLoBit]==que[m1].adr[AWID-1:DCacheTagLoBit])
							overlapping_store0[n6] = 1'b0;
					end
				end
			end
		end
		for (n6 = 0; n6 < QDEP; n6 = n6 + 1) begin
			if (i1.cache_type != wishbone_pkg::NC_NB && i1.cache_type != wishbone_pkg::NON_CACHEABLE) begin
				if (wr1 && que[n6].adr[AWID-1:DCacheTagLoBit]==i1.adr[AWID-1:DCacheTagLoBit] &&
					i1.func==MR_STORE && que[n6].func==MR_STORE)
					overlapping_store1[n6] = 1'b1;
				// Search que for overlapping address, read or write, already present in the
				// queue. If there  are any, then do not merge the stores.
				for (m1 = 0; m1 < QDEP; m1 = m1 + 1) begin
					if (m1 > n6) begin
						if (que[n6].adr[AWID-1:DCacheTagLoBit]==que[m1].adr[AWID-1:DCacheTagLoBit])
							overlapping_store1[n6] = 1'b0;
					end
				end
			end
		end
	end
	/*
	for (n6 = 0; n6 < QDEP; n6 = n6 + 1) begin
		if (wr0 && que[n6].adr[AWID-1:DCacheTagLoBit]==i0.adr[AWID-1:DCacheTagLoBit] &&
			i0.func==MR_STORE && que[n6].func==MR_STORE)
			overlapping_store = 1'b1;
		if (wr1 && que[n6].adr[AWID-1:DCacheTagLoBit]==i1.adr[AWID-1:DCacheTagLoBit] &&
			i1.func==MR_STORE && que[n6].func==MR_STORE)
			overlapping_store = 1'b1;
	end
	*/
end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	valid_bits <= 'd0;
	wr_ack0 <= 1'b0;
	wr_ack1 <= 1'b0;
	last_tid <= 8'd255;
	qndx <= 'd0;
	for (n3 = 0; n3 < NTHREADS; n3 = n3 + 1)
		rollback_bitmaps[n3] <= 'd0;
//	for (n3 = 1; n3 < QDEP; n3 = n3 + 1)
//		que[n3] <= 'd0;
	que <= 'd0;
end
else begin
	wr_ack0 <= 1'b0;
	wr_ack1 <= 1'b0;
//	o <= que[0];
	if (wr0 && foundst0)
		wr_ack0 <= 1'b1;
	if (wr1 && foundst1)
		wr_ack1 <= 1'b1;

	// Port #0 take precedence.
	// Read and write at the same time.
	if ((rd & ~empty) & wr0 & ~foundst0) begin
		tReadAndWrite(overlapping_store0, i0_, datm0);
		wr_ack0 <= 1'b1;
	end

	// Port #1
	// Read and write at the same time.
	else if ((rd & ~empty) & wr1 & ~foundst1) begin
		tReadAndWrite(overlapping_store1, i1_, datm1);
		wr_ack1 <= 1'b1;
	end

	// Port #0 write
	else if (wr0 & ~foundst0) begin
		tWrite(overlapping_store0, i0_, datm0);
		if (qndx < QDEP)
			wr_ack0 <= 1'b1;
	end

	// Port #1 write
	else if (wr1 & ~foundst1) begin
		tWrite(overlapping_store1, i1_, datm1);
		if (qndx < QDEP)
			wr_ack1 <= 1'b1;
	end
	
	// Read
	else if (rd & ~empty)
		tRead();

	if (|rollback) begin
		for (n3 = 0; n3 < QDEP; n3 = n3 + 1)
			if (rollback[que[n3].thread]) begin
				que[n3].v <= 1'b0;
				rollback_bitmaps[que[n3].thread] <= 'd0;
			end
	end
end

always_comb
	empty = ~|valid_bits;
always_comb
	o = que[0];
always_comb
	valid = valid_bits[0];
always_comb
	full = qndx==QDEP-1;

task tReadAndWrite;
input [QDEP-1:0] overlapping_store;
input memory_arg_t i_;
input memory_arg_t datm [0:QDEP-1];
integer n3;
begin
	for (n3 = 1; n3 < QDEP; n3 = n3 + 1) begin
		if (overlapping_store[n3])
			que[n3-1] <= datm[n3];
		else
			que[n3-1] <= que[n3];
		valid_bits[n3-1] <= valid_bits[n3];
	end
	valid_bits[QDEP-1] <= 1'b0;
	if (last_tid != i_.tid) begin
		rollback_bitmaps[que[0].thread][que[0].tgt] <= 1'b0;
		rollback_bitmaps[i_.thread][i_.tgt] <= 1'b1;
		if (~|overlapping_store) begin
			que[qndx-1] <= i_;
			valid_bits[qndx-1] <= 1'b1;
		end
		else if (|qndx)
			qndx <= qndx - 2'd1;
		last_tid <= i_.tid;
	end
	else if (|qndx)
		qndx <= qndx - 2'd1;
end
endtask

task tWrite;
input [QDEP-1:0] overlapping_store;
input memory_arg_t i_;
input memory_arg_t datm [0:QDEP-1];
begin
	if (qndx < QDEP) begin
		if (last_tid != i_.tid) begin
			rollback_bitmaps[i_.thread][i_.tgt] <= 1'b1;
			if (overlapping_store[qndx-1])
				que[qndx-1] <= datm[qndx-1];
			else begin
				que[qndx] <= i_;
				valid_bits[qndx] <= 1'b1;
				qndx <= qndx + 2'd1;
			end
			last_tid <= i_.tid;
		end
	end
end
endtask

task tRead;
integer n3;
begin
	if (|qndx)
		qndx <= qndx - 2'd1;
	for (n3 = 1; n3 < QDEP; n3 = n3 + 1) begin
		que[n3-1] <= que[n3];
		valid_bits[n3-1] <= valid_bits[n3];
		rollback_bitmaps[que[0].thread][que[0].tgt] <= 1'b0;
	end
	valid_bits[QDEP-1] <= 1'b0;
end
endtask

endmodule

/* under construction */
module MergeDat(i0, i1, o);
input memory_arg_t i0;
input memory_arg_t i1;
output memory_arg_t o;
parameter NSEL = 32;

reg [DCacheLineWidth-1:0] dat0, dat1, dat;
reg [NSEL-1:0] sel0, sel1;

always_comb
	sel0 = i0.sel << i0.adr[3:0];
always_comb
	sel1 = i1.sel << i1.adr[3:0];
always_comb
	dat0 = i0.res << {i0.adr[3:0],3'b0};
always_comb
	dat1 = i1.res << {i1.adr[3:0],3'b0};

genvar g1;
generate begin : gMerge
	for (g1 = 0; g1 < NSEL; g1 = g1 + 1) begin
		always_comb begin
			if (sel1[g1])
				dat[g1*8+7:g1*8] = dat1[g1*8+7:g1*8];
			else
				dat[g1*8+7:g1*8] = dat0[g1*8+7:g1*8];
		end
	end
end
endgenerate

always_comb
begin
	o = i0;
	o.sel = sel0|sel1;
	o.res = dat;
end

endmodule

