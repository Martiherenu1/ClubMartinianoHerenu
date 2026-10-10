"""Esquemas del catálogo: sedes, espacios deportivos y deportes."""
from datetime import time

from pydantic import BaseModel


class DeporteOut(BaseModel):
    """Un deporte con sus tipos, para los chips de filtro (CU-20)."""

    deporte: str
    tipos: list[str]


class SedeResumen(BaseModel):
    """Datos de la sede que acompañan a cada cancha."""

    id: int
    nombre: str
    direccion: str


class SedeOut(BaseModel):
    """Tarjeta de sede (CU-16): nombre, dirección, horario, canchas y deportes."""

    id: int
    nombre: str
    direccion: str
    hora_apertura: time
    hora_cierre: time
    imagen_url: str | None
    cantidad_canchas: int
    deportes: list[DeporteOut]


class EspacioOut(BaseModel):
    """Tarjeta de cancha (CU-16): tipo, nombre compuesto, condición, horario y precio."""

    id: int
    sede: SedeResumen
    deporte: str
    tipo: str
    numero: int
    nombre_compuesto: str
    cubierto: bool
    iluminacion: bool
    precio_hora: float
    # Franja en la que se puede reservar: la del horario de la sede.
    hora_apertura: time
    hora_cierre: time
