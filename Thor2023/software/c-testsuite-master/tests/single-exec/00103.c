int
main##__BASEFILE__()
{
	int x;
	void *foo;
	void **bar;
	
	x = 0;
	
	foo = (void*)&x;
	bar = &foo;
	
	return **(int**)bar;
}
