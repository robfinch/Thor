// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2023  Robert Finch, Waterloo
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
//
module scratchmem128pci(rst_i, clk_i, cs_config_i, cs_ram_i, blen_i, cti_i,
	tid_i, tid_o, cyc_i, stb_i, next_o, ack_o, we_i, sel_i, adr_i, 
	dat_i, dat_o, adr_o, ip, sp);
input rst_i;
input clk_i;
input cs_config_i;
input cs_ram_i;
input [5:0] blen_i;
input [2:0] cti_i;
input [7:0] tid_i;
output reg [7:0] tid_o;
input cyc_i;
input stb_i;
output next_o;
output ack_o;
input we_i;
input [15:0] sel_i;
input [31:0] adr_i;
input [127:0] dat_i;
output reg [127:0] dat_o;
output reg [31:0] adr_o;
input [31:0] ip;
input [31:0] sp;

parameter IO_ADDR = 32'hFFFC0001;
parameter IO_ADDR_MASK = 32'h00FC0000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd11;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h00;					// 00 = RAM
parameter CFG_CLASS = 8'h05;						// 05 = memory controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'hFF;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device


integer n;

reg [17:4] radr;
reg [31:0] adr1;

reg ack;
reg we;
reg [15:0] sel;
reg [31:0] adr, adrd;
reg [127:0] dati;
reg cs_ram, cs_config;
wire cs_bar0;
wire [127:0] cfg_out;
wire [127:0] ram_dat_o;

/*
initial begin
`include "f:/cores2023/Thor/software/examples/rom.ver";
end
*/
wire cs = cs_ram;
assign next_o = 1'b0;//cs;
reg csd;
reg [127:0] datod;
wire cfg_rd_ack;

reg [7:0] bndxd, bndxd1;
reg [5:0] cnt;
reg we2;
reg [15:0] sel2;
reg [31:0] adr2;
reg [127:0] dati2;

wire rd_ack, wr_ack;
vtdl #(.WID(1), .DEP(16)) udlyr (.clk(clk_i), .ce(1'b1), .a(1), .d((cs) & ~we), .q(rd_ack));
vtdl #(.WID(1), .DEP(16)) udlyc (.clk(clk_i), .ce(1'b1), .a(1), .d((cs_config) & ~we), .q(cfg_rd_ack));
vtdl #(.WID(1), .DEP(16)) udlyw (.clk(clk_i), .ce(1'b1), .a(1), .d((cs|cs_config) &  we), .q(wr_ack));
assign ack_o = (rd_ack|cfg_rd_ack|wr_ack);//(cs|cs_config);

always_ff @(posedge clk_i)
	cs_config <= cs_config_i & cyc_i & stb_i &&
		adr_i[27:20]==CFG_BUS &&
		adr_i[19:15]==CFG_DEVICE &&
		adr_i[14:12]==CFG_FUNC;

always_ff @(posedge clk_i)
	csd <= cs_ram_i && cyc_i && stb_i;
always_ff @(posedge clk_i)
	cs_ram <= csd && cs_bar0;
always_ff @(posedge clk_i)
	we <= we_i;
always_ff @(posedge clk_i)
	sel <= sel_i;
always_ff @(posedge clk_i)
	adr <= adr_i;
always_ff @(posedge clk_i)
	adrd <= adr_i;
always_ff @(posedge clk_i)
	dati <= dat_i;
always_ff @(posedge clk_i)
	we2 <= we;
always_ff @(posedge clk_i)
	sel2 <= sel;
always_ff @(posedge clk_i)
	adr2 <= adr;
always_ff @(posedge clk_i)
	dati2 <= dati;

pci128_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
	.CFG_SUBSYSTEM_VENDOR_ID(CFG_SUBSYSTEM_VENDOR_ID),
	.CFG_SUBSYSTEM_ID(CFG_SUBSYSTEM_ID),
	.CFG_ROM_ADDR(CFG_ROM_ADDR),
	.CFG_REVISION_ID(CFG_REVISION_ID),
	.CFG_PROGIF(CFG_PROGIF),
	.CFG_SUBCLASS(CFG_SUBCLASS),
	.CFG_CLASS(CFG_CLASS),
	.CFG_CACHE_LINE_SIZE(CFG_CACHE_LINE_SIZE),
	.CFG_MIN_GRANT(CFG_MIN_GRANT),
	.CFG_MAX_LATENCY(CFG_MAX_LATENCY),
	.CFG_IRQ_LINE(CFG_IRQ_LINE)
)
ucfg1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.irq_i(1'b0),
	.irq_o(),
	.cs_config_i(cs_config), 
	.we_i(we),
	.sel_i(sel),
	.adr_i(adr),
	.dat_i(dat),
	.dat_o(cfg_out),
	.cs_bar0_o(cs_bar0),
	.cs_bar1_o(),
	.cs_bar2_o(),
	.irq_en_o()
);

