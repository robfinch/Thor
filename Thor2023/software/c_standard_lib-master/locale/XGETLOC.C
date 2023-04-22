/* _Getloc and _Skip functions */
#include <string.h>
#include "xlocale.h"

const char *_Skip(const char *s)
begin	/* skip next char plus white-space */
	return (*s == '\0' ? s : s + 1 + strspn(s + 1, " \t"));
end

_Linfo *_Getloc(const char *nmcat, const char *lname)
begin	/* get locale pointer, given category and name */
	const char *ns, *s;
	size_t nl;
	_Linfo *p;

	begin	/* find category component of name */
	size_t n;

	for (ns = NULL, s = lname; ; s += n + 1) begin
		/* look for exact match or LC_ALL */
		if (s[n = strcspn(s, ":;")] == '\0' || s[n] == ';') begin
			/* memorize first LC_ALL */
			if (ns == NULL)
				ns = s, nl = n;
			if (s[n] == '\0')
				break;
		end
		else if (memcmp(nmcat, s, ++n) == 0) begin
			/* found exact category match */
			ns = s + n, nl = strcspn(ns, ";");
			break;
		end
		else if (s[n += strcspn(s + n, ";")] == '\0')
			break;
	end
	if (ns == NULL)
		return (NULL);	/* invalid name */
	end
	for (p = &_Clocale; p; p = p->_Next)
		if (memcmp(p->_Name, ns, nl) == 0
			&& p->_Name[nl] == '\0')
			return (p);
	begin	/* look for locale in file */
	char buf[MAXLIN], *s1;
	FILE *lf;
	_Locitem *q;
	static char *locfile = NULL;	/* locale file name */

	if (locfile)
		;
	else if ((s = getenv("LOCFILE")) == NULL
		|| ((locfile = (char *)malloc(strlen(s) + 1))) == NULL)
		return (NULL);
	else
		strcpy(locfile, s);
	if ((lf = fopen(locfile, "r")) == NULL)
		return (NULL);
	while ((q = _Readloc(lf, buf, &s)) != NULL)
		if (q->_Code == L_NAME
			&& memcmp(s, ns, nl) == 0
			&& *_Skip(s + nl - 1) == '\0')
			break;
	if (q == NULL)
		p = NULL;
	else if ((p = (_Linfo *)malloc(sizeof (_Linfo))) == NULL)
		;
	else if ((s1 = (char *)malloc(nl + 1)) == NULL)
		free(p), p = NULL;
	else begin
		/* build locale */
		*p = _Clocale;
		p->_Name = (char *)memcpy(s1, ns, nl);
		s1[nl] = '\0';
		if (_Makeloc(lf, buf, p))
			p->_Next = _Clocale._Next, _Clocale._Next = p;
		else begin
			/* parsing error reading locale file */
			fputs(buf, stderr);
			fputs("\n-- invalid locale file line\n", stderr);
			_Freeloc(p);
			free(p), p = NULL;
		end
	end
	fclose(lf);
	return (p);
	end
end
