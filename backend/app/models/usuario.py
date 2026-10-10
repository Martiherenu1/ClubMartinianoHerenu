"""Tabla `usuario`: perfil de cada persona registrada.

La contraseña NO se guarda acá: la administra Firebase Authentication. Esta tabla
guarda los datos de perfil y el `firebase_uid`, que es lo que llega dentro del
token en cada request y permite saber quién es el usuario.
"""
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, Date, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.dispositivo import Dispositivo
    from app.models.reserva import Reserva


class Usuario(Base):
    __tablename__ = "usuario"

    id: Mapped[int] = mapped_column(primary_key=True)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    # El email no se puede editar (requisito del TP); viene de Firebase.
    email: Mapped[str] = mapped_column(String(255), unique=True)
    nombre: Mapped[str] = mapped_column(String(80))
    apellido: Mapped[str] = mapped_column(String(80))
    # Único: el CU-03 rechaza el registro si el DNI ya existe.
    dni: Mapped[str] = mapped_column(String(15), unique=True)
    fecha_nacimiento: Mapped[date] = mapped_column(Date)
    # False = cuenta dada de baja (CU-07). No se borra la fila para conservar el historial.
    activo: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    creado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    reservas: Mapped[list["Reserva"]] = relationship(back_populates="usuario")
    dispositivos: Mapped[list["Dispositivo"]] = relationship(
        back_populates="usuario", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Usuario {self.id} {self.email}>"
