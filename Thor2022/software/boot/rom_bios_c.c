/* ROM BIOS  */
#define BIOSMEM		0xFFFC0000
extern int:64 DBGAttr;
int xx[32], yy[32], dx[32], dy[32];
int state;
int scrpos;
//extern int DBGAttr;
extern void SieveOfEratosthenes();
extern int rand();
extern void srand(unsigned int);
extern void DBGDisplayChar(char);
extern void DBGDisplayAsciiStringCRLF(char *);
extern void MapPage(int a0, int a1);
extern unsigned long PtgHash(unsigned long va);
extern void StPtg(unsigned long a0, unsigned long a1, unsigned long a2);

// a2
#define PTE_CRWX(x)	((x) << 0)
#define PTE_DUSA(x)	((x) << 4)
#define PTE_BC(x)		((x) << 8)
#define PTE_AV(x)		((x) << 13)
#define PTE_G(x)		((x) << 14)
#define PTE_V(x)		((x) << 15)
#define PTE_SCRWX(x)	((x) << 16)
#define PTE_ASID(x)	((x) << 20)
#define PTE_KEY(x)	((x) << 32)
#define PTE_AC(x)		((x) << 64)

// a1
#define PTE_PPN(x)	(x)
#define PTE_PL(x)		((x) << 52)
#define PTE_N(x)		((x) << 60)
#define PTE_EN(x)		((x) << 63)
#define PTE_VPN(x)	((x) << 64)
#define PTE_ME(x)		((x) << 116)
#define PTE_MB(x)		((x) << 122)

// a0
#define PTE_ENTRYNO(x)	((x) << 0)
#define PTE_WAY(x)			((x) << 10)
#define PTE_AL(x)				((x) << 14)
#define PTE_S(x)				((x) << 16)
#define PTE_W(x)				((x) << 31)
/*
#define PTE_CRWX(x)	((x) << 32)
#define PTE_DUSA(x)	((x) << 36)
#define PTE_BC(x)		((x) << 40)
#define PTE_AV(x)		((x) << 45)
#define PTE_G(x)		((x) << 46)
#define PTE_V(x)		((x) << 47)
#define PTE_SCRWX(x)	((x) << 48)
#define PTE_ASID(x)	((x) << 52)
*/

/*
void __interrupt syscall()
{

}

void __interrupt ext_irq()
{

}
*/

bool foo (register int a, register int b)
{
	return a > b;
}

// Map pages that are not already setup.

void MapPages()
{
	int m;
	unsigned long a0, a1, a2;

	// 4MB low memory
	// way = 0, entry $000, write = true
	for (m = 0; m < 1 /*64*/; m++) {
		a0 = PtgHash(m << 16);
		a1 = PTE_VPN(m)|PTE_PPN(m)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
		a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
		StPtg(a0,a1,a2);
	}
	// 64k at 0xFFFCxxxx
	// fixed way, entry $3C0, write = true
	a0 = PtgHash(0xFFFC0000)|(((0xFFFC0000) >> 16) & 3);
	a1 = PTE_VPN(0xFFFC)|PTE_PPN(0xFFFC)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	a0 = PtgHash(0xFFFD0000)|(((0xFFFD0000) >> 16) & 3);
	a1 = PTE_VPN(0xFFFD)|PTE_PPN(0xFFFD)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(1);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(13)|PTE_DUSA(0)|PTE_CRWX(13)|PTE_AV(1);
	StPtg(a0,a1,a2);
	a0 = PtgHash(0xFFFE0000)|(((0xFFFE0000) >> 16) & 3);
	a1 = PTE_VPN(0xFFFE)|PTE_PPN(0xFFFE)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(2);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(13)|PTE_DUSA(0)|PTE_CRWX(13)|PTE_AV(1);
	StPtg(a0,a1,a2);
	a0 = PtgHash(0xFFFF0000)|(((0xFFFF0000) >> 16) & 3);
	a1 = PTE_VPN(0xFFFF)|PTE_PPN(0xFFFF)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(3);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(13)|PTE_DUSA(0)|PTE_CRWX(13)|PTE_AV(1);
	StPtg(a0,a1,a2);

	// 128k at 0x00300000
	// 0x300000
	// 0x0000_0000_00_11_0000_0000_ 0000_0000_0000
	//   1111_1111_10 00_0000_0000 _0000_0000_0000
	// choose random way, entry $300, write = true
	a0 = PtgHash(0x00300000)|(((0x00300000) >> 16) & 3);
	a1 = PTE_VPN(0x0030)|PTE_PPN(0x0030)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	a0 = PtgHash(0x00310000)|(((0x00310000) >> 16) & 3);
	a1 = PTE_VPN(0x0031)|PTE_PPN(0x0031)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(1);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);

}

