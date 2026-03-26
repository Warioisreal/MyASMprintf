section .text

global _start


my_printf:
        push rbp
        mov rbp, rsp

        ; [rbp + 16] <- msg
        ; [rbp + 8]  <- ret addr
        ; [rbp]      <- old RBP

        mov rsi, [rbp + 16]

        ; calculate msg len in rdx
        xor rdx, rdx
.count_loop:
        cmp byte [rsi + rdx], 0
        je .do_write
        inc rdx
        jmp .count_loop

.do_write:
        mov rax, 0x01
        mov rdi, 1
        syscall

        pop rbp
        ret

_start:

        push message
        call my_printf
        add rsp, 8

        mov rax, 60
        xor rdi, rdi
        syscall


section .data

message     db "Привет! Это мой printf на ассемблере.", LF, 0
LF          equ 0x0a

section .note.GNU-stack noalloc noexec nowrite progbits
