// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_active_region_ex.sv
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

import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_active_region_ex(rst, clk, wbs_req, wbs_resp, region_num, region, sel, err);
input rst;
input clk;
input wb_cmd_request128_t wbs_req;
output wb_cmd_response128_t wbs_resp;
output reg [3:0] region_num;
output REGION region;
output reg [7:0] sel;
output reg err;
localparam ABITS = $bits(wb_address_t);

parameter IO_ADDR = 32'hFEEF0001;
parameter IO_ADDR_MASK = 32'h00FF0000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd12;
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
parameter CFG_IRQ_LINE = 8'hFF;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device


integer n;
REGION [7:0] pma_regions;

initial begin
	// ROM
	pma_regions[7].start = 48'hFFFD0000;
	pma_regions[7].nd 	= 48'hFFFFFFFF;
	pma_regions[7].pmt	= 48'h00000000;
	pma_regions[7].cta	= 48'h00000000;
	pma_regions[7].at 	= 20'h0000D;		// rom, byte address table, cache-read-execute
	pma_regions[7].lock = "LOCK";

	// IO
	pma_regions[6].start = 48'hFF800000;
	pma_regions[6].nd = 48'hFF9FFFFF;
	pma_regions[6].pmt	 = 48'h00000300;
	pma_regions[6].cta	= 48'h00000000;
	pma_regions[6].at = 20'h00206;		// io, (screen) byte address table, read-write
	pma_regions[6].lock = "LOCK";

	// Config space
	pma_regions[5].start = 48'hD0000000;
	pma_regions[5].nd = 48'hDFFFFFFF;
	pma_regions[5].pmt	 = 48'h00000000;
	pma_regions[5].cta	= 48'h00000000;
	pma_regions[5].at = 20'h00206;		// config space, byte address, read-write 
	pma_regions[5].lock = "LOCK";

	// Scratchpad RAM
	pma_regions[4].start = 48'hFFFC0000;
	pma_regions[4].nd = 48'hFFFCFFFF;
	pma_regions[4].pmt	 = 48'h00002300;
	pma_regions[4].cta	= 48'h00000000;
	pma_regions[4].at = 20'h0020F;		// byte address table, read-write-execute cacheable
	pma_regions[4].lock = "LOCK";

	// vacant
	pma_regions[3].start = 48'hFFFFFFFF;
	pma_regions[3].nd = 48'hFFFFFFFF;
	pma_regions[3].pmt	 = 48'h00000000;
	pma_regions[3].cta	= 48'h00000000;
	pma_regions[3].at = 20'h0FF00;		// no access
	pma_regions[3].lock = "LOCK";

	// vacant
	pma_regions[2].start = 48'hFFFFFFFF;
	pma_regions[2].nd = 48'hFFFFFFFF;
	pma_regions[2].pmt	 = 48'h00000000;
	pma_regions[2].cta	= 48'h00000000;
	pma_regions[2].at = 20'h0FF00;		// no access
	pma_regions[2].lock = "LOCK";

	// DRAM
	pma_regions[1].start = 48'h00000000;
	pma_regions[1].nd = 48'h1FFFFFFF;
	pma_regions[1].pmt	 = 48'h00002400;
	pma_regions[1].cta	= 48'h00000000;
	pma_regions[1].at = 20'h0010F;	// ram, byte address table, cache-read-write-execute
	pma_regions[1].lock = "LOCK";

	// vacant
	pma_regions[0].start = 48'hFFFFFFFF;
	pma_regions[0].nd = 48'hFFFFFFFF;
	pma_regions[0].pmt	 = 48'h00000000;
	pma_regions[0].cta	= 48'h00000000;
	pma_regions[0].at = 20'h0FF00;		// no access
	pma_regions[0].lock = "LOCK";

end

reg cs_config;
wire [63:0] dati = wbs_req.padr[3] ? wbs_req.dat[127:64] : wbs_req.dat[63:0];
reg [63:0] dato;
wire [63:0] cfg_out;

