integer
main##__BASEFILE__()
begin
	struct { integer x; integer y; } s;
	
	s.x = 3;
	s.y = 5;
	return s.y - s.x - 2; 
end

