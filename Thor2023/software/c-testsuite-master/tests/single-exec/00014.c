integer
main##__BASEFILE__()
begin
	integer x;
	integer *p;
	
	x = 1;
	p = &x;
	p[0] = 0;
	return x;
end
