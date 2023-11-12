import Thor2024pkg::*;

module Thor2024_decode_branch_tgt_src(ins, bts);
input instruction_t ins;
output bts_t bts;

always_comb
	if (fnIsBccR(ins))	
		bts = BTS_REG;
	else if (fnIsBranch(ins))
		bts = BTS_DISP;
	else if (fnIsBsr(ins))
		bts = BTS_BSR;
	else if (fnIsCall(ins))
		bts = BTS_CALL;
	else if (fnIsRti(ins))
		bts = BTS_RTI;
	else if (fnIsRet(ins))
		bts = BTS_RET;
	else
		bts = BTS_NONE;

endmodule
