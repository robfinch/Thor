integer
main##__BASEFILE__()
begin
	struct S { integer x; integer y; } s;
	struct S *p;

	p = &s;	
	s.x = 1;
	p->y = 2;
	return p->y + p->x - 3; 
end

