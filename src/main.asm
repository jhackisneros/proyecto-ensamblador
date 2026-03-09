global _start
extern show_tres
extern show_pong

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

%define VTIME      5
%define VMIN       6

section .data
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
SP3     db ' '
SP3_L   equ $-SP3

TITLE   db '              MINIARCADEOS',10,10
TITLE_L equ $-TITLE

F1      db 10,'SALIR: ESC',10
F1_L    equ $-F1
F2      db 'MOVERTE: <- ->  |  ENTRAR: ENTER',10
F2_L    equ $-F2

SOON    db 10,'COMING SOON... (ENTER para volver)',10
SOON_L  equ $-SOON

TOPSEG  db '+------------------------+'
TOP_L   equ $-TOPSEG

MID0 db '|1) TRES EN RAYA         |'
MID1 db '|2) PONG (1 JUGADOR)     |'
MID2 db '|3) COMING SOON          |'
MID_L equ 26

MIDTAB dd MID0, MID1, MID2

SEL0    db 10,' >>> [ JUGAR TRES EN RAYA ] <<< ',10
SEL0_L  equ $-SEL0
SEL1    db 10,' >>> [ JUGAR PONG ]         <<< ',10
SEL1_L  equ $-SEL1
SEL2    db 10,' >>> [ PROXIMAMENTE... ]    <<< ',10
SEL2_L  equ $-SEL2

SELTAB  dd SEL0, SEL1, SEL2
SELLEN  dd SEL0_L, SEL1_L, SEL2_L

section .bss
key      resb 1
tmp1     resb 1
term_old resb 64
term_new resb 64
selected resd 1

section .text

wout:
    mov eax, SYS_WRITE
    mov ebx, STDOUT
    int 0x80
    ret

rin:
    mov eax, SYS_READ
    mov ebx, STDIN
    int 0x80
    ret

ioctl0:
    mov eax, SYS_IOCTL
    int 0x80
    ret

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

raw_on:
    mov ebx, STDIN
    mov ecx, TCGETS
    mov edx, term_old
    call ioctl0

    mov esi, term_old
    mov edi, term_new
    mov ecx, 64
.copy:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop .copy

    mov eax, [term_new+12]
    and eax, ~(ICANON | ECHO)
    mov [term_new+12], eax

    mov byte [term_new + 17 + VMIN], 0
    mov byte [term_new + 17 + VTIME], 0

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

p:
    call wout
    ret

read_key:
    mov ecx, key
    mov edx, 1
    call rin
    cmp eax, 1
    jne .none
    mov al, [key]

    cmp al, 10
    je .enter
    cmp al, 13
    je .enter

    cmp al, 0x1B
    jne .none

    mov ecx, tmp1
    mov edx, 1
    call rin
    cmp eax, 1
    jne .esc_alone
    mov al, [tmp1]
    cmp al, '['
    jne .esc_alone

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

draw_menu:
    call tui_clear
    mov ecx, TITLE
    mov edx, TITLE_L
    call p

    mov ebx, [selected]

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
    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, 2
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, NL
    mov edx, 1
    call p

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
    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, 2
    mov ecx, [edi + 2*4]
    mov edx, MID_L
    call draw_seg_hl

    mov ecx, NL
    mov edx, 1
    call p

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
    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, 2
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, NL
    mov edx, 1
    call p

    mov eax, [selected]
    mov edi, SELTAB
    mov ecx, [edi + eax*4]
    mov edi, SELLEN
    mov edx, [edi + eax*4]
    call p

    mov ecx, F1
    mov edx, F1_L
    call p
    mov ecx, F2
    mov edx, F2_L
    call p
    ret

menu_loop:
    mov dword [selected], 0
.redraw:
    call draw_menu
.wait:
    call read_key
    cmp al, 0
    je .wait

    mov bl, al
    cmp bl, 'Q'
    je .esc
    cmp bl, 'E'
    je .enter

    mov eax, [selected]

    cmp bl, 'L'
    jne .chkR
    cmp eax, 0
    je .wait
    dec eax
    mov [selected], eax
    jmp .redraw

.chkR:
    cmp bl, 'R'
    jne .wait
    cmp eax, 2
    je .wait
    inc eax
    mov [selected], eax
    jmp .redraw

.enter:
    mov eax, [selected]
    ret
.esc:
    mov eax, -1
    ret

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
    je .go_pong
    cmp eax, 2
    je .go_soon
    jmp .loop

.go_tres:
    call show_tres
    jmp .loop

.go_pong:
    call show_pong
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