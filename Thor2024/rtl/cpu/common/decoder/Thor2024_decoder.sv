// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
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

module Thor2024_decoder(instr, db);
input instruction_t [4:0] instr;
output decode_bus_t db;

Thor2024_decode_imm udcimm
(
	.ins(instr),
	.imm(db.imm)
);

Thor2024_decode_Ra udcra
(
	.instr(instr[0]),
	.Ra(db.Ra)
);

Thor2024_decode_Rb udcrb
(
	.instr(instr[0]),
	.Rb(db.Rb)
);

Thor2024_decode_Rc udcrc
(
	.instr(instr[0]),
	.Rc(db.Rc)
);

Thor2024_decode_Rt udcrt
(
	.instr(instr[0]),
	.Rt(db.Rt)
);

Thor2024_decode_Rp udcrp
(
	.instr(instr[0]),
	.Rp(db.Rp)
);

Thor2024_decode_has_imm uhi
(
	.instr(instr[0]),
	.has_imm(db.has_imm)
);

Thor2024_decode_nop unop1
(
	.instr(instr[0]),
	.nop(db.nop)
);

Thor2024_decode_fc ufc1
(
	.instr(instr[0]),
	.fc(db.fc)
);

Thor2024_decode_branch udecbr
(
	.instr(instr[0]),
	.branch(db.br)
);

Thor2024_decode_backbr ubkbr1
(
	.instr(instr[0]),
	.backbr(db.backbr)
);

Thor2024_decode_alu udcalu
(
	.instr(instr[0]),
	.alu(db.alu)
);

Thor2024_decode_alu0 udcalu0
(
	.instr(instr[0]),
	.alu0(db.alu0)
);

Thor2024_decode_mul umul1
(
	.instr(instr[0]),
	.mul(db.mul)
);

Thor2024_decode_mulu umulu1
(
	.instr(instr[0]),
	.mulu(db.mulu)
);

Thor2024_decode_div udiv1
(
	.instr(instr[0]),
	.div(db.div)
);

Thor2024_decode_divu udivu1
(
	.instr(instr[0]),
	.divu(db.divu)
);

Thor2024_decode_mem umem1
(
	.instr(instr[0]),
	.mem(db.mem)
);

Thor2024_decode_load udecld1
(
	.instr(instr[0]),
	.load(db.load)
);

Thor2024_decode_loadz udecldz1
(
	.instr(instr[0]),
	.loadz(db.loadz)
);

Thor2024_decode_store udecst1
(
	.instr(instr[0]),
	.store(db.store)
);

Thor2024_decode_erc udecerc1
(
	.instr(instr[0]),
	.erc(db.erc)
);

Thor2024_decode_pfx udecpfx1
(
	.instr(instr[0]),
	.pfx(db.pfx)
);

Thor2024_decode_fpu ufpu
(
	.instr(instr[0]),
	.fpu(db.fpu)
);

endmodule
