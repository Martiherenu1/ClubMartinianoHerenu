"""Configuración de la aplicación.

Lee las variables de entorno (desde el archivo .env en desarrollo) y las expone
como un objeto `settings` tipado. Cualquier parte del backend importa esto para
saber a qué base conectarse, dónde están las credenciales de Firebase, etc.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Conexión a la base de datos (formato SQLAlchemy).
    DATABASE_URL: str

    # Credenciales del Admin SDK de Firebase. Acepta dos formas:
    # - la ruta al archivo JSON (desarrollo local), o
    # - el contenido completo del JSON (Render, como variable de entorno secreta).
    FIREBASE_CREDENTIALS: str = ""

    # development | production
    ENVIRONMENT: str = "development"

    # Zona horaria del club. Render corre en UTC: sin esto, desde las 21 h la API
    # pensaría que ya es el día siguiente.
    ZONA_HORARIA: str = "America/Argentina/Buenos_Aires"

    # Lee automáticamente el archivo .env ubicado en la carpeta backend/.
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


# Instancia única que importa el resto de la app.
settings = Settings()
