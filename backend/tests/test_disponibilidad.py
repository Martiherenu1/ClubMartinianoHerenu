"""Tests de horarios disponibles (CU-12).

Se fija "ahora" en una fecha conocida para que los tests no dependan del día en
que se corren: miércoles 14/10/2026 a las 15:30 (hora de Argentina).
"""
from datetime import date, datetime, time
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.core import tiempo
from app.models import EspacioDeportivo, Reserva, Sede, Usuario
from app.seed import cargar_catalogo
from app.services.disponibilidad import calcular_franjas, se_superponen
from tests.conftest import auth_header

AHORA = datetime(2026, 10, 14, 15, 30, tzinfo=tiempo.ZONA)
HOY = AHORA.date()
MANANA = date(2026, 10, 15)


@pytest.fixture(autouse=True)
def reloj_fijo(monkeypatch):
    monkeypatch.setattr(tiempo, "ahora", lambda: AHORA)


# ---------- Función pura: calcular_franjas ----------

def horas(franjas, solo_disponibles=False):
    return [f"{f.inicio:%H}-{f.fin:%H}" for f in franjas if f.disponible or not solo_disponibles]


def test_una_hora_de_8_a_23_da_15_franjas():
    franjas = calcular_franjas(time(8), time(23), 1, [], MANANA, AHORA)
    assert len(franjas) == 15
    assert horas(franjas)[0] == "08-09" and horas(franjas)[-1] == "22-23"
    assert all(f.disponible for f in franjas)


def test_dos_horas_la_ultima_termina_al_cierre():
    franjas = calcular_franjas(time(8), time(23), 2, [], MANANA, AHORA)
    assert len(franjas) == 14
    assert horas(franjas)[-1] == "21-23"


def test_reserva_ocupa_su_franja():
    franjas = calcular_franjas(time(8), time(23), 1, [(time(18), time(19))], MANANA, AHORA)
    ocupada = [f for f in franjas if not f.disponible]
    assert horas(ocupada) == ["18-19"]
    assert ocupada[0].motivo == "ocupado"


def test_con_dos_horas_una_reserva_bloquea_las_franjas_que_la_pisan():
    franjas = calcular_franjas(time(8), time(23), 2, [(time(18), time(19))], MANANA, AHORA)
    assert horas([f for f in franjas if not f.disponible]) == ["17-19", "18-20"]


def test_reserva_de_dos_horas_bloquea_dos_franjas_de_una_hora():
    franjas = calcular_franjas(time(8), time(23), 1, [(time(18), time(20))], MANANA, AHORA)
    assert horas([f for f in franjas if not f.disponible]) == ["18-19", "19-20"]


def test_hoy_las_franjas_que_ya_empezaron_no_se_pueden_reservar():
    # Son las 15:30: la de 15 a 16 ya empezó.
    franjas = calcular_franjas(time(8), time(23), 1, [], HOY, AHORA)
    pasadas = [f for f in franjas if f.motivo == "pasado"]
    assert horas(pasadas)[-1] == "15-16"
    assert len(pasadas) == 8
    assert horas(franjas, solo_disponibles=True)[0] == "16-17"


def test_se_superponen():
    assert se_superponen(time(18), time(20), time(19), time(21))
    assert not se_superponen(time(18), time(19), time(19), time(20))


# ---------- Endpoint ----------

@pytest.fixture
def ctx(db):
    """Catálogo + usuario con sesión. Devuelve (header, F5 Cancha 1 de Morón)."""
    cargar_catalogo(db)
    usuario = Usuario(firebase_uid="disp1", email="disp@mail.com", nombre="A", apellido="B",
                      dni="22333444", fecha_nacimiento=date(2000, 1, 1))
    db.add(usuario)
    db.flush()
    f5 = db.scalar(
        select(EspacioDeportivo).join(Sede).where(
            Sede.nombre == "Morón", EspacioDeportivo.tipo == "F5", EspacioDeportivo.numero == 1
        )
    )
    return auth_header("disp1"), f5, usuario


def url(espacio_id: int) -> str:
    return f"/api/v1/espacios/{espacio_id}/disponibilidad"


def reservar(db, usuario, espacio, inicio: int, fin: int, estado="confirmada", fecha=MANANA):
    db.add(Reserva(usuario_id=usuario.id, espacio_id=espacio.id, fecha=fecha,
                   hora_inicio=time(inicio), hora_fin=time(fin),
                   precio_total=Decimal("3800"), estado=estado))
    db.flush()


def test_requiere_sesion(cliente, ctx):
    _, f5, _ = ctx
    assert cliente.get(url(f5.id), params={"fecha": str(MANANA)}).status_code == 401


