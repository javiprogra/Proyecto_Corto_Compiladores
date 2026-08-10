import json
import re
from datetime import datetime
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    LongTable,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


# Rutas de los archivos que ya crea el analizador
BASE = Path(__file__).resolve().parent
TOKENS_JSON = BASE / "salida_tokens.json"
RESUMEN_TXT = BASE / "resumen_metricas.txt"
CARPETA_PDF = BASE / "reportes"
ARCHIVO_ANALIZADO = "prueba.rs"

VERDE_OSCURO = colors.HexColor("#174A3A")
VERDE = colors.HexColor("#287A5B")
GRIS = colors.HexColor("#F1F4F3")
GRIS_TEXTO = colors.HexColor("#4B5563")


def cargar_tokens():
    texto = TOKENS_JSON.read_text(encoding="utf-8")
    # También funciona si el JSON trae una coma antes del corchete final.
    texto = re.sub(r",\s*\]", "\n]", texto)
    return json.loads(texto)


def cargar_resumen():
    metricas = {
        "lineas": 0,
        "caracteres": 0,
        "enteros": 0,
        "flotantes": 0,
        "booleanos": 0,
        "identificadores": 0,
        "operadores": 0,
    }
    reservadas = {}
    simbolos = []

    equivalencias = {
        "Lineas": "lineas",
        "Caracteres": "caracteres",
        "Enteros": "enteros",
        "Flotantes": "flotantes",
        "Booleanos": "booleanos",
        "Identificadores": "identificadores",
        "Operadores": "operadores",
    }

    seccion = "metricas"

    for linea in RESUMEN_TXT.read_text(encoding="utf-8").splitlines():
        linea = linea.strip()
        if not linea:
            continue

        if linea == "=== PALABRAS RESERVADAS ===":
            seccion = "reservadas"
            continue
        if linea == "=== TABLA DE SIMBOLOS ===":
            seccion = "simbolos"
            continue

        if seccion == "metricas" and ":" in linea:
            nombre, cantidad = linea.split(":", 1)
            if nombre in equivalencias:
                metricas[equivalencias[nombre]] = int(cantidad.strip())

        elif seccion == "reservadas" and ":" in linea:
            palabra, cantidad = linea.split(":", 1)
            reservadas[palabra.strip()] = int(cantidad.strip())

        elif seccion == "simbolos":
            if "Nombre de simbolo" in linea or set(linea) == {"-"}:
                continue
            partes = [parte.strip() for parte in linea.split("|", 2)]
            if len(partes) == 3:
                simbolos.append(
                    {"nombre": partes[0], "tipo": partes[1], "ambito": partes[2]}
                )

    return metricas, reservadas, simbolos


def crear_estilos():
    estilos = getSampleStyleSheet()
    estilos.add(
        ParagraphStyle(
            name="TituloProyecto",
            parent=estilos["Title"],
            textColor=VERDE_OSCURO,
            fontSize=17,
            leading=20,
            alignment=TA_CENTER,
            spaceAfter=4,
        )
    )
    estilos.add(
        ParagraphStyle(
            name="TituloReporte",
            parent=estilos["Heading2"],
            textColor=VERDE,
            fontSize=13,
            leading=15,
            alignment=TA_CENTER,
            spaceAfter=7,
        )
    )
    estilos.add(
        ParagraphStyle(
            name="Datos",
            parent=estilos["Normal"],
            textColor=GRIS_TEXTO,
            fontSize=8,
            alignment=TA_CENTER,
            spaceAfter=8,
        )
    )
    estilos.add(
        ParagraphStyle(
            name="Seccion",
            parent=estilos["Heading2"],
            textColor=VERDE_OSCURO,
            fontSize=11,
            spaceBefore=4,
            spaceAfter=6,
        )
    )
    estilos.add(
        ParagraphStyle(
            name="Celda",
            parent=estilos["Normal"],
            fontSize=7.5,
            leading=9,
        )
    )
    return estilos


def texto_celda(valor, estilos):
    texto = str(valor).replace("\n", "\\n").replace("\t", "\\t")
    return Paragraph(escape(texto), estilos["Celda"])


def encabezado(estilos, titulo):
    fecha = datetime.now().strftime("%d/%m/%Y %H:%M")
    return [
        Paragraph(
            "Proyecto Corto #1 - Analizador Estático de Código",
            estilos["TituloProyecto"],
        ),
        Paragraph(titulo, estilos["TituloReporte"]),
        Paragraph(
            f"Lenguaje: Rust | Archivo: {ARCHIVO_ANALIZADO} | Generado: {fecha}",
            estilos["Datos"],
        ),
    ]


def estilizar_tabla(tabla, total_filas, columnas_centradas=()):
    comandos = [
        ("BACKGROUND", (0, 0), (-1, 0), VERDE_OSCURO),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 8),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#B8C2C0")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]

    for fila in range(2, total_filas, 2):
        comandos.append(("BACKGROUND", (0, fila), (-1, fila), GRIS))
    for columna in columnas_centradas:
        comandos.append(("ALIGN", (columna, 0), (columna, -1), "CENTER"))

    tabla.setStyle(TableStyle(comandos))
    return tabla


def pie_pagina(canvas, documento):
    canvas.saveState()
    ancho = documento.pagesize[0]
    canvas.setStrokeColor(colors.HexColor("#CBD5D1"))
    canvas.line(documento.leftMargin, 34, ancho - documento.rightMargin, 34)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(GRIS_TEXTO)
    canvas.drawString(documento.leftMargin, 21, "UMES - Compiladores")
    canvas.drawRightString(
        ancho - documento.rightMargin, 21, f"Página {documento.page}"
    )
    canvas.restoreState()


