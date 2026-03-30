#include <stdio.h>


extern void my_printf(const char* fmt, ...) __attribute__((format(printf, 1, 2)));


int main(void) {
    long long a = 10;

    printf("----------------------------------------\n");

    my_printf("Aboba %c %x %d %o %s %% %b\n", '!', 0xABCDEF, -10, (int)a, "real!?", 0xA);

    printf("----------------------------------------\n");

    return 0;
}
