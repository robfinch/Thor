





typedef unsigned short _Wchart;

typedef int _Ptrdifft;
typedef unsigned int _Sizet;

extern int _Setjmp(int *);










typedef _Sizet size_t;
typedef _Wchart wchar_t;
typedef struct {
int quot;
int rem;
} div_t;
typedef struct {
long quot;
long rem;
} ldiv_t;
typedef int _Cmpfun(const void *, const void *);
typedef struct {
unsigned char _State;
unsigned short _Wchar;
} _Mbsave;

void abort(void);
int abs(int);
int atexit(void (*)(void));
double atof(const char *);
int atoi(const char *);
long atol(const char *);
void *bsearch(const void *, const void *,
size_t, size_t, _Cmpfun *);
void *calloc(size_t, size_t);
div_t div(int, int);
void exit(int);
void free(void *);
char *getenv(const char *);
long labs(long);
ldiv_t ldiv(long, long);
void *malloc(size_t);
int mblen(const char *, size_t);
size_t mbstowcs(wchar_t *, const char *, size_t);
int mbtowc(wchar_t *, const char *, size_t);
void qsort(void *, size_t, size_t, _Cmpfun *);
int rand(void);
void *realloc(void *, size_t);
void srand(unsigned int);
double strtod(const char *, char **);
long strtol(const char *, char **, int);
unsigned long strtoul(const char *, char **, int);
int system(const char *);
size_t wcstombs(char *, const wchar_t *, size_t);
int wctomb(char *, wchar_t);
int _Mbtowc(wchar_t *, const char *, size_t, _Mbsave *);
double _Stod(const char *, char **);
unsigned long _Stoul(const char *, char **, int);
int _Wctomb(char *, wchar_t, char *);
extern char _Mbcurmax, _Wcxtomb;
extern _Mbsave _Mbxlen, _Mbxtowc;
extern unsigned long _Randseed;



int N;
int *t;

int
chk(int x, int y)
{
int i;
int r;

for (r=i=0; i<8; i++) {
r = r + t[x + 8*i];
r = r + t[i + 8*y];
if (x+i < 8 & y+i < 8)
r = r + t[x+i + 8*(y+i)];
if (x+i < 8 & y-i >= 0)
r = r + t[x+i + 8*(y-i)];
if (x-i >= 0 & y+i < 8)
r = r + t[x-i + 8*(y+i)];
if (x-i >= 0 & y-i >= 0)
r = r + t[x-i + 8*(y-i)];
}
return r;
}

int
go(int n, int x, int y)
{
if (n == 8) {
N++;
return 0;
}
for (; y<8; y++) {
for (; x<8; x++)
if (chk(x, y) == 0) {
t[x + 8*y]++;
go(n+1, x, y);
t[x + 8*y]--;
}
x = 0;
}
return 0;
}

int
main()
{
t = calloc(64, sizeof(int));
go(0, 0, 0);
if(N != 92)
return 1;
return 0;
}


