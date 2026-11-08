"""Configuración de la aplicación.

Lee las variables de entorno (desde el archivo .env en desarrollo) y las expone
como un objeto `settings` tipado. Cualquier parte del backend importa esto para
saber a qué base conectarse, dónde están las credenciales de Firebase, etc.
"""
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def normalizar_url_de_base(url: str) -> str:
    """Deja la URL de PostgreSQL en el formato que entiende SQLAlchemy 2.

    Render entrega la conexión como `postgres://...` o `postgresql://...`.
    SQLAlchemy 2 rechaza el primero y, con el segundo, elige el driver solo; acá
    se indica `psycopg2` (el que está instalado) para que no haya ambigüedad.
    """
    url = url.strip()
    for prefijo in ("postgres://", "postgresql://"):
        if url.startswith(prefijo):
            return "postgresql+psycopg2://" + url[len(prefijo):]
    return url


class Settings(BaseSettings):
    # Conexión a la base de datos (formato SQLAlchemy).
    DATABASE_URL: str

    # Credenciales del Admin SDK de Firebase. Acepta dos formas:
    # - la ruta al archivo JSON (desarrollo local), o
    # - el contenido completo del JSON (Render, como variable de entorno secreta).
    FIREBASE_CREDENTIALS: str = ""

    # Clave que tiene que mandar quien dispara las tareas programadas (el cron de
    # GitHub Actions llama a POST /tareas/recordatorios). Vacía = el endpoint
    # rechaza todo, así nadie puede dispararlo hasta que se configure.
    TAREAS_CLAVE: str = ""

    # development | production
    ENVIRONMENT: str = "development"

    # Zona horaria del club. Render corre en UTC: sin esto, desde las 21 h la API
    # pensaría que ya es el día siguiente.
    ZONA_HORARIA: str = "America/Argentina/Buenos_Aires"

    # Lee automáticamente el archivo .env ubicado en la carpeta backend/.
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @field_validator("DATABASE_URL")
    @classmethod
    def _url_de_base(cls, valor: str) -> str:
        return normalizar_url_de_base(valor)


# Instancia única que importa el resto de la app.
settings = Settings()
