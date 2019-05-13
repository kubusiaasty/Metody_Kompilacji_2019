%{
#include <stdio.h>
#include <string>
#include <sstream>
#include <sstream>
#include <iostream>
#include <stack>
#include <vector>
#include <map>
#include <algorithm>
#include <cctype>

#define IN_ERROR 1
#define OUT_ERROR 2

using namespace std;
extern "C" int yylex();
extern "C" int yyerror(const char *msg, ...);
extern FILE *yyin;
extern FILE *yyout;
FILE *dropfile,*dropfile2;

static int strCounter=0;
static int ifLabel = 0;
static int helper=0;
int ARRI = 10;
int ARRF = 11;
static int licznik = 0;

struct Str2
{
	string val;
	int token; 
}str2;

struct symbol_info{
  int type; //int/float/string -> LD/LC/STRING
  int size; //size
  string id; //id zmiennej (nazwa)
  string value; //wartość
};

stack<Str2> stk;
map<string,struct symbol_info> symbole; // .data
stack<string> etykiety; // etykiety if i for
vector<string> textCode; // .text

void makeThree(string op);
void inputFloat(string name);
void printFloat(string name);
void inputInt(string name);
void printInt(string name);
void printString(string name);
string GetInteger(Str2 el, int regNum);
string GetDouble(Str2 el, int regNum);
void syscall();
void makeAssignement(Str2 a1, Str2 a2);
void makeAsm(Str2 a1, char op, Str2 a2,string res);
void compare(string condition);
void callBreak();

template<typename T>
string toString(T value){
    stringstream sstream;
    sstream<<value;
    return sstream.str();
}
%}

%union
{ char *text;
int ival;
double dval; };


%type <text> wyr
%type <text> skladnik
%type <text> czynnik
%token <text> ID
%token <ival> LC
%token <dval> LD
%token <text> STR
%left '+' '-'
%left '*' '/'
%token FOR IF ELSE WHILE BREAK //operacje
%token EQ NEQ LT GT LEQ GEQ	 //porownanie
%token PRINTI PRINTF PRINTS //wyswietlanie
%token READI READF // wczytywanie
%token INT DOUBLE //deklaracja
%start multi
%%
multi
	:multi linia 				{;}
	|linia 						{;}
	;
linia
	:przyp ';' {;}
	|deklaracja ';' {;}
	|io_stmt ';' {;}
	|if_stmt  {;}
	|for_stmt  {;}
	|while_stmt {;}
	|break ';' {;}
	;
break
	:BREAK {callBreak();}
	;
while_stmt 
	:while_et '(' warunek ')' '{' multi '}' { 
			string etykieta1 = etykiety.top();
      etykiety.pop();
      string etykieta2 = etykiety.top();
      etykiety.pop();
      textCode.push_back("b " + etykieta2);
      textCode.push_back(etykieta1 + ":");
	 }
	;

while_et 
	:WHILE {
		string newEtykieta="ETYKIETA" + to_string(ifLabel);
      ifLabel++;
      etykiety.push(newEtykieta);
      textCode.push_back("b " + newEtykieta);
      textCode.push_back(newEtykieta+":");
	}
	;
for_stmt
  :for_stmt_begin '{' multi '}' {
      string etykieta1 = etykiety.top();
      etykiety.pop();
      string etykieta2 = etykiety.top();
      etykiety.pop();
      textCode.push_back("b " + etykieta2);
      textCode.push_back(etykieta1 + ":");
  }
;
for_stmt_begin
  : for_stmt_init for_stmt_inc warunek ')'
;
for_stmt_init
  :FOR '(' przyp ';' {
      string newEtykieta="ETYKIETA" + to_string(ifLabel);
      ifLabel++;
      string newEtykieta2="ETYKIETA" + to_string(ifLabel);
      ifLabel++;
      etykiety.push(newEtykieta2);
      etykiety.push(newEtykieta);
      textCode.push_back("b " + newEtykieta);
      textCode.push_back(newEtykieta2+":");
  }
