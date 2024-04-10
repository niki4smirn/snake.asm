section .data
    WIDTH         equ 40
    HEIGHT        equ 20
    MAX_LENGTH    equ WIDTH * HEIGHT

    STDIN_FILENO  equ 0
    ICANON        equ 2
    ECHO          equ 8
    F_GETFL       equ 3
    F_SETFL       equ 4
    TCSANOW       equ 0
    O_NONBLOCK    equ 0x800
    EOF           equ 255
    TCGETS        equ 21505
    TCSETS        equ 21506

    READ_SYS      equ 0
    IOCTL_SYS     equ 16
    FCNTL_SYS     equ 72
    SLEEP_SYS     equ 35
    EXEC_SYS      equ 59
    FORK_SYS      equ 57
    WAIT_SYS      equ 61
    EXIT_SYS      equ 60

    snakeX        times MAX_LENGTH dd 0
    snakeY        times MAX_LENGTH dd 0

    directionX    dd 1
    directionY    dd 0
    snakeLength   dd 1
    score         dd 0

    board         times HEIGHT * WIDTH db 0


    msg_score     db "Score: %d", 10, 0
    msg_newline   db 10, 0
    cell_format   db "%c", 0
    msg_game_over db "Game over. Score %d", 10, 0
    clear_cmd     db "/usr/bin/clear", 0
    clear_arg     db "clear", 0
    term_env      db "TERM=screen-256color", 0

extern printf
extern rand

section .text
    global main

main:
    call init_board
    call init_snake
    call gen_fruit

.game_loop:
    call draw

    call sleep_100ms

    call kbhit
    mov rsi, rax

    call handle_input

    call move_snake

    jmp .game_loop

init_board:
    mov ecx, 0
    
.outer_loop:
    mov esi, 0

.inner_loop:
    mov eax, ecx
    imul eax, WIDTH
    add eax, esi

    cmp ecx, 0
    je .set_wall
    cmp ecx, HEIGHT-1
    je .set_wall
    cmp esi, 0
    je .set_wall
    cmp esi, WIDTH-1
    je .set_wall

    mov BYTE [board + eax], ' '
    jmp .next_iteration

.set_wall:
    mov BYTE [board + eax], '#'

.next_iteration:
    inc esi
    cmp esi, WIDTH
    jl .inner_loop

    inc ecx
    cmp ecx, HEIGHT
    jl .outer_loop

    ret

init_snake:
    mov edi, 2
    xor rdx, rdx

    mov eax, WIDTH
    div edi
    mov DWORD [snakeX], eax ; snakeX[0] = WIDTH / 2

    mov ecx, eax
    xor rdx, rdx

    mov eax, HEIGHT
    div edi
    mov DWORD [snakeY], eax ; snakeY[0] = HEIGHT / 2

    imul eax, WIDTH
    add eax, [snakeX]

    mov BYTE [board + eax], '0'

    ret

gen_fruit:
    call rand
    mov edi, WIDTH - 2

    xor rdx, rdx
    div edi

    mov ecx, edx
    inc ecx
    ; now fruitX in ecx

    ; save fruitX before call
    push rcx

    call rand
    mov edi, HEIGHT - 2

    pop rcx

    xor rdx, rdx
    div edi

    inc edx
    imul edx, WIDTH

    add ecx, edx

    mov BYTE [board + ecx], 'F'

    ret

draw:
    call clear

    mov rdi, msg_score
    mov rsi, [score]
    call printf                

    mov rdi, msg_newline
    call printf                

    mov r12, 0

.outer_loop:
    mov r13, 0

.inner_loop:
    mov rdx, r12
    imul rdx, WIDTH
    add rdx, r13
    lea rcx, [board + rdx]

    mov rdi, cell_format
    mov rsi, [rcx]
    call printf

    inc r13

    cmp r13, WIDTH
    jl .inner_loop

    mov rdi, msg_newline
    call printf

    inc r12

    cmp r12, HEIGHT
    jl .outer_loop

    ret

clear:
    call fork

    cmp eax, 0
    jne .parent

.child:
    sub rsp, 32
    mov QWORD [rsp], clear_arg
    mov QWORD [rsp + 8], 0
    mov QWORD [rsp + 16], term_env
    mov QWORD [rsp + 24], 0

    mov rax, EXEC_SYS
    mov rdi, clear_cmd
    mov rsi, rsp
    lea rdx, [rsp + 16]
    syscall

    add rsp, 32

    jmp .return

.parent:
    mov edi, eax
    mov rax, WAIT_SYS
    xor rsi, rsi
    xor rdx, rdx
    xor r10, r10
    syscall
    
.return:
    ret

fork:
    mov rax, FORK_SYS
    syscall

    ret