def test_dia_libre_como_en_el_figma(cliente, ctx):
    h, f5, _ = ctx
    r = cliente.get(url(f5.id), params={"fecha": str(MANANA), "duracion": 1}, headers=h)
    assert r.status_code == 200
    d = r.json()
    assert d["espacio"]["nombre_compuesto"] == "Moron_Rivadavia_17500_Futbol_F5_1"
    assert d["precio_hora"] == 3800 and d["precio_total"] == 3800
    assert d["cantidad_disponibles"] == 15 and d["cantidad_no_disponibles"] == 0
    assert d["franjas"][0] == {"hora_inicio": "08:00:00", "hora_fin": "09:00:00",
                               "disponible": True, "motivo": None}


def test_duracion_por_defecto_es_una_hora(cliente, ctx):
    h, f5, _ = ctx
    r = cliente.get(url(f5.id), params={"fecha": str(MANANA)}, headers=h)
    assert r.json()["duracion"] == 1


def test_dos_horas_duplica_el_total(cliente, ctx):
    h, f5, _ = ctx
    d = cliente.get(url(f5.id), params={"fecha": str(MANANA), "duracion": 2}, headers=h).json()
    assert d["precio_total"] == 7600  # el "$7.600" del Figma
    assert len(d["franjas"]) == 14


def test_reservas_confirmadas_ocupan_y_canceladas_no(cliente, db, ctx):
    h, f5, usuario = ctx
    reservar(db, usuario, f5, 18, 19)
    reservar(db, usuario, f5, 20, 21, estado="cancelada")
    d = cliente.get(url(f5.id), params={"fecha": str(MANANA)}, headers=h).json()
    no_disp = [(f["hora_inicio"], f["motivo"]) for f in d["franjas"] if not f["disponible"]]
    assert no_disp == [("18:00:00", "ocupado")]
    assert d["cantidad_no_disponibles"] == 1


def test_reservas_de_otra_cancha_no_afectan(cliente, db, ctx):
    h, f5, usuario = ctx
    otra = db.scalar(select(EspacioDeportivo).where(
        EspacioDeportivo.sede_id == f5.sede_id, EspacioDeportivo.tipo == "F5", EspacioDeportivo.numero == 2))
    reservar(db, usuario, otra, 18, 19)
    d = cliente.get(url(f5.id), params={"fecha": str(MANANA)}, headers=h).json()
    assert d["cantidad_disponibles"] == 15


def test_dia_completo_sin_horarios(cliente, db, ctx):
    """CU-12 FA4: si no queda ninguna franja libre, la app muestra el estado vacío."""
    h, f5, usuario = ctx
    reservar(db, usuario, f5, 8, 23)
    d = cliente.get(url(f5.id), params={"fecha": str(MANANA)}, headers=h).json()
    assert d["cantidad_disponibles"] == 0
    assert all(f["motivo"] == "ocupado" for f in d["franjas"])


def test_hoy_marca_las_franjas_pasadas(cliente, ctx):
    h, f5, _ = ctx
    d = cliente.get(url(f5.id), params={"fecha": str(HOY)}, headers=h).json()
    assert d["cantidad_no_disponibles"] == 8  # de 08 a 16, ya empezadas a las 15:30
    assert d["franjas"][7]["motivo"] == "pasado"


def test_horario_de_otra_sede(cliente, db, ctx):
    h, _, _ = ctx
    rm = db.scalar(select(EspacioDeportivo).join(Sede).where(Sede.nombre == "Ramos Mejía").limit(1))
    d = cliente.get(url(rm.id), params={"fecha": str(MANANA)}, headers=h).json()
    assert len(d["franjas"]) == 13  # 09 a 22
    assert d["franjas"][0]["hora_inicio"] == "09:00:00"


def test_fecha_pasada_responde_400(cliente, ctx):
    h, f5, _ = ctx
    r = cliente.get(url(f5.id), params={"fecha": "2026-10-13"}, headers=h)
    assert r.status_code == 400
    assert r.json()["error"]["codigo"] == "FECHA_PASADA"


@pytest.mark.parametrize("params", [{"fecha": "2026-10-15", "duracion": 3},
                                    {"fecha": "2026-10-15", "duracion": 0},
                                    {"fecha": "15/10/2026"},
                                    {}])
def test_parametros_invalidos_responden_422(cliente, ctx, params):
    h, f5, _ = ctx
    r = cliente.get(url(f5.id), params=params, headers=h)
    assert r.status_code == 422
    assert r.json()["error"]["codigo"] == "DATOS_INVALIDOS"


def test_cancha_inexistente_responde_404(cliente, ctx):
    h, _, _ = ctx
    r = cliente.get(url(99999), params={"fecha": str(MANANA)}, headers=h)
    assert r.status_code == 404
    assert r.json()["error"]["codigo"] == "ESPACIO_NO_ENCONTRADO"
