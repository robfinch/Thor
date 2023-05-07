
import Thor2023Pkg::*;

module Thor2023_mult(rst, clk, ld, mul, mulu, mulsu, clmul, a, b, o, done);
parameter IDLE=3'd0;
parameter MULT=3'd1;
parameter FIX_SIGN=3'd2;
input rst;
input clk;
input ld;
input mul;
input mulu;
input mulsu;
input clmul;
input value_t a;
input value_t b;
output double_value_t o;
output done;

value_t aa;
double_value_t bb;
reg res_sgn;
reg clmul;
reg [2:0] state;
reg [6:0] msb;

assign done = state==IDLE;

always_ff @(posedge clk, posedge rst)
if (rst)
	state <= IDLE;
else begin
	case(state)
	SIGN:
		begin
			state <= MULT;
			if (mul) begin
				aa <= a[msb] ? -a : a;
				bb <= b[msb] ? -b : b;
				res_sgn <= a[msb] ^ b[msb];
			end
			else if (mulu|clmul) begin
				aa <= a;
				bb <= b;
				res_sgn <= 1'b0;
			end
			else if (mulsu) begin
				aa <= a[msb] ? -a : a;
				bb <= b;
				res_sgn <= a[msb];
			end
		end
	MULT:
		begin
			bb <= bb << 2'd1;
			aa <= aa >> 2'd1;
			if (aa[0]) begin
				if (clmul)
					o <= o ^ bb;
				else
					o <= o + bb;
			end
			ctr <= ctr + 2'd1;
			if (ctr==msb)
				state <= res_sgn ? FIX_SIGN : IDLE;
		end
	FIX_SIGN:
		begin
			state <= IDLE;
			if (res_sgn)
				o <= -o;
		end
	IDLE:
		done <= 1'b1;
	default:	state <= IDLE;
	endcase
	if (ld) begin
		state <= SIGN;
		done <= 1'b0;
		o <= 'd0;
		case(ir.any.sz)
		3'd0:	msb <= 7'd7;
		3'd1: msb <= 7'd15;
		3'd2: msb <= 7'd31;
		3'd3: msb <= 7'd63;
		default: msb <= 7'd127;
		endcase
	end
end

endmodule
