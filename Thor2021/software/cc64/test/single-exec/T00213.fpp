
extern int printf (const char *, ...);
static void kb_wait_1(void)
{
unsigned long timeout = 2;
do {

(1 ?
printf("timeout=%ld\n", timeout) :
({
int i = 1;
while (1)
while (i--)
some_label:
printf("error\n");
goto some_label;
})
);
timeout--;
} while (timeout);
}

static int global;

static void foo(int i)
{
global+=i;
printf ("g=%d\n", global);
}

static int check(void)
{
printf ("check %d\n", global);
return 1;
}

static void dowhile(void)
{
do {
foo(1);
if (global == 1) {
continue;
} else if (global == 2) {
continue;
}

break;
} while (check());
}

int main (void)
{
int i = 1;
kb_wait_1();


if (0) {
yeah:
printf ("yeah\n");
} else {
printf ("boo\n");
}
if (i--)
goto yeah;


i = 1;
if (0) {
while (i--) {
printf ("once\n");
enterloop:
printf ("twice\n");
}
}
if (i >= 0)
goto enterloop;


i = ({
int j = 1;
if (0) {
while (j--) {
printf ("SEonce\n");
enterexprloop:
printf ("SEtwice\n");
}
}
if (j >= 0)
goto enterexprloop;
j; });


i = 1;
if (0) {
for (i = 1; i--;) {
printf ("once2\n");
enterloop2:
printf ("twice2\n");
}
}
if (i > 0)
goto enterloop2;

i = 1;
if (0) {
do {
printf ("once3\n");
enterloop3:
printf ("twice3\n");
} while (i--);
}
if (i > 0)
goto enterloop3;


i = 41;
switch (i) {
if (0) {
printf ("error\n");
case 42:
printf ("error2\n");
case 41:
printf ("caseok\n");
}
}

i = 41;
switch (i) {
if (0) {
printf ("error3\n");
default:
printf ("caseok2\n");
break;
case 42:
printf ("error4\n");
}
}

dowhile();

return 0;
}

