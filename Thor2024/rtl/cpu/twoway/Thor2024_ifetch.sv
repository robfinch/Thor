import Thor2024pkg::*;

module Thor2024_ifetch(rst, clk, hit, irq, branchback, backpc, branchmiss, misspc,
	next_pc, takb, ptakb, pc, pc_i, stall, inst0, inst1, iq, tail0, tail1,
	fetchbuf, fetchbuf0_instr, fetchbuf0_v, fetchbuf0_pc, 
	fetchbuf1_instr, fetchbuf1_v, fetchbuf1_pc);
input rst;
input clk;
input hit;
input irq;
output reg branchback;
output address_t backpc;
input branchmiss;
input address_t misspc;
input address_t next_pc;
input takb;
output reg ptakb;
output address_t pc;
input address_t pc_i;
output reg stall;
input instruction_t [4:0] inst0;
input instruction_t [4:0] inst1;
input iq_entry_t [7:0] iq;
input que_ndx_t tail0;
input que_ndx_t tail1;
output reg fetchbuf;
output instruction_t [4:0] fetchbuf0_instr;
output reg fetchbuf0_v;
output address_t fetchbuf0_pc;
output instruction_t [4:0] fetchbuf1_instr;
output reg fetchbuf1_v;
output address_t fetchbuf1_pc;

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
address_t fetchbufA_pc;
address_t fetchbufB_pc;
address_t fetchbufC_pc;
address_t fetchbufD_pc;
reg buffered, consumed;
address_t pci;
reg takb1;
reg did_branchmiss;

always_ff @(posedge clk, posedge rst)
if (rst) begin
	pc <= 32'hFFFD0000;
	ppc <= 32'hFFFD0000;
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
	fetchbufA_instr <= 'd0;
	fetchbufB_pc <= 'd0;
	fetchbufB_instr <= 'd0;
	fetchbufC_pc <= 'd0;
	fetchbufC_instr <= 'd0;
	fetchbufD_pc <= 'd0;
	fetchbufD_instr <= 'd0;
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
    fetchbuf <= 1'b0;
    fetchbufA_v <= INV;
    fetchbufB_v <= INV;
    fetchbufC_v <= INV;
    fetchbufD_v <= INV;
    buffered <= 1'b0;
	end
	else begin
		consumed = 1'b0;
		if (0 && branchback) begin

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
					if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr)} == {VAL, TRUE}) begin
						tFetchCD();
						if (buffered | hit) begin
							consumed = 1'b1;
				    	fetchbufB_v <= iq[tail0].v;	// if it can be queued, it will
				    	fetchbuf <= fetchbuf + ~iq[tail0].v;
				    end
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
					if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr)} == {VAL, TRUE}) begin
				    fetchbufB_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr)} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufB_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr)} == {VAL, TRUE}) begin
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
					if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr)} == {VAL, TRUE}) begin
						tFetchCD();
						if (buffered | hit) begin
							consumed = 1'b1;
				    	fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    	fetchbuf <= fetchbuf + ~iq[tail0].v;
				    end
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
					if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr)} == {VAL, TRUE}) begin
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr)} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr)} == {VAL, TRUE}) begin
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
					if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr)} == {VAL, TRUE}) begin
				    // has to be first scenario
				    pc <= backpc;
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufB_v <= INV;		// stomp on it
				    if (~iq[tail0].v)	fetchbuf <= 1'b0;
					end
					else if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr)} == {VAL, TRUE}) begin
				    if (did_branchback) begin
				    	tFetchCD();
							if (buffered | hit) begin
								consumed = 1'b1;
								fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
								fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
								fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
							end
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
					if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr)} == {VAL, TRUE}) begin
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr)} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufA_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufB_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr)} == {VAL, TRUE}) begin
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
					if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr)} == {VAL, TRUE}) begin
						tFetchAB();
						if (buffered | hit) begin
							consumed = 1'b1;
				    	fetchbufD_v <= iq[tail0].v;	// if it can be queued, it will
				    	fetchbuf <= fetchbuf + ~iq[tail0].v;
				    end
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
					if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr)} == {VAL, TRUE}) begin
				    fetchbufD_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr)} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufD_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr)} == {VAL, TRUE}) begin
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
					if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr)} == {VAL, TRUE}) begin
						tFetchAB();
						if (buffered | hit) begin
							 consumed = 1'b1;
				    	fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    	fetchbuf <= fetchbuf + ~iq[tail0].v;
				    end
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
					if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr)} == {VAL, TRUE}) begin
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr)} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + ~iq[tail0].v;
					end
					else if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr)} == {VAL, TRUE}) begin
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
					if ({fetchbufC_v, fnIsBackBranch(fetchbufC_instr)} == {VAL, TRUE}) begin
				    // has to be first scenario
				    pc <= backpc;
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufD_v <= INV;		// stomp on it
				    if (~iq[tail0].v)	fetchbuf <= 1'b0;
					end
					else if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr)} == {VAL, TRUE}) begin
				    if (did_branchback) begin
				    	tFetchAB();
							if (buffered | hit) begin
								consumed = 1'b1;
								fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
								fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
								fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
							end
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
					if ({fetchbufD_v, fnIsBackBranch(fetchbufD_instr)} == {VAL, TRUE}) begin
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else if ({fetchbufA_v, fnIsBackBranch(fetchbufA_instr)} == {VAL, TRUE}) begin
				    // branchback is in later instructions ... do nothing
				    fetchbufC_v <= iq[tail0].v;	// if it can be queued, it will
				    fetchbufD_v <= iq[tail1].v;	// if it can be queued, it will
				    fetchbuf <= fetchbuf + (~iq[tail0].v & ~iq[tail1].v);
					end
					else if ({fetchbufB_v, fnIsBackBranch(fetchbufB_instr)} == {VAL, TRUE}) begin
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
		  	tFetchAB();
				if (buffered | hit) consumed = 1'b1;
	      // fetchbuf steering logic correction
	      if (fetchbufC_v==INV && fetchbufD_v==INV)
	        fetchbuf <= 1'b0;
	    end
	    else if (fetchbufC_v == INV && fetchbufD_v == INV) begin
	    	tFetchCD();
				if (buffered | hit) consumed = 1'b1;
			end
		end
		if (!consumed && !buffered) begin
			inst0a <= inst0;
			inst1a <= inst1;
			pci <= pc_i;
			buffered <= 1'b1;
		end
		if (branchback)
			buffered <= 1'b0;
	end
	if (0) begin
		if (fetchAB)
			tFetchAB();
		else if (fetchCD)
			tFetchCD();
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
always_comb
	isBB0 = fnIsBackBranch(fetchbuf0_instr[0]);
