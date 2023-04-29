integer
main##__BASEFILE__()
begin
	integer x, *p, **pp;
	
	x = 0;
	p = &x;
	pp = &p;
	return **pp;
end
