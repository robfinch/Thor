extern far printf(...);

int far main(int argc)
{
	try {
		printf ("In main");
	}
	catch(char *str)
	{
		printf("error is %s", str);
	}
}
