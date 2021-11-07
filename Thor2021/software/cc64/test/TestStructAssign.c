typedef struct
{
	int i;
	char ch;
	float f;
} UT;

UT a = {21,'h',0.0};
UT b = {16,'i',42.5};

int TestStructAssign()
{
	UT c, d;
	
	c = (UT){10,'k',21.5};
	c = d;
	return (b.f + a.i);
}