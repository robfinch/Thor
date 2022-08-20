// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_schedule.sv
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

import const_pkg::*;
import Thor2022_pkg::*;

module Thor2022_schedule(clk, reb, stomp, 
	fetch0, queued0, next_fetch0, next_fetch1,
	next_decompress0, next_decompress1, next_decode0, next_decode1,
	next_regfetch0, next_regfetch1,
	next_execute, next_retire0, next_retire1,
	open_buf, next_open_buf);
input clk;	
input sReorderEntry [7:0] reb;
input [7:0] stomp;
input [2:0] fetch0;
input [2:0] queued0;
output [2:0] next_fetch0;
output [2:0] next_fetch1;
output reg [2:0] next_decompress0;
output reg [2:0] next_decompress1;
output reg [2:0] next_decode0;
output reg [2:0] next_decode1;
output reg [2:0] next_regfetch0;
output reg [2:0] next_regfetch1;
output reg [2:0] next_execute;
output reg [2:0] next_retire0;
output reg [2:0] next_retire1;
output reg open_buf;
output [2:0] next_open_buf;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction fetch scheduler
//
// Chooses the next bucket to queue an instruction.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [5:0] lov;		// lock-out v
reg [5:0] lov2;
always_comb
	lov = (6'd1 << queued0);
wire [5:0] vv = {
		reb[5].v,
		reb[4].v,
		reb[3].v,
		reb[2].v,
		reb[1].v,
		reb[0].v
	};
always_comb
	open_buf = (vv|(lov&~lov2))!=6'h3F;
ffz6 uffoq2 (
	.i(vv|(lov&~lov2)),
	.o(next_open_buf)
);
always_ff @(posedge clk)
	lov2 <= lov;

reg [5:0] vv1;
wire [5:0] ev = {
		reb[5].executed,
		reb[4].executed,
		reb[3].executed,
		reb[2].executed,
		reb[1].executed,
		reb[0].executed
	};
wire [5:0] ol = {
		reb[5].out,
		reb[4].out,
		reb[3].out,
		reb[2].out,
		reb[1].out,
		reb[0].out
	};
ffz6 uffoq (
	.i(vv | lov | ev | stomp | ol),
	.o(next_fetch0)
);

always_comb
if (next_fetch0 != 3'd7)
	vv1 = vv | (6'd1 << next_fetch0);
else
	vv1 = 6'b111111;

ffz6 uffoq1 (
	.i(vv1),
	.o(next_fetch1)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Decode scheduler
//
// Chooses the next bucket to decode, essentially in any order.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire [5:0] fd = {
		reb[5].fetched,
		reb[4].fetched,
		reb[3].fetched,
		reb[2].fetched,
		reb[1].fetched,
		reb[0].fetched
	};
reg [5:0] fd1;
wire [2:0] next_decompress0a;
wire [2:0] next_decompress1a;
always_comb
if (next_decompress0a != 3'd7)
	fd1 = fd & ~(6'd1 << next_decompress0a);
else
	fd1 = 6'b000000;

ffo6 uffodecompress0 (
	.i(fd|stomp),
	.o(next_decompress0a)
);

ffo6 uffodecompress1 (
	.i(fd1),
	.o(next_decompress1a)
);

always_comb// @(posedge clk)
	next_decompress0 <= next_decompress0a;
always_comb// @(posedge clk)
	next_decompress1 <= next_decompress1a;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Decode scheduler
//
// Chooses the next bucket to decode, essentially in any order.
// Decodes are processed in order, all prior decodes must have been done
// before the newly choosen one.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function fnPriorsDecoded;
input [2:0] kk;
integer n;
begin
	fnPriorsDecoded = 1'b1;
	for (n = 0; n < REB_ENTRIES; n = n + 1)
		if (reb[n].sns < reb[kk].sns && !(reb[n].decoded || reb[n].rfetched || reb[n].executed || reb[n].out) && reb[n].v)
			fnPriorsDecoded = 1'b0;
end
endfunction

integer mm;
always_comb// @(posedge clk)
begin
	next_decode0 = 3'd7;
	next_decode1 = 3'd7;
	for (mm = 0; mm < REB_ENTRIES; mm = mm + 1) begin
		if ((reb[mm].sns < reb[next_decode0].sns || next_decode0==3'd7) && reb[mm].decompressed && !stomp[mm]) begin
			if (fnPriorsDecoded(mm))
				next_decode0 = mm;
		end
	end
	for (mm = 0; mm < REB_ENTRIES; mm = mm + 1) begin
		if ((reb[mm].sns < reb[next_decode0].sns || next_decode1==3'd7) && next_decode0 != 3'd7 && reb[mm].decompressed) begin
			if (fnPriorsDecoded(mm))
				next_decode1 = mm;
		end
	end
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Regfetch scheduler (not used)
//
// Chooses the next bucket to regfetch.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
/*
wire [5:0] rfd = {
		reb[5].decoded,
		reb[4].decoded,
		reb[3].decoded,
		reb[2].decoded,
		reb[1].decoded,
		reb[0].decoded
	};
reg [5:0] rfd1;
wire [2:0] next_regfetch0a;
wire [2:0] next_regfetch1a;
always_comb
if (next_regfetch0a != 3'd7)
	rfd1 = ~vv & ~(6'd1 << next_regfetch0a);
else
	rfd1 = 6'b000000;

ffo6 ufforegfetch0 (
	.i(rfd),
	.o(next_regfetch0a)
);

ffo6 ufforegfetch1 (
	.i(rfd1),
	.o(next_regfetch1a)
);

reg [2:0] rr;
always_comb// @(posedge clk)
begin
/*
	next_regfetch0 = 3'd7;
	for (rr = 0; rr < REB_ENTRIES; rr = rr + 1)
		if (next_regfetch0==3'd7 && reb[rr].decoded)
			next_regfetch0 = rr;
		else if (reb[rr].sns < reb[next_regfetch0].sns && reb[rr].decoded)
			next_regfetch0 = rr;
*/
always_comb
begin
	next_regfetch0 <= 3'd7;//next_regfetch0a;
end

always_comb// @(posedge clk)
	next_regfetch1 <= 3'd7;//next_regfetch1a;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute scheduler
//
// Picks instructions in any order except:
// a) memory instructions are executed in strict order
// b) preference is given to executing earlier instructions over later ones
// c) prior instructions must at least have been decoded (for arg dependency)
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function fnPriorFc;
input [2:0] kk;
integer kh;
begin
	fnPriorFc = 1'b0;
	for (kh = 0; kh < REB_ENTRIES; kh = kh + 1)
		if ((reb[kh].dec.flowchg && reb[kh].sns < reb[kk].sns && !reb[kh].executed)  || (|reb[kh].cause && reb[kh].sns < reb[kk].sns))
			fnPriorFc = 1'b1;
end
endfunction

function fnArgsValid;
input [2:0] kk;
fnArgsValid = (reb[kk].iav && reb[kk].ibv && reb[kk].icv && reb[kk].itv);// && reb[kk].idv);
endfunction

reg [2:0] next_execute_comb;
integer kk;
always_comb
begin
next_execute_comb = 3'd7;
for (kk = REB_ENTRIES-1; kk >= 0; kk = kk - 1)
	if (reb[kk].decoded && reb[kk].v) begin
		if (fnArgsValid(kk)) begin
			if (reb[kk].dec.mem && !fnPriorFc(kk)) begin
				if (reb[next_execute_comb].dec.mem) begin
					if (reb[kk].sns <= reb[next_execute_comb].sns || next_execute_comb > REB_ENTRIES)
						next_execute_comb = kk;
				end
				else if (reb[kk].sns <= reb[next_execute_comb].sns || next_execute_comb > REB_ENTRIES)
					next_execute_comb = kk;
			end
			else if (!reb[kk].dec.mem && !(reb[kk].dec.flowchg && fnPriorFc(kk))) begin
				if (next_execute_comb > REB_ENTRIES)
					next_execute_comb = kk;
				// Prefer executing earlier instructions over later ones.
				else if (reb[kk].sns <= reb[next_execute_comb].sns)
					next_execute_comb = kk;
			end
		end
	end
end
always_comb//ff @(posedge clk)
	next_execute <= next_execute_comb;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Writeback scheduler
//
// Wait for the next instruction to become executed before retiring it.
// Choose the instruction with the lowest sequence number as the head.
// Skip over constant prefixes.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [2:0] next_retire0a;
reg [2:0] next_retire1a;

integer n8;
always_comb
begin
	next_retire0a = 3'd7;
	next_retire1a = 3'd7;
	for (n8 = 0; n8 < REB_ENTRIES; n8 = n8 + 1)
		if ((reb[n8].sns < reb[next_retire0a].sns || next_retire0a > REB_ENTRIES) && reb[n8].v && reb[n8].executed &&
			!reb[n8].dec.isExi && reb[n8].ir.any.opcode!=EXIM)
			next_retire0a = n8;
	for (n8 = 0; n8 < REB_ENTRIES; n8 = n8 + 1)
		if ((reb[n8].sns < reb[next_retire1a].sns || next_retire1a > REB_ENTRIES) && reb[n8].v && reb[n8].executed &&
			!reb[n8].dec.isExi && reb[n8].ir.any.opcode!=EXIM && n8 != next_retire0a)
			next_retire1a = n8;
end

always_comb//_ff @(posedge clk)
	next_retire0 <= next_retire0a;
always_comb//_ff @(posedge clk)
	next_retire1 <= next_retire1a;
	
endmodule
