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

module Thor2023_mpu(rst_i, clk_i, wbm_req, wbm_resp);
input rst_i;
input clk_i;
output wb_cmd_request128_t wbm_req;
input wb_cmd_response128_t wbm_resp;
parameter CHANNELS = 5;

wb_cmd_request128_t [CHANNELS-1:0] wbn_req;
wb_cmd_response128_t [CHANNELS-1:0] wbn_resp;

Thor2023_stlb ustlb
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.clock(),
	.al_i(),
	.rdy_o(),
	.sys_mode_i(),
	.stptr_i(),
	.acr_o(),
	.tlben_i(),
	.wrtlb_i(),
	.tlbadr_i(),
	.tlbdat_i(),
	.tlbdat_o(),
	.tlbmiss_o(),
	.tlbmiss_adr_o(),
	.tlbkey_o(),
	.wbn_req_iwbn_req),
	.wbn_resp_o(wbn_resp),
	.wb_req_o(wbm_req),
	.wb_resp_i(wbm_resp),
	.snoop_v(),
	.snoop_adr(),
	.snoop_cid()
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// PMA Checker
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

REGION region;
wire [2:0] region_num;
wire [7:0] region_sel;
wb_cmd_response128_t rgn_resp;

Thor2023_active_region uargn
(
	.rst(rst_i),
	.clk(clk_i),
	.wbs_req(wbm_req),
	.wbs_resp(rgn_resp),
	.region_num(),
	.region(region),
	.sel(region_sel),
	.err()
);

always_comb
	wbm_resp = rgn_resp;

endmodule
