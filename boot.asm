global start
bits 16

section .text
start:
    xor ax, ax            ; AX = 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x7C00 ; set stack pointer; stack grows down towards BIOS data area
    jmp 0x0000:setcs      ; Set CS to 0
setcs:
    cld                   ; GCC code requires direction flag to be cleared 

    ; Set video mode to 320x200, 8-bit colour
    mov ah, 0x00
    mov al, 0x13
    int 10h
