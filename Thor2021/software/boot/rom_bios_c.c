/* ROM BIOS  */
#define BIOSMEM		0xFFFC0000
extern int DBGAttr;
int xx[32], yy[32], dx[32], dy[32];
int state;
//extern int DBGAttr;
extern void SieveOfEratosthenes();
extern int rand();
extern void srand(unsigned int);
extern void DBGDisplayChar(char);
extern void DBGDisplayAsciiStringCRLF(char *);
extern void MapPage(register int a0, register int a1);

/*
void __interrupt syscall()
{

}

void __interrupt ext_irq()
{

}
*/

// Map pages that are not already setup.

void MapPages()
{
	int m;
	unsigned int a0, a1;

	// 64k at 0xFFFCxxxx
	a0 = 0x8000000000000FC0;	// fixed way, entry $3C0, write = true
	a1 = 0x008E000FFC0FFFC0;
	for (m = 0; m < 16; m++) {
		MapPage(a0,a1);
		a0++;
		a1++;
	}
	// 128k at 0x00300000
	// 0x300000
	// 0x0000_0000_00_11_0000_0000_ 0000_0000_0000
	//   1111_1111_10 00_0000_0000 _0000_0000_0000
	a0 = 0x8000000000008300;	// choose random way, entry $300, write = true
	a1 = 0x008E000000000300;
	for (m = 0; m < 32; m++) {
		MapPage(a0,a1);
		a0++;
		a1++;
	}
	// 4MB low memory
	a0 = 0x8000000000000000;	// way = 0, entry $000, write = true
	a1 = 0x008E000000000000;
	for (m = 0; m < 1024; m++) {
		MapPage(a0,a1);
		a0++;
		a1++;
	}
}

void UnmapPage(int pgno)
{
	MapPage(pgno,0x00800000003FFFFF);
}

int my_abs(register int a)
{
	if (a < 0) a = -a;
	return (a);
}

void my_srand(register int a, register int b)
{
	int:32* pRand = 0;
	int ch;

	MapPage(0x8000000000000D40,0x008E000FF80FF940);		
	pRand += (0xFF940000/sizeof(int:32));
	for (ch = 0; ch < 256; ch++) {
		pRand[1] = ch;
		pRand[2] = a;
		pRand[3] = b;
	}
}

int my_rand(register int ch)
{
	int:32* pRand = 0;
	int r;
	
	MapPage(0x8000000000000D40,0x0086000FF80FF940);		
	pRand += (0xFF940000/sizeof(int:32));
	pRand[1] = ch;
	r = *pRand;
	*pRand = r;
	*pRand = r;
	*pRand = r;
	return (r);
}

void ramtest()
{

}

void PutNybble(int n)
{
	n = n & 15;
	if (n > 9)
		n = n + 'A' - 10;
	else
		n = n + '0';
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
	int* pLEDS = 0;
	int n;
	
	pLEDS += (0xFF910000/sizeof(int));
	*pLEDS = 0xAAAA;
	for (n = 0; n < 2000000; n++)
		*pLEDS = n >> 13;
}

void ShowSprites(int which)
{
	int:32 *pSprEN = 0xFF8B03C0;
	MapPage(0x8000000000000CB0,0x008E000FF80FF8B0);
	*pSprEN = which;
	UnmapPage(0x8000000000000CB0);
}

// Give each sprite its own color.

void SetSpriteColor()
{
	int:16* pSpr = 0;
	int m,n,c,k;
	int* pScreen = 0;

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
			if ((n & 15) == 0) {
				PutWyde(n);
				DBGDisplayChar('\r');
			}
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
	// Delay a bit to allow some vertical sync times to occur.
	for (m = 0; m < 1000000; m++)
		;
	pScreen[14] = DBGAttr + 'A' + m;
	// Turn off Vertical Sync DMA trigger.
	MapPage(0x8000000000000CB0,0x008E000FF80FF8B0);
	int:32 *pSprVDT = 0xFF8B03D8;
	*pSprVDT = 0;
	UnmapPage(0x8000000000000CB0);
}

void SetSpritePosAndSpeed()
{
	int:16* pSpr16 = 0;
	int n;
	
	MapPage(0x8000000000000CB0,0x008E000FF80FF8B0);
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
	UnmapPage(0x8000000000000CB0);
}

void MoveSprites()
{
	int* pScreen = 0;
	int:16* pSpr16 = 0;
	int m,n;
	int j,k,a,b;
	int t;

	// Map sprite registers	
	MapPage(0x8000000000000CB0,0x008E000FF80FF8B0);
	pSpr16 += (0xFF8B0000/sizeof(int:16));
	pScreen += (0xFF800000/sizeof(int));

	// Timing delay loop
	for (m = 0; m < 10000; m++)
		;
	for (n = 0; n < 32; n++) {
		
		j = xx[n];
		k = dx[n];
		a = yy[n];
		b = dy[n];
		
		t = j < 210 && k < 0;
		pScreen[0] = t + 0x7FE0F041;
		if (t)
			dx[n] = -dx[n];
		
		t = j > 210 + 800 && k > 0;
		pScreen[1] = t + 0x7FE0F041;
		if (t)
			dx[n] = -dx[n];
		
		t = a < 36 && b < 0;
		pScreen[2] = t + 0x7FE0F041;
		if (t)
			dy[n] = -dy[n];
		
		t = a > 600 + 26 && b > 0;
		pScreen[3] = t + 0x7FE0F041;
		if (t)
			dy[n] = -dy[n];
		
		pSpr16[n*8] = xx[n];
		pSpr16[n*8+1] = yy[n];			

		xx[n] += dx[n];
		yy[n] += dy[n];
		
	}
}

int main()
{
	int* pScreen = 0;
	int* pMem = 0;
	int n, m;
	char* bootstr = "Thor2021 SoC Booting...";
	char *btstr = 0xFFFE0000;

//	forever {
//		switch(state) {
//		case 0:
	ShowSprites(0x00);
	MapPages();
	int* pLEDS = 0;
	pLEDS += (0xFF910000/sizeof(int));
	*pLEDS = 0x01;
				state++;
				FlashLEDs();
	*pLEDS = 0x55;
				DBGAttr = 0x03FFFE0003FF0000;
				pMem += (BIOSMEM/sizeof(int));
				pScreen += (0xFF800000/sizeof(int));
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
				ShowSprites(0xFFFFFF00);
				DBGDisplayChar(' ');
//				DBGDisplayAsciiStringCRLF(bootstr);
					DBGDisplayChar('\r');
					DBGDisplayChar('\n');
					PutWyde(bootstr[0]);
					DBGDisplayChar('\r');
					DBGDisplayChar('\n');
				DBGDisplayChar(' ');
			
				my_srand(1234,4567);
				for (n = 0; n < 200; n++) {
					PutTetra(my_rand(0));
					DBGDisplayChar(' ');
				}
				
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

