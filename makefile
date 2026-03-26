all: assembly link
	./printf

link:
	clang-14 -O0 main.c printf.o -o printf

assembly:
	nasm -f elf64 printf.s -o printf.o
