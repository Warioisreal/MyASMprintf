default rel


section .bss
        char_buf        resb 1
        num_buffer      resb 64
        num_buffer_end:

;=========================================================

section .rodata
        addr_prefix     db "0x", 0
        hex_chars       db "0123456789ABCDEF"
        DEF_OFS         equ 40
        align 8
jump_table:
        %assign i 0
        %rep 256
                %if i == '%'
                        dd my_printf.handle_percent - jump_table
                %elif i == 'b'
                        dd my_printf.handle_b - jump_table
                %elif i == 'c'
                        dd my_printf.handle_c - jump_table
                %elif i == 'd'
                        dd my_printf.handle_d - jump_table
                %elif i == 'o'
                        dd my_printf.handle_o - jump_table
                %elif i == 's'
                        dd my_printf.handle_s - jump_table
                %elif i == 'x'
                        dd my_printf.handle_x - jump_table
                %else
                        dd my_printf.default - jump_table
                %endif
                %assign i i+1
        %endrep

;=========================================================

section .text

extern printf
global my_printf

;---------------------------------------------------------
; Функция:              print_char
; Назначение:           Выводит один ASCII-символ в stdout
; Состояние системы:    Стек выровнен (стандартный call), char_buf доступен для записи
; Вход:                 AL = ASCII-код символа для печати
; Сохранённые регистры: RSI
; Испорченные регистры: RAX, RDX, RDI, R11
;---------------------------------------------------------
print_char:
        push rsi

        lea r11, [char_buf]
        mov [r11], al

        mov rax, 0x01
        mov rdi, 1
        lea rsi, [char_buf]
        mov rdx, 1          ; msg len
        syscall

        pop rsi
        ret

;---------------------------------------------------------
; Функция:              print_num
; Назначение:           Преобразует 64-битное целое без знака в строку и выводит её
; Состояние системы:    R12 содержит корректное основание (2-16), num_buffer доступен
; Вход:                 RAX = Число для печати, R12 = Основание системы счисления
; Сохранённые регистры: RSI
; Испорченные регистры: RAX, RDX, RDI, R11
;---------------------------------------------------------
print_num:
        push rsi

        lea rsi, [num_buffer_end - 1]

.convert_loop:
        xor rdx, rdx
        div r12                     ; rax = rax / r12, rdx = rax % r12

        push rax
        lea r11, [hex_chars]
        mov al, [r11 + rdx]
        mov [rsi], al
        pop rax

        dec rsi
        cmp rax, 0
        jne .convert_loop

        inc rsi         ; rsi -> first digit in num_buffer

.print:
        mov rax, 0x01
        mov rdi, 1
        lea rdx, [num_buffer_end]
        sub rdx, rsi
        syscall

        pop rsi
        ret

;---------------------------------------------------------
; Функция:              print_string
; Назначение:           Выводит в stdout строку, завершенную нулем (null-terminated)
; Состояние системы:    RAX содержит валидный адрес строки, строка заканчивается 0x00
; Вход:                 RAX = Указатель (адрес) на начало строки
; Сохранённые регистры: RSI
; Испорченные регистры: RAX, RDX, RDI, R11
;---------------------------------------------------------
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

;---------------------------------------------------------

my_printf:
        ; ===== trampoline =====
        pop r10         ; return address

        push r9         ; arg4
        push r8         ; arg3
        push rcx        ; arg2
        push rdx        ; arg1
        push rsi        ; arg0
        push rdi        ; fmt

        push r10
        ; ======================

        push rbp
        push rbx
        push r12
        mov rbp, rsp

        mov rsi, rdi    ; rsi = fmt
        xor rbx, rbx    ; rbx = 0 (0, 8, 16...)

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
        inc rsi                             ; skip '%'
        movzx rax, byte [rsi]

        lea r11, [rel jump_table]
        movsxd rax, dword [r11 + rax * 4]
        add rax, r11
        jmp rax

.handle_c:
        mov rax, [rbp + DEF_OFS + rbx]
        call print_char
        jmp .next_arg
.handle_b:
        mov rax, [rbp + DEF_OFS + rbx]
        mov r12, 2
        call print_num
        jmp .next_arg
.handle_o:
        mov rax, [rbp + DEF_OFS + rbx]
        mov r12, 8
        call print_num
        jmp .next_arg
.handle_d:
        mov rax, [rbp + DEF_OFS + rbx]
        mov r12, 10

        cmp rax, 0
        jge .positive

        push rax
        mov al, '-'
        call print_char
        pop rax
        neg rax         ; get abs value

.positive:
        call print_num
        jmp .next_arg
.handle_x:
        mov rax, [rbp + DEF_OFS + rbx]
        mov r12, 16
        call print_num
        jmp .next_arg

.handle_s:
        mov rax, [rbp + DEF_OFS + rbx]
        call print_string
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
        ; [rbp + 24] -> arg0
        ; [rbp + 16] -> fmt
        ; [rbp + 8]  -> ret_addr
        ; [rbp]      -> old RBP
        pop r12
        pop rbx
        pop rbp         ; restore RBP
        pop r11         ; save ret addr

        mov rdi, [rsp]
        mov rsi, [rsp + 8]
        mov rdx, [rsp + 16]
        mov rcx, [rsp + 24]
        mov r8,  [rsp + 32]
        mov r9,  [rsp + 40]

        ; clear stack
        add rsp, 48     ; only my 6 arg from trampoline
        push r11        ; back ret addr

        xor rax, rax
        call printf wrt ..plt

        ret

;=========================================================

section .note.GNU-stack noalloc noexec nowrite progbits
