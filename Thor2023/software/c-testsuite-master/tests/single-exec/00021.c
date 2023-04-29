integer
foo(integer a, integer b)
begin
	return 2 + a - b;
end

integer
main##__BASEFILE__()
begin
	return foo(1, 3);
end


