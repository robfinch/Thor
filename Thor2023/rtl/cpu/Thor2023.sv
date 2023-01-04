
module Thor2023(rst_i, clk_i, );
input rst_i;
input clk_i;

typedef enum logic [7:0] {
	IDLE = 8'd0,
	IFETCH = 8'd2,
	DECODE
} state_t;
state_t state;
state_t state1;
state_t state2;
state_t state3;
state_t state4;

reg [31:0] ir;
reg [95:0] pc;
reg [95:0] sp, usp, ssp;
reg [95:0] regs [0:63];
reg [95:0] rfoa;
reg [95:0] rfob;
reg [191:0] res;
reg [5:0] rfwr;
always_ff @(posedge clk)
begin
	if (rfwr[0]) regs[Rt][15: 0] <= res[15: 0];
	if (rfwr[1]) regs[Rt][31:16] <= res[31:16];
	if (rfwr[2]) regs[Rt][47:32] <= res[47:32];
	if (rfwr[3]) regs[Rt][63:48] <= res[63:48];
	if (rfwr[4]) regs[Rt][79:64] <= res[79:64];
	if (rfwr[5]) regs[Rt][95:80] <= res[95:80];
end

always_comb
	case(Ra)
	6'd00:	rfoa <= 'd0;
	6'd62:	rfoa <= sp;
	6'd63:	rfoa <= pc;
	default:	rfoa <= regs[Ra];
	endcase
always_comb
	case(Rb)
	6'd00:	rfob <= 'd0;
	6'd62:	rfob <= sp;
	6'd63:	rfob <= pc;
	default:	rfob <= regs[Rb];
	endcase

always_ff @(posedge clk)
begin
	rfwr <= d0;
	case(state)
	IFETCH:
		if (!cyc_o) begin
			cyc_o <= 1'b1;
			stb_o <= 1'b1;
			sel_o <= 4'b1111;
			adr_o <= pc;
		end
		else if (ack_i) begin
			cyc_o <= 1'b0;
			stb_o <= 1'b0;
			sel_o <= 4'b0000;
			ir <= dat_i;
			Rt <= dat_i[12: 7];
			Ra <= dat_i[18:13];
			Rb <= dat_i[24:19];
			goto (DECODE);
		end
	DECODE:
		begin
			pc <= pc + 96'd4;
			case(ir[4:0])
			5'd2:
				begin
					case(ir[31:26])
					6'd04:	begin res <= rfoa + rfob; rfwr <= 6'b111111; goto (IFETCH); end
					6'd05:	begin res <= rfoa - rfob; rfwr <= 6'b111111; goto (IFETCH); end
					6'd08:	begin res <= rfoa & rfob; rfwr <= 6'b111111; goto (IFETCH); end
					6'd09:	begin res <= rfoa | rfob; rfwr <= 6'b111111; goto (IFETCH); end
					6'd10:	begin res <= rfoa ^ rfob; rfwr <= 6'b111111; goto (IFETCH); end
					default:	tUnimp();
					endcase
				end
			5'd4:
				begin
					case(ir[31:26])
					6'h20:	tUnimp();
					6'h21:	begin push(ADD); goto (FETCH_IMM32); end
					6'h22:	begin push(ADD); goto (FETCH_IMM64); end
					6'h23:	begin push(ADD); goto (FETCH_IMM96); end
					default:	begin res <= rfoa + {{84{ir[31]}},ir[31:26],ir[24:19]}; goto (IFETCH); end
					endcase
				end
			endcase
		end
		
	FETCH_IMM32:
		if (!cyc_o) begin
			cyc_o <= 1'b1;
			stb_o <= 1'b1;
			sel_o <= 4'b1111;
			adr_o <= pc;
		end
		else if (ack_i) begin
			cyc_o <= 1'b0;
			stb_o <= 1'b0;
			sel_o <= 'd0;
			imm <= {{64{dat_i[31]}},dat_i};
			goto (INC_PC4);
		end

	FETCH_IMM64:
		if (!cyc_o) begin
			cyc_o <= 1'b1;
			stb_o <= 1'b1;
			sel_o <= 4'b1111;
			adr_o <= pc;
		end
		else if (ack_i) begin
			stb_o <= 1'b0;
			imm[31:0] <= dat_i;
			goto (FETCH_IMM64a);
		end
	FETCH_IMM64a:
		if (!stb_o) begin
			stb_o <= 1'b1;
			adr_o <= pc + 4'd4;
		end
		else if (ack_i) begin
			cyc_o <= 1'b0;
			stb_o <= 1'b0;
			sel_o <= 'd0;
			imm[95:32] <= {{64{dat_i[31]}},dat_i};
			goto (INC_PC8);
		end

	FETCH_IMM96:
		if (!cyc_o) begin
			cyc_o <= 1'b1;
			stb_o <= 1'b1;
			sel_o <= 4'b1111;
			adr_o <= pc;
		end
		else if (ack_i) begin
			stb_o <= 1'b0;
			imm[31:0] <= dat_i;
			goto (FETCH_IMM96a);
		end
	FETCH_IMM96a:
		if (!stb_o) begin
			stb_o <= 1'b1;
			adr_o <= pc + 4'd4;
		end
		else if (ack_i) begin
			cyc_o <= 1'b0;
			stb_o <= 1'b0;
			sel_o <= 'd0;
			imm[63:32] <= dat_i;
			goto (FETCH_IMM96b);
		end
	FETCH_IMM96b:
		if (!stb_o) begin
			stb_o <= 1'b1;
			adr_o <= pc + 4'd8;
		end
		else if (ack_i) begin
			cyc_o <= 1'b0;
			stb_o <= 1'b0;
			sel_o <= 'd0;
			imm[95:64] <= dat_i;
			goto (INC_PC12);
		end

	INC_PC4:
		begin
			pc <= pc + 4'd4;
			ret();
		end
	INC_PC8:
		begin
			pc <= pc + 4'd8;
			ret();
		end
	INC_PC12:
		begin
			pc <= pc + 4'd12;
			ret();
		end
	
	ADD:	
		begin
			res <= rfoa + imm;
			rfwr <= 6'b111111;
			goto (IFETCH);
		end
	endcase
	
end

task goto;
input state_t nxt;
begin
	state <= nxt;
end
endtask

task push;
input state_t val;
begin
	state1 <= val;
	state2 <= state1;
	state3 <= state2;
	state4 <= state3;
end
endtask

task ret;
begin
	state <= state1;
	state1 <= state2;
	state2 <= state3;
end
endtask

endmodule
