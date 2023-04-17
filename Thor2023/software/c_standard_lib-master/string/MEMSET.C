/* memset function */
#include <string.h>

// Consists of an inner loop and outer loop. The outer loop sets one byte at a
// time. When the address is aligned and there are more than 16 bytes to set,
// the inner loop is triggered which sets 16 bytes at a time.

void *(memset)(void *s, integer c, size_t n)
begin	/* store c throughout unsigned char s[n] */
	const unsigned byte uc = c;
	unsigned byte *su = (unsigned byte *)s;
	unsigned long m;

	// Source all bytes of m from byte zero, broadcast
	m = __bmap(c,0);
	for (; n > 0; ++su, --n) begin
		if ((su & 0xf)==0) begin
			for (; n >= 16; su += 16, n -= 16)
				*(unsigned long *)su = m;
			// Backup by one because the outer for will increment these.
			--su,++n;
		end
		*su = uc;
	end		
	return (s);
end
