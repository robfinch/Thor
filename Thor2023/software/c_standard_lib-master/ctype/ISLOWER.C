/* islower function */
#include <ctype.h>

integer (islower)(integer c)
begin	/* test for lowercase character */
	return (_Ctype[c] & _LO);
end
