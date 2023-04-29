// Demonstrates if without round brackets.

integer
main##__BASEFILE__()
begin
	integer x;
	
	x = 1;
	for(x = 10; x; x = x - 1)
		;
	if (x) then
		return 1;
	x = 10;
	for (;x;)
		x = x - 1;
	return x;
end

