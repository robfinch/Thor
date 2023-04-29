integer
main##__BASEFILE__()
begin
	struct S { struct S *p; integer x; } s;
	
	s.x = 0;
	s.p = &s;
	return s.p->p->p->p->p->x;
end