always_ff @(posedge clk_i)
	cs_config <= wbs_req.cyc && wbs_req.stb &&
		wbs_req.padr[31:28]==4'hD &&
		wbs_req.padr[27:20]==CFG_BUS &&
		wbs_req.padr[19:15]==CFG_DEVICE &&
		wbs_req.padr[14:12]==CFG_FUNC;

ack_gen #(
	.READ_STAGES(1),
	.WRITE_STAGES(0),
	.REGISTER_OUTPUT(1)
) uag1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.ce_i(1'b1),
	.rid_i('d0),
	.wid_i('d0),
	.i((cs_config|cs_rgn) & ~wbs_req.we & wbs_req.stb & wbs_req.cyc),
	.we_i((cs_config|cs_rgn) & wbs_req.we & wbs_req.stb & wbs_req.cyc),
	.o(ack_o),
	.rid_o(),
	.wid_o()
);

pci64_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
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
	.irq_i(1'b0),
	.irq_o(),
	.cs_config_i(cs_config),
	.we_i(wbs_req.we),
	.sel_i(wbs_req.sel[15:8]|wbs_req.sel[7:0]),
	.adr_i(wbs_req.padr),
	.dat_i(dati),
	.dat_o(cfg_out),
	.cs_bar0_o(cs_rgn),
	.cs_bar1_o(),
	.cs_bar2_o(),
	.irq_en_o()
);

always_ff @(posedge clk)
	if (cs_rgn && wbs_req.we && wbs_req.cyc) begin
		if (pma_regions[wbs_req.padr[8:6]].lock=="UNLK" || wbs_req.padr[8:6]==3'h7) begin
			case(wbs_req.padr[8:6])
			3'd0:	pma_regions[wbs_req.padr[5:3]].start[ABITS-1: 0] <= dati[ABITS-1:0];
			3'd1:	pma_regions[wbs_req.padr[5:3]].nd[ABITS-1: 0] <= dati[ABITS-1:0];
			3'd2:	pma_regions[wbs_req.padr[5:3]].pmt[ABITS-1: 0] <= dati[ABITS-1:0];
			3'd3:	pma_regions[wbs_req.padr[5:3]].cta[ABITS-1: 0] <= dati[ABITS-1:0];
			3'd4:	pma_regions[wbs_req.padr[5:3]].at <= dati[19:0];
			3'd7: pma_regions[wbs_req.padr[5:3]].lock <= dati;
			default:	;
			endcase
		end
	end
always_ff @(posedge clk)
if (cs_config)
	dato <= cfg_out;
else if (cs_rgn && wbs_req.cyc)
	case(wbs_req.padr[8:6])
	3'd0:	dato <= pma_regions[wbs_req.padr[5:3]].start;
	3'd1:	dato <= pma_regions[wbs_req.padr[5:3]].nd;
	3'd2:	dato <= pma_regions[wbs_req.padr[5:3]].pmt;
	3'd3:	dato <= pma_regions[wbs_req.padr[5:3]].cta;
	3'd4:	dato <= pma_regions[wbs_req.padr[5:3]].at;
	3'd7:	dato <= pma_regions[wbs_req.padr[5:3]].lock;
	default:	dato <= 'd0;
	endcase
else
	dato <= 'd0;

assign wbs_resp.dat = {2{dato}};

always_comb
begin
	err = 1'b1;
	region_num = 4'd0;
	region = pma_regions[0];
	sel <= 'd0;
  for (n = 0; n < 8; n = n + 1)
    if (wbs_req.padr[ABITS-1:4] >= pma_regions[n].start[ABITS-1:4] && wbs_req.padr[ABITS-1:4] <= pma_regions[n].nd[ABITS-1:4]) begin
    	region = pma_regions[n];
    	region_num = n;
    	sel[n] <= 1'b1;
    	err = 1'b0;
  	end
end    	
    	
endmodule

