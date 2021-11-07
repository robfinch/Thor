





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





typedef long I;
typedef struct{I c[4];I b,e,k;} PT;

PT cases[] = {
((I)4194304L +(I)2097152L +(I)67108864L), (I)262144L, (((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L), -1L, 1,2,1,
+(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L), 2,3,2,
((I)4194304L +(I)2097152L +(I)67108864L)+( (I)524288L +(I)262144L +(((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L)), (((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(
I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L), (I)262144L, (((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)
131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L), 1,3,2,
((I)4194304L +(I)2097152L +(I)67108864L)+( (I)524288L +(I)262144L +(((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L)), (I)262144L +(((I)1L +(I)256L +(I)4L +(I)8
L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L), (I)524288L, -1L, 1,2,1,
((I)4194304L +(I)2097152L +(I)67108864L)+( (I)524288L +(I)262144L +(((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L)), (I)262144L +(((I)1L +(I)256L +(I)4L +(I)8
L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L), (I)1048576L, (I)262144L +(((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192
L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L), 1,3,1,
((I)4194304L +(I)2097152L +(I)67108864L)+( (I)524288L +(I)262144L +(((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L)), (I)262144L +(((I)1L +(I)256L +(I)4L +(I)8
L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L), (I)262144L, (I)262144L, 1,3,1,
262144L +(((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L)), -1L, 1,2,1,
(I)33554432L +(((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L), (I)2097152L, ((I)1048576L +(I)524288L +(I)262144L +(((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)6
4L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L)), -1L, 0,2,1,
(I)67108864L, ((I)1048576L +(I)524288L +(I)262144L +(((I)1L +(I)256L +(I)4L +(I)8L +(I)16L +(I)64L +(I)128L +(I)268435456L +(I)536870912L +(I)1024L +(I)4096L +(I)8192L +(I)16384L)+((I)2L +(I)131072L +(I)2048L)+(I)32L +(I)32768L +(I)65536L)), (I)134217728L, -1L, 0,2,0,
};

int main() {
int i, j;

for(j=0; j < sizeof(cases)/sizeof(cases[0]); j++) {
for(i=0; i < sizeof(cases->c)/sizeof(cases->c[0]); i++)
printf("cases[%d].c[%d]=%ld\n", j, i, cases[j].c[i]);

printf("cases[%d].b=%ld\n", j, cases[j].b);
printf("cases[%d].e=%ld\n", j, cases[j].e);
printf("cases[%d].k=%ld\n", j, cases[j].k);
printf("\n");
}
return 0;
}

