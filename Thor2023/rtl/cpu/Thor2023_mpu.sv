// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_mpu.sv
//	- processing unit
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

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module Thor2023_mpu(rst_i, clk_i, wbm_req, wbm_resp, irq_bus,
	clk0, gate0, out0, clk1, gate1, out1, clk2, gate2, out2, clk3, gate3, out3
	);
input rst_i;
input clk_i;
output wb_cmd_request128_t wbm_req;
input wb_cmd_response128_t wbm_resp;
input [31:0] irq_bus;
input clk0;
input gate0;
output out0;
input clk1;
input gate1;
output out1;
input clk2;
input gate2;
output out2;
input clk3;
input gate3;
output out3;
parameter CHANNELS = 4;

wb_cmd_request128_t [CHANNELS-1:0] wbn_req;
wb_cmd_response128_t [CHANNELS-1:0] wbn_resp;

wire cs_config, cs_io;
assign cs_config = wbm_req.padr[31:28]==4'hD;
assign cs_io = wbm_req.padr[31:24]==8'hFE;

wire snoop_v;
address_t snoop_adr;
wire [3:0] snoop_cid;
reg [31:0] iirq;

wire [7:0] pic_cause;
wire [5:0] pic_core;
wire [31:0] tlbmiss_irq;
wire [3:0] pic_irq;
wire [31:0] pit_irq;
wire pic_ack,pit_ack;
wire [31:0] pic_dato;
wire [63:0] pit_dato;
wb_cmd_request32_t wbm32_req;
wb_cmd_request64_t wbm64_req;
wb_cmd_response32_t pic_resp;
wb_cmd_response128_t pic128_resp;
wb_cmd_response64_t pit_resp;
wb_cmd_response128_t pit128_resp;
wb_cmd_response128_t wb128_resp;
wb_cmd_request128_t cpu1_ireq;
wb_cmd_response128_t cpu1_iresp;
wb_cmd_request128_t cpu1_dreq;
wb_cmd_response128_t cpu1_dresp;
wb_cmd_request128_t cpu2_ireq;
wb_cmd_response128_t cpu2_iresp;
wb_cmd_request128_t cpu2_dreq;
wb_cmd_response128_t cpu2_dresp;

Thor2023_stlb
#(
	.CHANNELS(CHANNELS)	// +1 for TLB itself
)
ustlb
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.rdy_o(),
	.rwx_o(),
	.tlbmiss_irq_o(tlbmiss_irq),
	.wbn_req_i(wbn_req),
	.wbn_resp_o(wbn_resp),
	.wb_req_o(wbm_req),
	.wb_resp_i(wb128_resp),
	.snoop_v(snoop_v),
	.snoop_adr(snoop_adr),
	.snoop_cid(snoop_cid)
);

wb_bridge128to64 ubridge1
(
	.req128_i(wbm_req),
	.resp128_o(pit128_resp),
	.req64_o(wbm64_req),
	.resp64_i(pit_resp)
);

Thor2023_pit utmr1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.cs_config_i(cs_config),
	.cs_io_i(cs_io),
	.cyc_i(wbm64_req.cyc),
	.stb_i(wbm64_req.stb),
	.ack_o(pit_ack),
	.sel_i(wbm64_req.sel),
	.we_i(wbm64_req.we),
	.adr_i(wbm64_req.padr),
	.dat_i(wbm64_req.dat),
	.dat_o(pit_dato),
	.clk0(clk0),
	.gate0(gate0),
	.out0(out0),
	.clk1(clk1),
	.gate1(gate1),
	.out1(out1),
	.clk2(clk2),
	.gate2(gate2),
	.out2(out2),
	.clk3(clk3),
	.gate3(gate3),
	.out3(out3),
	.irq_o(pit_irq)
);

always_comb
begin
	pit_resp.cid = wbm64_req.cid;
	pit_resp.tid = wbm64_req.tid;
	pit_resp.ack = pit_ack;
	pit_resp.err = 1'b0;
	pit_resp.rty = 1'b0;
	pit_resp.stall = 1'b0;
	pit_resp.next = 1'b0;
	pit_resp.dat = pit_dato;
	pit_resp.adr = wbm64_req.padr;
	pit_resp.pri = wbm64_req.pri;
end


wb_bridge128to32 ubridge2
(
	.req128_i(wbm_req),
	.resp128_o(pic128_resp),
	.req32_o(wbm32_req),
	.resp32_i(pic_resp)
);

