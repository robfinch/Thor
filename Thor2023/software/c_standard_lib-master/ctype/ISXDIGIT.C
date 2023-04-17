/* isxdigit function */
#include <ctype.h>

integer (isxdigit)(integer c)
begin	/* test for hexadecimal digit */
	return (_Ctype[c] & _XD);
end
