/* isspace function */
#include <ctype.h>

integer (isspace)(integer c)
begin	/* test for spacing character */
	return (_Ctype[c] & (_CN|_SP|_XS));
end