;
for_stmt_inc
  :przyp ';' {
      string etykieta = etykiety.top();
      etykiety.pop();
      textCode.push_back(etykieta+":");
  }
;
if_stmt
	:if_stmt_begin '{' multi '}' {
      string etykieta = etykiety.top();
      textCode.push_back(etykieta + ":");
      etykiety.pop();
      ifLabel++;
  }
	|if_stmt_begin '{' multi '}' else_stmt '{' multi '}'{
      string etykieta = etykiety.top();
      textCode.push_back(etykieta + ":");
      etykiety.pop();
      ifLabel++;
  }
	;
if_stmt_begin
  : IF '(' warunek ')' {;}
;
else_stmt
  :ELSE  {
      string etykieta = etykiety.top();
      string newEtykieta = "ETYKIETA" + to_string(ifLabel);
      textCode.push_back("b " + newEtykieta);
      textCode.push_back(etykieta+":");
      etykiety.pop();
      etykieta = "ETYKIETA" + to_string(ifLabel);
      etykiety.push(etykieta);
      ifLabel++;
  }
;
warunek
  : wyr EQ wyr {compare("bne");}
  | wyr NEQ wyr {compare("beq");}
  | wyr LT wyr {compare("bge");}
  | wyr GT wyr {compare("ble");}
  | wyr LEQ wyr {compare("bgt");}
  | wyr GEQ wyr {compare("blt");}
;
io_stmt
	:PRINTI '(' wyr ')'			{printInt($3);}
	|PRINTI '(' ID tab_wyr ')'	{
		string tmp = "printTmpI";
		auto it = symbole.find(tmp);
		symbol_info sInfo;
		sInfo.id = tmp;
		sInfo.type = LC;
		sInfo.size = 1;
		sInfo.value = "0";
		symbole.insert(std::pair<string,symbol_info>(tmp,sInfo));
      Str2 var1 = stk.top();
      stk.pop();
      string _asm1 = GetInteger(var1,0);
      textCode.push_back("la $t4, "+toString($3));
      if(var1.token == ID)
        textCode.push_back("lw $t5, "+ toString(var1.val));
      else
          textCode.push_back("li $t5, "+ toString(var1.val));
      textCode.push_back("mul $t5,$t5,4");
      textCode.push_back("add $t4, $t4, $t5");
      textCode.push_back("lw $t0, ($t4)");
      textCode.push_back("sw $t0, " + tmp);
      printInt(tmp);
	}
	|PRINTF '(' wyr ')'			{printFloat($3);}
	|PRINTF '(' ID tab_wyr ')' {
    string tmp = "printTmpF";
		auto it = symbole.find(tmp);
		symbol_info sInfo;
		sInfo.id = tmp;
		sInfo.type = LD;
		sInfo.size = 1;
		sInfo.value = "0";
		symbole.insert(std::pair<string,symbol_info>(tmp,sInfo));
      Str2 var1 = stk.top();
      stk.pop();
      string _asm1 = GetInteger(var1,0);
      textCode.push_back("la $t4, "+toString($3));
      if(var1.token == ID)
        textCode.push_back("lw $t5, "+ toString(var1.val));
      else
          textCode.push_back("li $t5, "+ toString(var1.val));
      textCode.push_back("mul $t5,$t5,4");
      textCode.push_back("add $t4, $t4, $t5");
      textCode.push_back("lw $t0, ($t4)");
      textCode.push_back("sw $t0, " + tmp);
      printFloat(tmp);
  }
	|PRINTS '(' STR ')'			{
		auto it = symbole.find($3);
		symbol_info sInfo;
		sInfo.type = STR;
		sInfo.size = 1;
		sInfo.id = "string" + to_string(strCounter);
		sInfo.value = $3;
		if(it != symbole.end())
		{
			printString(it->second.id);
		}
		else
		{
			symbole.insert(std::pair<string,symbol_info>($3, sInfo));
			printString(sInfo.id);
			strCounter++;
  	}
	}
	|READI '(' ID ')'			{inputInt($3);}
	|READF '(' ID ')'			{inputFloat($3);}
	;
