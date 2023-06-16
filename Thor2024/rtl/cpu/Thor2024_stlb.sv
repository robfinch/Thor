`timescale 1ns/1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_stlb.sv
//	- shared TLB
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
// 1649 LUTs / 1907 FFs / 12 BRAMs
// ============================================================================

import const_pkg::*;
import fta_bus_pkg::*;
import Thor2024pkg::*;
import Thor2024Mmupkg::*;

module Thor2024_stlb(rst_i, clk_i, clk2x_i, rdy_o, rwx_o, tlbmiss_irq_o,
	wbn_req_i, wbn_resp_o, fta_req_o, fta_resp_i, snoop_v, snoop_adr, snoop_cid,
	input_fifo_empty, input_fifo_full, input_fifo_overflow, input_fifo_underflow,
	input_fifo_rd_data_count, input_fifo_wr_data_count
	);
parameter ASSOC = 6;	// MAX assoc = 15
parameter LVL1_ASSOC = 1;
parameter CHANNELS = 4;
parameter FIFO_DEPTH = 16;
parameter RSTIP = 32'hFFFD0000;
parameter PAGE_SIZE = 65536;
localparam LOG_PAGE_SIZE = $clog2(PAGE_SIZE);
localparam LOG_ENTRIES = $clog2(ENTRIES);
parameter HTABLE = 1'b0;		// 1=support hash table
parameter SMALL = 1'b1;

parameter IO_ADDR = 32'hFEF00001;
parameter IO_ADDR2 = 32'hFEEF0001;
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

input rst_i;
input clk_i;
input clk2x_i;
output rdy_o;
output reg [2:0] rwx_o;
output [31:0] tlbmiss_irq_o;
input fta_cmd_request128_t [CHANNELS-1:0] wbn_req_i;
output fta_cmd_response128_t [CHANNELS-1:0] wbn_resp_o;
output fta_cmd_request128_t fta_req_o;
input fta_cmd_response128_t fta_resp_i;
output reg snoop_v;
output fta_address_t snoop_adr;
output reg [3:0] snoop_cid;
output [CHANNELS-1:0] input_fifo_empty;
output [CHANNELS-1:0] input_fifo_full;
output [CHANNELS-1:0] input_fifo_overflow;
output [CHANNELS-1:0] input_fifo_underflow;
output [$clog2(FIFO_DEPTH)-1:0] input_fifo_rd_data_count [0:CHANNELS-1];
output [$clog2(FIFO_DEPTH)-1:0] input_fifo_wr_data_count [0:CHANNELS-1];

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

tlb_state_t state = ST_RST;

integer n;
integer n1,j1;
integer n2;
integer n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13;
genvar g;

wire tlbmiss_irq;
wire irq_en;
wire [2:0] rgn;
wire [3:0] cache;
reg [3:0] cache_o;
REGION region;
wire [127:0] rgn_dato;
wire [2:0] rwx;
reg tlben_i;
reg wrtlb_i;
reg [31:0] tlbadr_i;

reg [2:0] rd_tlb;
reg wr_tlb;
STLBE tlbdat_i;
reg [31:0] ctrl_reg;

Thor2024pkg::address_t last_ladr, last_iadr;
Thor2024pkg::address_t adrd;
Thor2024pkg::address_t tlbmiss_adr;
reg invall;
reg [LOG_ENTRIES-1:0] inv_count;

tlb_count_t master_count;
fta_cmd_request128_t req,req1,wbs_req,fta_req;
fta_cmd_response128_t wbm_resp;
fta_asid_t asid_i;
fta_asid_t asidd;
fta_asid_t tlbmiss_asid;
fta_operating_mode_t om_i, omd, omd2;

reg [1:0] al;
reg LRU, RAND;
code_address_t rstip = RSTIP;
reg [3:0] randway;
STLBE tentryi [0:ASSOC-1];
STLBE tentryo [0:ASSOC-1];
STLBE tentryo2 [0:ASSOC-1];
reg xlaten_i;
reg xlatend;
reg we_i;
Thor2024pkg::address_t adr_i;
reg [LOG_ENTRIES-1:0] adr_i_slice [0:ASSOC-1];
Thor2024pkg::address_t iadrd;
reg next_i;
STLBE [ASSOC-1:0] tlbdato;
wire clk_g = clk_i;

reg [4:0] wway;
STLBE tlbdat_rst;
STLBE tlbdati;
reg [9:0] count;
reg [ASSOC-1:0] tlbwrr;
reg tlbeni;
wire [LOG_ENTRIES-1:0] tlbadri;
reg clock_r;
reg [LOG_ENTRIES-1:0] rcount;

SHPTE pte_reg;
SVPN vpn_reg;
reg [31:0] ctrl_req;
reg [7:0] selected_channel;
reg [CHANNELS-1:0] ch_active;
reg htable_lookup,htable_update;
wire htable_ack,htable_exc;
reg [31:0] htable_adr;
reg [11:0] htable_asid;
SHPTE htable_pte;
SHPTE htable_pte_o;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

assign wbs_req = fta_req_o;

wire acko;
reg cs_config, cs_stlbq, cs_rgnq;
wire cs_stlb, cs_rgn;
wire [127:0] cfg_out;
reg [127:0] dato;

always_ff @(posedge clk_g)
	cs_config <= wbs_req.cyc && wbs_req.stb &&
		wbs_req.padr[31:28]==4'hD &&
		wbs_req.padr[27:20]==CFG_BUS &&
		wbs_req.padr[19:15]==CFG_DEVICE &&
		wbs_req.padr[14:12]==CFG_FUNC;

always_comb
	cs_stlbq <= cs_stlb && wbs_req.cyc && wbs_req.stb;
always_comb
	cs_rgnq <= cs_rgn && wbs_req.cyc && wbs_req.stb;


ack_gen #(
	.READ_STAGES(1),
	.WRITE_STAGES(0),
	.REGISTER_OUTPUT(1)
) uag1
(
	.rst_i(rst_i),
	.clk_i(clk_g),
	.ce_i(1'b1),
	.rid_i('d0),
	.wid_i('d0),
	.i((cs_config|cs_stlbq|cs_rgnq) & ~wbs_req.we),
	.we_i((cs_config|cs_stlbq|cs_rgnq) & wbs_req.we),
	.o(acko),
	.rid_o(),
	.wid_o()
);

pci128_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
	.CFG_BAR1(IO_ADDR2),
	.CFG_BAR1_MASK(IO_ADDR_MASK),
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
	.rst_i(rst_i),
	.clk_i(clk_g),
	.irq_i(tlbmiss_irq & irq_en),
	.irq_o(tlbmiss_irq_o),
	.cs_config_i(cs_config),
	.we_i(wbs_req.we),
	.sel_i(wbs_req.sel),
	.adr_i(wbs_req.padr),
	.dat_i(wbs_req.data1),
	.dat_o(cfg_out),
	.cs_bar0_o(cs_stlb),
	.cs_bar1_o(cs_rgn),
	.cs_bar2_o(),
	.irq_en_o(irq_en)
);

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i) begin
	pte_reg <= 'd0;
	vpn_reg <= 'd0;
	ctrl_reg <= 'd0;
	rd_tlb <= 'b0;
	wr_tlb <= 1'b0;
	wrtlb_i <= 1'b0;
	tlben_i <= 1'b0;
	tlbadr_i <= 'd0;
	tlbdat_i <= 'd0;
	LRU <= 1'b1;
	RAND <= 1'b0;
end
else begin
	tlben_i <= |rd_tlb;
	rd_tlb <= {rd_tlb[1:0],1'b0};
	wr_tlb <= 1'b0;
	htable_update <= 1'b0;
	if (state==ST_UPD3)
		wrtlb_i <= 1'b0;
	if (cs_stlbq & wbs_req.we) begin
		case(wbs_req.padr[6:4])
		3'd0:	
			case(wbs_req.padr[3])
			1'b0:	pte_reg[63:0] <= wbs_req.data1[63:0];
			1'b1: pte_reg[71:64] <= wbs_req.data1[7:0];
			endcase
		3'd1:	vpn_reg <= wbs_req.data1;
		3'd7:	
			begin
			case(wbs_req.sel)
			16'h000F:	
				begin
					ctrl_reg <= wbs_req.data1[31:0];
					LRU <= wbs_req.data1[17:16]==2'b01;
					RAND <= wbs_req.data1[17:16]==2'b10;
					htable_update <= wbs_req.data1[24];
				end
			default:	;
			endcase
			if (wbs_req.sel[13])
				rd_tlb <= 3'b001;
			if (wbs_req.sel[14])
				wr_tlb <= 1'b1;
			end
		default:	;
		endcase
	end
	if (wr_tlb) begin
		tlben_i <= 1'b1;
		wrtlb_i <= 1'b1;
		tlbdat_i.count <= master_count;
		tlbdat_i.lru <= 'd0;
		tlbdat_i.pte <= pte_reg;
		tlbdat_i.vpn <= vpn_reg;
		tlbadr_i <= ctrl_reg;
	end
	if (rd_tlb[0])
		tlbadr_i <= ctrl_reg;
	if (rd_tlb[2]) begin
		pte_reg <= tlbdato[tlbadr_i[3:0]].pte;
		vpn_reg <= tlbdato[tlbadr_i[3:0]].vpn;
	end
end

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	dato <= 'd0;
else begin
	if (cs_config)
		dato <= cfg_out;
	else if (cs_stlbq)
		case(wbs_req.padr[6:4])
		3'd0:	dato <= pte_reg;
		3'd1:	dato <= vpn_reg;
		3'd2:	
			begin
				dato <= tlbmiss_adr;
				dato[123:112] <= tlbmiss_asid;
			end
		3'd7:	dato <= ctrl_reg;
		default:	dato <= 'd0;
		endcase
	else if (cs_rgnq)
		dato <= rgn_dato;
	else
		dato <= 'd0;
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Thor2024_stlb_active_region urgn
(
	.rst(rst_i),
	.clk(clk_i),
	.cs_rgn(cs_rgnq),
	.rgn(rgn),
	.wbs_req(fta_req_o),
	.dato(rgn_dato),
	.region_num(),
	.region(region),
	.sel(),
	.err()
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Arbitrate incoming requests.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire [CHANNELS-1:0] data_valid;
wire [CHANNELS-1:0] rd_rst_busy;
wire [CHANNELS-1:0] wr_rst_busy;
wire [CHANNELS-1:0] wr_ack;						// not used
wire [CHANNELS-1:0] data_valid;				// not used
wire [CHANNELS-1:0] input_fifo_full1;				// not used
reg [CHANNELS-1:0] input_fifo_rd, input_fifo_rd_d1;
fta_cmd_request128_t [CHANNELS-1:0] input_fifo_dout;
assign input_fifo_full = input_fifo_full1 | wr_rst_busy | state==ST_RST;

generate begin : gInputFifos
	for (g = 0; g < CHANNELS; g = g + 1) begin
// XPM_FIFO instantiation template for Synchronous FIFO configurations
// Refer to the targeted device family architecture libraries guide for XPM_FIFO documentation
// =======================================================================================================================

// Parameter usage table, organized as follows:
// +---------------------------------------------------------------------------------------------------------------------+
// | Parameter name       | Data type          | Restrictions, if applicable                                             |
// |---------------------------------------------------------------------------------------------------------------------|
// | Description                                                                                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// +---------------------------------------------------------------------------------------------------------------------+
// | CASCADE_HEIGHT       | Integer            | Range: 0 - 64. Default value = 0.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | 0- No Cascade Height, Allow Vivado Synthesis to choose.                                                             |
// | 1 or more - Vivado Synthesis sets the specified value as Cascade Height.                                            |
// +---------------------------------------------------------------------------------------------------------------------+
// | DOUT_RESET_VALUE     | String             | Default value = 0.                                                      |
// |---------------------------------------------------------------------------------------------------------------------|
// | Reset value of read data path.                                                                                      |
// +---------------------------------------------------------------------------------------------------------------------+
// | ECC_MODE             | String             | Allowed values: no_ecc, en_ecc. Default value = no_ecc.                 |
// |---------------------------------------------------------------------------------------------------------------------|
// |                                                                                                                     |
// |   "no_ecc" - Disables ECC                                                                                           |
// |   "en_ecc" - Enables both ECC Encoder and Decoder                                                                   |
// |                                                                                                                     |
// | NOTE: ECC_MODE should be "no_ecc" if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior.|
// +---------------------------------------------------------------------------------------------------------------------+
// | FIFO_MEMORY_TYPE     | String             | Allowed values: auto, block, distributed, ultra. Default value = auto.  |
// |---------------------------------------------------------------------------------------------------------------------|
// | Designate the fifo memory primitive (resource type) to use-                                                         |
// |                                                                                                                     |
// |   "auto"- Allow Vivado Synthesis to choose                                                                          |
// |   "block"- Block RAM FIFO                                                                                           |
// |   "distributed"- Distributed RAM FIFO                                                                               |
// |   "ultra"- URAM FIFO                                                                                                |
// |                                                                                                                     |
// | NOTE: There may be a behavior mismatch if Block RAM or Ultra RAM specific features, like ECC or Asymmetry, are selected with FIFO_MEMORY_TYPE set to "auto".|
// +---------------------------------------------------------------------------------------------------------------------+
// | FIFO_READ_LATENCY    | Integer            | Range: 0 - 100. Default value = 1.                                      |
// |---------------------------------------------------------------------------------------------------------------------|
// | Number of output register stages in the read data path                                                              |
// |                                                                                                                     |
// |   If READ_MODE = "fwft", then the only applicable value is 0                                                        |
// +---------------------------------------------------------------------------------------------------------------------+
// | FIFO_WRITE_DEPTH     | Integer            | Range: 16 - 4194304. Default value = 2048.                              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Defines the FIFO Write Depth, must be power of two                                                                  |
// |                                                                                                                     |
// |   In standard READ_MODE, the effective depth = FIFO_WRITE_DEPTH                                                     |
// |   In First-Word-Fall-Through READ_MODE, the effective depth = FIFO_WRITE_DEPTH+2                                    |
// |                                                                                                                     |
// | NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.                                             |
// +---------------------------------------------------------------------------------------------------------------------+
// | FULL_RESET_VALUE     | Integer            | Range: 0 - 1. Default value = 0.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | Sets full, almost_full and prog_full to FULL_RESET_VALUE during reset                                               |
// +---------------------------------------------------------------------------------------------------------------------+
// | PROG_EMPTY_THRESH    | Integer            | Range: 3 - 4194304. Default value = 10.                                 |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies the minimum number of read words in the FIFO at or below which prog_empty is asserted.                    |
// |                                                                                                                     |
// |   Min_Value = 3 + (READ_MODE_VAL*2)                                                                                 |
// |   Max_Value = (FIFO_WRITE_DEPTH-3) - (READ_MODE_VAL*2)                                                              |
// |                                                                                                                     |
// | If READ_MODE = "std", then READ_MODE_VAL = 0; Otherwise READ_MODE_VAL = 1.                                          |
// | NOTE: The default threshold value is dependent on default FIFO_WRITE_DEPTH value. If FIFO_WRITE_DEPTH value is      |
// | changed, ensure the threshold value is within the valid range though the programmable flags are not used.           |
// +---------------------------------------------------------------------------------------------------------------------+
// | PROG_FULL_THRESH     | Integer            | Range: 3 - 4194301. Default value = 10.                                 |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies the maximum number of write words in the FIFO at or above which prog_full is asserted.                    |
// |                                                                                                                     |
// |   Min_Value = 3 + (READ_MODE_VAL*2*(FIFO_WRITE_DEPTH/FIFO_READ_DEPTH))                                              |
// |   Max_Value = (FIFO_WRITE_DEPTH-3) - (READ_MODE_VAL*2*(FIFO_WRITE_DEPTH/FIFO_READ_DEPTH))                           |
// |                                                                                                                     |
// | If READ_MODE = "std", then READ_MODE_VAL = 0; Otherwise READ_MODE_VAL = 1.                                          |
// | NOTE: The default threshold value is dependent on default FIFO_WRITE_DEPTH value. If FIFO_WRITE_DEPTH value is      |
// | changed, ensure the threshold value is within the valid range though the programmable flags are not used.           |
// +---------------------------------------------------------------------------------------------------------------------+
// | RD_DATA_COUNT_WIDTH  | Integer            | Range: 1 - 23. Default value = 1.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies the width of rd_data_count. To reflect the correct value, the width should be log2(FIFO_READ_DEPTH)+1.    |
// |                                                                                                                     |
// |   FIFO_READ_DEPTH = FIFO_WRITE_DEPTH*WRITE_DATA_WIDTH/READ_DATA_WIDTH                                               |
// +---------------------------------------------------------------------------------------------------------------------+
// | READ_DATA_WIDTH      | Integer            | Range: 1 - 4096. Default value = 32.                                    |
// |---------------------------------------------------------------------------------------------------------------------|
// | Defines the width of the read data port, dout                                                                       |
// |                                                                                                                     |
// |   Write and read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1 and 2:1                                    |
// |   For example, if WRITE_DATA_WIDTH is 32, then the READ_DATA_WIDTH must be 32, 64,128, 256, 16, 8, 4.               |
// |                                                                                                                     |
// | NOTE:                                                                                                               |
// |                                                                                                                     |
// |   READ_DATA_WIDTH should be equal to WRITE_DATA_WIDTH if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior. |
// |   The maximum FIFO size (width x depth) is limited to 150-Megabits.                                                 |
// +---------------------------------------------------------------------------------------------------------------------+
// | READ_MODE            | String             | Allowed values: std, fwft. Default value = std.                         |
// |---------------------------------------------------------------------------------------------------------------------|
// |                                                                                                                     |
// |   "std"- standard read mode                                                                                         |
// |   "fwft"- First-Word-Fall-Through read mode                                                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// | SIM_ASSERT_CHK       | Integer            | Range: 0 - 1. Default value = 0.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// | 0- Disable simulation message reporting. Messages related to potential misuse will not be reported.                 |
// | 1- Enable simulation message reporting. Messages related to potential misuse will be reported.                      |
// +---------------------------------------------------------------------------------------------------------------------+
// | USE_ADV_FEATURES     | String             | Default value = 0707.                                                   |
// |---------------------------------------------------------------------------------------------------------------------|
// | Enables data_valid, almost_empty, rd_data_count, prog_empty, underflow, wr_ack, almost_full, wr_data_count,         |
// | prog_full, overflow features.                                                                                       |
// |                                                                                                                     |
// |   Setting USE_ADV_FEATURES[0] to 1 enables overflow flag; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
// |   Setting USE_ADV_FEATURES[4] to 1 enables wr_ack flag; Default value of this bit is 0                              |
// |   Setting USE_ADV_FEATURES[8] to 1 enables underflow flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 1                          |
// |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0                       |
// |   Setting USE_ADV_FEATURES[12] to 1 enables data_valid flag; Default value of this bit is 0                         |
// +---------------------------------------------------------------------------------------------------------------------+
// | WAKEUP_TIME          | Integer            | Range: 0 - 2. Default value = 0.                                        |
// |---------------------------------------------------------------------------------------------------------------------|
// |                                                                                                                     |
// |   0 - Disable sleep                                                                                                 |
// |   2 - Use Sleep Pin                                                                                                 |
// |                                                                                                                     |
// | NOTE: WAKEUP_TIME should be 0 if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior.   |
// +---------------------------------------------------------------------------------------------------------------------+
// | WRITE_DATA_WIDTH     | Integer            | Range: 1 - 4096. Default value = 32.                                    |
// |---------------------------------------------------------------------------------------------------------------------|
// | Defines the width of the write data port, din                                                                       |
// |                                                                                                                     |
// |   Write and read width aspect ratio must be 1:1, 1:2, 1:4, 1:8, 8:1, 4:1 and 2:1                                    |
// |   For example, if WRITE_DATA_WIDTH is 32, then the READ_DATA_WIDTH must be 32, 64,128, 256, 16, 8, 4.               |
// |                                                                                                                     |
// | NOTE:                                                                                                               |
// |                                                                                                                     |
// |   WRITE_DATA_WIDTH should be equal to READ_DATA_WIDTH if FIFO_MEMORY_TYPE is set to "auto". Violating this may result incorrect behavior.|
// |   The maximum FIFO size (width x depth) is limited to 150-Megabits.                                                 |
// +---------------------------------------------------------------------------------------------------------------------+
// | WR_DATA_COUNT_WIDTH  | Integer            | Range: 1 - 23. Default value = 1.                                       |
// |---------------------------------------------------------------------------------------------------------------------|
// | Specifies the width of wr_data_count. To reflect the correct value, the width should be log2(FIFO_WRITE_DEPTH)+1.   |
// +---------------------------------------------------------------------------------------------------------------------+

// Port usage table, organized as follows:
// +---------------------------------------------------------------------------------------------------------------------+
// | Port name      | Direction | Size, in bits                         | Domain  | Sense       | Handling if unused     |
// |---------------------------------------------------------------------------------------------------------------------|
// | Description                                                                                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// +---------------------------------------------------------------------------------------------------------------------+
// | almost_empty   | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Almost Empty : When asserted, this signal indicates that only one more read can be performed before the FIFO goes to|
// | empty.                                                                                                              |
// +---------------------------------------------------------------------------------------------------------------------+
// | almost_full    | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Almost Full: When asserted, this signal indicates that only one more write can be performed before the FIFO is full.|
// +---------------------------------------------------------------------------------------------------------------------+
// | data_valid     | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).        |
// +---------------------------------------------------------------------------------------------------------------------+
// | dbiterr        | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.|
// +---------------------------------------------------------------------------------------------------------------------+
// | din            | Input     | WRITE_DATA_WIDTH                      | wr_clk  | NA          | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Data: The input data bus used when writing the FIFO.                                                          |
// +---------------------------------------------------------------------------------------------------------------------+
// | dout           | Output    | READ_DATA_WIDTH                       | wr_clk  | NA          | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Data: The output data bus is driven when reading the FIFO.                                                     |
// +---------------------------------------------------------------------------------------------------------------------+
// | empty          | Output    | 1                                     | wr_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Empty Flag: When asserted, this signal indicates that the FIFO is empty.                                            |
// | Read requests are ignored when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.     |
// +---------------------------------------------------------------------------------------------------------------------+
// | full           | Output    | 1                                     | wr_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Full Flag: When asserted, this signal indicates that the FIFO is full.                                              |
// | Write requests are ignored when the FIFO is full, initiating a write when the FIFO is full is not destructive       |
// | to the contents of the FIFO.                                                                                        |
// +---------------------------------------------------------------------------------------------------------------------+
// | injectdbiterr  | Input     | 1                                     | wr_clk  | Active-high | Tie to 1'b0            |
// |---------------------------------------------------------------------------------------------------------------------|
// | Double Bit Error Injection: Injects a double bit error if the ECC feature is used on block RAMs or                  |
// | UltraRAM macros.                                                                                                    |
// +---------------------------------------------------------------------------------------------------------------------+
// | injectsbiterr  | Input     | 1                                     | wr_clk  | Active-high | Tie to 1'b0            |
// |---------------------------------------------------------------------------------------------------------------------|
// | Single Bit Error Injection: Injects a single bit error if the ECC feature is used on block RAMs or                  |
// | UltraRAM macros.                                                                                                    |
// +---------------------------------------------------------------------------------------------------------------------+
// | overflow       | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected,              |
// | because the FIFO is full. Overflowing the FIFO is not destructive to the contents of the FIFO.                      |
// +---------------------------------------------------------------------------------------------------------------------+
// | prog_empty     | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal              |
// | to the programmable empty threshold value.                                                                          |
// | It is de-asserted when the number of words in the FIFO exceeds the programmable empty threshold value.              |
// +---------------------------------------------------------------------------------------------------------------------+
// | prog_full      | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal            |
// | to the programmable full threshold value.                                                                           |
// | It is de-asserted when the number of words in the FIFO is less than the programmable full threshold value.          |
// +---------------------------------------------------------------------------------------------------------------------+
// | rd_data_count  | Output    | RD_DATA_COUNT_WIDTH                   | wr_clk  | NA          | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Data Count: This bus indicates the number of words read from the FIFO.                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// | rd_en          | Input     | 1                                     | wr_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO.        |
// |                                                                                                                     |
// |   Must be held active-low when rd_rst_busy is active high.                                                          |
// +---------------------------------------------------------------------------------------------------------------------+
// | rd_rst_busy    | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.                     |
// +---------------------------------------------------------------------------------------------------------------------+
// | rst            | Input     | 1                                     | wr_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Reset: Must be synchronous to wr_clk. The clock(s) can be unstable at the time of applying reset, but reset must be released only after the clock(s) is/are stable.|
// +---------------------------------------------------------------------------------------------------------------------+
// | sbiterr        | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.                             |
// +---------------------------------------------------------------------------------------------------------------------+
// | sleep          | Input     | 1                                     | NA      | Active-high | Tie to 1'b0            |
// |---------------------------------------------------------------------------------------------------------------------|
// | Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.                              |
// +---------------------------------------------------------------------------------------------------------------------+
// | underflow      | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected                     |
// | because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.                                   |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_ack         | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle is succeeded.    |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_clk         | Input     | 1                                     | NA      | Rising edge | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write clock: Used for write operation. wr_clk must be a free running clock.                                         |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_data_count  | Output    | WR_DATA_COUNT_WIDTH                   | wr_clk  | NA          | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Data Count: This bus indicates the number of words written into the FIFO.                                     |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_en          | Input     | 1                                     | wr_clk  | Active-high | Required               |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Enable: If the FIFO is not full, asserting this signal causes data (on din) to be written to the FIFO         |
// |                                                                                                                     |
// |   Must be held active-low when rst or wr_rst_busy or rd_rst_busy is active high                                     |
// +---------------------------------------------------------------------------------------------------------------------+
// | wr_rst_busy    | Output    | 1                                     | wr_clk  | Active-high | DoNotCare              |
// |---------------------------------------------------------------------------------------------------------------------|
// | Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset state.                   |
// +---------------------------------------------------------------------------------------------------------------------+


// xpm_fifo_sync : In order to incorporate this function into the design,
//    Verilog    : the following instance declaration needs to be placed
//   instance    : in the body of the design code.  The instance name
//  declaration  : (xpm_fifo_sync_inst) and/or the port declarations within the
//     code      : parenthesis may be changed to properly reference and
//               : connect this function to the design.  All inputs
//               : and outputs must be connected.

//  Please reference the appropriate libraries guide for additional information on the XPM modules.

//  <-----Cut code below this line---->

   // xpm_fifo_sync: Synchronous FIFO
   // Xilinx Parameterized Macro, version 2022.2

   xpm_fifo_sync #(
      .CASCADE_HEIGHT(0),        // DECIMAL
      .DOUT_RESET_VALUE("0"),    // String
      .ECC_MODE("no_ecc"),       // String
      .FIFO_MEMORY_TYPE("auto"), // String
      .FIFO_READ_LATENCY(1),     // DECIMAL
      .FIFO_WRITE_DEPTH(FIFO_DEPTH),   // DECIMAL
      .FULL_RESET_VALUE(0),      // DECIMAL
      .PROG_EMPTY_THRESH(10),    // DECIMAL
      .PROG_FULL_THRESH(10),     // DECIMAL
      .RD_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH)),   // DECIMAL
      .READ_DATA_WIDTH($bits(fta_cmd_request128_t)),      // DECIMAL
      .READ_MODE("std"),         // String
      .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("0707"), // String
      .WAKEUP_TIME(0),           // DECIMAL
      .WRITE_DATA_WIDTH($bits(fta_cmd_request128_t)),     // DECIMAL
      .WR_DATA_COUNT_WIDTH($clog2(FIFO_DEPTH))    // DECIMAL
   )
   xpm_fifo_sync_inst (
      .almost_empty(),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                     // only one more read can be performed before the FIFO goes to empty.

      .almost_full(),     // 1-bit output: Almost Full: When asserted, this signal indicates that
                                     // only one more write can be performed before the FIFO is full.

      .data_valid(data_valid[g]),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                     // that valid data is available on the output bus (dout).

      .dbiterr(),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                     // a double-bit error and data in the FIFO core is corrupted.

      .dout(input_fifo_dout[g]),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                     // when reading the FIFO.

      .empty(input_fifo_empty[g]),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                     // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                     // initiating a read while empty is not destructive to the FIFO.

      .full(input_fifo_full1[g]),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                     // FIFO is full. Write requests are ignored when the FIFO is full,
                                     // initiating a write when the FIFO is full is not destructive to the
                                     // contents of the FIFO.

      .overflow(input_fifo_overflow[g]),           // 1-bit output: Overflow: This signal indicates that a write request
                                     // (wren) during the prior clock cycle was rejected, because the FIFO is
                                     // full. Overflowing the FIFO is not destructive to the contents of the
                                     // FIFO.

      .prog_empty(),       // 1-bit output: Programmable Empty: This signal is asserted when the
                                     // number of words in the FIFO is less than or equal to the programmable
                                     // empty threshold value. It is de-asserted when the number of words in
                                     // the FIFO exceeds the programmable empty threshold value.

      .prog_full(),         // 1-bit output: Programmable Full: This signal is asserted when the
                                     // number of words in the FIFO is greater than or equal to the
                                     // programmable full threshold value. It is de-asserted when the number of
                                     // words in the FIFO is less than the programmable full threshold value.

      .rd_data_count(input_fifo_rd_data_count[g]), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                     // number of words read from the FIFO.

      .rd_rst_busy(rd_rst_busy[g]),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                     // domain is currently in a reset state.

      .sbiterr(),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                     // and fixed a single-bit error.

      .underflow(input_fifo_underflow[g]),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                     // the previous clock cycle was rejected because the FIFO is empty. Under
                                     // flowing the FIFO is not destructive to the FIFO.

      .wr_ack(wr_ack[g]),               // 1-bit output: Write Acknowledge: This signal indicates that a write
                                     // request (wr_en) during the prior clock cycle is succeeded.

      .wr_data_count(input_fifo_wr_data_count[g]), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                     // the number of words written into the FIFO.

      .wr_rst_busy(wr_rst_busy[g]),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     // write domain is currently in a reset state.

      .din(wbn_req_i[g]),            // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     // writing the FIFO.

      .injectdbiterr(1'b0), // 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr(1'b0), // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .rd_en(input_fifo_rd[g] & ~rd_rst_busy[g]),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                     // signal causes data (on dout) to be read from the FIFO. Must be held
                                     // active-low when rd_rst_busy is active high.

      .rst(rst_i),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                     // unstable at the time of applying reset, but reset must be released only
                                     // after the clock(s) is/are stable.

      .sleep(1'b0),                 // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                                     // block is in power saving mode.

      .wr_clk(clk_g),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     // free running clock.

      .wr_en(wbn_req_i[g].cyc & ~wr_rst_busy[g])       // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                     // signal causes data (on din) to be written to the FIFO Must be held
                                     // active-low when rst or wr_rst_busy or rd_rst_busy is active high

   );

   // End of xpm_fifo_sync_inst instantiation
end
end
endgenerate				
			

reg rr_ce;
reg [CHANNELS-1:0] rr_active;
reg [CHANNELS-1:0] rr_req;
wire [CHANNELS-1:0] rr_sel;
wire ne_ack;
wire [CHANNELS-1:0] ne_cyc;
fta_cmd_request128_t [CHANNELS-1:0] wbn_req_d;

edge_det uedack
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.i(fta_resp_i.ack|fta_resp_i.err|fta_resp_i.rty),
	.pe(),
	.ne(ne_ack),
	.ee()
);

generate begin : gNeCyc
	for (g = 0; g < CHANNELS; g = g + 1)
		edge_det uedcyc (
			.rst(rst_i),
			.clk(clk_i),
			.ce(1'b1),
			.i(wbn_req_i[g].cyc),
			.pe(),
			.ne(ne_cyc[g]),
			.ee()
		);
end
endgenerate

reg [5:0] arbit_ctr;
always_ff @(posedge clk_i)
if (rst_i)
	arbit_ctr <= 'd0;
else
	arbit_ctr <= arbit_ctr + 2'd1;

// Piplein delay to line up with seleect.
always_ff @(posedge clk_i)
	for (n12 = 0; n12 < CHANNELS; n12 = n12 + 1)
		wbn_req_d[n12] <= wbn_req_i[n12];

fta_tranid_t [CHANNELS-1:0] last_tid;
always_ff @(posedge clk_i)
if (rst_i)
	input_fifo_rd_d1 <= 'd0;
else
	input_fifo_rd_d1 <= input_fifo_rd;
always_ff @(posedge clk_i)
if (rst_i) begin
	for (n8 = 0; n8 < CHANNELS; n8 = n8 + 1)
	last_tid[n8] <= 'd0;
end
else begin
	req <= 'd0;
	selected_channel <= 'd255;
	for (n8 = 0; n8 < CHANNELS; n8 = n8 + 1)
		if (input_fifo_rd_d1[n8] && last_tid[n8] != input_fifo_dout[n8].tid) begin
			last_tid[n8] <= input_fifo_dout[n8].tid;
			req <= input_fifo_dout[n8];
		end
	/*
		if (rr_sel[n8] && last_tid[n8] != input_fifo_dout[n8].tid && !input_fifo_full[n8])	begin // should be one hot
			last_tid[n8] <= input_fifo_dout[n8].tid;
			req <= input_fifo_dout[n8];//wbn_req_d[n8];
			selected_channel <= n8;
		end
	*/
end

always_comb
begin
	wbm_resp = 'd0;
	wbm_resp.cid = fta_req_o.cid;
	wbm_resp.tid = fta_req_o.tid;
	wbm_resp.stall = 1'b0;
	wbm_resp.next = 1'b0;
	wbm_resp.ack = acko;
	wbm_resp.err = 1'b0;
	wbm_resp.rty = 1'b0;
	wbm_resp.pri = 4'd7;
	wbm_resp.dat = dato;
	wbm_resp.adr = fta_req_o.padr;
end

fta_tranid_t used_tid [0:CHANNELS-1];
reg [3:0] resp_ch;

always_ff @(posedge clk_i)
if (rst_i) begin
	for (n10 = 0; n10 < CHANNELS; n10 = n10 + 1)
		used_tid[n10] <= 4'hF;
end
else begin
	for (n10 = 0; n10 < CHANNELS; n10 = n10 + 1)
		if (wbn_req_i[n10].cyc)
			used_tid[n10] <= wbn_req_i[n10].tid;
end

function [3:0] fnRespch;
input fta_tranid_t tid;
integer n;
begin
	fnRespch = CHANNELS;
	for (n = 0; n < CHANNELS; n = n + 1)
		if (tid.core==used_tid[n].core && tid.channel==used_tid[n].channel)
			fnRespch = n;
end
endfunction

always_comb
	for (n11 = 0; n11 < CHANNELS; n11 = n11 + 1)
		rr_req[n11] = ~input_fifo_empty[n11];
//		rr_req[n11] = wbn_req_i[n11].cyc;

reg [5:0] chcnt = 'd0;
always_ff @(posedge clk_i)
	chcnt <= chcnt + 2'd1;

// Send a retry back as the response for non-selected channels.
always_comb
begin
	wbn_resp_o = 'd0;
	/*
	case(rr_req)
	// No channels active, one of them should not be retrying.
	4'b0000:
		begin
			for (n9 = 0; n9 < CHANNELS; n9 = n9 + 1) begin
				wbn_resp_o[n9].rty = 'd1;
				wbn_resp_o[chcnt[$clog2(CHANNELS)-1:0]].rty = 'd0;
			end
		end
	// Some channels are active, only the chosen one gets the bus.
	default:
		for (n9 = 0; n9 < CHANNELS; n9 = n9 + 1)
			wbn_resp_o[n9].rty = (n9!=selected_channel);
	endcase
	*/
	wbn_resp_o[fnRespch(fta_resp_i.tid)] = fta_resp_i;
	if (wbm_resp.ack)
		wbn_resp_o[fnRespch(wbm_resp.tid)] = wbm_resp;
//	wbn_resp_o[fta_resp_i.tid[7:4]].adr = fta_req_o.padr;
end

always_comb
	xlaten_i = req.cyc;
always_comb
	om_i = req.om;
always_comb
	we_i = req.we;
always_comb
	asid_i = req.asid;
always_comb
	adr_i = req.vadr;
always_comb
	next_i = fta_resp_i.next;

always_ff @(posedge clk_i)
if (rst_i)
	rr_active <= 'd0;
else begin
	rr_active <= (rr_active | rr_sel);
	if (fta_resp_i.ack|fta_resp_i.rty|fta_resp_i.err)
		rr_active[fta_resp_i.tid[7:4]] <= 1'b0;
	if (wbm_resp.ack)
		rr_active[wbm_resp.tid[7:4]] <= 1'b0;
end
wire [3:0] cache_type = fta_req_o.cache;

wire non_cacheable =
	cache_type==fta_bus_pkg::NC_NB ||
	cache_type==fta_bus_pkg::NON_CACHEABLE
	;
always_comb
//	snoop_v = (fta_req_o.we|non_cacheable) & fta_req_o.cyc; // Why non-cacheable????
	snoop_v = fta_req_o.we & fta_req_o.cyc;
always_comb
	snoop_adr = fta_req_o.padr;
always_comb
	snoop_cid = (non_cacheable) ? 4'd15 : fta_req_o.tid[7:4];

roundRobin
#(
	.N(CHANNELS)
) 
urr1
(
	.rst(rst_i),
	.clk(clk_g),
	.ce(1'b1),
	.req(rr_req),
	.lock('d0),
	.sel(rr_sel),
	.sel_enc()
);

reg toggle;
always_ff @(posedge clk_g)
if (rst_i)
	toggle <= 'd0;
else
	toggle <= state != ST_RST;//1'b1;//~toggle;

always_ff @(posedge clk_g)
if (rst_i)
	input_fifo_rd <= 'd0;
else begin
	input_fifo_rd <= 'd0;
	input_fifo_rd <= {CHANNELS{toggle}} & rr_sel;
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// Select the least recently used entry.
always_comb
begin
	wway = 5'd31;
	for (n6 = 0; n6 < 4; n6 = n6 + 1)
		if (wway==5'd31)
			if (tlbdato[n6].lru==3'd7)
				wway = n6;
			else if (tlbdato[n6].lru==3'd6)
				wway = n6;
			else if (tlbdato[n6].lru==3'd5)
				wway = n6;
			else if (tlbdato[n6].lru==3'd4)
				wway = n6;
			else if (tlbdato[n6].lru==3'd3)
				wway = n6;
			else if (tlbdato[n6].lru==3'd2)
				wway = n6;
			else if (tlbdato[n6].lru==3'd1)
				wway = n6;
			else
				wway = n6;
end


reg [ASSOC-1:0] wr;
reg wed;
reg [3:0] hit;
reg [ASSOC-1:0] wrtlb, next_wrtlb;
genvar g1;
generate begin : gWrtlb
	for (g1 = 0; g1 < ASSOC; g1 = g1 + 1) begin : gFor
		always_comb begin
			next_wrtlb[g1] <= 'd0;
			if (state==ST_UPD3) begin
				if (LRU && tlbadr_i[3:0] < 4) begin
					if (g1==wway)
						next_wrtlb[g1] <= wrtlb_i;
				end
				else begin
					if (tlbadr_i[3:0]==ASSOC-1) begin
						if (g1==ASSOC-1)
		 					next_wrtlb[g1] <= wrtlb_i;
		 			end
					else if (g1 < 4)
		 				next_wrtlb[g1] <= (RAND ? randway==g1 : tlbadr_i[3:0]==g1) && wrtlb_i;
		 			else
		 				next_wrtlb[g1] <= tlbadr_i[3:0]==g1 && wrtlb_i;
	 			end
 			end
 		end
 	end
end
endgenerate

// TLB RAM has a 1 cycle lookup latency.
// These signals need to be matched
always_ff @(posedge clk_g)
	xlatend <= xlaten_i;
always_ff @(posedge clk_g)
	iadrd <= req.vadr;

wire [ASSOC-1:0] wrtlbd;
ft_delay #(.WID(ASSOC), .DEP(3)) udlyw (.clk(clk_g), .ce(1'b1), .i(wrtlb), .o(wrtlbd));

wire pe_xlat, ne_xlat;
edge_det u5 (
  .rst(rst_i),
  .clk(clk_g),
  .ce(1'b1),
  .i(xlaten_i),
  .pe(pe_xlat),
  .ne(ne_xlat),
  .ee()
);

// Detect a change in the page number
wire cd_adr;
change_det #(.WID($bits(Thor2024pkg::address_t)-LOG_PAGE_SIZE)) ucd1 (
	.rst(rst_i),
	.clk(clk_g),
	.ce(1'b1),
	.i(adr_i[$bits(Thor2024pkg::address_t)-1:LOG_PAGE_SIZE]),
	.cd(cd_adr)
);

reg [5:0] dl;
always_ff @(posedge clk_g)
	if (cd_adr)
		dl <= 6'd0;
	else
		dl <= {dl[4:0],1'b1};

always_ff @(posedge clk_g)
	adrd <= adr_i;
always_ff @(posedge clk_g)
	asidd <= asid_i;

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i) begin
	randway <= 'd0;
end
else begin
	if (!wrtlb_i) begin
		randway <= randway + 2'd1;
		if (randway==ASSOC-2)
			randway <= 'd0;
	end
end

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i) begin
	state <= ST_RST;
	tlbdat_rst <= 'd0;
	master_count <= 6'd1;
	tlbeni <= 1'b1;		// forces ready low
	tlbwrr <= 'd0;
	wrtlb <= 'd0;
	count <= 'd0;		// Map only last 256kB
	rcount <= 'd0;
	inv_count <= 'd0;
	invall <= 'd0;
	clock_r <= 1'b0;
	htable_lookup <= 'd0;
end
else begin
tlbeni  <= 1'b0;
tlbwrr <= 'd0;
htable_lookup <= 1'b0;
case(state)
	
// Setup the last 256kB/16 pages of memory to point to the ROM BIOS.
ST_RST:
	begin
		master_count <= 6'd1;
		tlbeni <= 1'b1;
		tlbwrr <= 'd0;
		case(count[7])
//		13'b000: begin tlbwr0r <= 1'b1; tlbdat_rst <= {8'h00,8'hEF,14'h0,count[11:10],12'h000,8'h00,count[11:0]};	end // Map 16MB RAM area
//		13'b001: begin tlbwr1r <= 1'b1; tlbdat_rst <= {8'h00,8'hEF,14'h1,count[11:10],12'h000,8'h00,count[11:0]};	end // Map 16MB RAM area
//		13'b010: begin tlbwr2r <= 1'b1; tlbdat_rst <= {8'h00,8'hEF,14'h2,count[11:10],12'h000,8'h00,count[11:0]};	end // Map 16MB RAM area
		1'b0:
			begin
				tlbwrr[ASSOC-1] <= 1'b1; 
				tlbdat_rst <= 'd0;
				tlbdat_rst.count <= 6'd1;
				//tlbdat_rst.pte.g <= 1'b1;
				tlbdat_rst.pte.v <= 1'b1;
				tlbdat_rst.pte.m <= 1'b1;
				tlbdat_rst.pte.g <= 1'b1;
				tlbdat_rst.pte.urwx <= 3'd7;
				tlbdat_rst.pte.srwx <= 3'd7;
				tlbdat_rst.pte.hrwx <= 3'd7;
				//tlbdat_rst.pte.c <= 1'b1;
				// FFFC0000
				// 1111_1111_1111_1100_00 00_0000_0000_0000
				tlbdat_rst.vpn.asid <= 'd0;
				// ROM / scratchpad mapped into last 4MB
				if (count[6]) begin
					tlbdat_rst.vpn <= 8'h3F;
					tlbdat_rst.pte.ppn <= 16'hFFC0 + count[5:0];
					rcount <= {4'hF,count[5:0]};
				end
				// IO mapped at $FECxxxxx
				else begin
					tlbdat_rst.vpn <= 8'h3F;
					tlbdat_rst.pte.ppn <= 16'hFEC0 + count[5:0];
					rcount <= {4'hB,count[5:0]};
				end
				tlbdat_rst.pte.cache <= 'd0;//fta_bus_pkg::CACHEABLE;
				//tlbdat_rst.ppnx <= 12'h000;
			end // Map 16MB ROM/IO area
		1'b1: begin state <= ST_RUN; tlbwrr[ASSOC-1] <= 1'd1; end
		default:	;
		endcase
		count <= count + 2'd1;
		invall <= 'd0;
		inv_count <= ENTRIES-1;
	end
ST_RUN:
	begin
		if (invall && inv_count==ENTRIES-1) begin
			inv_count <= 'd0;
			invall <= 'd0;
			// Master count never hits zero.
			master_count <= master_count + 2'd1;
			if (master_count == 6'd63)
				master_count <= 6'd1;
		end
		if (wrtlb_i) begin
			tlbeni <= 1'b1;
			state <= ST_UPD1;
		end
		else if (inv_count != ENTRIES-1) begin
			wrtlb <= 'd0;
			inv_count <= inv_count + 2'd1;
			state <= ST_INVALL1;
		end
		else if (HTABLE && tlbmiss_irq) begin
			htable_lookup <= 1'b1;
			state <= ST_LOOKUP;
		end
	end
ST_UPD1:
	begin
		tlbeni <= 1'b1;
		state <= ST_UPD2;
	end
ST_UPD2:
	begin
		tlbeni <= 1'b1;
		state <= ST_UPD3;
	end
ST_UPD3:
	begin
		tlbeni <= 1'b1;
		wrtlb <= next_wrtlb;
		state <= ST_RUN;
	end

ST_INVALL1:
	begin
		tlbeni <= 1'b1;
		state <= ST_INVALL2;
	end
ST_INVALL2:
	begin
		tlbeni <= 1'b1;
		state <= ST_INVALL3;
	end
ST_INVALL3:
	begin
		tlbeni <= 1'b1;
		state <= ST_INVALL4;
	end
ST_INVALL4:
	begin
		tlbeni <= 1'b1;
		for (n2 = 0; n2 < ASSOC; n2 = n2 + 1) begin
			if (tlbdato[n2].count!=master_count)
				tlbwrr[n2] <= 1'b1;
		end
		state <= ST_RUN;
	end
ST_LOOKUP:
	begin
		tlbdat_rst <= 'd0;
		tlbdat_rst.count <= master_count;
		//tlbdat_rst.pte.g <= 1'b1;
		tlbdat_rst.pte.v <= 1'b1;
		tlbdat_rst.pte.m <= htable_pte_o.m;
		tlbdat_rst.pte.g <= htable_pte_o.g;
		tlbdat_rst.pte.urwx <= htable_pte_o.urwx;
		//tlbdat_rst.pte.c <= 1'b1;
		// FFFC0000
		// 1111_1111_1111_1100_00 00_0000_0000_0000
		tlbdat_rst.vpn.asid <= tlbmiss_asid;
		tlbdat_rst.vpn <= tlbmiss_adr[31:18];
		tlbdat_rst.pte.ppn <= htable_pte_o.ppn;
		tlbdat_rst.pte.cache <= htable_pte_o.cache;
		if (htable_ack)
			state <= ST_RUN;
	end
default:
	state <= ST_RUN;
endcase
end
assign rdy_o = ~tlbeni;

Thor2024_stlb_ad_state_machine
#(
	.ENTRIES(ENTRIES),
	.PAGE_SIZE(PAGE_SIZE),
	.ASSOC(ASSOC)
)
usm2
(
	.clk(clk_g),
	.state(state),
	.lookup_ack(htable_ack),
	.rcount(rcount),
	.tlbadr_i(tlbadr_i),
	.tlbadro(tlbadri), 
	.tlbdat_rst(tlbdat_rst),
	.tlbdat_i(tlbdat_i),
	.tlbdato(tlbdati),
	.master_count(master_count),
	.inv_count(inv_count)
);

// Dirty / Accessed bit write logic
always_ff @(posedge clk_g)
  wed <= we_i;

always_ff @(posedge clk_g)
begin
	wr <= 'd0;
  if (ne_xlat) begin
  	for (n1 = 0; n1 < ASSOC; n1 = n1 + 1) begin
  		tentryi[n1] <= tentryo2[n1];
  		case(hit)
  		4'd0,4'd1,4'd2,4'd3:
	  		if (n1 < 4) begin
		  		if (tentryo2[n1].lru < tentryo2[hit].lru)
		  			tentryi[n1].lru <= tentryo2[n1].lru + 2'd1;
	  		end
  		4'd5:
	  		if (n1==4) begin
		  		if (tentryo2[n1].lru < tentryo2[hit].lru)
		  			tentryi[n1].lru <= tentryo2[n1].lru + 2'd1;
	  		end
  		default:	;
  		endcase
  	end
  	if (hit < 4'd15) begin
			tentryi[hit].lru <= 'd0;
			if (wed)
				tentryi[hit].pte.m <= 1'b1;
	 		wr <= {ASSOC{1'b1}};
 		end
  end
end

always_comb
for (n7 = 0; n7 < ASSOC; n7 = n7 + 1)
	if (n7 < ASSOC-LVL1_ASSOC-1 || n7==ASSOC-1)
		adr_i_slice[n7] = adr_i[LOG_PAGE_SIZE+LOG_ENTRIES-1:LOG_PAGE_SIZE];
	else
		adr_i_slice[n7] = adr_i[$bits(Thor2024pkg::address_t)-1:LOG_ENTRIES+LOG_PAGE_SIZE];
	
generate begin : gTlbRAM
for (g = 0; g < ASSOC; g = g + 1) begin : gLvls
	Thor2024_TLBRam
	# (
		.ENTRIES(ENTRIES),
		.WIDTH($bits(STLBE))
	)
	u1 (
	  .clka(clk_g),
	  .ena(tlben_i|tlbeni),
	  .wea(wrtlb[g]|tlbwrr[g]),
	  .addra(tlbadri),
	  .dina(tlbdati),
	  .douta(tlbdato[g]),
	  .clkb(clk_g),
	  .enb(xlaten_i),
	  .web(wr[g]),
	  .addrb(adr_i_slice[g]),
	  .dinb(tentryi[g]),
	  .doutb(tentryo[g])
	);
end
end
endgenerate

// Pipeline delay req.
always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	req1 <= 'd0;
else
	req1 <= req;
always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	omd <= fta_bus_pkg::APP;
else
	omd <= om_i;
always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	omd2 <= fta_bus_pkg::APP;
else
	omd2 <= omd;


// Mask for virtual address bits that must match the incoming address.
function Thor2024pkg::address_t fnVmask1;
input [4:0] L;
integer nn;
begin
for (nn = 0; nn < $bits(Thor2024pkg::address_t); nn = nn + 1)
	if (nn < LOG_PAGE_SIZE + LOG_ENTRIES*(L+1))
		fnVmask1[nn] = 1'b0;
	else
		fnVmask1[nn] = 1'b1;
end
endfunction

// Mask for virtual page number that must match incoming address's page number.
function Thor2024pkg::address_t fnVmask2;
input [4:0] L;
integer nn;
begin
	for (nn = 0; nn < $bits(Thor2024pkg::address_t); nn = nn + 1)
		if (nn < LOG_ENTRIES * L)
			fnVmask2 = 1'b0;
		else
			fnVmask2 = 1'b1;
end
endfunction

always_ff @(posedge clk_g)
	if (tlbmiss_irq) begin
		htable_adr <= tlbmiss_adr;
		htable_asid <= tlbmiss_asid;
	end
	else begin
		htable_adr <= vpn_reg.vpn;
		htable_asid <= vpn_reg.asid;
		htable_pte <= pte_reg;
	end

generate begin : gHtable
if (HTABLE)
	Thor2024_htable uhtbl1
	(
		.rst(rst_i),
		.clk(clk2x_i),
		.lookup(htable_lookup),
		.update(htable_update),
		.upte(htable_pte),
		.asid(htable_asid),
		.vadr(htable_adr),
		.pte_o(htable_pte_o),
		.ack(htable_ack),
		.exc(htable_exc)
	);
else begin
	assign htable_ack = 1'b0;
	assign htable_exc = 1'b0;
end
end
endgenerate

// hit is the way containing the translation.
reg [3:0] hitr;

address_t mask1;
modAMask uam1
(
	.L(tentryo[hit].pte.bc),
	.mask(mask1)
);

modHit uhit1
(
	.xlaten(xlatend),
	.req(req1),
	.tentryo(tentryo),
	.master_count(master_count),
	.asid(asidd),
	.hitr(hitr),
	.hit(hit)
);

address_t t1, t2;
always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	t1 <= 'd0;
else
	t1 <= req1.vadr & mask1;
always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	t2 <= 'd0;
else begin
	if (hit < 4'd15)
		t2 <= {tentryo[hit].pte.ppn,{LOG_PAGE_SIZE{1'b0}}} & ~mask1;
	else
		t2 <= {$bits(address_t){1'b1}} & ~mask1;
end

always_ff @(posedge clk_g, posedge rst_i)
if (rst_i)
	hitr <= 'd0;
else
	hitr <= hit;

address_t t12;
assign t12 = t1|t2;

modTranslate
#(
	.RSTIP(RSTIP),
	.ASSOC(ASSOC),
	.PAGE_SIZE(PAGE_SIZE)
)
umtran1
(
	.rst(rst_i),
	.clk(clk_g),
	.xlaten(xlatend),
	.hitr(hitr),
	.hit(hit),
	.cd_adr(cd_adr),
	.dl(dl),
	.req(req1),
	.tlbmiss_irq(tlbmiss_irq),
	.tlbmiss_adr(tlbmiss_adr),
	.tlbmiss_asid(tlbmiss_asid),
	.adr(adrd),
	.asid(asidd),
	.t12(t12),
	.om(omd),
	.tentryo(tentryo),
	.rwx(rwx),
	.rwx_i(rwx_o),
	.rgn(rgn),
	.cache(cache),
	.cache_i(cache_o),
	.tentryo2(tentryo2),
	.fta_req_o(fta_req_o)
);

always_comb
	rwx_o = |rwx ? rwx : region.at[omd2].rwx;

// Cache-ability output. Region takes precedence.
always_comb
	case(fta_cache_t'(region.at[omd2].cache))
	fta_bus_pkg::NC_NB:					cache_o = fta_bus_pkg::NC_NB;
	fta_bus_pkg::NON_CACHEABLE:	cache_o = fta_bus_pkg::NON_CACHEABLE;
	fta_bus_pkg::CACHEABLE_NB:
		case(fta_cache_t'(cache))
		fta_bus_pkg::NC_NB:					cache_o = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	cache_o = fta_bus_pkg::NON_CACHEABLE;
		fta_bus_pkg::CACHEABLE_NB:		cache_o = fta_bus_pkg::CACHEABLE_NB;
		fta_bus_pkg::CACHEABLE:			cache_o = fta_bus_pkg::CACHEABLE_NB;
		default:				cache_o = cache;
		endcase
	fta_bus_pkg::CACHEABLE:
		case(fta_cache_t'(cache))
		fta_bus_pkg::NC_NB:					cache_o = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	cache_o = fta_bus_pkg::NON_CACHEABLE;
		fta_bus_pkg::CACHEABLE_NB:		cache_o = fta_bus_pkg::CACHEABLE_NB;
		default:				cache_o = cache;
		endcase
	fta_bus_pkg::WT_NO_ALLOCATE,fta_bus_pkg::WT_READ_ALLOCATE,fta_bus_pkg::WT_WRITE_ALLOCATE,fta_bus_pkg::WT_READWRITE_ALLOCATE,
	fta_bus_pkg::WB_NO_ALLOCATE,fta_bus_pkg::WB_READ_ALLOCATE,fta_bus_pkg::WB_WRITE_ALLOCATE,fta_bus_pkg::WB_READWRITE_ALLOCATE:
		case(fta_cache_t'(cache))
		fta_bus_pkg::NC_NB:					cache_o = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	cache_o = fta_bus_pkg::NON_CACHEABLE;
		default:				cache_o = region.at[omd2].cache;
		endcase
	default:	cache_o = fta_bus_pkg::NC_NB;
	endcase

endmodule


// Mask selecting between incoming address bits and address bits from the PPN.
module modAMask(L, mask);
input [4:0] L;
output address_t mask;

integer nn;

always_comb
begin
for (nn = 0; nn < $bits(Thor2024pkg::address_t); nn = nn + 1)
	if (nn < LOG_PAGE_SIZE + LOG_ENTRIES*L)
		mask[nn] = 1'b1;
	else
		mask[nn] = 1'b0;
end

endmodule

// hit is the way containing the translation.
module modHit(xlaten, req, tentryo, master_count, asid, hitr, hit);
parameter ASSOC = 6;
input xlaten;
input fta_cmd_request128_t req;
input tlb_count_t master_count;
input fta_asid_t asid;
input STLBE tentryo [0:ASSOC-1];
input [3:0] hitr;
output reg [3:0] hit;

integer n13;

// Compute shift for low order bits that do not need to be compared.
// Applied to incoming virtual address.
function [7:0] fnShamt1;
input [4:0] L;
integer nn;
begin
	fnShamt1 = LOG_PAGE_SIZE + LOG_ENTRIES*(L+1);
end
endfunction

// Compute shift for low order bits that do not need to be compared.
// Applied to the virtual page number.
function [7:0] fnShamt2;
input [4:0] L;
integer nn;
begin
	fnShamt2 = LOG_ENTRIES*L;
end
endfunction

function fnCompareVPN2Address;
input [77:0] vpn;
input [$bits(Thor2024pkg::address_t)-1:0] address;
input [4:0] L;
begin
	fnCompareVPN2Address = 
		(vpn >> fnShamt2(L)) ==
		(address >> fnShamt1(L))
		;
end
endfunction

always_comb
begin
	hit = 4'd15;
	for (n13 = 0; n13 < ASSOC; n13 = n13 + 1) begin
		if (tentryo[n13].count==master_count) begin
			if (tentryo[n13].vpn.asid[11:0]==asid[11:0] || tentryo[n13].pte.g) begin
				if (tentryo[n13].pte.v) begin
					if (fnCompareVPN2Address(
						tentryo[n13].vpn.vpn,
						{{2{&/*iadrd*/req.vadr[$bits(Thor2024pkg::address_t)-1:$bits(Thor2024pkg::address_t)-4]}},/*iadrd*/req.vadr},
						tentryo[n13].pte.bc
						)) begin
						hit = n13;
					end
				end
			end
		end
	end
end

endmodule


module modTranslate(rst, clk, xlaten, hitr, hit, cd_adr, dl, om, req,
	tlbmiss_irq, tlbmiss_adr, tlbmiss_asid, adr, asid, t12, cache_i,
	tentryo, rwx, rwx_i, rgn, cache, tentryo2, fta_req_o
);
parameter RSTIP = 32'hFFFD0000;
parameter ASSOC = 6;
parameter PAGE_SIZE = 65536;
localparam LOG_PAGE_SIZE = $clog2(PAGE_SIZE);
input rst;
input clk;
input xlaten;
input [3:0] hitr;
input [3:0] hit;
input cd_adr;
input [5:0] dl;
input fta_operating_mode_t om;
input fta_cmd_request128_t req;
output reg tlbmiss_irq;
output address_t tlbmiss_adr;
output fta_asid_t tlbmiss_asid;
input address_t adr;
input fta_asid_t asid;
input address_t t12;
input [3:0] cache_i;
input [2:0] rwx_i;
input STLBE tentryo [0:ASSOC-1];
output reg [2:0] rwx;
output reg [2:0] rgn;
output reg [3:0] cache;
output STLBE tentryo2 [0:ASSOC-1];
output fta_cmd_request128_t fta_req_o;

fta_cmd_request128_t fta_req;
code_address_t rstip = RSTIP;
reg xlatend;

integer n;

always_ff @(posedge clk, posedge rst)
if (rst) begin
//	fta_req_o <= 'd0;
//	fta_req_o <= req1;
	xlatend <= 'd0;
	fta_req.om <= fta_bus_pkg::APP;
	fta_req.cid <= 'd0;
	fta_req.tid <= 'd0;
	fta_req.cmd <= fta_bus_pkg::CMD_NONE;
	fta_req.bte <= fta_bus_pkg::LINEAR;
	fta_req.blen <= 'd0;
	fta_req.sz <= fta_bus_pkg::hexi;
	fta_req.seg <= fta_bus_pkg::DATA;
	fta_req.cti <= fta_bus_pkg::CLASSIC;
	fta_req.cyc <= 1'b0;
	fta_req.stb <= 1'b0;
	fta_req.we <= 1'b0;
	fta_req.sel <= 16'h0;
	fta_req.asid <= 'd0;
	fta_req.vadr <= rstip;
 	fta_req.padr[LOG_PAGE_SIZE-1:0] <= rstip[LOG_PAGE_SIZE-1:0];
  fta_req.padr[$bits(Thor2024pkg::address_t)-1:LOG_PAGE_SIZE] <= rstip[$bits(Thor2024pkg::address_t)-1:LOG_PAGE_SIZE];
  fta_req.data1 <= 'd0;
  fta_req.data2 <= 'd0;
  fta_req.csr <= 'd0;
  fta_req.pl <= 'd0;
  fta_req.pri <= 4'd7;
  fta_req.cache <= fta_bus_pkg::NC_NB;
  tlbmiss_irq <= FALSE;
	tlbmiss_adr <= 'd0;
	tlbmiss_asid <= 'd0;
  rwx <= 3'd7;
  rgn <= 3'd7;	// select default ROM region
  cache <= fta_bus_pkg::CACHEABLE;
	for (n = 0; n < ASSOC; n = n + 1)
		tentryo2[n] <= 'd0;
end
else begin
	xlatend <= xlaten;
  rgn <= 3'd7;	// select default ROM region
  /*
	if (next_i) begin
		rgn <= rgn;
		cache <= cache;
    tlbmiss_irq <= FALSE;
		rwx <= rwx;
		fta_req.padr <= fta_req.padr + 6'd16;
	end
  else
  */
  begin
		if (0 && !xlatend) begin
	    tlbmiss_irq <= FALSE;
	    fta_req <= 'd0;
	    /*
			if (req.cyc)
	  		fta_req.padr <= {16'h0000,req.vadr[$bits(Thor2024pkg::address_t)-1:0]};
	  	else
	  	*/
	  		fta_req.padr <= 32'hFFFFFFF0;
	    rwx <= 4'hF;
		end
		else begin
			tlbmiss_irq <= dl[4] & ~cd_adr;
			if (dl[4] & ~cd_adr) begin
				tlbmiss_adr <= adr;
				tlbmiss_asid <= asid;
			end
			rwx <= 4'h0;
			for (n = 0; n < ASSOC; n = n + 1)
				tentryo2[n] <= tentryo[n];
			if (hit < 4'd15) begin
				case(om)
				2'd0:	rwx <= tentryo[hit].pte.urwx;
				2'd1:	rwx <= tentryo[hit].pte.srwx;
				2'd2:	rwx <= tentryo[hit].pte.hrwx;
				2'd3:	rwx <= 3'd7;
				endcase
				cache <= tentryo[hit].pte.cache;
				tlbmiss_irq <= FALSE;
			  rgn <= tentryo[hit].pte.rgn;
				fta_req.om <= req.om;
				fta_req.cid <= req.cid;
				fta_req.tid <= req.tid;
				fta_req.cmd <= req.cmd;
				fta_req.seg <= req.seg;
				fta_req.cti <= req.cti;
				fta_req.cyc <= req.cyc;
				fta_req.stb <= req.stb;
				fta_req.we <= req.we;
				fta_req.sel <= req.sel;
				fta_req.asid <= req.asid;
				fta_req.vadr <= req.vadr;
			//	fta_req.padr <= fta_req_o.padr;
				fta_req.data1 <= req.data1;
				fta_req.data2 <= req.data2;
				fta_req.cache <= req.cache;
				if (tentryo[hit].pte.bc==1)
					fta_req.padr <= {tentryo[hit].pte.ppn[15:10],req.vadr[25:0]};
				else
					fta_req.padr <= {tentryo[hit].pte.ppn,req.vadr[15:0]};
			end
			else begin
				cache <= fta_bus_pkg::NC_NB;
				fta_req.cyc <= 1'b0;
			end				
		end
	end
	fta_req_o <= fta_req;
//	fta_req_o.padr <= t12;
	fta_req_o.cache <= fta_cache_t'(cache_i);
	fta_req_o.we <= fta_req.we & rwx_i[1];
end

endmodule
