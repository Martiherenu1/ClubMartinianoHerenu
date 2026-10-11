"""Tests de reservas: crear (CU-09), listar (CU-08), detalle y cancelar (CU-10).

Reloj fijo: miércoles 14/10/2026 a las 15:30 (hora de Argentina).
"""
import threading
from datetime import date, datetime, time
from decimal import Decimal

import pytest
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core import tiempo
from app.core.errores import ErrorAPI
from app.models import EspacioDeportivo, Reserva, Sede, Usuario
from app.schemas.reserva import ReservaIn
from app.seed import cargar_catalogo
from app.services import reservas as servicio
from tests.conftest import auth_header

AHORA = datetime(2026, 10, 14, 15, 30, tzinfo=tiempo.ZONA)
HOY = AHORA.date()
MANANA = date(2026, 10, 15)
URL = "/api/v1/reservas"


@pytest.fixture(autouse=True)
def reloj_fijo(monkeypatch):
    monkeypatch.setattr(tiempo, "ahora", lambda: AHORA)


def _usuario(db, uid: str, dni: str) -> Usuario:
    u = Usuario(firebase_uid=uid, email=f"{uid}@mail.com", nombre="A", apellido="B",
                dni=dni, fecha_nacimiento=date(2000, 1, 1))
    db.add(u)
    db.flush()
    return u


def _f5_moron(db, numero: int = 1) -> EspacioDeportivo:
    return db.scalar(select(EspacioDeportivo).join(Sede).where(
        Sede.nombre == "Morón", EspacioDeportivo.tipo == "F5", EspacioDeportivo.numero == numero))


@pytest.fixture
def ctx(db):
    """Catálogo, dos usuarios (ana y beto) y la F5 Cancha 1 de Morón."""
    cargar_catalogo(db)
    ana = _usuario(db, "ana", "30000001")
    beto = _usuario(db, "beto", "30000002")
    return {"ana": ana, "beto": beto, "f5": _f5_moron(db), "h_ana": auth_header("ana"),
            "h_beto": auth_header("beto")}


def reservar(cliente, ctx, inicio="18:00", duracion=1, fecha=MANANA, quien="ana", espacio=None):
    body = {"espacio_id": (espacio or ctx["f5"]).id, "fecha": str(fecha),
            "hora_inicio": inicio, "duracion": duracion}
    return cliente.post(URL, json=body, headers=ctx[f"h_{quien}"])


def insertar(db, usuario, espacio, fecha, inicio, fin, estado="confirmada") -> Reserva:
    """Inserta directo en la base (para armar reservas pasadas o en curso)."""
    r = Reserva(usuario_id=usuario.id, espacio_id=espacio.id, fecha=fecha,
                hora_inicio=time(inicio), hora_fin=time(fin),
                precio_total=Decimal("3800"), estado=estado)
    db.add(r)
    db.flush()
    return r


# ---------- Crear (CU-09) ----------

def test_reservar_una_hora(cliente, ctx):
    r = reservar(cliente, ctx)
    assert r.status_code == 201, r.text
    d = r.json()
    assert (d["hora_inicio"], d["hora_fin"], d["duracion"]) == ("18:00:00", "19:00:00", 1)
    assert d["precio_total"] == 3800
    assert d["estado"] == "confirmada" and d["cancelable"] is True
    assert d["espacio"]["nombre_compuesto"] == "Moron_Rivadavia_17500_Futbol_F5_1"


def test_reservar_dos_horas_cobra_el_doble(cliente, ctx):
    d = reservar(cliente, ctx, duracion=2).json()
    assert d["hora_fin"] == "20:00:00" and d["precio_total"] == 7600


@pytest.mark.parametrize(("inicio", "duracion"), [("18:00", 1), ("17:00", 2), ("18:00", 2)])
def test_horario_superpuesto_responde_409(cliente, ctx, inicio, duracion):
    assert reservar(cliente, ctx, "18:00", 1).status_code == 201
    r = reservar(cliente, ctx, inicio, duracion, quien="beto")
    assert r.status_code == 409
    assert r.json()["error"]["codigo"] == "HORARIO_OCUPADO"


def test_turnos_pegados_no_se_pisan(cliente, ctx):
    assert reservar(cliente, ctx, "18:00").status_code == 201
    assert reservar(cliente, ctx, "19:00", quien="beto").status_code == 201
    assert reservar(cliente, ctx, "17:00", quien="beto").status_code == 201


def test_misma_hora_en_otra_cancha_se_puede(cliente, ctx, db):
    assert reservar(cliente, ctx, "18:00").status_code == 201
    assert reservar(cliente, ctx, "18:00", quien="beto", espacio=_f5_moron(db, 2)).status_code == 201


def test_cancelar_libera_el_horario(cliente, ctx):
    reserva = reservar(cliente, ctx).json()
    cliente.delete(f"{URL}/{reserva['id']}", headers=ctx["h_ana"])
    assert reservar(cliente, ctx, quien="beto").status_code == 201


