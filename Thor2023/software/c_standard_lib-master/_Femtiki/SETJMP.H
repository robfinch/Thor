/* setjmp.h standard header */
#ifndef _SETJMP
#define _SETJMP
#ifndef _YVALS
#include <yvals.h>
#endif
		/* macros */
#define setjmp(env)	_Setjmp(env)
		/* type definitions */
typedef integer jmp_buf[_NSETJMP];
		/* declarations */
void longjmp(jmp_buf, integer);
#endif
