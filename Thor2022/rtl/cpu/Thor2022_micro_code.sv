// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_micro_code.sv
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

module Thor2022_micro_code(micro_ipi, next_mip, micro_ir, ir, incr);
input [6:0] micro_ipi;
input Instruction micro_ir;
output reg [6:0] next_mip;
output Instruction ir;
output reg [3:0] incr;

always_comb
begin
	next_mip = 'd0;
	incr = 'd0;
	case(micro_ipi)
	// POP Ra
	7'd1:		begin next_mip = 7'd2; ir = {29'h00,5'd31,micro_ir[13:9],1'b0,LDH}; incr = 4'd2; end	// LDOS $Ra,[$SP]
	7'd2:		begin next_mip = 7'd0; ir = {13'h010,5'd31,5'd31,1'b0,ADDI}; incr = 4'd2; end							// ADD $SP,$SP,#8
	// POP Ra,Rb,Rc,Rd
	7'd5:		begin next_mip = 7'd6; ir = {29'h00,5'd31,micro_ir[13: 9],1'b0,(micro_ir[31:29]>=3'd1)?LDH:NOP}; incr = 4'd4; end	// LDOS $Ra,[$SP]
	7'd6:		begin next_mip = 7'd7; ir = {29'h10,5'd31,micro_ir[18:14],1'b0,(micro_ir[31:29]>=3'd2)?LDH:NOP}; end	// LDOS $Rb,[$SP]
	7'd7:		begin next_mip = 7'd8; ir = {29'h20,5'd31,micro_ir[23:19],1'b0,(micro_ir[31:29]>=3'd3)?LDH:NOP}; end	// LDOS $Rc,[$SP]
	7'd8:		begin next_mip = 7'd9; ir = {29'h30,5'd31,micro_ir[28:24],1'b0,(micro_ir[31:29]>=3'd4)?LDH:NOP}; end	// LDOS $Rc,[$SP]
	7'd9:		begin next_mip = 7'd0; ir = {6'h0,micro_ir[31:29],4'h0,5'd31,5'd31,1'b0,ADDI}; incr = 4'd4; end							// ADD $SP,$SP,#24
	// PUSH Ra
	7'd10:	begin next_mip = 7'd11; ir = {13'h1FF0,5'd31,5'd31,1'b0,ADDI}; incr = 4'd2; end							// ADD $SP,$SP,#-16
	7'd11:	begin next_mip = 7'd0;  ir = {29'h00,5'd31,micro_ir[13:9],1'b0,STH}; incr = + 4'd2; end	// STOS $Ra,[$SP]
	// PUSH Ra,Rb,Rc,Rd
	7'd15:	begin next_mip = 7'd16; ir = {{5'h1F,4'h0-micro_ir[31:29],4'h0},5'd31,5'd31,1'b0,ADDI}; incr = 4'd4; end								// ADD $SP,$SP,#-24
	7'd16:	begin next_mip = 7'd17; ir = {29'h00,5'd31,micro_ir[28:24],1'b0,(micro_ir[31:29]==3'd4)?STH:NOP}; end	// STOS $Rc,[$SP]
	7'd17:	begin next_mip = 7'd18; ir = {22'd0,micro_ir[31:29]-2'd3,4'h0,5'd31,micro_ir[23:19],1'b0,(micro_ir[31:29]>=3'd3)?STH:NOP}; end	// STOS $Rb,8[$SP]
	7'd18:	begin next_mip = 7'd19; ir = {22'd0,micro_ir[31:29]-2'd2,4'h0,5'd31,micro_ir[18:14],1'b0,(micro_ir[31:29]>=3'd2)?STH:NOP}; end	// STOS $Rb,8[$SP]
	7'd19:	begin next_mip = 7'd0;  ir = {22'd0,micro_ir[31:29]-2'd1,4'h0,5'd31,micro_ir[13:9],1'b0,(micro_ir[31:29]>=3'd1)?STH:NOP}; incr = 4'd4; end		// STOS $Ra,16[$SP]
	// LEAVE
	7'd20:	begin next_mip = 7'd21; ir = {13'h000,5'd30,5'd31,1'b0,ADDI};	end						// ADD $SP,$FP,#0
	7'd21:	begin next_mip = 7'd22; ir = {29'h00,5'd31,5'd30,1'b0,LDH}; end				// LDO $FP,[$SP]
	7'd22:	begin next_mip = 7'd23; ir = {29'h10,5'd31,5'd03,1'b0,LDH}; end				// LDO $T0,16[$SP]
	7'd23:	begin next_mip = 7'd26; ir = {2'd1,5'd03,1'b0,MTLK}; end										// MTLK LK1,$T0
//			7'd24:	begin next_mip = 7'd25; ir = {3'd6,8'h18,6'd63,6'd03,1'b0,LDOS}; end				// LDO $T0,24[$SP]
//			7'd25:	begin next_mip = 7'd26; ir = {3'd0,1'b0,CSRRW,4'd0,16'h3103,6'd03,6'd00,1'b0,CSR}; end	// CSRRW $R0,$T0,0x3103
	7'd26: 	begin next_mip = 7'd27; ir = {{6'h0,micro_ir[31:13]}+8'd4,4'b0,5'd31,5'd31,1'b0,ADDIL}; end	// ADD $SP,$SP,#Amt
	7'd27:	begin next_mip = 7'd0;  ir = {1'd0,micro_ir[12:9],2'd1,1'b0,RTS}; incr = 4'd4; end
	// STOO
	7'd28:	begin next_mip = 7'd29; ir = {micro_ir[47:12],3'd0,1'b0,STOO}; incr = 4'd6; end
	7'd29:	begin next_mip = 7'd30; ir = {micro_ir[47:12],3'd2,1'b0,STOO}; end
	7'd30:	begin next_mip = 7'd31; ir = {micro_ir[47:12],3'd4,1'b0,STOO}; end
	7'd31:	begin next_mip = 7'd0;  ir = {micro_ir[47:12],3'd6,1'b0,STOO}; incr = 4'd6; end
	// ENTER
	7'd32: 	begin next_mip = 7'd33; ir = {13'h1FC0,5'd31,5'd31,1'b0,ADDI}; incr = 4'd4; end						// ADD $SP,$SP,#-64
	7'd33:	begin next_mip = 7'd34; ir = {29'h00,5'd31,5'd30,1'b0,STH}; end				// STO $FP,[$SP]
	7'd34:	begin next_mip = 7'd35; ir = {2'd1,5'd03,1'b0,MFLK}; end										// MFLK $T0,LK1
	7'd35:	begin next_mip = 7'd38; ir = {29'h10,5'd31,5'd03,1'b0,STH}; end				// STO $T0,16[$SP]
//			7'd36:	begin next_mip = 7'd37; ir = {3'd0,1'b0,CSRRD,4'd0,16'h3103,6'd00,6'd03,1'b0,CSR}; end	// CSRRD $T0,$R0,0x3103
//			7'd37:	begin next_mip = 7'd38; ir = {3'd6,8'h18,6'd63,6'd03,1'b0,STOS}; end				// STO $T0,24[$SP]
	7'd38:	begin next_mip = 7'd39; ir = {29'h20,5'd31,5'd00,1'b0,STH}; end				// STH $R0,32[$SP]
	7'd39:	begin next_mip = 7'd40; ir = {29'h30,5'd31,5'd00,1'b0,STH}; end				// STH $R0,48[$SP]
	7'd40: 	begin next_mip = 7'd41; ir = {13'h000,5'd31,5'd30,1'b0,ADDI}; end						// ADD $FP,$SP,#0
	7'd41: 	begin next_mip = 7'd0;  ir = {{9{micro_ir[31]}},micro_ir[31:12],3'b0,5'd31,5'd31,1'b0,ADDIL}; incr = 4'd4; end // SUB $SP,$SP,#Amt
	// DEFCAT
	7'd44:	begin next_mip = 7'd45; ir = {3'd6,8'h00,6'd62,6'd3,1'b0,LDH}; incr = 4'd2; end					// LDO $Tn,[$FP]
	7'd45:	begin next_mip = 7'd46; ir = {3'd6,8'h20,6'd3,6'd4,1'b0,LDHS}; end					// LDO $Tn+1,32[$Tn]
	7'd46:	begin next_mip = 7'd47; ir = {3'd6,8'h10,6'd62,6'd4,1'b0,STHS}; end					// STO $Tn+1,16[$FP]
	7'd47:	begin next_mip = 7'd48; ir = {3'd6,8'h28,6'd3,6'd4,1'b0,LDHS}; end					// LDO $Tn+1,40[$Tn]
	7'd48:	begin next_mip = 7'd0;  ir = {3'd6,8'h18,6'd62,6'd4,1'b0,STHS}; incr = 4'd2; end					// STO $Tn+1,24[$FP]
	default:	begin next_mip = 'd0; ir = NOP; end
	endcase
end

endmodule
