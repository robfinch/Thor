import Thor2024Mmupkg::*;
import Thor2024pkg::*;

module Thor2024_htable(rst, clk, lookup, update, upte, asid, vadr, pte_o, ack, exc);
input rst;
input clk;
input lookup;
input update;
input SHPTE upte;
input asid_t asid;
input address_t vadr;
output SHPTE pte_o;
output reg ack;
output reg exc;

typedef SHPTE shpte_t;

typedef struct packed {
	shpte_t [7:0] ptes;
} sptg_t;

typedef enum logic [2:0] {
	IDLE = 3'd0,
	LOOKUP1,
	LOOKUP2,
	LOOKUP3,
	UPDATE1,
	EXC
} state_t;
state_t state;

function [11:0] fnHash;
input [11:0] asid;
input [31:0] adr;
begin
	fnHash = {asid[7:0],4'd0} ^ adr[30:19];
end
endfunction

integer nn, n1;

sptg_t ptg;
reg [11:0] radr;
reg [11:0] hash;
reg [2:0] undx,hndx,indx;
reg [31:0] bndx;
reg [11:0] asid_reg;
reg [31:0] vadr_reg;
reg miss;
reg [4:0] miss_cnt;
reg [4:0] upd_cnt;
reg lookup1,update1;
reg ack1,ack2;
wire [7:0] pte_v;
reg active;
reg wea;
sptg_t douta;
shpte_t tpte;

assign pte_v = {douta.ptes[7].v,douta.ptes[6].v,douta.ptes[5].v,douta.ptes[4].v,
	douta.ptes[3].v,douta.ptes[2].v,douta.ptes[1].v,douta.ptes[0].v};

assign ack = ack1|ack2;




   // xpm_memory_spram: Single Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_spram #(
      .ADDR_WIDTH_A(12),              // DECIMAL
      .AUTO_SLEEP_TIME(0),           // DECIMAL
      .BYTE_WRITE_WIDTH_A(576),       // DECIMAL
      .CASCADE_HEIGHT(0),            // DECIMAL
      .ECC_MODE("no_ecc"),           // String
      .MEMORY_INIT_FILE("none"),     // String
      .MEMORY_INIT_PARAM("0"),       // String
      .MEMORY_OPTIMIZATION("true"),  // String
      .MEMORY_PRIMITIVE("auto"),     // String
      .MEMORY_SIZE(576*4096),            // DECIMAL
      .MESSAGE_CONTROL(0),           // DECIMAL
      .READ_DATA_WIDTH_A(576),        // DECIMAL
      .READ_LATENCY_A(2),            // DECIMAL
      .READ_RESET_VALUE_A("0"),      // String
      .RST_MODE_A("SYNC"),           // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_MEM_INIT(1),              // DECIMAL
      .USE_MEM_INIT_MMI(0),          // DECIMAL
      .WAKEUP_TIME("disable_sleep"), // String
      .WRITE_DATA_WIDTH_A(576),       // DECIMAL
      .WRITE_MODE_A("read_first"),   // String
      .WRITE_PROTECT(1)              // DECIMAL
   )
   xpm_memory_spram_inst (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .addra(radr),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A.
      .dina(ptg),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(active),                   // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(active),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(1'b0),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .sleep(1'b0),                  // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wea)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // End of xpm_memory_spram_inst instantiation
				
				
always_comb
begin
	miss = 1'b1;
	hndx = 'd0;
	tpte = 'd0;
	for (nn = 0; nn < 8; nn = nn + 1) begin
		if (douta.ptes[nn].v && douta.ptes[nn].vpn==vadr_reg[31:16] && (douta.ptes[nn].asid==asid_reg[7:0] || douta.ptes[nn].g))
			tpte = douta.ptes[nn];
			hndx = nn;
			miss = 1'b0;
	end
end	

always_comb
begin
	indx = 'd0;
	for (nn = 0; nn < 8; nn = nn + 1) begin
		if (~douta.ptes[nn].v)
			indx = nn;
	end
end

always_ff @(posedge clk)
if (rst) begin
	exc <= 1'b0;
	ack1 <= 1'b0;
	ack2 <= 1'b0;
	miss_cnt <= 'd0;
	upd_cnt <= 'd0;
	active <= 'd0;
	vadr_reg <= 'd0;
	asid_reg <= 'd0;
end
else begin
	ack1 <= 1'b0;
	ack2 <= ack1;
	if (lookup) begin
		lookup1 <= 1'b1;
		vadr_reg <= vadr;
		asid_reg <= asid;
		state <= IDLE;
	end
	if (update) begin
		update1 <= 1'b1;
		vadr_reg <= vadr;
		asid_reg <= asid;
		state <= IDLE;
	end
	case(state)
	IDLE:
		begin
			if (lookup|update)
				hash <= fnHash(asid, vadr);
			else if (lookup1|update1)
				hash <= fnHash(asid_reg, vadr_reg);
			miss_cnt <= 'd0;
			upd_cnt <= 'd0;
			active <= 'd0;
			if (lookup|lookup1|update|update1) begin
				state <= LOOKUP1;
				active <= 1'b1;
			end
		end
	// Quadratic probing.
	LOOKUP1:
		begin
			bndx <= hash + miss_cnt * miss_cnt;
			radr <= hash + miss_cnt * miss_cnt;
			state <= LOOKUP2;
		end
	LOOKUP2:
		begin
 			state <= LOOKUP3;
 		end
 	LOOKUP3:
		if (miss) begin
			miss_cnt <= miss_cnt + 1;
			state <= LOOKUP1;
			// Got a miss on an update cycle, means the translation is not in the table
			// yet, Check if there is a place to put the update translation. Update the
			// table and ack.
			if (update) begin
				if (pte_v==8'hFF)		// Empty slot?
					state <= LOOKUP1;	// No, keep looking.
				else begin
					casez(pte_v)
					8'b0???????:	undx <= 3'd7;
					8'b10??????:	undx <= 3'd6;
					8'b110?????:	undx <= 3'd5;
					8'b1110????:	undx <= 3'd4;
					8'b11110???:	undx <= 3'd3;
					8'b111110??:	undx <= 3'd2;
					8'b1111110?:	undx <= 3'd1;
					8'b11111110:	undx <= 3'd0;
					endcase
					state <= UPDATE1;
				end			
			end
			// Exception on lookup if the translation is not found, or on update if
			// there is no room in the table.
			if (miss_cnt==5'd31) begin
				exc <= 1'b1;
				state <= EXC;
			end
		end
		else begin
 			ptg <= douta;
			// Got a hit on a lookup, means the lookup is done. Pass back the info
			// and ack.
			if (lookup1) begin
				lookup1 <= 'd0;
				pte_o <= tpte;
				ack1 <= 1'b1;
				state <= IDLE;
			end
			// If got a hit on an update, update the table with new info.
			if (update1) begin
				undx <= hndx;
				state <= UPDATE1;
			end
		end
	UPDATE1:
		begin
			ptg <= (ptg & ~({448'd0,{64{1'b1}}} << {undx,6'd0})) | (upte << {undx,6'd0});
			wea <= 1'b1;
			ack1 <= 1'b1;
			state <= IDLE;
		end
	EXC:
		;
	default:
		state <= IDLE;
	endcase
end

endmodule
