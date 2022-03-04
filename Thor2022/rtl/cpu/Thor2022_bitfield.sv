// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2022_bitfield.sv
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

module Thor2022_bitfield(ir, a, b, c, o);
input Instruction ir;
input Value a;
input Value b;
input Value c;
output Value o;

reg [127:0] o1, o2, o3;
wire [6:0] mw = c[6:0];
wire [6:0] mb = b[6:0];
wire [6:0] me = c[6:0];
wire [6:0] func = ir[47:41];
Value imm = ir[28:21];
Value mask;
wire [7:0] ffoo;

ffo144 u1 ({16'd0,o1},ffoo);

integer nn, n;
always_comb
	for (nn = 0; nn < $bits(Value); nn = nn + 1)
		mask[nn] <= (nn >= mb) ^ (nn <= me) ^ (me >= mb);

always_comb
begin
	o1 = 'd0;
	o2 = 'd0;
	case(ir.any.opcode)
	BTFLD:
		case(func)
		ANDM:		begin for (n = 0; n < $bits(Value); n = n + 1) o2[n] = mask[n] ?  a[n] : 1'b0; end
		BFCLR:	begin for (n = 0; n < $bits(Value); n = n + 1) o2[n] = mask[n] ?  1'b0 : a[n]; end
		BFSET:	begin for (n = 0; n < $bits(Value); n = n + 1) o2[n] = mask[n] ?  1'b1 : a[n]; end
		BFCHG:	begin for (n = 0; n < $bits(Value); n = n + 1) o2[n] = mask[n] ? ~a[n] : a[n]; end
		BFEXTU:
			begin
				o1 = a >> mb;
				for (n = 0; n < $bits(Value); n = n + 1)
					if (n > mw)
						o2[n] = 1'b0;
					else
						o2[n] = o1[n];
			end
		BFEXT:
			begin
				o1 = {{128{a[127]}},a} >> mb;
				for (n = 0; n < $bits(Value); n = n + 1)
					if (n > mw)
						o2[n] = o1[mw];
					else
						o2[n] = o1[n];
			end
		BFALIGN:
			begin
				o1 = {128'd0,a} << mb;
				for (n = 0; n < $bits(Value); n = n + 1) o2[n] = (mask[n] ? o1[n] : 1'b0);
			end
		BFFFO:
			begin
				for (n = 0; n < $bits(Value); n = n + 1)
					o1[n] = mask[n] ? a[n] : 1'b0;
				o2 = (ffoo==8'd255) ? -64'd1 : ffoo - mb;	// ffoo returns -1 if no one was found
			end
		default:	o2 = 64'd0;
		endcase
	default:	o2 = 64'd0;
	endcase
end

always_comb
	o = o2;

endmodule
