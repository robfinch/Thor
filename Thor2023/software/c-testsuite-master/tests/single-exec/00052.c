int
main##__BASEFILE__()
{
	struct T { int x; };
	{
		struct T s;
		s.x = 0;
		return s.x;
	}
}
