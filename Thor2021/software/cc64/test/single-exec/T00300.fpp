unsigned int __mulsi3 (register unsigned int a, register unsigned int b)
{
unsigned int r = 0;
while (a)
{
if (a & 1)
r += b;
a >>= 1;
b <<= 1;
}
return r;
}
