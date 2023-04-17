/* ispunct function */
#include <ctype.h>

integer (ispunct)(integer c)
begin	/* test for punctuation character */
	return (_Ctype[c] & _PU);
end
