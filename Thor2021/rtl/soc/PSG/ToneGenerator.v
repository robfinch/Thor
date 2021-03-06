`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2007-2017  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// ToneGenerator.v
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
//=============================================================================

module ToneGenerator(rst, clk, ack, test, vt, freq, pw, acc, prev_acc, wave, sync, ringmod, o);
input rst;
input clk;
input ack;              // wave table input acknowledge
input [11:0] wave;      // wave table data input
input test;
input [4:0] vt;         // voice type
input [15:0] freq;
input [11:0] pw;        // pulse width
input sync;
input ringmod;
input  [23:0] prev_acc;  // from previous voice
output [23:0] acc;	     // 1.023MHz / 2^ 24 = 0.06Hz resolution
output [11:0] o;

reg [23:0] accd;    // cycle delayed accumulator

integer n;

reg [11:0] outputT;
reg [11:0] outputW;
reg [22:0] lfsr;

wire synca = ~prev_acc[23]&acc[23]&sync;


HarmonicSynthesizer u2
(
    .rst(rst),
    .clk(clk),
    .ce(1'b1),
    .test(test),
    .sync(synca),
    .freq({8'h00,freq}),
    .o(acc)
);

// capture wave input
always @(posedge clk)
if (rst)
    outputW <= 0;
else if (ack)
    outputW <= wave;

// Noise generator
always @(posedge clk)
	if (acc[14] != acc[18])
		lfsr <= {lfsr[21:0],~(lfsr[22]^lfsr[17])};

// Triangle wave, ring modulation
wire msb = ringmod ? acc[23]^prev_acc[23] : acc[23];
always @(acc or msb)
	outputT <= msb ? ~acc[22:11] : acc[22:11];

// Other waveforms, ho-hum
wire [11:0] outputP = {12{acc[23:12] < pw}};
wire [11:0] outputS = acc[23:12];
wire [11:0] outputN = lfsr[11:0];

wire [11:0] out;
PSGNoteOutMux #(12) u4 (.s(vt), .a(outputT), .b(outputS), .c(outputP), .d(outputN), .e(outputW), .o(out) );
assign o = out;

endmodule

