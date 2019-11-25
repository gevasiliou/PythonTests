#include <stdio.h>

int multiple; //global variable 

int sum_and_diff (int a, int b, int *sum, int *diff)
{
 *sum=a+b;
 *diff=a-b;
 multiple=a*b; //Assigning a value to a global variable.
 return 0;
}

void main (void)
{
 int a;   //actually local variables defined inside function main
 int summary,difference;
 int res=sum_and_diff(5,2,&summary,&difference);
 int *ptr_to_a;
 ptr_to_a = &a;
 a = 5;
 printf ("The value of 'a' declared just using 'int a' and then 'a=5' is :%d\n", a);
 *ptr_to_a = 6;
 printf ("The value of 'a' after pointer assignment '*ptr_to_a = 6' is :%d\n", a);
 printf ("if we just print 'ptr_to_a' we get the pointer value, which is the address of variable a (=%d) due to 'ptr_to_a = &a'\n", ptr_to_a);
 printf ("Obviously, '&a' holds the address of 'a' which is now the pointer 'ptr_to_a' value : %d (we just printed '&a')\n", &a);
 printf ("but if we print '*ptr_to_a' we actually get the value of the variable (a) since our pointer points there: %d (we just printed '*ptr_to_a')\n", *ptr_to_a);
 printf ("Actually we have modified value of 'a' since our pointer 'ptr_to_a' points to 'a' . Let's just 'print a' to verify it: %d\n", a);
 printf ("to make the long story short, ptr_to_a has as value the address of a variable , while '*ptr_to_a' returns the value of the variable in which pointer points to\n");
 printf ("\n\nThe crucial thing to remember when working with pointers is this: you can’t just declare a pointer, as you need to also \n"  
 "declare and associate the variable you want it to point to.When a pointer is created, it points at a random location in memory;\n"  
 "if you try to write something to it, you can cause all sorts of errors up to and including crashing the computer completely!\n" 
 "Always make sure your pointers are pointing at something before doing anything with them.\n");
 int intval = 255958283;
 void *vptr = &intval;
 printf ("\n\nLet's play with void pointers and casting.\n");
 printf ("The value at variable intval is %d\n", intval);
 printf ("The value at vptr as an int is %d\n", *((int *) vptr));
 printf ("The value at vptr as a char is %d\n", *((char *) vptr));
/*
We initialise the void pointer vptr to point to an integer variable called intval.
In the first printf statement, we insert (int *) in front of vptr before we dereference
it using *. This casts vptr to an integer pointer, and so the value of intval is printed as
an integer.
In the second printf statement, we insert (char *) in front of vptr before we
dereference it. This casts vptr to a char pointer, and so what’s printed is the value of the char
which makes up the first byte of intval.
*/
 printf ("\n\nLet's play with pointers and functions\n");
 printf ("summary of 5+2 is :%d\n",summary);
 printf ("difference of 5-2 is :%d\n",difference);
 printf ("multiple of 5*2 is : %d (this is actually global variable multiple)\n",multiple);
 printf ("Using pointers inside function we can send to function (as arguments) addresses of variables of the main programm\n");
 printf ("While our function returns 0, it is modifying the main prog variables that function's local pointers point to\n");
 printf ("This is great , considering that function vars are always local vars and considering also that functions return only ONE value\n");
 printf ("Even if you are allowed to access/modify global vars directly (without pointers) you could use pointers to point to variables of other functions (tricky!)\n");
 printf ("\n\nThis is the function used in this test\n"
 "int sum_and_diff (int a, int b, int *sum, int *diff)\n" 
"{\n" 
"*sum=a+b;\n" 
"*diff=a-b;\n" 
"return 0;\n" 
"}\n" 
"/*and this is how this function is called*/\n" 
"void main (void)\n" 
"{\n" 
"int summary,difference;\n" 
"int res=sum_and_diff(5,2,&summary,&difference);\n");
}
