"""Notificaciones push de reservas (CU-24).

- **Recordatorios** 24 h y 1 h antes de la reserva. Los dispara un cron externo
  (GitHub Actions, cada 15 minutos) llamando a `POST /tareas/recordatorios`; ver
  docs/arquitectura.md para saber por qué no es un temporizador dentro de la API.
- **Aviso de cancelación**, en el momento en que el usuario cancela (CU-24.3).

Cada aviso queda registrado en la tabla `notificacion`, que tiene una fila por
(reserva, tipo): así el mismo recordatorio no se manda dos veces aunque el cron
corra seguido o dos corridas se superpongan.

Resultados que se guardan:
- `enviada`: llegó a, al menos, un celular. Es definitivo.
- `no_enviada`: el usuario no tiene celulares registrados. Se vuelve a intentar en
  la corrida siguiente mientras la reserva esté en la ventana del recordatorio.
- `error`: Firebase falló. También se reintenta.
"""
import logging
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.core import firebase, tiempo
from app.models import Dispositivo, EspacioDeportivo, Notificacion, Reserva, Usuario
from app.schemas.notificacion import NotificacionOut, RecordatorioOut

logger = logging.getLogger(__name__)

RECORDATORIO_24H = "recordatorio_24h"
RECORDATORIO_1H = "recordatorio_1h"
CANCELACION = "cancelacion"

_DIAS = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
_MESES = [
    "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
    "septiembre", "octubre", "noviembre", "diciembre",
]


@dataclass
class ResumenRecordatorios:
    """Qué hizo una corrida de recordatorios."""

    revisadas: int = 0  # reservas que estaban en alguna ventana
    enviadas: int = 0
    sin_dispositivo: int = 0
    errores: int = 0


# ---------- Textos ----------

def _fecha_larga(fecha: date) -> str:
    """`2026-10-15` -> `jueves 15 de octubre`."""
    return f"{_DIAS[fecha.weekday()]} {fecha.day} de {_MESES[fecha.month - 1]}"


_DIAS_CORTOS = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]
_MESES_CORTOS = [
    "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic",
]


def _fecha_corta(fecha: date) -> str:
    """`2026-10-15` -> `jue 15 oct`."""
    return f"{_DIAS_CORTOS[fecha.weekday()]} {fecha.day} {_MESES_CORTOS[fecha.month - 1]}"


def _espacio(reserva: Reserva) -> str:
    """`Sede Morón · Fútbol F5`."""
    e = reserva.espacio
    return f"Sede {e.sede.nombre} · {e.deporte} {e.tipo}"


def _datos(reserva: Reserva, tipo: str) -> dict[str, str]:
    """Lo que la app necesita para abrir el detalle al tocar el aviso."""
    return {"tipo": tipo, "reserva_id": str(reserva.id)}


def texto_recordatorio(reserva: Reserva, tipo: str, hoy: date) -> tuple[str, str]:
    """Título y cuerpo del recordatorio de 24 h o de 1 h (textos del Figma, CU-24.1)."""
    inicio = f"{reserva.hora_inicio:%H:%M}"
    if tipo == RECORDATORIO_1H:
        sede = reserva.espacio.sede
        return (
            "Tu reserva comienza en 1 hora",
            f"{_espacio(reserva)}\n"
            f"{_fecha_corta(reserva.fecha)}, {inicio} a {reserva.hora_fin:%H:%M}\n"
            f"{sede.direccion}, {sede.nombre}",
        )
    cuando = "hoy" if reserva.fecha == hoy else "mañana"
    return (
        f"Tenés una reserva {cuando}",
        f"{_espacio(reserva)} — {_fecha_corta(reserva.fecha)}, {inicio}",
    )


def texto_de_aviso(reserva: Reserva, tipo: str, enviada_en: datetime) -> tuple[str, str]:
    """Título y cuerpo de un aviso ya enviado, para el panel de notificaciones."""
    if tipo == CANCELACION:
        return texto_cancelacion(reserva)
    return texto_recordatorio(reserva, tipo, enviada_en.astimezone(tiempo.ZONA).date())


