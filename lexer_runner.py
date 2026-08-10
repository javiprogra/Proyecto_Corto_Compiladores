import json
import os
import re
import subprocess


def ejecutar_analizador_lexico(
    ruta_archivo_rs, ruta_ejecutable="analizadorP.exe"
):
  """Ejecuta el binario 'analizadorP.exe' pasándole la ruta de prueba.rs

  y procesa los archivos 'salida_tokens.json' y 'resumen_metricas.txt'.
  """
  if not os.path.exists(ruta_ejecutable):
    raise FileNotFoundError(
        f"No se encontró el ejecutable '{ruta_ejecutable}' en la raíz del"
        " proyecto."
    )

  # Ejecutar el archivo .exe enviándole el archivo .rs por tubería
  proceso = subprocess.run(
      [ruta_ejecutable, ruta_archivo_rs],
      capture_output=True,
      text=True,
      encoding="utf-8",
  )

  if proceso.returncode != 0:
    raise RuntimeError(
        f"Error al ejecutar Flex:\n{proceso.stderr or proceso.stdout}"
    )

  archivo_json = "salida_tokens.json"
  archivo_txt = "resumen_metricas.txt"

  if not os.path.exists(archivo_json) or not os.path.exists(archivo_txt):
    raise FileNotFoundError(
        "El ejecutable no generó los archivos 'salida_tokens.json' o"
        " 'resumen_metricas.txt'."
    )

  # 1. Cargar la lista completa de tokens desinfectando la coma final
  with open(archivo_json, "r", encoding="utf-8") as f:
    contenido_json = f.read()

  # Eliminar comas flotantes/finales antes del cierre de arreglo ']'
  contenido_limpio = re.sub(r",\s*\]", "\n]", contenido_json)
  lista_tokens = json.loads(contenido_limpio)

  # 2. Cargar Métricas y Tabla de Símbolos desde el TXT
  metricas = {
      "lineas": 0,
      "caracteres": 0,
      "enteros": 0,
      "flotantes": 0,
      "booleanos": 0,
      "identificadores": 0,
      "operadores": 0,
      "palabras_reservadas": {},
  }
  tabla_simbolos = []
  seccion = "METRICAS"

  with open(archivo_txt, "r", encoding="utf-8") as f:
    for linea in f:
      linea_limpia = linea.strip()
      if not linea_limpia:
        continue

      if "=== PALABRAS RESERVADAS ===" in linea_limpia:
        seccion = "RESERVADAS"
        continue
      elif "=== TABLA DE SIMBOLOS ===" in linea_limpia:
        seccion = "SIMBOLOS"
        continue

      if seccion == "METRICAS" and ":" in linea_limpia:
        clave, valor = linea_limpia.split(":", 1)
        mapa = {
            "Lineas": "lineas",
            "Caracteres": "caracteres",
            "Enteros": "enteros",
            "Flotantes": "flotantes",
            "Booleanos": "booleanos",
            "Identificadores": "identificadores",
            "Operadores": "operadores",
        }
        if clave in mapa:
          metricas[mapa[clave]] = int(valor)

      elif seccion == "RESERVADAS" and ":" in linea_limpia:
        clave, valor = linea_limpia.split(":", 1)
        metricas["palabras_reservadas"][clave] = int(valor)

      elif seccion == "SIMBOLOS":
        if "Nombre de simbolo" in linea_limpia or "---" in linea_limpia:
          continue
        partes = [p.strip() for p in linea_limpia.split("|")]
        if len(partes) == 3:
          tabla_simbolos.append({
              "nombre": partes[0],
              "tipo": partes[1],
              "ambito": partes[2],
          })

  return metricas, tabla_simbolos, lista_tokens