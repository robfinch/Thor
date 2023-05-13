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

module Thor2023_regfile(rst, clk, regset, wg, gwa, gi, wr, wa, i, gra, go, ra0, ra1, ra2, ra3,
	o0, o1, o2, o3, asp, ssp, hsp, msp, lc, sc, om);
input rst;
input clk;
input regset;
input [3:0] wg;
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

wire rsta = rst;
wire rstb = rst;
wire clka = clk;
wire clkb = clk;
double_value_t dina;
double_value_t doutb[3:0];
reg wea;
wire regcea = 1'b1;
wire regceb = 1'b1;
wire enb = 1'b1;
wire ena = 1'b1;
reg [5:0] addra;
reg [5:0] addrb [3:0];


   // xpm_memory_dpdistram: Dual Port Distributed RAM
   // Xilinx Parameterized Macro, version 2022.2
genvar element, port;

generate begin
	for (port = 0; port < 4; port = port + 1) begin

   xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(6),               // DECIMAL
      .ADDR_WIDTH_B(6),               // DECIMAL
      .BYTE_WRITE_WIDTH_A(128),        // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_SIZE(8192),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A(128),         // DECIMAL
      .READ_DATA_WIDTH_B(128),         // DECIMAL
      .READ_LATENCY_A(0),             // DECIMAL
      .READ_LATENCY_B(0),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WRITE_DATA_WIDTH_A(128)         // DECIMAL
   )
   xpm_memory_dpdistram_inst0 (
      .douta(),   			// READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(doutb[port]),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(addra),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(addrb[port]),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clka),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(clkb),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(dina),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(ena),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(enb),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(regcea), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(regceb), // 1-bit input: Do not change from the provided value.
      .rsta(rsta),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(rstb),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(wea)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );
end
end
endgenerate
				
reg [4:0] gwa1;
integer nn;

always_comb
	if (wg)
		gwa1 <= gwa;
	else if (wr) 
		gwa1 <= wa[6:2];
	else
		gwa1 <= 5'd31;

always_comb
begin
	dina = i;
	/*
	dina[0] = wg[0] ? gi[$bits(double_value_t)*1-1:  0] : i;
	dina[1] = wg[1] ? gi[$bits(double_value_t)*2-1:$bits(double_value_t)*1] : i;
	dina[2] = wg[2] ? gi[$bits(double_value_t)*3-1:$bits(double_value_t)*2] : i;
	dina[3] = wg[2] ? gi[$bits(double_value_t)*4-1:$bits(double_value_t)*3] : i;
	*/
end

always_comb
begin
	wea = wr;
	/*
	wea[0] = wg[0] || (wr && wa[1:0]==2'b00);
	wea[1] = wg[1] || (wr && wa[1:0]==2'b01);
	wea[2] = wg[2] || (wr && wa[1:0]==2'b10);
	wea[3] = wg[3] || (wr && wa[1:0]==2'b11);
	*/
end

always_comb
begin
	addra = wa;
	addrb[0] = ra0;
	addrb[1] = ra1;
	addrb[2] = ra2;
	addrb[3] = ra3;
end

always_ff @(posedge clk, posedge rst)
if (rst)
	sc <= 'd0;
else begin

	if (wr)
		$display("reg %d (%d) write %x", wa, {gwa1,wa[1:0]}, i);
		
	if (wr && wa==SCREG)
		sc <= i;
end

reg [4:0] gra1;
always_comb
	gra1 = {regset,gra};
always_comb
	go <= 'd0;//{c3_regs[gra1],c2_regs[gra1],c1_regs[gra1],c0_regs[gra1]};


always_comb
	case(ra0[5:0])
	6'd0:		o0 = 'd0;
	wa:			o0 = i;
	LCREG:	o0 = lc;
	SPREG:
		case(om)
		2'd0:	o0 = asp;
		2'd1:	o0 = ssp;
		2'd2:	o0 = hsp;
		2'd3:	o0 = msp;
		endcase
	default:
		o0 = doutb[2'd0];
	endcase
	
always_comb
	case(ra1[5:0])
	6'd0:		o1 = 'd0;
	wa:			o1 = i;
	LCREG:	o1 = lc;
	SPREG:
		case(om)
		2'd0:	o1 = asp;
		2'd1:	o1 = ssp;
		2'd2:	o1 = hsp;
		2'd3:	o1 = msp;
		endcase
	default:
		o1 = doutb[2'd1];
	endcase
	
always_comb
	case(ra2[5:0])
	6'd0:		o2 = 'd0;
	wa:			o2 = i;
	LCREG:	o2 = lc;
	SPREG:
		case(om)
		2'd0:	o2 = asp;
		2'd1:	o2 = ssp;
		2'd2:	o2 = hsp;
		2'd3:	o2 = msp;
		endcase
	default:
		o2 = doutb[2'd2];
	endcase
	
always_comb
	case(ra3[5:0])
	6'd0:		o3 = 'd0;
	wa:			o3 = i;
	LCREG:	o3 = lc;
	SPREG:
		case(om)
		2'd0:	o3 = asp;
		2'd1:	o3 = ssp;
		2'd2:	o3 = hsp;
		2'd3:	o3 = msp;
		endcase
	default:
		o3 = doutb[2'd3];
	endcase

endmodule
