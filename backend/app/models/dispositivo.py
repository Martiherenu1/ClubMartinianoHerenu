"""Tabla `dispositivo`: token de notificaciones push (FCM) de cada celular.

La app lo registra al iniciar sesión y lo borra al cerrar sesión (CU-02). El
backend lo usa para mandar los recordatorios de reservas (CU-24).
"""
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.usuario import Usuario


class Dispositivo(Base):
    __tablename__ = "dispositivo"

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int] = mapped_column(
        ForeignKey("usuario.id", ondelete="CASCADE"), index=True
    )
    fcm_token: Mapped[str] = mapped_column(String(512), unique=True)
    plataforma: Mapped[str] = mapped_column(
        String(20), default="android", server_default="android"
    )
    actualizado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    usuario: Mapped["Usuario"] = relationship(back_populates="dispositivos")

    def __repr__(self) -> str:
        return f"<Dispositivo {self.id} usuario={self.usuario_id}>"
