 
//#define true 1
//#define false 0
#define size 8190
#define sizepl 8191

char	flags[sizepl];

inline(0) foo()
{
	return (42);
}

inline(500) void sieve()
{
	int i,prime,k,count,iter;
	printf("10 iterations\n");
	for(iter=1;iter<= 10;iter++){
		count=0;
		for(i = 0; i<=size;i++)
			flags[i]=true;
		for(i=0;i <= size; i++){
			if(flags[i]){
				prime = i+i+3;
				k=i+prime;
					while(k<=size){
						flags[k] = false;
						k += prime;
						}
					count = count+1;
				}
			}
		}
	printf("\n%d primes\n",count);
}

int
main##__BASEFILE__()
{
	int i;

 i = 47;
	inline(0) int foo1() {
		return 43;
	}
	int sub1(int a, int b) {
		int g, h;
		int sub2(int c, int d) {
			c = c + g + i;
			d = d + h;
			return (c*d);
		}
		g = 2; h = 3;
		return (a+b);
	}
	printf("%d", foo());
	printf("%d", foo1()*8);
	sieve();
}
