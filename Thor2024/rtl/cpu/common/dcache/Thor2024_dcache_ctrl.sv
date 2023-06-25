// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_dcache_ctrl.sv
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

module Thor2024_dcache_ctrl(rst_i, clk_i, dce, ftam_req, ftam_resp, ftam_full, acr, hit, modified,
	cache_load, cpu_request_i, cpu_request_i2, data_to_cache_o, response_from_cache_i, wr, uway, way,
	dump, dump_i, dump_ack, snoop_adr, snoop_v, snoop_cid);
parameter CID = 2;
parameter CORENO = 6'd1;
parameter WAYS = 4;
parameter NSEL = 32;
parameter WAIT = 6'd0;
localparam LOG_WAYS = $clog2(WAYS)-1;
input rst_i;
input clk_i;
input dce;
output fta_cmd_request128_t ftam_req;
input fta_cmd_response128_t ftam_resp;
input ftam_full;
input [3:0] acr;
input hit;
input modified;
output reg cache_load;
input fta_cmd_request512_t cpu_request_i;
output fta_cmd_request512_t cpu_request_i2;
output fta_cmd_response512_t data_to_cache_o;
input fta_cmd_response512_t response_from_cache_i;
output reg wr;
input [LOG_WAYS:0] uway;
output reg [LOG_WAYS:0] way;
input dump;
input DCacheLine dump_i;
output reg dump_ack;
input fta_address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;

genvar g;
integer nn,nn1,nn2,nn3,nn4,nn5;

typedef enum logic [2:0] {
	RESET = 0,
	STATE1,STATE3,STATE4,STATE5,RAND_DELAY
} state_t;
state_t req_state, resp_state;

reg [LOG_WAYS:0] iway;
fta_cmd_response512_t cache_load_data;
reg cache_dump;
reg [10:0] to_cnt;
reg [3:0] tid_cnt;
wire [16:0] lfsr_o;
reg [1:0] dump_cnt;
reg [511:0] upd_dat;
reg we_r;
reg [15:0] tran_active, tran_done;
reg [7:0] ndx;
reg [3:0] v [0:15];
reg [15:0] cache_load_r;
fta_cmd_request512_t cpu_req_queue [0:3];
fta_cmd_request128_t tran_req [0:15];
fta_cmd_response512_t tran_load_data [0:3];
fta_tranid_t [15:0] tranids;
reg [15:0] tran_out;
reg [4:0] last_out;
reg [15:0] is_dump;
reg req_load;
reg [1:0] load_cnt;
reg [5:0] wait_cnt;
reg [1:0] wr_cnt;
reg cpu_request_queued;
fta_tranid_t lasttid;
reg bus_busy;

always_comb
	bus_busy = ftam_resp.rty;

lfsr17 #(.WID(17)) ulfsr1
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

wire cache_type = cpu_request_i2.cache;
reg non_cacheable;
reg allocate;

always_comb
	non_cacheable =
	!dce ||
	cache_type==fta_bus_pkg::NC_NB ||
	cache_type==fta_bus_pkg::NON_CACHEABLE
	;
always_comb
	allocate =
	cache_type==fta_bus_pkg::CACHEABLE_NB ||
	cache_type==fta_bus_pkg::CACHEABLE ||
	cache_type==fta_bus_pkg::WT_READ_ALLOCATE ||
	cache_type==fta_bus_pkg::WT_WRITE_ALLOCATE ||
	cache_type==fta_bus_pkg::WT_READWRITE_ALLOCATE ||
	cache_type==fta_bus_pkg::WB_READ_ALLOCATE ||
	cache_type==fta_bus_pkg::WB_WRITE_ALLOCATE ||
	cache_type==fta_bus_pkg::WB_READWRITE_ALLOCATE
	;
// Comb logic so that hits do not take an extra cycle.
always_comb
	if (hit) begin
		way = uway;
		data_to_cache_o = response_from_cache_i;
		data_to_cache_o.ack = 1'b1;
	end
	else begin
		way = iway;
		data_to_cache_o = cache_load_data;
		data_to_cache_o.dat = upd_dat;
	end

