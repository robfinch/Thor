// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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

module Thor2024_micro_code(micro_ip, micro_ir, next_ip, instr);
input [11:0] micro_ip;
input instruction_t micro_ir;
output reg [11:0] next_ip;
output instruction_t instr;
parameter SP = 6'd62;
parameter FP = 6'd61;
parameter LR0 = 6'd56;

always_comb
case(micro_ip)
// ENTER
12'h001:	begin next_ip = 12'h002; instr = {2'd0,3'd0,16'h3FC0,SP,SP,OP_ADDI}; end				// SP = SP - 64
12'h002:	begin next_ip = 12'h003; instr = {2'd0,3'd0,16'h00,2'd0,SP,FP,OP_STO};	end		// Mem[SP] = FP
12'h003:	begin next_ip = 12'h004; instr = {2'd0,3'd0,16'h10,2'd0,SP,LR0,OP_STO};	end	// Mem16[sp] = LR0
12'h004:	begin next_ip = 12'h005; instr = {2'd0,3'd0,16'h20,2'd0,SP,6'd0,OP_STO}; end		// Mem32[sp] = 0
12'h005:	begin next_ip = 12'h006; instr = {2'd0,3'd0,16'h30,2'd0,SP,6'd0,OP_STO}; end		// Mem48[sp] = 0
12'h006:	begin next_ip = 12'h007; instr = {3'd0,3'd0,FN_OR,2'd0,6'd0,SP,FP,OP_R2};	end // FP = SP
12'h007:	begin next_ip = 12'h008; instr = {2'd0,3'd0,16'h0000,SP,SP,OP_ADDI}; end				// SP = SP + const
12'h008:	begin next_ip = 12'h000; instr = {micro_ir[39:8],1'b0,OP_PFX};	end	
// LEAVE
12'h00C:	begin next_ip = 12'h00D; instr = {3'd0,3'd0,FN_OR,2'd0,6'd0,FP,SP,OP_R2}; end	// SP = FP
12'h00D:	begin next_ip = 12'h00E; instr = {2'd0,3'd0,16'h0,2'd0,SP,FP,OP_LDO};	end			// FP = Mem[SP]
12'h00E:	begin next_ip = 12'h00F; instr = {2'd0,3'd0,16'h10,2'd0,SP,LR0,OP_LDO};	end		// LR0 = Mem16[sp]
12'h00F:	begin next_ip = 12'h010; instr = {2'd0,3'd0,16'h40,SP,SP,OP_ADDI}; end					// SP = SP + 64
12'h010:	begin next_ip = 12'h011; instr = {2'd0,3'd0,16'h0000,SP,SP,OP_ADDI}; end				// SP = SP + const
12'h011:	begin next_ip = 12'h012; instr = {5'd0,micro_ir[39:13],1'b0,OP_PFX};	end	
12'h012:	begin next_ip = 12'h000; instr = {2'd0,3'd0,10'h00,micro_ir[12:7],LR0,6'd0,OP_JSR}; end	// PC = LR0 + const
// PUSH
12'h016:	begin next_ip = 12'h017; instr = {2'd0,3'd0,-{9'h000,micro_ir[33:31],4'h0},SP,SP,OP_ADDI}; end				// SP = SP - N * 16
12'h017:	begin next_ip = 12'h018; instr = micro_ir[33:31] > 3'd3 ? {2'd0,3'd0,9'h0,micro_ir[33:31]-3'd3,4'h0,2'd0,SP,micro_ir[30:25],OP_STO} : {33'd0,OP_NOP};	end		// Mem[SP] = Rc
12'h018:	begin next_ip = 12'h019; instr = micro_ir[33:31] > 3'd2 ? {2'd0,3'd0,9'h0,micro_ir[33:31]-3'd2,4'h0,2'd0,SP,micro_ir[24:19],OP_STO} : {33'd0,OP_NOP};	end		// Mem[SP] = Rb
12'h019:	begin next_ip = 12'h01A; instr = micro_ir[33:31] > 3'd1 ? {2'd0,3'd0,9'h0,micro_ir[33:31]-3'd1,4'h0,2'd0,SP,micro_ir[18:13],OP_STO} : {33'd0,OP_NOP};	end		// Mem[SP] = Ra
12'h01A:	begin next_ip = 12'h000; instr = micro_ir[33:31] > 3'd0 ? {2'd0,3'd0,9'h0,micro_ir[33:31]-3'd0,4'h0,2'd0,SP,micro_ir[12: 7],OP_STO} : {33'd0,OP_NOP};	end		// Mem[SP] = Rs
// POP
12'h020:	begin next_ip = 12'h021; instr = micro_ir[33:31] > 3'd0 ? {2'd0,3'd0,8'h0,4'h0,4'h0,2'd0,SP,micro_ir[12: 7],OP_LDO} : {33'd0,OP_NOP};	end		// Rt = Mem[SP]
12'h021:	begin next_ip = 12'h022; instr = micro_ir[33:31] > 3'd1 ? {2'd0,3'd0,8'h0,4'h1,4'h0,2'd0,SP,micro_ir[18:13],OP_LDO} : {33'd0,OP_NOP};	end		// Ra = Mem[SP]
12'h022:	begin next_ip = 12'h023; instr = micro_ir[33:31] > 3'd2 ? {2'd0,3'd0,8'h0,4'h2,4'h0,2'd0,SP,micro_ir[24:19],OP_LDO} : {33'd0,OP_NOP};	end		// Rb = Mem[SP]
12'h023:	begin next_ip = 12'h024; instr = micro_ir[33:31] > 3'd3 ? {2'd0,3'd0,8'h0,4'h3,4'h0,2'd0,SP,micro_ir[30:25],OP_LDO} : {33'd0,OP_NOP};	end		// Rc = Mem[SP]
12'h024:	begin next_ip = 12'h000; instr = {2'd0,3'd0,9'h000,micro_ir[33:31],4'h0,SP,SP,OP_ADDI}; end				// SP = SP + N * 16

default:	begin next_ip = 12'h000; end
endcase

endmodule
