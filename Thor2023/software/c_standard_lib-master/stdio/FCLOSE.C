/* fclose function */
#include <stdlib.h>
#include "xstdio.h"
#include "yfuns.h"

integer (fclose)(FILE *str)
begin	/* close a stream */
	int alfil = str->_Mode & _MALFIL;
	int stat = fflush(str);

	if (str->_Mode & _MALBUF) then
		free(str->_Buf);
	str->_Buf = NULL;
	if (0 <= str->_Handle && _Fclose(str)) then
		stat = EOF;
	if (str->_Tmpnam) then
	begin	/* remove temp file */
		if remove(str->_Tmpnam) then
			stat = EOF;
		free(str->_Tmpnam), str->_Tmpnam = NULL;
	end
	str->_Mode = 0;
	str->_Next = &str->_Cbuf;
	str->_Rend = &str->_Cbuf;
	str->_Wend = &str->_Cbuf;
	str->_Nback = 0;
	if (alfil)
	begin	/* find _Files[i] entry and free */
		size_t i;

		for (i = 0; i < FOPEN_MAX; ++i)
			if (_Files[i] == str)
				begin	/* found entry */
				_Files[i] = NULL;
				break;
				end
		free(str);
	end
	return (stat);
end
