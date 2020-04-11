bits 16

%include "memory.mac"

section .bss

gameboard: resb (BOARD_WIDTH * BOARD_HEIGHT)
