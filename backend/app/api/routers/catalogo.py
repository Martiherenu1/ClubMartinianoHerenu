"""Endpoints del catálogo: sedes, espacios deportivos y deportes (solo lectura)."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_usuario_actual
from app.schemas.catalogo import DeporteOut, EspacioOut, SedeOut
from app.services import catalogo as servicio

# Todo el catálogo requiere sesión iniciada, como en el prototipo (CU-16).
router = APIRouter(dependencies=[Depends(get_usuario_actual)])

_ERROR = {"description": "Error con formato `{error: {codigo, mensaje}}`"}


@router.get(
    "/sedes",
    response_model=list[SedeOut],
    tags=["sedes"],
    summary="Listar sedes (CU-16)",
    responses={401: _ERROR},
)
def listar_sedes(
    deporte: str | None = Query(None, description="Solo sedes que ofrecen este deporte", examples=["Fútbol"]),
    db: Session = Depends(get_db),
):
    """Sedes con su dirección, horario, cantidad de canchas y deportes."""
    return servicio.listar_sedes(db, deporte)


@router.get(
    "/sedes/{sede_id}",
    response_model=SedeOut,
    tags=["sedes"],
    summary="Ver una sede (CU-16)",
    responses={401: _ERROR, 404: _ERROR},
)
def ver_sede(sede_id: int, db: Session = Depends(get_db)):
    return servicio.obtener_sede(db, sede_id)


@router.get(
    "/espacios",
    response_model=list[EspacioOut],
    tags=["espacios"],
    summary="Listar canchas con filtros (CU-13, CU-20)",
    responses={401: _ERROR},
)
def listar_espacios(
    sede_id: int | None = Query(None, description="Canchas de esta sede"),
    deporte: str | None = Query(None, examples=["Fútbol"]),
    tipo: str | None = Query(None, examples=["F5"]),
    db: Session = Depends(get_db),
):
    """Canchas activas. Los filtros se combinan: `?sede_id=1&deporte=Fútbol&tipo=F5`."""
    return servicio.listar_espacios(db, sede_id, deporte, tipo)


@router.get(
    "/espacios/{espacio_id}",
    response_model=EspacioOut,
    tags=["espacios"],
    summary="Ver una cancha (CU-16)",
    responses={401: _ERROR, 404: _ERROR},
)
def ver_espacio(espacio_id: int, db: Session = Depends(get_db)):
    return servicio.espacio_out(servicio.obtener_espacio_activo(db, espacio_id))


@router.get(
    "/deportes",
    response_model=list[DeporteOut],
    tags=["espacios"],
    summary="Deportes y tipos disponibles (filtros CU-20)",
    responses={401: _ERROR},
)
def listar_deportes(db: Session = Depends(get_db)):
    return servicio.listar_deportes(db)
