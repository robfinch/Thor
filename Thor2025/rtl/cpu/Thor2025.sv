import Thor2025Pkg::*;

rndx_t alu0_re;

op_src_t alu0_argA_src;
op_src_t alu0_argB_src;
op_src_t alu0_argC_src;
op_src_t alu0_argT_src;
op_src_t alu0_argP_src;

value_t rfo_alu0_argA;
value_t rfo_alu0_argB;
value_t rfo_alu0_argC;
value_t rfo_alu0_argT;
value_t rfo_alu0_argP;
value_t alu0_res;
value_t alu1_res;
value_t fpu0_res;
value_t fcu_res;
value_t load_res;

pregno_t alu0_argA_reg;
pregno_t alu0_argB_reg;
pregno_t alu0_argC_reg;
pregno_t alu0_argT_reg;
pregno_t alu0_argP_reg;

pregno_t alu1_argA_reg;
pregno_t alu1_argB_reg;
pregno_t alu1_argC_reg;
pregno_t alu1_argT_reg;
pregno_t alu1_argP_reg;

pregno_t fpu0_argA_reg;
pregno_t fpu0_argB_reg;
pregno_t fpu0_argC_reg;
pregno_t fpu0_argT_reg;
pregno_t fpu0_argP_reg;

pregno_t fcu_argA_reg;
pregno_t fcu_argB_reg;
pregno_t fcu_argT_reg;

pregno_t load_argA_reg;
pregno_t load_argB_reg;
pregno_t load_argC_reg;
pregno_t load_argT_reg;
pregno_t load_argP_reg;

pregno_t store_argA_reg;
pregno_t store_argB_reg;
pregno_t store_argC_reg;
pregno_t store_argP_reg;

pregno_t [26:0] rf_reg;
value_t [26:0] rfo;

assign rf_reg[0] = alu0_argA_reg;
assign rf_reg[1] = alu0_argB_reg;
assign rf_reg[2] = alu0_argC_reg;
assign rf_reg[3] = alu0_argT_reg;
assign rf_reg[4] = alu0_argP_reg;

assign rf_reg[5] = alu1_argA_reg;
assign rf_reg[6] = alu1_argB_reg;
assign rf_reg[7] = alu1_argC_reg;
assign rf_reg[8] = alu1_argT_reg;
assign rf_reg[9] = alu1_argP_reg;

assign rf_reg[10] = fpu0_argA_reg;
assign rf_reg[11] = fpu0_argB_reg;
assign rf_reg[12] = fpu0_argC_reg;
assign rf_reg[13] = fpu0_argT_reg;
assign rf_reg[14] = fpu0_argP_reg;

assign rf_reg[15] = fcu_argA_reg;
assign rf_reg[16] = fcu_argB_reg;
assign rf_reg[17] = fcu_argT_reg;

assign rf_reg[18] = load_argA_reg;
assign rf_reg[19] = load_argB_reg;
assign rf_reg[20] = load_argC_reg;
assign rf_reg[21] = load_argT_reg;
assign rf_reg[22] = load_argP_reg;

assign rf_reg[23] = store_argA_reg;
assign rf_reg[24] = store_argB_reg;
assign rf_reg[25] = store_argC_reg;
assign rf_reg[26] = store_argP_reg;

assign rfo_alu0_argA = rfo[0];
assign rfo_alu0_argB = rfo[1];
assign rfo_alu0_argC = rfo[2];
assign rfo_alu0_argT = rfo[3];
assign rfo_alu0_argP = rfo[4];

assign rfo_alu1_argA = rfo[5];
assign rfo_alu1_argB = rfo[6];
assign rfo_alu1_argC = rfo[7];
assign rfo_alu1_argT = rfo[8];
assign rfo_alu1_argP = rfo[9];

assign rfo_fpu0_argA = rfo[10];
assign rfo_fpu0_argB = rfo[11];
assign rfo_fpu0_argC = rfo[12];
assign rfo_fpu0_argT = rfo[13];
assign rfo_fpu0_argP = rfo[14];

assign rfo_fcu_argA = rfo[15];
assign rfo_fcu_argB = rfo[16];
assign rfo_fcu_argT = rfo[17];

assign rfo_load_argA = rfo[18];
assign rfo_load_argB = rfo[19];
assign rfo_load_argC = rfo[20];
assign rfo_load_argT = rfo[21];
assign rfo_load_argP = rfo[22];

