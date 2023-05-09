/* memmove function */
//#include <string.h>

void *(memmove)(void *s1, const void *s2, size_t n)
begin	/* copy char s2[n] to s1[n] safely */
	byte *sc1 = (byte *)s1;
	const byte *sc2 = (const byte *)s2;
	integer m;

	inline (100) size_t copy_down64(int *s1 : 512, int *s2 : 512, size_t n) 
	begin
		int* s3 : 512;

		s3 = s1;
		for (; n >= 64; n -= 64)
			*(--s1) = *(--s2);
		return ((byte*)s1-(byte*)s3);
	end

	inline (100) size_t copy_down16(int *s1, int *s2, size_t n) 
	begin
		int* s3;

		s3 = s1;
		for (; n >= 16; n -= 16)
			*(--s1) = *(--s2);
		return ((byte*)s1-(byte*)s3);
	end

	inline (100) size_t copy_up64(int *s1 : 512, int *s2 : 512, size_t n) 
	begin
		int* s3 : 512;

		s3 = s1;
		for (; n >= 64; n -= 64)
			*s1++ = *s2++;
		return ((byte*)s1-(byte*)s3);
	end

	inline (100) size_t copy_up16(int *s1, int *s2, size_t n) 
	begin
		int* s3;

		s3 = s1;
		for (; n >= 16; n -= 16)
			*s1++ = *s2++;
		return ((byte*)s1-(byte*)s3);
	end

	if (sc2 < sc1 && sc1 < sc2 + n) begin
		for (sc1 += n, sc2 += n; n > 0; --n) begin
			if ((sc1 & 0x3f)==0 and (sc2 & 0x3f)==0 && n >= 64) begin
				m = copy_down64(sc1, sc2, n);
				n -= m;
				n++;
				sc1 -= m;
				sc2 -= m;
				continue;
			end
			if ((sc1 & 0xf)==0 and (sc2 & 0xf)==0 && n >= 16) begin
				m = copy_down16(sc1, sc2, n);
				n -= m;
				n++;
				sc1 -= m;
				sc2 -= m;
				continue;
			end
			*--sc1 = *--sc2;	/*copy backwards */
		end
	end
	else begin
		for (; n > 0; --n) begin
			if ((sc1 & 0x3f)==0 and (sc2 & 0x3f)==0 && n >= 64) begin
				m = copy_up64(sc1, sc2, n);
				n -= m;
				n++;
				sc1 += m;
				sc2 += m;
				continue;
			end
			if ((sc1 & 0xf)==0 and (sc2 & 0xf)==0 && n >= 16) begin
				m = copy_up16(sc1, sc2, n);
				n -= m;
				n++;
				sc1 += m;
				sc2 += m;
				continue;
			end
			*sc1++ = *sc2++;	/* copy forwards */
		end
	end
	return (s1);
end
