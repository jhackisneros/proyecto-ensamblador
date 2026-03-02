; src/games/pong.asm
; PONG (2 jugadores) - palas HORIZONTALES:
;   P1 (arriba): A / D
;   P2 (abajo): Flechas <- ->
;   ESC: volver al menu
; Terminal ya está en RAW mode (lo hace main.asm)

global show_pong

%define SYS_READ   3
%define SYS_WRITE  4
%define STDIN      0
%define STDOUT     1

%define P_W        60              ; ancho total (incluye bordes)
%define P_H        20              ; alto total  (incluye bordes)
%define P_INW      (P_W-2)         ; ancho interior
%define P_INH      (P_H-2)         ; alto interior
%define P_PAD      9               ; largo pala

%define Y_TOPPAD   2
%define Y_BOTPAD   (P_H-2)

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

P_NL      db 10

section .bss
p_key     resb 1
p_tmp1    resb 1

p1x       resd 1        ; pala arriba (x inicio interior)
p2x       resd 1        ; pala abajo
bx        resd 1        ; bola x (1..P_W-2)
by        resd 1        ; bola y (1..P_H-2)
vx        resd 1        ; -1 / +1
vy        resd 1        ; -1 / +1

s1        resb 1        ; score P1
s2        resb 1        ; score P2

ended     resb 1        ; 0 jugando, 1 gana P1, 2 gana P2
ch        resb 1
linebuf   resb 128      ; para imprimir una linea

section .text

; -------- sys_write(STDOUT, ecx, edx) --------
p_wout:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    int 0x80
    ret

; -------- sys_read(STDIN, ecx, edx) -> eax bytes --------
p_rin:
    mov eax, SYS_READ
    mov ebx, STDIN
    int 0x80
    ret

p_p:
    call p_wout
    ret

; -------- read key --------
; returns AL: 'A','D','L','R','E','Q' or 0
p_read_key:
    mov ecx, p_key
    mov edx, 1
    call p_rin
    cmp eax, 1
    jne .none
    mov al, [p_key]

    ; ENTER (10/13)
    cmp al, 10
    je .enter
    cmp al, 13
    je .enter

    ; letras a/d
    cmp al, 'a'
    je .A
    cmp al, 'A'
    je .A
    cmp al, 'd'
    je .D
    cmp al, 'D'
    je .D

    ; ESC o flechas
    cmp al, 0x1B
    jne .none

    ; intenta leer '[' (si no llega, ESC solo)
    mov ecx, p_tmp1
    mov edx, 1
    call p_rin
    cmp eax, 1
    jne .esc_alone
    mov al, [p_tmp1]
    cmp al, '['
    jne .esc_alone

    ; siguiente byte C/D
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

; -------- helpers --------
p_center_paddle:
    ; start_x = (P_INW - P_PAD)/2 + 1
    mov eax, (P_INW - P_PAD)
    shr eax, 1
    inc eax
    ret

p_ball_center:
    ; x = P_INW/2 + 1
    mov eax, P_INW
    shr eax, 1
    inc eax
    ret

p_init:
    ; palas al centro
    call p_center_paddle
    mov [p1x], eax
    mov [p2x], eax

    ; bola centro
    call p_ball_center
    mov [bx], eax
    mov eax, (P_INH/2 + 1)
    mov [by], eax

    ; velocidad inicial
    mov dword [vx], 1
    mov dword [vy], 1

    mov byte [s1], 0
    mov byte [s2], 0
    mov byte [ended], 0
    ret

; clamp paddle in [1 .. P_W - P_PAD - 1]
; IN/OUT: [p1x] or [p2x]
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

; reset ball towards the scorer
; IN: AL = 1 (P1 scores) or 2 (P2 scores)
p_reset_ball:
    call p_ball_center
    mov [bx], eax
    mov eax, (P_INH/2 + 1)
    mov [by], eax

    ; vx alterna según quien marca
    cmp al, 1
    jne .toP1
    ; P1 marca -> bola va hacia abajo (vy=+1)
    mov dword [vy], 1
    jmp .vxset
.toP1:
    ; P2 marca -> bola va hacia arriba (vy=-1)
    mov dword [vy], -1
.vxset:
    mov dword [vx], 1
    ret

