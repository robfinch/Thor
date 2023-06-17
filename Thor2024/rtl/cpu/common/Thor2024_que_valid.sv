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

import Thor2024pkg::*;

module Thor2024_que_valid(rst, clk, stomp, iq, panic, heads, tail0, tail1,
	branchmiss, backbr, fetchbuf0_v, fetchbuf1_v, pred_mask, pred_val, iq_v);
input rst;
input clk;
input [QENTRIES-1:0] stomp;
input iq_entry_t [QENTRIES-1:0] iq;
input [3:0] panic;
input que_ndx_t [QENTRIES-1:0] heads;
input que_ndx_t tail0;
input que_ndx_t tail1;
input branchmiss;
input backbr;
input fetchbuf0_v;
input fetchbuf1_v;
input [1:0] pred_mask;
input [1:0] pred_val;
output reg [QENTRIES-1:0] iq_v;

integer nn;

always_ff @(posedge clk, posedge rst)
if (rst) begin
	iq_v <= {QENTRIES{INV}};
end
else begin

	// Instruction queue time.
	if (!branchmiss) 	// don't bother doing anything if there's been a branch miss

		case ({fetchbuf0_v, fetchbuf1_v})
    2'b00: ; // do nothing
    2'b01:
    	if (iq_v[tail0] == INV)
				iq_v[tail0] <= VAL;
    2'b10:
    	if (iq_v[tail0] == INV && (~^pred_mask || pred_mask==pred_val))
				iq_v[tail0] <= VAL;
    2'b11:
    	if (iq_v[tail0] == INV) begin
				//
				// if the first instruction is a backwards branch, enqueue it & stomp on all following instructions
				//
				if (backbr)
					iq_v[tail0] <= VAL;
				else begin	// fetchbuf0 doesn't contain a backwards branch
					iq_v[tail0] <= VAL;
			    //
			    // if there is room for a second instruction, enqueue it
			    //
			    if (iq_v[tail1] == INV)
						iq_v[tail1] <= VAL;
				end
			end
		endcase

	for (nn = 0; nn < QENTRIES; nn = nn + 1)
		if (iq_v[nn] && stomp[nn])
	    iq_v[nn] <= INV;

//
// COMMIT PHASE (dequeue only ... not register-file update)
//
// look at heads[0] and heads[1] and let 'em write to the register file if they are ready
//
	if (~|panic) begin
		if (SUPPORT_3COMMIT)
		casez ({ iq_v[heads[0]],
			iq[heads[0]].done,
			iq_v[heads[1]],
			iq[heads[1]].done,iq_v[heads[2]],iq[heads[2]].done })

	  // retire 0 - blocked at the first instruction
	  // 16 cases
	  6'b10_??_??:	;
	  // retire 1 - blocked at the second instruction
	  // 12 cases
		6'b0?_10_??:	;
		6'b11_10_??:  iq_v[heads[0]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
	  // retire 2 - blocked at third instruction
	  // 7 cases
		6'b0?_0?_10:	;
		6'b11_0?_10:
			if (heads[1] != tail0)
		    iq_v[heads[0]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
			else
		    iq_v[heads[0]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		6'b11_11_10:
			begin
		    iq_v[heads[0]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		    iq_v[heads[1]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
			end
		// retire 3
		// 27 cases
		6'b0?_0?_0?:	;
		6'b0?_0?_11:
			if (iq[heads[2]].tgt=='d0)
		    iq_v[heads[2]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		6'b0?_11_0?:
			if (heads[2] != tail0)
				iq_v[heads[1]] = INV;
			else
				iq_v[heads[1]] = INV;
		6'b0?_11_11:
			if (iq[heads[2]].tgt=='d0) begin
				iq_v[heads[1]] = INV;
		    iq_v[heads[2]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
			end
			else
				iq_v[heads[1]] = INV;
		6'b11_0?_11:
			if (heads[1] != tail0) begin
				iq_v[heads[0]] = INV;
				iq_v[heads[2]] = INV;
			end
			else
				iq_v[heads[0]] = INV;
		6'b11_11_0?:
			if (heads[2] != tail0) begin
				iq_v[heads[0]] = INV;
				iq_v[heads[1]] = INV;
			end
			else begin
				iq_v[heads[0]] = INV;
				iq_v[heads[1]] = INV;
			end
		6'b11_11_11:
			if (iq[heads[2]].tgt=='d0) begin
				iq_v[heads[0]] = INV;
				iq_v[heads[1]] = INV;
		    iq_v[heads[2]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
			end
			else begin
				iq_v[heads[0]] = INV;
				iq_v[heads[1]] = INV;
			end
		6'b11_0?_0?:
			if (heads[1] != tail0 && heads[2] != tail0)
				iq_v[heads[0]] = INV;
			else if (heads[1] != tail0)
				iq_v[heads[0]] = INV;
			else
				iq_v[heads[0]] = INV;
			
		default:	;
		endcase
	else
		case ({ iq[heads[0]].v,
			iq[heads[0]].done,
			iq[heads[1]].v,
			iq[heads[1]].done })

    // 4'b00_00	- neither valid; skip both
    // 4'b00_01	- neither valid; skip both
    // 4'b00_10	- skip heads[0], wait on heads[1]
    // 4'b00_11	- skip heads[0], commit heads[1]
    // 4'b01_00	- neither valid; skip both
    // 4'b01_01	- neither valid; skip both
    // 4'b01_10	- skip heads[0], wait on heads[1]
    // 4'b01_11	- skip heads[0], commit heads[1]
    // 4'b10_00	- wait on heads[0]
    // 4'b10_01	- wait on heads[0]
    // 4'b10_10	- wait on heads[0]
    // 4'b10_11	- wait on heads[0]
    // 4'b11_00	- commit heads[0], skip heads[1]
    // 4'b11_01	- commit heads[0], skip heads[1]
    // 4'b11_10	- commit heads[0], wait on heads[1]
    // 4'b11_11	- commit heads[0], commit heads[1]

    //
    // retire 0
    4'b10_00,
    4'b10_01,
    4'b10_10,
    4'b10_11: ;

    //
    // retire 1
    4'b00_10,
    4'b01_10,
    4'b11_10:
    	begin
				if (iq[heads[0]].v || heads[0] != tail0)
			    iq_v[heads[0]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
	    end

    // retire 2
    default: 
    	begin
				if ((iq[heads[0]].v && iq[heads[1]].v) || (heads[0] != tail0 && heads[1] != tail0)) begin
			    iq_v[heads[0]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
			    iq_v[heads[1]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
				end
				else if (iq[heads[0]].v || heads[0] != tail0)
			    iq_v[heads[0]] = INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
	    end
		endcase
	end

end

endmodule
