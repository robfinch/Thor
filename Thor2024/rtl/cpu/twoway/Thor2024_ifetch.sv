// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_ifetch.sv
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

module Thor2024_ifetch(rst, clk, hit, irq, branchback, backpc, branchmiss, misspc, missir,
	next_pc, takb, ptakb, pc, pc_i, stall, inst0, inst1, iq, tail0, tail1,
	fetchbuf, fetchbuf0_instr, fetchbuf0_v, fetchbuf0_pc, 
	fetchbuf1_instr, fetchbuf1_v, fetchbuf1_pc,
	commit0_v, commit0_instr, commit0_pc,
	commit1_v, commit1_instr, commit1_pc
);
input rst;
input clk;
input hit;
input irq;
output reg branchback;
output pc_address_t backpc;
input branchmiss;
input pc_address_t misspc;
input pc_address_t next_pc;
input instruction_t missir;
input takb;
output reg ptakb;
output pc_address_t pc;
input pc_address_t pc_i;
output reg stall;
input instruction_t [4:0] inst0;
input instruction_t [4:0] inst1;
input iq_entry_t [7:0] iq;
input que_ndx_t tail0;
input que_ndx_t tail1;
output reg fetchbuf;
output instruction_t [4:0] fetchbuf0_instr;
output reg fetchbuf0_v;
output pc_address_t fetchbuf0_pc;
output instruction_t [4:0] fetchbuf1_instr;
output reg fetchbuf1_v;
output pc_address_t fetchbuf1_pc;
// For RSB
input commit0_v;
input instruction_t commit0_instr;
input pc_address_t commit0_pc;
input commit1_v;
input instruction_t commit1_instr;
input pc_address_t commit1_pc;

reg [3:0] panic;
reg did_branchback;
reg fetchbufA_v;
reg fetchbufB_v;
reg fetchbufC_v;
reg fetchbufD_v;
reg hitd;
address_t ppc;
reg isBB0, isBB1;

reg fetchAB, fetchCD;
instruction_t [4:0] inst0a;
instruction_t [4:0] inst1a;
instruction_t [4:0] fetchbufA_instr;
instruction_t [4:0] fetchbufB_instr;
instruction_t [4:0] fetchbufC_instr;
instruction_t [4:0] fetchbufD_instr;
pc_address_t fetchbufA_pc;
pc_address_t fetchbufB_pc;
pc_address_t fetchbufC_pc;
pc_address_t fetchbufD_pc;
reg buffered, consumed;
pc_address_t pci;
reg takb1;
reg did_branchmiss;
instruction_t micro_ir;
instruction_t micro_instr0, micro_instr1, micro_instr2;
reg fetch_valid;
wire [11:0] next_micro_ip;