@pytest.mark.parametrize(("inicio", "duracion"), [("07:00", 1), ("22:00", 2), ("23:00", 1)])
def test_fuera_del_horario_de_la_sede_responde_400(cliente, ctx, inicio, duracion):
    r = reservar(cliente, ctx, inicio, duracion)
    assert r.status_code == 400
    assert r.json()["error"]["codigo"] == "HORARIO_FUERA_DE_SEDE"


def test_ultima_franja_que_termina_al_cierre_se_puede(cliente, ctx):
    assert reservar(cliente, ctx, "21:00", 2).status_code == 201


@pytest.mark.parametrize(("fecha", "inicio"), [(HOY, "15:00"), (HOY, "10:00"), (date(2026, 10, 13), "18:00")])
def test_horario_pasado_responde_400(cliente, ctx, fecha, inicio):
    r = reservar(cliente, ctx, inicio, fecha=fecha)
    assert r.status_code == 400
    assert r.json()["error"]["codigo"] == "HORARIO_PASADO"


def test_hoy_mas_tarde_se_puede(cliente, ctx):
    assert reservar(cliente, ctx, "16:00", fecha=HOY).status_code == 201


@pytest.mark.parametrize(("inicio", "duracion"), [("18:30", 1), ("18:00", 3), ("18:00", 0)])
def test_horas_no_completas_o_duracion_invalida_responden_422(cliente, ctx, inicio, duracion):
    r = reservar(cliente, ctx, inicio, duracion)
    assert r.status_code == 422
    assert r.json()["error"]["codigo"] == "DATOS_INVALIDOS"


def test_cancha_inexistente_responde_404(cliente, ctx):
    r = cliente.post(URL, json={"espacio_id": 99999, "fecha": str(MANANA), "hora_inicio": "18:00"},
                     headers=ctx["h_ana"])
    assert r.status_code == 404


def test_reservar_requiere_sesion(cliente, ctx):
    r = cliente.post(URL, json={"espacio_id": ctx["f5"].id, "fecha": str(MANANA), "hora_inicio": "18:00"})
    assert r.status_code == 401


def test_la_reserva_aparece_ocupada_en_la_disponibilidad(cliente, ctx):
    """Integración CU-09 → CU-12: lo que se reserva deja de estar disponible."""
    reservar(cliente, ctx, "18:00")
    d = cliente.get(f"/api/v1/espacios/{ctx['f5'].id}/disponibilidad",
                    params={"fecha": str(MANANA)}, headers=ctx["h_beto"]).json()
    franja = next(f for f in d["franjas"] if f["hora_inicio"] == "18:00:00")
    assert franja == {"hora_inicio": "18:00:00", "hora_fin": "19:00:00", "disponible": False, "motivo": "ocupado"}


# ---------- Listar (CU-08) ----------

def test_proximas_e_historial(cliente, ctx, db):
    ana, f5 = ctx["ana"], ctx["f5"]
    futura_lejana = insertar(db, ana, f5, date(2026, 10, 20), 10, 11)
    futura_cercana = insertar(db, ana, f5, MANANA, 18, 19)
    en_curso = insertar(db, ana, f5, HOY, 15, 16)
    pasada = insertar(db, ana, f5, date(2026, 10, 1), 18, 19)
    cancelada = insertar(db, ana, f5, date(2026, 10, 22), 18, 19, estado="cancelada")
    insertar(db, ctx["beto"], f5, MANANA, 20, 21)  # de otro usuario: no aparece

    proximas = cliente.get(URL, params={"vista": "proximas"}, headers=ctx["h_ana"]).json()
    assert [r["id"] for r in proximas] == [en_curso.id, futura_cercana.id, futura_lejana.id]
    assert proximas[0]["estado"] == "en_curso" and proximas[0]["cancelable"] is False

    historial = cliente.get(URL, params={"vista": "historial"}, headers=ctx["h_ana"]).json()
    assert [r["id"] for r in historial] == [cancelada.id, pasada.id]
    assert [r["estado"] for r in historial] == ["cancelada", "completada"]


def test_vista_por_defecto_es_proximas(cliente, ctx):
    reservar(cliente, ctx)
    assert len(cliente.get(URL, headers=ctx["h_ana"]).json()) == 1


def test_sin_reservas_devuelve_listas_vacias(cliente, ctx):
    """CU-08 FA1: la app muestra "No se encontraron reservas…"."""
    for vista in ("proximas", "historial"):
        assert cliente.get(URL, params={"vista": vista}, headers=ctx["h_ana"]).json() == []


def test_vista_invalida_responde_422(cliente, ctx):
    assert cliente.get(URL, params={"vista": "todas"}, headers=ctx["h_ana"]).status_code == 422


# ---------- Detalle ----------

def test_detalle_de_reserva_propia(cliente, ctx):
    reserva = reservar(cliente, ctx).json()
    r = cliente.get(f"{URL}/{reserva['id']}", headers=ctx["h_ana"])
    assert r.status_code == 200 and r.json()["id"] == reserva["id"]


