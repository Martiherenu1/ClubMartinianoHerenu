"""Tests de las notificaciones push (CU-24): recordatorios y aviso de cancelación.

Reloj fijo: miércoles 14/10/2026 a las 15:30 (hora de Argentina). Firebase está
reemplazado por `FirebaseFalso`, que recuerda cada push enviado.
"""
from datetime import date, datetime, time, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.core import tiempo
from app.core.config import settings
from app.models import (
    Dispositivo,
    EspacioDeportivo,
    Notificacion,
    Reserva,
    Sede,
    Usuario,
)
from app.seed import cargar_catalogo
from app.services import notificaciones as servicio
from tests.conftest import auth_header

ZONA = tiempo.ZONA
AHORA = datetime(2026, 10, 14, 15, 30, tzinfo=ZONA)
HOY = AHORA.date()
MANANA = HOY + timedelta(days=1)
LEJOS = datetime(2026, 10, 1, 9, 0, tzinfo=ZONA)  # reservas hechas hace tiempo


@pytest.fixture(autouse=True)
def reloj_fijo(monkeypatch):
    monkeypatch.setattr(tiempo, "ahora", lambda: AHORA)


def _usuario(db, uid: str, dni: str, activo: bool = True) -> Usuario:
    u = Usuario(
        firebase_uid=uid, email=f"{uid}@mail.com", nombre=uid.title(), apellido="B",
        dni=dni, fecha_nacimiento=date(2000, 1, 1), activo=activo,
    )
    db.add(u)
    db.flush()
    return u


@pytest.fixture
def ctx(db):
    """Catálogo, la usuaria Ana con un celular y la F5 Cancha 1 de Morón."""
    cargar_catalogo(db)
    ana = _usuario(db, "ana", "30000001")
    db.add(Dispositivo(usuario_id=ana.id, fcm_token="tok-ana-1"))
    f5 = db.scalar(
        select(EspacioDeportivo).join(Sede).where(
            Sede.nombre == "Morón",
            EspacioDeportivo.tipo == "F5",
            EspacioDeportivo.numero == 1,
        )
    )
    db.flush()
    db.expire(ana)
    return {"ana": ana, "f5": f5}


def reserva(db, ctx, fecha, hora, estado="confirmada", creada_en=LEJOS, usuario=None):
    r = Reserva(
        usuario_id=(usuario or ctx["ana"]).id, espacio_id=ctx["f5"].id,
        fecha=fecha, hora_inicio=time(hora), hora_fin=time(hora + 1),
        precio_total=Decimal("3800"), estado=estado, creada_en=creada_en,
    )
    db.add(r)
    db.flush()
    return r


def notificaciones_de(db, r):
    return {
        n.tipo: n.resultado
        for n in db.scalars(select(Notificacion).where(Notificacion.reserva_id == r.id))
    }


# ---------- Qué recordatorio corresponde ----------

@pytest.mark.parametrize(
    "fecha, hora, esperado",
    [
        (MANANA, 15, "recordatorio_24h"),  # empieza en 23 h 30 min
        (MANANA, 16, None),                # 24 h 30 min: todavía no
        (HOY, 17, "recordatorio_24h"),     # 1 h 30 min: entra el de 24 h
        (HOY, 16, "recordatorio_1h"),      # 30 min
        (HOY, 15, None),                   # ya empezó (15:00)
        (HOY, 22, "recordatorio_24h"),
    ],
)
def test_que_recordatorio_corresponde(db, ctx, fecha, hora, esperado):
    r = reserva(db, ctx, fecha, hora)
    assert servicio.recordatorio_que_corresponde(r, AHORA) == esperado


def test_a_una_hora_justa_cambia_del_recordatorio_de_24h_al_de_1h(db, ctx):
    r = reserva(db, ctx, HOY, 16)
    una_hora_antes = datetime(2026, 10, 14, 15, 0, tzinfo=ZONA)
    un_minuto_antes = datetime(2026, 10, 14, 14, 59, tzinfo=ZONA)
    assert servicio.recordatorio_que_corresponde(r, una_hora_antes) == "recordatorio_1h"
    assert servicio.recordatorio_que_corresponde(r, un_minuto_antes) == "recordatorio_24h"


