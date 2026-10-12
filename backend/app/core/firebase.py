"""Conexión con Firebase mediante el Admin SDK.

El backend usa Firebase para tres cosas:
- verificar el ID token que la app manda en cada request (¿quién es el usuario?);
- crear y borrar cuentas (registro y baja);
- enviar notificaciones push con Cloud Messaging (CU-24).

La inicialización es "perezosa": se hace la primera vez que se necesita, así la
API puede arrancar (y los tests correr) aunque todavía no haya credenciales.
"""
import json
from functools import lru_cache

import firebase_admin
from firebase_admin import auth, credentials, exceptions, messaging

from app.core.config import settings


class FirebaseNoConfigurado(RuntimeError):
    """Falta FIREBASE_CREDENTIALS en el entorno."""


class TokenDeDispositivoInvalido(Exception):
    """FCM informa que el token del celular ya no existe (app desinstalada, etc.)."""


class EnvioFallido(Exception):
    """No se pudo entregar la notificación (red, cuota, servicio caído)."""


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
    # httpTimeout: si Firebase no responde, que el pedido no quede colgado minutos.
    return firebase_admin.initialize_app(
        credentials.Certificate(origen), options={"httpTimeout": 15}
    )


def verificar_id_token(token: str) -> dict:
    """Verifica firma, emisor y vencimiento del ID token y devuelve sus datos.

    Lanza una excepción de `firebase_admin.auth` si el token no es válido.
    El dato clave del resultado es `uid`, el identificador del usuario en Firebase.
    """
    # El token trae la hora de emisión (`iat`). Si el reloj de esta máquina está
    # unos segundos atrasado respecto de Google, el SDK lo rechaza como "usado
    # demasiado pronto". 60 s es el máximo que admite el SDK y evita ese falso
    # rechazo (pasó en desarrollo con un reloj 13 s atrasado).
    return auth.verify_id_token(
        token, app=obtener_app_firebase(), clock_skew_seconds=60
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


def enviar_notificacion(
    token: str, titulo: str, cuerpo: str, datos: dict[str, str] | None = None
) -> None:
    """Envía un push a un celular (token de FCM).

    `datos` viaja junto a la notificación: la app lo usa para abrir el detalle de
    la reserva cuando el usuario toca el aviso. Todos los valores deben ser texto.

    Lanza `TokenDeDispositivoInvalido` si el token ya no sirve (hay que borrarlo,
    CU-24 FA3) y `EnvioFallido` ante cualquier otro problema.
    """
    mensaje = messaging.Message(
        token=token,
        notification=messaging.Notification(title=titulo, body=cuerpo),
        data=datos or {},
        # Prioridad alta: el recordatorio tiene que llegar aunque el celular duerma.
        android=messaging.AndroidConfig(priority="high"),
    )
    try:
        messaging.send(mensaje, app=obtener_app_firebase())
    except (messaging.UnregisteredError, messaging.SenderIdMismatchError) as e:
        raise TokenDeDispositivoInvalido(str(e)) from e
    except exceptions.InvalidArgumentError as e:
        # "The registration token is not a valid FCM registration token".
        if "registration token" in str(e).lower():
            raise TokenDeDispositivoInvalido(str(e)) from e
        raise EnvioFallido(str(e)) from e
    except (exceptions.FirebaseError, ValueError) as e:
        raise EnvioFallido(str(e)) from e
