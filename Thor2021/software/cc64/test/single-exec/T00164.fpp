





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



int main()
{
int a;
int b;
int c;
int d;
int e;
int f;
int x;
int y;

a = 12;
b = 34;
c = 56;
d = 78;
e = 0;
f = 1;

printf("%d\n", c + d);
printf("%d\n", (y = c + d));
printf("%d\n", e || e && f);
printf("%d\n", e || f && f);
printf("%d\n", e && e || f);
printf("%d\n", e && f || f);
printf("%d\n", a && f | f);
printf("%d\n", a | b ^ c & d);
printf("%d, %d\n", a == a, a == b);
printf("%d, %d\n", a != a, a != b);
printf("%d\n", a != b && c != d);
printf("%d\n", a + b * c / f);
printf("%d\n", a + b * c / f);
printf("%d\n", (4 << 4));
printf("%d\n", (64 >> 4));

return 0;
}