def test_reserva_hecha_dentro_de_la_ventana_no_recuerda(db, ctx):
    # La ventana de 24 h para mañana a las 15:00 abrió hoy a las 15:00. Quien
    # reservó a las 15:25 (ya dentro de la ventana) acaba de hacerlo: no se le
    # recuerda. Quien reservó a las 14:30 todavía no había recibido ningún aviso.
    reciente = reserva(db, ctx, MANANA, 15, creada_en=AHORA - timedelta(minutes=5))
    previa = reserva(db, ctx, MANANA, 15, creada_en=AHORA - timedelta(hours=1))
    assert servicio.recordatorio_que_corresponde(reciente, AHORA) is None
    assert servicio.recordatorio_que_corresponde(previa, AHORA) == "recordatorio_24h"


# ---------- Corrida de recordatorios ----------

def test_envia_el_recordatorio_de_24h_con_texto_y_datos(db, ctx, firebase_falso):
    r = reserva(db, ctx, MANANA, 15)

    resumen = servicio.enviar_recordatorios(db)

    assert (resumen.revisadas, resumen.enviadas) == (1, 1)
    (push,) = firebase_falso.pushes
    assert push["token"] == "tok-ana-1"
    assert push["titulo"] == "Tenés una reserva mañana"
    assert push["cuerpo"] == "Sede Morón · Fútbol F5 — jue 15 oct, 15:00"
    assert push["datos"] == {"tipo": "recordatorio_24h", "reserva_id": str(r.id)}
    assert notificaciones_de(db, r) == {"recordatorio_24h": "enviada"}


def test_envia_el_recordatorio_de_1h(db, ctx, firebase_falso):
    r = reserva(db, ctx, HOY, 16)

    servicio.enviar_recordatorios(db)

    (push,) = firebase_falso.pushes
    assert push["titulo"] == "Tu reserva comienza en 1 hora"
    assert push["cuerpo"] == (
        "Sede Morón · Fútbol F5\n"
        "mié 14 oct, 16:00 a 17:00\n"
        "Av. Rivadavia 17500, Morón"
    )
    assert notificaciones_de(db, r) == {"recordatorio_1h": "enviada"}


def test_el_texto_dice_hoy_si_es_el_mismo_dia(db, ctx, firebase_falso):
    reserva(db, ctx, HOY, 20)

    servicio.enviar_recordatorios(db)

    assert firebase_falso.pushes[0]["titulo"] == "Tenés una reserva hoy"
    assert firebase_falso.pushes[0]["cuerpo"].endswith("mié 14 oct, 20:00")


def test_no_manda_dos_veces_el_mismo_recordatorio(db, ctx, firebase_falso):
    r = reserva(db, ctx, MANANA, 15)

    primera = servicio.enviar_recordatorios(db)
    segunda = servicio.enviar_recordatorios(db)

    assert primera.enviadas == 1
    assert (segunda.revisadas, segunda.enviadas) == (1, 0)
    assert len(firebase_falso.pushes) == 1
    filas = db.scalars(select(Notificacion).where(Notificacion.reserva_id == r.id)).all()
    assert len(filas) == 1


def test_el_de_1h_se_manda_aunque_ya_se_mando_el_de_24h(db, ctx, firebase_falso):
    r = reserva(db, ctx, HOY, 20)

    servicio.enviar_recordatorios(db, AHORA)  # faltan 4 h 30 min: el de 24 h
    servicio.enviar_recordatorios(db, datetime(2026, 10, 14, 19, 5, tzinfo=ZONA))  # 55 min

    assert [p["datos"]["tipo"] for p in firebase_falso.pushes] == [
        "recordatorio_24h",
        "recordatorio_1h",
    ]
    assert notificaciones_de(db, r) == {
        "recordatorio_24h": "enviada",
        "recordatorio_1h": "enviada",
    }


def test_ignora_canceladas_empezadas_y_cuentas_dadas_de_baja(db, ctx, firebase_falso):
    reserva(db, ctx, MANANA, 15, estado="cancelada")
    reserva(db, ctx, HOY, 15)  # ya empezó
    baja = _usuario(db, "baja", "30000009", activo=False)
    db.add(Dispositivo(usuario_id=baja.id, fcm_token="tok-baja"))
    reserva(db, ctx, MANANA, 15, usuario=baja)

    resumen = servicio.enviar_recordatorios(db)

    assert resumen.revisadas == 0
    assert firebase_falso.pushes == []


