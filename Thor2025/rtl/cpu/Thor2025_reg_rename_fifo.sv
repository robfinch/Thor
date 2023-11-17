
module Thor2025_reg_rename(clk,free0,free1,free2,alloc0,alloc1,alloc2,wi1, wo0, wo1, wo2);
parameter PREG = 48;
input clk;
input [5:0] free0;
input [5:0] free1;
input [5:0] free2;
input alloc0;
input alloc1;
input alloc2;
output reg [5:0] wo0;
output reg [5:0] wo1;
output reg [5:0] wo2;

integer n;
reg [PREG-1:0] avail;

initial begin
	avail <= {PREG{1'b1}};
end

wire [5:0] o0, o1, o2;
wire [47:0] unavail0 = 48'd1 << o0;
wire [47:0] unavail1 = 48'd1 << o1;
wire [47:0] unavail2 = 48'd1 << o2;
wire [47:0] avail0 = 48'd1 << free0;
wire [47:0] avail1 = 48'd1 << free1;
wire [47:0] avail2 = 48'd1 << free2;

ffo48 uffo1(avail, o0);
ffo48 uffo2(avail & ~unavail0, o1);
ffo48 uffo3(avail & ~unavail0 & ~unavail1, o2);

always_ff @(posedge clk)
begin
	casez({alloc2,alloc1,alloc0})
	3'b111:
		begin
			wo0 <= o0;
			wo1 <= o1;
			wo2 <= o2;
			avail <= avail & ~(unavail2|unavail1|unavail0);
		end
	3'b110:
		begin
			wo1 <= o0;
			wo2 <= o1;
			avail <= avail & ~(unavail1|unavail0);
		end
	3'b101:
		begin
			wo0 <= o0;
			wo2 <= o1;
			avail <= avail & ~(unavail1|unavail0);
		end
	3'b100:
		begin
			wo2 <= o0;
			avail <= avail & ~unavail0;
		end
	3'b011:
		begin
			wo0 <= o0;
			wo1 <= o1;
			avail <= avail & ~(unavail1|unavail0);
		end
	3'b010:
		begin
			wo1 <= o0;
			avail <= avail & ~unavail0;
		end
	3'b001:
		begin
			wo0 <= o0;
			avail <= avail & ~unavail0;
		end
	3'b000:
		;
	endcase
	avail <= avail|avail2|avail1|avail0;
end

always_ff @(posedge clk)
casez ({push2,push1,pop2,pop1})
4'b0000:	;	// do nothing
4'b0001:	// pop 1
	begin
		wo0 <= mem[0];
		wo1 <= mem[0];
		for (n = 0; n < PREG-1; n = n + 1)
			mem[n] <= mem[n+1];
	end
4'b0010:	// pop 2
4'b0011:	// pop 1 and pop2
	begin
		wo0 <= mem[0];
		wo1 <= mem[1];
		for (n = 0; n < PREG-2; n = n + 1)
			mem[n] <= mem[n+2];
	end
4'b0100:	// push 1
	begin
		for (n = 0; n < PREG-1; n = n + 1)
			mem[n+1] <= mem[n];
		mem[0] <= wi0;
	end
4'b0101:	// push1, pop1
	begin
		wo0 <= wi0;
		wo1 <= wi0;
	end
4'b0110:	// push 1, pop2 = pop1
4'b0111:
	begin
		wo0 <= wi0;
		wo1 <= mem[0];
		for (n = 0; n < PREG-1; n = n + 1)
			mem[n] <= mem[n+1];
	end
4'b1?00:	// push 2
	begin
		for (n = 0; n < PREG-1; n = n + 1)
			mem[n+2] <= mem[n];
		mem[0] <= wi0;
		mem[1] <= wi1;
	end
// push2, pop1 = push1
4'b1?01:
	begin
		for (n = 0; n < PREG-1; n = n + 1)
			mem[n+1] <= mem[n];
		mem[0] <= wi1;
		wo0 <= wi0;
		wo1 <= wi0;
	end
4'b1?1?:	// push2 pop2
	begin
		wo0 <= wi0;
		wo1 <= wi1;
	end
endcase

endmodule
