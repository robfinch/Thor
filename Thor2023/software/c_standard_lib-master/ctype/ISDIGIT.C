/* isdigit function */
#include <ctype.h>

integer (isdigit)(integer c)
begin	/* test for digit */
	return (_Ctype[c] & _DI);
end
