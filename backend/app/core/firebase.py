"""Conexión con Firebase mediante el Admin SDK.

El backend usa Firebase para dos cosas:
- verificar el ID token que la app manda en cada request (¿quién es el usuario?);
- más adelante, crear cuentas en el registro y enviar notificaciones push.

La inicialización es "perezosa": se hace la primera vez que se necesita, así la
API puede arrancar (y los tests correr) aunque todavía no haya credenciales.
"""
import json
from functools import lru_cache

import firebase_admin
from firebase_admin import auth, credentials

from app.core.config import settings


class FirebaseNoConfigurado(RuntimeError):
    """Falta FIREBASE_CREDENTIALS en el entorno."""


@lru_cache
def obtener_app_firebase() -> firebase_admin.App:
    """Inicializa el Admin SDK una sola vez y devuelve la app de Firebase."""
    valor = settings.FIREBASE_CREDENTIALS.strip()
    if not valor:
        raise FirebaseNoConfigurado(
            "Falta FIREBASE_CREDENTIALS (ruta al JSON o contenido del JSON)."
        )
    # En Render se pega el contenido del JSON; en local, la ruta al archivo.
    origen = json.loads(valor) if valor.startswith("{") else valor
    return firebase_admin.initialize_app(credentials.Certificate(origen))


def verificar_id_token(token: str) -> dict:
    """Verifica firma, emisor y vencimiento del ID token y devuelve sus datos.

    Lanza una excepción de `firebase_admin.auth` si el token no es válido.
    El dato clave del resultado es `uid`, el identificador del usuario en Firebase.
    """
    return auth.verify_id_token(
        token, app=obtener_app_firebase(), clock_skew_seconds=10
    )


def crear_usuario(email: str, password: str, nombre_visible: str) -> str:
    """Crea la cuenta en Firebase Authentication y devuelve su uid.

    Lanza `auth.EmailAlreadyExistsError` si el email ya tiene cuenta.
    """
    usuario = auth.create_user(
        email=email,
        password=password,
        display_name=nombre_visible,
        app=obtener_app_firebase(),
    )
    return usuario.uid


def eliminar_usuario(uid: str) -> None:
    """Borra la cuenta de Firebase. Si ya no existía, no hace nada."""
    try:
        auth.delete_user(uid, app=obtener_app_firebase())
    except auth.UserNotFoundError:
        pass
