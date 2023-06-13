// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
import Thor2024pkg::*;

module Thor2024_regfile_valid(rst, clk, branchmiss, did_branchback, Rt0, Rt1,
	livetarget, tail0, tail1,
	fetchbuf0_v, fetchbuf1_v, fetchbuf0_rfw, fetchbuf1_rfw, fetchbuf0_instr, fetchbuf1_instr,
	iq, iqentry_source,
	commit0_v, commit1_v, commit0_tgt, commit1_tgt, commit0_id, commit1_id,
	rf_source, rf_v);
input rst;
input clk;
input branchmiss;
input did_branchback;
input regspec_t Rt0;
input regspec_t Rt1;
input [63:1] livetarget;
input [2:0] tail0;
input [2:0] tail1;
input fetchbuf0_v;
input fetchbuf1_v;
input fetchbuf0_rfw;
input fetchbuf1_rfw;
input instruction_t fetchbuf0_instr;
input instruction_t fetchbuf1_instr;
input iq_entry_t [QENTRIES-1:0] iq;
input [QENTRIES-1:0] iqentry_source;
input commit0_v;
input commit1_v;
input regspec_t commit0_tgt;
input regspec_t commit1_tgt;
input [4:0] commit0_id;
input [4:0] commit1_id;
input [4:0] rf_source [0:63];
output reg [63:0] rf_v;
parameter LR0 = 6'd56;

integer n, n1;
reg [63:0] rf_vr;

initial begin
	for (n = 0; n < AREGS; n = n + 1) begin
	  rf_vr[n] = 1'b1;
	end
end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	for (n1 = 0; n1 < AREGS; n1 = n1 + 1)
	  rf_vr[n1] <= 1'b1;
end
else begin
	rf_vr <= rf_v;
	if (branchmiss) begin
		for (n1 = 1; n1 < AREGS; n1 = n1 + 1)
		  if (rf_vr[n1] == INV && ~livetarget[n1])	rf_vr[n1] <= VAL;
	end
	//
	// COMMIT PHASE (register-file update only ... dequeue is elsewhere)
	//
	// look at head0 and head1 and let 'em write the register file if they are ready
	//
	// why is it happening here and not in another phase?
	// want to emulate a pass-through register file ... i.e. if we are reading
	// out of r3 while writing to r3, the value read is the value written.
	// requires BLOCKING assignments, so that we can read from rf[i] later.
	//
	if (commit0_v) begin
    if (!rf_vr[ commit0_tgt ]) 
			rf_vr[ commit0_tgt ] <= rf_source[ commit0_tgt ] == commit0_id || (branchmiss && iqentry_source[ commit0_id[2:0] ]);
	end
	if (commit1_v) begin
    if (!rf_vr[ commit1_tgt ]) 
			rf_vr[ commit1_tgt ] <= rf_source[ commit1_tgt ] == commit1_id || (branchmiss && iqentry_source[ commit1_id[2:0] ]);
	end

	if (!branchmiss) begin	
		case ({fetchbuf0_v, fetchbuf1_v})
    2'b00: ; // do nothing
    2'b01:
    	if (iq[tail0].v == INV && !did_branchback) begin
				if (fetchbuf1_rfw)
			    rf_vr[ Rt1 ] <= INV;
    	end
    2'b10:	;
		2'b11:
			if (iq[tail0].v == INV && !did_branchback) begin
				if (fnIsBackBranch(fetchbuf0_instr)) begin
					if (fetchbuf0_instr.br.lk != 1'b0)
						rf_vr[LR0] <= INV;
				end
				else begin
					if (iq[tail1].v == INV & !did_branchback) begin
						//
						// if the two instructions enqueued target the same register, 
						// make sure only the second writes to rf_v and rf_source.
						// first is allowed to update rf_v and rf_source only if the
						// second has no target (BEQ or SW)
						//
						if (Rt0 == Rt1) begin
					    if (fetchbuf1_rfw)
								rf_vr[ Rt1 ] <= INV;
					    else if (fetchbuf0_rfw)
								rf_vr[ Rt0 ] <= INV;
						end
						else begin
					    if (fetchbuf0_rfw)
								rf_vr[ Rt0 ] <= INV;
					    if (fetchbuf1_rfw)
								rf_vr[ Rt1 ] <= INV;
						end
			    end	// ends the "if IQ[tail1] is available" clause
		    	else begin	// only first instruction was enqueued
						if (fetchbuf0_rfw)
					    rf_vr[ Rt0 ] <= INV;
			    end
				end		
			end
  	endcase
  end
end

always_comb
begin

	rf_v = rf_vr;
	rf_v[0] = 1;

	rf_v[0] = 1;
end

endmodule
