
extern __int32 DBGAttr;
extern void DBGClearScreen();
extern void DBGHomeCursor();
extern void putch(register char);
extern int printf(char *, ...);
extern pascal int prtflt(register float, register int, register int, register char);
extern void ramtest();
extern void FloatTest();
extern void DBGDisplayString(register char *p);
extern void puthex(register int num);

static naked inline int GetButton()
{
	asm {
		lb		r1,BUTTONS
	}
}

void BIOSMain()
{
	float pi = 3.1415926535897932384626;
	// 400921FB54442D18 
	float a,b;
	int btn;
	int seln=0;

	DBGAttr = 0x087FC00;//0b0000_1000_0111_1111_1100_0000_0000;
	DBGClearScreen();
	DBGHomeCursor();
	DBGDisplayString("  FT64 Bios Started\r\n");
	DBGDisplayString("  Menu\r\n  up = ramtest\r\n  left = float test\r\n  right=TinyBasic\r\n");
	forever {
		//0b0000_1000_0111_1111_1100_0000_0000;
		//0b1111_1111_1000_0100_0000_0000_0000;
		btn = GetButton();
		switch(btn) {
		case 8:
			while(GetButton());
			ramtest();
			break;
		case 2:
			while(GetButton());
			FloatTest();
			break;
		case 1:
			while(GetButton());
			asm {
				jmp	TinyBasicDSD9
			};
			break;
		}
	}
}

static naked inline int GetEPC()
{
	asm {
		csrrd	r1,#$40,r0
	}
}

static naked inline int GetBadAddr()
{
	asm {
		csrrd	r1,#7,r0
		sh		r1,$FFDC0080
	}
}

static naked inline void SetPCHNDX(register int nn)
{
	asm {
		csrrw	r0,#$101,r18
	}
}

static naked inline int ReadPCHIST()
{
	asm {
		csrrd	r1,#$100,r0
	}
}

void interrupt BTNCIRQHandler()
{
	int nn;

	asm {
		ldi		r1,#30
		sh		r1,PIC_ESR
	}
	DBGDisplayString("\r\nPC History:\r\n");
	for (nn = 63; nn >= 0; nn--) {
		SetPCHNDX(nn);
		puthex(ReadPCHIST());
		putch(' ');
	}
}

void interrupt DBERout()
{
	int nn;

	DBGDisplayString("\r\nDatabus error: ");
	puthex(GetEPC());
	putch(' ');
	puthex(GetBadAddr());
	putch(' ');
	for (nn = 63; nn >= 0; nn--) {
		SetPCHNDX(nn);
		puthex(ReadPCHIST());
		putch(' ');
	}
	forever {}
}

void interrupt IBERout()
{
	int nn;

	DBGDisplayString("\r\nInstruction Bus Error:\r\n");
	DBGDisplayString("PC History:\r\n");
	for (nn = 63; nn >= 0; nn--) {
		SetPCHNDX(nn);
		puthex(ReadPCHIST());
		putch(' ');
	}
	forever {}
}