def texto_cancelacion(reserva: Reserva) -> tuple[str, str]:
    return (
        "Reserva cancelada",
        f"Cancelaste tu reserva del {_fecha_larga(reserva.fecha)} a las "
        f"{reserva.hora_inicio:%H:%M} en Sede {reserva.espacio.sede.nombre}. "
        "El horario quedó libre.",
    )


# ---------- Envío ----------

def _enviar_a_dispositivos(
    db: Session, usuario: Usuario, titulo: str, cuerpo: str, datos: dict[str, str]
) -> str:
    """Manda el push a todos los celulares del usuario y devuelve el resultado.

    Si Firebase dice que un token ya no existe, se borra (CU-24 FA3).
    """
    dispositivos: list[Dispositivo] = list(usuario.dispositivos)
    if not dispositivos:
        return "no_enviada"

    llego = False
    fallo = False
    for dispositivo in dispositivos:
        try:
            firebase.enviar_notificacion(dispositivo.fcm_token, titulo, cuerpo, datos)
            llego = True
        except firebase.TokenDeDispositivoInvalido:
            db.delete(dispositivo)
        except Exception:  # noqa: BLE001 - un celular que falla no frena a los demás
            logger.exception("No se pudo enviar el push al dispositivo %s", dispositivo.id)
            fallo = True
    if llego:
        return "enviada"
    return "error" if fallo else "no_enviada"


def _reclamar(db: Session, reserva: Reserva, tipo: str) -> Notificacion | None:
    """Devuelve la fila de (reserva, tipo) para enviar, o `None` si no hay que enviar.

    - Si ya se envió, `None`.
    - Si existe de un intento anterior fallido, se reutiliza.
    - Si no existe, se crea. La restricción de unicidad hace que, si otra corrida la
      creó justo antes, esta se retire en vez de duplicar el aviso.
    """
    existente = db.scalar(
        select(Notificacion).where(
            Notificacion.reserva_id == reserva.id, Notificacion.tipo == tipo
        )
    )
    if existente is not None:
        return None if existente.resultado == "enviada" else existente
    nueva = Notificacion(reserva_id=reserva.id, tipo=tipo, resultado="no_enviada")
    try:
        with db.begin_nested():
            db.add(nueva)
    except IntegrityError:
        return None
    return nueva


def _enviar_y_registrar(
    db: Session, reserva: Reserva, tipo: str, titulo: str, cuerpo: str
) -> str | None:
    """Envía un aviso de la reserva y deja el resultado en `notificacion`."""
    registro = _reclamar(db, reserva, tipo)
    if registro is None:
        return None
    resultado = _enviar_a_dispositivos(
        db, reserva.usuario, titulo, cuerpo, _datos(reserva, tipo)
    )
    registro.resultado = resultado
    registro.enviada_en = tiempo.ahora()
    db.commit()
    return resultado


# ---------- Casos de uso ----------

def avisar_cancelacion(db: Session, reserva: Reserva) -> None:
    """Push de "reserva cancelada" (CU-24.3).

    Es un aviso de cortesía: si falla, la cancelación igual ya quedó hecha, así
    que cualquier error se registra en el log y no se propaga.
    """
    try:
        titulo, cuerpo = texto_cancelacion(reserva)
        _enviar_y_registrar(db, reserva, CANCELACION, titulo, cuerpo)
    except Exception:  # noqa: BLE001
        logger.exception("No se pudo avisar la cancelación de la reserva %s", reserva.id)
        db.rollback()


def _inicio(reserva: Reserva) -> datetime:
    return datetime.combine(reserva.fecha, reserva.hora_inicio, tzinfo=tiempo.ZONA)


def recordatorios_de(reserva: Reserva, momento: datetime) -> list[RecordatorioOut]:
    """Estado de los recordatorios de una reserva, para el detalle (CU-24.1).

    Solo se listan los que aplican: si la reserva se hizo después de la hora en que
    habría salido un recordatorio, ese no corresponde. Una reserva cancelada no
    tiene recordatorios.
    """
    if reserva.estado == "cancelada":
        return []
    enviados = {n.tipo for n in reserva.notificaciones if n.resultado == "enviada"}
    inicio = _inicio(reserva)
    resultado: list[RecordatorioOut] = []
    for tipo, etiqueta, antes in (
        (RECORDATORIO_24H, "24h", timedelta(hours=24)),
        (RECORDATORIO_1H, "1h", timedelta(hours=1)),
    ):
        programado = inicio - antes
        if reserva.creada_en > programado:
            continue
        if tipo in enviados:
            estado = "enviado"
        elif momento < programado:
            estado = "pendiente"
        else:
            estado = "no_enviado"
        resultado.append(
            RecordatorioOut(tipo=etiqueta, programado_para=programado, estado=estado)
        )
    return resultado


