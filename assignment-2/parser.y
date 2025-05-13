%{

/*
 * PROLOGUE
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "parser.h"
#include "hash/hash.h"

struct hash* symbols; // symbols hash map

yypstate*    pstate; // parser state

// lexer function
extern int yylex();

// function prototype
void yyerror(YYLTYPE* loc, const char* err);

int _error = 0;

#define PARSE_ERROR(err_message, loc) do {                                        \
        fprintf(stderr, "Error: %s on line %d\n", err_message, loc.first_line);   \
        _error = 1;                                                               \
        YYERROR;                                                                  \
} while(0);                                                                       \

%}

/*
 * DECLARATIONS
*/
%locations
%define parse.error verbose

%union {
    float num;
    char* str;
    int category;
}

%define api.pure       full
%define api.push-pull  push

%token <str>      IDENTIFIER
%token <str>      AND BREAK DEF ELIF ELSE FOR IF NOT OR RETURN WHILE
%token <str>      BOOLEAN

%token <num>      INTEGER FLOAT

%token <category> ASSIGN PLUS MINUS TIMES DIVIDEDBY
%token <category> EQ NEQ GT GTE LT LTE
%token <category> COLON COMMA LPAREN RPAREN

%token <category> INDENT DEDENT NEWLINE

%type <str>       statement_list statement assignment_statement break_statement while_statement
%type <str>       program if_statement elif_block else_block expression
%type <str>       error

%left             OR
%left             AND
%left             EQ NEQ
%left             GT GTE LT LTE
%left             PLUS MINUS
%left             TIMES DIVIDEDBY
%right            NOT

%start            program;

/*
 * RULES
*/
%%

program
    : statement_list                                                                  { hash_insert(symbols, "program", $1); }
    ;

statement_list
    : statement_list statement                                                        { asprintf(&$$, "%s%s", $1, $2); }
    | statement                                                                       { $$ = $1; }
    ;

statement
    : assignment_statement                                                            { $$ = $1; }
    | if_statement                                                                    { $$ = $1; }
    | while_statement                                                                 { $$ = $1; }
    | break_statement                                                                 { $$ = $1; }
    | error NEWLINE                                                                   { }
    ;

assignment_statement
    : IDENTIFIER ASSIGN expression NEWLINE {
        hash_insert(symbols, $1, $3);
        asprintf(&$$, "%s = %s;\n", $1, $3);
    }
    | IDENTIFIER IDENTIFIER ASSIGN expression NEWLINE                                 { PARSE_ERROR("Invalid assignment statement", @1); }
    | INDENT IDENTIFIER ASSIGN expression NEWLINE                                     { PARSE_ERROR("Invalid indentation", @1); }
    ;

if_statement
    : IF expression COLON NEWLINE INDENT statement_list DEDENT                        { asprintf(&$$, "if (%s) {\n%s}\n", $2, $6); }
    | IF expression COLON NEWLINE INDENT statement_list DEDENT elif_block else_block  { asprintf(&$$, "if (%s) {\n%s} %s %s", $2, $6, $8, $9); }
    | IF expression COLON NEWLINE INDENT statement_list DEDENT elif_block             { asprintf(&$$, "if (%s) {\n%s} %s", $2, $6, $8); }
    | IF expression COLON NEWLINE INDENT statement_list DEDENT else_block             { asprintf(&$$, "if (%s) {\n%s} %s", $2, $6, $8); }
    | IF expression NEWLINE                                                           { PARSE_ERROR("Missing colon after 'if' statement", @1); }
    | elif_block                                                                      { PARSE_ERROR("Unexpected 'elif' statement", @1); }
    | elif_block if_statement                                                         { PARSE_ERROR("Unexpected 'elif' statement", @1); }
    | else_block                                                                      { PARSE_ERROR("Unexpected 'else' statement", @1); }
    ;

elif_block
    : elif_block ELIF expression COLON NEWLINE INDENT statement_list DEDENT           { asprintf(&$$, "%s else if (%s) {\n%s}", $1, $3, $7); }
    | ELIF expression COLON NEWLINE INDENT statement_list DEDENT                      { asprintf(&$$, "else if (%s) {\n%s}", $2, $6); }
    | ELIF expression NEWLINE INDENT statement_list DEDENT                            { PARSE_ERROR("Missing colon after 'elif' statement", @1); }
    ;

else_block
    : ELSE COLON NEWLINE INDENT statement_list DEDENT                                 { asprintf(&$$, "else {\n%s}\n", $5); }
    | ELSE expression NEWLINE                                                         { PARSE_ERROR("Missing colon after 'else' statement", @1); }
    ;

while_statement
    : WHILE expression COLON NEWLINE INDENT statement_list DEDENT                     { asprintf(&$$, "while (%s) {\n%s}\n", $2, $6); }
    | WHILE COLON NEWLINE INDENT statement_list DEDENT                                { PARSE_ERROR("Missing expression for 'while' statement", @1); }
    | WHILE expression NEWLINE                                                        { PARSE_ERROR("Missing colon after 'while' statement", @1); }
    ;

break_statement
    : BREAK NEWLINE                                                                   { asprintf(&$$, "break;\n"); }
    ;

expression
    : LPAREN expression RPAREN                                                        { asprintf(&$$, "(%s)", $2); }
    | expression PLUS expression                                                      { asprintf(&$$, "%s + %s", $1, $3); }
    | expression MINUS expression                                                     { asprintf(&$$, "%s - %s", $1, $3); }
    | expression TIMES expression                                                     { asprintf(&$$, "%s * %s", $1, $3); }
    | expression DIVIDEDBY expression                                                 { asprintf(&$$, "%s / %s", $1, $3); }
    | expression EQ expression                                                        { asprintf(&$$, "%s == %s", $1, $3); }
    | expression NEQ expression                                                       { asprintf(&$$, "%s != %s", $1, $3); }
    | expression GT expression                                                        { asprintf(&$$, "%s > %s", $1, $3); }
    | expression GTE expression                                                       { asprintf(&$$, "%s >= %s", $1, $3); }
    | expression LT expression                                                        { asprintf(&$$, "%s < %s", $1, $3);  }
    | expression LTE expression                                                       { asprintf(&$$, "%s <= %s", $1, $3); }
    | INTEGER                                                                         { asprintf(&$$, "%g", $1); }
    | FLOAT                                                                           { ((int)$1 == $1) ? asprintf(&$$, "%.1f", $1) : asprintf(&$$, "%g", $1); }
    | BOOLEAN                                                                         { $$ = strdup(strcmp($1, "True") ? "0" : "1"); }
    | expression expression                                                           { }
    | IDENTIFIER {
        if (hash_contains(symbols, $1)) {
            $$ = strdup($1);
        } else {
            fprintf(stderr, "Error: Invalid Symbol (%s) on line %d\n", $1, @1.first_line);
            _error = 1;
        }
    }
    ;

%%

/*
 * EPILOGUE
*/
void yyerror(YYLTYPE* loc, const char* err) {
    fprintf(stderr, "Error: %s\n", err);
}

int main() {
    symbols = hash_create();
    pstate = yypstate_new();

    if(!yylex() && !_error) {
        printf("#include <stdio.h>\n");
        printf("int main() {\n");

        struct hash_iter* iter = hash_iter_create(symbols);
        while (hash_iter_has_next(iter)) {
          char* key;
          char* val = (char*)hash_iter_next(iter, &key);

          if (strcmp(key, "program") == 0) {
            continue;
          }

          printf("double %s;\n", key);
        }

        printf("\n/* Begin Program */\n\n");
        printf("%s", (char*)hash_get(symbols, "program"));

        printf("\n/* End Program */\n\n");

        iter = hash_iter_create(symbols);
        while (hash_iter_has_next(iter)) {
          char* key;
          char* val = (char*)hash_iter_next(iter, &key);

          if (strcmp(key, "program") == 0) {
            continue;
          }

          printf("printf(\"%s: %%lf\\n\", %s);\n", key, key);
        }

        printf("}\n");

        hash_free(symbols);

        return 0;
    } else  {
        return 1;
    }
}