kbhit:
    sub rsp, 125
    
    ; Address of oldt is rsp
    ; Address of newt is rsp + 60
    ; Address of oldf is rsp + 120 
    ; Address of ch is rsp + 124

    mov rdi, STDIN_FILENO
    mov rsi, rsp
    call tcgetattr

    mov rsi, rsp
    lea rdi, [rsp + 60]
    mov rcx, 60

    cld
    rep movsb

    mov eax, DWORD [rsp + 72]
    and eax, ~ICANON
    and eax, ~ECHO
    mov DWORD [rsp + 72], eax

    mov rdi, STDIN_FILENO
    mov rsi, TCSANOW
    lea rdx, [rsp + 60]
    call tcsetattr

    mov rdi, STDIN_FILENO
    mov rsi, F_GETFL
    xor rdx, rdx
    call fcntl

    mov DWORD [rsp + 120], eax
    mov edx, eax
    or edx, O_NONBLOCK
    mov rdi, STDIN_FILENO
    mov rsi, F_SETFL
    call fcntl

    call getchar
    mov BYTE [rsp + 124], al

    mov rdi, STDIN_FILENO
    mov rsi, TCSANOW
    mov rdx, rsp
    call tcsetattr

    mov rdi, STDIN_FILENO
    mov rsi, F_SETFL
    mov edx, DWORD [rsp + 120]
    call fcntl

    mov al, BYTE [rsp + 124]
    add rsp, 125
    ret

tcgetattr:
    mov rdx, rsi
    mov rax, IOCTL_SYS
    mov rsi, TCGETS
    syscall

    ret

tcsetattr:
    mov rax, IOCTL_SYS
    mov rsi, TCSETS
    syscall

    ret

fcntl:
    mov rax, FCNTL_SYS
    syscall

    ret

getchar:
    dec rsp

    mov rax, READ_SYS
    mov rdi, STDIN_FILENO
    mov rsi, rsp
    mov rdx, 1

    syscall

    mov al, BYTE [rsp]

    inc rsp 
    ret

sleep_100ms:
    sub rsp, 16
    mov QWORD [rsp], 0              ; sec
    mov QWORD [rsp + 8], 100000000  ; nsec
    mov rax, SLEEP_SYS
    mov rdi, rsp
    xor rsi, rsi
    syscall

    add rsp, 16

    ret

handle_input:
    cmp sil, 'w'
    je .move_up
    cmp sil, 's'
    je .move_down
    cmp sil, 'a'
    je .move_left
    cmp sil, 'd'
    je .move_right

    ret

.move_up:
    cmp DWORD [directionY], 1
    je .return

    mov DWORD [directionX], 0
    mov DWORD [directionY], -1
    jmp .return

.move_down:
    cmp DWORD [directionY], -1
    je .return

    mov DWORD [directionX], 0
    mov DWORD [directionY], 1
    jmp .return

.move_left:
    cmp DWORD [directionX], 1
    je .return

    mov DWORD [directionX], -1
    mov DWORD [directionY], 0
    jmp .return

.move_right:
    cmp DWORD [directionX], -1
    je .return

    mov DWORD [directionX], 1
    mov DWORD [directionY], 0
    jmp .return

.return:
    ret

move_snake:
    mov ecx, DWORD [snakeX]
    add ecx, DWORD [directionX]

    mov edx, DWORD [snakeY]
    add edx, DWORD [directionY]

    ; (newX, newY) = (ecx, edx)

    mov eax, edx
    imul eax, WIDTH
    add eax, ecx
    mov al, BYTE [board + eax]

    cmp al, '#'
    je game_over

    cmp al, '0'
    je game_over

    cmp al, 'F'
    jne .no_fruit_eaten


    inc DWORD [score]
    inc DWORD [snakeLength]

    call gen_fruit

    jmp .move_tail

.no_fruit_eaten:
    mov esi, DWORD [snakeLength]
    dec esi
    mov eax, DWORD [snakeY + 4 * esi]
    imul eax, WIDTH
    add eax, DWORD [snakeX + 4 * esi]
    mov BYTE [board + eax], ' '

.move_tail:

    mov esi, DWORD [snakeLength]
    dec esi
    cmp esi, 0
    je .move_head

.move_tail_loop:
    mov edi, esi
    dec edi

    mov ecx, DWORD [snakeX + 4 * edi]
    mov DWORD [snakeX + 4 * esi], ecx

    mov ecx, DWORD [snakeY + 4 * edi]
    mov DWORD [snakeY + 4 * esi], ecx

    dec esi

    cmp esi, 0
    jg .move_tail_loop

.move_head:
    mov eax, DWORD [snakeX]
    add eax, DWORD [directionX]
    mov DWORD [snakeX], eax

    mov eax, DWORD [snakeY]
    add eax, DWORD [directionY]
    mov DWORD [snakeY], eax

    imul eax, WIDTH
    add eax, DWORD [snakeX]

    mov BYTE [board + eax], '0'

    ret

game_over:
    mov rdi, msg_game_over
    mov rsi, [score]
    call printf

    mov rax, EXIT_SYS
    xor edi, edi
    syscall