always_comb
	isBB1 = fnIsBackBranch(fetchbuf1_instr[0]);
always_comb
	branchback = (fetchbuf0_v & isBB0) | (fetchbuf1_v & isBB1);
always_comb
	backpc = (fetchbuf0_v & isBB0)
	    ? (fetchbuf0_pc + fnBranchDisp(fetchbuf0_instr[0]))
	    : (fetchbuf1_pc + fnBranchDisp(fetchbuf1_instr[0]));

task tFetchAB;
begin
	if (buffered) begin
		fetchAB <= 1'b0;
	  fetchbufA_instr <= inst0a;
	  fetchbufA_v <= !did_branchmiss;
	  fetchbufA_pc <= pci;
	  fetchbufB_instr <= inst1a;
	  fetchbufB_v <= !did_branchmiss;
	  fetchbufB_pc <= pci + INSN_LEN;
	  buffered <= 1'b0;
	  ptakb <= takb1;
	  if (hit & ~irq) begin
	  	ppc <= pc;
		  pc <= next_pc;
		  takb1 <= takb;
		end
	end
	else if (hit) begin
		fetchAB <= 1'b0;
	  fetchbufA_instr <= inst0;
	  fetchbufA_v <= !did_branchmiss;
	  fetchbufA_pc <= pc_i;
	  fetchbufB_instr <= inst1;
	  fetchbufB_v <= !did_branchmiss;
	  fetchbufB_pc <= pc_i + INSN_LEN;
	  buffered <= 1'b0;
	  ptakb <= takb1;
	  if (hit & ~irq) begin
	  	ppc <= pc;
		  pc <= next_pc;
		  takb1 <= takb;
		end
	end
	else
		fetchAB <= 1'b1;
end
endtask

task tFetchCD;
begin
	if (buffered) begin
		fetchCD <= 1'b0;
	  fetchbufC_instr <= inst0a;
	  fetchbufC_v <= VAL;
	  fetchbufC_pc <= pci;
	  fetchbufD_instr <= inst1a;
	  fetchbufD_v <= VAL;
	  fetchbufD_pc <= pci + INSN_LEN;
	  buffered <= 1'b0;
	  ptakb <= takb1;
	  if (hit & ~irq) begin
	  	ppc <= pc;
		  pc <= next_pc;
		  takb1 <= takb;
	  end
	end
	else if (hit) begin
		fetchCD <= 1'b0;
	  fetchbufC_instr <= inst0;
	  fetchbufC_v <= VAL;
	  fetchbufC_pc <= pc_i;
	  fetchbufD_instr <= inst1;
	  fetchbufD_v <= VAL;
	  fetchbufD_pc <= pc_i + INSN_LEN;
	  buffered <= 1'b0;
	  ptakb <= takb1;
	  if (hit & ~irq) begin
	  	ppc <= pc;
		  pc <= next_pc;
		  takb1 <= takb;
	  end
	end
	else
		fetchCD <= 1'b1;
end
endtask

endmodule