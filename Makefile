all: game.bin

boot.o: boot.asm utils.mac memory.mac unpacker.mac
	nasm -f elf32 boot.asm -o boot.o

memory.o: memory.asm memory.mac
	nasm -f elf32 memory.asm -o memory.o

data.o: data.asm utils.mac
	nasm -f elf32 data.asm -o data.o

game.elf: link.ld boot.o memory.o data.o
	ld -melf_i386 -T link.ld boot.o memory.o data.o -o game.elf

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
