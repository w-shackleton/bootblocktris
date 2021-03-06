global start
bits 16

%include "utils.mac"
%include "memory.mac"
%include "unpacker.mac"

extern __bss_sizeb
extern __bss_start

extern blocks

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

    ; Note that we do not use the stack.

    mov ax, VGA_SEGMENT
    mov ds, ax
    mov es, ax
    mov ss, ax

    cld ; Clear direction flag: make sure rep etc go up not down

    ; Zero out BSS (which is set in the VGA segment)
    mov cx, __bss_sizeb
    mov di, __bss_start
    rep stosb ; stosb fills di -> cx bytes with the contents of ax

    CLS

    UNPACK_PIECES

    ; No idea why but the code below needs ss at zero
    xor ax, ax
    mov ss, ax

; Main game logic. We flow into this from `start`
main:

    ; Load a piece onto the screen. The pieces are defined in `blocks` in
    ; data.asm as a byte for each block: the first 4 bits are the first line,
    ; second four the second line.
    
    ; Use the clock as a random number source: mod it by 7 to choose the next
    ; piece
    ; 8-bit integer divide does ax / <reg> and stores remainder in ah
    xor ax, ax
    mov dx, ax
    mov al, [clock]
    ; There are 7 different blocks
    mov bl, 7
    div bl
    ; Remainder [0 to 6] now in ah; move to al and zero ah with a shift
    shr ax, 8
    mov si, ax
    shl si, 3 ; mul by 8 (aka BOARD_WIDTH * 4)
    ; Save the selected piece as its index into the unpacked_pieces array
    mov [current_piece], si
    mov word [current_rotation], 0
    ; Load the random block from the unpacked pieces
    lea si, [unpacked_pieces + si]
    mov di, gameboard_floating
    movsw
    movsw

; This is where we point the ES register such that the start of the first line
; of pixels is address es:0
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

    ; Fill the next CELL_SIZE bytes of es:di with al (aka black or red)
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
    ; If we've reached the end of the board, stop drawing
    cmp bx, (BOARD_WIDTH * BOARD_HEIGHT)
    jne draw_line

    ; Reset es back to what it was
    mov ax, VGA_SEGMENT
    mov es, ax

    ; end of draw_screen



    SLEEP

take_user_input:
    ; Backup the game state so that we can revert if an illegal move is taken
    COPY_BOARD gameboard_floating, gameboard_floating_backup

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
    xor ah, ah
    mov di, ax
    jmp [cs:di + jump_table]

jump_table:
    dw case_left ; 0x00 - a = left
    ; When down is pressed skip straight to the game progress code and ignore
    ; the timer
    dw progress_game ; 0x01 - s = down
    dw case_right ; 0x10 - d = right
    dw case_rotate ; 0x11 - w = up

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
    jmp case_end

case_rotate:
    ; Oh boy.

    ; First work out which line the block starts at
    mov di, gameboard_floating
    mov cx, BOARD_HEIGHT
    ; set ax to 0
    xor ax, ax
    repz scasw
    dec di
    dec di
    ; di now contains a pointer to the line containing the piece

    ; calculate the offset into the array based on the current rotation, plus
    ; increment the current rotation
    mov si, current_rotation
    inc word [si]
    and word [si], 0x03 ; chop it to 0,1,2,3
    mov ax, [si]
    ; There are 7 pieces. Add the required offset in here too
    mov bl, NUM_PIECES * BOARD_WIDTH * 4
    mul bl
    ; The rotation based offset is now in ax

    ; Load the currently selected piece into si; this is in the range 0-6 * 8
    mov si, [current_piece]
    add si, unpacked_pieces
    add si, ax

    ; Count the number of leading zeros in the line. We use this later
    bsf word cx, [di]
    ; The rotated blocks are sort of right-aligned so whack a bit off
    jz rotate_no_decrement_adjustment
    dec cx

rotate_no_decrement_adjustment:
    mov al, 4
rotate_copy_loop:
    movsw
    shl word [di - 2], cl
    dec al
    jnz rotate_copy_loop


case_end:
    ; Increment the game clock. If we passed so many ticks then move the piece
    ; down a notch.
    mov di, clock
    dec byte [di]
    ; Every time the first three bits of the clock are zero (aka 1 in 8 ticks),
    ; advance
    mov al, 0x07
    and al, [di]

    ; Clock not yet ticked. Don't move block down.
    jnz check_collision

progress_game:
    ; PROGRESS GAME STATE
    ; 1. Move floating component down
    ; Load address of bottom line of board into si
    mov si, gameboard_floating + (BOARD_WIDTH * BOARD_HEIGHT - BOARD_WIDTH)
    ; Load address of line-beyond-last-line into di (this array goes 1 beyond
    ; the board height)
    mov di, gameboard_floating + (BOARD_WIDTH * BOARD_HEIGHT)
    ; Set number of copies to make
    mov cx, BOARD_HEIGHT
    ; set direction flag to go backwards through memory
    std
    rep movsw ; copy si -> di in 1 word pieces
    cld
    ; Clear the top row. At this point the address of that is in di
    ; cx is zero so use that instead of literal
    mov word [di], cx

check_collision:
    
    ; Has the line below the bottom line got something in it? This indicates
    ; that a piece fell off the bottom which counts as a collision.
    ; (The fact that it fell off the bottom is fine since we use the previous
    ;state in gameboard_floating_backup)
    cmp word [gameboard_floating + (BOARD_WIDTH * BOARD_HEIGHT)], 0
    jne collide

    COLLIDE_BOARDS gameboard_floating, gameboard
    ; when COLLIDE_BOARDS finishes, ZF=1 if a collision was found
    jnz collide

    ; Nothing happened: continue looping
    jmp draw_screen
collide:
    ; OK we've hit a collision. We need to merge the previous board state into
    ; the set-in-stone state

    MERGE_BOARD gameboard_floating_backup, gameboard
    ; Clear the floating gameboard plus the extra collision row after it
    CLEAR_BOARD gameboard_floating, 2

    ; The main game board is now up to date with the latest block in place.
    ; If a full line has been made we need to clear it.

    ; We're going to copy every line to itself, but skip decrementing the
    ; destination offset if the line is full.
    ; We actually skimp on the logic for the top line because I'm kind of
    ; assuming that if you've reached the top line then it's probs game over
    ; anyway ;)
    mov cx, BOARD_HEIGHT - 1
    mov si, gameboard + (BOARD_HEIGHT - 1) * BOARD_WIDTH
    mov di, si
    ; We're going backwards through the board: set direction flag
    std

compact_loop:
    ; A line is full if its value is 0xFFFF; we can add 1 to that and check if
    ; the result is zero to see if the line was full
    mov ax, [si]
    inc ax
    ; The line was not full: continue as normal
    jnz compact_loop_skip_adjust_line_copy
    ; The line IS full: take 2 from si so that we copy the previous line
    ; to this line
    dec si
    dec si
    ; This could underflow. Maybe. Need to figure out whether that's actually
    ; something that could happen given the constraints of the game.
    ; I don't think it is, as we'd have to fill up the top line to reach that
    ; point which I'm going to declare as impossible..
    dec cx

compact_loop_skip_adjust_line_copy:
    movsw
    loop compact_loop

    ; Reset direction flag
    cld

; End of compaction

    jmp main
