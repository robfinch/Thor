
#include <fmtk/config.h>
#include <fmtk/const.h>

extern int LockSysSemaphore();
extern void UnlockSysSemaphore();

typedef struct tagPMT {
	unsigned int:16 acl;
	unsigned int:16 share_count;
	unsigned int:32 access_count;
	unsigned int:32 key;
	unsigned int:32 flags;
	unsigned int:32 list;
	int:32 pad1a;
	int:32 pad1b;
	int:32 pad1c;
} PMT;

static int:32 free_list;
static int:32 active_list;
static int:32 inactive_list;
	
static PMT* pmts;

void PMTInit()
{
	int k;
	int:128* pmt = 0;
	
	for (k = 0; k < MEM_SIZE * 2; k++)
		pmt[k] = 0;	
	pmts = 0;
	free_list = 1;
	active_list = 0;
	inactive_list = 0;
	// place everything on the free list
	for (k = 1; k < MEM_SIZE; k++) {
		pmts[k].list = k + 1;
	}	
	pmts[k].list = 0;
}

int* PMTAlloc(int key, int flags, int* err)
{
	unsigned int* rv;
	unsigned int al,pal;

	while (!LockSysSemaphore());
	rv = free_list;
	if (rv==0) {
		UnlockSysSemaphore();
		if (err)
			*err = E_NoMem;
		return (0);
	}
	if (!PMTCheckKey(key)) {
		UnlockSysSemaphore();
		if (err)
			*err = E_BadKey;
		return (0);
	}
	free_list = pmts[free_list].list;
	pmts[rv].list = 0;
	pmts[rv].key = key;
	pmts[rv].flags = flags | PMT_A(1);
	if (active_list==0) {
		active_list = rv;
		UnlockSysSemaphore();
		if (err)
			*err = E_Ok;
		return (rv << LOG_PGSIZE);
	}
	for (al = active_list; al > 0; al = pmts[al].list)
		pal = al;
	pmts[pal].list = rv;
	UnlockSysSemaphore();
	if (err)
		*err = E_Ok;
	return (rv << LOG_PGSIZE);
}

int PMTFree(int* p)
{
	unsigned int v;
	
	v = p >> LOG_PGSIZE;
	if (v >= MEM_SIZE)
		return (E_Arg);
	while (!LockSysSemaphore());
	if (PMTCheckKey(pmts[v].key)) {
		pmts[v].key = 0;
		pmts[v].list = free_list;
		free_list = v;
	}
	UnlockSysSemaphore();
	return (E_Ok);
}

int PMTShare(int* p)
{
	unsigned int v;

	v = p >> LOG_PGSIZE;
	if (v >= MEM_SIZE)
		return (E_Arg);
	while (!LockSysSemaphore());
	if (PMTCheckKey(pmts[v].key))
		if (pmts[v].share_count != 0xffff)
			pmts[v].share_count++;	
	UnlockSysSemaphore();
	return (E_Ok);
}
