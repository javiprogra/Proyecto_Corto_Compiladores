%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int lineas = 1;
int caracteres = 0;
int cant_enteros = 0;
int cant_flotantes = 0;
int cant_identificadores = 0;
int cant_booleanos = 0;
int cant_operadores = 0;

/* Estructura unificada para palabras reservadas */
typedef struct {
    char palabra[50];
    int conteo;
} PalabraReservada;

PalabraReservada lista_pr[100];
int total_pr = 0;

void registrar_pr(const char* pr);
void registrar_token(const char* lexema, const char* token, int linea);
void ordenar_pr();
%}

%option noyywrap

DIGITO [0-9]
LETRA [a-zA-Z_]
ID {LETRA}({LETRA}|{DIGITO})*

ENTERO {DIGITO}({DIGITO}|_)*([iu](8|16|32|64|128|size))?
FLOTANTE {DIGITO}({DIGITO}|_)*\.{DIGITO}({DIGITO}|_)*([f](32|64))?
CADENA \"([^\"\\]|\\.)*\"|r#\"([^#]*)\"#

%%

\n          { lineas++; caracteres++; }
[ \t\r]+    { caracteres += yyleng; }

"//".*      { caracteres += yyleng; }

"/*"([^*]|\*+[^*/])*\*+"/" {
    for(int i = 0; i < yyleng; i++) {
        if(yytext[i] == '\n') lineas++;
    }
    caracteres += yyleng;
}

"true"|"false" {
    caracteres += yyleng;
    cant_booleanos++;
    registrar_token(yytext, "TOKEN_BOOL", lineas);
}

"as"|"async"|"await"|"break"|"const"|"continue"|"crate"|
"dyn"|"else"|"enum"|"extern"|"fn"|"for"|"if"|"impl"|
"in"|"let"|"loop"|"match"|"mod"|"move"|"mut"|"pub"|
"ref"|"return"|"self"|"Self"|"static"|"struct"|"super"|
"trait"|"type"|"unsafe"|"use"|"where"|"while" { 
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas); 
}

{FLOTANTE}  { 
    cant_flotantes++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_FLOAT", lineas); 
}

{ENTERO}    { 
    cant_enteros++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_INT", lineas); 
}

{CADENA}    { 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_STRING", lineas); 
}

"=="|"!="|"<="|">="|">"|"<"|"&&"|"||"|"+"|"-"|"*"|"/" { 
    cant_operadores++; 
    caracteres += yyleng;
    
    char token_op[30];
    sprintf(token_op, "TOKEN_OP_%s", yytext);
    registrar_token(yytext, token_op, lineas); 
}

"=" {
    cant_operadores++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_OP_ASSIGN", lineas);
}

{ID}"!"     {
    cant_identificadores++;
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_MACRO", lineas);
}

{ID}        { 
    cant_identificadores++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_ID", lineas); 
}

.           { caracteres++; }

%%

FILE *json_file;

void registrar_token(const char* lexema, const char* token, int linea) {
    fprintf(json_file, "  {\"lexema\": \"%s\", \"token\": \"%s\", \"linea\": %d},\n", lexema, token, linea);
}

void registrar_pr(const char* pr) {
    for (int i = 0; i < total_pr; i++) {
        if (strcmp(lista_pr[i].palabra, pr) == 0) {
            lista_pr[i].conteo++;
            return;
        }
    }
    strcpy(lista_pr[total_pr].palabra, pr);
    lista_pr[total_pr].conteo = 1;
    total_pr++;
}

void ordenar_pr() {
    PalabraReservada temp;
    for (int i = 0; i < total_pr - 1; i++) {
        for (int j = i + 1; j < total_pr; j++) {
            if (lista_pr[i].conteo < lista_pr[j].conteo) {
                temp = lista_pr[i];
                lista_pr[i] = lista_pr[j];
                lista_pr[j] = temp;
            }
        }
    }
}

int main(int argc, char **argv) {
    if (argc > 1) {
        FILE *archivo = fopen(argv[1], "r");
        if (!archivo) {
            perror("Error al abrir el archivo de Rust");
            return 1;
        }
        yyin = archivo;
    }

    json_file = fopen("salida_tokens.json", "w");
    if (!json_file) {
        perror("Error al crear salida_tokens.json");
        return 1;
    }
    fprintf(json_file, "[\n");

    yylex(); 

    /* Controlamos que el archivo no esté vacío para no romper el formato JSON */
    long pos = ftell(json_file);
    if (pos > 3) { 
        fseek(json_file, -2, SEEK_CUR); 
        fprintf(json_file, "\n]\n");
    } else {
        fprintf(json_file, "]\n");
    }
    fclose(json_file);

    ordenar_pr();

    FILE *reporte_resumen = fopen("resumen_metricas.txt", "w");
    if (!reporte_resumen) {
        perror("Error al crear resumen_metricas.txt");
        return 1;
    }
    fprintf(reporte_resumen, "Lineas:%d\n", lineas);
    fprintf(reporte_resumen, "Caracteres:%d\n", caracteres);
    fprintf(reporte_resumen, "Enteros:%d\n", cant_enteros);
    fprintf(reporte_resumen, "Flotantes:%d\n", cant_flotantes);
    fprintf(reporte_resumen, "Booleanos:%d\n", cant_booleanos);
    fprintf(reporte_resumen, "Identificadores:%d\n", cant_identificadores);
    fprintf(reporte_resumen, "Operadores:%d\n", cant_operadores);
    fprintf(reporte_resumen, "=== PALABRAS RESERVADAS ===\n");
    for(int i = 0; i < total_pr; i++) {
        fprintf(reporte_resumen, "%s:%d\n", lista_pr[i].palabra, lista_pr[i].conteo);
    }
    fclose(reporte_resumen);

    printf("Analisis completado con exito. Archivos 'salida_tokens.json' y 'resumen_metricas.txt' generados.\n");
    return 0;
}