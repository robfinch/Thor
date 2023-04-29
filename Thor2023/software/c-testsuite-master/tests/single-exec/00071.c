#define X 1
#undef X

#ifdef X
FAIL
#endif

int
main##__BASEFILE__()
{
	return 0;
}
