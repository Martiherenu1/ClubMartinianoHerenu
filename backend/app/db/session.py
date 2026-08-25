"""Motor de conexión y sesiones de base de datos.

- `engine`: la conexión física a PostgreSQL (una por app).
- `SessionLocal`: fábrica de sesiones; cada request abre una y la cierra al terminar.
- `get_db`: dependencia de FastAPI que entrega una sesión a cada endpoint.
"""
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db() -> Generator[Session, None, None]:
    """Entrega una sesión de base de datos y garantiza su cierre."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
