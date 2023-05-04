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

module Thor2023_regfile(clk, wg, gwa, gi, wr, wa, i, gra, go, ra0, ra1, ra2, ra3,
	o0, o1, o2, o3, asp, ssp, hsp, msp, sc, om);
parameter SCREG = 53;
input clk;
input wg;
input [3:0] gwa;
input quad_value_t gi;
input wr;
input [5:0] wa;
input value_t i;
input [3:0] gra;
output quad_value_t go;
input [5:0] ra0;
input [5:0] ra1;
input [5:0] ra2;
input [5:0] ra3;
output value_t o0;
output value_t o1;
output value_t o2;
output value_t o3;
input value_t asp;
input value_t ssp;
input value_t hsp;
input value_t msp;
output value_t sc;
input [1:0] om;

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

reg [4:0] gwa1;
integer nn;

initial begin
	for (nn = 0; nn < 32; nn = nn + 1) begin
		c0_regs[nn] = 'd0;
		c1_regs[nn] = 'd0;
		c2_regs[nn] = 'd0;
		c3_regs[nn] = 'd0;
	end
end

always_comb
	if (wg)
		gwa1 <= {1'b0,gwa};
	else if (wr) 
		gwa1 <= {1'b0,wa[5:2]};
	else
		gwa1 <= 5'd15;

always_ff @(posedge clk)
begin
	if (wg)	begin
		c0_regs[gwa1] <= gi[$bits(value_t)*1-1:  0];
		c1_regs[gwa1] <= gi[$bits(value_t)*2-1:$bits(value_t)*1];
		c2_regs[gwa1] <= gi[$bits(value_t)*3-1:$bits(value_t)*2];
		c3_regs[gwa1] <= gi[$bits(value_t)*4-1:$bits(value_t)*3];
	end	

	if (wr) 
		case(wa[1:0])
		2'd0:	c0_regs[gwa1] <= i;
		2'd1:	c1_regs[gwa1] <= i;
		2'd2:	c2_regs[gwa1] <= i;
		2'd3:	c3_regs[gwa1] <= i;
		default:	;
		endcase
		
	if (wr && wa==SCREG)
		sc <= i;
end

always_comb
	go <= {c3_regs[gra],c2_regs[gra],c1_regs[gra],c0_regs[gra]};

always_comb
begin
	tGetReg({1'b0,ra0},o0);
	tGetReg({1'b0,ra1},o1);
	tGetReg({1'b0,ra2},o2);
	tGetReg({1'b0,ra3},o3);
end

task tGetReg;
input [6:0] ra;
output value_t o;
begin
	case(ra[5:0])
	6'd0:		o <= 'd0;
	wa:			o <= i;
	SPREG:
		case(om)
		2'd0:	o <= asp;
		2'd1:	o <= ssp;
		2'd2:	o <= hsp;
		2'd3:	o <= msp;
		endcase
	default:
		case(ra[1:0])
		3'd0:	o <= c0_regs[ra[6:2]];
		3'd1:	o <= c1_regs[ra[6:2]];
		3'd2:	o <= c2_regs[ra[6:2]];
		3'd3:	o <= c3_regs[ra[6:2]];
		default:	;
		endcase
	endcase
end
endtask

endmodule
