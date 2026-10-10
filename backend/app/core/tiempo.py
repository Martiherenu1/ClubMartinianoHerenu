"""Fecha y hora "de ahora" en la zona horaria del club.

Todo lo que dependa de "hoy", "futuro" o "pasado" (reservas, horarios
disponibles, recordatorios) tiene que usar `ahora()`, nunca `datetime.now()`
suelto, porque el servidor de Render corre en UTC.
"""
from datetime import datetime
from zoneinfo import ZoneInfo

from app.core.config import settings

ZONA = ZoneInfo(settings.ZONA_HORARIA)


def ahora() -> datetime:
    """Fecha y hora actuales en Argentina (con zona horaria)."""
    return datetime.now(ZONA)
