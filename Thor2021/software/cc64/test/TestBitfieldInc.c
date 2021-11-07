typedef struct _tagTest
{
	unsigned int bf1 : 10;
	unsigned int bf2 : 3;
	unsigned int bf3 : 29;
} TEST;

int main(int x)
{
	TEST a;
	
	a.bf2 = 10;
	
	a.bf2++;
	return (a.bf2);
}