assign rfo_store_argA = rfo[23];
assign rfo_store_argB = rfo[24];
assign rfo_store_argC = rfo[25];
assign rfo_store_argP = rfo[26];


	alu0_argA_reg <= rob[alu0_re].Ra;
	alu0_argB_reg <= rob[alu0_re].Rb;
	alu0_argC_reg <= rob[alu0_re].Rc;
	alu0_argT_reg <= rob[alu0_re].Rt;
	alu0_argP_reg <= rob[alu0_re].Rp;

	alu1_argA_reg <= rob[alu1_re].Ra;
	alu1_argB_reg <= rob[alu1_re].Rb;
	alu1_argC_reg <= rob[alu1_re].Rc;
	alu1_argT_reg <= rob[alu1_re].Rt;
	alu1_argP_reg <= rob[alu1_re].Rp;

	fpu0_argA_reg <= rob[fpu0_re].Ra;
	fpu0_argB_reg <= rob[fpu0_re].Rb;
	fpu0_argC_reg <= rob[fpu0_re].Rc;
	fpu0_argT_reg <= rob[fpu0_re].Rt;
	fpu0_argP_reg <= rob[fpu0_re].Rp;

	fcu_argA_reg <= rob[fcu_re].Ra;
	fcu_argB_reg <= rob[fcu_re].Rb;
	fcu_argT_reg <= rob[fcu_re].Rt;

	load_argA_reg <= rob[load_re].Ra;
	load_argB_reg <= rob[load_re].Rb;
	load_argC_reg <= rob[load_re].Rc;
	load_argT_reg <= rob[load_re].Rt;
	load_argP_reg <= rob[load_re].Rp;

	store_argA_reg <= rob[store_re].Ra;
	store_argB_reg <= rob[store_re].Rb;
	store_argC_reg <= rob[store_re].Rc;
	store_argP_reg <= rob[store_re].Rp;

Thor2025_regfile3w32r urf1 (
	.rst(rst),
	.clk(clk), 
	.wr0(),
	.wr1(),
	.wr2(),
	.we0(),
	.we1(),
	.we2(),
	.wa0(alu0_Rt),
	.wa1(alu1_Rt),
	.wa2(rf_i2_Rt),
	.i0(alu0_res),
	.i1(alu1_res),
	.i2(rf_i2_res),
	.rclk(clk),
	.ra(rf_reg),
	.o(rfo)
);

// Operand source muxes
					if (alu0_available) begin
						case(alu0_argA_src)
						OP_SRC_REG:	alu0_argA <= rfo_alu0_argA;
						OP_SRC_ALU0: alu0_argA <= alu0_res;
						OP_SRC_ALU1: alu0_argA <= alu1_res;
						OP_SRC_FPU0: alu0_argA <= fpu0_res;
						OP_SRC_FCU:	alu0_argA <= fcu_res;
						OP_SRC_LOAD:	alu0_argA <= load_res;
						default:	alu0_argA <= {2{32'hDEADBEEF}};
						endcase
						case(alu0_argB_src)
						OP_SRC_REG:	alu0_argB <= rfo_alu0_argB;
						OP_SRC_ALU0: alu0_argB <= alu0_res;
						OP_SRC_ALU1: alu0_argB <= alu1_res;
						OP_SRC_FPU0: alu0_argB <= fpu0_res;
						OP_SRC_FCU:	alu0_argB <= fcu_res;
						OP_SRC_LOAD:	alu0_argB <= load_res;
						OP_SRC_IMM:	alu0_argB <= rob[alu0_re].imm;
						default:	alu0_arga <= {2{32'hDEADBEEF}};
						endcase
						case(alu0_argC_src)
						OP_SRC_REG:	alu0_argC <= rfo_alu0_argC;
						OP_SRC_ALU0: alu0_argC <= alu0_res;
						OP_SRC_ALU1: alu0_argC <= alu1_res;
						OP_SRC_FPU0: alu0_argC <= fpu0_res;
						OP_SRC_FCU:	alu0_argC <= fcu_res;
						OP_SRC_LOAD:	alu0_argC <= load_res;
						default:	alu0_argC <= {2{32'hDEADBEEF}};
						endcase
						case(alu0_argT_src)
						OP_SRC_REG:	alu0_argT <= rfo_alu0_argT;
						OP_SRC_ALU0: alu0_argT <= alu0_res;
						OP_SRC_ALU1: alu0_argT <= alu1_res;
						OP_SRC_FPU0: alu0_argT <= fpu0_res;
						OP_SRC_FCU:	alu0_argT <= fcu_res;
						OP_SRC_LOAD:	alu0_argT <= load_res;
						default:	alu0_argT <= {2{32'hDEADBEEF}};
						endcase
						case(alu0_argP_src)
						OP_SRC_REG:	alu0_argP <= rfo_alu0_argP;
						OP_SRC_ALU0: alu0_argP <= alu0_res;
						OP_SRC_ALU1: alu0_argP <= alu1_res;
						OP_SRC_LOAD:	alu0_argP <= load_res;
						default:	alu0_argP <= {2{32'hDEADBEEF}};
						endcase
						alu0_argI	<= rob[alu0_re].a0;
						alu0_ld <= 1'b1;
						alu0_instr <= rob[alu0_re].op;
						alu0_div <= rob[alu0_re].div;
						alu0_pc <= rob[alu0_re].pc;
				    rob[alu0_re].out <= VAL;
				    rob[alu0_re].owner <= Thor2025pkg::ALU0;
			    end
