"""Esquemas de las tareas programadas de notificaciones (CU-24)."""
from pydantic import BaseModel, Field


class ResumenRecordatoriosOut(BaseModel):
    """Qué hizo una corrida de recordatorios."""

    revisadas: int = Field(description="Reservas que estaban en una ventana de aviso")
    enviadas: int = Field(description="Avisos que llegaron a algún celular")
    sin_dispositivo: int = Field(
        description="Avisos pendientes porque el usuario no tiene celular registrado"
    )
    errores: int = Field(description="Avisos que Firebase no pudo entregar")
