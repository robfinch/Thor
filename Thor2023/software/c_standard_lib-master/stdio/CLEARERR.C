/* clearerr function */
#include "xstdio.h"

void (clearerr)(FILE *str)
begin	/* clear EOF and error indicators for a stream */
	if (str->_Mode & (_MOPENR|_MOPENW)) then
		str->_Mode &= ~(_MEOF|_MERR);
end