def listar_avisos(db: Session, usuario: Usuario, limite: int) -> list[NotificacionOut]:
    """Avisos que recibió el usuario, del más nuevo al más viejo (panel in-app)."""
    filas = db.scalars(
        select(Notificacion)
        .join(Reserva)
        .where(Reserva.usuario_id == usuario.id, Notificacion.resultado == "enviada")
        .options(
            joinedload(Notificacion.reserva)
            .joinedload(Reserva.espacio)
            .joinedload(EspacioDeportivo.sede)
        )
        .order_by(Notificacion.enviada_en.desc(), Notificacion.id.desc())
        .limit(limite)
    ).unique()
    avisos = []
    for n in filas:
        titulo, cuerpo = texto_de_aviso(n.reserva, n.tipo, n.enviada_en)
        avisos.append(
            NotificacionOut(
                id=n.id,
                tipo=n.tipo,
                titulo=titulo,
                cuerpo=cuerpo,
                reserva_id=n.reserva_id,
                # Hora del club: la app muestra la hora tal cual viene.
                enviada_en=n.enviada_en.astimezone(tiempo.ZONA),
            )
        )
    return avisos


def recordatorio_que_corresponde(reserva: Reserva, momento: datetime) -> str | None:
    """Qué recordatorio toca mandar ahora para la reserva, si toca alguno.

    - **24 h:** desde 24 h antes y hasta 1 h antes (en la última hora manda el de
      1 h). No se manda si la reserva se hizo dentro de esas 24 h: la persona
      acaba de reservar y ya lo sabe.
    - **1 h:** desde 1 h antes y hasta que empieza. Misma regla para reservas
      hechas dentro de esa hora.
    """
    inicio = _inicio(reserva)
    if momento >= inicio:
        return None
    if momento >= inicio - timedelta(hours=1):
        if reserva.creada_en > inicio - timedelta(hours=1):
            return None
        return RECORDATORIO_1H
    if momento >= inicio - timedelta(hours=24):
        if reserva.creada_en > inicio - timedelta(hours=24):
            return None
        return RECORDATORIO_24H
    return None


def enviar_recordatorios(
    db: Session, momento: datetime | None = None
) -> ResumenRecordatorios:
    """Manda los recordatorios que correspondan en este momento (CU-24).

    Es idempotente: se puede llamar tantas veces como se quiera, cada recordatorio
    se envía una sola vez por reserva.
    """
    momento = momento or tiempo.ahora()
    resumen = ResumenRecordatorios()

    # Una reserva a menos de 24 h empieza hoy o mañana: alcanza con mirar esos días.
    reservas = list(db.scalars(
        select(Reserva)
        .join(Usuario)
        .where(
            Reserva.estado == "confirmada",
            Usuario.activo.is_(True),
            Reserva.fecha >= momento.date(),
            Reserva.fecha <= momento.date() + timedelta(days=1),
        )
        .options(
            joinedload(Reserva.espacio).joinedload(EspacioDeportivo.sede),
            joinedload(Reserva.usuario).joinedload(Usuario.dispositivos),
        )
        .order_by(Reserva.fecha, Reserva.hora_inicio)
    ).unique())

    for reserva in reservas:
        tipo = recordatorio_que_corresponde(reserva, momento)
        if tipo is None:
            continue
        resumen.revisadas += 1
        titulo, cuerpo = texto_recordatorio(reserva, tipo, momento.date())
        resultado = _enviar_y_registrar(db, reserva, tipo, titulo, cuerpo)
        if resultado == "enviada":
            resumen.enviadas += 1
        elif resultado == "no_enviada":
            resumen.sin_dispositivo += 1
        elif resultado == "error":
            resumen.errores += 1
    return resumen
