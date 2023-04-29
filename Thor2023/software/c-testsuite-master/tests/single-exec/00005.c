integer
main##__BASEFILE__()
begin
	integer x;
	integer *p;
	integer **pp;

	x = 0;
	p = &x;
	pp = &p;

	if (*p) then
		return 1;
	if (**pp) then
		return 1;
	else
		**pp = 1;

	if (x) then
		return 0;
	else
		return 1;
end

