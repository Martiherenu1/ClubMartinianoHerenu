"""Reglas de negocio de reservas: crear (CU-09), listar (CU-08) y cancelar (CU-10).

Validaciones al crear, en este orden (las pide el TP):
1. La cancha existe y está activa.                          -> 404
2. Empieza y termina en horas completas, dura 1 o 2 horas.  -> 422 (esquema)
3. Queda dentro del horario de la sede.                     -> 400 HORARIO_FUERA_DE_SEDE
4. Es en el futuro.                                         -> 400 HORARIO_PASADO
5. No se superpone con otra reserva confirmada.             -> 409 HORARIO_OCUPADO

Concurrencia: si dos personas reservan el mismo turno al mismo tiempo, las dos
podrían ver el horario libre y guardar. Para evitarlo se bloquea la fila de la
cancha (`SELECT ... FOR UPDATE`) antes de verificar la superposición: la segunda
reserva espera a que la primera termine y recién ahí verifica, ya viendo la
reserva nueva, y recibe 409.
"""
from datetime import datetime
from decimal import Decimal

from fastapi import status
from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core import tiempo
from app.core.errores import ErrorAPI
from app.models import EspacioDeportivo, Reserva, Usuario
from app.schemas.reserva import ReservaIn, ReservaOut
from app.services.catalogo import espacio_out, obtener_espacio_activo
from app.services import notificaciones
from app.services.disponibilidad import sumar_horas, se_superponen


def _inicio_y_fin(reserva: Reserva) -> tuple[datetime, datetime]:
    return (
        datetime.combine(reserva.fecha, reserva.hora_inicio, tzinfo=tiempo.ZONA),
        datetime.combine(reserva.fecha, reserva.hora_fin, tzinfo=tiempo.ZONA),
    )


def estado_visible(reserva: Reserva, momento: datetime) -> str:
    """Estado para mostrar. "Completada" y "en curso" no se guardan: se deducen de la hora."""
    if reserva.estado == "cancelada":
        return "cancelada"
    inicio, fin = _inicio_y_fin(reserva)
    if momento >= fin:
        return "completada"
    if momento >= inicio:
        return "en_curso"
    return "confirmada"


def reserva_out(reserva: Reserva, momento: datetime) -> ReservaOut:
    estado = estado_visible(reserva, momento)
    duracion = reserva.hora_fin.hour - reserva.hora_inicio.hour
    return ReservaOut(
        id=reserva.id,
        espacio=espacio_out(reserva.espacio),
        fecha=reserva.fecha,
        hora_inicio=reserva.hora_inicio,
        hora_fin=reserva.hora_fin,
        duracion=duracion,
        precio_total=float(reserva.precio_total),
        estado=estado,
        cancelable=estado == "confirmada",
        creada_en=reserva.creada_en,
        cancelada_en=reserva.cancelada_en,
        recordatorios=notificaciones.recordatorios_de(reserva, momento),
    )


def crear(db: Session, usuario: Usuario, datos: ReservaIn) -> ReservaOut:
    """Registra una reserva confirmada (CU-09)."""
    espacio = obtener_espacio_activo(db, datos.espacio_id)
    sede = espacio.sede
    inicio = datos.hora_inicio
    fin = sumar_horas(inicio, datos.duracion)

    if fin <= inicio or inicio < sede.hora_apertura or fin > sede.hora_cierre:
        raise ErrorAPI(
            status.HTTP_400_BAD_REQUEST,
            "HORARIO_FUERA_DE_SEDE",
            f"La sede abre de {sede.hora_apertura:%H:%M} a {sede.hora_cierre:%H:%M}.",
        )

    momento = tiempo.ahora()
    if datetime.combine(datos.fecha, inicio, tzinfo=tiempo.ZONA) <= momento:
        raise ErrorAPI(
            status.HTTP_400_BAD_REQUEST,
            "HORARIO_PASADO",
            "Solo se pueden reservar horarios futuros.",
        )

    # Bloquea la cancha hasta el commit: las reservas simultáneas se atienden de a una.
    db.execute(
        select(EspacioDeportivo.id)
        .where(EspacioDeportivo.id == espacio.id)
        .with_for_update()
    )
    confirmadas = db.execute(
        select(Reserva.hora_inicio, Reserva.hora_fin).where(
            Reserva.espacio_id == espacio.id,
            Reserva.fecha == datos.fecha,
            Reserva.estado == "confirmada",
        )
    ).all()
    if any(se_superponen(inicio, fin, a, b) for a, b in confirmadas):
        raise ErrorAPI(
            status.HTTP_409_CONFLICT,
            "HORARIO_OCUPADO",
            "El horario seleccionado ya no está disponible. Elegí otro.",
        )

    reserva = Reserva(
        usuario_id=usuario.id,
        espacio_id=espacio.id,
        fecha=datos.fecha,
        hora_inicio=inicio,
        hora_fin=fin,
        precio_total=espacio.precio_hora * Decimal(datos.duracion),
        estado="confirmada",
    )
    db.add(reserva)
    db.commit()
    db.refresh(reserva)
    return reserva_out(reserva, momento)


