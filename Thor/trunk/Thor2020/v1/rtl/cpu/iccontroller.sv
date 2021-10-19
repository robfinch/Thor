// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2020  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	-ICController.v
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
// ============================================================================
//
`include "..\inc\Thor2020-config.sv"
`include "..\inc\Thor2020-const.sv"
`include "..\inc\Thor2020-types.sv"
`define HIGH	1'b1
`define LOW		1'b0

module ICController(rst_i, clk_i, missadr, hit, bstate, idle,
	invline, invlineAddr, icl_ctr,
	thread_en, ihitL2, L2_ld, L2_cnt, L2_adr, L2_dat, L2_nxt,
	L1_selpc, L1_adr, L1_dat, L1_flt, L1_wr, L1_invline, icnxt, icwhich,
	ROM_dat, isROM,
	icl_o, cti_o, bte_o, bok_i, cyc_o, stb_o, ack_i, err_i, tlbmiss_i, exv_i, sel_o, adr_o, dat_i);
parameter ABW = 32;
parameter AMSB = ABW-1;
parameter RSTPC = 32'hFFFC0000;
parameter L2_ReadLatency = 3'd3;
parameter L1_WriteLatency = 3'd3;
parameter ROM_ReadLatency = 3'd1;
input rst_i;
input clk_i;
input tAddress missadr;
input hit;
input [4:0] bstate;
(* mark_debug="true" *)
output reg idle;
input invline;
input tAddress invlineAddr;
output reg [39:0] icl_ctr;
input thread_en;
input ihitL2;
output reg L2_ld;
output [2:0] L2_cnt;
output tAddress L2_adr = RSTPC;
input [511:0] L2_dat;
output reg L2_nxt;
output reg L1_selpc;
output tAddress L1_adr = RSTPC;
output reg [511:0] L1_dat = {128'h0};
output reg [2:0] L1_flt = 3'b0;
output reg L1_wr;
output reg L1_invline;
input [511:0] ROM_dat;
output isROM;
output reg icnxt;
output reg [1:0] icwhich = 2'b00;
output reg icl_o;
output reg [2:0] cti_o = 3'b000;
output reg [1:0] bte_o = 2'b00;
input bok_i;
output reg cyc_o = 1'b0;
output reg stb_o;
input ack_i;
input err_i;
input tlbmiss_i;
input exv_i;
output reg [15:0] sel_o;
output tAddress adr_o;
input [127:0] dat_i;

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

reg [3:0] state;
reg [3:0] picstate;
`include "..\inc\Thor2020-busStates.sv"
reg invline_r = 1'b0;
reg [79:0] invlineAddr_r = 72'd0;

