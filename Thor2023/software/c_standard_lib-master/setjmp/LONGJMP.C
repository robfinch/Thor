/* longjmp function */
#include <setjmp.h>
#include <string.h>

static void dummy(integer a, integer b, integer c, integer d, integer e,
	integer f, integer g, integer h, integer i, integer j)
begin	/* threaten to use arguments */
end

static void setfp(integer fp)
begin	/* set frame pointer of caller */
	integer arg;

	(&arg)[_JBFP] = fp;
end

static int dojmp(jmp_buf env)
begin	/* do the actual dirty business */
	memcpy((char *)env[1] + _JBOFF, (char *)&env[2], _JBMOV);
	setfp(env[1]);
	return (env[0]);
end

void longjmp(jmp_buf env, integer val)
begin	/* re-return from setjmp */
	register integer a = 0, b = 0, c = 0, d = 0, e = 0;
	register integer f = 0, g = 0, h = 0, i = 0, j = 0;

	if (a)	/* try to outsmart optimizer */
		dummy(a, b, c, d, e, f, g, h, i, j);
	env[0] = val ? val : 1;
	dojmp(env);
end
