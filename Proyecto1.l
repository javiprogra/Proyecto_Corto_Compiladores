%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Métricas globales */
int lineas = 1;
int caracteres = 0;
int cant_enteros = 0;
int cant_flotantes = 0;
int cant_identificadores = 0;
int cant_booleanos = 0;
int cant_operadores = 0;

/* Estructura para el inventario de Palabras Reservadas */
typedef struct {
    char palabra[50];
    int conteo;
} PalabraReservada;

PalabraReservada lista_pr[100];
int total_pr = 0;

/* Estructura para la Tabla de Símbolos con Manejo de Ámbitos (Rust) */
typedef struct {
    char nombre[50];
    char tipo[50];
    char ambito[60];
} Simbolo;

Simbolo tabla_simbolos[200];
int total_simbolos = 0;

/* Banderas de contexto para la tabla de símbolos */
int nivel_llaves = 0;          /* Cuenta la profundidad de bloques { } */
int esperando_nombre_fn = 0;   /* 1 tras leer 'fn' */
int en_parametros_fn = 0;      /* 1 dentro de ( ) de una función */
int esperando_tipo_param = 0;  /* 1 tras encontrar ':' en parámetros */
int en_bucle_for = 0;          /* 1 tras leer 'for' */
int en_let = 0;                /* 1 tras leer 'let' o 'let mut' */
int esperando_tipo_let = 0;    /* 1 tras encontrar ':' en un let */
int es_extern_fn = 0;          /* 1 tras leer 'extern' */

int es_struct_padre = 0;
int es_enum_padre = 0;
int en_struct = 0;
int en_enum = 0;
int en_const = 0;
char nombre_padre[50] = ""; /* Almacena 'Usuario' o 'Rol' para sus campos/variantes */

char id_temporal[50] = "";     /* Guarda temporalmente el ID a registrar */

/* Prototipos de funciones */
void agregar_simbolo(const char* nombre, const char* tipo, const char* ambito);
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

"extern" {
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas);
    es_extern_fn = 1;
}

"fn" {
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas);
    esperando_nombre_fn = 1;
}

"let" {
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas);
    en_let = 1;
}

"for" {
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas);
    en_bucle_for = 1;
}

"struct" {
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas);
    en_struct = 1;
}

"enum" {
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas);
    en_enum = 1;
}

"const" {
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas);
    en_const = 1;
}

"as"|"async"|"await"|"break"|"continue"|"crate"|"dyn"|"else"|"if"|"impl"|"in"|"loop"|"match"|"mod"|"move"|"mut"|"pub"|"ref"|"return"|"self"|"Self"|"static"|"super"|"trait"|"type"|"unsafe"|"use"|"where"|"while" { 
    caracteres += yyleng;
    registrar_pr(yytext);
    registrar_token(yytext, "TOKEN_PR", lineas); 
}

"{" {
    caracteres++;
    nivel_llaves++;
}

"}" {
    caracteres++;
    /* Si cerramos un Enum y quedó la última variante pendiente sin coma final */
    if (es_enum_padre && id_temporal[0] != '\0') {
        char ambito_enum[100];
        sprintf(ambito_enum, "local (enum %s)", nombre_padre);
        agregar_simbolo(id_temporal, "variant", ambito_enum);
        id_temporal[0] = '\0';
    }

    if (nivel_llaves > 0) nivel_llaves--;
    if (nivel_llaves == 0) {
        nombre_padre[0] = '\0';
        es_struct_padre = 0;
        es_enum_padre = 0;
    }
}

"(" {
    caracteres++;
    if (esperando_nombre_fn) {
        esperando_nombre_fn = 0;
        en_parametros_fn = 1;
    }
}

")" {
    caracteres++;
    /* Si el paréntesis cierra y teníamos un parámetro listo con su tipo, lo guardamos */
    if (en_parametros_fn && esperando_tipo_param && id_temporal[0] != '\0') {
        /* Nota: En este punto yytext contiene el tipo antes de cambiar de token */
        agregar_simbolo(id_temporal, yytext, "local (parametro de funcion)");
        id_temporal[0] = '\0';
    }
    en_parametros_fn = 0;
    esperando_tipo_param = 0;
}

":" {
    caracteres++;
    if (en_parametros_fn) esperando_tipo_param = 1;
    /* Se activa la espera de tipo tanto para variables let, constantes y campos de struct */
    if (en_let || es_struct_padre || en_const) esperando_tipo_let = 1;
}