deklaracja
	:INT ID {
	  	auto it = symbole.find($2);
      if(it != symbole.end()) {cout << "Int is already declared\n"; exit(-1);}
      symbol_info sInfo;
      sInfo.type = LC;
      sInfo.size = 1;
      sInfo.id = $2;
      sInfo.value = "0";
      symbole.insert(std::pair<string,symbol_info>($2, sInfo));
	}
	|INT ID '[' LC ']' {
      symbol_info sInfo;
      sInfo.type = ARRI;
      sInfo.size = $4;
      sInfo.id = $2;
      sInfo.value = "0 :"+to_string($4);
      symbole.insert(std::pair<string,symbol_info>($2,sInfo));
  }
	|DOUBLE ID	{
      auto it = symbole.find($2);
      if(it != symbole.end()) {cout << "Float is already declared\n"; exit(-1);}
      symbol_info sInfo;
      sInfo.type = LD;
      sInfo.size = 1;
      sInfo.id = $2;
      sInfo.value = "0.0";
      symbole.insert(std::pair<string,symbol_info>($2,sInfo));
	}
	|DOUBLE ID '[' LC ']' {
      symbol_info sInfo;
      sInfo.type = ARRF;
      sInfo.size = $4;
      sInfo.id = $2;
      sInfo.value = "0 :"+to_string($4);
      symbole.insert(std::pair<string,symbol_info>($2,sInfo));
  }
	;
przyp
	:ID '=' wyr 				{fprintf(dropfile ," %s = ",$1);str2.val=$1; str2.token=ID; stk.push(str2); makeThree("=");}
	|ID '[' wyr ']' '=' wyr {
      auto it = symbole.find($1);
      if(it->second.type == ARRI)
			{
          textCode.push_back("la $t4, " + toString($1));
          Str2 var1 = stk.top();
          stk.pop();
          string _asm1 = GetInteger(var1,0);
          textCode.push_back(_asm1);

          Str2 var2 = stk.top(); 
          stk.pop();
          string _asm2 = GetInteger(var2,5);
          textCode.push_back(_asm2);
          textCode.push_back("mul $t5, $t5, 4");
          textCode.push_back("add $t4, $t4, $t5");
          textCode.push_back("sw $t0, ($t4)");
      }
			else 
			{
				textCode.push_back("la $t4, " + toString($1));
				Str2 var1 = stk.top();
        stk.pop();
				string _asm1 = GetDouble(var1,0);
				textCode.push_back(_asm1);

				Str2 var2 = stk.top(); 
        stk.pop();
				string _asm2=GetInteger(var2,5);
				textCode.push_back(_asm2);
				textCode.push_back("mul $t5, $t5, 4");
				textCode.push_back("add $t4, $t4, $t5");
				textCode.push_back("s.s $f0, ($t4)");
			}
	}
	;
wyr
	:wyr '+' skladnik			{fprintf(dropfile ," + "); makeThree("+");}
	|wyr '-' skladnik			{fprintf(dropfile ," - "); makeThree("-");}
	|skladnik					{;}
	;
skladnik
	:skladnik '*' czynnik		{fprintf(dropfile ," * "); makeThree("*");}
	|skladnik '/' czynnik		{fprintf(dropfile ," / "); makeThree("/");}
	|czynnik					{;}
	;
