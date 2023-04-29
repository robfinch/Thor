extern __cdecl printf(char *, ...);
integer tick;

// Do not push r0 or sp
__machine interrupt(0xFFFFFFFA)
foo()
begin
	tick = tick + 1;	
end

integer
main##__BASEFILE__()
begin
	integer i;
	double qf : quad;
	vector vec;

//	qf = foo2 (125, vec);
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
