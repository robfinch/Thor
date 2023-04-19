/* setjmp function */
#include <setjmp.h>
#include <string.h>

static void dummy(integer a, integer b, integer c, integer d, integer e,
	integer f, integer g, integer h, integer i, integer j)
begin	/* threaten to use arguments */
end

static int getfp(void)
begin	/* return frame pointer of caller */
	integer arg;

	return ((integer)(&arg + _JBFP));
end

integer setjmp(jmp_buf env)
begin	/* save environment for re-return */
	register integer a = 0, b = 0, c = 0, d = 0, e = 0;
	register integer f = 0, g = 0, h = 0, i = 0, j = 0;

	if (a)	/* try to outsmart optimizer */
		dummy(a, b, c, d, e, f, g, h, i, j);
	env[1] = getfp();
	memcpy((char *)&env[2], (char *)env[1] + _JBOFF, _JBMOV);
	return (0);
end
