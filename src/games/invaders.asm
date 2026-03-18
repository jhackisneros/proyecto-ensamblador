; src/games/invaders.asm
; SPACE INVADERS SIMPLE
; <- -> Moverse | ENTER disparar | ESC salir
;commit
global show_invaders

%define SYS_READ   3
%define SYS_WRITE  4
%define STDIN      0
%define STDOUT     1

I_W      equ 60
I_H      equ 20

section .data
I_CLS     db 0x1B,'[2J',0x1B,'[H'
I_CLS_L   equ $-I_CLS
I_TITLE   db '           SPACE INVADERS',10,10
I_TITLE_L equ $-I_TITLE
I_HELP    db ' <- -> Mover  |  ENTER Disparar  |  ESC Volver',10,10
I_HELP_L  equ $-I_HELP

I_SCORE   db ' NIVEL 1 | ALIENS ELIMINADOS: 00 / 00',10,10
I_SCORE_L equ $-I_SCORE

I_NEXT    db 10,' NIVEL SUPERADO! (ENTER para continuar)',10
I_NEXT_L  equ $-I_NEXT

I_WIN     db 10,' VICTORIA FINAL! (ENTER para volver)',10
I_WIN_L   equ $-I_WIN

I_LOSE    db 10,' LA TIERRA HA SIDO DESTRUIDA! (ENTER volver)',10
I_LOSE_L  equ $-I_LOSE

inv_fps   dd 0, 20000000  ; 50 FPS

section .bss
i_key         resb 1
i_tmp1        resb 1

p_x           resd 1
b_x           resd 1
b_y           resd 1

a_x           resd 1
a_y           resd 1
adir          resd 1
atimer        resb 1

alive         resb 12
killed        resb 1
ended         resb 1

current_level resb 1
aliens_total  resb 1
speed_limit   resb 1
x_limit       resd 1

linebuf       resb 128

section .text

i_wout:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    int 0x80
    ret

i_rin:
    mov eax, SYS_READ
    mov ebx, STDIN
    int 0x80
    ret

i_p:
    call i_wout
    ret

i_read_key:
    mov ecx, i_key
    mov edx, 1
    call i_rin
    cmp eax, 1
    jne .none
    mov al, [i_key]

    cmp al, 10
    je .enter
    cmp al, 13
    je .enter
    cmp al, 0x1B
    jne .none

    mov ecx, i_tmp1
    mov edx, 1
    call i_rin
    cmp eax, 1
    jne .esc_alone
    mov al, [i_tmp1]
    cmp al, '['
    jne .esc_alone

    mov ecx, i_tmp1
    mov edx, 1
    call i_rin
    cmp eax, 1
    jne .esc_alone
    mov al, [i_tmp1]
    cmp al, 'C'
    je .R
    cmp al, 'D'
    je .L
    xor al, al
    ret

.esc_alone:
    mov al, 'Q'
    ret
.enter:
    mov al, 'E'
    ret
.L:
    mov al, 'L'
    ret
.R:
    mov al, 'R'
    ret
.none:
    xor al, al
    ret

; ------------------------------------------------------------
; Devuelve posición del alien índice ESI
; OUT: EAX = x, EDX = y
;
; Nivel 1: 5 aliens  -> 1 fila (5)
; Nivel 2: 8 aliens  -> 2 filas (4 + 4)
; Nivel 3: 12 aliens -> 3 filas (4 + 4 + 4)
; ------------------------------------------------------------
i_get_alien_pos:
    push ebx
    push ecx

    cmp byte [current_level], 1
    je .lvl1
    cmp byte [current_level], 2
    je .lvl2
    jmp .lvl3

.lvl1:
    ; 5 aliens en una fila
    mov eax, [a_x]
    lea eax, [eax + esi*4]
    mov edx, [a_y]
    jmp .done

.lvl2:
    ; 8 aliens = 2 filas de 4
    mov eax, esi
    xor edx, edx
    mov ecx, 4
    div ecx            ; eax = fila, edx = columna

    mov ebx, eax       ; fila
    mov eax, [a_x]
    lea eax, [eax + edx*4]
    mov edx, [a_y]
    lea edx, [edx + ebx*2]
    jmp .done

