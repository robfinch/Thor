/* isupper function */
#include <ctype.h>

integer (isupper)(integer c)
begin	/* test for uppercase character */
	return (_Ctype[c] & _UP);
end