def test_sin_celular_queda_pendiente_y_se_manda_cuando_lo_registra(db, ctx, firebase_falso):
    db.delete(db.scalar(select(Dispositivo)))
    db.flush()
    db.expire(ctx["ana"])
    r = reserva(db, ctx, MANANA, 15)

    primera = servicio.enviar_recordatorios(db)
    assert (primera.enviadas, primera.sin_dispositivo) == (0, 1)
    assert notificaciones_de(db, r) == {"recordatorio_24h": "no_enviada"}

    db.add(Dispositivo(usuario_id=ctx["ana"].id, fcm_token="tok-nuevo"))
    db.flush()
    db.expire(ctx["ana"])
    segunda = servicio.enviar_recordatorios(db)

    assert segunda.enviadas == 1
    assert firebase_falso.pushes[0]["token"] == "tok-nuevo"
    assert notificaciones_de(db, r) == {"recordatorio_24h": "enviada"}


def test_token_invalido_se_borra_y_el_otro_celular_igual_recibe(db, ctx, firebase_falso):
    db.add(Dispositivo(usuario_id=ctx["ana"].id, fcm_token="tok-ana-2"))
    db.flush()
    db.expire(ctx["ana"])
    firebase_falso.tokens_invalidos.add("tok-ana-1")
    reserva(db, ctx, MANANA, 15)

    resumen = servicio.enviar_recordatorios(db)

    assert resumen.enviadas == 1
    assert [p["token"] for p in firebase_falso.pushes] == ["tok-ana-2"]
    assert {d.fcm_token for d in db.scalars(select(Dispositivo))} == {"tok-ana-2"}


def test_si_firebase_falla_se_registra_el_error_y_se_reintenta(db, ctx, firebase_falso):
    firebase_falso.tokens_con_error.add("tok-ana-1")
    r = reserva(db, ctx, MANANA, 15)

    primera = servicio.enviar_recordatorios(db)
    assert (primera.enviadas, primera.errores) == (0, 1)
    assert notificaciones_de(db, r) == {"recordatorio_24h": "error"}

    firebase_falso.tokens_con_error.clear()
    segunda = servicio.enviar_recordatorios(db)

    assert segunda.enviadas == 1
    assert notificaciones_de(db, r) == {"recordatorio_24h": "enviada"}


def test_una_reserva_con_error_no_frena_a_las_demas(db, ctx, firebase_falso):
    beto = _usuario(db, "beto", "30000002")
    db.add(Dispositivo(usuario_id=beto.id, fcm_token="tok-beto"))
    db.flush()
    db.expire(beto)
    firebase_falso.tokens_con_error.add("tok-ana-1")
    reserva(db, ctx, MANANA, 15)  # Ana: falla
    reserva(db, ctx, HOY, 20, usuario=beto)  # Beto: sale

    resumen = servicio.enviar_recordatorios(db)

    assert (resumen.enviadas, resumen.errores) == (1, 1)
    assert [p["token"] for p in firebase_falso.pushes] == ["tok-beto"]


# ---------- Endpoint del cron ----------

URL = "/api/v1/tareas/recordatorios"


@pytest.fixture
def clave(monkeypatch):
    monkeypatch.setattr(settings, "TAREAS_CLAVE", "clave-de-prueba")
    return {"X-Tareas-Clave": "clave-de-prueba"}


def test_el_endpoint_envia_y_resume(cliente, db, ctx, firebase_falso, clave):
    reserva(db, ctx, MANANA, 15)

    r = cliente.post(URL, headers=clave)

    assert r.status_code == 200, r.text
    assert r.json() == {"revisadas": 1, "enviadas": 1, "sin_dispositivo": 0, "errores": 0}
    assert len(firebase_falso.pushes) == 1


