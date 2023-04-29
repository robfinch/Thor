typedef struct { int x; int y; } s;

s v;

integer
main##__BASEFILE__()
{
	v.x = 1;
	v.y = 2;
	return 3 - v.x - v.y;
}