; adjust vx based on hit position (0..P_PAD-1)
; IN: EAX = pos
p_adjust_vx:
    cmp eax, 2
    jg .chkRight
    mov dword [vx], -1
    ret
.chkRight:
    cmp eax, 6
    jl .keep
    mov dword [vx], 1
    ret
.keep:
    ret

; -------- update physics one tick --------
p_update:
    ; side bounce
    mov eax, [bx]
    mov edx, [vx]
    cmp eax, 1
    jne .chkRightWall
    cmp edx, -1
    jne .chkRightWall
    mov dword [vx], 1
.chkRightWall:
    mov eax, [bx]
    mov edx, [vx]
    cmp eax, (P_W-2)
    jne .nextY
    cmp edx, 1
    jne .nextY
    mov dword [vx], -1

.nextY:
    ; compute next x,y
    mov eax, [bx]
    add eax, [vx]
    mov esi, eax          ; next_x

    mov eax, [by]
    add eax, [vy]
    mov edi, eax          ; next_y

    ; collision with top paddle?
    cmp edi, Y_TOPPAD
    jne .chkBotPad

    mov eax, [p1x]
    mov ebx, eax
    add ebx, (P_PAD-1)    ; end
    cmp esi, eax
    jl .scoreP2
    cmp esi, ebx
    jg .scoreP2

    ; hit: bounce down
    mov dword [vy], 1
    ; adjust vx
    mov eax, esi
    sub eax, [p1x]        ; pos
    call p_adjust_vx
    jmp .applyMove

.scoreP2:
    ; P2 scores
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

    ; hit: bounce up
    mov dword [vy], -1
    mov eax, esi
    sub eax, [p2x]
    call p_adjust_vx
    jmp .applyMove

.scoreP1:
    ; P1 scores
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
    mov [bx], esi
    mov [by], edi
    ret

; -------- draw border line into linebuf and print --------
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

; -------- draw row y in EAX (1..P_H-2) --------
p_draw_row:
    pushad
    mov esi, eax                ; y

    mov byte [linebuf+0], '|'

    ; fill interior spaces
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
    ; ball
    mov eax, [by]
    cmp eax, esi
    jne .out
    mov eax, [bx]
    mov edi, linebuf
    add edi, eax
    mov byte [edi], 'O'

.out:
    mov ecx, linebuf
    mov edx, (P_W+1)
    call p_p
    popad
    ret

; -------- draw full screen --------
p_draw:
    ; clear
    mov ecx, P_CLS
    mov edx, P_CLS_L
    call p_p

    ; title + help
    mov ecx, P_TITLE
    mov edx, P_TITLE_L
    call p_p
    mov ecx, P_HELP
    mov edx, P_HELP_L
    call p_p

    ; score line (patch digits)
    ; P_SCORE = "P1: 0   P2: 0\n\n"
    ; digit positions: after "P1: " and after "P2: "
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
    jg .doneRows
    push eax
    call p_draw_row
    pop eax
    inc eax
    jmp .rowloop

.doneRows:
    call p_draw_border
    ret

; -------- wait ENTER (o ESC) --------
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

; -------- main entry --------
show_pong:
    call p_init

.loop:
    call p_draw

    ; ended?
    mov al, [ended]
    cmp al, 0
    jne .end_screen

    ; read input (no bloquea gracias a VMIN/VTIME del main)
    call p_read_key
    cmp al, 'Q'
    je .ret_menu

    ; P1 arriba: A/D
    cmp al, 'A'
    jne .chkD
    mov eax, [p1x]
    dec eax
    mov [p1x], eax
    call p_clamp_p1
    jmp .tick
.chkD:
    cmp al, 'D'
    jne .chkL
    mov eax, [p1x]
    inc eax
    mov [p1x], eax
    call p_clamp_p1
    jmp .tick

    ; P2 abajo: <- ->
.chkL:
    cmp al, 'L'
    jne .chkR
    mov eax, [p2x]
    dec eax
    mov [p2x], eax
    call p_clamp_p2
    jmp .tick
.chkR:
    cmp al, 'R'
    jne .tick
    mov eax, [p2x]
    inc eax
    mov [p2x], eax
    call p_clamp_p2

.tick:
    call p_update
    jmp .loop

.end_screen:
    ; show winner
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