def generar_reporte_1(metricas, reservadas):
    estilos = crear_estilos()
    ruta = CARPETA_PDF / "reporte_1_metricas_prueba.pdf"
    documento = SimpleDocTemplate(
        str(ruta),
        pagesize=letter,
        leftMargin=0.6 * inch,
        rightMargin=0.6 * inch,
        topMargin=0.45 * inch,
        bottomMargin=0.6 * inch,
        title="Reporte 1 - Métricas",
    )

    contenido = encabezado(estilos, "Reporte 1 - Métricas del análisis léxico")
    contenido.append(Paragraph("Resumen general", estilos["Seccion"]))

    nombres = [
        ("Cantidad de líneas de código", "lineas"),
        ("Cantidad de caracteres", "caracteres"),
        ("Números enteros encontrados", "enteros"),
        ("Números flotantes encontrados", "flotantes"),
        ("Identificadores encontrados", "identificadores"),
        ("Valores booleanos encontrados", "booleanos"),
        ("Operadores encontrados", "operadores"),
    ]
    filas = [["Métrica", "Cantidad"]]
    filas += [[nombre, metricas[clave]] for nombre, clave in nombres]

    tabla = Table(filas, colWidths=[4.9 * inch, 1.3 * inch], repeatRows=1)
    contenido.append(estilizar_tabla(tabla, len(filas), (1,)))
    contenido.append(Spacer(1, 8))
    contenido.append(Paragraph("Palabras reservadas", estilos["Seccion"]))

    ordenadas = sorted(reservadas.items(), key=lambda dato: (-dato[1], dato[0]))
    filas = [["No.", "Palabra reservada", "Cantidad"]]
    filas += [
        [numero, palabra, cantidad]
        for numero, (palabra, cantidad) in enumerate(ordenadas, 1)
    ]
    if not ordenadas:
        filas.append(["-", "No se encontraron", 0])

    tabla = LongTable(
        filas, colWidths=[0.7 * inch, 4.2 * inch, 1.3 * inch], repeatRows=1
    )
    contenido.append(estilizar_tabla(tabla, len(filas), (0, 2)))
    documento.build(contenido, onFirstPage=pie_pagina, onLaterPages=pie_pagina)
    return ruta


def generar_reporte_2(tokens, simbolos):
    estilos = crear_estilos()
    ruta = CARPETA_PDF / "reporte_2_lexemas_simbolos_prueba.pdf"
    documento = SimpleDocTemplate(
        str(ruta),
        pagesize=landscape(letter),
        leftMargin=0.5 * inch,
        rightMargin=0.5 * inch,
        topMargin=0.45 * inch,
        bottomMargin=0.6 * inch,
        title="Reporte 2 - Lexemas y símbolos",
    )

    contenido = encabezado(estilos, "Reporte 2 - Lexemas y tabla de símbolos")
    contenido.append(
        Paragraph(f"Lexemas encontrados: {len(tokens)}", estilos["Seccion"])
    )

    filas = [["No.", "Lexema", "Token", "Línea"]]
    for numero, token in enumerate(tokens, 1):
        filas.append(
            [
                numero,
                texto_celda(token.get("lexema", ""), estilos),
                texto_celda(token.get("token", ""), estilos),
                token.get("linea", ""),
            ]
        )
    if not tokens:
        filas.append(["-", "No se encontraron lexemas", "-", "-"])

    tabla = LongTable(
        filas,
        colWidths=[0.55 * inch, 4.0 * inch, 3.55 * inch, 0.8 * inch],
        repeatRows=1,
    )
    contenido.append(estilizar_tabla(tabla, len(filas), (0, 3)))

    contenido.append(PageBreak())
    contenido.extend(encabezado(estilos, "Reporte 2 - Tabla de símbolos"))
    contenido.append(
        Paragraph(f"Símbolos registrados: {len(simbolos)}", estilos["Seccion"])
    )

    filas = [["No.", "Nombre del símbolo", "Tipo", "Ámbito"]]
    for numero, simbolo in enumerate(simbolos, 1):
        filas.append(
            [
                numero,
                texto_celda(simbolo["nombre"], estilos),
                texto_celda(simbolo["tipo"], estilos),
                texto_celda(simbolo["ambito"], estilos),
            ]
        )
    if not simbolos:
        filas.append(["-", "No se registraron símbolos", "-", "-"])

    tabla = LongTable(
        filas,
        colWidths=[0.55 * inch, 2.5 * inch, 2.5 * inch, 3.35 * inch],
        repeatRows=1,
    )
    contenido.append(estilizar_tabla(tabla, len(filas), (0,)))
    documento.build(contenido, onFirstPage=pie_pagina, onLaterPages=pie_pagina)
    return ruta


def generar_reportes_pdf(archivo_analizado=ARCHIVO_ANALIZADO):
    faltantes = [
        ruta.name
        for ruta in (TOKENS_JSON, RESUMEN_TXT)
        if not ruta.exists()
    ]

    if faltantes:
        raise FileNotFoundError(
            "FALTAN ESTOS ARCHIVOS: " + ", ".join(faltantes).upper()
        )

    tokens = cargar_tokens()
    metricas, reservadas, simbolos = cargar_resumen()

    CARPETA_PDF.mkdir(exist_ok=True)

    reporte_1 = generar_reporte_1(metricas, reservadas)
    reporte_2 = generar_reporte_2(tokens, simbolos)

    return reporte_1, reporte_2


def main():
    try:
        reporte_1, reporte_2 = generar_reportes_pdf()

        mostrar_mensaje("REPORTES GENERADOS CORRECTAMENTE:")
        mostrar_mensaje(reporte_1)
        mostrar_mensaje(reporte_2)

    except Exception as error:
        mostrar_mensaje(f"ERROR AL GENERAR LOS REPORTES: {error}")


if __name__ == "__main__":
    main()