czynnik
	:ID							{fprintf(dropfile ,"%s ",$1); str2.val=$1; str2.token=ID; stk.push(str2); }
	|LC							{fprintf(dropfile ,"%d ",$1); str2.val=to_string($1); str2.token=LC; stk.push(str2);}
	|LD							{fprintf(dropfile ,"%f ",$1); str2.val=to_string($1); str2.token=LD; stk.push(str2);}
	|STR {;}
	|ID tab_wyr {
		auto it = symbole.find($1);
      if(it->second.type == ARRI)
			{
          Str2 var1 = stk.top();
          stk.pop();
          textCode.push_back("la $t4,"+toString($1));
          if(var1.token == ID)
              textCode.push_back("lw $t5, "+toString(var1.val));
          else
              textCode.push_back("li $t5, "+toString(var1.val));

          textCode.push_back("mul $t5, $t5, 4");
          textCode.push_back("add $t4, $t4, $t5");
          textCode.push_back("lw $t0, ($t4)");
          helper++;
          string tmp="tmp" + toString(helper);
          symbol_info sInfo;
          sInfo.id = tmp;
          sInfo.type = LC;
          sInfo.size = 1;
          sInfo.value = "0";
          symbole.insert(std::pair<string,symbol_info>(tmp, sInfo));
					str2.val = toString(tmp); str2.token= ID; stk.push(str2);
          textCode.push_back("sw $t0, " + tmp);
      }
			else
			{
				Str2 var1 = stk.top();
          stk.pop();
          textCode.push_back("la $t4,"+toString($1));
          if(var1.token == ID)
              textCode.push_back("lw $t5, "+toString(var1.val));
          else
              textCode.push_back("li $t5, "+toString(var1.val));
					
          textCode.push_back("mul $t5, $t5, 4");
          textCode.push_back("add $t4, $t4, $t5");
					textCode.push_back("l.s $f0, ($t4)");
          licznik++;
          string tmp = "float"+toString(licznik);
          symbol_info sInfo;
          sInfo.id = tmp;
          sInfo.type = LD;
          sInfo.size = 1;
          sInfo.value = "0";
          symbole.insert(std::pair<string,symbol_info>(tmp, sInfo));
					str2.val = toString(tmp); str2.token= ID; stk.push(str2);
          textCode.push_back("s.s $f0, " + tmp);
			}
	} 
	|'(' wyr ')'				{;}
	;
tab_wyr
  :'[' wyr ']' {}
;

%%
void callBreak()
{
	string etykieta = etykiety.top();
  textCode.push_back("#break");
  textCode.push_back("b "+etykieta);
}

void syscall()
{
	string _asm;
	_asm= "syscall";
	textCode.push_back(_asm);
}
void printString(string name){
  string _asm1, _asm2;
  _asm1 = "li $v0, 4"; 
  _asm2 = "la $a0, " + name;
  textCode.push_back(_asm1);
  textCode.push_back(_asm2);
  syscall();
}

void inputInt(string name)
{
	string _asm1, _asm2;
	_asm1= "li $v0, 5";
	_asm2= "sw $v0,  "+ name;
	textCode.push_back(_asm1);
	syscall();
	textCode.push_back(_asm2);
}

void inputFloat(string name)
{
	string _asm1, _asm2;
	_asm1= "li $v0, 6";
	_asm2= "s.s $f0,  "+ name;
	textCode.push_back(_asm1);
	syscall();
	textCode.push_back(_asm2);
}

void printInt(string name)
{
	string _asm1, _asm2;
	_asm1= "li $v0, 1";
	_asm2= "lw $a0,  "+ name;
	textCode.push_back(_asm1);
	textCode.push_back(_asm2);
	syscall();
}

void printFloat(string name)
{
	string _asm1, _asm2;
	_asm1= "li $v0, 2";
	_asm2= "lwc1 $f12,  "+ name;
	textCode.push_back(_asm1);
	textCode.push_back(_asm2);
	syscall();
}

string convert (int id)
{
  if(id == LC || id == ARRI)
    return ".word";
  else if(id == LD || id == ARRF)
    return ".float";
  else if (id == STR)
    return ".asciiz";

  return ".unknown";
}

