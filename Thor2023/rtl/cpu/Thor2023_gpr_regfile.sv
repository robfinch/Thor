// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_gpr_regfile.sv
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

module Thor2023_gpr_regfile(clk, regset, rg, wg, gwa, gi, rd, wr, wa, i, gra, go, ra0, ra1, ra2, ra3,
	o0, o1, o2, o3, asp, ssp, hsp, msp, sc, om);
parameter SCREG = 53;
input clk;
input [4:0] regset;
input rg;
input wg;
input [2:0] gwa;
input [511:0] gi;
input rd;
input wr;
input [5:0] wa;
input value_t i;
input [3:0] gra;
output reg [511:0] go;
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


wire clka = clk;
wire clkb = clk;
wire [511:0] doutb [0:3];
reg [8:0] addra;
reg [8:0] addrb [0:3];
reg [511:0] dina;
reg [63:0] wea;

always_comb
	casez({wg,wa})
	7'b1??????:	wea = {64{1'b1}};
	7'b0??????:	wea = {63'h0,{8{wr}}} << {wa[2:0],3'b0};
	endcase
always_comb
	dina = gwa ? gi : {8{i}};
always_comb
begin
	if (rg)
		addrb[0] = {regset,gra};
	else
		addrb[0] = {regset,ra0[5:3]};
	addrb[1] = {regset,ra1[5:3]};
	addrb[2] = {regset,ra2[5:3]};
	addrb[3] = {regset,ra3[5:3]};
end
always_comb
	if (wr)
		addra = {regset,wa[5:3]};
	else
		addra = {regset,gwa};
genvar g;

generate begin : gRegfile
	for (g = 0; g < 4; g = g + 1) begin : xpm_mem
   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(8),               // DECIMAL
      .ADDR_WIDTH_B(8),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),        	// DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("block"),
      .MEMORY_SIZE(131072),
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B(512),
      .READ_LATENCY_B(1),
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),
      .RST_MODE_B("SYNC"),
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(512),
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst (
      .dbiterrb(),
      .doutb(doutb[g]),
      .sbiterrb(),
      .addra(addra),
      .addrb(addrb[g]),
      .clka(clka),
      .clkb(clkb),
      .dina(dina),
      .ena(wr|wg),
      .enb(rd|rg),
      .injectdbiterra(1'b0),
      .injectsbiterra(1'b0),
      .regceb(1'b1),
      .rstb(1'b0),
      .sleep(1'b0),
      .wea(wea)
   );
   // End of xpm_memory_sdpram_inst instantiation
  end
end
endgenerate


always_ff @(posedge clk)
begin
	if (wr && wa==SCREG)
		sc <= i;
end

always_comb
	go <= doutb[0];

always_comb
begin
	tGetReg(ra0,doutb[0],o0);
	tGetReg(ra1,doutb[1],o1);
	tGetReg(ra2,doutb[2],o2);
	tGetReg(ra3,doutb[3],o3);
end

task tGetReg;
input [5:0] ra;
input [511:0] doutb;
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
		o <= doutb >> {ra[2:0],6'h0};
	endcase
end
endtask

endmodule