void UnmapPage(int pgno)
{
	MapPage(pgno,0x00800000003FFFFF);
}

int my_abs(int a)
{
	if (a < 0) a = -a;
	return (a);
}

void my_srand(int a, int b)
{
	int:32* pRand = 0;
	int ch;
	unsigned long a0, a1, a2;

	a0 = PtgHash(0xFF940000)|(((0xFF940000) >> 16) & 3);
	a1 = PTE_VPN(0xFF94)|PTE_PPN(0xFF94)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	pRand += (0xFF940000/sizeof(int:32));
	for (ch = 0; ch < 256; ch++) {
		pRand[1] = ch;
		pRand[2] = a;
		pRand[3] = b;
	}
}

int my_rand(int ch)
{
	int:32* pRand = 0;
	int r;
	unsigned long a0, a1, a2;

	a0 = PtgHash(0xFF940000)|(((0xFF940000) >> 16) & 3);
	a1 = PTE_VPN(0xFF94)|PTE_PPN(0xFF94)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	pRand += (0xFF940000/sizeof(int:32));
	pRand[1] = ch;
	r = *pRand;
	*pRand = r;
	return (r);
}

void bypassTest()
{
	__asm {
		ldi		a0,1
		add		a1,a0,1
		add		a2,a0,1
		add		a3,a1,a2
		ldo		a4,_DBGAttr
		or		a4,a4,a3
		add		a4,a4,'0'
		sto		a4,0xFF800378
		slt		a5,a4,'0'
		ldo		a4,_DBGAttr
		or		a4,a5,'0'
		sto		a4,0xFF800370
	}
}

void ramtest()
{

}

void TstDisplayChar(int n)
{
	int:64* pScreen = 0;

	pScreen += (0xFF800000/sizeof(int));
	pScreen[scrpos++] = DBGAttr|n;
}

void PutNybble(int n)
{
	n = n & 15;
	n = n | '0';
	if (n > '9')
		n = n + 7;
	DBGDisplayChar(n);
	DBGDisplayChar(n);
}

void PutByte(int n)
{
	PutNybble(n >> 4);
	PutNybble(n);
}

void PutWyde(int n)
{
	PutByte(n >> 8);
	PutByte(n);
}

void PutTetra(int n)
{
	PutWyde(n >> 16);
	PutWyde(n);
}

void PutOcta(int n)
{
	PutTetra(n >> 32);
	PutTetra(n);
}

void FlashLEDs()
{
	int:16* pLEDS = 0;
	int n;
	
	pLEDS += (0xFF910000/sizeof(int:16));
	*pLEDS = 0xAAAA;
	for (n = 0; n < 2000000; n++)
		*pLEDS = n >> 13;
}

void ShowSprites(int which)
{
	int:32 *pSprEN = 0xFF8B03C0;
	unsigned long a0, a1, a2;

	a0 = PtgHash(0xFF8B0000)|(((0xFF8B0000) >> 16) & 3);
	a1 = PTE_VPN(0xFF8B)|PTE_PPN(0xFF8B)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);//0x3F000018003FE00FF940);		
	*pSprEN = which;
//	UnmapPage(0x8000000000000CB0);
}

// Give each sprite its own color.

