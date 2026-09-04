CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -std=c11

all:
	$(CC) $(CFLAGS) -I../../include test_unicontext.c ../../libUniContext.a -o test_unicontext
	./test_unicontext

clean:
	rm -f test_unicontext
