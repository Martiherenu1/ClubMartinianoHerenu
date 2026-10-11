"""Esquemas de reservas (CU-08, CU-09, CU-10)."""
from datetime import date, datetime, time
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.schemas.catalogo import EspacioOut

EstadoVisible = Literal["confirmada", "en_curso", "completada", "cancelada"]


class ReservaIn(BaseModel):
    """Body de POST /reservas: la franja elegida en la pantalla de horarios (CU-12)."""

    espacio_id: int = Field(examples=[1])
    fecha: date = Field(examples=["2026-10-15"])
    hora_inicio: time = Field(examples=["18:00"])
    duracion: int = Field(1, ge=1, le=2, description="Horas: 1 o 2")

    @field_validator("hora_inicio")
    @classmethod
    def hora_completa(cls, valor: time) -> time:
        # Requisito del TP: las reservas empiezan y terminan en el minuto 00.
        if valor.minute or valor.second or valor.microsecond:
            raise ValueError("tiene que ser una hora completa (minuto 00)")
        return valor


class ReservaOut(BaseModel):
    """Tarjeta / detalle de una reserva."""

    id: int
    espacio: EspacioOut
    fecha: date
    hora_inicio: time
    hora_fin: time
    duracion: int
    precio_total: float
    # Estado para mostrar: además de lo guardado, distingue si ya empezó o terminó.
    estado: EstadoVisible
    # Si la app debe mostrar el botón "Cancelar reserva" (CU-10).
    cancelable: bool
    creada_en: datetime
    cancelada_en: datetime | None
