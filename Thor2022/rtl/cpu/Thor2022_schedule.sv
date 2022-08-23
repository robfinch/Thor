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

module Thor2022_schedule(clk, strict, reb, stomp, 
	queued0, exec0, memo,
	next_execute, next_retire,
	open_buf, next_open_buf);
input clk;	
input strict;
input sReorderEntry [7:0] reb;
input [7:0] stomp;
input [2:0] queued0;
input [2:0] exec0;
input sOrderBufEntry [7:0] memo;
output[2:0] next_execute;
output reg [2:0] next_retire;
output reg open_buf;
output [2:0] next_open_buf;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Queue scheduler
//
// Chooses the next bucket to queue an instruction. Prevents choosing the
// same queue entry two clock cycles in a row.
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

ex_sched uexsched1(.strict(strict), .reb(reb), .memo(memo), .exec(next_execute));
wb_sched uwbsched1(.reb(reb), .next_retire(next_retire));

endmodule

// ============================================================================
// Execute scheduler
//
// Picks instructions in any order except:
// a) memory instructions are executed in strict order
// --b) preference is given to executing earlier instructions over later ones
// c) prior instructions must at least have been decoded (for arg dependency)
// ============================================================================

module ex_sched(strict, reb, memo, exec);
input strict;
input sReorderEntry [7:0] reb;
input sOrderBufEntry [7:0] memo;
output reg [2:0] exec;


function fnPriorFc;
input [2:0] kk;
integer kh;
begin
	fnPriorFc = 1'b0;
	for (kh = 0; kh < REB_ENTRIES; kh = kh + 1)
		if ((reb[kh].dec.flowchg && reb[kh].sns < reb[kk].sns && !reb[kh].executed && reb[kh].v)  || (|reb[kh].cause && reb[kh].sns < reb[kk].sns))
			fnPriorFc = 1'b1;
end
endfunction

function fnAddressCollision;
input [2:0] ld;
integer jj;
begin
	fnAddressCollision = 1'b0;
	for (jj = 0; jj < 8; jj = jj + 1)
		if (jj > ld)
			if ((reb[memo[ld].ndx].badAddr[31:6] == reb[memo[jj].ndx].badAddr[31:6] || !reb[memo[jj].ndx].agen) && reb[memo[jj].ndx].dec.store)
				fnAddressCollision = 1'b1;
end
endfunction

function fnStoresAgened;
integer jk;
input [2:0] sg;
begin
	fnStoresAgened = 1'b1;
	for (jk = 0; jk < 6; jk = jk + 1)
		if (jk > sg)
			if (!(reb[memo[jk].ndx].agen || !reb[memo[jk].ndx].dec.store))
				fnStoresAgened = 1'b0;
end
endfunction

function fnArgsValid;
input [2:0] kk;
fnArgsValid = (reb[kk].iav && reb[kk].ibv && reb[kk].icv && reb[kk].itv);// && reb[kk].idv);
endfunction

reg [2:0] next_execute_comb;
reg later_store;
reg later_mem;
reg exec_sel;
integer kk;
always_comb
begin
later_store = 1'b0;
later_mem = 1'b0;
next_execute_comb = 3'd7;
exec_sel = 1'b0;
// Try and pick a memory operation first giving precedence to the oldest operation.
for (kk = REB_ENTRIES-1; kk >= 0; kk = kk - 1)
if (memo[kk].v) begin
	if (reb[memo[kk].ndx].v && !reb[memo[kk].ndx].executed && !reb[memo[kk].ndx].out && fnArgsValid(memo[kk].ndx)) begin
		if (!exec_sel) begin
			// Stores can only execute from tail
			if (reb[memo[kk].ndx].dec.store && !later_store) begin
				if (reb[memo[kk].ndx].agen) begin
					next_execute_comb = memo[kk].ndx;
					exec_sel = 1'b1;
				end
				later_store = 1'b1;
				later_mem = 1'b1;
			end
			// Loads may go if they are ready and there is no address conflict.
			if (reb[memo[kk].ndx].dec.load && !(later_store || (strict & later_mem)) && !exec_sel) begin
				if (!fnAddressCollision(kk) && reb[memo[kk].ndx].agen && fnStoresAgened(kk)) begin
					next_execute_comb = memo[kk].ndx;
					exec_sel = 1'b1;
				end
				later_mem = 1'b1;
			end
			// Other operations may go ahead.
			if (!(reb[memo[kk].ndx].dec.load|reb[memo[kk].ndx].dec.store) && (!strict || !later_mem)) begin
				next_execute_comb = memo[kk].ndx;
				exec_sel = 1'b1;
			end
		end
	end
end
// Now pick other operations.
for (kk = 0; kk < REB_ENTRIES; kk = kk + 1)
	if (reb[kk].decoded && reb[kk].v && !reb[kk].dec.mem && !reb[kk].dec.can_chgflow && fnArgsValid(kk)) begin
		if (!exec_sel) begin
			next_execute_comb = kk;
			exec_sel = 1'b1;
		end
	end
end
always_comb//ff @(posedge clk)
	exec <= next_execute_comb;

endmodule

// ============================================================================
// Writeback scheduler
//
// Wait for instruction to become executed before retiring it.
// Skip over constant prefixes.
// ============================================================================

module wb_sched(reb, next_retire);
input sReorderEntry [7:0] reb;
output reg [2:0] next_retire;

reg [2:0] next_retire0a;
reg ret_sel;
integer n8;
always_comb
begin
	next_retire0a = 3'd7;
	ret_sel = 1'b0;
	for (n8 = 0; n8 < REB_ENTRIES; n8 = n8 + 1)
		if (!ret_sel && reb[n8].v && reb[n8].executed && !reb[n8].dec.isExi) begin
			ret_sel = 1'b1;
			next_retire0a = n8;
		end
end

always_comb
	next_retire <= next_retire0a;
	
endmodule

