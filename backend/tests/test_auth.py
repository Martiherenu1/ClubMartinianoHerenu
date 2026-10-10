"""Tests de autenticación: verificación del token y perfil del usuario actual."""
from datetime import date

import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.api.deps import get_uid_autenticado, get_usuario_actual
from app.core.errores import registrar_manejadores_de_error
from app.db.session import get_db
from app.models import Usuario
from tests.conftest import auth_header


@pytest.fixture
def cliente_auth(db):
    """API mínima con dos rutas protegidas, para probar las dependencias solas."""
    app = FastAPI()
    registrar_manejadores_de_error(app)

    @app.get("/uid")
    def ver_uid(uid: str = Depends(get_uid_autenticado)):
        return {"uid": uid}

    @app.get("/privado")
    def privado(usuario: Usuario = Depends(get_usuario_actual)):
        return {"email": usuario.email}

    app.dependency_overrides[get_db] = lambda: db
    return TestClient(app)


def crear_usuario(db, uid: str, activo: bool = True) -> Usuario:
    usuario = Usuario(
        firebase_uid=uid,
        email=f"{uid}@mail.com",
        nombre="Ana",
        apellido="Pérez",
        dni=f"4{len(uid)}{abs(hash(uid)) % 10**6:06d}",
        fecha_nacimiento=date(2000, 5, 10),
        activo=activo,
    )
    db.add(usuario)
    db.flush()
    return usuario


def test_sin_token_responde_401(cliente_auth):
    r = cliente_auth.get("/uid")
    assert r.status_code == 401
    assert r.json() == {
        "error": {"codigo": "NO_AUTENTICADO", "mensaje": "Tenés que iniciar sesión."}
    }


def test_token_invalido_responde_401(cliente_auth):
    r = cliente_auth.get("/uid", headers={"Authorization": "Bearer cualquier-cosa"})
    assert r.status_code == 401
    assert r.json()["error"]["codigo"] == "NO_AUTENTICADO"


def test_token_vencido_pide_volver_a_iniciar_sesion(cliente_auth):
    r = cliente_auth.get("/uid", headers={"Authorization": "Bearer token-vencido"})
    assert r.status_code == 401
    assert "expiró" in r.json()["error"]["mensaje"]


def test_token_valido_devuelve_el_uid(cliente_auth):
    r = cliente_auth.get("/uid", headers=auth_header("abc123"))
    assert r.status_code == 200
    assert r.json() == {"uid": "abc123"}


def test_token_valido_sin_perfil_responde_404(cliente_auth):
    r = cliente_auth.get("/privado", headers=auth_header("sin-perfil"))
    assert r.status_code == 404
    assert r.json()["error"]["codigo"] == "PERFIL_NO_ENCONTRADO"


def test_usuario_activo_accede(cliente_auth, db):
    crear_usuario(db, "ana1")
    r = cliente_auth.get("/privado", headers=auth_header("ana1"))
    assert r.status_code == 200
    assert r.json() == {"email": "ana1@mail.com"}


def test_cuenta_dada_de_baja_responde_401(cliente_auth, db):
    crear_usuario(db, "baja1", activo=False)
    r = cliente_auth.get("/privado", headers=auth_header("baja1"))
    assert r.status_code == 401
    assert r.json()["error"]["mensaje"] == "Esta cuenta fue dada de baja."
