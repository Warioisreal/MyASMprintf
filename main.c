extern void my_printf(const char* fmt, ...);


int main(void) {
    long long a = 10;

    my_printf("Aboba %c %x %d %o %s %% %b\n", '!', (long long)0xABCDEF, (long long)-10, (long long)0xA, "real!?", (long long)0xA);

    return 0;
}
