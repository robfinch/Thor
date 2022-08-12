`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	- programmable interval timer
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
//	00	current count   (read only)
//	04	max count	    (read-write)
//  08  on time			(read-write)
//	0C	control
//		byte 0 for counter 0, byte 1 for counter 1, byte 2 for counter 2
//		bit in byte
//		0 = 1 = load, automatically clears
//	    1 = 1 = enable counting, 0 = disable counting
//		2 = 1 = auto-reload on terminal count, 0 = no reload
//		3 = 1 = use external clock, 0 = internal clk_i
//      4 = 1 = use gate to enable count, 0 = ignore gate
//	10	current count 1
//	14  max count 1
//	18  on time 1
//	20	current count 2
//	24	max count 2
//	28	on time 2
//	30	current count 3
//	34	max count 3
//	38	on time 3
//	...
//	200	underflow status
//  204 synchronization register
//  208 interrupt enable
//	20C temporary register
//
//	- all counter controls can be written at the same time with a
//    single instruction allowing synchronization of the counters.
//
// 4k346 LUTs 5k578 FF's
// ============================================================================
//
module Thor2022_pit(rst_i, clk_i, cs_i, cyc_i, stb_i, ack_o, sel_i, we_i, adr_i, dat_i, dat_o,
	clk0, gate0, out0, clk1, gate1, out1, clk2, gate2, out2, clk3, gate3, out3,
	irq,
	);
parameter NTIMER=8;
input rst_i;
input clk_i;
input cs_i;
input cyc_i;
input stb_i;
output ack_o;
input [3:0] sel_i;
input we_i;
input [8:0] adr_i;
input [31:0] dat_i;
output reg [31:0] dat_o;
input clk0;
input gate0;
output out0;
input clk1;
input gate1;
output out1;
input clk2;
input gate2;
output out2;
input clk3;
input gate3;
output out3;
output reg irq;

integer n;
reg [31:0] maxcounth [0:NTIMER-1];
reg [31:0] maxcount [0:NTIMER-1];
reg [31:0] count [0:NTIMER-1];
reg [31:0] onth [0:NTIMER-1];
reg [31:0] ont [0:NTIMER-1];
wire [NTIMER-1:0] gate;
wire [NTIMER-1:0] pulse;
reg ldh [0:NTIMER-1];
reg ceh [0:NTIMER-1];
reg arh [0:NTIMER-1];
reg geh [0:NTIMER-1];
reg xch [0:NTIMER-1];
reg ieh [0:NTIMER-1];
reg ld [0:NTIMER-1];
reg ce [0:NTIMER-1];
reg ar [0:NTIMER-1];
reg ge [0:NTIMER-1];
reg xc [0:NTIMER-1];
reg [NTIMER-1:0] ie;
reg out [0:NTIMER-1];
reg [NTIMER-1:0] underflow;
reg [NTIMER-1:0] tmp;

wire cs = cyc_i & stb_i & cs_i;
reg rdy;
always @(posedge clk_i)
	rdy <= cs;
assign ack_o = cs ? (we_i ? 1'b1 : rdy) : 1'b0;

assign out0 = out[0];
assign out1 = out[1];
assign out2 = out[2];
assign out3 = out[3];
assign gate[0] = gate0;
assign gate[1] = gate1;
assign gate[2] = gate2;
assign gate[3] = gate3;

edge_det ued0 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk0), .pe(pulse[0]), .ne(), .ee());
edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk1), .pe(pulse[1]), .ne(), .ee());
edge_det ued2 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk2), .pe(pulse[2]), .ne(), .ee());
edge_det ued3 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk3), .pe(pulse[3]), .ne(), .ee());

initial begin
	for (n = 0; n < NTIMER; n = n + 1) begin
		maxcount[n] <= 32'd0;
		maxcounth[n] <= 32'd0;
		count[n] <= 32'd0;
		ont[n] <= 32'd0;
		onth[n] <= 32'd0;
		ld[n] <= 1'b0;
		ce[n] <= 1'b0;
		ar[n] <= 1'b0;
		ge[n] <= 1'b0;
		xc[n] <= 1'b0;
		ldh[n] <= 1'b0;
		ceh[n] <= 1'b0;
		arh[n] <= 1'b0;
		geh[n] <= 1'b0;
		xch[n] <= 1'b0;
		out[n] <= 1'b0;
	end
end

always @(posedge clk_i)
if (rst_i) begin
	irq <= 1'b0;
	ie <= 'd0;
	for (n = 0; n < NTIMER; n = n + 1) begin
		ld[n] <= 1'b0;
		ce[n] <= 1'b0;
		ar[n] <= 1'b1;
		ge[n] <= 1'b0;
		ldh[n] <= 1'b0;
		ceh[n] <= 1'b0;
		arh[n] <= 1'b1;
		geh[n] <= 1'b0;
		out[n] <= 1'b0;
	end	
end
else begin
	for (n = 0; n < NTIMER; n = n + 1) begin
		ld[n] <= 1'b0;
		if (cs && we_i && adr_i[8:4]==n)
		case(adr_i[3:2])
		2'd1:	maxcounth[n] <= dat_i;
		2'd2:	onth[n] <= dat_i;
		2'd3:	begin
					if (sel_i[0]) begin
						ldh[n] <= dat_i[0];
						ceh[n] <= dat_i[1];
						arh[n] <= dat_i[2];
						xch[n] <= dat_i[3];
						geh[n] <= dat_i[4];
					end
				end
		default:	;
		endcase
		// Writing the underflow register clears the underflows and disable further
		// interrupts where bits are set in the incoming data.
		// Interrupt processing should read the underflow register to determine
		// which timers underflowed, then write back the value to the underflow
		// register.
		if (cs && we_i && adr_i[8:2]==7'h40) begin
			if (dat_i[n]) begin
				ie[n] <= 1'b0;
				underflow[n] <= 1'b0;
			end
			irq <= 1'b0;
		end
		// The timer synchronization register indicates which timer's registers to
		// update. All timers may have their registers updated synchronously.
		if (cs && we_i && adr_i[8:2]==7'h41)
			if (dat_i[n]) begin
				ld[n] <= ldh[n];
				ce[n] <= ceh[n];
				ar[n] <= arh[n];
				xc[n] <= xch[n];
				ge[n] <= geh[n];
				ldh[n] <= 1'b0;
				maxcount[n] <= maxcounth[n];
				ont[n] <= onth[n];
			end
		if (cs && we_i && adr_i[8:2]==7'h42)
			ie <= dat_i;
		if (cs && we_i && adr_i[8:2]==7'h43)
			tmp <= dat_i;
		if (cs) begin
			case(adr_i[8:2])
			7'h40:	dat_o <= underflow;
			7'h41:	dat_o <= 'd0;
			7'h42:	dat_o <= ie;
			7'h43:	dat_o <= tmp;
			default:
				if (adr_i[8:4]==n)
					case(adr_i[3:2])
					2'd0:	dat_o <= count[n];
					2'd1:	dat_o <= maxcount[n];
					2'd2:	dat_o <= ont[n];
					2'd3:	dat_o <= {3'b0,ge[n],xc[n],ar[n],ce[n],1'b0};
					endcase
			endcase
		end
		else
			dat_o <= 32'd0;
		
		if (ld[n]) begin
			count[n] <= maxcount[n];
		end
		else if ((xc[n] ? pulse[n] & ce[n] : ce[n]) & (ge[n] ? gate[n] : 1'b1)) begin
			count[n] <= count[n] - 2'd1;
			if (count[n]==ont[n])
				out[n] <= 1'b1;
			else if (count[n]=='d0) begin
				underflow[n] <= 1'b1;
				if (ie[n])
					irq <= 1'b1;
				out[n] <= 1'b0;
				if (ar[n]) begin
					count[n] <= maxcount[n];
				end
				else begin
					ce[n] <= 1'b0;
				end
			end
		end
	end
end

endmodule
