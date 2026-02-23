; MINIARCADEOS - Menu 6 cajas (3x2) con flechas + Enter + ESC
; NASM 32-bit Linux (WSL). Terminal en RAW mode.
; Compila con:
;   nasm -f elf32 src/main.asm -o main.o
;   ld -m elf_i386 -o app main.o

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
F2      db 'MOVERTE: FLECHAS  |  ENTRAR: ENTER',10
F2_L    equ $-F2

SOON    db 10,'PROXIMAMENTE... (ENTER para volver)',10
SOON_L  equ $-SOON

; Caja: 26 chars
TOPSEG  db '+------------------------+'
TOP_L   equ $-TOPSEG

; Líneas MID completas (26 chars): '|' + 24 chars + '|'
MID0 db '|1) TRES EN RAYA         |'
MID1 db '|2) SNAKE                |'
MID2 db '|3) PONG                 |'
MID3 db '|4) MEMORY               |'
MID4 db '|5) MOLE                 |'
MID5 db '|6) SALIR                |'
MID_L equ 26

; tabla de punteros a MID por índice
MIDTAB dd MID0, MID1, MID2, MID3, MID4, MID5

section .bss
key      resb 1
tmp2     resb 2
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

; -------- read key --------
; returns AL: U/D/L/R/E(enter)/Q(esc) or 0
read_key:
    mov ecx, key
    mov edx, 1
    call rin
    mov al, [key]

    cmp al, 0x1B
    jne .not_esc

    ; read 2 more bytes: [ X
    mov ecx, tmp2
    mov edx, 2
    call rin
    mov al, [tmp2]
    cmp al, '['
    jne .esc_alone

    mov al, [tmp2+1]
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

.not_esc:
    cmp al, 10
    jne .other
    mov al, 'E'
    ret
.other:
    xor al, al
    ret

; -------- print helper (ecx=ptr, edx=len) --------
p:
    call wout
    ret

; -------- draw one segment highlighted if (eax==ebx) --------
; IN: EAX = box_index (0..5), EBX = selected_index
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

; -------- draw row (3 boxes) --------
; IN: ESI = base_index (0 or 3), EBX = selected_index
draw_row:
    ; Top line
    mov eax, esi
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, esi
    inc eax
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, esi
    add eax, 2
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, NL
    mov edx, 1
    call p

    ; Mid line (from table)
    mov edi, MIDTAB

    mov eax, esi
    mov ecx, [edi + eax*4]
    mov edx, MID_L
    call draw_seg_hl

    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, esi
    inc eax
    mov ecx, [edi + eax*4]
    mov edx, MID_L
    call draw_seg_hl

    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, esi
    add eax, 2
    mov ecx, [edi + eax*4]
    mov edx, MID_L
    call draw_seg_hl

    mov ecx, NL
    mov edx, 1
    call p

    ; Bot line
    mov eax, esi
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, esi
    inc eax
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, SP3
    mov edx, SP3_L
    call p

    mov eax, esi
    add eax, 2
    mov ecx, TOPSEG
    mov edx, TOP_L
    call draw_seg_hl

    mov ecx, NL
    mov edx, 1
    call p

    ret

; -------- draw full menu --------
draw_menu:
    call tui_clear
    mov ecx, TITLE
    mov edx, TITLE_L
    call p

    mov ebx, [selected]
    mov esi, 0
    call draw_row

    mov ecx, NL
    mov edx, 1
    call p

    mov ebx, [selected]
    mov esi, 3
    call draw_row

    mov ecx, F1
    mov edx, F1_L
    call p
    mov ecx, F2
    mov edx, F2_L
    call p
    ret

; -------- menu loop returns EAX (0..5) or -1 --------
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
    ; left if col>0
    mov edx, eax
    mov ecx, 3
    mov eax, edx
    xor edx, edx
    div ecx            ; edx = col
    cmp edx, 0
    je .redraw
    mov eax, [selected]
    dec eax
    mov [selected], eax
    jmp .redraw

.chkR:
    cmp al, 'R'
    jne .chkU
    ; right if col<2
    mov edx, eax
    mov ecx, 3
    mov eax, edx
    xor edx, edx
    div ecx
    cmp edx, 2
    je .redraw
    mov eax, [selected]
    inc eax
    mov [selected], eax
    jmp .redraw

.chkU:
    cmp al, 'U'
    jne .chkD
    ; up if row>0
    mov eax, [selected]
    cmp eax, 2
    jle .redraw
    sub eax, 3
    mov [selected], eax
    jmp .redraw

.chkD:
    cmp al, 'D'
    jne .redraw
    ; down if row<1
    mov eax, [selected]
    cmp eax, 2
    jg .redraw
    add eax, 3
    mov [selected], eax
    jmp .redraw

.enter:
    mov eax, [selected]
    ret
.esc:
    mov eax, -1
    ret

; -------- placeholder --------
show_soon:
    call tui_clear
    mov ecx, SOON
    mov edx, SOON_L
    call p
.w2:
    call read_key
    cmp al, 'E'
    jne .w2
    ret

; -------- entrypoint --------
_start:
    call raw_on
    call tui_hide

.loop:
    call menu_loop
    cmp eax, -1
    je .exit
    cmp eax, 5
    je .exit
    call show_soon
    jmp .loop

.exit:
    call tui_show
    call raw_off
    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80
