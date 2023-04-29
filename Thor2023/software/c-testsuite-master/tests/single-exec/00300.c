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
	printf("hello world");
	return (foo());
}
