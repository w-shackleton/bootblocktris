global start
bits 16

%include "utils.mac"
%include "memory.mac"

extern __bss_sizeb
extern __bss_start

section .text
start:
    jmp 0x0000:setcs      ; Set CS to 0
setcs:
    ; Set video mode to 320x200, 8-bit colour
    mov ah, 0x00
    mov al, 0x13
    int 10h

    ; For this project, we are keeping all data segments pointing to the VGA
    ; RAM. In BIOS VGA mode 0x13 the video RAM takes up 64,000 bytes which
    ; leaves us the last 1536 bytes of wiggle room at 0xFFFF to use as variable
    ; storage / stack space.

    mov ax, VGA_SEGMENT
    mov ds, ax
    mov es, ax
    mov ss, ax ; TODO if we don't end up using the stack, remove this

    mov sp, 0xFFFF ; TODO if we don't end up using the stack, remove this
    cld ; Clear direction flag: make sure rep etc go up not down

    ; Zero out BSS (which is set in this VGA segment)
    mov cx, __bss_sizeb
    mov di, __bss_start
    rep stosb ; stosb fills di -> cx bytes with the contents of ax

; Main game logic. We flow into this from `start`
main:
    CLS

    mov byte [0x0000], 0x0F
    mov byte [0x0005], 0x0F

    mov word [gameboard+6], 0x0101
    mov word [gameboard+8], 0x0101
    mov word [gameboard+10], 0x1010
    mov word [gameboard+12], 0x1010

    mov word [gameboard_floating    ], 0b0000000111000000
    mov word [gameboard_floating + 2], 0b0000000010000000

ES_START equ (VGA_SEGMENT + (SCREEN_Y_START * VGA_WIDTH + SCREEN_X_START) / 0x10)

draw_screen:
    xor ecx, ecx
    
    ; OK so what we're doing here is using the es segment register to point
    ; to the start of the current line to be drawn. Each time we'll increase
    ; it by one line to draw the next one. This is neat because stosb writes
    ; to es:di
    mov ax, ES_START
    mov es, ax
    ; Set bx as the array index into gameboard.
    xor bx, bx
draw_line:
    ; dx holds the current line we're drawing
    mov dx, [bx + gameboard]
    ; merge in the floating part of the board
    or dx, [bx + gameboard_floating]
    xor di, di

draw_cell:
    ; Put the line into al, and and it with 0x01 to find the lowest bit
    mov al, dl
    and al, 0x01
    ; al is now either 0 or 1; shift left to turn that into 0x00 or 0x04
    shl al, 2

    ; Fill the next CELL_SIZE bytes of es:di with al (aka black or white)
    mov cx, CELL_SIZE
    rep stosb

    ; Shift the game board to the next cell
    shr dx, 1

    ; Loop if we haven't reached the screen end yet
    cmp di, SCREEN_X_WIDTH
    jne draw_cell

    ; We've reached the end of the line! Time for the next one...
    ; Increase the es segment to the next line
    mov ax, es
    add ax, (VGA_WIDTH / 0x10)
    mov es, ax

    ; Figure out if we just started the next row of the board. This happens
    ; every CELL_SIZE'th row
    ; TODO this code could be shorter (fewer machine code bytes)
    sub ax, ES_START
    mov dl, (VGA_WIDTH / 0x10 * CELL_SIZE)
    div dl

    ; if ah is zero, increment the game row
    test ah, ah
    jnz draw_skip_increment_board
    ; Start drawing the next line of the board if the above bitmask passed
    ; add 2
    inc bx
    inc bx

draw_skip_increment_board:
    cmp bx, (BOARD_WIDTH * BOARD_HEIGHT)
    jne draw_line

    ; Reset es back to what it was
    mov ax, VGA_SEGMENT
    mov es, ax

    ; end of draw_screen



    SLEEP

take_user_input:
    GETKEY ; Loads the pressed keystroke into ax

    ; w = 0x77 0111 0111
    ; a = 0x61 0110 0001
    ; s = 0x73 0111 0011
    ; d = 0x64 0110 0100
    ;                ^^
    ; We look at bits 1 and 2 to determine the direction of travel. We use a
    ; bitmask to turn this into the numbers 0,2,4,6, which can be used in the
    ; word-sized jump table below.

    test al, al

    ; If no key was pressed then progress as normal
    jz case_end

    and al, 0x06

    ; al now contains the jump table location mentioned above. Before we kick
    ; off the jump table, calculate a few useful things first.

    ; and together all rows into bx so that we can see if we're hitting the
    ; edge
    xor bx, bx
    mov cx, BOARD_HEIGHT
    mov di, gameboard_floating
calculate_edge_loop:
    or bx, [di]
    inc di
    inc di
    loop calculate_edge_loop

    ; Now go to the jump table to decide what logic to run

    ; al is still the same from above and corresponds to the keystroke
    BREAKPOINT
    xor ah, ah
    mov di, ax
    jmp [cs:di + jump_table]

jump_table:
    dw case_left ; 0x00 - a = left
    dw case_end ; 0x01 - s = down
    dw case_right ; 0x10 - d = right
    dw case_end ; 0x11 - w = up

case_left:
    ; Check if we've hit the limit. If we have then don't allow moving left
    and bl, 0x01
    jnz case_end
    mov cx, BOARD_HEIGHT
    mov di, gameboard_floating
case_left_loop:
    shr word [di], 1
    inc di
    inc di
    loop case_left_loop
    jmp case_end

case_right:
    ; Check if we've hit the limit. If we have then don't allow moving right
    and bh, 0x80
    jnz case_end
    mov cx, BOARD_HEIGHT
    mov di, gameboard_floating
case_right_loop:
    shl word [di], 1
    inc di
    inc di
    loop case_right_loop

case_end:


progress_game:
    ; PROGRESS GAME STATE
    ; 1. Move floating component down
    ; Load address of bottom line of board into si
    mov si, gameboard_floating + (BOARD_WIDTH * BOARD_HEIGHT - BOARD_WIDTH * 2)
    ; Load address of penultimate line of board into di
    mov di, gameboard_floating + (BOARD_WIDTH * BOARD_HEIGHT - BOARD_WIDTH * 1)
    ; Set number of copies to make
    mov cx, (BOARD_HEIGHT - 1)
    ; set direction flag to go backwards through memory
    std
    rep movsw ; copy si -> di in 1 word pieces
    cld
    ; Clear the top row. At this point the address of that is in di
    mov word [di], 0x0000

    jmp draw_screen
