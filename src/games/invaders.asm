; src/games/invaders.asm
; SPACE INVADERS SIMPLE
; <- -> Moverse | ENTER disparar | ESC salir

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
I_SCORE   db ' ALIENS ELIMINADOS: 0 / 5',10,10
I_SCORE_L equ $-I_SCORE

I_WIN     db 10,' VICTORIA! (ENTER para volver)',10
I_WIN_L   equ $-I_WIN
I_LOSE    db 10,' LA TIERRA HA SIDO DESTRUIDA! (ENTER volver)',10
I_LOSE_L  equ $-I_LOSE

inv_fps   dd 0, 20000000  ; 50 FPS

section .bss
i_key     resb 1
i_tmp1    resb 1

p_x       resd 1   
b_x       resd 1   
b_y       resd 1   

a_x       resd 1   
a_y       resd 1   
adir      resd 1   
atimer    resb 1   

alive     resb 5   
killed    resb 1   
ended     resb 1   

linebuf   resb 128

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

i_init:
    mov dword [p_x], 30
    mov dword [b_x], 0
    mov dword [b_y], 0
    mov dword [a_x], 10
    mov dword [a_y], 2
    mov dword [adir], 1
    mov byte [atimer], 0
    mov byte [killed], 0
    mov byte [ended], 0

    ; ARREGLADO EL BUG DEL SEGMENTATION FAULT
    mov ecx, 5
    mov edi, alive
.fill_aliens:
    mov byte [edi], 1
    inc edi
    loop .fill_aliens
    ret

i_update:
    mov eax, [b_y]
    cmp eax, 0
    je .aliens_turn
    dec eax
    mov [b_y], eax
    cmp eax, 0          
    je .aliens_turn

    mov eax, [b_y]
    cmp eax, [a_y]       
    jne .aliens_turn
    
    ; ARREGLADO EL BUG DEL SEGMENTATION FAULT
    mov ecx, 5
    mov esi, 0          
.check_hit:
    mov bl, [alive + esi]
    cmp bl, 0
    je .next_alien      

    mov eax, esi
    imul eax, 4         
    add eax, [a_x]       
    
    mov edx, [b_x]
    cmp edx, eax        
    jl .next_alien
    add eax, 2
    cmp edx, eax        
    jg .next_alien

    mov byte [alive + esi], 0
    mov dword [b_y], 0   
    inc byte [killed]
    cmp byte [killed], 5
    jne .aliens_turn
    mov byte [ended], 1 
    ret

.next_alien:
    inc esi
    loop .check_hit

.aliens_turn:
    inc byte [atimer]
    cmp byte [atimer], 5
    jl .done
    mov byte [atimer], 0

    mov eax, [a_x]
    add eax, [adir]
    mov [a_x], eax

    cmp eax, 2
    jl .drop
    cmp eax, 38         
    jg .drop
    jmp .done

.drop:
    mov eax, [adir]
    neg eax             
    mov [adir], eax
    mov eax, [a_y]
    inc eax             
    mov [a_y], eax
    
    cmp eax, 18         
    jl .done
    mov byte [ended], 2 

.done:
    ret

i_draw_row:
    pushad
    mov esi, eax        

    mov byte [linebuf+0], '|'
    mov ecx, (I_W-2)
    mov edi, linebuf+1
.fsp:
    mov byte [edi], ' '
    inc edi
    loop .fsp
    mov byte [linebuf + (I_W-1)], '|'
    mov byte [linebuf + I_W], 10

    cmp esi, 0
    je .border
    cmp esi, I_H
    je .border
    jmp .check_alien

.border:
    mov ecx, (I_W-2)
    mov edi, linebuf+1
.fbd:
    mov byte [edi], '-'
    inc edi
    loop .fbd
    jmp .print

.check_alien:
    cmp esi, [a_y]
    jne .check_bullet
    
    ; ARREGLADO EL BUG DEL SEGMENTATION FAULT
    mov ecx, 5
    mov ebx, 0
.draw_a:
    mov al, [alive + ebx]
    cmp al, 0
    je .skip_a
    
    mov eax, ebx
    imul eax, 4
    add eax, [a_x]       
    mov edi, linebuf
    add edi, eax
    mov byte [edi], 'M'
    mov byte [edi+1], 'W'
    mov byte [edi+2], 'M'
.skip_a:
    inc ebx
    loop .draw_a

.check_bullet:
    cmp esi, [b_y]
    jne .check_player
    mov eax, [b_x]
    mov edi, linebuf
    add edi, eax
    mov byte [edi], '^'

.check_player:
    cmp esi, 18
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

    mov al, [killed]
    add al, '0'
    mov [I_SCORE + 20], al
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
    jne .w2
    mov ecx, I_WIN
    mov edx, I_WIN_L
    call i_p
    jmp .wait
.w2:
    mov ecx, I_LOSE
    mov edx, I_LOSE_L
    call i_p
.wait:
    call i_read_key
    cmp al, 'E'
    je .ret_menu
    jmp .wait

.ret_menu:
    ret