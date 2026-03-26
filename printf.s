section .bss
        char_buf        resb 1
        num_buffer      resb 64
        num_buffer_end:


section .rodata
        hex_chars       db "0123456789ABCDEF"
        align 8
jump_table:
        %assign i 0
        %rep 256
                %if i == '%'
                        dq .handle_percent
                %elif i == 'b'
                        dq .handle_b
                %elif i == 'c'
                        dq .handle_c
                %elif i == 'd'
                        dq .handle_d
                %elif i == 'o'
                        dq .handle_o
                %elif i == 's'
                        dq .handle_s
                %elif i == 'x'
                        dq .handle_x
                %else
                        dq .default
                %endif
                %assign i i+1
        %endrep

section .text

global _start

;=========================================================

print_char:
        push rsi
        mov [char_buf], al

        mov rax, 0x01
        mov rdi, 1
        mov rsi, char_buf
        mov rdx, 1          ; msg len
        syscall

        pop rsi
        ret

;=========================================================

print_num:
        push rsi

        lea rsi, [num_buffer_end - 1]

.convert_loop:
        xor rdx, rdx
        div r10                     ; rax = rax / r10, rdx = rax % r10

        push rax
        mov al, [hex_chars + rdx]
        mov [rsi], al
        pop rax

        dec rsi
        cmp rax, 0
        jne .convert_loop

        inc rsi         ; rsi -> first digit in num_buffer

.print:
        mov rax, 0x01
        mov rdi, 1
        mov rdx, num_buffer_end
        sub rdx, rsi
        syscall

        pop rsi
        ret

;=========================================================

print_string:
        push rsi

        mov rdi, rax
        mov rsi, rax

        xor rdx, rdx
.len_loop:
        cmp byte [rdi + rdx], 0
        je .do_print
        inc rdx
        jmp .len_loop
.do_print:
        cmp rdx, 0
        je .done

        mov rax, 0x01
        mov rdi, 1
        syscall

.done:
        pop rsi
        ret

;=========================================================

my_printf:
        push rbp
        mov rbp, rsp
        ; ...
        ; [rbp + 32] -> 2 spec arg
        ; [rbp + 24] -> 1 spec arg
        ; [rbp + 16] -> fmt

        mov rsi, [rbp + 16]
        xor rbx, rbx        ; set on first arg

.loop:
        mov al, [rsi]       ; take fmt symbol

        cmp al, 0           ; is end ?
        je .done

        cmp al, '%'         ; is %... ?
        je .spec

        call print_char

        inc rsi
        jmp .loop

.spec:
        inc rsi             ; skip '%'
        movzx rax, byte [rsi]

        jmp [jump_table + rax * 8]

.handle_c:
        mov rax, [rbp + 24 + rbx]
        call print_char
        jmp .next_arg
.handle_b:
        mov rax, [rbp + 24 + rbx]
        mov r10, 2
        call print_num
        jmp .next_arg
.handle_o:
        mov rax, [rbp + 24 + rbx]
        mov r10, 8
        call print_num
        jmp .next_arg
.handle_d:
        mov rax, [rbp + 24 + rbx]
        mov r10, 10
        call print_num
        jmp .next_arg
.handle_x:
        mov rax, [rbp + 24 + rbx]
        mov r10, 16
        call print_num
        jmp .next_arg
.handle_s:
        mov rax, [rbp + 24 + rbx]
        call print_string
        jmp .next_arg
        jmp .next_arg
.handle_percent:
        mov al, '%'
        call print_char
        inc rsi
        jmp .loop
.default:
        mov al, [rsi]
        call print_char
        inc rsi
        jmp .loop
.next_arg:
        add rbx, 8      ; got to next arg
        inc rsi
        jmp .loop

.done:
        ; ...
        ; [rsp + 24] -> 2 spec arg
        ; [rsp + 16] -> 1 spec arg
        ; [rsp + 8] -> fmt
        pop rbp

        ; clear stack
        add rbx, 8
        pop r11
        add rsp, rbx
        push r11

        ret

;=========================================================

_start:
        push msg
        push 10
        push 10
        push 10
        push 10
        push fmt

        call my_printf

        mov rax, 60
        xor rdi, rdi
        syscall


section .data
        fmt     db "Аргумент из стека: %x %d %o %b | %s %%", LF, 0
        msg     db "Hello, World!", 0
        LF      equ 0x0a


section .note.GNU-stack noalloc noexec nowrite progbits
