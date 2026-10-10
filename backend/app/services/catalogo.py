"""Consultas del catálogo: sedes, espacios deportivos y deportes.

Solo se muestran sedes activas y canchas activas de sedes activas: lo que el
usuario puede efectivamente reservar.
"""
import re
from collections import defaultdict

from fastapi import status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.errores import ErrorAPI
from app.models import EspacioDeportivo, Sede
from app.schemas.catalogo import DeporteOut, EspacioOut, SedeOut, SedeResumen


def _espacios_activos():
    return (
        select(EspacioDeportivo)
        .join(EspacioDeportivo.sede)
        .where(EspacioDeportivo.activo.is_(True), Sede.activa.is_(True))
        .options(joinedload(EspacioDeportivo.sede))
    )


def _orden_natural(texto: str) -> list:
    """Clave para ordenar 'F5' < 'F7' < 'F11' (como texto quedaría 'F11' < 'F5')."""
    return [int(p) if p.isdigit() else p.lower() for p in re.split(r"(\d+)", texto)]


def _ordenar(espacios) -> list[EspacioDeportivo]:
    """Orden de las tarjetas: sede, deporte, tipo (natural) y número de cancha."""
    return sorted(
        espacios,
        key=lambda e: (e.sede_id, e.deporte, _orden_natural(e.tipo), e.numero),
    )


def _agrupar_deportes(espacios: list[EspacioDeportivo]) -> list[DeporteOut]:
    """Lista de deportes con sus tipos, en orden de aparición y sin repetir."""
    tipos: dict[str, list[str]] = defaultdict(list)
    for e in espacios:
        if e.tipo not in tipos[e.deporte]:
            tipos[e.deporte].append(e.tipo)
    return [
        DeporteOut(deporte=d, tipos=sorted(t, key=_orden_natural))
        for d, t in tipos.items()
    ]


def _sede_out(sede: Sede, espacios: list[EspacioDeportivo]) -> SedeOut:
    return SedeOut(
        id=sede.id,
        nombre=sede.nombre,
        direccion=sede.direccion,
        hora_apertura=sede.hora_apertura,
        hora_cierre=sede.hora_cierre,
        imagen_url=sede.imagen_url,
        cantidad_canchas=len(espacios),
        deportes=_agrupar_deportes(espacios),
    )


def espacio_out(e: EspacioDeportivo) -> EspacioOut:
    return EspacioOut(
        id=e.id,
        sede=SedeResumen(id=e.sede.id, nombre=e.sede.nombre, direccion=e.sede.direccion),
        deporte=e.deporte,
        tipo=e.tipo,
        numero=e.numero,
        nombre_compuesto=e.nombre_compuesto,
        cubierto=e.cubierto,
        iluminacion=e.iluminacion,
        precio_hora=float(e.precio_hora),
        hora_apertura=e.sede.hora_apertura,
        hora_cierre=e.sede.hora_cierre,
    )


def listar_sedes(db: Session, deporte: str | None = None) -> list[SedeOut]:
    """Todas las sedes activas (CU-16). Con `deporte`, solo las que lo ofrecen (Home)."""
    por_sede: dict[int, list[EspacioDeportivo]] = defaultdict(list)
    for e in _ordenar(db.scalars(_espacios_activos()).unique()):
        por_sede[e.sede_id].append(e)

    sedes = db.scalars(select(Sede).where(Sede.activa.is_(True)).order_by(Sede.id)).all()
    resultado = [_sede_out(s, por_sede[s.id]) for s in sedes]
    if deporte:
        resultado = [s for s in resultado if any(d.deporte == deporte for d in s.deportes)]
    return resultado


def obtener_sede(db: Session, sede_id: int) -> SedeOut:
    sede = db.get(Sede, sede_id)
    if sede is None or not sede.activa:
        raise ErrorAPI(
            status.HTTP_404_NOT_FOUND, "SEDE_NO_ENCONTRADA", "La sede no existe."
        )
    espacios = db.scalars(
        _espacios_activos().where(EspacioDeportivo.sede_id == sede_id)
    ).unique()
    return _sede_out(sede, _ordenar(espacios))


def listar_espacios(
    db: Session,
    sede_id: int | None = None,
    deporte: str | None = None,
    tipo: str | None = None,
) -> list[EspacioOut]:
    """Canchas activas, filtrables por sede, deporte y tipo (CU-13, CU-16, CU-20)."""
    consulta = _espacios_activos()
    if sede_id is not None:
        consulta = consulta.where(EspacioDeportivo.sede_id == sede_id)
    if deporte:
        consulta = consulta.where(EspacioDeportivo.deporte == deporte)
    if tipo:
        consulta = consulta.where(EspacioDeportivo.tipo == tipo)
    return [espacio_out(e) for e in _ordenar(db.scalars(consulta).unique())]


def obtener_espacio_activo(db: Session, espacio_id: int) -> EspacioDeportivo:
    """Devuelve la cancha si existe y se puede reservar; si no, 404."""
    espacio = db.scalar(_espacios_activos().where(EspacioDeportivo.id == espacio_id))
    if espacio is None:
        raise ErrorAPI(
            status.HTTP_404_NOT_FOUND,
            "ESPACIO_NO_ENCONTRADO",
            "La cancha no existe o no está disponible.",
        )
    return espacio


def listar_deportes(db: Session) -> list[DeporteOut]:
    """Deportes y tipos que existen en el club, para los filtros de la Home y de sedes."""
    return _agrupar_deportes(_ordenar(db.scalars(_espacios_activos()).unique()))
