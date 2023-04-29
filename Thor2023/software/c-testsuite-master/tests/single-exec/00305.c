integer
foo()
begin
	integer i;
	float quad qf;
	float single sf;
	float double df;
	decimal dd;

	i = 47;
	printf("%0d",
		 _Generic(15.5D, 
		 	int: 0,
		 	long: 1, 
		 	float: 2,
		 	double: 3,
		 	long double: 4,
			default: printf("default")
		)
	);
	return (i);
end

integer
bar()
begin
	integer i, x;
	long double qf;

	i = 47;
	x = 10;
	printf("%0d",
	 +switch(x) {
		case 10: 0;
		case 11: 2;
		case 12: 3;
		default: printf("default");
	});
	return (i);
end

integer
main##__BASEFILE__()
begin
	integer i;
	double qf : quad;

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
