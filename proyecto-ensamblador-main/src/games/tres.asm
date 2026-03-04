; src/games/tres.asm
; TRES EN RAYA (3x3) - Flechas para mover, ENTER para poner, ESC para volver
; Se asume que el terminal YA está en RAW mode (lo hace main.asm)

global show_tres

%define SYS_READ   3
%define SYS_WRITE  4
%define STDIN      0
%define STDOUT     1

section .data
; ANSI
T3_CLS     db 0x1B,'[2J',0x1B,'[H'
T3_CLS_L   equ $-T3_CLS
T3_REVON   db 0x1B,'[7m'
T3_REVON_L equ $-T3_REVON
T3_REVOFF  db 0x1B,'[0m'
T3_REVOFF_L equ $-T3_REVOFF

T3_NL   db 10
T3_SP   db ' '
T3_PIPE db '|'

T3_TITLE db '           TRES EN RAYA',10,10
T3_TITLE_L equ $-T3_TITLE

T3_HELP  db 'MOVER: Flechas  |  PONER: ENTER  |  VOLVER: ESC',10,10
T3_HELP_L equ $-T3_HELP

T3_HLINE db '+---+---+---+',10
T3_HLINE_L equ $-T3_HLINE

T3_TURN  db 10,'Turno: '
T3_TURN_L equ $-T3_TURN

T3_WIN   db 10,'GANADOR: '
T3_WIN_L equ $-T3_WIN

T3_DRAW  db 10,'EMPATE'
T3_DRAW_L equ $-T3_DRAW

T3_BACK  db 10,10,'(ENTER para volver al menu)',10
T3_BACK_L equ $-T3_BACK

section .bss
t3_key     resb 1
t3_tmp1    resb 1
t3_board   resb 9           ; ' ' / 'X' / 'O'
t3_sel     resd 1           ; 0..8
t3_turn    resb 1           ; 'X' or 'O'
t3_ended   resb 1           ; 0 jugando | 1 win | 2 draw
t3_winner  resb 1
t3_ch      resb 1

section .text

; -------- sys_write(STDOUT, ecx, edx) --------
t3_wout:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    int 0x80
    ret

; -------- sys_read(STDIN, ecx, edx) -> eax bytes --------
t3_rin:
    mov eax, SYS_READ
    mov ebx, STDIN
    int 0x80
    ret

; -------- print helper (ecx=ptr, edx=len) --------
t3_p:
    call t3_wout
    ret

; -------- read key --------
; returns AL: U/D/L/R/E(enter)/Q(esc) or 0
t3_read_key:
    mov ecx, t3_key
    mov edx, 1
    call t3_rin
    cmp eax, 1
    jne .none
    mov al, [t3_key]

    ; ENTER (10 o 13)
    cmp al, 10
    je .enter
    cmp al, 13
    je .enter

    ; ESC
    cmp al, 0x1B
    jne .none

    ; intenta leer '[' (si no llega, es ESC solo)
    mov ecx, t3_tmp1
    mov edx, 1
    call t3_rin
    cmp eax, 1
    jne .esc_alone
    mov al, [t3_tmp1]
    cmp al, '['
    jne .esc_alone

    ; siguiente byte A/B/C/D
    mov ecx, t3_tmp1
    mov edx, 1
    call t3_rin
    cmp eax, 1
    jne .esc_alone
    mov al, [t3_tmp1]

    cmp al, 'A'
    je .up
    cmp al, 'B'
    je .down
    cmp al, 'C'
    je .right
    cmp al, 'D'
    je .left
    xor al, al
    ret

.esc_alone:
    mov al, 'Q'
    ret
.up:
    mov al, 'U'
    ret
.down:
    mov al, 'D'
    ret
.left:
    mov al, 'L'
    ret
.right:
    mov al, 'R'
    ret
.enter:
    mov al, 'E'
    ret
.none:
    xor al, al
    ret

; -------- init board --------
t3_init:
    mov ecx, 9
    mov edi, t3_board
.fill:
    mov byte [edi], ' '
    inc edi
    loop .fill
    mov dword [t3_sel], 0
    mov byte [t3_turn], 'X'
    mov byte [t3_ended], 0
    mov byte [t3_winner], ' '
    ret

; -------- draw cell (EAX=index 0..8) --------
t3_draw_cell:
    pushad
    mov esi, eax                ; idx

    ; highlight si idx == sel y no ended
    mov bl, [t3_ended]
    cmp bl, 0
    jne .no_hl
    mov eax, [t3_sel]
    cmp esi, eax
    jne .no_hl
    mov ecx, T3_REVON
    mov edx, T3_REVON_L
    call t3_p
