`define RR		6'd2
`define MULU		6'd24
`define MULS		6'd25
`define MULUI	6'd12
`define MULSI	6'd13


module Strawberry_mult(rst, clk, ld, ir, a, b, imm, o, done);
parameter IDLE=3'd0;
parameter MULT=3'd1;
parameter FIX_SIGN=3'd2;
input rst;
input clk;
input ld;
input [31:0] ir;
input [31:0] a;
input [31:0] b;
input [31:0] imm;
output [63:0] o;
output done;

reg [31:0] aa, bb;
reg [63:0] o;
reg res_sgn;

reg [2:0] state;

assign done = state==IDLE;

always @(posedge clk)
if (rst)
state <= IDLE;
else begin
case(state)
IDLE:
	if (ld) begin
		state <= MULT;
		case(ir[31:26])
		`RR:	// RR
			case(ir[5:0])
			`MULS:
				begin
					aa <= a[31] ? -a : a;
					bb <= b[31] ? -b : b;
					res_sgn <= a[31] ^ b[31];
				end
			`MULU:
				begin
					aa <= a;
					bb <= b;
					res_sgn <= 1'b0;
				end
			endcase
		`MULSI:
			begin
				aa <= a[31] ? -a : a;
				bb <= imm[31] ? -imm : imm;
				res_sgn <= a[31] ^ b[31];
			end
		`MULUI:
			begin
				aa <= a;
				bb <= imm;
				res_sgn <= 1'b0;
			end
		endcase
	end
MULT:
	begin
		state <= res_sgn ? FIX_SIGN : IDLE;
		o <= aa * bb;
	end
FIX_SIGN:
	begin
		state <= IDLE;
		if (res_sgn)
			o <= -o;
	end
default:	state <= IDLE;
endcase
end

endmodule
