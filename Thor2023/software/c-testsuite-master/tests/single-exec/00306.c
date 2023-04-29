// Vector mask test

vector
foo(integer me, vector double once)
begin
	integer i;
	vector_mask ma, mb;
	vector float quad vqf;
	float single sf;
	float double df;
//	decimal dd;

	i = 47;
	ma = 0x3f;
	mb = ma + 0x20;
	df = 15.5D;
	vqf = ma(mb(vqf + df) * once);
	return (vqf);
end

integer
main##__BASEFILE__()
begin
	integer i;
	double qf : quad;
	vector vec;

	qf = foo(125, vec);
	i = 47;
	qf = (long double)_Generic(15.3,
		int: i=printf("hello world"),
		long: printf("long"),
		float: printf("float"),
		double: printf("double"),
		long double: qf=4.5Q,//67.25Q,
		default: printf("default")
	);
	return (i);
end
