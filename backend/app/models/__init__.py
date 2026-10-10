"""Modelos (tablas) de la base de datos.

Se importan todos acá para que `Base.metadata` los conozca: Alembic lo necesita
para generar las migraciones, y SQLAlchemy para resolver las relaciones.
"""
from app.models.dispositivo import Dispositivo
from app.models.espacio_deportivo import EspacioDeportivo
from app.models.notificacion import Notificacion
from app.models.reserva import Reserva
from app.models.sede import Sede
from app.models.usuario import Usuario

__all__ = [
    "Dispositivo",
    "EspacioDeportivo",
    "Notificacion",
    "Reserva",
    "Sede",
    "Usuario",
]
