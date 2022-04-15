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

module Thor2022_schedule(reb, sns, stomp, next_fetch0, next_fetch1,
	next_decompress, next_decode, next_execute, next_retire);
input sReorderEntry [REB_ENTRIES-1:0] reb;
input [5:0] sns [0:7];
input [7:0] stomp;
output [2:0] next_fetch0;
output [2:0] next_fetch1;
output [2:0] next_decompress;
output [2:0] next_decode;
output reg [2:0] next_execute;
output reg [2:0] next_retire;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction fetch scheduler
//
// Chooses the next bucket to queue an instruction in any order.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire [5:0] vv = {
		reb[5].v,
		reb[4].v,
		reb[3].v,
		reb[2].v,
		reb[1].v,
		reb[0].v
	};
reg [5:0] vv1;

ffz6 uffoq (
	.i(vv),
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

ffo6 uffodecompress (
	.i({
		reb[5].fetched,
		reb[4].fetched,
		reb[3].fetched,
		reb[2].fetched,
		reb[1].fetched,
		reb[0].fetched
	}),
	.o(next_decompress)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Decode scheduler
//
// Chooses the next bucket to decode, essentially in any order.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ffo6 uffodecode (
	.i({
		reb[5].decompressed,
		reb[4].decompressed,
		reb[3].decompressed,
		reb[2].decompressed,
		reb[1].decompressed,
		reb[0].decompressed
	}),
	.o(next_decode)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute scheduler
//
// Picks instructions in any order except:
// a) memory instructions are executed in strict order
// b) preference is given to executing earlier instructions over later ones
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function fnPriorFc;
input [2:0] kk;
integer kh;
begin
	fnPriorFc = 1'b0;
	for (kh = 0; kh < REB_ENTRIES; kh = kh + 1)
		if ((reb[kh].dec.flowchg && sns[kh] < sns[kk] /* && !reb[kh].executed*/)  || (|reb[kh].cause && sns[kh] < sns[kk]))
			fnPriorFc = 1'b1;
end
endfunction

function fnArgsValid;
input [2:0] kk;
fnArgsValid = (reb[kk].iav && reb[kk].ibv && reb[kk].icv && reb[kk].lkv);
endfunction

integer kk;
always_comb
begin
next_execute = 3'd7;
for (kk = REB_ENTRIES-1; kk >= 0; kk = kk - 1)
	if ((reb[kk].decoded || reb[kk].out) && reb[kk].v && !stomp[kk]) begin
		if (fnArgsValid(kk)) begin
			if (reb[kk].dec.mem && !fnPriorFc(kk)) begin
				if (reb[next_execute].dec.mem && !reb[next_execute].executed && reb[next_execute].v) begin
					if (sns[kk] <= sns[next_execute] || next_execute > REB_ENTRIES)
						next_execute = kk;
				end
				else if (sns[kk] <= sns[next_execute] || next_execute > REB_ENTRIES)
					next_execute = kk;
			end
			else if (!reb[kk].dec.mem && !(reb[kk].dec.flowchg && fnPriorFc(kk))) begin
				if (next_execute > REB_ENTRIES)
					next_execute = kk;
				// Prefer executing earlier instructions over later ones.
				else if (sns[kk] <= sns[next_execute])
					next_execute = kk;
			end
		end
	end
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Writeback scheduler
//
// Wait for the next instruction to become executed before retiring it.
// Choose the instruction with the lowest sequence number as the head.
// Skip over constant prefixes.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

integer n8;
always_comb
begin
	next_retire = 3'd7;
	for (n8 = 0; n8 < REB_ENTRIES; n8 = n8 + 1)
		if ((sns[n8] < sns[next_retire] || next_retire > REB_ENTRIES) && reb[n8].v && reb[n8].executed &&
			!reb[n8].dec.isExi && reb[n8].ir.any.opcode!=EXIM)
			next_retire = n8;
end

endmodule
