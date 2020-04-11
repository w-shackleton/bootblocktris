OUTPUT_FORMAT("elf32-i386");
/* We define an entry point to keep the linker quiet. This entry point
 * has no meaning with a bootloader in the binary image we will eventually
 * generate. Bootloader will start executing at whatever is at 0x07c00 */
ENTRY(start);
SECTIONS
{
    . = 0x7C00;
    .text : {
        /* Place the code in boot.o before all other code */
        boot.o(.text);
        *(.text);
    }

    /* Place the boot signature at VMA 0x7DFE */
    .sig : AT(0x7DFE) {
        SHORT(0xaa55);
    }

    /* Remove sections that won't be relevant to us */
    /DISCARD/ : {
        *(.eh_frame);
        *(.comment);
        *(.note.gnu.build-id);
    }
}
