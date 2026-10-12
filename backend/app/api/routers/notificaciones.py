"""Panel de notificaciones del usuario (CU-24): los avisos que ya recibió."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_usuario_actual
from app.models import Usuario
from app.schemas.notificacion import NotificacionOut
from app.services import notificaciones as servicio

router = APIRouter(prefix="/notificaciones", tags=["notificaciones"])

_ERROR = {"description": "Error con formato `{error: {codigo, mensaje}}`"}


@router.get(
    "",
    response_model=list[NotificacionOut],
    summary="Mis notificaciones (CU-24)",
    responses={401: _ERROR},
)
def listar_notificaciones(
    limite: int = Query(20, ge=1, le=50, description="Cantidad máxima de avisos"),
    usuario: Usuario = Depends(get_usuario_actual),
    db: Session = Depends(get_db),
):
    """Recordatorios y avisos de cancelación que le llegaron al usuario, del más
    nuevo al más viejo. Alimenta el panel de la campana de la Home."""
    return servicio.listar_avisos(db, usuario, limite)
