#include <stdio.h>
#include <float.h>
/* This is a comment
Compile with gcc helloworld.c and run with ./a.out
or use gcc hello.c -o hello.out and then run with ./hello.out

# find / -type f -name 'float.h'
/usr/include/c++/6/tr1/float.h
/usr/include/c++/7/tr1/float.h
/usr/lib/gcc/x86_64-linux-gnu/6/include/float.h
/usr/lib/gcc/x86_64-linux-gnu/5/include/float.h
/usr/lib/gcc/x86_64-linux-gnu/7/include/float.h

Obviously the version of gcc selects the right float.h
*/
#define P_S (4*1024) /*just for testing*/

int main()
{
	int a, b, c;
	float f;
	const int LENGTH = 10;
	const int WIDTH = 5;

    printf("Hello,\t\t world!\n");

    printf("PS is:%d\n",P_S);
    printf("Storage size for int : %d \n", sizeof(int));
    printf("Storage size for float : %d \n", sizeof(float));
	printf("Minimum float positive value: %E\n", FLT_MIN );
	printf("Maximum float positive value: %E\n", FLT_MAX );
	printf("Precision value: %d\n", FLT_DIG );
	a = 10;
	b = 20;

	c = a + b;
	printf("value of c=a+b: c=10+20 ==> %d+%d=%d \n", a,b,c);

	int area;
	area = LENGTH * WIDTH;
	printf("value of area 10 * 5 : %d\n\n", area);
    
    f = 70.0/3.0;
	printf("value of f=70/3 ==> f : %f \n", f);

    return 0;
}

	/*http://stackoverflow.com/documentation/c/507/files-and-i-o-streams#t=201704101223569451915 */
    /* Attempt to open a file, put file contents in an array , print the array and close the file
    FILE *myfile;
    myfile=fopen("file1","r");
    fread(myArray, sizeof(myArray), myfile);
    fclose(myfile); 
    */ 

/* http://www.catonmat.net/blog/awk-book/

C euivalent of awk -F: '{ print $1 }' /etc/passwd

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_LINE_LEN 1024

int main () {
    char line [MAX_LINE_LEN];
    FILE *in = fopen ("/etc/passwd", "r");
    if (!in) exit (EXIT_FAILURE);
    while (fgets(line, MAX_LINE_LEN, in) != NULL) {
        char *sep = strchr(line , ':');
        if (!sep) exit (EXIT_FAILURE);
        *sep = '\0';
        printf("%s\n", line);
    }
    fclose(in);
    return EXIT_SUCCESS ;
}
The strchr function searches string for the first occurrence of a given char. The null character terminating string is included in the search.
*/

