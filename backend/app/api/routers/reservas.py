"""Endpoints de reservas del usuario autenticado (CU-08, CU-09, CU-10)."""
from typing import Literal

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_usuario_actual
from app.models import Usuario
from app.schemas.reserva import ReservaIn, ReservaOut
from app.services import reservas as servicio

router = APIRouter(prefix="/reservas", tags=["reservas"])

_ERROR = {"description": "Error con formato `{error: {codigo, mensaje}}`"}


@router.post(
    "",
    response_model=ReservaOut,
    status_code=status.HTTP_201_CREATED,
    summary="Reservar una cancha (CU-09)",
    responses={400: _ERROR, 401: _ERROR, 404: _ERROR, 409: _ERROR, 422: _ERROR},
)
def crear_reserva(
    datos: ReservaIn,
    usuario: Usuario = Depends(get_usuario_actual),
    db: Session = Depends(get_db),
):
    """Reserva la franja elegida en la pantalla de horarios.

    Valida horario de la sede, que sea futura y que no se superponga con otra
    reserva confirmada. Si alguien la tomó antes: 409 `HORARIO_OCUPADO`.
    """
    return servicio.crear(db, usuario, datos)


@router.get(
    "",
    response_model=list[ReservaOut],
    summary="Mis reservas: próximas o historial (CU-08)",
    responses={401: _ERROR},
)
def listar_reservas(
    vista: Literal["proximas", "historial"] = Query(
        "proximas", description="`proximas` o `historial`"
    ),
    usuario: Usuario = Depends(get_usuario_actual),
    db: Session = Depends(get_db),
):
    return servicio.listar(db, usuario, vista)


@router.get(
    "/{reserva_id}",
    response_model=ReservaOut,
    summary="Detalle de una reserva",
    responses={401: _ERROR, 404: _ERROR},
)
def ver_reserva(
    reserva_id: int,
    usuario: Usuario = Depends(get_usuario_actual),
    db: Session = Depends(get_db),
):
    return servicio.obtener(db, usuario, reserva_id)


@router.delete(
    "/{reserva_id}",
    response_model=ReservaOut,
    summary="Cancelar una reserva (CU-10)",
    responses={401: _ERROR, 404: _ERROR, 409: _ERROR},
)
def cancelar_reserva(
    reserva_id: int,
    usuario: Usuario = Depends(get_usuario_actual),
    db: Session = Depends(get_db),
):
    """La reserva pasa a `cancelada` (no se borra) y el horario queda libre.

    409 `RESERVA_NO_CANCELABLE` si ya empezó, terminó o estaba cancelada.
    """
    return servicio.cancelar(db, usuario, reserva_id)
