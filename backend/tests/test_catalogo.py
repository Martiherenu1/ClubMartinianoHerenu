"""Tests del catálogo: /sedes, /espacios y /deportes."""
from datetime import date

import pytest
from sqlalchemy import select

from app.models import EspacioDeportivo, Sede, Usuario
from app.seed import cargar_catalogo
from tests.conftest import auth_header

API = "/api/v1"


@pytest.fixture
def h(db) -> dict[str, str]:
    """Catálogo cargado + un usuario con sesión; devuelve su header de auth."""
    cargar_catalogo(db)
    db.add(Usuario(firebase_uid="cat1", email="cat@mail.com", nombre="A", apellido="B",
                   dni="11222333", fecha_nacimiento=date(2000, 1, 1)))
    db.flush()
    return auth_header("cat1")


def _id_sede(db, nombre: str) -> int:
    return db.scalar(select(Sede.id).where(Sede.nombre == nombre))


def test_catalogo_requiere_sesion(cliente):
    for ruta in ("/sedes", "/espacios", "/deportes", "/sedes/1", "/espacios/1"):
        assert cliente.get(API + ruta).status_code == 401


def test_listar_sedes_como_en_el_figma(cliente, h):
    r = cliente.get(f"{API}/sedes", headers=h)
    assert r.status_code == 200
    sedes = r.json()
    assert [s["nombre"] for s in sedes] == ["Morón", "Ramos Mejía", "San Justo", "Castelar"]
    assert [s["cantidad_canchas"] for s in sedes] == [7, 4, 6, 5]
    moron = sedes[0]
    assert moron["direccion"] == "Av. Rivadavia 17500"
    assert moron["hora_apertura"] == "08:00:00"
    assert [d["deporte"] for d in moron["deportes"]] == ["Fútbol", "Tenis"]
    futbol = moron["deportes"][0]
    assert futbol["tipos"] == ["F5", "F7", "F11"]  # orden natural, como los chips del Figma


def test_filtrar_sedes_por_deporte(cliente, h):
    r = cliente.get(f"{API}/sedes", params={"deporte": "Hockey"}, headers=h)
    assert [s["nombre"] for s in r.json()] == ["Ramos Mejía", "Castelar"]


def test_ver_sede(cliente, h, db):
    r = cliente.get(f"{API}/sedes/{_id_sede(db, 'San Justo')}", headers=h)
    assert r.status_code == 200
    assert r.json()["cantidad_canchas"] == 6


def test_sede_inexistente_responde_404(cliente, h):
    r = cliente.get(f"{API}/sedes/99999", headers=h)
    assert r.status_code == 404
    assert r.json()["error"]["codigo"] == "SEDE_NO_ENCONTRADA"


def test_listar_todas_las_canchas(cliente, h):
    r = cliente.get(f"{API}/espacios", headers=h)
    assert r.status_code == 200
    assert len(r.json()) == 22


def test_filtros_de_canchas_se_combinan(cliente, h, db):
    moron = _id_sede(db, "Morón")
    r = cliente.get(f"{API}/espacios", params={"sede_id": moron, "deporte": "Fútbol", "tipo": "F5"}, headers=h)
    canchas = r.json()
    assert [c["numero"] for c in canchas] == [1, 2]
    assert canchas[0]["nombre_compuesto"] == "Moron_Rivadavia_17500_Futbol_F5_1"
    assert canchas[0]["cubierto"] is False and canchas[1]["cubierto"] is True
    assert canchas[0]["precio_hora"] == 3800
    assert canchas[0]["sede"] == {"id": moron, "nombre": "Morón", "direccion": "Av. Rivadavia 17500"}
    assert canchas[0]["hora_cierre"] == "23:00:00"


def test_filtro_sin_resultados_devuelve_lista_vacia(cliente, h):
    r = cliente.get(f"{API}/espacios", params={"deporte": "Básquet"}, headers=h)
    assert r.status_code == 200
    assert r.json() == []


def test_ver_cancha(cliente, h, db):
    espacio_id = db.scalar(select(EspacioDeportivo.id).where(EspacioDeportivo.tipo == "9 hoyos"))
    r = cliente.get(f"{API}/espacios/{espacio_id}", headers=h)
    assert r.status_code == 200
    assert r.json()["nombre_compuesto"] == "SanJusto_Casanova_320_Golf_9Hoyos_1"


def test_cancha_inactiva_no_aparece_y_da_404(cliente, h, db):
    espacio = db.scalar(select(EspacioDeportivo).where(EspacioDeportivo.tipo == "H7"))
    espacio.activo = False
    db.flush()
    assert len(cliente.get(f"{API}/espacios", headers=h).json()) == 21
    r = cliente.get(f"{API}/espacios/{espacio.id}", headers=h)
    assert r.status_code == 404
    assert r.json()["error"]["codigo"] == "ESPACIO_NO_ENCONTRADO"


def test_sede_inactiva_oculta_sus_canchas(cliente, h, db):
    db.get(Sede, _id_sede(db, "Castelar")).activa = False
    db.flush()
    assert len(cliente.get(f"{API}/sedes", headers=h).json()) == 3
    assert len(cliente.get(f"{API}/espacios", headers=h).json()) == 17


def test_deportes_para_los_filtros(cliente, h):
    r = cliente.get(f"{API}/deportes", headers=h)
    deportes = {d["deporte"]: d["tipos"] for d in r.json()}
    assert set(deportes) == {"Fútbol", "Tenis", "Hockey", "Vóley", "Golf"}
    assert deportes["Fútbol"] == ["F5", "F7", "F8", "F11"]
