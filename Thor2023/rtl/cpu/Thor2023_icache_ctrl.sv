// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_icache_ctrl.sv
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

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_icache_ctrl(rst_i, clk_i, wbm_req, wbm_resp, hit, miss_adr,
	wr_ic, way, line_o, snoop_adr, snoop_v);
input rst_i;
input clk_i;
output wb_cmd_request128_t wbm_req;
input wb_cmd_response128_t wbm_resp;
input hit;
input wb_address_t miss_adr;
output reg wr_ic;
output reg [1:0] way;
output ICacheLine line_o;
input wb_address_t snoop_adr;
input snoop_v;
parameter CORENO = 1;

typedef enum logic [2:0] {
	RESET = 0,
	STATE1,STATE2,STATE3,STATE4,STATE5,STATE6
} state_t;
state_t req_state, resp_state;

reg [4:0] to_cnt;
wb_tranid_t tid_cnt;
wire [16:0] lfsr_o;
reg [1:0] v;

lfsr17 #(.WID(17)) ulfsr1
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

always_ff @(posedge clk_i)
if (rst_i) begin
	req_state <= RESET;
	resp_state <= RESET;
	to_cnt <= 'd0;
	tid_cnt <= 'd0;
	wbm_req <= 'd0;
end
else begin
	wr_ic <= 1'b0;
	case(req_state)
	RESET:
		begin
			wbm_req.cmd <= wishbone_pkg::CMD_ICACHE_LOAD;
			wbm_req.sz  <= wishbone_pkg::hexi;
			wbm_req.blen <= 'd0;
			wbm_req.cid <= 3'd7;					// CPU channel id
			wbm_req.tid <= 'd0;						// transaction id (not used)
			wbm_req.csr  <= 'd0;					// clear/set reservation
			wbm_req.pl	<= 'd0;						// privilege level
			wbm_req.pri	<= 4'h7;					// average priority (higher is better).
			wbm_req.cache <= wishbone_pkg::CACHEABLE;
			wbm_req.seg <= wishbone_pkg::CODE;
			wbm_req.bte <= wishbone_pkg::LINEAR;
			wbm_req.cti <= wishbone_pkg::CLASSIC;
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			req_state <= STATE1;
		end
	STATE1:
		if (!hit) begin
			tid_cnt[7:4] <= {CORENO,1'b0};
			tid_cnt[2:0] <= tid_cnt[2:0] + 2'd1;
			wbm_req.tid <= tid_cnt;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.we <= 1'b0;
			wbm_req.vadr <= {miss_adr[$bits(wb_address_t)-1:ICacheTagLoBit],v[0],{ICacheTagLoBit-2{1'h0}}};
			to_cnt <= 'd0;
			req_state <= STATE2;
		end
	STATE2:
		begin
			to_cnt <= to_cnt + 2'd1;
			if (to_cnt[4]) begin
				wbm_req.cyc <= 1'b0;
				wbm_req.stb <= 1'b0;
				wbm_req.sel <= 16'h0000;
				wbm_req.we <= 1'b0;
				req_state <= STATE6;
			end
		end
	// Wait some random number of clocks before trying again.
	STATE6:
		begin
			if (lfsr_o[4:2]==3'b111)
				req_state <= STATE1;
		end
	default:	req_state <= RESET;
	endcase

	// Process responses.
	case(resp_state)
	RESET:
		begin
			v <= 2'b00;
			resp_state <= STATE1;
		end
	STATE1:
	/*
		if (wbm_resp.next) begin
			wbm_req.cti <= CLASSIC;
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			req_state <= STATE1;
		end
		else
	*/
		if (wbm_resp.ack) begin
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			if (wbm_resp.adr[4]) begin
				v[1] <= 1'b1;
				line_o.v[1] <= 1'b1;
				line_o.data[255:128] <= wbm_resp.dat;
			end
			else begin
				v[0] <= 1'b1;
				line_o.v[0] <= 1'b1;
				line_o.data[127:  0] <= wbm_resp.dat;
			end
			line_o.vtag <= {wbm_req.vadr[$bits(wb_address_t)-1:ICacheTagLoBit],{ICacheTagLoBit{1'b0}}};
			line_o.ptag <= {wbm_resp.adr[$bits(wb_address_t)-1:ICacheTagLoBit],{ICacheTagLoBit{1'b0}}};
			resp_state <= STATE2;
		end
		else if (wbm_resp.rty) begin
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			v <= 2'b00;
			line_o.v <= 2'b00;
			req_state <= STATE6;
		end
	STATE2:
		begin
			if (v==2'b11) begin
				v <= 2'b00;
				wr_ic <= 1'b1;
				way <= lfsr_o[1:0];
			end
			req_state <= STATE1;
			resp_state <= STATE1;
		end
	default:	resp_state <= STATE1;
	endcase
	// Only the cache index need be compared for snoop hit.
	if (snoop_v && snoop_adr[ITAG_BIT:ICacheTagLoBit]==miss_adr[ITAG_BIT:ICacheTagLoBit]) begin
		wbm_req.cyc <= 1'b0;
		wbm_req.stb <= 1'b0;
		wbm_req.sel <= 16'h0000;
		wbm_req.we <= 1'b0;
		wr_ic <= 1'b0;
		v <= 2'b00;
		line_o.v <= 2'b00;
		req_state <= STATE1;		
		resp_state <= STATE1;	
	end
end

endmodule
