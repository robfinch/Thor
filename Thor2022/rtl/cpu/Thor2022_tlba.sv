// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_tlb.sv
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

import Thor2022_pkg::*;
import Thor2022_tlbpkg::*;

module Thor2022_tlb(rst, clk, tlben_i, tlbwr_i, tlbadr_i, tlbdat_i, tlbdat_o,
	asid_i, sys_mode_i, xlaten_i,
	iaccess_i, iadr_i,
	daccess_i, dadr_i,
	padr_o, acr_o, tlbmiss_o
);
parameter ASSOC = 4;
input rst;
input clk;
// Update port
input tlben_i;
input tlbwr_i;
input [15:0] tlbadr_i;
input [127:0] tlbdat_i;
output [127:0] tlddat_o;

input [7:0] asid_i;
input sys_mode_i;
input xlaten_i;
input we_i;
// Instruction address input
input iaccess_i;
input Address iadr_i;
// Data address input
input daccess_i;
input Address dadr_i;

output Address padr_o;
output [3:0] acr_o;
output tlbmiss_o;

genvar g;
generate begin : gTable
	for (g = 0; g < ASSOC; g = g + 1)
		Thor2022_tlbram #(.WID($bits(TLBEntry))) u1 (
			
		);
end
endgenerate

endmodule
Thor2021_TLB utlb (
  .rst_i(rst),
  .clk_i(tlbclk),
  .rdy_o(tlbrdy),
  .asid_i(ASID),
  .umode_i(vpa_o ? UserMode : MUserMode),
  .xlaten_i(xlaten),
  .we_i(we_o),
  .ladr_i(dadr),
  .next_i(inext),
  .iacc_i(iaccess),
  .dacc_i(daccess),
  .iadr_i(iadr),
  .padr_o(adr_o),
  .acr_o(tlbacr),
  .tlben_i(tlben),
  .wrtlb_i(tlbwr & tlb_ia[63]),
  .tlbadr_i(tlb_ia[15:0]),
  .tlbdat_i(tlb_ib),
  .tlbdat_o(tlbdato),
  .tlbmiss_o(tlbmiss)
);

