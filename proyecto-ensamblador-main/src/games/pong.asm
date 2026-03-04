; src/games/pong.asm
; PONG (2 jugadores) - palas HORIZONTALES:
;   P1 (arriba): A / D
;   P2 (abajo): Flechas <- ->
;   ESC: volver al menu
; Terminal ya esta en RAW mode (lo hace main.asm)

global show_pong

%define SYS_READ   3
%define SYS_WRITE  4
%define STDIN      0
%define STDOUT     1

P_W      equ 60
P_H      equ 20
P_INW    equ (P_W-2)
P_INH    equ (P_H-2)
P_PAD    equ 9

Y_TOPPAD equ 2
Y_BOTPAD equ (P_H-2)

section .data

P_CLS     db 0x1B,'[2J',0x1B,'[H'
P_CLS_L   equ $-P_CLS

P_TITLE   db '                  PONG',10,10
P_TITLE_L equ $-P_TITLE

P_HELP    db 'P1: A/D (arriba)   P2: <- -> (abajo)   ESC: volver',10,10
P_HELP_L  equ $-P_HELP

P_SCORE   db 'P1: 0   P2: 0',10,10
P_SCORE_L equ $-P_SCORE

P_WIN1    db 10,'GANA P1!  (ENTER para volver)',10
P_WIN1_L  equ $-P_WIN1
P_WIN2    db 10,'GANA P2!  (ENTER para volver)',10
P_WIN2_L  equ $-P_WIN2

timespec:
    dd 0          ; Segundos
    dd 200000000   ; Nanosegundos (aprox. 50 FPS.)
    fps_delay dd 0, 20000000  ; 0 segundos, 20,000,000 nanosegundos
    pong_fps dd 0, 150000000

section .bss
p_key     resb 1
p_tmp1    resb 1

p1x       resd 1
p2x       resd 1
ballx        resd 1
bally        resd 1
vx        resd 1
vy        resd 1

s1        resb 1
s2        resb 1
ended     resb 1

linebuf   resb 128

delay_sec  dd 0
delay_nsec dd 16666666  ; 16.6 milisegundos

section .text

p_wout:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    int 0x80
    ret

p_rin:
    mov eax, SYS_READ
    mov ebx, STDIN
    int 0x80
    ret

p_p:
    call p_wout
    ret

; returns AL: 'A','D','L','R','E','Q' or 0
p_read_key:
    mov ecx, p_key
    mov edx, 1
    call p_rin
    cmp eax, 1
    jne .none
    mov al, [p_key]

    cmp al, 10
    je .enter
    cmp al, 13
    je .enter

    cmp al, 'a'
    je .A
    cmp al, 'A'
    je .A
    cmp al, 'd'
    je .D
    cmp al, 'D'
    je .D

    cmp al, 0x1B
    jne .none

    mov ecx, p_tmp1
    mov edx, 1
    call p_rin
    cmp eax, 1
    jne .esc_alone
    mov al, [p_tmp1]
    cmp al, '['
    jne .esc_alone

    mov ecx, p_tmp1
    mov edx, 1
    call p_rin
    cmp eax, 1
    jne .esc_alone
    mov al, [p_tmp1]
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
.A:
    mov al, 'A'
    ret
.D:
    mov al, 'D'
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

p_center_paddle:
    mov eax, (P_INW - P_PAD)
    shr eax, 1
    inc eax
    ret

p_ball_center:
    mov eax, P_INW
    shr eax, 1
    inc eax
    ret

p_init:
    call p_center_paddle
    mov [p1x], eax
    mov [p2x], eax

    call p_ball_center
    mov [ballx], eax
    mov eax, (P_INH/2 + 1)
    mov [bally], eax

    mov dword [vx], 1
    mov dword [vy], 1

    mov byte [s1], 0
    mov byte [s2], 0
    mov byte [ended], 0
    ret

p_clamp_p1:
    mov eax, [p1x]
    cmp eax, 1
    jge .okL
    mov eax, 1
.okL:
    mov edx, (P_W - P_PAD - 1)
    cmp eax, edx
    jle .okR
    mov eax, edx
.okR:
    mov [p1x], eax
    ret

p_clamp_p2:
    mov eax, [p2x]
    cmp eax, 1
    jge .okL2
    mov eax, 1
.okL2:
    mov edx, (P_W - P_PAD - 1)
    cmp eax, edx
    jle .okR2
    mov eax, edx
.okR2:
    mov [p2x], eax
    ret

p_reset_ball:
    call p_ball_center
    mov [ballx], eax
    mov eax, (P_INH/2 + 1)
    mov [bally], eax

    ; AL: 1 si marca P1, 2 si marca P2
    cmp al, 1
    jne .toP1
    mov dword [vy], 1
    jmp .vxset
.toP1:
    mov dword [vy], -1
.vxset:
    mov dword [vx], 1
    ret

p_adjust_vx:
    cmp eax, 2
    jg .chkRight
    mov dword [vx], -1
    ret
.chkRight:
    cmp eax, 6
    jl .keep
    mov dword [vx], 1
.keep:
    ret

p_update:
    ; rebote lateral
    mov eax, [ballx]
    mov edx, [vx]
    cmp eax, 1
    jne .chkRightWall
    cmp edx, -1
    jne .chkRightWall
    mov dword [vx], 1
.chkRightWall:
    mov eax, [ballx]
    mov edx, [vx]
    cmp eax, (P_W-2)
    jne .nextY
    cmp edx, 1
    jne .nextY
    mov dword [vx], -1

