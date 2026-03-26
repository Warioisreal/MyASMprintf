#include <stdio.h>
#include <stdlib.h>


extern void MyPrintf();


int main(void) {
    printf("\n>>> main(): start\n\n");

    int a = 85, b = 14;

    MyPrintf();

    printf("\n<<< main(): end\n\n");

    return 0;
}