Thor2024_micro_code umc0
(
	.micro_ip(pc.micro_ip),
	.micro_ir(micro_ir),
	.next_ip(),
	.instr(micro_instr0)
);
Thor2024_micro_code umc1
(
	.micro_ip(pc.micro_ip+12'd1),
	.micro_ir(micro_ir),
	.next_ip(next_micro_ip),
	.instr(micro_instr1)
);
Thor2024_micro_code umc2
(
	.micro_ip(pc.micro_ip+12'd2),
	.micro_ir(micro_ir),
	.next_ip(),
	.instr(micro_instr2)
);

reg [11:0] mip0,mip1;

function [11:0] fnMip;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_ENTER:	fnMip = 12'h001;
	OP_LEAVE:	fnMip = 12'h00C;
	OP_PUSH:	fnMip = 12'h016;
	OP_POP:		fnMip = 12'h020;
	OP_FLT2:
		case(ir.f2.func)
		FN_FLT1:
			case(ir.f1.func)
			FN_FRES:
				case(ir[26:25])
				2'd1:	fnMip = 12'h080;
				2'd2:	fnMip = 12'h088;
				2'd3: fnMip = 12'h090;
				endcase
			FN_RSQRTE:
				case(ir[26:25])
				2'd0: fnMip = 12'h04D;
				2'd1:	fnMip = 12'h059;
				2'd2:	fnMip = 12'h069;
				2'd3: fnMip = 12'h035;
				endcase
			default:	fnMip = 12'h000;			
			endcase
		FN_FDIV:	fnMip = 12'h027;
		default:	fnMip = 12'h000;
		endcase
	default:	fnMip = 12'h000;
	endcase
end
endfunction

always_comb
	mip0 = fnMip(fetchbuf0_instr[0]);
always_comb
	mip1 = fnMip(fetchbuf1_instr[0]);

always_comb
	fetch_valid = buffered | hit | pc.micro_ip != 12'h000;

always_ff @(posedge clk, posedge rst)
if (rst) begin
	pc <= RSTPC;
	ppc <= RSTPC;
	micro_ir <= {33'd0,OP_NOP};
	ptakb <= 'd0;
	stall <= 1'b0;
	hitd <= 1'b0;
	did_branchback <= 'd0;
	did_branchmiss <= 'd0;
	fetchbuf <= 'd0;
	fetchbufA_v <= INV;
	fetchbufB_v <= INV;
	fetchbufC_v <= INV;
	fetchbufD_v <= INV;
	fetchbufA_pc <= 'd0;
	fetchbufA_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	fetchbufB_pc <= 'd0;
	fetchbufB_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	fetchbufC_pc <= 'd0;
	fetchbufC_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	fetchbufD_pc <= 'd0;
	fetchbufD_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	fetchAB <= 1'b0;
	fetchCD <= 1'b0;
	buffered <= 1'b0;
	consumed = 1'b0;
end
else begin

	did_branchback <= branchback;
	did_branchmiss <= branchmiss;
	stall <= 1'b0;

	if (branchmiss) begin
    pc <= misspc;
    micro_ir <= missir;
    fetchbuf <= 1'b0;
    fetchbufA_v <= INV;
    fetchbufB_v <= INV;
    fetchbufC_v <= INV;
    fetchbufD_v <= INV;
    buffered <= 1'b0;
	end
	else begin
		consumed <= 1'b0;
		if (branchback) begin

	    // update the fetchbuf valid bits as well as fetchbuf itself
	    // ... this must be based on which things are backwards branches, how many things
	    // will get enqueued (0, 1, or 2), and how old the instructions are
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, fetchbufC_v, fetchbufD_v})

			4'b0000	: ;	// do nothing
			4'b0001	: panic <= PANIC_INVALIDFBSTATE;
			4'b0010	: panic <= PANIC_INVALIDFBSTATE;
			4'b0011	: panic <= PANIC_INVALIDFBSTATE;	// this looks like it might be screwy fetchbuf logic

			// because the first instruction has been enqueued, 
			// we must have noted this in the previous cycle.
			// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
			// this looks like the following:
			//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - enqueued fbA, stomped on fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
			4'b0100: 
				begin
					if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr[0])} == {VAL, TRUE}) begin
						tFetchCD(0);
						if (fetch_valid)
							consumed <= 1'b1;
		    		fetchbufB_v <= iq[tail0].v;	// if it can be queued, it will
		    		fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else panic <= PANIC_BRANCHBACK;
			  end

			4'b0101: panic <= PANIC_INVALIDFBSTATE;
			4'b0110: panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched an INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - enqueued fbA, but not fbB, recognized branchback in fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbB, but fetched from backwards target
			//   cycle 3 - where we are now ... update fetchbufB_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b0111:
				begin
					if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr[0])} == {VAL, TRUE}) begin
				    fetchbufB_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufB_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufB_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else panic <= PANIC_BRANCHBACK;
		    end

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbA holding a branchback
			//   cycle 1 - stomped on fbB, but could not enqueue fbA, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufA_v appropriately
			4'b1000:
				begin
					if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr[0])} == {VAL, TRUE}) begin
						tFetchCD(0);
						if (fetch_valid)
							consumed <= 1'b1;
		    		fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
		    		fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else panic <= PANIC_BRANCHBACK;
		    end

			4'b1001: panic <= PANIC_INVALIDFBSTATE;
			4'b1010: panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbA holding a branchback
			//   cycle 1 - stomped on fbB, but could not enqueue fbA, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbA, but fetched from backwards target
			//   cycle 3 - where we are now ... set fetchbufA_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b1011:
				begin
					if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr[0])} == {VAL, TRUE}) begin
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else panic <= PANIC_BRANCHBACK;
		    end

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
				begin
					if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr[0])} == {VAL, TRUE}) begin
				    // has to be first scenario
				    pc <= backpc;
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufB_v <= INV;		// stomp on it
				    if (~iq[tail0].v)	fetchbuf <= 1'b0;
					end
					else if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr[0])} == {VAL, TRUE}) begin
				    if (did_branchback) begin
				    	tFetchCD(0);
				    	if (fetch_valid)
				    		consumed <= 1'b1;
							fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
							fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
							fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
				    end
				    else begin
							pc <= backpc;
							fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
							fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
							if (~iq[tail0].v & ~iq[tail1].v)	fetchbuf <= 1'b0;
				    end
					end
					else panic <= PANIC_BRANCHBACK;
		    end

			4'b1101: panic <= PANIC_INVALIDFBSTATE;
			4'b1110: panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched an INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - enqueued neither fbA nor fbB, recognized branchback in fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbB, but fetched from backwards target
			//   cycle 3 - where we are now ... update fetchbufX_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b1111:
				begin
					if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr[0])} == {VAL, TRUE}) begin
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else panic <= PANIC_BRANCHBACK;
		    end

		  endcase
	    else case ({fetchbufC_v, fetchbufD_v, fetchbufA_v, fetchbufB_v})

			4'b0000: ; // do nothing
			4'b0001: panic <= PANIC_INVALIDFBSTATE;
			4'b0010: panic <= PANIC_INVALIDFBSTATE;
			4'b0011: panic <= PANIC_INVALIDFBSTATE;	// this looks like it might be screwy fetchbuf logic

			// because the first instruction has been enqueued, 
			// we must have noted this in the previous cycle.
			// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
			// this looks like the following:
			//   cycle 0 - fetched a INSTR+BEQ, with fbD holding a branchback
			//   cycle 1 - enqueued fbC, stomped on fbD, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
			4'b0100:
				begin
					if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr[0])} == {VAL, TRUE}) begin
						tFetchAB(0);
						if (fetch_valid)
							consumed <= 1'b1;
		    		fetchbufD_v <= iq[tail0].v;	// if it can be queued, it will
		    		fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else panic <= PANIC_BRANCHBACK;
		    end

			4'b0101: panic <= PANIC_INVALIDFBSTATE;
			4'b0110: panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched an INSTR+BEQ, with fbD holding a branchback
			//   cycle 1 - enqueued fbC, but not fbD, recognized branchback in fbD, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbD, but fetched from backwards target
			//   cycle 3 - where we are now ... update fetchbufD_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b0111:
				begin
					if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr[0])} == {VAL, TRUE}) begin
				    fetchbufD_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufD_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufD_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else panic <= PANIC_BRANCHBACK;
		    end

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbC holding a branchback
			//   cycle 1 - stomped on fbD, but could not enqueue fbC, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufC_v appropriately
			4'b1000:
				begin
					if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr[0])} == {VAL, TRUE}) begin
						tFetchAB(0);
						if (fetch_valid)
							consumed <= 1'b1;
			    	fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
			    	fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else panic <= PANIC_BRANCHBACK;
		    end

			4'b1001: panic <= PANIC_INVALIDFBSTATE;
			4'b1010: panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbC holding a branchback
			//   cycle 1 - stomped on fbD, but could not enqueue fbC, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbC, but fetched from backwards target
			//   cycle 3 - where we are now ... set fetchbufC_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b1011:
				begin
					if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr[0])} == {VAL, TRUE}) begin
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else panic <= PANIC_BRANCHBACK;
		    end

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
				begin
					if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr[0])} == {VAL, TRUE}) begin
				    // has to be first scenario
				    pc <= backpc;
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufD_v <= INV;		// stomp on it
				    if (~iq[tail0].v)	fetchbuf <= 1'b0;
					end
					else if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr[0])} == {VAL, TRUE}) begin
				    if (did_branchback) begin
				    	tFetchAB(0);
				    	if (fetch_valid)
				    		consumed <= 1'b1;
							fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
							fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
							fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
				    end
				    else begin
							pc <= backpc;
							fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
							fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
							if (~iq[tail0].v & ~iq[tail1].v)	fetchbuf <= 1'b0;
				    end
					end
					else panic <= PANIC_BRANCHBACK;
		    end

			4'b1101: panic <= PANIC_INVALIDFBSTATE;
			4'b1110: panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched an INSTR+BEQ, with fbD holding a branchback
			//   cycle 1 - enqueued neither fbC nor fbD, recognized branchback in fbD, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbD, but fetched from backwards target
			//   cycle 3 - where we are now ... update fetchbufX_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b1111:
				begin
					if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr[0])} == {VAL, TRUE}) begin
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr[0])} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else panic <= PANIC_BRANCHBACK;
		    end
	    endcase

		end // if branchback

		else begin	// there is no branchback in the system
	    //
	    // update fetchbufX_v and fetchbuf ... relatively simple, as
	    // there are no backwards branches in the mix
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, ~iq[tail0].v, ~iq[tail1].v})
			4'b00_00: ;	// do nothing
			4'b00_01: panic <= PANIC_INVALIDIQSTATE;
			4'b00_10: ;	// do nothing
			4'b00_11: ;	// do nothing
			4'b01_00: ;	// do nothing
			4'b01_01: panic <= PANIC_INVALIDIQSTATE;

			4'b01_10,
			4'b01_11:
				begin	// enqueue fbB and flip fetchbuf
					fetchbufB_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end

			4'b10_00: ;	// do nothing
			4'b10_01: panic <= PANIC_INVALIDIQSTATE;

			4'b10_10,
			4'b10_11:
				begin	// enqueue fbA and flip fetchbuf
					fetchbufA_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end

			4'b11_00: ;	// do nothing
			4'b11_01: panic <= PANIC_INVALIDIQSTATE;

			4'b11_10:
				begin	// enqueue fbA but leave fetchbuf
					fetchbufA_v <= INV;
			  end

			4'b11_11:
				begin	// enqueue both and flip fetchbuf
					fetchbufA_v <= INV;
					fetchbufB_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end
		  endcase
		  else case ({fetchbufC_v, fetchbufD_v, ~iq[tail0].v, ~iq[tail1].v})
			4'b00_00: ;	// do nothing
			4'b00_01: panic <= PANIC_INVALIDIQSTATE;
			4'b00_10: ;	// do nothing
			4'b00_11: ;	// do nothing
			4'b01_00: ;	// do nothing
			4'b01_01: panic <= PANIC_INVALIDIQSTATE;

			4'b01_10,
			4'b01_11:
				begin	// enqueue fbD and flip fetchbuf
					fetchbufD_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end

			4'b10_00: ;	// do nothing
			4'b10_01: panic <= PANIC_INVALIDIQSTATE;

			4'b10_10,
			4'b10_11:
				begin	// enqueue fbC and flip fetchbuf
					fetchbufC_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end

			4'b11_00: ;	// do nothing
			4'b11_01: panic <= PANIC_INVALIDIQSTATE;

			4'b11_10:
				begin	// enqueue fbC but leave fetchbuf
					fetchbufC_v <= INV;
			  end

			4'b11_11:
				begin	// enqueue both and flip fetchbuf
					fetchbufC_v <= INV;
					fetchbufD_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end
		  endcase
		    //
		    // get data iff the fetch buffers are empty
		    //
		   
		  if (fetchbufA_v == INV && fetchbufB_v == INV) begin
		  	tFetchAB(1);
				if (fetch_valid)
					consumed <= 1'b1;
	      // fetchbuf steering logic correction
	      if (fetchbufC_v==INV && fetchbufD_v==INV)
	        fetchbuf <= 1'b0;
	    end
	    else if (fetchbufC_v == INV && fetchbufD_v == INV) begin
	    	tFetchCD(1);
				if (fetch_valid)
					consumed <= 1'b1;
			end
		end
	end
	if (0) begin
		if (fetchAB)
			tFetchAB(1);
		else if (fetchCD)
			tFetchCD(1);
	end
