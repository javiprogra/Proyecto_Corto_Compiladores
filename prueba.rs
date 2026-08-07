// ==========================================
// Archivo de prueba en Rust para Analizador Léxico
// Universidad Mesoamericana - Compiladores
// ==========================================

use std::fmt;

/*
 * Estructura principal de datos para simular
 * una cuenta de usuario y sus estadísticas.
 */
#[derive(Debug)]
pub struct Usuario {
    pub id: u32,
    pub nombre: String,
    pub activo: bool,
    pub saldo: f64,
    pub intentos_login: i32,
}

pub enum Rol {
    Admin,
    Cliente,
    Invitado,
}

const LIMITE_INTENTOS: i32 = 3;
const IMPUESTO_BASE: f64 = 0.12;

impl Usuario {
    pub fn nuevo(id: u32, nombre: &str, saldo_inicial: f64) -> Self {
        Usuario {
            id,
            nombre: nombre.to_string(),
            activo: true,
            saldo: saldo_inicial,
            intentos_login: 0,
        }
    }

    pub fn aplicar_descuento(&mut self, porcentaje: f64) -> f64 {
        if porcentaje > 0.0 && porcentaje <= 100.0 {
            let descuento = self.saldo * (porcentaje / 100.0);
            self.saldo = self.saldo - descuento;
            return self.saldo;
        } else {
            println!("Porcentaje no valido!");
            return 0.0;
        }
    }

    pub fn verificar_estado(&mut self) -> bool {
        if self.intentos_login >= LIMITE_INTENTOS {
            self.activo = false;
            println!("Cuenta bloqueada debido a intentos fallidos.");
        }
        return self.activo;
    }
}

pub fn calcular_total(precios: &[f64], aplicar_impuesto: bool) -> f64 {
    let mut total = 0.0;
    for precio in precios {
        if *precio > 0.0 {
            total = total + *precio;
        }
    }

    if aplicar_impuesto {
        let impuesto = total * IMPUESTO_BASE;
        total = total + impuesto;
    }

    return total;
}

fn main() {
    println!("=== Inicio de Pruebas de Analisis Lexico ===");

    let mut usuario1 = Usuario::nuevo(101, "Carlos Gomez", 250.75);
    let mut contador = 0;

    while contador < 5 {
        contador = contador + 1;
        if contador == 3 {
            println!("Contador alcanzo el valor de 3");
        }
    }

    let precios_compra = [12.50, 45.00, 89.99, 150.25];
    let total_compra = calcular_total(&precios_compra, true);

    println!("Total calculado con impuesto: {}", total_compra);

    let nuevo_saldo = usuario1.aplicar_descuento(15.0);
    println!("Nuevo saldo con descuento: {}", nuevo_saldo);

    let es_valido = usuario1.verificar_estado();

    if es_valido && usuario1.saldo >= 100.0 {
        println!("El usuario esta activo y tiene fondos suficientes.");
    } else if !es_valido || usuario1.saldo < 100.0 {
        println!("Atencion: Revisar estado o saldo del usuario.");
    }

    let mensaje_raw = r#"Ruta de configuracion: C:\Archivos\config.json"#;
    println!("Mensaje en raw string: {}", mensaje_raw);

    let rol_actual = Rol::Admin;
    match rol_actual {
        Rol::Admin => println!("Acceso total concedido."),
        Rol::Cliente => println!("Acceso limitado a compras."),
        Rol::Invitado => println!("Acceso solo lectura."),
    }

    println!("=== Fin de las pruebas ===");
}