// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2023  Robert Finch, Waterloo
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

module Thor2024_divider(rst, clk, ld, sgn, sgnus, a, b, qo, ro, dvByZr, done, idle);
parameter WID=$bits(value_t);
input clk;
input rst;
input ld;
input sgn;
input sgnus;
input [WID-1:0] a;
input [WID-1:0] b;
output [WID-1:0] qo;
reg [WID-1:0] qo;
output [WID-1:0] ro;
reg [WID-1:0] ro;
output done;
output idle;
output dvByZr;
reg dvByZr;

typedef enum logic [2:0] {
	IDLE = 3'd0,
	DIV1 = 3'd1,
	DIV2 = 3'd2,
	SGN = 3'd3,
	DONE = 3'd4
} div_state_t;
div_state_t state;

reg [WID-1:0] bb;
reg so;
reg [7:0] cnt;
wire cnt_done = cnt==8'd0;
assign done = state==DONE;//||(state==IDLE && !ld);
assign idle = state==IDLE;
reg ce1;
reg [WID-1:0] q;
reg [WID:0] r;
reg b0;
wire [WID-1:0] r1 = b0 ? r - bb : r;

reg ld1;
reg sgn1,sgnus1;
value_t a1, b1;

// register inputs
always_ff @(posedge clk)
begin
	ld1 <= ld;
	a1 <= a;
	b1 <= b;
	sgn1 <= sgn;
	sgnus1 <= sgnus;
end

always_ff @(posedge clk)
if (rst) begin
	bb <= {WID{1'b0}};
	q <= {WID{1'b0}};
	r <= {WID{1'b0}};
	qo <= {WID{1'b0}};
	ro <= {WID{1'b0}};
	cnt <= 8'd0;
	dvByZr <= 1'b0;
	state <= IDLE;
end
else
begin

case(state)
IDLE:	;
DIV1:
	begin
		b0 <= bb <= r;
		state <= DIV2;
	end
DIV2:
	if (!cnt_done) begin
		$display("cnt:%d r1=%h q[63:0]=%h", cnt,r1,q);
		q <= {q[WID-2:0],b0};
		r <= {r1,q[WID-1]};
		cnt <= cnt - 8'd1;
		state <= DIV1;
	end
	else
		state <= SGN;
	// Sign correct output
SGN:
	begin
		$display("cnt:%d r1=%h q[63:0]=%h", cnt,r1,q);
		if (sgn|sgnus) begin
			if (so) begin
				qo <= -q;
				ro <= -r[WID:1];
			end
			else begin
				qo <= q;
				ro <= r[WID:1];
			end
		end
		else begin
			qo <= q;
			ro <= r[WID:1];
		end
		state <= DONE;
	end
DONE:
	state <= IDLE;
default: state <= IDLE;
endcase
	if (ld1) begin
		if (sgn1) begin
			q <= a1[WID-1] ? -a1 : a1;
			bb <= b1[WID-1] ? -b1 : b1;
			so <= a1[WID-1] ^ b1[WID-1];
		end
		else if (sgnus1) begin
			q <= a1[WID-1] ? -a1 : a1;
      bb <= b1;
      so <= a1[WID-1];
		end
		else begin
			q <= a1;
			bb <= b1;
			so <= 1'b0;
			$display("bb=%d", b1);
		end
		dvByZr <= b1=={WID{1'b0}};
		r <= {WID{1'b0}};
		cnt <= WID+1;
		state <= DIV1;
	end
end

endmodule

module Thor2024_divider_tb();
parameter WID=64;
reg rst;
reg clk;
reg ld;
wire done;
wire [WID-1:0] qo,ro;

initial begin
	clk = 1;
	rst = 0;
	#100 rst = 1;
	#100 rst = 0;
	#100 ld = 1;
	#150 ld = 0;
end

always #10 clk = ~clk;	//  50 MHz


Thor2024_divider #(WID) u1
(
	.rst(rst),
	.clk(clk),
	.ld(ld),
	.sgn(1'b1),
	.isDivi(1'b0),
	.a(64'd10005),
	.b(64'd27),
	.qo(qo),
	.ro(ro),
	.dvByZr(),
	.done(done),
	.idle()
);

endmodule

