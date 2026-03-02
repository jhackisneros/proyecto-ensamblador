k; MINIARCADEOS - Menu 2 cajas (1x2) con flechas + Enter + ESC
; NASM 32-bit Linux (WSL). Terminal en RAW mode.
; Compila con:
;   nasm -f elf32 src/main.asm -o main.o
;   ld -m elf_i386 -o app main.o
;   ./app

global _start

%define SYS_EXIT   1
%define SYS_READ   3
%define SYS_WRITE  4
%define SYS_IOCTL  54

%define STDIN      0
%define STDOUT     1

%define TCGETS     0x5401
%define TCSETS     0x5402

%define ICANON     0x0002
%define ECHO       0x0008

; termios c_cc indexes
%define VTIME      5
%define VMIN       6

section .data
; ANSI
CLS     db 0x1B,'[2J',0x1B,'[H'
CLS_L   equ $-CLS
HIDE    db 0x1B,'[?25l'
HIDE_L  equ $-HIDE
SHOW    db 0x1B,'[?25h'
SHOW_L  equ $-SHOW
REVON   db 0x1B,'[7m'
REVON_L equ $-REVON
REVOFF  db 0x1B,'[0m'
REVOFF_L equ $-REVOFF

NL      db 10
SP3     db '   '
SP3_L   equ $-SP3

TITLE   db '              MINIARCADEOS',10,10
TITLE_L equ $-TITLE

F1      db 10,'SALIR: ESC',10
F1_L    equ $-F1
F2      db 'MOVERTE: <- ->  |  ENTRAR: ENTER',10
F2_L    equ $-F2

SOON    db 10,'COMING SOON... (ENTER para volver)',10
SOON_L  equ $-SOON

TRESMSG db 10,'TRES EN RAYA... (ENTER para volver)',10
TRES_L  equ $-TRESMSG

; Caja: 26 chars
TOPSEG  db '+------------------------+'
TOP_L   equ $-TOPSEG

; Líneas MID completas (26 chars): '|' + 24 chars + '|'
MID0 db '|1) TRES EN RAYA         |'
MID1 db '|2) COMING SOON          |'
MID_L equ 26

; tabla de punteros a MID por índice (0..1)
MIDTAB dd MID0, MID1

section .bss
key      resb 1
tmp1     resb 1
term_old resb 64
term_new resb 64
selected resd 1

section .text

; -------- sys_write(STDOUT, ecx, edx) --------
wout:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    int 0x80
    ret

; -------- sys_read(STDIN, ecx, edx) --------
; returns EAX = bytes read
rin:
    mov eax, SYS_READ
    mov ebx, STDIN
    int 0x80
    ret

; -------- ioctl(ebx=fd, ecx=req, edx=argp) --------
ioctl0:
    mov eax, SYS_IOCTL
    int 0x80
    ret

; -------- TUI --------
tui_clear:
    mov ecx, CLS
    mov edx, CLS_L
    call wout
    ret

tui_hide:
    mov ecx, HIDE
    mov edx, HIDE_L
    call wout
    ret

tui_show:
    mov ecx, SHOW
    mov edx, SHOW_L
    call wout
    ret

rev_on:
    mov ecx, REVON
    mov edx, REVON_L
    call wout
    ret

rev_off:
    mov ecx, REVOFF
    mov edx, REVOFF_L
    call wout
    ret

; -------- RAW mode ON/OFF --------
raw_on:
    ; TCGETS -> term_old
    mov ebx, STDIN
    mov ecx, TCGETS
    mov edx, term_old
    call ioctl0

    ; copy old -> new (64 bytes)
    mov esi, term_old
    mov edi, term_new
    mov ecx, 64
.copy:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop .copy

    ; c_lflag offset 12: disable ICANON & ECHO
    mov eax, [term_new+12]
    and eax, ~(ICANON | ECHO)
    mov [term_new+12], eax

    ; IMPORTANTE: evitar que ESC se bloquee:
    ; VMIN=0, VTIME=1 (0.1s) => read "timeout" corto
    mov byte [term_new + 17 + VMIN], 0
    mov byte [term_new + 17 + VTIME], 1

    ; TCSETS <- term_new
    mov ebx, STDIN
    mov ecx, TCSETS
    mov edx, term_new
    call ioctl0
    ret

