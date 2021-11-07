
















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







int A[4], B[4], C[4];

void Hanoi(int,int*,int*,int*);


void PrintAll()
{
int i;

printf("A: ");
for(i=0;i<4;i++)printf(" %d ",A[i]);
printf("\n");

printf("B: ");
for(i=0;i<4;i++)printf(" %d ",B[i]);
printf("\n");

printf("C: ");
for(i=0;i<4;i++)printf(" %d ",C[i]);
printf("\n");
printf("------------------------------------------\n");
return;
}



int Move(int *source, int *dest)
{
int i = 0, j = 0;

while (i<4 && (source[i])==0) i++;
while (j<4 && (dest[j])==0) j++;

dest[j-1] = source[i];
source[i] = 0;
PrintAll();       /* Print configuration after each move. */
return dest[j-1];
}



void Hanoi(int n,int *source, int *dest, int *spare)
{
int i;
if(n==1){
Move(source,dest);
return;
}

Hanoi(n-1,source,spare,dest);
Move(source,dest);
Hanoi(n-1,spare,dest,source);
return;
}

int main()
{
int i;


for(i=0;i<4;i++)A[i]=i+1;
for(i=0;i<4;i++)B[i]=0;
for(i=0;i<4;i++)C[i]=0;

printf("Solution of Tower of Hanoi Problem with %d Disks\n\n",4);


printf("Starting state:\n");
PrintAll();
printf("\n\nSubsequent states:\n\n");


Hanoi(4,A,B,C);

return 0;
}



