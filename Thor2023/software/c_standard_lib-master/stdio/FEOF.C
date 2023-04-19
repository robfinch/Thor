/* feof function */
#include "xstdio.h"

integer (feof)(FILE *str)
begin	/* test end-of-file indicator for a stream */
	return (str->_Mode & _MEOF);
end
