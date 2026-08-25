"""Configuración de la aplicación.

Lee las variables de entorno (desde el archivo .env en desarrollo) y las expone
como un objeto `settings` tipado. Cualquier parte del backend importa esto para
saber a qué base conectarse, dónde están las credenciales de Firebase, etc.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Conexión a la base de datos (formato SQLAlchemy).
    DATABASE_URL: str

    # Ruta al JSON de credenciales del Admin SDK de Firebase (se usa en Auth).
    FIREBASE_CREDENTIALS: str = ""

    # development | production
    ENVIRONMENT: str = "development"

    # Lee automáticamente el archivo .env ubicado en la carpeta backend/.
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


# Instancia única que importa el resto de la app.
settings = Settings()
