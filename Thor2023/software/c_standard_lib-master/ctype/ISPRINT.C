/* isprint function */
#include <ctype.h>

integer (isprint)(integer c)
begin	/* test for printable character */
	return (_Ctype[c] & (_DI|_LO|_PU|_SP|_UP|_XA));
end