.nextY:
    ; next x,y
    mov eax, [ballx]
    add eax, [vx]
    mov esi, eax

    mov eax, [bally]
    add eax, [vy]
    mov edi, eax

    ; top paddle line
    cmp edi, Y_TOPPAD
    jne .chkBotPad

    mov dword [vy], 1
    jmp .applyMove

.scoreP2:
    mov al, 2
    inc byte [s2]
    cmp byte [s2], 5
    jne .reset
    mov byte [ended], 2
    ret
.reset:
    call p_reset_ball
    ret

.chkBotPad:
    cmp edi, Y_BOTPAD
    jne .applyMove

    mov eax, [p2x]
    mov ebx, eax
    add ebx, (P_PAD-1)
    cmp esi, eax
    jl .scoreP1
    cmp esi, ebx
    jg .scoreP1

    mov dword [vy], -1
    mov eax, esi
    sub eax, [p2x]
    call p_adjust_vx
    jmp .applyMove

.scoreP1:
    mov al, 1
    inc byte [s1]
    cmp byte [s1], 5
    jne .reset2
    mov byte [ended], 1
    ret
.reset2:
    call p_reset_ball
    ret

.applyMove:
    mov [ballx], esi
    mov [bally], edi
    ret

p_draw_border:
    mov byte [linebuf+0], '+'
    mov ecx, (P_W-2)
    mov edi, linebuf+1
.fill:
    mov byte [edi], '-'
    inc edi
    loop .fill
    mov byte [linebuf + (P_W-1)], '+'
    mov byte [linebuf + (P_W)], 10
    mov ecx, linebuf
    mov edx, (P_W+1)
    call p_p
    ret

p_draw_row:
    pushad
    mov esi, eax

    mov byte [linebuf+0], '|'
    mov ecx, (P_W-2)
    mov edi, linebuf+1
.fsp:
    mov byte [edi], ' '
    inc edi
    loop .fsp

    mov byte [linebuf + (P_W-1)], '|'
    mov byte [linebuf + (P_W)], 10

    ; paddles
    cmp esi, Y_TOPPAD
    jne .botpad
    mov eax, [p1x]
    mov ecx, P_PAD
    mov edi, linebuf
    add edi, eax
.pt:
    mov byte [edi], '='
    inc edi
    loop .pt
.botpad:
    cmp esi, Y_BOTPAD
    jne .ball
    mov eax, [p2x]
    mov ecx, P_PAD
    mov edi, linebuf
    add edi, eax
.pb:
    mov byte [edi], '='
    inc edi
    loop .pb

.ball:
    mov eax, [bally]
    cmp eax, esi
    jne .out
    mov eax, [ballx]
    mov edi, linebuf
    add edi, eax
    mov byte [edi], 'O'

.out:
    mov ecx, linebuf
    mov edx, (P_W+1)
    call p_p
    popad
    ret

p_draw:
    mov ecx, P_CLS
    mov edx, P_CLS_L
    call p_p

    mov ecx, P_TITLE
    mov edx, P_TITLE_L
    call p_p

    mov ecx, P_HELP
    mov edx, P_HELP_L
    call p_p

    ; patch digits
    mov al, [s1]
    add al, '0'
    mov [P_SCORE+4], al
    mov al, [s2]
    add al, '0'
    mov [P_SCORE+12], al

    mov ecx, P_SCORE
    mov edx, P_SCORE_L
    call p_p

    call p_draw_border
    mov eax, 1
.rowloop:
    cmp eax, (P_H-2)
    jg .done
    push eax
    call p_draw_row
    pop eax
    inc eax
    jmp .rowloop
.done:
    call p_draw_border
    ret

p_wait_enter:
.w:
    call p_read_key
    cmp al, 'E'
    je .ok
    cmp al, 'Q'
    je .ok
    jmp .w
.ok:
    ret

show_pong:
    call p_init
.loop:
    call p_draw

    ; 1. EL RELOJ: Pausa obligatoria de 20ms en cada vuelta
    mov eax, 162            ; syscall: sys_nanosleep
    mov ebx, pong_fps
    xor ecx, ecx
    int 0x80

    call p_read_key         ; 2. Leer teclado (ahora es instantáneo)
    cmp al, 'Q'
    je .ret_menu

    ; 3. MOVIMIENTO POR TOQUE (Aumentado a 3 unidades)
    cmp al, 'L'
    je .moveL
    cmp al, 'R'
    je .moveR
    jmp .tick

.moveL:
    mov eax, [p2x]
    sub eax, 3              ; <--- Se mueve 3 espacios en lugar de 1
    mov [p2x], eax
    call p_clamp_p2
    jmp .tick

.moveR:
    mov eax, [p2x]
    add eax, 3              ; <--- Se mueve 3 espacios
    mov [p2x], eax
    call p_clamp_p2

.tick:
    call p_update           ; 4. Actualizar física de la bola
    jmp .loop

.end_screen:
    mov ecx, P_CLS
    mov edx, P_CLS_L
    call p_p

    cmp byte [ended], 1
    jne .w2
    mov ecx, P_WIN1
    mov edx, P_WIN1_L
    call p_p
    jmp .wait
.w2:
    mov ecx, P_WIN2
    mov edx, P_WIN2_L
    call p_p
.wait:
    call p_wait_enter
    ret

.ret_menu:
    ret
