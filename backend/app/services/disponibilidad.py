"""Cálculo de horarios disponibles de una cancha (CU-12, "Consultar horarios disponibles").

La disponibilidad NO se guarda en la base: se calcula en cada consulta a partir de
tres datos:

1. El horario de la sede (ej. 08:00 a 23:00).
2. La duración elegida por el usuario (1 o 2 horas).
3. Las reservas confirmadas de esa cancha en esa fecha.

Algoritmo:
- Se arman franjas de hora en hora: 08–09, 09–10, … (con 2 h: 08–10, 09–11, …).
  La última franja es la que termina justo al cierre (el TP no permite pasarse).
- Una franja NO está disponible si:
  * se superpone con una reserva confirmada  -> motivo "ocupado";
  * es de hoy y ya empezó                     -> motivo "pasado".
- Dos rangos [a, b) y [c, d) se superponen cuando a < d y c < b.

Las reservas canceladas no cuentan: cancelar libera el horario (CU-10).
"""
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

from fastapi import status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core import tiempo
from app.core.errores import ErrorAPI
from app.models import Reserva
from app.schemas.disponibilidad import DisponibilidadOut, FranjaOut
from app.services.catalogo import espacio_out, obtener_espacio_activo


@dataclass(frozen=True)
class Franja:
    inicio: time
    fin: time
    disponible: bool
    motivo: str | None  # None | "ocupado" | "pasado"


def _sumar_horas(hora: time, horas: int) -> time:
    return (datetime.combine(date.min, hora) + timedelta(hours=horas)).time()


def se_superponen(inicio_a: time, fin_a: time, inicio_b: time, fin_b: time) -> bool:
    """¿Los rangos [inicio_a, fin_a) y [inicio_b, fin_b) comparten algún momento?

    >>> se_superponen(time(18), time(19), time(18), time(20))
    True
    >>> se_superponen(time(18), time(19), time(19), time(20))  # se tocan, no se pisan
    False
    """
    return inicio_a < fin_b and inicio_b < fin_a


def calcular_franjas(
    apertura: time,
    cierre: time,
    duracion: int,
    ocupadas: list[tuple[time, time]],
    fecha: date,
    momento: datetime,
) -> list[Franja]:
    """Arma la grilla de franjas de un día y marca cuáles se pueden reservar.

    Es una función pura (no toca la base ni el reloj): todo llega por parámetro.
    """
    franjas: list[Franja] = []
    inicio = apertura
    while True:
        fin = _sumar_horas(inicio, duracion)
        # Si se pasa del cierre (o "da la vuelta" a la medianoche) no hay más franjas.
        if fin > cierre or fin <= inicio:
            break
        if fecha == momento.date() and inicio <= momento.time().replace(tzinfo=None):
            motivo = "pasado"
        elif any(se_superponen(inicio, fin, a, b) for a, b in ocupadas):
            motivo = "ocupado"
        else:
            motivo = None
        franjas.append(Franja(inicio, fin, motivo is None, motivo))
        inicio = _sumar_horas(inicio, 1)
    return franjas


def consultar(db: Session, espacio_id: int, fecha: date, duracion: int) -> DisponibilidadOut:
    """Disponibilidad de una cancha para una fecha y una duración (CU-12)."""
    espacio = obtener_espacio_activo(db, espacio_id)  # 404 si no existe o está inactiva
    momento = tiempo.ahora()
    if fecha < momento.date():
        raise ErrorAPI(
            status.HTTP_400_BAD_REQUEST,
            "FECHA_PASADA",
            "No se pueden consultar horarios de días que ya pasaron.",
        )

    ocupadas = db.execute(
        select(Reserva.hora_inicio, Reserva.hora_fin).where(
            Reserva.espacio_id == espacio.id,
            Reserva.fecha == fecha,
            Reserva.estado == "confirmada",
        )
    ).all()

    franjas = calcular_franjas(
        espacio.sede.hora_apertura,
        espacio.sede.hora_cierre,
        duracion,
        [(r.hora_inicio, r.hora_fin) for r in ocupadas],
        fecha,
        momento,
    )
    disponibles = sum(f.disponible for f in franjas)
    precio_hora = float(espacio.precio_hora)
    return DisponibilidadOut(
        espacio=espacio_out(espacio),
        fecha=fecha,
        duracion=duracion,
        precio_hora=precio_hora,
        precio_total=precio_hora * duracion,
        cantidad_disponibles=disponibles,
        cantidad_no_disponibles=len(franjas) - disponibles,
        franjas=[
            FranjaOut(hora_inicio=f.inicio, hora_fin=f.fin, disponible=f.disponible, motivo=f.motivo)
            for f in franjas
        ],
    )
