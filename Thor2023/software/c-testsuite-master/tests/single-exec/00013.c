integer
main##__BASEFILE__()
begin
	integer x;
	integer *p;
	
	x = 0;
	p = &x;
	return p[0];
end
