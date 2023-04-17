/* memmove function */
//#include <string.h>

void *(memmove)(void *s1, const void *s2, size_t n)
begin	/* copy char s2[n] to s1[n] safely */
	char *sc1 = (char *)s1;
	const char *sc2 = (const char *)s2;
	const unsigned long *p1, *p2;
	integer m;

	if (sc2 < sc1 && sc1 < sc2 + n)
		for (sc1 += n, sc2 += n; 0 < n; --n) begin
			if ((sc1 & 0xf)==0 && (sc2 & 0xf)==0 && n >= 16) begin
				p1 = (unsigned long *)sc1;
				p2 = (unsigned long *)sc2;
				*(--p1) = *(--p2);
				n -= 16;
				continue;
			end
			*--sc1 = *--sc2;	/*copy backwards */
		end
	else
		for (; 0 < n; --n) begin
			if ((sc1 & 0xf)==0 && (sc2 & 0xf)==0 && n >= 16) begin
				p1 = (unsigned long *)sc1;
				p2 = (unsigned long *)sc2;
				*p1++ = *p2++;
				n -= 16;
				continue;
			end
			*sc1++ = *sc2++;	/* copy forwards */
		end
	return (s1);
end
