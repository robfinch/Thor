// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	biu_tb.sv
//	- bus interface unit test bench
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
// 32373 LUTs / 35147 FFs / 31 BRAMs                                                                          
// ============================================================================

import wishbone_pkg::*;
import Thor2023Pkg::*;
import Thor2023Mmupkg::*;

module biu_tb();

reg rst;
reg clk;
reg pe = 1'b1;
reg dce = 1'b1;
reg run = 1'b1;
wire ihit;
wire ic_valid;
Thor2023Pkg::address_t pc;
Thor2023Pkg::address_t pc_o;
reg [31:0] count;
reg [31:0] a;
reg snoop_v;
Thor2023Pkg::address_t snoop_adr;
reg [3:0] snoop_cid;
wb_cmd_request128_t wbm_req;
wb_cmd_response128_t wbm_resp;
wb_cmd_request128_t iwbm_req;
wb_cmd_response128_t iwbm_resp;
ICacheLine ic_line_hi, ic_line_lo;
memory_arg_t memreq;
wire memreq_full;
wire memreq_wack;
reg memresp_fifo_rd = 1'b0;
wire memresp_fifo_empty;
wire memresp_fifo_v;

initial begin
  a = $urandom(1);
	rst = 1'b0;
	clk = 1'b0;
	#10 rst = 1'b1;
	#300 rst = 1'b0;
end

always #5 clk = ~clk;

Thor2023_biu
#(
	.CID(4'd1)
)
ubiu
(
	.rst(rst),
	.clk(clk),
	.tlbclk(clk),
	.clock(1'b0),
	.AppMode(1'b0),
	.MAppMode(1'b0),
	.omode(3'd3),
//	.ASID(asid),
	.bounds_chk(),
	.pe(pe),
	.ip(pc),
	.ip_o(pc_o),
	.ihit_o(ihit),
	.ifStall(!run),
	.ic_line_hi(ic_line_hi),
	.ic_line_lo(ic_line_lo),
	.ic_valid(ic_valid),
	.fifoToCtrl_i(memreq),
	.fifoToCtrl_full_o(memreq_full),
	.fifoToCtrl_wack(memreq_wack),
	.fifoFromCtrl_o(memresp),
	.fifoFromCtrl_rd(memresp_fifo_rd),
	.fifoFromCtrl_empty(memresp_fifo_empty),
	.fifoFromCtrl_v(memresp_fifo_v),
//	.bok_i(bok_i),
	.bte_o(wbm_req.bte),
	.blen_o(wbm_req.blen),
	.tid_o(wbm_req.tid),
	.cti_o(wbm_req.cti),
	.seg_o(wbm_req.seg),
//	.vpa_o(vpa_o),
//	.vda_o(vda_o),
	.cyc_o(wbm_req.cyc),
	.stb_o(wbm_req.stb),
	.ack_i(wbm_resp.ack),
	.stall_i(1'b0),
	.next_i(wbm_resp.next),
	.rty_i(wbm_resp.rty),
	.err_i(wbm_resp.err),
	.tid_i(wbm_resp.tid),
	.we_o(wbm_req.we),
	.sel_o(wbm_req.sel),
	.adr_o(wbm_req.padr),
	.dat_i(wbm_resp.dat),
	.dat_o(wbm_req.data1),
	.csr_o(wbm_req.csr),
	.adr_i(wbm_resp.adr),
	.dce(dce),
	.keys(),
	.arange(),
	.ptbr(),
	.rollback(),
	.rollback_bitmaps(),
	.iwbm_req(iwbm_req),
	.iwbm_resp(iwbm_resp),
	.dwbm_req(),
	.dwbm_resp(),
	.snoop_v(snoop_v),
	.snoop_adr(snoop_adr),
	.snoop_cid(snoop_cid)
);

assign iwbm_req.padr = iwbm_req.vadr;

scratchmem128pci uscr1
(
	.rst_i(rst),
	.cs_config_i(1'b0),
	.cs_ram_i(iwbm_req.vadr[31:24]==8'hFF),
	.clk_i(clk),
	.cyc_i(iwbm_req.cyc),
	.stb_i(iwbm_req.stb),
	.next_o(iwbm_resp.next),
	.ack_o(iwbm_resp.ack),
	.we_i(1'b0),
	.sel_i(16'hFFFF),
	.adr_i(iwbm_req.vadr[31:0]),
	.dat_i(),
	.dat_o(iwbm_resp.dat),
	.adr_o(iwbm_resp.adr)
);


always_ff @(posedge clk, posedge rst)
if (rst) begin
	pc <= 32'hFFFD0000;
	count <= 'd0;
	snoop_v <= 1'b0;
	snoop_adr <= 'd0;
	snoop_cid <= 4'd1;
	memreq <= 'd0;
end
else begin
	if (ihit)
		pc <= pc + 4'd5;
	count <= count + 2'd1;
	snoop_v <= 1'b0;
	// After a few cycles, see if we can still execute from the cache, hit.
	if (count == 25)
		pc <= 32'hFFFD0000;
	// Every so often, branch to a random address
	if (count > 100) begin
		if (ihit && count[3:0]==4'd10) begin
			pc <= ($urandom() & 32'hffff) | (pc & 32'hffff0000);
		end
	end
	// Every so often, invalidate an address.
	if (count[5:0]==6'd30) begin
		snoop_v <= 1'b1;
		snoop_adr <= ($urandom() & 32'hffff) | (pc & 32'hffff0000);
		snoop_cid <= 4'd1;
	end
end

endmodule
