#define x(y) #y

int
main##__BASEFILE__(void)
{
	char *p;
	p = x(hello)  " is better than bye";

	return (*p == 'h') ? 0 : 1;
}
