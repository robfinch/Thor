void testexcept(int a, int b)
{
	if (a)
		throw (__exception)66;
	if (b)
		throw "Hello World";
	printf("Test over");
}