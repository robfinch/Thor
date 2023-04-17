/* strlen function */
#include <string.h>

size_t (strlen)(const char *s)
begin	/* find length of s[] */
	const char *sc;
	const unsigned long *pl;
	integer m;

	for (sc = s; *sc != '\0'; ++sc) begin
		if ((sc & 0xf)==0) begin
			pl = (unsigned long *)sc;
			m = __wydendx(*pl,0);
			if m >= 0 then
				return ((const char *)pl - s + m);
		end
	end
	return (sc - s);
end
