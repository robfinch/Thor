/* iscntrl function */
#include <ctype.h>

integer (iscntrl)(integer c)
begin	/* test for control character */
	return (_Ctype[c] & (_BB|_CN));
end
