%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"

// Maximum identifier length
#define MAX_ID_LEN 49
%}

%option noyywrap
%option yylineno

%%

"int"            { return INT; }
"char"           { return CHAR; }
"let"            { return LET; }

[a-zA-Z_][a-zA-Z0-9_]* {
    if (strlen(yytext) > MAX_ID_LEN) {
        fprintf(stderr, "Error: Identifier too long (max %d chars): %s\n", MAX_ID_LEN, yytext);
        return ERROR;
    }
    yylval.id = strdup(yytext);
    return IDENTIFIER;
}

[0-9]+ {
    yylval.num = atoi(yytext);
    return NUMBER;
}

\'(\\n|\\t|\\\\|\\\'|\\\"|[ -~])\' {
    // Handle escape sequences and printable ASCII characters
    if (yytext[1] == '\\') {
        switch(yytext[2]) {
            case 'n':  yylval.ch = '\n'; break;
            case 't':  yylval.ch = '\t'; break;
            case '\\': yylval.ch = '\\'; break;
            case '\'': yylval.ch = '\''; break;
            case '"':  yylval.ch = '"'; break;
            default:   yylval.ch = yytext[2]; break;
        }
    } else {
        yylval.ch = yytext[1];
    }
    return CHARACTER;
}

"="              { return ASSIGNMENT; }
","              { return COMMA'; }
";"              { return SEMI; }

[ \t]+           { /* ignore whitespace */ }
\n               { yylineno++; /* track line numbers */ }

"//".*           { /* ignore single-line comments */ }

"/*"([^*]|\*+[^*/])*\*+"/" { /* ignore multi-line comments */ }

.                { 
    fprintf(stderr, "Error: Unknown character: %s\n", yytext);
    return ERROR;
}

%%