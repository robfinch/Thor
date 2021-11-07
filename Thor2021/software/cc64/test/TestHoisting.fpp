void TestHoisting(int a, int b, int c, int d)
{
volatile int n;	// prevent n from being assigned a register
int j;

do {
printf("%d", a);
b = 10;
for (j = 0; j < 20; j++) {
d = 15;
c = c + b;
b = 21;
}
d = d + c;
n++;
} while (n < 10);
printf("%d", b);
printf("%d", c);
}

