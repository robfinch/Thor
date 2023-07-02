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
parameter MC0 = 6'd48;
parameter MC1 = 6'd49;
parameter MC2 = 6'd50;
parameter MC3 = 6'd51;

always_comb
case(micro_ip)
// ENTER
12'h001:	begin next_ip = 12'h002; instr = {2'd0,3'd0,16'hFFC0,SP,SP,OP_ADDI}; end				// SP = SP - 64
12'h002:	begin next_ip = 12'h003; instr = {2'd0,3'd0,16'h00,2'd0,SP,FP,OP_STO};	end		// Mem[SP] = FP
12'h003:	begin next_ip = 12'h004; instr = {2'd0,3'd0,16'h10,2'd0,SP,LR0,OP_STO};	end	// Mem16[sp] = LR0
12'h004:	begin next_ip = 12'h005; instr = {2'd0,3'd0,16'h20,2'd0,SP,6'd0,OP_STO}; end		// Mem32[sp] = 0
12'h005:	begin next_ip = 12'h006; instr = {2'd0,3'd0,16'h30,2'd0,SP,6'd0,OP_STO}; end		// Mem48[sp] = 0
12'h006:	begin next_ip = 12'h007; instr = {3'd0,3'd0,FN_OR,2'd0,6'd0,SP,FP,OP_R2};	end // FP = SP
12'h007:	begin next_ip = 12'h008; instr = {2'd0,3'd0,16'h0000,SP,SP,OP_ADDI}; end				// SP = SP + const
12'h008:	begin next_ip = 12'h000; instr = {micro_ir[39:8],1'b0,OP_PFX};	end	
12'h009:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end
// LEAVE
12'h00C:	begin next_ip = 12'h00D; instr = {3'd0,3'd0,FN_OR,2'd0,6'd0,FP,SP,OP_R2}; end	// SP = FP
12'h00D:	begin next_ip = 12'h00E; instr = {2'd0,3'd0,16'h0,2'd0,SP,FP,OP_LDO};	end			// FP = Mem[SP]
12'h00E:	begin next_ip = 12'h00F; instr = {2'd0,3'd0,16'h10,2'd0,SP,LR0,OP_LDO};	end		// LR0 = Mem16[sp]
12'h00F:	begin next_ip = 12'h010; instr = {2'd0,3'd0,16'h40,SP,SP,OP_ADDI}; end					// SP = SP + 64
12'h010:	begin next_ip = 12'h011; instr = {2'd0,3'd0,16'h0000,SP,SP,OP_ADDI}; end				// SP = SP + const
12'h011:	begin next_ip = 12'h012; instr = {5'd0,micro_ir[39:13],1'b0,OP_PFX};	end	
12'h012:	begin next_ip = 12'h000; instr = {2'd0,3'd0,10'h00,micro_ir[12:7],LR0,6'd0,OP_JSR}; end	// PC = LR0 + const
12'h013:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end
// PUSH
12'h016:	begin next_ip = 12'h017; instr = {2'd0,3'd0,-{9'h000,micro_ir[33:31],4'h0},SP,SP,OP_ADDI}; end				// SP = SP - N * 16
12'h017:	begin next_ip = 12'h018; instr = micro_ir[33:31] > 3'd0 ? {2'd0,3'd0,9'h0,3'd0,4'h0,2'd0,SP,micro_ir[12: 7],OP_STO} : {33'd0,OP_NOP};	end		// Mem[SP] = Rs
12'h018:	begin next_ip = 12'h019; instr = micro_ir[33:31] > 3'd1 ? {2'd0,3'd0,9'h0,3'd1,4'h0,2'd0,SP,micro_ir[18:13],OP_STO} : {33'd0,OP_NOP};	end		// Mem[SP] = Ra
12'h019:	begin next_ip = 12'h01A; instr = micro_ir[33:31] > 3'd2 ? {2'd0,3'd0,9'h0,3'd2,4'h0,2'd0,SP,micro_ir[24:19],OP_STO} : {33'd0,OP_NOP};	end		// Mem[SP] = Rb
12'h01A:	begin next_ip = 12'h000; instr = micro_ir[33:31] > 3'd3 ? {2'd0,3'd0,9'h0,3'd3,4'h0,2'd0,SP,micro_ir[30:25],OP_STO} : {33'd0,OP_NOP};	end		// Mem[SP] = Rc
12'h01B:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end
// POP
12'h020:	begin next_ip = 12'h021; instr = micro_ir[33:31] > 3'd0 ? {2'd0,3'd0,8'h0,4'h0,4'h0,2'd0,SP,micro_ir[12: 7],OP_LDO} : {33'd0,OP_NOP};	end		// Rt = Mem[SP]
12'h021:	begin next_ip = 12'h022; instr = micro_ir[33:31] > 3'd1 ? {2'd0,3'd0,8'h0,4'h1,4'h0,2'd0,SP,micro_ir[18:13],OP_LDO} : {33'd0,OP_NOP};	end		// Ra = Mem[SP]
12'h022:	begin next_ip = 12'h023; instr = micro_ir[33:31] > 3'd2 ? {2'd0,3'd0,8'h0,4'h2,4'h0,2'd0,SP,micro_ir[24:19],OP_LDO} : {33'd0,OP_NOP};	end		// Rb = Mem[SP]
12'h023:	begin next_ip = 12'h024; instr = micro_ir[33:31] > 3'd3 ? {2'd0,3'd0,8'h0,4'h3,4'h0,2'd0,SP,micro_ir[30:25],OP_LDO} : {33'd0,OP_NOP};	end		// Rc = Mem[SP]
12'h024:	begin next_ip = 12'h000; instr = {2'd0,3'd0,9'h000,micro_ir[33:31],4'h0,SP,SP,OP_ADDI}; end				// SP = SP + N * 16
12'h025:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end
// FDIV
12'h027:	begin next_ip = 12'h028; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FRES,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h028:	begin next_ip = 12'h029; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FNEG,micro_ir[18:13],micro_ir[18:13],OP_FLT2}; end
12'h029:	begin next_ip = 12'h02A; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd2,6'd58,OP_FLT2}; end
12'h02A:	begin next_ip = 12'h02B; instr = {micro_ir[39:34],FN_FMA,6'd58,micro_ir[18:13],micro_ir[12:7],6'd47,OP_FLT3}; end
12'h02B:	begin next_ip = 12'h02C; instr = {micro_ir[39:34],FN_FMA,6'd0,6'd47,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h02C:	begin next_ip = 12'h02D; instr = {micro_ir[39:34],FN_FMA,6'd58,micro_ir[18:13],micro_ir[12:7],6'd47,OP_FLT3}; end
12'h02D:	begin next_ip = 12'h02E; instr = {micro_ir[39:34],FN_FMA,6'd0,6'd47,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h02E:	begin next_ip = 12'h02F; instr = {micro_ir[39:34],FN_FMA,6'd58,micro_ir[18:13],micro_ir[12:7],6'd47,OP_FLT3}; end
12'h02F:	begin next_ip = 12'h030; instr = {micro_ir[39:34],FN_FMA,6'd0,6'd47,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h030:	begin next_ip = 12'h031; instr = {micro_ir[39:34],FN_FMA,6'd58,micro_ir[18:13],micro_ir[12:7],6'd47,OP_FLT3}; end
12'h031:	begin next_ip = 12'h032; instr = {micro_ir[39:34],FN_FMA,6'd0,6'd47,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h032:	begin next_ip = 12'h033; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FNEG,micro_ir[18:13],micro_ir[18:13],OP_FLT2}; end
12'h033:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_FMA,6'd0,micro_ir[18:13],micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h034:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end

// Lomont Reciprocal Square Root
// float RcpSqrt1 (float x)
// {
//   float xhalf = 0.5f*x;
//   int i = *(int*)&x; // represent float as an integer  ()
//	 i = 0x5f375a86 – (i >> 1);// integer division by two and change in sign
//	 float y = *(float*)&i; // represent integer as a float  ()
//
// initial approximation 0
//   y = y*(1.5f – xhalf *y*y); // first NR iteration			9.16 bits accurate
//	 y = y*(1.5f – xhalf *y*y); // second NR iteration	 17.69 bits accurate
//	 y = y*(1.5f – xhalf *y*y); // third NR iteration	   35 bits accurate
//   y = y*(1.5f – xhalf *y*y); // second NR iteration	 70 bits accurate
//	 return y;
// }
//64-bit magic used:
//0x5FE6EB50C7B537A9
// Approximately 119 clock cycles.
12'h035:	begin next_ip = 12'h036; instr = {3'd0,12'h04A,6'd0,micro_ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h036:	begin next_ip = 12'h037; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd57,MC0,OP_FLT2}; end	// MC0 = infinity
12'h037:	begin next_ip = 12'h038; instr = {3'd0,12'h04B,MC0,micro_ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; end			// if = infinity
12'h038:	begin next_ip = 12'h039; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd0,MC0,OP_FLT2}; end	// MC0 = 0.5
12'h039:	begin next_ip = 12'h03A; instr = {micro_ir[39:34],FN_MUL,2'b0,MC0,micro_ir[18:13],MC1,OP_FLT2}; end	// MC1 = x * MC0
12'h03A:	begin next_ip = 12'h03B; instr = {micro_ir[39:34],1'b0,1'b1,OP_LSR,7'd1,micro_ir[18:13],MC2,OP_SHIFT}; end	// MC2 = i>>1
12'h03B:	begin next_ip = 12'h03C; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd4,MC0,OP_FLT2}; end			// MC0 = MAGIC
12'h03C:	begin next_ip = 12'h03D; instr = {micro_ir[39:34],FN_SUB,2'b00,MC2,MC0,MC2,OP_FLT2}; end							// MC2 = MAGIC - MC2
12'h03D:	begin next_ip = 12'h03E; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h03E:	begin next_ip = 12'h03F; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd3,MC0,OP_FLT2}; end			// MC0 = 1.5
12'h03F:	begin next_ip = 12'h040; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h040:	begin next_ip = 12'h041; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; end		// MC2 = MC2 * Rt
12'h041:	begin next_ip = 12'h042; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h042:	begin next_ip = 12'h043; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h043:	begin next_ip = 12'h044; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; end		// MC2 = MC2 * Rt
12'h044:	begin next_ip = 12'h045; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h045:	begin next_ip = 12'h046; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h046:	begin next_ip = 12'h047; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; end		// MC2 = MC2 * Rt
12'h047:	begin next_ip = 12'h048; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h048:	begin next_ip = 12'h049; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h049:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],micro_ir[12:7],OP_FLT2}; end		// Rt = MC2 * Rt
12'h04A:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd63,micro_ir[12:7],OP_FLT2}; end		// Rt = Nan (square root of negative)
12'h04B:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd62,micro_ir[12:7],OP_FLT2}; end		// Rt = Nan (square root of infinity)
12'h04C:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end

// FRSQRTE9
// Approximately 46 clock cycles.
12'h04D:	begin next_ip = 12'h04E; instr = {3'd0,12'h04A,6'd0,micro_ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h04E:	begin next_ip = 12'h04F; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd57,MC0,OP_FLT2}; end	// MC0 = infinity
12'h04F:	begin next_ip = 12'h050; instr = {3'd0,12'h04B,MC0,micro_ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; end			// if = infinity
12'h050:	begin next_ip = 12'h051; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd0,MC0,OP_FLT2}; end	// MC0 = 0.5
12'h051:	begin next_ip = 12'h052; instr = {micro_ir[39:34],FN_MUL,2'b0,MC0,micro_ir[18:13],MC1,OP_FLT2}; end	// MC1 = x * MC0
12'h052:	begin next_ip = 12'h053; instr = {micro_ir[39:34],1'b0,1'b1,OP_LSR,7'd1,micro_ir[18:13],MC2,OP_SHIFT}; end	// MC2 = i>>1
12'h053:	begin next_ip = 12'h054; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd4,MC0,OP_FLT2}; end			// MC0 = MAGIC
12'h054:	begin next_ip = 12'h055; instr = {micro_ir[39:34],FN_SUB,2'b00,MC2,MC0,MC2,OP_FLT2}; end							// MC2 = MAGIC - MC2
12'h055:	begin next_ip = 12'h056; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h056:	begin next_ip = 12'h057; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd3,MC0,OP_FLT2}; end			// MC0 = 1.5
12'h057:	begin next_ip = 12'h058; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h058:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],micro_ir[12:7],OP_FLT2}; end		// MC2 = MC2 * Rt

// FRSQRTE17
// Approximately 70 clock cycles
12'h059:	begin next_ip = 12'h05A; instr = {3'd0,12'h04A,6'd0,micro_ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h05A:	begin next_ip = 12'h05B; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd57,MC0,OP_FLT2}; end	// MC0 = infinity
12'h05B:	begin next_ip = 12'h05C; instr = {3'd0,12'h04B,MC0,micro_ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; end			// if = infinity
12'h05C:	begin next_ip = 12'h05D; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd0,MC0,OP_FLT2}; end	// MC0 = 0.5
12'h05D:	begin next_ip = 12'h05E; instr = {micro_ir[39:34],FN_MUL,2'b0,MC0,micro_ir[18:13],MC1,OP_FLT2}; end	// MC1 = x * MC0
12'h05E:	begin next_ip = 12'h05F; instr = {micro_ir[39:34],1'b0,1'b1,OP_LSR,7'd1,micro_ir[18:13],MC2,OP_SHIFT}; end	// MC2 = i>>1
12'h05F:	begin next_ip = 12'h060; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd4,MC0,OP_FLT2}; end			// MC0 = MAGIC
12'h060:	begin next_ip = 12'h061; instr = {micro_ir[39:34],FN_SUB,2'b00,MC2,MC0,MC2,OP_FLT2}; end							// MC2 = MAGIC - MC2
12'h061:	begin next_ip = 12'h062; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h062:	begin next_ip = 12'h063; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd3,MC0,OP_FLT2}; end			// MC0 = 1.5
12'h063:	begin next_ip = 12'h064; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h064:	begin next_ip = 12'h065; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; end		// MC2 = MC2 * Rt
12'h065:	begin next_ip = 12'h066; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h066:	begin next_ip = 12'h067; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h067:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],micro_ir[12:7],OP_FLT2}; end		// Rt = MC2 * Rt
12'h068:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end

// FRSQRTE34
// Approximately 94 clock cycles
12'h069:	begin next_ip = 12'h06A; instr = {3'd0,12'h04A,6'd0,micro_ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h06A:	begin next_ip = 12'h06B; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd57,MC0,OP_FLT2}; end	// MC0 = infinity
12'h06B:	begin next_ip = 12'h06C; instr = {3'd0,12'h04B,MC0,micro_ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; end			// if = infinity
12'h06C:	begin next_ip = 12'h06D; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd0,MC0,OP_FLT2}; end	// MC0 = 0.5
12'h06D:	begin next_ip = 12'h06E; instr = {micro_ir[39:34],FN_MUL,2'b0,MC0,micro_ir[18:13],MC1,OP_FLT2}; end	// MC1 = x * MC0
12'h06E:	begin next_ip = 12'h06F; instr = {micro_ir[39:34],1'b0,1'b1,OP_LSR,7'd1,micro_ir[18:13],MC2,OP_SHIFT}; end	// MC2 = i>>1
12'h06F:	begin next_ip = 12'h070; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd4,MC0,OP_FLT2}; end			// MC0 = MAGIC
12'h070:	begin next_ip = 12'h071; instr = {micro_ir[39:34],FN_SUB,2'b00,MC2,MC0,MC2,OP_FLT2}; end							// MC2 = MAGIC - MC2
12'h071:	begin next_ip = 12'h072; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h072:	begin next_ip = 12'h073; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd3,MC0,OP_FLT2}; end			// MC0 = 1.5
12'h073:	begin next_ip = 12'h074; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h074:	begin next_ip = 12'h075; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; end		// MC2 = MC2 * Rt
12'h075:	begin next_ip = 12'h076; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h076:	begin next_ip = 12'h077; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h077:	begin next_ip = 12'h078; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; end		// MC2 = MC2 * Rt
12'h078:	begin next_ip = 12'h079; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,MC2,MC3,OP_FLT2}; end							// MC3 = MC2 * MC2
12'h079:	begin next_ip = 12'h07A; instr = {micro_ir[39:34],FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; end		// Rt = -(MC3 * MC1 - MC0)
12'h07A:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_MUL,2'b0,MC2,micro_ir[12:7],micro_ir[12:7],OP_FLT2}; end		// Rt = MC2 * Rt
12'h07B:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end

// FRES16
// 22 clocks
// x[i+1] = x[i]*(2 - x[i]*a)
12'h080:	begin next_ip = 12'h081; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_ISNAN,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h081:	begin next_ip = 12'h082; instr = {3'd0,12'h086,6'd0,micro_ir[12:7],3'd1,2'd0,1'b0,OP_MCB}; end
12'h082:	begin next_ip = 12'h083; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FRES,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h083:	begin next_ip = 12'h084; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd2,MC0,OP_FLT2}; end
12'h084:	begin next_ip = 12'h085; instr = {micro_ir[39:34],FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; end
12'h085:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h086:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_OR,2'b0,6'd0,micro_ir[18:13],micro_ir[12:7],OP_R2}; end		// Rt = Ra = NaN
12'h087:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end

// FRES32
// 38 clocks
12'h088:	begin next_ip = 12'h089; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_ISNAN,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h089:	begin next_ip = 12'h08A; instr = {3'd0,12'h086,6'd0,micro_ir[12:7],3'd1,2'd0,1'b0,OP_MCB}; end
12'h08A:	begin next_ip = 12'h08B; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FRES,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h08B:	begin next_ip = 12'h08C; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd2,MC0,OP_FLT2}; end
12'h08C:	begin next_ip = 12'h08D; instr = {micro_ir[39:34],FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; end
12'h08D:	begin next_ip = 12'h08E; instr = {micro_ir[39:34],FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h08E:	begin next_ip = 12'h08F; instr = {micro_ir[39:34],FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; end
12'h08F:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end

// FRES64
// 54 clocks
12'h090:	begin next_ip = 12'h091; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_ISNAN,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h091:	begin next_ip = 12'h092; instr = {3'd0,12'h086,6'd0,micro_ir[12:7],3'd1,2'd0,1'b0,OP_MCB}; end
12'h092:	begin next_ip = 12'h093; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FRES,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h093:	begin next_ip = 12'h094; instr = {micro_ir[39:34],FN_FLT1,2'b0,FN_FCONST,6'd2,MC0,OP_FLT2}; end
12'h094:	begin next_ip = 12'h095; instr = {micro_ir[39:34],FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; end
12'h095:	begin next_ip = 12'h096; instr = {micro_ir[39:34],FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h096:	begin next_ip = 12'h097; instr = {micro_ir[39:34],FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; end
12'h097:	begin next_ip = 12'h098; instr = {micro_ir[39:34],FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h098:	begin next_ip = 12'h099; instr = {micro_ir[39:34],FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; end
12'h099:	begin next_ip = 12'h000; instr = {micro_ir[39:34],FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h09A:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end

// RESET
12'h0A0:	begin next_ip = 12'h0A1; instr = {2'd0,3'd0,16'hFFE0,2'd0,6'd0,SP,OP_LDO};	end			// SP = Mem[FFFFFFE0]
12'h0A1:	begin next_ip = 12'h0A2; instr = {2'd0,3'd0,16'hFFF0,2'd0,6'd0,MC0,OP_LDO};	end			// PC = Mem[FFFFFFF0]
12'h0A2:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,MC0,6'd0,OP_JSR};	end
12'h0A3:	begin next_ip = 12'h000; instr = {2'd0,3'd0,16'h0000,2'd0,6'd0,6'd0,OP_NOP};	end
default:	begin next_ip = 12'h000; instr = 40'hFFFFFFFFFF; end	// NOP
endcase

endmodule
