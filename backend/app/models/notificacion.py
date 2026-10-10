"""Tabla `notificacion`: registro de cada aviso push enviado por una reserva.

La combinación (reserva, tipo) es única, así el mismo recordatorio nunca se
manda dos veces aunque el proceso que los dispara corra varias veces (CU-24).
"""
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.reserva import Reserva

TIPOS_NOTIFICACION = ("recordatorio_24h", "recordatorio_1h", "cancelacion")
RESULTADOS_NOTIFICACION = ("enviada", "no_enviada", "error")


class Notificacion(Base):
    __tablename__ = "notificacion"
    __table_args__ = (
        UniqueConstraint("reserva_id", "tipo", name="uq_notificacion_reserva_tipo"),
        CheckConstraint(f"tipo IN {TIPOS_NOTIFICACION}", name="tipo_valido"),
        CheckConstraint(
            f"resultado IN {RESULTADOS_NOTIFICACION}", name="resultado_valido"
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    reserva_id: Mapped[int] = mapped_column(ForeignKey("reserva.id"), index=True)
    tipo: Mapped[str] = mapped_column(String(30))
    enviada_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    resultado: Mapped[str] = mapped_column(String(20))

    reserva: Mapped["Reserva"] = relationship(back_populates="notificaciones")

    def __repr__(self) -> str:
        return f"<Notificacion {self.id} reserva={self.reserva_id} {self.tipo} {self.resultado}>"
