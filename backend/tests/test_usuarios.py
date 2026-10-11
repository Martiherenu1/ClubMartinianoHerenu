"""Tests de /api/v1/usuarios: registro, perfil, edición, baja y dispositivos."""
from datetime import date, time, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select

from app.core.tiempo import ahora
from app.models import Dispositivo, Reserva, Usuario
from app.seed import cargar_catalogo
from app.models import EspacioDeportivo
from tests.conftest import auth_header

URL = "/api/v1/usuarios"


def datos_registro(**cambios) -> dict:
    datos = {
        "email": "martiniano@mail.com",
        "password": "clave123",
        "nombre": "Martiniano",
        "apellido": "Hereñu",
        "dni": "40123456",
        "fecha_nacimiento": "2001-03-15",
    }
    datos.update(cambios)
    return datos


@pytest.fixture
def registrado(cliente) -> dict:
    """Registra un usuario y devuelve el JSON de la respuesta."""
    r = cliente.post(URL, json=datos_registro())
    assert r.status_code == 201, r.text
    return r.json()


# ---------- Registro (CU-03) ----------

def test_registro_crea_cuenta_en_firebase_y_perfil(cliente, db, firebase_falso):
    r = cliente.post(URL, json=datos_registro(email="Martiniano@Mail.com", dni="40.123.456"))
    assert r.status_code == 201
    cuerpo = r.json()
    assert cuerpo["email"] == "martiniano@mail.com"  # se guarda en minúsculas
    assert cuerpo["dni"] == "40123456"  # sin puntos
    assert cuerpo["activo"] is True
    assert "password" not in cuerpo
    assert firebase_falso.cuentas == {"martiniano@mail.com": "uid-1"}
    assert db.scalar(select(Usuario.firebase_uid)) == "uid-1"


def test_registro_con_dni_repetido_responde_409(cliente, registrado, firebase_falso):
    r = cliente.post(URL, json=datos_registro(email="otro@mail.com"))
    assert r.status_code == 409
    assert r.json()["error"]["codigo"] == "DNI_YA_REGISTRADO"
    assert "otro@mail.com" not in firebase_falso.cuentas  # no se creó la cuenta


def test_registro_con_email_repetido_responde_409(cliente, registrado):
    r = cliente.post(URL, json=datos_registro(dni="30111222"))
    assert r.status_code == 409
    assert r.json()["error"]["codigo"] == "EMAIL_YA_REGISTRADO"


def test_email_que_ya_existe_solo_en_firebase_responde_409(cliente, firebase_falso):
    firebase_falso.cuentas["martiniano@mail.com"] = "uid-viejo"
    r = cliente.post(URL, json=datos_registro())
    assert r.status_code == 409
    assert r.json()["error"]["codigo"] == "EMAIL_YA_REGISTRADO"


@pytest.mark.parametrize(
    ("campo", "valor"),
    [
        ("email", "no-es-un-email"),
        ("password", "123"),
        ("password", "1234567"),  # 7 caracteres: el Figma pide mínimo 8
        ("dni", "12ab"),
        ("nombre", "   "),
        ("fecha_nacimiento", "2999-01-01"),
    ],
)
def test_registro_con_datos_invalidos_responde_422(cliente, campo, valor, firebase_falso):
    r = cliente.post(URL, json=datos_registro(**{campo: valor}))
    assert r.status_code == 422
    assert r.json()["error"]["codigo"] == "DATOS_INVALIDOS"
    assert campo in r.json()["error"]["mensaje"]
    assert firebase_falso.cuentas == {}


def test_registro_con_campos_faltantes_responde_422(cliente):
    r = cliente.post(URL, json={"email": "a@a.com"})
    assert r.status_code == 422


# ---------- Perfil (CU-05) y edición (CU-06) ----------

def test_ver_mi_perfil(cliente, registrado):
    r = cliente.get(f"{URL}/me", headers=auth_header("uid-1"))
    assert r.status_code == 200
    assert r.json()["nombre"] == "Martiniano"


def test_ver_perfil_sin_token_responde_401(cliente):
    assert cliente.get(f"{URL}/me").status_code == 401


def test_editar_perfil(cliente, registrado):
    nuevos = {"nombre": "Martín", "apellido": "Hereñu", "dni": "40123457", "fecha_nacimiento": "2001-03-16"}
    r = cliente.put(f"{URL}/me", json=nuevos, headers=auth_header("uid-1"))
    assert r.status_code == 200
    assert r.json()["nombre"] == "Martín"
    assert r.json()["dni"] == "40123457"


