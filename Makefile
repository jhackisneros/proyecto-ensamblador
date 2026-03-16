app: main.o tres.o pong.o invaders.o
	ld -m elf_i386 -o app main.o tres.o pong.o invaders.o

main.o: src/main.asm
	nasm -f elf32 src/main.asm -o main.o

tres.o: src/games/tres.asm
	nasm -f elf32 src/games/tres.asm -o tres.o

pong.o: src/games/pong.asm
	nasm -f elf32 src/games/pong.asm -o pong.o

invaders.o: src/games/invaders.asm
	nasm -f elf32 src/games/invaders.asm -o invaders.o

run: app
	./app

clean:
	rm -f *.o app