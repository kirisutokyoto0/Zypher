%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void yyerror(const char *s);
extern int yylex();
extern char* yytext;
extern int yylineno;

#define MAX_SYMBOLS 100
#define MAX_NAME_LEN 50

// Symbol table entry
typedef struct {
    char name[MAX_NAME_LEN];
    char type;    // 'i' for int, 'c' for char
    int value;    // store int value or ASCII for char
    int declared; // 1 if declared, 0 if not
} Var;

Var symbol_table[MAX_SYMBOLS];
int symbol_count = 0;
int error_count = 0;

// Function to find a variable in the symbol table
int find_var(char* name) {
    for(int i = 0; i < symbol_count; i++) {
        if(strcmp(symbol_table[i].name, name) == 0) {
            return i;
        }
    }
    return -1;
}

// Function to add a new variable to the symbol table
int add_new_var(char* name, char type, int value) {
    if(symbol_count >= MAX_SYMBOLS) {
        fprintf(stderr, "Error: Symbol table full (max %d variables)\n", MAX_SYMBOLS);
        error_count++;
        return -1;
    }
    
    if(strlen(name) >= MAX_NAME_LEN) {
        fprintf(stderr, "Error: Variable name too long: %s\n", name);
        error_count++;
        return -1;
    }
    
    // Check if already declared in this scope
    int idx = find_var(name);
    if(idx != -1) {
        fprintf(stderr, "Error: Variable '%s' already declared\n", name);
        error_count++;
        return -1;
    }
    
    strncpy(symbol_table[symbol_count].name, name, MAX_NAME_LEN - 1);
    symbol_table[symbol_count].name[MAX_NAME_LEN - 1] = '\0';
    symbol_table[symbol_count].type = type;
    symbol_table[symbol_count].value = value;
    symbol_table[symbol_count].declared = 1;
    symbol_count++;
    return symbol_count - 1;
}

// Function to add or update a variable (used for assignments with type inference)
int add_or_update_var(char* name, char type, int value) {
    int idx = find_var(name);
    
    if(idx == -1) {
        // Variable doesn't exist, create it (type inference)
        return add_new_var(name, type, value);
    } else {
        // Variable exists, update it
        // Type checking
        if(symbol_table[idx].type != type) {
            fprintf(stderr, "Warning: Type mismatch for variable '%s' (declared as %s, assigned as %s)\n",
                    name, 
                    symbol_table[idx].type == 'i' ? "int" : "char",
                    type == 'i' ? "int" : "char");
        }
        
        symbol_table[idx].value = value;
        return idx;
    }
}

// Debug: print symbol table
void print_table() {
    printf("\n=== Symbol Table ===\n");
    printf("%-20s %-10s %-10s\n", "Name", "Type", "Value");
    printf("-----------------------------------------------\n");
    for(int i = 0; i < symbol_count; i++) {
        printf("%-20s %-10s ", 
               symbol_table[i].name, 
               symbol_table[i].type == 'i' ? "int" : "char");
        
        if(symbol_table[i].type == 'c' && symbol_table[i].value >= 32 && symbol_table[i].value <= 126) {
            printf("'%c' (%d)\n", symbol_table[i].value, symbol_table[i].value);
        } else {
            printf("%d\n", symbol_table[i].value);
        }
    }
    printf("====================\n");
}

// Global variable to track current declaration type
char current_decl_type = 'i';
%}

%union {
    int num;
    char ch;
    char* id;
}

%token <num> NUMBER
%token <ch> CHARACTER
%token <id> IDENTIFIER
%token INT CHAR LET ERROR SEMI COMMA ASSIGNMENT

%type <ch> type_spec

%%
// current
program:
      stmt_list { 
          if(error_count == 0) {
              printf("\nParsing completed successfully!\n");
          } else {
              printf("\nParsing completed with %d error(s)\n", error_count);
          }
      }
    | /* empty */ {
          printf("\nNo input provided.\n");
      }
;


stmt_list:
      stmt
    | stmt_list stmt
;

