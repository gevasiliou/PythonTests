#include <stdio.h>

int main(){
    int c, d;
    c = getchar();
    if (c == EOF) return 0; // edge case, empty file
    for (d = getchar(); d != EOF; c = d, d = getchar())
            if (c != ',' || d != '\r') putchar(c);
    putchar(c); // last char in file
}

/* 
Usage
$ cc comma.c
$ ./a <InputFile >OutputFile

Operation: 
For lines ending with ,\r removes the comma and line ends with \r
sed equivalent: sed 's/,\r/\r/g' inputfile >outputFile

Input
"India","Australia",1991-07-03,99,\r
1991-07-03,99,"India","Australia",\r

Output
"India","Australia",1991-07-03,99\r
1991-07-03,99,"India","Australia"\r
*/