def test_el_email_no_se_puede_editar(cliente, registrado):
    nuevos = {"nombre": "M", "apellido": "H", "dni": "40123456",
              "fecha_nacimiento": "2001-03-15", "email": "nuevo@mail.com"}
    r = cliente.put(f"{URL}/me", json=nuevos, headers=auth_header("uid-1"))
    assert r.status_code == 200
    assert r.json()["email"] == "martiniano@mail.com"


def test_editar_con_dni_de_otro_usuario_responde_409(cliente, registrado):
    cliente.post(URL, json=datos_registro(email="otra@mail.com", dni="30111222"))
    nuevos = {"nombre": "M", "apellido": "H", "dni": "30111222", "fecha_nacimiento": "2001-03-15"}
    r = cliente.put(f"{URL}/me", json=nuevos, headers=auth_header("uid-1"))
    assert r.status_code == 409
    assert r.json()["error"]["codigo"] == "DNI_YA_REGISTRADO"


# ---------- Baja (CU-07) ----------

def _reserva(db, usuario_id: int, dias: int, estado: str = "confirmada") -> Reserva:
    cargar_catalogo(db)
    espacio = db.scalar(select(EspacioDeportivo).limit(1))
    reserva = Reserva(
        usuario_id=usuario_id,
        espacio_id=espacio.id,
        fecha=ahora().date() + timedelta(days=dias),
        hora_inicio=time(18),
        hora_fin=time(19),
        precio_total=Decimal("3800"),
        estado=estado,
    )
    db.add(reserva)
    db.flush()
    return reserva


def test_baja_cancela_futuras_anonimiza_y_borra_de_firebase(cliente, db, registrado, firebase_falso):
    futura = _reserva(db, registrado["id"], dias=3)
    pasada = _reserva(db, registrado["id"], dias=-3)

    r = cliente.delete(f"{URL}/me", headers=auth_header("uid-1"))
    assert r.status_code == 204

    db.expire_all()
    usuario = db.get(Usuario, registrado["id"])
    assert usuario.activo is False
    assert usuario.email.endswith("@cuenta.eliminada")
    assert usuario.dni.startswith("baja-")
    assert db.get(Reserva, futura.id).estado == "cancelada"
    assert db.get(Reserva, pasada.id).estado == "confirmada"  # el historial no se toca
    assert firebase_falso.eliminados == ["uid-1"]


def test_despues_de_la_baja_el_token_viejo_no_sirve(cliente, registrado):
    cliente.delete(f"{URL}/me", headers=auth_header("uid-1"))
    assert cliente.get(f"{URL}/me", headers=auth_header("uid-1")).status_code in (401, 404)


def test_despues_de_la_baja_se_puede_volver_a_registrar(cliente, registrado, firebase_falso):
    cliente.delete(f"{URL}/me", headers=auth_header("uid-1"))
    firebase_falso.cuentas.clear()  # Firebase ya borró la cuenta
    r = cliente.post(URL, json=datos_registro())
    assert r.status_code == 201


# ---------- Dispositivos (CU-24 / CU-02) ----------

def test_registrar_y_quitar_dispositivo(cliente, db, registrado):
    token = "fcm-token-de-prueba-123"
    h = auth_header("uid-1")
    assert cliente.post(f"{URL}/me/dispositivos", json={"fcm_token": token}, headers=h).status_code == 204
    assert cliente.post(f"{URL}/me/dispositivos", json={"fcm_token": token}, headers=h).status_code == 204
    assert db.scalar(select(Dispositivo).where(Dispositivo.fcm_token == token)) is not None

    assert cliente.delete(f"{URL}/me/dispositivos/{token}", headers=h).status_code == 204
    assert db.scalar(select(Dispositivo).where(Dispositivo.fcm_token == token)) is None


def test_un_token_usado_por_otro_usuario_pasa_al_actual(cliente, db, registrado):
    cliente.post(URL, json=datos_registro(email="otra@mail.com", dni="30111222"))
    token = "fcm-token-compartido-1"
    cliente.post(f"{URL}/me/dispositivos", json={"fcm_token": token}, headers=auth_header("uid-1"))
    cliente.post(f"{URL}/me/dispositivos", json={"fcm_token": token}, headers=auth_header("uid-2"))
    dispositivo = db.scalar(select(Dispositivo).where(Dispositivo.fcm_token == token))
    assert db.get(Usuario, dispositivo.usuario_id).email == "otra@mail.com"