string GetDouble(Str2 el, int regNum)
{
	static int counter=0;
    if(el.token == ID)
        return "l.s $f" + to_string(regNum) + "," + el.val;
    symbol_info sInfo;
    sInfo.id = "float" + to_string(counter);
    counter++;
    sInfo.type = LD;
    sInfo.size = 1;
    sInfo.value = el.val;
    symbole.insert(std::pair<string,symbol_info>(sInfo.id, sInfo));
    return "l.s $f" + to_string(regNum) + "," + sInfo.id;
}

string GetInteger(Str2 el, int regNum)
{
    if(el.token == ID)
      return "lw $t"  + to_string(regNum) + "," + el.val;
    else if (el.token == LC)
      return "li $t" + to_string(regNum) + "," + el.val;
}

int GetTypeL(Str2 el)
{
  if(el.token == LC || el.token == LD)
    return el.token;
  else if(el.token == ID){
    auto it = symbole.find(el.val);
    if(it != symbole.end())
      return it->second.type;
  }
  else
    throw "Nie znaleziono symbolu!";
}

void makeAssignement(Str2 a1, Str2 a2)
{
	int t1= GetTypeL(a1);
	int t2= GetTypeL(a2);

	if(t1 == LD && t2 == LD)
	{
		textCode.push_back(GetDouble(a2,0));
	}
	else if(t1 == LC && t2 == LC)
	{
		textCode.push_back(GetInteger(a2,0));
	}
	else if(t1 == LC && t2 == LD) // konwersja z float na int niemozliwa
	{
		cout << "Blad przypisania";
    exit(-1);
	}
	if(t1 == LD && t2 == LC)
	{
		textCode.push_back(GetInteger(a2,0));
		textCode.push_back("mtc1 $t0, $f0");
		textCode.push_back("cvt.s.w $f0, $f0");
	}

	if(t1 == LC && t2 == LC)
	{
		textCode.push_back("sw $t0,"+a1.val+"\n");
	}
	else
	{
		textCode.push_back("s.s $f0,"+a1.val+"\n");
	}

}

void makeAsm(Str2 a1, char op, Str2 a2,string res)
{
	string _tmp1, _tmp2, _tmp3, _tmp4;
	int t1= GetTypeL(a1);
	int t2= GetTypeL(a2);
	int flag=0;

	if(t1 == LD && t2 == LD)
	{
		_tmp1= GetDouble(a1,0);
		_tmp2= GetDouble(a2,1);
	}
	else if(t1 == LC && t2 == LC)
	{
		_tmp1= GetInteger(a1,0);
		_tmp2= GetInteger(a2,1);
	}
	else 
	{
		int rej;
		flag=1;
		//konwersja
		if(t1 == LD)
		{
			_tmp1= GetDouble(a1,0); // a1>a2
			_tmp2= GetInteger(a2,1); //a2>a1
			rej=1;
		}
		else if(t2 == LD)
		{
			_tmp1= GetDouble(a1,0);
			_tmp2= GetInteger(a2,0);
			rej=0;
		}
		_tmp3 = "mtc1 $t" + to_string(rej) + ", $f" + to_string(rej);
    _tmp4 = "cvt.s.w $f" + to_string(rej) + ", $f" + to_string(rej);
  }

	textCode.push_back(_tmp1);
	if(flag == 1 && t2 == LD)
	{
		textCode.push_back(_tmp3);
		textCode.push_back(_tmp4);
	}

	textCode.push_back(_tmp2);
	if(flag == 1 && t1 == LD)
	{
		textCode.push_back(_tmp3);
		textCode.push_back(_tmp4);
	}

	if(t1 == LC && t2 == LC)
	{
		switch(op)
		{
				case '+':
						textCode.push_back("add $t0, $t0, $t1");
					break;
				case '-':
						textCode.push_back("sub $t0, $t1, $t0");
					break;
				case '*':
						textCode.push_back("mul $t0, $t0, $t1");
					break;
				case '/':
						textCode.push_back("div $t0, $t1, $t0");
					break;				
		}
		textCode.push_back("sw $t0,"+ res+"\n");
	}
	else
	{
		switch(op)
		{
				case '+':
						textCode.push_back("add.s $f0, $f0, $f1");
					break;
				case '-':
						textCode.push_back("sub.s $f0, $f1, $f0");
					break;
				case '*':
						textCode.push_back("mul.s $f0, $f0, $f1");
					break;
				case '/':
						textCode.push_back("div.s $f0, $f1, $f0");
					break;				
		}
		textCode.push_back("s.s $f0,"+ res+"\n");
	}
}

