"""Esquemas de notificaciones (CU-24): tareas programadas, panel y recordatorios."""
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class RecordatorioOut(BaseModel):
    """Un recordatorio de una reserva, para el bloque "Recordatorios" del detalle."""

    tipo: Literal["24h", "1h"]
    programado_para: datetime = Field(description="Cuándo corresponde enviarlo")
    estado: Literal["pendiente", "enviado", "no_enviado"]


class NotificacionOut(BaseModel):
    """Un aviso que recibió el usuario (panel de notificaciones de la app)."""

    id: int
    tipo: Literal["recordatorio_24h", "recordatorio_1h", "cancelacion"]
    titulo: str
    cuerpo: str
    reserva_id: int
    enviada_en: datetime


class ResumenRecordatoriosOut(BaseModel):
    """Qué hizo una corrida de recordatorios."""

    revisadas: int = Field(description="Reservas que estaban en una ventana de aviso")
    enviadas: int = Field(description="Avisos que llegaron a algún celular")
    sin_dispositivo: int = Field(
        description="Avisos pendientes porque el usuario no tiene celular registrado"
    )
    errores: int = Field(description="Avisos que Firebase no pudo entregar")
