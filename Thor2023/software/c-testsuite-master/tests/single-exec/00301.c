enum { X = 2 } x;
enum (*1.5) { a, b, c, g, h} Y;

int
foo()
{
	return X * c;
}

int
main##__BASEFILE__()
{
	int x;
	
	x = foo();
	printf("hello world");
	return (x[5:3]);
}
