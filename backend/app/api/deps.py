"""Dependencias comunes de los endpoints.

Cómo se identifica al usuario en cada request (módulo 9 de la cursada):

    App Flutter --(Authorization: Bearer <ID token>)--> API
    API --(verifica el token con el Admin SDK)--> Firebase  =>  uid
    API --(busca el uid en la tabla usuario)--> PostgreSQL  =>  Usuario

- `get_uid_autenticado`: solo verifica el token. Lo usa el registro, donde el
  perfil todavía no existe.
- `get_usuario_actual`: además exige que el perfil exista y esté activo. Lo usan
  todos los endpoints de usuarios y reservas.
- `exigir_clave_de_tareas`: protege los endpoints que dispara el cron (no hay un
  usuario detrás, solo una clave compartida).
"""
import secrets

from fastapi import Depends, Header, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as firebase_auth
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core import firebase
from app.core.config import settings
from app.core.errores import ErrorAPI
from app.db.session import get_db
from app.models import Usuario

__all__ = [
    "exigir_clave_de_tareas",
    "get_db",
    "get_uid_autenticado",
    "get_usuario_actual",
]

# auto_error=False: si falta el header respondemos nosotros, con el formato de error propio.
_bearer = HTTPBearer(auto_error=False, description="ID token de Firebase Authentication")


def _no_autenticado(mensaje: str) -> ErrorAPI:
    return ErrorAPI(status.HTTP_401_UNAUTHORIZED, "NO_AUTENTICADO", mensaje)


def get_uid_autenticado(
    credenciales: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
    """Devuelve el uid de Firebase del portador del token, o responde 401."""
    if credenciales is None or not credenciales.credentials:
        raise _no_autenticado("Tenés que iniciar sesión.")
    try:
        datos = firebase.verificar_id_token(credenciales.credentials)
    except firebase_auth.ExpiredIdTokenError:
        raise _no_autenticado("Tu sesión expiró. Volvé a iniciar sesión.")
    except (firebase_auth.RevokedIdTokenError, firebase_auth.UserDisabledError):
        raise _no_autenticado("Tu sesión ya no es válida. Volvé a iniciar sesión.")
    except (firebase_auth.InvalidIdTokenError, ValueError):
        raise _no_autenticado("La sesión no es válida. Volvé a iniciar sesión.")
    return datos["uid"]


def get_usuario_actual(
    uid: str = Depends(get_uid_autenticado),
    db: Session = Depends(get_db),
) -> Usuario:
    """Devuelve el perfil del usuario autenticado.

    401 si la cuenta fue dada de baja (CU-07): la app vuelve al login (CU-05, FA4).
    404 si el token es válido pero el perfil no existe (registro incompleto).
    """
    usuario = db.scalar(select(Usuario).where(Usuario.firebase_uid == uid))
    if usuario is None:
        raise ErrorAPI(
            status.HTTP_404_NOT_FOUND,
            "PERFIL_NO_ENCONTRADO",
            "No encontramos tu perfil. Completá el registro.",
        )
    if not usuario.activo:
        raise _no_autenticado("Esta cuenta fue dada de baja.")
    return usuario


def exigir_clave_de_tareas(
    x_tareas_clave: str | None = Header(
        default=None, description="Clave secreta de las tareas programadas"
    ),
) -> None:
    """Deja pasar solo a quien manda la clave configurada en `TAREAS_CLAVE`.

    Si la clave no está configurada responde igual que con una clave equivocada:
    así el endpoint queda cerrado hasta que se la defina, y no se revela cuál de
    los dos casos es.
    """
    esperada = settings.TAREAS_CLAVE
    if (
        not esperada
        or not x_tareas_clave
        or not secrets.compare_digest(x_tareas_clave.encode(), esperada.encode())
    ):
        raise ErrorAPI(
            status.HTTP_401_UNAUTHORIZED,
            "CLAVE_INVALIDA",
            "La clave de tareas no es válida.",
        )
