// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_active_region.sv
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
import Thor2022_mmupkg::*;

module Thor2022_active_region(adr, region_num, region, err);
input Address adr;
output reg [3:0] region_num;
output REGION region;
output reg err;

integer n;
REGION [7:0] pma_regions;

initial begin
	// ROM
	pma_regions[7].start = 32'hFFFD0000;
	pma_regions[7].nd = 32'hFFFFFFFF;
	pma_regions[7].art	 = 32'h00000000;
	pma_regions[7].at = 16'h000D;		// rom, byte addressable, cache-read-execute

	// IO
	pma_regions[6].start = 32'hFF800000;
	pma_regions[6].nd = 32'hFF9FFFFF;
	pma_regions[6].art	 = 32'h00000300;
	pma_regions[6].at = 16'h0206;		// io, (screen) byte addressable, read-write

	// Vacant
	pma_regions[5].start = 32'hFFFFFFFF;
	pma_regions[5].nd = 32'hFFFFFFFF;
	pma_regions[5].art	 = 32'h00000000;
	pma_regions[5].at = 16'hFF00;		// no access

	// Scratchpad RAM
	pma_regions[4].start = 32'hFFFC0000;
	pma_regions[4].nd = 32'hFFFCFFFF;
	pma_regions[4].art	 = 32'h00002300;
	pma_regions[4].at = 16'h020F;		// byte addressable, read-write-execute cacheable

	// vacant
	pma_regions[3].start = 32'hFFFFFFFF;
	pma_regions[3].nd = 32'hFFFFFFFF;
	pma_regions[3].art	 = 32'h00000000;
	pma_regions[3].at = 16'hFF00;		// no access

	// vacant
	pma_regions[2].start = 32'hFFFFFFFF;
	pma_regions[2].nd = 32'hFFFFFFFF;
	pma_regions[2].art	 = 32'h00000000;
	pma_regions[2].at = 16'hFF00;		// no access

	// DRAM
	pma_regions[1].start = 32'h00000000;
	pma_regions[1].nd = 32'h1FFFFFFF;
	pma_regions[1].art	 = 32'h00002400;
	pma_regions[1].at = 16'h010F;	// ram, byte addressable, cache-read-write-execute

	// vacant
	pma_regions[0].start = 32'hFFFFFFFF;
	pma_regions[0].nd = 32'hFFFFFFFF;
	pma_regions[0].art	 = 32'h00000000;
	pma_regions[0].at = 16'hFF00;		// no access

end

always_comb
begin
	err = 1'b1;
	region_num = 4'd0;
	region = pma_regions[0];
  for (n = 0; n < 8; n = n + 1)
    if (adr[31:4] >= pma_regions[n].start[31:4] && adr[31:4] <= pma_regions[n].nd[31:4]) begin
    	region = pma_regions[n];
    	region_num = n;
    	err = 1'b0;
  	end
end    	
    	
endmodule

