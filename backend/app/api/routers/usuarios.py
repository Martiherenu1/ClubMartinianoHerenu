"""Endpoints de usuarios: registro, perfil, baja y dispositivos.

El login, la recuperación y el cambio de contraseña no pasan por acá: la app los
hace directo con Firebase Authentication (ver docs/arquitectura.md).
"""
from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_usuario_actual
from app.models import Usuario
from app.schemas.usuario import (
    DispositivoIn,
    EdicionUsuario,
    RegistroUsuario,
    UsuarioOut,
)
from app.services import usuarios as servicio

router = APIRouter(prefix="/usuarios", tags=["usuarios"])

_ERROR = {"description": "Error con formato `{error: {codigo, mensaje}}`"}


@router.post(
    "",
    response_model=UsuarioOut,
    status_code=status.HTTP_201_CREATED,
    summary="Registrarse (CU-03)",
    responses={409: _ERROR, 422: _ERROR},
)
def registrar(datos: RegistroUsuario, db: Session = Depends(get_db)):
    """Crea la cuenta en Firebase y el perfil en la base.

    No requiere token. Después del registro, la app inicia sesión con Firebase
    usando el mismo email y contraseña.
    """
    return servicio.registrar(db, datos)


@router.get(
    "/me",
    response_model=UsuarioOut,
    summary="Ver mi perfil (CU-05)",
    responses={401: _ERROR, 404: _ERROR},
)
def ver_perfil(usuario: Usuario = Depends(get_usuario_actual)):
    return usuario


@router.put(
    "/me",
    response_model=UsuarioOut,
    summary="Editar mi perfil (CU-06)",
    responses={401: _ERROR, 409: _ERROR, 422: _ERROR},
)
def editar_perfil(
    datos: EdicionUsuario,
    usuario: Usuario = Depends(get_usuario_actual),
    db: Session = Depends(get_db),
):
    """Edita nombre, apellido, DNI y fecha de nacimiento. El email no se puede cambiar."""
    return servicio.actualizar(db, usuario, datos)


@router.delete(
    "/me",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Dar de baja mi cuenta (CU-07)",
    responses={401: _ERROR},
)
def dar_de_baja(
    usuario: Usuario = Depends(get_usuario_actual),
    db: Session = Depends(get_db),
):
    """Cancela las reservas futuras, borra la cuenta de Firebase y anonimiza el perfil."""
    servicio.dar_de_baja(db, usuario)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/me/dispositivos",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Registrar el celular para notificaciones (CU-24)",
    responses={401: _ERROR, 422: _ERROR},
)
def registrar_dispositivo(
    datos: DispositivoIn,
    usuario: Usuario = Depends(get_usuario_actual),
    db: Session = Depends(get_db),
):
    servicio.registrar_dispositivo(db, usuario, datos)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/me/dispositivos/{fcm_token}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Quitar el celular al cerrar sesión (CU-02)",
    responses={401: _ERROR},
)
def eliminar_dispositivo(
    fcm_token: str,
    usuario: Usuario = Depends(get_usuario_actual),
    db: Session = Depends(get_db),
):
    servicio.eliminar_dispositivo(db, usuario, fcm_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
