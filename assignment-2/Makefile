CC=gcc
CCFLAGS=--std=c99

all: parse

scan: scanner.c
	$(CC) $(CCFLAGS) scanner.c -o scan

parse: parser.c scanner.c hash.o
	$(CC) $(CCFLAGS) parser.c scanner.c hash.o -o parse

hash.o: hash/hash.c hash/hash.h
	$(CC) $(CCFLAGS) hash/hash.c -c -o hash.o

scanner.c: scanner.l
	flex -o scanner.c scanner.l

parser.c parser.h: parser.y
	bison -d -o parser.c parser.y

clean:
	rm -rf parse scan scanner.c parser.c parser.h *.o output_files
