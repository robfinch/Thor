// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Thor2024_PCReg.sv
// - program counter
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

module Thor2024_PCReg(rst, clk, irq, hit, next_pc, next_micro_ip, backpc,
	branchmiss, misspc, branchback, fetchbuf,
	fetchbufA_v, fetchbufB_v, fetchbufC_v, fetchbufD_v,
	backbrA, backbrB, backbrC, backbrD, 
	pc
);
input rst;
input clk;
input irq;
input hit;
input pc_address_t next_pc;
input [11:0] next_micro_ip;
input pc_address_t backpc;
input branchmiss;
input pc_address_t misspc;
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
output pc_address_t pc;

reg did_branchback;
always_ff @(posedge clk)
if (rst)
	did_branchback <= 1'b0;
else
	did_branchback <= branchback;

always_ff @(posedge clk)
if (rst)
	pc <= RSTPC;
else begin

	if (branchmiss)
    pc <= misspc;
	else begin
		if (branchback) begin

	    // update the fetchbuf valid bits as well as fetchbuf itself
	    // ... this must be based on which things are backwards branches, how many things
	    // will get enqueued (0, 1, or 2), and how old the instructions are
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, fetchbufC_v, fetchbufD_v})

			// because the first instruction has been enqueued, 
			// we must have noted this in the previous cycle.
			// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
			// this looks like the following:
			//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - enqueued fbA, stomped on fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
			4'b0100: 
				if (backbrB)
					tUpdatePC();

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbA holding a branchback
			//   cycle 1 - stomped on fbB, but could not enqueue fbA, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufA_v appropriately
			4'b1000:
				if (backbrA)
					tUpdatePC();

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
				if (backbrA)
			    // has to be first scenario
			    pc <= backpc;
				else if (backbrB) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			default	: ;	// do nothing

		  endcase
	    else case ({fetchbufC_v, fetchbufD_v, fetchbufA_v, fetchbufB_v})

			// because the first instruction has been enqueued, 
			// we must have noted this in the previous cycle.
			// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
			// this looks like the following:
			//   cycle 0 - fetched a INSTR+BEQ, with fbD holding a branchback
			//   cycle 1 - enqueued fbC, stomped on fbD, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
			4'b0100:
				if (backbrD)
					tUpdatePC();

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbC holding a branchback
			//   cycle 1 - stomped on fbD, but could not enqueue fbC, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufC_v appropriately
			4'b1000:
				if (backbrC)
					tUpdatePC();

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
				if (backbrC)
			    // has to be first scenario
			    pc <= backpc;
				else if (backbrD) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			default:	;
	    endcase

		end // if branchback

		else begin	// there is no branchback in the system
	    //
	    // get data iff the fetch buffers are empty
	    //
		  if (fetchbufA_v == INV && fetchbufB_v == INV)
		  	tUpdatePC();
	    else if (fetchbufC_v == INV && fetchbufD_v == INV)
	    	tUpdatePC();
		end
	end
end

task tUpdatePC;
begin
	if (|pc[11:0]) begin
	  if (~irq) begin
	  	if (~|next_micro_ip)
	  		pc <= pc + 16'h5000;
  		pc[11:0] <= next_micro_ip;
		end
	end
	else if (hit) begin
	  if (~irq) begin
		  pc <= next_pc;
		end
	end
end
endtask

endmodule