always_ff @(posedge clk_i)
	if (cs & we_i) begin
		$display ("%d %h: wrote to scratchmem: %h=%h:%h", $time, ip, adr_i, dat_i, sel_i);
		/*
		if (adr_i[14:3]==15'h3e9 && dat_i==64'h00) begin
		  $display("3e9=00");
		  $finish;
		end
		*/
	end

wire pe_cs;
edge_det u1(.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(cs), .pe(pe_cs), .ne(), .ee() );

reg [14:0] ctr;
always_ff @(posedge clk_i)
if (rst_i)
	cnt <= 'd0;
else begin
	if (pe_cs) begin
		if (cti_i==3'b000)
			ctr <= adr_i[17:4];
		else
			ctr <= adr_i[17:4] + 12'd1;
		cnt <= 'd0;
	end
	else if (cs && cnt!=blen_i+2'd1 && cti_i!=3'b000) begin
		ctr <= ctr + 2'd1;
		cnt <= cnt + 2'd1;
	end
end

always_ff @(posedge clk_i)
	radr <= pe_cs ? adr_i[17:4] : ctr;
always_ff @(posedge clk_i)
	bndxd1 <= tid_i;

//assign dat_o = cs ? {smemH[radr],smemG[radr],smemF[radr],smemE[radr],
//				smemD[radr],smemC[radr],smemB[radr],smemA[radr]} : 64'd0;
reg [11:0] spr;
always_ff @(posedge clk_i)
	spr <= sp[17:4];

always_ff @(posedge clk_i)
begin
//	datod <= rommem[radr];
	bndxd <= bndxd1;
	adr1 <= adrd;
	/*
	if (!we_i & cs)
		$display("%d %h: read from scratchmem: %h=%h", $time, ip, radr, rommem[radr]);
	*/
//	$display("-------------- Stack --------------");
//	for (n = -6; n < 8; n = n + 1) begin
//		$display("%c%c %h %h", n==0 ? "-": " ", n==0 ?">" : " ",spr + n, rommem[spr+n]);
//	end
end


   // xpm_memory_spram: Single Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_spram #(
      .ADDR_WIDTH_A(14),              // DECIMAL
      .AUTO_SLEEP_TIME(0),           // DECIMAL
      .BYTE_WRITE_WIDTH_A(8),       	// DECIMAL
      .CASCADE_HEIGHT(0),            // DECIMAL
      .ECC_MODE("no_ecc"),           // String
      .MEMORY_INIT_FILE("rom.mem"),     // String
      .MEMORY_INIT_PARAM(""),       // String
      .MEMORY_OPTIMIZATION("true"),  // String
      .MEMORY_PRIMITIVE("block"),     // String
      .MEMORY_SIZE(16384*128),            // DECIMAL
      .MESSAGE_CONTROL(0),           // DECIMAL
      .READ_DATA_WIDTH_A(128),        // DECIMAL
      .READ_LATENCY_A(2),            // DECIMAL
      .READ_RESET_VALUE_A("0"),      // String
      .RST_MODE_A("SYNC"),           // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_MEM_INIT(1),              // DECIMAL
      .USE_MEM_INIT_MMI(0),          // DECIMAL
      .WAKEUP_TIME("disable_sleep"), // String
      .WRITE_DATA_WIDTH_A(128),       // DECIMAL
      .WRITE_MODE_A("read_first"),   // String
      .WRITE_PROTECT(1)              // DECIMAL
   )
   xpm_memory_spram_inst (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(ram_dat_o),       // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .addra(adr2[17:4]),             // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .clka(clk_i),                     // 1-bit input: Clock signal for port A.
      .dina(dati2),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(cs),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(cs|rd_ack),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(1'b0),                // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea({16{we2}}&sel2)           // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );
				
always_comb
	if (cfg_rd_ack)
		dat_o <= cfg_out;
	else if (rd_ack)
		dat_o <= ram_dat_o;
	else
		dat_o <= 'd0;

wire [7:0] tid3;
wire [31:0] adr3;
vtdl #(.WID( 8), .DEP(16)) udlytid (.clk(clk_i), .ce(1'b1), .a(2), .d(tid_i), .q(tid3));
vtdl #(.WID(32), .DEP(16)) udlyadr (.clk(clk_i), .ce(1'b1), .a(2), .d(adr_i), .q(adr3));
always_ff @(posedge clk_i)
	tid_o <= tid3;
always_ff @(posedge clk_i)
	adr_o <= adr3;
/*			
always_ff @(posedge clk_i)
if (rst_i) begin
	tid_o <= 'd0;
	adr_o <= 'd0;
end
else begin
	if (cs_ram) begin
		tid_o <= bndxd;
		adr_o <= adr1;
	end
	else begin
		tid_o <= 'd0;
		adr_o <= 'd0;
	end
*/
	/*
	if (cs_i|rd_ack) begin
		dat_o <= datod;
	end
	else
		dat_o <= 128'd0;
	*/
//end

endmodule
