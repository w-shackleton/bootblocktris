bits 16

%include "memory.mac"

section .bss

gameboard: resb (BOARD_WIDTH * BOARD_HEIGHT)

; We keep an extra row on the bottom so that we can detect if a piece would
; have fallen off-screen. We keep a few extra rows so that the block rotation
; logic can't overflow
gameboard_floating: resb (BOARD_WIDTH * (BOARD_HEIGHT + 3))
; A second copy of the floating gameboard, used to revert the gameboard if an
; illegal move is taken
gameboard_floating_backup: resb (BOARD_WIDTH * BOARD_HEIGHT)

clock: resb 1
; Which piece did we select last time we did so?
current_piece: resb 2
current_rotation: resb 2

; NUM_PIECES * board width * 4 rows possible total space taken * 4 rotations
unpacked_pieces: resb (8 * BOARD_WIDTH * 4 * 4)
