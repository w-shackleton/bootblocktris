all: game.bin

%.o: %.asm
	nasm -f elf32 $< -o $@

game.elf: game.o link.ld boot.o utils.o
	ld -melf_i386 -T link.ld game.o boot.o utils.o -o game.elf

game.bin: game.elf
	objcopy -O binary game.elf game.bin

run: game.bin
	qemu-system-i386 -fda game.bin

bochs: game.bin
	bochs -f bochsrc

objdump: game.elf
	objdump -D -mi386 -Maddr16,data16 game.elf

clean:
	rm -f *.o game.elf game.bin
