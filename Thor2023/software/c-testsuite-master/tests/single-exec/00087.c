struct S
{
	int	(*fptr)();
};

int
foo()
{
	return 0;
}

int
main##__BASEFILE__()
{
	struct S v;
	
	v.fptr = foo;
	return v.fptr();
}

