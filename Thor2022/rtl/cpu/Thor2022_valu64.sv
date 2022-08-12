// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_valu64.sv
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

import Thor2022_pkg::*;

module Thor2022_valu64(ir, m, z, xa, xb, xc, t, res);
input Instruction ir;
input [63:0] m;
input z;
input VecValue xa;
input VecValue xb;
input VecValue xc;
input VecValue t;
output VecValue res;

reg [NLANES-1:0] v2b;
VecValue b2v;
VecValue vcmprss;

genvar g;
generate
	for (g = 0; g < NLANES; g = g + 1)
	always_comb
		if (m[g])
			v2b[g] = xa[g * $bits(Value) + xb[5:0]];
		else if (z)
			v2b[g] = 'd0;
		else
			v2b[g] = t[g];
endgenerate

/*
reg mask;
always_comb
	mask = 64'd1 << xb[5:0];

generate
	for (g = 0; g < NLANES; g = g + 1)
	always_comb
		if (m[g]) begin
			if (ir[31])
				b2v[g * $bits(Value) + $bits(Value)-1:g * $bits(Value)] = {63'd0,xa[g]} << xb[5:0];
			else
				b2v[g * $bits(Value):g * $bits(Value)] = (b2v[g * $bits(Value):g * $bits(Value)] & ~mask) | ({63'd0,xa[g]} << xb[5:0]);
		end
		else if (z)
			b2v[g * $bits(Value) + $bits(Value)-1:g * $bits(Value)] = 'd0;
		else
			b2v[g * $bits(Value) + $bits(Value)-1:g * $bits(Value)] = t[g * $bits(Value) + $bits(Value)-1:g * $bits(Value)];
endgenerate
*/
/*
Value vcmp [0:NLANES-1];
Value vcmpc [0:NLANES-1];
generate
for (g = 0; g < NLANES; g = g + 1)
always_comb
begin
	vcmp[g] = xa[g * 64 + 63:g * 64];
end
endgenerate
integer gv;
generate
for (g = 0; g < NLANES; g = g + 1)
always_comb
begin
	if (g==0)
		gv = 0;
	vcmpc[g] = 'd0;
	if (m[g]) begin
		vcmpc[gv] = vcmp[g];
		gv = gv + 1;
	end
end
endgenerate
generate
for (g = 0; g < NLANES; g = g + 1)
always_comb
begin
	vcmprss[g * $bits(Value) + $bits(Value)-1:g * $bits(Value)] = vcmpc[g];
end
endgenerate
*/


always_comb
	case(ir.any.opcode)
	R1:
		case(ir.r1.func)
//		VCMPRSS:	res <= vcmprss;
		default:	res <= 'd0;
		endcase
	R2:
		case(ir.r3.func)
		V2BITS:		res <= v2b;
//		BITS2V:		res <= b2v;
		VEX:			res <= (xb >> {xa[5:0],6'd0}) & 64'hFFFFFFFFFFFFFFFF;
		VSLLV:		res <= xb << {xa[5:0],6'd0};
		VSRLV:		res <= xb >> {xa[5:0],6'd0};
		default:	res <= 'd0;
		endcase
	default:	res <= 'd0;
	endcase
endmodule

