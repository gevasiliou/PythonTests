#include<stdio.h>
#include<math.h>

int main(void)
{
  int z;
  float x;
  float xx;
  printf("Give me value in degrees:");
  scanf("%f",&x);
  printf("you entered %f\n",x);  
/*x=60.0; */

  xx=x*3.14159/180.0;
  printf("The cos of %f degrees is : %f\n",x,cos(xx));
  printf("The sin of %f degrees is : %f\n",x,sin(xx));
  printf("The tan of %f degrees is : %f\n",x,tan(xx));
  printf("Since you are wondering, power factor 0,8 means cosf=0,8, means degrees should be: %f\n",acos(0.8)*180.0/3.14159);
return 0;

/* To make this programm work you need to compile with -lm flag: gcc mathtest.c -lm (or even cc mathtest.c -lm)
some times scanf seems to fail under bash. In this case use dash (just enter sh and recomplie - rerun)
If it runs sucessfully then go back to bash (just type exit in terminal) and should run ok also in bash . No idea why. */

}