def _consulta_del_usuario(usuario: Usuario):
    return (
        select(Reserva)
        .where(Reserva.usuario_id == usuario.id)
        .options(
            joinedload(Reserva.espacio).joinedload(EspacioDeportivo.sede),
            selectinload(Reserva.notificaciones),
        )
    )


def listar(db: Session, usuario: Usuario, vista: str) -> list[ReservaOut]:
    """Reservas del usuario (CU-08).

    - `proximas`: confirmadas que todavía no terminaron (incluye las en curso),
      de la más cercana a la más lejana.
    - `historial`: las que ya terminaron y las canceladas, de la más reciente a la
      más vieja.
    """
    momento = tiempo.ahora()
    hoy, hora = momento.date(), momento.time().replace(tzinfo=None)
    no_terminada = or_(
        Reserva.fecha > hoy, and_(Reserva.fecha == hoy, Reserva.hora_fin > hora)
    )
    consulta = _consulta_del_usuario(usuario)
    if vista == "proximas":
        consulta = consulta.where(Reserva.estado == "confirmada", no_terminada).order_by(
            Reserva.fecha, Reserva.hora_inicio
        )
    else:
        consulta = consulta.where(
            or_(Reserva.estado == "cancelada", ~no_terminada)
        ).order_by(Reserva.fecha.desc(), Reserva.hora_inicio.desc())
    return [reserva_out(r, momento) for r in db.scalars(consulta).unique()]


def _obtener_propia(db: Session, usuario: Usuario, reserva_id: int) -> Reserva:
    reserva = db.scalar(_consulta_del_usuario(usuario).where(Reserva.id == reserva_id))
    if reserva is None:
        # También si existe pero es de otro usuario: no se revela que existe.
        raise ErrorAPI(
            status.HTTP_404_NOT_FOUND,
            "RESERVA_NO_ENCONTRADA",
            "No encontramos esa reserva.",
        )
    return reserva


def obtener(db: Session, usuario: Usuario, reserva_id: int) -> ReservaOut:
    """Detalle de una reserva propia (destino de la notificación, CU-24)."""
    return reserva_out(_obtener_propia(db, usuario, reserva_id), tiempo.ahora())


def cancelar(db: Session, usuario: Usuario, reserva_id: int) -> ReservaOut:
    """Cancela una reserva propia que todavía no empezó (CU-10).

    No se borra: pasa a `cancelada`, el horario queda libre y la reserva sigue en
    el historial.
    """
    reserva = _obtener_propia(db, usuario, reserva_id)
    momento = tiempo.ahora()
    estado = estado_visible(reserva, momento)
    if estado != "confirmada":
        mensajes = {
            "cancelada": "La reserva ya estaba cancelada.",
            "en_curso": "No se puede cancelar una reserva que ya empezó.",
            "completada": "No se puede cancelar una reserva que ya terminó.",
        }
        raise ErrorAPI(
            status.HTTP_409_CONFLICT, "RESERVA_NO_CANCELABLE", mensajes[estado]
        )
    reserva.estado = "cancelada"
    reserva.cancelada_en = momento
    db.commit()
    db.refresh(reserva)
    # Aviso de cortesía: si falla no deshace la cancelación (CU-24.3).
    notificaciones.avisar_cancelacion(db, reserva)
    return reserva_out(reserva, momento)
