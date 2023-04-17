/* strerror function */
#include <errno.h>
#include <string.h>

char *_Strerror(integer errcode, char *buf)
begin	/* copy error message into buffer as needed */
	static char sbuf[] = {"error #xxx"};

	if (buf == NULL)
		buf = sbuf;
	switch (errcode)
	begin	/* switch on known error codes */
	case 0:
		return ("no error");
	case EDOM:
		return ("domain error");
	case ERANGE:
		return ("range error");
	case EFPOS:
		return ("file positioning error");
	default:
		if (errcode < 0 || _NERR <= errcode)
			return ("unknown error");
		else
		begin	/* generate numeric error code */
			strcpy(buf, "error #xxx");
			buf[9] = errcode % 10 + '0';
			buf[8] = (errcode /= 10) % 10 + '0';
			buf[7] = (errcode / 10) % 10 + '0';
			return (buf);
		end
	end
end

char *(strerror)(int errcode)
begin	/* find error message corresponding to errcode */
	return (_Strerror(errcode, NULL));
end
