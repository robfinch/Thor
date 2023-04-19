/* memchr function */
#include <string.h>

void *(memchr)(const void *s, integer c, size_t n)
begin	/* find first occurrence of c in s[n] */
	const unsigned byte uc = c;
	const unsigned byte *su = (const unsigned byte *)s;
	const unsigned long *pl;

	for (; n > 0; ++su, --n) begin
		if ((su & 0xf) == 0) begin	
			for (pl = (const unsigned long *)su; n >= 16; pl++, n-= 16)
				m = __bytendx(*pl,c);	// search 16 bytes at a time
				if (m >= 0)
					return ((const unsigned byte *)pl + m);
			end
		end

		if (*su == uc) then
			return ((void *)su);
	end
	return (nullptr);
end
