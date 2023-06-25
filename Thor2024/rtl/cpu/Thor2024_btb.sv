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

import Thor2024pkg::*;

module Thor2024_btb(rst, clk, rclk, pc, next_pc, takb, commit_pc0, commit_brtgt0, commit_takb0, commit_pc1, commit_brtgt1, commit_takb1);
input rst;
input clk;
input rclk;
input pc_address_t pc;
output pc_address_t next_pc;
output reg takb;
input pc_address_t commit_pc0;
input pc_address_t commit_brtgt0;
input commit_takb0;
input pc_address_t commit_pc1;
input pc_address_t commit_brtgt1;
input commit_takb1;

typedef struct packed {
	logic takb;
	pc_address_t pc;
	pc_address_t tgt;
} btb_entry_t;


reg [9:0] addrb0, addrb1;
reg [9:0] addra;
btb_entry_t doutb0, doutb1;
reg w;
btb_entry_t tmp;

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(10),               // DECIMAL
      .ADDR_WIDTH_B(10),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(1024*$bits(btb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B($bits(btb_entry_t)),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst0 (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(doutb0),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addrb0),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(tmp),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(w)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(10),               // DECIMAL
      .ADDR_WIDTH_B(10),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(1024*$bits(btb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B($bits(btb_entry_t)),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst1 (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(doutb1),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addrb1),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(tmp),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(w)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

				
btb_entry_t [1023:0] btb_tbl;

btb_entry_t [7:0] btb_buf;
reg [2:0] bp, rbp;

always_ff @(posedge rclk)
	addrb0 <= pc;
always_ff @(posedge rclk)
	addrb1 <= pc + 16'h5000;

always_comb
begin
	if (pc==doutb0.pc && doutb0.takb) begin
		next_pc <= doutb0.tgt;
		takb <= 1'b1;
	end
	else if (fnPCInc(pc)==doutb1.pc && doutb1.takb) begin
		next_pc <= doutb1.tgt;
		takb <= 1'b1;
	end
	else begin
		next_pc <= pc + 16'hA000;// + {4'd10,12'h00};
		next_pc[11:0] <= 'd0;
		takb <= 1'b0;
	end
	// For now, to disable BTB
	next_pc <= pc + 16'hA000;
	next_pc[11:0] <= 'd0;
	takb <= 1'b0;
end

always_ff @(posedge clk)
if (rst) begin
	bp <= 'd0;
	rbp <= 'd0;
	w <= 'd0;
	addra <= 'd0;
	tmp <= 'd0;
end
else begin
	w <= 'd0;
	if (commit_takb0 & commit_takb1) begin
		btb_buf[bp].pc <= commit_pc0;
		btb_buf[bp].takb <= commit_takb0;
		btb_buf[bp].tgt <= commit_brtgt0;
		btb_buf[bp+1].pc <= commit_pc1;
		btb_buf[bp+1].takb <= commit_takb1;
		btb_buf[bp+1].tgt <= commit_brtgt1;
		bp <= bp + 2'd2;
	end
	else if (commit_takb0) begin
		btb_buf[bp].pc <= commit_pc0;
		btb_buf[bp].takb <= commit_takb0;
		btb_buf[bp].tgt <= commit_brtgt0;
		bp <= bp + 2'd1;
	end
	else if (commit_takb1) begin
		btb_buf[bp].pc <= commit_pc1;
		btb_buf[bp].takb <= commit_takb1;
		btb_buf[bp].tgt <= commit_brtgt1;
		bp <= bp + 2'd1;
	end
	if (bp != rbp) begin
		addra <= btb_buf[rbp].pc[9:0];
		tmp <= btb_buf[rbp];
		w <= 1'b1;
		rbp <= rbp + 2'd1;	
	end
end

endmodule
