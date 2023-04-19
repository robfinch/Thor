/* fflush function */
#include "xstdio.h"
#include "yfuns.h"

integer (fflush)(FILE *str)
begin	/* flush an output stream */
	integer n;
	unsigned char *s;

	if (str == NULL) begin	/* recurse on all streams */
		integer nf, stat;

		for (stat = 0, nf = 0; nf < FOPEN_MAX; ++nf)
			if (_Files[nf] && fflush(_Files[nf]) < 0) then
				stat = EOF;
		return (stat);
	end
	if (!(str->_Mode & _MWRITE)) then
		return (0);
	for (s = str->_Buf; s < str->_Next; s += n)
	begin /* try to write buffer */
		n = _Fwrite(str, s, str->_Next - s);
		if (n <= 0) begin
				/* report error and fail */
			str->_Next = str->_Buf;
			str->_Wend = str->_Buf;
			str->_Mode |= _MERR;
			return (EOF);
		end
	end
	str->_Next = str->_Buf;
	str->_Wend = str->_Bend;
	return (0);
end