void makeThree(string op)
{
	char sign=op[0];
	static int counter =0;
	Str2 a1= stk.top();
	stk.pop();
	Str2 a2= stk.top();
	stk.pop();
	string result="res"+to_string(counter);
	symbol_info sInfo;

	if(op=="=")
	{
		sInfo.id = a1.val;
		sInfo.type = ID;
		sInfo.value = "0";
		fprintf(dropfile2, "%s %s %s\n",a1.val.c_str(),op.c_str(),a2.val.c_str());
		textCode.push_back("#"+a1.val+op+a2.val);
		makeAssignement(a1,a2);

	}
	else
	{
		counter++;
		int t1= GetTypeL(a1);
		int t2= GetTypeL(a2);

		fprintf(dropfile2, "%s = %s %s %s\n",result.c_str(),a1.val.c_str(),op.c_str(),a2.val.c_str());
		str2.val = result; str2.token= ID; stk.push(str2);
		sInfo.id= result;
		if(t1 == LD || t2 == LD)
      sInfo.type = LD;
    else
      sInfo.type = LC;

		sInfo.size = 1;
		sInfo.value = "0";
		symbole.insert(std::pair<string,symbol_info>(result,sInfo));
		textCode.push_back("#"+result+"="+a1.val+op+a2.val);
		makeAsm(a1,sign,a2,result);
	}
}
void compare(string condition){
  Str2 var2 = stk.top();
  stk.pop();
  Str2 var1=stk.top();
  stk.pop();
  if(var1.token == LD || var2.token == LD) {cout << "ERROR incorrect types\n";exit(-1);}
  string _asm1, _asm2, etykieta;
  _asm1 = GetInteger(var1,0);
  _asm2 = GetInteger(var2,1);
  etykieta = "ETYKIETA" + to_string(ifLabel);
  etykiety.push(etykieta);
  textCode.push_back(_asm1);
  textCode.push_back(_asm2);
  textCode.push_back(condition+" $t0,$t1, " + etykieta);
  ifLabel++;
}

int main(int argc, char *argv[])
{
	if(argc>1)
	{
		yyin= fopen(argv[1],"r");
		if(yyin ==NULL)
		{
			return IN_ERROR;
		}
		if(argc>2)
		{
			yyout= fopen(argv[2],"w");
			if(yyout ==NULL)
			{
				return OUT_ERROR;
			}
		}
	}
	dropfile = fopen("rpn", "w");
	if(dropfile ==NULL)
	{
		return -1;
	}
	dropfile2= fopen("trojki","w");
	if(dropfile ==NULL)
	{
		return -2;
	}
	yyparse();
	fclose(dropfile);
	fclose(dropfile2);


	fprintf(yyout,".data\n");
	for(auto sym:symbole)
	{
		fprintf(yyout,"\t%s\t:", sym.second.id.c_str());
		fprintf(yyout,"\t%s", convert(sym.second.type).c_str());
		fprintf(yyout,"\t%s\n", sym.second.value.c_str());
  }

	fprintf(yyout,".text\n");
	for(auto line: textCode)
	{
		fprintf(yyout,"\t%s\n",line.c_str());
	}
	return 0;
}
