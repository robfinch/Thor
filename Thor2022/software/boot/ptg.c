#define GET_PTE_PPN (x)	((x) & 0xfffffff)
#define GET_PTE_VPN (x)	(((x) >> 28) & 0xfffffff)
#define GET_PTE_X(x)		(((x) >> 56) & 1)
#define GET_PTE_W(x)		(((x) >> 57) & 1)
#define GET_PTE_R(x)		(((x) >> 58) & 1)
#define GET_PTE_C(x)		(((x) >> 59) & 1)
#define GET_PTE_A(x)		(((x) >> 60) & 1) 
#define GET_PTE_S(x)		(((x) >> 61) & 1) 
#define GET_PTE_U(x)		(((x) >> 62) & 1) 
#define GET_PTE_D(x)		(((x) >> 63) & 1) 
#define GET_PTE_PL(x)		(((x) >> 64) & 0xff) 
#define GET_PTE_SX(x)		(((x) >> 72) & 1)
#define GET_PTE_SW(x)		(((x) >> 73) & 1)
#define GET_PTE_SR(x)		(((x) >> 74) & 1)
#define GET_PTE_SC(x)		(((x) >> 75) & 1)
#define GET_PTE_V(x)		(((x) >> 76) & 1)
#define GET_PTE_G(x)		(((x) >> 77) & 1)
#define GET_PTE_ASID(x)	(((x) >> 78) & 1)

typedef struct {
	long ppn : 48;
	long vpn : 48;	
	long x : 1;
	long w : 1;
	long r : 1;
	long c : 1;
	long a : 1;
	long s : 1;
	long u : 1;
	long d : 1;
	long bc : 4;
	long pad : 2;
	long g : 1;
	long v : 1;
	long sx : 1;
	long sw : 1;
	long sr : 1;
	long sc : 1;
	long asid : 12;
} PTE;

typedef struct {
	PTE pte[8];
} PTG;

static int num;
static PTG ptg;
static PTG following_ptg;
static PTE pte;

static void get_ptg(int num)
{
	int ptbr;
	int adr;

	ptbr = get_ptbr();
	adr = ptbr + num * 64;
		
}

static void get_following_ptg(int bc)
{
	int ptbr;
	int adr;

	ptbr = get_ptbr();
	adr = ptbr + num * 64 + bc * bc;
		
}

static void update_ptg(int num)
{
	int ptbr;
	int adr;

	ptbr = get_ptbr();
	adr = ptbr + num * 64;
		
}

static void update_following_ptg(int bc)
{
	int ptbr;
	int adr;

	ptbr = get_ptbr();
	adr = ptbr + num * 64 + bc * bc;
		
}

static int find_empty_pte()
{
	int k;
	
	for (k = 0; k < 8; k++)
	if (!ptg.pte[k].v)
		return (k);
	return (-1);
}

static void ptg_pack()
{
	int j,k;
	int bc;

	while((k = find_empty_pte()) > 0) {
		for (bc = 0; bc < 16; bc++) {
			get_following_ptg(bc);
			for (j = 0; j < 8; j++) {
				if (following_ptg.pte[j].v) {
					if (following_ptg.pte[j].bc==bc) {
						ptg.pte[k] = following_ptg.pte[j];
						ptg.pte[k].bc = 0;
						following_ptg.pte[j].v = 0;
						k = find_empty_pte();
						if (k < 0) {
							update_following_ptg(bc);
							goto xloop1;
						}
					}
				}
			}
			update_following_ptg(bc);
		}
	}
xloop1:
	;
}

void hash_table_pack()
{
	int j;
	
	for (j = 0; j < 32768; j++) {
		get_ptg(j);
		ptg_pack();
		update_ptg(j);
	}
}
