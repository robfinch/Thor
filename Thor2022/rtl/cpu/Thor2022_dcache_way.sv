// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_dcache_way.sv
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

import Thor2022_pkg::*;
import Thor2022_mmupkg::*;

module Thor2022_dcache_way(rst, clk, state, ack, func, dce, hit, inv, acr, eaeo, daeo, lfsr, rway, wway);
input rst;
input clk;
input [6:0] state;
input ack;
input [6:0] func;
input dce;
input hit;
input inv;
input [3:0] acr;
input eaeo;
input daeo;
input [1:0] lfsr;
input [1:0] rway;
output reg [1:0] wway;

always_ff @(posedge clk)
if (rst)
	wway <= 2'd0;
else begin
	case(state)
	MEMORY_ACKLO:
		if (!inv && (dce & hit & acr[3]) &&
			(func==MR_STORE || func==MR_MOVST || func==M_CALL) &&
			ack) begin
			//if (~eaeo)
				wway <= rway;
		end
	MEMORY_ACKHI:
		if ((dce & hit & acr[3]) && 
			(func==MR_STORE || func==MR_MOVST || func==M_CALL) &&
			ack) begin
			//if (eaeo)
				wway <= rway;
		end
	DFETCH7:
		begin
	  	//if (daeo)
				wway <= lfsr;
	  end
	default:	;
	endcase
end

endmodule
