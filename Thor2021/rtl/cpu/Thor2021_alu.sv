import Thor2021_pkg::*;


module Thor2021_alu64(ir, step, m, z, a, b, c, imm, t, o, cause, crypto_en, bf_en);
parameter WID=64;
input Instruction ir;
input [5:0] step;
input m;
input z;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] c;
input [WID-1:0] imm;
input [WID-1:0] t;
output reg [WID-1:0] o;
output reg [7:0] cause;
input crypto_en;
input bf_en;

wire [127:0] sllo = a << b[5:0];
wire [127:0] srlo = {a,64'd0} >> b[5:0];
wire [127:0] srao = {{64{a[63]}},a} >> b[5:0];
wire M = m | ~ir.any.v;
reg [WID-1:0] o1;
wire [WID-1:0] ocrypto;
wire [WID-1:0] bfldo;

Thor2021_bitfield ubfld
(
	.ir(ir),
	.a(a),
	.b(b),
	.c(c),
	.o(bfldo)
);

Thor2021_crypto ucrypto
(
	.ir(ir),
	.m(m & crypto_en),
	.z(z | ~crypto_en),
	.a(a),
	.b(b),
	.c(c),
	.t(t),
	.o(ocrypto)
);

always_comb
begin
cause = FLT_NONE;
case(ir.any.opcode)
R1:
	case(ir.r1.func)
	ABS:	o1 = M ? ($signed(a) < 0 ? -a : a) : z ? 64'd0 : t;
	V2BITS:
		if (step==6'd0)
			o1 = {63'd0,a[0]};
		else
			o1 = t | ({63'd0,a[0]} << step);
	BITS2V:
		o1 = {63'd0,a[step]};
	default:	o1 = 64'd0;
	endcase
R2:
	case(ir.r2.func)
	ADD:
		begin
			o1 = M ? a + b : z ? 64'd0 : t;
			if (ir[29] & (o1[63] ^ b[63]) & (1'b1 ^ a[63] ^ b[63]))
				cause = FLT_OFL;
		end
	SUBF:	o1 = M ? b - a : z ? 64'd0 : t;
	AND:	o1 = M ? a & b : z ? 64'd0 : t;
	OR:		o1 = M ? a | b : z ? 64'd0 : t;
	XOR:	o1 = M ? a ^ b : z ? 64'd0 : t;
	ORC:	o1 = M ? a | ~b : z ? 64'd0 : t;
	NAND:	o1 = M ? ~(a & b) : z ? 64'd0 : t;
	NOR:	o1 = M ? ~(a | b) : z ? 64'd0 : t;
	XNOR:	o1 = M ? ~(a ^ b) : z ? 64'd0 : t;
	ANDC:	o1 = M ? a & ~b : z ? 64'd0 : t;
	CMP:	o1 = M ? ($signed(a) < $signed(b) ? -64'd1 : a==b ? 64'd0 : 64'd1) : z ? 64'd0 : t;
	SLL:	o1 = M ? sllo[63:0] : z ? 64'd0 : t;
	SRL:	o1 = M ? srlo[127:64] : z ? 64'd0 : t;
	SRA:	o1 = M ? srao[63:0] : z ? 64'd0 : t;
	ROL:	o1 = M ? sllo[63:0]|sllo[127:64] : z ? 64'd0 : t;
	ROR:	o1 = M ? srlo[127:64]|srlo[63:0] : z ? 64'd0 : t;
	SEQ:	o1 = M ? a == b : z ? 64'd0 : t;
	SNE:	o1 = M ? a != b : z ? 64'd0 : t;
	SLT:	o1 = M ? $signed(a) < $signed(b) : z ? 64'd0 : t;
	SGE:	o1 = M ? $signed(a) >= $signed(b) : z ? 64'd0 : t;
	SLTU:	o1 = M ? a < b : z ? 64'd0 : t;
	SGEU:	o1 = M ? a >= b : z ? 64'd0 : t;
	MIN:	o1 = M ? ( $signed(a) < $signed(b) ? a : b) : z ? 64'd0 : t;
	MAX:	o1 = M ? ( $signed(a) > $signed(b) ? a : b) : z ? 64'd0 : t;
	default:	o1 = 64'd0;
	endcase
R3:
	case(ir.r3.func)
	default:	o1 = 64'd0;
	endcase
ADDI:		o1 = M ? a + imm : z ? 64'd0 : t;
SUBFI:	o1 = M ? imm - a : z ? 64'd0 : t;
ANDI:		o1 = M ? a & imm : z ? 64'd0 : t;
ORI:			o1 = M ? a | imm : z ? 64'd0 : t;
XORI:		o1 = M ? a ^ imm : z ? 64'd0 : t;
CMPI:		o1 = M ? ($signed(a) < $signed(imm) ? -64'd1 : a==imm ? 64'd0 : 64'd1) : z ? 64'd0 : t;
SEQI:		o1 = M ? a == imm : z ? 64'd0 : t;
SNEI:		o1 = M ? a != imm : z ? 64'd0 : t;
SLTI:		o1 = M ? $signed(a) < $signed(imm) : z ? 64'd0 : t;
BTFLD:		o1 = M & bf_en ? bfldo : z | ~bf_en ? 64'd0 : t;
default:	o1 = 64'd0;
endcase
end

always_comb
begin
	o = o1|ocrypto;
end

endmodule

module Thor2021_alu(ir, step, m, z, a, b, c, imm, t, o, crypto_en, bf_en);
parameter WID=64;
input Instruction ir;
input [5:0] step;
input [7:0] m;
input z;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] c;
input [WID-1:0] imm;
input [WID-1:0] t;
output reg [WID-1:0] o;
input crypto_en;
input bf_en;

reg [WID-1:0] sum, subf, ando, oro, xoro;

integer n;

genvar g;
generate begin : gAlu
for (g = 0; g < WID/64; g = g + 1)
	Thor2021_alu64 u1 (
			ir,
			step,
			m[g],
			z,
			a[g*64+63:g*64],
			b[g*64+63:g*64],
			c[g*64+63:g*64],
			imm,
			t[g*64+63:g*64],
			o[g*64+63:g*64],
			crypto_en,
			bf_en
		);
end
endgenerate

endmodule
