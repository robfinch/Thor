/* isalnum function */
#include <ctype.h>

integer (isalnum)(integer c)
begin	/* test for alphanumeric character */
	return (_Ctype[c] & (_DI|_LO|_UP|_XA));
end