// Selection of data used to update cache.
// For a write request the data includes data from the CPU.
// Otherwise it is just a cache line load, all data comes from the response.
// Note data is passed in 512-bit chunks.
generate begin : gCacheLineUpdate
	for (g = 0; g < 64; g = g + 1) begin : gFor
		always_comb
			if (cpu_req_queue[ndx].we) begin
				if (cpu_req_queue[ndx].sel[g])
					upd_dat[g*8+7:g*8] <= cpu_req_queue[ndx].dat[g*8+7:g*8];
				else
					upd_dat[g*8+7:g*8] <= data_to_cache_o.dat[g*8+7:g*8];
			end
			else
				upd_dat[g*8+7:g*8] <= cache_load_data[g*8+7:g*8];
	end
end
endgenerate				

always_comb
begin
	nn2 = 'd16;
	for (nn1 = 0; nn1 < 4; nn1 = nn1 + 1)
		if (cpu_req_queue[nn1].cyc)
			nn2 = nn1;
end

// Select a transaction to output
always_comb
begin
	nn4 = 'd16;
	for (nn3 = 0; nn3 < 16; nn3 = nn3 + 1) begin
		if (tran_active[nn3]
			&& !tran_out[nn3] 
			&& !tran_done[nn3] 
			&& !tran_load_data[nn3>>2].ack
			&& nn4=='d16)
			nn4 = nn3;
	end
end

// Get index of completed transaction.
always_comb
begin
	ndx = 8'd16;
	for (nn5 = 0; nn5 < 4; nn5 = nn5 + 1)
		if (tran_done[{nn5[1:0],2'b00}]
			&& tran_done[{nn5[1:0],2'b01}]
			&& tran_done[{nn5[1:0],2'b10}]
			&& tran_done[{nn5[1:0],2'b11}])
			ndx = nn;
end

always_ff @(posedge clk_i)
if (rst_i) begin
	req_state <= RESET;
	resp_state <= RESET;
	to_cnt <= 'd0;
	tid_cnt <= 'd0;
	lasttid <= 'd0;
	dump_ack <= 1'd0;
	wr <= 1'b0;
	cache_load_data <= 'd0;
	ftam_req <= 'd0;
	dump_cnt <= 'd0;
	load_cnt <= 'd0;
	cache_load <= 'd0;
	cache_load_r <= 'd0;
	cache_dump <= 'd0;
	for (nn = 0; nn < 16; nn = nn + 1) begin
		tran_req[nn] <= 'd0;
	end
	for (nn = 0; nn < 4; nn = nn + 1) begin
		tran_load_data[nn] <= 'd0;
		cpu_req_queue[nn] <= 'd0;
	end
	tran_active <= 'd0;
	tran_out <= 'd0;
	tran_done <= 'd0;
	req_load <= 'd0;
	load_cnt <= 'd0;
	wait_cnt <= 'd0;
	wr_cnt <= 'd0;
	is_dump <= 'd0;
	cpu_request_queued <= 'd1;
	cpu_request_i2 <= 'd0;
	last_out <= 'd16;
end
else begin
	dump_ack <= 1'd0;
	cache_load_data.stall <= 1'b0;
	cache_load_data.next <= 1'b0;
	cache_load_data.ack <= 1'b0;
	cache_load_data.pri <= 4'd7;
	wr <= 1'b0;
	// Grab the bus for only 1 clock.
	if (ftam_req.cyc)
		tBusClear();
	// Ack pulses for only 1 clock.
	for (nn = 0; nn < 4; nn = nn + 1)
		tran_load_data[nn].ack <= 1'b0;
	if (cpu_request_i.cyc)
		cpu_req_queue[cpu_request_i.tid & 3] <= cpu_request_i;
	case(req_state)
	RESET:
		begin
			ftam_req.cmd <= fta_bus_pkg::CMD_DCACHE_LOAD;
			ftam_req.sz  <= fta_bus_pkg::hexi;
			ftam_req.blen <= 'd0;
			ftam_req.cid <= 3'd7;					// CPU channel id
			ftam_req.tid <= 'd0;						// transaction id (not used)
			ftam_req.csr  <= 'd0;					// clear/set reservation
			ftam_req.pl	<= 'd0;						// privilege level
			ftam_req.pri	<= 4'h7;					// average priority (higher is better).
			ftam_req.cache <= fta_bus_pkg::CACHEABLE;
			ftam_req.seg <= fta_bus_pkg::DATA;
			ftam_req.bte <= fta_bus_pkg::LINEAR;
			ftam_req.cti <= fta_bus_pkg::CLASSIC;
			tBusClear();
			wr_cnt <= 'd0;
			req_state <= STATE1;
		end
	STATE1:
		begin
			// Look for transactions to perform.
			if (req_load && !cache_dump) begin
				if (!modified) begin
					if (load_cnt==2'd3) begin
						req_load <= 1'b0;
						cpu_request_queued <= 1'b1;
					end
					else begin
						tAddr(
							cpu_request_i2.om,
							1'b0,
							!non_cacheable,
							cpu_request_i2.asid,
							{cpu_request_i2.vadr[$bits(fta_address_t)-1:Thor2024_cache_pkg::DCacheTagLoBit],load_cnt,{Thor2024_cache_pkg::DCacheTagLoBit-2{1'h0}}},
							16'hFFFF,
							'd0,
							cpu_request_i2.tid,
							load_cnt
						);
						load_cnt <= load_cnt + 2'd1;
					end
				end
				else begin
					cache_dump <= 1'b1;
					dump_cnt <= 'd0;
				end
			end
			else if (((!hit && allocate && dce && modified && cpu_request_i2.cyc) || cache_dump)) begin
			if (cache_dump && dump_cnt==2'd3)
					cache_dump <= 1'b0;
				else begin
					cache_dump <= 1'b1;
					is_dump[{cpu_request_i2.tid[1:0],dump_cnt}] <= 1'b1;
					tAddr(
						cpu_request_i2.om,
						1'b1,
						!non_cacheable,
						dump_i.asid,
						{dump_i.vtag[$bits(fta_address_t)-1:Thor2024_cache_pkg::DCacheTagLoBit],dump_cnt[1:0],{Thor2024_cache_pkg::DCacheTagLoBit-2{1'h0}}},
						16'hFFFF,
						dump_i.data >> {dump_cnt,7'd0},
						cpu_request_i2.tid,
						dump_cnt
					);
					dump_cnt <= dump_cnt + 2'd1;
				end
			end
			// It may have missed because a non-cacheable address is being accessed.
			else if (!hit && (cpu_request_i2.cyc || wr_cnt != 2'd0) && !cpu_request_queued && !req_load) begin
				if (!(non_cacheable & cpu_request_i2.cyc) && (allocate)) begin
					req_load <= 1'b1;
					load_cnt <= 'd0;
				end
				else
					tAccess();
			end
			else if (hit /*&& !cpu_request_queued*/) begin
				
				// If it is not a writeback cache and a write cycle, write to memory.
				if (!(cpu_request_i2.cache == fta_bus_pkg::WB_READ_ALLOCATE ||
					cpu_request_i2.cache == fta_bus_pkg::WB_WRITE_ALLOCATE ||
					cpu_request_i2.cache == fta_bus_pkg::WB_READWRITE_ALLOCATE
				) && (cpu_request_i2.we || wr_cnt != 2'd0))
					tAccess();
			end
			// Look for outstanding transactions to execute.
			else begin
				if (nn4 < 'd16) begin
					if (!ftam_full) begin
						last_out <= nn4;
						tran_out[nn4] <= 1'b1;
						ftam_req <= tran_req[nn4];
						wait_cnt <= 'd0;
						req_state <= RAND_DELAY;
					end
				end
			end
			if (cpu_request_i2.tid != lasttid) begin // && cpu_request_queued) begin
				lasttid <= cpu_request_i2.tid;
				cpu_request_queued <= 1'b0;
				wr_cnt <= 'd0;
			end
		end
	STATE5:
		begin
			to_cnt <= to_cnt + 2'd1;
			if (ftam_resp.ack) begin
				tBusClear();
				req_state <= RAND_DELAY;
			end
			else if (ftam_resp.rty) begin
				tBusClear();
				req_state <= STATE1;
			end
			if (to_cnt[10]) begin
				tBusClear();
				req_state <= RAND_DELAY;
			end
		end
	// Wait some random number of clocks before trying again.
	RAND_DELAY:
		begin
			tBusClear();
			if (lfsr_o[1:0]==2'b11)
				req_state <= STATE1;
		end
	default:	req_state <= RESET;
	endcase

	// Process responses.
	// Could have a string of ack's coming back due to a string of requests.
	if (ftam_resp.ack) begin
		// Got an ack back so the tran no longer needs to be performed.
		tran_active[ftam_resp.tid.tranid] <= 1'b0;
		tran_out[ftam_resp.tid.tranid] <= 1'b0;
		tran_done[ftam_resp.tid.tranid] <= 1'b1;
		//tran_req[ftam_resp.tid & 4'hF].cyc <= 1'b0;
		tran_load_data[ftam_resp.tid.tranid>>2].cid <= ftam_resp.cid;
		tran_load_data[ftam_resp.tid.tranid>>2].tid <= ftam_resp.tid;
		tran_load_data[ftam_resp.tid.tranid>>2].pri <= ftam_resp.pri;
		tran_load_data[ftam_resp.tid.tranid>>2].adr <= {ftam_resp.adr[$bits(fta_address_t)-1:6],6'd0};
		case(ftam_resp.adr[5:4])
		2'd0: begin tran_load_data[ftam_resp.tid.tranid>>2].dat[127:  0] <= ftam_resp.dat; v[ftam_resp.tid.tranid][0] <= 1'b1; end
		2'd1:	begin tran_load_data[ftam_resp.tid.tranid>>2].dat[255:128] <= ftam_resp.dat; v[ftam_resp.tid.tranid][1] <= 1'b1; end
		2'd2:	begin tran_load_data[ftam_resp.tid.tranid>>2].dat[383:256] <= ftam_resp.dat; v[ftam_resp.tid.tranid][2] <= 1'b1; end
		2'd3:	begin tran_load_data[ftam_resp.tid.tranid>>2].dat[511:384] <= ftam_resp.dat; v[ftam_resp.tid.tranid][3] <= 1'b1; end
		endcase
		we_r <= ftam_req.we;
		tran_load_data[ftam_resp.tid.tranid>>2].rty <= 1'b0;
		tran_load_data[ftam_resp.tid.tranid>>2].err <= 1'b0;
		v[ftam_resp.tid.tranid][ftam_resp.adr[5:4]] <= 'd1;
	end
	// Retry or error (only if transaction active)
	// Abort the memory request. Go back and try again.
	else if ((ftam_resp.rty|ftam_resp.err) && ftam_resp.tid.tranid[3:0]==last_out[3:0]) begin
		tran_load_data[last_out[3:2]].rty <= ftam_resp.rty;
		tran_load_data[last_out[3:2]].err <= ftam_resp.err;
		tran_load_data[last_out[3:2]].ack <= 1'b0;
		tran_out[last_out[3:0]] <= 1'b0;
		v[last_out[3:0]][ftam_resp.adr[5:4]] <= 'd0;
	end
	// Acknowledge completed transactions.
	for (nn = 0; nn < 4; nn = nn + 1)
		if (tran_done[{nn[1:0],2'b00}]
			&& tran_done[{nn[1:0],2'b01}]
			&& tran_done[{nn[1:0],2'b10}]
			&& tran_done[{nn[1:0],2'b11}]) begin
			tran_load_data[nn[1:0]].ack <= 1'b1;
			tran_done[{nn[1:0],2'b00}] <= 1'b0;
			tran_done[{nn[1:0],2'b01}] <= 1'b0;
			tran_done[{nn[1:0],2'b10}] <= 1'b0;
			tran_done[{nn[1:0],2'b11}] <= 1'b0;
			dump_ack <= is_dump[nn];
			is_dump[nn] <= 'd0;
			iway <= lfsr_o[LOG_WAYS:0];
			cache_load_data <= tran_load_data[nn];
			cache_load_data.tid <= tranids[nn];
//			resp_state <= STATE3;
			// Write to cache only if response from TLB indicates a cacheable
			// address.
		end

	// We want to update the cache, but if its allocate on write the
	// cache needs to be loaded with data from RAM first before its
	// updated. Request a cache load.
	if (ndx < 8'd16) begin
		if (!hit & (~non_cacheable & dce & cpu_request_i.we & allocate) & !cache_load_r[ndx[1:0]]) begin
			cache_load_r[ndx[1:0]] <= 1'b1;
			req_load <= 1'b1;
			load_cnt <= 'd0;
		end
		// If we have a hit on the cache line, write the data to the cache if
		// it is a writeable cacheable transaction.
		else if (hit) begin
			wr <= (~non_cacheable & dce & cpu_request_i.we & allocate);
			cache_load_data.ack <= !cache_dump;
			cache_dump <= 'd0;
			cache_load <= 'd0;
			cache_load_r[ndx[1:0]] <= 'd0;
	//		resp_state <= STATE1;
		end
		// No hit on the cache line and not allocating, we're done.
		else begin
			cache_load_data.ack <= !cache_dump;
			cache_load <= 'd0;
			cache_load_r[ndx[1:0]] <= 'd0;
	//		resp_state <= STATE1;
		end
	end

	// Process responses.
	case(resp_state)
	RESET:
		begin
			for (nn = 0; nn < 16; nn = nn + 1)
				v[nn] <= 'd0;
			resp_state <= STATE1;
		end
	STATE1:
		begin
		end
	STATE3:
		resp_state <= STATE4;
	// cache_load_data.ack is delayed a couple of cycles to give time to read the
	// cache.
	STATE4:
		begin
			if (!ftam_resp.ack) begin
			end
			else
				resp_state <= STATE1;
		end
	default:	resp_state <= STATE1;
	endcase
	// Only the cache index need be compared for snoop hit.
	if (snoop_v && snoop_adr[Thor2024_cache_pkg::ITAG_BIT:Thor2024_cache_pkg::ICacheTagLoBit]==
		cpu_request_i2.vadr[Thor2024_cache_pkg::ITAG_BIT:Thor2024_cache_pkg::ICacheTagLoBit] && snoop_cid==CID) begin
		/*
		tBusClear();
		wr <= 1'b0;
		// Force any transactions matching the snoop address to retry.
		for (nn = 0; nn < 16; nn = nn + 1) begin
			// Note: the tag bits are compared only for the addresses that would match
			// between the virtual and physical. The cache line number. Need to match on 
			// the physical address returning from snoop, but only have the virtual
			// address available.
			if (cpu_request_i2.vadr[Thor2024_cache_pkg::ITAG_BIT:Thor2024_cache_pkg::ICacheTagLoBit] ==
				tran_load_data[nn].adr[Thor2024_cache_pkg::ITAG_BIT:Thor2024_cache_pkg::ICacheTagLoBit]) begin
				v[nn] <= 'd0;
				tran_load_data[nn].rty <= 1'b1;
			end
			if (cpu_request_i2.vadr[Thor2024_cache_pkg::ITAG_BIT:Thor2024_cache_pkg::ICacheTagLoBit]==
				cpu_req_queue[nn].vadr[Thor2024_cache_pkg::ITAG_BIT:Thor2024_cache_pkg::ICacheTagLoBit])
				cpu_req_queue[nn] <= 'd0;
		end
		*/
		req_state <= STATE1;		
		resp_state <= STATE1;	
	end
	if (nn2 < 16 && cpu_req_queue[nn2[1:0]].cyc) begin
		cpu_request_i2 <= cpu_req_queue[nn2[1:0]];
		cpu_req_queue[nn2[1:0]].cyc <= 'd0;
	end
end

task tBusClear;
begin
	ftam_req.cyc <= 1'b0;
	ftam_req.stb <= 1'b0;
	ftam_req.sel <= 16'h0000;
	ftam_req.we <= 1'b0;
end
endtask

task tAddr;
input fta_operating_mode_t om;
input wr;
input cache;
input Thor2024pkg::asid_t asid;
input Thor2024pkg::address_t adr;
input [15:0] sel;
input [127:0] data;
input fta_tranid_t tid;
input [1:0] which;
integer ndx;
begin
	ndx = {tid[1:0],which};
	tranids[ndx] <= tid;
	to_cnt <= 'd0;
	tran_req[ndx].om <= om;
	tran_req[ndx].cmd <= wr ? fta_bus_pkg::CMD_STORE : 
		cache ? fta_bus_pkg::CMD_DCACHE_LOAD : fta_bus_pkg::CMD_LOADZ;
	tran_req[ndx].sz <= fta_bus_pkg::hexi;
	tran_req[ndx].blen <= 'd0;
	tran_req[ndx].cid <= tid.channel;
	tran_req[ndx].tid.core <= tid.core;
	tran_req[ndx].tid.channel <= tid.channel;
	tran_req[ndx].tid.tranid <= ndx;
	tran_req[ndx].bte <= fta_bus_pkg::LINEAR;
	tran_req[ndx].cti <= fta_bus_pkg::CLASSIC;
	tran_req[ndx].cyc <= 1'b1;
	tran_req[ndx].stb <= 1'b1;
	tran_req[ndx].sel <= sel;
	tran_req[ndx].we <= wr;
	tran_req[ndx].csr <= 'd0;
	tran_req[ndx].asid <= asid;
	tran_req[ndx].vadr <= adr;
	tran_req[ndx].data1 <= data;
	tran_req[ndx].pl <= 'd0;
	tran_req[ndx].pri <= 4'h7;
	tran_req[ndx].cache <= fta_bus_pkg::CACHEABLE;
	tran_req[ndx].seg <= fta_bus_pkg::DATA;
	tran_active[ndx] <= 1'b1;
	tran_done[ndx] <= 1'b0;
	tran_load_data[ndx].adr <= adr;
end
endtask

task tAccess;
fta_address_t ta;
begin
	if (wr_cnt == 2'd3) begin
		cpu_request_queued <= 1'b1;
		wr_cnt <= 'd0;
	end
	// Access only the strip of memory requested. It could be an I/O device.
	if (wr_cnt==2'd0)
		v[tid_cnt & 4'hF] <= 4'b1111;
	ta = {cpu_request_i2.vadr[$bits(fta_address_t)-1:Thor2024_cache_pkg::DCacheTagLoBit],wr_cnt,{Thor2024_cache_pkg::DCacheTagLoBit-2{1'h0}}};
	case(wr_cnt)
	2'd0:	
		begin
			wr_cnt <= 2'd1;
			if (|cpu_request_i2.sel[15: 0]) begin
				v[tid_cnt & 4'hF][0] <= 1'b0;
				tAddr(
					cpu_request_i2.om,
					cpu_request_i2.we,
					!non_cacheable,
					cpu_request_i2.asid,
					{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd0,4'h0},
					cpu_request_i2.sel[15:0],
					cpu_request_i2.dat[127:0],
					cpu_request_i2.tid,
					2'd0
				);
				req_state <= RAND_DELAY;
			end
			else begin
				tran_done[{cpu_request_i2.tid[1:0],2'b00}] <= 1'b1;
				wr_cnt <= 2'd2;
				if (|cpu_request_i2.sel[31:16]) begin
					v[tid_cnt & 4'hF][1] <= 1'b0;
					tAddr(
						cpu_request_i2.om,
						cpu_request_i2.we,
						!non_cacheable,
						cpu_request_i2.asid,
						{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd1,4'h0},
						cpu_request_i2.sel[31:16],
						cpu_request_i2.dat[255:128],
						cpu_request_i2.tid,
						2'd1
					);
					req_state <= RAND_DELAY;
				end
				else begin
					tran_done[{cpu_request_i2.tid[1:0],2'b01}] <= 1'b1;
					wr_cnt <= 2'd3;
					if (|cpu_request_i2.sel[47:32]) begin
						v[tid_cnt & 4'hF][2] <= 1'b0;
						tAddr(
							cpu_request_i2.om,
							cpu_request_i2.we,
							!non_cacheable,
							cpu_request_i2.asid,
							{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd2,4'h0},
							cpu_request_i2.sel[47:32],
							cpu_request_i2.dat[383:256],
							cpu_request_i2.tid,
							2'd2
						);
						req_state <= RAND_DELAY;
					end
					else begin
						tran_done[{cpu_request_i2.tid[1:0],2'b10}] <= 1'b1;
						wr_cnt <= 2'd0;
						cpu_request_queued <= 1'b1;
						if (|cpu_request_i2.sel[63:48]) begin
							v[tid_cnt & 4'hF][3] <= 1'b0;
							tAddr(
								cpu_request_i2.om,
								cpu_request_i2.we,
								!non_cacheable,
								cpu_request_i2.asid,
								{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd3,4'h0},
								cpu_request_i2.sel[63:48],
								cpu_request_i2.dat[511:384],
								cpu_request_i2.tid,
								2'd3
							);
							req_state <= RAND_DELAY;
						end
						else
							tran_done[{cpu_request_i2.tid[1:0],2'b11}] <= 1'b1;
					end
				end
			end
		end
	2'd1:	
		begin
			wr_cnt <= 2'd2;
			if (|cpu_request_i2.sel[31:16]) begin
				v[tid_cnt & 4'hF][1] <= 1'b0;
				tAddr(
					cpu_request_i2.om,
					cpu_request_i2.we,
					!non_cacheable,
					cpu_request_i2.asid,
					{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd1,4'h0},
					cpu_request_i2.sel[31:16],
					cpu_request_i2.dat[255:128],
					cpu_request_i2.tid,
					2'd1
				);
				req_state <= RAND_DELAY;
			end
			else begin
				tran_done[{cpu_request_i2.tid[1:0],2'b01}] <= 1'b1;
				wr_cnt <= 2'd3;
				if (|cpu_request_i2.sel[47:32]) begin
					v[tid_cnt & 4'hF][2] <= 1'b0;
					tAddr(
						cpu_request_i2.om,
						cpu_request_i2.we,
						!non_cacheable,
						cpu_request_i2.asid,
						{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd2,4'h0},
						cpu_request_i2.sel[47:32],
						cpu_request_i2.dat[383:256],
						cpu_request_i2.tid,
						2'd2
					);
					req_state <= RAND_DELAY;
				end
				else begin
					tran_done[{cpu_request_i2.tid[1:0],2'b10}] <= 1'b1;
					wr_cnt <= 2'd0;
					cpu_request_queued <= 1'b1;
					if (|cpu_request_i2.sel[63:48]) begin
						v[tid_cnt & 4'hF][3] <= 1'b0;
						tAddr(
							cpu_request_i2.om,
							cpu_request_i2.we,
							!non_cacheable,
							cpu_request_i2.asid,
							{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd3,4'h0},
							cpu_request_i2.sel[63:48],
							cpu_request_i2.dat[511:384],
							cpu_request_i2.tid,
							2'd3
						);
						req_state <= RAND_DELAY;
					end
					else
						tran_done[{cpu_request_i2.tid[1:0],2'b11}] <= 1'b1;
				end
			end
		end
	2'd2:
		begin
			wr_cnt <= 2'd3;
			if (|cpu_request_i2.sel[47:32]) begin
				v[tid_cnt & 4'hF][2] <= 1'b0;
				tAddr(
					cpu_request_i2.om,
					cpu_request_i2.we,
					!non_cacheable,
					cpu_request_i2.asid,
					{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd2,4'h0},
					cpu_request_i2.sel[47:32],
					cpu_request_i2.dat[383:256],
					cpu_request_i2.tid,
					2'd2
				);
				req_state <= RAND_DELAY;
			end
			else begin
				tran_done[{cpu_request_i2.tid[1:0],2'b10}] <= 1'b1;
				wr_cnt <= 2'd0;
				cpu_request_queued <= 1'b1;
				if (|cpu_request_i2.sel[63:48]) begin
					v[tid_cnt & 4'hF][3] <= 1'b0;
					tAddr(
						cpu_request_i2.om,
						cpu_request_i2.we,
						!non_cacheable,
						cpu_request_i2.asid,
						{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd3,4'h0},
						cpu_request_i2.sel[63:48],
						cpu_request_i2.dat[511:384],
						cpu_request_i2.tid,
						2'd3
					);
					req_state <= RAND_DELAY;
				end
				else
					tran_done[{cpu_request_i2.tid[1:0],2'b11}] <= 1'b1;
			end
		end
	2'd3: 
		begin
			wr_cnt <= 2'd0;
			cpu_request_queued <= 1'b1;
			if (|cpu_request_i2.sel[63:48]) begin
				v[tid_cnt & 4'hF][3] <= 1'b0;
				tAddr(
					cpu_request_i2.om,
					cpu_request_i2.we,
					!non_cacheable,
					cpu_request_i2.asid,
					{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd3,4'h0},
					cpu_request_i2.sel[63:48],
					cpu_request_i2.dat[511:384],
					cpu_request_i2.tid,
					2'd3
				);
				req_state <= RAND_DELAY;
			end
			else
				tran_done[{cpu_request_i2.tid[1:0],2'b11}] <= 1'b1;
		end
	endcase
end
endtask

endmodule
