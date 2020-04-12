bits 16

%include "memory.mac"

section .bss

gameboard: resb (BOARD_WIDTH * BOARD_HEIGHT)

; We keep an extra row on the bottom so that we can detect if a piece would
; have fallen off-screen
gameboard_floating: resb (BOARD_WIDTH * (BOARD_HEIGHT + 1))
; A second copy of the floating gameboard, used to revert the gameboard if an
; illegal move is taken
gameboard_floating_backup: resb (BOARD_WIDTH * BOARD_HEIGHT)

clock: resb 1