raw_off:
    mov ebx, STDIN
    mov ecx, TCSETS
    mov edx, term_old
    call ioctl0
    ret

; -------- print helper (ecx=ptr, edx=len) --------
p:
    call wout
    ret

; -------- read key --------
; returns AL: L/R/E(enter)/Q(esc) or 0
read_key:
    mov ecx, key
    mov edx, 1
    call rin
    cmp eax, 1
    jne .none
    mov al, [key]

    ; ENTER puede ser 10 o 13
    cmp al, 10
    je .enter
    cmp al, 13
    je .enter

    cmp al, 0x1B
    jne .none

    ; intento leer 1 byte: '[' (si es flecha). Si no llega, es ESC solo.
    mov ecx, tmp1
    mov edx, 1
    call rin
    cmp eax, 1
    jne .esc_alone
    mov al, [tmp1]
    cmp al, '['
    jne .esc_alone

    ; leo 1 byte más: A/B/C/D
    mov ecx, tmp1
    mov edx, 1
    call rin
    cmp eax, 1
    jne .esc_alone
    mov al, [tmp1]

    cmp al, 'C'
    je .right
    cmp al, 'D'
    je .left
    xor al, al
    ret

.esc_alone:
    mov al, 'Q'
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

; -------- draw one segment highlighted if (eax==ebx) --------
; IN: EAX = box_index (0..1), EBX = selected_index
;     ECX = ptr, EDX = len
draw_seg_hl:
    cmp eax, ebx
    jne .nohl
    call rev_on
    call p
    call rev_off
    ret
.nohl:
    call p
    ret

; -------- draw menu (2 boxes) --------
draw_menu:
    call tui_clear
    mov ecx, TITLE
    mov edx, TITLE_L
    call p

    mov ebx, [selected]

    ; TOP
    mov eax, 0
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, 1
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, NL
    mov edx, 1
    call p

    ; MID
    mov edi, MIDTAB

    mov eax, 0
    mov ecx, [edi + 0*4]
    mov edx, MID_L
    call draw_seg_hl

    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, 1
    mov ecx, [edi + 1*4]
    mov edx, MID_L
    call draw_seg_hl

    mov ecx, NL
    mov edx, 1
    call p

    ; BOT
    mov eax, 0
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, 1
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, NL
    mov edx, 1
    call p

    mov ecx, F1
    mov edx, F1_L
    call p
    mov ecx, F2
    mov edx, F2_L
    call p
    ret

; -------- menu loop returns EAX (0..1) or -1 --------
menu_loop:
    mov dword [selected], 0
.redraw:
    call draw_menu
.wait:
    call read_key
    cmp al, 0
    je .wait
    cmp al, 'Q'
    je .esc
    cmp al, 'E'
    je .enter

    mov eax, [selected]

    cmp al, 'L'
    jne .chkR
    cmp eax, 0
    je .redraw
    dec eax
    mov [selected], eax
    jmp .redraw

.chkR:
    cmp al, 'R'
    jne .redraw
    cmp eax, 1
    je .redraw
    inc eax
    mov [selected], eax
    jmp .redraw

.enter:
    mov eax, [selected]
    ret
.esc:
    mov eax, -1
    ret

; -------- screens --------
wait_enter:
.w:
    call read_key
    cmp al, 'E'
    jne .w
    ret

show_soon:
    call tui_clear
    mov ecx, SOON
    mov edx, SOON_L
    call p
    call wait_enter
    ret

show_tres:
    call tui_clear
    mov ecx, TRESMSG
    mov edx, TRES_L
    call p
    call wait_enter
    ret

; -------- entrypoint --------
_start:
    call raw_on
    call tui_hide

.loop:
    call menu_loop
    cmp eax, -1
    je .exit

    cmp eax, 0
    je .go_tres
    cmp eax, 1
    je .go_soon
    jmp .loop

.go_tres:
    call show_tres
    jmp .loop

.go_soon:
    call show_soon
    jmp .loop

.exit:
    call tui_show
    call raw_off
    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80
