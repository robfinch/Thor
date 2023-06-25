// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_head.sv
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
import Thor2024pkg::*;

module Thor2024_head(rst, clk, heads, tail0, tail1, iq, panic_i, panic_o, I);
input rst;
input clk;
output que_ndx_t [QENTRIES-1:0] heads;
input que_ndx_t tail0;
input que_ndx_t tail1;
input iq_entry_t [QENTRIES-1:0] iq;
input [3:0] panic_i;
output reg [3:0] panic_o;
output reg [39:0] I;

integer nn;

reg [2:0] inc;
que_ndx_t head0;
que_ndx_t head1;
que_ndx_t head2;
always_comb head0 = heads[0];
always_comb head1 = heads[1];
always_comb head2 = heads[2];

//
// COMMIT PHASE (dequeue only ... not register-file update)
//
// look at head0 and head1 and let 'em write to the register file if they are ready
//
always_ff @(posedge clk)
if (rst) begin
	I <= 0;
	inc <= 0;
	for (nn = 0; nn < QENTRIES; nn = nn + 1)
		heads[nn] <= nn;
	panic_o <= 'd0;
end
else begin
	inc <= 0;
	if (~|panic_i) begin
		if (SUPPORT_3COMMIT)
		casez ({ iq[head0].v,
			iq[head0].done,
			iq[head1].v,
			iq[head1].done,iq[head2].v,iq[head2].done })

	  // retire 0 - blocked at the first instruction
	  // 16 cases
	  6'b10_??_??:	;
	  // retire 1 - blocked at the second instruction
	  // 12 cases
		6'b0?_10_??:
			if (head0 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 1;
		    inc <= 1;
			end
		6'b11_10_??:
			begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 1;
		    if (iq[head0].v && |iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 1;
			end
	  // retire 2 - blocked at third instruction
	  // 7 cases
		6'b0?_0?_10:
			if (head0 != tail0 && head1 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 2;
		    inc <= 2;
			end
			else if (head0 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 1;
		    inc <= 1;
			end
		6'b11_0?_10:
			if (head1 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 2;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 2;
			end
			else begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 1;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 1;
			end
		6'b11_11_10:
			begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 2;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 2;
			end
		// retire 3
		// 27 cases
		6'b0?_0?_0?:
			if (head0 != tail0 && head1 != tail0 && head2 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 3;
		    inc <= 3;
			end
			else if (head0 != tail0 && head1 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 2;
		    inc <= 2;
			end
			else if (head0 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 1;
		    inc <= 1;
			end
		6'b0?_0?_11:
			if (iq[head2].tgt=='d0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 3;
		    if (iq[head2].v && iq[head2].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 3;
			end
		6'b0?_11_0?:
			if (head2 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 3;
		    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 3;
			end
			else begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 2;
		    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 2;
			end
		6'b0?_11_11:
			if (iq[head2].tgt=='d0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 3;
		    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    if (iq[head2].v && iq[head2].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 3;
			end
			else begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 2;
		    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 2;
			end
		6'b11_0?_11:
			if (head1 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 3;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    if (iq[head2].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 3;
			end
			else begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 1;
		    if (iq[head0].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 1;
			end
		6'b11_11_0?:
			if (head2 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 3;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 3;
			end
			else begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 2;
		    if (iq[head0].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 2;
			end
		6'b11_11_11:
			if (iq[head2].tgt=='d0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 3;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    if (iq[head2].v && iq[head2].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 3;
			end
			else begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 2;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 2;
			end
		6'b11_0?_0?:
			if (head1 != tail0 && head2 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 3;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 3;
			end
			else if (head1 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 2;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 2;
			end
			else begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 1;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 1;
			end
			
		default:
			begin
				panic_o <= PANIC_COMMIT;
				$stop;
			end
		endcase
	else
		casez ({ iq[head0].v,
			iq[head0].done,
			iq[head1].v,
			iq[head1].done })

    // 4'b00_00	- neither valid; skip both
    // 4'b00_01	- neither valid; skip both
    // 4'b00_10	- skip head0, wait on head1
    // 4'b00_11	- skip head0, commit head1
    // 4'b01_00	- neither valid; skip both
    // 4'b01_01	- neither valid; skip both
    // 4'b01_10	- skip head0, wait on head1
    // 4'b01_11	- skip head0, commit head1
    // 4'b10_00	- wait on head0
    // 4'b10_01	- wait on head0
    // 4'b10_10	- wait on head0
    // 4'b10_11	- wait on head0
    // 4'b11_00	- commit head0, skip head1
    // 4'b11_01	- commit head0, skip head1
    // 4'b11_10	- commit head0, wait on head1
    // 4'b11_11	- commit head0, commit head1

    // retire 0
    4'b10_??:	;

    // retire 1
    4'b0?_10,
    4'b11_10:
			if (iq[head0].v || head0 != tail0) begin
				for (nn = 0; nn < QENTRIES; nn = nn + 1)
					heads[nn] <= heads[nn] + 1;
		    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
		    inc <= 1;
			end

    // retire 2
    default: 
    	begin
				if ((iq[head0].v && iq[head1].v) || (head0 != tail0 && head1 != tail0)) begin
					for (nn = 0; nn < QENTRIES; nn = nn + 1)
						heads[nn] <= heads[nn] + 2;
			    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
			    if (iq[head1].v && iq[head1].exc)	panic_o <= PANIC_HALTINSTRUCTION;
			    inc <= 2;
				end
				else if (iq[head0].v || head0 != tail0) begin
					for (nn = 0; nn < QENTRIES; nn = nn + 1)
						heads[nn] <= heads[nn] + 1;
			    if (iq[head0].v && iq[head0].exc)	panic_o <= PANIC_HALTINSTRUCTION;
			    inc <= 1;
				end
	    end
		endcase
	end
	I <= I + inc;
end

endmodule
