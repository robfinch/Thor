int x;
int x = 3;
int x;

int main##__BASEFILE__();

void *
foo()
{
	return &main##__BASEFILE__;
}

int
main##__BASEFILE__()
{
	if (x != 3)
		return 0;

	x = 0;
	return x;
}

