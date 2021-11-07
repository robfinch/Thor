





typedef unsigned short _Wchart;

typedef int _Ptrdifft;
typedef unsigned int _Sizet;

extern int _Setjmp(int *);










typedef _Sizet size_t;
typedef struct {
unsigned long _Off;	/* system dependent */
} fpos_t;
typedef struct {
unsigned short _Mode;
short _Handle;
unsigned char *_Buf, *_Bend, *_Next;
unsigned char *_Rend, *_Rsave, *_Wend;
unsigned char _Back[2], _Cbuf, _Nback;
char *_Tmpnam;
} FILE;

void clearerr(FILE *);
int fclose(FILE *);
int feof(FILE *);
int ferror(FILE *);
int fflush(FILE *);
int fgetc(FILE *);
int fgetpos(FILE *, fpos_t *);
char *fgets(char *, int, FILE *);
FILE *fopen(const char *, const char *);
int fprintf(FILE *, const char *, ...);
int fputc(int, FILE *);
int fputs(const char *, FILE *);
size_t fread(void *, size_t, size_t, FILE *);
FILE *freopen(const char *, const char *, FILE *);
int fscanf(FILE *, const char *, ...);
int fseek(FILE *, long, int);
int fsetpos(FILE *, const fpos_t *);
long ftell(FILE *);
size_t fwrite(const void *, size_t, size_t, FILE *);
int getc(FILE *);
int getchar(void);
char *gets(char *);
void perror(const char *);
int printf(const char *, ...);
int putc(int, FILE *);
int putchar(int);
int puts(const char *);
int remove(const char *);
int rename(const char *, const char *);
void rewind(FILE *);
int scanf(const char *, ...);
void setbuf(FILE *, char *);
int setvbuf(FILE *, char *, int, size_t);
int sprintf(char *, const char *, ...);
int sscanf(const char *, const char *, ...);
FILE *tmpfile(void);
char *tmpnam(char *);
int ungetc(int, FILE *);
int vfprintf(FILE *, const char *, char *);
int vprintf(const char *, char *);
int vsprintf(char *, const char *, char *);
long _Fgpos(FILE *, fpos_t *);
int _Fspos(FILE *, const fpos_t *, long, int);
extern FILE *_Files[16];



const int a = 0;

struct a {
int a;
};

struct b {
int a;
};

int a_f()
{
return 20;
}

int b_f()
{
return 10;
}

typedef int (*fptr)(int);
int foo(int i)
{
return i;
}

typedef int int_type1;


int main()
{
int i = 0;
signed long int l = 2;
struct b titi;
const int * const ptr;
const char *ti;
int_type1 i2;

i = _Generic(a, int: a_f, const int: b_f)();
printf("%d\n", i);
i = _Generic(a, int: a_f() / 2, const int: b_f() / 2);
printf("%d\n", i);
i = _Generic(ptr, int *:1, int * const:2, default:20);
printf("%d\n", i);
i = _Generic(a, const char *: 1, default: 8, int: 123);;
printf("%d\n", i);
i = _Generic(titi, struct a:1, struct b:2, default:20);
printf("%d\n", i);
i = _Generic(i2, char: 1, int : 0);
printf("%d\n", i);
i = _Generic(a, char:1, int[4]:2, default:5);
printf("%d\n", i);
i = _Generic(17, int :1, int **:2);
printf("%d\n", i);
i = _Generic(17L, int :1, long :2, long long : 3);
printf("%d\n", i);
i = _Generic("17, io", char *: 3, const char *: 1);
printf("%d\n", i);
i = _Generic(ti, const unsigned char *:1, const char *:4, char *:3,
const signed char *:2);
printf("%d\n", i);
printf("%s\n", _Generic(i + 2L, long: "long", int: "int",
long long: "long long"));
i = _Generic(l, long: 1, int: 2);
printf("%d\n", i);
i = _Generic(foo, fptr: 3, int: 4);
printf("%d\n", i);
return 0;
}