";" {
    caracteres++;
    /* El punto y coma finaliza statements de let y const */
    if (en_let) {
        if (id_temporal[0] != '\0') {
            agregar_simbolo(id_temporal, "inferred", "local (bloque local)");
            id_temporal[0] = '\0';
        }
        en_let = 0;
        esperando_tipo_let = 0;
    }
    if (en_const) {
        en_const = 0;
        esperando_tipo_let = 0;
        id_temporal[0] = '\0';
    }
}

"," {
    caracteres++;
    
    /* ENUMS: Al encontrar una coma en un Enum, registramos la variante previa */
    if (es_enum_padre && id_temporal[0] != '\0') {
        char ambito_enum[100];
        sprintf(ambito_enum, "local (enum %s)", nombre_padre);
        agregar_simbolo(id_temporal, "variant", ambito_enum);
        id_temporal[0] = '\0';
    }

    /* PARÁMETROS: La coma solo indica que terminamos UN parámetro, bajamos la bandera del tipo */
    if (en_parametros_fn) esperando_tipo_param = 0;
    if (en_let || es_struct_padre) esperando_tipo_let = 0;
}

"=" {
    cant_operadores++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_OP_ASSIGN", lineas);

    /* Al llegar a la asignacion de un let sin tipo explícito (ej. let x = 5;) */
    if (en_let && !esperando_tipo_let && id_temporal[0] != '\0') {
        agregar_simbolo(id_temporal, "inferred", "local (bloque local)");
        id_temporal[0] = '\0';
        en_let = 0; 
    }
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

"=="|"!="|"<="|">="|"=>"|"->"|">"|"<"|"&&"|"||"|"+"|"-"|"*"|"/" { 
    cant_operadores++; 
    caracteres += yyleng;
    registrar_token(yytext, "TOKEN_OP", lineas); 
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

    /* 1. Definición de Estructuras (pub struct Nombre) */
    if (en_struct) {
        agregar_simbolo(yytext, "struct", "global");
        strcpy(nombre_padre, yytext);
        es_struct_padre = 1;
        es_enum_padre = 0;
        en_struct = 0;
    }
    /* 2. Definición de Enumeraciones (pub enum Nombre) */
    else if (en_enum) {
        agregar_simbolo(yytext, "enum", "global");
        strcpy(nombre_padre, yytext);
        es_enum_padre = 1;
        es_struct_padre = 0;
        en_enum = 0;
    }
    /* 3. Definición de Constantes Globales (const NOMBRE: tipo) */
    else if (en_const) {
        if (!esperando_tipo_let) {
            strcpy(id_temporal, yytext);
        } else {
            agregar_simbolo(id_temporal, yytext, "global (const)");
            en_const = 0;
            esperando_tipo_let = 0;
            id_temporal[0] = '\0';
        }
    }
    /* 4. Declaración de Funciones (fn nombre) */
    else if (esperando_nombre_fn) {
        char ambito[50];
        if (es_extern_fn) {
            strcpy(ambito, "externo");
            es_extern_fn = 0;
        } else {
            strcpy(ambito, "global");
        }
        agregar_simbolo(yytext, "function", ambito);
        esperando_nombre_fn = 0;
    } 
    /* 5. Parámetros de Funciones (fn foo(id: u32)) */
    else if (en_parametros_fn) {
        if (!esperando_tipo_param) {
            /* Filtramos modificadores explícitos de Rust en parámetros */
            if (strcmp(yytext, "self") != 0 && strcmp(yytext, "mut") != 0) {
                strcpy(id_temporal, yytext);
            }
        } else {
            /* Registramos el parámetro con su tipo correspondiente */
            agregar_simbolo(id_temporal, yytext, "local (parametro de funcion)");
            esperando_tipo_param = 0;
            id_temporal[0] = '\0';
        }
    }
    /* 6. Variables en bucles for (for precio in precios) */
    else if (en_bucle_for) {
        if (strcmp(yytext, "mut") != 0 && strcmp(yytext, "in") != 0) {
            agregar_simbolo(yytext, "inferred", "local (bucle for)");
            en_bucle_for = 0;
        }
    }
    /* 7. Variables declaradas con let */
    else if (en_let) {
        if (strcmp(yytext, "mut") != 0) {
            if (!esperando_tipo_let) {
                strcpy(id_temporal, yytext);
            } else {
                agregar_simbolo(id_temporal, yytext, "local (bloque local)");
                en_let = 0;
                esperando_tipo_let = 0;
                id_temporal[0] = '\0';
            }
        }
    }
    /* 8. Campos de Structs o Variantes de Enums */
    else if (nivel_llaves > 0 && strlen(nombre_padre) > 0) {
        if (es_struct_padre) {
            if (!esperando_tipo_let) {
                /* Guarda el nombre del campo (ej. 'id', 'nombre', 'saldo') */
                strcpy(id_temporal, yytext);
            } else {
                /* Guarda el tipo del campo (ej. 'u32', 'String', 'f64') */
                char ambito_struct[100];
                sprintf(ambito_struct, "local (struct %s)", nombre_padre);
                agregar_simbolo(id_temporal, yytext, ambito_struct);
                esperando_tipo_let = 0;
                id_temporal[0] = '\0';
            }
        } else if (es_enum_padre) {
            /* Guarda el nombre de la variante (ej. 'Admin', 'Cliente') */
            strcpy(id_temporal, yytext);
        }
    }
}

.           { caracteres++; }

%%

FILE *json_file;

/* Función para evitar duplicados al agregar identificadores */
void agregar_simbolo(const char* nombre, const char* tipo, const char* ambito) {
    for (int i = 0; i < total_simbolos; i++) {
        if (strcmp(tabla_simbolos[i].nombre, nombre) == 0 && 
            strcmp(tabla_simbolos[i].ambito, ambito) == 0) {
            return;
        }
    }

    strcpy(tabla_simbolos[total_simbolos].nombre, nombre);
    strcpy(tabla_simbolos[total_simbolos].tipo, tipo);
    strcpy(tabla_simbolos[total_simbolos].ambito, ambito);
    total_simbolos++;
}

void registrar_token(const char* lexema, const char* token, int linea) {
    char lexema_escapado[500];
    int j = 0;
    int inicio = 0;
    int fin = strlen(lexema);

    if (strcmp(token, "TOKEN_STRING") == 0 && lexema[0] == '"') {
        inicio = 1;
        fin = fin - 1;
    }
    
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
    lexema_escapado[j] = '\0';

    fprintf(json_file, "  {\"lexema\": \"%s\", \"token\": \"%s\", \"linea\": %d},\n", lexema_escapado, token, linea);
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

     /* Cierre del JSON de tokens */
    long pos = ftell(json_file);
    if (pos > 3) { 
        fseek(json_file, -2, SEEK_CUR); 
        fprintf(json_file, "\n]\n");
    } else {
        fprintf(json_file, "]\n");
    }
    fclose(json_file);

    ordenar_pr();

    /* Escritura del Segundo Reporte (Métricas + Tabla de Símbolos) */
    FILE *reporte_resumen = fopen("resumen_metricas.txt", "w");
    if (!reporte_resumen) {
        perror("Error al crear resumen_metricas.txt");
        return 1;
    }

     /* Parte 1: Métricas de conteo */
    fprintf(reporte_resumen, "Lineas:%d\n", lineas);
    fprintf(reporte_resumen, "Caracteres:%d\n", caracteres);
    fprintf(reporte_resumen, "Enteros:%d\n", cant_enteros);
    fprintf(reporte_resumen, "Flotantes:%d\n", cant_flotantes);
    fprintf(reporte_resumen, "Booleanos:%d\n", cant_booleanos);
    fprintf(reporte_resumen, "Identificadores:%d\n", cant_identificadores);
    fprintf(reporte_resumen, "Operadores:%d\n", cant_operadores);

    /* Parte 2: Palabras Reservadas */
    fprintf(reporte_resumen, "=== PALABRAS RESERVADAS ===\n");
    for(int i = 0; i < total_pr; i++) {
        fprintf(reporte_resumen, "%s:%d\n", lista_pr[i].palabra, lista_pr[i].conteo);
    }

      /* Parte 3: Tabla de Símbolos (Adjuntada al 2do Reporte) */
    fprintf(reporte_resumen, "\n=== TABLA DE SIMBOLOS ===\n");
    fprintf(reporte_resumen, "%-20s | %-20s | %-30s\n", "Nombre de simbolo", "Tipo", "Ambito");
    fprintf(reporte_resumen, "-----------------------------------------------------------------------\n");
    for (int i = 0; i < total_simbolos; i++) {
        fprintf(reporte_resumen, "%-20s | %-20s | %-30s\n", 
            tabla_simbolos[i].nombre, 
            tabla_simbolos[i].tipo, 
            tabla_simbolos[i].ambito);
    }
    fclose(reporte_resumen);
    printf("Analisis completado con exito. Archivos 'salida_tokens.json' y 'resumen_metricas.txt' generados.\n");
    return 0;
}