%{
/* * * * * * * * * * * *
 * * * OPTIONS * * * * *
 * * * * * * * * * * * */
%}
%option noyywrap
%option yylineno

%{
/* * * * * * * * * * * *
 * * * DEFINITIONS * * *
 * * * * * * * * * * * */
%}
%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "stack/stack.h"

// MACROS to change output formatting for TOKENS
#define PRINT_TOKEN(token, val) printf("%-12s\t%s\n", token, val)
#define PRINT_TOKEN_NUM(token, fmt, val) printf("%-12s\t" fmt "\n", token, val)

int             have_err = 0;
struct stack*   indent_stack;

// function prototypes
long int        count_indentation();
void            check_indentation();
int             end_of_file();

%}

%{
/* * * * * * * * * * * *
 * * * PATTERNS* * * * *
 * * * * * * * * * * * */
%}

IDENTIFIER   [a-zA-Z_][a-zA-Z0-9_]*
FLOAT        [0-9]*\.[0-9]+
INTEGER      [0-9]+
BOOLEAN      ("True"|"False")

AND          "and"
BREAK        "break"
DEF          "def"
ELIF         "elif"
ELSE         "else"
FOR          "for"
IF           "if"
NOT          "not"
OR           "or"
RETURN       "return"
WHILE        "while"

ASSIGN       "="
PLUS         "+"
MINUS        "-"
TIMES        "*"
DIVIDEDBY     "/"
EQ           "=="
NEQ          "!="
GT           ">"
GTE          ">="
LT           "<"
LTE          "<="

LPAREN       "("
RPAREN       ")"
COMMA        ","
COLON        ":"

NEWLINE      (\r?)\n

INDENT       {NEWLINE}([ \t]|{NEWLINE})*
COMMENT      "#".*({NEWLINE})?

WHITESPACE   ([ \t]|{NEWLINE})*

%{
/* * * * * * * * * * * *
 * * * * RULES * * * * *
 * * * * * * * * * * * */
%}
%%

{INDENT}     { check_indentation(); }

{COMMENT}
{WHITESPACE}

{FLOAT}      { PRINT_TOKEN_NUM("FLOAT", "%g", atof(yytext)); }
{INTEGER}    { PRINT_TOKEN_NUM("INTEGER", "%d", atoi(yytext)); }
{BOOLEAN}    { PRINT_TOKEN_NUM("BOOLEAN", "%d", strcmp(yytext, "True") ? 0 : 1); }

{AND}        { PRINT_TOKEN("AND", yytext); }
{BREAK}      { PRINT_TOKEN("BREAK", yytext); }
{DEF}        { PRINT_TOKEN("DEF", yytext); }
{ELIF}       { PRINT_TOKEN("ELIF", yytext); }
{ELSE}       { PRINT_TOKEN("ELSE", yytext); }
{FOR}        { PRINT_TOKEN("FOR", yytext); }
{IF}         { PRINT_TOKEN("IF", yytext); }
{NOT}        { PRINT_TOKEN("NOT", yytext); }
{OR}         { PRINT_TOKEN("OR", yytext); }
{RETURN}     { PRINT_TOKEN("RETURN", yytext); }
{WHILE}      { PRINT_TOKEN("WHILE", yytext); }

{ASSIGN}     { PRINT_TOKEN("ASSIGN", yytext); }
{PLUS}       { PRINT_TOKEN("PLUS", yytext); }
{MINUS}      { PRINT_TOKEN("MINUS", yytext); }
{TIMES}      { PRINT_TOKEN("TIMES", yytext); }
{DIVIDEDBY}  { PRINT_TOKEN("DIVIDEDBY", yytext); }

{EQ}         { PRINT_TOKEN("EQ", yytext); }
{NEQ}        { PRINT_TOKEN("NEQ", yytext); }
{GT}         { PRINT_TOKEN("GT", yytext); }
{GTE}        { PRINT_TOKEN("GTE", yytext); }
{LT}         { PRINT_TOKEN("LT", yytext); }
{LTE}        { PRINT_TOKEN("LTE", yytext); }

{LPAREN}     { PRINT_TOKEN("LPAREN", yytext); }
{RPAREN}     { PRINT_TOKEN("RPAREN", yytext); }
{COLON}      { PRINT_TOKEN("COLON", yytext); }
{COMMA}      { PRINT_TOKEN("COMMA", yytext); }

{IDENTIFIER} { PRINT_TOKEN("IDENTIFIER", yytext); }

<<EOF>>      { return end_of_file(); }

. {
    fprintf(stderr, "Invalid Symbol on Line %d: %s\n", yylineno, yytext);
    have_err = 1;
}

%%

/* * * * * * * * * * * *
 * * * USER CODE * * * *
 * * * * * * * * * * * */
int main() {
    //initialize indentation stack before scanning
    indent_stack = stack_create();
    stack_push(indent_stack, (void*)0);

    // scan and output error if there is one
    int err = yylex();
    if (err) {
        printf("Compilation Error\n");
    }

    // free memory and return
    stack_free(indent_stack);
    return err;
}

/*
 * PURPOSE:
 * --------
 * count_indentation() counts the indentation in the current
 * matched token stored in yytext using the following criteria:
 *
 *      tabs and spaces: valid indentation using any combo
 *      newlines: will be skipped because of the INDENT regex
 *
 * everything else is invalid and causes and indentation error.
 *
 * params: NONE
 *
 * returns: indentation in a long int so that it can be casted
 * to void* when pushed or popped from stack.
*/
long int count_indentation() {
    long int indentation = 0;
    for (int i = 0; i < yyleng; i++) {
        switch (yytext[i]) {
            case '\t':
            case ' ':
                indentation += 1;
            case '\n':
                continue;
            default:
                fprintf(stderr, "Indentation Error on Line %d: Only TABS and SPACES are valid for indentation\n", yylineno);
                have_err = 1;
                return 0;
        }
    }

    return indentation;
}

/*
 * PURPOSE:
 * --------
 * check_indentation() this function handles getting the current indentation
 * of the matched token and then checks to see if there was an indentation or
 * dedentation. If an indentation was detected then an INDENT token is outputted,
 * and inversely if a dedentation was detected then a DEDENT token is outputted.
 *
 * params: NONE
 * returns: NONE
*/
void check_indentation() {
    PRINT_TOKEN("NEWLINE", "");

    long int indentation = count_indentation();
    long int prev_indentation = (long int)stack_top(indent_stack);

    if (indentation > prev_indentation) {
        stack_push(indent_stack, (void*)indentation);
        PRINT_TOKEN("INDENT", "");
    } else if (indentation < prev_indentation) {
        while (indentation < prev_indentation) {
            stack_pop(indent_stack);
            prev_indentation = (long int)stack_top(indent_stack);

            PRINT_TOKEN("DEDENT", "");
        }
    }
}

/*
 * PURPOSE:
 * --------
 * end_of_file() is ran when the <<EOF>> character is matched and
 * handles all the final activities that need to be done when the
 * file is done being scanned such as:
 *
 *      clears out the stack and the corresponding DEDENT tokens
 *      that still need to be printed out.
 *
 *      returns an error from the scanner if an error was occured
 *      so that this can be appropriately handled in main().
 *
 * params: NONE
 *
 * returns: 1 if there was a scanning error and 0 otherwise.
*/
int end_of_file() {
    while ((long int)stack_top(indent_stack) > 0) {
        stack_pop(indent_stack);
        PRINT_TOKEN("DEDENT", "");
    }

    return have_err ? 1 : 0;
}
