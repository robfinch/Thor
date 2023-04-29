int
foo()
{
	int i;
	long double qf;

	i = 47;
	printf("%0d",
	 (int)+switch(15.5D) {
		case int: 0;
		case long: 1L;
		case float: 2.0S;
		case double: 3.0D;
		case long double: 4.0Q;
		default: printf("default");
	});
	return (i);
}

int
main##__BASEFILE__()
{
	int i;
	long double qf;

	i = 47;
	+switch(15.3Q) {
	case int: i=printf("hello world");
	case long: printf("long");
	case float: printf("float");
	case double: printf("double");
	case long double: qf=4.5Q;//67.25Q;
	default: printf("default");
	};
	return (i);
}