stmt:
      var_decl SEMI
    | assignment SEMI
    | let_assignment SEMI
    | var_decl error {
          fprintf(stderr, "Error: Missing semicolon after variable declaration\n");
          yyerrok;
          error_count++;
      }
    | assignment error {
          fprintf(stderr, "Error: Missing semicolon after assignment\n");
          yyerrok;
          error_count++;
      }
    | let_assignment error {
          fprintf(stderr, "Error: Missing semicolon after let statement\n");
          yyerrok;
          error_count++;
      }
    | error SEMI { 
          fprintf(stderr, "Error: Invalid statement, skipping to next semicolon\n");
          yyerrok; 
          error_count++; 
      }
;

type_spec:
      INT  { $$ = 'i'; }
    | CHAR { $$ = 'c'; }
;

var_decl:
      type_spec { current_decl_type = $1; } var_init_list {
          printf("✓ Parsed %s declaration\n", $1 == 'i' ? "INT" : "CHAR");
      }
;

var_init_list:
      var_init
    | var_init_list COMMA var_init
;

var_init:
    CHAR IDENTIFIER SEMI {
          if(add_new_var($1, current_decl_type, 0) != -1) {
              printf("  → %s (uninitialized)\n", $1);
          }
          free($1);
      }
    |
      INT IDENTIFIER SEMI {
          if(add_new_var($1, current_decl_type, 0) != -1) {
              printf("  → %s (uninitialized)\n", $1);
          }
          free($1);
      }
    | IDENTIFIER ASSIGNMENT NUMBER SEMI {
          if(current_decl_type == 'c') {
              // Allow implicit conversion but warn if out of char range
              if($3 > 127 || $3 < -128) {
                  fprintf(stderr, "Warning: Number %d may be out of char range for '%s'\n", $3, $1);
              }
          }
          if(add_new_var($1, current_decl_type, $3) != -1) {
              printf("  → %s = %d\n", $1, $3);
          }
          free($1);
      }
    | IDENTIFIER ASSIGNMENT CHARACTER SEMI {
          int val = (int)$3;
          if(current_decl_type == 'i') {
              // Implicitly convert char to int (ASCII value)
              if(add_new_var($1, current_decl_type, val) != -1) {
                  printf("  → %s = '%c' (%d)\n", $1, $3, val);
              }
          } else {
              if(add_new_var($1, current_decl_type, $3) != -1) {
                  printf("  → %s = '%c'\n", $1, $3);
              }
          }
          free($1);
      }
;

let_assignment:
      LET IDENTIFIER ASSIGNMENT NUMBER SEMI {
          // 'let' for implicit typing based on value
          if(add_new_var($2, 'i', $4) != -1) {
              printf("✓ Let declaration: %s = %d (int)\n", $2, $4);
          }
          free($2);
      }
    | LET IDENTIFIER ASSIGNMENT CHARACTER SEMI {
          if(add_new_var($2, 'c', $4) != -1) {
              printf("✓ Let declaration: %s = '%c' (char)\n", $2, $4);
          }
          free($2);
      }
;

assignment:
      IDENTIFIER ASSIGNMENT NUMBER SEMI {
          if(add_or_update_var($1, 'i', $3) != -1) {
              printf("✓ Assigned %s = %d\n", $1, $3);
          }
          free($1);
      }
    | IDENTIFIER ASSIGNMENT CHARACTER SEMI{
          if(add_or_update_var($1, 'c', $3) != -1) {
              printf("✓ Assigned %s = '%c'\n", $1, $3);
          }
          free($1);
      }
;


%%

int main() {
    printf("╔════════════════════════════════════════╗\n");
    printf("║    Zypher Language Parser v1.0         ║\n");
    printf("╚════════════════════════════════════════╝\n\n");
    printf("Supported syntax:\n");
    printf("  • int x, y = 5;        (integer declaration)\n");
    printf("  • char c = 'a';        (character declaration)\n");
    printf("  • let z = 10;          (type inference)\n");
    printf("  • x = 42;              (assignment)\n");
    printf("\nEnter your code (Ctrl+D or Ctrl+Z to end):\n");
    printf("----------------------------------------\n");
    
    int parse_result = yyparse();
    
    if(symbol_count > 0) {
        print_table();
    } else if(error_count == 0) {
        printf("\nNo variables declared.\n");
    }
    
    return error_count > 0 ? 1 : 0;
}

void yyerror(const char *s) {
    fprintf(stderr, "Parse error: %s\n", s);
}