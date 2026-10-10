"""Reglas de negocio de usuarios: registro, edición, baja y dispositivos."""
from fastapi import status
from firebase_admin import auth as firebase_auth
from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core import firebase
from app.core.errores import ErrorAPI
from app.core.tiempo import ahora
from app.models import Dispositivo, Reserva, Usuario
from app.schemas.usuario import DispositivoIn, EdicionUsuario, RegistroUsuario


def _email_ya_registrado() -> ErrorAPI:
    return ErrorAPI(
        status.HTTP_409_CONFLICT,
        "EMAIL_YA_REGISTRADO",
        "Ya existe una cuenta con ese email.",
    )


def _dni_ya_registrado() -> ErrorAPI:
    return ErrorAPI(
        status.HTTP_409_CONFLICT,
        "DNI_YA_REGISTRADO",
        "Ya existe una cuenta con ese DNI.",
    )


def _dni_en_uso(db: Session, dni: str, excepto_id: int | None = None) -> bool:
    consulta = select(Usuario.id).where(Usuario.dni == dni)
    if excepto_id is not None:
        consulta = consulta.where(Usuario.id != excepto_id)
    return db.scalar(consulta) is not None


def registrar(db: Session, datos: RegistroUsuario) -> Usuario:
    """Registra un usuario nuevo (CU-03).

    1. Valida que el DNI y el email no estén registrados (FA2).
    2. Crea la cuenta en Firebase Authentication (guarda la contraseña).
    3. Guarda el perfil en PostgreSQL.
    Si el paso 3 falla, se borra la cuenta del paso 2: no quedan cuentas a medias.
    """
    email = datos.email.lower()
    if _dni_en_uso(db, datos.dni):
        raise _dni_ya_registrado()
    if db.scalar(select(Usuario.id).where(Usuario.email == email)) is not None:
        raise _email_ya_registrado()

    try:
        uid = firebase.crear_usuario(
            email, datos.password, f"{datos.nombre} {datos.apellido}"
        )
    except firebase_auth.EmailAlreadyExistsError:
        raise _email_ya_registrado()

    usuario = Usuario(
        firebase_uid=uid,
        email=email,
        nombre=datos.nombre,
        apellido=datos.apellido,
        dni=datos.dni,
        fecha_nacimiento=datos.fecha_nacimiento,
    )
    try:
        db.add(usuario)
        db.commit()
    except IntegrityError:
        # Otro registro simultáneo usó el mismo DNI o email entre la validación y el guardado.
        db.rollback()
        firebase.eliminar_usuario(uid)
        raise _dni_ya_registrado() if _dni_en_uso(db, datos.dni) else _email_ya_registrado()
    except Exception:
        db.rollback()
        firebase.eliminar_usuario(uid)
        raise
    db.refresh(usuario)
    return usuario


def actualizar(db: Session, usuario: Usuario, datos: EdicionUsuario) -> Usuario:
    """Edita los datos personales (CU-06). El email no se puede cambiar."""
    if _dni_en_uso(db, datos.dni, excepto_id=usuario.id):
        raise _dni_ya_registrado()
    usuario.nombre = datos.nombre
    usuario.apellido = datos.apellido
    usuario.dni = datos.dni
    usuario.fecha_nacimiento = datos.fecha_nacimiento
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise _dni_ya_registrado()
    db.refresh(usuario)
    return usuario


def dar_de_baja(db: Session, usuario: Usuario) -> None:
    """Da de baja la cuenta (CU-07).

    - Cancela sus reservas futuras: libera esos horarios para otros usuarios.
    - Borra sus dispositivos (deja de recibir notificaciones).
    - Anonimiza email, DNI y uid: la persona puede volver a registrarse con los
      mismos datos, y no se conservan datos personales de una cuenta eliminada.
    - Marca la cuenta como inactiva. La fila y sus reservas pasadas quedan para
      que el historial del club no tenga huecos.
    - Borra la cuenta de Firebase (ya no puede iniciar sesión).
    """
    momento = ahora()
    hoy, hora = momento.date(), momento.time().replace(tzinfo=None)
    futuras = db.scalars(
        select(Reserva).where(
            Reserva.usuario_id == usuario.id,
            Reserva.estado == "confirmada",
            or_(
                Reserva.fecha > hoy,
                and_(Reserva.fecha == hoy, Reserva.hora_inicio > hora),
            ),
        )
    ).all()
    for reserva in futuras:
        reserva.estado = "cancelada"
        reserva.cancelada_en = momento

    usuario.dispositivos.clear()
    uid_firebase = usuario.firebase_uid
    usuario.firebase_uid = f"baja-{usuario.id}"
    usuario.email = f"baja-{usuario.id}@cuenta.eliminada"
    usuario.dni = f"baja-{usuario.id}"
    usuario.activo = False
    db.commit()

    firebase.eliminar_usuario(uid_firebase)


def registrar_dispositivo(db: Session, usuario: Usuario, datos: DispositivoIn) -> Dispositivo:
    """Guarda el token de push del celular (CU-24).

    Si el token ya existía (por ejemplo, otra persona usó antes el mismo celular)
    pasa a pertenecer al usuario actual.
    """
    dispositivo = db.scalar(
        select(Dispositivo).where(Dispositivo.fcm_token == datos.fcm_token)
    )
    if dispositivo is None:
        dispositivo = Dispositivo(fcm_token=datos.fcm_token)
        db.add(dispositivo)
    dispositivo.usuario_id = usuario.id
    dispositivo.plataforma = datos.plataforma
    dispositivo.actualizado_en = ahora()
    db.commit()
    db.refresh(dispositivo)
    return dispositivo


def eliminar_dispositivo(db: Session, usuario: Usuario, fcm_token: str) -> None:
    """Borra el token al cerrar sesión (CU-02). Si no existe, no hace nada."""
    dispositivo = db.scalar(
        select(Dispositivo).where(
            Dispositivo.fcm_token == fcm_token,
            Dispositivo.usuario_id == usuario.id,
        )
    )
    if dispositivo is not None:
        db.delete(dispositivo)
        db.commit()
