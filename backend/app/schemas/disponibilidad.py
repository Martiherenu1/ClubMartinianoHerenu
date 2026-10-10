"""Esquemas de la consulta de horarios disponibles (CU-12)."""
from datetime import date, time
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.catalogo import EspacioOut


class FranjaOut(BaseModel):
    """Un botón de la grilla de horarios."""

    hora_inicio: time
    hora_fin: time
    disponible: bool
    motivo: Literal["ocupado", "pasado"] | None = Field(
        description="Por qué no se puede reservar (null si está disponible)"
    )


class DisponibilidadOut(BaseModel):
    """Pantalla de horarios: cancha, fecha, duración, resumen de precio y grilla."""

    espacio: EspacioOut
    fecha: date
    duracion: int
    precio_hora: float
    # Lo que muestra el resumen del Figma: "$ 3.800 × 1 … Total $ 3.800".
    precio_total: float
    cantidad_disponibles: int
    # Para la nota "Algunos horarios están ocupados · N no disponibles".
    cantidad_no_disponibles: int
    franjas: list[FranjaOut]
