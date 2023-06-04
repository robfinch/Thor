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

/*

Input matrix M:
    | aa ab ac tx |
M = | ba bb bc ty |
    | ca cb cc tz |

Input point X:
    | x |
X = | y |
    | z |
    | 1 |

Output point X':
     | x' |        | aa*x + ab*y + ac*z + tx |
X' = | y' | = MX = | ba*x + bb*y + bc*z + ty |
     | z' |        | ca*x + cb*y + cc*z + tz |

*/

module Thor2024_transform(rst, clk, op, ld, a, b, o, done);
input rst;
input clk;
input [1:0] op;
input ld;
input value_t a;
input value_t b;
output value_t o;
output reg done;

reg [2:0] dnp;	// done pipe
reg signed [point_width-1:-subpixel_width] x_i;
reg signed [point_width-1:-subpixel_width] y_i;
reg signed [point_width-1:-subpixel_width] z_i;

parameter point_width = 16;
parameter subpixel_width = 16;

reg signed [point_width-1:-subpixel_width] aa;
reg signed [point_width-1:-subpixel_width] ab;
reg signed [point_width-1:-subpixel_width] ac;
reg signed [point_width-1:-subpixel_width] tx;
reg signed [point_width-1:-subpixel_width] ba;
reg signed [point_width-1:-subpixel_width] bb;
reg signed [point_width-1:-subpixel_width] bc;
reg signed [point_width-1:-subpixel_width] ty;
reg signed [point_width-1:-subpixel_width] ca;
reg signed [point_width-1:-subpixel_width] cb;
reg signed [point_width-1:-subpixel_width] cc;
reg signed [point_width-1:-subpixel_width] tz;

reg signed [2*point_width-1:-subpixel_width*2] aax;
reg signed [2*point_width-1:-subpixel_width*2] aby;
reg signed [2*point_width-1:-subpixel_width*2] acz;
reg signed [2*point_width-1:-subpixel_width*2] bax;
reg signed [2*point_width-1:-subpixel_width*2] bby;
reg signed [2*point_width-1:-subpixel_width*2] bcz;
reg signed [2*point_width-1:-subpixel_width*2] cax;
reg signed [2*point_width-1:-subpixel_width*2] cby;
reg signed [2*point_width-1:-subpixel_width*2] ccz;


reg signed [point_width-1:-subpixel_width] p0_x_o;
reg signed [point_width-1:-subpixel_width] p0_y_o;
reg signed               [point_width-1:0] p0_z_o;
reg signed [point_width-1:-subpixel_width] p1_x_o;
reg signed [point_width-1:-subpixel_width] p1_y_o;
reg signed               [point_width-1:0] p1_z_o;
reg signed [point_width-1:-subpixel_width] p2_x_o;
reg signed [point_width-1:-subpixel_width] p2_y_o;
reg signed               [point_width-1:0] p2_z_o;

wire [subpixel_width-1:0] zeroes = 1'b0;

wire signed [2*point_width-1:-subpixel_width*2] x_prime = aax + aby + acz + {tx,zeroes};
wire signed [2*point_width-1:-subpixel_width*2] y_prime = bax + bby + bcz + {ty,zeroes};
wire signed [2*point_width-1:-subpixel_width*2] z_prime = cax + cby + ccz + {tz,zeroes};

wire signed [point_width-1:-subpixel_width] x_prime_trunc = x_prime[point_width-1:-subpixel_width];
wire signed [point_width-1:-subpixel_width] y_prime_trunc = y_prime[point_width-1:-subpixel_width];
wire signed [point_width-1:-subpixel_width] z_prime_trunc = z_prime[point_width-1:-subpixel_width];
reg upd1;

always_comb
	done <= dnp[2];

always_ff @(posedge clk)
if (rst) begin
	upd1 <= 'd0;
  p0_x_o <= 1'b0;
  p0_y_o <= 1'b0;
  p0_z_o <= 1'b0;
  p1_x_o <= 1'b0;
  p1_y_o <= 1'b0;
  p1_z_o <= 1'b0;
  p2_x_o <= 1'b0;
  p2_y_o <= 1'b0;
  p2_z_o <= 1'b0;

  aax <= 1'b0;
  aby <= 1'b0;
  acz <= 1'b0;
  bax <= 1'b0;
  bby <= 1'b0;
  bcz <= 1'b0;
  cax <= 1'b0;
  cby <= 1'b0;
  ccz <= 1'b0;
 
	dnp <= 'd0;
end
else begin
	dnp <= {dnp[1:0],1'b1};
	upd1 <= op==2'd3;
	if (op==2'd3) begin
		case(a[3:0])
		4'd0:	aa <= b[31:0];
		4'd1:	ab <= b[31:0];
		4'd2:	ac <= b[31:0];
		4'd3:	tx <= b[31:0];
		4'd4:	ba <= b[31:0];
		4'd5:	bb <= b[31:0];
		4'd6:	bc <= b[31:0];
		4'd7:	ty <= b[31:0];
		4'd8:	ca <= b[31:0];
		4'd9:	cb <= b[31:0];
		4'd10:	cc <= b[31:0];
		4'd11:	tz <= b[31:0];
		default:	;
		endcase
	end
	if (op==2'd3 && !upd1) begin
		case(a[3:0])
		4'd0:	o <= aa;
		4'd1:	o <= ab;
		4'd2:	o <= ac;
		4'd3:	o <= tx;
		4'd4:	o <= ba;
		4'd5:	o <= bb;
		4'd6:	o <= bc;
		4'd7:	o <= ty;
		4'd8:	o <= ca;
		4'd9:	o <= cb;
		4'd10:	o <= cc;
		4'd11:	o <= tz;
		default:	o <= 'd0;
		endcase
	end
	if (op!=3'd3) begin
		case(op)
		2'd0:	o <= x_o;
		2'd1:	o <= y_o;
		2'd2:	o <= z_o;
		default:	o <= 'd0;
		endcase
	end
	
	if (ld) begin
		x_i = a[31: 0];
		y_i = a[63:32];
		z_i = b[31: 0];
		dnp <= 'd0;
	end

  aax <= aa * x_i;
  aby <= ab * y_i;
  acz <= ac * z_i;
  bax <= ba * x_i;
  bby <= bb * y_i;
  bcz <= bc * z_i;
  cax <= ca * x_i;
  cby <= cb * y_i;
  ccz <= cc * z_i;

	x_o <= x_prime_trunc;
	y_o <= y_prime_trunc;
	z_o <= z_prime_trunc[point_width-1:0];
end

endmodule
