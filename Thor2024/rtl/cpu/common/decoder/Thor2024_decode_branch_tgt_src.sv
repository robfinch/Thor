import Thor2024pkg::*;

module Thor2024_decode_branch_tgt_src(ins, bts);
input instruction_t ins;
output bts_t bts;

always_comb
	if (fnIsBccR(ins))	
		bts = BTS_REG;
	else if (fnIsBranch(fcu_instr))
		bts = BTS_DISP;
	else if (fnIsBsr(fcu_instr))
		bts = BTS_BSR;
	else if (fnIsCall(fcu_instr))
		bts = BTS_CALL;
	else if (fnIsRti(fcu_instr))
		bts = BTS_RTI;
	else if (fnIsRet(fcu_instr))
		bts = BTS_RET;
	else
		bts = BTS_NONE;

endmodule