end

always_comb
	fetchbuf0_instr = (fetchbuf == 1'b0) ? fetchbufA_instr : fetchbufC_instr;
always_comb
	fetchbuf0_v     = (fetchbuf == 1'b0) ? fetchbufA_v     : fetchbufC_v    ;
always_comb
	fetchbuf0_pc    = (fetchbuf == 1'b0) ? fetchbufA_pc    : fetchbufC_pc   ;
always_comb
	fetchbuf1_instr = (fetchbuf == 1'b0) ? fetchbufB_instr : fetchbufD_instr;
always_comb
	fetchbuf1_v     = (fetchbuf == 1'b0) ? fetchbufB_v     : fetchbufD_v    ;
always_comb
	fetchbuf1_pc    = (fetchbuf == 1'b0) ? fetchbufB_pc    : fetchbufD_pc   ;

//
// set branchback and backpc values ... ignore branches in fetchbuf slots not ready for enqueue yet
//
reg rsb_push;
reg rsb_pop, rsb_popc;
pc_address_t ret_pc;
pc_address_t rsb_pc;

always_comb
	isBB0 = fnIsBackBranch(fetchbuf0_instr[0]);
always_comb
	isBB1 = fnIsBackBranch(fetchbuf1_instr[0]);
always_comb
	branchback = ((fetchbuf0_v & isBB0) | (fetchbuf1_v & isBB1)
			|| (SUPPORT_RSB && fetchbuf0_v && fnIsRet(fetchbuf0_instr[0]))
			|| (SUPPORT_RSB && fetchbuf1_v && fnIsRet(fetchbuf1_instr[0]) && fetchbuf1_v)
			)
			;
always_comb
	if (SUPPORT_RSB && fetchbuf0_v && fnIsRet(fetchbuf0_instr[0]))
		backpc = ret_pc;
	else if (SUPPORT_RSB && fetchbuf0_v && fetchbuf1_v && fnIsRet(fetchbuf1_instr[0]))
		backpc = ret_pc;
	else if (fetchbuf0_v && isBB0) begin
		if (fnIsMacroInstr(fetchbuf0_instr[0])) begin
			backpc.pc = fetchbuf0_pc.pc;
			backpc.micro_ip = mip0;
		end
		else begin
			backpc.pc = fetchbuf0_pc.pc + fnBranchDisp(fetchbuf0_instr[0]);
			backpc.micro_ip = 'd0;
		end
	end
	else if (fetchbuf1_v && isBB1) begin
		if (fnIsMacroInstr(fetchbuf1_instr[0])) begin
			backpc.pc = fetchbuf1_pc.pc;
			backpc.micro_ip = mip1;
		end
		else begin
			backpc.pc = fetchbuf1_pc.pc + fnBranchDisp(fetchbuf1_instr[0]);
			backpc.micro_ip = 'd0;
		end
	end

generate begin : gRSB
	if (SUPPORT_RSB) begin
		// If there was a call type instruction that did not commit, then pop the RSB
		// to keep it in sync.
		always_comb
			if (~commit0_v && fnIsCallType(commit0_instr[0]))
				rsb_popc = 1'b1;
			else if (commit0_v & ~commit1_v && fnIsCallType(commit1_instr[0]))
				rsb_popc = 1'b1;
			else
				rsb_popc = 1'b0;

		// "Push" call instructions during the fetch phase. Even though the call may 
		// eventually turn out not to be executed. It is pushed in fetch to allow a 
		// return shortly after the call.
		always_comb
			if (fetchbuf0_v && fnIsCallType(fetchbuf0_instr[0])) begin
				rsb_push = 1'b1;
				rsb_pc.pc = fetchbuf0_pc.pc + INSN_LEN;
				rsb_pc.micro_ip = 12'h0;
			end
			else if (fetchbuf0_v && fetchbuf1_v && fnIsCallType(fetchbuf1_instr[0])) begin
				rsb_push = 1'b1;
				rsb_pc.pc = fetchbuf1_pc.pc + INSN_LEN;
				rsb_pc.micro_ip = 12'h0;
			end
			else begin
				rsb_push = 1'b0;
				rsb_pc.pc = fetchbuf0_pc.pc + INSN_LEN;
				rsb_pc.micro_ip = 12'h0;
			end

		always_comb
			if (fetchbuf0_v && fnIsRet(fetchbuf0_instr[0]))
				rsb_pop = 1'b1;
			else if (fetchbuf0_v && fetchbuf1_v
				&& !fnIsFlowCtrl(fetchbuf0_instr[0]) && fnIsRet(fetchbuf1_instr[0]))
				rsb_pop = 1'b1;
			else
				rsb_pop = 1'b0;

		Thor2024_rsb ursb1
		(
			.rst(rst),
			.clk(clk),
			.pop(rsb_pop|rsb_popc),
			.push(rsb_push),
			.pc(rsb_pc),
			.o(ret_pc)
		);
	end
end
endgenerate

task tFetchAB;
input flag;
begin
	if (pc.micro_ip != 12'h000) begin
		fetchAB <= 1'b1;
  	fetchbufA_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,micro_instr1,micro_instr0};
	  fetchbufB_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,micro_instr2,micro_instr1};
	  fetchbufA_v <= VAL;
	  fetchbufA_pc <= pc;
	  fetchbufB_v <= VAL;
	  fetchbufB_pc.pc <= pc.pc;
	  fetchbufB_pc.micro_ip <= pc.micro_ip+1;
	  buffered <= 1'b0;
	  ptakb <= takb1;
	  if (~irq) begin
	  	ppc <= pc;
	  	if (next_micro_ip=='d0)
	  		pc <= {pc.pc + 4'd5,12'h000};
	  	else
		  	pc <= {pc.pc,next_micro_ip};
		  takb1 <= takb;
		end
	end
	else if (hit) begin
		fetchAB <= 1'b0;
	  fetchbufA_instr <= inst0;
	  fetchbufB_instr <= inst1;
	  fetchbufA_v <= VAL;
	  fetchbufA_pc <= pc_i;
	  fetchbufB_v <= VAL;
	  fetchbufB_pc <= fnPCInc(pc_i);// + {INSN_LEN,12'h000};
	  buffered <= 1'b0;
	  ptakb <= takb1;
	  if (hit & ~irq) begin
	  	ppc <= pc;
		  pc <= next_pc;
		  takb1 <= takb;
		end
	end
	else begin
	  fetchbufA_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	  fetchbufB_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	  fetchbufA_v <= INV;
	  fetchbufB_v <= INV;
		fetchAB <= 1'b1;
	end
end
endtask

task tFetchCD;
input flag;
begin
	if (pc.micro_ip != 12'h000) begin
		fetchCD <= 1'b1;
  	fetchbufC_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,micro_instr1,micro_instr0};
  	fetchbufD_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,micro_instr2,micro_instr1};
	  fetchbufC_v <= VAL;
	  fetchbufC_pc <= pc;
	  fetchbufD_v <= VAL;
	  fetchbufD_pc.pc <= pc.pc;
	  fetchbufD_pc.micro_ip <= pc.micro_ip+1;
	  buffered <= 1'b0;
	  ptakb <= takb1;
	  if (~irq) begin
	  	ppc <= pc;
	  	if (next_micro_ip=='d0)
	  		pc <= {pc.pc + 4'd5,12'h000};
	  	else
		  	pc <= {pc.pc,next_micro_ip};
		  takb1 <= takb;
		end
	end
	else if (hit) begin
		fetchCD <= 1'b0;
	  fetchbufC_instr <= inst0;
	  fetchbufD_instr <= inst1;
	  fetchbufC_v <= VAL;
	  fetchbufC_pc <= pc_i;
	  fetchbufD_v <= VAL;
	  fetchbufD_pc <= fnPCInc(pc_i);// + {INSN_LEN,12'h000};
	  buffered <= 1'b0;
	  ptakb <= takb1;
	  if (hit & ~irq) begin
	  	ppc <= pc;
		  pc <= next_pc;
		  takb1 <= takb;
	  end
	end
	else begin
	  fetchbufC_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	  fetchbufD_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	  fetchbufC_v <= INV;
	  fetchbufD_v <= INV;
		fetchCD <= 1'b1;
	end
end
endtask

endmodule
