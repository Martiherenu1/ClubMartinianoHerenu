"""Tabla `reserva`: un espacio deportivo + una fecha + hora de inicio y de fin.

Estados guardados:
- `confirmada`: reserva vigente (CU-09).
- `cancelada`: la canceló el usuario (CU-10); libera el horario.

"Completada" no se guarda: es una reserva confirmada cuyo horario ya terminó, y
se calcula al consultar (CU-08).
"""
from datetime import date, datetime, time
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Time,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.espacio_deportivo import EspacioDeportivo
    from app.models.notificacion import Notificacion
    from app.models.usuario import Usuario

ESTADOS_RESERVA = ("confirmada", "cancelada")


class Reserva(Base):
    __tablename__ = "reserva"
    __table_args__ = (
        CheckConstraint(
            f"estado IN {ESTADOS_RESERVA}", name="estado_valido"
        ),
        CheckConstraint("hora_fin > hora_inicio", name="fin_posterior_a_inicio"),
        # Horas completas: inicio y fin en el minuto 00 (requisito del TP).
        CheckConstraint(
            "EXTRACT(MINUTE FROM hora_inicio) = 0 AND EXTRACT(SECOND FROM hora_inicio) = 0"
            " AND EXTRACT(MINUTE FROM hora_fin) = 0 AND EXTRACT(SECOND FROM hora_fin) = 0",
            name="horas_completas",
        ),
        CheckConstraint("precio_total >= 0", name="precio_no_negativo"),
        # Acelera la búsqueda de superposiciones y el cálculo de disponibilidad (CU-12).
        Index("ix_reserva_espacio_fecha", "espacio_id", "fecha"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuario.id"), index=True)
    espacio_id: Mapped[int] = mapped_column(ForeignKey("espacio_deportivo.id"))
    fecha: Mapped[date] = mapped_column(Date)
    hora_inicio: Mapped[time] = mapped_column(Time)
    hora_fin: Mapped[time] = mapped_column(Time)
    # Foto del precio al reservar: si después cambia el precio, la reserva no se altera.
    precio_total: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    estado: Mapped[str] = mapped_column(
        String(15), default="confirmada", server_default="confirmada"
    )
    creada_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    cancelada_en: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    usuario: Mapped["Usuario"] = relationship(back_populates="reservas")
    espacio: Mapped["EspacioDeportivo"] = relationship(back_populates="reservas")
    notificaciones: Mapped[list["Notificacion"]] = relationship(
        back_populates="reserva"
    )

    def __repr__(self) -> str:
        return f"<Reserva {self.id} {self.fecha} {self.hora_inicio}-{self.hora_fin} {self.estado}>"
