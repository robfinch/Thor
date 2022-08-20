// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_livetarget.sv
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

import const_pkg::*;
import Thor2022_pkg::*;

module Thor2022_livetarget(reb, stomp, missid, livetarget, livetarget2, latestID, latestID2);
input sReorderEntry [7:0] reb;
input [7:0] stomp;
input [2:0] missid;
output reg [NREGS-1:0] livetarget;
output reg [NREGS-1:0] livetarget2;
output reg [NREGS-1:0] latestID [0:7];
output reg [NREGS-1:0] latestID2 [0:7];

reg [NREGS-1:0] reb_out [0:REB_ENTRIES-1];
reg [NREGS-1:0] reb_out2 [0:REB_ENTRIES-1];
reg [NREGS-1:0] reb_livetarget [0:7];
reg [NREGS-1:0] reb_livetarget2 [0:7];
reg [NREGS-1:0] reb_cumulative [0:7];
reg [NREGS-1:0] reb_cumulative2 [0:7];

integer n1,n2;
always_comb
for (n1 = 0; n1 < REB_ENTRIES; n1 = n1 + 1)
	reb_out[n1] <= (64'h1 << reb[n1].dec.Rt) & {{NREGS-1{1'b1}},1'b0};
always_comb
for (n2 = 0; n2 < REB_ENTRIES; n2 = n2 + 1)
	reb_out2[n2] <= (64'h1 << reb[n2].dec.Rt2) & {{NREGS-1{1'b1}},1'b0};

integer n31;
always_comb
	for (n31 = 0; n31 < REB_ENTRIES; n31 = n31 + 1) begin
		reb_livetarget[n31] = {NREGS{reb[n31].v}} & {NREGS{~stomp[n31]}} & reb_out[n31];// & {32{~reb[n31].out}};
		reb_livetarget2[n31] = {NREGS{reb[n31].v}} & {NREGS{~stomp[n31]}} & reb_out2[n31];// & {16{~reb[n31].out}};
	end
integer n32,j32;
always_comb
for (j32 = 1; j32 < NREGS; j32 = j32 + 1) begin
	livetarget[j32] = 1'b0;
	for (n32 = 0; n32 < REB_ENTRIES; n32 = n32 + 1)
		livetarget[j32] = livetarget[j32] | reb_livetarget[n32][j32];
end
integer n33,j33;
always_comb
for (j33 = 1; j33 < NREGS; j33 = j33 + 1) begin
	livetarget2[j33] = 1'b0;
	for (n33 = 0; n33 < REB_ENTRIES; n33 = n33 + 1)
		livetarget2[j33] = livetarget2[j33] | reb_livetarget2[n33][j33];
end

integer n34,j34,k34;
always_comb
	for (n34 = 0; n34 < REB_ENTRIES; n34 = n34 + 1) begin
		reb_cumulative[n34] = 1'b0;
		for (k34 = 0; k34 <= REB_ENTRIES; k34 = k34 + 1)
			if (reb[k34].sns <= reb[missid].sns && reb[k34].sns >= reb[n34].sns)
				reb_cumulative[n34] = reb_cumulative[n34] | reb_livetarget[k34];
	end
integer n35,j35,k35;
always_comb
	for (n35 = 0; n35 < REB_ENTRIES; n35 = n35 + 1) begin
		reb_cumulative2[n35] = 'd0;
		for (k35 = 0; k35 < REB_ENTRIES; k35 = k35 + 1)
			if (reb[k35].sns <= reb[missid].sns && reb[k35].sns >= reb[n35].sns)
				reb_cumulative2[n35] = reb_cumulative2[n35] | reb_livetarget2[k35];
	end

integer n36;
always_comb
	for (n36 = 0; n36 < REB_ENTRIES; n36 = n36 + 1)
    latestID[n36] = (missid == n36 || ((reb_livetarget[n36] & reb_cumulative[(n36+1)%REB_ENTRIES]) == {NREGS{1'b0}}))
				    ? reb_livetarget[n36]
				    : {NREGS{1'b0}};
integer n37;
always_comb
	for (n37 = 0; n37 < REB_ENTRIES; n37 = n37 + 1)
    latestID2[n37] = (missid == n37 || ((reb_livetarget2[n37] & reb_cumulative2[(n37+1)%REB_ENTRIES]) == {NREGS{1'b0}}))
				    ? reb_livetarget2[n37]
				    : {NREGS{1'b0}};

endmodule
