// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_dcache_ctrl.sv
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

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_dcache_ctrl(rst_i, clk_i, dce, wbm_req, wbm_resp, acr, hit,
	cache_load, cpu_request_i, cpu_response_o, cpu_response_i, wr, uway, way,
	dump, dump_i, dump_ack, snoop_adr, snoop_v, snoop_cid);
parameter CID = 2;
parameter WAYS = 4;
parameter NSEL = 32;
localparam LOG_WAYS = $clog2(WAYS)-1;
input rst_i;
input clk_i;
input dce;
output wb_cmd_request128_t wbm_req;
input wb_cmd_response128_t wbm_resp;
input [3:0] acr;
input hit;
output reg cache_load;
input wb_cmd_request256_t cpu_request_i;
output wb_cmd_response256_t cpu_response_o;
input wb_cmd_response256_t cpu_response_i;
output reg wr;
input [LOG_WAYS:0] uway;
output reg [LOG_WAYS:0] way;
input dump;
input DCacheLine dump_i;
output reg dump_ack;
input wb_address_t snoop_adr;
input snoop_v;
input [3:0] snoop_cid;

genvar g;

typedef enum logic [2:0] {
	RESET = 0,
	STATE1,STATE2,STATE3,STATE4,STATE5,STATE6
} state_t;
state_t req_state, resp_state;

reg [LOG_WAYS:0] iway;
wb_cmd_response256_t response_o;
reg cache_dump;
reg [10:0] to_cnt;
wb_tranid_t tid_cnt;
wire [16:0] lfsr_o;
reg [1:0] v;
reg [255:0] upd_dat;


lfsr17 #(.WID(17)) ulfsr1
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

wire cache_type = cpu_request_i.cache;

wire non_cacheable =
	!dce ||
	cache_type==NC_NB ||
	cache_type==NON_CACHEABLE
	;
wire allocate =
	cache_type==CACHEABLE_NB ||
	cache_type==CACHEABLE ||
	cache_type==WT_READ_ALLOCATE ||
	cache_type==WT_WRITE_ALLOCATE ||
	cache_type==WT_READWRITE_ALLOCATE ||
	cache_type==WB_READ_ALLOCATE ||
	cache_type==WB_WRITE_ALLOCATE ||
	cache_type==WB_READWRITE_ALLOCATE
	;
// Comb logic so that hits do not take an extra cycle.
always_comb
	if (hit) begin
		way = uway;
		cpu_response_o = cpu_response_i;
		cpu_response_o.ack = 1'b1;
	end
	else begin
		way = iway;
		cpu_response_o = response_o;
		cpu_response_o.ack = response_o.ack;
	end

// Selection of data used to update cache.
// For a write request the data includes data from the CPU.
// Otherwise it is just a cache line load, all data comes from the response.
// Note data is passed in 128-bit chunks.
generate begin : gCacheLineUpdate
	for (g = 0; g < 16; g = g + 1) begin : gFor
		always_comb
			if (cpu_request_i.we && cpu_request_i.sel[wbm_resp.adr[4]*16+g]) begin
				if (wbm_resp.adr[4])
					upd_dat[g*8+7:g*8] <= cpu_request_i.dat[128+g*8+7:128+g*8];
				else
					upd_dat[g*8+7:g*8] <= cpu_request_i.dat[g*8+7:g*8];
			end
			else
				upd_dat[g*8+7:g*8] <= wbm_resp.dat[g*8+7:g*8];
	end
end
endgenerate				
	
always_ff @(posedge clk_i)
if (rst_i) begin
	req_state <= RESET;
	resp_state <= RESET;
	to_cnt <= 'd0;
	tid_cnt <= 'd0;
	dump_ack <= 1'd0;
	wr <= 1'b0;
	response_o <= 'd0;
	wbm_req <= 'd0;