def test_el_endpoint_sin_clave_o_con_clave_mala_responde_401(cliente, clave):
    assert cliente.post(URL).status_code == 401
    r = cliente.post(URL, headers={"X-Tareas-Clave": "otra"})
    assert r.status_code == 401
    assert r.json()["error"]["codigo"] == "CLAVE_INVALIDA"


def test_sin_clave_configurada_el_endpoint_queda_cerrado(cliente, monkeypatch):
    monkeypatch.setattr(settings, "TAREAS_CLAVE", "")
    assert cliente.post(URL, headers={"X-Tareas-Clave": ""}).status_code == 401
    assert cliente.post(URL, headers={"X-Tareas-Clave": "algo"}).status_code == 401


def test_un_usuario_logueado_no_puede_disparar_las_tareas(cliente, ctx, clave):
    assert cliente.post(URL, headers=auth_header("ana")).status_code == 401


# ---------- Aviso de cancelación ----------

def test_cancelar_avisa_por_push(cliente, db, ctx, firebase_falso):
    r = reserva(db, ctx, MANANA, 18)

    resp = cliente.delete(f"/api/v1/reservas/{r.id}", headers=auth_header("ana"))

    assert resp.status_code == 200, resp.text
    (push,) = firebase_falso.pushes
    assert push["titulo"] == "Reserva cancelada"
    assert push["cuerpo"] == (
        "Cancelaste tu reserva del jueves 15 de octubre a las 18:00 en Sede Morón. "
        "El horario quedó libre."
    )
    assert push["datos"] == {"tipo": "cancelacion", "reserva_id": str(r.id)}
    assert notificaciones_de(db, r) == {"cancelacion": "enviada"}


def test_si_el_push_falla_la_cancelacion_igual_se_hace(cliente, db, ctx, firebase_falso):
    firebase_falso.tokens_con_error.add("tok-ana-1")
    r = reserva(db, ctx, MANANA, 18)

    resp = cliente.delete(f"/api/v1/reservas/{r.id}", headers=auth_header("ana"))

    assert resp.status_code == 200
    assert resp.json()["estado"] == "cancelada"
    assert notificaciones_de(db, r) == {"cancelacion": "error"}


def test_cancelar_sin_celular_registrado_funciona(cliente, db, ctx, firebase_falso):
    db.delete(db.scalar(select(Dispositivo)))
    db.flush()
    db.expire(ctx["ana"])
    r = reserva(db, ctx, MANANA, 18)

    resp = cliente.delete(f"/api/v1/reservas/{r.id}", headers=auth_header("ana"))

    assert resp.status_code == 200
    assert firebase_falso.pushes == []
    assert notificaciones_de(db, r) == {"cancelacion": "no_enviada"}


def test_una_reserva_cancelada_no_recibe_recordatorios(cliente, db, ctx, firebase_falso, clave):
    r = reserva(db, ctx, MANANA, 15)
    cliente.delete(f"/api/v1/reservas/{r.id}", headers=auth_header("ana"))
    firebase_falso.pushes.clear()

    resp = cliente.post(URL, headers=clave)

    assert resp.json()["revisadas"] == 0
    assert firebase_falso.pushes == []


# ---------- Panel de notificaciones ----------

PANEL = "/api/v1/notificaciones"


def test_el_panel_lista_los_avisos_recibidos_del_mas_nuevo_al_mas_viejo(
    cliente, db, ctx, firebase_falso
):
    r = reserva(db, ctx, HOY, 20)
    servicio.enviar_recordatorios(db, AHORA)  # 24 h
    servicio.enviar_recordatorios(db, datetime(2026, 10, 14, 19, 5, tzinfo=ZONA))  # 1 h

    resp = cliente.get(PANEL, headers=auth_header("ana"))

    assert resp.status_code == 200, resp.text
    avisos = resp.json()
    assert [a["tipo"] for a in avisos] == ["recordatorio_1h", "recordatorio_24h"]
    assert avisos[0]["titulo"] == "Tu reserva comienza en 1 hora"
    assert avisos[1]["titulo"] == "Tenés una reserva hoy"
    assert {a["reserva_id"] for a in avisos} == {r.id}