.no_hl:
    ; ' '
    mov ecx, T3_SP
    mov edx, 1
    call t3_p

    ; símbolo
    mov al, [t3_board + esi]
    mov [t3_ch], al
    mov ecx, t3_ch
    mov edx, 1
    call t3_p

    ; ' '
    mov ecx, T3_SP
    mov edx, 1
    call t3_p

    ; cerrar highlight si tocaba
    mov bl, [t3_ended]
    cmp bl, 0
    jne .out
    mov eax, [t3_sel]
    cmp esi, eax
    jne .out
    mov ecx, T3_REVOFF
    mov edx, T3_REVOFF_L
    call t3_p
.out:
    popad
    ret

; -------- draw board --------
t3_draw:
    ; clear + title + help
    mov ecx, T3_CLS
    mov edx, T3_CLS_L
    call t3_p
    mov ecx, T3_TITLE
    mov edx, T3_TITLE_L
    call t3_p
    mov ecx, T3_HELP
    mov edx, T3_HELP_L
    call t3_p

    ; row 0
    mov ecx, T3_HLINE
    mov edx, T3_HLINE_L
    call t3_p

    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov eax, 0
    call t3_draw_cell
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov eax, 1
    call t3_draw_cell
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov eax, 2
    call t3_draw_cell
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov ecx, T3_NL
    mov edx, 1
    call t3_p

    mov ecx, T3_HLINE
    mov edx, T3_HLINE_L
    call t3_p

    ; row 1
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov eax, 3
    call t3_draw_cell
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov eax, 4
    call t3_draw_cell
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov eax, 5
    call t3_draw_cell
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov ecx, T3_NL
    mov edx, 1
    call t3_p

    mov ecx, T3_HLINE
    mov edx, T3_HLINE_L
    call t3_p

    ; row 2
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov eax, 6
    call t3_draw_cell
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov eax, 7
    call t3_draw_cell
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov eax, 8
    call t3_draw_cell
    mov ecx, T3_PIPE
    mov edx, 1
    call t3_p
    mov ecx, T3_NL
    mov edx, 1
    call t3_p

    mov ecx, T3_HLINE
    mov edx, T3_HLINE_L
    call t3_p

    ; status
    mov al, [t3_ended]
    cmp al, 0
    jne .ended

    mov ecx, T3_TURN
    mov edx, T3_TURN_L
    call t3_p
    mov al, [t3_turn]
    mov [t3_ch], al
    mov ecx, t3_ch
    mov edx, 1
    call t3_p
    mov ecx, T3_NL
    mov edx, 1
    call t3_p
    ret

.ended:
    cmp al, 1
    jne .drawmsg
    mov ecx, T3_WIN
    mov edx, T3_WIN_L
    call t3_p
    mov al, [t3_winner]
    mov [t3_ch], al
    mov ecx, t3_ch
    mov edx, 1
    call t3_p
    jmp .back
.drawmsg:
    mov ecx, T3_DRAW
    mov edx, T3_DRAW_L
    call t3_p
.back:
    mov ecx, T3_BACK
    mov edx, T3_BACK_L
    call t3_p
    ret

; -------- check win/draw after a move by current player --------
t3_check_end:
    ; check win for [t3_turn]
    mov al, [t3_turn]
    call t3_check_win
    cmp al, 1
    jne .chk_draw

    mov byte [t3_ended], 1
    mov al, [t3_turn]
    mov [t3_winner], al
    ret

.chk_draw:
    ; if no spaces => draw
    mov ecx, 9
    mov esi, t3_board
.scan:
    mov al, [esi]
    cmp al, ' '
    je .not_draw
    inc esi
    loop .scan
    mov byte [t3_ended], 2
.not_draw:
    ret

; returns AL=1 if win else 0, input AL = player ('X'/'O')
t3_check_win:
    pushad
    mov dl, al

    ; helper macro-like: compare 3 positions
    ; We'll inline 8 checks.

    ; (0,1,2)
    mov al, [t3_board+0]
    cmp al, dl
    jne .c345
    mov al, [t3_board+1]
    cmp al, dl
    jne .c345
    mov al, [t3_board+2]
    cmp al, dl
    jne .c345
    mov al, 1
    jmp .out

.c345:
    ; (3,4,5)
    mov al, [t3_board+3]
    cmp al, dl
    jne .c678
    mov al, [t3_board+4]
    cmp al, dl
    jne .c678
    mov al, [t3_board+5]
    cmp al, dl
    jne .c678
    mov al, 1
    jmp .out

