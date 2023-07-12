// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
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

import fta_bus_pkg::*;
import Thor2024Mmupkg::*;
import Thor2024pkg::*;

module Thor2024_ptable_walker(rst, clk, tlbmiss,
	ftas_req, ftas_resp, ftam_req, ftam_resp, fault_o);
parameter CID = 6'd3;

parameter IO_ADDR = 32'hFEFC0001;
parameter IO_ADDR_MASK = 32'h00FF0000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd14;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h00;					// 00 = RAM
parameter CFG_CLASS = 8'h05;						// 05 = memory controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'd27;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

input rst;
input clk;
input tlbmiss;
input fta_cmd_request128_t ftas_req;
output fta_cmd_response128_t ftas_resp;
output fta_cmd_request128_t ftam_req;
input fta_cmd_response128_t ftam_resp;
output [31:0] fault_o;

integer nn,n1,n2;

typedef enum logic [3:0] {
	IDLE = 4'd0,
	STATE1,
	STATE2,
	STATE3,
	UPD1,
	UPD2,
	UPD3,
	UPD4,
	UPD5,
	RDMISS1,
	RDMISS2,
	FAULT
} state_t;
state_t req_state;

typedef struct packed {
	logic v;				// valid
	logic o;				// out
	asid_t asid;
	address_t adr;
} miss_stack_t;

typedef struct packed {
	logic [1:0] t;			// type: 0=fetch pte, 1=update pte, 2=read miss info
	logic v;
	logic rdy;
	fta_tranid_t id;
	logic [1:0] stk;
	asid_t asid;
	address_t vadr;
	address_t padr;
	SHPTE pte;
	logic [127:0] dat;
} tran_buf_t;

typedef struct packed
{
	logic v;
	logic [31:16] ptr;
} rootptr_t;

ptbr_t ptbr;
wire sack;
reg [63:0] fault_adr;
asid_t fault_asid;
reg tlbmiss_ip;		// miss processing in progress.
reg hit, fault;
reg upd_req;
tran_buf_t [15:0] tranbuf;
fta_tranid_t tid;
miss_stack_t [3:0] miss_stack;
reg [2:0] miss_sp;
reg [31:0] miss_adr = miss_stack[miss_sp].adr;
reg [7:0] miss_asid = miss_stack[miss_sp].asid;
reg wr1,wr2;
reg [1:0] stk;
reg [63:0] stlb_adr;
reg [10:0] addrb;
reg cs_config, cs_hwtw;

