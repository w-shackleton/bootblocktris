global blocks
bits 16

%include "utils.mac"

section .data

blocks: 
    DEFINE_BLOCK 0b1111, \
                 0b0000
    DEFINE_BLOCK 0b1000, \
                 0b1110
    DEFINE_BLOCK 0b0010, \
                 0b1110
    DEFINE_BLOCK 0b1100, \
                 0b1100
    DEFINE_BLOCK 0b0110, \
                 0b1100
    DEFINE_BLOCK 0b1100, \
                 0b0110
    DEFINE_BLOCK 0b0100, \
                 0b1110
