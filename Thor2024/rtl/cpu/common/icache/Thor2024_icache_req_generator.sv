// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_icache_req_generator.sv
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
// 212 LUTs / 348 FFs
// ============================================================================

import fta_bus_pkg::*;
import Thor2024pkg::*;
import Thor2024_cache_pkg::*;

module Thor2024_icache_req_generator(rst, clk, hit, miss_adr, miss_asid,
	wbm_req, full, vtags, snoop_v, snoop_adr, snoop_cid, ack);
parameter CORENO = 6'd1;
parameter CID = 6'd0;
parameter WAIT = 6'd6;
input rst;
input clk;
input hit;
input fta_address_t miss_adr;
input Thor2024pkg::asid_t miss_asid;
output fta_cmd_request128_t wbm_req;
input full;
output Thor2024pkg::address_t [15:0] vtags;
input snoop_v;
input fta_address_t snoop_adr;
input [5:0] snoop_cid;
input ack;

typedef enum logic [3:0] {
	RESET = 0,
	WAIT4MISS,STATE2,STATE3,STATE3a,STATE4,STATE4a,STATE5,STATE5a,DELAY1,
	WAIT_ACK,WAIT_UPD1,WAIT_UPD2
} state_t;
state_t req_state;

Thor2024pkg::address_t madr, vadr;
reg [7:0] lfsr_cnt;
reg [3:0] tid_cnt;
wire [16:0] lfsr_o;
reg [5:0] wait_cnt;

lfsr17 #(.WID(17)) ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(req_state != RESET),
	.cyc(1'b0),
	.o(lfsr_o)
);

always_ff @(posedge clk)
if (rst) begin
	req_state <= RESET;
	tid_cnt <= {CORENO,1'b0,4'h0};
	wbm_req <= 'd0;
	lfsr_cnt <= 'd0;
	wait_cnt <= 'd0;
	vtags <= 'd0;
end
else begin
	case(req_state)
	RESET:
		begin
			wbm_req.asid <= 'd0;
			wbm_req.cmd <= fta_bus_pkg::CMD_ICACHE_LOAD;
			wbm_req.sz  <= fta_bus_pkg::hexi;
			wbm_req.blen <= 'd0;
			wbm_req.cid <= 3'd7;					// CPU channel id
			wbm_req.tid <= 'd0;
			wbm_req.csr  <= 'd0;					// clear/set reservation
			wbm_req.pl	<= 'd0;						// privilege level
			wbm_req.pri	<= 4'h7;					// average priority (higher is better).
			wbm_req.cache <= fta_bus_pkg::CACHEABLE;
			wbm_req.seg <= fta_bus_pkg::CODE;
			wbm_req.bte <= fta_bus_pkg::LINEAR;
			wbm_req.cti <= fta_bus_pkg::CLASSIC;
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			if (lfsr_cnt=={CID,2'b0})
				req_state <= WAIT4MISS;
			lfsr_cnt <= lfsr_cnt + 2'd1;
		end
	WAIT4MISS:
		if (!hit) begin
			tid_cnt <= 4'h0;
			wbm_req.tid.core = CORENO;
			wbm_req.tid.channel = CID;			
			wbm_req.tid.tranid <= 'h0;
			wbm_req.blen <= 6'd1;
			wbm_req.cti <= fta_bus_pkg::FIXED;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.we <= 1'b0;
			wbm_req.vadr <= {miss_adr[$bits(fta_address_t)-1:Thor2024_cache_pkg::ICacheTagLoBit],{Thor2024_cache_pkg::ICacheTagLoBit{1'h0}}};
			wbm_req.asid <= miss_asid;
			vtags[4'd0] <= {miss_adr[$bits(fta_address_t)-1:Thor2024_cache_pkg::ICacheTagLoBit],{Thor2024_cache_pkg::ICacheTagLoBit{1'h0}}};
			vadr <= {miss_adr[$bits(fta_address_t)-1:Thor2024_cache_pkg::ICacheTagLoBit],{Thor2024_cache_pkg::ICacheTagLoBit{1'h0}}};
			madr <= {miss_adr[$bits(fta_address_t)-1:Thor2024_cache_pkg::ICacheTagLoBit],{Thor2024_cache_pkg::ICacheTagLoBit{1'h0}}};
			if (!full) begin
				req_state <= STATE3;
			end
		end
		else
			tBusClear();
	STATE3:
		begin
			wbm_req.cyc <= 1'b0;
			req_state <= STATE3a;
		end
	STATE3a:
		begin
			wbm_req.tid.core = CORENO;
			wbm_req.tid.channel = CID;			
			wbm_req.tid.tranid <= 4'h1;
			wbm_req.cti <= fta_bus_pkg::FIXED;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.vadr <= vadr + 5'd16;
			vtags[4'd1] <= madr + 5'd16;
			if (!full) begin
				vadr <= vadr + 5'd16;
				madr <= madr + 5'd16;
				req_state <= STATE4;
			end
		end
	STATE4:
		begin
			wbm_req.cyc <= 1'b0;
			req_state <= STATE4a;
		end
	STATE4a:
		begin
			wbm_req.tid.core = CORENO;
			wbm_req.tid.channel = CID;			
			wbm_req.tid.tranid <= 4'h2;
			wbm_req.cti <= fta_bus_pkg::FIXED;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.vadr <= vadr + 5'd16;
			vtags[4'd2] <= madr + 5'd16;
			if (!full) begin
				vadr <= vadr + 5'd16;
				madr <= madr + 5'd16;
				req_state <= STATE5;
			end
		end
	STATE5:
		begin
			wbm_req.cyc <= 1'b0;
			req_state <= STATE5a;
		end
	STATE5a:
		begin
			wbm_req.tid.core = CORENO;
			wbm_req.tid.channel = CID;			
			wbm_req.tid.tranid <= 4'h3;
			wbm_req.cti <= fta_bus_pkg::EOB;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.vadr <= vadr + 5'd16;
			vtags[4'd3] <= madr + 5'd16;
			if (!full) begin
				wait_cnt <= 'd0;
				vadr <= vadr + 5'd16;
				madr <= madr + 5'd16;
				req_state <= WAIT_ACK;
			end
		end
	DELAY1:
		begin
			tBusClear();
			req_state <= WAIT4MISS;
		end
	// Wait some random number of clocks before trying again.
	WAIT_ACK:
		begin
			tBusClear();
			if (ack)
				req_state <= WAIT_UPD1;
		end
	WAIT_UPD1:
		req_state <= WAIT_UPD2;
	WAIT_UPD2:
		req_state <= WAIT4MISS;
	default:
		req_state <= RESET;
	endcase
	// Only the cache index need be compared for snoop hit.
	if (snoop_v && snoop_adr[Thor2024_cache_pkg::ITAG_BIT:Thor2024_cache_pkg::ICacheTagLoBit]==
		miss_adr[Thor2024_cache_pkg::ITAG_BIT:Thor2024_cache_pkg::ICacheTagLoBit] &&
		snoop_cid != CID) begin
		tBusClear();
		req_state <= WAIT4MISS;		
	end
end

task tBusClear;
begin
	wbm_req.cti <= fta_bus_pkg::CLASSIC;
	wbm_req.cyc <= 1'b0;
	wbm_req.stb <= 1'b0;
	wbm_req.sel <= 16'h0000;
	wbm_req.we <= 1'b0;
end
endtask

endmodule
