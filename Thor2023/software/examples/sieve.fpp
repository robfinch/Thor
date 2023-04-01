



char	flags[8191];

main()
{
int i,prime,k,count,iter;
printf("10 iterations\n");
for(iter=1;iter<= 10;iter++){
count=0;
for(i = 0; i<=8190;i++)
flags[i]=true;
for(i=0;i <= 8190; i++){
if(flags[i]){
prime = i+i+3;
k=i+prime;
while(k<=8190){
flags[k] = false;
k += prime;
}
count = count+1;
}
}
}
printf("\n%d primes\n",count);
}