.lvl3:
    ; 12 aliens = 3 filas de 4
    mov eax, esi
    xor edx, edx
    mov ecx, 4
    div ecx            ; eax = fila, edx = columna

    mov ebx, eax       ; fila
    mov eax, [a_x]
    lea eax, [eax + edx*4]
    mov edx, [a_y]
    lea edx, [edx + ebx*2]

.done:
    pop ecx
    pop ebx
    ret

i_load_level:
    mov byte [killed], 0
    mov byte [ended], 0
    mov byte [atimer], 0
    mov dword [b_x], 0
    mov dword [b_y], 0
    mov dword [p_x], 30
    mov dword [a_y], 2
    mov dword [adir], 1

    mov ecx, 12
    mov edi, alive
.zero_aliens:
    mov byte [edi], 0
    inc edi
    loop .zero_aliens

    cmp byte [current_level], 1
    je .lvl1
    cmp byte [current_level], 2
    je .lvl2
    jmp .lvl3

.lvl1:
    ; 5 aliens, velocidad normal
    mov byte [aliens_total], 5
    mov byte [speed_limit], 5
    mov dword [a_x], 10
    mov dword [x_limit], 38
    jmp .fill_alive

.lvl2:
    ; 8 aliens, un poco más rápido
    mov byte [aliens_total], 8
    mov byte [speed_limit], 4
    mov dword [a_x], 10
    mov dword [x_limit], 42
    jmp .fill_alive

.lvl3:
    ; 12 aliens, aún más rápido
    mov byte [aliens_total], 12
    mov byte [speed_limit], 3
    mov dword [a_x], 10
    mov dword [x_limit], 42

.fill_alive:
    movzx ecx, byte [aliens_total]
    mov edi, alive
.fill_loop:
    mov byte [edi], 1
    inc edi
    loop .fill_loop
    ret

i_init:
    mov byte [current_level], 1
    call i_load_level
    ret

i_update:
    mov eax, [b_y]
    cmp eax, 0
    je .aliens_turn
    dec eax
    mov [b_y], eax
    cmp eax, 0
    je .aliens_turn

    movzx ecx, byte [aliens_total]
    xor esi, esi
.check_hit:
    mov bl, [alive + esi]
    cmp bl, 0
    je .next_alien

    call i_get_alien_pos

    mov ebx, [b_y]
    cmp ebx, edx
    jne .next_alien

    mov ebx, [b_x]
    cmp ebx, eax
    jl .next_alien
    lea eax, [eax + 2]
    cmp ebx, eax
    jg .next_alien

    mov byte [alive + esi], 0
    mov dword [b_y], 0
    inc byte [killed]

    mov al, [killed]
    cmp al, [aliens_total]
    jne .aliens_turn
    mov byte [ended], 1
    ret

.next_alien:
    inc esi
    loop .check_hit

.aliens_turn:
    inc byte [atimer]
    mov al, [atimer]
    cmp al, [speed_limit]
    jl .done
    mov byte [atimer], 0

    mov eax, [a_x]
    add eax, [adir]
    mov [a_x], eax

    cmp eax, 2
    jl .drop
    cmp eax, [x_limit]
    jg .drop
    jmp .done

.drop:
    mov eax, [adir]
    neg eax
    mov [adir], eax

    mov eax, [a_y]
    inc eax
    mov [a_y], eax

    cmp byte [current_level], 1
    je .check_lvl1
    cmp byte [current_level], 2
    je .check_lvl2
    jmp .check_lvl3

.check_lvl1:
    ; 1 fila
    cmp eax, 18
    jl .done
    mov byte [ended], 2
    jmp .done

.check_lvl2:
    ; 2 filas => la última está a y+2
    mov ebx, eax
    add ebx, 2
    cmp ebx, 18
    jl .done
    mov byte [ended], 2
    jmp .done

.check_lvl3:
    ; 3 filas => la última está a y+4
    mov ebx, eax
    add ebx, 4
    cmp ebx, 18
    jl .done
    mov byte [ended], 2

.done:
    ret

i_draw_row:
    pushad
    mov ebp, eax

    mov byte [linebuf+0], '|'
    mov ecx, (I_W-2)
    mov edi, linebuf+1
.fsp:
    mov byte [edi], ' '
    inc edi
    loop .fsp
    mov byte [linebuf + (I_W-1)], '|'
    mov byte [linebuf + I_W], 10

    cmp ebp, 0
    je .border
    cmp ebp, I_H
    je .border
    jmp .draw_aliens

