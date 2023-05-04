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
// ============================================================================

module Thor2023_regfile(clk, wg, gwa, gi, wr, wa, i, gra, go, ra0, ra1, ra2, ra3,
	o0, o1, o2, o3, asp, ssp, hsp, msp, pc, om);
input clk;
input wg;
input [3:0] gwa;
input [511:0] gi;
input wr;
input [5:0] wa;
input [95:0] i;
input [3:0] gra;
output reg [511:0] go;
input [5:0] ra0;
input [5:0] ra1;
input [5:0] ra2;
input [5:0] ra3;
output reg [95:0] o0;
output reg [95:0] o1;
output reg [95:0] o2;
output reg [95:0] o3;
input [95:0] asp;
input [95:0] ssp;
input [95:0] hsp;
input [95:0] msp;
input [95:0] pc;
input [1:0] om;

parameter PCREG = 6'd53;
parameter SPREG = 6'd63;

typedef struct packed
{
	logic [2:0] column;
	logic [3:0] group;
} regadr_t;

regadr_t [63:0] rga;
initial begin
	rga[0] = { 3'd0, 4'd0};
	rga[1] = { 3'd1, 4'd0};
	rga[2] = { 3'd2, 4'd0};
	rga[3] = { 3'd3, 4'd0};
	rga[4] = { 3'd4, 4'd0};
	rga[5] = { 3'd0, 4'd1};
	rga[6] = { 3'd1, 4'd1};
	rga[7] = { 3'd2, 4'd1};
	rga[8] = { 3'd3, 4'd1};
	rga[9] = { 3'd4, 4'd1};
	rga[10] = { 3'd0, 4'd2};
	rga[11] = { 3'd1, 4'd2};
	rga[12] = { 3'd2, 4'd2};
	rga[13] = { 3'd3, 4'd2};
	rga[14] = { 3'd4, 4'd2};
	rga[15] = { 3'd0, 4'd3};
	rga[16] = { 3'd1, 4'd3};
	rga[17] = { 3'd2, 4'd3};
	rga[18] = { 3'd3, 4'd3};
	rga[19] = { 3'd4, 4'd3};
	rga[20] = { 3'd0, 4'd4};
	rga[21] = { 3'd1, 4'd4};
	rga[22] = { 3'd2, 4'd4};
	rga[23] = { 3'd3, 4'd4};
	rga[24] = { 3'd4, 4'd4};
	rga[25] = { 3'd0, 4'd5};
	rga[26] = { 3'd1, 4'd5};
	rga[27] = { 3'd2, 4'd5};
	rga[28] = { 3'd3, 4'd5};
	rga[29] = { 3'd4, 4'd5};
	rga[30] = { 3'd0, 4'd6};
	rga[31] = { 3'd1, 4'd6};
	rga[32] = { 3'd2, 4'd6};
	rga[33] = { 3'd3, 4'd6};
	rga[34] = { 3'd4, 4'd6};
	rga[35] = { 3'd0, 4'd7};
	rga[36] = { 3'd1, 4'd7};
	rga[37] = { 3'd2, 4'd7};
	rga[38] = { 3'd3, 4'd7};
	rga[39] = { 3'd4, 4'd7};
	rga[40] = { 3'd0, 4'd8};
	rga[41] = { 3'd1, 4'd8};
	rga[42] = { 3'd2, 4'd8};
	rga[43] = { 3'd3, 4'd8};
	rga[44] = { 3'd4, 4'd8};
	rga[45] = { 3'd0, 4'd9};
	rga[46] = { 3'd1, 4'd9};
	rga[47] = { 3'd2, 4'd9};
	rga[48] = { 3'd3, 4'd9};
	rga[49] = { 3'd4, 4'd9};
	rga[50] = { 3'd0, 4'd10};
	rga[51] = { 3'd1, 4'd10};
	rga[52] = { 3'd2, 4'd10};
	rga[53] = { 3'd3, 4'd10};
	rga[54] = { 3'd4, 4'd10};
	rga[55] = { 3'd0, 4'd11};
	rga[56] = { 3'd1, 4'd11};
	rga[57] = { 3'd2, 4'd11};
	rga[58] = { 3'd3, 4'd11};
	rga[59] = { 3'd4, 4'd11};
	rga[60] = { 3'd0, 4'd12};
	rga[61] = { 3'd1, 4'd12};
	rga[62] = { 3'd2, 4'd12};
	rga[63] = { 3'd3, 4'd12};
end

(* ram_style="distributed" *)
reg [95:0] c0_regs [0:15];
(* ram_style="distributed" *)
reg [95:0] c1_regs [0:15];
(* ram_style="distributed" *)
reg [95:0] c2_regs [0:15];
(* ram_style="distributed" *)
reg [95:0] c3_regs [0:15];
(* ram_style="distributed" *)
reg [95:0] c4_regs [0:15];

reg [3:0] gwa1;

always_comb
	if (wg)
		gwa1 <= gwa;
	else if (wr) 
		gwa1 <= rga[wa].group;
	else
		gwa1 <= 4'd15;

always_ff @(posedge clk)
begin
	if (wg)	begin
		c0_regs[gwa1] <= gi[ 95:  0];
		c1_regs[gwa1] <= gi[191: 96];
		c2_regs[gwa1] <= gi[287:192];
		c3_regs[gwa1] <= gi[383:288];
		c4_regs[gwa1] <= gi[479:384];
	end	

	if (wr) 
		case(rga[wa].column)
		3'd0:	c0_regs[gwa1] <= i;
		3'd1:	c1_regs[gwa1] <= i;
		3'd2:	c2_regs[gwa1] <= i;
		3'd3:	c3_regs[gwa1] <= i;
		3'd4:	c4_regs[gwa1] <= i;
		default:	;
		endcase
end

always_comb
	go <= {32'h0,c4_regs[gra],c3_regs[gra],c2_regs[gra],c1_regs[gra],c0_regs[gra]};

always_comb
begin
	tGetReg(ra0,o0);
	tGetReg(ra1,o1);
	tGetReg(ra2,o2);
	tGetReg(ra3,o3);
end

task tGetReg;
input [5:0] ra;
output [95:0] o;
begin
	case(ra)
	6'd0:		o <= 'd0;
	PCREG: 	o <= pc;
	wa:			o <= i;
	SPREG:
		case(om)
		2'd0:	o <= asp;
		2'd1:	o <= ssp;
		2'd2:	o <= hsp;
		2'd3:	o <= msp;
		endcase
	default:
		case(rga[ra].column)
		3'd0:	o <= c0_regs[rga[ra].group];
		3'd1:	o <= c1_regs[rga[ra].group];
		3'd2:	o <= c2_regs[rga[ra].group];
		3'd3:	o <= c3_regs[rga[ra].group];
		3'd4:	o <= c4_regs[rga[ra].group];
		default:	;
		endcase
	endcase
end
endtask

endmodule
