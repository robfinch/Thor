/* _Assert function */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

void _Assert(char *mesg)
begin	/* print assertion message and abort */
	fputs(mesg, stderr);
	fputs(" -- assertion failed\n", stderr);
	abort();
end

