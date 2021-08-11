snake:	snake.asm
	fasm snake.asm

run:	snake.bin
	qemu-system-x86_64 -drive format=raw,file=snake.bin

clean:
	rm -f snake.bin
