default rel


section .bss
        char_buf        resb 1
        num_buffer      resb 64
        num_buffer_end:
        ret_addr        resb 8
        general_buffer  resb G_BUF_CAP

;=========================================================
section .rodata
        addr_prefix     db "0x", 0
        hex_chars       db "0123456789abcdef"
        DEF_OFS         equ 40
        G_BUF_CAP       equ 256
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


flash_buf:
        push rcx
        cmp rdx, 0
        jle .done

        push rsi

        mov rax, 0x01
        mov rdi, 1
        lea rsi, [rel general_buffer]
        syscall

        pop rsi
.done:

        pop rcx

        xor rdx, rdx
        ret

;---------------------------------------------------------

;---------------------------------------------------------
print_to_buf:
        cmp rcx, 0
        jle .done

        cmp rcx, G_BUF_CAP
        jb .medium_data         ; if (RCX < G_BUF_CAP) goto medium_data_zone

        call flash_buf          ; RDX = 0 (free)
.loop:
        mov rdx, rcx            ; save RCX to free RDX

        cld
        lea rdi, [rel general_buffer]
        mov rcx, G_BUF_CAP
        shr rcx, 3
        rep movsq

        mov rcx, rdx            ; restore RCX, RDX = trash (free)

        mov rdx, G_BUF_CAP      ; RDX = 256 (full buffer)
        sub rcx, G_BUF_CAP      ; RCX = RCX - 256

        call flash_buf          ; RDX = 0 (free)

        cmp rcx, G_BUF_CAP
        jae .loop               ; while (RCX >= G_BUF_CAP) goto loop


.medium_data:
        mov r13, G_BUF_CAP
        sub r13, rdx

        cmp rcx, r13
        jbe .small_data         ; if (RCX <= G_BUF_CAP - RDX) goto small_data_zone

        call flash_buf


.small_data:
        mov r13, rdx
        add r13, rcx

        cld
        lea rdi, [rel general_buffer]
        add rdi, rdx
        ; RCX = msg last bite count
        rep movsb

        mov rdx, r13
.done:
        ret

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

        lea r11, [rel char_buf]
        mov [r11], al

        lea rsi, [rel char_buf]
        mov rcx, 1

        call print_to_buf

        pop rsi
        ret

;---------------------------------------------------------
; Функция:              print_num
; Назначение:           Преобразует 64-битное целое без знака в строку и выводит её
; Состояние системы:    R12 содержит корректное основание, num_buffer доступен
; Вход:                 RAX = Число для печати, R12 = Основание системы счисления
; Сохранённые регистры: RSI, RDX, R12
; Испорченные регистры: RAX, RCX, RDI, R11
;---------------------------------------------------------
print_num:
        push rsi
        push rdx

        lea rsi, [rel num_buffer_end - 1]

        lea r11, [rel hex_chars]
.convert_loop:
        xor rdx, rdx
        div r12                     ; rax = rax / r12, rdx = rax % r12

        mov rdi, rax
        mov al, [r11 + rdx]
        mov [rsi], al
        mov rax, rdi

        dec rsi
        cmp rax, 0
        jne .convert_loop

        inc rsi         ; rsi -> first digit in num_buffer

.print:
        lea rcx, [rel num_buffer_end]
        sub rcx, rsi

        pop rdx
        call print_to_buf

        pop rsi
        ret

;---------------------------------------------------------
; Функция:              print_num_pow2
; Назначение:           Быстрый вывод для систем счисления 2, 8, 16, ... (степени 2)
; Состояние системы:    R12 содержит корректное основание, num_buffer доступен
; Вход:                 RAX = Число для печати, R12 = Основание системы счисления
; Сохранённые регистры: RSI, RDX
; Испорченные регистры: RAX, RCX, RDI, R11, R12
;---------------------------------------------------------
print_num_pow2:
        push rsi
        push rdx

        lea rsi, [rel num_buffer_end - 1]

        bsf rcx, r12            ; RCX = deg of 2
        dec r12                 ; R12 = 2^cs - 1 (bit mask)

        lea r11, [rel hex_chars]

.convert_loop:
        mov rdx, rax
        and rdx, r12

        mov dl, [r11 + rdx]     ; get symbol
        mov [rsi], dl

        shr rax, cl
        dec rsi

        cmp rax, 0
        jne .convert_loop

        inc rsi

.print:
        lea rcx, [rel num_buffer_end]
        sub rcx, rsi

        pop rdx
        call print_to_buf

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

        xor rcx, rcx
.len_loop:
        cmp byte [rdi + rcx], 0
        je .print

        inc rcx
        jmp .len_loop
.print:
        call print_to_buf

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
        xor rdx, rdx

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

        lea r11, [rel general_buffer]
        add r11, rcx
        jmp rax

.handle_c:
        mov rax, [rbp + DEF_OFS + rbx]
        call print_char
        jmp .next_arg
.handle_b:
        mov eax, dword [rbp + DEF_OFS + rbx]
        mov r12, 2
        call print_num_pow2
        jmp .next_arg
.handle_o:
        mov eax, dword [rbp + DEF_OFS + rbx]
        mov r12, 8
        call print_num_pow2
        jmp .next_arg
.handle_d:
        movsxd rax, dword [rbp + DEF_OFS + rbx]
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
        mov eax, dword [rbp + DEF_OFS + rbx]
        mov r12, 16
        call print_num_pow2
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
        call flash_buf
        ; ...
        ; [rbp + 24] -> arg0
        ; [rbp + 16] -> fmt
        ; [rbp + 8]  -> ret_addr
        ; [rbp]      -> old RBP
        pop r12
        pop rbx
        pop rbp         ; restore RBP

        pop qword [rel ret_addr]        ; save ret addr

        mov rdi, [rsp]
        mov rsi, [rsp + 8]
        mov rdx, [rsp + 16]
        mov rcx, [rsp + 24]
        mov r8,  [rsp + 32]
        mov r9,  [rsp + 40]

        ; clear stack
        add rsp, 48                     ; only my 6 arg from trampoline

        xor rax, rax
        call printf wrt ..plt

        push qword [rel ret_addr]       ; back ret addr
        ret

;=========================================================

section .note.GNU-stack noalloc noexec nowrite progbits
