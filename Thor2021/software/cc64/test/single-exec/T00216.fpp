typedef unsigned char u8;
typedef struct {} empty_s;
struct contains_empty {
u8 a;
empty_s empty;
u8 b;
};
struct contains_empty ce = { { (1) }, (empty_s){}, 022, };

struct SS {u8 a[3], b; };
struct SS sinit16[] = { { 1 }, 2 };
struct S
{
u8 a,b;
u8 c[2];
};

struct T
{
u8 s[16];
u8 a;
};

struct U
{
u8 a;
struct S s;
u8 b;
struct T t;
};

struct V
{
struct S s;
struct T t;
u8 a;
};

struct W
{
struct V t;
struct S s[];
};

struct S gs = ((struct S){1, 2, 3, 4});
struct S gs2 = {1, 2, {3, 4}};
struct T gt = {"hello", 42};
struct U gu = {3, 5,6,7,8, 4, "huhu", 43};
struct U gu2 = {3, {5,6,7,8}, 4, {"huhu", 43}};

struct U gu3 = { {3}, {5,6,7,8,}, 4, {"huhu", 43}};

struct U gu4 = { 3, {5,6,7,},  5, { "bla", {44}} };

struct S gs3 = { (1), {(2)}, {(((3))), {4}}};

struct V gv = {{{3},4,{5,6}}, "haha", (u8)45, 46};

struct V gv2 = {(struct S){7,8,{9,10}}, {"hihi", 47}, 48};

struct V gv3 = {((struct S){7,8,{9,10}}), {"hoho", 49}, 50};

struct W gw = {{1,2,3,4}, {1,2,3,4,5}};

union UU {
u8 a;
u8 b;
};
struct SU {
union UU u;
u8 c;
};
struct SU gsu = {5,6};


union UV {
struct {u8 a,b;};
struct S s;
};
union UV guv = {{6,5}};
union UV guv2 = {{.b = 7, .a = 8}};
union UV guv3 = {.b = 8, .a = 7};


struct S s;
};
struct Anon gan = { 10, 11 }; // ... which makes it available here.
union UV2 guv4 = {{4,3}};     // and the other inits from above as well


struct in6_addr {
union {
u8 u6_addr8[16];
unsigned short u6_addr16[8];
} u;
};
struct flowi6 {
struct in6_addr saddr, daddr;
};
struct pkthdr {
struct in6_addr daddr, saddr;
};
struct pkthdr phdr = { { { 6,5,4,3 } }, { { 9,8,7,6 } } };

struct Wrap {
void *func;
};
int global;
void inc_global (void)
{
global++;
}

struct Wrap global_wrap[] = {
((struct Wrap) {inc_global}),
inc_global,
};







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


void print_ (const char *name, const u8 *p, long size)
{
printf ("%s:", name);
while (size--) {
printf (" %x", *p++);
}
printf ("\n");
}
void foo (struct W *w, struct pkthdr *phdr_)
{
struct S ls = {1, 2, 3, 4};
struct S ls2 = {1, 2, {3, 4}};
struct T lt = {"hello", 42};
struct U lu = {3, 5,6,7,8, 4, "huhu", 43};
struct U lu1 = {3, ls, 4, {"huhu", 43}};
struct U lu2 = {3, (ls), 4, {"huhu", 43}};
const struct S *pls = &ls;
struct S ls21 = *pls;
struct U lu22 = {3, *pls, 4, {"huhu", 43}};

struct U lu21 = {3, ls, 4, "huhu", 43};

struct U lu3 = { 3, {5,6,7,8,}, 4, {"huhu", 43}};

struct U lu4 = { 3, {5,6,7,},  5, { "bla", 44} };

struct S ls3 = { (1), (2), {(((3))), 4}};

struct V lv = {{3,4,{5,6}}, "haha", (u8)45, 46};

struct V lv2 = {(struct S)w->t.s, {"hihi", 47}, 48};

struct V lv3 = {((struct S){7,8,{9,10}}), ((const struct W *)w)->t.t, 50};
const struct pkthdr *phdr = phdr_;
struct flowi6 flow = { .daddr = phdr->daddr, .saddr = phdr->saddr };
int elt = 0x42;

struct T lt2 = { { [1 ... 5] = 9, [6 ... 10] = elt, [4 ... 7] = elt+1 }, 1 };
print_("ls", (u8*)&ls, sizeof (ls));
print_("ls2", (u8*)&ls2, sizeof (ls2));
print_("lt", (u8*)&lt, sizeof (lt));
print_("lu", (u8*)&lu, sizeof (lu));
print_("lu1", (u8*)&lu1, sizeof (lu1));
print_("lu2", (u8*)&lu2, sizeof (lu2));
print_("ls21", (u8*)&ls21, sizeof (ls21));
print_("lu21", (u8*)&lu21, sizeof (lu21));
print_("lu22", (u8*)&lu22, sizeof (lu22));
print_("lu3", (u8*)&lu3, sizeof (lu3));
print_("lu4", (u8*)&lu4, sizeof (lu4));
print_("ls3", (u8*)&ls3, sizeof (ls3));
print_("lv", (u8*)&lv, sizeof (lv));
print_("lv2", (u8*)&lv2, sizeof (lv2));
print_("lv3", (u8*)&lv3, sizeof (lv3));
print_("lt2", (u8*)&lt2, sizeof (lt2));
print_("flow", (u8*)&flow, sizeof (flow));
}

