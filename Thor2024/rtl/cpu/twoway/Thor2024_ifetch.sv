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
	next_pc, takb, ptakb, pc, inst0, inst1, iq, tail0, tail1,
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
reg isBB0, isBB1;

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
pc_address_t pci;
reg takb1;
instruction_t micro_ir;
instruction_t micro_instr0, micro_instr1, micro_instr2;
wire [11:0] next_micro_ip;

Thor2024_micro_code umc0
(
	.micro_ip(pc[11:0]),
	.micro_ir(micro_ir),
	.next_ip(),
	.instr(micro_instr0)
);
Thor2024_micro_code umc1
(
	.micro_ip(pc[11:0]+12'd1),
	.micro_ir(micro_ir),
	.next_ip(next_micro_ip),
	.instr(micro_instr1)
);
Thor2024_micro_code umc2
(
	.micro_ip(pc[11:0]+12'd2),
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

reg backbrA, backbrB, backbrC, backbrD;
always_comb
	backbrA = fnIsBackBranch(fetchbufA_instr[0]);
always_comb
	backbrB = fnIsBackBranch(fetchbufB_instr[0]);
always_comb
	backbrC = fnIsBackBranch(fetchbufC_instr[0]);
always_comb
	backbrD = fnIsBackBranch(fetchbufD_instr[0]);
	
Thor2024_PCReg upcr1
(
	.rst(rst),
	.clk(clk),
	.irq(irq),
	.hit(hit),
	.next_pc(next_pc),
	.next_micro_ip(next_micro_ip),
	.backpc(backpc),
	.branchmiss(branchmiss),
	.misspc(misspc),
	.branchback(branchback),
	.fetchbuf(fetchbuf),
	.fetchbufA_v(fetchbufA_v),
	.fetchbufB_v(fetchbufB_v),
	.fetchbufC_v(fetchbufC_v),
	.fetchbufD_v(fetchbufD_v),
	.backbrA(backbrA),
	.backbrB(backbrB),
	.backbrC(backbrC),
	.backbrD(backbrD),
	.pc(pc)
);

always_ff @(posedge clk)
if (rst)
	did_branchback <= 'd0;
else
	did_branchback <= branchback;

Thor2024_micro_ir umir1
(
	.rst(rst),
	.clk(clk),
	.branchmiss(branchmiss),
	.branchback(branchback),
	.fetchbuf(fetchbuf),
	.fetchbufA_v(fetchbufA_v),
	.fetchbufB_v(fetchbufB_v),
	.fetchbufC_v(fetchbufC_v),
	.fetchbufD_v(fetchbufD_v),
	.backbrA(backbrA),
	.backbrB(backbrB),
	.backbrC(backbrC),
	.backbrD(backbrD), 
	.fetchbufA_instr(fetchbufA_instr[0]),
	.fetchbufB_instr(fetchbufB_instr[0]),
	.fetchbufC_instr(fetchbufC_instr[0]),
	.fetchbufD_instr(fetchbufD_instr[0]), 
	.micro_ir(micro_ir)
);

always_ff @(posedge clk)
if (rst) begin
	ptakb <= 'd0;
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
end
else begin

	if (branchmiss) begin
    fetchbuf <= 1'b0;
    fetchbufA_v <= INV;
    fetchbufB_v <= INV;
    fetchbufC_v <= INV;
    fetchbufD_v <= INV;
	end
	else begin
		if (branchback) begin

	    // update the fetchbuf valid bits as well as fetchbuf itself
	    // ... this must be based on which things are backwards branches, how many things
	    // will get enqueued (0, 1, or 2), and how old the instructions are
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, fetchbufC_v, fetchbufD_v})

			4'b0000	: ;	// do nothing
			4'b0001	: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b0010	: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b0011	: if (SIM) panic <= PANIC_INVALIDFBSTATE;	// this looks like it might be screwy fetchbuf logic

			// because the first instruction has been enqueued, 
			// we must have noted this in the previous cycle.
			// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
			// this looks like the following:
			//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - enqueued fbA, stomped on fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
			4'b0100: 
				if (backbrB) begin
					tFetchCD();
	    		fetchbufB_v <= iq[tail0].v;	// if it can be queued, it will
	    		fetchbuf <= fetchbuf + ~iq[tail0].v;
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

			4'b0101: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b0110: if (SIM) panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched an INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - enqueued fbA, but not fbB, recognized branchback in fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbB, but fetched from backwards target
			//   cycle 3 - where we are now ... update fetchbufB_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b0111:
				if (backbrB|backbrC|backbrD) begin
			    fetchbufB_v <= iq[tail0].v;	// if it can be queued, it will
			    fetchbuf <= fetchbuf + ~iq[tail0].v;
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbA holding a branchback
			//   cycle 1 - stomped on fbB, but could not enqueue fbA, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufA_v appropriately
			4'b1000:
				if (backbrA) begin
					tFetchCD();
	    		fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
	    		fetchbuf <= fetchbuf + ~iq[tail0].v;
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

			4'b1001: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b1010: if (SIM) panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbA holding a branchback
			//   cycle 1 - stomped on fbB, but could not enqueue fbA, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbA, but fetched from backwards target
			//   cycle 3 - where we are now ... set fetchbufA_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b1011:
				if (backbrA|backbrC|backbrD) begin
			    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
			    fetchbuf <= fetchbuf + ~iq[tail0].v;
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

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
			    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
			    fetchbufB_v <= INV;		// stomp on it
			    //if (~iq[tail0].v)	fetchbuf <= 1'b0; // fetchbuf stays at zero
				end
				else if (backbrB) begin
			    if (did_branchback) begin
			    	tFetchCD();
						fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
						if (SUPPORT_Q2) begin
							fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
							fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
						end
			    end
			    else begin
						fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
						if (SUPPORT_Q2) begin
							fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
							//if (~iq[tail0].v & ~iq[tail1].v)	fetchbuf <= 1'b0;	// fetchbuf stays at zero
						end
			    end
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

			4'b1101: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b1110: if (SIM) panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched an INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - enqueued neither fbA nor fbB, recognized branchback in fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbB, but fetched from backwards target
			//   cycle 3 - where we are now ... update fetchbufX_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b1111:
				if (backbrB|backbrC|backbrD) begin
			    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
			    if (SUPPORT_Q2) begin
			    	fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
			    	fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
			  	end
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

		  endcase
	    else case ({fetchbufC_v, fetchbufD_v, fetchbufA_v, fetchbufB_v})

			4'b0000: ; // do nothing
			4'b0001: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b0010: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b0011: if (SIM) panic <= PANIC_INVALIDFBSTATE;	// this looks like it might be screwy fetchbuf logic

			// because the first instruction has been enqueued, 
			// we must have noted this in the previous cycle.
			// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
			// this looks like the following:
			//   cycle 0 - fetched a INSTR+BEQ, with fbD holding a branchback
			//   cycle 1 - enqueued fbC, stomped on fbD, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
			4'b0100:
				if (backbrD) begin
					tFetchAB();
	    		fetchbufD_v <= iq[tail0].v;	// if it can be queued, it will
	    		fetchbuf <= fetchbuf + ~iq[tail0].v;
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

			4'b0101: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b0110: if (SIM) panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched an INSTR+BEQ, with fbD holding a branchback
			//   cycle 1 - enqueued fbC, but not fbD, recognized branchback in fbD, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbD, but fetched from backwards target
			//   cycle 3 - where we are now ... update fetchbufD_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b0111:
				if (backbrD|backbrA|backbrB) begin
			    fetchbufD_v <= iq[tail0].v;	// if it can be queued, it will
			    fetchbuf <= fetchbuf + ~iq[tail0].v;
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbC holding a branchback
			//   cycle 1 - stomped on fbD, but could not enqueue fbC, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufC_v appropriately
			4'b1000:
				if (backbrC) begin
					tFetchAB();
		    	fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
		    	fetchbuf <= fetchbuf + ~iq[tail0].v;
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

			4'b1001: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b1010: if (SIM) panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched a BEQ+INSTR, with fbC holding a branchback
			//   cycle 1 - stomped on fbD, but could not enqueue fbC, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbC, but fetched from backwards target
			//   cycle 3 - where we are now ... set fetchbufC_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b1011:
				if (backbrC|backbrA|backbrB) begin
			    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
			    fetchbuf <= fetchbuf + ~iq[tail0].v;
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

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
			    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
			    fetchbufD_v <= INV;		// stomp on it
			    //if (~iq[tail0].v)	fetchbuf <= 1'b1;	// fetcbuf stays at one
				end
				else if (backbrD) begin
			    if (did_branchback) begin
			    	tFetchAB();
						fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
						if (SUPPORT_Q2) begin
							fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
							fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
						end
			    end
			    else begin
						fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
						if (SUPPORT_Q2) begin
							fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
							// if (~iq[tail0].v & ~iq[tail1].v)	fetchbuf <= 1'b1; // fetchbuf stays at one
						end
			    end
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;

			4'b1101: if (SIM) panic <= PANIC_INVALIDFBSTATE;
			4'b1110: if (SIM) panic <= PANIC_INVALIDFBSTATE;

			// this looks like the following:
			//   cycle 0 - fetched an INSTR+BEQ, with fbD holding a branchback
			//   cycle 1 - enqueued neither fbC nor fbD, recognized branchback in fbD, stalled fetch + updated pc0/pc1
			//   cycle 2 - still could not enqueue fbD, but fetched from backwards target
			//   cycle 3 - where we are now ... update fetchbufX_v appropriately
			//
			// however -- if there are backwards branches in the latter two slots, it is more complex.
			// simple solution: leave it alone and wait until we are through with the first two slots.
			4'b1111:
				if (backbrD|backbrA|backbrB) begin
			    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
			    if (SUPPORT_Q2) begin
			    	fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
			    	fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
			  	end
				end
				else if (SIM) panic <= PANIC_BRANCHBACK;
	    endcase

		end // if branchback

		else begin	// there is no branchback in the system
	    //
	    // update fetchbufX_v and fetchbuf ... relatively simple, as
	    // there are no backwards branches in the mix
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, ~iq[tail0].v, ~iq[tail1].v})
			4'b00_00: ;	// do nothing
			4'b00_01: if (SIM) panic <= PANIC_INVALIDIQSTATE;
			4'b00_10: ;	// do nothing
			4'b00_11: ;	// do nothing
			4'b01_00: ;	// do nothing
			4'b01_01: if (SIM) panic <= PANIC_INVALIDIQSTATE;

			4'b01_10,
			4'b01_11:
				begin	// enqueue fbB and flip fetchbuf
					fetchbufB_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end

			4'b10_00: ;	// do nothing
			4'b10_01: if (SIM) panic <= PANIC_INVALIDIQSTATE;

			4'b10_10,
			4'b10_11:
				begin	// enqueue fbA and flip fetchbuf
					fetchbufA_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end

			4'b11_00: ;	// do nothing
			4'b11_01: if (SIM) panic <= PANIC_INVALIDIQSTATE;

			4'b11_10:
				begin	// enqueue fbA but leave fetchbuf
					fetchbufA_v <= INV;
			  end

			4'b11_11:
				begin	// enqueue both and flip fetchbuf
					fetchbufA_v <= INV;
					if (SUPPORT_Q2) begin
						fetchbufB_v <= INV;
						fetchbuf <= ~fetchbuf;
					end
			  end
		  endcase
		  else case ({fetchbufC_v, fetchbufD_v, ~iq[tail0].v, ~iq[tail1].v})
			4'b00_00: ;	// do nothing
			4'b00_01: if (SIM) panic <= PANIC_INVALIDIQSTATE;
			4'b00_10: ;	// do nothing
			4'b00_11: ;	// do nothing
			4'b01_00: ;	// do nothing
			4'b01_01: if (SIM) panic <= PANIC_INVALIDIQSTATE;

			4'b01_10,
			4'b01_11:
				begin	// enqueue fbD and flip fetchbuf
					fetchbufD_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end

			4'b10_00: ;	// do nothing
			4'b10_01: if (SIM) panic <= PANIC_INVALIDIQSTATE;

			4'b10_10,
			4'b10_11:
				begin	// enqueue fbC and flip fetchbuf
					fetchbufC_v <= INV;
					fetchbuf <= ~fetchbuf;
			  end

			4'b11_00: ;	// do nothing
			4'b11_01: if (SIM) panic <= PANIC_INVALIDIQSTATE;

			4'b11_10:
				begin	// enqueue fbC but leave fetchbuf
					fetchbufC_v <= INV;
			  end

			4'b11_11:
				begin	// enqueue both and flip fetchbuf
					fetchbufC_v <= INV;
					if (SUPPORT_Q2) begin
						fetchbufD_v <= INV;
						fetchbuf <= ~fetchbuf;
					end
			  end
		  endcase
		    //
		    // get data iff the fetch buffers are empty
		    //
		   
		  if (fetchbufA_v == INV && fetchbufB_v == INV) begin
		  	tFetchAB();
	      // fetchbuf steering logic correction
	      if (fetchbufC_v==INV && fetchbufD_v==INV)
	        fetchbuf <= 1'b0;
	    end
	    else if (fetchbufC_v == INV && fetchbufD_v == INV) begin
	    	tFetchCD();
			end
		end
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
begin
	if (SUPPORT_RSB && fetchbuf0_v && fnIsRet(fetchbuf0_instr[0]))
		backpc = ret_pc;
	else if (SUPPORT_RSB && fetchbuf0_v && fetchbuf1_v && fnIsRet(fetchbuf1_instr[0]))
		backpc = ret_pc;
	else if (fetchbuf0_v && isBB0) begin
		if (fnIsMacroInstr(fetchbuf0_instr[0])) begin
			backpc = fetchbuf0_pc;
			backpc[11:0] = mip0;
		end
		else begin
			backpc = fetchbuf0_pc + {fnBranchDisp(fetchbuf0_instr[0]),12'h000};
			backpc[11:0] = 'd0;
		end
	end
	else if (fetchbuf1_v && isBB1) begin
		if (fnIsMacroInstr(fetchbuf1_instr[0])) begin
			backpc = fetchbuf1_pc;
			backpc[11:0] = mip1;
		end
		else begin
			backpc = fetchbuf1_pc + {fnBranchDisp(fetchbuf1_instr[0]),12'h000};
			backpc[11:0] = 'd0;
		end
	end
	// To avoid a latch
	else
		backpc = pc;
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
				rsb_pc = fetchbuf0_pc + 16'h5000;
				rsb_pc[11:0] = 'd0;
			end
			else if (fetchbuf0_v && fetchbuf1_v && fnIsCallType(fetchbuf1_instr[0])) begin
				rsb_push = 1'b1;
				rsb_pc = fetchbuf1_pc + 16'h5000;
				rsb_pc[11:0] = 'd0;
			end
			else begin
				rsb_push = 1'b0;
				rsb_pc = fetchbuf0_pc + 16'h5000;
				rsb_pc[11:0] = 'd0;
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
begin
	if (|pc[11:0]) begin
  	fetchbufA_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,micro_instr1,micro_instr0};
	  fetchbufB_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,micro_instr2,micro_instr1};
	  fetchbufA_v <= VAL;
	  fetchbufA_pc <= pc;
	  fetchbufB_v <= VAL;
	  fetchbufB_pc <= pc;
	  fetchbufB_pc[11:0] <= pc[11:0] + 1;
	  ptakb <= takb1;
	  if (~irq)
		  takb1 <= takb;
	end
	else if (hit) begin
	  fetchbufA_instr <= inst0;
	  fetchbufB_instr <= inst1;
	  fetchbufA_v <= VAL;
	  fetchbufA_pc <= pc;
	  fetchbufB_v <= VAL;
	  fetchbufB_pc <= pc + 16'h5000;
	  ptakb <= takb1;
	  if (~irq)
		  takb1 <= takb;
	end
	else begin
	  fetchbufA_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	  fetchbufB_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	  fetchbufA_v <= INV;
	  fetchbufB_v <= INV;
	end
end
endtask

task tFetchCD;
begin
	if (|pc[11:0]) begin
  	fetchbufC_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,micro_instr1,micro_instr0};
  	fetchbufD_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,micro_instr2,micro_instr1};
	  fetchbufC_v <= VAL;
	  fetchbufC_pc <= pc;
	  fetchbufD_v <= VAL;
	  fetchbufD_pc <= pc;
	  fetchbufD_pc[11:0] <= pc[11:0] + 1;
	  ptakb <= takb1;
	  if (~irq)
		  takb1 <= takb;
	end
	else if (hit) begin
	  fetchbufC_instr <= inst0;
	  fetchbufD_instr <= inst1;
	  fetchbufC_v <= VAL;
	  fetchbufC_pc <= pc;
	  fetchbufD_v <= VAL;
	  fetchbufD_pc <= pc + 16'h5000;
	  ptakb <= takb1;
	  if (~irq)
		  takb1 <= takb;
	end
	else begin
	  fetchbufC_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	  fetchbufD_instr <= {NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN,NOP_INSN};
	  fetchbufC_v <= INV;
	  fetchbufD_v <= INV;
	end
end
endtask

endmodule

