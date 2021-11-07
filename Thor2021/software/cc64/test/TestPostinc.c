extern char *func();

int TestPostinc(char *s1, char *s2)
{
	int x;

	*s1++ = *s2++ = *s1++;
	x = func()++;
	return (x);
}