def test_el_panel_no_muestra_avisos_que_no_llegaron_ni_los_de_otros(
    cliente, db, ctx, firebase_falso
):
    firebase_falso.tokens_con_error.add("tok-ana-1")
    reserva(db, ctx, MANANA, 15)
    servicio.enviar_recordatorios(db)  # error: no llegó

    beto = _usuario(db, "beto", "30000002")
    db.add(Dispositivo(usuario_id=beto.id, fcm_token="tok-beto"))
    db.flush()
    db.expire(beto)
    reserva(db, ctx, MANANA, 15, usuario=beto)
    servicio.enviar_recordatorios(db)  # a Beto sí le llega

    assert cliente.get(PANEL, headers=auth_header("ana")).json() == []
    assert len(cliente.get(PANEL, headers=auth_header("beto")).json()) == 1


def test_el_panel_incluye_la_cancelacion_y_respeta_el_limite(cliente, db, ctx, firebase_falso):
    r = reserva(db, ctx, MANANA, 18)
    cliente.delete(f"/api/v1/reservas/{r.id}", headers=auth_header("ana"))

    todos = cliente.get(PANEL, headers=auth_header("ana")).json()
    assert [a["tipo"] for a in todos] == ["cancelacion"]
    assert todos[0]["titulo"] == "Reserva cancelada"
    assert cliente.get(f"{PANEL}?limite=0", headers=auth_header("ana")).status_code == 422


def test_el_panel_requiere_sesion(cliente):
    assert cliente.get(PANEL).status_code == 401


# ---------- Recordatorios en el detalle de la reserva ----------

def _detalle(cliente, r):
    return cliente.get(f"/api/v1/reservas/{r.id}", headers=auth_header("ana")).json()


def test_el_detalle_muestra_los_recordatorios_pendientes(cliente, db, ctx):
    r = reserva(db, ctx, date(2026, 10, 20), 19)

    recordatorios = _detalle(cliente, r)["recordatorios"]

    assert [(x["tipo"], x["estado"]) for x in recordatorios] == [
        ("24h", "pendiente"),
        ("1h", "pendiente"),
    ]
    assert recordatorios[0]["programado_para"].startswith("2026-10-19T19:00:00")
    assert recordatorios[1]["programado_para"].startswith("2026-10-20T18:00:00")


def test_el_detalle_marca_enviado_lo_que_ya_salio(cliente, db, ctx, firebase_falso):
    r = reserva(db, ctx, HOY, 20)
    servicio.enviar_recordatorios(db, AHORA)  # sale el de 24 h

    recordatorios = _detalle(cliente, r)["recordatorios"]

    assert [(x["tipo"], x["estado"]) for x in recordatorios] == [
        ("24h", "enviado"),
        ("1h", "pendiente"),
    ]


def test_el_detalle_marca_no_enviado_si_paso_la_hora_y_no_salio(cliente, db, ctx):
    # Empieza en 30 min y nunca corrió el cron.
    r = reserva(db, ctx, HOY, 16)

    recordatorios = _detalle(cliente, r)["recordatorios"]

    assert [(x["tipo"], x["estado"]) for x in recordatorios] == [
        ("24h", "no_enviado"),
        ("1h", "no_enviado"),
    ]


def test_el_detalle_omite_los_recordatorios_que_no_aplican(cliente, db, ctx):
    # El aviso de 24 h de una reserva de mañana a las 15:00 sale hoy a las 15:00.
    # Quien reservó a las 15:25 lo hizo después: ese aviso no corresponde y queda
    # solo el de 1 h.
    r = reserva(db, ctx, MANANA, 15, creada_en=AHORA - timedelta(minutes=5))

    recordatorios = _detalle(cliente, r)["recordatorios"]

    assert [x["tipo"] for x in recordatorios] == ["1h"]


def test_una_reserva_cancelada_no_tiene_recordatorios(cliente, db, ctx):
    r = reserva(db, ctx, MANANA, 18, estado="cancelada")
    assert _detalle(cliente, r)["recordatorios"] == []


def test_la_lista_de_reservas_trae_los_recordatorios(cliente, db, ctx):
    reserva(db, ctx, date(2026, 10, 20), 19)

    lista = cliente.get("/api/v1/reservas", headers=auth_header("ana")).json()

    assert [x["tipo"] for x in lista[0]["recordatorios"]] == ["24h", "1h"]