//assign L2_ld = (state==IC_Ack) && (ack_i|err_i|tlbmiss_i|exv_i);
assign isROM = L1_adr[AMSB:18]=={ABW-18{1'b1}};
wire clk = clk_i;
reg [2:0] iccnt;
assign L2_cnt = iccnt;

//BUFH uclkb (.I(clk_i), .O(clk));

always @(posedge clk)
if (rst_i) begin
	icl_ctr <= 40'd0;
	icl_o <= `LOW;
	cti_o <= 3'b000;
	bte_o <= 2'b00;
	cyc_o <= `LOW;
	stb_o <= `LOW;
	sel_o <= 16'h00;
	adr_o <= {missadr[AMSB:4],4'h0};
	state <= IDLE;
	idle <= TRUE;
	L1_selpc <= TRUE;
	L1_adr <= RSTPC;
	L2_ld <= FALSE;
	L2_adr <= RSTPC;
end
else begin
L1_wr <= FALSE;
L1_invline <= FALSE;
icnxt <= FALSE;
L2_nxt <= FALSE;
if (invline) begin
	invline_r <= 1'b1;
	invlineAddr_r <= invlineAddr;
	L1_selpc <= FALSE;
end

// Instruction cache state machine.
// On a miss first see if the instruction is in the L2 cache. No need to go to
// the BIU on an L1 miss.
// If not the machine will wait until the BIU loads the L2 cache.

// Capture the previous ic state, used to determine how long to wait in
// icstate #4.
picstate <= state;
case(state)
IDLE:
	begin
		iccnt <= 3'd0;
		if (invline_r) begin
			L1_adr <= {invlineAddr_r[AMSB:4],4'd0};
			L1_invline <= TRUE;
			invline_r <= 1'b0;
			L1_selpc <= TRUE;
		end
		// If the bus unit is busy doing an update involving L1_adr or L2_adr
		// we have to wait.
		else begin
			if (!hit) begin
				L1_adr <= {missadr[AMSB:6],6'h0};
				icwhich <= 2'b00;
				state <= IC2;
				idle <= FALSE;
				L1_selpc <= FALSE;
			end
		end
	end
IC2:
	begin
		iccnt <= iccnt + 3'd1;
		if (isROM && iccnt>=ROM_ReadLatency) begin
			L1_wr <= TRUE;
			L1_dat <= ROM_dat;
			iccnt <= 3'd0;
			state <= IC5;
			idle <= FALSE;
		end
		else if (!isROM && iccnt>=L2_ReadLatency) begin
			iccnt <= 3'd0;
	    state <= IC_WaitL2;
			idle <= FALSE;
	  end
	end
// If data was in the L2 cache already there's no need to wait on the
// BIU to retrieve data. It can be determined if the hit signal was
// already active when this state was entered in which case waiting
// will do no good.
// The IC machine will stall in this state until the BIU is ready for
// data transfers. 
IC_WaitL2: 
	if (ihitL2 && picstate==IC2) begin
		L1_wr <= TRUE;
		L1_dat <= L2_dat;
		iccnt <= 3'd0;
		state <= IC5;
		idle <= FALSE;
		L1_selpc <= FALSE;
	end
	else begin
		if (bstate == B_WaitIC) begin
			iccnt <= 3'd0;
			icl_o <= `HIGH;
			cti_o <= 3'b001;
			bte_o <= 2'b00;
			cyc_o <= `HIGH;
			stb_o <= `HIGH;
			sel_o <= 8'hFF;
			adr_o <= L1_adr;
			L2_adr <= L1_adr;
			L2_ld <= TRUE;
			state <= IC_Ack;
			idle <= FALSE;
			L1_selpc <= FALSE;
		end
	end
// Wait for the L1 write latency to expire before continuing. Writes to the L1
// cache need to be visible before the processor can continue. Also pulse the
// random number generator associated with choosing a way.
IC5: 	
	begin
		iccnt <= iccnt + 3'd1;
		if (iccnt>=L1_WriteLatency) begin
			icnxt <= TRUE;
			L2_nxt <= TRUE;	// Dont really need to advance if L2 hit.
			state <= IDLE;
			idle <= TRUE;
			L1_selpc <= TRUE;
		end
	end
IC_Ack:
  if (ack_i|err_i|tlbmiss_i|exv_i) begin
  	if (!bok_i) begin
  		stb_o <= `LOW;
			adr_o[AMSB:4] <= adr_o[AMSB:4] + 2'd1;
  		state <= IC_Nack2;
			idle <= FALSE;
			L1_selpc <= FALSE;
  	end
		if (tlbmiss_i) begin
			//L1_dat[514:512] <= 2'd1;
			L1_flt <= 2'd1;
			L1_dat[127:0] <= {3'b000,{3{41'h00000013}}};	// NOP
			nack();
	  end
		else if (exv_i) begin
			//L1_dat[514:512] <= 2'd2;
			L1_flt <= 2'd2;
			L1_dat[127:0] <= {3'b000,{3{41'h00000013}}};	// NOP
			nack();
		end
	  else if (err_i) begin
			//L1_dat[514:512] <= 2'd3;
			L1_flt <= 2'd3;
			L1_dat[127:0] <= {3'b000,{3{41'h00000013}}};	// NOP
			nack();
	  end
	  else
	  	case(iccnt)
	  	3'd0:	L1_dat[127:  0] <= dat_i;
	  	3'd1:	L1_dat[255:128] <= dat_i;
	  	3'd2:	L1_dat[384:256] <= dat_i;
	  	3'd3:
	  		begin	
	  			L1_dat[511:384] <= dat_i;
	  			L1_flt <= 3'd0;
	  		end
//	  	3'd7:	L1_dat[514:448] <= {3'b000,dat_i};
	  	default:	L1_dat <= L1_dat;
	  	endcase
    iccnt <= iccnt + 3'd1;
    if (iccnt==3'd2)
      cti_o <= 3'b111;
    if (iccnt==3'd3)
    	nack();
  end
// This state only used when burst mode is not allowed.
IC_Nack2:
	if (~ack_i) begin
		stb_o <= `HIGH;
		state <= IC_Ack;
		idle <= FALSE;
		L1_selpc <= FALSE;
	end
// The cycle after data loading is complete, pulse the L1 write to update the
// cache.
IC_Nack:
	begin
		L2_ld <= FALSE;
    iccnt <= 3'd0;
		L1_wr <= TRUE;
		icl_ctr <= icl_ctr + 40'd1;
		state <= IC5;	// Wait for write latency to expire
		idle <= FALSE;
		L1_selpc <= FALSE;
	end
default:
	begin
   	state <= IDLE;
		idle <= TRUE;
		L1_selpc <= TRUE;
  end
endcase
end

task nack;
begin
	icl_o <= `LOW;
	cti_o <= 3'b000;
	cyc_o <= `LOW;
	stb_o <= `LOW;
	state <= IC_Nack;
	idle <= FALSE;
	L1_selpc <= FALSE;
end
endtask

endmodule
