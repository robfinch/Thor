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
input wb_cmd_request512_t cpu_request_i;
output wb_cmd_response512_t cpu_response_o;
input wb_cmd_response512_t cpu_response_i;
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
wb_cmd_response512_t response_o;
reg cache_dump;
reg [10:0] to_cnt;
wb_tranid_t tid_cnt;
wire [16:0] lfsr_o;
reg [3:0] v;
reg [5:0] wr_cnt;
reg [5:0] dump_cnt;
reg [5:0] load_cnt;
reg [511:0] upd_dat;


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
		cpu_response_o = upd_dat;
		cpu_response_o.ack = response_o.ack;
	end

// Selection of data used to update cache.
// For a write request the data includes data from the CPU.
// Otherwise it is just a cache line load, all data comes from the response.
// Note data is passed in 128-bit chunks.
generate begin : gCacheLineUpdate
	for (g = 0; g < 64; g = g + 1) begin : gFor
		always_comb
			if (cpu_request_i.we) begin
				if (cpu_request_i.sel[g])
					upd_dat[g*8+7:g*8] <= cpu_request_i.dat[g*8+7:g*8];
				else
					upd_dat[g*8+7:g*8] <= cpu_response_o.dat[g*8+7:g*8];
			end
			else
				upd_dat[g*8+7:g*8] <= response_o[g*8+7:g*8];
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
	wr_cnt <= 'd0;
	dump_cnt <= 'd0;
	load_cnt <= 'd0;
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
			wr_cnt <= 'd0;
			req_state <= STATE1;
		end
	STATE1:
		if ((!hit && allocate && dce && cpu_request_i.cyc) || cache_dump) begin
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
			wbm_req.vadr <= {dump_i.vtag[$bits(wb_address_t)-1:DCacheTagLoBit],dump_cnt[1:0],{DCacheTagLoBit-2{1'h0}}};
			case(wr_cnt)
			2'd0:	wbm_req.data1 <= dump_i.data[127:  0];
			2'd1:	wbm_req.data1 <= dump_i.data[255:128];
			2'd2:	wbm_req.data1 <= dump_i.data[383:256];
			2'd3:	wbm_req.data1 <= dump_i.data[511:384];
			endcase
			to_cnt <= 'd0;
			req_state <= STATE2;
		end
		// It may have missed because a non-cacheable address is being accessed.
		else if (!hit) begin
			req_state <= STATE5;
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
			response_o.dat <= 'd0;
			// Access only the strip of memory requested. It could be an I/O device.
			if (|cpu_request_i.sel[15:0]) begin
				wbm_req.vadr <= {cpu_request_i.vadr[$bits(wb_address_t)-1:DCacheTagLoBit],2'b00,{DCacheTagLoBit-2{1'h0}}};
				load_cnt <= 2'd00;
				v[0] <= 1'b0;
				v[1] <= ~|cpu_request_i.sel[31:16];
				v[2] <= ~|cpu_request_i.sel[47:32];
				v[3] <= ~|cpu_request_i.sel[63:48];
			end
			else if (|cpu_request_i,sel[31:16]) begin
				wbm_req.vadr <= {cpu_request_i.vadr[$bits(wb_address_t)-1:DCacheTagLoBit],2'b01,{DCacheTagLoBit-2{1'h0}}};
				load_cnt <= 2'd01;
				v[0] <= 1'b1;
				v[1] <= 1'b0;
				v[2] <= ~|cpu_request_i.sel[47:32];
				v[3] <= ~|cpu_request_i.sel[63:48];
			end
			else if (|cpu_request_i,sel[47:32]) begin
				wbm_req.vadr <= {cpu_request_i.vadr[$bits(wb_address_t)-1:DCacheTagLoBit],2'b10,{DCacheTagLoBit-2{1'h0}}};
				load_cnt <= 2'd10;
				v[0] <= 1'b1;
				v[1] <= 1'b1;
				v[2] <= 1'b0;
				v[3] <= ~|cpu_request_i.sel[63:48];
			end
			else if (cpu_request_i,sel[47:32]) begin
				wbm_req.vadr <= {cpu_request_i.vadr[$bits(wb_address_t)-1:DCacheTagLoBit],2'b11,{DCacheTagLoBit-2{1'h0}}};
				load_cnt <= 2'd11;
				v[0] <= 1'b1;
				v[1] <= 1'b1;
				v[2] <= 1'b1;
				v[3] <= 1'b0;
			end
			// If nothing selected remain in STATE1
			else
				req_state <= STATE1;
			to_cnt <= 'd0;
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
			tid_cnt[7:4] <= CID;
			tid_cnt[2:0] <= tid_cnt[2:0] + 2'd1;
			wbm_req.cmd <= wishbone_pkg::CMD_DCACHE_LOAD;
			wbm_req.tid <= tid_cnt;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.we <= 1'b0;
			wbm_req.asid <= cpu_request_i.asid;
			wbm_req.vadr <= {cpu_request_i.vadr[$bits(wb_address_t)-1:DCacheTagLoBit],load_cnt[1:0],{DCacheTagLoBit-2{1'h0}}};
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
			v <= 4'b0000;
			resp_state <= STATE1;
		end
	STATE1:
		if (wbm_resp.ack) begin
			resp_state <= STATE2;
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			if (wbm_req.we && cache_dump)
				dump_cnt <= dump_cnt + 2'd1;
			if (!wbm_req.we || cache_load)
				load_cnt <= load_cnt + 2'd1;
			response_o.cid <= wbm_resp.cid;
			response_o.tid <= wbm_resp.tid;
			response_o.pri <= wbm_resp.pri;
			response_o.adr <= {wbm_resp.adr[$bits(wb_address_t)-1:6],6'd0};
			case(wbm_resp.adr[5:4])
			2'd0: begin response_o.dat[127:  0] <= wbm_resp.dat; v[0] <= 1'b1; end
			2'd1:	begin response_o.dat[255:128] <= wbm_resp.dat; v[1] <= 1'b1; end
			2'd2:	begin response_o.dat[383:256] <= wbm_resp.dat; v[2] <= 1'b1; end
			2'd3:	begin response_o.dat[511:384] <= wbm_resp.dat; v[3] <= 1'b1; end
			endcase
		end
		else if (wbm_resp.rty|wbm_resp.err) begin
			wbm_req.cyc <= 1'b0;
			wbm_req.stb <= 1'b0;
			wbm_req.sel <= 16'h0000;
			wbm_req.we <= 1'b0;
			response_o.rty <= wbm_resp.rty;
			response_o.err <= wbm_resp.err;
			response_o.ack <= 1'b0;
			v <= 4'b0000;
			req_state <= STATE6;
		end
	// Wait for ack to clear before continuing.
	STATE2:
		begin
			resp_state <= STATE3;
			// Line load complete or cpu access complete, pulse appropriate ack line.
			if (v==4'b1111) begin
				if (cache_dump)
					req_state <= STATE4;
				else if (~cpu_request_i.we || cache_load)
					req_state <= STATE1;
				load_cnt <= 'd0;
				dump_cnt <= 'd0;
				dump_ack <= cache_dump;
				v <= 4'b0000;
				iway <= lfsr_o[LOG_WAYS:0];
				// Write to cache only if response from TLB indicates a cacheable
				// address.
			end
		end
	STATE3:
		resp_state <= STATE4;
	// response_o.ack is delayed a couple of cycles to give time to read the
	// cache.
	STATE4:
		begin
			if (!wbm_resp.ack) begin
				if (v==4'b1111) begin
					wr <= cache_load | (~non_cacheable & dce & cpu_request_i.we & allocate);
					response_o.ack <= !cache_dump;
					cache_dump <= 'd0;
				end
				req_state <= req_state==STATE5 ? STATE4 : STATE1;
				resp_state <= STATE1;
			end
		end
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
