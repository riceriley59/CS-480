all: scan

scan: scanner.o list.o stack.o
	gcc scanner.o list.o stack.o -o scan

scanner.o: scanner.c
	gcc -c scanner.c -o scanner.o

scanner.c: scanner.l
	flex -o scanner.c scanner.l

list.o: stack/list.c stack/list.h
	gcc -c stack/list.c -o list.o

stack.o: stack/stack.c stack/stack.h
	gcc -c stack/stack.c -o stack.o

clean:
	rm -f scan scanner.c *.o

