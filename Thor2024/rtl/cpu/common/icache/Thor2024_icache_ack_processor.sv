// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_icache_ack_processor.sv
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
// 41 LUTs / 358 FFs
// ============================================================================

import fta_bus_pkg::*;
import Thor2024pkg::*;
import Thor2024_cache_pkg::*;

module Thor2024_icache_ack_processor(rst, clk, wbm_resp, wr_ic, line_o, vtags, way);
parameter LOG_WAYS = 2;
input rst;
input clk;
input fta_cmd_response128_t wbm_resp;
output reg wr_ic;
output ICacheLine line_o;
input Thor2024pkg::address_t [15:0] vtags;
output reg [LOG_WAYS-1:0] way;

typedef enum logic [2:0] {
	WAIT=0,DELAY1,WAIT_NACK,DELAY3,DELAY4,STATE6
} state_t;
state_t resp_state;

integer n;
fta_tranid_t last_tid;
reg [3:0] v [0:3];
wire [16:0] lfsr_o;

ICacheLine [3:0] tran_line;

lfsr17 #(.WID(17)) ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

always_ff @(posedge clk, posedge rst)
if (rst) begin
	resp_state <= WAIT;
	wr_ic <= 1'd0;
	for (n = 0; n < 4; n = n + 1) begin
		v[n] <= 4'b0000;
		tran_line[n] <= 'd0;
	end
	line_o <= 'd0;
	last_tid <= 'd0;
	way <= 'd0;
end
else begin
	wr_ic <= 1'b0;
	// Process responses.
	case(resp_state)
	WAIT:
		begin
			if (wbm_resp.ack) begin
				if (wbm_resp.tid != last_tid) begin
					last_tid <= wbm_resp.tid;
				end
				case(wbm_resp.adr[5:4])
				2'b00:
					begin
						v[wbm_resp.tid.tranid[3:2]][0] <= 1'b1;
						tran_line[wbm_resp.tid.tranid[3:2]].v[0] <= 1'b1;
						tran_line[wbm_resp.tid.tranid[3:2]].vtag <= vtags[wbm_resp.tid.tranid] & ~64'h30;
						tran_line[wbm_resp.tid.tranid[3:2]].ptag <= wbm_resp.adr[$bits(Thor2024pkg::address_t)-1:0] & ~64'h30;
						tran_line[wbm_resp.tid.tranid[3:2]].data[ICacheBundleWidth*1-1:ICacheBundleWidth*0] <= wbm_resp.dat[ICacheBundleWidth-1:0];
					end
				2'b01:
					begin
						v[wbm_resp.tid.tranid[3:2]][1] <= 1'b1;
						tran_line[wbm_resp.tid.tranid[3:2]].v[1] <= 1'b1;
						tran_line[wbm_resp.tid.tranid[3:2]].vtag <= vtags[wbm_resp.tid.tranid] & ~64'h30;
						tran_line[wbm_resp.tid.tranid[3:2]].ptag <= wbm_resp.adr[$bits(Thor2024pkg::address_t)-1:0] & ~64'h30;
						tran_line[wbm_resp.tid.tranid[3:2]].data[ICacheBundleWidth*2-1:ICacheBundleWidth*1] <= wbm_resp.dat[ICacheBundleWidth-1:0];
					end
				2'b10:
					begin
						v[wbm_resp.tid.tranid[3:2]][2] <= 1'b1;
						tran_line[wbm_resp.tid.tranid[3:2]].v[2] <= 1'b1;
						tran_line[wbm_resp.tid.tranid[3:2]].vtag <= vtags[wbm_resp.tid.tranid] & ~64'h30;
						tran_line[wbm_resp.tid.tranid[3:2]].ptag <= wbm_resp.adr[$bits(Thor2024pkg::address_t)-1:0] & ~64'h30;
						tran_line[wbm_resp.tid.tranid[3:2]].data[ICacheBundleWidth*3-1:ICacheBundleWidth*2] <= wbm_resp.dat[ICacheBundleWidth-1:0];
					end
				2'b11:
					begin
						v[wbm_resp.tid.tranid[3:2]][3] <= 1'b1;
						tran_line[wbm_resp.tid.tranid[3:2]].v[3] <= 1'b1;
						tran_line[wbm_resp.tid.tranid[3:2]].vtag <= vtags[wbm_resp.tid.tranid] & ~64'h30;
						tran_line[wbm_resp.tid.tranid[3:2]].ptag <= wbm_resp.adr[$bits(Thor2024pkg::address_t)-1:0] & ~64'h30;
						tran_line[wbm_resp.tid.tranid[3:2]].data[ICacheBundleWidth*4-1:ICacheBundleWidth*3] <= wbm_resp.dat[ICacheBundleWidth-1:0];
					end
				endcase
			end
		end
	default:	
		resp_state <= WAIT;
	endcase
	// Search for completely loaded cache lines. Send off to cache.
	for (n = 0; n < 4; n = n + 1) begin
		if (v[n]==4'b1111) begin
			v[n] <= 4'b0000;
			line_o <= tran_line[n];
			wr_ic <= 1'b1;
			way <= lfsr_o[LOG_WAYS-1:0];
		end
	end
end

endmodule
