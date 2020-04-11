global start
bits 16

%include "utils.mac"

VGA_SEGMENT equ 0xA000

; The board is 16 cells across, aka 2 bytes
BOARD_WIDTH equ 2
BOARD_HEIGHT equ 24

%define BREAKPOINT xchg bx, bx

section .text
start:

    BREAKPOINT
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


; Main game logic. We flow into this from `start`
main:
    mov byte [0x0000], 0x0F
    mov byte [0x0005], 0x0F

    GETKEY

    mov bx, ax
    mov byte [bx] , 0x0F

    jmp main
