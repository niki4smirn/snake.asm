all: build run

build:
	nasm -g -f elf64 snake.asm
	gcc -no-pie -o snake snake.o -lm -lc

run:
	./snake
