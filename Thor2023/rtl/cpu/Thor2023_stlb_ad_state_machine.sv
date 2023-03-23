// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_stlb_ad_state_machine.sv
//	- shared TLB state machine
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

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;
import Thor2023_stlb_pkg::*;

module Thor2023_stlb_ad_state_machine(rst, clk, state, rcount, tlbadr_i, tlbadro, 
	tlbdat_rst, tlbdat_i, tlbdati, tlbdato,	master_count, inv_count);
parameter ENTRIES = 1024;
parameter PAGE_SIZE = 8192;
parameter ASSOC = 9;
localparam LOG_ENTRIES = $clog2(ENTRIES);
localparam LOG_PAGE_SIZE = $clog2(PAGE_SIZE);
input rst;
input clk;
input tlb_state_t state;
input [LOG_ENTRIES-1:0] rcount;
input [$bits(address_t)-1:0] tlbadr_i;
output reg [LOG_ENTRIES-1:0] tlbadro;
input TLBE tlbdat_rst;
input TLBE tlbdat_i;
input TLBE [ASSOC-1:0] tlbdati;
output TLBE [ASSOC-1:0] tlbdato;
input [5:0] master_count;
input [LOG_ENTRIES-1:0] inv_count;

integer n2;

always_ff @(posedge clk)
begin
	case(state)
	ST_RST:	
		begin
			tlbadro <= rcount;
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdato[n2] <= tlbdat_rst;
			end
		end
	ST_RUN:
		begin
			tlbadro <= tlbadr_i[LOG_PAGE_SIZE+LOG_ENTRIES-1:LOG_PAGE_SIZE];
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdato[n2] <= tlbdat_i;
				tlbdato[n2].count <= master_count;
			end
		end
	ST_AGE1,ST_AGE2,ST_AGE3:
		begin
			tlbadro <= rcount;
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdato[n2] <= tlbdat_i;
				tlbdato[n2].count <= master_count;
			end
		end
	ST_AGE4:
		begin
			tlbadro <= rcount;
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdato[n2] <= tlbdati[n2];
				tlbdato[n2].count <= master_count;
			end
		end
	ST_INVALL1,ST_INVALL2,ST_INVALL3,ST_INVALL4:
		begin
			tlbadro <= inv_count;
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1)
				tlbdato[n2] <= 'd0;
		end
	default:
		begin
			tlbadro <= tlbadr_i[LOG_PAGE_SIZE+LOG_ENTRIES-1:LOG_PAGE_SIZE];
			for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
				tlbdato[n2] <= tlbdat_i;
				tlbdato[n2].count <= master_count;
			end
		end
	endcase
	if (tlbdato[ASSOC-1].pte.ppn=='d0 && tlbdato[ASSOC-1].vpn != 'd0) begin
		$display("PPN zero");
	end
end


endmodule
