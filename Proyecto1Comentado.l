%{
/* =========================================================================
 * SECCIÓN 1: DEFINICIONES DE C (HEADERS, VARIABLES Y ESTRUCTURAS)
 * ========================================================================= */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Contadores globales para métricas de resumen */
int lineas = 1;
int caracteres = 0;
int cant_enteros = 0;
int cant_flotantes = 0;
int cant_identificadores = 0;
int cant_booleanos = 0;
int cant_operadores = 0;

/* Estructura para almacenar palabras reservadas y sus frecuencias */
typedef struct {
    char palabra[50];
    int conteo;
} PalabraReservada;

/* Arreglo para el inventario de palabras reservadas */
PalabraReservada lista_pr[100];
int total_pr = 0;

/* Prototipos de funciones */
void registrar_pr(const char* pr);
void registrar_token(const char* lexema, const char* token, int linea);
void ordenar_pr();
%}

/* Opción para no requerir la librería -lfl al compilar */
%option noyywrap

/* =========================================================================
 * SECCIÓN 2: DEFINICIONES DE EXPRESIONES REGULARES (MACROS DE FLEX)
 * ========================================================================= */

DIGITO [0-9]
LETRA [a-zA-Z_]
ID {LETRA}({LETRA}|{DIGITO})*

/* Tipos numéricos de Rust con o sin sufijos de tipo (ej. 10u32, 3.14f64) */
ENTERO {DIGITO}({DIGITO}|_)*([iu](8|16|32|64|128|size))?
FLOTANTE {DIGITO}({DIGITO}|_)*\.{DIGITO}({DIGITO}|_)*([f](32|64))?

/* Cadenas estándar entre comillas dobles y Raw Strings de Rust (r#"..."#) */
CADENA \"([^\"\\]|\\.)*\"|r#\"([^#]*)\"#

%%

/* =========================================================================
 * SECCIÓN 3: REGLAS LÉXICAS Y ACCIONES
 * ========================================================================= */

\n { 
    /* Incrementar contador de líneas y caracteres al encontrar salto de línea */
    lineas++; 
    caracteres++; 
}

[ \t\r]+ { 
    /* Sumar espacios en blanco y tabulaciones al total de caracteres */
    caracteres += yyleng; 
}

"//".* { 
    /* Comentarios de una sola línea: contar caracteres e ignorar token */
    caracteres += yyleng; 
}

"/*"([^*]|\*+[^*/])*\*+"/" {
    /* Comentarios multilínea: contar saltos de línea internos y caracteres */
    for(int i = 0; i < yyleng; i++) {
        if(yytext[i] == '\n') lineas++;
    }
    caracteres += yyleng;
}

"true"|"false" {
    /* Booleanos de Rust */
    caracteres += yyleng;
    cant_booleanos++;
    registrar_token(yytext, "TOKEN_BOOL", lineas);
}

"as"|"async"|"await"|"break"|"const"|"continue"|"crate"|"dyn"|"else"|"enum"|"extern"|"fn"|"for"|"if"|"impl"|"in"|"let"|"loop"|"match"|"mod"|"move"|"mut"|"pub"|"ref"|"return"|"self"|"Self"|"static"|"struct"|"super"|"trait"|"type"|"unsafe"|"use"|"where"|"while" { 
    /* Lista de palabras reservadas clave de Rust */
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas); 
}

{FLOTANTE} { 
    /* Números flotantes */
    cant_flotantes++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_FLOAT", lineas); 
}

{ENTERO} { 
    /* Números enteros */
    cant_enteros++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_INT", lineas); 
}

{CADENA} { 
    /* Literales de texto / cadenas */
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_STRING", lineas); 
}

"=="|"!="|"<="|">="|"=>"|"->"|">"|"<"|"&&"|"||"|"+"|"-"|"*"|"/" { 
    /* Operadores aritméticos, lógicos, de comparación y flechas de Rust */
    cant_operadores++; 
    caracteres += yyleng;
    
    char token_op[30];
    sprintf(token_op, "TOKEN_OP_%s", yytext);
    registrar_token(yytext, token_op, lineas); 
}

"=" {
    /* Operador de asignación simple */
    cant_operadores++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_OP_ASSIGN", lineas);
}

{ID}"!" {
    /* Invocaciones de macros en Rust (ej. println!, vec!) */
    cant_identificadores++;
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_MACRO", lineas);
}

{ID} { 
    /* Identificadores normales (variables, funciones, tipos) */
    cant_identificadores++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_ID", lineas); 
}

. { 
    /* Captura cualquier otro carácter individual no contemplado */
    caracteres++; 
}

%%

/* =========================================================================
 * SECCIÓN 4: CÓDIGO C DE SOPORTE (FUNCIONES Y MAIN)
 * ========================================================================= */

FILE *json_file;

/* Función que procesa los tokens, remueve comillas extremas en cadenas y escapa caracteres especiales */
void registrar_token(const char* lexema, const char* token, int linea) {
    char lexema_escapado[500];
    int j = 0;
    int inicio = 0;
    int fin = strlen(lexema);

    /* Si es una cadena entre comillas dobles, se ajustan los límites para omitirlas */
    if (strcmp(token, "TOKEN_STRING") == 0 && lexema[0] == '"') {
        inicio = 1;
        fin = fin - 1;
    }
    
    /* Bucle para copiar el lexema escapando comillas internas y barras invertidas para JSON */
    for (int i = inicio; i < fin && j < 490; i++) {
        if (lexema[i] == '"') {
            lexema_escapado[j++] = '\\';
            lexema_escapado[j++] = '"';
        } else if (lexema[i] == '\\') {
            lexema_escapado[j++] = '\\';
            lexema_escapado[j++] = '\\';
        } else {
            lexema_escapado[j++] = lexema[i];
        }
    }
    lexema_escapado[j] = '\0'; /* Cierre de cadena en C */

    /* Escritura de la entidad en formato JSON */
    fprintf(json_file, "  {\"lexema\": \"%s\", \"token\": \"%s\", \"linea\": %d},\n", lexema_escapado, token, linea);
}

/* Registra o incrementa el conteo de apariciones de cada palabra reservada */
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

/* Ordena las palabras reservadas de mayor a menor frecuencia mediante ordenamiento burbuja */
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

/* Función principal del analizador */
int main(int argc, char **argv) {
    /* Lectura de archivo fuente si se provee como argumento */
    if (argc > 1) {
        FILE *archivo = fopen(argv[1], "r");
        if (!archivo) {
            perror("Error al abrir el archivo de Rust");
            return 1;
        }
        yyin = archivo;
    }

    /* Apertura del archivo JSON de salida */
    json_file = fopen("salida_tokens.json", "w");
    if (!json_file) {
        perror("Error al crear salida_tokens.json");
        return 1;
    }
    fprintf(json_file, "[\n");

    /* Ejecución del análisis léxico */
    yylex(); 

    /* Ajuste para eliminar la última coma sobrante del JSON y cerrar el arreglo */
    long pos = ftell(json_file);
    if (pos > 3) { 
        fseek(json_file, -2, SEEK_CUR); 
        fprintf(json_file, "\n]\n");
    } else {
        fprintf(json_file, "]\n");
    }
    fclose(json_file);

    /* Generación del reporte de texto secundario */
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