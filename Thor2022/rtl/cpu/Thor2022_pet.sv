`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	- precision event timers
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
//
//	Reg	Description
//	000	comparator #0
//  008 control #0
//	010	comparator #1
//	018 control #1
//	020 ...
//	1F0 comparator #31
//	1F8 control #31
//	200	master counter
//	208	master control
//	210 match status
//	218 out status / acknowledge
//	220 capabilities register
//
// Comparators
//	If the comparator value matches the counter value then the match status is
//	set to true. The match status must be cleared by writing the match status
//  register with a one in the bit position of the match status to clear.
//  If outputs (interrupts) are enabled they will be generated when the
//  comparator matches the counter value.
//
// Control Register bits
//	0 to 31		output route
//	32				output type 0 = level, 1 = pulse
//	34				periodic = 1, non-periodic = 0
//	The following bit is used only for periodic timers, it is otherwise
// 	ignored. Setting the bit to 0 allows direct access to the compare
//  register. This bit will automatically set back to 1 after the compare
//  register has been updated.
//	35				0 = access compare reg, 1 = access addend
//	40				output status (read only)
//	48				interrupt enable 1=enabled, 0=disabled
// Byte lane selects on the control register are honored.
//	Output routing will cause the outputs specified to be affected by the
//  timer. Multiple outputs may be affected by a single timing event. Usually
//  the outputs will be connected to interrupt request lines, but they do not
//  need to be.
//
// Master Counter
//	The counter should be stopped before writing the register. Writing the
//	register while the counter is running will be ignored.
// 	Reading this register returns the current count.
//
// Master Control
//	0				1 = counter enabled, 0 = disabled
//	1				1 = interrupts enabled, 0 = disabled
//
// Match Status
//	The match status register indicates which comparators have matched the
//  master count register since the last read of the match status register.
//	The match status may be set to zero by writing a one bit to the position
//  in the register corresponding to the timer.
//
// Output Status
//	The output status register reflects the status of the PET outputs.
//	Writing to this register with a one bit set sets the output to zero for
//  the timer corresponding to the position of the one bit. Writing zeros
//  does not affect the output status.
//
// Capabilities Register
//	0 to 7		core revision number
//	8 to 12		number of timers supported - 1
//	13				64-bit counter (0)
//	14				no legacy support (0)
//	15				reserved
//	16 to 27	vendor ID (0)
//	28 to 31	counter size in bytes - 1
//	32 to 63	time basis in femtoseconds
// ============================================================================
//
module Thor2022_pet(rst_i, clk_i, cs_i, cyc_i, stb_i, ack_o, sel_i, we_i, adr_i, dat_i, dat_o,
	cclk_i, out, irq
);
parameter NTIMER=8;
parameter BITS=48;
input rst_i;
input clk_i;
input cs_i;
input cyc_i;
input stb_i;
output ack_o;
input [7:0] sel_i;
input we_i;
input [9:0] adr_i;
input [63:0] dat_i;
output reg [63:0] dat_o;
input cclk_i;
output reg [31:0] out;
output irq;

integer n;
reg [63:0] cap_reg;
reg [63:0] config_reg;
reg [BITS-1:0] counter;
reg [63:0] master_control;
reg [63:0] control [0:NTIMER-1];
reg [BITS-1:0] addend [0:NTIMER-1];
reg [BITS-1:0] compare [0:NTIMER-1];
reg [31:0] out_route [0:NTIMER-1];
reg [NTIMER-1:0] ie;
reg [NTIMER-1:0] ms;	// match status
reg [NTIMER-1:0] es;	// edge (1) or level (0) sensitive
reg [3:0] outpulse [0:NTIMER-1];

wire cs = cyc_i & stb_i & cs_i;
reg rdy;
always_ff @(posedge clk_i)
	rdy <= cs;
assign ack_o = cs ? (we_i ? 1'b1 : rdy) : 1'b0;

initial begin
	master_control = 'd0;
	// 20 MHz time base
	// 48 bit counter (6 bytes)
	// 000 vendor ID
	// no legacy routing
	// 64-bit counter
	// 8 timers
	// revision 01
	cap_reg = 64'h02FAF08050002701;
	for (n = 0; n < NTIMER; n = n + 1) begin
		es[n] = 2'b00;
		control[n] = 64'd0;
		compare[n] = 64'hFFFFFFFFFFFFFFFF;
		out_route[n] = 32'd0;
	end
	ie = 'd0;
	ms = 'd0;
end

reg upd_counter;
reg upd_done;
reg [BITS-1:0] upd_value;
always_ff @(posedge cclk_i)
if (rst_i) begin
	upd_done <= 1'b0;
	counter <= 'd0;
end
else begin
	if (upd_counter=='d0)
		upd_done <= 1'b0;
	if (master_control[0])
		counter <= counter + 2'd1;
	else begin
		if (upd_counter) begin
			upd_done <= 1'b1;
			counter <= upd_value;
		end
	end
end

integer n1;
always_ff @(posedge clk_i)
if (rst_i) begin
	upd_counter <= 1'b0;
	out <= 1'b0;
	// Counter disabled
	master_control <= 'd0;
	for (n1 = 0; n1 < NTIMER; n1 = n1 + 1) begin
		control[n1] <= 64'd0;
		outpulse[n1] <= 4'd8;
		compare[n1] = 64'hFFFFFFFFFFFFFFFF;
		out_route[n1] <= 64'd0;
		es[n1] <= 1'b0;
	end
	ie <= 'd0;
	ms <= 'd0;
end
else begin
	if (upd_done)
		upd_counter <= 1'b0;
	for (n1 = 0; n1 < NTIMER; n1 = n1 + 1)
		if (outpulse[n1][3] & es[n1]==1'b1)
			out[n1] <= 'd0;
		else
			outpulse[n1] <= outpulse[n1] + 2'd1;

	if (cs && we_i) begin
		casez(adr_i[9:3])
		7'b0?????0:
			if (control[adr_i[8:4]][34] & control[adr_i[8:4]][35])
				addend[adr_i[8:4]] <= dat_i;
			else begin
				compare[adr_i[8:4]] <= dat_i;
				control[adr_i[8:4]][35] <= 1'b1;
			end
		7'b0?????1:
			begin
				if (sel_i[0])	begin out_route[adr_i[8:4]][7:0] <= dat_i[7:0]; control[adr_i[8:4]][7:0] <= dat_i[7:0]; end
				if (sel_i[1])	begin out_route[adr_i[8:4]][15:8] <= dat_i[15:8]; control[adr_i[8:4]][15:8] <= dat_i[15:8]; end
				if (sel_i[2])	begin out_route[adr_i[8:4]][23:16] <= dat_i[23:16]; control[adr_i[8:4]][23:16] <= dat_i[23:16]; end
				if (sel_i[3])	begin out_route[adr_i[8:4]][31:24] <= dat_i[31:24]; control[adr_i[8:4]][31:24] <= dat_i[31:24]; end
				if (sel_i[4]) begin es[adr_i[8:4]] <= dat_i[32]; control[adr_i[8:4]][39:32] <= dat_i[39:32]; end
				if (sel_i[5]) begin control[adr_i[8:4]][47:40] <= dat_i[47:40]; end
				if (sel_i[6]) begin ie[adr_i[8:4]] <= dat_i[48]; control[adr_i[8:4]][55:48] <= dat_i[55:48]; end
				if (sel_i[7]) begin control[adr_i[8:4]][63:56] <= dat_i[63:56]; end
			end
		7'b1000000:
			begin
				upd_counter <= 1'b1;
				upd_value <= dat_i;
			end
		7'b1000001:	master_control <= dat_i;
		7'b1000010:	ms <= ms & ~dat_i;
		7'b1000011:	out <= out & ~dat_i;
		7'b1000100:	;
		default:	;
		endcase
	end
	if (cs && ~we_i) begin
		casez(adr_i[9:3])
		7'b0?????0:	dat_o <= compare[adr_i[8:4]];
		7'b0?????1:	dat_o <= control[adr_i[8:4]]|{ms[adr_i[8:4]],40'd0};
		7'b1000000:	dat_o <= counter;
		7'b1000001:	dat_o <= master_control;
		7'b1000010:	dat_o <= ms;
		7'b1000011:	dat_o <= out;
		7'b1000100:	dat_o <= cap_reg;
		default:		dat_o <= 'd0;
		endcase
	end
	else
		dat_o <= 'd0;
		
	for (n1 = 0; n1 < NTIMER; n1 = n1 + 1) begin
		if (compare[n1]==counter && ~ms[n1]) begin
			ms[n1] <= 1'b1;
			if (ie[n1] & master_control[1]) begin
				case(es[n1])
				1'b0:	out <= out | out_route[n1];		// set level
				1'b1:	out <= out | out_route[n1];		// pulse
				endcase
				outpulse[n1] <= 4'd0;
			end
			if (control[n1][34])
				compare[n1] <= compare[n1] + addend[n1];
		end
	end
end

assign irq = |out;

endmodule