void test_compound_with_relocs (void)
{
struct Wrap local_wrap[] = {
((struct Wrap) {inc_global}),
inc_global,
};
void (*p)(void);
p = global_wrap[0].func; p();
p = global_wrap[1].func; p();
p = local_wrap[0].func; p();
p = local_wrap[1].func; p();
}

void sys_ni(void) { printf("ni\n"); }
void sys_one(void) { printf("one\n"); }
void sys_two(void) { printf("two\n"); }
void sys_three(void) { printf("three\n"); }
typedef void (*fptr)(void);
const fptr table[3] = {
[0 ... 2] = &sys_ni,
[0] = sys_one,
[1] = sys_two,
[2] = sys_three,
};

void test_multi_relocs(void)
{
int i;
for (i = 0; i < sizeof(table)/sizeof(table[0]); i++)
table[i]();
}



struct SEA { int i; int j; int k; int l; };
struct SEB { struct SEA a; int r[1]; };
struct SEC { struct SEA a; int r[0]; };
struct SED { struct SEA a; int r[]; };

static void
test_correct_filling (struct SEA *x)
{
static int i;
if (x->i != 0 || x->j != 5 || x->k != 0 || x->l != 0)
printf("sea_fill%d: wrong\n", i);
else
printf("sea_fill%d: okay\n", i);
i++;
}

int
test_zero_init (void)
{

struct SEB b = { .a.j = 5 };
struct SEC c = { .a.j = 5 };
struct SED d = { .a.j = 5 };
test_correct_filling (&b.a);
test_correct_filling (&c.a);
test_correct_filling (&d.a);
return 0;
}

int main()
{
print_("ce", (u8*)&ce, sizeof (ce));
print_("gs", (u8*)&gs, sizeof (gs));
print_("gs2", (u8*)&gs2, sizeof (gs2));
print_("gt", (u8*)&gt, sizeof (gt));
print_("gu", (u8*)&gu, sizeof (gu));
print_("gu2", (u8*)&gu2, sizeof (gu2));
print_("gu3", (u8*)&gu3, sizeof (gu3));
print_("gu4", (u8*)&gu4, sizeof (gu4));
print_("gs3", (u8*)&gs3, sizeof (gs3));
print_("gv", (u8*)&gv, sizeof (gv));
print_("gv2", (u8*)&gv2, sizeof (gv2));
print_("gv3", (u8*)&gv3, sizeof (gv3));
print_("sinit16", (u8*)&sinit16, sizeof (sinit16));
print_("gw", (u8*)&gw, sizeof (gw));
print_("gsu", (u8*)&gsu, sizeof (gsu));
print_("guv", (u8*)&guv, sizeof (guv));
print_("guv.b", (u8*)&guv.b, sizeof (guv.b));
print_("guv2", (u8*)&guv2, sizeof (guv2));
print_("guv3", (u8*)&guv3, sizeof (guv3));
print_("phdr", (u8*)&phdr, sizeof (phdr));
foo(&gw, &phdr);

test_compound_with_relocs();
test_multi_relocs();
test_zero_init();
return 0;
}