void SetSpriteColor()
{
	int:16* pSpr = 0;
	int m,n,c,k;
	int:64* pScreen = 0;
	unsigned long a0, a1, a2;

	pScreen += (0xFF800000/sizeof(int));
	pScreen[10] = DBGAttr|'A';
	pScreen[11] = DBGAttr + 'A';
	pSpr += (0x00300000/sizeof(int:16));
	pScreen[12] = DBGAttr + 'A';
	for (m = 0; m < 32; m++) {
		pScreen[11] = DBGAttr + 'A' + m;
		c = my_rand(0);
		k = m * 2048;
		for (n = 0; n < 2048; n++) {
			pSpr[k + n] = c;
		}
	}
	// Make a boxed X shape
	c = 0x7fff;
	for (m = 0; m < 32; m++) {
		pScreen[12] = DBGAttr + 'A' + m;
		k = m * 2048;
		for (n = 0; n < 56; n++)	// Top
			pSpr[k + n] = c;
		for (n = 0; n < 56; n++)	// Bottom
			pSpr[k + 35*56 + n] = c;
		for (n = 0; n < 36; n++)	// Left
			pSpr[k + n * 56] = c;
		for (n = 0; n < 36; n++)	// Right
			pSpr[k + 55 + n * 56] = c;
		for (n = 0; n < 36; n++)
			pSpr[k + n * 57] = c;
		for (n = 0; n < 36; n++)
			pSpr[k + n * 55 + 55] = c;
	}
	pScreen[13] = DBGAttr + 'A' + m;
	// Turn on Vertical Sync DMA trigger.
	a0 = PtgHash(0xFF8B0000)|(((0xFF8B0000) >> 16) & 3);
	a1 = PTE_VPN(0xFF8B)|PTE_PPN(0xFF8B)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	int:32 *pSprVDT = 0xFF8B03D8;
	*pSprVDT = 0xFFFFFFFF;
	// Delay a bit to allow some vertical sync times to occur.
	for (m = 0; m < 10000000; m++)
		;
	pScreen[14] = DBGAttr + 'A' + m;
	// Turn on Vertical Sync DMA trigger.
	a0 = PtgHash(0xFF8B0000)|(((0xFF8B0000) >> 16) & 3);
	a1 = PTE_VPN(0xFF8B)|PTE_PPN(0xFF8B)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	int:32 *pSprVDT = 0xFF8B03D8;
	*pSprVDT = 0xFFFFFFFF;
//	UnmapPage(0x8000000000000CB0);
}

void SetSpritePosAndSpeed()
{
	int:16* pSpr16 = 0;
	int n;
	unsigned long a0, a1, a2;
	
	a0 = PtgHash(0xFF8B0000)|(((0xFF8B0000) >> 16) & 3);
	a1 = PTE_VPN(0xFF8B)|PTE_PPN(0xFF8B)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	pSpr16 += (0xFF8B0000/sizeof(int:16));
	for (n = 0; n < 32; n++) 
	{
		xx[n] = (my_rand(0) & 511) + 210;
		yy[n] = (my_rand(0) & 511) + 36;
		dx[n] = (my_rand(0) & 7) - 4;
		dy[n] = (my_rand(0) & 7) - 4;
		pSpr16[n*8] = xx[n];
		pSpr16[n*8+1] = yy[n];
		pSpr16[n*8+2] = 0x2a30;		// set size 48x42
	}
//	UnmapPage(0x8000000000000CB0);
}

void MoveSprites()
{
	int:64* pScreen = 0;
	int:16* pSpr16 = 0;
	int m,n;
	int j,k,a,b;
	int t;
	unsigned long a0, a1, a2;

	// Map sprite registers	
	a0 = PtgHash(0xFF8B0000)|(((0xFF8B0000) >> 16) & 3);
	a1 = PTE_VPN(0xFF8B)|PTE_PPN(0xFF8B)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	pSpr16 += (0xFF8B0000/sizeof(int:16));
	pScreen += (0xFF800000/sizeof(int));

	forever {
		// Timing delay loop
		for (m = 0; m < 100000; m++)
			;
		for (n = 0; n < 32; n++) {
			
			bypassTest();
			
			j = xx[n];
			k = dx[n];
			a = yy[n];
			b = dy[n];
			
			t = j < 210 && k < 0;
			pScreen[0] = t + 0x7FE0F041;
			if (t)
				dx[n] = -k;
			
			t = j > 210 + 800 - 48 && k > 0;
			pScreen[1] = t + 0x7FE0F041;
			if (t)
				dx[n] = -k;
			
			t = a < 36 && b < 0;
			pScreen[2] = t + 0x7FE0F041;
			if (t)
				dy[n] = -b;
			
			t = a > 600 + 26 - 42 && b > 0;
			pScreen[3] = t + 0x7FE0F041;
			if (t)
				dy[n] = -b;
			
			pSpr16[n*8] = j;
			pSpr16[n*8+1] = a;			

			xx[n] = j + dx[n];
			yy[n] = a + dy[n];
			
		}
	}
}

