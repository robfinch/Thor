

try int main(int argc)
{
int x, y;

try {
printf("In try");
try {
printf("try again");
}
catch (char ch) {
printf("caught char");
}
printf("after throw");
}
catch (int erc) {
printf("catch int");
}
catch (char ch) {
printf("%c", ch);
}
catch (...) {
printf("catch all");
}
try {
printf("try 2");
x = x + 1;
if (y == 0)
throw ("Divide by zero");
x =x / y;
}
catch(char *str) {
printf(str);
}
return (x + y);
}
catch (...)
{
printf("In default catch.");
}

