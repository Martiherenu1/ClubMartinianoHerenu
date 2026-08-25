"""Base declarativa de SQLAlchemy.

Todos los modelos (tablas) heredan de `Base`. Alembic también la usa para
detectar el esquema y generar migraciones.
"""
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