end
else begin
	dump_ack <= 1'd0;
	response_o.stall <= 1'b0;
	response_o.next <= 1'b0;
	response_o.ack <= 1'b0;
	response_o.pri <= 4'd7;
	wr <= 1'b0;
	case(req_state)
	RESET:
		begin
			wbm_req.cmd <= wishbone_pkg::CMD_DCACHE_LOAD;
			wbm_req.sz  <= wishbone_pkg::hexi;
			wbm_req.blen <= 'd0;
			wbm_req.cid <= 3'd7;					// CPU channel id
			wbm_req.tid <= 'd0;						// transaction id (not used)
			wbm_req.csr  <= 'd0;					// clear/set reservation
			wbm_req.pl	<= 'd0;						// privilege level
			wbm_req.pri	<= 4'h7;					// average priority (higher is better).
			wbm_req.cache <= wishbone_pkg::CACHEABLE;
			wbm_req.seg <= wishbone_pkg::DATA;
			wbm_req.bte <= wishbone_pkg::LINEAR;
			wbm_req.cti <= wishbone_pkg::CLASSIC;
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			req_state <= STATE1;
		end
	STATE1:
		if (!hit && allocate && dce && cpu_request_i.cyc) begin
			cache_dump <= 1'b1;
			tid_cnt[7:4] <= CID;
			tid_cnt[2:0] <= tid_cnt[2:0] + 2'd1;
			wbm_req.cmd <= wishbone_pkg::CMD_STORE;
			wbm_req.tid <= tid_cnt;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.we <= 1'b1;
			wbm_req.asid <= dump_i.asid;
			wbm_req.vadr <= {dump_i.vtag[$bits(wb_address_t)-1:DCacheTagLoBit],v[0],{DCacheTagLoBit-2{1'h0}}};
			wbm_req.data1 <= v[0] ? dump_i.data[255:128] : dump_i.data[127:0];
			to_cnt <= 'd0;
			req_state <= STATE2;
		end
		// It may have missed because a non-cacheable address is begin accessed.
		else if (!hit) begin
			cache_load <= !(non_cacheable & cpu_request_i.cyc);
			tid_cnt[7:4] <= CID;
			tid_cnt[2:0] <= tid_cnt[2:0] + 2'd1;
			wbm_req.cmd <= wishbone_pkg::CMD_DCACHE_LOAD;
			wbm_req.tid <= tid_cnt;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.we <= 1'b0;
			wbm_req.asid <= cpu_request_i.asid;
			wbm_req.vadr <= {cpu_request_i.vadr[$bits(wb_address_t)-1:DCacheTagLoBit],v[0],{DCacheTagLoBit-2{1'h0}}};
			to_cnt <= 'd0;
			req_state <= STATE5;
		end
	STATE2:
		begin
			to_cnt <= to_cnt + 2'd1;
			if (to_cnt[10]) begin
				wbm_req.cyc <= 1'b0;
				wbm_req.stb <= 1'b0;
				wbm_req.sel <= 16'h0000;
				wbm_req.we <= 1'b0;
				req_state <= STATE6;
			end
		end
	STATE4:
		begin
			cache_load <= dce;
			tid_cnt[7:4] <= CID;
			tid_cnt[2:0] <= tid_cnt[2:0] + 2'd1;
			wbm_req.cmd <= wishbone_pkg::CMD_DCACHE_LOAD;
			wbm_req.tid <= tid_cnt;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.we <= 1'b0;
			wbm_req.asid <= cpu_request_i.asid;
			wbm_req.vadr <= {cpu_request_i.vadr[$bits(wb_address_t)-1:DCacheTagLoBit],v[0],{DCacheTagLoBit-2{1'h0}}};
			to_cnt <= 'd0;
			req_state <= STATE5;
		end
	STATE5:
		begin
			to_cnt <= to_cnt + 2'd1;
			if (to_cnt[10]) begin
				wbm_req.cyc <= 1'b0;
				wbm_req.stb <= 1'b0;
				wbm_req.sel <= 16'h0000;
				wbm_req.we <= 1'b0;
				req_state <= STATE1;
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
		if (wbm_resp.ack) begin
			req_state <= req_state==STATE5 ? STATE4 : STATE1;
			resp_state <= STATE2;
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			if (wbm_resp.adr[4]) begin
				v[1] <= 1'b1;
				response_o.cid <= wbm_resp.cid;
				response_o.tid <= wbm_resp.tid;
				response_o.pri <= wbm_resp.pri;
				response_o.adr <= wbm_resp.adr;
				response_o.dat[255:128] <= upd_dat;
			end
			else begin
				v[0] <= 1'b1;
				response_o.cid <= wbm_resp.cid;
				response_o.tid <= wbm_resp.tid;
				response_o.pri <= wbm_resp.pri;
				response_o.adr <= wbm_resp.adr;
				response_o.dat[127:0] <= upd_dat;
			end
			// Line load complete or cpu access complete, pulse appropriate ack line.
			if (v==2'b01 || v==2'b10) begin
				if (cache_dump)
					req_state <= STATE4;
				dump_ack <= cache_dump;
				response_o.ack <= !cache_dump;
				v <= 2'b00;
				iway <= lfsr_o[LOG_WAYS:0];
				// Write to cache only if response from TLB indicates a cacheable
				// address.
				wr <= acr[3] & dce;
			end
		end
		else if (wbm_resp.rty|wbm_resp.err) begin
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			response_o.rty <= wbm_resp.rty;
			response_o.err <= wbm_resp.err;
			response_o.ack <= 1'b0;
			v <= 2'b00;
			req_state <= STATE6;
		end
	// Wait for ack to clear before continuing.
	STATE2:
		if (!wbm_resp.ack)
			resp_state <= STATE1;
	default:	resp_state <= STATE1;
	endcase
	// Only the cache index need be compared for snoop hit.
	if (snoop_v && snoop_adr[ITAG_BIT:ICacheTagLoBit]==cpu_request_i.vadr[ITAG_BIT:ICacheTagLoBit] && snoop_cid==CID) begin
		wbm_req.cyc <= 1'b0;
		wbm_req.stb <= 1'b0;
		wbm_req.sel <= 16'h0000;
		wbm_req.we <= 1'b0;
		wr <= 1'b0;
		v <= 2'b00;
		req_state <= STATE1;		
		resp_state <= STATE1;	
	end
end

endmodule
