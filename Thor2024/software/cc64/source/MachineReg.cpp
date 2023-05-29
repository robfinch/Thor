#include "stdafx.h"

MachineReg regs[3072];
MachineReg vregs[3072];

bool MachineReg::IsCalleeSave(int regno)
{
	if (IsTempReg(regno & 0x3ff))
		return (true);
	if (regno == regSP || regno == regFP)
		return (true);
	if (regno == regTP)
		return (true);
	return(false);
}

bool MachineReg::IsPositReg()
{
	return (number >= 2048 && number <= 3071);
}

bool MachineReg::IsFloatReg()
{
	return (number >= 1024 && number <= 2047);
}

bool MachineReg::IsArgReg()
{
	return (::IsArgReg(number & 0x3ff));
};

bool MachineReg::IsArgReg(int regno)
{
	return (::IsArgReg(regno & 0x3ff));
};

void MachineReg::MarkColorable()
{
	int nn;

	for (nn = 0; nn < 3072; nn++) {
		regs[nn].IsColorable = true;
		if (IsArgReg(nn & 0x3ff))
			regs[nn].IsColorable = false;
	}
	regs[0].IsColorable = false;
	regs[1].IsColorable = false;
	regs[2].IsColorable = false;
	regs[regXoffs].IsColorable = false;
	regs[regAsm].IsColorable = false;
	regs[regLR].IsColorable = false;
	regs[regGP1].IsColorable = false;
	regs[regGP].IsColorable = false;
	regs[regFP].IsColorable = false;
	regs[regSP].IsColorable = false;
}

bool MachineReg::ContainsPositConst() {
	if (offset == nullptr)
		return (false);
	return (offset->tp->IsPositType());
};
