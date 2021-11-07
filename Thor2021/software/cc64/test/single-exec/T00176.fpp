





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



int array[16];


void swap(int a, int b)
{
int tmp  = array[a];
array[a] = array[b];
array[b] = tmp;
}



int partition(int left, int right)
{
int pivotIndex = left;
int pivotValue = array[pivotIndex];
int index = left;
int i;

swap(pivotIndex, right);
for(i = left; i < right; i++)
{
if(array[i] < pivotValue)
{
swap(i, index);
index += 1;
}
}
swap(right, index);

return index;
}


void quicksort(int left, int right)
{
if(left >= right)
return;

int index = partition(left, right);
quicksort(left, index - 1);
quicksort(index + 1, right);
}

int main()
{
int i;

array[0] = 62;
array[1] = 83;
array[2] = 4;
array[3] = 89;
array[4] = 36;
array[5] = 21;
array[6] = 74;
array[7] = 37;
array[8] = 65;
array[9] = 33;
array[10] = 96;
array[11] = 38;
array[12] = 53;
array[13] = 16;
array[14] = 74;
array[15] = 55;

for (i = 0; i < 16; i++)
printf("%d ", array[i]);

printf("\n");

quicksort(0, 15);

for (i = 0; i < 16; i++)
printf("%d ", array[i]);

printf("\n");

return 0;
}



