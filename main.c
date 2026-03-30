#include <stdio.h>


extern void my_printf(const char* fmt, ...) __attribute__((format(printf, 1, 2)));


int main(void) {
    long long a = 10;

    printf("----------------------------------------\n");

    my_printf("%d %s %x %d%%%c\n"
                "Aboba %x %d %o %b\n",
                -1, "love", 3802, 100, 33,
                0xAA, 0xAA, 0xAA, 0xAA);

    printf("----------------------------------------\n");

    return 0;
}