int main()
{
	int:64* pScreen = 0;
	int* pMem = 0;
	int n, m;
	char* bootstr = "Thor2021 SoC Booting...";
	char *btstr = 0xFFFE0000;
	int:16* pLEDS = 0;
	unsigned long int a0,a1,a2;

	pLEDS += (0xFF910000/sizeof(int:16));
	*pLEDS = 0xAAAA;

	// Zero out page table
	for (n = 0; n < 1 /*6384*/; n = n + 1)
		StPtg(n,0,0);
	
	MapPages();
	TurnOnPt();

	// Map LEDs
	a0 = PtgHash(0xFF910000)|(((0xFF910000) >> 16) & 3);
	a1 = PTE_VPN(0xFF91)|PTE_PPN(0xFF91)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	*pLEDS = 0x5555;

	// Map Text Screen
	a0 = PtgHash(0xFF800000)|(((0xFF800000) >> 16) & 3);
	a1 = PTE_VPN(0xFF80)|PTE_PPN(0xFF80)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
	// Map Text Registers
	a0 = PtgHash(0xFF810000)|(((0xFF810000) >> 16) & 3);
	a1 = PTE_VPN(0xFF81)|PTE_PPN(0xFF81)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);


	scrpos = 0;
//	forever {
//		switch(state) {
//		case 0:
	ShowSprites(0x00);
	// Map random number generator
//	MapPage(0x8000000000000D40,0x008E000FF80FF940);		
	a0 = PtgHash(0xFF940000)|(((0xFF940000) >> 16) & 3);
	a1 = PTE_VPN(0xFF94)|PTE_PPN(0xFF94)|PTE_PL(0)|PTE_N(1)|PTE_MB(0)|PTE_ME(63)|PTE_EN(0);
	a2 = PTE_G(1)|PTE_V(1)|PTE_SCRWX(6)|PTE_DUSA(0)|PTE_CRWX(6)|PTE_AV(1);
	StPtg(a0,a1,a2);
//	int* pLEDS = 0;
//	pLEDS += (0xFF910000/sizeof(int));
	*pLEDS = 0x01;
				state++;
				FlashLEDs();
	*pLEDS = 0x55;
				DBGAttr = 0x03FFFE0003FF0000;
				pMem += (BIOSMEM/sizeof(int));
				pScreen += (0xFF800000/sizeof(int:64));
			//	for (n = 0; n < 64 * 33; n++)
			//		*pScreen++ = DBGAttr;
				DBGClearScreen();
				DBGHomeCursor();
				pScreen[0] = DBGAttr|'A';
				pScreen[1] = DBGAttr|'A';
				pScreen[2] = DBGAttr|'A';
				pScreen[3] = DBGAttr|'A';
				n = 1;
				if (n)
					pScreen[4] = DBGAttr|'B';
				n++;
				if (n==2)
					pScreen[5] = DBGAttr|'C';
				if (n==4)
					pScreen[6] = DBGAttr|'D';

				bypassTest();
				DBGCRLF();
				PutTetra(&DBGAttr);
				DBGDisplayChar(' ');
				PutTetra(0x87654321);
				DBGDisplayChar(' ');
				__asm {
					csrrd	a0,r0,0x3036
					sub		sp,sp,8
					sto		a0,[sp]
					jsr		lk1,_PutTetra
				}
				ShowSprites(0xAAAAAAAA);
					DBGCRLF();
					/*
					for (n = 0; n < 256; n++) {
						PutByte(n);
						DBGDisplayChar(' ');
					}
					*/
				DBGDisplayChar(' ');
//				DBGDisplayAsciiStringCRLF(bootstr);
					DBGCRLF();
					PutWyde(bootstr[0]);
					DBGCRLF();
				DBGDisplayChar(' ');
			
				my_srand(1234,4567);
				/*
				for (n = 0; n < 200; n++) {
					PutTetra(my_rand(0));
					DBGDisplayChar(' ');
				}
				*/
				SetSpriteColor();
				
//		case 1:
				state++;
				SetSpritePosAndSpeed();

//		case 2:
			forever {
				MoveSprites();
			}
			forever {
		//	pMem[5] = (int)ext_irq|0x48000002;
		//	pMem[12] = (int)syscall|0x48000002;
			//SieveOfEratosthenes();
		//	for (n = 0; n < 56 *31; n = n + 1)
		//		pScreen[n] = DBGAttr|' ';
				for (n = 0; n < 100000; n = n + 1)
					pScreen[my_abs(my_rand(0))%(64*32)+64] = my_rand(0);
				for (m = 0; m < 10000; m = m + 1) {
					pScreen = 0;
					pScreen += (0xFF800010/sizeof(int));
					for (n = 0; n < 64*33; n = n + 1)
						*pScreen++ = my_rand(0);
				}
			}
//		default:
//			state = 2;
//		}
//	}
	ramtest();
}

void last_func()
{
}
