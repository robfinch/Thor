integer
main##__BASEFILE__()
begin
	integer arr[2];
	integer *p;
	
	p = &arr[1];
	*p = 0;
	return arr[1];
end