// PIC needs to be able to detect INTA cycle where all address lines are high
// except for a0 to a3.
Thor2023_pic upic1
(
	.rst_i(rst_i),		// reset
	.clk_i(clk_i),		// system clock
	.cs_config_i(cs_config),
	.cs_io_i(cs_io),
	.cti_i(wbm32_req.cti),
	.cyc_i(wbm32_req.cyc),
	.stb_i(wbm32_req.stb),
	.ack_o(pic_ack),       // controller is ready
	.wr_i(wbm32_req.we),			// write
	.sel_i(wbm32_req.sel),
	.adr_i(wbm32_req.padr),	// address
	.dat_i(wbm32_req.dat),
	.dat_o(pic_dato),
	.vol_o(),		// volatile register selected
	.vp_o(),
	.i1(iirq[1]),
	.i2(iirq[2]),
	.i3(iirq[3]),
	.i4(iirq[4]),
	.i5(iirq[5]),
	.i6(iirq[6]),
	.i7(iirq[7]),
	.i8(iirq[8]),
	.i9(iirq[9]),
	.i10(iirq[10]),
	.i11(iirq[11]),
	.i12(iirq[12]),
	.i13(iirq[13]),
	.i14(iirq[14]),
	.i15(iirq[15]),
	.i16(iirq[16]),
	.i17(iirq[17]),
	.i18(iirq[18]),
	.i19(iirq[19]),
	.i20(iirq[20]),
	.i21(iirq[21]),
	.i22(iirq[22]),
	.i23(iirq[23]),
	.i24(iirq[24]),
	.i25(iirq[25]),
	.i26(iirq[26]),
	.i27(iirq[27]),
	.i28(iirq[28]),
	.i29(iirq[29]),
	.i30(iirq[30]),
	.i31(iirq[31]),
	.irqo(pic_irq),	// normally connected to the processor irq
	.nmii(1'b0),		// nmi input connected to nmi requester
	.nmio(),	// normally connected to the nmi of cpu
	.causeo(pic_cause),
	.core_o(pic_core)
);

always_comb
begin
	pic_resp.cid = wbm32_req.cid;
	pic_resp.tid = wbm32_req.tid;
	pic_resp.ack = pic_ack;
	pic_resp.err = 1'b0;
	pic_resp.rty = 1'b0;
	pic_resp.stall = 1'b0;
	pic_resp.next = 1'b0;
	pic_resp.dat = pic_dato;
	pic_resp.adr = wbm32_req.padr;
	pic_resp.pri = wbm32_req.pri;
end

Thor2023seq ucpu1
(
	.coreno_i(6'd1),
	.rst_i(rst_i),
	.clk_i(clk_i),
	.bok_i(1'b0),
	.iwbm_req(cpu1_ireq),
	.iwbm_resp(cpu1_iresp),
	.dwbm_req(cpu1_dreq),
	.dwbm_resp(cpu1_dresp),
	.rb_i(1'b0),
	.snoop_v(snoop_v),
	.snoop_adr(snoop_adr),
	.snoop_cid(snoop_cid)
);

Thor2023seq ucpu2
(
	.coreno_i(6'd2),
	.rst_i(rst_i),
	.clk_i(clk_i),
	.bok_i(1'b0),
	.iwbm_req(cpu2_ireq),
	.iwbm_resp(cpu2_iresp),
	.dwbm_req(cpu2_dreq),
	.dwbm_resp(cpu2_dresp),
	.rb_i(1'b0),
	.snoop_v(snoop_v),
	.snoop_adr(snoop_adr),
	.snoop_cid(snoop_cid)
);

always_comb wbn_req[0] = cpu1_ireq;
always_comb cpu1_iresp = wbn_resp[0];
always_comb wbn_req[1] = cpu1_dreq;
always_comb cpu1_dresp = wbn_resp[1];
always_comb wbn_req[2] = cpu2_ireq;
always_comb cpu2_iresp = wbn_resp[2];
always_comb wbn_req[3] = cpu2_dreq;
always_comb cpu2_dresp = wbn_resp[3];

always_comb
	if (pic_ack)
		wb128_resp = pic128_resp;
	else if (pit_ack)
		wb128_resp = pit128_resp;
	else
		wb128_resp = wbm_resp;

always_comb
	iirq = irq_bus|pit_irq|tlbmiss_irq;

endmodule
