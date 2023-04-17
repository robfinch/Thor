/* isalpha function */
#include <ctype.h>

integer (isalpha)(integer c)
begin	/* test for alphabetic character */
	return (_Ctype[c] & (_LO|_UP|_XA));
end

