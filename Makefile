CC=gcc
LEX=flex
YACC=bison
LD=gcc 
CPP=g++  -std=c++11 

all:	fifolafo

fifolafo:	def.tab.o lex.yy.o
	$(CPP) lex.yy.o def.tab.o -o fifolafo -ll

lex.yy.o:	lex.yy.c
	$(CC) -c lex.yy.c

lex.yy.c: fifolafo.l
	$(LEX) fifolafo.l

def.tab.o:	def.tab.cc
	$(CPP) -c def.tab.cc

def.tab.cc:	def.yy
	$(YACC) -d def.yy

clean:
	rm *.o fifolafo def.tab.cc lex.yy.c
