int a[] = {1, 2, 3, 4};

int
main##__BASEFILE__()
{
	if (sizeof(a) != 4*sizeof(int))
		return 1;
	
	return 0;
}