.c678:
    ; (6,7,8)
    mov al, [t3_board+6]
    cmp al, dl
    jne .c036
    mov al, [t3_board+7]
    cmp al, dl
    jne .c036
    mov al, [t3_board+8]
    cmp al, dl
    jne .c036
    mov al, 1
    jmp .out

.c036:
    ; (0,3,6)
    mov al, [t3_board+0]
    cmp al, dl
    jne .c147
    mov al, [t3_board+3]
    cmp al, dl
    jne .c147
    mov al, [t3_board+6]
    cmp al, dl
    jne .c147
    mov al, 1
    jmp .out

.c147:
    ; (1,4,7)
    mov al, [t3_board+1]
    cmp al, dl
    jne .c258
    mov al, [t3_board+4]
    cmp al, dl
    jne .c258
    mov al, [t3_board+7]
    cmp al, dl
    jne .c258
    mov al, 1
    jmp .out

.c258:
    ; (2,5,8)
    mov al, [t3_board+2]
    cmp al, dl
    jne .c048
    mov al, [t3_board+5]
    cmp al, dl
    jne .c048
    mov al, [t3_board+8]
    cmp al, dl
    jne .c048
    mov al, 1
    jmp .out

.c048:
    ; (0,4,8)
    mov al, [t3_board+0]
    cmp al, dl
    jne .c246
    mov al, [t3_board+4]
    cmp al, dl
    jne .c246
    mov al, [t3_board+8]
    cmp al, dl
    jne .c246
    mov al, 1
    jmp .out

.c246:
    ; (2,4,6)
    mov al, [t3_board+2]
    cmp al, dl
    jne .no
    mov al, [t3_board+4]
    cmp al, dl
    jne .no
    mov al, [t3_board+6]
    cmp al, dl
    jne .no
    mov al, 1
    jmp .out

.no:
    xor al, al
.out:
    mov [t3_tmp1], al  ; guarda resultado
    popad
    mov al, [t3_tmp1]
    ret

; -------- toggle player --------
t3_toggle:
    mov al, [t3_turn]
    cmp al, 'X'
    jne .toX
    mov byte [t3_turn], 'O'
    ret
.toX:
    mov byte [t3_turn], 'X'
    ret

; -------- main entry for game --------
show_tres:
    call t3_init

.game_loop:
    call t3_draw

.wait_key:
    call t3_read_key
    cmp al, 0
    je .wait_key

    ; ESC siempre vuelve al menu
    cmp al, 'Q'
    je .ret_menu

    ; si terminó, ENTER vuelve
    mov bl, [t3_ended]
    cmp bl, 0
    jne .ended_keys

    ; movimiento
    cmp al, 'L'
    je .mvL
    cmp al, 'R'
    je .mvR
    cmp al, 'U'
    je .mvU
    cmp al, 'D'
    je .mvD
    cmp al, 'E'
    je .place
    jmp .game_loop

.ended_keys:
    cmp al, 'E'
    je .ret_menu
    jmp .game_loop

.mvL:
    mov eax, [t3_sel]
    xor edx, edx
    mov ecx, 3
    div ecx              ; edx=col
    cmp edx, 0
    je .game_loop
    mov eax, [t3_sel]
    dec eax
    mov [t3_sel], eax
    jmp .game_loop

.mvR:
    mov eax, [t3_sel]
    xor edx, edx
    mov ecx, 3
    div ecx              ; edx=col
    cmp edx, 2
    je .game_loop
    mov eax, [t3_sel]
    inc eax
    mov [t3_sel], eax
    jmp .game_loop

.mvU:
    mov eax, [t3_sel]
    cmp eax, 2
    jle .game_loop       ; fila 0
    sub eax, 3
    mov [t3_sel], eax
    jmp .game_loop

.mvD:
    mov eax, [t3_sel]
    cmp eax, 6
    jge .game_loop       ; fila 2
    add eax, 3
    mov [t3_sel], eax
    jmp .game_loop

.place:
    mov eax, [t3_sel]
    mov bl, [t3_board + eax]
    cmp bl, ' '
    jne .game_loop       ; ocupado

    mov bl, [t3_turn]
    mov [t3_board + eax], bl

    call t3_check_end
    mov bl, [t3_ended]
    cmp bl, 0
    jne .game_loop       ; terminó (draw lo pintará con mensaje)
    call t3_toggle
    jmp .game_loop

.ret_menu:
    ret
