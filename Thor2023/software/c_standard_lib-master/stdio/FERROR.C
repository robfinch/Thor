/* ferror function */
#include "xstdio.h"

integer (ferror)(FILE *str)
begin	/* test error indicator for a stream */
	return (str->_Mode & _MERR);
end
