"""Endpoint de horarios disponibles (CU-12)."""
from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_usuario_actual
from app.schemas.disponibilidad import DisponibilidadOut
from app.services import disponibilidad as servicio

router = APIRouter(dependencies=[Depends(get_usuario_actual)], tags=["disponibilidad"])

_ERROR = {"description": "Error con formato `{error: {codigo, mensaje}}`"}


@router.get(
    "/espacios/{espacio_id}/disponibilidad",
    response_model=DisponibilidadOut,
    summary="Consultar horarios disponibles (CU-12)",
    responses={400: _ERROR, 401: _ERROR, 404: _ERROR, 422: _ERROR},
)
def consultar_disponibilidad(
    espacio_id: int,
    fecha: date = Query(description="Día a consultar (AAAA-MM-DD)", examples=["2026-10-15"]),
    duracion: int = Query(1, ge=1, le=2, description="Horas de la reserva: 1 o 2"),
    db: Session = Depends(get_db),
):
    """Grilla de franjas de la cancha para ese día y esa duración.

    Cada franja indica si está disponible y, si no, por qué (`ocupado` o `pasado`).
    Si `cantidad_disponibles` es 0, la app muestra "No hay horarios disponibles"
    (CU-12, FA4). Solo lectura: no reserva nada.
    """
    return servicio.consultar(db, espacio_id, fecha, duracion)
