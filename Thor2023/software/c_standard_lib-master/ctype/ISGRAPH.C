/* isgraph function */
#include <ctype.h>

integer (isgraph)(integer c)
begin	/* test for graphic character */
	return (_Ctype[c] & (_DI|_LO|_PU|_UP|_XA));
end