def test_reserva_ajena_no_se_ve(cliente, ctx):
    reserva = reservar(cliente, ctx).json()
    r = cliente.get(f"{URL}/{reserva['id']}", headers=ctx["h_beto"])
    assert r.status_code == 404
    assert r.json()["error"]["codigo"] == "RESERVA_NO_ENCONTRADA"


# ---------- Cancelar (CU-10) ----------

def test_cancelar_reserva(cliente, ctx):
    reserva = reservar(cliente, ctx).json()
    r = cliente.delete(f"{URL}/{reserva['id']}", headers=ctx["h_ana"])
    assert r.status_code == 200
    d = r.json()
    assert d["estado"] == "cancelada" and d["cancelable"] is False and d["cancelada_en"]
    # Pasa al historial.
    historial = cliente.get(URL, params={"vista": "historial"}, headers=ctx["h_ana"]).json()
    assert [x["id"] for x in historial] == [reserva["id"]]


def test_cancelar_dos_veces_responde_409(cliente, ctx):
    reserva = reservar(cliente, ctx).json()
    cliente.delete(f"{URL}/{reserva['id']}", headers=ctx["h_ana"])
    r = cliente.delete(f"{URL}/{reserva['id']}", headers=ctx["h_ana"])
    assert r.status_code == 409
    assert r.json()["error"]["mensaje"] == "La reserva ya estaba cancelada."


@pytest.mark.parametrize(("fecha", "inicio", "fin", "mensaje"), [
    (HOY, 15, 16, "No se puede cancelar una reserva que ya empezó."),  # CU-10 FA4
    (date(2026, 10, 1), 18, 19, "No se puede cancelar una reserva que ya terminó."),
])
def test_no_se_cancela_lo_que_ya_empezo_o_termino(cliente, ctx, db, fecha, inicio, fin, mensaje):
    reserva = insertar(db, ctx["ana"], ctx["f5"], fecha, inicio, fin)
    r = cliente.delete(f"{URL}/{reserva.id}", headers=ctx["h_ana"])
    assert r.status_code == 409
    assert r.json()["error"] == {"codigo": "RESERVA_NO_CANCELABLE", "mensaje": mensaje}


def test_no_se_cancela_una_reserva_ajena(cliente, ctx):
    reserva = reservar(cliente, ctx).json()
    assert cliente.delete(f"{URL}/{reserva['id']}", headers=ctx["h_beto"]).status_code == 404


# ---------- Concurrencia ----------

def test_dos_reservas_simultaneas_del_mismo_turno(engine):
    """Dos personas reservan el mismo turno al mismo tiempo: solo una lo consigue.

    Usa transacciones reales (con commit), no la transacción de prueba:
    1. La sesión A bloquea la cancha y guarda su reserva, sin confirmar todavía.
    2. La sesión B intenta reservar lo mismo: queda ESPERANDO el bloqueo.
    3. A confirma (commit). B continúa, ve la reserva de A y recibe 409.
    """
    with Session(engine) as preparacion:
        cargar_catalogo(preparacion)
        ana = _usuario(preparacion, "conc-ana", "39000001")
        beto = _usuario(preparacion, "conc-beto", "39000002")
        f5 = _f5_moron(preparacion)
        preparacion.commit()
        ids = {"ana": ana.id, "beto": beto.id, "f5": f5.id}

    resultado: dict = {}
    sesion_a, sesion_b = Session(engine), Session(engine)
    try:
        sesion_a.execute(select(EspacioDeportivo.id).where(EspacioDeportivo.id == ids["f5"]).with_for_update())
        sesion_a.add(Reserva(usuario_id=ids["ana"], espacio_id=ids["f5"], fecha=MANANA,
                             hora_inicio=time(18), hora_fin=time(19), precio_total=Decimal("3800")))
        sesion_a.flush()

        def reservar_b():
            try:
                servicio.crear(sesion_b, sesion_b.get(Usuario, ids["beto"]),
                               ReservaIn(espacio_id=ids["f5"], fecha=MANANA, hora_inicio=time(18)))
                resultado["b"] = "reservó"
            except ErrorAPI as e:
                resultado["b"] = e.codigo

        hilo = threading.Thread(target=reservar_b)
        hilo.start()
        hilo.join(timeout=1.5)
        assert hilo.is_alive(), "B debería estar esperando el bloqueo de A"

        sesion_a.commit()
        hilo.join(timeout=10)
        assert not hilo.is_alive()
        assert resultado["b"] == "HORARIO_OCUPADO"
    finally:
        sesion_a.close()
        sesion_b.close()
        with Session(engine) as limpieza:
            limpieza.execute(delete(Reserva).where(Reserva.usuario_id.in_([ids["ana"], ids["beto"]])))
            limpieza.execute(delete(Usuario).where(Usuario.id.in_([ids["ana"], ids["beto"]])))
            limpieza.execute(delete(EspacioDeportivo))
            limpieza.execute(delete(Sede))
            limpieza.commit()
