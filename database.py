from datetime import datetime
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure

MONGO_URI = "mongodb+srv://javitoglk_db_user:OHKrEXgNjxIBqH9S@cluster0.klnwrqv.mongodb.net/?appName=Cluster0"
DB_NAME = "compiladores_db"
COLLECTION_NAME = "tabla_simbolos"


def guardar_reporte_mongo(nombre_archivo, metricas, tabla_simbolos):
  try:
    client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=3000)
    #Verificar conexión activa
    client.admin.command("ping")

    db = client[DB_NAME]
    coleccion = db[COLLECTION_NAME]

    documento = {
        "nombre_archivo": nombre_archivo,
        "fecha_analisis": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "metricas": metricas,
        "tabla_simbolos": tabla_simbolos,
    }

    resultado = coleccion.insert_one(documento)
    client.close()
    return True, str(resultado.inserted_id)

  except ConnectionFailure:
    return (
        False,
        "No se pudo conectar a MongoDB. Revisa si el servicio está activo.",
    )
  except Exception as e:
    return False, str(e)