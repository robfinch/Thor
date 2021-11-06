int Astack[1024];
int Bstack[1024];

int coroutine B();

int coroutine(Astack + 1024) A()
{
	forever {
		yield B();
	}
	return (0);
}

int coroutine(Bstack + 1024) B()
{
	forever {
		yield A();
	}
}

int main()
{
	int x;
	
	x = A();
	return (x);
}
