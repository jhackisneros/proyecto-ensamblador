app: src/main.asm
	nasm -f elf32 src/main.asm -o main.o
	ld -m elf_i386 -o app main.o

run: app
	./app

clean:
	rm -f *.o app
