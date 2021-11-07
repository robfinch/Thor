struct A
{
unsigned  char l[2];
unsigned  char m;
unsigned  char n;
} globa;

int test0( register int aaa )
{
int ss = 34;
globa.m = ss + globa.l[0] + globa.l[1] + aaa;
return globa.m;
}

int test00( struct A *a, int aaa )
{
int ss = 34;
a->m = ss + a->l[0] + a->l[1] + aaa;
return a->m;
}
