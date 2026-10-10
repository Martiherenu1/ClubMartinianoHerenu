"""Carga inicial del catálogo: sedes y espacios deportivos.

Reproduce el catálogo del Figma grupal: 4 sedes y 22 canchas (la pantalla
"Todas las sedes" muestra "4 sedes · 22 canchas disponibles"). Como la app no
tiene panel de administración, esta es la única forma de cargar sedes y canchas.

Es idempotente: se puede correr varias veces. Si una sede o cancha ya existe la
actualiza en lugar de duplicarla.

Ejecutar desde la carpeta backend/:
    python -m app.seed
"""
from dataclasses import dataclass
from datetime import time
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models import EspacioDeportivo, Sede
from app.services.nombres import generar_nombre_compuesto


@dataclass(frozen=True)
class Cancha:
    deporte: str
    tipo: str
    numero: int
    cubierto: bool
    iluminacion: bool
    precio_hora: int


@dataclass(frozen=True)
class SedeSeed:
    nombre: str
    direccion: str
    apertura: time
    cierre: time
    canchas: tuple[Cancha, ...]


# Fuente: capturas del Figma en las specs CU-08, CU-12 y CU-16.
# Valores vistos en el Figma: direcciones, cantidad de canchas por sede, horarios de
# Morón, Ramos Mejía y Castelar, Fútbol 5 de Morón (Cancha 1 outdoor, Cancha 2
# indoor, $3.800), Fútbol 11 de Ramos Mejía ($8.000), Tenis polvo de ladrillo
# de Morón ($2.500) y de Castelar ($2.700).
# El resto de los precios y el horario de San Justo son ESTIMADOS (marcados con *).
CATALOGO: tuple[SedeSeed, ...] = (
    SedeSeed(
        nombre="Morón",
        direccion="Av. Rivadavia 17500",
        apertura=time(8),
        cierre=time(23),
        canchas=(
            Cancha("Fútbol", "F5", 1, cubierto=False, iluminacion=True, precio_hora=3800),
            Cancha("Fútbol", "F5", 2, cubierto=True, iluminacion=True, precio_hora=3800),
            Cancha("Fútbol", "F7", 1, cubierto=False, iluminacion=True, precio_hora=5500),  # *
            Cancha("Fútbol", "F11", 1, cubierto=False, iluminacion=True, precio_hora=8000),  # *
            Cancha("Tenis", "Polvo de ladrillo", 1, cubierto=False, iluminacion=True, precio_hora=2500),
            Cancha("Tenis", "Polvo de ladrillo", 2, cubierto=False, iluminacion=True, precio_hora=2500),
            Cancha("Tenis", "Cemento", 1, cubierto=True, iluminacion=True, precio_hora=2500),  # *
        ),
    ),
    SedeSeed(
        nombre="Ramos Mejía",
        direccion="Calle Belgrano 1240",
        apertura=time(9),
        cierre=time(22),
        canchas=(
            Cancha("Fútbol", "F5", 1, cubierto=True, iluminacion=True, precio_hora=3800),  # *
            Cancha("Fútbol", "F11", 1, cubierto=False, iluminacion=True, precio_hora=8000),
            Cancha("Hockey", "H7", 1, cubierto=False, iluminacion=True, precio_hora=6000),  # *
            Cancha("Vóley", "Indoor parquet", 1, cubierto=True, iluminacion=True, precio_hora=3000),  # *
        ),
    ),
    SedeSeed(
        nombre="San Justo",
        direccion="Av. Casanova 320",
        apertura=time(8),  # *
        cierre=time(23),  # *
        canchas=(
            Cancha("Fútbol", "F5", 1, cubierto=False, iluminacion=True, precio_hora=3800),  # *
            Cancha("Fútbol", "F5", 2, cubierto=True, iluminacion=True, precio_hora=3800),  # *
            Cancha("Fútbol", "F8", 1, cubierto=False, iluminacion=True, precio_hora=4500),  # *
            Cancha("Tenis", "Sintético", 1, cubierto=False, iluminacion=True, precio_hora=2500),  # *
            Cancha("Golf", "Driving range", 1, cubierto=False, iluminacion=True, precio_hora=4000),  # *
            Cancha("Golf", "9 hoyos", 1, cubierto=False, iluminacion=False, precio_hora=9000),  # *
        ),
    ),
    SedeSeed(
        nombre="Castelar",
        direccion="Av. Rivadavia 22500",
        apertura=time(8),
        cierre=time(23),
        canchas=(
            Cancha("Tenis", "Polvo de ladrillo", 1, cubierto=False, iluminacion=True, precio_hora=2700),
            Cancha("Tenis", "Cemento", 1, cubierto=False, iluminacion=True, precio_hora=2700),  # *
            Cancha("Vóley", "Playa", 1, cubierto=False, iluminacion=True, precio_hora=3000),  # *
            Cancha("Vóley", "Indoor parquet", 1, cubierto=True, iluminacion=True, precio_hora=3000),  # *
            Cancha("Hockey", "H11", 1, cubierto=False, iluminacion=True, precio_hora=7000),  # *
        ),
    ),
)


def cargar_catalogo(db: Session) -> tuple[int, int]:
    """Crea o actualiza las sedes y canchas del catálogo.

    Devuelve (cantidad de sedes, cantidad de canchas) cargadas.
    """
    total_canchas = 0
    for datos in CATALOGO:
        sede = db.scalar(select(Sede).where(Sede.nombre == datos.nombre))
        if sede is None:
            sede = Sede(nombre=datos.nombre)
            db.add(sede)
        sede.direccion = datos.direccion
        sede.hora_apertura = datos.apertura
        sede.hora_cierre = datos.cierre
        sede.activa = True
        db.flush()  # asegura sede.id para las canchas nuevas

        for c in datos.canchas:
            espacio = db.scalar(
                select(EspacioDeportivo).where(
                    EspacioDeportivo.sede_id == sede.id,
                    EspacioDeportivo.deporte == c.deporte,
                    EspacioDeportivo.tipo == c.tipo,
                    EspacioDeportivo.numero == c.numero,
                )
            )
            if espacio is None:
                espacio = EspacioDeportivo(
                    sede_id=sede.id, deporte=c.deporte, tipo=c.tipo, numero=c.numero
                )
                db.add(espacio)
            espacio.nombre_compuesto = generar_nombre_compuesto(
                sede.nombre, sede.direccion, c.deporte, c.tipo, c.numero
            )
            espacio.cubierto = c.cubierto
            espacio.iluminacion = c.iluminacion
            espacio.precio_hora = Decimal(c.precio_hora)
            espacio.activo = True
            total_canchas += 1

    db.commit()
    return len(CATALOGO), total_canchas


def main() -> None:
    with SessionLocal() as db:
        sedes, canchas = cargar_catalogo(db)
    print(f"Catálogo cargado: {sedes} sedes y {canchas} canchas.")


if __name__ == "__main__":
    main()
