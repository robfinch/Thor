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
/*
void __interrupt syscall()
{

}

void __interrupt ext_irq()
{

}
*/

int my_abs(register int a)
{
	if (a < 0) a = -a;
	return (a);
}

void my_srand(register int a, register int b)
{
	int* pRand = 0;
	int ch;
		
	pRand += (0xFFDC0C00/sizeof(int));
	for (ch = 0; ch < 256; ch++) {
		pRand[1] = ch;
		pRand[2] = a;
		pRand[3] = b;
	}
}

int my_rand(register int ch)
{
	int* pRand = 0;
	int r;
	
	pRand += (0xFFDC0C00/sizeof(int));
	pRand[1] = ch;
	r = *pRand;
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

void FlashLEDs()
{
	int* pLEDS = 0;
	int n;
	
	pLEDS += (0xFFDC0600/sizeof(int));
	*pLEDS = 0xAAAA;
	for (n = 0; n < 2000000; n++)
		*pLEDS = n >> 13;
}

// Give each sprite its own color.

void SetSpriteColor()
{
	int:16* pSpr = 0;
	int m,n,c,k;
	
	pSpr += (0x00300000/sizeof(int:16));
	for (m = 0; m < 32; m++) {
		c = my_rand(0);
		k = m * 2048;
		for (n = 0; n < 2048; n++)
			pSpr[k + n] = c;
	}
	// Make a boxed X shape
	c = 0x7fff;
	for (m = 0; m < 32; m++) {
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
	// Delay a bit to allow some vertical sync times to occur.
	for (m = 0; m < 1000000; m++)
		;
	// Turn off Vertical Sync DMA trigger.
	int:32 *pSprVDT = 0xFFDAD3D8;
	*pSprVDT = 0;
}

void SetSpritePosAndSpeed()
{
	int:16* pSpr16 = 0;
	int n;
	
	pSpr16 += (0xFFDAD000/sizeof(int:16));
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
}

void MoveSprites()
{
	int* pScreen = 0;
	int:16* pSpr16 = 0;
	int m,n;
	int j,k,a,b;
	int t;
	
	pSpr16 += (0xFFDAD000/sizeof(int:16));
	pScreen += (0xFFD00000/sizeof(int));

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
	char* bootstr = "rfPower SoC Booting...";
	char *btstr = 0xFFFE0000;

//	forever {
//		switch(state) {
//		case 0:
				state++;
				FlashLEDs();
				DBGAttr = 0x7FE0F000;
				pMem += (BIOSMEM/sizeof(int));
				pScreen += (0xFFD00000/sizeof(int));
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
				DBGDisplayChar('E');
				DBGDisplayChar('F');
				DBGDisplayChar('G');
				PutWyde(0x1234);
				//DBGDisplayAsciiStringCRLF(bootstr);
					DBGDisplayChar('\r');
					DBGDisplayChar('\n');
					PutWyde(btstr[0]);
					DBGDisplayChar('\r');
					DBGDisplayChar('\n');
				DBGDisplayChar(' ');
				
				my_srand(1234,4567);
				SetSpriteColor();
				
//		case 1:
				state++;
				SetSpritePosAndSpeed();

//		case 2:
			forever {
				MoveSprites();

		//	pMem[5] = (int)ext_irq|0x48000002;
		//	pMem[12] = (int)syscall|0x48000002;
			//SieveOfEratosthenes();
		//	for (n = 0; n < 56 *31; n = n + 1)
		//		pScreen[n] = DBGAttr|' ';
				for (n = 0; n < 100000; n = n + 1)
					pScreen[my_abs(my_rand(0))%(64*32)+64] = my_rand(0);
				for (m = 0; m < 10000; m = m + 1) {
					pScreen = 0;
					pScreen += (0xFFD00010/sizeof(int));
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

