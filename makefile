all: assembly link
	./printf
	@rm -rf printf.o

link:
	clang-14 -O0 -no-pie main.c printf.o -o printf

assembly:
	nasm -f elf64 printf.s -o printf.o
