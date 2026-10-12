"""Tareas programadas que dispara un cron externo (CU-24).

No las usa la app: las llama un workflow de GitHub Actions cada 15 minutos con la
clave secreta en el header `X-Tareas-Clave`.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import exigir_clave_de_tareas, get_db
from app.schemas.notificacion import ResumenRecordatoriosOut
from app.services import notificaciones

router = APIRouter(prefix="/tareas", tags=["tareas"])

_ERROR = {"description": "Error con formato `{error: {codigo, mensaje}}`"}


@router.post(
    "/recordatorios",
    response_model=ResumenRecordatoriosOut,
    summary="Enviar los recordatorios de reservas pendientes (CU-24)",
    dependencies=[Depends(exigir_clave_de_tareas)],
    responses={401: _ERROR},
)
def enviar_recordatorios(db: Session = Depends(get_db)):
    """Manda el push de 24 h y de 1 h antes a las reservas confirmadas que entraron
    en la ventana, y lo registra en `notificacion`.

    Se puede llamar las veces que haga falta: cada recordatorio se envía una sola
    vez por reserva. Requiere el header `X-Tareas-Clave`.
    """
    return notificaciones.enviar_recordatorios(db)
