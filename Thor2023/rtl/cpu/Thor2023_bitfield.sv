// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2023_bitfield.sv
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

import Thor2023Pkg::*;

module Thor2023_bitfield(ir, t, a, b, c, o);
input instruction_t ir;
input value_t t;
input value_t a;
input value_t b;
input value_t c;
output value_t o;

reg [127:0] o1, o2, o3;
wire [6:0] mb = ir[39] ? ir[29:23] : b[6:0];
wire [6:0] me = ir[39] ? ir[36:30] : c[6:0];
wire [6:0] mw = me - mb;
value_t mask;
wire [7:0] ffoo;

wire [255:0] shr = {a,a} >> mb;
wire [255:0] shl = a << mb;
wire [255:0] shr2 = {o1,o1} >> mb;

ffo144 u1 ({16'd0,o1},ffoo);

// Generate a mask, allows a field to wrap-around the end of a register.
integer nn, n;
always_comb
	for (nn = 0; nn < $bits(value_t); nn = nn + 1)
		mask[nn] <= (nn >= mb) ^ (nn <= me) ^ (me >= mb);

always_comb
begin
	o1 = 'd0;
	o2 = 'd0;
	case(ir.any.opcode)
	OP_BITFLD:
		case(bitfld_t'(ir.any.sz))
		//ANDM:		begin for (n = 0; n < $bits(Value); n = n + 1) o2[n] = mask[n] ?  a[n] : 1'b0; end
		OP_CLR:	begin for (n = 0; n < $bits(value_t); n = n + 1) o2[n] = mask[n] ?  1'b0 : a[n]; end
		OP_SET:	begin for (n = 0; n < $bits(value_t); n = n + 1) o2[n] = mask[n] ?  1'b1 : a[n]; end
		OP_COM:	begin for (n = 0; n < $bits(value_t); n = n + 1) o2[n] = mask[n] ? ~a[n] : a[n]; end
		OP_EXTU:
			begin
				for (n = 0; n < $bits(value_t); n = n + 1)
					o1 = mask[n] ? a[n] : 1'b0;
				o2 = shr2[127:0]|shr2[255:128];
			end
		OP_EXTS:
			begin
				for (n = 0; n < $bits(value_t); n = n + 1)
					o1 = mask[n] ? a[n] : 1'b0;
				for (n = 0; n < $bits(value_t); n = n + 1)
					o1 = mask[n] ? o1[n] : a[me];
				o2 = shr2[127:0]|shr2[255:128];
			end
		OP_SBX:
			begin
				for (n = 0; n < $bits(value_t); n = n + 1)
					o1 = mask[n] ? a[n] : 1'b0;
				o1 = shr2[127:0]|shr2[255:128];
				for (n = 0; n < $bits(value_t); n = n + 1)
					o2 = (n > mw) ? a[me] : o1[n];
			end
		OP_DEP:
			begin
				o1 = shl[127:0]|shl[255:128];
				for (n = 0; n < $bits(value_t); n = n + 1)
					o2[n] = mask[n] ? o1[n] : t[n];
			end			
		OP_FFO:
			begin
				for (n = 0; n < $bits(value_t); n = n + 1)
					o1[n] = mask[n] ? a[n] : 1'b0;
				o2 = (ffoo==8'd255) ? -128'd1 : ffoo - mb;	// ffoo returns -1 if no one was found
			end
		/*
		BFALIGN:
			begin
				o1 = {128'd0,a} << mb;
				for (n = 0; n < $bits(Value); n = n + 1) o2[n] = (mask[n] ? o1[n] : 1'b0);
			end
		*/
		default:	o2 = 'd0;
		endcase
	default:	o2 = 'd0;
	endcase
end

always_comb
	o = o2;

endmodule
