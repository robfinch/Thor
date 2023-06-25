// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Thor2024_micro_ir.sv
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

import Thor2024pkg::*;

module Thor2024_micro_ir(rst, clk, branchmiss, branchback, fetchbuf,
	fetchbufA_v, fetchbufB_v, fetchbufC_v, fetchbufD_v,
	backbrA, backbrB, backbrC, backbrD, 
	fetchbufA_instr, fetchbufB_instr, fetchbufC_instr, fetchbufD_instr, 
	micro_ir
);
input rst;
input clk;
input branchmiss;
input branchback;
input fetchbuf;
input fetchbufA_v;
input fetchbufB_v;
input fetchbufC_v;
input fetchbufD_v;
input backbrA;
input backbrB;
input backbrC;
input backbrD;
input instruction_t fetchbufA_instr;
input instruction_t fetchbufB_instr;
input instruction_t fetchbufC_instr;
input instruction_t fetchbufD_instr;
output instruction_t micro_ir;

reg did_micro_op;
always_ff @(posedge clk)
if (rst)
	did_micro_op <= 1'b0;
else
	did_micro_op <= branchback;

always_ff @(posedge clk)
if (rst)
	micro_ir <= 40'hFFFFFFFFFF;
else begin

	if (!branchmiss) begin
		if (branchback) begin

	    // update the fetchbuf valid bits as well as fetchbuf itself
	    // ... this must be based on which things are backwards branches, how many things
	    // will get enqueued (0, 1, or 2), and how old the instructions are
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, fetchbufC_v, fetchbufD_v})

			// if fbB has the branchback, can't immediately tell which of the following scenarios it is:
			//   cycle 0 - fetched a pair of instructions, one or both of which is a branchback
			//   cycle 1 - where we are now.  stomp, enqueue, and update pc0/pc1
			// or
			//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - could not enqueue fbA or fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufX_v appropriately
			// if fbA has the branchback, then it is scenario 1.
			// if fbB has it: if pc0 == fbB_pc, then it is the former scenario, else it is the latter
			4'b1100:
				if (backbrA) begin
			    // has to be first scenario
			    micro_ir <= fetchbufA_instr;
			  end
				else if (backbrB) begin
			    if (!did_micro_op)
				    micro_ir <= fetchbufB_instr;
				end

			default	: ;	// do nothing

		  endcase
	    else case ({fetchbufC_v, fetchbufD_v, fetchbufA_v, fetchbufB_v})

			// if fbD has the branchback, can't immediately tell which of the following scenarios it is:
			//   cycle 0 - fetched a pair of instructions, one or both of which is a branchback
			//   cycle 1 - where we are now.  stomp, enqueue, and update pc0/pc1
			// or
			//   cycle 0 - fetched a INSTR+BEQ, with fbD holding a branchback
			//   cycle 1 - could not enqueue fbC or fbD, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufX_v appropriately
			// if fbC has the branchback, then it is scenario 1.
			// if fbD has it: if pc0 == fbB_pc, then it is the former scenario, else it is the latter
			4'b1100:
				if (backbrC) begin
			    // has to be first scenario
			    micro_ir <= fetchbufC_instr;
			  end
				else if (backbrD) begin
			    if (!did_micro_op)
						micro_ir <= fetchbufD_instr;
				end

			default:	;
	    endcase

		end // if branchback
	end
end

endmodule