rootptr_t root_ptrs, root_ptrs2;

   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(11),               // DECIMAL
      .ADDR_WIDTH_B(11),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(rootptr_t)),        // DECIMAL
      .BYTE_WRITE_WIDTH_B($bits(rootptr_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(2048*$bits(rootptr_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(rootptr_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(rootptr_t)),         // DECIMAL
      .READ_LATENCY_A(1),             // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(rootptr_t)),        // DECIMAL
      .WRITE_DATA_WIDTH_B($bits(rootptr_t)),        // DECIMAL
      .WRITE_MODE_A("no_change"),     // String
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(root_ptrs),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(root_ptrs2),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(sreq.padr[13:3]),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(addrb),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(sreq.data1[32:16]),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb('d0),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(1'b0),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(cs_hwtw && sreq.we && sreq.padr[15:14]==2'd0),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(1'b0)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );


asid_t asid;
address_t vadr;
SHPTE pte;
reg [31:0] tlbmiss_adr;
reg [11:0] tlbmiss_asid;
reg tlbmiss_v;

fta_cmd_request128_t sreq;
fta_cmd_response128_t sresp;
wire irq_en;
wire [127:0] cfg_out;

always_ff @(posedge clk)
	sreq <= ftas_req;
always_ff @(posedge clk)
begin
	ftas_resp <= sresp;
	ftas_resp.ack <= sack;
end

always_ff @(posedge clk)
	cs_config <= ftas_req.cyc && ftas_req.stb &&
		ftas_req.padr[31:28]==4'hD &&
		ftas_req.padr[27:20]==CFG_BUS &&
		ftas_req.padr[19:15]==CFG_DEVICE &&
		ftas_req.padr[14:12]==CFG_FUNC;

always_comb
	cs_hwtw <= cs_tw && sreq.cyc && sreq.stb;

vtdl #(.WID(1), .DEP(16)) urdyd1 (.clk(clk_i), .ce(1'b1), .a(4'd1), .d(cs_hwtw|cs_config), .q(sack));

pci128_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
	.CFG_BAR1('d0),
	.CFG_BAR1_MASK('d0),
	.CFG_SUBSYSTEM_VENDOR_ID(CFG_SUBSYSTEM_VENDOR_ID),
	.CFG_SUBSYSTEM_ID(CFG_SUBSYSTEM_ID),
	.CFG_ROM_ADDR(CFG_ROM_ADDR),
	.CFG_REVISION_ID(CFG_REVISION_ID),
	.CFG_PROGIF(CFG_PROGIF),
	.CFG_SUBCLASS(CFG_SUBCLASS),
	.CFG_CLASS(CFG_CLASS),
	.CFG_CACHE_LINE_SIZE(CFG_CACHE_LINE_SIZE),
	.CFG_MIN_GRANT(CFG_MIN_GRANT),
	.CFG_MAX_LATENCY(CFG_MAX_LATENCY),
	.CFG_IRQ_LINE(CFG_IRQ_LINE)
)
upci
(
	.rst_i(rst),
	.clk_i(clk),
	.irq_i(fault & irq_en),
	.irq_o(fault_o),
	.cs_config_i(cs_config),
	.we_i(sreq.we),
	.sel_i(sreq.sel),
	.adr_i(sreq.padr),
	.dat_i(sreq.data1),
	.dat_o(cfg_out),
	.cs_bar0_o(cs_tw),
	.cs_bar1_o(),
	.cs_bar2_o(),
	.irq_en_o(irq_en)
);

always_ff @(posedge clk, posedge rst)
if (rst) begin
	stlb_adr <= 64'h0FEF00000;
	ptbr <= 'd0;
end
else begin
	if (cs_hwtw && sreq.we)
		casez(sreq.padr[15:0])
		16'hFF20:	ptbr <= sreq.data1[63:0];
		16'hFF30: stlb_adr <= sreq.data1[63:0];
		default:	;
		endcase
end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	sresp <= 'd0;
end
else begin
	if (cs_config)
		sresp.dat <= cfg_out;
	else if (cs_hwtw) begin
		sresp.dat <= 'd0;
		casez(sreq.padr[15:0])
		16'b00??????????????:	sresp.dat <= {root_ptrs.ptr,16'd0};
		16'hFF00:	sresp.dat[63: 0] <= fault_adr;
		16'hFF10:	sresp.dat[59:48] <= fault_asid;
		16'hFF20:	sresp.dat[63: 0] <= ptbr;
		16'hFF30: sresp.dat[63: 0] <= stlb_adr;
		default:	sresp.dat <= 'd0;
		endcase
	end
	else
		sresp.dat <= 'd0;
end

always_comb
begin
	hit = 1'b0;
	for (n1 = 0; n1 < 4; n1 = n1 + 1) begin
		if ({1'b1,1'b0,tlbmiss_asid,tlbmiss_adr}==miss_stack[n1] && tlbmiss_v)
			hit = 1'b1;
		if ({1'b1,1'b1,tlbmiss_asid,tlbmiss_adr}==miss_stack[n1] && tlbmiss_v)
			hit = 1'b1;
	end
end

always_ff @(posedge clk)
if (rst) begin
	tlbmiss_ip <= 'd0;
	miss_sp <= 'd0;
	ftam_req <= 'd0;
	ftam_req.cid <= CID;
	ftam_req.bte <= fta_bus_pkg::LINEAR;
	ftam_req.cti <= fta_bus_pkg::CLASSIC;
	tid <= 8'd1;
	stk <= 'd0;
	upd_req <= 'd0;
	for (nn = 0; nn < 4; nn = nn + 1)
		miss_stack[nn] <= 'd0;
end
else begin

	// Capture miss
	if (tlbmiss && !hit && !tlbmiss_ip) begin
		if (!(tlbmiss_asid==asid && tlbmiss_adr==vadr && tlbmiss_v)) begin
			for (nn = 0; nn < 4; nn = nn + 1)
				if (~miss_stack[nn].v) begin
					miss_stack[nn] <= {1'b1,1'b0,tlbmiss_asid,tlbmiss_adr};
					tlbmiss_v <= 1'b0;
				end
		end
	end

	case(req_state)
	IDLE:
		if (upd_req) begin
			upd_req <= 'd0;
			ftam_req.cyc <= 1'b1;
			ftam_req.stb <= 1'b1;
			ftam_req.we <= 1'b1;
			ftam_req.sel <= 16'h00FF;
			ftam_req.vadr <= stlb_adr;
			ftam_req.data1 <= pte[63:0];
			ftam_req.tid <= tid;
			tid <= tid + 2'd1;
			if (&tid)
				tid <= 8'd1;
			req_state <= UPD1;
		end
		// On a miss issue a read request to the STLB.
		else if (tlbmiss && !tlbmiss_ip) begin
			tlbmiss_ip <= 1'b1;
			ftam_req.cyc <= 1'b1;
			ftam_req.stb <= 1'b1;
			ftam_req.we <= 1'b0;
			ftam_req.sel <= 16'hFFFF;
			ftam_req.vadr <= stlb_adr + 8'd125;	// Read TLBE port
			ftam_req.data1 <= 'd0;
			ftam_req.tid <= tid;
			tid <= tid + 2'd1;
			if (&tid)
				tid <= 8'd1;
			req_state <= RDMISS1;
		end
		else begin
			for (nn = 0; nn < 4; nn = nn + 1) begin
				if (miss_stack[nn].v & ~miss_stack[nn].o) begin
					if (ptbr.level==4'd0) begin
						miss_stack[nn].o <= 1'b1;
						ftam_req.cyc <= 1'b1;
						ftam_req.stb <= 1'b1;
						ftam_req.we <= 1'b0;
						ftam_req.sel <= 64'h0FFFF << {miss_stack[nn].adr[18:16],3'b0};
						ftam_req.asid <= miss_stack[nn].asid;
						ftam_req.vadr <= {ptbr.adr,miss_stack[nn].adr[28:16],3'b0};
						ftam_req.tid <= tid;
						tid <= tid + 2'd1;
						if (&tid)
							tid <= 8'd1;
						stk <= nn;
						req_state <= STATE3;
					end
					else begin
						addrb <= {miss_stack[nn].asid[7:0],miss_stack[nn].adr[31:29]};
						req_state <= STATE2;
					end
				end
			end
		end
	STATE2:
		begin
			if (root_ptrs2.v) begin
				miss_stack[nn].o <= 1'b1;
				ftam_req.cyc <= 1'b1;
				ftam_req.stb <= 1'b1;
				ftam_req.we <= 1'b0;
				ftam_req.sel <= 64'h0FFFF << {miss_stack[nn].adr[18:16],3'b0};
				ftam_req.asid <= miss_stack[nn].asid;
				ftam_req.vadr <= {root_ptrs2.ptr,miss_stack[nn].adr[28:16],3'b0};
				ftam_req.tid <= tid;
				tid <= tid + 2'd1;
				if (&tid)
					tid <= 8'd1;
				stk <= nn;
				req_state <= STATE3;
			end
			else begin
				fault <= 1'b1;
				fault_asid <= miss_stack[nn].asid;
				fault_adr <= {root_ptrs2.ptr,miss_stack[nn].adr[28:16],3'b0};
				req_state <= FAULT;
			end
		end
	STATE3:
		begin
			tranbuf[ftam_req.tid & 15].t <= 2'd0;
			tranbuf[ftam_req.tid & 15].v <= 1'b1;
			tranbuf[ftam_req.tid & 15].rdy <= 1'b0;
			tranbuf[ftam_req.tid & 15].asid <= ftam_req.asid;
			tranbuf[ftam_req.tid & 15].vadr <= ftam_req.vadr;
			tranbuf[ftam_req.tid & 15].stk <= stk;
			if (!ftam_resp.rty) begin
				ftam_req.cyc <= 1'b0;
				ftam_req.stb <= 1'b0;
				ftam_req.sel <= 'd0;
				req_state <= IDLE;
			end
		end
	UPD1:
		begin
			tranbuf[ftam_req.tid & 15].t <= 2'd1;
			tranbuf[ftam_req.tid & 15].v <= 1'b1;
			tranbuf[ftam_req.tid & 15].rdy <= 1'b0;
			if (!ftam_resp.rty) begin
				ftam_req.vadr <= stlb_adr + 8'd16;
				ftam_req.data1 <= vadr[31:0];
				ftam_req.tid <= tid;
				tid <= tid + 2'd1;
				if (&tid)
					tid <= 8'd1;
				req_state <= UPD2;
			end
		end
	UPD2:
		begin
			tranbuf[ftam_req.tid & 15].t <= 1'b1;
			tranbuf[ftam_req.tid & 15].v <= 1'b1;
			tranbuf[ftam_req.tid & 15].rdy <= 1'b0;
			if (!ftam_resp.rty) begin
				ftam_req.vadr <= stlb_adr + 8'd32;
				ftam_req.data1 <= vadr[31:0];
				ftam_req.tid <= tid;
				tid <= tid + 2'd1;
				if (&tid)
					tid <= 8'd1;
				req_state <= UPD3;
			end	
		end
	UPD3:
		begin
			tranbuf[ftam_req.tid & 15].t <= 1'b1;
			tranbuf[ftam_req.tid & 15].v <= 1'b1;
			tranbuf[ftam_req.tid & 15].rdy <= 1'b0;
			if (!ftam_resp.rty) begin
				ftam_req.vadr <= stlb_adr + 8'd40;
				ftam_req.data1 <= {64'd0,asid} << 8'd48;
				ftam_req.tid <= tid;
				tid <= tid + 2'd1;
				if (&tid)
					tid <= 8'd1;
				req_state <= UPD4;
			end	
		end
	UPD4:
		begin
			tranbuf[ftam_req.tid & 15].t <= 1'b1;
			tranbuf[ftam_req.tid & 15].v <= 1'b1;
			tranbuf[ftam_req.tid & 15].rdy <= 1'b0;
			if (!ftam_resp.rty) begin
				ftam_req.vadr <= stlb_adr + 8'd126;	// Write TLBE port
				ftam_req.sel <= 16'h0001;
				ftam_req.data1 <= 8'd1;
				ftam_req.tid <= tid;
				tid <= tid + 2'd1;
				if (&tid)
					tid <= 8'd1;
				req_state <= UPD5;
			end	
		end
	UPD5:
		if (!ftam_resp.rty) begin
			tlbmiss_ip <= 'b0;
			ftam_req.cyc <= 1'b0;
			ftam_req.stb <= 1'b0;
			ftam_req.we <= 1'b0;
			ftam_req.sel <= 'd0;
			req_state <= IDLE;
		end
	RDMISS1:
		begin
			tranbuf[ftam_req.tid & 15].t <= 2'd2;
			tranbuf[ftam_req.tid & 15].v <= 1'b1;
			tranbuf[ftam_req.tid & 15].rdy <= 1'b0;
			if (!ftam_resp.rty) begin
				ftam_req.sel <= 16'hFFFF;
				ftam_req.vadr <= stlb_adr + 8'h20;
				ftam_req.data1 <= 'd0;
				ftam_req.tid <= tid;
				tid <= tid + 2'd1;
				if (&tid)
					tid <= 8'd1;
				req_state <= RDMISS2;
			end	
		end
	RDMISS2:
		begin
			tranbuf[ftam_req.tid & 15].t <= 2'd2;
			tranbuf[ftam_req.tid & 15].v <= 1'b1;
			tranbuf[ftam_req.tid & 15].rdy <= 1'b0;
			req_state <= IDLE;
		end
	FAULT:
		if (cs_hwtw && sreq.padr[15:0]==16'hFF00) begin
			tlbmiss_ip <= 'd0;
			fault <= 'd0;
			req_state <= IDLE;		
		end
	endcase

	// Capture responses.
	if (ftam_resp.ack) begin
		tranbuf[ftam_resp.tid & 15].dat <= ftam_resp.dat;
		tranbuf[ftam_resp.tid & 15].pte <= ftam_resp.dat[63:0];
		tranbuf[ftam_resp.tid & 15].padr <= ftam_resp.adr;
		tranbuf[ftam_resp.tid & 15].rdy <= 1'b1;
	end

	// Search for ready translations and update the TLB.	
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (tranbuf[nn].rdy)
			case(tranbuf[nn].t)
			2'd0:
				begin
					// Allow capture of new TLB misses.
					miss_stack[tranbuf[nn].stk].v <= 1'b0;
					miss_stack[tranbuf[nn].stk].o <= 1'b0;
					tranbuf[nn].v <= 1'b0;
					tranbuf[nn].rdy <= 1'b0;
					asid <= tranbuf[nn].asid;
					vadr <= tranbuf[nn].vadr;
					pte <= tranbuf[nn].pte;
					if (~tranbuf[nn].pte.v) begin
						fault <= 1'b1;
						fault_asid <= tranbuf[nn].asid;
						fault_adr <= tranbuf[nn].vadr;
						req_state <= FAULT;
					end
					else
						upd_req <= 1'b1;
				end
			2'd1:
				begin
					tranbuf[nn].t <= 1'b0;
					tranbuf[nn].v <= 1'b0;
					tranbuf[nn].rdy <= 1'b0;
				end
			2'd2:
				begin
					tranbuf[nn].t <= 1'b0;
					tranbuf[nn].v <= 1'b0;
					tranbuf[nn].rdy <= 1'b0;
					tlbmiss_v <= 1'b1;
					tlbmiss_asid <= tranbuf[nn].dat[123:112];
					tlbmiss_adr <= tranbuf[nn].dat[31:0];
				end
			default:	;
			endcase
	end
end

endmodule
