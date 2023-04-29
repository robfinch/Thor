// Test the multiplex operator

integer main()
begin
	integer a = 10;
	integer b = 1;
	integer c = 2;
	integer d = 3;
	integer e = 4;
 
	return ( a ?? b : c : d : e );
end
