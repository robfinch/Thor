// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_regfile.sv
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
// 4800 LUTs                                                                          
// ============================================================================

import Thor2023Pkg::*;

module Thor2023_regfile(clk, regset, wg, gwa, gi, wr, wa, i, gra, go, ra0, ra1, ra2, ra3,
	o0, o1, o2, o3, asp, ssp, hsp, msp, lc, sc, om);
input clk;
input regset;
input [7:0] wg;
input [3:0] gwa;
input octa_value_t gi;
input wr;
input [6:0] wa;
input double_value_t i;
input [2:0] gra;
output octa_value_t go;
input [6:0] ra0;
input [6:0] ra1;
input [6:0] ra2;
input [6:0] ra3;
output double_value_t o0;
output double_value_t o1;
output double_value_t o2;
output double_value_t o3;
input double_value_t asp;
input double_value_t ssp;
input double_value_t hsp;
input double_value_t msp;
input double_value_t lc;
output double_value_t sc;
input [1:0] om;

parameter LCREG = 6'd55;
parameter SCREG = 6'd53;
parameter PCREG = 6'd53;
parameter SPREG = 6'd63;

(* ram_style="distributed" *)
value_t c0_regs [0:31];
(* ram_style="distributed" *)
value_t c1_regs [0:31];
(* ram_style="distributed" *)
value_t c2_regs [0:31];
(* ram_style="distributed" *)
value_t c3_regs [0:31];
(* ram_style="distributed" *)
value_t c4_regs [0:31];
(* ram_style="distributed" *)
value_t c5_regs [0:31];
(* ram_style="distributed" *)
value_t c6_regs [0:31];
(* ram_style="distributed" *)
value_t c7_regs [0:31];

(* ram_style="distributed" *)
value_t c0h_regs [0:31];
(* ram_style="distributed" *)
value_t c1h_regs [0:31];
(* ram_style="distributed" *)
value_t c2h_regs [0:31];
(* ram_style="distributed" *)
value_t c3h_regs [0:31];
(* ram_style="distributed" *)
value_t c4h_regs [0:31];
(* ram_style="distributed" *)
value_t c5h_regs [0:31];
(* ram_style="distributed" *)
value_t c6h_regs [0:31];
(* ram_style="distributed" *)
value_t c7h_regs [0:31];

reg [4:0] gwa1;
integer nn;

initial begin
	for (nn = 0; nn < 32; nn = nn + 1) begin
		c0_regs[nn] = 'd0;
		c1_regs[nn] = 'd0;
		c2_regs[nn] = 'd0;
		c3_regs[nn] = 'd0;
		c4_regs[nn] = 'd0;
		c5_regs[nn] = 'd0;
		c6_regs[nn] = 'd0;
		c7_regs[nn] = 'd0;
		c0h_regs[nn] = 'd0;
		c1h_regs[nn] = 'd0;
		c2h_regs[nn] = 'd0;
		c3h_regs[nn] = 'd0;
		c4h_regs[nn] = 'd0;
		c5h_regs[nn] = 'd0;
		c6h_regs[nn] = 'd0;
		c7h_regs[nn] = 'd0;
	end
end

always_comb
	if (wg)
		gwa1 <= {regset,gwa};
	else if (wr) 
		gwa1 <= {regset,wa[6:3]};
	else
		gwa1 <= 7'd7;

always_ff @(posedge clk)
begin
	if (wg[0]) c0_regs[gwa1] <= gi[$bits(value_t)*1-1:  0];
	if (wg[1]) c1_regs[gwa1] <= gi[$bits(value_t)*2-1:$bits(value_t)*1];
	if (wg[2]) c2_regs[gwa1] <= gi[$bits(value_t)*3-1:$bits(value_t)*2];
	if (wg[3]) c3_regs[gwa1] <= gi[$bits(value_t)*4-1:$bits(value_t)*3];
	if (wg[4]) c4_regs[gwa1] <= gi[$bits(value_t)*5-1:$bits(value_t)*4];
	if (wg[5]) c5_regs[gwa1] <= gi[$bits(value_t)*6-1:$bits(value_t)*5];
	if (wg[6]) c6_regs[gwa1] <= gi[$bits(value_t)*7-1:$bits(value_t)*6];
	if (wg[7]) c7_regs[gwa1] <= gi[$bits(value_t)*8-1:$bits(value_t)*7];

	if (wr) begin
		$display("reg %d (%d) write %x", wa, {gwa1,wa[2:0]}, i);
		case(wa[2:0])
		3'd0:	{c0h_regs[gwa1],c0_regs[gwa1]} <= i;
		3'd1:	{c1h_regs[gwa1],c1_regs[gwa1]} <= i;
		3'd2:	{c2h_regs[gwa1],c2_regs[gwa1]} <= i;
		3'd3:	{c3h_regs[gwa1],c3_regs[gwa1]} <= i;
		3'd4:	{c4h_regs[gwa1],c4_regs[gwa1]} <= i;
		3'd5:	{c5h_regs[gwa1],c5_regs[gwa1]} <= i;
		3'd6:	{c6h_regs[gwa1],c6_regs[gwa1]} <= i;
		3'd7:	{c7h_regs[gwa1],c7_regs[gwa1]} <= i;
		default:	;
		endcase
	end
		
	if (wr && wa==SCREG)
		sc <= i;
end

reg [4:0] gra1;
always_comb
	gra1 = {regset,gra};
always_comb
	go <= {c7_regs[gra1],c6_regs[gra1],c5_regs[gra1],c4_regs[gra1],
				c3_regs[gra1],c2_regs[gra1],c1_regs[gra1],c0_regs[gra1]};

always_comb
begin
	tGetReg({regset,ra0},o0);
	tGetReg({regset,ra1},o1);
	tGetReg({regset,ra2},o2);
	tGetReg({regset,ra3},o3);
end

task tGetReg;
input [7:0] ra;
output value_t o;
begin
	case(ra[5:0])
	6'd0:		o <= 'd0;
	wa:			o <= i;
	LCREG:	o <= lc;
	SPREG:
		case(om)
		2'd0:	o <= asp;
		2'd1:	o <= ssp;
		2'd2:	o <= hsp;
		2'd3:	o <= msp;
		endcase
	default:
		case(ra[2:0])
		3'd0:	o <= {c0h_regs[ra[7:3]],c0_regs[ra[7:3]]};
		3'd1:	o <= {c1h_regs[ra[7:3]],c1_regs[ra[7:3]]};
		3'd2:	o <= {c2h_regs[ra[7:3]],c2_regs[ra[7:3]]};
		3'd3:	o <= {c3h_regs[ra[7:3]],c3_regs[ra[7:3]]};
		3'd4:	o <= {c4h_regs[ra[7:3]],c4_regs[ra[7:3]]};
		3'd5:	o <= {c5h_regs[ra[7:3]],c5_regs[ra[7:3]]};
		3'd6:	o <= {c6h_regs[ra[7:3]],c6_regs[ra[7:3]]};
		3'd7:	o <= {c7h_regs[ra[7:3]],c7_regs[ra[7:3]]};
		default:	;
		endcase
	endcase
end
endtask

endmodule
