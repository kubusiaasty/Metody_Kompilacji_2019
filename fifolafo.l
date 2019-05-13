%{
#include <stdlib.h>
#include <string.h>
#include "def.tab.hh"
extern int yylineno;
int yyerror(const char *,...);
%}
%%
"printi"				{return PRINTI;}
"printf"				{return PRINTF;}
"prints"				{return PRINTS;}
"readi"					{return READI;}
"readf"					{return READF;}
"int"					{return INT;}
"double"				{return DOUBLE;}
"string"				{return STR;}
"for"					{return FOR;}
"if"					{return IF;}
"else"					{return ELSE;}
"while"					{return WHILE;}
"break"					{return BREAK;}

\{						{return '{';}
\}						{return '}';}
\;						{return ';';}
\+						{return '+';} 
\*						{return '*';}
\(						{return '(';}
\)						{return ')';}
\[						{return '[';}
\]						{return ']';}
\/						{return '/';}
\-						{return '-';}
\=						{return '=';}

\<\=					{return LEQ;}
\>\=					{return GEQ;}
\=\=					{return EQ;}
\!\=					{return NEQ;}
\<						{return LT;}
\>						{return GT;}

[1-9][0-9]*|0			{yylval.ival= atoi(yytext); return LC;} 	
[_a-zA-Z][_a-zA-Z0-9]*	{yylval.text= strdup(yytext); return ID;}
([1-9][0-9]*|0)\.[0-9]*	{yylval.dval= atof(yytext);return LD;}
\"[^\"]*\" 				{yylval.text = strdup(yytext);return STR;}
\n						{yylineno++;}
\ |\t					{;}
.						{yyerror("Blad leksykalny\n");}
%%

int yyerror (const char *msg,...)
{
	printf("%d: %s",yylineno,msg);
	exit(1);
}
