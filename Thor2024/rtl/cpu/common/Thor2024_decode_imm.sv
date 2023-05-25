// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Thor2024_decode_imm.sv
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

module Thor2024_decode_imm(insn, imma, immb, immc, immd, inc);
parameter WID=32;
input [255:0] insn;
output reg [WID-1:0] imma;
output reg [WID-1:0] immb;
output reg [WID-1:0] immc;
output reg [WID-1:0] immd;
output reg [5:0] inc;

reg [159:0] postfix;

always_comb
begin
	imma = 'd0;
	immb = 'd0;
	immc = 'd0;
	immd = 'd0;
	inc = 6'd04;
	
	casez(insn[7:0])
	8'b?0000000:	begin inc = 6'd04; imma = insn[15:7]; end
	8'b?0000100:	begin inc = 6'd04; immb = {{WID-10{insn[26]}},insn[26:17]}; end
	8'b?0000101:	begin inc = 6'd04; immb = {{WID-10{insn[26]}},insn[26:17]}; end
	8'b?0000110:	begin inc = 6'd04; immb = {{WID-10{insn[26]}},insn[26:17]}; end
	8'b?0000111:	// CSR
		begin
			inc = 6'd08;
			imma = {{WID-28{insn[53]}},insn[53:31],insn[16:12]};
			immb = {{WID-14{1'b0}},insn[30:17]};
		end
	8'b?00010??:	begin inc = 6'd04; immb = {{WID-10{insn[26]}},insn[26:17]}; end
	8'b?0001101:	begin inc = 6'd04; immb = {{WID-10{insn[26]}},insn[26:17]}; end	// MULI
	8'b?0001110:	begin inc = 6'd04; immb = {{WID-10{insn[26]}},insn[26:17]}; end	// DIVI
	8'b?0010101:	begin inc = 6'd04; immb = {{WID-10{insn[26]}},insn[26:17]}; end	// DIVUI
	8'b10100000:	inc = 6'd08;
	8'b10100001:	inc = 6'd08;
	8'b10100010:	inc = 6'd08;
	8'b10100110:	inc = 6'd08;
	8'b10100111:	inc = 6'd08;
	8'b10101???:	inc = 6'd08;
	8'b?0110100:	begin inc = 6'd04; imma = {{WID-25{insn[31]}},insn[31:7]}; end
	8'b?0110101:	begin inc = 6'd04; imma = {{WID-5{1'b0}},insn[11:7]}; immb = {{WID-20{insn[31]}},insn[31:12]}; end
	8'b0011011?:	begin inc = 6'd04; imma = {{WID-19{1'b0}},insn[26:8]}; end	// PUSH / POP
	8'b1011011?:	begin inc = 6'd08; imma = {{WID-51{1'b0}},insn[58:8]}; end
	8'b?0111???:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end
	8'b?1000???:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// LDx
	8'b?1001000:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// LDx
	8'b?1001001:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// LDx
	8'b?1001010:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// LDx
	8'b?1001011:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// LDx
	8'b?1001100:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// LDx
	8'b?1001101:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// LDx
	8'b?1001110:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// LDx
	8'b?1001111:	begin inc = 6'd08; immc = {{WID-24{insn[48]}},insn[48:25]}; end	// LDxX
	8'b?1010000:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// STx
	8'b?1010001:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// STx
	8'b?1010010:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// STx
	8'b?1010011:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// STx
	8'b?1010100:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// STx
	8'b?1010101:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// STx
	8'b?1010110:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// STx
	8'b?1010111:	begin inc = 6'd08; immc = {{WID-24{insn[48]}},insn[48:25]}; end	// STxX
	8'b?1011101:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// DFST
	8'b?1011110:	begin inc = 6'd04; immb = {{WID-8{insn[26]}},insn[26:19]}; end	// PSTS
	8'b?1011111:	begin inc = 6'd08; immc = {{WID-24{insn[48]}},insn[48:25]}; end	// PSTD
	8'b?1100001:	begin inc = 6'd08; immb = insn[48:17]; end
	8'b?1100011:	inc = 6'd08;
	8'b?1100111:	inc = 6'd08;
	8'b?1101000:	inc = 6'd08;
	8'b?1101001:	begin inc = 6'd08; immb = insn[48:17]; end	// PSTI
	8'b?1101011:	begin inc = 6'd08; immb = insn[48:17]; end	// PST3
	8'b?1110000:	begin inc = 6'd04; imma = insn[18:7]; end		// IRQ
	8'b?1110001:	begin inc = 6'd04; imma = insn[26:11]; end	// STOP
	8'b?1110011:	begin inc = 6'd04; imma = insn[26:12]; end	// PFI
	8'b?1110101:	begin inc = 6'd08; imma = insn[63:9]; end		// REGS
	8'b?1111000:	begin inc = 6'd04; imma = insn[25:14]; end	// REP
	8'b?1111001:	begin inc = 6'd04; imma = insn[25:12]; end	// PRED
	8'b11111100:	inc = 6'd08;
	8'b11111101:	inc = 6'd16;
	8'b11111110:	inc = 6'd20;
	8'b?1111111:	inc = 6'd04;
	default:	inc = 6'd04;
	endcase
	
	postfix = insn >> {inc,3'd0};

	case(postfix[7:0])
	// PFX22
	8'b01111100:
		begin
			inc = inc + 6'd4;
			case(postfix[9:8])
			2'b00:	imma = postfix[31:10];
			2'b01:	immb = postfix[31:10];
			2'b10:	immc = postfix[31:10];
			2'b11:	immd = postfix[31:10];
			endcase
		end
	// PFX54
	8'b11111100:
		begin
			inc = inc + 6'd8;
			case(postfix[9:8])
			2'b00:	imma = postfix[63:10];
			2'b01:	immb = postfix[63:10];
			2'b10:	immc = postfix[63:10];
			2'b11:	immd = postfix[63:10];
			endcase
		end
	// PFX86
	8'b01111101:
		begin
			inc = inc + 6'd12;
			case(postfix[9:8])
			2'b00:	imma = postfix[95:10];
			2'b01:	immb = postfix[95:10];
			2'b10:	immc = postfix[95:10];
			2'b11:	immd = postfix[95:10];
			endcase
		end
	// PFX118
	8'b11111101:
		begin
			inc = inc + 6'd16;
			case(postfix[9:8])
			2'b00:	imma = postfix[127:10];
			2'b01:	immb = postfix[127:10];
			2'b10:	immc = postfix[127:10];
			2'b11:	immd = postfix[127:10];
			endcase
		end
	// PFX150
	8'b01111110:
		begin
			inc = inc + 6'd20;
			case(postfix[9:8])
			2'b00:	imma = postfix[159:10];
			2'b01:	immb = postfix[159:10];
			2'b10:	immc = postfix[159:10];
			2'b11:	immd = postfix[159:10];
			endcase
		end
	endcase
		
end

endmodule
