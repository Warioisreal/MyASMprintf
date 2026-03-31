#include <stdio.h>


extern void my_printf(const char* fmt, ...) __attribute__((format(printf, 1, 2)));


int main(void) {
    char string[600] = {0};

    for (int i = 0; i < 300; i++) {
        string[i] = '0' + i / 10;
    } string[298] = '\n'; string[299] = 0;

    printf("\n----------------------------------------\n\n");

    my_printf("%d %s %x %d%%%c\n"
                "Aboba %x %d %o %b\n",
                -1, "love", 3802, 100, 33,
                0xAA, 0xAA, 0xAA, 0xAA);

    printf("\n----------------------------------------\n\n");

    my_printf("%s"
                "%s\n", string, string);
    printf("\n----------------------------------------\n\n");

    return 0;
}
