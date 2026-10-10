"""Tabla `espacio_deportivo`: cada cancha reservable de una sede.

`deporte` + `tipo` reproducen el catálogo del Figma (ej. Fútbol / F5, Tenis /
Polvo de ladrillo). `numero` distingue "Cancha 1" de "Cancha 2" del mismo tipo.
"""
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.reserva import Reserva
    from app.models.sede import Sede


class EspacioDeportivo(Base):
    __tablename__ = "espacio_deportivo"
    __table_args__ = (
        # No puede haber dos "Fútbol F5 Cancha 1" en la misma sede.
        UniqueConstraint(
            "sede_id", "deporte", "tipo", "numero", name="uq_espacio_por_sede"
        ),
        CheckConstraint("numero >= 1", name="numero_positivo"),
        CheckConstraint("precio_hora > 0", name="precio_positivo"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    sede_id: Mapped[int] = mapped_column(ForeignKey("sede.id"), index=True)
    deporte: Mapped[str] = mapped_column(String(30))
    tipo: Mapped[str] = mapped_column(String(40))
    numero: Mapped[int] = mapped_column(Integer)
    # Formato del TP: Sede_Direccion_Deporte_Tipo_Numero (ej. Moron_Rivadavia_19850_Futbol_F5_1).
    nombre_compuesto: Mapped[str] = mapped_column(String(150), unique=True)
    cubierto: Mapped[bool] = mapped_column(Boolean)  # indoor / outdoor
    iluminacion: Mapped[bool] = mapped_column(Boolean)
    # Precio informativo: se muestra en la app, no hay pagos.
    precio_hora: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    activo: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")

    sede: Mapped["Sede"] = relationship(back_populates="espacios")
    reservas: Mapped[list["Reserva"]] = relationship(back_populates="espacio")

    def __repr__(self) -> str:
        return f"<EspacioDeportivo {self.id} {self.nombre_compuesto}>"
