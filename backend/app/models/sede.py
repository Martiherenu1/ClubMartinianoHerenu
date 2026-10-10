"""Tabla `sede`: cada club físico (Morón, Ramos Mejía, San Justo, Castelar).

El horario de funcionamiento es único para todos los días, igual que en los
formularios de sede del Figma. Las reservas tienen que quedar dentro de él.
"""
from datetime import time
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, String, Time
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.espacio_deportivo import EspacioDeportivo


class Sede(Base):
    __tablename__ = "sede"
    __table_args__ = (
        CheckConstraint("hora_cierre > hora_apertura", name="horario_valido"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(80), unique=True)
    direccion: Mapped[str] = mapped_column(String(150))
    hora_apertura: Mapped[time] = mapped_column(Time)
    hora_cierre: Mapped[time] = mapped_column(Time)
    imagen_url: Mapped[str | None] = mapped_column(String(500))
    activa: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")

    espacios: Mapped[list["EspacioDeportivo"]] = relationship(back_populates="sede")

    def __repr__(self) -> str:
        return f"<Sede {self.id} {self.nombre}>"
