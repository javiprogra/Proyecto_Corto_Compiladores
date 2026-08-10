import os
import customtkinter as ctk
from tkinter import filedialog, messagebox, ttk

#Importación del ejecutable runner
from lexer_runner import ejecutar_analizador_lexico

#Importación de la base de datos
from database import guardar_reporte_mongo

#Importación del generador de reportes PDF
from G_Reportes import generar_reportes_pdf

# Configuración de apariencia
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")


class AnalizadorGUI(ctk.CTk):

  def __init__(self):
    super().__init__()

    self.title("Analizador Léxico - Rust | Proyecto Compiladores")
    self.geometry("1100x700")

    self.archivo_cargado_path = None
    self.tabla_simbolos = []
    self.metricas = {}

    #Configuración de cuadrícula principal
    self.grid_columnconfigure(0, weight=1)
    self.grid_columnconfigure(1, weight=2)
    self.grid_rowconfigure(1, weight=1)

    #Barra superior
    self.frame_top = ctk.CTkFrame(self)
    self.frame_top.grid(
        row=0, column=0, columnspan=2, padx=15, pady=10, sticky="ew"
    )

    self.btn_cargar = ctk.CTkButton(
        self.frame_top,
        text="Abrir Archivo (.rs)",
        command=self.cargar_archivo,
    )
    self.btn_cargar.pack(side="left", padx=10, pady=10)

    self.lbl_archivo = ctk.CTkLabel(
        self.frame_top, text="Ningún archivo seleccionado", text_color="gray"
    )
    self.lbl_archivo.pack(side="left", padx=10)

    self.btn_procesar = ctk.CTkButton(
        self.frame_top,
        text="Procesar Código",
        fg_color="green",
        hover_color="darkgreen",
        command=self.procesar_codigo,
    )
    self.btn_procesar.pack(side="right", padx=10, pady=10)

    self.btn_reportes_pdf = ctk.CTkButton(
    self.frame_top,
    text="GENERAR REPORTES EN PDF",
    command=self.generar_reportes_desde_interfaz,
    state="disabled",
    )
    self.btn_reportes_pdf.pack(side="right", padx=10, pady=10)
    #Panel izquierdo
    self.frame_codigo = ctk.CTkFrame(self)
    self.frame_codigo.grid(
        row=1, column=0, padx=(15, 5), pady=10, sticky="nsew"
    )

    self.lbl_codigo_title = ctk.CTkLabel(
        self.frame_codigo,
        text="Código Fuente (Rust)",
        font=("Arial", 14, "bold"),
    )
    self.lbl_codigo_title.pack(anchor="w", padx=10, pady=5)

    self.txt_codigo = ctk.CTkTextbox(
        self.frame_codigo, font=("Consolas", 12), wrap="none"
    )
    self.txt_codigo.pack(fill="both", expand=True, padx=10, pady=10)

    #Panel derecho
    self.tabview_resultados = ctk.CTkTabview(self)
    self.tabview_resultados.grid(
        row=1, column=1, padx=(5, 15), pady=10, sticky="nsew"
    )

    self.tab_reporte1 = self.tabview_resultados.add("Reporte 1: Métricas")
    self.tab_reporte2 = self.tabview_resultados.add(
        "Reporte 2: Tabla de Símbolos"
    )

    self._setup_tab_reporte1()
    self._setup_tab_reporte2()

  def _setup_tab_reporte1(self):
    self.lbl_metrica_lineas = ctk.CTkLabel(
        self.tab_reporte1, text="Líneas de código: 0", anchor="w"
    )
    self.lbl_metrica_lineas.pack(fill="x", padx=10, pady=2)

    self.lbl_metrica_caracteres = ctk.CTkLabel(
        self.tab_reporte1, text="Cantidad de caracteres: 0", anchor="w"
    )
    self.lbl_metrica_caracteres.pack(fill="x", padx=10, pady=2)

    self.lbl_metrica_enteros = ctk.CTkLabel(
        self.tab_reporte1, text="Números enteros: 0", anchor="w"
    )
    self.lbl_metrica_enteros.pack(fill="x", padx=10, pady=2)

    self.lbl_metrica_flotantes = ctk.CTkLabel(
        self.tab_reporte1, text="Números flotantes: 0", anchor="w"
    )
    self.lbl_metrica_flotantes.pack(fill="x", padx=10, pady=2)

    self.lbl_metrica_ids = ctk.CTkLabel(
        self.tab_reporte1, text="Identificadores: 0", anchor="w"
    )
    self.lbl_metrica_ids.pack(fill="x", padx=10, pady=2)

    self.lbl_metrica_booleanos = ctk.CTkLabel(
        self.tab_reporte1, text="Valores booleanos: 0", anchor="w"
    )
    self.lbl_metrica_booleanos.pack(fill="x", padx=10, pady=2)

    self.lbl_metrica_operadores = ctk.CTkLabel(
        self.tab_reporte1, text="Operadores: 0", anchor="w"
    )
    self.lbl_metrica_operadores.pack(fill="x", padx=10, pady=2)

    self.lbl_reservadas_title = ctk.CTkLabel(
        self.tab_reporte1,
        text="Palabras Reservadas (Descendente):",
        font=("Arial", 12, "bold"),
    )
    self.lbl_reservadas_title.pack(anchor="w", padx=10, pady=(10, 2))

    self.txt_reservadas = ctk.CTkTextbox(self.tab_reporte1, height=120)
    self.txt_reservadas.pack(fill="both", expand=True, padx=10, pady=5)

  def _setup_tab_reporte2(self):
    #Tabla interactiva para la Tabla de Símbolos
    columns = ("nombre", "tipo", "ambito")
    self.tree_simbolos = ttk.Treeview(
        self.tab_reporte2, columns=columns, show="headings"
    )

    self.tree_simbolos.heading("nombre", text="Nombre de símbolo")
    self.tree_simbolos.heading("tipo", text="Tipo")
    self.tree_simbolos.heading("ambito", text="Ámbito")

    self.tree_simbolos.column("nombre", width=150, anchor="w")
    self.tree_simbolos.column("tipo", width=150, anchor="w")
    self.tree_simbolos.column("ambito", width=220, anchor="w")

    self.tree_simbolos.pack(fill="both", expand=True, padx=10, pady=10)

    self.btn_guardar_mongo = ctk.CTkButton(
        self.tab_reporte2,
        text="Guardar Tabla de Símbolos en MongoDB",
        command=self.guardar_en_mongodb,
    )
    self.btn_guardar_mongo.pack(padx=10, pady=10)

  def cargar_archivo(self):
    filepath = filedialog.askopenfilename(
        filetypes=[("Archivos de Rust", "*.rs"), ("Todos los archivos", "*.*")]
    )
    if filepath:
      self.archivo_cargado_path = filepath
      self.btn_reportes_pdf.configure(state="disabled")
      self.lbl_archivo.configure(
          text=os.path.basename(filepath), text_color="white"
      )
      with open(filepath, "r", encoding="utf-8") as file:
        contenido = file.read()
        self.txt_codigo.delete("1.0", "end")
        self.txt_codigo.insert("1.0", contenido)

  def procesar_codigo(self):
    if not self.archivo_cargado_path:
      messagebox.showwarning(
          "Atención", "Por favor selecciona un archivo .rs antes de procesar."
      )
      return

    try:
      
      self.btn_reportes_pdf.configure(state="disabled")
      self.metricas, self.tabla_simbolos, _ = ejecutar_analizador_lexico(
          self.archivo_cargado_path
      )
      self._actualizar_reporte1(self.metricas)
      self._actualizar_reporte2(self.tabla_simbolos)
      self.btn_reportes_pdf.configure(state="normal")
      messagebox.showinfo(
          "Éxito", "Análisis completado y reportes actualizados."
      )

    except Exception as e:
      messagebox.showerror(
          "Error de Análisis", f"Ocurrió un error al procesar:\n{str(e)}"
      )
      
  def generar_reportes_desde_interfaz(self):
    if not self.archivo_cargado_path or not self.metricas:
      messagebox.showwarning(
          "ATENCIÓN",
          "PRIMERO DEBES ABRIR Y PROCESAR UN ARCHIVO .RS.",
      )
      return

    try:
      nombre_archivo = os.path.basename(self.archivo_cargado_path)
      reporte_1, reporte_2 = generar_reportes_pdf(nombre_archivo)

      messagebox.showinfo(
          "REPORTES PDF",
          "REPORTES GENERADOS CORRECTAMENTE:\n\n"
          f"{str(reporte_1).upper()}\n\n"
          f"{str(reporte_2).upper()}",
      )

    except Exception as e:
      messagebox.showerror(
          "ERROR AL GENERAR REPORTES",
          f"NO FUE POSIBLE GENERAR LOS PDF:\n{str(e).upper()}",
      )
  def _actualizar_reporte1(self, m):
    self.lbl_metrica_lineas.configure(text=f"Líneas de código: {m['lineas']}")
    self.lbl_metrica_caracteres.configure(
        text=f"Cantidad de caracteres: {m['caracteres']}"
    )
    self.lbl_metrica_enteros.configure(text=f"Números enteros: {m['enteros']}")
    self.lbl_metrica_flotantes.configure(
        text=f"Números flotantes: {m['flotantes']}"
    )
    self.lbl_metrica_ids.configure(
        text=f"Identificadores: {m['identificadores']}"
    )
    self.lbl_metrica_booleanos.configure(
        text=f"Valores booleanos: {m['booleanos']}"
    )
    self.lbl_metrica_operadores.configure(
        text=f"Operadores: {m['operadores']}"
    )

    texto_res = "\n".join(
        [f"{kw}: {cant}" for kw, cant in m["palabras_reservadas"].items()]
    )
    self.txt_reservadas.delete("1.0", "end")
    self.txt_reservadas.insert("1.0", texto_res)

  def _actualizar_reporte2(self, tabla):
    for item in self.tree_simbolos.get_children():
      self.tree_simbolos.delete(item)

    for fila in tabla:
      self.tree_simbolos.insert(
          "", "end", values=(fila["nombre"], fila["tipo"], fila["ambito"])
      )

  def guardar_en_mongodb(self):
    if not self.tabla_simbolos:
      messagebox.showwarning(
          "Atención",
          "No hay datos para guardar. Ejecuta 'Procesar Código' primero.",
      )
      return

    nombre_file = (
        os.path.basename(self.archivo_cargado_path)
        if self.archivo_cargado_path
        else "codigo_desconocido.rs"
    )

    exito, mensaje = guardar_reporte_mongo(
        nombre_file, self.metricas, self.tabla_simbolos
    )

    if exito:
      messagebox.showinfo(
          "MongoDB",
          f"¡Tabla de Símbolos guardada exitosamente!\nID de registro:"
          f" {mensaje}",
      )
    else:
      messagebox.showerror("Error MongoDB", f"Falló el guardado:\n{mensaje}")


if __name__ == "__main__":
  app = AnalizadorGUI()
  app.mainloop()