.border:
    mov ecx, (I_W-2)
    mov edi, linebuf+1
.fbd:
    mov byte [edi], '-'
    inc edi
    loop .fbd
    jmp .print

.draw_aliens:
    movzx ecx, byte [aliens_total]
    xor ebx, ebx
.draw_a:
    mov al, [alive + ebx]
    cmp al, 0
    je .skip_a

    mov esi, ebx
    call i_get_alien_pos
    cmp edx, ebp
    jne .skip_a

    mov edi, linebuf
    add edi, eax
    mov byte [edi], 'M'
    mov byte [edi+1], 'W'
    mov byte [edi+2], 'M'

.skip_a:
    inc ebx
    loop .draw_a

.check_bullet:
    cmp ebp, [b_y]
    jne .check_player
    mov eax, [b_x]
    mov edi, linebuf
    add edi, eax
    mov byte [edi], '^'

.check_player:
    cmp ebp, 18
    jne .print
    mov eax, [p_x]
    mov edi, linebuf
    add edi, eax
    mov byte [edi], '/'
    mov byte [edi+1], 'A'
    mov byte [edi+2], '\'

.print:
    mov ecx, linebuf
    mov edx, (I_W+1)
    call i_p
    popad
    ret

i_draw:
    mov ecx, I_CLS
    mov edx, I_CLS_L
    call i_p

    mov ecx, I_TITLE
    mov edx, I_TITLE_L
    call i_p

    mov ecx, I_HELP
    mov edx, I_HELP_L
    call i_p

    mov al, [current_level]
    add al, '0'
    mov [I_SCORE + 7], al

    mov al, [killed]
    aam
    add ax, 0x3030
    mov [I_SCORE + 30], ah
    mov [I_SCORE + 31], al

    mov al, [aliens_total]
    aam
    add ax, 0x3030
    mov [I_SCORE + 35], ah
    mov [I_SCORE + 36], al

    mov ecx, I_SCORE
    mov edx, I_SCORE_L
    call i_p

    mov eax, 0
.rowloop:
    cmp eax, I_H
    jg .done
    push eax
    call i_draw_row
    pop eax
    inc eax
    jmp .rowloop
.done:
    ret

show_invaders:
    call i_init

.loop:
    call i_draw

    mov eax, 162
    mov ebx, inv_fps
    xor ecx, ecx
    int 0x80

    mov al, [ended]
    cmp al, 0
    jne .end_screen

    call i_read_key
    cmp al, 'Q'
    je .ret_menu
    cmp al, 'L'
    je .moveL
    cmp al, 'R'
    je .moveR
    cmp al, 'E'
    je .shoot
    jmp .tick

.moveL:
    mov eax, [p_x]
    cmp eax, 2
    jle .tick
    sub eax, 2
    mov [p_x], eax
    jmp .tick

.moveR:
    mov eax, [p_x]
    cmp eax, 54
    jge .tick
    add eax, 2
    mov [p_x], eax
    jmp .tick

.shoot:
    cmp dword [b_y], 0
    jne .tick
    mov eax, [p_x]
    inc eax
    mov [b_x], eax
    mov dword [b_y], 17
    jmp .tick

.tick:
    call i_update
    jmp .loop

.end_screen:
    call i_draw

    cmp byte [ended], 1
    jne .lose_screen

    cmp byte [current_level], 3
    je .final_win

    mov ecx, I_NEXT
    mov edx, I_NEXT_L
    call i_p
    jmp .wait_next

.final_win:
    mov ecx, I_WIN
    mov edx, I_WIN_L
    call i_p
    jmp .wait_end

.lose_screen:
    mov ecx, I_LOSE
    mov edx, I_LOSE_L
    call i_p
    jmp .wait_end

.wait_next:
    call i_read_key
    cmp al, 'E'
    je .go_next
    cmp al, 'Q'
    je .ret_menu
    jmp .wait_next

.go_next:
    inc byte [current_level]
    call i_load_level
    jmp .loop

.wait_end:
    call i_read_key
    cmp al, 'E'
    je .ret_menu
    cmp al, 'Q'
    je .ret_menu
    jmp .wait_end

.ret_menu:
    ret
