











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







void topline(int d, char *p){

*p++ = ' ';
switch(d){



case 0:
case 2:
case 3:
case 5:
case 7:
case 8:
case 9:
*p++ = '_';
break;
default:
*p++=' ';

}
*p++=' ';
}



void midline(int d, char *p){

switch(d){



case 0:
case 4:
case 5:
case 6:
case 8:
case 9:
*p++='|';
break;
default:
*p++=' ';
}
switch(d){



case 2:
case 3:
case 4:
case 5:
case 6:
case 8:
case 9:
*p++='_';
break;
default:
*p++=' ';

}
switch(d){



case 0:
case 1:
case 2:
case 3:
case 4:
case 7:
case 8:
case 9:
*p++='|';
break;
default:
*p++=' ';

}
}



void botline(int d, char *p){


switch(d){



case 0:
case 2:
case 6:
case 8:
*p++='|';
break;
default:
*p++=' ';
}
switch(d){



case 0:
case 2:
case 3:
case 5:
case 6:
case 8:
*p++='_';
break;
default:
*p++=' ';

}
switch(d){



case 0:
case 1:
case 3:
case 4:
case 5:
case 6:
case 7:
case 8:
case 9:
*p++='|';
break;
default:
*p++=' ';

}
}



void print_led(unsigned long x, char *buf)
{

int i=0,n;
static int d[32];




n = ( x == 0L ? 1 : 0 );  /* 0 is a digit, hence a special case */

while(x){
d[n++] = (int)(x%10L);
if(n >= 32)break;
x = x/10L;
}



for(i=n-1;i>=0;i--){
topline(d[i],buf);
buf += 3;
*buf++=' ';
}
*buf++='\n'; /* move teletype to next line */



for(i=n-1;i>=0;i--){
midline(d[i],buf);
buf += 3;
*buf++=' ';
}
*buf++='\n';



for(i=n-1;i>=0;i--){
botline(d[i],buf);
buf += 3;
*buf++=' ';
}
*buf++='\n';
*buf='\0';
}

int main()
{
char buf[5*32];
print_led(1234567, buf);
printf("%s\n",buf);

return 0;
}




