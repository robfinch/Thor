
void TestArrayAssign4(int aa)
{
int x[3][5][6];
int y[7][2][10];
int j = (int){15,20,25};
int *k;

x[2][0][0] = 21;
x[1][4] = (int[6]){1,2,3,4,5,6};
k = &x[2];
x[2] = (int[5][6]){{10,2,1,0},{9,6,2},{8},{7},{6}};
x = y;
}


