// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_decode_len.sv
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
// 238 LUTs
// ============================================================================

import Thor2024Pkg::*;

module Thor2024_decode_len(ir, len);
input [7:0] ir;
output [5:0] len;

always_comb
casez(ir)
8'b10100000:	len = 5'd08;
8'b10100001:	len = 5'd08;
8'b10100010:	len = 5'd08;
8'b10100101:	len = 5'd08;
8'b10100110:	len = 5'd08;
8'b10100111:	len = 5'd08;
8'b10101???:	len = 5'd08;
8'b?1001111:	len = 5'd08;
8'b?1010111:	len = 5'd08;
8'b?1100001:	len = 5'd08;
8'b?1100011:	len = 5'd08;
8'b?1100100:	len = 5'd08;
8'b?1100111:	len = 5'd08;
8'b?1101000:	len = 5'd08;
8'b?1101001:	len = 5'd08;
8'b?1101011:	len = 5'd08;
8'b?1110101:	len = 5'd08;
8'b11111100:	len = 5'd08;
8'b01111101:	len = 5'd12;
8'b11111101:	len = 5'd16;
8'b?1111110:	len = 5'd20;
default:	len = 5'd04;
endcase
end
endfunction

endmodule
