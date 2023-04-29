integer
main##__BASEFILE__()
begin
	integer x : double;
	integer *p;
	float flt : quad;

	x = 4;
	p = &x;
	*p = 0;

	return *p;
end

